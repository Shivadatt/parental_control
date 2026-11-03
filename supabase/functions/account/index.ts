// account: the caller's own privacy lifecycle — export, deletion, retention.
//
// JWT required for every action; identity always comes from the verified token
// (never from the body). There is no storage bucket in this project, so the
// export is delivered as the HTTP response itself: `application/json` with a
// `Content-Disposition: attachment` header. The Flutter client receives the
// same document through `functions.invoke` (it parses JSON either way).
import { preflightResponse, corsHeaders } from "../_shared/cors.ts";
import {
  ApiError,
  ensureNoError,
  errorResponse,
  ok,
  readJson,
  requireAction,
} from "../_shared/envelope.ts";
import { getServiceClient, requireUser } from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import type { AuthContext, MembershipRow } from "../_shared/auth.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  findDeletionBlocker,
  type OwnedFamilyCounts,
  validateDeleteAccountInput,
} from "./validation.ts";
import {
  buildFamilyRetentionReport,
  buildRetentionReportPayload,
  type FamilyRetentionReport,
  retentionCountFilter,
  retentionFromSettings,
  resolveRetentionScope,
  type RetentionCountFilter,
  type SweepMarkerRow,
} from "./retention.ts";

/** Hard safety cap per exported table, independent of PostgREST max-rows. */
const EXPORT_ROW_CAP = 20_000;
/** PostgREST/project max-rows is commonly 1000; page explicitly. */
const EXPORT_PAGE_SIZE = 1_000;
/** Matches nothing; used instead of an empty `in.()` filter. */
const NO_MATCH_UUID = "00000000-0000-0000-0000-000000000000";

interface FamilyRow {
  id: string;
  name: string;
  owner_id: string;
  settings: Record<string, unknown> | null;
  created_at: string;
}

interface TableSection {
  rows: unknown[];
  row_count: number;
  truncated: boolean;
}

/** Columns safe to export: never credential hashes or revocation secrets. */
const DEVICE_COLUMNS = [
  "id",
  "family_id",
  "child_user_id",
  "installation_id",
  "display_name",
  "platform",
  "android_version",
  "app_version",
  "status",
  "last_seen_at",
  "battery_level",
  "is_charging",
  "enforcement_mode",
  "policy_version",
  "usage_access_granted",
  "location_granted",
  "background_location_granted",
  "camera_granted",
  "microphone_granted",
  "notifications_granted",
  "created_at",
  "updated_at",
].join(", ");

// The PostgREST builder is heavily generic; one local alias keeps the paging
// helper readable without leaking `any` into exported code.
// deno-lint-ignore no-explicit-any
type AnyQuery = any;

async function fetchCapped(
  db: SupabaseClient,
  table: string,
  filter: (query: AnyQuery) => AnyQuery,
  orderColumn: string,
): Promise<TableSection> {
  const rows: unknown[] = [];
  for (let from = 0; ; from += EXPORT_PAGE_SIZE) {
    const query = filter(db.from(table).select("*"))
      .order(orderColumn, { ascending: false })
      // Stable tiebreaker so paging cannot duplicate or skip rows that share
      // the same timestamp/day.
      .order("id", { ascending: false })
      .range(from, from + EXPORT_PAGE_SIZE - 1);
    const result = await query;
    ensureNoError(result);
    const page = (result.data ?? []) as unknown[];
    rows.push(...page);
    if (rows.length > EXPORT_ROW_CAP) {
      rows.length = EXPORT_ROW_CAP;
      return { rows, row_count: rows.length, truncated: true };
    }
    if (page.length < EXPORT_PAGE_SIZE) {
      return { rows, row_count: rows.length, truncated: false };
    }
  }
}

async function loadActiveMemberships(
  db: SupabaseClient,
  userId: string,
): Promise<MembershipRow[]> {
  const result = await db
    .from("family_members")
    .select("id, family_id, user_id, role, status")
    .eq("user_id", userId)
    .eq("status", "active");
  ensureNoError(result);
  return (result.data ?? []) as MembershipRow[];
}

async function loadFamilies(
  db: SupabaseClient,
  familyIds: string[],
): Promise<FamilyRow[]> {
  if (familyIds.length === 0) return [];
  const result = await db
    .from("families")
    .select("id, name, owner_id, settings, created_at")
    .in("id", familyIds);
  ensureNoError(result);
  return (result.data ?? []) as FamilyRow[];
}

