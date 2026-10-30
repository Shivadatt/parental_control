// Pure mapping tests for apply_policy acknowledgements.
// Run with:
//   deno test supabase/functions/device-command
// No network, no Supabase client.
import {
  decideEnforcement,
  policyTargetsApps,
  type EnforcementInput,
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