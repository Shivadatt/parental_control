# PHASE 3.2.2 — CHROME DEVTOOLS CONNECTOR COMPATIBILITY DIAGNOSTIC

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Supabase Project:** `parent-control-prod`  
**Expected Supabase Reference:** `hhqgreaoqulmfwfwarhc`  
**Audit Mode:** STRICT READ-ONLY DIAGNOSTIC  
**Timestamp:** 2026-11-18T15:48:00+05:30  

---

## 1. EXECUTIVE SUMMARY

The browser-based dashboard inspection for Phase 3.2.2 encountered a DevTools connection block (`DevToolsActivePort` ENOENT error). A deep technical diagnostic of the Windows host environment, active processes, and Antigravity's Model Context Protocol (MCP) browser connector was conducted without modifying user profiles, terminating browser sessions, or executing database mutations.

### Key Technical Findings:
1. **Installed Chrome:** Google Chrome Version `157.0.8103.79` (64-bit) at `C:\Program Files\Google\Chrome\Application\chrome.exe`.
2. **Connector Package:** `@ChromeDevTools/chrome-devtools-mcp` (latest) executed via Node.js by `agy.exe`.
3. **Connector Arguments:** `chrome-devtools-mcp@latest --no-usage-statistics --no-performance-crux --autoConnect`.
4. **Root Cause:** 
   - Modern Chrome (144+) architecture separates command-line debugging from active profile single-instance management.
   - When Chrome is already running, launching `chrome.exe --remote-debugging-port=9222` simply delegates to the existing master process, which ignores the flag and does not initialize the DevTools server.
   - Antigravity's `chrome-devtools-mcp` was invoked with `--autoConnect`, which hardcodes looking for `DevToolsActivePort` at `C:\Users\ASUS\AppData\Local\Google\Chrome\User Data\DevToolsActivePort`.
   - `chrome-devtools-mcp` natively supports explicit endpoints via `-u, --browserUrl http://127.0.0.1:9222`, but this flag is not currently passed in the default `agy.exe` spawn arguments.

---

## 2. STAGE 1 — BROWSER ENVIRONMENT INSPECTION

### 2.1 Chrome Executable & Version
* **Binary Path:** `C:\Program Files\Google\Chrome\Application\chrome.exe`
* **Product Version:** `157.0.8103.79`
* **Architecture:** Win64

### 2.2 Active Chrome Process Hierarchy
* **Master Process:** PID `13572` (`"C:\Program Files\Google\Chrome\Application\chrome.exe" --source-shortcut-location=taskbar`)
* **Default User Data Directory:** `C:\Users\ASUS\AppData\Local\Google\Chrome\User Data`
* **Crashpad Handler:** PID `22260`
* **GPU Process:** PID `10676`
* **Network Service:** PID `6856`
* **Extension & Tab Renderers:** PIDs `14820`, `18724`, `26032`, etc.
* **Process Status:** 24 active Chrome processes running under the user's primary desktop session. No processes were terminated.

### 2.3 Antigravity Connector Architecture
* **Parent Process:** `agy.exe` (PID `31640`, located at `C:\Users\ASUS\.gemini\bin\agy.exe`).
* **Spawned MCP Bridge:** 
  ```bat
  C:\WINDOWS\system32\cmd.exe /c ""C:\Program Files\nodejs\npx.cmd" -y chrome-devtools-mcp@latest --no-usage-statistics --no-performance-crux --autoConnect"
  ```
* **Node Wrapper:** PID `22548` -> Child Worker PID `1620`:
  `node C:\Users\ASUS\AppData\Local\npm-cache\_npx\15c61037b1978c83\node_modules\chrome-devtools-mcp\out\Default\gen\src\bin\chrome-devtools-mcp.js --no-usage-statistics --no-performance-crux --autoConnect`

---

## 3. STAGE 2 — CHROME 144+ / 157+ COMPATIBILITY & CONNECTOR MECHANICS

### 3.1 Connector Code Analysis (`BrowserManager.js` & `third_party/index.js`)
Inspection of `chrome-devtools-mcp` source reveals the exact connection decision tree:

```javascript
// BrowserManager.js (lines 370-380)
if (wsEndpoint) {
    connectOptions.browserWSEndpoint = wsEndpoint;
} else if (browserURL) {
    connectOptions.browserURL = browserURL;
} else if (channel || userDataDir) {
    autoConnect = true;
    const portPath = path.join(userDataDir, 'DevToolsActivePort');
    // Reads DevToolsActivePort from userDataDir
}
```

