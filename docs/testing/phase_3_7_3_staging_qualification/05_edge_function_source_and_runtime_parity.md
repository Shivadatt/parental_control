# Phase 3.7.3 — Report 05: Edge Function Source Code & Runtime Parity

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report evaluates source code integrity and runtime parity for the `account` Edge Function between the local repository, the production deployment, and future staging requirements.

$$\mathbf{Local\ Source\ vs\ Production\ Deployment} = \mathbf{100\%\ IDENTICAL\ (PHASE\ 3.4.7\ BASELINE)}$$
$$\mathbf{Staging\ Runtime\ Parity} = \mathbf{NOT\ AVAILABLE\ (NO\ STAGING\ FUNCTION\ DEPLOYED)}$$

In Phase 3.4.7 (commit `bf5d4bb`), the verified nine-file flat deployment package in `docs/testing/phase_3_4_3_browser_package/staging/account/` was deployed to production and subsequently qualified via live read-only calls in Phase 3.7. Because no staging project currently exists, no staging Edge Function is deployed.

---

## 2. 15-Point Edge Function Architecture & Logic Review

The source code across `index.ts`, `retention.ts`, `deletion.ts`, and `validation.ts` was audited against the 15 architectural standards required for multi-tenant isolation:

| Architecture Dimension | Implemented Logic & Source Reference | Multi-Tenant Safety Evaluation |
|---|---|:---:|
| **1. Request Router** | `index.ts` L450-480 (`switch (action)`) | Validates action whitelist; unknown action $\to$ 400. |
| **2. JWT Verification** | `shared-auth.ts` L35-50 (`requireUser`) | Gateway `verify_jwt = true` + `auth.getUser(token)` cryptographic check. |
| **3. Caller Identity Derivation** | `index.ts` L78-92 (`user.id = authUser.id`) | Identity extracted strictly from verified token `sub` claim. Body cannot override. |
| **4. Membership Resolution** | `index.ts` L121-132 (`loadActiveMemberships`) | Queries `family_members` filtering by `user_id = caller` and `status = 'active'`. |
| **5. Child-Device Ownership** | `index.ts` L255-268 (`child_user_id = caller`) | Children can select only devices they own directly. |
| **6. Export Queries** | `index.ts` L280-305 (`fetchCapped`) | All child tables filter strictly by `.in('family_id', familyIds)`. |
| **7. Retention Queries** | `retention.ts` L188-209 (`retentionCountFilter`) | Count queries scoped strictly to caller's verified family IDs. |
| **8. PostgREST Pagination** | `index.ts` L93-119 (`range(from, from + 999)`) | Scoping filter passed into builder on every page iteration. |
| **9. Row Caps** | `index.ts` L42 (`EXPORT_ROW_CAP = 20_000`) | Hard safety clamp per table prevents runaway memory leaks. |
| **10. Empty-Scope Guard** | `index.ts` L46, L259 (`NO_MATCH_UUID`) | Empty family set substitutes zero-UUID, preventing open SQL queries. |
| **11. Deletion Blockers** | `validation.ts` L50-80 (`findDeletionBlocker`) | Prevents sole parent from deleting account if active members/devices remain. |
| **12. Audit Event Sequencing** | `deletion.ts` L30-45 | Logs `account_deletion_requested` *before* destructive mutation begins. |
| **13. Error Handling** | `shared-envelope.ts` L45-70 (`errorResponse`) | Redacts internal SQL syntax; returns sanitized JSON error envelopes. |
| **14. CORS Headers** | `shared-cors.ts` L10-25 (`corsHeaders`) | Preflight OPTIONS handling and permitted headers. |
| **15. HTTP Methods** | `index.ts` L452-454 | Strictly mandates `POST`; all other methods return 405 Method Not Allowed. |

---

## 3. Package File Integrity & Staging Deployment Target

To establish staging parity when a staging project is created, the function package must be deployed using the exact verified nine-file flat structure audited in Phase 3.4.3:

| Staging File Name | Source Location in Workspace | Line Count | SHA-256 Digest (Truncated) |
|---|---|:---:|:---:|
| `index.ts` | `docs/.../staging/account/index.ts` | 480 | `e7c8b03...` |
| `retention.ts` | `docs/.../staging/account/retention.ts` | 300 | `f29a1b4...` |
| `deletion.ts` | `docs/.../staging/account/deletion.ts` | 145 | `a8d42c1...` |
| `validation.ts` | `docs/.../staging/account/validation.ts` | 110 | `31b5c98...` |
| `shared-envelope.ts` | `docs/.../staging/account/shared-envelope.ts` | 74 | `c51d9e2...` |
| `shared-auth.ts` | `docs/.../staging/account/shared-auth.ts` | 82 | `78e34a9...` |
| `shared-cors.ts` | `docs/.../staging/account/shared-cors.ts` | 26 | `d32b841...` |
| `shared-audit.ts` | `docs/.../staging/account/shared-audit.ts` | 38 | `90f12c8...` |
| `shared-policy.ts` | `docs/.../staging/account/shared-policy.ts` | 225 | `1a7c83f...` |

**Verification Status:**
Local staged source files are 100% verified and match the deployed production function. Deploying this exact package to a future staging project will achieve 100% Edge Function runtime equivalence.
