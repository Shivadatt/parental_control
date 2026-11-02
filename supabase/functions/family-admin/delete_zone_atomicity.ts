// Safe-zone delete audit handling for the `family-admin` `delete_zone` action
// (Phase 3, gap SQL-05).
//
// WHY THIS MODULE EXISTS
// The handler deletes the zone with one PostgREST call and then writes the
// `audit_logs` row with a second, independent call (index.ts case
// "delete_zone"). The DELETE commits in its own transaction; the INSERT runs
// in another. When the INSERT fails the deletion stays committed with no
// audit row, and a retry cannot fix it (a second delete_zone call now 404s on
// the pre-read). This module owns the post-delete decision — bounded audit
// retries, a compensating restore of the zone row, and an explicit outcome
// for the failure branch — as an importable pure orchestration so failures
// can genuinely be injected in tests (the bare top-level `Deno.serve` handler
// itself is not importable; see supabase/functions/handler_wiring_test.ts).
//
// INVARIANTS (unchanged from the Phase 1 contract)
// 1. An audit row is written only when a deletion actually happened. The
//    zero-row case never reaches this module: the handler audits strictly
//    inside `if ((deleted.count ?? 0) > 0)`.
// 2. An audit failure must never leave an unaudited deletion *silently*. If
//    every audit attempt fails we restore the exact zone row; if the restore
//    also fails the caller receives an explicit `audit_failed`/500 naming the
//    unaudited zone id in the server log — never `{deleted: true}`.
// 3. `audit_logs` stays append-only: this module only ever INSERTs audit
//    rows; it never updates or deletes them (immutability trigger
//    private.audit_logs_append_only, 20260101000000_core.sql:563-565, is
//    untouched).
//
// DOCUMENTED RESIDUAL RISKS (true atomicity needs the proposed RPC; see
// docs/implementation/proposals/phase3-safe-zone-audit-atomicity.sql)
// - A retry after an insert that COMMITTED but was not acknowledged (network
//   cut mid-response) can produce a duplicate `zone_deleted` row. That is
//   over-recording, which the append-only ledger tolerates, unlike a missing
//   row.
// - In that same window the compensating restore can re-create a zone whose
//   deletion was (unknown to us) already audited. Requires every attempt to
//   commit-and-lose-its-response; recorded here rather than hidden.
// - The restore re-creates the `safe_zones` row, not the cascade-deleted
//   `safe_zone_states` latches (FK `on delete cascade`, core.sql:287). They
//   are rebuilt by the next `device-telemetry` `location_upload`, so the
//   zone behaves correctly; only the inside/outside history is reset.

/** The full pre-delete zone row — every column needed to re-create it faithfully. */
export interface ZoneSnapshot {
  id: string;
  family_id: string;
  name: string;
  lat: number;
  lng: number;
  radius_m: number;
  active: boolean;
  created_by: string | null;
  created_at: string;
}

/** One `audit_logs` insert, field-for-field identical to _shared/audit.ts. */
export interface AuditLogInsert {
  family_id: string;
  actor_user_id: string;
  device_id: null;
  event_type: string;
  target_type: string;
  target_id: string;
  metadata: Record<string, unknown>;
}

export interface StoreFailure {
  code?: string;
  message?: string;
}

/**
 * The two side effects this decision needs. The handler implements them with
 * the service-role client; tests implement them with fakes that fail.
 */
export interface ZoneDeleteStore {
  insertAudit(row: AuditLogInsert): Promise<StoreFailure | null>;
  restoreZone(zone: ZoneSnapshot): Promise<StoreFailure | null>;
}

/** Max audit insert attempts before compensating (each attempt is one insert). */
export const AUDIT_MAX_ATTEMPTS = 3;

/** Backoff before the retry following failure N, in ms. */
export function auditRetryDelayMs(failedAttempt: number): number {
  return failedAttempt * 100;
}

export type ZoneAuditOutcome =
  /** A `zone_deleted` audit row was recorded for the committed deletion. */
  | { kind: "audited"; attempts: number }
  /** Audit could not be recorded; the zone row was restored — net effect: not deleted. */
  | { kind: "restored"; attempts: number; auditErrorCode?: string }
  /**
   * Audit could not be recorded AND the compensating restore failed: the
   * deletion stands without an audit row. The handler must surface this
   * explicitly; it must never be reported as success.
   */
  | {
      kind: "unaudited_delete";
      attempts: number;
      auditErrorCode?: string;
      restoreErrorCode?: string;
    };

/**
 * Builds the audit row for a completed zone deletion. Shape is frozen to
 * match `_shared/audit.ts` `recordAudit` (which still serves every other
 * action): same columns, `device_id: null`, event_type `zone_deleted`,
 * target_type `safe_zone`, metadata `{ name }`.
 */
export function buildZoneAuditInsert(
  zone: Pick<ZoneSnapshot, "id" | "family_id" | "name">,
  actorUserId: string,
): AuditLogInsert {
  return {
    family_id: zone.family_id,
    actor_user_id: actorUserId,
    device_id: null,
    event_type: "zone_deleted",
    target_type: "safe_zone",
    target_id: zone.id,
    metadata: { name: zone.name },
  };
}

const realSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Records the audit row for a deletion that already committed.
 *
 * Attempt the insert up to `maxAttempts` times with a linear backoff. On the
 * first success the result is `audited`. If every attempt fails, attempt one
 * compensating restore of the exact pre-delete row: `restored` when it
 * succeeds (nothing was deleted, net), `unaudited_delete` when it too fails.
 * Callers must treat anything other than `audited` as an error and must not
 * return success.
 */
export async function auditZoneDeletion(
  store: ZoneDeleteStore,
  audit: AuditLogInsert,
  zone: ZoneSnapshot,
  options: {
    maxAttempts?: number;
    sleep?: (ms: number) => Promise<void>;
  } = {},
): Promise<ZoneAuditOutcome> {
  const maxAttempts = Math.max(1, options.maxAttempts ?? AUDIT_MAX_ATTEMPTS);
  const sleep = options.sleep ?? realSleep;

  let attempts = 0;
  let lastAuditError: StoreFailure | null = null;
  for (;;) {
    attempts += 1;
    lastAuditError = await store.insertAudit(audit);
    if (!lastAuditError) {
      return { kind: "audited", attempts };
    }
    if (attempts >= maxAttempts) break;
    await sleep(auditRetryDelayMs(attempts));
  }

  const auditErrorCode = lastAuditError?.code;
  const restoreError = await store.restoreZone(zone);
  if (!restoreError) {
    return { kind: "restored", attempts, auditErrorCode };
  }
  return {
    kind: "unaudited_delete",
    attempts,
    auditErrorCode,
    restoreErrorCode: restoreError.code,
  };
}
