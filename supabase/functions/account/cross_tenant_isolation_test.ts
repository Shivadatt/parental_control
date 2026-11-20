// cross_tenant_isolation_test.ts — Phase 3.7.4 Offline Adversarial Cross-Tenant Isolation Suite
//
// Exercised scenarios: CT-01 through CT-10
// Tests all 10 adversarial isolation scenarios against `fakePostgrest` without network,
// production, or remote credentials.
//
// CT-01: Baseline Isolation (Export) — Tenant A data strictly isolated from Tenant B
// CT-02: Adversarial Injected Family ID in Export — Injected payload ignored
// CT-03: Adversarial Injected Family ID in Retention Report — Injected payload ignored
// CT-04: Inactive / Revoked Membership Isolation — Suspended membership fails closed
// CT-05: Child Role Isolation & Audit Log Partitioning — Device scope, parent logs excluded
// CT-06: Multi-Membership Scope Isolation — Multi-family parent sees own families only
// CT-07: Empty Scope Fail-Closed Verification — NO_MATCH_UUID fails closed (0 leaks)
// CT-08: Adversarial Injected Device ID in Export — Injected device parameter ignored
// CT-09: Audit Log Query Isolation & Sweep Marker Leak Prevention — Global markers excluded
// CT-10: Pagination & Row-Cap Isolation Across Interleaved Records — Page boundary & 20k cap

import { assertEquals, assert } from "jsr:@std/assert";
import { fakePostgrest, type Row } from "../_shared/fake_postgrest.ts";
import { handleAccountRequest } from "./deletion.ts";

// =============================================================================
// Constants & Synthetic Tenant IDs
// =============================================================================

// Tenant A (Authorized Caller)
const USER_A_ID = "11111111-1111-4111-8111-111111111111";
const USER_A_EMAIL = "parent-a@internal-test.local";
const TOKEN_USER_A = "token-user-a-valid-bearer-32chars";

const FAMILY_A_ID = "aaaa1111-1111-4111-8111-111111111111";
const MEMBERSHIP_A_ID = "mema1111-1111-4111-8111-111111111111";
const DEVICE_A_ID = "deva1111-1111-4111-8111-111111111111";

const CHILD_A_ID = "ca111111-1111-4111-8111-111111111111";
const CHILD_A_EMAIL = "child-a@internal-test.local";
const TOKEN_CHILD_A = "token-child-a-valid-bearer-32chars";
const MEMBERSHIP_CHILD_A_ID = "memca111-1111-4111-8111-111111111111";

// Tenant B (Victim / Foreign Tenant)
const USER_B_ID = "22222222-2222-4222-8222-222222222222";
const USER_B_EMAIL = "parent-b@internal-test.local";
const TOKEN_USER_B = "token-user-b-valid-bearer-32chars";

const FAMILY_B_ID = "bbbb2222-2222-4222-8222-222222222222";
const MEMBERSHIP_B_ID = "memb2222-2222-4222-8222-222222222222";
const DEVICE_B_ID = "devb2222-2222-4222-8222-222222222222";

// Stranger / Inactive / Secondary Family
const STRANGER_ID = "33333333-3333-4333-8333-333333333333";
const STRANGER_EMAIL = "stranger@internal-test.local";
const TOKEN_STRANGER = "token-stranger-valid-bearer-32chars";

const INACTIVE_USER_ID = "44444444-4444-4444-8444-444444444444";
const INACTIVE_USER_EMAIL = "inactive@internal-test.local";
const TOKEN_INACTIVE = "token-inactive-valid-bearer-32chars";
const MEMBERSHIP_INACTIVE_ID = "meminact-4444-4444-8444-444444444444";

const FAMILY_C_ID = "cccc3333-3333-4333-8333-333333333333";
const MEMBERSHIP_A_IN_C_ID = "memac333-3333-4333-8333-333333333333";

