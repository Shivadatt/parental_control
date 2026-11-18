# PHASE 3.0 — MASTER FUNCTIONAL TEST CASE CATALOG

**Project:** `D:\parentcontrol_app`  
**Package:** `com.parentcontrol.parent_control`  
**Target Backend:** Supabase Project `hhqgreaoqulmfwfwarhc`  
**Execution Mode:** STRICT READ-ONLY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. TEST EXECUTION CATEGORIES

1. **Automated Unit Tests (AUT):** Fast offline unit tests in Dart, Kotlin, and Deno.
2. **Widget / UI Tests (WGT):** Flutter widget rendering and navigation tests.
3. **Backend Integration Tests (BIT):** Deno Edge Function and Postgres RPC tests.
4. **Physical Device Tests (PDT):** Real hardware tests on Realme RMX2161 (Android 12).
5. **Emulator Tests (EMT):** Parent dashboard tests on Pixel 9a Emulator.
6. **Security & Privacy Tests (SPT):** Cross-family, credential isolation, and role boundary audits.
7. **Manual Consent Tests (MCT):** Audio and pairing approvals requiring explicit child tap.
8. **Destructive Tests (DST):** Account deletion, unlinking, and factory resets (Requires separate authorization).

---

## 2. MASTER TEST CASE CATALOG

