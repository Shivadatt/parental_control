# 08 — Resolution of Findings REV-008 & REV-009: Native Notification Channels & Challenge Code UX

**Document ID:** HAVEN-COR-008  
**Target Findings:** REV-008 (MEDIUM) & REV-009 (MEDIUM)  
**Target Defects:** HAVEN-QA-004 (`DEF-604` / `MON05`) & HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Phase:** Phase 1.2 — Remediation Plan Correction & Closure (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** RESOLVED BY DESIGN CORRECTION  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Scope

This report resolves two technical usability and platform-accuracy findings:
1. **REV-008**: Incorporating notification channel importance checks on Android 8.0+ into native permission reporting (`HAVEN-QA-004`).
2. **REV-009**: Establishing Crockford Base32 encoding and entropy guarantees for the re-credentialing challenge code (`HAVEN-QA-003`).

---

## 2. Part 1: Resolution of Finding REV-008 (Notification Channel-Level Inspection)

### 2.1 The Android Channel Architecture
On Android 8.0 (API 26) and higher, the Android OS introduced Notification Channels.
- An application can have its master notification switch turned ON in system settings (`NotificationManagerCompat.areNotificationsEnabled() == true`), but an individual notification channel can be set to `IMPORTANCE_NONE` (blocked) by the user.
- In HAVEN Parent Control, `GuardianService.kt:70` creates and depends on a specific foreground service notification channel:
  `val CHANNEL_ID = "guardian_service_channel"`
- If a child navigates to `Settings → Apps → Parent Control → Notifications → Channels` and disables `guardian_service_channel`:
  - The foreground service notification cannot be posted.
  - On modern Android versions, running a data-sync foreground service without a visible notification can cause Android to aggressively kill the background process (`onTimeout`).
  - Yet `areNotificationsEnabled()` continues to return `true`, reporting false-positive permission health to the parent.

### 2.2 Corrected Multi-Tier Native Inspection Specification (`NativePermissions.kt`)
The native implementation in `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt` is updated to inspect all three platform tiers:

```mermaid
flowchart TD
    Start["hasNotifications(context)"] --> CheckMaster{"NotificationManagerCompat<br/>.areNotificationsEnabled()"}
    CheckMaster -- "FALSE" --> RetFalse["return false (Master Switch OFF)"]
    CheckMaster -- "TRUE" --> CheckSDK{"Build.VERSION.SDK_INT >= 26 (Android 8.0+)?"}
    
    CheckSDK -- "YES" --> CheckChannel{"Get Channel 'guardian_service_channel'<br/>Is importance == IMPORTANCE_NONE?"}
    CheckChannel -- "YES (Channel Blocked)" --> RetFalse2["return false (Channel Blocked)"]
    CheckChannel -- "NO (Channel Active)" --> CheckTiramisu{"Build.VERSION.SDK_INT >= 33 (Android 13+)?"}
    CheckSDK -- "NO (< API 26)" --> RetTrue["return true"]
    
    CheckTiramisu -- "YES" --> CheckRuntime{"granted(POST_NOTIFICATIONS)?"}
    CheckRuntime -- "NO" --> RetFalse3["return false (Runtime Denied)"]
    CheckRuntime -- "YES" --> RetTrue2["return true (Fully Granted)"]
    CheckTiramisu -- "NO (< API 33)" --> RetTrue3["return true (Fully Granted)"]
```

### 2.3 Comprehensive Notification State Model
To ensure complete transparency without breaking the wire contract (`capabilities.notifications_granted: Boolean`), the native bridge computes the boolean strictly:
```text
Boolean hasNotifications = (masterEnabled) && (guardianChannelActive) && (postNotificationsGranted);
```
- If master notifications are disabled $\rightarrow$ `false`
- If runtime `POST_NOTIFICATIONS` is denied (API 33+) $\rightarrow$ `false`
- If `guardian_service_channel` is blocked (API 26+) $\rightarrow$ `false`
- Otherwise $\rightarrow$ `true`

---

## 3. Part 2: Resolution of Finding REV-009 (Challenge Code UX & Crockford Base32)

### 3.1 The Mobile Usability Problem
The Phase 1 proposal recommended a standard 6-digit alphanumeric code.
- On soft mobile touchscreens, children and parents frequently confuse visually ambiguous characters:
  - `0` (digit zero) vs `O` (capital O) vs `o` (lowercase o)
  - `1` (digit one) vs `I` (capital I) vs `l` (lowercase L)
  - `5` (digit five) vs `S` (capital S)
  - `8` (digit eight) vs `B` (capital B)
- Because `rotate_device_secret` strictly locks after 5 failed attempts (REV-001), user transcription typos will accidentally exhaust the challenge, causing parent frustration.

### 3.2 Crockford's Base32 Specification
To achieve zero-transcription error usability while preserving strong cryptographic entropy, the system adopts **Crockford's Base32**:

1. **Alphabet (32 Characters)**:
   `0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T V W X Y Z`
2. **Excluded Ambiguous Characters**:
   - `I` (capital I) and `L` (capital L) are excluded (mapped to `1`).
   - `O` (capital O) is excluded (mapped to `0`).
   - `U` is excluded (omitted to avoid accidental formation of offensive words).
3. **Automatic Client Input Normalization**:
   When the child types or pastes the code, the input formatter automatically executes:
   ```text
   input = input.trim().toUpperCase()
     .replaceAll('O', '0')
     .replaceAll('I', '1')
     .replaceAll('L', '1')
   ```

### 3.3 Cryptographic Entropy & Threat Model Analysis
- **Code Length**: 6 characters.
- **Alphabet Size**: 32 characters.
- **Total Possible Codes**: $32^6 = 1,073,741,824 \approx 1.07 \times 10^9$ possibilities.
- **Bit Entropy**: $\log_2(32^6) = 30.0\text{ bits}$ of true cryptographic entropy.
- **Random Generation**: Generated via `crypto.getRandomValues()` in the Edge Function (Deno CSPRNG).

#### Brute-Force Mathematical Proof
- Maximum attempts permitted: $5$.
- Attack window: $10\text{ minutes}$.
- Probability of a successful random guess across all 5 attempts:
  $$P(\text{guess}) = \frac{5}{1,073,741,824} \approx 4.65 \times 10^{-9}$$
- **Conclusion**: The probability of guessing a valid challenge is less than 1 in 214 million. This exceeds banking and 2FA authentication standards while providing an effortless, mistake-proof UX for children and parents.

---

## 4. Verification Test Matrix for REV-008 & REV-009

| Test ID | Test Target | Input / Injected Fault | Expected System Outcome |
|---|---|---|---|
| `TEST-REV008-01` | Notification Channel Inspection | Master switch ON, `guardian_service_channel` set to `IMPORTANCE_NONE` on API 28 | `hasNotifications(context) == false` |
| `TEST-REV008-02` | Notification Master Switch | Master switch OFF, channel active on API 28 | `hasNotifications(context) == false` |
| `TEST-REV008-03` | Android 13+ Runtime Denial | Master switch ON, channel active, `POST_NOTIFICATIONS` denied on API 33 | `hasNotifications(context) == false` |
| `TEST-REV008-04` | Full Grant | Master switch ON, channel active, `POST_NOTIFICATIONS` granted on API 34 | `hasNotifications(context) == true` |
| `TEST-REV009-01` | Crockford Base32 Normalization | User types `"o1l8-ab"` | Normalized to `"0118AB"`; verified successfully. |
| `TEST-REV009-02` | Case Insensitivity | User types lowercase `"7k4x9m"` | Converted to uppercase `"7K4X9M"`; verified successfully. |
| `TEST-REV009-03` | Entropy Enforcement | Edge Function generates 10,000 challenge codes | All codes measure 6 chars in `[0-9A-HJKMNP-TV-Z]`; zero collision. |

---

## 5. Resolution Status

**RESOLVED BY DESIGN CORRECTION**. Incorporating channel importance checks prevents false-positive permission reporting on Android 8.0+, while Crockford's Base32 eliminates user transcription errors without degrading cryptographic entropy.
