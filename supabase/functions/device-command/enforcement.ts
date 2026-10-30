// Pure enforcement mapping for apply_policy acknowledgements.
//
// The device ack carries the counter set produced by PolicyApplier.kt. A bare
// success boolean is never enough: a command can "succeed" while zero apps are
// suspended (for example when the phone is not a Device Owner). The frozen
// contract in docs/implementation/_work/coordinator-contract.md defines the
// only honest mapping.
//
// Run the tests with:
//   deno test supabase/functions/device-command

export type EnforcementStatus = "pending" | "enforced" | "failed" | "unsupported";

export interface EnforcementInput {
  /** The `result` object of the ack, or null when the device sent none. */
  result: Record<string, unknown> | null;
  /** "succeeded" | "failed" | "expired" (the device_commands status). */
  ackStatus: string;
  /** True when the stored policy selects at least one app to block. */
  targetsApps: boolean;
}

export interface EnforcementDecision {
  status: EnforcementStatus;
  /** Short, truthful explanation; null only for a proven "enforced". */
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
 */
export function policyTargetsApps(policy: unknown): boolean {
  if (!isRecord(policy)) return false;
  const blocked = Array.isArray(policy.blocked_packages) &&
    policy.blocked_packages.length > 0;
  const rules = Array.isArray(policy.app_rules) &&
    policy.app_rules.some((rule) => isRecord(rule) && rule.blocked === true);
  return blocked || rules || policy.block_all_except_allowed === true;
}

export function decideEnforcement(input: EnforcementInput): EnforcementDecision {
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

  // Zero desired and a policy that does not target apps: there is nothing to
  // suspend, and Device Owner is confirmed, so the version is applied.
  return {
    ...base,
    status: "enforced",
    lastError: null,
    advancePolicyVersion: true,
  };
}