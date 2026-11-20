# Phase 3.7.3 — Report 04: Supabase Auth Configuration & Synthetic Identity Feasibility

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report evaluates the Supabase GoTrue Auth configuration parameters required for multi-tenant isolation testing and assesses the feasibility of using synthetic identities in the `@internal-test.local` namespace.

$$\mathbf{Auth\ Configuration\ Parity} = \mathbf{PRODUCTION\ VERIFIED\ -\ STAGING\ UNKNOWN\ (NO\ PROJECT)}$$
$$\mathbf{Synthetic\ Identity\ Feasibility} = \mathbf{100\%\ FEASIBLE\ (PROVEN\ IN\ PHASE\ 3.7)}$$

Phase 3.7 confirmed live in production that Supabase GoTrue Auth cleanly accepts synthetic emails ending in `@internal-test.local` when created via Dashboard UI with auto-confirm enabled. Any future staging environment must replicate this configuration to support automated or manual synthetic provisioning without external email delivery.

---

## 2. GoTrue Auth Configuration Parity Matrix

The table below audits the Auth settings defined in `supabase/config.toml` and verified in production during Phase 3.2.2 / Phase 3.7:

| Configuration Parameter | Repository Baseline (`config.toml`) | Production Verified State | Required Staging State | Staging Parity Status |
|---|---|---|---|:---:|
| **Email Authentication** | Enabled (`enable_signup = true`) | Enabled | Enabled | **UNKNOWN** |
| **Email Confirmations** | Enabled (`enable_confirmations = true`) | Enabled (Auto-confirm supported via UI/Admin) | Auto-confirm enabled for synthetic runs | **UNKNOWN** |
| **Double Confirm Changes** | Enabled (`double_confirm_changes = true`) | Enabled | Enabled | **UNKNOWN** |
| **Site URL** | `http://localhost:3000` | Production Site URL | Staging / Local URL | **UNKNOWN** |
| **Redirect URLs** | `parentcontrol://auth-callback`, `localhost:3000` | Configured | Configured | **UNKNOWN** |
| **JWT Expiry** | 3600 seconds (1 hour) | 3600 seconds | 3600 seconds | **UNKNOWN** |
| **Refresh Token Rotation** | Enabled (reuse interval: 10s) | Enabled | Enabled | **UNKNOWN** |
| **Anonymous Sign-ins** | Disabled (`enable_anonymous_sign_ins = false`) | Disabled | Disabled | **UNKNOWN** |
| **New User Trigger** | `private.handle_new_user()` on `auth.users` | Verified active (Creates profile with role `unset`) | Must be deployed via migrations | **UNKNOWN** |

---

## 3. Synthetic Identity Feasibility Analysis (`@internal-test.local`)

### 3.1 Domain Standard Compliance (RFC 2606 / RFC 6761)
- The top-level domain `.local` and reserved test domains (`.test`, `.example`, `.invalid`) are defined by IETF standards as non-routable.
- In Phase 3.7, the synthetic parent email:
  $$\texttt{ephemeral-parent-run-20261120-e7f1@internal-test.local}$$
  was submitted directly to Supabase GoTrue Auth.
- **Observed Result:** GoTrue validated the email format successfully, issued UID `22a1dbb7-c4d9-4a3a-8481-e0d44871146d`, stamped `email_confirmed_at = now()`, and dispatched zero outbound SMTP messages.

### 3.2 Key Feasibility Findings for Future Staging:
1. **Zero Spam / Zero Delivery Risk:** Outbound SMTP is not invoked when auto-confirm is toggled in Dashboard UI or API, completely preventing email leakage or bounce-rate penalties.
2. **Deterministic Trigger Execution:** Auth creation immediately invokes PostgreSQL trigger `private.handle_new_user()`, automatically inserting the matching row into `public.profiles`.
3. **Precondition for Staging:** Any future staging project must have email provider enabled and the `handle_new_user()` trigger applied via migration `20260101000100_functions.sql`.
