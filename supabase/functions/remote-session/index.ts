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
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import { buildIceConfig, readTurnEnv } from "../_shared/turn.ts";
import {
  readBoolean,
  readEnum,
  readOptionalString,
  readUuid,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const KINDS = ["audio", "video"] as const;
const REQUEST_TTL_MS = 10 * 60 * 1000;
const CONSENT_TTL_MS = 30 * 60 * 1000;

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
  expires_at: string;
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

async function markExpired(db: SupabaseClient, sessionId: string): Promise<void> {
  const nowIso = new Date().toISOString();
  const result = await db
    .from("remote_sessions")
    .update({ status: "expired", ended_at: nowIso, ended_reason: "expired" })
    .eq("id", sessionId)
    .in("status", ["requested", "accepted", "active"]);
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

        const now = new Date();
        const inserted = await db
          .from("remote_sessions")
          .insert({
            family_id: device.family_id,
            device_id: device.id,
            parent_user_id: auth.user.id,
            child_user_id: device.child_user_id,
            kind,
            status: "requested",
            requested_at: now.toISOString(),
            expires_at: new Date(now.getTime() + REQUEST_TTL_MS).toISOString(),
            consent_recorded: false,
          })
          .select(SESSION_SELECT)
          .single();
        ensureNoError(inserted);
        const session = inserted.data as SessionRow;

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
        if (new Date(session.expires_at).getTime() <= Date.now()) {
          await markExpired(db, session.id);
          throw new ApiError("session_expired", "This session request expired.", 410);
        }

        const now = new Date();
        const nowIso = now.toISOString();
        const patch = accept
          ? {
            status: "accepted",
            accepted_at: nowIso,
            expires_at: new Date(now.getTime() + CONSENT_TTL_MS).toISOString(),
            consent_recorded: true,
            session_nonce: crypto.randomUUID(),
          }
          : {
            status: "declined",
            ended_at: nowIso,
            ended_reason: "declined",
            consent_recorded: false,
          };
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
        if (new Date(session.expires_at).getTime() <= Date.now()) {
          await markExpired(db, session.id);
          throw new ApiError("session_expired", "This session has expired.", 410);
        }

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
        const reason = readOptionalString(body.reason, "reason", {
          min: 1,
          max: 200,
        });
        const session = await loadSession(db, sessionId);
        assertParticipant(session, auth.user.id);
        if (["ended", "declined", "expired", "failed"].includes(session.status)) {
          return ok(session);
        }

        const nowIso = new Date().toISOString();
        const updated = await db
          .from("remote_sessions")
          .update({
            status: "ended",
            ended_at: nowIso,
            ended_by: auth.user.id,
            ended_reason: reason ?? null,
          })
          .eq("id", session.id)
          .in("status", ["requested", "accepted", "active"])
          .select(SESSION_SELECT)
          .maybeSingle();
        ensureNoError(updated);
        const finalSession = (updated.data as SessionRow | null) ?? session;

        await recordAudit(db, {
          familyId: session.family_id,
          actorUserId: auth.user.id,
          deviceId: session.device_id,
          eventType: "session_ended",
          targetType: "remote_session",
          targetId: session.id,
          metadata: { status_before: session.status, reason: reason ?? null },
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
        if (new Date(session.expires_at).getTime() <= Date.now()) {
          await markExpired(db, session.id);
          throw new ApiError("session_expired", "This session has expired.", 410);
        }

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
