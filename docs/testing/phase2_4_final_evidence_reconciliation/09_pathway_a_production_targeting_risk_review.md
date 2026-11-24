# Phase 2.4 — Pathway A: Production-Targeting Risk Reconciliation

**Document ID:** `HAVEN-GOV-PHASE2-4-PW-A`  
**Phase:** Phase 2.4 — Final Evidence Reconciliation & Governance Correction Audit  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Adversarial Static Infrastructure & Targeting Risk Audit  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Adversarial Rationale

Phase 2.2 asserted that **Pathway A (Provisioning a Dedicated Staging Supabase Project)** carries *"absolute zero risk to production data"*.

While provisioning a separate Supabase cloud project establishes strong database-level isolation, claiming "absolute zero risk" is engineering hyperbole. This audit examines the concrete technical vectors through which staging activities could accidentally target, pollute, or disrupt the live production environment.

---

## 2. Technical Production-Targeting Risk Vectors

### 2.1 The Hardcoded Production Fallback in `lib/core/config/env.dart`
Source inspection of `lib/core/config/env.dart:15–25` reveals:
```dart
static const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hhqgreaoqulmfwfwarhc.supabase.co',
);
static const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '...',
);
```

#### Forensic Risk Analysis
- **Silent Production Fallback**: If a QA engineer or automated CI runner builds the app with a simple `flutter run` or `flutter build apk` (omitting `--dart-define=SUPABASE_URL=...`), **the app compiles cleanly and silently connects to production `hhqgreaoqulmfwfwarhc`**!
- **Targeting Hazard**: A tester believing they are executing destructive tests against staging would actually be executing against production.

### 2.2 Shared Developer Supabase CLI Workstation State
`docs/backend.md:327–332` records that the developer workstation's CLI login was linked to project `irlqctcddjmkwqdvsdsm`, while the app targeted production `hhqgreaoqulmfwfwarhc`.
- When a staging project is created, the developer's CLI must be explicitly re-linked via `supabase link --project-ref <staging-ref>`.
- If a developer accidentally runs `supabase db push` or `supabase functions deploy` while linked to production, **unverified test migrations or experimental functions are pushed directly to live production infrastructure**!

### 2.3 Shared Android Application Identity & Keystore Token Overwrite
Source inspection of `android/app/build.gradle` confirms:
- **Application ID**: Both staging and production builds use `applicationId "com.parentcontrol.parent_control"`. Zero build flavors (e.g. `.staging` or `.dev`) are configured.
- **Over-the-Top Install Hazard**: If a tester installs a staging build on a device containing a production account, Android OS replaces the APK while preserving app private data storage. The staging app will read the production device secret from Android Keystore (`SecureStore.kt`), send invalid tokens to staging, and trigger unexpected token revocations.

### 2.4 Deep Link & Intent Collisions
`android/app/src/main/AndroidManifest.xml:58` registers the intent filter:
```xml
<data android:scheme="parentcontrol" android:host="auth-callback" />
```
- Both staging and production builds register the identical URI scheme (`parentcontrol://auth-callback`).
- Email confirmation links clicked on a test device can be intercepted by the wrong app build.

### 2.5 Shared WebRTC STUN/TURN Ingress
Both environments share the public Google STUN server (`stun:stun.l.google.com:19302`) and the same co-turn server configurations in `turn.ts`, creating potential network signaling collisions if session IDs were ever duplicated.

---

## 3. Required Safeguards for Pathway A Feasibility

Before Pathway A can be safely utilized, the following technical safeguards must be implemented:
1. **Remove Default Production Fallback**: `env.dart` must be modified so that building without `--dart-define=SUPABASE_URL` results in a compilation failure or displays the `/configuration` screen, rather than silently defaulting to production.
2. **Configure Staging Build Flavor**: `android/app/build.gradle` should define a `staging` product flavor with `applicationIdSuffix ".staging"` to prevent APK overwrites on test phones.
3. **CLI Target Verification Protocol**: Mandatory pre-deployment checks (`supabase status`) before running any CLI migration command.

---

## 4. Pathway A Feasibility Verdict

```
====================================================================================================
                        PATHWAY A ADVERSARIAL FEASIBILITY VERDICT
====================================================================================================

               [ FEASIBLE WITH UNRESOLVED SAFEGUARDS ]

   1. Physical Database Isolation: VERIFIED (Independent cloud project isolates tables & auth).
   2. Absolute Zero Risk Claim: REFUTED (Silent env.dart fallback, CLI linking targets, and 
      shared Android package identity create measurable production-targeting hazards).
   3. Operational Feasibility: Sound, provided the 3 mandatory safeguards are implemented.

====================================================================================================
```
