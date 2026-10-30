// remote-session: parent consent flow, session lifecycle and ICE config.
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
import { buildIceConfig, readTurnEnv } from "../_shared/turn.ts";
import {
  readBoolean,
  readEnum,
  readUuid,
} from "../_shared/validation.ts";
import {
  acceptPatch,
  assertParentOwner,
  declinePatch,
  endPatch,
  mapRequestRpcError,
  sessionStatePayload,
  type SessionStateRow,
} from "./guard.ts";
import { withAbandonedSweep } from "../_shared/remote_session_lifecycle.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const KINDS = ["audio", "video"] as const;

const SESSION_SELECT =
  "*, devices(display_name), parent_profile:profiles!remote_sessions_parent_user_id_fkey(display_name), child_profile:profiles!remote_sessions_child_user_id_fkey(display_name)";

interface SessionRow {
  id: string;
  family_id: string;
  device_id: string;
  parent_user_id: string;
  child_user_id: string;
  kind: string;
  status: string;
  requested_at: string;
  accepted_at: string | null;
  started_at: string | null;
  ended_at: string | null;
  /** Pending-request deadline; NULL once the child consented. */
  expires_at: string | null;
  ended_reason: string | null;
  consent_recorded: boolean;
  session_nonce: string | null;
}

async function loadSession(
  db: SupabaseClient,
  sessionId: string,
): Promise<SessionRow> {
  const result = await db
    .from("remote_sessions")
    .select(SESSION_SELECT)
    .eq("id", sessionId)
    .maybeSingle();
  ensureNoError(result);
  if (!result.data) {
    throw new ApiError("session_not_found", "The session was not found.", 404);
  }
  return result.data as SessionRow;
}

function assertParticipant(session: SessionRow, userId: string): void {
  if (session.parent_user_id !== userId && session.child_user_id !== userId) {
    throw new ApiError("forbidden", "You are not a participant in this session.", 403);
  }
}

/**
 * Only a pending request has a deadline. An accepted session is owned by the
 * parent and is never expired by the clock, so this must not touch it.
 */
