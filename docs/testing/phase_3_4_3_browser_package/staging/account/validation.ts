// Pure validation for the `account` Edge Function.
//
// Account deletion is irreversible, so the confirmation rules are kept pure and
// unit-tested: the literal word DELETE, plus the caller's own email typed back.
// No Supabase import here; `deno test supabase/functions/account` runs offline.

/** The only accepted confirmation word. Case-sensitive on purpose. */
export const DELETE_CONFIRMATION = "DELETE";

export interface DeleteAccountInput {
  confirm: unknown;
  email: unknown;
  /** Verified JWT email of the caller, or null when the token carries none. */
  callerEmail: string | null | undefined;
}

export interface ValidationFailure {
  /** Stable wire code for the client. */
  code: string;
  message: string;
  status: number;
}

/** Trims and lowercases an email for comparison; null when unusable. */
export function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed.length === 0 ? null : trimmed;
}

/**
 * Returns the first reason the request must be refused, or null when it is
 * well formed. Deliberately generic messages: neither the typed value nor the
 * account email is echoed back.
 */
export function validateDeleteAccountInput(
  input: DeleteAccountInput,
): ValidationFailure | null {
  const callerEmail = normalizeEmail(input.callerEmail);
  if (callerEmail === null) {
    return {
      code: "email_unavailable",
      message: "The account email is not available. Sign in again.",
      status: 409,
    };
  }
  if (
    typeof input.confirm !== "string" ||
    input.confirm.trim() !== DELETE_CONFIRMATION
  ) {
    return {
      code: "confirmation_required",
      message: `Type ${DELETE_CONFIRMATION} to confirm account deletion.`,
      status: 400,
    };
  }
  const typedEmail = normalizeEmail(input.email);
  if (typedEmail === null || typedEmail !== callerEmail) {
    return {
      code: "email_mismatch",
      message: "The typed email does not match the signed-in account.",
      status: 400,
    };
  }
  return null;
}

export interface OwnedFamilyCounts {
  familyId: string;
  /** Active members of the family other than the caller. */
  otherActiveMembers: number;
  /** Active (paired, non-revoked) devices in the family. */
  activeDevices: number;
}

export type DeletionBlockReason =
  | "owned_family_has_other_members"
  | "owned_family_has_active_devices";

export interface DeletionBlocker {
  blocked_reason: DeletionBlockReason;
  message: string;
  family_ids: string[];
}

/**
 * The owner of a family cannot delete their account while the family still has
 * another active member or an active device: those rows would either be
 * orphaned or silently destroyed for somebody else. Other members must be
 * unlinked/transferred and devices revoked first.
 *
 * The caller's own membership row and own devices are not "other" data, so the
 * counts are computed server-side with `user_id <> caller`.
 */
export function findDeletionBlocker(
  families: readonly OwnedFamilyCounts[],
): DeletionBlocker | null {
  const withMembers = families.filter((f) => f.otherActiveMembers > 0);
  if (withMembers.length > 0) {
    return {
      blocked_reason: "owned_family_has_other_members",
      message:
        "Remove or transfer the other members of your family before deleting your account.",
      family_ids: withMembers.map((f) => f.familyId),
    };
  }
  const withDevices = families.filter((f) => f.activeDevices > 0);
  if (withDevices.length > 0) {
    return {
      blocked_reason: "owned_family_has_active_devices",
      message:
        "Revoke the active devices in your family before deleting your account.",
      family_ids: withDevices.map((f) => f.familyId),
    };
  }
  return null;
}