// device-policy: strict policy validation + atomic version/command creation.
import { preflightResponse } from "../_shared/cors.ts";
import {
  ApiError,
  errorResponse,
  ok,
  readJson,
  requireAction,
} from "../_shared/envelope.ts";
import {
  getServiceClient,
  requireActiveDeviceForParent,
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import { validatePolicyPayload } from "../_shared/policy.ts";
import { readString, readUuid } from "../_shared/validation.ts";

function mapPolicyRpcError(message: string): never {
  if (message.includes("device_not_found")) {
    throw new ApiError("device_not_found", "The device was not found.", 404);
  }
  if (message.includes("device_not_active")) {
    throw new ApiError("device_not_active", "The device is not active.", 403);
  }
  if (
    message.includes("invalid_policy") ||
    message.includes("invalid_idempotency_key") ||
    message.includes("device_required")
  ) {
    throw new ApiError("validation_error", "The policy request is not valid.", 400);
  }
  console.error("apply_policy_rpc_failed");
  throw new ApiError("internal_error", "The policy could not be saved.", 500);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflightResponse();
  if (req.method !== "POST") {
    return errorResponse(new ApiError("method_not_allowed", "Use POST.", 405));
  }
  try {
    const body = await readJson(req);
    const action = requireAction(body);
    if (action !== "update") {
      throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
    const db = getServiceClient();
    const auth = await requireUser(req, db, { requireVerifiedEmail: true });
    requireRole(auth.profile, "parent");

    const deviceId = readUuid(body.device_id, "device_id");
    const device = await requireActiveDeviceForParent(db, auth.user.id, deviceId);
    const idempotencyKey = readString(body.idempotency_key, "idempotency_key", {
      min: 1,
      max: 128,
    });
    const policy = validatePolicyPayload(body.policy);

    const rpc = await db.rpc("apply_policy_version", {
      p_device_id: device.id,
      p_policy: policy,
      p_actor: auth.user.id,
      p_idempotency_key: idempotencyKey,
    });
    if (rpc.error) {
      mapPolicyRpcError(rpc.error.message ?? "");
    }
    const data = rpc.data as {
      policy: Record<string, unknown>;
      command: Record<string, unknown>;
      idempotent?: boolean;
    };
    if (!data || !data.policy || !data.command) {
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
          command_id: data.command.id ?? null,
        },
      });
    }

    return ok({ policy: data.policy, command: data.command });
  } catch (error) {
    return errorResponse(error);
  }
});
