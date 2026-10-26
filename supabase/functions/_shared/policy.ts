// Strict policy / command payload validation. Pure and unit-tested.
import { ApiError } from "./envelope.ts";
import {
  isRecord,
  readArray,
  readBoolean,
  readInteger,
  readOptionalInteger,
  readPackageName,
  readUuid,
  requireRecord,
} from "./validation.ts";

export interface NormalizedWindow {
  days_of_week: number[];
  start_minutes: number;
  end_minutes: number;
}

export interface NormalizedAppRule {
  package_name: string;
  label: string;
  blocked: boolean;
  windows: NormalizedWindow[];
}

export interface NormalizedPolicy {
  enforce_app_blocks: boolean;
  block_all_except_allowed: boolean;
  blocked_packages: string[];
  allowed_packages: string[];
  app_rules: NormalizedAppRule[];
  daily_screen_time_limit_minutes: number | null;
  bedtime_start_minutes: number | null;
  bedtime_end_minutes: number | null;
}

export const COMMAND_TYPES = [
  "apply_policy",
  "sync_policy",
  "request_usage",
  "request_location",
  "end_session",
  "custom",
] as const;

export type CommandType = (typeof COMMAND_TYPES)[number];

const POLICY_KEYS = new Set([
  "enforce_app_blocks",
  "block_all_except_allowed",
  "blocked_packages",
  "allowed_packages",
  "app_rules",
  "daily_screen_time_limit_minutes",
  "bedtime_start_minutes",
  "bedtime_end_minutes",
]);

const RULE_KEYS = new Set(["package_name", "label", "blocked", "windows"]);
const WINDOW_KEYS = new Set(["days_of_week", "start_minutes", "end_minutes"]);
const MAX_RULES = 200;
const MAX_PACKAGES = 200;
const MAX_WINDOWS_PER_RULE = 100;
const MAX_POLICY_BYTES = 256 * 1024;

function rejectUnknownKeys(
  value: Record<string, unknown>,
  allowed: Set<string>,
  field: string,
): void {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new ApiError("validation_error", `${field}.${key} is not allowed.`, 400);
    }
  }
}

function readPackageList(value: unknown, field: string): string[] {
  if (value === undefined || value === null) return [];
  const list = readArray(value, field, MAX_PACKAGES);
  const seen = new Set<string>();
  const result: string[] = [];
  for (let i = 0; i < list.length; i += 1) {
    const name = readPackageName(list[i], `${field}[${i}]`);
    if (!seen.has(name)) {
      seen.add(name);
      result.push(name);
    }
  }
  return result;
}

function readWindow(value: unknown, field: string): NormalizedWindow {
  const window = requireRecord(value, field);
  rejectUnknownKeys(window, WINDOW_KEYS, field);
  const daysRaw = readArray(window.days_of_week, `${field}.days_of_week`, 7);
  if (daysRaw.length === 0) {
    throw new ApiError(
      "validation_error",
      `${field}.days_of_week must contain at least one weekday.`,
      400,
    );
  }
  const days: number[] = [];
  const seenDays = new Set<number>();
  for (let i = 0; i < daysRaw.length; i += 1) {
    const day = readInteger(daysRaw[i], `${field}.days_of_week[${i}]`, 1, 7);
    if (seenDays.has(day)) {
      throw new ApiError(
        "validation_error",
        `${field}.days_of_week contains a duplicate day.`,
        400,
      );
    }
    seenDays.add(day);
    days.push(day);
  }
  days.sort((a, b) => a - b);
  return {
    days_of_week: days,
    start_minutes: readInteger(window.start_minutes, `${field}.start_minutes`, 0, 1439),
    end_minutes: readInteger(window.end_minutes, `${field}.end_minutes`, 0, 1439),
  };
}

function readAppRule(value: unknown, field: string): NormalizedAppRule {
  const rule = requireRecord(value, field);
  rejectUnknownKeys(rule, RULE_KEYS, field);
  const packageName = readPackageName(rule.package_name, `${field}.package_name`);
  const labelRaw = rule.label;
  let label = packageName;
  if (labelRaw !== undefined && labelRaw !== null) {
    if (typeof labelRaw !== "string") {
      throw new ApiError("validation_error", `${field}.label must be a string.`, 400);
    }
    const trimmed = labelRaw.trim().slice(0, 100);
    if (trimmed.length > 0) label = trimmed;
  }
  const windowsRaw = rule.windows === undefined || rule.windows === null
    ? []
    : readArray(rule.windows, `${field}.windows`, MAX_WINDOWS_PER_RULE);
  const windows = windowsRaw.map((entry, index) =>
    readWindow(entry, `${field}.windows[${index}]`)
  );
  return {
    package_name: packageName,
    label,
    blocked: readBoolean(rule.blocked, `${field}.blocked`),
    windows,
  };
}

/**
 * Validates and normalises a policy payload emitted by
 * `PolicyPayload.toJson()` in the Flutter client.
 */
