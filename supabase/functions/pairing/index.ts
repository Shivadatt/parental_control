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
  assertInviteQuotaAllowed,
  assertPairingCodeCreationAllowed,
  assertPairingRedeemAllowed,
  recordPairingAttempt,
} from "../_shared/rate_limit.ts";
import {
  formatChildContactId,
  generateChildContactId,
  generatePairingCode,
  identifierHash,
  isChildContactId,
  isPairingCode,
  normalizePairingCode,
  readBoolean,
  readString,
  readUuid,
  sha256Hex,
} from "../_shared/validation.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const CODE_TTL_MINUTES = 10;
/** A Child ID invite is answered on the child's own schedule, not in 10 min. */
const INVITE_TTL_MINUTES = 24 * 60;

/** One identical answer for every unusable identifier, so neither the code
 * path nor the Child ID path can be used to enumerate accounts. */
const INVALID_IDENTIFIER = "The linking code or Child ID is not valid.";

/** What a guardian sees until the child themselves approves the request. */
const PENDING_CHILD_LABEL = "Child account (pending approval)";

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

interface ContactRow {
  child_user_id: string;
  contact_id: string;
  created_at: string;
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
  options: { maskPendingChildName?: boolean } = {},
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
  return rows.map((row) => {
    const childLabel =
      options.maskPendingChildName && row.status === "pending_child"
        ? PENDING_CHILD_LABEL
        : (displayNames.get(row.child_user_id) ?? "Child account");
    return {
      ...row,
      family_name: familyNames.get(row.family_id) ?? "Family",
      parent_display_name: displayNames.get(row.parent_user_id) ?? "Guardian",
      child_display_name: childLabel,
      // Nested shapes keep the Flutter wire model compatible while the flat
      // fields remain the contract-defined response.
      families: {
        id: row.family_id,
        name: familyNames.get(row.family_id) ?? "Family",
      },
      parent_profile: { display_name: displayNames.get(row.parent_user_id) ?? "Guardian" },
      child_profile: { display_name: childLabel },
    };
  });
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
  // Until the child approves, a guardian confirms *which account* by the
  // identifier they entered, not by the server's record: returning the display
  // name here would turn any guessed Child ID into a name lookup.
  const childLabel = status === "approved" ? childName : PENDING_CHILD_LABEL;
  return {
    id: requestId,
    token_id: tokenId,
    family_id: familyId,
    family_name: familyLabel,
    parent_user_id: parent.user.id,
    parent_display_name: parent.profile.display_name,
    child_user_id: childUserId,
    child_display_name: childLabel,
    status,
    created_at: createdAt,
    expires_at: expiresAt,
    responded_at: respondedAt,
    families: { id: familyId, name: familyLabel },
    parent_profile: { display_name: parent.profile.display_name },
    child_profile: { display_name: childLabel },
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

/**
 * Returns the child's permanent Child ID, assigning one on first use. Safe to
 * call on every read: it is idempotent, and a concurrent caller that loses the
 * insert race simply reads the winner's row.
 */
async function ensureContactId(
  db: SupabaseClient,
  childUserId: string,
): Promise<ContactRow> {
  const select = "child_user_id, contact_id, created_at";
  const existing = await db
    .from("child_contact_ids")
    .select(select)
    .eq("child_user_id", childUserId)
    .maybeSingle();
  ensureNoError(existing);
  if (existing.data) return existing.data as ContactRow;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const inserted = await db
      .from("child_contact_ids")
      .insert({ child_user_id: childUserId, contact_id: generateChildContactId() })
      .select(select)
      .single();
    if (!inserted.error && inserted.data) return inserted.data as ContactRow;
    if (inserted.error?.code !== "23505") {
      console.error(`contact_id_insert_failed:${inserted.error?.code ?? "unknown"}`);
      throw new ApiError("internal_error", "A Child ID could not be assigned.", 500);
    }
    const reread = await db
      .from("child_contact_ids")
      .select(select)
      .eq("child_user_id", childUserId)
      .maybeSingle();
    ensureNoError(reread);
    if (reread.data) return reread.data as ContactRow;
  }
  throw new ApiError("internal_error", "A Child ID could not be assigned.", 500);
}

function contactPayload(row: ContactRow): Record<string, unknown> {
  return {
    contact_id: formatChildContactId(row.contact_id),
    contact_id_canonical: row.contact_id,
    qr_payload: `parentcontrol://pair?id=${row.contact_id}&v=2`,
    created_at: row.created_at,
  };
}

/**
 * A parent opens a pairing request from a permanent Child ID.
 *
 * The Child ID only identifies the account. It never grants data access: the
 * result is a normal `pending_child` request that the child must approve. The
 * single-use token is still created, but server-side, so the child no longer
 * has to mint one and `pairing_requests.token_id` keeps its replay guard.
 */
async function handleInvite(
  db: SupabaseClient,
  auth: AuthContext,
  contactId: string,
  familyId: string,
): Promise<Record<string, unknown>> {
  const lookupHash = await identifierHash(contactId);
  await assertPairingRedeemAllowed(db, auth.user.id, lookupHash);

  const contactResult = await db
    .from("child_contact_ids")
    .select("child_user_id")
    .eq("contact_id", contactId)
    .maybeSingle();
  ensureNoError(contactResult);
  const contact = contactResult.data as { child_user_id: string } | null;
  if (!contact) {
    await recordPairingAttempt(db, auth.user.id, lookupHash, false);
    throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
  }

  // A parent account's own ID must not be linkable as a child.
  const childProfile = await db
    .from("profiles")
    .select("role")
    .eq("id", contact.child_user_id)
    .maybeSingle();
  ensureNoError(childProfile);
  if ((childProfile.data as { role?: string } | null)?.role !== "child") {
    await recordPairingAttempt(db, auth.user.id, lookupHash, false);
    throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
  }

  const childLinked = await db
    .from("family_members")
    .select("family_id")
    .eq("user_id", contact.child_user_id)
    .eq("role", "child")
    .eq("status", "active")
    .maybeSingle();
  ensureNoError(childLinked);
  const linkedFamilyId =
    (childLinked.data as { family_id?: string } | null)?.family_id ?? null;
  if (linkedFamilyId) {
    // A guardian of the requested family already knows this child, so naming
    // the link state costs nothing. Any other family must not learn that the
    // identifier exists or that it is linked: same failure as an unknown ID.
    if (linkedFamilyId === familyId) {
      await recordPairingAttempt(db, auth.user.id, lookupHash, true);
      throw new ApiError(
        "child_already_linked",
        "This child account is already linked to a family.",
        409,
      );
    }
    await recordPairingAttempt(db, auth.user.id, lookupHash, false);
    throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
  }

  const childName = await profileName(db, contact.child_user_id);

  // Fast path for an honest retry: asking again for a live invitation must
  // return it rather than be refused as "too many pending requests". The RPC
  // repeats this lookup under the advisory lock, so this read cannot create a
  // duplicate; it only avoids spending quota on a request that already exists.
  const existingResult = await db
    .from("pairing_requests")
    .select("*")
    .eq("child_user_id", contact.child_user_id)
    .eq("family_id", familyId)
    .eq("parent_user_id", auth.user.id)
    .eq("status", "pending_child")
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1);
  ensureNoError(existingResult);
  // `limit(1)` rather than `maybeSingle()`: pre-fix duplicates already exist in
  // some databases, and two live rows must not turn a retry into a 500.
  const existing =
    ((existingResult.data ?? []) as PairingRequestRow[])[0] ?? null;
  if (existing) {
    await recordPairingAttempt(db, auth.user.id, lookupHash, true);
    return redeemPayload(
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
    );
  }

