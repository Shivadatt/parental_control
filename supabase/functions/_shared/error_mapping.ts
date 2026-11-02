// Authorization-shaped Postgres error mapping — single source of truth.
//
// Why this exists (Phase 3 gap SQL-03): migration 20261030000200 hardened the
// service RPCs with `private.is_parent_of_family()`, which raises
// `not_family_parent` with SQLSTATE 42501 (INSUFFICIENT_PRIVILEGE). Before this
// module, only `family-admin` translated it; `device-policy`, `device-command`
// and `pairing` fell through to their generic `internal_error`/500 branch.
//
// A 5xx is the wrong answer twice over:
//   * it is a lie — the caller is not allowed to do this, and no retry changes
//     that;
//   * it is retryable by contract. `GuardianService.kt` grows its poll backoff
//     from *any* `DeviceHttpException` (2x for an unclassified status, i.e. 5xx)
//     and never stops retrying, and the Dart repositories already treat the
//     Postgres code `42501` as `AppErrorCodes.forbidden`. A permanent
//     permission failure therefore became an endless retry loop.
//
// Rules this module must keep:
//   1. An authorization failure never becomes a success and never becomes a 5xx.
//   2. Nothing internal leaks: the caller gets a stable code plus a fixed safe
//      message — never the SQL message, constraint name, table name or payload.
//      Server-side, only a short whitelisted reason token and the SQLSTATE are
//      logged (same convention as `ensureNoError` and `recordAudit`).
//   3. Everything else is left alone: this returns `null` for any error that is
//      not authorization-shaped, so each handler keeps its own existing 401 /
//      404 / 409 / 410 / 422 / 500 mapping untouched.
//
// No Deno.serve, no Supabase client, no environment access: the error object and
// the logger are injected, so the mapping is genuinely unit-testable (see
// `error_mapping_test.ts`).

import { ApiError } from "./envelope.ts";

/** Minimal shape of a PostgREST/`supabase-js` error, as returned by `.error`. */
export interface PostgresErrorLike {
  message?: string | null;
  code?: string | null;
  details?: string | null;
  hint?: string | null;
}

/** PostgreSQL SQLSTATE used by every authorization raise in this schema. */
export const INSUFFICIENT_PRIVILEGE = "42501";

/**
 * Stable machine-readable code returned to callers for an authorization
 * failure. Matches `family-admin`'s existing 403 mapping and Dart
 * `AppErrorCodes.forbidden`, so all four handlers agree.
 */
export const AUTHORIZATION_CODE = "forbidden";

/** Caller-facing message. Fixed text: it never carries SQL internals. */
export const AUTHORIZATION_MESSAGE =
  "You do not have permission to perform this action.";

/**
 * Messages our own SQL raises for "this caller may not do this"
 * (`not_family_parent`: migration 20261030000200; `forbidden`: 20260101000100 /
 * 20260101000400), plus the PostgREST/Postgres-native phrasings of the same
 * SQLSTATE. Order is diagnostic-token order, not precedence.
 */
const AUTHORIZATION_MARKERS = [
  "not_family_parent",
  "forbidden",
  "parent_required",
  "owner_required",
  "permission denied",
  "row-level security",
  "insufficient privilege",
  "insufficient_privilege",
] as const;

/**
 * 42501 raises that are data-integrity rules, not caller permission
 * (`audit_logs_append_only`, `profiles_before_update`, `families_before_update`
 * in 20260101000000_core.sql). A service-role write hitting one of these is a
 * server fault, so the handler's existing 500 must stay: relabelling it 403
 * would hide a broken deploy behind a permission message.
 */
const INTEGRITY_MARKERS = ["append-only", "is immutable"] as const;

/** Matches the lower-cased message against a marker list. */
function firstMarker(message: string, markers: readonly string[]): string | null {
  for (const marker of markers) {
    if (message.includes(marker)) return marker;
  }
  return null;
}

/**
 * The whitelisted reason token logged server-side, or `null` when the marker
 * list says this is not an authorization failure. Never the raw message.
 */
function reasonToken(message: string): string | null {
  if (firstMarker(message, INTEGRITY_MARKERS)) return null;
  const known = firstMarker(message, AUTHORIZATION_MARKERS);
  if (known) return known;
  // A 42501 raised with an unrecognised message is still PostgreSQL saying
  // "insufficient privilege"; SQLSTATE 42501 is reserved and no rule in this
  // schema reuses it for anything else.
  return "unrecognised_42501";
}

/**
 * True when a Postgres error is an authorization failure rather than a bug.
 * Keyed on the SQLSTATE first, because a message can change without the
 * meaning changing; the message markers catch the case where a transport drops
 * or rewrites the code.
 */
export function isAuthorizationError(
  error: PostgresErrorLike | null | undefined,
): boolean {
  if (!error) return false;
  const message = (error.message ?? "").toLowerCase();
  if (firstMarker(message, INTEGRITY_MARKERS)) return false;
  if ((error.code ?? "").toUpperCase() === INSUFFICIENT_PRIVILEGE) return true;
  return firstMarker(message, AUTHORIZATION_MARKERS) !== null;
}

/** Short diagnostic token for the log line; never raw SQL text or payloads. */
export function authorizationReason(
  error: PostgresErrorLike | null | undefined,
): string {
  if (!isAuthorizationError(error)) return "not_authorization";
  const message = (error?.message ?? "").toLowerCase();
  return reasonToken(message) ?? "unrecognised_42501";
}

/**
 * The mapped 403 for an authorization-shaped Postgres error, or `null` for
 * anything else (so the caller's existing mapping keeps full control).
 * `message` may be overridden for operation-specific wording; it must be static
 * text, never a value derived from the database error.
 */
export function authorizationError(
  error: PostgresErrorLike | null | undefined,
  message: string = AUTHORIZATION_MESSAGE,
): ApiError | null {
  if (!isAuthorizationError(error)) return null;
  return new ApiError(AUTHORIZATION_CODE, message, 403);
}

export type MappingLogger = (message: string) => void;

/**
 * Convenience for handler error branches: returns the 403 `ApiError` to throw
 * and logs a short reason server-side, or returns `null` without logging so the
 * handler's own branch runs unchanged.
 *
 * `context` is a static site name (e.g. "apply_policy") — it is what makes the
 * log line diagnosable without echoing a Supabase payload.
 */
export function denyAuthorization(
  error: PostgresErrorLike | null | undefined,
  context: string,
  log: MappingLogger = (message: string) => console.error(message),
  message?: string,
): ApiError | null {
  const denied = authorizationError(error, message);
  if (!denied) return null;
  log(
    `${context}_denied:${error?.code ?? "unknown"}:${authorizationReason(error)}`,
  );
  return denied;
}
