# Phase 3.5 — Report 02: Source Integrity Audit & Cryptographic Verification

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Package Source:** `docs/testing/phase_3_4_3_browser_package/staging/account/`  
**Audit Date:** 2026-11-20  

---

## 1. Cryptographic Baseline Verification

The production `account` Edge Function deployed in Phase 3.4.7 consists of a nine-file flat package located at `docs/testing/phase_3_4_3_browser_package/staging/account/`. Every file has been cryptographically verified using SHA-256 to ensure complete parity with the audited Phase 3.4.3 and Phase 3.4.7 baselines.

### SHA-256 Hash Comparison Table

| Filename | File Size | Line Count | SHA-256 Digest | Status vs Phase 3.4.3 Baseline |
|---|---|---|---|---|
| `index.ts` | 15,868 B | 480 lines | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | **EXACT MATCH** |
| `deletion.ts` | 19,699 B | 641 lines | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | **EXACT MATCH** |
| `retention.ts` | 10,537 B | 300 lines | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | **EXACT MATCH** |
| `validation.ts` | 3,908 B | 117 lines | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | **EXACT MATCH** |
| `shared-audit.ts` | 1,145 B | 37 lines | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | **EXACT MATCH** |
| `shared-auth.ts` | 10,818 B | 353 lines | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | **EXACT MATCH** |
| `shared-cors.ts` | 502 B | 12 lines | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | **EXACT MATCH** |
| `shared-envelope.ts` | 3,637 B | 111 lines | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | **EXACT MATCH** |
| `shared-validation.ts` | 13,067 B | 418 lines | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | **EXACT MATCH** |

---

## 2. File Roles & Architectural Provenance

1. **`index.ts` (Entrypoint & Router):**
   - Implements `Deno.serve` with HTTP method filtering (`OPTIONS` and `POST`).
   - Dispatches authenticated requests to `export`, `delete` / `delete_account`, and `retention_report`.
   - Generates JSON attachment streaming response for account export.
   - Enforces `EXPORT_ROW_CAP = 20,000` and paging increments of `EXPORT_PAGE_SIZE = 1,000`.

2. **`deletion.ts` (Account Deletion Lifecycle):**
   - Implements `executeAccountDeletion` with full retry-safety.
   - Solves the profile-missing 403 lockout by decoupling token identity validation from `profiles` existence.
   - Enforces family ownership blockers, cascade order, pre- and post-deletion audit events, and GoTrue Auth deletion.

3. **`retention.ts` (Retention Policy & Audit Computations):**
   - Implements pure retention window parsing and clamping (`[1, 3650]` days).
   - Provides three-state caller scoping: `family` (parent), `device` (child), and `not_reported` (unknown/unauthorized).
   - Redacts project-wide sweep markers from non-owner parents and children.

4. **`validation.ts` (Pure Confirmation & Blocker Checks):**
   - Validates the affirmative confirmation word `DELETE` (case-sensitive).
   - Checks caller email match against verified JWT identity.
   - Detects active family members (`otherActiveMembers > 0`) or active devices (`activeDevices > 0`) to block unsafe deletions.

5. **`shared-audit.ts` (Structured Audit Logging):**
   - Writes immutable records to the `audit_logs` table via service-role Supabase client.
   - Handles events: `account_deletion_requested`, `account_deleted`, `account_deletion_failed`.

6. **`shared-auth.ts` (Authentication & Authorization):**
   - Implements `requireAuthUser` (JWT validation only) and `requireUser` (JWT + profile validation).
   - Extracts and verifies Bearer tokens with GoTrue Auth (`db.auth.getUser`).
   - Restricts role transitions and blocks unverified callers.

7. **`shared-cors.ts` (Cross-Origin Resource Sharing):**
   - Supplies CORS headers (`Access-Control-Allow-Origin: *`, `POST, OPTIONS`, `authorization, x-client-info, apikey, content-type`).
   - Answers `OPTIONS` preflight with `200 OK`.

8. **`shared-envelope.ts` (Error & JSON Parsing):**
   - Implements `ApiError`, `ok`, `errorResponse`, `readJson`, and `ensureNoError`.
   - Prevents unhandled server exceptions from leaking internal SQL or infrastructure details.

9. **`shared-validation.ts` (Cryptographic & String Primitives):**
   - Constant-time equality checks (`constantTimeEqualHex`) to mitigate timing attacks.
   - SHA-256 hashing, UUID syntax verification, and string sanitization.

---

## 3. Absence of Extraneous or Unverified Code

- **Zero Nested Directory Dependencies:** All nine files utilize flat `./sibling.ts` imports, eliminating dependency on `_shared/` directories that are unsupported by the Supabase Dashboard editor.
- **Zero Extraneous Exports:** The package exposes only sanctioned functions and types.
- **Zero Local Artifact Leaks:** Unit and integration test suites (`*_test.ts`) are excluded from production deployment and reside purely in staging and local testing paths.
- **Conclusion:** The source code deployed in production matches the verified local source package byte-for-byte and line-for-line.
