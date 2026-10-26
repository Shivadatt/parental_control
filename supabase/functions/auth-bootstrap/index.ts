// auth-bootstrap: one-time role selection and family creation.
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
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import { readEnum, readOptionalString, readString } from "../_shared/validation.ts";

const ROLES = ["parent", "child"] as const;

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
      case "set_role": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        const role = readEnum(body.role, "role", ROLES);
        const displayName = readOptionalString(body.display_name, "display_name", {
          min: 1,
          max: 60,
        });
        if (auth.profile.role !== "unset" && auth.profile.role !== role) {
          throw new ApiError(
            "role_already_set",
            "This account already has a different role.",
            409,
          );
        }
        const patch: Record<string, unknown> = { role };
        if (displayName) patch.display_name = displayName;
        const result = await db
          .from("profiles")
          .update(patch)
          .eq("id", auth.user.id)
          .select("id, role, display_name, created_at, updated_at")
          .single();
        ensureNoError(result);
        if (auth.profile.role === "unset") {
          await recordAudit(db, {
            actorUserId: auth.user.id,
            eventType: "role_set",
            targetType: "profile",
            targetId: auth.user.id,
            metadata: { role },
          });
        }
        return ok(result.data);
      }

      case "create_family": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const name = readString(body.name, "name", { min: 1, max: 80 });

        const existing = await db
          .from("families")
          .select("id")
          .eq("owner_id", auth.user.id)
          .is("deleted_at", null)
          .maybeSingle();
        ensureNoError(existing);
        if (existing.data) {
          throw new ApiError(
            "family_exists",
            "You already own an active family.",
            409,
          );
        }

        const rpc = await db.rpc("create_family_with_owner", {
          p_owner: auth.user.id,
          p_name: name,
        });
        if (rpc.error) {
          if (rpc.error.code === "23505") {
            throw new ApiError(
              "family_exists",
              "You already own an active family.",
              409,
            );
          }
          console.error(`create_family_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "The family could not be created.",
            500,
          );
        }
        return ok(rpc.data);
      }

      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
