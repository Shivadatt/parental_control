// Abandoned-session sweep shared helper.
//
// The SQL contract is `public.expire_abandoned_sessions(p_max_age interval
// default '24 hours')` (migration 20261030000100). The sweeper closes
// consented (`accepted`/`active`) sessions that nobody has touched for
// `p_max_age`; elapsed time never closes a *live* session, which is why this is
// not part of the 10-minute pending-request expiry.
//
// No Deno.serve and no Supabase client type here: the callable is injected so
// the logic can be unit-tested with a fake (see lifecycle_test.ts).

/** SQL function name. Changing it is a contract change, not a refactor. */
export const ABANDONED_SWEEP_RPC = "expire_abandoned_sessions";
/** Server-side default for consented sessions nobody returns to. */
export const ABANDONED_SWEEP_MAX_AGE = "24 hours";

export interface SweepRpcResult {
  data: unknown;
  error: { code?: string | null; message?: string | null } | null;
}

/** Minimal shape of `SupabaseClient.rpc` the sweep needs. */
export type SweepRpc = (
  fn: string,
  args: Record<string, unknown>,
) => PromiseLike<SweepRpcResult>;

export type SweepLogger = (message: string) => void;

/** Argument object sent to the RPC. Exported so the test can pin it. */
export function abandonedSweepArgs(
  maxAge: string = ABANDONED_SWEEP_MAX_AGE,
): Record<string, unknown> {
  return { p_max_age: maxAge };
}

/**
 * Best-effort sweep. Returns the number of closed rows, or `null` when the
 * sweep did not run (function missing, SQL error, transport throw).
 *
 * It never throws: a cleanup failure must never fail the parent's request, and
 * this code can reach production before the migration is applied. Only a short
 * code is logged - SQL messages can echo argument values.
 */
export async function sweepAbandonedSessions(
  rpc: SweepRpc,
  log: SweepLogger = (message: string) => console.error(message),
): Promise<number | null> {
  try {
    const result = await rpc(ABANDONED_SWEEP_RPC, abandonedSweepArgs());
    if (result.error) {
      log(`abandoned_session_sweep_failed:${result.error.code ?? "unknown"}`);
      return null;
    }
    const closed = typeof result.data === "number"
      ? result.data
      : Number(result.data ?? 0);
    if (!Number.isFinite(closed) || closed < 0) {
      log("abandoned_session_sweep_failed:invalid_result");
      return null;
    }
    if (closed > 0) log(`abandoned_session_sweep_closed:${closed}`);
    return closed;
  } catch (error) {
    const code = error && typeof error === "object" && "code" in error
      ? String((error as { code?: unknown }).code ?? "unknown")
      : "unknown";
    log(`abandoned_session_sweep_failed:${code}`);
    return null;
  }
}

/**
 * Sweep first, then run the request RPC. The order matters: the sweep must
 * happen before `request_remote_session` takes the per-device advisory lock,
 * and the request proceeds whatever the sweep did.
 */
export async function withAbandonedSweep<T>(
  rpc: SweepRpc,
  run: () => PromiseLike<T>,
  log?: SweepLogger,
): Promise<T> {
  await sweepAbandonedSessions(rpc, log);
  return await run();
}