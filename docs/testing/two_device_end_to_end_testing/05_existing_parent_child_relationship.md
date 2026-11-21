# 05 — Existing Parent/Child Relationship

**Date:** 2026-11-21  
**Parent:** `emulator-5554` / `ankit@gmail.com`  
**Child:** `5HXWRGQ4IFU8WS4T` / `ankit1@gmail.com`  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Constraint honored

No pairing, re-pairing, unlinking, revocation, device deletion, membership change, role change or family-ownership change was performed. The existing relationship was inspected only.

---

## 2. Parent-side relationship evidence

The parent Family screen showed:

| Field | Observed value | Label |
|---|---|---|
| Family name | `demo` | PASS |
| Owner | `ankit (you)` | PASS |
| Created | Oct 29, 2026 | PASS |
| Guardians | `ankit (you)` — Family owner — Active | PASS |
| Children | `ankit1` — Active — Role Child — Joined Oct 29, 2026 11:17 AM | PASS |
| Linked devices | `realme RMX2161` — Offline — last seen 186 h ago — Nov 13, 2026 5:23 PM | PASS (relationship) / FAIL (freshness) |
| Enforcement | Not enforced | PASS |
| Battery | 100% (charging) | REPORTED (stale) |
| Pending pairing | “No pairing request is waiting for a child to approve.” | PASS |

The parent therefore sees exactly the expected child account and one linked-device identity.

---

## 3. Child-side relationship evidence

The child shell showed:

| Field | Observed value | Label |
|---|---|---|
| Family | `demo` | PASS |
| Role | Child (Home / Rules / Requests / Settings; child-only controls) | PASS |
| Signed-in identity | `ankit1` (parent Family screen) | PASS |
| Requests card | “0 pending” after an initial timeout message cleared | PASS |
| Local data freshness | “Updated 2 d ago” | FAIL (freshness) |

The child is a member of the same family and is not on a registration or role-selection screen.

---

## 4. Device identity and duplicate rows

The parent Dashboard and Devices tab displayed **two rows both named `realme RMX2161`**:

1. One marked **Revoked**, last seen Nov 13, 2026 10:18 AM, “No policy applied yet”.
2. One marked **Offline**, last seen Nov 13, 2026 5:23 PM, policy displayed as **v2** on the list and **v4** on the detail screen.

Both rows carry the same model and account label. One is explicitly revoked but is still presented in the current device list.

**Labels:**

- Expected child device visible: **PASS**
- Duplicate/revoked row still listed as a current device: **FAIL (P2)**
- Policy version consistency across screens: **FAIL (P2)**

This matches the previously reported `BUG-040` family of defects (revoked devices listed as current) and adds a policy-version divergence observation.

---

## 5. Authorization isolation

The parent UI showed only family `demo`; no foreign family or foreign device was visible.

No foreign identifiers were injected, no cross-tenant request was made, and no destructive authorization test was attempted. Cross-family isolation is covered by the repository’s offline/hosted test suites, not by this device pass.

**Label:** NOT TESTED (by design).

---

## 6. Relationship verdict

**PASS — the existing `demo` parent/child membership is intact and both devices resolve to it.**  
**FAIL (P2) — duplicate revoked device row and inconsistent policy version display.**  
**FAIL (P1) — the linked device is shown offline with stale data while the child app is running (see report 06).**
