# 04 — Security and Approval-Gate Audit

## 1. SEC-001 review

| Check | Result |
|---|---|
| Separate from the 80 functionality IDs | Yes — recorded as `SECURITY ISSUE`, role `Security (outside inventory)` |
| Open security issue | Yes — `OPEN — NOT FIXED` |
| Severity provisional | Yes — `HIGH — PROVISIONAL, REQUIRES SECURITY REVIEW` |
| Real password/token in reports | None found |
| Reproduction requires real credential | No — synthetic dummy value only |
| Evidence requirements expose secrets | No — masked screenshot and redacted metadata |
| Incorrectly marked fixed | No |
| Counted in the 90 test cases | Yes, as `P6-SEC-001`; not counted in the 80 functionality IDs |

### SEC-001 finding

`P6-SEC-001` does not explain how the Parent reaches the Sign-in screen while the existing authenticated Parent session is preserved. Opening Sign-in may require signing out, which is approval-gated elsewhere. The case gate says `OPEN SECURITY REVIEW — PROVISIONAL HIGH`, but does not explicitly approve or prohibit a session change.

**Severity: Medium.** Proposed documentation correction: state a safe route to Sign-in that does not sign out, or add an explicit session-preservation approval gate. Do not reproduce the defect now.

## 2. Approval-gated scenarios (14)

| Scenario | Risk explanation | Owner dependency | Recorded status | Consistent? |
|---|---|---|---|---|
| APR-01 Account deletion | Irreversible account loss | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-02 Family deletion | Irreversible family loss | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-03 Child unlink | Persistent relationship change | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-04 Device revoke | Persistent device access change | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-05 Device re-registration | Replaces registration identity | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-06 Pairing cancellation/decline | Persistent relationship change | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-07 Credential recovery/rotation | Changes authentication secret | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-08 Secure-storage reset | Destroys device credentials | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-09 Local app-data deletion | Destroys sessions, settings, evidence | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-10 Remote lock/wipe | Irreversible device impact | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-11 Retention deletion/purge | Deletes retained backend data | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-12 Parent leave-family | Changes family membership | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-13 Family owner transfer | Changes family authority | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |
| APR-14 Reinstall or QA-relationship change | Breaks current QA environment | Explicit owner approval | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Yes |

All 14 have a reason, a blocked status, and an owner-approval dependency.

## 3. Unsafe or insufficiently gated steps

| Case | Issue | Severity | Proposed correction |
|---|---|---|---|
| P6-SEC-001 | Sign-in route may disturb the preserved session; gate is security review, not session approval | Medium | Add safe route or explicit session gate |
| P6-PAR-028 | Step says “acknowledge if reversible and approved”; gate says NONE | Medium | Add gate or make the step read-only |
| P6-CHD-016 | Step says restart “only if safe and approved”; gate says NONE | Medium | Add gate or restrict to status observation |
| P6-SHR-012 | Permission prompt may change runtime permission if accepted | Low | State “do not accept; dismiss/deny” explicitly |
| P6-PAR-024 | Sync command is persistent but Medium with no gate | Low | Keep non-destructive or add controlled-command gate |
| P6-PAR-004 | Listing is safe but cancellation is gated; case mixes both | Low | Split listing and cancellation |

No High or Destructive test case lacks an approval or dependency gate. No approval register entry authorizes execution.

## 4. Required owner decisions

1. Whether SEC-001 verification may use a safe Sign-in route or requires a session-change approval.
2. Whether any of the 14 approval-gated scenarios will be authorized, and with what restoration plan.
3. Whether high-risk but reversible policy, retention, pairing, device-admin, and session writes will be individually approved.
4. Whether the ten absent capabilities are in or out of product scope.
5. Whether documentation corrections in this review are authorized before approval.

## 5. Verdict for this section

Approval architecture is sound. Two cases have gate inconsistencies, and SEC-001 needs a safe-route clarification. These are documentation corrections, not execution failures.
