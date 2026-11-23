# 02 — Corrected Finding Verification

Each first-review finding was checked against the actual corrected files. No finding was accepted from the correction log alone.

## Verdict table

| Finding | Verdict | Evidence |
|---|---|---|
| M-01 | VERIFIED CORRECTED | Reports 01 and 09 define Low/Medium/High/Destructive; report 01 states risk levels are not permission to execute. |
| M-02 | PARTIALLY CORRECTED | Report 04 has all seven requested cases with start, window, cadence, propagation, delayed and INCONCLUSIVE rules. Values are not labelled “PROPOSED — OWNER REVIEW REQUIRED”; they are labelled “PROVISIONAL QA OBSERVATION PARAMETERS — NOT APPLICATION SLAs.” |
| M-03 | PARTIALLY CORRECTED | `P6-SHR-001` no longer mentions invalid credentials, and `P6-SHR-015` covers invalid credentials in an isolated environment. But `P6-SHR-001` still says “If approved, sign out and sign in,” contrary to M-03’s “never sign out” requirement. |
| M-04 | PARTIALLY CORRECTED | State cases exist; `P6-PAR-004` is split. But `P6-SHR-012` still triggers a permission request without explicit dismiss/deny-only language and has Approval Gate NONE. |
| M-05 | VERIFIED CORRECTED | SEC-001 remains open/provisional High, outside the 80; `P6-SEC-001` is blocked pending session-preservation approval and does not assume a safe route. |
| M-06 | VERIFIED CORRECTED | `P6-PAR-028` and `P6-CHD-016` are read-only; acknowledgement and restart are separately gated as `P6-PAR-037` and `P6-CHD-020`. |
| L-01 | VERIFIED CORRECTED | `P6-SHR-010` / A10 category is `Account`, matching the inventory. |
| L-02 | VERIFIED CORRECTED | Report 05 distinguishes 11 primary items, 7 limitation cases, 2 UI, 2 backend, and 18 referenced cases, explicitly not 18 unique functionality IDs. |
| L-03 | VERIFIED CORRECTED | `FAM13`, `MON02`, and `REM02` use the exact inventory names in reports 01–03. Report 12 still contains stale “abbreviations remain faithful” wording. |
| I-01 | VERIFIED | Report 10 documents SET01/SET02 function-level plus UI-only duplicate pairs. |
| I-02 | VERIFIED | Report 07 says the 14-entry register is a minimum and case-level gates are binding; APR-06 now references `P6-PAR-036`. |
| I-03 | PARTIALLY CORRECTED | Policy text exists, but `P6-PAR-024` and `P6-SHR-012` remain persistent/permission-changing cases with no gate. |

## M-01 detail

- Report 01 risk table uses the required Low/Medium/High/Destructive definitions.
- Report 09 repeats the definitions.
- Risk is explicitly separated from permission: “Existing risk levels are not downgraded to make cases executable” and “Preparation of a case is not permission to execute it.”

## M-02 detail

All seven required cases appear in the report 04 timing table:

`P6-INT-001`, `P6-INT-005`, `P6-INT-006`, `P6-INT-007`, `P6-INT-008`, `P6-INT-009`, `P6-INT-010`.

Each has an observation start, maximum window, cadence, propagation expectation, delayed threshold, INCONCLUSIVE condition, and approval column. Outcome distinctions include child offline, parent offline, backend unavailable, auth failure, credential failure, delayed synchronization, genuine failure, and insufficient evidence.

Remaining defect: the values are not labelled with the second-review-required phrase `PROPOSED — OWNER REVIEW REQUIRED`. They are described as provisional and owner decision is deferred in report 12, but the exact status label is absent.

## M-03 detail

`P6-SHR-001` now has a single valid sign-in/observation objective. `P6-SHR-015` is the separate invalid-credential case and is blocked on an isolated auth environment. `P6-SHR-016` is the backend/auth error refresh case and is blocked on a safe fixture.

Remaining defect: `P6-SHR-001` steps still say “If approved, sign out and sign in with owner-entered credentials.” The correction requirement says never sign out the existing Parent or Child accounts. A gated instruction does not satisfy an absolute preservation rule.

## M-04 detail

Added state cases cover Parent dashboard/devices, family/usage/location/alerts/audit, and Child home/rules. They are read-only and prohibit forced empty/offline/permission states. `P6-PAR-004` is now list/empty-only; cancellation is `P6-PAR-036`, gated.

Remaining defect: `P6-SHR-012` still says “Trigger a safe re-request” and expects “Correct permission.” It does not explicitly require denying or dismissing the prompt, and its gate is NONE.

## M-05 detail

- SEC-001 remains outside the 80 and is still `OPEN — NOT FIXED`.
- Severity remains `HIGH — PROVISIONAL, REQUIRES SECURITY REVIEW`.
- Safe-route evidence is not assumed.
- `P6-SEC-001` gate is `BLOCKED — REQUIRES SEPARATE SESSION-PRESERVATION APPROVAL`.
- No real credential is required; synthetic dummy only.

## M-06 detail

- `P6-PAR-028` is read-only and says “Do not acknowledge.”
- `P6-PAR-037` is the gated acknowledgement case.
- `P6-CHD-016` is read-only and says “Do not stop or restart.”
- `P6-CHD-020` is the gated restart case.

## Low and informational findings

- L-01 fixed in report 01.
- L-02 fixed in report 05.
- L-03 fixed in reports 01–03; report 12 is stale.
- I-01 and I-02 are documented.
- I-03 is incomplete because two persistent/permission actions remain ungated.
