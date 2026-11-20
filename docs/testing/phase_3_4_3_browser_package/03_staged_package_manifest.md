# Phase 3.4.3 — Report 03: Staged Package Manifest & Checksum Directory

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Staging Directory:** `docs/testing/phase_3_4_3_browser_package/staging/account/`  
**Target Function:** `account`  
**Package Architecture:** Single-Directory Flat Structure for Supabase Dashboard Editor  

---

## 1. Complete Package Manifest & Cryptographic Hashes

The browser-compatible `account` function package consists of exactly nine `.ts` source files located in a flat root-level hierarchy:

| Staged File Name | Origin File in Repository | Staged Size (Bytes) | Staged SHA-256 Checksum | Role / Purpose |
| :--- | :--- | :---: | :--- | :--- |
| **`index.ts`** | `supabase/functions/account/index.ts` | 15,868 | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | Main HTTP entrypoint & request dispatcher |
| **`deletion.ts`** | `supabase/functions/account/deletion.ts` | 19,699 | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | Two-tier deletion lifecycle & retry resumption |
| **`retention.ts`** | `supabase/functions/account/retention.ts` | 10,537 | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | Retention scope resolution & report builders |
| **`validation.ts`** | `supabase/functions/account/validation.ts` | 3,908 | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | Payload validation (`confirm: "DELETE"`, email matching) |
| **`shared-audit.ts`** | `supabase/functions/_shared/audit.ts` | 1,145 | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | Immutable audit log record generator |
| **`shared-auth.ts`** | `supabase/functions/_shared/auth.ts` | 10,818 | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | JWT identity validation & service client factory |
| **`shared-cors.ts`** | `supabase/functions/_shared/cors.ts` | 502 | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | CORS headers & preflight response |
| **`shared-envelope.ts`** | `supabase/functions/_shared/envelope.ts` | 3,637 | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | Sanitized ApiError responses & envelopes |
| **`shared-validation.ts`**| `supabase/functions/_shared/validation.ts` | 13,067 | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | Cryptographic SHA-256 & constant-time helpers |

**Total Package Size:** 80,181 bytes (~78.3 KB)  
**Supabase Edge Functions Limit:** 10 MB uncompressed (Package is well within 0.8% of the platform threshold).

---

## 2. Invariance & Non-Inclusion Verification

- **Unrelated Functions:** 0 (Zero files from `auth-bootstrap`, `device-policy`, `pairing`, `remote-session`, etc. were included).
- **Test Files in Production Payload:** 0 (Unit and regression test files are isolated to staging test suites and never part of the production bundle).
- **Database / SQL Files:** 0 (Zero SQL or schema scripts included).
- **Configuration / Secrets:** 0 (Zero environment variables or secret files included).

**Conclusion:** The staging package manifest is minimal, fully self-contained, and precisely aligned with the single authorized function scope.