interface ApiEnvelope<T = unknown> {
  ok: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

async function parseExportPayload(res: Response): Promise<Record<string, unknown>> {
  return (await res.json()) as Record<string, unknown>;
}

async function parseEnvelope<T = unknown>(res: Response): Promise<ApiEnvelope<T>> {
  return (await res.json()) as ApiEnvelope<T>;
}

function makeRequest(
  body: Record<string, unknown>,
  token: string | null = TOKEN_USER_A,
): Request {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token !== null) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  return new Request("http://localhost/account", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

// =============================================================================
// Two-Tenant World Builder
// =============================================================================

function setupTwoTenantWorld(): ReturnType<typeof fakePostgrest> {
  // Profiles
  const profiles: Row[] = [
    {
      id: USER_A_ID,
      role: "parent",
      display_name: "Parent A",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
    {
      id: CHILD_A_ID,
      role: "child",
      display_name: "Child A",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
    {
      id: USER_B_ID,
      role: "parent",
      display_name: "Parent B",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
    {
      id: STRANGER_ID,
      role: "parent",
      display_name: "Stranger User",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
    {
      id: INACTIVE_USER_ID,
      role: "parent",
      display_name: "Inactive User",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
  ];

  // Families
  const families: Row[] = [
    {
      id: FAMILY_A_ID,
      name: "Family A (Tenant A)",
      owner_id: USER_A_ID,
      settings: { location_retention_days: 30, usage_retention_days: 60 },
      created_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
    },
    {
      id: FAMILY_B_ID,
      name: "Family B (Tenant B)",
      owner_id: USER_B_ID,
      settings: { location_retention_days: 14, usage_retention_days: 30 },
      created_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
    },
    {
      id: FAMILY_C_ID,
      name: "Family C (Secondary)",
      owner_id: USER_A_ID,
      settings: null,
      created_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
    },
  ];

  // Family Memberships
  const familyMembers: Row[] = [
    // Tenant A
    {
      id: MEMBERSHIP_A_ID,
      family_id: FAMILY_A_ID,
      user_id: USER_A_ID,
      role: "parent",
      status: "active",
    },
    {
      id: MEMBERSHIP_CHILD_A_ID,
      family_id: FAMILY_A_ID,
      user_id: CHILD_A_ID,
      role: "child",
      status: "active",
    },
    // Multi-membership for User A
    {
      id: MEMBERSHIP_A_IN_C_ID,
      family_id: FAMILY_C_ID,
      user_id: USER_A_ID,
      role: "parent",
      status: "active",
    },
    // Tenant B
    {
      id: MEMBERSHIP_B_ID,
      family_id: FAMILY_B_ID,
      user_id: USER_B_ID,
      role: "parent",
      status: "active",
    },
    // Inactive user in Family A
    {
      id: MEMBERSHIP_INACTIVE_ID,
      family_id: FAMILY_A_ID,
      user_id: INACTIVE_USER_ID,
      role: "parent",
      status: "suspended",
    },
  ];

  // Devices
  const devices: Row[] = [
    {
      id: DEVICE_A_ID,
      family_id: FAMILY_A_ID,
      child_user_id: CHILD_A_ID,
      secret_hash: "hash_a",
      status: "active",
      credential_revoked_at: null,
      display_name: "Child A Device",
      policy_version: 1,
      last_seen_at: "2026-11-20T10:00:00.000Z",
      battery_level: 85,
      is_charging: false,
      enforcement_mode: "device_owner",
    },
    {
      id: DEVICE_B_ID,
      family_id: FAMILY_B_ID,
      child_user_id: USER_B_ID,
      secret_hash: "hash_b",
      status: "active",
      credential_revoked_at: null,
      display_name: "Tenant B Device",
      policy_version: 1,
      last_seen_at: "2026-11-20T10:00:00.000Z",
      battery_level: 92,
      is_charging: true,
      enforcement_mode: "device_owner",
    },
  ];

  // Location Events: exactly 5 for Tenant A, 5 for Tenant B
  const locationEvents: Row[] = [
    // Tenant A (5 rows)
    { id: "loc-a-01", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, recorded_at: "2026-11-19T01:00:00.000Z", lat: 37.5665, lon: 126.9780, marker: "TENANT_A_ONLY" },
    { id: "loc-a-02", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, recorded_at: "2026-11-19T02:00:00.000Z", lat: 37.5666, lon: 126.9781, marker: "TENANT_A_ONLY" },
    { id: "loc-a-03", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, recorded_at: "2026-11-19T03:00:00.000Z", lat: 37.5667, lon: 126.9782, marker: "TENANT_A_ONLY" },
    { id: "loc-a-04", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, recorded_at: "2026-11-19T04:00:00.000Z", lat: 37.5668, lon: 126.9783, marker: "TENANT_A_ONLY" },
    { id: "loc-a-05", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, recorded_at: "2026-11-19T05:00:00.000Z", lat: 37.5669, lon: 126.9784, marker: "TENANT_A_ONLY" },
    // Tenant B (5 rows)
    { id: "loc-b-01", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, recorded_at: "2026-11-19T01:00:00.000Z", lat: 35.6762, lon: 139.6503, marker: "TENANT_B_ONLY" },
    { id: "loc-b-02", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, recorded_at: "2026-11-19T02:00:00.000Z", lat: 35.6763, lon: 139.6504, marker: "TENANT_B_ONLY" },
    { id: "loc-b-03", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, recorded_at: "2026-11-19T03:00:00.000Z", lat: 35.6764, lon: 139.6505, marker: "TENANT_B_ONLY" },
    { id: "loc-b-04", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, recorded_at: "2026-11-19T04:00:00.000Z", lat: 35.6765, lon: 139.6506, marker: "TENANT_B_ONLY" },
    { id: "loc-b-05", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, recorded_at: "2026-11-19T05:00:00.000Z", lat: 35.6766, lon: 139.6507, marker: "TENANT_B_ONLY" },
  ];

  // Usage Daily: exactly 5 for Tenant A, 5 for Tenant B
  const usageDaily: Row[] = [
    // Tenant A (5 rows)
    { id: "use-a-01", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, day: "2026-11-15", package_name: "com.example.app1", screen_time_seconds: 1200, marker: "TENANT_A_ONLY" },
    { id: "use-a-02", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, day: "2026-11-16", package_name: "com.example.app2", screen_time_seconds: 1800, marker: "TENANT_A_ONLY" },
    { id: "use-a-03", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, day: "2026-11-17", package_name: "com.example.app3", screen_time_seconds: 2400, marker: "TENANT_A_ONLY" },
    { id: "use-a-04", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, day: "2026-11-18", package_name: "com.example.app4", screen_time_seconds: 900, marker: "TENANT_A_ONLY" },
    { id: "use-a-05", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, day: "2026-11-19", package_name: "com.example.app5", screen_time_seconds: 3600, marker: "TENANT_A_ONLY" },
    // Tenant B (5 rows)
    { id: "use-b-01", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, day: "2026-11-15", package_name: "com.victim.app1", screen_time_seconds: 1500, marker: "TENANT_B_ONLY" },
    { id: "use-b-02", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, day: "2026-11-16", package_name: "com.victim.app2", screen_time_seconds: 2100, marker: "TENANT_B_ONLY" },
    { id: "use-b-03", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, day: "2026-11-17", package_name: "com.victim.app3", screen_time_seconds: 3000, marker: "TENANT_B_ONLY" },
    { id: "use-b-04", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, day: "2026-11-18", package_name: "com.victim.app4", screen_time_seconds: 800, marker: "TENANT_B_ONLY" },
    { id: "use-b-05", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, day: "2026-11-19", package_name: "com.victim.app5", screen_time_seconds: 4000, marker: "TENANT_B_ONLY" },
  ];

  // Safety Alerts: exactly 3 for Tenant A, 3 for Tenant B
  const safetyAlerts: Row[] = [
    // Tenant A (3 rows)
    { id: "alert-a-01", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, created_at: "2026-11-18T10:00:00.000Z", alert_type: "geofence_exit", severity: "high", marker: "TENANT_A_ONLY" },
    { id: "alert-a-02", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, created_at: "2026-11-19T11:00:00.000Z", alert_type: "battery_low", severity: "low", marker: "TENANT_A_ONLY" },
    { id: "alert-a-03", family_id: FAMILY_A_ID, device_id: DEVICE_A_ID, created_at: "2026-11-20T12:00:00.000Z", alert_type: "tamper_detected", severity: "critical", marker: "TENANT_A_ONLY" },
    // Tenant B (3 rows)
    { id: "alert-b-01", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, created_at: "2026-11-18T10:00:00.000Z", alert_type: "geofence_exit", severity: "medium", marker: "TENANT_B_ONLY" },
    { id: "alert-b-02", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, created_at: "2026-11-19T11:00:00.000Z", alert_type: "speeding", severity: "high", marker: "TENANT_B_ONLY" },
    { id: "alert-b-03", family_id: FAMILY_B_ID, device_id: DEVICE_B_ID, created_at: "2026-11-20T12:00:00.000Z", alert_type: "content_warning", severity: "medium", marker: "TENANT_B_ONLY" },
  ];

  // Audit Logs: 3 for Tenant A, 3 for Tenant B, plus 1 global sweep marker
  const auditLogs: Row[] = [
    // Tenant A (3 rows: 2 parent events, 1 child device event)
    { id: "audit-a-01", family_id: FAMILY_A_ID, actor_user_id: USER_A_ID, device_id: null, event_type: "policy_updated", created_at: "2026-11-18T10:00:00.000Z", marker: "TENANT_A_ONLY" },
    { id: "audit-a-02", family_id: FAMILY_A_ID, actor_user_id: USER_A_ID, device_id: null, event_type: "member_invited", created_at: "2026-11-19T11:00:00.000Z", marker: "TENANT_A_ONLY" },
    { id: "audit-a-03", family_id: FAMILY_A_ID, actor_user_id: CHILD_A_ID, device_id: DEVICE_A_ID, event_type: "device_heartbeat", created_at: "2026-11-20T12:00:00.000Z", marker: "TENANT_A_ONLY" },
    // Tenant B (3 rows)
    { id: "audit-b-01", family_id: FAMILY_B_ID, actor_user_id: USER_B_ID, device_id: null, event_type: "policy_updated", created_at: "2026-11-18T10:00:00.000Z", marker: "TENANT_B_ONLY" },
    { id: "audit-b-02", family_id: FAMILY_B_ID, actor_user_id: USER_B_ID, device_id: null, event_type: "member_invited", created_at: "2026-11-19T11:00:00.000Z", marker: "TENANT_B_ONLY" },
    { id: "audit-b-03", family_id: FAMILY_B_ID, actor_user_id: USER_B_ID, device_id: DEVICE_B_ID, event_type: "device_heartbeat", created_at: "2026-11-20T12:00:00.000Z", marker: "TENANT_B_ONLY" },
    // Global retention sweep marker (family_id: null)
    { id: "audit-sweep-01", family_id: null, actor_user_id: null, device_id: null, event_type: "retention_sweep", created_at: "2026-11-20T03:00:00.000Z", metadata: { purged_count: 42 }, marker: "GLOBAL_SWEEP" },
  ];

  const fake = fakePostgrest({
    profiles,
    families,
    family_members: familyMembers,
    devices,
    location_events: locationEvents,
    usage_daily: usageDaily,
    safety_alerts: safetyAlerts,
    audit_logs: auditLogs,
  });

  // Configure authentication tokens
  fake.setTokenUser(TOKEN_USER_A, { id: USER_A_ID, email: USER_A_EMAIL, email_confirmed_at: "2026-01-01T00:00:00.000Z" });
  fake.setTokenUser(TOKEN_USER_B, { id: USER_B_ID, email: USER_B_EMAIL, email_confirmed_at: "2026-01-01T00:00:00.000Z" });
  fake.setTokenUser(TOKEN_CHILD_A, { id: CHILD_A_ID, email: CHILD_A_EMAIL, email_confirmed_at: "2026-01-01T00:00:00.000Z" });
  fake.setTokenUser(TOKEN_STRANGER, { id: STRANGER_ID, email: STRANGER_EMAIL, email_confirmed_at: "2026-01-01T00:00:00.000Z" });
  fake.setTokenUser(TOKEN_INACTIVE, { id: INACTIVE_USER_ID, email: INACTIVE_USER_EMAIL, email_confirmed_at: "2026-01-01T00:00:00.000Z" });

  return fake;
}

// =============================================================================
// CT-01: Baseline Isolation (Export)
// =============================================================================
Deno.test("CT-01: Baseline Isolation — User A export strictly isolates Tenant A data from Tenant B", async () => {
  const fake = setupTwoTenantWorld();
  const req = makeRequest({ action: "export" }, TOKEN_USER_A);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  assert(res.headers.get("Content-Disposition")?.includes("attachment"));

  const data = await parseExportPayload(res);
  assertEquals(data.scope, "family");

  // Account identity
  const account = data.account as Record<string, unknown>;
  assertEquals(account.user_id, USER_A_ID);
  assertEquals(account.email, USER_A_EMAIL);

  // Families: only Family A and Family C (User A is active member), ZERO Family B
  const families = data.families as Array<Record<string, unknown>>;
  const familyIds = families.map((f) => f.id);
  assert(familyIds.includes(FAMILY_A_ID), "Must include Family A");
  assert(!familyIds.includes(FAMILY_B_ID), "Must NEVER include Family B");

  // Devices: only Device A, ZERO Device B
  const devices = data.devices as Array<Record<string, unknown>>;
  assertEquals(devices.length, 1);
  assertEquals(devices[0].id, DEVICE_A_ID);

  // Tables verification: check each table for exact row counts and tenant markers
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>>; row_count: number }>;

  // Location events: exactly 5 Tenant A rows, 0 Tenant B
  assertEquals(tables.location_events.row_count, 5);
  for (const row of tables.location_events.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assertEquals(row.marker, "TENANT_A_ONLY");
    assert(row.marker !== "TENANT_B_ONLY", "Must not contain Tenant B location events");
  }

  // Usage daily: exactly 5 Tenant A rows, 0 Tenant B
  assertEquals(tables.usage_daily.row_count, 5);
  for (const row of tables.usage_daily.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assertEquals(row.marker, "TENANT_A_ONLY");
    assert(row.marker !== "TENANT_B_ONLY", "Must not contain Tenant B usage rows");
  }

  // Safety alerts: exactly 3 Tenant A rows, 0 Tenant B
  assertEquals(tables.safety_alerts.row_count, 3);
  for (const row of tables.safety_alerts.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assertEquals(row.marker, "TENANT_A_ONLY");
    assert(row.marker !== "TENANT_B_ONLY", "Must not contain Tenant B safety alerts");
  }

  // Audit logs: exactly 3 Tenant A rows, 0 Tenant B, 0 global sweep
  assertEquals(tables.audit_logs.row_count, 3);
  for (const row of tables.audit_logs.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assertEquals(row.marker, "TENANT_A_ONLY");
    assert(row.marker !== "TENANT_B_ONLY", "Must not contain Tenant B audit logs");
    assert(row.marker !== "GLOBAL_SWEEP", "Must not contain global sweep markers");
  }
});

// =============================================================================
// CT-02: Adversarial Injected Family ID in Export
// =============================================================================
Deno.test("CT-02: Adversarial Injected Family ID in Export — Injected family_id is ignored", async () => {
  const fake = setupTwoTenantWorld();
  // Adversary supplies User B's family ID in request body
  const req = makeRequest(
    {
      action: "export",
      family_id: FAMILY_B_ID,
      target_family: FAMILY_B_ID,
      injected_filter: { "$ne": null },
    },
    TOKEN_USER_A,
  );
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>>; row_count: number }>;

  // Assert that injected family_id was completely ignored and 0 Tenant B rows leaked
  for (const row of tables.location_events.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assert(row.family_id !== FAMILY_B_ID, "Injected family_id MUST NOT leak foreign data");
  }
  for (const row of tables.usage_daily.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assert(row.family_id !== FAMILY_B_ID, "Injected family_id MUST NOT leak foreign data");
  }
  for (const row of tables.safety_alerts.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assert(row.family_id !== FAMILY_B_ID, "Injected family_id MUST NOT leak foreign data");
  }
  for (const row of tables.audit_logs.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assert(row.family_id !== FAMILY_B_ID, "Injected family_id MUST NOT leak foreign data");
  }
});

// =============================================================================
// CT-03: Adversarial Injected Family ID in Retention Report
// =============================================================================
Deno.test("CT-03: Adversarial Injected Family ID in Retention Report — Injected family_id is ignored", async () => {
  const fake = setupTwoTenantWorld();
  // Adversary supplies Tenant B's family ID to retention_report
  const req = makeRequest(
    {
      action: "retention_report",
      family_id: FAMILY_B_ID,
      extra_param: "malicious_probe",
    },
    TOKEN_USER_A,
  );
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const envelope = await parseEnvelope<Record<string, unknown>>(res);
  assertEquals(envelope.ok, true);

  const data = envelope.data!;
  assertEquals(data.scope, "family");

  // Families in retention report should strictly be User A's authorized families
  const families = data.families as Array<Record<string, unknown>>;
  const familyIds = families.map((f) => (f.family_id ?? f.id) as string);
  assert(familyIds.includes(FAMILY_A_ID), "Must include Family A");
  assert(!familyIds.includes(FAMILY_B_ID), "Must NEVER include Family B in retention report");
});

// =============================================================================
// CT-04: Inactive / Revoked Membership Isolation
// =============================================================================
Deno.test("CT-04: Inactive / Revoked Membership Isolation — Suspended user receives empty scope", async () => {
  const fake = setupTwoTenantWorld();
  // User whose only membership is 'suspended'
  const req = makeRequest({ action: "export" }, TOKEN_INACTIVE);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);

  // Scope must be 'not_reported'
  assertEquals(data.scope, "not_reported");

  // Families must be empty
  const families = data.families as Array<unknown>;
  assertEquals(families.length, 0);

  // Devices must be empty
  const devices = data.devices as Array<unknown>;
  assertEquals(devices.length, 0);

  // All tables must return 0 rows
  const tables = data.tables as Record<string, { rows: Array<unknown>; row_count: number }>;
  assertEquals(tables.location_events.row_count, 0);
  assertEquals(tables.location_events.rows.length, 0);
  assertEquals(tables.usage_daily.row_count, 0);
  assertEquals(tables.usage_daily.rows.length, 0);
  assertEquals(tables.safety_alerts.row_count, 0);
  assertEquals(tables.safety_alerts.rows.length, 0);
  assertEquals(tables.audit_logs.row_count, 0);
  assertEquals(tables.audit_logs.rows.length, 0);
});

// =============================================================================
// CT-05: Child Role Isolation & Audit Log Partitioning
// =============================================================================
Deno.test("CT-05: Child Role Isolation — Scope is device, parent audit logs excluded", async () => {
  const fake = setupTwoTenantWorld();
  const req = makeRequest({ action: "export" }, TOKEN_CHILD_A);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  assertEquals(data.scope, "device");

  // Child should only see their assigned device
  const devices = data.devices as Array<Record<string, unknown>>;
  assertEquals(devices.length, 1);
  assertEquals(devices[0].id, DEVICE_A_ID);
  assertEquals(devices[0].child_user_id, CHILD_A_ID);

  // Tables should be filtered to Child A's device
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>>; row_count: number }>;
  for (const row of tables.location_events.rows) {
    assertEquals(row.device_id, DEVICE_A_ID);
  }
  for (const row of tables.usage_daily.rows) {
    assertEquals(row.device_id, DEVICE_A_ID);
  }

  // Audit logs partitioning: Child must only see logs where actor == CHILD_A_ID or device == DEVICE_A_ID
  // In our fixture, audit-a-01 and audit-a-02 are parent-only events (actor: USER_A_ID, device_id: null).
  // audit-a-03 is a child device event (actor: CHILD_A_ID, device_id: DEVICE_A_ID).
  assertEquals(tables.audit_logs.row_count, 1);
  assertEquals(tables.audit_logs.rows[0].id, "audit-a-03");
  assertEquals(tables.audit_logs.rows[0].actor_user_id, CHILD_A_ID);
});

// =============================================================================
// CT-06: Multi-Membership Scope Isolation
// =============================================================================
Deno.test("CT-06: Multi-Membership Scope Isolation — Multi-family parent sees own families only", async () => {
  const fake = setupTwoTenantWorld();
  // Add a location event specifically in Family C for User A
  fake.rows.location_events.push({
    id: "loc-c-01",
    family_id: FAMILY_C_ID,
    device_id: "devc-test",
    recorded_at: "2026-11-19T06:00:00.000Z",
    lat: 37.0,
    lon: 127.0,
    marker: "FAMILY_C_ROW",
  });

  const req = makeRequest({ action: "export" }, TOKEN_USER_A);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  const families = data.families as Array<Record<string, unknown>>;
  const familyIds = families.map((f) => f.id);

  assert(familyIds.includes(FAMILY_A_ID), "Must include Family A");
  assert(familyIds.includes(FAMILY_C_ID), "Must include Family C");
  assert(!familyIds.includes(FAMILY_B_ID), "Must NOT include Family B");

  // Check location events: includes Family A and Family C, ZERO Family B
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>> }>;
  const eventFamilyIds = tables.location_events.rows.map((r) => r.family_id);
  assert(eventFamilyIds.includes(FAMILY_A_ID));
  assert(eventFamilyIds.includes(FAMILY_C_ID));
  assert(!eventFamilyIds.includes(FAMILY_B_ID));
});

// =============================================================================
// CT-07: Empty Scope Fail-Closed Verification (NO_MATCH_UUID)
// =============================================================================
Deno.test("CT-07: Empty Scope Fail-Closed Verification — Stranger with 0 memberships gets 0 rows", async () => {
  const fake = setupTwoTenantWorld();
  const req = makeRequest({ action: "export" }, TOKEN_STRANGER);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  assertEquals(data.scope, "not_reported");
  assertEquals((data.families as Array<unknown>).length, 0);
  assertEquals((data.devices as Array<unknown>).length, 0);

  const tables = data.tables as Record<string, { rows: Array<unknown>; row_count: number }>;
  assertEquals(tables.location_events.row_count, 0);
  assertEquals(tables.usage_daily.row_count, 0);
  assertEquals(tables.safety_alerts.row_count, 0);
  assertEquals(tables.audit_logs.row_count, 0);

  // Verify that database calls executed eq("family_id", NO_MATCH_UUID)
  const noMatchCalls = fake.log.filter((c) =>
    c.filters.some((f) => f.value === "00000000-0000-0000-0000-000000000000"),
  );
  assert(noMatchCalls.length > 0, "Handler must activate NO_MATCH_UUID fail-closed filter");
});

// =============================================================================
// CT-08: Adversarial Injected Device ID in Export
// =============================================================================
Deno.test("CT-08: Adversarial Injected Device ID in Export — Injected device_id is ignored", async () => {
  const fake = setupTwoTenantWorld();
  // Child A attempts to pass Tenant B's device ID in body
  const req = makeRequest(
    {
      action: "export",
      device_id: DEVICE_B_ID,
      injected_device: DEVICE_B_ID,
    },
    TOKEN_CHILD_A,
  );
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  assertEquals(data.scope, "device");

  // Child A must only see DEVICE_A_ID, never DEVICE_B_ID
  const devices = data.devices as Array<Record<string, unknown>>;
  assertEquals(devices.length, 1);
  assertEquals(devices[0].id, DEVICE_A_ID);
  assert(devices[0].id !== DEVICE_B_ID);

  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>> }>;
  for (const row of tables.location_events.rows) {
    assertEquals(row.device_id, DEVICE_A_ID);
    assert(row.device_id !== DEVICE_B_ID);
  }
});

// =============================================================================
// CT-09: Audit Log Query Isolation & Sweep Marker Leak Prevention
// =============================================================================
Deno.test("CT-09: Audit Log Query Isolation — Global sweep marker with family_id=null is not leaked", async () => {
  const fake = setupTwoTenantWorld();
  const req = makeRequest({ action: "export" }, TOKEN_USER_A);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>> }>;

  // Audit logs returned to User A
  const auditLogs = tables.audit_logs.rows;
  assertEquals(auditLogs.length, 3);

  // Verify none of the returned logs is the global sweep marker
  const sweepLog = auditLogs.find((log) => log.event_type === "retention_sweep" || log.marker === "GLOBAL_SWEEP");
  assertEquals(sweepLog, undefined, "Global sweep marker MUST NOT appear in export audit logs");

  // Verify all returned logs have family_id == FAMILY_A_ID
  for (const log of auditLogs) {
    assertEquals(log.family_id, FAMILY_A_ID);
    assert(log.family_id !== null, "Audit logs in export must have non-null family_id");
  }
});

