// Pure enforcement mapping for apply_policy acknowledgements.
//
// The device ack carries the counter set produced by PolicyApplier.kt. A bare
// success boolean is never enough: a command can "succeed" while zero apps are
// suspended (for example when the phone is not a Device Owner). The frozen
// contract in docs/implementation/_work/coordinator-contract.md defines the
// only honest mapping.
//
// T-B-02 adds the second half of that evidence: a nested `result.quota` block
// reporting the daily screen-time budget, the measured usage and what the
// device actually did about it. The block is validated by `normalizeQuotaAck`
// before anything reads it, and a block that is absent or malformed is worth
// exactly nothing — it degrades to the T-B-01 `limits_enforcement_unverified`
// verdict instead of becoming a claim. `enforcement_status` stays inside the
// hosted enum of 20260101000000_core.sql ('pending' | 'enforced' | 'failed' |
// 'unsupported'); DEC-12's *Proposed* `partially_enforced` is never emitted.
//
// Run the tests with:
//   deno test supabase/functions/device-command

export type EnforcementStatus = "pending" | "enforced" | "failed" | "unsupported";

/**
 * The `result.quota.action` vocabulary the device emits. Anything else is a
 * protocol violation and is never treated as proof.
 */
export type QuotaAction = "none" | "advisory" | "suspended" | "suspend_failed";

const QUOTA_ACTIONS: readonly string[] = [
  "none",
  "advisory",
  "suspended",
  "suspend_failed",
];

/**
 * The validated `result.quota` block of an `apply_policy` ack (T-B-02, DEC-12
 * sections 4.1/4.2/5). Every field is kept exactly as the device reported it
 * once — and only once — it passed validation, so a downstream verdict can
 * never accidentally trust a value `normalizeQuotaAck` did not check.
 */
export interface QuotaAck {
  configured: boolean;
  usage_available: boolean;
  usage_minutes: number | null;
  limit_minutes: number | null;
  day_bucket: string | null;
  limit_reached: boolean;
  action: QuotaAction;
  desired_count: number | null;
  applied_count: number | null;
  failed_count: number | null;
  enforcement_supported: boolean;
  enforcement_mode: string;
  reason: string | null;
}

export interface EnforcementInput {
  /** The `result` object of the ack, or null when the device sent none. */
  result: Record<string, unknown> | null;
  /** "succeeded" | "failed" | "expired" (the device_commands status). */
  ackStatus: string;
  /** True when the stored policy selects at least one app to block. */
  targetsApps: boolean;
  /**
   * True when the stored policy configures a daily limit or a bedtime window.
   * The ack counters describe package suspension only, so such a policy can
   * never be proven applied by this mapping (see `policyDeclaresTimeLimits`).
   */
  timeLimitsConfigured: boolean;
  /**
   * The `result.quota` block of the ack, already passed through
   * `normalizeQuotaAck`. `null` means the ack carried no quota proof at all:
   * either the device is older than T-B-02, or the block was present but
   * malformed and therefore rejected.
   *
   * Required, not optional, for the same reason `timeLimitsConfigured` is: a
   * call site that forgot it would silently skip quota reasoning and fall back
   * to the pre-T-B-02 "the counters prove everything" verdict. TypeScript then
   * forces the single production call site in `handler.ts` to compute it.
   */
  quota: QuotaAck | null;
}

