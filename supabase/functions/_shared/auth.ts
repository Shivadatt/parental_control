// Authentication and authorization helpers for Edge Functions.
// User identity always comes from a verified JWT; device identity always comes
// from x-device-id + x-device-secret with a constant-time SHA-256 comparison.
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2";
import { ApiError, ensureNoError } from "./envelope.ts";
import {
  constantTimeEqualHex,
  isUuid,
  sha256Hex,
} from "./validation.ts";

export type Role = "unset" | "parent" | "child";

export interface ProfileRow {
  id: string;
  role: Role;
  display_name: string;
}

export interface AuthContext {
  user: User;
  profile: ProfileRow;
  emailVerified: boolean;
  accessToken: string;
}

export interface DeviceRow {
  id: string;
  family_id: string;
  child_user_id: string;
  secret_hash: string | null;
  status: "pending" | "active" | "revoked";
  credential_revoked_at: string | null;
  display_name: string;
  policy_version: number;
  last_seen_at: string | null;
  battery_level: number | null;
  is_charging: boolean | null;
  enforcement_mode: "none" | "device_admin" | "device_owner";
}

let cachedClient: SupabaseClient | null = null;

/** Service-role client. Called only from Edge Functions server-side. */
export function getServiceClient(): SupabaseClient {
  if (cachedClient) return cachedClient;
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new ApiError(
      "server_misconfigured",
      "The backend is missing required server configuration.",
      503,
    );
  }
  cachedClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "X-Client-Info": "parentcontrol-edge/1" } },
  });
  return cachedClient;
}

function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match || match[1].length < 20) {
    throw new ApiError("unauthorized", "Sign in to continue.", 401);
  }
  return match[1];
}

/**
 * Validates the caller JWT with Supabase Auth, loads the profile and (when
 * requested) requires a confirmed email address.
 */
export async function requireUser(
  req: Request,
  db: SupabaseClient,
  options: { requireVerifiedEmail?: boolean } = {},
): Promise<AuthContext> {
  const token = bearerToken(req);
  let user: User | null = null;
  try {
    const { data, error } = await db.auth.getUser(token);
    if (error) {
      throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
    }
    user = data.user;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
  }
  if (!user) {
    throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
  }

  const profileResult = await db
    .from("profiles")
    .select("id, role, display_name")
    .eq("id", user.id)
    .maybeSingle();
  ensureNoError(profileResult);
  const row = profileResult.data as ProfileRow | null;
  if (!row) {
    throw new ApiError(
      "profile_missing",
      "The account profile is not ready yet. Try again shortly.",
      403,
    );
  }
  if (row.role !== "unset" && row.role !== "parent" && row.role !== "child") {
    throw new ApiError("profile_invalid", "The account profile is invalid.", 403);
  }
  const emailVerified = Boolean(user.email_confirmed_at);
  if (options.requireVerifiedEmail && !emailVerified) {
    throw new ApiError(
      "email_not_verified",
      "Confirm your email address before continuing.",
      403,
    );
  }
  return { user, profile: row, emailVerified, accessToken: token };
}

export function requireRole(profile: ProfileRow, role: "parent" | "child"): void {
  if (profile.role !== role) {
    throw new ApiError(
      "role_required",
      role === "parent"
        ? "A parent account is required for this action."
        : "A child account is required for this action.",
      403,
    );
  }
}

async function loadFamily(
  db: SupabaseClient,
  familyId: string,
): Promise<{ id: string; deleted_at: string | null }> {
  const { data, error } = await db
    .from("families")
    .select("id, deleted_at")
    .eq("id", familyId)
    .maybeSingle();
  ensureNoError({ error });
  if (!data || (data as { deleted_at: string | null }).deleted_at) {
    throw new ApiError("forbidden", "You do not have access to this family.", 403);
  }
  return data as { id: string; deleted_at: string | null };
}

export interface MembershipRow {
  id: string;
  family_id: string;
  user_id: string;
  role: "parent" | "child";
  status: "active" | "removed";
}

async function loadMembership(
  db: SupabaseClient,
  userId: string,
  familyId: string,
): Promise<MembershipRow | null> {
  const { data, error } = await db
    .from("family_members")
    .select("id, family_id, user_id, role, status")
    .eq("family_id", familyId)
    .eq("user_id", userId)
    .eq("status", "active")
    .maybeSingle();
  ensureNoError({ error });
  return (data as MembershipRow | null) ?? null;
}

