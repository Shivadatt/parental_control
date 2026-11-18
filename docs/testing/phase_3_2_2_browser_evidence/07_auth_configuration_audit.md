# Phase 3.2.2 — Report 07: Authentication & URL Configuration Audit

## 1. Executive Summary

This report documents the live audit of Supabase Authentication configuration, Auth providers, and URL redirect allowlists for project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

The inspection was performed across the Supabase Dashboard under **Authentication > Configuration** and **Authentication > URL Configuration** (`/auth/url-configuration`).

---

## 2. Authentication Providers

| Provider | Status | Inspection Details | Security Justification |
| :--- | :---: | :--- | :--- |
| **Email Auth** | **ENABLED** | Standard Email/Password sign-up and sign-in enabled. | Core authentication mechanism for parent accounts. |
| **Email Confirmation** | **ENABLED** | New accounts require email verification before full access. | Prevents spam accounts and guarantees valid parent email. |
| **Phone / SMS** | **DISABLED**| Not configured. | Minimizes telecom attack surface & SMS cost. |
| **Google OAuth** | **DISABLED**| Not enabled. | Not currently utilized in Phase 3 client builds. |
| **Apple OAuth** | **DISABLED**| Not enabled. | iOS client not yet in active scope. |
| **Third-Party OAuth**| **DISABLED**| All 20+ other third-party OAuth providers disabled. | Eliminates unnecessary external auth attack surfaces. |

---

## 3. URL Configuration & Redirect Allowlist

Live inspection of **URL Configuration** (`/auth/url-configuration`):

- **Visual Evidence**: [P322_09_auth_url_configuration.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_09_auth_url_configuration.png)

| Setting | Value | Verification | Operational Purpose |
| :--- | :--- | :---: | :--- |
| **Site URL** | `http://localhost:3000` | **VERIFIED** | Default web fallback URL for local testing/auth. |
| **Redirect URLs Allowlist** | `parentcontrol://auth-callback` | **VERIFIED** | Deep-link scheme allowing the Flutter mobile app to intercept auth callbacks, password reset links, and email confirmations directly on Android devices. |

---

## 4. Auth Service Version

- **Auth Engine Version**: `2.198.0` (GoTrue)
- **Visual Evidence**: [P322_16_settings_general.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_16_settings_general.png)

---

## 5. Security & Mobile Integration Analysis

1. **Mobile Deep-Linking Verification**:
   - The deep link URI `parentcontrol://auth-callback` matches the custom intent-filter defined in `android/app/src/main/AndroidManifest.xml`.
   - When a parent user clicks an email confirmation or password recovery link sent by Supabase Auth, Android immediately resumes the Parent Control application.
2. **Strict Redirect Boundary**:
   - Only `parentcontrol://auth-callback` is allowlisted.
   - Wildcard redirects (`*`) or open web redirects are strictly avoided, preventing open-redirect phishing attacks.
3. **Email Confirmation Flow**:
   - Verified that email confirmation is mandatory. A newly created parent profile remains in a restricted state until the email confirmation callback is processed.
