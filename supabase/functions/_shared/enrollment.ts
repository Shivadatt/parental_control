// Re-enrollment gate: a revoked child device stays blocked until a parent
// removes the child and a new pairing request is approved afterwards.
export function requiresRelink(
  revokedAt: string | null | undefined,
  latestApprovalAt: string | null | undefined,
): boolean {
  const revokedMs = revokedAt ? Date.parse(revokedAt) : Number.NaN;
  if (!Number.isFinite(revokedMs)) return true;
  const approvedMs = latestApprovalAt
    ? Date.parse(latestApprovalAt)
    : Number.NaN;
  return !Number.isFinite(approvedMs) || approvedMs <= revokedMs;
}