export async function assertFamilyMember(
  db: SupabaseClient,
  userId: string,
  familyId: string,
): Promise<MembershipRow> {
  await loadFamily(db, familyId);
  const membership = await loadMembership(db, userId, familyId);
  if (!membership) {
    throw new ApiError("forbidden", "You do not have access to this family.", 403);
  }
  return membership;
}

export async function assertFamilyParent(
  db: SupabaseClient,
  userId: string,
  familyId: string,
): Promise<MembershipRow> {
  await loadFamily(db, familyId);
  const membership = await loadMembership(db, userId, familyId);
  if (!membership || membership.role !== "parent") {
    throw new ApiError("forbidden", "A parent in this family is required.", 403);
  }
  return membership;
}

export async function assertChildMembership(
  db: SupabaseClient,
  userId: string,
  familyId: string,
): Promise<MembershipRow> {
  await loadFamily(db, familyId);
  const membership = await loadMembership(db, userId, familyId);
  if (!membership || membership.role !== "child") {
    throw new ApiError(
      "forbidden",
      "An active child membership in this family is required.",
      403,
    );
  }
  return membership;
}

export async function assertFamilyOwner(
  db: SupabaseClient,
  userId: string,
  familyId: string,
): Promise<{ id: string; owner_id: string; settings: Record<string, unknown> }> {
  const { data, error } = await db
    .from("families")
    .select("id, owner_id, settings, deleted_at")
    .eq("id", familyId)
    .maybeSingle();
  ensureNoError({ error });
  const family = data as
    | { id: string; owner_id: string; settings: Record<string, unknown>; deleted_at: string | null }
    | null;
  if (!family || family.deleted_at) {
    throw new ApiError("forbidden", "You do not have access to this family.", 403);
  }
  await assertFamilyParent(db, userId, familyId);
  if (family.owner_id !== userId) {
    throw new ApiError(
      "owner_required",
      "Only the family owner can change this setting.",
      403,
    );
  }
  return family;
}

/** Loads an active device and verifies that the caller is a parent in its family. */
export async function requireActiveDeviceForParent(
  db: SupabaseClient,
  userId: string,
  deviceId: string,
): Promise<DeviceRow> {
  const { data, error } = await db
    .from("devices")
    .select(
      "id, family_id, child_user_id, secret_hash, status, credential_revoked_at, display_name, policy_version, last_seen_at, battery_level, is_charging, enforcement_mode",
    )
    .eq("id", deviceId)
    .maybeSingle();
  ensureNoError({ error });
  const device = data as DeviceRow | null;
  if (!device) {
    throw new ApiError("device_not_found", "The device was not found.", 404);
  }
  await assertFamilyParent(db, userId, device.family_id);
  if (device.status !== "active") {
    throw new ApiError("device_not_active", "The device is not active.", 403);
  }
  return device;
}

/**
 * Device proof: x-device-id + x-device-secret. A user JWT or device id alone is
 * never accepted.
 */
export async function requireDevice(
  req: Request,
  db: SupabaseClient,
): Promise<DeviceRow> {
  const deviceId = req.headers.get("x-device-id") ?? "";
  const secret = req.headers.get("x-device-secret") ?? "";
  if (!deviceId || !secret) {
    throw new ApiError(
      "device_auth_required",
      "Device credentials are required.",
      401,
    );
  }
  if (!isUuid(deviceId) || secret.length < 16 || secret.length > 512) {
    throw new ApiError(
      "invalid_device_credentials",
      "Device credentials are not valid.",
      401,
    );
  }

  const { data, error } = await db
    .from("devices")
    .select(
      "id, family_id, child_user_id, secret_hash, status, credential_revoked_at, display_name, policy_version, last_seen_at, battery_level, is_charging, enforcement_mode",
    )
    .eq("id", deviceId)
    .maybeSingle();
  ensureNoError({ error });
  const device = data as DeviceRow | null;

  const digest = await sha256Hex(secret);
  if (!device || !device.secret_hash) {
    // Still run a comparison so unknown ids and wrong secrets are similar.
    constantTimeEqualHex(digest, "0".repeat(64));
    throw new ApiError(
      "invalid_device_credentials",
      "Device credentials are not valid.",
      401,
    );
  }
  if (!constantTimeEqualHex(digest, device.secret_hash)) {
    throw new ApiError(
      "invalid_device_credentials",
      "Device credentials are not valid.",
      401,
    );
  }
  if (device.status !== "active" || device.credential_revoked_at !== null) {
    throw new ApiError(
      "device_revoked",
      "This device credential was revoked. Link the device again.",
      403,
    );
  }
  return device;
}
