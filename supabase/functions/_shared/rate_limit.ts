// Server-side pairing rate limits backed by public.pairing_attempts.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { ApiError, ensureNoError } from "./envelope.ts";

export const ATTEMPT_WINDOW_MINUTES = 10;
export const MAX_ATTEMPTS_PER_PARENT = 5;
export const MAX_ATTEMPTS_PER_TOKEN = 10;
export const CODE_CREATIONS_PER_24H = 5;

function windowStart(minutes: number): string {
  return new Date(Date.now() - minutes * 60 * 1000).toISOString();
}

export async function assertPairingRedeemAllowed(
  db: SupabaseClient,
  parentUserId: string,
  codeHash: string,
): Promise<void> {
  const since = windowStart(ATTEMPT_WINDOW_MINUTES);
  const parentResult = await db
    .from("pairing_attempts")
    .select("id", { count: "exact", head: true })
    .eq("parent_user_id", parentUserId)
    .gte("attempted_at", since);
  ensureNoError(parentResult);
  if ((parentResult.count ?? 0) >= MAX_ATTEMPTS_PER_PARENT) {
    throw new ApiError(
      "rate_limited",
      "Too many linking attempts. Wait a few minutes and try again.",
      429,
    );
  }

  const tokenResult = await db
    .from("pairing_attempts")
    .select("id", { count: "exact", head: true })
    .eq("code_hash", codeHash)
    .gte("attempted_at", since);
  ensureNoError(tokenResult);
  if ((tokenResult.count ?? 0) >= MAX_ATTEMPTS_PER_TOKEN) {
    throw new ApiError(
      "rate_limited",
      "Too many attempts for this code. Ask for a new code.",
      429,
    );
  }
}

export async function recordPairingAttempt(
  db: SupabaseClient,
  parentUserId: string,
  codeHash: string,
  success: boolean,
): Promise<void> {
  const { error } = await db.from("pairing_attempts").insert({
    parent_user_id: parentUserId,
    code_hash: codeHash,
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

export async function assertPairingCodeCreationAllowed(
  db: SupabaseClient,
  childUserId: string,
): Promise<void> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const result = await db
    .from("device_pairing_tokens")
    .select("id", { count: "exact", head: true })
    .eq("child_user_id", childUserId)
    .gte("created_at", since);
  ensureNoError(result);
  if ((result.count ?? 0) >= CODE_CREATIONS_PER_24H) {
    throw new ApiError(
      "rate_limited",
      "You have created too many linking codes today. Try again later.",
      429,
    );
  }
}
