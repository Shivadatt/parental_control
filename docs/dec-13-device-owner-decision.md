# DEC-13 — Device Owner / Managed Mode Decision Package

**Decision ID:** DEC-13  
**Status on 2026-11-05 (Phase 9.2):** **APPROVED — OPTION B (Managed Mode Required for Full Enforcement)**  
**Explicit Owner Rulings:**
1. **Product Architecture:** **OPTION B** — Standard Android mode remains available for monitoring and capabilities supported by ordinary Android permissions. Full app suspension and managed enforcement strictly require Device Owner mode. If provisioning fails, the device remains in Standard Mode without claiming full enforcement.
2. **Device Owner Safe Exit Policy:** **MANDATORY IN-APP NON-DESTRUCTIVE EXIT (RELEASE BLOCKER).** A safe, non-destructive in-app Device Owner exit mechanism is mandatory before Managed Mode can be released to production. Factory reset must not be the only supported consumer exit mechanism.
3. **Device Administrator Disposition:** **RETIRED.** The Device Administrator mode and label are to be retired completely from the product ladder, parent UI, child UI, and telemetry. It will not be presented as a third management tier.
4. **Release Signing Keystore:** **DEFERRED.** Creation of the production release keystore is deferred and requires separate explicit owner authorization.
5. **Authorization Boundary:** This approval authorizes the architectural decision and documentation updates only. It does **NOT** authorize implementation, provisioning, APK builds, device testing, signing-key creation, hosted changes, or deployment.

**Repository:** `D:\parentcontrol_app` — branch `main`, HEAD `b398ab8425b256f5991aed0dd55b8ccd1d71fbe6`.  
**Governance in force:** DEC-01 APPROVED (Choice B) · DEC-02 PENDING/BLOCKED · DEC-03 PENDING/BLOCKED (75/75 QA rows NOT RUN) · DEC-05 APPROVED (Choice B) · DEC-13 APPROVED (Option B) · DEC-12 PROPOSED · DEC-14…DEC-16 PROPOSED · Phase 10 NOT AUTHORISED.  
**Related documents:** `docs/p0-decision-specifications.md:124`, `docs/supabase-hosted-state-verification-2026-11-05.md`, `docs/dec-13-decision-readiness-report.md`, `phase-9-owner-decision-register.md`.

---

## 0. Method, evidence discipline and disclosure

### 0.1 How every claim below was established

Every capability statement cites repository source at a line number that was read in this session. Verification vocabulary:

| Label | Meaning |
|---|---|
| VERIFIED (CODE) | The source exists at the cited line and does what is stated. Says nothing about runtime. |
| VERIFIED (HOSTED, 2026-11-05) | Read-only live Supabase inspection during Phase 9; **not re-inspected in this pass**. |
| PARTIALLY VERIFIED | Object exists; behaviour depends on a device/OS response never observed here. |
| NOT TESTED | No runtime observation exists. Every item blocked by DEC-03. |
| ABSENT | Named search over named paths returned nothing; the search is stated. |
| DOCUMENTED-ONLY | A procedure exists in a `.md` file with no corresponding code. |
| UNKNOWN | Cannot be established without a device or an OS-behaviour test. |

**No method existence is treated as feature working.** No documentation statement is treated as implementation proof. No unit test is treated as device evidence.

### 0.2 Sub-agent disclosure (owner instruction: "use 6 subagents")

Six read-only sub-agents were dispatched across disjoint inspection domains in Phase 9.1:
1. **Android Policy Inspector** (`588f7d16-8a65-450f-8a7c-909a5d447e0f`): Verified Kotlin policy enforcement core (`EnforcementMode.kt:16-26`, `PolicyApplier.kt:116-161, 271-321`, `GuardianService.kt:502-509, 669-671`, `AndroidManifest.xml:95-105`, and `device_admin.xml:1-6`). Confirmed DPM call sites and empty Device Admin capabilities.
2. **Provisioning Lifecycle Inspector** (`fe58b1ed-f4ba-45e5-a5e1-3999b2394e4c`): Verified complete absence of in-code provisioning (QR, NFC, Zero-touch, EMM; `android_dpc` empty), absence of programmatic teardown (`clearDeviceOwnerApp`), that factory reset is the only teardown path (`docs/device-owner-provisioning.md:724`), and that Android 15 boot foreground service is refused in `BootReceiver.kt:31-37`.
3. **Flutter UI & Model Inspector** (`6c79449b-2b1d-4434-a27e-42de5e2f2619`): Verified Dart mode parsing (`device.dart:415, 448`), presentation labels (`device_presentation.dart:7-21`), anti-overpromise banners (`app_restrictions_page.dart:127-147, 293-302, 348-360`), exact-match proof logic (`policy_enforcement.dart:59-70, 174-208`), and child-side honest status disclosure (`child_shell_controller.dart:106, 126-135`, `child_home_tab.dart:103-115`, `child_rules_tab.dart:66-77`, `child_restrictions_page.dart:124-183`).
4. **Backend Schema & Edge Function Inspector** (`fbd76d28-8c41-426c-8ef8-0a98c90907d3`): Verified SQL schema CHECK constraints (`core.sql:100-101, 185-186`), strict SELECT-only RLS for `authenticated` (`rls.sql:68-73, 259-266`), `decideEnforcement` precedence in Edge Functions (`enforcement.ts:51-130`), telemetry updates (`device-telemetry/index.ts:28, 87-119`), and hosted production discrepancies (0/17 historical acks carry counters, 2/2 active devices report `device_admin`).
5. **Governance & Register Inspector** (`ba63da11-c317-4d2d-8ad2-eeb4afcb3b43`): Verified byte-identical SHA-256 match between `phase-9-owner-decision-register.md` and `docs/implementation/phase-9-owner-decision-register.md`, current status of DEC-01 (APPROVED Choice B), DEC-02 (BLOCKED), DEC-03 (BLOCKED 75/75 NOT RUN), DEC-05 (APPROVED Choice B), DEC-12..16 (all PROPOSED), and absolute rule that DEC-13 remains PROPOSED.
6. **Capability Matrix & DEC-12 Inspector** (`280ae102-e0b8-43b4-a722-773f316683b4`): Verified screen-time limits and bedtime device lock are measurement-only in this codebase (parsed at `PolicyJson.kt:16`, zero readers in applier or DPM), analyzed the empty-target false-`enforced` bug (`enforcement.ts:124-129`), detailed the 8 blockers before the parent UI can truthfully show `enforced`, and synthesized the Option A/B/C comparison.

All 6 sub-agents returned structured, line-cited evidence. Every cited repository source was verified directly against the codebase. No sub-agent result was invented, and DEC-13 remains strictly PROPOSED awaiting owner decision.

### 0.3 Labelling reconciliation with `docs/p0-decision-specifications.md`

The earlier DEC-13 entry used labels (A) Standard-only / (B) Dual mode / (C) Managed-primary. **This package uses the option definitions supplied in the Phase 9.1 brief**, which are different:

| This document | Earlier document | Relationship |
|---|---|---|
| **OPTION A** — Standard Android first | close to earlier (A) plus its UI honesty requirements | same family |
| **OPTION B** — Managed mode required for full enforcement | close to earlier (B) "dual mode" | same family |
| **OPTION C** — Two explicit product tiers | earlier (B) taken to a commercial conclusion | superset of B |

The recommendation in §8 is stated so that it maps consistently onto both labelling schemes; no governance status changes, and **DEC-13 remains PROPOSED under either naming.**

---

## 1. Problem statement

The enforcement capability the product markets — "apps get blocked on the child's phone" — rests on exactly one Android API in this codebase, `setPackagesSuspended`, which the OS grants only to a **Device Owner**. Everything else the app does today (location, usage, alerts, safe zones, consented audio, remote assist) runs on ordinary Android permissions.

