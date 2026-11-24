# 10 — Test Safety and Prerequisite Register

**Document ID:** `HAVEN-GAP-010`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Risk Classification, Test Environment Isolation, Destructive Test Quarantine & Execution Prerequisites  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Safety Governance & Risk Principles

Manual testing of a parental control application carries inherent operational risks:
1. **Physical Device Lockout**: Testing screen time lockouts (`USE08`), bedtime curfews (`USE06`), or app suspension (`APP07`) can render a physical test device inaccessible if the tester lacks administrative override credentials.
2. **Account & Family Destruction**: Testing account deletion (`A09`), device unlinking (`FAM10`), or device revocation (`FAM12`) destroys persistent records and breaks family associations.
3. **Database State Pollution**: Executing audit purges (`AUD03`) or cross-tenant queries (`SEC01`) against a production environment could lead to accidental data loss or privacy violations.

To guarantee zero unintended disruption, every test case across the baseline and expansion suites has been classified into a strict **6-tier safety taxonomy**, and all high-risk tests have been placed under formal **Quarantine Protocols**.

---

## 2. Six-Tier Test Safety Taxonomy

```
+----------------------------------------------------------------------------------------------------+
|                                    TEST SAFETY CLASSIFICATION MAP                                  |
|                                                                                                    |
|  [TIER 1: SAFE]                     (38 Tests / 44.7%) - Read-only UI, navigation, inspection      |
|  [TIER 2: SAFE_REVERSIBLE]          (24 Tests / 28.2%) - Config mutations with documented teardown |
|  [TIER 3: REQUIRES_DISPOSABLE_ACCT] ( 6 Tests /  7.1%) - Irreversible user account mutation       |
|  [TIER 4: REQUIRES_DISPOSABLE_DEV]  ( 7 Tests /  8.2%) - Device enrollment, unlinking, revocation  |
|  [TIER 5: REQUIRES_ISOLATED_BACK]   ( 5 Tests /  5.9%) - Direct DB execution, RLS, token replay    |
|  [TIER 6: SPECIALIST_TEST]          ( 5 Tests /  5.9%) - Hardware WebRTC, GPS mock, ADB DO rights  |
+----------------------------------------------------------------------------------------------------+
```

### 2.1 Detailed Tier Definitions & Guardrails

#### Tier 1: `SAFE` (Non-Mutating / Read-Only UI)
- **Characteristics**: Exercises read-only views, list scrolling, navigation tabs, search filters, form validation helper labels, or app version displays.
- **State Impact**: Absolutely zero persistent state modified in local storage or remote database.
- **Environment**: Can be safely executed on any environment, including staging or production-like environments.
- **Representative Tests**: `TC-MON01` (Dashboard), `TC-LOC01` (Map view), `TC-AUD01` (Audit viewer), `TC-EXP-11` (Form validation), `TC-EXP-34` (App search).

#### Tier 2: `SAFE_REVERSIBLE` (State Mutation with Teardown)
- **Characteristics**: Modifies application settings, creates temporary safe zones, or toggles app blocking rules, but provides an explicit teardown procedure to restore baseline state.
- **State Impact**: Modifies database rows temporarily; completely reversed during test cleanup.
- **Environment**: Standard test environment with dedicated test family.
- **Representative Tests**: `TC-APP01` (Block/unblock app), `TC-LOC05` (Add/delete safe zone), `TC-EXP-10` (Update display name), `TC-EXP-46` (Update retention days).

#### Tier 3: `REQUIRES_DISPOSABLE_ACCOUNT` (Account Destruction / Danger Zone)
- **Characteristics**: Irreversibly alters or destroys user authentication accounts, GDPR export triggers, or permanent role assignments.
- **State Impact**: User profile, family association, or auth records are destroyed or irreversibly mutated.
- **Environment**: Requires dedicated disposable test email accounts (e.g. `disposable_test_parent_01@haven.test`). **NEVER execute using personal or primary developer accounts.**
- **Representative Tests**: `TC-A09` (Account deletion cascade), `TC-A08` / `TC-EXP-04` (GDPR data export), `TC-EXP-01` (Permanent role selection binding).

#### Tier 4: `REQUIRES_DISPOSABLE_DEVICE` (Hardware Enrollment & Revocation)
- **Characteristics**: Binds or revokes hardware identities in Android Keystore, enrolls device into family groups, or unlinks devices.
- **State Impact**: Device pairing credentials invalidated; child client reset to welcome screen.
- **Environment**: Requires dedicated physical test Android phones or disposable Android Emulators. **NEVER execute on personal daily-driver smartphones.**
- **Representative Tests**: `TC-FAM01` / `TC-FAM02` (Device pairing), `TC-FAM10` (Device unlinking), `TC-EXP-17` (Device revocation), `TC-SET05` (Device Admin grant).