export interface EnforcementDecision {
  status: EnforcementStatus;
  /**
   * Short, truthful explanation. `enforced` from the app counters keeps it null;
   * an enforced *quota* uses it to qualify which half was proven.
   */
  lastError: string | null;
  desiredCount: number | null;
  appliedCount: number | null;
  failedCount: number | null;
  enforcementSupported: boolean;
  /** devices.policy_version may advance only on enforced/unsupported. */
  advancePolicyVersion: boolean;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Non-negative integers only; anything else is "not reported". */
function readCount(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  if (!Number.isInteger(value) || value < 0) return null;
  return value;
}

/**
 * Whether a policy payload asks for app blocking. This decides the "desired
 * count must be positive" rule: a policy that does not target apps may be
 * enforced with zero suspended packages.
 *
 * Time-based controls are deliberately NOT app targets here. A daily limit or a
 * bedtime window suspends no package, so it must not be counted as an app
 * target — and, equally, its presence must not let a zero-target policy claim
 * `enforced`. That second half is `policyDeclaresTimeLimits`'s job.
 */
export function policyTargetsApps(policy: unknown): boolean {
  if (!isRecord(policy)) return false;
  const blocked = Array.isArray(policy.blocked_packages) &&
    policy.blocked_packages.length > 0;
  const rules = Array.isArray(policy.app_rules) &&
    policy.app_rules.some((rule) => isRecord(rule) && rule.blocked === true);
  return blocked || rules || policy.block_all_except_allowed === true;
}

/**
 * Whether a policy payload configures screen-time or bedtime control.
 *
 * `supabase/functions/_shared/policy.ts:33-35` stores these three fields as
 * `number | null`, and validation writes an explicit `null` for "not
 * configured" (`policy.ts:204-211`), so only a present non-null value counts.
 * `0` is a legitimate bedtime minute value and must be treated as configured,
 * which is why this tests for null/undefined rather than truthiness.
 */
export function policyDeclaresTimeLimits(policy: unknown): boolean {
  if (!isRecord(policy)) return false;
  const keys = [
    "daily_screen_time_limit_minutes",
    "bedtime_start_minutes",
    "bedtime_end_minutes",
  ] as const;
  return keys.some((key) =>
    policy[key] !== undefined && policy[key] !== null
  );
}

/**
 * `true` / `false` are the only valid values. `null` means "malformed", which
 * the caller must read as "reject the whole quota block": a missing or
 * non-boolean flag cannot be guessed at, and guessing it as `false` would let a
 * truncated ack silently change the verdict.
 */
function readQuotaBoolean(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

/**
 * Tri-state read of a nullable quota string.
 *   string              - accepted verbatim
 *   null                - absent (missing key or explicit null), which the
 *                         contract allows for these fields
 *   undefined           - malformed: present but not a string
 */
function readQuotaString(
  value: unknown,
): string | null | undefined {
  if (value === undefined || value === null) return null;
  return typeof value === "string" ? value : undefined;
}

/**
 * Tri-state read of a quota number/count.
 *   number              - a real non-negative integer
 *   null                - absent (missing key or explicit null): "not reported"
 *   undefined           - malformed: negative, fractional, non-numeric, NaN or
 *                         Infinity. The caller must reject the whole block.
 *
 * Absent counts stay usable, because DEC-12 section 5 wants a *positive*
 * suspension count as proof: an ack that reports no counts can only ever be
 * read as "not confirmed", never as "applied".
 */
function readQuotaCount(value: unknown): number | null | undefined {
  if (value === undefined || value === null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  if (!Number.isInteger(value) || value < 0) return undefined;
  return value;
}

/**
 * Validate the `result.quota` block of an `apply_policy` ack.
 *
 * Returns `null` in both directions of "no quota proof": the block is absent
 * (a device predating T-B-02) and the block is present but malformed. This is
 * deliberate — a malformed proof must degrade to the honest non-advancing
 * verdict, exactly like the count cross-checks in `decideEnforcement`, and it
 * must never be repaired into a claim that looks like device evidence. An old
 * device therefore cannot gain the ability to claim quota support by sending a
 * half-filled block.
 */
export function normalizeQuotaAck(result: unknown): QuotaAck | null {
  if (!isRecord(result)) return null;
  const quota = result.quota;
  if (quota === undefined || quota === null) return null;
  if (!isRecord(quota)) return null;

  const configured = readQuotaBoolean(quota.configured);
  const usageAvailable = readQuotaBoolean(quota.usage_available);
  const limitReached = readQuotaBoolean(quota.limit_reached);
  const supported = readQuotaBoolean(quota.enforcement_supported);
  if (
    configured === null || usageAvailable === null || limitReached === null ||
    supported === null
  ) {
    return null;
  }

  const action = quota.action;
  if (typeof action !== "string" || !QUOTA_ACTIONS.includes(action)) return null;

  const mode = quota.enforcement_mode;
  if (typeof mode !== "string") return null;

  const usageMinutes = readQuotaCount(quota.usage_minutes);
  const limitMinutes = readQuotaCount(quota.limit_minutes);
  if (usageMinutes === undefined || limitMinutes === undefined) return null;

  const dayBucket = readQuotaString(quota.day_bucket);
  const reason = readQuotaString(quota.reason);
  if (dayBucket === undefined || reason === undefined) return null;

  const desiredCount = readQuotaCount(quota.desired_count);
  const appliedCount = readQuotaCount(quota.applied_count);
  const failedCount = readQuotaCount(quota.failed_count);
  if (
    desiredCount === undefined || appliedCount === undefined ||
    failedCount === undefined
  ) {
    return null;
  }

  // Cross-checks. Each one is a device contradicting itself, which is the
  // same class of defect the app-counter cross-check already refuses: an ack
  // that cannot be true cannot be proof.
  if (!usageAvailable && usageMinutes !== null) return null;
  if (limitReached && !usageAvailable) return null;
  if (
    appliedCount !== null && desiredCount !== null && appliedCount > desiredCount
  ) {
    return null;
  }

  return {
    configured,
    usage_available: usageAvailable,
    usage_minutes: usageMinutes,
    limit_minutes: limitMinutes,
    day_bucket: dayBucket,
    limit_reached: limitReached,
    action: action as QuotaAction,
    desired_count: desiredCount,
    applied_count: appliedCount,
    failed_count: failedCount,
    enforcement_supported: supported,
    enforcement_mode: mode,
    reason,
  };
}

/**
 * The pre-T-B-02 mapping, unchanged and byte-compatible: the ack counters
 * describe *package suspension* and nothing else. Extracted so the quota
 * reasoning in `decideEnforcement` can compose with it instead of editing it,
 * which is what keeps every T-B-01 and T-B-02-app assertion below intact.
 */
function decideAppEnforcement(input: EnforcementInput): EnforcementDecision {
  const result = isRecord(input.result) ? input.result : null;
  const supportedRaw = result?.enforcement_supported;
  const explicitlyUnsupported = supportedRaw === false;
  const supported = supportedRaw === true;

  const desiredCount = readCount(result?.desired_count);
  const appliedCount = readCount(result?.applied_count);
  const failedCount = readCount(result?.failed_count);
  const countsPresent =
    desiredCount !== null && appliedCount !== null && failedCount !== null;

  const base = {
    desiredCount,
    appliedCount,
    failedCount,
    enforcementSupported: supported,
    advancePolicyVersion: false,
  };

  // The device was evaluated and says it cannot suspend packages at all.
  // This wins even if some packages happen to still be suspended: the
  // installation cannot enforce future changes.
  if (explicitlyUnsupported) {
    return {
      ...base,
      status: "unsupported",
      lastError: "device_owner_required",
      advancePolicyVersion: true,
    };
  }

  if (!countsPresent || !supported) {
    // Old clients, an expired command or a malformed result: nothing can be
    // proven, so the policy stays pending and the version does not advance.
    return {
      ...base,
      status: "pending",
      lastError: input.ackStatus === "expired"
        ? "command_expired"
        : "enforcement_counts_missing",
    };
  }

  if (input.targetsApps && desiredCount === 0) {
    // The policy blocks apps but the device resolved zero targets. Claiming
    // "enforced" here is exactly the defect this phase removes.
    return {
      ...base,
      status: "pending",
      lastError: "no_apps_suspended",
    };
  }

  if (failedCount > 0 || appliedCount !== desiredCount) {
    return {
      ...base,
      status: "failed",
      lastError: `suspended ${appliedCount} of ${desiredCount}`,
    };
  }

  if (input.timeLimitsConfigured && !input.targetsApps) {
    // The parent configured a daily limit or a bedtime window and the policy
    // blocks no app. The ack proves package suspension only, so time-based
    // control is unverified here — never "applied". Pending, and the version
    // stays where it is until the device can report the real outcome.
    return {
      ...base,
      status: "pending",
      lastError: "limits_enforcement_unverified",
    };
  }

  // Zero desired and a policy that does not target apps: there is nothing to
  // suspend, and Device Owner is confirmed, so the version is applied.
  return {
    ...base,
    status: "enforced",
    lastError: null,
    advancePolicyVersion: true,
  };
}

/**
 * The one place the hosted enum is written for quota verdicts. `enforced` and
 * `unsupported` advance `devices.policy_version`; `pending` and `failed` never
 * do, which is the pre-existing rule (DEC-12 section 5: `unsupported` advances
 * precisely to stop a retry loop against a Standard Mode device).
 *
 * No branch here can emit any other status: `partially_enforced` is still
 * marked *Proposed* in DEC-12 and is refused by the
 * `20260101000000_core.sql:185-186` CHECK, so inventing it would fail the ack
 * write at the database instead of informing the parent.
 */
function quotaDecision(
  quota: QuotaAck,
  status: EnforcementStatus,
  lastError: string | null,
): EnforcementDecision {
  return {
    status,
    lastError,
    desiredCount: quota.desired_count,
    appliedCount: quota.applied_count,
    failedCount: quota.failed_count,
    enforcementSupported: quota.enforcement_supported,
    advancePolicyVersion: status === "enforced" || status === "unsupported",
  };
}

/**
 * The seven quota states of DEC-12 sections 4.1, 4.2 and 5, read from a block
 * `normalizeQuotaAck` already accepted.
 *
 * A command receipt is never proof: only `action: "suspended"` with a positive
 * desired count, `applied_count == desired_count`, `failed_count == 0` and a
 * Managed device reports an *enforced* limit, and only a measured usage figure
 * below the budget reports the monitor as active.
 */
function decideQuotaEnforcement(quota: QuotaAck): EnforcementDecision {
  // The device holds no quota at all, so the stored limit was never installed.
  if (!quota.configured) {
    return quotaDecision(quota, "pending", "quota_not_configured");
  }

  // Nothing was measured: the limit can be neither proven applied nor proven
  // satisfied, so the policy stays pending and the version stays put.
  if (!quota.usage_available) {
    return quotaDecision(quota, "pending", "quota_usage_unavailable");
  }

  if (!quota.limit_reached) {
    // "Available" without a number is self-contradictory; refuse to read it as
    // a measurement that would let the policy advance to enforced.
    if (quota.usage_minutes === null) {
      return quotaDecision(quota, "pending", "quota_usage_unavailable");
    }
    // Under budget the suspension is *not* supposed to be active. On a Managed
    // device the monitor is provably running, so the policy is applied; on a
    // Standard device nothing more than an advisory is possible, and DEC-12
    // section 5 says `unsupported` (which advances) rather than a retry loop.
    return quota.enforcement_supported
      ? quotaDecision(quota, "enforced", "quota_below_limit")
      : quotaDecision(quota, "unsupported", "quota_advisory_only");
  }

  if (quota.action === "suspend_failed") {
    const partial = quota.desired_count !== null && quota.applied_count !== null &&
      quota.applied_count > 0 && quota.applied_count < quota.desired_count;
    return quotaDecision(
      quota,
      "failed",
      partial
        ? `quota_suspended ${quota.applied_count} of ${quota.desired_count}`
        : "quota_suspend_failed",
    );
  }

  // The device itself says the outcome is unconfirmed. Whatever the action
  // string claims, this is never proof.
  if (quota.reason === "quota_confirmation_missing") {
    return quotaDecision(quota, "pending", "quota_confirmation_missing");
  }

  if (quota.action === "advisory" && !quota.enforcement_supported) {
    return quotaDecision(quota, "unsupported", "quota_advisory_only");
  }

  if (
    quota.action === "suspended" && quota.enforcement_supported &&
    quota.desired_count !== null && quota.applied_count !== null &&
    quota.failed_count !== null && quota.desired_count > 0 &&
    quota.applied_count === quota.desired_count && quota.failed_count === 0
  ) {
    return quotaDecision(quota, "enforced", null);
  }

  // Limit reached, capable device, but the suspension is not established:
  // absent counts, zero applied, a lying failed_count, or `action: "none"`.
  return quotaDecision(quota, "pending", "quota_confirmation_missing");
}

export function decideEnforcement(input: EnforcementInput): EnforcementDecision {
  const app = decideAppEnforcement(input);

  // No daily limit or bedtime configured, an expired command, or an ack whose
  // quota block is absent or malformed: the pre-T-B-02 verdict answers, so an
  // old device keeps reporting `limits_enforcement_unverified` and can never
  // claim quota support.
  if (
    !input.timeLimitsConfigured || input.quota === null ||
    input.ackStatus === "expired"
  ) {
    return app;
  }

  const quota = decideQuotaEnforcement(input.quota);

  // A limits-only policy says nothing about packages, so the quota block is
  // the only evidence there is and it decides on its own.
  if (!input.targetsApps) return quota;

  // Mixed policy (app targets + a daily limit). The app counters are the only
  // evidence for the blocking half, and a quota success cannot repair an app
  // failure: `failed` stays `failed`.
  if (app.status === "failed") return app;
  // Conversely a quota suspension that the device says *failed* is a positive
  // contradiction of "all limits enforced", so it out-votes a non-failing app
  // verdict. Status `failed` is the truthful vocabulary the hosted CHECK
  // allows; the partial case keeps the counts in `last_error`.
  if (quota.status === "failed") return quota;
  // Otherwise the app verdict is preserved unchanged — including its advance
  // rule — and the quota state is reported through `last_error`, which is how
  // the parent sees "apps are blocked, the limit half is only advisory".
  return { ...app, lastError: app.lastError ?? quota.lastError };
}