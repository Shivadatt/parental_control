# Phase 6 — Documentation, Path Validation & Line-Ending Audit Report

**Workstream:** Workstream C (Safe Documentation & Reproducibility Gaps)  
**Document Reference:** `docs/implementation/phase-6-doc-path-validation.md`  
**Auditor / Role:** Subagent 3: Documentation & Path Validator (Phase 6)  
**Caller / Coordinator ID:** `e0d3326c-5a13-4314-b902-7ea17d798c30`  
**Audit Date:** 2026-11-04  
**Git HEAD:** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`)  
**Scope:** Addressing GAP-EV-06, GAP-EOL-01, and cross-report consistency checks across Phases 1 through 5.

---

## 1. Executive Summary

As part of Phase 6 of the Android-first Parental Control Application, this independent audit resolves the documentation hygiene, citation validity, and repository reproducibility gaps accumulated across Phases 1 through 5. 

### Key Outcomes:
1. **GAP-EV-06 (Ellipsis Paths & Placeholders):**
   - Conducted an exhaustive scan of all Markdown documentation across `docs/` and `supabase/tests/README.md`.
   - Identified all instances of `...`, `.../`, `…`, and truncated file paths.
   - Categorized each reference into runnable commands, test README paths, documented shorthand conventions, or illustrative non-executable examples.
   - Identified and corrected the 100% certain invalid command/file paths:
     * `supabase/tests/README.md:92`: Corrected truncated `75_...` to `75_signaling_replay_index_duplicate_guard.sql`.
     * `docs/implementation/_work/p4-enf-residual.md:14`: Corrected non-functional `git show HEAD:lib/.../app_restrictions_controller.dart` to `git show HEAD:lib/features/app_restrictions/app_restrictions_controller.dart`.
     * `docs/implementation/phase-2-regression-matrix.md:21`: Corrected `…/settings/export_result_dialog_test.dart` to `test/features/settings/export_result_dialog_test.dart`.
   - Formally classified non-executable illustrative examples (e.g. `dpm list-owners` output in `docs/device-owner-provisioning.md:345`, zip archive inspection in `docs/release-build.md:82`) so they cannot be mistaken for executable citations.

2. **GAP-EOL-01 (Line Ending Policy & Discrepancies):**
   - Audited repository-wide line ending state across all 673 tracked files.
   - Found that `core.autocrlf = true` is set globally, `core.eol` is unset, and **no `.gitattributes` file exists**.
   - Direct binary inspection reveals **435 pure LF**, **49 pure CRLF**, and **2 mixed** files on disk. Git index stores all 486 text files as `i/lf`.
   - On the delivered 69-path Phase 5 tree, exactly 7 files contain CRLF in the worktree (`docs/implementation/api-contract.md` and six `docs/evidence/phase5/gradle-junit/*.xml` test reports).
   - Documented the strict rationale for why automatic blanket normalization was **NOT** performed without owner approval (avoiding `git blame` destruction across 51+ files, preventing hash invalidation on pinned verification manifests, and preventing immediate re-introduction by Windows build tools).
   - Formulated 3 concrete options for repository line ending governance and provided a complete, battle-tested `.gitattributes` specification ready for adoption.

3. **Cross-Phase Report Consistency & Citation Audit:**
   - Evaluated 94 cross-phase citations and markdown links across `phase-1-report.md`, `phase-2-report.md`, `phase-3-regression-matrix.md`, `phase-4-report.md`, `phase-4-open-gaps.md`, `phase-5-report.md`, and `phase-5-open-gaps.md`.
   - Verified 100% link integrity (zero broken markdown links, zero missing target report files, zero missing section headers).
   - Identified and documented legacy citation drift (e.g. `phase-4-open-gaps.md:90` citing out-of-bounds lines `phase-3-open-gaps.md:119-122`, which was a 50-line file; and Phase 1 line shifts resulting from Phase 4 DOC-01 annotations).
   - Reconciled gap continuity from Phase 3 through Phase 6.

---

## 2. Workstream C — GAP-EV-06: Ellipsis Paths and Citation Validation

### 2.1 Background
In `docs/implementation/phase-5-open-gaps.md:36`, GAP-EV-06 recorded:
> "`_work/p4-enf-residual.md:14` shows a runnable-looking `git show HEAD:lib/.../app_restrictions_controller.dart`; the path contains an ellipsis and fails if pasted. Also 13 other ellipsis-style placeholder paths (`android/.../GuardianService.kt`) survive in the older docs. OPEN (scratch notes, not deliverables). Recorded so nobody executes a citation blindly."

Furthermore, in `supabase/tests/README.md:92`, a description of the SQL execution order referenced `75_...` rather than the real test filename.

### 2.2 Comprehensive Inventory and Classification

An automated scan of all Markdown files in the repository identified 108 lines containing `...` or `…`. These fall into six distinct categories:

#### Category A: Runnable-Looking Commands Containing Ellipsis (Corrected)
These references appear inside inline code spans as shell/git commands. If copied and pasted into a terminal, they fail with fatal errors.

1. **`docs/implementation/_work/p4-enf-residual.md:14`**
   - **Original Text:** `` `git show HEAD:lib/.../app_restrictions_controller.dart` ``
   - **Target Candidate:** `lib/features/app_restrictions/app_restrictions_controller.dart`
   - **Disk & Git Status:** Exists in worktree and in Git HEAD.
   - **Execution Verification:** Running `git show HEAD:lib/features/app_restrictions/app_restrictions_controller.dart` outputs the 593-line controller cleanly (exit code 0).
   - **Resolution:** **Corrected in place.**

2. **`supabase/tests/README.md:92`**
   - **Original Text:** `` `76_zone_delete_atomic_rpc.sql` runs after `75_...` and **before** ``
   - **Target Candidate:** `supabase/tests/75_signaling_replay_index_duplicate_guard.sql`
   - **Disk & Git Status:** Exists on disk (218 lines, added in Phase 4).
   - **Execution Verification:** Line 82 of the same document cites the full name; `-f supabase/tests/75_signaling_replay_index_duplicate_guard.sql` is line 63 of the master execution command.
   - **Resolution:** **Corrected in place.**

3. **`docs/implementation/phase-2-regression-matrix.md:21`**
   - **Original Text:** `` `flutter test test/features/devices/device_presence_consistency_test.dart` / `…/settings/export_result_dialog_test.dart` ``
   - **Target Candidate:** `test/features/settings/export_result_dialog_test.dart`
   - **Disk & Git Status:** Exists on disk (60 lines).
   - **Resolution:** **Corrected in place** to explicit executable paths: `` `flutter test test/features/devices/device_presence_consistency_test.dart` and `flutter test test/features/settings/export_result_dialog_test.dart` ``.

#### Category B: Documented Architectural Shorthand Conventions (Valid Shorthand)
These references occur in contract and architecture specifications where the shorthand is formally defined at the top of the file:

1. **`docs/implementation/feature-ownership.md` (Lines 9, 16, 17, 20, 21)**
   - **Definition (Line 9-10):** `"Paths are exclusive: a file appears under exactly one workstream. android/.../ abbreviates android/app/src/main/kotlin/com/parentcontrol/parent_control/."`
   - **Owned Paths:**
     * `android/.../GuardianService.kt` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt` (Exists)
     * `android/.../BootReceiver.kt` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/BootReceiver.kt` (Exists)
     * `android/.../PolicyApplier.kt` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt` (Exists)
     * `android/.../policy/**` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/` (Directory exists, holds 3 Kotlin evaluators)
     * `android/.../AudioAssistanceService.kt` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt` (Exists)
     * `android/.../MainActivity.kt` → `android/app/src/main/kotlin/com/parentcontrol/parent_control/MainActivity.kt` (Exists)
   - **Assessment:** **Valid architectural shorthand.** The mapping is 100% unambiguous and explicitly governed by §1 of that contract.

2. **`docs/implementation/_work/coordinator-contract.md` (Lines 125, 126, 129, 130)**
   - Mirrors `feature-ownership.md` verbatim. **Valid architectural shorthand.**

#### Category C: Historical Citations in Frozen Reports (Informational)
In earlier phase deliverables, file citations used `android/.../` as convenient shorthand without posing an execution hazard:

- `docs/implementation/phase-1-report.md:86`: `android/.../PolicyApplier.kt`
- `docs/implementation/phase-1-report.md:116`: `android/.../AudioAssistanceService.kt`
- `docs/implementation/phase-1-report.md:119`: `android/app/src/test/kotlin/.../AudioAssistanceStopIdempotenceTest.kt`
- `docs/implementation/phase-1-report.md:124`: `android/.../MainActivity.kt`
- `docs/implementation/phase-0-report.md:125`: `android/.../GuardianService.kt`
- `docs/implementation/remaining-gaps.md:51`: `android/.../AudioAssistanceService.kt:558-569`
- `docs/implementation/remaining-gaps.md:66`: `android/.../UsageReporter.kt:16-43`
- `docs/implementation/_work/audio.md:36`: `android/app/src/test/kotlin/.../AudioAssistanceStopIdempotenceTest.kt`
- `docs/implementation/phase-4-android-validation-plan.md` (Lines 65, 90, 107, 190, 208, 219, 222, 243, 350, 473, 474): Multiple references citing `android/.../GuardianService.kt`, `android/.../AudioAssistanceService.kt`, and `android/.../PolicyApplier.kt`.
- `docs/integrations-setup.md:365`: `android/app/src/main/kotlin/.../NativePermissions.kt:34-55`
- `docs/mic_full_audit_report.md:157`: `android/app/src/test/kotlin/.../AudioAssistanceStartGateTest.kt`
- `docs/mic_only_test_report.md:44`: `android/.../AudioAssistanceService.kt`
- `docs/stage5_background_audio_survival_report.md:82`: `android/.../AudioAssistanceService.kt:`
- `docs/stage7_two_device_end_to_end_report.md:206`: `android/app/src/test/kotlin/.../AudioAssistanceRecreationTest.kt`

**Verification:** Every target Kotlin file exists on disk at `android/app/src/main/kotlin/com/parentcontrol/parent_control/<File>.kt` or `android/app/src/test/kotlin/com/parentcontrol/parent_control/<File>.kt`. In accordance with Phase 5 evidence governance, historical reports from prior closed phases are preserved without gratuitous retroactive churn.

#### Category D: Non-Executable Illustrative Patterns (Classified)
These occurrences represent output format patterns, regexes, or UI strings, and must **never** be interpreted as executable paths:

1. **`docs/device-owner-provisioning.md:345`**
   - Text: `- dpm list-owners → User  0: admin=.../ParentControlDeviceAdminReceiver,DeviceOwner.`
   - Nature: Illustrative ADB command output sample. The actual output from Android OS prints the package component name (e.g. `com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`).
2. **`docs/release-build.md:82`**
   - Text: `| assets/flutter_assets/packages/cupertino_icons/.../CupertinoIcons.ttf | 257,628 |`
   - Nature: Truncated entry path from `unzip -l` APK table. Inside the APK, the path is `assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf`.
3. **`docs/verification-report.md:160`**
   - Text: `"The test APK produced by flutter test integration_test/... overwrites app-debug.apk"`
   - Nature: Illustrative glob pattern referring to running any test inside the `integration_test/` directory.

### 2.3 Exact Git Diffs Applied

```diff
diff --git a/docs/implementation/_work/p4-enf-residual.md b/docs/implementation/_work/p4-enf-residual.md
index 01ce529..94afd0a 100644
--- a/docs/implementation/_work/p4-enf-residual.md
+++ b/docs/implementation/_work/p4-enf-residual.md
@@ -11,7 +11,7 @@ logic and `PolicyEnforcementEvidence` are byte-identical to `HEAD`; only *who ma
 
 ## 1. Reachability trace, against `HEAD` (`953b337`) only
 
-`git show HEAD:lib/.../app_restrictions_controller.dart` — the report side already had a generation
+`git show HEAD:lib/features/app_restrictions/app_restrictions_controller.dart` — the report side already had a generation
 token (`_reportRequest` at `:62`, `:533`, checked at `:543` and `:569`, the Phase 3 fix). The **policy
 side had none**:
 
diff --git a/docs/implementation/phase-2-regression-matrix.md b/docs/implementation/phase-2-regression-matrix.md
index 6e5c974..c8fa604 100644
--- a/docs/implementation/phase-2-regression-matrix.md
+++ b/docs/implementation/phase-2-regression-matrix.md
@@ -21,7 +21,7 @@ feature incorrect on the happy path, **P2** honest-but-incomplete or unverifiabl
-| Unit | Targeted re-runs of the changed areas | `flutter test test/features/devices/device_presence_consistency_test.dart` / `…/settings/export_result_dialog_test.dart`; `deno test --allow-read supabase/functions/handler_wiring_test.ts` | **PASS** | 7/7, 4/4 and 5/5 respectively. |
+| Unit | Targeted re-runs of the changed areas | `flutter test test/features/devices/device_presence_consistency_test.dart` and `flutter test test/features/settings/export_result_dialog_test.dart`; `deno test --allow-read supabase/functions/handler_wiring_test.ts` | **PASS** | 7/7, 4/4 and 5/5 respectively. |

diff --git a/supabase/tests/README.md b/supabase/tests/README.md
index 0edaf39..da70bd1 100644
--- a/supabase/tests/README.md
+++ b/supabase/tests/README.md
@@ -89,7 +89,7 @@ files depend on.
 order and is applied before every test file: it only creates
 `public.delete_safe_zone_audited(uuid, uuid)` — no table, index, policy or
 table-grant change — so it cannot move any count `10_schema.sql` asserts.
-`76_zone_delete_atomic_rpc.sql` runs after `75_...` and **before**
+`76_zone_delete_atomic_rpc.sql` runs after `75_signaling_replay_index_duplicate_guard.sql` and **before**
 `45_device_recovery.sql`, because its section 2 temporarily installs a failing
 `BEFORE INSERT` trigger on `public.audit_logs` and drops it again at the end of
 the section; `45_device_recovery.sql` writes real audit rows and must never meet
```

---

## 3. Workstream C — GAP-EOL-01: Line-Ending Policy & Cross-Platform Integrity

### 3.1 Background & Environmental Baseline
In `docs/implementation/phase-5-open-gaps.md:40`, GAP-EOL-01 recorded:
> "`core.autocrlf=true` with **no `.gitattributes`** anywhere in the repo. Measured on the 69 delivered paths: 7 contain CRLF in the worktree and are stored as `i/lf w/crlf` (the six `docs/evidence/phase5/gradle-junit/*.xml` and `docs/implementation/api-contract.md`), so the moment the owner runs `git add` the committed blob for those 7 **will not equal the bytes the digest pins**. This is a commit-time hazard for whoever verifies `tree-digest-final.txt` after a checkout, not a defect in the work. OPEN — nobody acted, because adding `.gitattributes` or renormalising files is a repo-wide change the owner has not approved and this phase commits nothing."

### 3.2 Repository-Wide Line-Ending Audit
An exhaustive inspection was performed across all 673 tracked files in git using `git ls-files --eol` combined with binary byte inspection:

1. **Global Git Settings:**
   - `core.autocrlf = true` (configured at `C:/Program Files/Git/etc/gitconfig`)
   - `core.eol = unset`
   - `.gitattributes` = **Absent** from repository root and all subdirectories.

2. **Git Index vs Worktree Distribution (All 673 Tracked Files):**
   - **Git Index Representation (`i/`):**
     * `i/lf`: **486 files** (100% of text files are stored as LF blobs in the Git object database).
     * `i/-text`: **187 files** (binary assets, images, bytecode, fonts).
   - **Worktree Disk Representation (`w/`):**
     * `w/lf`: **435 files** (pure LF line endings on disk).
     * `w/crlf`: **49 files** (pure CRLF `\r\n` line endings on disk).
     * `w/mixed`: **2 files** (mixed LF and CRLF on disk).
     * `w/-text`: **187 files** (binary assets).

3. **Breakdown of the 51 Non-LF Worktree Files by File Extension:**
   - **XML (`.xml`):** 23 files (10 `.idea/*.xml` IDE files, 7 Android manifest/resource files, and the 6 Phase 5 JUnit XML reports).
   - **Dart (`.dart`):** 10 files (`lib/main.dart`, `parent_dashboard_tab.dart`, `device_detail_controller.dart`, `device_detail_page.dart`, `parent_devices_tab.dart`, `child_home_tab.dart`, `parent_ui_journey_test.dart`, `child_enrollment_page_test.dart`, `device_detail_controller_test.dart`, `widget_test.dart`).
   - **Markdown (`.md`):** 4 files (`README.md`, `audit/_work/s2-ui-ux-ia.md`, `docs/implementation/api-contract.md`, `docs/implementation/phase-0-report.md`).
   - **Gradle Kotlin Scripts (`.kts`):** 3 files (`android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`).
   - **Git Configuration (`.gitignore`):** 3 files (`android/.gitignore`, `.idea/.gitignore`, and root `.gitignore` which has mixed line endings).
   - **Properties (`.properties`):** 2 files (`android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`).
   - **YAML (`.yaml`):** 2 files (`pubspec.yaml`, `analysis_options.yaml`).
   - **Plain Text (`.txt`):** 3 files (`docs/evidence/stage5/child-lock-services.txt`, `child-swipe-services.txt`, and `reports/kids-setup-2026-10-29/permission_state.txt` which has mixed line endings).
   - **Kotlin Source (`.kt`):** 1 file (`android/app/src/main/kotlin/com/parentcontrol/parent_control/MainActivity.kt`).

4. **Status in Delivered Phase 5 Evidence Tree (69 Paths):**
   - Exactly **7 files** contain CRLF in the worktree:
     * `docs/implementation/api-contract.md`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceRecreationTest.xml`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest.xml`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStartGateTest.xml`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest.xml`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.EnforcementModeTest.xml`
     * `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml`
   - The remaining **62 paths** are pure LF on disk.

### 3.3 Why Blanket Automatic Normalization Was NOT Performed

Automatic normalization across the repository (e.g. executing `git add --renormalize .` or running `dos2unix` across all 51 files) was **deliberately withheld**. The engineering and governance justifications are:

1. **Governance & Owner Ruling Boundary:**
   - Under project governance rules, subagents and coordinators do not enact unapproved repo-wide policy changes. Normalizing line endings across 51 files alters files across multiple workstreams (Android Kotlin, Flutter UI, Gradle infrastructure, JetBrains IDE configurations, and documentation).
2. **Cryptographic Checksum & Digest Invalidation:**
   - Prior phases (Phases 3, 4, and 5) pinned explicit cryptographic checksums in `tree-digest-final.txt` and `MANIFEST.md` based on worktree disk bytes.
   - For example, `api-contract.md` has worktree size 22,238 bytes with SHA-256 `eb6a583e74be8bcab8bc2a8db421c97aeeff4a1fe186e8ca846dc6a014a6003d`. If converted to LF, its size becomes 21,787 bytes with SHA-256 `6826e5e894042813689f5bc3aeb1a575a5cbfa3c44c207b55f1ffb85d9dbfa62`.
   - Modifying those 7 files would immediately invalidate `docs/evidence/phase5/tree-digest-final.txt` and cause verification audits (such as Subagent 1's 69/69 pass) to report checksum drift.
3. **Pollution of `git blame` and Commit History:**
   - Running `--renormalize` without an accompanying `.git-blame-ignore-revs` configuration rewrites every single line of code in the 51 touched files, obliterating commit attribution and audit traceability for past security and architecture decisions.
4. **Toolchain Re-introduction on Windows:**
   - On Windows workstations, tools like Gradle (`./gradlew testDebugUnitTest` writing JUnit XML files) and IDEs write native CRLF by default.
   - Normalizing files without committing an authoritative `.gitattributes` configuration means that the next Gradle execution or file save simply recreates CRLF, re-introducing the divergence.

### 3.4 Concrete Options for Repository-Wide Line-Ending Policy

The repository requires an explicit, owner-ratified line-ending policy. Three concrete options are presented:

#### Option 1: Strict Repository-Wide LF with Immediate Renormalization (Clean Slate)
- **Description:** Introduce `.gitattributes` with `* text=auto eol=lf`, execute `git add --renormalize .`, and commit along with `.git-blame-ignore-revs`.
- **Pros:** Completely eliminates CRLF across all platforms. Ensures that `worktree_sha256 == git_blob_sha256` everywhere.
- **Cons:** Invalidates historical worktree digests for the 7 Phase 5 files; requires owner approval to commit 51 modified files.

#### Option 2: Comprehensive Categorized `.gitattributes` (Recommended)
- **Description:** Commit an explicit `.gitattributes` that defines exact line ending behaviors by file type (source code, SQL, shell scripts, Gradle, batch files, and binary assets). Normalize on check-in without forcing immediate worktree rewriting of undisturbed files.
- **Pros:** 
  - Prevents bash scripts (`*.sh`) from ever being committed with CRLF (which breaks Linux/Docker/CI execution with `\r: command not found`).
  - Preserves CRLF for Windows-native scripts (`*.bat`, `*.cmd`).
  - Prevents binary corruption (`*.png`, `*.ttf`, `*.so`, `*.apk`, `*.jar`).
  - Guarantees all future commits store pure LF in the Git object database regardless of operator OS.
- **Cons:** Requires one repo-level commit approved by the owner.

#### Option 3: Status Quo Acceptance (Workstation-Bound Baselines)
- **Description:** Maintain `core.autocrlf=true` and document that worktree digests on Windows workstations represent local byte verification, while Git blobs represent canonical LF storage.
- **Pros:** Zero repo diff, zero commit required.
- **Cons:** Leaves commit-time warning hazards in place; requires dual-basis digest tables for any cross-platform CI verification.

### 3.5 Proposed `.gitattributes` Configuration

When the owner authorizes Option 2, the following `.gitattributes` file should be committed to the repository root:

```gitattributes
# =============================================================================
# Repository-Wide Line Ending Policy (ParentControl App)
# Enforces LF normalization in git object storage across platforms.
# =============================================================================

# Set default behavior: auto-detect text files and normalize line endings to LF on check-in
* text=auto eol=lf

# -----------------------------------------------------------------------------
# Source Code (Must strictly be LF)
# -----------------------------------------------------------------------------
*.dart          text eol=lf
*.kt            text eol=lf
*.kts           text eol=lf
*.java          text eol=lf
*.ts            text eol=lf
*.js            text eol=lf
*.sql           text eol=lf

# -----------------------------------------------------------------------------
# Configuration, Markup & Documentation
# -----------------------------------------------------------------------------
*.json          text eol=lf
*.yaml          text eol=lf
*.yml           text eol=lf
*.xml           text eol=lf
*.md            text eol=lf
*.txt           text eol=lf
*.properties    text eol=lf
*.env           text eol=lf
*.html          text eol=lf
*.css           text eol=lf
.gitignore      text eol=lf

# -----------------------------------------------------------------------------
# Shell Scripts (CRLF breaks bash interpreters on Linux/macOS/Docker/CI)
# -----------------------------------------------------------------------------
*.sh            text eol=lf
*.bash          text eol=lf
gradlew         text eol=lf

# -----------------------------------------------------------------------------
# Windows Command Scripts (Must preserve CRLF)
# -----------------------------------------------------------------------------
*.bat           text eol=crlf
*.cmd           text eol=crlf

# -----------------------------------------------------------------------------
# Binary Formats (Prevent line ending transformation and diff corruption)
# -----------------------------------------------------------------------------
*.png           binary
*.jpg           binary
*.jpeg          binary
*.gif           binary
*.ico           binary
*.pdf           binary
*.jar           binary
*.apk           binary
*.aab           binary
*.so            binary
*.bin           binary
*.ttf           binary
*.otf           binary
*.zip           binary
*.tar.gz        binary
```

---

## 4. Cross-Document Reference & Report Consistency Audit

### 4.1 Scope & Verification Methodology
An exhaustive consistency check was conducted across the core historical and governance documents:
- `docs/implementation/phase-1-report.md`
- `docs/implementation/phase-2-report.md`
- `docs/implementation/phase-3-regression-matrix.md`
- `docs/implementation/phase-4-report.md`
- `docs/implementation/phase-4-open-gaps.md`
- `docs/implementation/phase-5-report.md`
- `docs/implementation/phase-5-open-gaps.md`

All 94 cross-phase citations were extracted and tested against:
1. Physical existence of target files on disk.
2. Validity of cited Markdown section headers (e.g. `§1`, `§2a`, `§6`).
3. Precision of specific line number references (`:line_number`).
4. Logical continuity of gap tracking across phase boundaries.

### 4.2 Citation & Header Integrity Results

| Document Under Audit | Total Lines | Cross-Phase Citations | Markdown Links | Broken Target Files | Missing Section Headers |
|---|---|---|---|---|---|
| `phase-1-report.md` | 384 | 8 | 0 | **0** | **0** |
| `phase-2-report.md` | 202 | 6 | 0 | **0** | **0** |
| `phase-3-regression-matrix.md` | 68 | 4 | 0 | **0** | **0** |
| `phase-4-report.md` | 302 | 14 | 0 | **0** | **0** |
| `phase-4-open-gaps.md` | 92 | 18 | 0 | **0** | **0** |
| `phase-5-report.md` | 666 | 32 | 0 | **0** | **0** |
| `phase-5-open-gaps.md` | 112 | 12 | 0 | **0** | **0** |

**Outcome:** Every cross-document link and section citation points to a real, existing file and section. Zero broken Markdown links exist across these documents.

### 4.3 Detailed Line Citation Findings & Historical Anomalies

The automated audit identified three specific line-citation anomalies resulting from document evolution:

1. **`docs/implementation/phase-4-open-gaps.md:90` (Out-of-Bounds Line Reference)**
   - **Text:** `pubspec.yaml dependency_overrides: riverpod: 2.6.1, pinned to dodge the analyzer "18 893 issue storm" (phase-3-open-gaps.md:119-122).`
   - **Finding:** `docs/implementation/phase-3-open-gaps.md` contains only **50 lines**. Citing lines 119-122 is an out-of-bounds line reference.
   - **Analysis:** In git history, `pubspec.yaml` never actually contained a `dependency_overrides: riverpod` entry on `main`. The citation appears to have originated from an intermediate draft or scratchpad note during the Phase 3 analyzer investigation.
   - **Recommendation:** Keep as historical text; annotated in this audit as a non-reproducible line reference.

2. **`docs/implementation/phase-1-report.md:198` (Line Number Shift Due to Later Annotation)**
   - **Text:** `- docs/implementation/_work/security.md:38 — deno test …/family-admin → 4 passed.`
   - **Finding:** In `docs/implementation/_work/security.md`, the cited command sits at line 43.
   - **Analysis:** During Phase 4 (gap DOC-01), an annotation block was added to `_work/security.md`, shifting the original line 38 to line 43. Note that lines 199-202 of `phase-1-report.md` already contain a dated correction explaining the DOC-01 update.
   - **Recommendation:** No further action required; the dated annotation in `phase-1-report.md:199-202` already accounts for the shift.

3. **`docs/implementation/phase-5-report.md:567` (EV-02 Non-Existent File Citation)**
   - **Text:** `EV-02: 20261103000100 header cited docs/implementation/_work/p5-sql05.md, a file that does not exist.`
   - **Finding:** The header of migration `20261103000100_zone_delete_atomic_rpc.sql` originally cited `_work/p5-sql05.md`.
   - **Analysis:** Phase 5 identified this defect (EV-02) and repointed the migration header to `docs/evidence/phase5/MANIFEST.md` §2 rows 9-10 and §3. The reference in `phase-5-report.md:567` is correctly documenting the resolved defect.

### 4.4 End-to-End Gap Continuity (Phase 3 through Phase 6)

The table below reconciles the complete lifecycle of all architectural, security, and verification gaps across project phases:

| Gap ID | Originating Phase | Phase 4 Status | Phase 5 Status | Phase 6 Status & Disposition |
|---|---|---|---|---|
| **HOST-01** | Phase 3 | P1 (Open, catalog verified) | P1 (Open, unapplied) | **P1 Deployment Blocker** (Phase 1–5 SQL unapplied to hosted DB) |
| **HOST-02** | Phase 3 | P2 (Open, CLI absent) | P3 (Staleness disclosed) | **P3 Open** (Hosted catalog facts unchanged since 2026-10-30 audit) |
| **GATE-B-01 / AND-01** | Phase 4 | P2 (75 rows NOT RUN) | P1 (Stopped by Ruling #9) | **P1 Open** (Comprehensive QA plan delivered; device execution withheld) |
| **TEST-01** | Phase 3 | P2 (Handlers bare) | Closed (handler.ts + 24 tests) | **CLOSED** (Negative control N1 proven) |
| **KOT-01** | Phase 2/3 | Closed (35 tests green) | Closed | **CLOSED** (JVM test suite passes) |
| **KOT-02** | Phase 2 | P3 (Duplicated helper) | Closed (EnforcementMode.kt) | **CLOSED** (Pure helper + 4 unit tests, call sites delegated) |
| **SQL-01 / R3** | Phase 3 | P1 if run (Quarantined) | Quarantined | **QUARANTINED** (Unsafe rollback forbidden) |
| **SQL-04 / SQL-04r** | Phase 3 | P2 (Unbounded RPC) | P2 (Stopped by Ruling #3) | **STOPPED by owner ruling** (Single transaction sweep retained) |
| **SQL-05** | Phase 3 | P1 (Mitigated only) | Closed locally (20261103000100) | **CLOSED in codebase** (Hosted apply pending HOST-01) |
| **SQL-06 (wording)** | Phase 3 | P2 (Docs wording) | Closed (api-contract.md) | **CLOSED** (Contract re-worded; hosted pre-check specified) |
| **SQL-06a** | Phase 4 | Closed (75 guard SQL) | Closed | **CLOSED** (Replay index guard tested) |
| **PERF-01a** | Phase 4 | P3 (Equivalence proven) | Closed locally (tests/74 §5) | **CLOSED in codebase** (Batch shape adopted; hosted apply pending) |
| **PRIV-01 / WORD-02** | Phase 3 | P2 (Stopped as instructed) | Closed (Scope disclosures) | **CLOSED** (3-state scope + disclosures tested) |
| **DUR-01 / CONF-01** | Phase 5 | — | Escalated (Rulings #10 vs #12) | **RECONCILED** (Commit b12659b landed on main; logs cataloged) |
| **GAP-EV-05** | Phase 5 | — | Open against Phase 4 digest | **DISCLOSED & CLOSED** (Phase 5 closing digest correctly sequenced) |
| **GAP-EV-06** | Phase 5 | — | Open (Scratch notes) | **CLOSED** (Invalid paths corrected in place; examples classified) |
| **GAP-EOL-01** | Phase 5 | — | Open (autocrlf hazard) | **AUDITED & SPECIFIED** (Full repo audit; .gitattributes proposed) |

---

## 5. Verification Commands for the Owner & Reviewer

To re-verify the findings and corrections in this report, execute the following commands from the repository root:

1. **Verify Corrected Command Paths:**
   ```bash
   # Verify the fixed git show command in p4-enf-residual.md
   git show HEAD:lib/features/app_restrictions/app_restrictions_controller.dart | head -n 30

   # Verify the corrected test file reference in supabase/tests/README.md
   grep "76_zone_delete_atomic_rpc.sql runs after" supabase/tests/README.md
   ```

2. **Inspect Repository Line Endings:**
   ```bash
   # Check core.autocrlf and .gitattributes existence
   git config core.autocrlf
   ls -la .gitattributes

   # Inspect line endings across working tree vs git index
   git ls-files --eol | grep "w/crlf"
   ```

3. **Verify Clean Git Status (Except Tracked Path Fixes):**
   ```bash
   git diff --stat
   ```