#### Tier 5: `REQUIRES_ISOLATED_BACKEND` (Database Maintenance & Security Boundaries)
- **Characteristics**: Interacts directly with database RPCs, triggers audit retention purges, exercises cross-tenant RLS queries, or replays redemption tokens.
- **State Impact**: Deletes historical database records or tests adversary authorization boundaries.
- **Environment**: Requires an isolated Staging/Sandbox Supabase instance. **PROHIBITED on production databases.**
- **Representative Tests**: `TC-SEC01` (Cross-Family RLS Tenant Boundary), `TC-SEC02` (Token Replay Attack), `TC-EXP-18` (Device Re-Credentialing), `TC-EXP-47` (Manual Audit Purge), `TC-EXP-48` (Retention Sweep SQL).

#### Tier 6: `SPECIALIST_TEST` (Hardware Enclaves & Advanced Native Capabilities)
- **Characteristics**: Requires physical camera/microphone hardware, mock GPS location injection, or ADB shell access to provision Device Owner mode.
- **State Impact**: Interacts with physical sensors and Android Linux security subsystems.
- **Environment**: Dedicated hardware test bench with ADB developer tools connected.
- **Representative Tests**: `TC-APP07` (Device Owner app suspension), `TC-EXP-08` (WebRTC two-way streaming), `TC-EXP-37` (Continuous background GPS tracking), `TC-EXP-45` (In-call media controls).

---

## 3. High-Risk & Destructive Test Quarantine Protocols

The following 6 test procedures represent high-impact actions and must only be executed within an authorized quarantine window:

### Quarantine Gate 1: Account Deletion (`TC-A09`)
- **Quarantine Standard**: Must be scheduled as the **FINAL test** for that test account.
- **Pre-Execution Check**: Ensure no active child devices or other parent test accounts depend on this family ID.
- **Teardown**: Account is permanently purged. Tester must discard credentials.

### Quarantine Gate 2: Child Device Unlinking (`TC-FAM10`)
- **Quarantine Standard**: Clears child device association. Child app resets to enrollment.
- **Pre-Execution Check**: Complete all screen time, app blocking, and monitoring tests for this child device before unlinking.
- **Teardown**: Re-enroll device via `TC-FAM01` or `TC-FAM02` if further testing is required.

### Quarantine Gate 3: Cryptographic Device Revocation (`TC-EXP-17`)
- **Quarantine Standard**: Changes device status to `revoked` in database and invalidates Keystore tokens.
- **Pre-Execution Check**: Complete all telemetry and remote assistance tests before triggering revocation.
- **Teardown**: Device cannot be un-revoked without re-credentialing (`TC-EXP-18`) or full re-pairing.

### Quarantine Gate 4: On-Demand Historical Audit Purge (`TC-EXP-47`)
- **Quarantine Standard**: Deletes audit logs older than retention threshold.
- **Pre-Execution Check**: Must only be executed against a staging database with seeded historical test logs.
- **Teardown**: Database logs older than threshold are permanently gone; re-seed if necessary.

### Quarantine Gate 5: Cross-Family Multi-Tenant RLS Test (`TC-SEC01`)
- **Quarantine Standard**: Requires two separate families (Family A and Family B) seeded in database.
- **Pre-Execution Check**: Parent A attempts to read Family B device rows.
- **Teardown**: None (read-only verification of HTTP 403 / empty set).

### Quarantine Gate 6: Staged Credential Replay Test (`TC-SEC02`)
- **Quarantine Standard**: Requires intercepting network payload and replaying against backend.
- **Pre-Execution Check**: Must be executed against staging edge functions.
- **Teardown**: None (replayed request must fail with HTTP 400/409).

---

## 4. Pre-Test Hardware, Account & Environment Checklist

Before beginning any manual testing execution, the QA lead and owner must complete this checklist:

```
[ ] 1. BACKEND ISOLATION:
       [ ] Staging Supabase project URL configured.
       [ ] Production database connection strings completely removed from test configs.
       [ ] Supabase Edge Functions deployed to staging environment.

[ ] 2. TEST ACCOUNTS PROVISIONED:
       [ ] 2x Dedicated Disposable Parent Accounts (e.g. parent1@haven.test, parent2@haven.test).
       [ ] 2x Unregistered Test Emails (for registration and form validation tests).
       [ ] Known test passwords adhering to complexity rules.

[ ] 3. PHYSICAL TEST HARDWARE:
       [ ] Parent Device: Android smartphone (Android 10+) or tablet running Parent mode.
       [ ] Child Device A: Android smartphone (Android 10+) dedicated for Child mode.
       [ ] Child Device B: Secondary Android phone or emulator (for multi-child testing).
       [ ] Both devices connected to active Wi-Fi with internet access.
       [ ] Workstation with Android SDK platform-tools (ADB) available for specialist tests.

[ ] 4. BASELINE BACKUP:
       [ ] Staging database snapshot taken prior to destructive test execution.
```

---

## 5. Safety Register Summary

By strictly adhering to these safety classifications, quarantine protocols, and prerequisites, manual testing can proceed with **zero risk to production systems, zero data leakage, and complete protection of physical test hardware**.
