// cron: scheduled maintenance. Self-authenticates with x-cron-secret vs CRON_SECRET.
import { preflightResponse } from "../_shared/cors.ts";
import {
  ApiError,
  errorResponse,
  ok,
  readJson,
  requireAction,
} from "../_shared/envelope.ts";
import { getServiceClient } from "../_shared/auth.ts";
import { constantTimeSecretEqual } from "../_shared/validation.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflightResponse();
  if (req.method !== "POST") {
    return errorResponse(new ApiError("method_not_allowed", "Use POST.", 405));
  }
  try {
    const configured = Deno.env.get("CRON_SECRET") ?? "";
    if (configured.length < 16) {
      throw new ApiError(
        "cron_not_configured",
        "Scheduled maintenance is not configured.",
        503,
      );
    }
    const provided = req.headers.get("x-cron-secret") ?? "";
    if (
      provided.length === 0 ||
      !(await constantTimeSecretEqual(provided, configured))
    ) {
      throw new ApiError("unauthorized", "Scheduled credentials are not valid.", 401);
    }

    const body = await readJson(req);
    const action = requireAction(body);
    const db = getServiceClient();

    switch (action) {
      case "expire_sessions": {
        const rpc = await db.rpc("expire_stale_sessions");
        if (rpc.error) {
          console.error(`expire_sessions_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "Expired sessions could not be processed.",
            500,
          );
        }
        return ok({ expired_sessions: typeof rpc.data === "number" ? rpc.data : 0 });
      }
      case "detect_offline": {
        const rpc = await db.rpc("detect_offline_devices");
        if (rpc.error) {
          console.error(`detect_offline_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "Offline devices could not be processed.",
            500,
          );
        }
        return ok({ alerts_created: typeof rpc.data === "number" ? rpc.data : 0 });
      }
      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
