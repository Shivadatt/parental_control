# Phase 3.6 — Report 06: Test Data Classification & Strict Privacy Boundaries

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Test Data Classification Taxonomy

To prevent data contamination, accidental disclosure, or privacy violations, all data utilized in test modeling, mock fixtures, and future ephemeral qualification is partitioned into strict classification tiers.

```
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: Permitted Proposed Test Data (100% Synthetic)       │
│  - Controlled synthetic email namespace: @internal-test.local│
│  - Fictional display names: "Test Parent A", "Test Child B" │
│  - Deterministic correlation UUIDs: run-YYYYMMDD-XXXX       │
│  - Synthetic hardware identifiers: test-inst-XXXX-01        │
│  - Synthetic geolocations: Null Island (0.0, 0.0) or mocks  │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ TIER 2: Prohibited Operational Data (Strictly Excluded)     │
│  - Real user emails, phone numbers, or residential addresses│
│  - Protected QA accounts: spg7753@*, ankit@*, ankit1@*      │
│  - Real mobile device serials, IMEI, or hardware MACs       │
│  - Real live child GPS breadcrumbs or app usage timelines   │
│  - Production passwords, live refresh tokens, or long JWTs  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Permitted vs Prohibited Data Boundaries

| Data Field / Entity | Permitted Proposed Synthetic Formats | Prohibited Operational Data Formats | Enforcement Mechanism |
|---|---|---|---|
| **User Email Addresses** | `ephemeral-parent-<RUN_ID>@internal-test.local`<br>`ephemeral-child-<RUN_ID>@internal-test.local` | Any real public domain (`@gmail.com`, `@yahoo.com`, `@outlook.com`) | Regex assertion in provisioning scripts: `/^ephemeral-[a-z]+-run-[0-9a-f-]+@internal-test\.local$/` |
| **Protected QA Identities** | **None.** (Never mocked or referenced) | `spg7753@gmail.com`<br>`ankit@gmail.com`<br>`ankit1@gmail.com` | Hardcoded exclusion blacklist; immediate abort if target matches protected set |
| **Display Names** | `"Ephemeral Parent <RUN_ID>"`<br>`"Ephemeral Child <RUN_ID>"` | Real human full names or personal nicknames | Sanitized naming conventions |
| **Family Names** | `"Ephemeral QA Family <RUN_ID>"` | Real family names or personal identifiers | Prefixed standard naming |
| **Device Installation IDs** | `"test-inst-<RUN_ID>-01"` | Real Android hardware IDs or Firebase installation tokens | Formatted mock strings |
| **Device Secret Material** | Synthetic hex hashes (`"0123456789abcdef..."`) | Real production device secret keys | Prohibited in git logs and reports |
| **Geographic Coordinates** | Fixed synthetic coordinates (e.g. `lat: 37.5665, lng: 126.9780` — Seoul City Hall center) | Real child school, home, or live location breadcrumbs | Synthetic coordinates only |
| **Application Package Names**| Synthetic package names (`"com.example.testapp"`) | Real personal applications or private apps | Standard test package naming |
| **Authentication JWTs** | Short-lived ephemeral tokens (TTL $\le 1$ hour) | Real long-lived user session tokens or admin keys | Secret redaction (`Bearer eyJ...***`) |

---

## 3. Sanitization & Evidence Logging Hygiene

To guarantee that documentation, git commits, and runtime test logs remain free from sensitive data:
1. **Zero Secret Printing:** Test scripts and execution logs must never output unmasked access tokens, refresh tokens, service keys, or password strings.
2. **Deterministic Correlation Masking:** In reports, correlation IDs may be shown in truncated form (`run-20261120-a1b2`).
3. **No Database Dumps in Artifacts:** Raw exports containing real production rows must never be committed to git or stored in public workspaces.
4. **Immediate Redaction:** Any accidental logging of sensitive identifiers triggers immediate git history scrubbing and token revocation.