/**
 * The device rows a `device`-scoped caller owns: `devices.child_user_id` is the
 * caller themself. This is the same rule `exportAccount` applies, deliberately
 * not a second weaker variant of it.
 */
async function loadOwnDeviceIds(
  db: SupabaseClient,
  userId: string,
): Promise<string[]> {
  const result = await db
    .from("devices")
    .select("id, child_user_id")
    .eq("child_user_id", userId);
  ensureNoError(result);
  const rows = (result.data ?? []) as Array<Record<string, unknown>>;
  return rows
    .map((row) => (typeof row.id === "string" ? row.id : ""))
    .filter((id) => id !== "");
}

/**
 * Newest project-wide sweep marker. Its `family_id` is null, so no RLS select
 * policy matches it (`audit_logs_select_family_parent` requires a non-null
 * family_id) and only the service role can read it — which is exactly why the
 * caller's scope decides whether this row is read at all, and which part of it
 * is returned.
 */
async function loadLatestSweepMarker(
  db: SupabaseClient,
): Promise<SweepMarkerRow | null> {
  const result = await db
    .from("audit_logs")
    .select("created_at, metadata")
    .eq("event_type", "retention_sweep")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  ensureNoError(result);
  return (result.data as SweepMarkerRow | null) ?? null;
}

/** Count filter -> never an unfiltered or empty `in.()` query. */
async function countOlderLocationEvents(
  db: SupabaseClient,
  filter: RetentionCountFilter,
  before: string,
): Promise<number> {
  if (!filter.run || filter.device_ids?.length === 0) return 0;
  let query = db
    .from("location_events")
    .select("id", { count: "exact", head: true })
    .eq("family_id", filter.family_id)
    .lt("recorded_at", before);
  if (filter.device_ids !== null) {
    query = query.in("device_id", [...filter.device_ids]);
  }
  const result = await query;
  ensureNoError(result);
  return result.count ?? 0;
}

async function countOlderUsageDays(
  db: SupabaseClient,
  filter: RetentionCountFilter,
  beforeDay: string,
): Promise<number> {
  if (!filter.run || filter.device_ids?.length === 0) return 0;
  let query = db
    .from("usage_daily")
    .select("id", { count: "exact", head: true })
    .eq("family_id", filter.family_id)
    .lt("day", beforeDay);
  if (filter.device_ids !== null) {
    query = query.in("device_id", [...filter.device_ids]);
  }
  const result = await query;
  ensureNoError(result);
  return result.count ?? 0;
}

async function exportAccount(
  db: SupabaseClient,
  auth: AuthContext,
): Promise<Record<string, unknown>> {
  const userId = auth.user.id;
  const memberships = await loadActiveMemberships(db, userId);
  const familyIds = memberships.map((m) => m.family_id);
  const families = await loadFamilies(db, familyIds);
  const familyById = new Map(families.map((f) => [f.id, f]));

  // PRIV-01: one scope rule for both actions. The export document carries the
  // same three-state token the retention report does, so the disclosure in the
  // UI is read from the server's answer instead of inferred from a boolean.
  const decision = resolveRetentionScope({
    callerUserId: userId,
    profileRole: auth.profile?.role,
    memberships,
    families,
  });
  const scope = decision.scope;
  // `family` is the only scope that may contain another member's rows. A child
  // (device) and a caller whose scope the server could not establish
  // (not_reported) both get only rows tied to this account directly.
  const familyScoped = scope === "family";

  // Devices: a device-scoped caller exports only their own; a family-scoped
  // parent exports the family's devices (the same rows the parent UI already
  // shows). Secret material is never selected.
  let devicesQuery = db.from("devices").select(DEVICE_COLUMNS);
  devicesQuery = familyScoped
    ? familyIds.length > 0
      ? devicesQuery.in("family_id", familyIds)
      : devicesQuery.eq("id", NO_MATCH_UUID)
    : devicesQuery.eq("child_user_id", userId);
  const devicesResult = await devicesQuery;
  ensureNoError(devicesResult);
  const devices =
    (devicesResult.data ?? []) as unknown as Array<Record<string, unknown>>;
  const childDeviceIds = devices
    .filter((d) => d.child_user_id === userId)
    .map((d) => String(d.id));

  const scopeRows = (query: AnyQuery): AnyQuery => {
    if (!familyScoped) {
      return childDeviceIds.length === 0
        ? query.eq("device_id", NO_MATCH_UUID)
        : query.in("device_id", childDeviceIds);
    }
    return familyIds.length === 0
      ? query.eq("family_id", NO_MATCH_UUID)
      : query.in("family_id", familyIds);
  };

  const [locationEvents, usageDaily, safetyAlerts, auditLogs] = await Promise.all([
    fetchCapped(db, "location_events", scopeRows, "recorded_at"),
    fetchCapped(db, "usage_daily", scopeRows, "day"),
    fetchCapped(db, "safety_alerts", scopeRows, "created_at"),
    fetchCapped(
      db,
      "audit_logs",
      (query) => {
        if (familyScoped) {
          return familyIds.length === 0
            ? query.eq("family_id", NO_MATCH_UUID)
            : query.in("family_id", familyIds);
        }
        // A device-scoped (or unscoped) caller sees only audit rows they caused
        // or that concern their own device; never the parents' family-wide
        // history.
        return childDeviceIds.length === 0
          ? query.eq("actor_user_id", userId)
          : query.or(
            `actor_user_id.eq.${userId},device_id.in.(${childDeviceIds.join(",")})`,
          );
      },
      "created_at",
    ),
  ]);

  return {
    generated_at: new Date().toISOString(),
    scope,
    account: {
      user_id: userId,
      email: auth.user.email ?? null,
      email_verified: auth.emailVerified,
    },
    profile: {
      id: auth.profile.id,
      role: auth.profile.role,
      display_name: auth.profile.display_name,
    },
    families: memberships.map((membership) => {
      const family = familyById.get(membership.family_id);
      return {
        id: membership.family_id,
        name: family?.name ?? null,
        owner_id: family?.owner_id ?? null,
        settings: family?.settings ?? null,
        created_at: family?.created_at ?? null,
        membership: {
          id: membership.id,
          role: membership.role,
          status: membership.status,
        },
      };
    }),
    devices,
    tables: {
      location_events: locationEvents,
      usage_daily: usageDaily,
      safety_alerts: safetyAlerts,
      audit_logs: auditLogs,
    },
    limits: { max_rows_per_table: EXPORT_ROW_CAP },
  };
}