| Test Case ID | Category | Module | Feature Under Test | Preconditions | Test Steps | Expected Result | Device | Status |
|---|---|---|---|---|---|---|---|---|
| **TC-001** | AUT | Mod A: Foundation | Dependency Injection Bootstrap | Cold app startup | Execute `RepositoryBinding.dependencies()` | All repositories, services, and API clients registered in GetX | All | **PASS** |
| **TC-002** | PDT | Mod A: Foundation | Single Engine UI Recreation | Child app running | Rotate screen / swipe to background | UI detaches and re-attaches without destroying cached engine | Realme | **PASS** |
| **TC-003** | AUT | Mod A: Foundation | Deep Link Filter Parsing | Valid & invalid intent URIs | Call `MainActivity.isAuthCallback` | Accepts only `parentcontrol://auth-callback` with code or token | All | **PASS** |
| **TC-004** | PDT | Mod A: Foundation | Role Selection Persistence | First app launch | Select "Parent Mode", restart app | Choice persisted in SharedPreferences; displays "Last choice on this device" | Realme | **PASS** |
| **TC-005** | AUT | Mod B: Auth | Password Validation Rules | Various password strings | Run `Validators.password` | Requires >=8 chars, uppercase, lowercase, number; rejects weak | All | **PASS** |
| **TC-006** | EMT | Mod B: Auth | Parent Sign-In | Account `ankit@gmail.com` | Enter credentials, tap "Sign in" | Successfully signs in, restores session, routes to `/parent` | Pixel 9a | **PASS** |
| **TC-007** | PDT | Mod B: Auth | Child Sign-In | Account `ankit1@gmail.com` | Enter credentials, tap "Sign in" | Successfully signs in, restores session, routes to `/child` | Realme | **PASS** |
| **TC-008** | PDT | Mod B: Auth | Unverified Email Redirection | New unverified account | Sign in before email confirmation | Routed to `/auth/verify-email`; dashboard routes blocked | Realme | **PASS** |
| **TC-009** | PDT | Mod B: Auth | Resend Verification Email | On verify email screen | Tap "Resend email" | Calls Supabase Auth resend; shows confirmation banner | Realme | **PASS** |
| **TC-010** | EMT | Mod B: Auth | Parent Sign-Out | Signed in on Pixel 9a | Tap Settings -> "Sign out" | Auth session destroyed locally and remotely; routes to login | Pixel 9a | **PASS** |
| **TC-011** | BIT | Mod C: Family | Family Creation via Bootstrap | Authenticated parent JWT | Invoke `auth-bootstrap` (`create_family`) | Family inserted with caller as owner; member row created | Server | **PASS** |
| **TC-012** | PDT | Mod C: Family | Child ID Generation | Enrolled child account | Open `/child/enrollment` | Generates canonical format `PC-XXXXXX` from database | Realme | **PASS** |
| **TC-013** | BIT | Mod C: Family | Pairing Code Expiration (15m) | Active pairing token | Check token timestamp > 15 mins | Token expired; redemption fails closed with 410 Gone | Server | **PASS** |
| **TC-014** | MCT | Mod C: Family | Child Pairing Request Approval | Pending pairing invite | Tap "Approve" on `/child/requests` | Family membership status changes to active; device linked | Realme | **PASS** |
| **TC-015** | DST | Mod C: Family | Unlink Child Member | Active family link | Parent invokes `unlink` | Membership set to removed; device revoked (Auth required) | Pixel 9a | **NOT TESTED — AUTH REQ** |
| **TC-016** | AUT | Mod D: Device | Keystore Secret Generation | Native Android environment | Run `SecureStore.deviceSecret()` | Generates 32-byte secret; persists via EncryptedSharedPreferences | Realme | **PASS** |
| **TC-017** | BIT | Mod D: Device | Constant-Time HMAC Auth | Valid & invalid secrets | Call `_shared/auth.ts` `requireDevice` | Valid secret authenticates; invalid secret returns 401 | Server | **PASS** |
| **TC-018** | PDT | Mod D: Device | Battery Telemetry Reporting | Child app in foreground | Inspect `devices` row | Battery level (e.g. 100%) and charging state update accurately | Realme | **PASS** |
| **TC-019** | DST | Mod D: Device | Device Revocation | Active paired device | Parent taps "Revoke device" | `credential_revoked_at` set; subsequent device calls 401 | Pixel 9a | **NOT TESTED — AUTH REQ** |
| **TC-020** | DST | Mod D: Device | Device Recovery RPC | Desynced Keystore secret | Parent triggers recovery | Backend generates recovery nonce to re-link device | Server | **NOT TESTED — AUTH REQ** |
| **TC-021** | EMT | Mod E: Dashboard | Parent Family Metrics Display | Enrolled family `demo` | Open `/parent` Tab 0 | Displays family name, child card, battery, and screentime | Pixel 9a | **PASS** |
| **TC-022** | EMT | Mod E: Dashboard | Online / Offline Indicator | Disconnect child device | Observe child card | Changes to "Offline" once heartbeat exceeds 5 minutes | Pixel 9a | **PASS** |
| **TC-023** | PDT | Mod F: Child Shell | Guardian Service Card Display | Child app on Realme | Open `/child` Tab 0 | Shows "Guardian Service Running" with active policy version | Realme | **PASS** |
| **TC-024** | PDT | Mod F: Child Shell | Permission Status Tiles | All permissions granted | Open `/child` Tab 0 | Tiles display green checkmarks for Location, Usage, Notifs | Realme | **PASS** |
| **TC-025** | EMT | Mod G: Screen Time | Daily Quota Schedule Update | Pixel 9a Parent App | Set quota to 120 mins; tap Save | Enqueues `apply_policy` command with incremented version | Pixel 9a | **PASS** |
| **TC-026** | AUT | Mod G: Screen Time | Local Quota Evaluator | Daily limit reached | Run Kotlin `QuotaEvaluator` | Correctly signals quota exhaustion without network call | Android | **PASS** |
| **TC-027** | PDT | Mod G: Screen Time | Advisory Mode Fallback | Non-DO physical device | Receive `apply_policy` command | Returns `appliedCount = 0, supported = false`; UI shows Advisory | Realme | **PASS** |
| **TC-028** | PDT | Mod H: App Restr | Query Installed Packages | Child app on Realme | Open App Restrictions | Returns non-system apps (Chrome, YouTube, etc.) | Realme | **PASS** |
| **TC-029** | BLK | Mod H: App Restr | Hard App Suspension (`setPackagesSuspended`) | Physical Realme device | Enforce app restriction | Blocked: device is not Device Owner; cannot suspend package | Realme | **BLOCKED (Non-DO)** |
| **TC-030** | BIT | Mod I: Assistance | Assistance Request Creation | Active family membership | Call `remote-session` (`request`) | Session row inserted in `pending_child` state; sweeps expired | Server | **PASS** |
| **TC-031** | MCT | Mod I: Assistance | Child Audio Explicit Consent | Assistance requested | Present `MediaSelfTestSheet` | Audio capture begins ONLY after child manually allows consent | Realme | **PASS** |
| **TC-032** | AUT | Mod I: Assistance | Receive-Only Audio Enforcement | Parent session controller | Inspect WebRTC peer options | `offerToReceiveAudio: true`, audio track publication disabled | All | **PASS** |
| **TC-033** | BIT | Mod I: Assistance | STUN / TURN Credential Lease | Valid assistance session | Invoke `remote-session` (`ice`) | Returns short-lived ICE credentials; secret never leaked | Server | **PASS** |
| **TC-034** | PDT | Mod J: Location | Foreground GPS Location Fix | Location permission granted | Call `getLastKnownLocation` | Returns valid latitude, longitude, accuracy, and timestamp | Realme | **PASS** |
| **TC-035** | EMT | Mod J: Location | Safe Zone Creation | Pixel 9a Parent App | Enter name, radius (200m), save | Zone inserted into `safe_zones` table; shows on map | Pixel 9a | **PASS** |
| **TC-036** | BIT | Mod J: Location | Atomic Safe Zone Delete | Existing safe zone ID | Call `family-admin` (`delete_zone`) | Atomically deletes zone and records audit entry via RPC | Server | **PASS** |
| **TC-037** | EMT | Mod K: Alerts | Low Battery Alert Display | Device battery < 15% | Inspect Parent Alerts tab | Displays "Low Battery Alert" card with timestamp | Pixel 9a | **PASS** |
| **TC-038** | EMT | Mod K: Alerts | Alert Parent Acknowledgement | Active safety alert | Tap "Acknowledge" button | Row updated with `acknowledged_at` and `acknowledged_by` | Pixel 9a | **PASS** |
| **TC-039** | AUT | Mod K: Alerts | Realtime WebSocket Auto-Reconnect | WebSocket dropped | Resume app (`WidgetsBindingObserver`) | Triggers exponential backoff reconnect up to 3 attempts | All | **PASS** |
| **TC-040** | BIT | Mod L: Settings | Retention Report Window Data | Parent caller JWT | Invoke `account` (`retention_report`) | Returns 30-day location and 90-day usage retention windows | Server | **PASS (Local)** |
| **TC-041** | BIT | Mod L: Settings | GDPR Account Data Export | Valid user JWT | Invoke `account` (`export`) | Returns scoped JSON attachment capped at 20,000 rows | Server | **PASS (Local)** |
| **TC-042** | DST | Mod L: Settings | Cascading Account Deletion | Empty owned family | Invoke `account` (`delete_account`) | Requires `confirm: "DELETE"`; cascades removal safely | Server | **NOT TESTED — AUTH REQ** |
| **TC-043** | EMT | Mod M: Audit | Append-Only Audit Trail View | Family `demo` | Open `/parent/audit` | Displays chronologically ordered, immutable audit entries | Pixel 9a | **PASS** |
| **TC-044** | BIT | Mod M: Audit | Audit Log UPDATE Prevention | Attempt SQL UPDATE | Execute `UPDATE audit_logs ...` | Database trigger throws exception; rejects modification | Server | **PASS** |
| **TC-045** | SPT | Mod Q: Security | Cross-Family Isolation Test | User A in Family A | Query Family B records | RLS policies return 0 rows; cross-family leakage prevented | Server | **PASS** |
| **TC-046** | SPT | Mod Q: Security | Child Family Deletion Protection | Child JWT token | Attempt `delete_family` | Server rejects with 403 Forbidden; child cannot delete family | Server | **PASS** |