export function validatePolicyPayload(raw: unknown): NormalizedPolicy {
  const policy = requireRecord(raw, "policy");
  rejectUnknownKeys(policy, POLICY_KEYS, "policy");

  const blockedPackages = readPackageList(
    policy.blocked_packages,
    "policy.blocked_packages",
  );
  const allowedPackages = readPackageList(
    policy.allowed_packages,
    "policy.allowed_packages",
  );

  const rulesRaw = policy.app_rules === undefined || policy.app_rules === null
    ? []
    : readArray(policy.app_rules, "policy.app_rules", MAX_RULES);
  const rules: NormalizedAppRule[] = [];
  const seenRulePackages = new Set<string>();
  for (let i = 0; i < rulesRaw.length; i += 1) {
    const rule = readAppRule(rulesRaw[i], `policy.app_rules[${i}]`);
    if (seenRulePackages.has(rule.package_name)) {
      throw new ApiError(
        "validation_error",
        `policy.app_rules contains duplicate package ${rule.package_name}.`,
        400,
      );
    }
    seenRulePackages.add(rule.package_name);
    rules.push(rule);
  }

  const enforceAppBlocks = policy.enforce_app_blocks === undefined
    ? true
    : readBoolean(policy.enforce_app_blocks, "policy.enforce_app_blocks");
  const blockAllExceptAllowed = policy.block_all_except_allowed === undefined
    ? false
    : readBoolean(
      policy.block_all_except_allowed,
      "policy.block_all_except_allowed",
    );

  const dailyRaw = policy.daily_screen_time_limit_minutes;
  const dailyLimit = dailyRaw === undefined || dailyRaw === null
    ? null
    : readInteger(dailyRaw, "policy.daily_screen_time_limit_minutes", 1, 1440);

  const bedtimeStart = policy.bedtime_start_minutes === undefined ||
      policy.bedtime_start_minutes === null
    ? null
    : readInteger(policy.bedtime_start_minutes, "policy.bedtime_start_minutes", 0, 1439);
  const bedtimeEnd = policy.bedtime_end_minutes === undefined ||
      policy.bedtime_end_minutes === null
    ? null
    : readInteger(policy.bedtime_end_minutes, "policy.bedtime_end_minutes", 0, 1439);
  if ((bedtimeStart === null) !== (bedtimeEnd === null)) {
    throw new ApiError(
      "validation_error",
      "policy.bedtime_start_minutes and bedtime_end_minutes must be provided together.",
      400,
    );
  }

  const normalized: NormalizedPolicy = {
    enforce_app_blocks: enforceAppBlocks,
    block_all_except_allowed: blockAllExceptAllowed,
    blocked_packages: blockedPackages,
    allowed_packages: allowedPackages,
    app_rules: rules,
    daily_screen_time_limit_minutes: dailyLimit,
    bedtime_start_minutes: bedtimeStart,
    bedtime_end_minutes: bedtimeEnd,
  };

  if (JSON.stringify(normalized).length > MAX_POLICY_BYTES) {
    throw new ApiError("validation_error", "policy is too large.", 400);
  }
  return normalized;
}

/**
 * Validates type-specific command payloads. Returns the sanitised payload that
 * is stored and delivered to the device.
 */
export function validateCommandPayload(
  type: CommandType,
  raw: unknown,
): Record<string, unknown> {
  if (raw === undefined || raw === null) return {};
  const payload = requireRecord(raw, "payload");
  switch (type) {
    case "apply_policy": {
      rejectUnknownKeys(payload, new Set(["policy"]), "payload");
      const policy = validatePolicyPayload(payload.policy);
      return { policy };
    }
    case "sync_policy": {
      rejectUnknownKeys(payload, new Set(["version"]), "payload");
      const version = readOptionalInteger(payload.version, "payload.version", 0, 1_000_000);
      return version === undefined ? {} : { version };
    }
    case "request_usage": {
      rejectUnknownKeys(payload, new Set(["days"]), "payload");
      const days = readOptionalInteger(payload.days, "payload.days", 1, 365);
      return days === undefined ? {} : { days };
    }
    case "request_location": {
      rejectUnknownKeys(payload, new Set(["high_accuracy"]), "payload");
      const highAccuracy = payload.high_accuracy;
      if (highAccuracy === undefined || highAccuracy === null) return {};
      return { high_accuracy: readBoolean(highAccuracy, "payload.high_accuracy") };
    }
    case "end_session": {
      rejectUnknownKeys(payload, new Set(["session_id", "reason"]), "payload");
      const sessionId = payload.session_id === undefined || payload.session_id === null
        ? undefined
        : readUuid(payload.session_id, "payload.session_id");
      const reason = payload.reason;
      let safeReason: string | undefined;
      if (reason !== undefined && reason !== null) {
        if (typeof reason !== "string" || reason.length > 200) {
          throw new ApiError(
            "validation_error",
            "payload.reason must be at most 200 characters.",
            400,
          );
        }
        safeReason = reason;
      }
      const result: Record<string, unknown> = {};
      if (sessionId) result.session_id = sessionId;
      if (safeReason) result.reason = safeReason;
      return result;
    }
    case "custom": {
      const encoded = JSON.stringify(payload);
      if (encoded.length > 64 * 1024) {
        throw new ApiError("validation_error", "payload is too large.", 400);
      }
      if (!isRecord(payload)) {
        throw new ApiError("validation_error", "payload must be an object.", 400);
      }
      return payload;
    }
    default:
      throw new ApiError("validation_error", "Unsupported command type.", 400);
  }
}
