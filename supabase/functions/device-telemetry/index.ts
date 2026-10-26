// device-telemetry: heartbeat, usage, location and app snapshot uploads.
// verify_jwt=false; every action requires x-device-id + x-device-secret.
import { preflightResponse } from "../_shared/cors.ts";
import {
  ApiError,
  ensureNoError,
  errorResponse,
  ok,
  readJson,
  requireAction,
} from "../_shared/envelope.ts";
import { getServiceClient, requireDevice } from "../_shared/auth.ts";
import {
  distanceMeters,
  readArray,
  readDateOnly,
  readEnum,
  readIsoDate,
  readNumber,
  readOptionalBoolean,
  readOptionalInteger,
  readOptionalString,
  readPackageName,
  requireRecord,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const ENFORCEMENT_MODES = ["none", "device_admin", "device_owner"] as const;
const LOW_BATTERY_THRESHOLD = 20;
const LOW_BATTERY_WINDOW_HOURS = 6;
const LOCATION_MAX_FUTURE_MS = 5 * 60 * 1000;
const LOCATION_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

interface SafeZoneRow {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radius_m: number;
}

async function latestPolicyVersion(
  db: SupabaseClient,
  deviceId: string,
): Promise<number> {
  const result = await db
    .from("device_policies")
    .select("version")
    .eq("device_id", deviceId)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();
  ensureNoError(result);
  return (result.data as { version?: number } | null)?.version ?? 0;
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
      case "heartbeat": {
        const device = await requireDevice(req, db);
        const batteryLevel = readOptionalInteger(
          body.battery_level,
          "battery_level",
          0,
          100,
        );
        const isCharging = readOptionalBoolean(body.is_charging, "is_charging");
        readOptionalBoolean(body.online, "online"); // presence is inferred from this call

        const patch: Record<string, unknown> = {
          last_seen_at: new Date().toISOString(),
        };
        if (batteryLevel !== undefined) patch.battery_level = batteryLevel;
        if (isCharging !== undefined) patch.is_charging = isCharging;
        // policy_version is only advanced by a successful apply_policy ack in
        // device-command; a heartbeat must not be able to claim enforcement.

        if (body.capabilities !== undefined && body.capabilities !== null) {
          const capabilities = requireRecord(body.capabilities, "capabilities");
          if (capabilities.enforcement_mode !== undefined) {
            patch.enforcement_mode = readEnum(
              capabilities.enforcement_mode,
              "capabilities.enforcement_mode",
              ENFORCEMENT_MODES,
            );
          }
          const permissionMap: Array<[string, string]> = [
            ["usage_access_granted", "usage_access_granted"],
            ["location_granted", "location_granted"],
            ["background_location_granted", "background_location_granted"],
            ["camera_granted", "camera_granted"],
            ["microphone_granted", "microphone_granted"],
            ["notifications_granted", "notifications_granted"],
          ];
          for (const [field, column] of permissionMap) {
            const value = readOptionalBoolean(
              capabilities[field],
              `capabilities.${field}`,
            );
            if (value !== undefined) patch[column] = value;
          }
        }

        const updated = await db
          .from("devices")
          .update(patch)
          .eq("id", device.id)
          .select("id")
          .maybeSingle();
        ensureNoError(updated);

        if (
          batteryLevel !== undefined && batteryLevel <= LOW_BATTERY_THRESHOLD &&
          isCharging === false
        ) {
          const since = new Date(
            Date.now() - LOW_BATTERY_WINDOW_HOURS * 60 * 60 * 1000,
          ).toISOString();
          const recent = await db
            .from("safety_alerts")
            .select("id")
            .eq("device_id", device.id)
            .eq("type", "low_battery")
            .gte("created_at", since)
            .limit(1)
            .maybeSingle();
          ensureNoError(recent);
          if (!recent.data) {
            const alert = await db.from("safety_alerts").insert({
              family_id: device.family_id,
              device_id: device.id,
              type: "low_battery",
              severity: "warning",
              message: `Device battery is low (${batteryLevel}%).`,
              payload: { battery_level: batteryLevel },
            });
            ensureNoError(alert);
          }
        }

        const pendingVersion = await latestPolicyVersion(db, device.id);
        return ok({
          server_time: new Date().toISOString(),
          pending_policy_version: pendingVersion,
        });
      }

      case "usage_upload": {
        const device = await requireDevice(req, db);
        const rawEntries = readArray(body.entries, "entries", 500);
        if (rawEntries.length === 0) {
          throw new ApiError(
            "validation_error",
            "entries must contain at least one item.",
            400,
          );
        }
        const rows: Record<string, unknown>[] = [];
        const seen = new Set<string>();
        const nowIso = new Date().toISOString();
        const latestAllowed = Date.now() + 36 * 60 * 60 * 1000;

        for (let i = 0; i < rawEntries.length; i += 1) {
          const entry = requireRecord(rawEntries[i], `entries[${i}]`);
          const day = readDateOnly(entry.day, `entries[${i}].day`);
          const dayStart = Date.parse(`${day}T00:00:00Z`);
          if (!Number.isFinite(dayStart) || dayStart > latestAllowed) {
            throw new ApiError(
              "validation_error",
              `entries[${i}].day cannot be in the future.`,
              400,
            );
          }
          const packageName = readPackageName(
            entry.package_name,
            `entries[${i}].package_name`,
          );
          const key = `${day}|${packageName}`;
          if (seen.has(key)) {
            throw new ApiError(
              "validation_error",
              `entries contains a duplicate for ${packageName} on ${day}.`,
              400,
            );
          }
          seen.add(key);
          const appLabel = readOptionalString(
            entry.app_label,
            `entries[${i}].app_label`,
            { min: 1, max: 100 },
          ) ?? packageName;
          const totalMs = readOptionalInteger(
            entry.total_ms,
            `entries[${i}].total_ms`,
            0,
            1_000_000_000_000,
          );
          if (totalMs === undefined) {
            throw new ApiError(
              "validation_error",
              `entries[${i}].total_ms is required.`,
              400,
            );
          }
          const lastUsedAt = entry.last_used_at === undefined ||
              entry.last_used_at === null
            ? null
            : readIsoDate(entry.last_used_at, `entries[${i}].last_used_at`)
              .toISOString();
          rows.push({
            device_id: device.id,
            family_id: device.family_id,
            day,
            package_name: packageName,
            app_label: appLabel,
            total_ms: totalMs,
            last_used_at: lastUsedAt,
            uploaded_at: nowIso,
            source: "usage_stats",
          });
        }

        const upsert = await db
          .from("usage_daily")
          .upsert(rows, { onConflict: "device_id,day,package_name" });
        ensureNoError(upsert);
        return ok({ accepted: rows.length, uploaded_at: nowIso });
      }

      case "location_upload": {
        const device = await requireDevice(req, db);
        const lat = readNumber(body.lat, "lat", -90, 90);
        const lng = readNumber(body.lng, "lng", -180, 180);
        const accuracy = readNumber(body.accuracy_m, "accuracy_m", 0, 100000);
        const recordedAt = readIsoDate(body.recorded_at, "recorded_at");
        const nowMs = Date.now();
        if (recordedAt.getTime() > nowMs + LOCATION_MAX_FUTURE_MS) {
          throw new ApiError(
            "invalid_timestamp",
            "recorded_at is too far in the future.",
            400,
          );
        }
        if (recordedAt.getTime() < nowMs - LOCATION_MAX_AGE_MS) {
          throw new ApiError(
            "invalid_timestamp",
            "recorded_at is older than seven days.",
            400,
          );
        }
        const source = readOptionalString(body.source, "source", {
          min: 1,
          max: 40,
        }) ?? "device";
        const recordedIso = recordedAt.toISOString();

        const inserted = await db.from("location_events").insert({
          device_id: device.id,
          family_id: device.family_id,
          lat,
          lng,
          accuracy_m: accuracy,
          recorded_at: recordedIso,
          source,
        });
        ensureNoError(inserted);

        const zonesResult = await db
          .from("safe_zones")
          .select("id, name, lat, lng, radius_m")
          .eq("family_id", device.family_id)
          .eq("active", true);
        ensureNoError(zonesResult);
        const zones = (zonesResult.data ?? []) as SafeZoneRow[];
        const zoneEvents: Array<{ zone_id: string; name: string; event: string }> = [];
        if (zones.length > 0) {
          const zoneIds = zones.map((zone) => zone.id);
          const statesResult = await db
            .from("safe_zone_states")
            .select("zone_id, inside")
            .eq("device_id", device.id)
            .in("zone_id", zoneIds);
          ensureNoError(statesResult);
          const previous = new Map<string, boolean>(
            ((statesResult.data ?? []) as { zone_id: string; inside: boolean }[])
              .map((row) => [row.zone_id, row.inside]),
          );

          const stateUpserts: Record<string, unknown>[] = [];
          const alerts: Record<string, unknown>[] = [];
          for (const zone of zones) {
            const distance = distanceMeters(lat, lng, zone.lat, zone.lng);
            const inside = distance <= zone.radius_m;
            const wasInside = previous.get(zone.id);
            if (wasInside === undefined) {
              // First sample is a baseline, not a transition.
              stateUpserts.push({
                zone_id: zone.id,
                device_id: device.id,
                inside,
                updated_at: new Date().toISOString(),
              });
              continue;
            }
            if (wasInside !== inside) {
              const event = inside ? "enter" : "exit";
              zoneEvents.push({ zone_id: zone.id, name: zone.name, event });
              stateUpserts.push({
                zone_id: zone.id,
                device_id: device.id,
                inside,
                updated_at: new Date().toISOString(),
              });
              alerts.push({
                family_id: device.family_id,
                device_id: device.id,
                type: inside ? "geofence_enter" : "geofence_exit",
                severity: inside ? "info" : "warning",
                message: inside
                  ? `Entered safe zone ${zone.name}.`
                  : `Left safe zone ${zone.name}.`,
                payload: {
                  zone_id: zone.id,
                  zone_name: zone.name,
                  distance_m: Math.round(distance),
                  lat,
                  lng,
                  recorded_at: recordedIso,
                },
              });
            }
          }
          if (stateUpserts.length > 0) {
            const upsert = await db
              .from("safe_zone_states")
              .upsert(stateUpserts, { onConflict: "zone_id,device_id" });
            ensureNoError(upsert);
          }
          if (alerts.length > 0) {
            const alertInsert = await db.from("safety_alerts").insert(alerts);
            ensureNoError(alertInsert);
          }
        }

        return ok({ accepted: true, zone_events: zoneEvents });
      }

      case "apps_upload": {
        const device = await requireDevice(req, db);
        const rawApps = readArray(body.apps, "apps", 500);
        if (rawApps.length === 0) {
          // Never silently delete the snapshot on an empty report.
          throw new ApiError(
            "validation_error",
            "apps must contain at least one installed application.",
            400,
          );
        }
        const apps: Record<string, unknown>[] = [];
        const seen = new Set<string>();
        for (let i = 0; i < rawApps.length; i += 1) {
          const app = requireRecord(rawApps[i], `apps[${i}]`);
          const packageName = readPackageName(
            app.package_name,
            `apps[${i}].package_name`,
          );
          if (seen.has(packageName)) {
            throw new ApiError(
              "validation_error",
              `apps contains duplicate package ${packageName}.`,
              400,
            );
          }
          seen.add(packageName);
          const label = readOptionalString(app.label, `apps[${i}].label`, {
            min: 1,
            max: 100,
          }) ?? packageName;
          const isSystem = readOptionalBoolean(
            app.is_system,
            `apps[${i}].is_system`,
          ) ?? false;
          const isSuspended = readOptionalBoolean(
            app.is_suspended,
            `apps[${i}].is_suspended`,
          ) ?? false;
          const versionName = readOptionalString(
            app.version_name,
            `apps[${i}].version_name`,
            { min: 1, max: 64 },
          );
          apps.push({
            package_name: packageName,
            label,
            is_system: isSystem,
            is_suspended: isSuspended,
            version_name: versionName ?? null,
          });
        }

        const rpc = await db.rpc("replace_device_apps", {
          p_device_id: device.id,
          p_family_id: device.family_id,
          p_apps: apps,
        });
        if (rpc.error) {
          console.error(`replace_apps_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "The app snapshot could not be saved.",
            500,
          );
        }
        return ok({
          accepted: typeof rpc.data === "number" ? rpc.data : apps.length,
          reported_at: new Date().toISOString(),
        });
      }

      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
