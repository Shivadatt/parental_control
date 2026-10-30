// Pure helpers for the remote-session request guard and the device-facing
// session_state action. Kept free of Deno.serve / Supabase clients so they can
// be unit-tested without booting the Edge Function.
import { ApiError } from "../_shared/envelope.ts";

export const OPEN_SESSION_STATUSES = [
  "requested",
  "accepted",
  "active",
] as const;

/** True while a session still owns the device microphone/camera. */
export function isOpenSessionStatus(status: string): boolean {
  return (OPEN_SESSION_STATUSES as readonly string[]).includes(status);
}

export interface RpcErrorLike {
  message?: string | null;
  details?: string | null;
  code?: string | null;
}

/**
 * Maps the SQL errors raised by public.request_remote_session() to the stable
 * API envelope. Only the SQLSTATE is logged: messages can echo argument values
 * and must never reach the log or the client verbatim.
 */
export function mapRequestRpcError(error: RpcErrorLike): ApiError {
  const haystack = `${error.message ?? ""} ${error.details ?? ""}`
    .toLowerCase();

  if (haystack.includes("session_in_progress")) {
    return new ApiError(
      "session_in_progress",
      "Another assistance session is already open for this device.",
      409,
    );
  }
  if (haystack.includes("device_not_found")) {
    return new ApiError("device_not_found", "The device was not found.", 404);
  }
  if (haystack.includes("device_not_active")) {
    return new ApiError("device_not_active", "The device is not active.", 403);
  }
  if (haystack.includes("invalid_kind")) {
    return new ApiError(
      "invalid_kind",
      "The session kind is not supported.",
      400,
    );
  }

  console.error(`request_remote_session_failed:${error.code ?? "unknown"}`);
  return new ApiError(
    "internal_error",
    "The server could not complete the request.",
    500,
  );
}

export interface SessionStateRow {
  id: string;
  device_id: string;
  child_user_id: string;
  status: string;
  /** Pending-request deadline only; NULL once consent was recorded. */
  expires_at: string | null;
}

export interface SessionStateDevice {
  id: string;
  child_user_id: string;
}

export interface SessionStatePayload {
  session_id: string;
  status: string;
  expires_at: string | null;
}

/**
 * Device-auth view of one session. The device credential proves the caller; a
 * session is visible only when both its device_id and child_user_id belong to
 * that device, otherwise a different family's session id would be readable.
 * The payload deliberately carries no signal data and no personal details.
 */
export function sessionStatePayload(
  session: SessionStateRow,
  device: SessionStateDevice,
): SessionStatePayload {
  if (
    session.device_id !== device.id ||
    session.child_user_id !== device.child_user_id
  ) {
    throw new ApiError(
      "forbidden",
      "This session does not belong to this device.",
      403,
    );
  }
  return {
    session_id: session.id,
    status: session.status,
    expires_at: session.expires_at,
  };
}

export interface SessionOwner {
  parent_user_id: string;
}

/**
 * Only the parent who requested the session may end it on the server. A child
 * withdrawing consent stops local capture (a device concern); it is not an
 * authorization to terminate the session record, which the parent owns.
 */
export function assertParentOwner(
  session: SessionOwner,
  userId: string,
): void {
  if (session.parent_user_id !== userId) {
    throw new ApiError(
      "parent_only",
      "Only the parent who requested this session can end it.",
      403,
    );
  }
}

export interface EndPatch {
  status: "ended";
  ended_at: string;
  ended_by: string;
  ended_reason: string;
}

/**
 * The end reason is chosen by the server, never by the caller: a pending
 * request is a cancellation, anything already consented is a parent end. The
 * caller's own string is ignored so `ended_by`/`ended_reason` cannot be spoofed.
 */
export function endPatch(
  statusBefore: string,
  parentUserId: string,
  nowIso: string,
): EndPatch {
  return {
    status: "ended",
    ended_at: nowIso,
    ended_by: parentUserId,
    ended_reason: statusBefore === "requested"
      ? "cancelled_by_parent"
      : "ended_by_parent",
  };
}

/**
 * Consent patch. `expires_at: null` is the whole point: the pending-request
 * deadline is released the moment the child consents, so from then on only the
 * parent can end the session (migration 20261028000200).
 */
export interface AcceptPatch {
  status: "accepted";
  accepted_at: string;
  expires_at: null;
  consent_recorded: true;
  session_nonce: string;
}

export function acceptPatch(nowIso: string, sessionNonce: string): AcceptPatch {
  return {
    status: "accepted",
    accepted_at: nowIso,
    expires_at: null,
    consent_recorded: true,
    session_nonce: sessionNonce,
  };
}

/** Refusal patch: terminal immediately, no consent, no deadline to keep. */
export interface DeclinePatch {
  status: "declined";
  ended_at: string;
  ended_reason: "declined";
  consent_recorded: false;
}

export function declinePatch(nowIso: string): DeclinePatch {
  return {
    status: "declined",
    ended_at: nowIso,
    ended_reason: "declined",
    consent_recorded: false,
  };
}
