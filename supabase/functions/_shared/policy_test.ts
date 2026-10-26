// Pure policy and command payload validation tests.
import { ApiError } from "./envelope.ts";
import {
  COMMAND_TYPES,
  type CommandType,
  validateCommandPayload,
  validatePolicyPayload,
} from "./policy.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`ASSERTION FAILED (${message}): expected ${e}, got ${a}`);
  }
}

function assertApiError(fn: () => unknown, label: string): void {
  try {
    fn();
  } catch (error) {
    if (error instanceof ApiError && error.code === "validation_error") return;
    throw error;
  }
  throw new Error(`ASSERTION FAILED (${label}): expected validation_error`);
}

const FULL_POLICY = {
  enforce_app_blocks: false,
  block_all_except_allowed: true,
  blocked_packages: ["com.example.blocked", "com.example.blocked"],
  allowed_packages: ["com.example.allowed"],
  app_rules: [
    {
      package_name: "com.example.rule",
      label: "  Rule Label  ",
      blocked: true,
      windows: [
        {
          days_of_week: [5, 1, 3],
          start_minutes: 1200,
          end_minutes: 420,
        },
      ],
    },
  ],
  daily_screen_time_limit_minutes: 90,
  bedtime_start_minutes: 1260,
  bedtime_end_minutes: 420,
};

Deno.test("valid Dart-style policy is normalised", () => {
  const policy = validatePolicyPayload(FULL_POLICY);
  assertEqual(policy.enforce_app_blocks, false, "enforce flag");
  assertEqual(policy.block_all_except_allowed, true, "block-all flag");
  assertEqual(
    policy.blocked_packages,
    ["com.example.blocked"],
    "blocked packages dedupe",
  );
  assertEqual(policy.allowed_packages, ["com.example.allowed"], "allowed packages");
  assertEqual(policy.daily_screen_time_limit_minutes, 90, "daily limit");
  assertEqual(policy.bedtime_start_minutes, 1260, "bedtime start");
  assertEqual(policy.bedtime_end_minutes, 420, "bedtime end");
  assertEqual(policy.app_rules.length, 1, "one rule");
  const rule = policy.app_rules[0];
  assertEqual(rule.label, "Rule Label", "label trimmed");
  assertEqual(rule.blocked, true, "rule blocked");
  assertEqual(rule.windows[0].days_of_week, [1, 3, 5], "weekdays sorted");
  assertEqual(rule.windows[0].start_minutes, 1200, "window start");
  assertEqual(rule.windows[0].end_minutes, 420, "overnight window kept");
});

Deno.test("empty policy gets safe defaults", () => {
  const policy = validatePolicyPayload({});
  assertEqual(policy, {
    enforce_app_blocks: true,
    block_all_except_allowed: false,
    blocked_packages: [],
    allowed_packages: [],
    app_rules: [],
    daily_screen_time_limit_minutes: null,
    bedtime_start_minutes: null,
    bedtime_end_minutes: null,
  }, "defaults");
  assertEqual(
    validatePolicyPayload({ app_rules: null }).app_rules,
    [],
    "null app_rules means empty",
  );
});

Deno.test("unknown keys are rejected at every level", () => {
  assertApiError(
    () => validatePolicyPayload({ ...FULL_POLICY, extra: true }),
    "unknown top-level key",
  );
  assertApiError(
    () =>
      validatePolicyPayload({
        app_rules: [{ package_name: "com.example.app", blocked: false, extra: 1 }],
      }),
    "unknown rule key",
  );
  assertApiError(
    () =>
      validatePolicyPayload({
        app_rules: [{
          package_name: "com.example.app",
          blocked: false,
          windows: [{ days_of_week: [1], start_minutes: 0, end_minutes: 10, extra: 1 }],
        }],
      }),
    "unknown window key",
  );
});

Deno.test("duplicate rules and weekdays are rejected", () => {
  assertApiError(
    () =>
      validatePolicyPayload({
        app_rules: [
          { package_name: "com.example.app", blocked: true },
          { package_name: "com.example.app", blocked: false },
        ],
      }),
    "duplicate package rule",
  );
  assertApiError(
    () =>
      validatePolicyPayload({
        app_rules: [{
          package_name: "com.example.app",
          blocked: true,
          windows: [{ days_of_week: [2, 2], start_minutes: 0, end_minutes: 10 }],
        }],
      }),
    "duplicate weekday",
  );
});