The decision the owner must make is therefore not technical but product-level, and it is unavoidable:

1. **Either** the product promises app blocking and accepts the Device Owner lifecycle that comes with it — including provisioning that no ordinary guardian can perform today, and a removal path that is currently a factory reset;
2. **or** the product does not promise app blocking, and the enforcement vocabulary shrinks to monitoring plus honestly-labelled unsupported states;
3. **or** the product sells two different things, and must then maintain two truthful feature matrices, two onboarding flows and two support stories.

The current build sits in an unintended fourth position: it contains a full Device Owner enforcement pipeline, a `device_owner`/`device_admin`/`none` wire vocabulary, honest UI warnings — **and no supported way to reach the Device Owner state, and no supported way to leave it.** Production reflects that: of 14 hosted devices, the two `device_owner` rows are **both revoked**, and the only two active devices report `device_admin` (VERIFIED HOSTED, 2026-11-05).

A fourth, quieter problem: **Device Administrator mode currently buys nothing at all** (§3.4). It is a label the system reports and the child is asked to grant, with zero enforcement capability behind it. That has to be either given substance or removed from the product, and it is a DEC-13 question because it is the same mode ladder.

---

## 2. Current registered status

- Governance register: DEC-13 is **APPROVED (OPTION B)** as recorded in `phase-9-owner-decision-register.md` and `docs/implementation/phase-9-owner-decision-register.md` (Phase 9.2 Addendum, 2026-11-05).
- Owner rulings recorded:
  - Architecture: **Option B** (Standard Mode for monitoring; Managed Mode via Device Owner for full app suspension; fallback to Standard Mode on provisioning failure).
  - Exit policy: **Non-destructive in-app exit is mandatory (Release Blocker).** Factory reset must not be the only supported consumer exit.
  - Device Administrator: **Retired.**
  - Release signing keystore: **Deferred** (requires separate owner authorization).
- Explicit scope boundary: Approving Option B does **not** authorize DEC-02 hosted migrations, DEC-03 device QA testing, Phase 10 implementation, APK builds, keystore creation, or device provisioning. All remain separately gated.

---

## 3. Verified implementation (code, this session)

### 3.1 The mode ladder is real and consistently wired

