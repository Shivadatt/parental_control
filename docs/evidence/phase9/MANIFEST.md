# Phase 9 Cryptographic Evidence & Deliverables Manifest

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
| **S3** | Local CI Stage 3 (Deno) | `powershell -File scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql` | `0` | Stage 3 passed in 2.7s; working tree verified clean | `.tools/ci-logs/ci-run-20261104-110917.log` |
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
- **DEC-01 (Evidence Durability Policy):** **PENDING OWNER DECISION / BLOCKED** (Choice A vs Choice B).
- **DEC-02 (Hosted Deployment Readiness):** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**.
- **DEC-03 (Android QA Hardware Readiness):** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**.
- **DEC-05 (Retention Sweep Scheduler Policy):** **STOPPED BY POLICY / PENDING (P2)**.

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