  await assertInviteQuotaAllowed(db, contact.child_user_id);

  const expiresAt = new Date(
    Date.now() + INVITE_TTL_MINUTES * 60 * 1000,
  ).toISOString();
  const rpc = await db.rpc("create_pairing_invite", {
    p_child_user_id: contact.child_user_id,
    p_family_id: familyId,
    p_parent_user_id: auth.user.id,
    p_code_hash: await sha256Hex(generatePairingCode()),
    p_expires_at: expiresAt,
  });
  if (rpc.error) {
    console.error(`invite_rpc_failed:${rpc.error.code ?? "unknown"}`);
    throw new ApiError("internal_error", "The linking request could not be created.", 500);
  }

  const outcome = (rpc.data ?? {}) as {
    created?: boolean;
    request?: PairingRequestRow;
  };
  const request = outcome.request;
  if (
    !request?.id || !request.token_id || !request.family_id ||
    !request.child_user_id
  ) {
    console.error("invite_rpc_malformed");
    throw new ApiError("internal_error", "The linking request could not be created.", 500);
  }

  await recordPairingAttempt(db, auth.user.id, lookupHash, true);
  if (outcome.created === true) {
    await recordAudit(db, {
      familyId,
      actorUserId: auth.user.id,
      eventType: "pairing_invited",
      targetType: "pairing_request",
      targetId: request.id,
      metadata: {
        child_user_id: contact.child_user_id,
        // Identifies the flow, not the identifier: the Child ID itself is never
        // written into the parent-readable audit log.
        via: "child_id",
      },
    });
  }