| Layer | Evidence | Status |
|---|---|---|
| Single source of truth for the reported mode | [EnforcementMode.kt:22-26](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/EnforcementMode.kt#L22) — `device_owner` beats `device_admin`, else `none` | VERIFIED (CODE) |
| Wire contract declared in SQL | [20260101000000_core.sql:100-101](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L100) — `enforcement_mode text not null default 'none' check (… in ('none','device_admin','device_owner'))` | VERIFIED (CODE); column present on hosted (Phase 9) |
| Detection | `PolicyApplier.kt:284-289` (`isDeviceOwnerApp`), `:291-296` (`isAdminActive`) | VERIFIED (CODE) |
| Ack + heartbeat both delegate to it | `PolicyApplier.kt:234`, `GuardianService.kt:669-670` | VERIFIED (CODE) |
| JVM test pins all four combinations + vocabulary | [EnforcementModeTest.kt:22-54](file:///D:/parentcontrol_app/android/app/src/test/kotlin/com/parentcontrol/parent_control/EnforcementModeTest.kt#L22) | VERIFIED (CODE) — **tests not executed in this pass** |

### 3.2 App suspension / restoration — the only Device-Owner capability implemented

The whole application calls `DevicePolicyManager` at **five sites only** (search: `devicePolicyManager\.` over `android/app/src/main/kotlin`):

| Call | file:line | DO required | Status |
|---|---|---|---|
| `isPackageSuspended` | [PolicyApplier.kt:274](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt#L274) | yes | VERIFIED (CODE) |
| `isDeviceOwnerApp` | `PolicyApplier.kt:286` | — (always callable) | VERIFIED (CODE) |
| `isAdminActive` | `PolicyApplier.kt:293` | — | VERIFIED (CODE) |
| `setPackagesSuspended(…, true)` | `PolicyApplier.kt:302` | **yes** | VERIFIED (CODE) — NOT TESTED |
| `setPackagesSuspended(…, false)` | `PolicyApplier.kt:315` | **yes** | VERIFIED (CODE) — NOT TESTED |

Supporting machinery that is genuinely implemented and matters for honesty:

- **Target resolution** `PolicyApplier.kt:56-89`: self-block refused (`:64-68`), protected system components refused with an error string (`:70-83`), uninstalled targets dropped **without** entering the failure denominator (`:84-87`).
- **DO-precondition branch** `PolicyApplier.kt:116-124`: when targets exist and the app is not Device Owner, it records `"Device Owner provisioning is required to suspend apps on this device. No apps were suspended."` and keeps the target set in `unsupported` so the server can mark it unsupported rather than enforced.
- **Owner branch** `PolicyApplier.kt:125-133` (suspend the diff, restore the diff) and **lost-owner branch** `:134-142` (error, no silent restore).
- **Post-verification against the OS**, not against the request: `PolicyApplier.kt:144-160` re-reads `isSuspended` for every desired and previously-suspended package and records failures.
- **Honest capability flag** `PolicyApplier.kt:171-173`: `enforcement_supported = isOwner && (suspendCallSucceeded || applied == desired)`.
- **Counter-bearing ack** `PolicyApplier.kt:363-379`: `desired_count`, `applied_count`, `failed_count`, `enforcement_supported`, `enforcement_mode`, `failures` — emitted only when `countsKnown` is true; after any exception the counts are deliberately withheld (`:179-189`).

### 3.3 Server-side consumption of that honesty

| Piece | Evidence | Status |
|---|---|---|
| Ack never derives status from command success alone | [handler.ts:376-391](file:///D:/parentcontrol_app/supabase/functions/device-command/handler.ts#L376) — `decideEnforcement({result, ackStatus, targetsApps: policyTargetsApps(command.payload.policy)})` | VERIFIED (CODE) |
| Mapping rules | `enforcement.ts:83-89` `unsupported`/`device_owner_required`; `:92-102` `pending`/`enforcement_counts_missing`; `:104-112` `pending`/`no_apps_suspended`; `:114-119` `failed`; `:124-129` `enforced` + version advance | VERIFIED (CODE) |
| `enforcement_status` CHECK | `20260101000000_core.sql:185-186` (`pending`/`enforced`/`failed`/`unsupported`) | VERIFIED (CODE); present on hosted |
| Heartbeat writes the mode, validated against an enum | [device-telemetry/index.ts:28](file:///D:/parentcontrol_app/supabase/functions/device-telemetry/index.ts#L28) `ENFORCEMENT_MODES`; `:87-118` patch + update | VERIFIED (CODE) |
| Heartbeat may **not** advance `policy_version` | `device-telemetry/index.ts:84-85` (explicit comment + no write) | VERIFIED (CODE) |
| `authenticated` cannot write device rows at all | `20260101000200_rls.sql:68-72` — the only `devices` policy is SELECT for parent-or-child; `:257-266` column-scoped SELECT grant excluding `secret_hash`/`installation_id` | VERIFIED (CODE); RLS posture confirmed on hosted in Phase 9 |

### 3.4 Device Administrator is a label with no capability behind it

| Fact | Evidence |
|---|---|
| The admin receiver is declared, exported and correctly protected by `BIND_DEVICE_ADMIN` | [AndroidManifest.xml:95-105](file:///D:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L95) |
| The policies file requests **nothing**: `<uses-policies />` with the comment "App suspension is a Device Owner capability and must never be applied without it" | [device_admin.xml:2-5](file:///D:/parentcontrol_app/android/app/src/main/res/xml/device_admin.xml#L2) |
| The receiver subclass is empty — no `onEnabled`/`onDisabled`/`onProvisioningComplete` | [ParentControlDeviceAdminReceiver.kt:18](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/ParentControlDeviceAdminReceiver.kt#L18) |
| The app *can* ask the user to become device admin | `NativeBridge.kt:398-410` (`ACTION_ADD_DEVICE_ADMIN`, `EXTRA_ADD_EXPLANATION`); wired to the child UI at `lib/features/child/controllers/child_shell_controller.dart:832` |
| …and the child UI already says what admin is worth | `child_shell_controller.dart:131-133` — `'Device admin only — app blocking is not available'` |

**Conclusion (VERIFIED CODE):** granting Device Administrator changes the reported mode from `none` to `device_admin` and changes **zero** enforcement outcomes. Only five DPM calls exist, and four of them are suspension-related.

### 3.5 Runtime lifecycle that a managed mode would depend on

| Mechanism | Evidence | Status |
|---|---|---|
| Intervals: tick 10 s, poll 20 s, policy re-apply 60 s, heartbeat 5 min, apps 30 min, usage 60 min | `GuardianService.kt:38-45` | VERIFIED (CODE) |
| Service survives process restart only via `START_STICKY`; refuses to start unconfigured | `GuardianService.kt:165-171` | VERIFIED (CODE) |
| Android 15 `dataSync` foreground-service timeout is surfaced, not hidden | `GuardianService.kt:195-209` | VERIFIED (CODE) |
| Reboot / update resume, with an explicit Android 15 refusal | [BootReceiver.kt:17-52](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/BootReceiver.kt#L17) (`:31-37` device-OS check; `:38-44` notification gate; `:45-51` start + toast) | VERIFIED (CODE) — NOT TESTED |
| No `WorkManager`/`AlarmManager`/`JobScheduler` fallback exists anywhere | search `WorkManager\|AlarmManager\|JobScheduler\|JobService\|setRecurring` over `android/app/src/main` → no match | ABSENT |
| No `onTaskRemoved` teardown/restart logic in `GuardianService` (it exists only in `AudioAssistanceService.kt:499`) | search `onTaskRemoved\|stopWithTask` over `android` | ABSENT (Guardian) |
| Command dedupe happens **before** the ack is attempted, and a failed ack is not retried | `GuardianService.kt:377` (`handledCommands().contains(commandId) → return`), `:475` `markCommandHandled` then `:477 sendAck`, `:478-480` on failure only `recordError(...)` | VERIFIED (CODE) — silent result loss, see §13 |
| Persisted policy + suspended set in EncryptedSharedPreferences; backup disabled | `SecureStore.kt:38-40`, `:76-81`, `:162-179`; `AndroidManifest.xml:43` `allowBackup="false"` | VERIFIED (CODE) |
| Whether an OS suspension survives a device reboot | no code can answer this | **UNKNOWN** — DEC-03 blocked |

### 3.6 Parent- and child-visible mode disclosure is already honest

| Screen | Evidence | Wording |
|---|---|---|
| Shared mode label | [device_presentation.dart:7-18](file:///D:/parentcontrol_app/lib/features/devices/device_presentation.dart#L7) | "Fully managed (Device Owner)" / "Device admin only" / "Not enforced" / **"Not reported"** for unknown |
| Shared unsupported predicate | `device_presentation.dart:20-21` | `appSuspensionUnsupported(device) => mode != 'device_owner'` |
| Policy status tone | `device_presentation.dart:58-69` | `unsupported` renders neutral, never green |
| App-restrictions header + warning | `app_restrictions_page.dart:106`, `:127-137` | "Android only allows setPackagesSuspended when Parent Control is the Device Owner… a saved policy can be acknowledged but apps cannot be suspended." |
| Anti-overpromise banner | `app_restrictions_page.dart:139-147` | "A database flag does not block an app… Nothing on this screen claims an app is blocked before that acknowledgement." |
| Refusal surfaced on ack | `app_restrictions_page.dart:313` | "The device refused enforcement. Fully managed Device Owner provisioning is required to suspend apps." |
| Report model | [policy_enforcement.dart:59-82](file:///D:/parentcontrol_app/lib/data/models/policy_enforcement.dart#L59) | `isUnsupported`, `provesFullEnforcement` (supported + counts + zero failures), `unsupportedMessage` = "App blocking requires Device Owner…" |
| Attribution discipline | `policy_enforcement.dart:109-133` | `PolicyReportCorrelation` matched / uncorrelated / mismatched; uncorrelated reports are "never proof" (the ENF-01 lesson) |
| Child-side status | `child_shell_controller.dart:126-135`; `child_home_tab.dart:110`; `child_rules_tab.dart:72,110`; `child_settings_tab.dart:197-199,250`; `child_restrictions_page.dart:133-135` | the child is told plainly when the app is not a Device Owner |
| Device detail warning | `device_detail_page.dart:101` | "This device is not a fully managed Device Owner device…" |

**This materially lowers the risk of OPTION A and OPTION B**: the honesty scaffolding exists; what is missing is a way to reach the managed state, and a way to leave it.

---

## 4. Missing functionality (with the searches that establish it)

| # | Missing | Search run | Classification |
|---|---|---|---|
| 1 | **Any Device Owner provisioning path in code.** No `ACTION_PROVISION_MANAGED_DEVICE`, no QR/`afw`/`AUTHENTICATE`/`NFC`, no zero-touch/AFF, no EMM/EMDM client, no `setActiveAdmin`/`addDeviceOwner`. | grep `ACTION_PROVISION*`, `PROVISIONING`, `zero-touch`, `affiliate`, `afw`, `qr`, `setActiveAdmin`, `addDeviceOwner` over `android/`, `lib/` | **ABSENT / DOCUMENTED-ONLY** |
| 2 | **Any teardown path.** No `clearDeviceOwnerApp`, no `removeActiveAdmin`, no `removeOwner`, no `getActiveAdmins`. The documented consequence stands: [docs/device-owner-provisioning.md:724](file:///D:/parentcontrol_app/docs/device-owner-provisioning.md#L724) "**Factory reset is the only reliable teardown for the current build.**" | grep `clearDeviceOwner\|removeActiveAdmin\|removeOwner\|getActiveAdmins` over `android/`, `lib/`, `supabase/` | **ABSENT** |
| 3 | **No DPC / managed-provisioning app package.** `android_dpc/` exists but is empty (`ls -la` → no entries). | directory listing | **ABSENT (empty scaffold)** |
| 4 | **Screen-time daily limit is parsed, never enforced.** Only `PolicyJson.kt:16` parse + `PolicyModels.kt:43` field; no `setBusyTime`, no `setMaximumTimeToLock`, no Digital Wellbeing parent-facing API, no usage-based lock. | grep `dailyScreenTimeLimit\|BusyTime\|setMaximumTimeToLock\|timeLock` over `android/app/src/main` | **ABSENT (reporting only)** |
| 5 | **Bedtime is informational only.** `PolicyApplier.kt:369-370` writes `bedtime_active` with the comment "bedtime is stored but app suspension follows app rules"; real time-window blocking exists only through per-app rules (`PolicyModels.kt:24-35`). | read of `PolicyApplier.kt:349-379`, `PolicyModels.kt:24-76` | **PARTIALLY IMPLEMENTED (windows via app rules; no device lock)** |
| 6 | **No device-restriction APIs at all**: `setUninstallBlocked`, `setKeyguardDisabled`, `setScreenCaptureDisabled`, `installCaCertificate`, `addPersistentPreferredActivity`, `setProfileOwner`, `wipeData`. | single grep over `android/app/src/main`, `lib`, `supabase` (see §3.2 call-site census) | **ABSENT** |
| 7 | **Device Admin has nothing to grant** (§3.4). | `device_admin.xml:2-5` | **ABSENT capability, PRESENT label** |
| 8 | **Release signing identity is unresolved.** [build.gradle.kts:13-22](file:///D:/parentcontrol_app/android/app/build.gradle.kts#L13) derives `hasReleaseSigning` from `android/key.properties`; that file does **not** exist (only `android/key.properties.example`); `:67-77` falls the release build back to the **debug** key, and `:30-32` warns `release build signed with DEBUG key - not shippable`. | `ls android/key.properties` → not found; read of build.gradle.kts | **BLOCKER for any managed commitment** |
| 9 | **No instrumented test surface.** `android/app/src/androidTest` does not exist; JVM unit tests exist (`EnforcementModeTest.kt`, `policy/PolicyEvaluatorTest.kt`, four `AudioAssistance*Test.kt`) but a JVM test cannot exercise `DevicePolicyManager`. | `ls android/app/src/androidTest` → No such file; `find android -name "*Test.kt"` | **ABSENT** — DO behaviour has never been observed |
| 10 | **The Flutter-initiated immediate apply path is unreachable.** Native channel `applyPolicy` is registered (`NativeBridge.kt:132`, `:271-283`) and wrapped in Dart (`device_admin_service.dart:87`), but grep for `.applyPolicy(` over `lib` excluding the service returns **no caller**. Enforcement therefore flows only through the poll/ack path. | grep `\.applyPolicy\(` lib | **DEAD PATH (code present, not wired)** |
| 11 | **No per-device capability contract beyond mode + 6 booleans.** Heartbeat capabilities: `enforcement_mode` + usage/location/background-location/camera/microphone/notifications (`GuardianService.kt:502-509`, `supabase_device_repository.dart:178-188`). There is no "supported features" list, no reason codes, no device-policy-capability table. | read of both producers + hosted column list | **MISSING (structured capability report)** |
| 12 | **The same rule is implemented three times.** Kotlin pure object, Dart heartbeat conditional (`supabase_device_repository.dart:179-181`), and server enum (`device-telemetry/index.ts:28`). No shared fixture test pins them together. | grep `enforcement_mode` over `lib`, `supabase`, `android` | **PRESENT RISK (drift)** |
| 13 | **Deployed server logic is not proven to match repository logic.** `enforcement.ts` exists locally, but the newest hosted deployment is 2026-10-27T18:07:08Z and **0 of 17 hosted `device_commands` carry `desired_count`** (Phase 9, VERIFIED HOSTED). The honest ack contract has therefore never been observed end-to-end. | Phase 9 hosted report §9 | **HISTORICAL/UNDETERMINED** — re-check needs DEC-02 |

---

## 5. Capability matrix

### 5.1 Mode ladder — the six device states asked for

| State | `enforcement_mode` reported | Can suspend apps? | How the app gets there | Reversibility |
|---|---|---|---|---|
| **1. Standard Android device** | `none` | **No** | Default for any Play/sideload install (VERIFIED CODE) | N/A |
| **2. Device Administrator mode** | `device_admin` | **No** | Child taps the admin prompt: `NativeBridge.kt:398-410` → `child_shell_controller.dart:832` | Reversible in Settings (DA can be deactivated) |
| **3. Fully managed Device Owner** | `device_owner` | **Yes (code)** | **No in-app path.** Only the lab ADB ceremony in `docs/device-owner-provisioning.md` (self-labelled NOT EXECUTED) on a factory-reset, account-free device; requires a stable non-debug signing key | **Factory reset only** (`docs/device-owner-provisioning.md:724`) |
| **4. Device Owner revoked or lost** | `none`/`device_admin` again | No | Not detected by an event — recomputed on each tick/heartbeat (`PolicyApplier.kt:234`, `GuardianService.kt:669-670`) | Stale suspensions are **not** restorable by the app (`PolicyApplier.kt:134-142`) |
| **5. Provisioning incomplete or failed** | `none` | No | **Not represented at all** — the app never attempts provisioning, so there is no "provisioning failed" state | N/A (ABSENT) |
| **6. Unsupported Android/OEM configuration** | any mode string | Unknown | Android 15 blocks `dataSync` FGS at boot (`BootReceiver.kt:31-37`); OEM task-kill has no scheduled fallback (§3.5); `QUERY_ALL_PACKAGES` is Play-restricted (`AndroidManifest.xml:24-29`) | N/A |

### 5.2 Capability × mode

Legend — **Impl.** = implemented in code (VERIFIED CODE unless noted); **Std** = available on a standard device; **DA** = available with Device Administrator only; **DO** = requires Device Owner; **Perm** = extra Android permission/setting; **Managed** = managed device required; **RT** = runtime tested; **DEC-03** = blocked pending device testing.

| Capability | Impl. | Std | DA | DO | Perm | Managed | RT | DEC-03 | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| **App suspension** | YES | NO | NO | YES | DO provisioning | **YES** | **NOT TESTED** | **BLOCKED** | `PolicyApplier.kt:302` (`:116-124` honest refusal otherwise) |
| **App restoration** | YES | NO | NO | YES | DO | **YES** | NOT TESTED | BLOCKED | `PolicyApplier.kt:313-321`, diff at `:126-133`, `PolicyApplier.kt:244-256` |
| **App blocking (policy→suspension pipeline, incl. time windows)** | YES (suspension only) | NO | NO | YES | usage/location unrelated | YES | NOT TESTED | BLOCKED | `PolicyModels.kt:67-76` + `PolicyApplier.kt:56-89` + `GuardianService.kt:396-416` |
| **Screen-time daily limit enforcement** | **NO — report only** | NO | NO | **NO (nothing implemented)** | `PACKAGE_USAGE_STATS` (user-granted) | n/a | NOT TESTED | BLOCKED | parse `PolicyJson.kt:16`; no DPM limit anywhere (§4 #4) |
| **Bedtime enforcement** | **PARTIAL** | windows via app rules only | NO | windows only | — | for a device-wide lock: YES | NOT TESTED | BLOCKED | `PolicyModels.kt:24-35`; `PolicyApplier.kt:369-370` (informational) |
| **Device restrictions (uninstall block, keyguard, camera disable, wipe, allowlist install)** | **NO** | NO | NO | would require DO | — | YES | NOT TESTED | BLOCKED | ABSENT (§4 #6) |
| **Permission handling / capability snapshot** | YES | YES | YES | YES | runtime perms | NO | NOT TESTED (UI) | BLOCKED | `NativeBridge.kt:183-204`; `permissionGapsFor` `device_presentation.dart:73-82` |
| **Location, usage reporting, safe zones, alerts** | YES | YES | YES | YES | location, background location, notifications, usage access | NO | NOT TESTED | BLOCKED | `GuardianService.kt:499-509`; `UsageReporter.kt` (no block/limit refs) |
| **Consented remote audio** | YES | YES | YES | YES | `RECORD_AUDIO`, mic FGS | NO | **FAILED on tested build 4005** (Phase 8) | BLOCKED | `AndroidManifest.xml:89-93` + Phase 8 findings |
| **Device unlinking / credential revoke** | YES | YES | YES | YES | — | NO | NOT TESTED | BLOCKED | `NativeBridge.kt:381-396`; `functions.sql:761-771` + `private.revoke_device:432-458`; `unlink_child` `:748-759` |
| **Device Owner revocation (in-app)** | **NO** | NO | NO | **NO** | — | YES | NOT TESTED | BLOCKED | ABSENT (§4 #2); factory-reset-only teardown |
| **Recovery after service restart** | PARTIAL | YES | YES | YES | — | NO | NOT TESTED | BLOCKED | `GuardianService.kt:165-171`; no `onTaskRemoved` (§3.5); ack-loss path `:475-480` |
| **Recovery after reboot** | PARTIAL (blocked on Android 15) | YES | YES | YES | `RECEIVE_BOOT_COMPLETED` | NO | NOT TESTED | BLOCKED | `BootReceiver.kt:17-52`; no scheduler fallback |
| **Parent-visible capability status** | YES | YES | YES | YES | — | NO | NOT TESTED (UI) | BLOCKED | `device_presentation.dart:7-21`; `app_restrictions_page.dart:127-147` |
| **Honest server status derivation** | YES (repo) / **UNDETERMINED (deployed)** | — | — | — | — | — | never observed on hosted | needs DEC-02 + DEC-03 | `enforcement.ts:60-129`, `handler.ts:376-412` |

### 5.3 What is *not* blocked by DEC-03

Only three things in the table above can currently be raised beyond code reading: the JVM unit tests (`EnforcementModeTest`, `PolicyEvaluatorTest` — executable without a device, **not executed in this pass**), and static verification of RLS/SQL invariants. Everything with the word "suspension", "restoration", "reboot" or "UI behaviour" in it is DEC-03-blocked.

---

## 6. Three product options (as defined in the brief)

### OPTION A — Standard Android first

Baseline is ordinary Android permissions; Device Owner is optional and never required for the shipped promise; anything that needs DO is marked **unsupported** in copy and in the data model; managed capability switches on only after a valid provisioning is *detected* (not assumed).

- Product meaning: the feature list a family gets on a normal phone **is** the feature list. App blocking is not sold; it appears as "requires a managed device — not supported on this phone".
- Code impact: mostly **subtractive and additive-honest**. The existing `appSuspensionUnsupported` (`device_presentation.dart:20-21`) and warning banners already implement the disclosure; the app-restrictions screen would be demoted to "not available" rather than "configure and hope".
- Consequence the owner must accept: the strongest competitive feature (real app blocking) is off the table for ordinary users, and the DO pipeline (`PolicyApplier.kt:299-321`) becomes maintenance-only code.

### OPTION B — Managed mode required for full enforcement

Standard mode keeps monitoring and everything ordinary permissions allow. Full app suspension/managed enforcement **requires** Device Owner; Device Owner provisioning is an explicit enrollment step for that tier; the parent UI distinguishes Standard vs Managed; if provisioning fails, the device simply stays Standard.

- Product meaning: two capabilities, one product, an explicit enrollment gate to reach the upper one.
- Closest to the code as written: mode is already reported, `enforcement_supported` already computed (`PolicyApplier.kt:171-173`), the server already maps `device_owner_required` → `unsupported` (`enforcement.ts:83-89`).
- **Hard prerequisite the brief's phrasing hides:** "provisioning is a required enrollment step" is **not implementable today** — there is no in-app provisioning of any kind (§4 #1) and no supported removal (§4 #2). OPTION B therefore *implicitly mandates* building a real provisioning channel (QR/AFW or EMM) **and** a supported un-provision story, or it degrades into OPTION A in the field.
- "If provisioning fails, the device remains in Standard mode" is the correct and safest failure semantics, and matches the absence of any provisioning-failed state today.

### OPTION C — Two explicit product tiers

Formally two SKUs: **Standard protection** and **Fully Managed protection**, each with its own published feature matrix, onboarding flow, capability status and limitations.

- Product meaning: OPTION B's engineering posture plus commercial/UX/contractual separation — per-tier onboarding, per-tier copy, per-tier support scripts, per-tier acceptance criteria, and a matrix a family can read before buying.
- Adds the most clarity to the end user and the most ongoing burden to the team (two test matrices, two release-checklist sets, two OEM behaviour profiles).
- Also the only option that makes the honest labels in §3.6 *load-bearing* rather than incidental: the tier promise is exactly what the `enforcement_mode` field already distinguishes.

---

## 7. Comparison table

Scale: ● favourable / ◐ mixed / ○ unfavourable, judged against **this repository as it stands today**.

| Dimension | OPTION A — Standard first | OPTION B — Managed required | OPTION C — Two tiers |
|---|---|---|---|
| User experience | ○ no app blocking, but no broken promise | ◐ two experiences, one product; clear labels already exist | ● explicit, matched expectations |
| Android compatibility | ● works on everything the app already targets | ◐ upper tier only where provisioning is possible (OEM-dependent) | ◐ same as B, per tier |
| OEM restrictions (Realme/ColorOS task-kill, Android 15 boot block) | ● already the limiting factor for background sync, unrelated to mode | ○ managed tier is judged by OEM failures it cannot fix | ○ same exposure, but *contained* by tier expectations |
| Provisioning complexity | ● none (no provisioning) | ○ must build QR/AFW/EMM + verification; nothing exists today (§4 #1) | ○ same engineering, plus a tier-aware onboarding flow |
| Security | ● smallest attack surface; no device-wide power held | ○ Device Owner is the strongest non-root position; child can potentially disrupt an unprovisioned-owner setup | ○ same as B, with the benefit that the *standard tier* is clearly low-power |
| Privacy | ● no management footprint on a personal device | ◐ DO can read installed apps broadly; `QUERY_ALL_PACKAGES` is already declared (`AndroidManifest.xml:27-29`) | ●/◐ the managed tier is a *dedicated* device by design, which is the cleanest privacy story of all three |
| Support burden | ● one matrix | ◐ two behaviours, one product = "why doesn't it block my kid's apps?" tickets | ○ two matrices, two scripts — but tickets self-select |
| Release readiness | ● **shippable today** apart from the signing key | ○ blocked by provisioning + teardown + DEC-03 | ○ blocked by the same, plus product packaging |
| Long-term maintenance | ○ the DO pipeline rots unused, then gets re-litigated later | ◐ two code paths, one product contract | ● explicit contract per tier makes regressions visible; ◐ the cost is doubled test surface |
| Fit with current code | ◐ several screens would need demotion copy; the DO pipeline becomes dead code | ● the code already computes exactly B's state | ● B's state + `device_presentation.dart` labels become the tier definition |
| Fit with current production fleet | ● 14/14 hosted devices are already in A-compatible states | ◐ the 2 active devices are `device_admin`, which buys nothing (§3.4) | ◐ same |

---

## 8. Owner Ruling & Approved Architecture — **OPTION B APPROVED**

> **The owner has explicitly approved OPTION B as the product architecture**, with mandatory non-destructive in-app exit as a release blocker, complete retirement of Device Administrator mode, and deferral of the release signing keystore.

### 8.1 Approved Architectural Principles
1. **Standard Mode as Baseline:** Ordinary Android permissions provide monitoring, usage reporting, location tracking, safe zones, alerts, and consented audio. Full app suspension must not be promised or claimed in Standard Mode.
2. **Managed Mode via Device Owner:** Full app suspension and managed enforcement require Device Owner status. If provisioning fails, the device remains in Standard Mode without claiming full enforcement.
3. **Loss of Ownership Handled Honestly:** If Device Owner is lost or revoked, the device immediately transitions to Standard Mode; capability displays downgrade, and backend mapping returns `unsupported` (`device_owner_required`).
4. **Mandatory Safe In-App Exit (Release Blocker):** Managed Mode cannot be released to consumers while factory reset is the only teardown path. A safe, non-destructive in-app Device Owner removal path is a hard pre-condition for release.
5. **Retirement of Device Administrator:** The empty Device Admin receiver (`device_admin.xml:5`) and label are retired. The mode ladder becomes binary (`none` vs `device_owner`), eliminating consumer confusion.
6. **Release Signing Keystore Deferred:** Keystore generation is deferred to a separate authorized build/release preparation pass.

### 8.2 Scope Boundary
This architectural approval authorizes documentation updates only. It does **not** authorize code implementation, device provisioning, APK builds, ADB operations, or hosted Supabase mutations.

---

## 9. Security and privacy implications

Must be preserved by whichever option the owner chooses (all VERIFIED CODE today):

| Requirement | Current state |
|---|---|
| Parent–child authorization | `private.revoke_device` verifies an active `role='parent'` membership before revoking (`functions.sql:452-458`); devices readable by parent-or-child only (`rls.sql:68-72`) — **held** |
| RLS / backend authorization | No `insert/update/delete` policy for `authenticated` on `devices` (only SELECT) → device-row writes are service-role only — **held** |
| Device identity validation | Device-scoped selects at `_shared/auth.ts:261,305`; secret hash and `installation_id` excluded from the column grant (`rls.sql:257-266`) — **held** |
| Honest enforcement status | `enforcement.ts` refuses `enforced` without counters + support + zero failures (`:92-119`) — **held in repo code; never observed deployed** (§4 #13) |
| Clear indication of unsupported | reason code `device_owner_required`, `unsupported` status, neutral UI tone, explicit banners — **held** |
| No hidden restrictions | suspensions always visible as disabled apps; child told "This phone is not set up as a managed Device Owner device" (`child_home_tab.dart:110`) — **held** |
| No unauthorized Device Owner acquisition | the app never provisions (`ParentControlDeviceAdminReceiver.kt:16` "This app never attempts the provisioning command programmatically"), so DO can only be granted by an out-of-band ceremony — **held today by absence**; **this must remain true under any option**: no UI may ever make DO acquisition look like a routine permission prompt |
| No OS permission bypass | no `root`, no accessibility-abuse, no indicator suppression, `allowBackup="false"`, no scheduler fallback used to dodge Doze — **held** |
| Safe recovery after DO removal | **NOT held**: `restoreAll()` is DO-gated (`PolicyApplier.kt:247`) and, when not owner, treats everything as already restored (`:250-253`) and clears local policy state. Whether the OS cleared the suspensions at the same moment is **UNKNOWN** and is the single most important device question DEC-03 must answer |
| Child-visible management status | `child_shell_controller.dart:126-135` — **held** |

Risks a managed tier introduces, stated plainly:

- **Concentration of power.** The same code path that suspends packages sits next to `wipeData`/keyguard APIs the app has deliberately **not** called; a future feature request will want them. Any decision to go managed should carry an explicit "these APIs stay unused" line in the product contract.
- **Ownership lock-in as a child-safety issue.** If only a factory reset removes the owner, a family cannot exit the arrangement non-destructively; that is a trust and, in a separated-parent scenario, a coercive-power problem. This is why §4 #2 is a blocker, not a backlog item.
- **Self-reported mode.** `enforcement_mode` is whatever the device says it is (`device-telemetry/index.ts:89-95` validates only the enum). A child who roots, re-signs or replays telemetry can misreport the mode; the server has no independent proof. Acceptable for product status; **not** acceptable as a security assertion.
- **Package visibility.** `QUERY_ALL_PACKAGES` (`AndroidManifest.xml:27-29`) plus the app inventory upload is a broad installed-apps picture of a personal device in OPTION A/B-on-a-personal-phone. OPTION C's "dedicated managed device" framing is the cleanest privacy story.
- **Play policy.** The same file's comment already flags that a Play release needs a justified use case for `QUERY_ALL_PACKAGES`; a managed tier changes the review profile too.

---

## 10. Provisioning and device lifecycle assessment

| Mechanism / event | Classification | Evidence |
|---|---|---|
| **QR-code provisioning** | **MISSING** (no code); documented as NOT SUPPORTED | grep `PROVISIONING`/`afw`/`QR` → none; `docs/device-owner-provisioning.md:264-265` |
| **NFC provisioning (beam)** | **MISSING** | same searches; `docs/device-owner-provisioning.md:264-265` |
| **Zero-touch / AFF** | **MISSING** | grep `zero-touch`/`affiliate` → none |
| **EMM / EMDM / cloud-device-admin** | **MISSING** (no `android_dpc` payload — empty dir) | §4 #3 |
| **ADB lab-only provisioning** | **DOCUMENTED-ONLY** — procedure exists and self-declares not executed, and forbids the personal Realme | `docs/device-owner-provisioning.md:3-5`, `:70-76`, `:156-159`; `ParentControlDeviceAdminReceiver.kt:12-15` (command example in a comment) |
| **Device Admin activation (not DO)** | **IMPLEMENTED-CODE-ONLY** — intent fired from child UI; grants no policy | `NativeBridge.kt:398-410`; `device_admin.xml:2-5` |
| **Device Owner verification after enrollment** | **PARTIALLY VERIFIED** — re-detected every tick/heartbeat (`PolicyApplier.kt:234`, `GuardianService.kt:669-670`), but no enrollment-completion callback exists (receiver is empty, `ParentControlDeviceAdminReceiver.kt:18`) so "just provisioned" is never a known event | VERIFIED CODE |
| **Device Owner revocation (in-app)** | **MISSING**; documented teardown is factory reset | §4 #2; `docs/device-owner-provisioning.md:724` |
| **Device release / factory-reset implications** | **DOCUMENTED-ONLY** | same |
| **App-uninstall limitation while managed** | **MISSING** (no `setUninstallBlocked`) — and uninstalling a Device Owner app is OS-blocked anyway without owner removal | §4 #6 |
| **Recovery after provisioning failure** | **MISSING / N/A** — no provisioning exists, so no failure state; device naturally remains `none`, which is the safe default | §5.1 state 5 |
| **Ownership transfer** | **MISSING** (no `setActiveAdmin`, no owner-change code, no server concept of owner identity beyond `family_id`) | searches |
| **Device replacement** | **PARTIAL** — a new device pairs via the normal flow and old rows persist; no "replace" gesture, no history migration | pairing flows in `lib/features/pairing/**` |
| **Parent account unlinking** | **IMPLEMENTED-CODE-ONLY** — `public.unlink_child` (`functions.sql:748-759`) + `private.revoke_device` (`:432-458`); child-side sync teardown `NativeBridge.kt:381-396` | VERIFIED CODE |
| **Child account deletion** | governed by the account/family functions; **device rows and their `enforcement_mode` history are a retention question, not a DEC-13 one** | `account`/`family-admin` functions; retention is DEC-05 territory |
| **Suspension persistence across reboot** | **UNKNOWN** — code persists its own list (`SecureStore.kt:176-179`) and re-applies on tick, but whether the OS retains suspensions is a device question, DEC-03 blocked | §3.5 |
| **Recovery after service kill** | **PARTIAL** — `START_STICKY` only; no `onTaskRemoved`, no scheduled fallback | §3.5 |

**Explicit non-claims.** No provisioning was performed in this pass. The personal Realme `RMX2161` (`5HXWRGQ4IFU8WS4T`) was not touched and must not become a Device Owner test device — the existing procedure already forbids it (`docs/device-owner-provisioning.md:70-76`, `:156-159`). **A lab ADB ceremony is not production-ready provisioning, and is not described as such anywhere in this document.**

### 10.1 Safe In-App Device Owner Exit Architecture & Feasibility Analysis (Mandatory Release Blocker)

Under the approved DEC-13 ruling, **a safe, non-destructive in-app Device Owner exit mechanism is a mandatory release blocker.** Factory reset must not be the only supported exit path for consumers.

#### 1. Android Platform Constraints & API Realities
Android enforces strict platform boundaries on Device Owner teardown:
- **`DevicePolicyManager.clearDeviceOwnerApp(String packageName)`**: This is the only programmatic AOSP API allowing a Device Owner to remove its own device ownership. However:
  - It can only be called by the current Device Owner package itself.
  - **Irreversibility on user devices**: Once `clearDeviceOwnerApp` executes on an Android device with user accounts, Device Owner **cannot** be reprovisioned without removing all accounts or factory resetting the device.
  - **Active Admin Persistence**: In AOSP, clearing Device Owner does not automatically deactivate the Device Administrator component; `dpm.removeActiveAdmin(adminComponent)` must also be called.
  - **Orphaned Restrictions Danger**: If `clearDeviceOwnerApp` is called *before* all suspended packages are restored via `dpm.setPackagesSuspended(admin, packages, false)`, the application loses owner authority immediately and becomes permanently incapable of unsuspending them. Those apps remain permanently disabled until a factory reset.
  - **Enterprise / OEM Constraints**: Devices provisioned under Zero-Touch or Samsung Knox with mandatory management locks may disallow `clearDeviceOwnerApp()` at the OS level. If the platform forbids programmatic teardown, the system must detect this and provide clear instructions rather than falsely reporting success.

#### 2. Lifecycle Boundary Distinctions
The architecture must strictly distinguish these 6 distinct operations:
1. **Device Owner Policy Cleanup:** Restoring suspended packages (`setPackagesSuspended(false)`), clearing user restrictions, and verifying restoration before dropping authority.
2. **App-Managed Data Cleanup:** Wiping local policy cache, command history, and encrypted tokens in `SecureStore`.
3. **Device Unenrollment:** Server-side revocation of device credentials, unlinking device from `family_id`, and updating backend registry to `unmanaged`/`standard`.
4. **Device Owner Removal:** Programmatic invocation of `clearDeviceOwnerApp()` and deactivation of active admin.
5. **Factory Reset:** Complete OS-level wipe; strictly relegated to fallback/recovery when non-destructive exit is blocked by OEM or physical damage.
6. **Device Transfer / Re-pairing:** Transitioning device to a new family or child account without re-provisioning DO if still valid.

#### 3. Mandatory 12-Step Safe Exit Protocol (Future Implementation Specification)
When implemented, the in-app safe exit flow must execute in this exact sequence:
1. **Parent Authorization:** Initiated only by an authenticated parent via Parent UI or parent-signed one-time exit token (prevents child from unilaterally bypassing protection).
2. **Child-Device Visibility:** Child UI displays an unenrollment progress screen informing the child that management is ending.
3. **Server-Side Authorization:** Backend validates parent permissions via authenticated RPC (`private.authorize_device_exit`), revokes pending commands, and issues a cryptographically verified exit command.
4. **Revocation of Active Commands:** Outstanding `apply_policy` and telemetry tasks are cancelled.
5. **Restoration of App Restrictions:** `PolicyApplier.restoreAll()` executes `dpm.setPackagesSuspended(admin, packages, false)` for all tracked packages.
6. **Verification Post-Check:** `PolicyApplier` loops through all packages querying `dpm.isPackageSuspended()`. Exit is aborted/halted if any app remains suspended.
7. **Neutralization of Policies:** Local policy store is cleared; all policy locks are reset.
8. **Programmatic Device Owner Removal:** App calls `dpm.clearDeviceOwnerApp(context.packageName)`. Once cleared, calls `dpm.removeActiveAdmin(adminComponent)`.
9. **Credential & State Cleanup:** `SecureStore.clearConfig()` wipes installation secret, device tokens, and device credentials.
10. **Server-Side Transition to Standard:** Device sends final unmanaged status update; backend marks device `enforcement_mode = 'none'`.
11. **Interruption Recovery:** If network drops or battery dies during steps 1–7, the exit sequence is idempotent; the app restarts in exit-recovery mode and completes restoration before clearing ownership.
12. **Honest Failure Handling:** If `clearDeviceOwnerApp()` throws `SecurityException` or is blocked by OEM, the app refuses to claim exit succeeded and informs the parent that manual OEM settings action or factory reset is required.

---

## 11. DEC-12 dependencies (exact answers to the five questions asked)

### 11.1 Which screen-time features can operate in Standard mode?

| Feature | Standard mode | Evidence |
|---|---|---|
| Usage **measurement** and daily totals | YES (reporting only) | `UsageReporter.kt` contains no block/suspend/enforce/limit reference (grep); `usage_daily` uploads on the 60-min timer (`GuardianService.kt:43`, `:426-429`) |
| Daily screen-time **limit enforcement** (device locks up at quota) | **NO — not implemented in any mode** | `PolicyJson.kt:16` parses the field; no `setBusyTime`/`setMaximumTimeToLock`/Digital-Wellbeing call exists (§4 #4) |
| Bedtime **device lock** | **NO** | `PolicyApplier.kt:369-370` — informational flag only |
| Bedtime **app windows** (block specific apps during a window) | YES **in principle**, but only via per-app rules, and the suspension itself needs DO | `PolicyModels.kt:24-35` (`PolicyAppRule.windows`), `:67-76` |
| Location / safe zones / alerts / remote assist | YES (ordinary permissions) | `GuardianService.kt:499-509`, `LocationTrackingService`, `AndroidManifest.xml:84-93` |

So: **every limit that is a number of minutes is currently a measurement, not an enforcement** — in Standard *and* in Managed mode. DEC-13 does not unlock screen-time limits; a separate implementation (not this pass) would have to.

### 11.2 Which enforcement actions require Device Owner?

- App suspension and app restoration — `PolicyApplier.kt:302`, `:315`; the non-DO branch refuses at `:116-124`.
- Anything on the §4 #6 list the product might later want (uninstall block, keyguard, camera disable, install restriction, wipe).
- **Not** Device Owner: policy delivery, ack, heartbeats, usage/location upload, alerts, pairing, session signalling.

### 11.3 What the app must report when Device Owner is absent

It already has the vocabulary, and DEC-12 should keep it:

- ack: `enforcement_supported = false`, `desired_count`/`applied_count`/`failed_count` preserved, errors carry the literal `"Device Owner provisioning is required to suspend apps on this device. No apps were suspended."` (`PolicyApplier.kt:116-124`, `:171-173`, `:363-379`)
- server: `enforcement_status = 'unsupported'`, `last_error = 'device_owner_required'`, and `devices.policy_version` **advances** on that path (`enforcement.ts:83-89` + `handler.ts:401-412`)
- UI: neutral tone, never green (`device_presentation.dart:58-69`), plus the explicit unsupported message (`policy_enforcement.dart:81-82`)

### 11.4 Can the backend distinguish Standard vs Managed reliably today?

**Structurally yes; evidentially no.**

- It *stores* the distinction (`core.sql:100-101`; column confirmed live in Phase 9) and only service-role code writes it (RLS: SELECT-only for `authenticated`, `rls.sql:68-72`).
- But the value is **device-self-reported** and only enum-validated (`device-telemetry/index.ts:89-95`), there is no attestation, and there is **no capability/feature-support contract** beyond mode + 6 booleans (§4 #11).
- Production distribution shows the field is not decision-grade: the two `device_owner` devices are both **revoked** and the two **active** devices are `device_admin` (VERIFIED HOSTED, Phase 9) — i.e. the `device_owner` values in the table have never corresponded to a working managed deployment in this dataset.
- And `device_admin` currently means "label only" (§3.4), so a query for "managed" (`mode != 'none'`) would over-count. The reliable predicate today is `mode = 'device_owner'`, nothing looser.

### 11.5 What must be fixed before the parent UI can truthfully show `enforced`

Blocking list, in dependency order:

1. **Deployed logic must match repository logic.** `enforcement.ts`/`handler.ts` mapping is unproven on hosted; nothing has been deployed since 2026-10-27T18:07:08Z and 0/17 hosted acks carry counters. Requires **DEC-02**.
2. **Empty-target case must not read as enforced.** The current repo rule yields `enforced` for a limits-only policy on a DO device (`enforcement.ts:124-129`, since `targetsApps=false` skips the `:104-112` guard) even though nothing on the device enforces limits (§11.1). Also, uninstalled/protected targets never enter the failure denominator (`PolicyApplier.kt:84-87`), so `desired_count = 0` looks clean. **DEC-12 scope.**
3. **Historical rows.** The hosted `enforced` row `d4a05b68-eff2-4dca-a794-86ced2565a48` is a limits-only policy with empty `blocked_packages`/`app_rules` — it would be `unsupported`/`pending` under the new rule and needs an owner ruling on backfill vs annotation. **DEC-12 scope.**
4. **Attribution must stay explicit.** `PolicyReportCorrelation` (matched/uncorrelated/mismatched) must be honoured by the UI so an unlinked ack can never colour a policy green (`policy_enforcement.dart:109-133`).
5. **Lost-ack path.** A command is marked handled before the ack is sent and never retried (`GuardianService.kt:377`, `:475-480`); the parent then sees a permanently `pending` row. This is a truthful-but-stuck state and must be fixed (or explicitly accepted) before `enforced` is presented as the goal.
6. **Device evidence.** None of the above can be *demonstrated* without DEC-03.

**DEC-12 was not implemented in this pass, and no production enforcement status was modified.**

---

## 12. Acceptance criteria for the owner's DEC-13 choice

| AC | Criterion | Gate |
|---|---|---|
| **AC-13-1** | The chosen option (A / B / C) is named in writing by the owner and recorded in the register as APPROVED with its option letter. | owner |
| **AC-13-2** | Product copy, in-app banners and the marketing feature list state the same per-mode capability matrix; no screen promises suspension without `device_owner`. | DEC-03 verification |
| **AC-13-3** | If B or C is chosen: a **supported** provisioning channel exists (QR/AFW or EMM), reproducible by a non-engineer, verified on at least one dedicated device. | implementation + DEC-03 |
| **AC-13-4** | If B or C is chosen: a **supported, non-destructive exit** exists (owner release path or documented, tested procedure) before any family is enrolled. | implementation + DEC-03 |
| **AC-13-5** | Release signing is durable: `android/key.properties` + keystore exist, the release artefact's certificate digest is recorded, and no shipped build is debug-signed. | build/deploy window |
| **AC-13-6** | Device Administrator is either given real policy content or removed from the user-facing ladder — no mode that changes a label and nothing else. | owner + implementation |
| **AC-13-7** | The three copies of the mode rule (Kotlin, Dart heartbeat, server enum) are pinned by one shared fixture test. | implementation |
| **AC-13-8** | The capability contract carries reason codes and a supported-feature list, not only `enforcement_mode` + 6 booleans. | implementation + DEC-02 (schema) |
| **AC-13-9** | Loss of Device Owner is detected and re-reported within one heartbeat interval, and suspensions are proven restored or explicitly reported as unrestorable. | DEC-03 |
| **AC-13-10** | A child-visible management status exists on every screen that is affected by mode, matching `child_shell_controller.dart:126-135`. | implementation |
| **AC-13-11** | Nothing in the chosen design bypasses Android's consent or security model, suppresses a system indicator, or acquires Device Owner without a deliberate human ceremony. | design review |
| **AC-13-12** | All 75 QA rows relevant to suspension/restoration/reboot are executed and recorded before the managed tier is called "supported". | **DEC-03** |

---

## 13. Rollback and failure handling

| Failure | Current behaviour | Gap / risk |
|---|---|---|
| Provisioning attempt fails (B/C) | **N/A** — no provisioning exists; device stays `none` | Once B/C is chosen, the fallback must be "remain Standard and say so", never "assume managed" |
| App is not Device Owner but policy has targets | Honest: `unsupported` + `device_owner_required` (`PolicyApplier.kt:116-124` → `enforcement.ts:83-89`) | None in repo code; **unproven deployed** (§4 #13) |
| Suspension call throws | Recorded as an error; `isSuspended` re-verification marks per-package failures (`PolicyApplier.kt:144-160`, `:299-311`) | `isSuspended` swallows *all* exceptions → `false` (`:279-281`), so a transient DPM fault reads as "not suspended". Acceptable direction (understates enforcement), noted |
| Exception anywhere in apply | Counts withheld (`countsKnown=false`, `:179-189`) → server keeps `pending` | Correct-by-design |
| Ack delivery fails | Command already marked handled (`:475`), ack failure only `recordError` (`:478-480`), dedupe at `:377` blocks re-run | **Silent enforcement loss** — parent sees permanent `pending` |
| Device Owner removed externally | Mode recomputes to `none`/`device_admin` next tick; the lost-owner branch errors if a stale list exists (`:134-142`) | `restoreAll()` (`:244-269`) treats everything as already restored when not owner and **clears local state** (`:253`) — whether the OS did the same is UNKNOWN |
| Child uninstalls the app while Device Owner | OS prevents uninstall of a Device Owner app; no `setUninstallBlocked` needed or present | The family's only exit is factory reset (`docs/device-owner-provisioning.md:724`) — the dominant product risk |
| Reboot (Android 15+) | `BootReceiver` refuses to start `dataSync` FGS and stores an explanatory error (`:31-37`) | Enforcement silently off until someone opens the app; no scheduler fallback exists |
| OEM task-kill | `START_STICKY` only; no `onTaskRemoved` in `GuardianService` | Same as above; matches Phase 8 LIFE-04/LIFE-05 concerns, both NOT RUN |
| Rollback of a bad policy | `apply_policy_version` is atomic and versioned (`functions.sql:721-733`); the server advances `devices.policy_version` only on `enforced`/`unsupported` (`handler.ts:401-412`); a new policy restores the diff (`PolicyApplier.kt:126-133`) | **Best-supported failure path in the design** — but requires DO to restore anything |
| Full rollback of the managed tier | No in-app removal | **Factory reset** |

---

## 14. Owner Approval Recorded & Remaining Implementation Gates

On 2026-11-05 (Phase 9.2), the owner explicitly approved **DEC-13** with the following binding rulings:

1. **Architecture:** **OPTION B (Managed Mode Required for Full Enforcement)** is approved. Standard Mode is the baseline for monitoring; Managed Mode via Device Owner is required for app suspension.
2. **Safe Exit Policy:** **MANDATORY NON-DESTRUCTIVE IN-APP EXIT (RELEASE BLOCKER).** Factory reset must not be the only supported consumer exit mechanism. Safe programmatic teardown protocol (§10.1) must be implemented and verified before Managed Mode can be released.
3. **Device Administrator Disposition:** **RETIRED.** The Device Administrator label and receiver are retired completely from the product ladder.
4. **Release Signing Keystore:** **DEFERRED.** Creation of the release keystore requires separate future owner authorization.
5. **Implementation Scope:** This decision authorizes documentation updates only. It does **NOT** authorize APK builds, ADB commands, device testing, provisioning, hosted migrations, Edge Function deployments, or Phase 10 work.

### Remaining Implementation Gates (Pre-Release)
- **GATE-EXIT-01:** Design, build, and hardware-verify the 12-step safe in-app un-provisioning flow (§10.1).
- **GATE-KEY-01:** Owner authorization and execution of durable release signing keystore creation (`android/key.properties`).
- **GATE-PROV-01:** Implement a legitimate, user-visible Android provisioning channel (QR / NFC / Zero-touch).
- **GATE-DA-01:** Clean up retired Device Admin declarations in manifest, controller, and UI.
- **DEC-03:** Execute the 75 physical Android QA hardware matrix rows once device authorization is granted.

---

**DEC-13 is APPROVED (Option B). DEC-12 remains PROPOSED. No implementation, device provisioning, APK build, ADB operation, hosted mutation or deployment was performed.**