async function deleteAccount(
  db: SupabaseClient,
  auth: AuthContext,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const userId = auth.user.id;
  const failure = validateDeleteAccountInput({
    confirm: body.confirm,
    email: body.email,
    callerEmail: auth.user.email,
  });
  if (failure) {
    throw new ApiError(failure.code, failure.message, failure.status);
  }

  const memberships = await loadActiveMemberships(db, userId);
  const familyIds = memberships.map((m) => m.family_id);

  const ownedResult = await db
    .from("families")
    .select("id, name, owner_id")
    .eq("owner_id", userId)
    .is("deleted_at", null);
  ensureNoError(ownedResult);
  const ownedFamilies = (ownedResult.data ?? []) as Array<{
    id: string;
    name: string;
    owner_id: string;
  }>;

  // Owner safety: only the caller's own membership row is excluded from the
  // member count, so another parent/child can never be deleted implicitly.
  const counts: OwnedFamilyCounts[] = await Promise.all(
    ownedFamilies.map(async (family) => {
      const members = await db
        .from("family_members")
        .select("id", { count: "exact", head: true })
        .eq("family_id", family.id)
        .eq("status", "active")
        .neq("user_id", userId);
      ensureNoError(members);
      const devices = await db
        .from("devices")
        .select("id", { count: "exact", head: true })
        .eq("family_id", family.id)
        .eq("status", "active");
      ensureNoError(devices);
      return {
        familyId: family.id,
        otherActiveMembers: members.count ?? 0,
        activeDevices: devices.count ?? 0,
      };
    }),
  );

  const blocker = findDeletionBlocker(counts);
  if (blocker) {
    throw new ApiError(
      "account_deletion_blocked",
      blocker.message,
      409,
      { blocked_reason: blocker.blocked_reason, family_ids: blocker.family_ids },
    );
  }

  // Written before deletion; `actor_user_id` is set null by the FK when the
  // profile row goes away, so this record survives the account (event_type is
  // plain text, no user FK). The sweep separately drops audit rows after 365
  // days.
  await recordAudit(db, {
    familyId: ownedFamilies[0]?.id ?? familyIds[0] ?? null,
    actorUserId: userId,
    eventType: "account_deleted",
    targetType: "account",
    targetId: userId,
    metadata: {
      user_id: userId,
      memberships: memberships.length,
      owned_families: ownedFamilies.length,
    },
  });

  // Only the caller's own rows. Another user's membership, profile or device
  // is never touched by this path.
  const membershipDelete = await db
    .from("family_members")
    .delete()
    .eq("user_id", userId);
  ensureNoError(membershipDelete);

  // An otherwise empty family owned solely by the caller has no meaning once
  // the owner is gone. Active devices were refused above, so only pending or
  // revoked rows can cascade here.
  let familiesRemoved = 0;
  for (const family of ownedFamilies) {
    const deleted = await db
      .from("families")
      .delete({ count: "exact" })
      .eq("id", family.id)
      .eq("owner_id", userId);
    ensureNoError(deleted);
    familiesRemoved += deleted.count ?? 0;
  }

  const profileDelete = await db.from("profiles").delete().eq("id", userId);
  ensureNoError(profileDelete);

  const authDelete = await db.auth.admin.deleteUser(userId);
  if (authDelete.error) {
    console.error(`account_auth_delete_failed:${authDelete.error.code ?? "unknown"}`);
    throw new ApiError(
      "account_delete_incomplete",
      "The account data was removed, but the sign-in record could not be deleted. Contact the project owner.",
      500,
    );
  }

  return {
    deleted: true,
    memberships_removed: memberships.length,
    families_removed: familiesRemoved,
  };
}

