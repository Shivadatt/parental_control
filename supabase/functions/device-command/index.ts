// device-command: parent command creation, device poll and acknowledgement.
// verify_jwt=false; this function authenticates every action itself.
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
  getServiceClient,
  requireActiveDeviceForParent,
  requireDevice,
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import {
  COMMAND_TYPES,
  type CommandType,
  validateCommandPayload,
} from "../_shared/policy.ts";
import {
  isRecord,
  isUuid,
  readEnum,
  readOptionalInteger,
  readOptionalString,
  readString,
  readUuid,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

interface CommandRow {
  id: string;
  device_id: string;
  family_id: string;
  type: string;
  payload: Record<string, unknown>;
  status: string;
  idempotency_key: string;
  created_at: string;
  expires_at: string;
  delivered_at: string | null;
  acked_at: string | null;
  result: Record<string, unknown> | null;
  error_message: string | null;
  attempts: number;
}

const ACK_STATUSES = ["succeeded", "failed", "expired"] as const;

function mapApplyPolicyRpcError(message: string): never {
  if (message.includes("device_not_found")) {
    throw new ApiError("device_not_found", "The device was not found.", 404);
  }
  if (message.includes("device_not_active")) {
    throw new ApiError("device_not_active", "The device is not active.", 403);
  }
  console.error("apply_policy_rpc_failed");
  throw new ApiError("internal_error", "The policy could not be saved.", 500);
}

function extractError(
  result: Record<string, unknown> | null,
  explicit: string | undefined,
): string | undefined {
  if (explicit) return explicit.slice(0, 500);
  if (!result) return undefined;
  const errors = result.errors;
  if (Array.isArray(errors)) {
    const text = errors.filter((item) => typeof item === "string").join("; ");
    if (text) return text.slice(0, 500);
  }
  const single = result.error;
  if (typeof single === "string" && single.length > 0) {
    return single.slice(0, 500);
  }
  return undefined;
}

async function loadCommand(
  db: SupabaseClient,
  commandId: string,
  deviceId: string,
): Promise<CommandRow | null> {
  const { data, error } = await db
    .from("device_commands")
    .select("*")
    .eq("id", commandId)
    .eq("device_id", deviceId)
    .maybeSingle();
  ensureNoError({ error });
  return (data as CommandRow | null) ?? null;
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
      case "create": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const deviceId = readUuid(body.device_id, "device_id");
        const device = await requireActiveDeviceForParent(db, auth.user.id, deviceId);

        const type = readEnum<CommandType>(body.type, "type", COMMAND_TYPES);
        const payload = validateCommandPayload(type, body.payload);
        const idempotencyKey = readString(body.idempotency_key, "idempotency_key", {
          min: 1,
          max: 128,
        });
        const ttlRaw = readOptionalInteger(body.ttl_seconds, "ttl_seconds", 1, 86400);
        const ttl = Math.min(900, Math.max(60, ttlRaw ?? 300));

        // Policy changes must be versioned atomically; the command payload then
        // carries policy_id so the device ack can reconcile enforcement.
        if (type === "apply_policy") {
          const applied = await db.rpc("apply_policy_version", {
            p_device_id: device.id,
            p_policy: payload.policy,
            p_actor: auth.user.id,
            p_idempotency_key: idempotencyKey,
          });
          if (applied.error) {
            mapApplyPolicyRpcError(applied.error.message ?? "");
          }
          const data = applied.data as {
            policy?: Record<string, unknown>;
            command?: Record<string, unknown>;
            idempotent?: boolean;
          } | null;
          if (!data?.policy || !data.command?.id) {
            throw new ApiError("internal_error", "The policy could not be saved.", 500);
          }
          if (!data.idempotent) {
            await recordAudit(db, {
              familyId: device.family_id,
              actorUserId: auth.user.id,
              deviceId: device.id,
              eventType: "policy_updated",
              targetType: "device_policy",
              targetId: String(data.policy.id ?? ""),
              metadata: {
                version: data.policy.version ?? null,
                command_id: data.command.id,
              },
            });
            await recordAudit(db, {
              familyId: device.family_id,
              actorUserId: auth.user.id,
              deviceId: device.id,
              eventType: "command_created",
              targetType: "device_command",
              targetId: String(data.command.id),
              metadata: { type, policy_id: data.policy.id ?? null },
            });
          }
          return ok({ command: data.command });
        }

        const now = new Date();

        const existingResult = await db
          .from("device_commands")
          .select("*")
          .eq("device_id", device.id)
          .eq("idempotency_key", idempotencyKey)
          .maybeSingle();
        ensureNoError(existingResult);
        if (existingResult.data) {
          return ok({ command: existingResult.data });
        }

        const inserted = await db
          .from("device_commands")
          .insert({
            device_id: device.id,
            family_id: device.family_id,
            type,
            payload,
            status: "pending",
            idempotency_key: idempotencyKey,
            created_by: auth.user.id,
            expires_at: new Date(now.getTime() + ttl * 1000).toISOString(),
          })
          .select("*")
          .single();
        if (inserted.error) {
          if (inserted.error.code === "23505") {
            const raced = await loadCommandByName(
              db,
              device.id,
              idempotencyKey,
            );
            if (raced) return ok({ command: raced });
          }
          console.error(`command_insert_failed:${inserted.error.code ?? "unknown"}`);
          throw new ApiError("internal_error", "The command could not be queued.", 500);
        }
        const command = inserted.data as CommandRow;

        await recordAudit(db, {
          familyId: device.family_id,
          actorUserId: auth.user.id,
          deviceId: device.id,
          eventType: "command_created",
          targetType: "device_command",
          targetId: command.id,
          metadata: { type, ttl_seconds: ttl },
        });
        return ok({ command: inserted.data });
      }

      case "poll": {
        const device = await requireDevice(req, db);
        const rpc = await db.rpc("poll_device_commands", {
          p_device_id: device.id,
          p_limit: 20,
        });
        if (rpc.error) {
          console.error(`poll_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "Commands could not be loaded.",
            500,
          );
        }
        const commands = Array.isArray(rpc.data) ? rpc.data : [];
        return ok({ commands, server_time: new Date().toISOString() });
      }

      case "ack": {
        const device = await requireDevice(req, db);
        const commandId = readUuid(body.command_id, "command_id");
        const ackStatus = readEnum(body.status, "status", ACK_STATUSES);
        const resultRaw = body.result;
        let result: Record<string, unknown> | null = null;
        if (resultRaw !== undefined && resultRaw !== null) {
          if (!isRecord(resultRaw)) {
            throw new ApiError("validation_error", "result must be an object.", 400);
          }
          if (JSON.stringify(resultRaw).length > 32 * 1024) {
            throw new ApiError("validation_error", "result is too large.", 400);
          }
          result = resultRaw;
        }
        const explicitError = readOptionalString(body.error_message, "error_message", {
          min: 1,
          max: 500,
        });

        const command = await loadCommand(db, commandId, device.id);
        if (!command) {
          throw new ApiError("command_not_found", "The command was not found.", 404);
        }
        if (["succeeded", "failed", "expired"].includes(command.status)) {
          return ok({ command });
        }

        const now = new Date();
        const nowIso = now.toISOString();
        const expired = new Date(command.expires_at).getTime() <= now.getTime();
        if (expired && ackStatus !== "expired") {
          const expire = await db
            .from("device_commands")
            .update({
              status: "expired",
              acked_at: nowIso,
              error_message: "Command expired before acknowledgement.",
            })
            .eq("id", command.id)
            .in("status", ["pending", "delivered"]);
          ensureNoError(expire);
          throw new ApiError(
            "command_expired",
            "The command expired before it was acknowledged.",
            410,
          );
        }

        const nextStatus = ackStatus === "expired" ? "expired" : ackStatus;
        const errorMessage = extractError(result, explicitError);
        const updated = await db
          .from("device_commands")
          .update({
            status: nextStatus,
            acked_at: nowIso,
            result,
            error_message: nextStatus === "succeeded"
              ? null
              : (errorMessage ?? "Device reported failure."),
          })
          .eq("id", command.id)
          .in("status", ["pending", "delivered"])
          .select("*")
          .maybeSingle();
        ensureNoError(updated);
        if (!updated.data) {
          // A concurrent ack won the race; return the settled row.
          const settled = await loadCommand(db, command.id, device.id);
          if (!settled) {
            throw new ApiError("command_not_found", "The command was not found.", 404);
          }
          return ok({ command: settled });
        }
        const finalCommand = updated.data as CommandRow;

        if (command.type === "apply_policy" && isRecord(command.payload)) {
          const policyId = command.payload.policy_id;
          if (isUuid(policyId)) {
            const enforcement = nextStatus === "succeeded" ? "enforced" : "failed";
            const policyUpdate = await db
              .from("device_policies")
              .update({
                acknowledged_at: nowIso,
                enforcement_status: enforcement,
                last_error: nextStatus === "succeeded"
                  ? null
                  : (errorMessage ?? "Command expired before acknowledgement."),
              })
              .eq("id", policyId)
              .eq("device_id", device.id)
              .select("version")
              .maybeSingle();
            ensureNoError(policyUpdate);

            const appliedVersion = (policyUpdate.data as { version?: number } | null)
              ?.version;
            if (
              nextStatus === "succeeded" &&
              typeof appliedVersion === "number" &&
              Number.isInteger(appliedVersion) &&
              appliedVersion >= 0
            ) {
              const deviceUpdate = await db
                .from("devices")
                .update({ policy_version: appliedVersion })
                .eq("id", device.id);
              ensureNoError(deviceUpdate);
            }
          }
        }

        await recordAudit(db, {
          familyId: command.family_id,
          deviceId: device.id,
          eventType: nextStatus === "succeeded" ? "command_acked" : "command_failed",
          targetType: "device_command",
          targetId: command.id,
          metadata: { type: command.type, status: nextStatus },
        });

        return ok({ command: finalCommand });
      }

      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});

async function loadCommandByName(
  db: SupabaseClient,
  deviceId: string,
  idempotencyKey: string,
): Promise<CommandRow | null> {
  const { data, error } = await db
    .from("device_commands")
    .select("*")
    .eq("device_id", deviceId)
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle();
  ensureNoError({ error });
  return (data as CommandRow | null) ?? null;
}
