# 06 — Absent Capability Gap Register

These ten capabilities are **separate from the 80 functionality IDs**. They were not found in the inspected checkout. Absence is not automatically a product defect; each requires an owner/product scope decision. No fictional execution steps or failed tests are created.

| Gap ID | Absent capability | Audit evidence / reference | Product impact | Product-scope decision | Test status |
|---|---|---|---|---|---|
| M01 | Website/internet/content filtering (DNS, VPN, proxy, safe search, category blocking) | `05_missing_and_incomplete_functionalities.md` M01; no functional content-filter code in `lib`, Kotlin, Edge Functions, or migrations | Cannot restrict web content or specific sites | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M02 | Push notifications/background alert delivery | M02; no Firebase/FCM dependency or push-token registration; alerts realtime only | Parent may miss alerts when app is closed | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M03 | Password reset/forgot-password | M03; no reset-password flow or recovery screen | Locked-out users lack in-app recovery | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M04 | Device Owner provisioning from app | M04; `ParentControlDeviceAdminReceiver.kt` states provisioning is not attempted | Full enforcement is unavailable on ordinary installs | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M05 | Remote lock/wipe | M05; no `lockNow`/`wipeData` call | Lost-device response limited to revoke/recovery | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M06 | App install/uninstall monitoring and alerts | M06; installed-app snapshots exist, no package-change receiver/alert type | Parent not notified when apps change | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M07 | Multiple-family switching/family selector | M07; one `activeFamily`; no family-switch UI | One parent identity cannot manage separate families in-app | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M08 | Accessibility service/accessibility-based enforcement | M08; no `AccessibilityService` subclass or manifest declaration | No accessibility-driven app/site control | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M09 | Family owner transfer, family deletion, parent leave-family | M09; no RPC/UI beyond child unlink | Family lifecycle cannot be completed by owner | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |
| M10 | Additional parent/guardian invitation | M10; no co-parent invite/role-assignment flow | Both parents cannot independently administer family | REQUIRES OWNER/PRODUCT DECISION | ABSENT IN INSPECTED CHECKOUT — no test case |

## Scope notes

- These are not `NOT TESTED` cases; there is no implemented feature to execute.
- They are not `FAIL` results; absence must first be accepted or rejected as product scope.
- They do not change the 80-item inventory or its 69/7/2/2 counts.
- Implementing or simulating any gap requires separate design and authorization.