async function retentionReport(
  db: SupabaseClient,
  auth: AuthContext,
): Promise<Record<string, unknown>> {
  const memberships = await loadActiveMemberships(db, auth.user.id);
  const families = await loadFamilies(
    db,
    memberships.map((m) => m.family_id),
  );
  const now = new Date();

  // PRIV-01: the scope is decided from the caller's own profile role plus their
  // active memberships and ownership, BEFORE any row is counted. A child gets
  // their own device rows; only a parent gets family counts; only the owner
  // gets the project-wide sweep totals; anything else gets nothing.
  const decision = resolveRetentionScope({
    callerUserId: auth.user.id,
    profileRole: auth.profile?.role,
    memberships,
    families,
  });

  // Device scope reuses the export path's device rule (child_user_id = caller),
  // so there is only ever one definition of "this child's devices".
  const deviceIds = decision.scope === "device"
    ? await loadOwnDeviceIds(db, auth.user.id)
    : [];

  // Read only for the family scope. The sweep metadata stays in the payload
  // builder, where the owner-only redaction is applied.
  const lastSweep = decision.readsSweepMarker
    ? await loadLatestSweepMarker(db)
    : null;

  const reports: FamilyRetentionReport[] = decision.scope === "not_reported"
    ? []
    : await Promise.all(
      families.map(async (family) => {
        const windows = retentionFromSettings(family.settings);
        const dayMs = 24 * 60 * 60 * 1000;
        const locationBefore = new Date(
          now.getTime() - windows.location_retention_days * dayMs,
        ).toISOString();
        const usageBefore = new Date(
          now.getTime() - windows.usage_retention_days * dayMs,
        ).toISOString().slice(0, 10);

        const filter = retentionCountFilter({
          scope: decision.scope,
          familyId: family.id,
          deviceIds,
        });

        const [location, usage] = await Promise.all([
          countOlderLocationEvents(db, filter, locationBefore),
          countOlderUsageDays(db, filter, usageBefore),
        ]);

        return buildFamilyRetentionReport({
          familyId: family.id,
          name: family.name,
          settings: family.settings,
          locationEventsOlder: location,
          usageDaysOlder: usage,
          now,
        });
      }),
    );

  return buildRetentionReportPayload({ now, decision, reports, lastSweep });
}

function exportResponse(payload: unknown): Response {
  const stamp = new Date().toISOString().slice(0, 10);
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition":
        `attachment; filename="parent-control-export-${stamp}.json"`,
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflightResponse();
  if (req.method !== "POST") {
    return errorResponse(new ApiError("method_not_allowed", "Use POST.", 405));
  }
  try {
    const body = await readJson(req);
    const action = requireAction(body);
    const db = getServiceClient();

    // Account data belongs to the caller: export and deletion must remain
    // possible even when the email is not verified, so no verified-email gate.
    // The gate that does exist is the JWT itself — every action below runs only
    // after `requireUser`, and `retention_report` further narrows the payload by
    // the caller's resolved scope (family / device / not_reported).
    const auth = await requireUser(req, db);

    switch (action) {
      case "export":
        return exportResponse(await exportAccount(db, auth));
      case "delete_account":
        return ok(await deleteAccount(db, auth, body));
      case "retention_report":
        return ok(await retentionReport(db, auth));
      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});