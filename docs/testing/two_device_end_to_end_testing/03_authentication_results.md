# 03 — Authentication Results

**Date:** 2026-11-21  
**Build:** installed `1.0.0` debug, 2026-11-18  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Method and constraints

The owner was to enter passwords manually. The execution environment cannot type into device login fields and was denied physical-device UI interaction after the initial observation window.

Therefore this phase distinguishes:

- **Existing-session authentication** — observed directly.
- **Fresh credential entry** — not performed and not claimed.

No password was requested, typed, read, stored, logged or recovered. No account was created, deleted, reset or re-roled.

---

## 2. Parent device (`emulator-5554`)

| Check | Observation | Label |
|---|---|---|
| App process | PID 3410 alive | PASS |
| Login screen shown | No; app resumed directly into the parent shell | PASS (existing session) |
| Parent role | Bottom tabs: Dashboard / Devices / Alerts / Settings | PASS |
| Profile / family loaded | Family `demo` displayed | PASS |
| Ownership | Family page: “Owner — ankit (you)” | PASS |
| Child visible | `ankit1` listed as active child | PASS |
| Unexpected registration flow | None | PASS |
| Credential entry by tester | Not performed | NOT TESTED |
| Session survives background/relaunch | Yes; parent shell restored on Devices tab | PASS |

**Parent authentication result:** PASS for an existing, persisted Supabase session. Fresh password login was not exercised.

---

## 3. Child device (`5HXWRGQ4IFU8WS4T`)

| Check | Observation | Label |
|---|---|---|
| App process | PID 9467 alive | PASS |
| Login screen shown | No; child shell displayed | PASS (existing session) |
| Child role | Tabs: Home / Rules / Requests / Settings; child-only location and rules cards | PASS |
| Profile / family loaded | Family `demo` displayed | PASS |
| Child identity | Family page lists `ankit1`, role Child, joined Oct 29, 2026 | PASS |
| Unexpected registration flow | None | PASS |
| Credential entry by tester | Not performed | NOT TESTED |
| Session survives relaunch | Yes; child shell restored | PASS |

**Child authentication result:** PASS for an existing, persisted Supabase session. Fresh password login was not exercised.

---

## 4. Authentication failure behavior (not triggered)

No sign-in failure was induced. Existing evidence in the repository reports correct validation errors for empty and wrong credentials, but this pass did not independently retest them.

**Label:** REPORTED, not retested.

---

## 5. Authentication verdict

**PASS — existing sessions and role resolution on both devices.**  
**NOT TESTED — fresh manual credential entry.**  
No authentication-related defect was observed. No account state was modified.
