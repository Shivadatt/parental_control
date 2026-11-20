# Phase 3.7 — Report 03: Synthetic Identity & Ephemeral Tenant Design

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Design Status:** **STAGED — AWAITING GATE 1 OWNER AUTHORIZATION**  
**Audit Date:** 2026-11-20  

---

## 1. Synthetic Namespace & Identity Specifications

To ensure complete isolation from real operational accounts, any ephemeral test identities provisioned under future Gate 1 authorization are strictly bound to a synthetic namespace and deterministic correlation identifiers.

```
┌─────────────────────────────────────────────────────────────┐
│ SYNTHETIC TENANT BLUEPRINT (Pending Gate 1 Authorization)   │
├─────────────────────────────────────────────────────────────┤
│ Correlation ID: run-20261120-e7f1                           │
│ Namespace:      @internal-test.local                        │
│ Parent User:    ephemeral-parent-run-20261120-e7f1@...      │
│ Child User:     ephemeral-child-run-20261120-e7f1@...       │
│ Family Name:    Ephemeral QA Family run-20261120-e7f1       │
│ Device Inst ID: test-inst-run-20261120-e7f1-01              │
│ Time-to-Live:   3600 seconds (1 Hour Expiration)            │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Planned Tenant Entity Architecture

1. **Ephemeral Parent Entity:**
   - Email: `ephemeral-parent-run-20261120-e7f1@internal-test.local`
   - Application Role: `parent` (`profiles.role = 'parent'`)
   - Ownership: Root owner of the ephemeral family (`families.owner_id = parent.id`).
2. **Ephemeral Family Entity:**
   - Name: `"Ephemeral QA Family run-20261120-e7f1"`
   - Settings: `{"location_retention_days": 30, "usage_retention_days": 90}`
   - Correlation Metadata:
     ```json
     {
       "test_correlation_id": "run-20261120-e7f1",
       "is_ephemeral_test": true,
       "expires_at": "2026-11-20T16:15:00.000Z"
     }
     ```
3. **Ephemeral Child Entity:**
   - Email: `ephemeral-child-run-20261120-e7f1@internal-test.local`
   - Application Role: `child` (`profiles.role = 'child'`)
   - Membership: Active member in the ephemeral family (`family_members.role = 'child'`).

---

## 3. Strict Pre-Provisioning Safeguards

Before any entity can be created under future authorization:
- **Blacklist Enforcement:** The provisioning script strictly asserts that the target identity is not in the set:  
  `{"spg7753@gmail.com", "ankit@gmail.com", "ankit1@gmail.com"}`.
- **Domain Whitelist Assertion:** The email must match `/^ephemeral-[a-z]+-run-[0-9a-f-]+@internal-test\.local$/`.
- **Zero Real Hardware:** Device pairing and physical Android IMEI/hardware enrollment are permanently excluded.
