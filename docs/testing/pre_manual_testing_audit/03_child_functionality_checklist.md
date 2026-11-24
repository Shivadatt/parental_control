# 03 — Child Functionality Checklist

**Document ID:** `HAVEN-INV-003`  
**Phase:** Phase 1.5 — Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Target Role:** Child Mode  
**Coverage:** 49 Total Accessible Functionalities (22 Child-Only + 17 Shared + 10 Interconnected)  

---

## 1. Overview & Verification Protocol

This document provides a comprehensive, step-by-step testing checklist for every capability accessible from the **Child role** in HAVEN Parent Control.

> [!IMPORTANT]
> **Pre-Testing State**: In accordance with the audit protocol, **all items are marked `[ ] NOT TESTED`**. No runtime tests have been executed. This checklist serves as the authoritative guide for the future authorized QA execution phase.

---

## 2. Child Testing Checklist by Screen & Module

### 2.1 Child Onboarding, Role Selection & Pairing
- [ ] **A06 — Set Child Role**: On `/role-selection`, enter child display name. Tap "Set child role". Assert `profiles.role` set to `'child'` and routes to child enrollment. Status: `IMPLEMENTED`.
- [ ] **FAM06 — View Child Linking Code & QR Code**: Navigate to `/child/enrollment`. Assert screen displays dynamic 6-digit text linking code and high-contrast QR code for parent scanning. Status: `IMPLEMENTED`.
- [ ] **FAM07 — Child Hardware Device Registration**: On enrollment screen, enter device name (e.g. "Alex Phone"). Complete enrollment. Assert 32-byte secret generated in KeyStore and row inserted into `devices`. Status: `IMPLEMENTED`.
- [ ] **FAM05 — Approve Inbound Parent Pairing Request**: Open Requests tab (`/child`). Find incoming pairing request from parent. Tap "Accept". Assert child links to family and routes to Child Home. Status: `IMPLEMENTED`.
- [ ] **FAM05 — Decline Inbound Parent Pairing Request**: On incoming pairing request, tap "Decline". Assert request marked `'declined'` and child remains unlinked. Status: `IMPLEMENTED`.
- [ ] **A12 — Enrollment Form Validation**: In device name field, enter empty string. Assert "Device name required" inline validation surfaces. Status: `IMPLEMENTED`.

### 2.2 Child Authentication & Session Management
- [ ] **A01 — Child Email/Password Sign-In**: Navigate to `/auth/login`. Enter child credentials. Tap "Sign In". Assert session created and routes to `/child`. Status: `IMPLEMENTED`.
- [ ] **A02 — Child Account Registration**: Navigate to `/auth/register`. Enter name, child email, password. Tap "Create Account". Assert account created. Status: `IMPLEMENTED`.
- [ ] **A03 — Child Email Verification**: On `/auth/verify-email`, verify email link click updates session state. Status: `IMPLEMENTED`.
- [ ] **A04 — Persisted Child Session Restoration**: Cold-launch app with existing child session. Assert app bypasses login and opens `/child` directly. Status: `IMPLEMENTED`.
- [ ] **A05 — Child Sign Out**: From Child Settings tab, tap "Sign out". Confirm prompt. Assert local cache cleared and routes to login. Status: `IMPLEMENTED`.
- [ ] **A11 — Password Input Masking**: Tap visibility toggle on password field. Assert text toggles between masked and visible. Status: `IMPLEMENTED`.

### 2.3 Child Home Tab & Protection Status
- [ ] **CHD01 — Child Home Status Overview**: Open Home tab (`/child`). Assert screen renders: (1) "Protection Active" shield banner, (2) Family name, (3) Assigned device name, (4) Active rules summary. Status: `IMPLEMENTED`.
- [ ] **CHD09 — Emergency Parent Quick-Call Action**: On Child Home tab, tap "Call Parent" button. Assert system phone dialer opens pre-populated with parent's registered phone number. Status: `IMPLEMENTED`.

### 2.4 Child Rules & Policy Oversight
- [ ] **CHD02 — View Applied Restrictions & Rules**: Open Rules tab (`/child`). Assert screen lists: (1) Currently blocked applications, (2) Daily screen time limit & remaining time, (3) Bedtime schedule hours. Status: `IMPLEMENTED`.
- [ ] **CHD06 — Verify Native Policy Enforcement Status**: On Rules tab, inspect app badges. Assert native bridge queries `isPackageSuspended` and displays "Blocked by Parent". Status: `IMPLEMENTED`.
- [ ] **CHD08 — Manual Policy Refresh**: Pull down to refresh on Rules tab. Assert latest `device_policies` queried and UI updates. Status: `IMPLEMENTED`.

### 2.5 Requests Inbox (Pairing & Assistance)
- [ ] **CHD03 — Incoming Requests Badge Count**: Observe Requests tab icon in bottom navigation bar. Assert red badge displays count of pending unhandled requests. Status: `IMPLEMENTED`.
- [ ] **REM02 — Accept Inbound Remote Assistance Call**: Incoming remote assistance prompt surfaces. Tap "Accept". Assert WebRTC call initializes and routes to `/child/session`. Status: `IMPLEMENTED`.
- [ ] **REM02 — Decline Inbound Remote Assistance Call**: On incoming assistance prompt, tap "Decline". Assert session marked `'declined'` and prompt closes. Status: `IMPLEMENTED`.

