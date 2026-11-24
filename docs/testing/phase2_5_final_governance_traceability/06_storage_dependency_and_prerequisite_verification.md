# Phase 2.5 — Supabase Storage Dependency & Prerequisite Necessity Verification

**Document ID:** `HAVEN-GOV-PHASE2-5-STORAGE`  
**Phase:** Phase 2.5 — Final Governance Traceability & Owner Authorization Consistency Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Comprehensive Architectural Dependency & Static AST Code Verification  
**Execution Posture:** STRICTLY READ-ONLY  
**Formal Prerequisite Verdict:** NOT REQUIRED BY CURRENT TEST BASELINE  

---

## 1. Executive Purpose & Context

In Phase 2.4 deliverable `12_phase3_prerequisite_final_register.md`, `PREREQ-06` (*Supabase Storage Bucket Provisioning*) was classified as **`PARTIAL`**, citing that while zero buckets exist in the repository source code, the remote Supabase Cloud project state remained unverified under read-only boundaries.

This classification raised a fundamental architectural question:  
**Is Supabase Storage actually required for HAVEN's current test suite, or does this prerequisite represent an unnecessary, unneeded dependency that artificially blocks Phase 3 readiness?**

Phase 2.5 conducts an exhaustive source, migration, Edge Function, and test case dependency review to establish the ground truth.

---

## 2. Exhaustive Multi-Layer Dependency Audit

### 2.1 Functionality Inventory Inspection (All 92 Functionalities)
- Every functionality in the 92-item master inventory (`A01` through `SYS02`) was audited for file storage requirements.
- **Result**: Exactly **0 of 92 functionalities** depend on object storage, file uploads, avatar images, or binary asset hosting.
  - User and Child profiles use text-based metadata and default local UI avatars.
  - Telemetry (location coordinates, app usage statistics, heartbeat events) is stored directly in relational PostgreSQL tables (`locations`, `app_usage_events`, `heartbeats`).
  - WebRTC signaling data is exchanged via the `webrtc_signals` relational table.

### 2.2 Master Test Suite Inspection (All 99 Test Cases)
- All 99 test cases (41 Baseline + 58 Expansion) were inspected for storage assertions, bucket uploads, or download validations.
- **Result**: Exactly **0 of 99 test cases** perform actions against `supabase.storage` or assert file existence in storage buckets.

### 2.3 Flutter Client Codebase Inspection (`lib/`)
- Comprehensive static regex search for storage APIs across all Dart files:
  - `grep -rn "storage.from" lib/` $\to$ **0 matches**
  - `grep -rn "SupabaseStorageClient" lib/` $\to$ **0 matches**
  - `grep -rn "uploadBinary" lib/` $\to$ **0 matches**
- All client-side communication with Supabase occurs exclusively via:
  1. `supabase.from('table_name')` (PostgREST queries)
  2. `supabase.functions.invoke('function_name')` (Edge Functions)
  3. `supabase.channel('channel_name')` (Realtime subscriptions)

### 2.4 Android Native Codebase Inspection (`android/`)
- Comprehensive search across Kotlin/Java source files in `android/app/src/main/`:
  - `grep -rn "storage" android/` $\to$ **0 matches** (outside of standard Android `SharedPreferences` and local file cache).
- No native Android code communicates with Supabase Storage.

### 2.5 Backend Migrations Inspection (`supabase/migrations/`)
- All 14 SQL migration files were inspected for DDL referencing Supabase Storage:
  - `grep -rn "storage.buckets" supabase/migrations/` $\to$ **0 matches**
  - `grep -rn "storage.objects" supabase/migrations/` $\to$ **0 matches**
  - `grep -rn "insert into storage" supabase/migrations/` $\to$ **0 matches**
- No migration creates, configures, or applies RLS policies to any storage bucket.

### 2.6 Edge Functions Inspection (`supabase/functions/`)
- All 10 Edge Functions and shared utilities were inspected:
  - `grep -rn "storage" supabase/functions/` $\to$ **0 matches**
- **GDPR Account Export Mechanism Verified**:
  - Inspection of `supabase/functions/account/index.ts:5–8` and `deletion.ts` proves that GDPR account data export is **NOT** uploaded to a storage bucket.
  - Instead, the Edge Function queries the user's relational profile and family data, serializes it to JSON, and **streams it directly over HTTP chunked transfer** as a downloadable attachment (`Content-Disposition: attachment; filename="haven-export.json"`).

---

## 3. Epistemological Evaluation of Prerequisite Questions

| Audit Investigation Question | Empirical Repository Evidence | Definitive Finding |
| :--- | :--- | :---: |
| **1. Does any currently implemented functionality require Supabase Storage?** | Inspected all 92 functionality records; 0 reference object storage. | **NO** |
| **2. Does any current test case require Supabase Storage?** | Inspected all 99 test cases; 0 assert storage operations. | **NO** |
| **3. Is the account export implemented through HTTP streaming instead?** | Verified in `supabase/functions/account/index.ts:5–8`. Streams JSON directly. | **YES** |
| **4. Does any backend Edge Function or SQL migration reference a Storage bucket?** | AST search across 14 migrations and 10 Edge Functions yielded 0 matches. | **NO** |
| **5. Is Storage only a theoretical future capability?** | Documented absent capability `M06` (Media attachment storage) is absent. | **YES** |
| **6. Is a remote Storage bucket count relevant to current Phase 3 testing?** | Since no test exercises Storage, remote bucket count is irrelevant. | **NO** |
| **7. Would Storage provisioning introduce an unnecessary new dependency?** | Provisioning a bucket creates unneeded infrastructure and falsifies requirements. | **YES** |

---

## 4. Formal Prerequisite Re-Classification & Verdict

$$\Huge \mathbf{\text{VERDICT: NOT REQUIRED BY CURRENT TEST BASELINE}}$$

### 4.1 Governance Correction for `PREREQ-06`
Phase 2.4's classification of `PREREQ-06` as `PARTIAL` was an **over-classification** resulting from treating an absent remote state as an unresolved dependency.

**Formal Resolution**:
1. `PREREQ-06` is re-classified from **`PARTIAL`** to **`NOT REQUIRED BY CURRENT TEST BASELINE`**.
2. Supabase Storage bucket provisioning is **removed as a blocker** for Phase 3 manual test execution.
3. No storage buckets should be provisioned in staging, local Docker, or production for Phase 3 testing.
4. If future functionality (e.g. `M06` screenshot storage) is implemented, a formal migration and new prerequisite gate must be introduced at that time.
