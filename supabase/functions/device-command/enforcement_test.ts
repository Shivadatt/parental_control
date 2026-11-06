// Pure mapping tests for apply_policy acknowledgements.
// Run with:
//   deno test supabase/functions/device-command
// No network, no Supabase client.
import {
  decideEnforcement,
  normalizeQuotaAck,
  policyDeclaresTimeLimits,
  policyTargetsApps,
  type EnforcementInput,
  type QuotaAck,
} from "./enforcement.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${expected}, got ${actual}`,
    );
  }
}

function input(overrides: Partial<EnforcementInput> = {}): EnforcementInput {
  return {
    result: {
      desired_count: 5,
      applied_count: 5,
      failed_count: 0,
      enforcement_supported: true,
      enforcement_mode: "device_owner",
      failures: [],
    },
    ackStatus: "succeeded",
    targetsApps: true,
    // No time-based control by default: the pre-T-B-01 ack shape stays the one
    // every existing case in this file was written against.
    timeLimitsConfigured: false,
    // Neutral quota: "this ack carries no quota proof", which is exactly what
    // every pre-existing case observed before T-B-02 existed. Quota cases
    // override it with `quota: quotaAck(...)` below.
    quota: null,
    ...overrides,
  };
}

Deno.test("supported device with every app suspended is enforced", () => {
  const decision = decideEnforcement(input());
  assertEqual(decision.status, "enforced", "full suspension must be enforced");
  assertEqual(decision.lastError, null, "an enforced policy has no error");
  assertEqual(decision.advancePolicyVersion, true, "enforced advances the version");
  assertEqual(decision.desiredCount, 5, "desired count is carried through");
  assertEqual(decision.appliedCount, 5, "applied count is carried through");
  assertEqual(decision.failedCount, 0, "failed count is carried through");
});

Deno.test("non-Device-Owner reports unsupported even when the ack says succeeded", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 3,
      applied_count: 0,
      failed_count: 3,
      enforcement_supported: false,
      enforcement_mode: "none",
      failures: [{ package: "com.example.game", reason: "Device Owner required" }],
    },
  }));
  assertEqual(decision.status, "unsupported", "supported=false is unsupported");
  assertEqual(decision.lastError, "device_owner_required", "short honest reason");
  assertEqual(decision.advancePolicyVersion, true, "unsupported advances the version");
  assertEqual(decision.appliedCount, 0, "nothing was applied");
  assertEqual(decision.desiredCount, 3, "the target set is still reported");
});

Deno.test("unsupported wins even if stale packages remain suspended", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 4,
      applied_count: 2,
      failed_count: 2,
      enforcement_supported: false,
    },
  }));
  assertEqual(decision.status, "unsupported", "capability, not counts, decides");
});

Deno.test("a partial failure is failed and reports suspended N of M", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 5,
      applied_count: 2,
      failed_count: 3,
      enforcement_supported: true,
      failures: [{ package: "com.example.game", reason: "not confirmed" }],
    },
  }));
  assertEqual(decision.status, "failed", "missing apps must not be enforced");
  assertEqual(decision.lastError, "suspended 2 of 5", "truthful short message");
  assertEqual(decision.advancePolicyVersion, false, "failed never advances the version");
});

Deno.test("applied<desired is failed even if failed_count lies", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 4,
      applied_count: 1,
      failed_count: 0,
      enforcement_supported: true,
    },
  }));
  assertEqual(decision.status, "failed", "counts are cross-checked");
  assertEqual(decision.lastError, "suspended 1 of 4", "message follows the counts");
});

Deno.test("zero desired targets for an app policy stays pending, not enforced", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 0,
      applied_count: 0,
      failed_count: 0,
      enforcement_supported: true,
    },
    targetsApps: true,
  }));
  assertEqual(decision.status, "pending", "zero blocked apps is not enforcement");
  assertEqual(decision.lastError, "no_apps_suspended", "reason names the real state");
  assertEqual(decision.advancePolicyVersion, false, "pending does not advance");
});

Deno.test("a policy without app targets may be enforced with zero desired", () => {
  const decision = decideEnforcement(input({
    result: {
      desired_count: 0,
      applied_count: 0,
      failed_count: 0,
      enforcement_supported: true,
    },
    targetsApps: false,
  }));
  assertEqual(decision.status, "enforced", "nothing to suspend is still applied");
  assertEqual(decision.advancePolicyVersion, true, "enforced advances");
});

Deno.test("missing result fields stay pending instead of guessing", () => {
  const noResult = decideEnforcement(input({ result: null }));
  assertEqual(noResult.status, "pending", "no result cannot be enforced");
  assertEqual(noResult.lastError, "enforcement_counts_missing", "reason is explicit");
  assertEqual(noResult.desiredCount, null, "unknown count stays null");
  assertEqual(noResult.advancePolicyVersion, false, "pending does not advance");

  const partial = decideEnforcement(input({
    result: {
      desired_count: 5,
      applied_count: 5,
      enforcement_supported: true,
    },
  }));
  assertEqual(partial.status, "pending", "a missing failed_count is not proof");

  const noSupportFlag = decideEnforcement(input({
    result: { desired_count: 2, applied_count: 2, failed_count: 0 },
  }));
  assertEqual(noSupportFlag.status, "pending", "absent supported flag is not proof");
});

