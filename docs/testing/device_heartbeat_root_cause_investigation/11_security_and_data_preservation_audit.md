# 11 — Security and Data Preservation Audit

**Date:** 2026-11-21  
**Phase:** read-only diagnostic  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Safety checklist

| Requirement | Result | Evidence |
|---|---|---|
| No application code modified | PASS | No file edits outside the report directory |
| No APK rebuilt | PASS | No build command executed |
| No APK installed | PASS | No `adb install` executed |
| No app data cleared | PASS | No `pm clear`, uninstall or reinstall |
| No account changed | PASS | No auth mutation |
| No credential reset/regenerated | PASS | No secret operation performed |
| No pairing changed | PASS | No pairing/unlink/recovery action |
| No database writes | PASS | No DB/endpoint call |
| No production endpoint invoked | PASS | No HTTP request sent |
| No Supabase configuration changed | PASS | No CLI/dashboard mutation |
| No Edge Function modified/deployed | PASS | No function write/deploy |
| No schema/RLS change | PASS | No migration executed |
| No secrets exposed | PASS | No headers/tokens/secret values printed |
| Existing relationship preserved | PASS | Family `demo` untouched |

---

## 2. Git state

```text
branch: main
HEAD:   bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f
status: only untracked report directories under docs/testing/
```

The Phase 1 report directory was already untracked before this investigation. This phase adds a second untracked report directory. No source, test, migration, function, config or lock file changed.

---

## 3. Credential handling

| Item | Handling |
|---|---|
| Device secret | Never read from secure storage |
| Secret hash | Never extracted or printed |
| Installation ID | Never printed |
| JWTs / refresh tokens | Never read or logged |
| Authorization headers | Never captured |
| Publishable/anon key | Existing config file not printed |
| Passwords | Never requested, typed or stored |
| Pairing codes | Not generated or read |

The investigation used only:

- source code,
- installed package metadata,
- runtime state already observed in the preceding phase,
- non-secret device properties (model, Android version, API level, install timestamps).

Encrypted preferences were deliberately not read; the execution policy also refused that class of access. This protects tokens and device credentials.

---

## 4. Data minimization in the reports

The reports do not contain:

- exact location or map data,
- device secret or hash,
- authentication headers or tokens,
- full request/response bodies,
- passwords,
- pairing codes,
- personal contact information beyond the already-known test account identity where necessary.

Device serials and test account roles are included only where needed to identify the evidence source.

---

## 5. Read-only inspection boundaries

The following were **not** performed:

- `adb` ping/log/notification dumps after the policy refused further physical-device inspection,
- reading `shared_prefs` or `EncryptedSharedPreferences`,
- packet capture or TLS interception,
- hosted SQL queries or Edge Function logs,
- Supabase CLI calls,
- invoking `device-telemetry` or any other endpoint.

The exact rejection response therefore remains unobserved. This is recorded as a limitation, not filled with an assumption.

---

## 6. Security observations for the future fix

1. **`device-register` currently trusts a client-computed `secret_hash`** but binds it to an authenticated child and active family membership. Any re-credential path must preserve equivalent or stronger checks.
2. **A re-credential endpoint must not allow device takeover.** Require the same child user session, same family, and the existing active row; add rate limiting and audit.
3. **Do not log secrets or full headers** when adding observability. Log the HTTP status, a safe error code, device row ID (not secret), and timestamps.
4. **Device-authenticated endpoints are intentionally not user-JWT endpoints.** Do not “fix” the 401 by disabling `requireDevice` or accepting a user JWT as device proof.
5. **The child’s `lastError` is already stored securely.** Surface it through a safe UI message; do not export secure storage.

---

## 7. Data-preservation verdict

**PASS** — no application, account, credential, pairing, database or backend state was changed. The existing parent/child relationship remains intact. No sensitive value was exposed.
