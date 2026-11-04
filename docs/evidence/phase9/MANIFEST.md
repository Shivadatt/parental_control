# Phase 9 Cryptographic Evidence & Deliverables Manifest

> _Dated reconciliation (2026-11-04 governance-consistency pass; measured 16:32 +0530): the `Current HEAD Commit` line below is this manifest's execution-window value, preserved verbatim as history. Current measured state at that pre-edit baseline: HEAD `65b39485a10b51e9a3e26f6b7f09f057b904b126` on `main` (= `origin/main`); 0 staged / 0 unstaged / 0 untracked non-ignored, 32 ignored. **[Dated 2026-11-04 17:40 +0530: that was the baseline before this pass edited documents. After the pass, the index is still 0 staged, but the working tree carries 20 unstaged tracked modifications plus 1 untracked report; it is not a clean tree. Ignored content and HEAD are unchanged.]** Owner commit chronology: `b12659b` (Phase 9 entry) → `75d1a52` (12:23:31 +0530) → `65b3948` (15:18:45 +0530, pushed). The documentation passes made no commit; the owner committed externally. **§3 of this manifest records pre-correction digests and sizes; read §7 for the current digest values and for which documents are authoritative versus historical.**_

**Manifest ID:** `PHASE-9-EVIDENCE-MANIFEST`  
**Date:** 2026-11-04  
**Workspace:** `D:\parentcontrol_app`  
**Active Branch:** `main`  
**Current HEAD Commit:** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`)  
**Phase 5 Reference Commit:** `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d`  
**Antigravity Coordinator ID:** `69ce22be-3642-4007-a757-b448f71c7ebc`  
**Governance Discipline:** Strictly Read-Only (0 Git write operations; 0 hosted mutations; 0 APK builds)

---

## 1. Toolchain Actually Used

The local evidentiary verification was conducted using the following confirmed toolchain:

| Tool / Runtime | Version String | Environment / Path | Verification Command |
|---|---|---|---|
| **Flutter SDK** | `Flutter 3.44.6` (channel stable) | `D:\parentcontrol_app\.fvm\versions\3.44.6` | `fvm flutter --version` |
| **Dart SDK** | `Dart 3.12.2` | Bundled with Flutter 3.44.6 | `fvm dart --version` |
| **Deno Runtime** | `deno 2.9.4 (release, x86_64-pc-windows-msvc)` | System PATH | `deno --version` |
| **Gradle** | `Gradle 9.1.0` | `android/gradlew.bat` | `./gradlew --version` |
| **PostgreSQL (Local)** | `PostgreSQL 16.9, 64-bit` | Standby cluster in `.tools/` | `psql --version` |
| **PostgreSQL (Hosted)** | `PostgreSQL 17.11` | Supabase Project `hhqgreaoqulmfwfwarhc` (AWS Seoul) | Dashboard Preflight 3 |
| **Git SCM** | `git version 2.47.1.windows.1` | System PATH | `git --version` |

---

## 2. Authoritative Executed Test Suites Table

The following 10 automated test suites establish the local hermetic baseline:

| Suite ID | Subsystem / Target | Exact Command Dispatched | Exit Code | Verified Output / Metrics | Evidence Log Path |
|---|---|---|:---:|---|---|
| **S1** | Full Deno Edge Functions | `deno test --allow-read supabase/functions/` | `0` | **150 passed / 0 failed** across 15 files in 2.0s | `.tools/ci-logs/deno-full-test.log` |
| **S2** | Targeted `family-admin` (SQL-05) | `deno test --allow-read supabase/functions/family-admin/` | `0` | **12 passed / 0 failed** in 142ms | `.tools/ci-logs/deno-family-admin-test.log` |
| **S3** | Local CI Stage 3 (Deno) | `powershell -File scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql` | `0` | Stage 3 passed in 2.7s; working tree verified clean **[Dated 2026-11-04: "working tree verified clean" is the CI script's own printed message, not an independently verified tree state. Gate A is a local hermetic baseline; the governance pass measured the tree separately.]** | `.tools/ci-logs/ci-run-20261104-110917.log` |
| **S4** | PostgreSQL 33-File SQL Chain (Positive) | `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_...` | `0` | 33 files, 621 log lines, **0 errors, 0 assertion failures** | `.tools/chain_p6chain_20261104_095112.log` |
| **S5** | SQL-05 Negative Control (Lossy RPC) | `.\supabase\tests\run_sql_chain.ps1 -NegativeControl ...` | `3` | **Expected Red:** Caught failure at `76_zone_delete_atomic_rpc.sql:411` | `.tools/chain_p6chain_neg_20261104_095527.log` |
| **S6** | Checksum Integrity Suite | SHA-256 verification of 69 delivered tree paths | `0` | 69/69 paths match byte-level digest `2bd6b310...` | `docs/evidence/phase5/tree-digest-final.txt` |
| **S7** | Phase 5 Manifest Table Audit | PowerShell `Get-FileHash` against manifest §8 | `0` | 20/20 artifacts (logs, XMLs, digests) match exactly | `docs/evidence/phase5/MANIFEST.md` |
| **S8** | Doc Path Ellipsis Validation | Scanned all markdown files for truncated links | `0` | 108 files scanned, 3 corrected in Phase 6, 105 verified safe | `docs/implementation/phase-6-doc-path-validation.md` |
| **S9** | Android JVM Unit Tests | `./gradlew test` (Robolectric / JUnit 4) | `0` | 6 test classes, **39 tests passed / 0 failed** | `reports/test-results/TEST-*.xml` |
| **S10** | Flutter Unit & Widget Tests | `flutter test` (Dart test runner) | `0` | **408 tests passed / 0 failed**; Dart analyze clean | `docs/evidence/phase5/logs/p5-coord-flutter-run2.log` |

---

## 3. Inventory of Delivered Phase 9 Documentation Assets

All delivered documents have been verified for mathematical consistency, exact byte sizes, and SHA-256 hashes:

| # | Relative File Path | Worktree Bytes | Lines | SHA-256 Checksum | Operational Purpose |
|---|---|---:|---:|---|---|
| **1** | `phase-9-report.md` | 14,447 | 158 | `e3b6606fd1c1c7e4391002aa1a3d113e8612a4f3f4103ef91b701b4d3178ad44` | Master Synthesis & Release Verdict |
| | `docs/implementation/phase-9-report.md` | 14,447 | 158 | `e3b6606fd1c1c7e4391002aa1a3d113e8612a4f3f4103ef91b701b4d3178ad44` | Exact Mirror in Docs Directory |
| **2** | `phase-9-regression-matrix.md` | 9,930 | 108 | `2539982f6b7ce229ceb5f56cdd1b3449e18e9d9110dfefee8d3939804d09dad8` | Automated Test & Invariant Matrix |
| | `docs/implementation/phase-9-regression-matrix.md` | 9,930 | 108 | `2539982f6b7ce229ceb5f56cdd1b3449e18e9d9110dfefee8d3939804d09dad8` | Exact Mirror in Docs Directory |
| **3** | `phase-9-open-gaps.md` | 12,469 | 157 | `25a21cf40f87269c3a494ec04988fd612dcc23e2039cd0bf3dc49230fe32ee53` | Master Open Gaps & Blocker Register |
| | `docs/implementation/phase-9-open-gaps.md` | 12,469 | 157 | `25a21cf40f87269c3a494ec04988fd612dcc23e2039cd0bf3dc49230fe32ee53` | Exact Mirror in Docs Directory |
| **4** | `phase-9-owner-decision-register.md` | 11,796 | 134 | `b5102665ebc442338fffa2f768fd820dacdcde0d8cc1656a9c9724bafc64ee71` | Governance Decisions & Sign-Off Matrix |
| | `docs/implementation/phase-9-owner-decision-register.md` | 11,796 | 134 | `b5102665ebc442338fffa2f768fd820dacdcde0d8cc1656a9c9724bafc64ee71` | Exact Mirror in Docs Directory |
| **5** | `phase-9-release-readiness.md` | 11,072 | 196 | `c4bce06bac2c3777791632ecaa3f68e8b3c39206a9ea98054a8e752fade7de05` | Staged Deployment Playbook & Preflights |
| | `docs/implementation/phase-9-release-readiness.md` | 11,072 | 196 | `c4bce06bac2c3777791632ecaa3f68e8b3c39206a9ea98054a8e752fade7de05` | Exact Mirror in Docs Directory |
| **6** | `phase-9-git-integrity-report.md` | 26,427 | 258 | `a3c026768ce516dc294c7393dc962bc1492ed2f49d63c93c29aed072a8d8c35b` | Git Tree & DEC-01 Durability Audit |
| | `docs/implementation/phase-9-git-integrity-report.md` | 26,427 | 258 | `a3c026768ce516dc294c7393dc962bc1492ed2f49d63c93c29aed072a8d8c35b` | Exact Mirror in Docs Directory |
| **7** | `phase-9-security-review.md` | 14,908 | 192 | `bd1ced981709e72f7c8d5c726bc333a3d3f7cc14328f52eeb406e6dccd6808d3` | Security & Privacy Architecture Review |
| | `docs/implementation/phase-9-security-review.md` | 14,908 | 192 | `bd1ced981709e72f7c8d5c726bc333a3d3f7cc14328f52eeb406e6dccd6808d3` | Exact Mirror in Docs Directory |
| **8** | `docs/implementation/phase-9-dec05-scheduler-retention-analysis.md` | 22,670 | 288 | `e29dbf677ae8c02b80ad08aae01687034e7273c18349fa8178ca2a66e01a5da2` | Subagent 6 Scheduler Deep-Dive |
| **9** | `docs/evidence/phase9/MANIFEST.md` | Self | Self | Self-referential | Phase 9 Evidence Manifest (This File) |

---

## 4. Four-Gate Release Framework & Formal Decision Status

### Four-Gate Status Matrix:
- **Gate A (Local Verification Baseline):** **CLEARED (100% Pass)**.
- **Gate B (Android Hardware QA):** **BLOCKED (P1 Release Blocker - GAP AND-01)**.
- **Gate C (Hosted Supabase Deployment):** **BLOCKED (P1 Release Blocker - GAP HOST-01)**.
- **Gate D (Production Release & Distribution):** **HARD STOP (NO-GO)**.

### Formal Owner Decision Register:
- **DEC-01 (Evidence Durability Policy):** **PENDING OWNER DECISION / BLOCKED** (Choice A vs Choice B). [dated 2026-11-04: superseded - **APPROVED, CHOICE B (local-only evidence)**; DUR-01 remains OPEN as an accepted durability risk.]
- **DEC-02 (Hosted Deployment Readiness):** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**.
- **DEC-03 (Android QA Hardware Readiness):** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**.
- **DEC-05 (Retention Sweep Scheduler Policy):** **STOPPED BY POLICY / PENDING (P2)**. [dated 2026-11-04: superseded - **APPROVED, CHOICE B (ON-DEMAND EXECUTION ONLY)**. Automation stays prohibited; hosted sweep invocation still needs separate written owner authorisation.]

---

## 5. Offline Re-Verification Command Playbook

To independently re-verify the local evidence baseline without mutating the repository or contacting remote infrastructure, execute the following commands in PowerShell from repository root:

```powershell
# 1. Re-verify Deno Full Suite (150 tests)
$env:DENO_DIR = "C:\Users\ASUS\AppData\Local\deno"
deno test --allow-read supabase/functions/