Deno.test("malformed counts are treated as missing", () => {
  for (const bad of [-1, 1.5, "3", null, Number.NaN]) {
    const decision = decideEnforcement(input({
      result: {
        desired_count: bad,
        applied_count: 0,
        failed_count: 0,
        enforcement_supported: true,
      },
    }));
    assertEqual(decision.status, "pending", `count ${String(bad)} must not enforce`);
    assertEqual(decision.advancePolicyVersion, false, "malformed counts do not advance");
  }
});

Deno.test("an expired command leaves the policy pending", () => {
  const decision = decideEnforcement(input({
    result: null,
    ackStatus: "expired",
  }));
  assertEqual(decision.status, "pending", "expired is not enforced");
  assertEqual(decision.lastError, "command_expired", "reason is explicit");
});

Deno.test("policyTargetsApps detects every blocking shape", () => {
  assertEqual(policyTargetsApps(null), false, "no policy targets nothing");
  assertEqual(
    policyTargetsApps({ blocked_packages: ["com.example.game"] }),
    true,
    "blocked packages target apps",
  );
  assertEqual(
    policyTargetsApps({
      app_rules: [{ package_name: "com.example.game", blocked: true }],
    }),
    true,
    "a blocked rule targets apps",
  );
  assertEqual(
    policyTargetsApps({
      app_rules: [{ package_name: "com.example.game", blocked: false }],
    }),
    false,
    "an unblocked rule does not target apps",
  );
  assertEqual(
    policyTargetsApps({ block_all_except_allowed: true }),
    true,
    "block-all targets apps",
  );
  assertEqual(policyTargetsApps({}), false, "an empty policy targets nothing");
});

// ---------------------------------------------------------------------------
// T-B-01: enforcement-status truthfulness for time-based policies.
//
// The ack counters describe package suspension only. A policy whose whole
// enforcement intent is a daily limit or a bedtime window therefore has no
// evidence behind an `enforced` verdict, and devices.policy_version must not
// move for it either. DEC-12 D1-B states the rule directly: "Limit must not be
// reported as `enforced` unless physical enforcement is verified."
// ---------------------------------------------------------------------------

/** The zero-suspension ack a limits-only policy produces on a real device. */
function zeroTargetAck(): Record<string, unknown> {
  return {
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    enforcement_supported: true,
    enforcement_mode: "device_owner",
    failures: [],
  };
}

