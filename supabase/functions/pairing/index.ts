// pairing: child linking codes, parent redemption, child consent, unlink.
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
  type AuthContext,
  assertChildMembership,
  assertFamilyParent,
  getServiceClient,
  requireRole,
  requireUser,
} from "../_shared/auth.ts";
import { recordAudit } from "../_shared/audit.ts";
import {
  assertPairingCodeCreationAllowed,
  assertPairingRedeemAllowed,
  recordPairingAttempt,
} from "../_shared/rate_limit.ts";
import {
  generatePairingCode,
  isPairingCode,
  normalizePairingCode,
  readBoolean,
  readString,
  readUuid,
  sha256Hex,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const CODE_TTL_MINUTES = 10;

interface PairingRequestRow {
  id: string;
  token_id: string;
  family_id: string;
  parent_user_id: string;
  child_user_id: string;
  status: string;
  created_at: string;
  expires_at: string;
  responded_at: string | null;
}

interface TokenRow {
  id: string;
  child_user_id: string;
  status: string;
  expires_at: string;
  attempts: number;
  max_attempts: number;
}

async function familyName(db: SupabaseClient, familyId: string): Promise<string> {
  const { data, error } = await db
    .from("families")
    .select("name")
    .eq("id", familyId)
    .maybeSingle();
  ensureNoError({ error });
  return (data as { name?: string } | null)?.name ?? "Family";
}

async function profileName(db: SupabaseClient, userId: string): Promise<string> {
  const { data, error } = await db
    .from("profiles")
    .select("display_name")
    .eq("id", userId)
    .maybeSingle();
  ensureNoError({ error });
  return (data as { display_name?: string } | null)?.display_name ?? "Child account";
}

async function decorateRequests(
  db: SupabaseClient,
  rows: PairingRequestRow[],
): Promise<Record<string, unknown>[]> {
  if (rows.length === 0) return [];
  const familyIds = Array.from(new Set(rows.map((row) => row.family_id)));
  const userIds = Array.from(
    new Set(rows.flatMap((row) => [row.parent_user_id, row.child_user_id])),
  );
  const [familiesResult, profilesResult] = await Promise.all([
    db.from("families").select("id, name").in("id", familyIds),
    db.from("profiles").select("id, display_name").in("id", userIds),
  ]);
  ensureNoError(familiesResult);
  ensureNoError(profilesResult);
  const familyNames = new Map<string, string>(
    ((familiesResult.data ?? []) as { id: string; name: string }[]).map((row) => [
      row.id,
      row.name,
    ]),
  );
  const displayNames = new Map<string, string>(
    ((profilesResult.data ?? []) as { id: string; display_name: string }[]).map((
      row,
    ) => [row.id, row.display_name]),
  );
  return rows.map((row) => ({
    ...row,
    family_name: familyNames.get(row.family_id) ?? "Family",
    parent_display_name: displayNames.get(row.parent_user_id) ?? "Guardian",
    child_display_name: displayNames.get(row.child_user_id) ?? "Child account",
    // Nested shapes keep the Flutter wire model compatible while the flat
    // fields remain the contract-defined response.
    families: {
      id: row.family_id,
      name: familyNames.get(row.family_id) ?? "Family",
    },
    parent_profile: { display_name: displayNames.get(row.parent_user_id) ?? "Guardian" },
    child_profile: { display_name: displayNames.get(row.child_user_id) ?? "Child account" },
  }));
}

function redeemPayload(
  requestId: string,
  tokenId: string,
  familyId: string,
  familyLabel: string,
  parent: AuthContext,
  childUserId: string,
  childName: string,
  status: string,
  createdAt: string,
  expiresAt: string,
  respondedAt: string | null = null,
): Record<string, unknown> {
  return {
    id: requestId,
    token_id: tokenId,
    family_id: familyId,
    family_name: familyLabel,
    parent_user_id: parent.user.id,
    parent_display_name: parent.profile.display_name,
    child_user_id: childUserId,
    child_display_name: childName,
    status,
    created_at: createdAt,
    expires_at: expiresAt,
    responded_at: respondedAt,
    families: { id: familyId, name: familyLabel },
    parent_profile: { display_name: parent.profile.display_name },
    child_profile: { display_name: childName },
  };
}

function mapResponseRpcError(message: string): never {
  if (message.includes("request_not_found")) {
    throw new ApiError("request_not_found", "The request was not found.", 404);
  }
  if (message.includes("forbidden")) {
    throw new ApiError("forbidden", "You cannot respond to this request.", 403);
  }
  if (message.includes("code_expired")) {
    throw new ApiError(
      "code_expired",
      "This linking request has expired. Ask for a new code.",
      410,
    );
  }
  if (message.includes("child_already_linked")) {
    throw new ApiError(
      "child_already_linked",
      "This child account is already linked to a family.",
      409,
    );
  }
  if (message.includes("request_already_responded")) {
    throw new ApiError(
      "request_already_responded",
      "This request has already been answered.",
      409,
    );
  }
  if (message.includes("request_unavailable")) {
    throw new ApiError("request_unavailable", "This request is no longer valid.", 409);
  }
  console.error("pairing_rpc_failed");
  throw new ApiError("internal_error", "The request could not be completed.", 500);
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
        requireRole(auth.profile, "child");

        const linked = await db
          .from("family_members")
          .select("family_id")
          .eq("user_id", auth.user.id)
          .eq("role", "child")
          .eq("status", "active")
          .maybeSingle();
        ensureNoError(linked);
        if (linked.data) {
          throw new ApiError(
            "child_already_linked",
            "This account is already linked to a family.",
            409,
          );
        }

        await assertPairingCodeCreationAllowed(db, auth.user.id);

        const code = generatePairingCode();
        const codeHash = await sha256Hex(code);
        const expiresAt = new Date(
          Date.now() + CODE_TTL_MINUTES * 60 * 1000,
        ).toISOString();

        const inserted = await db
          .from("device_pairing_tokens")
          .insert({
            child_user_id: auth.user.id,
            code_hash: codeHash,
            expires_at: expiresAt,
            status: "active",
            created_by: auth.user.id,
          })
          .select("id, expires_at")
          .single();
        if (inserted.error) {
          console.error(`pairing_token_insert_failed:${inserted.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "A linking code could not be created.",
            500,
          );
        }
        const tokenId = (inserted.data as { id: string }).id;

        const revoke = await db
          .from("device_pairing_tokens")
          .update({ status: "revoked" })
          .eq("child_user_id", auth.user.id)
          .eq("status", "active")
          .neq("id", tokenId);
        ensureNoError(revoke);

        const cancelStale = await db
          .from("pairing_requests")
          .update({ status: "cancelled", responded_at: new Date().toISOString() })
          .eq("child_user_id", auth.user.id)
          .eq("status", "pending_child");
        ensureNoError(cancelStale);

        await recordAudit(db, {
          actorUserId: auth.user.id,
          eventType: "pairing_code_created",
          targetType: "device_pairing_token",
          targetId: tokenId,
        });

        return ok({
          code,
          qr_payload: `parentcontrol://pair?code=${code}&v=1`,
          expires_at: (inserted.data as { expires_at: string }).expires_at,
        });
      }

      case "redeem": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const rawCode = readString(body.code, "code", { min: 1, max: 32 });
        const familyId = readUuid(body.family_id, "family_id");
        await assertFamilyParent(db, auth.user.id, familyId);

        const normalized = normalizePairingCode(rawCode);
        const codeHash = await sha256Hex(normalized);
        await assertPairingRedeemAllowed(db, auth.user.id, codeHash);

        if (!isPairingCode(normalized)) {
          await recordPairingAttempt(db, auth.user.id, codeHash, false);
          throw new ApiError("invalid_code", "The linking code is not valid.", 400);
        }

        const tokenResult = await db
          .from("device_pairing_tokens")
          .select("id, child_user_id, status, expires_at, attempts, max_attempts")
          .eq("code_hash", codeHash)
          .maybeSingle();
        ensureNoError(tokenResult);
        const token = tokenResult.data as TokenRow | null;
        if (!token) {
          await recordPairingAttempt(db, auth.user.id, codeHash, false);
          throw new ApiError("invalid_code", "The linking code is not valid.", 400);
        }
        if (
          token.status !== "active" ||
          new Date(token.expires_at).getTime() <= Date.now()
        ) {
          if (token.status === "active") {
            await db
              .from("device_pairing_tokens")
              .update({ status: "expired" })
              .eq("id", token.id)
              .eq("status", "active");
          }
          await recordPairingAttempt(db, auth.user.id, codeHash, false);
          // Uniform answer for unknown/expired codes (prevents enumeration).
          throw new ApiError("invalid_code", "The linking code is not valid.", 400);
        }

        // The child must not already belong to an active family.
        const childLinked = await db
          .from("family_members")
          .select("family_id")
          .eq("user_id", token.child_user_id)
          .eq("role", "child")
          .eq("status", "active")
          .maybeSingle();
        ensureNoError(childLinked);
        if (childLinked.data) {
          await recordPairingAttempt(db, auth.user.id, codeHash, true);
          throw new ApiError(
            "child_already_linked",
            "This child account is already linked to a family.",
            409,
          );
        }

        const existingResult = await db
          .from("pairing_requests")
          .select("*")
          .eq("token_id", token.id)
          .maybeSingle();
        ensureNoError(existingResult);
        const childName = await profileName(db, token.child_user_id);
        const existing = existingResult.data as PairingRequestRow | null;
        if (existing) {
          if (
            existing.parent_user_id === auth.user.id &&
            existing.family_id === familyId &&
            existing.status === "pending_child" &&
            new Date(existing.expires_at).getTime() > Date.now()
          ) {
            await recordPairingAttempt(db, auth.user.id, codeHash, true);
            return ok(
              redeemPayload(
                existing.id,
                existing.token_id,
                existing.family_id,
                await familyName(db, existing.family_id),
                auth,
                existing.child_user_id,
                childName,
                existing.status,
                existing.created_at,
                existing.expires_at,
                existing.responded_at,
              ),
            );
          }
          await recordPairingAttempt(db, auth.user.id, codeHash, false);
          throw new ApiError("code_unavailable", "This linking code was used.", 409);
        }

        const familyLabel = await familyName(db, familyId);
        const inserted = await db
          .from("pairing_requests")
          .insert({
            token_id: token.id,
            family_id: familyId,
            parent_user_id: auth.user.id,
            child_user_id: token.child_user_id,
            status: "pending_child",
            expires_at: token.expires_at,
          })
          .select("*")
          .single();
        if (inserted.error) {
          if (inserted.error.code === "23505") {
            await recordPairingAttempt(db, auth.user.id, codeHash, false);
            throw new ApiError("code_unavailable", "This linking code was used.", 409);
          }
          console.error(`pairing_request_insert_failed:${inserted.error.code ?? "unknown"}`);
          throw new ApiError(
            "internal_error",
            "The linking request could not be created.",
            500,
          );
        }
        const request = inserted.data as PairingRequestRow;

        await recordPairingAttempt(db, auth.user.id, codeHash, true);
        await recordAudit(db, {
          familyId,
          actorUserId: auth.user.id,
          eventType: "pairing_redeemed",
          targetType: "pairing_request",
          targetId: request.id,
          metadata: { child_user_id: token.child_user_id },
        });

        return ok(
          redeemPayload(
            request.id,
            request.token_id,
            request.family_id,
            familyLabel,
            auth,
            request.child_user_id,
            childName,
            request.status,
            request.created_at,
            request.expires_at,
            request.responded_at,
          ),
        );
      }

      case "pending_child": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const nowIso = new Date().toISOString();

        const expireRequests = await db
          .from("pairing_requests")
          .update({ status: "expired", responded_at: nowIso })
          .eq("child_user_id", auth.user.id)
          .eq("status", "pending_child")
          .lte("expires_at", nowIso);
        ensureNoError(expireRequests);
        const expireTokens = await db
          .from("device_pairing_tokens")
          .update({ status: "expired" })
          .eq("child_user_id", auth.user.id)
          .eq("status", "active")
          .lte("expires_at", nowIso);
        ensureNoError(expireTokens);

        const result = await db
          .from("pairing_requests")
          .select("*")
          .eq("child_user_id", auth.user.id)
          .eq("status", "pending_child")
          .gt("expires_at", nowIso)
          .order("created_at", { ascending: false })
          .limit(50);
        ensureNoError(result);
        return ok(
          await decorateRequests(db, (result.data ?? []) as PairingRequestRow[]),
        );
      }

      case "respond": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const requestId = readUuid(body.request_id, "request_id");
        const approve = readBoolean(body.approve, "approve");

        const rpc = await db.rpc("respond_pairing_request", {
          p_request_id: requestId,
          p_child_user_id: auth.user.id,
          p_approve: approve,
        });
        if (rpc.error) {
          mapResponseRpcError(rpc.error.message ?? "");
        }
        return ok(rpc.data);
      }

      case "cancel": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const requestId = readUuid(body.request_id, "request_id");

        const result = await db
          .from("pairing_requests")
          .select("*")
          .eq("id", requestId)
          .maybeSingle();
        ensureNoError(result);
        const request = result.data as PairingRequestRow | null;
        if (!request) {
          throw new ApiError("request_not_found", "The request was not found.", 404);
        }
        await assertFamilyParent(db, auth.user.id, request.family_id);
        if (request.status === "cancelled") {
          return ok({ status: "cancelled", request_id: request.id });
        }
        if (request.status !== "pending_child") {
          throw new ApiError(
            "request_already_responded",
            "This request has already been answered.",
            409,
          );
        }
        if (new Date(request.expires_at).getTime() <= Date.now()) {
          throw new ApiError(
            "code_expired",
            "This linking request has expired.",
            410,
          );
        }

        const updated = await db
          .from("pairing_requests")
          .update({ status: "cancelled", responded_at: new Date().toISOString() })
          .eq("id", request.id)
          .eq("status", "pending_child")
          .select("id, status")
          .maybeSingle();
        ensureNoError(updated);
        const revokeToken = await db
          .from("device_pairing_tokens")
          .update({ status: "revoked" })
          .eq("id", request.token_id);
        ensureNoError(revokeToken);

        await recordAudit(db, {
          familyId: request.family_id,
          actorUserId: auth.user.id,
          eventType: "pairing_cancelled",
          targetType: "pairing_request",
          targetId: request.id,
        });
        return ok({ status: "cancelled", request_id: request.id });
      }

      case "list_family": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const familyId = readUuid(body.family_id, "family_id");
        await assertFamilyParent(db, auth.user.id, familyId);

        const result = await db
          .from("pairing_requests")
          .select("*")
          .eq("family_id", familyId)
          .order("created_at", { ascending: false })
          .limit(100);
        ensureNoError(result);
        return ok(
          await decorateRequests(db, (result.data ?? []) as PairingRequestRow[]),
        );
      }

      case "unlink": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        const familyId = readUuid(body.family_id, "family_id");
        const childUserId = readUuid(body.child_user_id, "child_user_id");

        if (auth.user.id === childUserId) {
          requireRole(auth.profile, "child");
          await assertChildMembership(db, auth.user.id, familyId);
        } else {
          requireRole(auth.profile, "parent");
          await assertFamilyParent(db, auth.user.id, familyId);
        }

        const rpc = await db.rpc("unlink_child", {
          p_family_id: familyId,
          p_child_user_id: childUserId,
          p_actor_user_id: auth.user.id,
        });
        if (rpc.error) {
          const message = rpc.error.message ?? "";
          if (message.includes("membership_not_found")) {
            throw new ApiError(
              "membership_not_found",
              "That child is not linked to this family.",
              404,
            );
          }
          if (message.includes("forbidden")) {
            throw new ApiError("forbidden", "You cannot unlink this account.", 403);
          }
          console.error(`unlink_rpc_failed:${rpc.error.code ?? "unknown"}`);
          throw new ApiError("internal_error", "The account could not be unlinked.", 500);
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
