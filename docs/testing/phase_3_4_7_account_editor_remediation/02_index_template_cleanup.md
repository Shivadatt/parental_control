# Phase 3.4.7 — Report 02: Index Template Cleanup & Full Buffer Replacement

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Audit Date:** 2026-11-20  

---

## 1. Incident Root Cause Analysis (Phase 3.4.6)

In Phase 3.4.6, remote bundling failed with:
```
Failed to bundle the function (reason: The module's source code could not be parsed: Expected ',', got '{' at file:///tmp/.../source/index.ts:33:10)
```
Inspection revealed that the default Supabase boilerplate template:
```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

interface ReqPayload {
  name: string;
}

console.info("server started");

export default {
  fetch: withSupabase({ auth: ["publishable", "secret"] }, async (req, ctx) => {
    ...
  }),
```
was NOT cleared before the 480-line application code was inserted. Consequently, the top-level imports in `index.ts` were embedded within an unclosed object literal at line 33, causing Deno's bundler to throw a syntax error.

---

## 2. Remediation Procedure

To ensure 100% elimination of residual template code:
1. Focused Monaco editor on `index.ts`.
2. Executed `Control+A` (Select All) followed by `Backspace`.
3. Verified the editor content accessibility tree snapshot confirmed an empty buffer (`value=""`).
4. Read the verified 480-line `index.ts` (15,868 bytes, SHA-256 `31ed89d4...`) directly from local disk via the subagent's native `read_file` tool.
5. Injected the pristine code starting at line 1.
6. Formatted the buffer with `Shift+Alt+F`.

---

## 3. Buffer Scope & Syntax Verification

- **Line 1 Check:** `index.ts` begins cleanly at line 1 with file header comments and top-level imports:
  ```typescript
  // account: the caller's own privacy lifecycle — export, deletion, retention.
  ...
  import { preflightResponse, corsHeaders } from "./shared-cors.ts";
  ```
- **Top-Level Scope:** `import { preflightResponse, corsHeaders } from "./shared-cors.ts"` is confirmed at root level scope (not nested inside `export default { ... }` or any wrapper).
- **Template Absence:** Supabase's `withSupabase`, `jsr:@supabase/functions-js`, and `ReqPayload` are completely absent.
- **Terminal Construct:** The file terminates cleanly at line 480 with:
  ```typescript
    } catch (error) {
      return errorResponse(error);
    }
  });
  ```