Deno.test("a daily-limit-only policy is not enforced and does not advance the version", () => {
  // The exact production shape policy.ts normalizes for
  // `daily_screen_time_limit_minutes: 90` with no app rules at all.
  const policy = {
    blocked_packages: [],
    app_rules: [],
    daily_screen_time_limit_minutes: 90,
    bedtime_start_minutes: null,
    bedtime_end_minutes: null,
  };
  const decision = decideEnforcement(input({
    result: zeroTargetAck(),
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(policyTargetsApps(policy), false, "a limit is not an app target");
  assertEqual(
    decision.status,
    "pending",
    "an unobservable limit cannot be enforced",
  );
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "the reason names the real gap",
  );
  assertEqual(
    decision.advancePolicyVersion,
    false,
    "no devices.policy_version advancement is implied",
  );
  assertEqual(decision.desiredCount, 0, "the honest zero counts are still carried");
  assertEqual(decision.appliedCount, 0, "nothing was applied");
});

Deno.test("a bedtime-only policy is not enforced and does not advance the version", () => {
  const policy = {
    blocked_packages: [],
    app_rules: [],
    daily_screen_time_limit_minutes: null,
    bedtime_start_minutes: 1260,
    bedtime_end_minutes: 420,
  };
  const decision = decideEnforcement(input({
    result: zeroTargetAck(),
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(
    policyDeclaresTimeLimits(policy),
    true,
    "a bedtime window is a configured time limit",
  );
  assertEqual(decision.status, "pending", "bedtime alone is not proof");
  assertEqual(
    decision.advancePolicyVersion,
    false,
    "bedtime alone must not move the version",
  );
});

Deno.test("a daily limit plus a bedtime with no app targets stays pending", () => {
  const policy = {
    daily_screen_time_limit_minutes: 120,
    bedtime_start_minutes: 1320,
    bedtime_end_minutes: 360,
  };
  const decision = decideEnforcement(input({
    result: zeroTargetAck(),
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(decision.status, "pending", "two limits are still zero apps");
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "the same honest reason applies",
  );
  assertEqual(
    decision.advancePolicyVersion,
    false,
    "a combined limits policy still does not advance",
  );
});

Deno.test("a policy with app rules and limits keeps its app-targeting verdict", () => {
  const policy = {
    blocked_packages: ["com.example.game"],
    daily_screen_time_limit_minutes: 90,
  };
  assertEqual(
    policyTargetsApps(policy),
    true,
    "the app rule still classifies as an app target",
  );
  assertEqual(
    policyDeclaresTimeLimits(policy),
    true,
    "the limit is still configured alongside it",
  );

  // Real suspensions on an app-targeting policy are still proven enforced.
  const enforced = decideEnforcement(input({
    targetsApps: true,
    timeLimitsConfigured: true,
  }));
  assertEqual(enforced.status, "enforced", "5 of 5 suspended is still enforced");
  assertEqual(enforced.lastError, null, "an enforced mixed policy has no error");
  assertEqual(enforced.advancePolicyVersion, true, "and it still advances");

  // With zero resolved targets the pre-existing app rule wins, unchanged.
  const noTargets = decideEnforcement(input({
    result: zeroTargetAck(),
    targetsApps: true,
    timeLimitsConfigured: true,
  }));
  assertEqual(
    noTargets.lastError,
    "no_apps_suspended",
    "the app-targeting branch keeps its own reason",
  );

  // A partial failure on a mixed policy is still failed, not re-labelled.
  const failed = decideEnforcement(input({
    result: {
      desired_count: 3,
      applied_count: 1,
      failed_count: 2,
      enforcement_supported: true,
    },
    targetsApps: true,
    timeLimitsConfigured: true,
  }));
  assertEqual(failed.status, "failed", "mixed policies keep count verdicts");
  assertEqual(failed.lastError, "suspended 1 of 3", "with the same message");
});

Deno.test("an empty non-targeting policy is still applied, not re-labelled", () => {
  const policy = { blocked_packages: [], app_rules: [] };
  assertEqual(
    policyDeclaresTimeLimits(policy),
    false,
    "a policy with no limits configures nothing",
  );
  const decision = decideEnforcement(input({
    result: zeroTargetAck(),
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(
    decision.status,
    "enforced",
    "blocking nothing with no limits is truthfully applied",
  );
  assertEqual(decision.lastError, null, "and it carries no invented error");
  assertEqual(decision.advancePolicyVersion, true, "the version still advances");
});

Deno.test("a limits policy on an unsupported device stays unsupported", () => {
  // Capability outranks the new rule: a Standard Mode device cannot suspend
  // packages at all, and DEC-12 D1-B makes hard quota enforcement Managed-only.
  const decision = decideEnforcement(input({
    result: {
      desired_count: 0,
      applied_count: 0,
      failed_count: 0,
      enforcement_supported: false,
      enforcement_mode: "none",
    },
    targetsApps: false,
    timeLimitsConfigured: true,
  }));
  assertEqual(decision.status, "unsupported", "capability is decided first");
  assertEqual(decision.lastError, "device_owner_required", "unchanged reason");
});

Deno.test("policyDeclaresTimeLimits reads the normalized policy shape", () => {
  assertEqual(policyDeclaresTimeLimits(null), false, "no policy configures nothing");
  assertEqual(policyDeclaresTimeLimits(undefined), false, "undefined is not a policy");
  assertEqual(policyDeclaresTimeLimits([]), false, "an array is not a policy");
  assertEqual(policyDeclaresTimeLimits({}), false, "an empty policy has no limits");
  assertEqual(
    policyDeclaresTimeLimits({ daily_screen_time_limit_minutes: 90 }),
    true,
    "a daily limit is configured",
  );
  assertEqual(
    policyDeclaresTimeLimits({ bedtime_start_minutes: 1260, bedtime_end_minutes: 420 }),
    true,
    "a bedtime window is configured",
  );
  assertEqual(
    policyDeclaresTimeLimits({ bedtime_start_minutes: 0, bedtime_end_minutes: 0 }),
    true,
    "minute zero is a real value, not an absence",
  );
  assertEqual(
    policyDeclaresTimeLimits({ daily_screen_time_limit_minutes: 0 }),
    true,
    "a zero limit is still a configured field",
  );
  assertEqual(
    policyDeclaresTimeLimits({
      daily_screen_time_limit_minutes: null,
      bedtime_start_minutes: null,
      bedtime_end_minutes: null,
    }),
    false,
    "explicit nulls are how policy.ts stores an unconfigured limit",
  );
});

// ---------------------------------------------------------------------------
// T-B-02: daily screen-time quota acknowledgement contract.
//
// The device now answers an `apply_policy` with a nested `result.quota` block
// (owner-approved extension; DEC-12 sections 4.1, 4.2 and 5). The block is the
// first evidence the backend has ever had that a *limit* — not a package — is
// enforced, so it is validated before use and every verdict below either names
// the proof or refuses it. `enforcement_status` is still restricted to the
// hosted enum in 20260101000000_core.sql:185-186, so `partially_enforced` (a
// DEC-12 *Proposed* value) is never emitted.
// ---------------------------------------------------------------------------

/** The quota block of a Managed device that has just suspended its apps. */
function quotaAck(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    configured: true,
    usage_available: true,
    usage_minutes: 95,
    limit_minutes: 90,
    day_bucket: "2026-11-29",
    limit_reached: true,
    action: "suspended",
    desired_count: 3,
    applied_count: 3,
    failed_count: 0,
    enforcement_supported: true,
    enforcement_mode: "device_owner",
    reason: null,
    ...overrides,
  };
}

/** A Managed ack for a limits-only policy; `quota === null` is an old device. */
function managedAck(quota: Record<string, unknown> | null): Record<string, unknown> {
  return quota === null ? zeroTargetAck() : { ...zeroTargetAck(), quota };
}

/** The same ack from a Standard Mode device: advisory, never suspending. */
function standardAck(quota: Record<string, unknown>): Record<string, unknown> {
  return {
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    enforcement_supported: false,
    enforcement_mode: "none",
    failures: [],
    quota,
  };
}

/** A Managed ack with every app suspended: the pre-T-B-02 proven shape. */
function appAck(): Record<string, unknown> {
  return {
    desired_count: 5,
    applied_count: 5,
    failed_count: 0,
    enforcement_supported: true,
    enforcement_mode: "device_owner",
    failures: [],
  };
}

/**
 * Builds the input the way `handler.ts` does: the raw ack goes through
 * `normalizeQuotaAck`, so no test can smuggle an unvalidated quota block into
 * the decision.
 */
function quotaCase(
  ack: Record<string, unknown>,
  overrides: Partial<EnforcementInput> = {},
): EnforcementInput {
  return input({
    result: ack,
    targetsApps: false,
    timeLimitsConfigured: true,
    quota: normalizeQuotaAck(ack),
    ...overrides,
  });
}

/** A daily-limit-only policy, i.e. the shape `policy.ts` normalizes. */
function limitPolicy(): Record<string, unknown> {
  return {
    blocked_packages: [],
    app_rules: [],
    daily_screen_time_limit_minutes: 90,
    bedtime_start_minutes: null,
    bedtime_end_minutes: null,
  };
}

Deno.test("normalizeQuotaAck accepts the approved quota shape verbatim", () => {
  const parsed: QuotaAck | null = normalizeQuotaAck({ quota: quotaAck() });
  assert(parsed !== null, "the approved device shape must parse");
  assertEqual(parsed.configured, true, "configured is carried through");
  assertEqual(parsed.usage_available, true, "usage_available is carried");
  assertEqual(parsed.usage_minutes, 95, "usage_minutes is carried");
  assertEqual(parsed.limit_minutes, 90, "limit_minutes is carried");
  assertEqual(parsed.day_bucket, "2026-11-29", "day_bucket is carried");
  assertEqual(parsed.limit_reached, true, "limit_reached is carried");
  assertEqual(parsed.action, "suspended", "action is carried");
  assertEqual(parsed.desired_count, 3, "desired_count is carried");
  assertEqual(parsed.applied_count, 3, "applied_count is carried");
  assertEqual(parsed.failed_count, 0, "failed_count is carried");
  assertEqual(parsed.enforcement_supported, true, "supported is carried");
  assertEqual(parsed.enforcement_mode, "device_owner", "mode is carried");
  assertEqual(parsed.reason, null, "an absent reason stays null");
  assertEqual(normalizeQuotaAck(null), null, "no ack is no quota");
  assertEqual(normalizeQuotaAck({}), null, "no quota key is no quota");
});

Deno.test("a valid quota-enforcement ack is enforced and advances the version", () => {
  const policy = limitPolicy();
  const ack = managedAck(quotaAck());
  const decision = decideEnforcement(quotaCase(ack, {
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(
    policyDeclaresTimeLimits(policy),
    true,
    "the policy still configures the limit the ack proves",
  );
  assertEqual(decision.status, "enforced", "a confirmed suspension is enforced");
  assertEqual(decision.lastError, null, "an enforced quota carries no error");
  assertEqual(decision.advancePolicyVersion, true, "proof advances the version");
  assertEqual(decision.desiredCount, 3, "the quota counts are the reported ones");
  assertEqual(decision.appliedCount, 3, "applied is carried from the quota block");
  assertEqual(decision.failedCount, 0, "failed is carried from the quota block");
  assertEqual(decision.enforcementSupported, true, "managed quota is supported");
});

Deno.test("state 5: a managed suspension confirmed at the limit is enforced", () => {
  const decision = decideEnforcement(quotaCase(managedAck(quotaAck())));
  assertEqual(decision.status, "enforced", "DEC-12 4.2: verified by the OS");
  assertEqual(decision.lastError, null, "nothing to qualify");
  assertEqual(decision.advancePolicyVersion, true, "and the version advances");
});

Deno.test("state 5 needs the whole proof: any weaker ack is not enforced", () => {
  // desired_count 0: nothing was actually suspended.
  const zero = decideEnforcement(quotaCase(managedAck(
    quotaAck({ desired_count: 0, applied_count: 0 }),
  )));
  assertEqual(zero.status, "pending", "a zero target set proves nothing");
  // A device that is not Device Owner cannot have suspended anything.
  const standard = decideEnforcement(quotaCase(
    standardAck(quotaAck({ enforcement_supported: false, enforcement_mode: "none" })),
  ));
  assertEqual(standard.status, "pending", "advisory claims are not suspension");
  // failed_count > 0 contradicts a completed suspension.
  const dirty = decideEnforcement(quotaCase(
    managedAck(quotaAck({ failed_count: 1 })),
  ));
  assertEqual(dirty.status, "pending", "a reported failure is not proof");
  for (const d of [zero, standard, dirty]) {
    assertEqual(d.advancePolicyVersion, false, "no proof, no version advance");
  }
});

Deno.test("a quota block missing required fields is not proof", () => {
  for (
    const key of [
      "configured",
      "usage_available",
      "limit_reached",
      "action",
      "enforcement_supported",
      "enforcement_mode",
    ]
  ) {
    const ack = quotaAck();
    delete ack[key];
    assertEqual(
      normalizeQuotaAck({ quota: ack }),
      null,
      `a quota block without ${key} must be rejected`,
    );
  }

  const policy = limitPolicy();
  const ack = managedAck({ action: "suspended", desired_count: 3 });
  const decision = decideEnforcement(quotaCase(ack, {
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  }));
  assertEqual(decision.status, "pending", "a rejected block cannot enforce");
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "and the device is read as quota-unaware",
  );
  assertEqual(decision.advancePolicyVersion, false, "no advance without proof");
});

Deno.test("invalid quota action and flag values are rejected, never guessed", () => {
  for (const bad of ["", "SUSPENDED", "partially_enforced", "enforced", 3, null]) {
    assertEqual(
      normalizeQuotaAck({ quota: quotaAck({ action: bad }) }),
      null,
      `action ${String(bad)} is outside the vocabulary`,
    );
  }
  for (const bad of ["true", 1, 0, {}, null, undefined]) {
    assertEqual(
      normalizeQuotaAck({ quota: quotaAck({ configured: bad }) }),
      null,
      `configured ${String(bad)} is not a boolean`,
    );
    assertEqual(
      normalizeQuotaAck({ quota: quotaAck({ usage_available: bad }) }),
      null,
      `usage_available ${String(bad)} is not a boolean`,
    );
    assertEqual(
      normalizeQuotaAck({ quota: quotaAck({ limit_reached: bad }) }),
      null,
      `limit_reached ${String(bad)} is not a boolean`,
    );
    assertEqual(
      normalizeQuotaAck({ quota: quotaAck({ enforcement_supported: bad }) }),
      null,
      `enforcement_supported ${String(bad)} is not a boolean`,
    );
  }
  assertEqual(
    normalizeQuotaAck({ quota: quotaAck({ enforcement_mode: 7 }) }),
    null,
    "enforcement_mode must be a string",
  );
  assertEqual(
    normalizeQuotaAck({ quota: "device_owner" }),
    null,
    "a quota block must be an object",
  );
  assertEqual(
    normalizeQuotaAck({ quota: [quotaAck()] }),
    null,
    "an array is not a quota block",
  );
});

Deno.test("an old-device ack with no quota object keeps the T-B-01 verdict", () => {
  const decision = decideEnforcement(quotaCase(managedAck(null)));
  assertEqual(
    decision.status,
    "pending",
    "an ack without quota is still not proof of a limit",
  );
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "the exact T-B-01 reason is preserved",
  );
  assertEqual(decision.advancePolicyVersion, false, "no advance");
  // Malformed instead of absent must degrade the same way: an old device must
  // not gain the ability to claim quota support by sending a half block.
  assertEqual(normalizeQuotaAck({}), null, "an ack with no quota key is none");
  assertEqual(
    normalizeQuotaAck({ quota: undefined }),
    null,
    "an explicitly undefined quota is none",
  );
  for (const quota of ["yes", 42, true, []]) {
    const ack = { ...zeroTargetAck(), quota };
    assertEqual(
      normalizeQuotaAck(ack),
      null,
      `quota ${String(quota)} must be rejected outright`,
    );
    const d = decideEnforcement(quotaCase(ack));
    assertEqual(d.status, "pending", `quota ${String(quota)} is not proof`);
    assertEqual(
      d.lastError,
      "limits_enforcement_unverified",
      `quota ${String(quota)} degrades to the old-device verdict`,
    );
    assertEqual(d.advancePolicyVersion, false, "and never advances");
  }

  // A mixed policy from the same old device keeps its T-B-01 app verdict: with
  // no quota block there is nothing for the quota reasoning to say.
  const mixed = decideEnforcement(quotaCase(appAck(), { targetsApps: true }));
  assertEqual(mixed.status, "enforced", "5 of 5 suspended still proves the apps");
  assertEqual(mixed.lastError, null, "and the ack invents no quota error");
  assertEqual(mixed.advancePolicyVersion, true, "with the pre-T-B-02 advance");
});

Deno.test("no quota configured: the pending reason names the missing install", () => {
  const ack = managedAck(quotaAck({
    configured: false,
    usage_available: false,
    usage_minutes: null,
    limit_minutes: null,
    day_bucket: null,
    limit_reached: false,
    action: "none",
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    reason: "quota_not_configured",
  }));
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(decision.status, "pending", "the limit was never installed");
  assertEqual(decision.lastError, "quota_not_configured", "honest reason");
  assertEqual(decision.advancePolicyVersion, false, "no advance");
});

Deno.test("with no limit configured the quota block cannot change the verdict", () => {
  // State 1, the byte-compatibility pin: a policy that configures no time
  // control answers exactly as it did before T-B-02, even when the device
  // volunteers a quota block that reports a failure.
  const ack = {
    ...zeroTargetAck(),
    quota: quotaAck({
      action: "suspend_failed",
      applied_count: 0,
      failed_count: 3,
      reason: "quota_suspend_failed",
    }),
  };
  const decision = decideEnforcement(quotaCase(ack, {
    targetsApps: policyTargetsApps({ blocked_packages: [], app_rules: [] }),
    timeLimitsConfigured: policyDeclaresTimeLimits({
      daily_screen_time_limit_minutes: null,
      bedtime_start_minutes: null,
      bedtime_end_minutes: null,
    }),
  }));
  assertEqual(
    decision.status,
    "enforced",
    "blocking nothing with no limits is still truthfully applied",
  );
  assertEqual(decision.lastError, null, "and it carries no invented error");
  assertEqual(decision.advancePolicyVersion, true, "the version still advances");
});

Deno.test("state 2: quota usage unavailable is pending without a version advance", () => {
  const ack = managedAck(quotaAck({
    usage_available: false,
    usage_minutes: null,
    limit_reached: false,
    action: "none",
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    reason: "quota_usage_unavailable",
  }));
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(decision.status, "pending", "no measurement is not proof");
  assertEqual(decision.lastError, "quota_usage_unavailable", "honest reason");
  assertEqual(decision.advancePolicyVersion, false, "the version stays put");

  // "Available" with no number is the same absence of measurement.
  const noNumber = decideEnforcement(
    quotaCase(managedAck(quotaAck({ usage_minutes: null, limit_reached: false }))),
  );
  assertEqual(noNumber.status, "pending", "an unavailable figure is unmeasured");
  assertEqual(
    noNumber.lastError,
    "quota_usage_unavailable",
    "with the same reason",
  );
});

Deno.test("state 3: usage below the limit is enforced on a managed device", () => {
  const ack = managedAck(quotaAck({
    usage_minutes: 45,
    limit_reached: false,
    action: "none",
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    reason: "quota_below_limit",
  }));
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(
    decision.status,
    "enforced",
    "the monitor is provably active on a capable device",
  );
  assertEqual(
    decision.lastError,
    "quota_below_limit",
    "enforced is qualified by the real reason",
  );
  assertEqual(decision.advancePolicyVersion, true, "so the version advances");
});

Deno.test("state 3: usage below the limit is advisory-only on standard mode", () => {
  const ack = standardAck(quotaAck({
    usage_minutes: 45,
    limit_reached: false,
    action: "advisory",
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    enforcement_supported: false,
    enforcement_mode: "none",
    reason: "quota_advisory_only",
  }));
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(decision.status, "unsupported", "DEC-12 4.1: no suspension at all");
  assertEqual(
    decision.lastError,
    "quota_advisory_only",
    "the quota reason wins over the generic capability note",
  );
  assertEqual(
    decision.advancePolicyVersion,
    true,
    "unsupported advances to prevent a retry loop",
  );
});

Deno.test("state 4: limit reached with no confirmed suspension stays pending", () => {
  const cases: Array<[string, Record<string, unknown>]> = [
    ["explicit confirmation_missing reason", quotaAck({
      action: "none",
      desired_count: 0,
      applied_count: 0,
      failed_count: 0,
      reason: "quota_confirmation_missing",
    })],
    ["no action taken at the limit", quotaAck({
      action: "none",
      desired_count: 0,
      applied_count: 0,
      failed_count: 0,
    })],
    ["absent counts", quotaAck({
      desired_count: null,
      applied_count: null,
      failed_count: null,
    })],
    ["advisory on a capable device", quotaAck({ action: "advisory" })],
    ["applied short of desired", quotaAck({ applied_count: 2, failed_count: 1 })],
  ];
  for (const [label, quota] of cases) {
    const decision = decideEnforcement(quotaCase(managedAck(quota)));
    assertEqual(decision.status, "pending", `${label}: receipt is not proof`);
    assertEqual(
      decision.lastError,
      "quota_confirmation_missing",
      `${label}: the reason names the gap`,
    );
    assertEqual(decision.advancePolicyVersion, false, `${label}: no advance`);
  }
});

Deno.test("state 6: a standard advisory at the limit is unsupported", () => {
  const ack = standardAck(quotaAck({
    action: "advisory",
    desired_count: 0,
    applied_count: 0,
    failed_count: 0,
    enforcement_supported: false,
    enforcement_mode: "none",
    reason: "quota_advisory_only",
  }));
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(decision.status, "unsupported", "DEC-12 5: capability is absent");
  assertEqual(decision.lastError, "quota_advisory_only", "advisory is the truth");
  assertEqual(decision.advancePolicyVersion, true, "and it must not retry");
});

Deno.test("state 7: a managed quota suspension failure is failed", () => {
  const total = decideEnforcement(quotaCase(managedAck(quotaAck({
    action: "suspend_failed",
    applied_count: 0,
    failed_count: 3,
    reason: "quota_suspend_failed",
  }))));
  assertEqual(total.status, "failed", "a DPM call that failed is failed");
  assertEqual(total.lastError, "quota_suspend_failed", "total failure reason");
  assertEqual(total.advancePolicyVersion, false, "failed never advances");

  const partial = decideEnforcement(quotaCase(managedAck(quotaAck({
    action: "suspend_failed",
    applied_count: 2,
    failed_count: 1,
    reason: "quota_suspended 2 of 3",
  }))));
  assertEqual(partial.status, "failed", "a partial suspension is not enforced");
  assertEqual(
    partial.lastError,
    "quota_suspended 2 of 3",
    "the counts are reported truthfully",
  );
  assertEqual(partial.advancePolicyVersion, false, "no advance");

  // Absent counts cannot rescue a failure either: it stays failed, with the
  // total-failure reason rather than an invented "0 of null".
  const blind = decideEnforcement(quotaCase(managedAck(quotaAck({
    action: "suspend_failed",
    desired_count: null,
    applied_count: null,
    failed_count: null,
  }))));
  assertEqual(blind.status, "failed", "no counts still fails");
  assertEqual(blind.lastError, "quota_suspend_failed", "and says so plainly");
});

Deno.test("no quota verdict advances the policy version without proof", () => {
  // The devices.policy_version rule pinned for the whole quota vocabulary:
  // only an enforced or unsupported (DEC-12: advisory) verdict may move it.
  const nonProof: Array<Record<string, unknown>> = [
    quotaAck({ configured: false }),
    quotaAck({ usage_available: false, usage_minutes: null, limit_reached: false }),
    quotaAck({ reason: "quota_confirmation_missing" }),
    quotaAck({ action: "none", desired_count: 0, applied_count: 0, failed_count: 0 }),
    quotaAck({ action: "suspend_failed", applied_count: 0, failed_count: 3 }),
    quotaAck({ action: "suspend_failed", applied_count: 2, failed_count: 1 }),
    quotaAck({ action: "suspended", applied_count: 2 }),
    quotaAck({ desired_count: 0, applied_count: 0 }),
    // Rejected blocks: an unknown action, and a non-boolean flag.
    quotaAck({ action: "nonsense" }),
    quotaAck({ enforcement_supported: "yes" }),
  ];
  for (const quota of nonProof) {
    const decision = decideEnforcement(quotaCase(managedAck(quota)));
    assertEqual(
      decision.advancePolicyVersion,
      false,
      `action=${String(quota.action)} must never advance the version`,
    );
    assert(
      decision.status !== "enforced",
      `action=${String(quota.action)} must never claim enforcement`,
    );
  }
});

Deno.test("every quota verdict stays inside the hosted enforcement_status enum", () => {
  // 20260101000000_core.sql:185-186 CHECKs enforcement_status to exactly these
  // four values; `partially_enforced` is DEC-12 *Proposed* and unapproved.
  const hosted = ["pending", "enforced", "failed", "unsupported"];
  const payloads = [
    quotaAck(),
    quotaAck({ configured: false }),
    quotaAck({ usage_available: false, usage_minutes: null, limit_reached: false }),
    quotaAck({ limit_reached: false, usage_minutes: 10 }),
    quotaAck({ action: "advisory" }),
    quotaAck({ action: "none" }),
    quotaAck({ action: "suspend_failed" }),
    quotaAck({ action: "suspend_failed", applied_count: 1 }),
    quotaAck({ reason: "quota_confirmation_missing" }),
    quotaAck({ desired_count: null, applied_count: null, failed_count: null }),
  ];
  for (const quota of payloads) {
    for (const ack of [managedAck(quota), standardAck(quota)]) {
      for (const targetsApps of [false, true]) {
        const decision = decideEnforcement(quotaCase(ack, { targetsApps }));
        assert(
          hosted.includes(decision.status),
          `${quota.action}: ${decision.status} is outside the hosted enum`,
        );
        assert(
          decision.lastError === null ||
            (typeof decision.lastError === "string" &&
              decision.lastError.length <= 500),
          "last_error must always fit the device_policies CHECK",
        );
        assert(
          decision.advancePolicyVersion ===
            (decision.status === "enforced" ||
              decision.status === "unsupported"),
          "only enforced and unsupported may move devices.policy_version",
        );
      }
    }
  }
});

Deno.test("an expired command is never quota proof", () => {
  const decision = decideEnforcement(quotaCase(managedAck(quotaAck()), {
    ackStatus: "expired",
  }));
  assertEqual(decision.status, "pending", "a receipt that timed out proves none");
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "the quota block is simply not consulted",
  );
  assertEqual(decision.advancePolicyVersion, false, "no advance");
});

Deno.test("a mixed app and quota policy keeps its app verdict", () => {
  const policy = {
    blocked_packages: ["com.example.game"],
    daily_screen_time_limit_minutes: 90,
  };
  assertEqual(policyTargetsApps(policy), true, "the policy still targets apps");
  assertEqual(
    policyDeclaresTimeLimits(policy),
    true,
    "and still configures the limit",
  );
  const mixed = {
    targetsApps: policyTargetsApps(policy),
    timeLimitsConfigured: policyDeclaresTimeLimits(policy),
  };

  // Both halves proven: enforced, no qualification.
  const both = decideEnforcement(quotaCase(
    { ...appAck(), quota: quotaAck() },
    { ...mixed },
  ));
  assertEqual(both.status, "enforced", "5 of 5 apps plus a confirmed quota");
  assertEqual(both.lastError, null, "nothing to qualify");
  assertEqual(both.advancePolicyVersion, true, "and the version advances");

  // Apps proven, quota only advisory: the app verdict is preserved and the
  // quota state is reported through last_error rather than a fake status.
  const advisory = decideEnforcement(quotaCase(
    { ...appAck(), quota: quotaAck({ limit_reached: false, action: "none" }) },
    { ...mixed },
  ));
  assertEqual(advisory.status, "enforced", "the proven app half stays enforced");
  assertEqual(
    advisory.lastError,
    "quota_below_limit",
    "the quota half is described honestly",
  );

  // Apps failed: a quota success must never mask it.
  const appFailed = decideEnforcement(quotaCase(
    {
      desired_count: 3,
      applied_count: 1,
      failed_count: 2,
      enforcement_supported: true,
      quota: quotaAck(),
    },
    { ...mixed },
  ));
  assertEqual(appFailed.status, "failed", "quota proof cannot hide app failures");
  assertEqual(appFailed.lastError, "suspended 1 of 3", "with the app reason");
  assertEqual(appFailed.advancePolicyVersion, false, "and no advance");

  // Apps pending because nothing resolved: still pending, still its own reason.
  const appPending = decideEnforcement(quotaCase(
    { ...zeroTargetAck(), quota: quotaAck() },
    { ...mixed },
  ));
  assertEqual(appPending.status, "pending", "an unresolved app half holds back");
  assertEqual(
    appPending.lastError,
    "no_apps_suspended",
    "and keeps the app-targeting reason",
  );
  assertEqual(appPending.advancePolicyVersion, false, "no advance");
});

Deno.test("a quota suspension failure out-votes an enforced app half on a mixed policy", () => {
  // The deliberate truthfulness choice: `enforced` per DEC-12 5 means every
  // half is physically confirmed, and here the device says the quota
  // suspension failed. `failed` is the only honest value the hosted enum has.
  const ack = {
    desired_count: 5,
    applied_count: 5,
    failed_count: 0,
    enforcement_supported: true,
    enforcement_mode: "device_owner",
    quota: quotaAck({
      action: "suspend_failed",
      applied_count: 2,
      failed_count: 1,
      reason: "quota_suspended 2 of 3",
    }),
  };
  const decision = decideEnforcement(quotaCase(ack, {
    targetsApps: true,
    timeLimitsConfigured: true,
  }));
  assertEqual(decision.status, "failed", "the quota failure wins");
  assertEqual(
    decision.lastError,
    "quota_suspended 2 of 3",
    "and reports what actually happened",
  );
  assertEqual(decision.advancePolicyVersion, false, "failed never advances");
});

Deno.test("a quota verdict never echoes a device-supplied reason string", () => {
  // The reason token is an input, not a message: `last_error` stays bounded
  // and server-owned, so no device can write arbitrary text into
  // device_policies.last_error (CHECK char_length <= 500).
  const long = "x".repeat(4000);
  const ack = managedAck(quotaAck({ reason: long }));
  assertEqual(
    normalizeQuotaAck(ack)?.action,
    "suspended",
    "a free-form reason string still parses",
  );
  const decision = decideEnforcement(quotaCase(ack));
  assertEqual(decision.status, "enforced", "the proof is the counts, not text");
  assertEqual(decision.lastError, null, "and nothing is copied into last_error");

  const failed = decideEnforcement(
    quotaCase(managedAck(quotaAck({ action: "suspend_failed", reason: long }))),
  );
  assertEqual(failed.status, "failed", "a failure still fails");
  assertEqual(failed.lastError, "quota_suspend_failed", "with the server message");
});

Deno.test("malformed quota counts are never proof", () => {
  // Mirrors the pre-existing app-counter sweep: every non-count value must
  // degrade to an honest, non-advancing verdict.
  for (const field of ["desired_count", "applied_count", "failed_count"]) {
    for (const bad of [-1, 1.5, "3", null, Number.NaN]) {
      const quota = quotaAck({ [field]: bad, limit_reached: true });
      const ack = managedAck(quota);
      const decision = decideEnforcement(quotaCase(ack));
      if (bad === null) {
        // Absent counts parse, but cannot establish a completed suspension.
        assertEqual(
          decision.lastError,
          "quota_confirmation_missing",
          "absent counts read as unconfirmed",
        );
      } else {
        assertEqual(
          normalizeQuotaAck(ack),
          null,
          `${field}=${String(bad)} must reject the block`,
        );
        assertEqual(
          decision.lastError,
          "limits_enforcement_unverified",
          `${field}=${String(bad)} is not quota proof at all`,
        );
      }
      assertEqual(
        decision.status,
        "pending",
        `${field}=${String(bad)} must not enforce`,
      );
      assertEqual(
        decision.advancePolicyVersion,
        false,
        `${field}=${String(bad)} must not advance`,
      );
    }
  }
});

Deno.test("contradictory quota claims are rejected, not trusted", () => {
  // limit_reached cannot be true with no measurement.
  const reachedWithoutUsage = quotaAck({ usage_available: false, usage_minutes: null });
  assertEqual(
    normalizeQuotaAck({ quota: reachedWithoutUsage }),
    null,
    "limit_reached with usage_available=false is a contradiction",
  );
  const decision = decideEnforcement(quotaCase(managedAck(reachedWithoutUsage)));
  assertEqual(decision.status, "pending", "and it is not proof");
  assertEqual(
    decision.lastError,
    "limits_enforcement_unverified",
    "it is rejected outright, never read as quota_usage_unavailable",
  );
  assertEqual(decision.advancePolicyVersion, false, "no advance");

  // usage_minutes present while usage is unavailable.
  assertEqual(
    normalizeQuotaAck({
      quota: quotaAck({
        usage_available: false,
        limit_reached: false,
        action: "none",
      }),
    }),
    null,
    "a number cannot exist without a measurement",
  );

  // applied_count above desired_count.
  assertEqual(
    normalizeQuotaAck({ quota: quotaAck({ desired_count: 2, applied_count: 3 }) }),
    null,
    "more applied than desired is impossible",
  );

  // A non-string day_bucket or reason is a malformed field, not a free pass.
  assertEqual(
    normalizeQuotaAck({ quota: quotaAck({ day_bucket: 20261129 }) }),
    null,
    "day_bucket must be a string or null",
  );
  assertEqual(
    normalizeQuotaAck({ quota: quotaAck({ reason: { code: "x" } }) }),
    null,
    "reason must be a string or null",
  );
});

Deno.test("normalizeQuotaAck tolerates the nullable fields the contract allows", () => {
  // Absent nullable fields (counts included) parse as null rather than being
  // guessed at, so a partial block can only ever reach a pending verdict.
  const parsed: QuotaAck | null = normalizeQuotaAck({
    quota: {
      configured: true,
      usage_available: false,
      limit_reached: false,
      action: "none",
      enforcement_supported: true,
      enforcement_mode: "device_owner",
    },
  });
  assert(parsed !== null, "a block with only the required fields parses");
  assertEqual(parsed.usage_minutes, null, "usage_minutes defaults to absent");
  assertEqual(parsed.limit_minutes, null, "limit_minutes defaults to absent");
  assertEqual(parsed.day_bucket, null, "day_bucket defaults to absent");
  assertEqual(parsed.reason, null, "reason defaults to absent");
  assertEqual(parsed.desired_count, null, "desired_count defaults to absent");
  assertEqual(parsed.applied_count, null, "applied_count defaults to absent");
  assertEqual(parsed.failed_count, null, "failed_count defaults to absent");

  // The normalized block re-reads identically, so the round trip through the
  // handler's validator cannot invent a proof either.
  const decision = decideEnforcement(quotaCase({ ...zeroTargetAck(), quota: parsed }));
  assertEqual(decision.status, "pending", "no measurement is no proof");
  assertEqual(decision.lastError, "quota_usage_unavailable", "and says which");
  assertEqual(decision.advancePolicyVersion, false, "no advance");
});