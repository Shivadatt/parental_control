# 07 — Security and Approval-Required Register

This register is separate from the 80-function inventory. It does not authorize execution.

## 1. Security issue

### SEC-001 — Password field exposes entered password in plaintext

| Field | Record |
|---|---|
| Severity | **HIGH — PROVISIONAL, REQUIRES SECURITY REVIEW** |
| Status | **OPEN — NOT FIXED** |
| Reproduction context | Parent Sign-in screen on Pixel_9a |
| Expected | Password input uses secure password semantics and masks the entered value |
| Actual | Entered password was visible in plaintext and the UI node reported `password=false` |
| Phase 6 evidence | Observed during Run 8; transient pre-submit screenshot and UI dump containing the field were deleted; no password retained in evidence |
| Required future evidence | Safe screenshot showing masking without any real password; accessibility/UI metadata confirming secure password semantics |
| Session safety | Current Parent session must remain authenticated. No sign-out, app-data clearing, or credential entry is authorized. |
| Safe route | Only an already-accessible, non-destructive route supported by existing source/documentation evidence may be used. No such route is assumed. |
| Test status | `P6-SEC-001` is **NOT TESTED** and its approval gate is **BLOCKED — REQUIRES SEPARATE SESSION-PRESERVATION APPROVAL**. |
| Test case | `P6-SEC-001` |
| Count impact | **Not one of the 80 functionalities** |

No real credential may be entered to reproduce this issue. Use only a synthetic dummy value and do not submit it. The issue remains open. Source changes are outside this task.

## 2. Approval and absolute-prohibition scenarios

| Scenario ID | Scenario | Related ID / case | Why approval is required | Status |
|---|---|---|---|---|
| APR-01 | Account deletion | A09 / P6-SHR-009 | Destructive account loss | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-02 | Family deletion | M09 (absent) | Destructive family loss; no implemented flow | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-03 | Child unlink | FAM10 / P6-PAR-007 | Changes persistent family relationship | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-04 | Device revoke | FAM12 / P6-PAR-008 | Changes persistent device access | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-05 | Device re-registration | FAM07 / P6-CHD-003 | Replaces registration identity | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-06 | Pairing cancellation or decline | FAM04, FAM05 / P6-PAR-036, P6-CHD-001 | Changes pending/persistent relationship | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-07 | Credential recovery or rotation | FAM13, MON04 / P6-PAR-009, P6-LIM-001 | Changes authentication identity/secret | ABSOLUTELY PROHIBITED AGAINST PRESERVED QA ACCOUNTS — ISOLATED ENVIRONMENT REQUIRED |
| APR-08 | Secure-storage reset | MON04 / P6-LIM-001 | Destroys device credentials | ABSOLUTELY PROHIBITED AGAINST PRESERVED QA ACCOUNTS — ISOLATED ENVIRONMENT REQUIRED |
| APR-09 | Local app-data deletion | Environment-wide | Destroys sessions, settings, evidence | ABSOLUTELY PROHIBITED — DESTROYS PRESERVED SESSIONS AND APP DATA |
| APR-10 | Remote lock or wipe | M05 (absent) | Irreversible device impact | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-11 | Retention deletion or purge | AUD03 / P6-PAR-033 | Deletes retained backend data | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-12 | Parent leave-family | M09 (absent) | Changes family membership | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-13 | Family owner transfer | M09 (absent) | Changes family authority | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| APR-14 | Reinstall or QA-relationship change | FAM07, MON04 | Breaks current QA environment | ABSOLUTELY PROHIBITED — PRESERVED QA ENVIRONMENT MUST REMAIN |

## 2a. Session preservation (absolute)

Existing Parent and Child QA sessions must never be signed out, replaced, invalidated, or modified. This rule cannot be overridden by owner approval, a case-level gate, an approval-register scenario, a risk classification, a dependency, a reversible-action claim, or owner-entered credentials.

- **Permitted:** read-only observation of current session state and the visible sign-out affordance.
- **Prohibited:** executing sign-out, clearing sessions, replacing sessions, re-authenticating, or changing credentials against the preserved QA accounts.
- **Future isolated authentication testing:** requires a separately designed and explicitly approved isolated environment that does not disturb the preserved QA accounts. Until then, it is `BLOCKED — SEPARATE ISOLATED AUTHENTICATION ENVIRONMENT AND EXPLICIT OWNER APPROVAL REQUIRED`.

## 3. Approval policy

- Preparation of a case is not permission to execute it.
- Every case-level approval gate remains binding even if the scenario is not individually listed in the 14-scenario register.
- The register covers the minimum owner-approval categories; it is not a complete list of every high-risk write case.
- Each approval must name the scenario, scope, device, expected state change, and restoration plan.
- High-risk writes that are reversible but change policy, retention, pairing, or other persistent state require explicit approval.
- No approval may authorize sign-out, session replacement, session invalidation, credential change, secure-storage reset, app-data clearing, or reinstall against the preserved QA accounts. Those actions are absolutely prohibited in this environment.
- Destructive scenarios remain blocked even if a test case is otherwise complete.
- No approval covers a different scenario, device, account, or build.
- If an approved action cannot be safely restored, stop and return to owner review.

## 4. Count

Registered scenarios: **14** (APR-01 through APR-14). This is an approval/security register, not a guarantee that every scenario is approval-eligible; APR-07, APR-08, APR-09, and APR-14 are absolute prohibitions against the preserved QA accounts and environment. SEC-001 is a separate security issue and is not included in the 80 inventory.
