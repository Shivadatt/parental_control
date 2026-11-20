# Phase 3.7.3 — Report 06: Environment & Secret Separation Architecture

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report establishes the secret isolation standards, configuration guardrails, and environment boundary rules required to prevent credential cross-contamination between production and any future staging environment.

$$\mathbf{Secret\ Separation\ Invariant} = \mathbf{ZERO\ PRODUCTION\ CREDENTIALS\ IN\ STAGING\ -\ ZERO\ CONFIGURATION\ FALLBACK}$$

A critical finding of this audit is that **zero production keys are hardcoded in the application repository**. Production secrets are injected dynamically by the Supabase Edge Functions runtime, and client credentials in `.tools/live_config.env` are strictly limited to publishable anonymous tokens.

---

## 2. Environment Secret Separation Matrix

The table below defines the boundary separation requirements across all operational keys:

| Secret / Config Parameter | Production Environment (`parent-control-prod`) | Staging Environment Requirement | Contamination Risk | Required Safeguard |
|---|---|---|:---:|---|
| **Project URL** | `https://hhqgreaoqulmfwfwarhc.supabase.co` | Must have distinct ref (e.g. `https://<staging_ref>.supabase.co`) | Critical | Hard-stop abort if staging URL matches production ref. |
| **Publishable / Anon Key** | `sb_publishable_sP1oJ0Px...` | Unique staging anonymous key | Low | Scoped to staging project only. |
| **Service-Role Key** | Injected dynamically by Supabase runtime | Unique staging `service_role` key | Critical | Never export production service-role key to local `.env`. |
| **JWT Secret** | Managed internally by Supabase Auth | Unique staging GoTrue secret | Critical | Tokens signed for staging must be rejected by production. |
| **`CRON_SECRET`** | Secret header for cron endpoints | Distinct random staging value | High | Staging cron must not invoke production endpoints. |
| **`TURN_SECRET`** | WebRTC signaling secret | Independent staging secret | Low | Network isolation for media relays. |
| **Database Passwords** | Configured in Supabase Dashboard | Dedicated staging password | Critical | Zero password reuse between projects. |

---

## 3. Hard-Stop Condition Evaluation

In accordance with Section 9 of the Phase 3.7.3 mandate:

> **Mandatory Hard-Stop Condition:**
> *If a staging configuration appears to reference production credentials or the production project URL, classify the staging setup as `NOT SAFE`.*

### Audit Findings:
1. **Zero Configuration Crosstalk:** No file in the repository attempts to point a staging environment to `hhqgreaoqulmfwfwarhc`.
2. **Local Development Separation:** `supabase/config.toml` targets local ports (`54321`, `54322`) and cannot accidentally proxy to the production cloud project without an explicit `--linked` parameter.
3. **No Credential Exposure:** Neither service-role secrets nor database master passwords for production are committed in Git.

---

## 4. Staging Configuration Template (Future Provisioning)

When the project owner authorizes the creation of a staging project, its configuration must strictly adhere to this isolated structure:
```bash
# Future .env.staging specification (Never commit real values)
STAGING_SUPABASE_URL=https://<staging-ref>.supabase.co
STAGING_SUPABASE_ANON_KEY=<staging-anon-key>
# Service-role key must remain exclusively inside Supabase Dashboard / CI secrets
```
No live test script may fall back to production if staging variables are undefined; scripts must fail closed immediately.
