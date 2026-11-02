// family-admin: device revoke, alert acknowledgement, data purge, retention.
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
  assertFamilyOwner,
  assertFamilyParent,
  getServiceClient,
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import { readInteger, readUuid } from "../_shared/validation.ts";
import { canDeleteZone, canPurge } from "./authorization.ts";
import {
  auditZoneDeletion,
  buildZoneAuditInsert,
  type ZoneDeleteStore,
  type ZoneSnapshot,
} from "./delete_zone_atomicity.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const DAY_MS = 24 * 60 * 60 * 1000;

async function familySettings(
  db: SupabaseClient,
  familyId: string,
): Promise<{ location_retention_days: number; usage_retention_days: number }> {
  const result = await db
    .from("families")
    .select("settings")
    .eq("id", familyId)
    .maybeSingle();
  ensureNoError(result);
  const raw = (result.data as { settings?: Record<string, unknown> } | null)
    ?.settings ?? {};
  const location = Number(raw.location_retention_days);
  const usage = Number(raw.usage_retention_days);
  return {
    location_retention_days: Number.isInteger(location) && location > 0 ? location : 30,
    usage_retention_days: Number.isInteger(usage) && usage > 0 ? usage : 90,
  };
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

    switch (action) {
      case "revoke_device": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const deviceId = readUuid(body.device_id, "device_id");
        const rpc = await db.rpc("revoke_device", {
          p_device_id: deviceId,
          p_actor_user_id: auth.user.id,
        });
        if (rpc.error) {
          const message = rpc.error.message ?? "";
          if (message.includes("device_not_found")) {
            throw new ApiError("device_not_found", "The device was not found.", 404);
          }
          if (message.includes("forbidden")) {
            throw new ApiError(
              "forbidden",
              "A parent in this family is required.",
              403,
            );
          }
          // Raised by the public wrapper's membership check (migration
          // 20261030000200); the RPC no longer trusts the actor id it is given.
          if (message.includes("not_family_parent")) {
            throw new ApiError(
              "forbidden",
              "A parent in this family is required.",
              403,
            );
          }
          console.error(`revoke_device_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError("internal_error", "The device could not be revoked.", 500);
        }
        return ok(rpc.data);
      }

      case "recover_device": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const deviceId = readUuid(body.device_id, "device_id");
        const rpc = await db.rpc("request_device_recovery", {
          p_device_id: deviceId,
          p_actor_user_id: auth.user.id,
        });
        if (rpc.error) {
          const message = rpc.error.message ?? "";
          if (message.includes("device_not_found")) {
            throw new ApiError("device_not_found", "The device was not found.", 404);
          }
          if (message.includes("forbidden")) {
            throw new ApiError(
              "forbidden",
              "A parent in this family is required.",
              403,
            );
          }
          console.error(
            `request_device_recovery_rpc_failed:${rpc.error.code ?? "unknown"}`,
          );
          throw new ApiError(
            "internal_error",
            "Device recovery could not be started.",
            500,
          );
        }
        return ok(rpc.data);
      }

      case "ack_alert": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const alertId = readUuid(body.alert_id, "alert_id");

        const result = await db
          .from("safety_alerts")
          .select("*")
          .eq("id", alertId)
          .maybeSingle();
        ensureNoError(result);
        const alert = result.data as Record<string, unknown> | null;
        if (!alert) {
          throw new ApiError("alert_not_found", "The alert was not found.", 404);
        }
        const familyId = String(alert.family_id ?? "");
        await assertFamilyParent(db, auth.user.id, familyId);
        if (alert.acknowledged_at) {
          return ok(alert);
        }
        const updated = await db
          .from("safety_alerts")
          .update({
            acknowledged_at: new Date().toISOString(),
            acknowledged_by: auth.user.id,
          })
          .eq("id", alertId)
          .is("acknowledged_at", null)
          .select("*")
          .maybeSingle();
        ensureNoError(updated);
        const finalAlert = (updated.data as Record<string, unknown> | null) ?? alert;

        await recordAudit(db, {
          familyId,
          actorUserId: auth.user.id,
          eventType: "alert_acknowledged",
          targetType: "safety_alert",
          targetId: alertId,
          metadata: { alert_type: alert.type ?? null },
        });
        return ok(finalAlert);
      }

      // Replaces the client-side safe_zones DELETE, which migration
      // 20261030000200 revokes. Any active parent of the zone's family may
      // delete; every deletion is audited. Post-delete audit handling
      // (bounded retries, compensating restore, explicit failure surface)
      // is decided in delete_zone_atomicity.ts — SQL-05: a failed audit
      // insert must not silently leave an unaudited deletion.
      case "delete_zone": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const zoneId = readUuid(body.zone_id, "zone_id");

        // The full row, not just id/family/name: a failed audit insert is
        // compensated by restoring this exact snapshot (delete_zone_atomicity.ts).
        const existing = await db
          .from("safe_zones")
          .select(
            "id, family_id, name, lat, lng, radius_m, active, created_by, created_at",
          )
          .eq("id", zoneId)
          .maybeSingle();
        ensureNoError(existing);
        const zone = existing.data as ZoneSnapshot | null;
        if (!zone) {
          throw new ApiError(
            "zone_not_found",
            "The safe zone was not found.",
            404,
          );
        }

        const membership = await assertFamilyParent(
          db,
          auth.user.id,
          zone.family_id,
        );
        if (!canDeleteZone(auth.profile.role, membership.role === "parent")) {
          throw new ApiError(
            "forbidden",
            "A parent in this family is required.",
            403,
          );
        }

        const deleted = await db
          .from("safe_zones")
          .delete({ count: "exact" })
          .eq("id", zoneId)
          .eq("family_id", zone.family_id);
        ensureNoError(deleted);

        // A concurrent delete of the same zone is not an error: the caller's
        // postcondition holds. Only an actual removal is audited.
        if ((deleted.count ?? 0) > 0) {
          const store: ZoneDeleteStore = {
            insertAudit: async (row) =>
              (await db.from("audit_logs").insert(row)).error ?? null,
            restoreZone: async (snapshot) =>
              (
                await db.from("safe_zones").insert({
                  id: snapshot.id,
                  family_id: snapshot.family_id,
                  name: snapshot.name,
                  lat: snapshot.lat,
                  lng: snapshot.lng,
                  radius_m: snapshot.radius_m,
                  active: snapshot.active,
                  created_by: snapshot.created_by,
                  created_at: snapshot.created_at,
                })
              ).error ?? null,
          };
          const outcome = await auditZoneDeletion(
            store,
            buildZoneAuditInsert(zone, auth.user.id),
            zone,
          );
          if (outcome.kind === "restored") {
            // Net effect: the zone still exists. Say so; do not claim a delete.
            console.error(`zone_delete_reverted:${zone.id}`);
            throw new ApiError(
              "audit_failed",
              "The deletion could not be recorded in the audit log, so the safe zone was kept. Try again.",
              500,
              { zone_restored: true },
            );
          }
          if (outcome.kind === "unaudited_delete") {
            // The zone is gone and no audit row could be written or reverted.
            // Surface it explicitly — never respond {deleted: true} here.
            console.error(
              `zone_delete_unaudited:${outcome.auditErrorCode ?? "unknown"}:${zone.id}`,
            );
            throw new ApiError(
              "audit_failed",
              "The safe zone was deleted, but the deletion could not be recorded in the audit log. Contact support if this persists.",
              500,
              { zone_restored: false, delete_unaudited: true },
            );
          }
        }
        return ok({ deleted: true });
      }

      case "purge_data": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const familyId = readUuid(body.family_id, "family_id");
        const olderThanDays = readInteger(
          body.older_than_days,
          "older_than_days",
          1,
          3650,
        );
        // Owner-only. Purging history is irreversible for the family, so a
        // non-owner parent must not be able to trigger it even though the
        // purge stays inside the configured retention window.
        const family = await assertFamilyOwner(db, auth.user.id, familyId);
        if (!canPurge(auth.profile.role, family.owner_id === auth.user.id)) {
          throw new ApiError(
            "owner_required",
            "Only the family owner can purge family history.",
            403,
          );
        }
        const retention = await familySettings(db, familyId);

        // Retention is a minimum keep window: never delete inside it, even when
        // a caller asks for a more aggressive purge.
        const locationCutoffDays = Math.max(
          olderThanDays,
          retention.location_retention_days,
        );
        const usageCutoffDays = Math.max(
          olderThanDays,
          retention.usage_retention_days,
        );
        const now = Date.now();
        const locationCutoff = new Date(now - locationCutoffDays * DAY_MS)
          .toISOString();
        const usageCutoff = new Date(now - usageCutoffDays * DAY_MS)
          .toISOString()
          .slice(0, 10);

        const locationDelete = await db
          .from("location_events")
          .delete({ count: "exact" })
          .eq("family_id", familyId)
          .lt("recorded_at", locationCutoff);
        ensureNoError(locationDelete);

        const usageDelete = await db
          .from("usage_daily")
          .delete({ count: "exact" })
          .eq("family_id", familyId)
          .lt("day", usageCutoff);
        ensureNoError(usageDelete);

        const counts = {
          location_events: locationDelete.count ?? 0,
          usage_daily: usageDelete.count ?? 0,
        };
        await recordAudit(db, {
          familyId,
          actorUserId: auth.user.id,
          eventType: "data_purged",
          targetType: "family",
          targetId: familyId,
          metadata: {
            older_than_days: olderThanDays,
            location_cutoff_days: locationCutoffDays,
            usage_cutoff_days: usageCutoffDays,
            counts,
          },
        });
        return ok({
          counts,
          older_than_days: olderThanDays,
          retention,
          cutoffs: {
            location_before: locationCutoff,
            usage_before: usageCutoff,
          },
        });
      }

      case "update_retention": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const familyId = readUuid(body.family_id, "family_id");
        const locationDays = readInteger(body.location_days, "location_days", 1, 365);
        const usageDays = readInteger(body.usage_days, "usage_days", 1, 730);
        const family = await assertFamilyOwner(db, auth.user.id, familyId);
        const settings = {
          ...(family.settings ?? {}),
          location_retention_days: locationDays,
          usage_retention_days: usageDays,
        };

        const updated = await db
          .from("families")
          .update({ settings })
          .eq("id", familyId)
          .select("settings")
          .single();
        ensureNoError(updated);

        await recordAudit(db, {
          familyId,
          actorUserId: auth.user.id,
          eventType: "settings_updated",
          targetType: "family",
          targetId: familyId,
          metadata: {
            location_retention_days: locationDays,
            usage_retention_days: usageDays,
          },
        });
        return ok((updated.data as { settings: Record<string, unknown> }).settings);
      }

      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