### 2.6 Remote Assistance Live Call (Child Side)
- [ ] **REM03 — WebRTC Audio/Video Streaming**: During active session (`/child/session`), assert two-way audio active and local camera feed streams to parent. Status: `IMPLEMENTED`.
- [ ] **REM05 — End Call from Child Device**: On session screen, tap "End Call". Assert WebRTC connection closed, native audio service halted, and routes back to Home. Status: `IMPLEMENTED`.
- [ ] **REM06 — In-Call Controls (Child Side)**: Tap Mute Mic, Toggle Video, or Switch Camera (front/back). Assert camera and microphone respond immediately. Status: `IMPLEMENTED`.

### 2.7 Child Settings & Native Protection Management
- [ ] **A07 — View Child Profile**: Open Settings tab (`/child`). Assert child email, display name, and family ID display correctly. Status: `IMPLEMENTED`.
- [ ] **SET03 — View App Version Information**: Scroll to bottom of Child Settings. Assert app version string matches package metadata. Status: `IMPLEMENTED`.
- [ ] **FAM11 — Child Self-Unlink**: In Child Settings, tap "Unlink Family". Confirm prompt. Assert sync config wiped from `SecureStore` and child unlinked. Status: `IMPLEMENTED`.
- [ ] **CHD05 — Camera & Microphone Self-Test**: In Child Settings, tap "Camera & Mic Test". Assert bottom sheet opens displaying live local camera preview and microphone volume meter. Status: `IMPLEMENTED`.
- [ ] **CHD07 — Reconnect Background Sync**: In Child Settings, tap "Reconnect Sync". Assert `GuardianService` restarts and attempts server handshake. Status: `IMPLEMENTED`.
- [ ] **LOC03 — Location Sharing Master Toggle**: In Child Settings, toggle "Share location" switch. Assert `LocationTrackingService` starts or stops accordingly. Status: `IMPLEMENTED`.
- [ ] **SET04 — Request Missing Runtime Permissions**: Tap "Grant Permissions" tile for missing camera, mic, or location. Assert native Android OS permission prompt surfaces. Status: `IMPLEMENTED`.
- [ ] **SET05 — Activate Android Device Administrator**: Tap "Enable Device Admin" button. Assert Android system Device Admin activation screen launches. Tap "Activate". Status: `IMPLEMENTED`.
- [ ] **SET06 — Launch Android Background Location Settings**: Tap "Allow Background Location". Assert Android App Info settings screen opens directly to Location permission page. Status: `IMPLEMENTED`.
- [ ] **SET07 — Permission Diagnostics Tile**: View permission list in Child Settings. Assert clean chips showing "Granted" or "Denied" for each capability. Status: `IMPLEMENTED`.
- [ ] **SET08 — Device Admin Tampering Warning**: Attempt to deactivate Device Admin in Android OS settings. Assert native warning dialog informs user that protection will be revoked. Status: `IMPLEMENTED`.

### 2.8 Native Background Daemon Execution (Android Native)
- [ ] **CHD04 — Guardian Foreground Service Execution**: Check Android notification drawer. Assert persistent notification with channel `"guardian_status"` displays "HAVEN Protection Active". Status: `IMPLEMENTED`.
- [ ] **MON04 — Background Heartbeat Transmission**: Monitor network traffic. Assert `GuardianService` transmits telemetry heartbeat every 5 minutes. Status: `PARTIALLY_IMPLEMENTED` (Breaks after reinstall).
- [ ] **MON05 — Permission State Reporting**: Revoke camera permission in OS settings. Assert next heartbeat updates permission column in `devices`. Status: `PARTIALLY_IMPLEMENTED` (Android 12 false-positive).
- [ ] **MON07 — Installed Apps Snapshot Upload**: Every 30 minutes, assert `GuardianService` snapshots user apps and posts batch to `device-telemetry`. Status: `IMPLEMENTED`.
- [ ] **USE04 — Hourly Usage Statistics Upload**: Hourly, assert `UsageReporter` queries `UsageStatsManager` and uploads daily app usage. Status: `PARTIALLY_IMPLEMENTED` (Fails if credential broken).
- [ ] **LOC04 — Continuous Background Location Tracking**: Move child device > 50 meters. Assert `LocationTrackingService` uploads new GPS event. Status: `PARTIALLY_IMPLEMENTED` (Fails if credential broken).
- [ ] **APP05 — Command Execution & Policy ACK**: Parent dispatches `apply_policy`. Assert `GuardianService` polls command (20s interval), applies rules, and posts ACK result. Status: `IMPLEMENTED`.
- [ ] **APP07 — Native OS App Suspension**: Parent blocks an app. Assert child attempts to launch app and receives Android OS "App paused by admin" dialog. Status: `PARTIALLY_IMPLEMENTED` (Requires Device Owner).
- [ ] **USE08 — Daily Quota Lockout Enforcement**: Daily limit exceeded. Assert `QuotaEvaluator` natively suspends non-essential applications. Status: `PARTIALLY_IMPLEMENTED` (Requires Device Owner).
- [ ] **SYS01 — Offline Daemon Caching**: Disconnect internet. Assert `GuardianService` buffers usage and location events locally in SQLite/prefs until connection restored. Status: `IMPLEMENTED`.
- [ ] **SYS02 — Periodic Poll & Check-in**: Assert background service executes periodic tick every 10s and polls commands every 20s. Status: `IMPLEMENTED`.
