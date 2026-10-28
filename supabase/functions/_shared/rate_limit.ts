// Server-side pairing rate limits.
//
// Two distinct concerns live here and must not be conflated:
//   * how many *usable* codes a child has (an invariant, already guaranteed by
//     revocation in the create path), and
//   * how fast a child may mint (the real anti-spam control).
// Counting every row regardless of status merged the two and locked children
// out of their own happy path. See docs/read_only_audit_2026-10-27.md §3.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { ApiError, ensureNoError } from "./envelope.ts";

export const ATTEMPT_WINDOW_MINUTES = 10;
export const MAX_ATTEMPTS_PER_PARENT = 5;
export const MAX_ATTEMPTS_PER_TOKEN = 10;
/** Contract limit: live ("active") codes per child per 24h. */
export const MAX_ACTIVE_CODES_PER_24H = 5;
/** Anti-spam limit: code creations per child per rolling hour. */
export const CODE_CREATIONS_PER_HOUR = 10;
/** Inbound abuse limits that make a permanent Child ID survivable. */
export const MAX_PENDING_INVITES_PER_CHILD = 3;
export const MAX_INVITES_PER_CHILD_24H = 10;

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;

function windowStart(minutes: number): string {
  return new Date(Date.now() - minutes * MINUTE_MS).toISOString();
}

function retryDetails(
  oldestCreatedAt: string | null | undefined,
  windowMs: number,
): Record<string, unknown> {
  const base = oldestCreatedAt ? new Date(oldestCreatedAt).getTime() : Date.now();
  const seconds = Math.max(1, Math.ceil((base + windowMs - Date.now()) / 1000));
  return { retry_after_seconds: seconds };
}

function humanizeRetry(details: Record<string, unknown>): string {
  const seconds = Number(details.retry_after_seconds ?? 0);
  if (!Number.isFinite(seconds) || seconds <= 0) return "in a few minutes";
  const minutes = Math.max(1, Math.ceil(seconds / 60));
  return minutes === 1 ? "in about a minute" : `in about ${minutes} minutes`;
}

/**
 * Failed lookups are the brute-force control. Successful outcomes never count,
 * so a parent who links several children cleanly is never throttled by their
 * own success (docs/api-contract.md: "count failures").
 */
export async function assertPairingRedeemAllowed(
  db: SupabaseClient,
  parentUserId: string,
  lookupHash: string,
): Promise<void> {
  const since = windowStart(ATTEMPT_WINDOW_MINUTES);
  const parentResult = await db
    .from("pairing_attempts")
    .select("id", { count: "exact", head: true })
    .eq("parent_user_id", parentUserId)
    .eq("success", false)
    .gte("attempted_at", since);
  ensureNoError(parentResult);
  if ((parentResult.count ?? 0) >= MAX_ATTEMPTS_PER_PARENT) {
    throw new ApiError(
      "rate_limited",
      "Too many linking attempts. Wait a few minutes and try again.",
      429,
      { retry_after_seconds: ATTEMPT_WINDOW_MINUTES * 60 },
    );
  }

  const targetResult = await db
    .from("pairing_attempts")
    .select("id", { count: "exact", head: true })
    .eq("code_hash", lookupHash)
    .eq("success", false)
    .gte("attempted_at", since);
  ensureNoError(targetResult);
  if ((targetResult.count ?? 0) >= MAX_ATTEMPTS_PER_TOKEN) {
    throw new ApiError(
      "rate_limited",
      "Too many attempts for this identifier. Ask for a fresh one.",
      429,
      { retry_after_seconds: ATTEMPT_WINDOW_MINUTES * 60 },
    );
  }
}

export async function recordPairingAttempt(
  db: SupabaseClient,
  parentUserId: string,
  lookupHash: string,
  success: boolean,
): Promise<void> {
  const { error } = await db.from("pairing_attempts").insert({
    parent_user_id: parentUserId,
    code_hash: lookupHash,
    success,
  });
  if (error) {
    console.error(`pairing_attempt_insert_failed:${error.code ?? "unknown"}`);
    throw new ApiError(
      "internal_error",
      "The request could not be completed.",
      500,
    );
  }
}

/**
 * Legacy code minting. Counts only *usable* codes against the contract limit,
 * and bounds the mint rate per hour. Revoked/expired rows the create path
 * leaves behind are not debt.
 */
export async function assertPairingCodeCreationAllowed(
  db: SupabaseClient,
  childUserId: string,
): Promise<void> {
  const nowIso = new Date().toISOString();
  const live = await db
    .from("device_pairing_tokens")
    .select("id", { count: "exact", head: true })
    .eq("child_user_id", childUserId)
    .eq("purpose", "code")
    .eq("status", "active")
    .gt("expires_at", nowIso)
    .gte("created_at", new Date(Date.now() - 24 * HOUR_MS).toISOString());
  ensureNoError(live);
  if ((live.count ?? 0) >= MAX_ACTIVE_CODES_PER_24H) {
    throw new ApiError(
      "rate_limited",
      "You have too many live linking codes. Wait for one to expire and try again.",
      429,
      { retry_after_seconds: 10 * 60 },
    );
  }

  const recent = await db
    .from("device_pairing_tokens")
    .select("created_at")
    .eq("child_user_id", childUserId)
    .eq("purpose", "code")
    .gte("created_at", new Date(Date.now() - HOUR_MS).toISOString())
    .order("created_at", { ascending: true })
    .limit(CODE_CREATIONS_PER_HOUR);
  ensureNoError(recent);
  const rows = (recent.data ?? []) as { created_at: string }[];
  if (rows.length >= CODE_CREATIONS_PER_HOUR) {
    const details = retryDetails(rows[0]?.created_at, HOUR_MS);
    throw new ApiError(
      "rate_limited",
      `You have created too many linking codes. Try again ${
        humanizeRetry(details)
      }.`,
      429,
      details,
    );
  }
}

/**
 * Inbound abuse control for a permanent identifier. Without a per-child cap a
 * public Child ID would let any parent fill a minor's consent inbox.
 *
 * Counting `pairing_requests` covers both entry points (legacy code redeem and
 * Child ID invite), so neither path can be used to bypass the cap.
 */
export async function assertInviteQuotaAllowed(
  db: SupabaseClient,
  childUserId: string,
): Promise<void> {
  const nowIso = new Date().toISOString();
  const pending = await db
    .from("pairing_requests")
    .select("id", { count: "exact", head: true })
    .eq("child_user_id", childUserId)
    .eq("status", "pending_child")
    .gt("expires_at", nowIso);
  ensureNoError(pending);
  if ((pending.count ?? 0) >= MAX_PENDING_INVITES_PER_CHILD) {
    throw new ApiError(
      "rate_limited",
      "This account already has several linking requests waiting for approval. Try again once they are answered.",
      429,
      { retry_after_seconds: 10 * 60 },
    );
  }

  const recent = await db
    .from("pairing_requests")
    .select("created_at")
    .eq("child_user_id", childUserId)
    .gte("created_at", new Date(Date.now() - 24 * HOUR_MS).toISOString())
    .order("created_at", { ascending: true })
    .limit(MAX_INVITES_PER_CHILD_24H);
  ensureNoError(recent);
  const rows = (recent.data ?? []) as { created_at: string }[];
  if (rows.length >= MAX_INVITES_PER_CHILD_24H) {
    const details = retryDetails(rows[0]?.created_at, 24 * HOUR_MS);
    throw new ApiError(
      "rate_limited",
      `This account has received too many linking requests today. Try again ${
        humanizeRetry(details)
      }.`,
      429,
      details,
    );
  }
}