When `--browserUrl` is passed (e.g. `http://127.0.0.1:9222`), `chrome-devtools-mcp` executes:
```javascript
// third_party/index.js (lines 76833-76856)
async function getWSEndpoint(browserURL, headers) {
    const endpointURL = getWSEndpointURL(browserURL); // fetches http://127.0.0.1:9222/json/version
    const result = await globalThis.fetch(endpointURL);
    const data = await result.json();
    return data.webSocketDebuggerUrl; // Connects directly via WebSocket
}
```
**Conclusion:** The connector **fully supports** direct connection to `http://127.0.0.1:9222` without requiring `DevToolsActivePort` file inspection, but requires `--browserUrl` instead of `--autoConnect`.

### 3.2 Modern Chrome 144+ Dynamic Remote Debugging Feature
In modern Chrome (Chrome 144 through 157), the Chrome team added an in-browser interface to start the remote debugging server on a live profile without command-line flags:
* **Interface URL:** `chrome://inspect/#remote-debugging`
* **Connector Documentation:**
  > `--autoConnect`: *"If specified, automatically connects to a browser (Chrome 144+) running locally from the user data directory identified by the channel param (default channel is stable). Requires the remote debugging server to be started in the Chrome instance via chrome://inspect/#remote-debugging."*

When the user enables remote debugging in the `chrome://inspect/#remote-debugging` tab, Chrome creates `DevToolsActivePort` directly in `C:\Users\ASUS\AppData\Local\Google\Chrome\User Data\` on the fly.

---

## 4. STAGE 3 — IDENTIFICATION OF SUPPORTED CONNECTION METHODS

| Method | Description | User Profile Preservation | Authenticated Sessions | Risk / Complexity | Recommended |
|---|---|---|---|---|---|
| **Option 1 (Zero-Interruption)** | **Enable in-browser debugging toggle in `chrome://inspect/#remote-debugging`** | 100% Preserved | 100% Preserved | None; built-in Chrome 144+ feature; requires zero restarts and zero CLI flags. | **(Recommended)** |
| **Option 2 (Dedicated Profile with Port File Sync)** | Launch Chrome with `--remote-debugging-port=9222 --user-data-dir="<dir>"` and sync `DevToolsActivePort` to default path | 100% Preserved (separate folder) | Isolated profile (requires sign-in to Supabase in debug window) | Low; requires one sign-in to Supabase on debug window. | Secondary |
| **Option 3 (Connector Override via `mcp_config.json`)** | Add custom `chrome_devtools` entry to `mcp_config.json` with `--browserUrl http://127.0.0.1:9222` | 100% Preserved | Isolated or live | Moderate; modifies local tool registration. | Fallback |

---

## 5. PROPOSED SOLUTION & VERIFICATION PROCEDURE

### Recommended Action: Option 1 (Dynamic In-Browser Activation)

This method requires **zero terminations**, preserves all active tabs, extensions, and logins, and directly satisfies the connector's `--autoConnect` requirement:

1. In the already running Chrome window, open a new tab and navigate to:
   ```text
   chrome://inspect/#remote-debugging
   ```
2. Locate the toggle or start button for **Remote Debugging Server** and turn it **ON**.
3. Verify that the debugging port activates (Chrome will write `DevToolsActivePort`).
4. Keep the tab open and navigate to `parent-control-prod` in the Supabase Dashboard.
5. Antigravity Browser Subagent will immediately attach via `chrome-devtools-mcp` `--autoConnect`.

### Alternative Action: Option 2 (Dedicated Debug Profile)

If `chrome://inspect/#remote-debugging` is unavailable or restricted by browser policy:
1. Create a dedicated debug directory: `C:\Users\ASUS\chrome_debug_profile`.
2. Launch a parallel Chrome instance:
   ```powershell
   & "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir="C:\Users\ASUS\chrome_debug_profile"
   ```
   *(This starts cleanly alongside the existing Chrome without interfering with the user's primary profile).*
3. Create a link/copy of the resulting `DevToolsActivePort` file into `C:\Users\ASUS\AppData\Local\Google\Chrome\User Data\DevToolsActivePort`.
4. Log into Supabase Dashboard in that dedicated window.

---

## 6. STRICT READ-ONLY SAFETY ASSERTIONS

* `USER_CHROME_PROFILE_MODIFIED = NO`
* `CHROME_PROCESSES_TERMINATED = NO`
* `COOKIES_SESSIONS_DELETED = NO`
* `CONNECTOR_CONFIGURATION_MODIFIED = NO`
* `SUPABASE_DATABASE_MUTATIONS = NONE`
* `EDGE_FUNCTION_DEPLOYMENTS = NONE`
* `DIAGNOSTIC_COMPLETED = YES`

---

## 7. STOP & APPROVAL REQUEST

In accordance with Phase 3.2.2 Stage 4 instructions, **no connector configuration changes or process modifications have been made**.

Please indicate which connection method you prefer to proceed with (Option 1 recommended, or Option 2). Once approved, we will proceed with the live Dashboard verification.