async function expirePending(
  db: SupabaseClient,
  sessionId: string,
): Promise<void> {
  const nowIso = new Date().toISOString();
  const result = await db
    .from("remote_sessions")
    .update({ status: "expired", ended_at: nowIso, ended_reason: "expired" })
    .eq("id", sessionId)
    .eq("status", "requested");
  ensureNoError(result);
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
      case "request": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const deviceId = readUuid(body.device_id, "device_id");
        const kind = readEnum(body.kind, "kind", KINDS);
        const device = await requireActiveDeviceForParent(db, auth.user.id, deviceId);

        // One open session per device, enforced atomically in SQL: the RPC takes
        // a per-device advisory lock, expires stale rows in-lock and raises
        // session_in_progress instead of ending a valid session.
        // Before the lock, close consented sessions nobody returned to
        // (public.expire_abandoned_sessions). Best effort: the sweep never fails
        // the request, and may legitimately be missing before its migration is
        // deployed. The 10-minute pending expiry is unchanged.
        const rpc = await withAbandonedSweep(
          (fn, args) => db.rpc(fn, args),
          () =>
            db.rpc("request_remote_session", {
              p_device_id: device.id,
              p_parent_user_id: auth.user.id,
              p_kind: kind,
            }),
        );
        if (rpc.error) throw mapRequestRpcError(rpc.error);
        const insertedId = (rpc.data as { id?: string } | null)?.id;
        if (!insertedId) {
          throw new ApiError(
            "internal_error",
            "The server could not complete the request.",
            500,
          );
        }

        // Re-read with the participant joins so the response shape is unchanged.
        const session = await loadSession(db, insertedId);

        await recordAudit(db, {
          familyId: device.family_id,
          actorUserId: auth.user.id,
          deviceId: device.id,
          eventType: "session_requested",
          targetType: "remote_session",
          targetId: session.id,
          metadata: { kind },
        });
        return ok(session);
      }

      // Device-authenticated poll for the Android foreground service. No user
      // JWT: requireDevice (x-device-id/x-device-secret) is the authentication.
      case "session_state": {
        const device = await requireDevice(req, db);
        const sessionId = readUuid(body.session_id, "session_id");
        const result = await db
          .from("remote_sessions")
          .select("id, device_id, child_user_id, status, expires_at")
          .eq("id", sessionId)
          .maybeSingle();
        ensureNoError(result);
        if (!result.data) {
          throw new ApiError("session_not_found", "The session was not found.", 404);
        }
        return ok(
          sessionStatePayload(result.data as SessionStateRow, {
            id: device.id,
            child_user_id: device.child_user_id,
          }),
        );
      }

      case "pending_child": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const nowIso = new Date().toISOString();

        const expire = await db
          .from("remote_sessions")
          .update({ status: "expired", ended_at: nowIso, ended_reason: "expired" })
          .eq("child_user_id", auth.user.id)
          .eq("status", "requested")
          .lte("expires_at", nowIso);
        ensureNoError(expire);

        const result = await db
          .from("remote_sessions")
          .select(SESSION_SELECT)
          .eq("child_user_id", auth.user.id)
          .eq("status", "requested")
          .gt("expires_at", nowIso)
          .order("requested_at", { ascending: false })
          .limit(50);
        ensureNoError(result);
        return ok(result.data ?? []);
      }

      case "respond": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const sessionId = readUuid(body.session_id, "session_id");
        const accept = readBoolean(body.accept, "accept");
        const session = await loadSession(db, sessionId);
        if (session.child_user_id !== auth.user.id) {
          throw new ApiError("forbidden", "You cannot respond to this request.", 403);
        }
        if (session.status === "accepted" && accept) return ok(session);
        if (session.status === "declined" && !accept) return ok(session);
        if (session.status !== "requested") {
          throw new ApiError(
            "session_not_open",
            "This session is no longer waiting for consent.",
            409,
          );
        }
        if (
          session.expires_at !== null &&
          new Date(session.expires_at).getTime() <= Date.now()
        ) {
          await expirePending(db, session.id);
          throw new ApiError("session_expired", "This session request expired.", 410);
        }

        const nowIso = new Date().toISOString();
        // Consent releases the session from the pending deadline: from here on
        // only the parent can end it (migration 20261028000200).
        const patch = accept
          ? acceptPatch(nowIso, crypto.randomUUID())
          : declinePatch(nowIso);
        const updated = await db
          .from("remote_sessions")
          .update(patch)
          .eq("id", session.id)
          .eq("status", "requested")
          .select(SESSION_SELECT)
          .maybeSingle();
        ensureNoError(updated);
        if (!updated.data) {
          throw new ApiError(
            "session_not_open",
            "This session is no longer waiting for consent.",
            409,
          );
        }
        const finalSession = updated.data as SessionRow;

        await recordAudit(db, {
          familyId: session.family_id,
          actorUserId: auth.user.id,
          deviceId: session.device_id,
          eventType: accept ? "session_accepted" : "session_declined",
          targetType: "remote_session",
          targetId: session.id,
        });
        return ok(finalSession);
      }

      case "start": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const sessionId = readUuid(body.session_id, "session_id");
        const session = await loadSession(db, sessionId);
        if (session.child_user_id !== auth.user.id) {
          throw new ApiError("forbidden", "Only the child can start this session.", 403);
        }
        if (session.status === "active") return ok(session);
        if (session.status !== "accepted" || !session.consent_recorded) {
          throw new ApiError(
            "session_not_open",
            "Consent must be recorded before the session can start.",
            409,
          );
        }

        // No clock check: an accepted session lasts until the parent ends it.
        const nowIso = new Date().toISOString();
        const updated = await db
          .from("remote_sessions")
          .update({ status: "active", started_at: nowIso })
          .eq("id", session.id)
          .eq("status", "accepted")
          .select(SESSION_SELECT)
          .maybeSingle();
        ensureNoError(updated);
        if (!updated.data) {
          throw new ApiError("session_not_open", "The session cannot be started.", 409);
        }

        await recordAudit(db, {
          familyId: session.family_id,
          actorUserId: auth.user.id,
          deviceId: session.device_id,
          eventType: "session_started",
          targetType: "remote_session",
          targetId: session.id,
        });
        return ok(updated.data);
      }

      case "end": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        const sessionId = readUuid(body.session_id, "session_id");
        const session = await loadSession(db, sessionId);
        // The child can stop sharing, but only the requesting parent ends the
        // server session. A client-supplied reason is ignored: the server
        // derives ended_reason from the state it observed.
        assertParentOwner(session, auth.user.id);
        if (["ended", "declined", "expired", "failed"].includes(session.status)) {
          return ok(session);
        }

        const patch = endPatch(
          session.status,
          auth.user.id,
          new Date().toISOString(),
        );
        const updated = await db
          .from("remote_sessions")
          .update(patch)
          .eq("id", session.id)
          .in("status", ["requested", "accepted", "active"])
          .select(SESSION_SELECT)
          .maybeSingle();
        ensureNoError(updated);
        // A concurrent terminal transition (pending expiry, abandoned sweep)
        // can win between the read and this update. Return what the row is now
        // instead of a stale pre-update snapshot the caller would misread as a
        // live session.
        const finalSession = (updated.data as SessionRow | null) ??
          (await loadSession(db, session.id));

        await recordAudit(db, {
          familyId: session.family_id,
          actorUserId: auth.user.id,
          deviceId: session.device_id,
          eventType: "session_ended",
          targetType: "remote_session",
          targetId: session.id,
          metadata: { status_before: session.status },
        });
        return ok(finalSession);
      }

      case "ice": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        const sessionId = readUuid(body.session_id, "session_id");
        const session = await loadSession(db, sessionId);
        assertParticipant(session, auth.user.id);
        if (!["accepted", "active"].includes(session.status)) {
          throw new ApiError(
            "session_not_open",
            "ICE configuration is only available after consent.",
            409,
          );
        }
        if (!session.consent_recorded) {
          throw new ApiError(
            "consent_required",
            "Consent has not been recorded for this session.",
            403,
          );
        }

        // Credentials are short-lived by design and reissued per call; they are
        // unrelated to how long the session may stay open.
        const config = await buildIceConfig(readTurnEnv(), auth.user.id);
        return ok(config);
      }

      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
