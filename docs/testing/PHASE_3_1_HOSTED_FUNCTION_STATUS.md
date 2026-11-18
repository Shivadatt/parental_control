# PHASE 3.1 — STAGE D: HOSTED FUNCTION STATUS REPORT

**Target Endpoint:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Region:** `ap-south-1`  
**Execution Timestamp:** 2026-11-18T14:54:20+05:30  
**Inspection Mode:** Safe Read-Only HTTP Probing (OPTIONS Preflight)  

---

## 1. MANDATORY HOSTED STATE DECLARATION

```
HOSTED_ACCOUNT_FUNCTION = NOT DEPLOYED
```

---

## 2. PROBE RESULTS & NETWORK EVIDENCE

### 2.1 Target Probe (`/account`)
A non-mutating HTTP OPTIONS probe was dispatched via `curl.exe` to examine the gateway response:

```bash
curl.exe -i -X OPTIONS "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account"
```

#### Actual HTTP Gateway Response:
```http
HTTP/1.1 404 Not Found
Date: Wed, 18 Nov 2026 09:24:22 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
CF-Ray: a5c5ebfa8f6a68a4-BOM
CF-Cache-Status: DYNAMIC
Access-Control-Allow-Origin: *
Server: cloudflare
sb-error-code: NOT_FOUND
sb-gateway-version: 1
sb-project-ref: hhqgreaoqulmfwfwarhc
sb-request-id: 01a1edf8-b899-7b73-b89b-aff2aa1fe944
x-sb-edge-region: ap-south-1
x-served-by: supabase-edge-runtime

{"code":"NOT_FOUND","message":"Requested function was not found"}
```

---

### 2.2 Control Probe Against Active Deployed Function (`/auth-bootstrap`)
To verify that the gateway and edge runtime are functional, a control probe was dispatched to `/auth-bootstrap`:

```bash
curl.exe -i -X OPTIONS "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/auth-bootstrap"
```

#### Actual HTTP Gateway Response:
```http
HTTP/1.1 200 OK
Date: Wed, 18 Nov 2026 09:24:38 GMT
Content-Type: text/plain;charset=UTF-8
Connection: keep-alive
CF-Ray: a5c5ec5badccb1e7-BOM
Access-Control-Allow-Origin: *
access-control-allow-headers: authorization, x-client-info, apikey, content-type, x-device-id, x-device-secret, x-cron-secret
access-control-allow-methods: POST, GET, OPTIONS
sb-project-ref: hhqgreaoqulmfwfwarhc
x-deno-execution-id: 0dc7f36e-2c5c-4d1a-804f-7e42e71164b8
x-sb-edge-region: ap-south-1
x-served-by: supabase-edge-runtime

ok
```

---

## 3. AUDIT CONCLUSION

1. **Defect E-15 Confirmed Live:** The live Supabase gateway returns `{"code":"NOT_FOUND","message":"Requested function was not found"}` when `/functions/v1/account` is invoked.
2. **Gateway Health:** The Supabase Edge Runtime infrastructure in region `ap-south-1` is online and healthy (as evidenced by `auth-bootstrap` returning 200 OK).
3. **Deployment Necessity:** Deploying the locally implemented `account` function is the singular missing operational step required to resolve the Parent Settings retention-report error.