Deno.test("weekday and minute bounds are enforced", () => {
  for (const day of [0, 8, -1, 1.5]) {
    assertApiError(
      () =>
        validatePolicyPayload({
          app_rules: [{
            package_name: "com.example.app",
            blocked: true,
            windows: [{ days_of_week: [day], start_minutes: 0, end_minutes: 10 }],
          }],
        }),
      `weekday ${day}`,
    );
  }
  assertApiError(
    () =>
      validatePolicyPayload({
        app_rules: [{
          package_name: "com.example.app",
          blocked: true,
          windows: [{ days_of_week: [], start_minutes: 0, end_minutes: 10 }],
        }],
      }),
    "empty weekday list",
  );
  for (const minutes of [-1, 1440]) {
    assertApiError(
      () =>
        validatePolicyPayload({
          app_rules: [{
            package_name: "com.example.app",
            blocked: true,
            windows: [{
              days_of_week: [1],
              start_minutes: minutes,
              end_minutes: 10,
            }],
          }],
        }),
      `start minute ${minutes}`,
    );
  }
});

Deno.test("bedtime and daily limit pairing rules", () => {
  assertApiError(
    () => validatePolicyPayload({ bedtime_start_minutes: 1200 }),
    "start without end",
  );
  assertApiError(
    () => validatePolicyPayload({ bedtime_end_minutes: 420 }),
    "end without start",
  );
  assertEqual(
    validatePolicyPayload({ bedtime_start_minutes: 1200, bedtime_end_minutes: 420 })
      .bedtime_start_minutes,
    1200,
    "paired bedtime accepted",
  );
  for (const limit of [0, 1441, -5, 1.5]) {
    assertApiError(
      () => validatePolicyPayload({ daily_screen_time_limit_minutes: limit }),
      `daily limit ${limit}`,
    );
  }
  assertEqual(
    validatePolicyPayload({ daily_screen_time_limit_minutes: 1440 })
      .daily_screen_time_limit_minutes,
    1440,
    "daily limit max accepted",
  );
});

Deno.test("labels and lists are bounded", () => {
  const longLabel = "l".repeat(150);
  const policy = validatePolicyPayload({
    app_rules: [{ package_name: "com.example.app", label: longLabel, blocked: false }],
  });
  assertEqual(policy.app_rules[0].label.length, 100, "label truncated to 100");
  assertEqual(policy.app_rules[0].windows, [], "windows default to empty");

  const tooManyPackages = Array.from(
    { length: 201 },
    (_, index) => `com.example.p${index}`,
  );
  assertApiError(
    () => validatePolicyPayload({ blocked_packages: tooManyPackages }),
    "more than 200 packages",
  );
});

Deno.test("command payloads are sanitised per type", () => {
  assertEqual(COMMAND_TYPES.length, 6, "six command types");
  assert(COMMAND_TYPES.includes("apply_policy"), "apply_policy present");

  const applied = validateCommandPayload("apply_policy", { policy: FULL_POLICY });
  assert("policy" in applied, "apply_policy returns policy");
  assertApiError(
    () => validateCommandPayload("apply_policy", { policy: {}, extra: true }),
    "apply_policy unknown key",
  );
  assertApiError(
    () => validateCommandPayload("apply_policy", {}),
    "apply_policy missing policy",
  );

  assertEqual(
    validateCommandPayload("sync_policy", { version: 3 }),
    { version: 3 },
    "sync_policy version",
  );
  assertEqual(
    validateCommandPayload("sync_policy", {}),
    {},
    "sync_policy version optional",
  );
  assertApiError(
    () => validateCommandPayload("sync_policy", { version: -1 }),
    "sync_policy negative version",
  );
  assertApiError(
    () => validateCommandPayload("sync_policy", { version: 1, extra: true }),
    "sync_policy unknown key",
  );

  assertEqual(
    validateCommandPayload("request_usage", { days: 30 }),
    { days: 30 },
    "request_usage days",
  );
  assertApiError(
    () => validateCommandPayload("request_usage", { days: 0 }),
    "request_usage min",
  );
  assertApiError(
    () => validateCommandPayload("request_location", { high_accuracy: "yes" }),
    "request_location boolean",
  );
  assertEqual(
    validateCommandPayload("request_location", { high_accuracy: true }),
    { high_accuracy: true },
    "request_location accepted",
  );

  const sessionId = "11111111-1111-4111-8111-111111111111";
  assertEqual(
    validateCommandPayload("end_session", { session_id: sessionId, reason: "bye" }),
    { session_id: sessionId, reason: "bye" },
    "end_session payload",
  );
  assertApiError(
    () => validateCommandPayload("end_session", { reason: "x".repeat(201) }),
    "end_session reason too long",
  );
  assertApiError(
    () => validateCommandPayload("end_session", { session_id: "not-a-uuid" }),
    "end_session bad uuid",
  );

  assertEqual(
    validateCommandPayload("custom", { arbitrary: { nested: true } }),
    { arbitrary: { nested: true } },
    "custom payload preserved",
  );
  assertApiError(
    () => validateCommandPayload("bogus" as CommandType, {}),
    "unsupported command type",
  );
});
