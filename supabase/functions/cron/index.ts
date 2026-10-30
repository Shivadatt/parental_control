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

/**
 * PostgREST reports a missing SQL function as PGRST202; Postgres uses 42883.
 * Edge Functions can be deployed before their migration, so the scheduled
 * actions below treat only these as "migration not applied yet" and answer 200
 * with `skipped`, instead of failing the whole schedule.
 */
function isMissingFunction(error: {
  code?: string | null;
  message?: string | null;
}): boolean {
  const code = (error.code ?? "").toUpperCase();
  const message = (error.message ?? "").toLowerCase();
  return code === "PGRST202" ||
    code === "42883" ||
    message.includes("could not find the function") ||
    message.includes("does not exist");
}

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
      // Consented sessions nobody returned to (migration 20261030000100).
      case "sweep_sessions": {
        const rpc = await db.rpc("expire_abandoned_sessions", {
          p_max_age: "24 hours",
        });
        if (rpc.error) {
          if (isMissingFunction(rpc.error)) {
            console.warn("sweep_sessions_function_missing");
            return ok({ skipped: true, reason: "function_missing" });
          }
          console.error(`sweep_sessions_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "Abandoned sessions could not be processed.",
            500,
          );
        }
        const closed = Number(rpc.data ?? 0);
        return ok({
          closed_sessions: Number.isFinite(closed) && closed >= 0 ? closed : 0,
        });
      }
      // Enforced retention (migration 20261030000300). Deployment order is not
      // guaranteed, so a missing function is a clean skip, not a 500.
      case "retention_sweep": {
        const rpc = await db.rpc("run_retention_sweep");
        if (rpc.error) {
          if (isMissingFunction(rpc.error)) {
            console.warn("retention_sweep_function_missing");
            return ok({ skipped: true, reason: "function_missing" });
          }
          console.error(`retention_sweep_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "Retention could not be applied.",
            500,
          );
        }
        return ok(
          typeof rpc.data === "object" && rpc.data !== null
            ? rpc.data as Record<string, unknown>
            : { swept: true },
        );
      }
      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
