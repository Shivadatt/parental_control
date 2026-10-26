// device-register: child account enrolls its Android installation.
import { preflightResponse } from "../_shared/cors.ts";
import {
  ApiError,
  ensureNoError,
  errorResponse,
  ok,
  readJson,
  requireAction,
} from "../_shared/envelope.ts";
import {
  assertChildMembership,
  getServiceClient,
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import { requiresRelink } from "../_shared/enrollment.ts";
import {
  readHex64,
  readInstallationId,
  readOptionalString,
  readString,
  readUuid,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

interface DeviceRowFull {
  id: string;
  family_id: string;
  child_user_id: string;
  installation_id: string;
  status: string;
  credential_revoked_at: string | null;
}

interface RevokedDeviceRow {
  id: string;
  credential_revoked_at: string | null;
}

// Never return secret_hash; installation_id is service-only by the column
// grants and the client already knows its own installation id.
function publicDevice(row: unknown): Record<string, unknown> {
  const safe = { ...(row as Record<string, unknown>) };
  delete safe.secret_hash;
  delete safe.installation_id;
  return safe;
}

// A revoked child device may only be replaced after the parent removes the
// child and approves a new pairing request; the child cannot self-clear it.
async function assertReenrollmentAllowed(
  db: SupabaseClient,
  familyId: string,
  childUserId: string,
  actorUserId: string,
): Promise<void> {
  const revokedResult = await db
    .from("devices")
    .select("id, credential_revoked_at")
    .eq("family_id", familyId)
    .eq("child_user_id", childUserId)
    .eq("status", "revoked")
    .order("credential_revoked_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  ensureNoError(revokedResult);
  const revoked = revokedResult.data as RevokedDeviceRow | null;
  if (!revoked) return;

  const approvalResult = await db
    .from("pairing_requests")
    .select("responded_at")
    .eq("family_id", familyId)
    .eq("child_user_id", childUserId)
    .eq("status", "approved")
    .order("responded_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  ensureNoError(approvalResult);
  const approved = approvalResult.data as { responded_at: string | null } | null;

  if (!requiresRelink(revoked.credential_revoked_at, approved?.responded_at)) {
    return;
  }

  await recordAudit(db, {
    familyId,
    actorUserId,
    deviceId: revoked.id,
    eventType: "device_registration_blocked",
    targetType: "device",
    targetId: revoked.id,
    metadata: { reason: "device_revoked_relink_required" },
  });
  throw new ApiError(
    "device_revoked",
    "This child's device was revoked. A parent must remove and re-link this child before another device can be enrolled.",
    403,
  );
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

    if (action !== "register") {
      throw new ApiError("unknown_action", "Unsupported action.", 400);
    }

    const auth = await requireUser(req, db, { requireVerifiedEmail: true });
    requireRole(auth.profile, "child");

    const familyId = readUuid(body.family_id, "family_id");
    const installationId = readInstallationId(body.installation_id);
    const secretHash = readHex64(body.secret_hash, "secret_hash");
    const displayName = readString(body.display_name, "display_name", {
      min: 1,
      max: 60,
    });
    const platform = readOptionalString(body.platform, "platform", {
      min: 1,
      max: 32,
    }) ?? "android";
    const androidVersion = readOptionalString(body.android_version, "android_version", {
      min: 1,
      max: 40,
    });
    const appVersion = readOptionalString(body.app_version, "app_version", {
      min: 1,
      max: 40,
    });

    await assertChildMembership(db, auth.user.id, familyId);

    const existingResult = await db
      .from("devices")
      .select(
        "id, family_id, child_user_id, installation_id, status, credential_revoked_at",
      )
      .eq("family_id", familyId)
      .eq("installation_id", installationId)
      .maybeSingle();
    ensureNoError(existingResult);
    const existing = existingResult.data as DeviceRowFull | null;

    const nowIso = new Date().toISOString();
    const patch: Record<string, unknown> = {
      secret_hash: secretHash,
      credential_issued_at: nowIso,
      credential_revoked_at: null,
      status: "active",
      display_name: displayName,
      platform,
      android_version: androidVersion ?? null,
      app_version: appVersion ?? null,
    };

    if (existing) {
      if (existing.child_user_id !== auth.user.id) {
        throw new ApiError(
          "device_exists",
          "This installation is registered to another account.",
          409,
        );
      }
      if (existing.status === "revoked") {
        await assertReenrollmentAllowed(db, familyId, auth.user.id, auth.user.id);
      }

      const updated = await db
        .from("devices")
        .update(patch)
        .eq("id", existing.id)
        .select("*")
        .single();
      ensureNoError(updated);

      await recordAudit(db, {
        familyId,
        actorUserId: auth.user.id,
        deviceId: existing.id,
        eventType: "device_recredentialed",
        targetType: "device",
        targetId: existing.id,
      });
      return ok(publicDevice(updated.data));
    }

    const activeDevice = await db
      .from("devices")
      .select("id")
      .eq("child_user_id", auth.user.id)
      .eq("status", "active")
      .maybeSingle();
    ensureNoError(activeDevice);
    if (activeDevice.data) {
      throw new ApiError(
        "device_already_registered",
        "This account already has an active device.",
        409,
      );
    }

    await assertReenrollmentAllowed(db, familyId, auth.user.id, auth.user.id);

    const inserted = await db
      .from("devices")
      .insert({
        family_id: familyId,
        child_user_id: auth.user.id,
        installation_id: installationId,
        ...patch,
      })
      .select("*")
      .single();
    if (inserted.error) {
      if (inserted.error.code === "23505") {
        throw new ApiError(
          "device_already_registered",
          "This account or installation is already registered.",
          409,
        );
      }
      console.error(`device_insert_failed:${inserted.error.code ?? "unknown"}`);
      throw new ApiError("internal_error", "The device could not be registered.", 500);
    }
    const device = inserted.data as DeviceRowFull;

    await recordAudit(db, {
      familyId,
      actorUserId: auth.user.id,
      deviceId: device.id,
      eventType: "device_registered",
      targetType: "device",
      targetId: device.id,
    });
    return ok(publicDevice(inserted.data));
  } catch (error) {
    return errorResponse(error);
  }
});