# 2. Re-verify Targeted SQL-05 Deno Suite (family-admin)
deno test --allow-read supabase/functions/family-admin/

# 3. Re-verify Local CI Pipeline Stage 3
powershell -ExecutionPolicy Bypass -File scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql

# 4. Re-verify 33-File PostgreSQL SQL Chain (Requires local PostgreSQL)
.\supabase\tests\run_sql_chain.ps1

# 5. Re-verify SQL-05 Negative Control (Requires local PostgreSQL; Expected Exit Code 3)
.\supabase\tests\run_sql_chain.ps1 -NegativeControl

# 6. Re-verify Phase 9 Deliverable Hashes
Get-Item "phase-9-*.md" | ForEach-Object { 
  [PSCustomObject]@{ File = $_.Name; Hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }
} | Format-Table -AutoSize
```

---

## 6. Manifest Verification Sign-Off

The evidence documented in this manifest is cryptographically verified and represents the authentic, unaltered state of the Parental Control App repository at entry HEAD `b12659b9795ba69499483a84750a33897dd7e08a`.
All workstreams are complete. The release gate stands at **NO-GO** awaiting owner instructions.

---

## 7. Dated Reconciliation, Document Authority & Current Digests (2026-11-04 governance-consistency pass)

> Added 2026-11-04 by the documentation-only governance-consistency pass. §1-§6 above are preserved verbatim as the historical record of the Phase 9 entry window. Where §3 or §4 disagree with this section, **this section is current** and §3/§4 are historical snapshots. Full audit: `docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md`.

### 7.1 Document Authority Precedence

| Rank | Document | Authority |
|---|---|---|
| 1 | `docs/evidence/phase9/OWNER-DECISION-ADDENDUM.md` | **Authoritative current owner-decision record** (DEC-01 and DEC-05 approved Choice B; DEC-02 and DEC-03 PENDING). |
| 2 | `docs/evidence/phase9/FINAL-MICRO-CORRECTION-ADDENDUM.md` | Supersedes earlier wording for **R5-R8** corrections. |
| 3 | `docs/evidence/phase9/FINAL-DOCUMENTATION-CORRECTION-ADDENDUM.md` | Supersedes earlier wording for **R1-R4** corrections. |
| 4 | The nine `docs/implementation/phase-9-*.md` deliverables (+ root mirrors) | Current documents, each carrying a dated reconciliation block. |
| 5 | `docs/evidence/phase9/DOCUMENTATION-CORRECTION-ADDENDUM.md`, `FINAL-CONSISTENCY-AUDIT.md`, `MANIFEST.md` §1-§6 | **Historical snapshots** of their own passes. Not current-state claims. |

### 7.2 HEAD / Commit Chronology

| # | Event | HEAD | Recorded by |
|---|---|---|---|
| 1 | Phase 9 entry | `b12659b9795ba69499483a84750a33897dd7e08a` | this manifest §header, report, register, git-integrity |
| 2 | Owner external commit (12:23:31 +0530) | `75d1a5232acbd87fe1068b5000d2916892e8143d` | DOCUMENTATION-CORRECTION-ADDENDUM.md:15 |
| 3 | R1-R4 correction pass | `75d1a52` (0 staged / 16 unstaged / 3 untracked) | FINAL-DOCUMENTATION-CORRECTION-ADDENDUM |
| 4 | R5-R8 micro-correction pass | `75d1a52` (0 staged / 16 unstaged / 4 untracked) | FINAL-MICRO-CORRECTION-ADDENDUM |
| 5 | **Owner external commit + push (15:18:45 +0530)** | `65b39485a10b51e9a3e26f6b7f09f057b904b126` | previously unrecorded; recorded here for the first time |
| 6 | Governance-consistency pass (measured 16:32 +0530) | `65b3948` - 0 staged / 0 unstaged / 0 untracked non-ignored / 32 ignored | this section |

No documentation pass created or pushed any commit; items 2 and 5 are the owner's external actions. The owner's commits added **no** raw `.log` evidence, so DEC-01 Choice B remains intact.

### 7.3 Current Digests (worktree bytes, SHA-256, measured 2026-11-04 after this pass)

| Document | Bytes | Lines | SHA-256 |
|---|---:|---:|---|
| `phase-9-report.md` | 36,908 | 295 | `de23a8cbd20e67149fd27fdf42a61a76225884b25cdb2992908bf93789fb87b4` |
| `phase-9-regression-matrix.md` | 10,690 | 116 | `d972d680a3e053a7b34633bb766564bfd2267d736306a4951aab1ac3d2859d1c` |
| `phase-9-open-gaps.md` | 28,357 | 239 | `e29b8b3669f037b56da54fc3df8f8908bbdc0bb600fbe57b5903b654c5545fda` |
| `phase-9-owner-decision-register.md` | 33,914 | 294 | `0a6fe00427b25fecf52c87a5b61b8d9639479485fa2ea10ead06894a3d36d09c` |
| `phase-9-release-readiness.md` | 27,371 | 328 | `1f970db72da8db4d7e77c8efdf89a094dc1050acf34f4ca65fc2e5f6823967b3` |
| `phase-9-git-integrity-report.md` | 31,545 | 332 | `1b369db9c2956502ae118876a82796aed32f194e3753fe916d617699da1100cd` |
| `phase-9-security-review.md` | 15,519 | 184 | `afd8045bc35e9fc67c1276fb9269a43804ad554750edde748676fda1d2f10262` |
| `phase-9-decision-execution-log.md` | 34,631 | 260 | `84849da7e4c96cb47f367d509d32904b3d627fadf317d48185bae7dc914c5d29` |
| `phase-9-dec05-scheduler-retention-analysis.md` (no root twin by design) | 26,663 | 332 | `2540f4271117a63f98bdeb2ae17a529c359bb22734af4b73796bc0117157f4a2` |

* Digest basis: SHA-256 over raw worktree bytes (LF endings on this workstation). A `git clone` on a system that applies `core.autocrlf=true` rewrites endings on checkout, so `sha256sum` there may differ; `git` blob digests are not the same values.
* Dated 2026-11-04 17:40 +0530: the `phase-9-report.md` row above was refreshed after a final Gate A wording correction (an unqualified "working tree clean" cell at `phase-9-report.md:111` received a dated annotation). This §7.3 table is the authoritative post-pass digest record; digests printed inside `FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md` §15 and in earlier addenda are point-in-time snapshots of the moment they were measured. `MANIFEST.md` does not publish its own digest — a file cannot record its own final hash — so the manifest's post-edit digest is reported only in the pass response.
* §3 rows 1, 3, 4, 5, 6 and 8 record pre-correction sizes/digests and are **superseded** by the table above; §3 rows 2 and 7 (regression matrix at `2539982f...`, security review at `bd1ced98...`) matched before this pass began.
* `phase-9-decision-execution-log.md` was **never listed** in §3; it is included above.
* All eight mirrored deliverables were re-verified byte-identical between `docs/implementation/` and the repository root after this pass.

### 7.4 Verification Provenance

| Claim class | Basis |
|---|---|
| **Independently verifiable from disk** | 12/12 Phase 5 evidence digests (11 ignored `.log` = 201,441 B / 4,403 lines; tracked `p5-coord-deno-full3.txt` = 19,608 B / 200 lines); `.gitignore:22` = `*.log`; zero tracked `.log`; mirror byte identity. |
| **Self-reported by the executing agent, artifacts present** | Suite results in §2 (S1-S10). Their logs live under `.tools/` and `build/`, which are **Git-ignored** (`.gitignore:16`, `.gitignore:54`) and are **not** covered by the 12-asset Phase 5 manifest, so they are local-workstation-only and absent from a fresh clone. |
| **Self-reported with no artifact in the repository** | Hosted Supabase observations (RLS on 19 tables, catalog state) - dated 2026-10-30, gated by DEC-02, NOT RE-VERIFIED. |
| **Independent second-party verification** | **OPEN.** Verification agents dispatched across these passes overwhelmingly failed with infrastructure errors; the R1-R8 verdicts rest on the author's own commands. No independent confirmation is claimed here. |

### 7.5 Decision and Gate Status After This Pass

DEC-01 **APPROVED - CHOICE B**; DEC-02 **PENDING**; DEC-03 **PENDING**; DEC-05 **APPROVED - CHOICE B (on-demand only; hosted invocation separately gated)**; DEC-04 and DEC-06 through DEC-11 unchanged. DUR-01 **OPEN (accepted, P2)**; SCHED-01 **OPEN (accepted, P2)**; HOST-01 **P1 blocker OPEN**; AND-01 / GATE-B-01 **P1 blocker OPEN**. Gate A = local verification baseline only; Gate B **BLOCKED**; Gate C **BLOCKED**; Gate D **NO-GO**.