  return redeemPayload(
    request.id,
    request.token_id,
    request.family_id,
    await familyName(db, request.family_id),
    auth,
    request.child_user_id,
    childName,
    request.status,
    request.created_at,
    request.expires_at,
    request.responded_at,
  );
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
      case "get_contact_id": {
        // Read-only for the caller: the identifier is assigned once and then
        // returned unchanged for as long as the account exists.
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "child");
        const row = await ensureContactId(db, auth.user.id);
        return ok(contactPayload(row));
      }

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
            purpose: "code",
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

        // Only previous *code* tokens are superseded. An invite token is
        // internal and belongs to a request the child has not answered yet.
        const revoke = await db
          .from("device_pairing_tokens")
          .update({ status: "revoked" })
          .eq("child_user_id", auth.user.id)
          .eq("status", "active")
          .eq("purpose", "code")
          .neq("id", tokenId)
          .select("id");
        ensureNoError(revoke);
        const replacedTokenIds = ((revoke.data ?? []) as { id: string }[]).map(
          (row) => row.id,
        );

        // Cancel only the requests whose code was just replaced, never every
        // pending request for the child: retrying a code must not silently
        // destroy a guardian's live invitation.
        if (replacedTokenIds.length > 0) {
          const cancelStale = await db
            .from("pairing_requests")
            .update({ status: "cancelled", responded_at: new Date().toISOString() })
            .in("token_id", replacedTokenIds)
            .eq("status", "pending_child");
          ensureNoError(cancelStale);
        }

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

        // A Child ID is a different identifier with a different lifecycle, so
        // it is routed on format. Both branches answer an unusable input with
        // the identical body, so neither can be used to probe the other.
        if (isChildContactId(normalized)) {
          return ok(await handleInvite(db, auth, normalized, familyId));
        }

        // Two digests on purpose: the token row keeps plain SHA-256 so codes
        // issued before this change still redeem, while attempt records use
        // the keyed digest so a database dump cannot recover the identifier.
        const codeHash = await sha256Hex(normalized);
        const attemptHash = await identifierHash(normalized);
        await assertPairingRedeemAllowed(db, auth.user.id, attemptHash);

        if (!isPairingCode(normalized)) {
          await recordPairingAttempt(db, auth.user.id, attemptHash, false);
          throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
        }

        const tokenResult = await db
          .from("device_pairing_tokens")
          .select("id, child_user_id, status, expires_at, attempts, max_attempts")
          .eq("code_hash", codeHash)
          .maybeSingle();
        ensureNoError(tokenResult);
        const token = tokenResult.data as TokenRow | null;
        if (!token) {
          await recordPairingAttempt(db, auth.user.id, attemptHash, false);
          throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
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
          await recordPairingAttempt(db, auth.user.id, attemptHash, false);
          // Uniform answer for unknown/expired codes (prevents enumeration).
          throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
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
        const linkedFamilyId =
          (childLinked.data as { family_id?: string } | null)?.family_id ?? null;
        if (linkedFamilyId) {
          // Same rule as the Child ID path: only the family the child already
          // belongs to may learn the link state; everyone else gets the
          // uniform "unknown identifier" failure.
          if (linkedFamilyId === familyId) {
            await recordPairingAttempt(db, auth.user.id, attemptHash, true);
            throw new ApiError(
              "child_already_linked",
              "This child account is already linked to a family.",
              409,
            );
          }
          await recordPairingAttempt(db, auth.user.id, attemptHash, false);
          throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
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
            await recordPairingAttempt(db, auth.user.id, attemptHash, true);
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
          await recordPairingAttempt(db, auth.user.id, attemptHash, false);
          throw new ApiError("code_unavailable", "This linking code was used.", 409);
        }

        // The per-child inbox cap protects this path too: the permanent-ID
        // entry point must not be the only one that respects a minor's inbox.
        await assertInviteQuotaAllowed(db, token.child_user_id);

        const rpc = await db.rpc("create_pairing_request", {
          p_child_user_id: token.child_user_id,
          p_family_id: familyId,
          p_parent_user_id: auth.user.id,
          p_token_id: token.id,
          p_expires_at: token.expires_at,
        });
        if (rpc.error) {
          console.error(`redeem_rpc_failed:${rpc.error.code ?? "unknown"}`);
          if ((rpc.error.message ?? "").includes("code_unavailable")) {
            // The token itself was redeemed concurrently for another triple.
            await recordPairingAttempt(db, auth.user.id, attemptHash, false);
            throw new ApiError("code_unavailable", "This linking code was used.", 409);
          }
          throw new ApiError(
            "internal_error",
            "The linking request could not be created.",
            500,
          );
        }

        const outcome = (rpc.data ?? {}) as {
          created?: boolean;
          request?: PairingRequestRow;
        };
        const request = outcome.request;
        if (
          !request?.id || !request.token_id || !request.family_id ||
          !request.child_user_id
        ) {
          console.error("redeem_rpc_malformed");
          throw new ApiError(
            "internal_error",
            "The linking request could not be created.",
            500,
          );
        }

        if (outcome.created !== true) {
          // A live request already exists for this triple, possibly opened from
          // a different code. The code just used must not stay redeemable.
          const revoke = await db
            .from("device_pairing_tokens")
            .update({ status: "revoked" })
            .eq("id", token.id)
            .eq("status", "active");
          ensureNoError(revoke);
          await recordPairingAttempt(db, auth.user.id, attemptHash, true);
          return ok(
            redeemPayload(
              request.id,
              request.token_id,
              request.family_id,
              await familyName(db, request.family_id),
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

        await recordPairingAttempt(db, auth.user.id, attemptHash, true);
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
            await familyName(db, request.family_id),
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

      case "invite": {
        const auth = await requireUser(req, db, { requireVerifiedEmail: true });
        requireRole(auth.profile, "parent");
        const familyId = readUuid(body.family_id, "family_id");
        await assertFamilyParent(db, auth.user.id, familyId);

        const normalized = normalizePairingCode(
          readString(body.child_id, "child_id", { min: 1, max: 32 }),
        );
        if (!isChildContactId(normalized)) {
          // Malformed input costs one attempt so garbage cannot be free.
          const lookupHash = await identifierHash(normalized);
          await recordPairingAttempt(db, auth.user.id, lookupHash, false);
          throw new ApiError("invalid_code", INVALID_IDENTIFIER, 400);
        }
        return ok(await handleInvite(db, auth, normalized, familyId));
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
        if (!updated.data) {
          // The child answered between the read and the update. Report the
          // status the server actually stored instead of a cancel that did not
          // happen, and leave the now-redeemed token untouched.
          const current = await db
            .from("pairing_requests")
            .select("status")
            .eq("id", request.id)
            .maybeSingle();
          ensureNoError(current);
          const status =
            (current.data as { status?: string } | null)?.status ?? "unknown";
          throw new ApiError(
            "conflict",
            `This request was already answered as ${status}.`,
            409,
          );
        }
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
          await decorateRequests(
            db,
            (result.data ?? []) as PairingRequestRow[],
            // Guardian-facing view: a not-yet-approved child's name must not be
            // readable here either.
            { maskPendingChildName: true },
          ),
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