// =============================================================================
// CT-10: Pagination & Row-Cap Isolation Across Interleaved Records
// =============================================================================
Deno.test("CT-10: Pagination & Row-Cap Isolation — Multi-page fetch preserves tenant isolation", async () => {
  const fake = setupTwoTenantWorld();

  // Clear existing location events and seed 1,050 Tenant A rows interleaved with 500 Tenant B rows
  fake.rows.location_events.length = 0;

  const totalA = 1050;
  const totalB = 500;
  for (let i = 0; i < totalA; i++) {
    fake.rows.location_events.push({
      id: `loc-a-paged-${String(i).padStart(5, "0")}`,
      family_id: FAMILY_A_ID,
      device_id: DEVICE_A_ID,
      recorded_at: new Date(Date.parse("2026-11-20T00:00:00.000Z") - i * 1000).toISOString(),
      marker: "TENANT_A_PAGED",
    });
    // Interleave Tenant B rows
    if (i < totalB) {
      fake.rows.location_events.push({
        id: `loc-b-paged-${String(i).padStart(5, "0")}`,
        family_id: FAMILY_B_ID,
        device_id: DEVICE_B_ID,
        recorded_at: new Date(Date.parse("2026-11-20T00:00:00.000Z") - i * 1000).toISOString(),
        marker: "TENANT_B_PAGED",
      });
    }
  }

  const req = makeRequest({ action: "export" }, TOKEN_USER_A);
  const res = await handleAccountRequest(req, { db: fake.asClient() });

  assertEquals(res.status, 200);
  const data = await parseExportPayload(res);
  const tables = data.tables as Record<string, { rows: Array<Record<string, unknown>>; row_count: number; truncated: boolean }>;

  // Assert exactly 1,050 Tenant A rows fetched across page boundaries (Page 1: 1000, Page 2: 50)
  assertEquals(tables.location_events.row_count, 1050);
  assertEquals(tables.location_events.truncated, false);
  assertEquals(tables.location_events.rows.length, 1050);

  // Assert every single row belongs to Tenant A, ZERO Tenant B rows leaked
  for (const row of tables.location_events.rows) {
    assertEquals(row.family_id, FAMILY_A_ID);
    assertEquals(row.marker, "TENANT_A_PAGED");
    assert(row.marker !== "TENANT_B_PAGED", "Must never leak Tenant B paged rows");
  }
});
