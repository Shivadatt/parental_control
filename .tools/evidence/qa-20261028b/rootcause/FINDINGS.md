# Root cause: `apps[13].package_name is not a valid Android package name` (realme RMX2161, Android 12)

Read-only audit, 2026-10-28. No source, migration, hosted config or DB was modified; no `adb`, no Supabase CLI.
All paths relative to `D:\parentcontrol_app`.

Device list used: `.tools/evidence/qa-20261028b/device_packages.txt` — 342 names, all unique, none > 150 chars.
Re-running the server regex over that file yields exactly two rejects: `android` (line 1) and `oplus` (line 340).

---

## 1. End-to-end path, with exact lines

### 1.1 Collection and sort (no filtering)

`android/app/src/main/kotlin/com/parentcontrol/parent_control/InstalledApps.kt`

- `:17-21` — `val packages = try { packageManager.getInstalledPackages(0) } catch (_: Exception) { return emptyList() }`
- `:25` — `val applicationInfo = info.applicationInfo ?: continue` (only skip condition on a package)
- `:31` — `val isSystem = (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0`
- `:35` — `label = label.ifBlank { name }` (a blank/absent label becomes the package name)
- `:41` — `return result.sortedBy { it.label.lowercase() }`

There is no other filter: no launchability query, no `isSystem` exclusion, no regex/format check.
`grep getInstalledPackages` over `android/app/src/main/kotlin` returns this one call site only. `queryIntentActivities`,
`getLaunchIntentForPackage`, `MATCH_LAUNCHER`, `CATEGORY_LAUNCHER` are absent from the Kotlin sources.
`AndroidManifest.xml:25` declares `android.permission.QUERY_ALL_PACKAGES` (with a Play-policy comment at `:21-24`),
so package visibility does not prune the list.

### 1.2 Serialization and HTTP

`GuardianService.kt`

- `:398` — `val installed = InstalledAppsProvider.load(this).take(500)` (342 < 500, so nothing is truncated)
- `:401-412` — builds `{"package_name","label","is_system","is_suspended","version_name"}` per app
- `:413-416` — `client.post("device-telemetry", JSONObject().put("action","apps_upload").put("apps", apps))`

`DeviceHttpClient.kt`

- `:48-50` — body written as UTF-8 JSON
- `:41-46` — `Content-Type: application/json`, `x-device-id`, `x-device-secret`
- `:52-57` — non-2xx reads `errorStream` and throws `DeviceHttpException(readErrorMessage(text, status), status)`
- `:63-68` — a 200 envelope with `ok:false` also throws with `error.message`

Note: the app-level JSON (org.json) preserves all 342 strings verbatim; no normalisation, escaping loss or truncation.

### 1.3 Client error handling and retry

`GuardianService.kt`

- `:418-421` — `catch (error: Exception) { recordError("App list upload failed: ${error.message?.take(200) ?: "network error"}"); false }` — this is exactly the string the child UI shows
- `:552-559` — `recordError` dedupes identical text, persists it (`SecureStore.kt:149-155`), emits `NativeEventBus.emitServiceStatus`, and sets the notification to `guardian_notification_error_text` (`res/values/strings.xml:7`)
- `:561-567` — `clearError` resets store/notification
- `:232` — every successful `pollCommands` calls `clearError()`

Retry gate:

- `:40` — `APPS_UPLOAD_MS = 30 * 60_000L`
- `:82` — `lastAppsUploadAt = 0L`
- `:217-219` — `if (now - lastAppsUploadAt >= APPS_UPLOAD_MS) { if (uploadApps(client)) lastAppsUploadAt = now }`

Because `lastAppsUploadAt` is only advanced on success and starts at `0`, **the 30-minute interval never applies after a failure**:
every `tick()` attempts the upload. `tick()` is scheduled at `:121-126` with `scheduleWithFixedDelay(..., 0L, 10L, TimeUnit.SECONDS)`.
So the intent is ~6 attempts/minute whenever the service's executor actually runs. There is no backoff and no give-up path —
`pollBackoffMs` (`:80`, `:200-211`) applies only to `pollCommands`.

Extra attempts: `apply_policy` success (`:278-279`) and every `sync_policy` command (`:288-291`) call `uploadApps` immediately.

Actual observed cadence is bursty, not a tight loop: the captured child screen
(`.tools/evidence/qa-20261028/device/5HXWRGQ4IFU8WS4T_ui_text.txt`) shows `Last command check 36 min ago` while the service
badge says `Running`; a live `ScheduledExecutorService` cannot fire through device doze/CPU suspend, so attempts only run while
the process is awake. This is consistent with the UI's own stale poll timestamp, not with a stopped service.

### 1.4 Server validation (whole-batch reject)

`supabase/functions/device-telemetry/index.ts`

- `:357-367` — `case "apps_upload"`, `readArray(body.apps, "apps", 500)`, empty array rejected
- `:370-375` — per-index loop; `const packageName = readPackageName(app.package_name, \`apps[${i}].package_name\`)`
- `:376-383` — duplicate detection (`apps contains duplicate package ...`)
- `:384-400` — label (1..100), `is_system`, `is_suspended`, `version_name` (1..64)
- `:410-414` — only after **all** entries validate: `db.rpc("replace_device_apps", {...})`
- `:432-434` — `catch (error) { return errorResponse(error) }`

`supabase/functions/_shared/validation.ts`

- `:8` — comment `// Android application ids: at least two dot-separated segments.`
- `:9` — `export const PACKAGE_RE = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/;`
- `:212-222` — `readPackageName` → `readString(value, field, { min: 1, max: 150 })` then
  `if (!PACKAGE_RE.test(result)) throw new ApiError("validation_error", \`${field} is not a valid Android package name.\`, 400)`

`supabase/functions/_shared/envelope.ts:56-63` — `ApiError` becomes `{ok:false, error:{code:"validation_error", message}}` with HTTP 400.

### 1.5 RPC and storage (never reached on this device)

`supabase/functions/device-telemetry/index.ts:410-426` → `supabase/migrations/20260101000100_functions.sql:654-703`

- `:667-669` — only shape check on `p_apps` (must be a JSON array)
- `:677` — `delete from public.device_apps where device_id = p_device_id;`
- `:679-699` — bulk insert of every row, `where x.package_name is not null`
- `:701-702` — returns row count

`supabase/migrations/20260101000000_core.sql:395-407` — `device_apps.package_name text not null check (char_length(package_name) between 1 and 150)`, unique `(device_id, package_name)` (`:406`). The database itself has **no** format constraint.

Because validation throws before the RPC, no delete and no insert happen. An earlier snapshot would be preserved untouched;
for this device the parent has never had one.

### 1.6 Was any filtering supposed to exclude `android` / `oplus`?

No. Nothing filters them anywhere:

- Kotlin keeps every package with a non-null `ApplicationInfo` (`InstalledApps.kt:25`); `is_system` is metadata only.
- SQL inserts all rows regardless of `is_system` (`functions.sql:683-699`).
- The parent renders system apps and labels them (`lib/features/app_restrictions/app_restrictions_page.dart:359-362`:
  `'${app.packageName}${app.isSystem ? ' · System app' : ''}'`).
- Contract intent is a full inventory: `docs/api-contract.md:491-494` — "absence means the device has not reported and must be
  shown as unknown, never as 'no apps'".

`android` is special-cased in exactly one place, and only to *protect* it from suspension:
`android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyEvaluator.kt:27-29` (`CRITICAL_PACKAGES` contains `"android"`),
consumed at `PolicyApplier.kt:58-70`. That guard is on the enforcement path, not the telemetry path.

There is also an unused Dart upload path (`lib/data/repositories/supabase_device_repository.dart:137-171`) with no callers
(`grep uploadReportedApps` → declarations only). It would send the same unfiltered list. The only runtime uploader is `GuardianService.uploadApps`.

---

## 2. Which package is `apps[13]`?

**Evidence-based result: `android`, with `oplus` as the only alternative.** It cannot be proven to the last step from repository
artifacts, because no app-label snapshot for this device exists in the repo, tests or docs (searched `.tools/evidence` including the
backup drill dump; `parentcontrol_final7.sql:1828-1831` contains only `com.example.*` fixtures).

Reasoning that does not depend on the absolute index:

1. Exactly two entries can fail (`android`, `oplus`), and the server aborts on the **first** bad index (`index.ts:370-375`), so
   `apps[13]` is whichever of the two sorts first by `label.lowercase()` (`InstalledApps.kt:41`).
2. `android` is framework-res; its manifest label is the AOSP `android_system_label` = "Android System" (the device UI is English,
   per every captured screen). So its sort key is `"android system"`.
3. `oplus` is a vendor framework package. Its manifest label is not in the evidence. If it has no label, `InstalledApps.kt:35`
   falls back to `"oplus"`. Any plausible value (`oplus`, `ColorOS`, `系统`, `OPPO ...`) sorts *after* `"android system"`.
4. Therefore `android` is earlier, `apps[13]` = `android`, and `oplus` fails at some index > 13.
   If `oplus` had a null `ApplicationInfo` it would be dropped at `InstalledApps.kt:25`, which still leaves `android` as the sole
   failure at 13.

Residual uncertainty (why this is not called proof): if the `oplus` resource package's label were itself something sorting before
`"android system"` (e.g. `"Android"`, `"Android System"`, or a digit-leading string), the two swap and `apps[13]` would be `oplus`.
Nothing in the repo can rule that out.

**Single observation that settles it:** read the label of package `oplus` (manifest of its APK; obtain the code path from
`dumpsys package oplus`, then `aapt2 dump badging`) and compare with `"android system"`. If it sorts before, `apps[13] = oplus`;
otherwise `apps[13] = android`. Equivalently: capture the 14th element of the label-sorted array on the child. (Not run here: adb
is out of scope for this audit.)

---

## 3. Is `android` expected on API 31, and what is `oplus`?

`android`

- It is the platform's own `framework-res.apk`, registered with package id `android` since API 1. `PackageManager.getInstalledPackages(0)`
  returns installed packages, including system/framework packages; the `MATCH_*` flags only widen (disabled/uninstalled) or filter on
  components. So yes, on API 31 the framework package is a normal member of the returned list.
- It is `FLAG_SYSTEM`, `hasCode=false`, exposes no activities, and its label comes from `framework-res` ("Android System").
  It cannot be launched and cannot meaningfully be "blocked".
- On this exact device it is visible to the querying app: `.tools/evidence/full-qa/phase6b-recording-20261027/device1-realme-dumpsys-package.txt:184`
  lists both `android` and `oplus` in the app's package-visibility state, and `device_packages.txt:1` has it.

`oplus`

- A vendor (ColorOS / realme UI) framework resource package that uses the single-segment name `oplus`. The vendor's framework code
  namespace is visible in the device logs (`oplus.android.OplusFrameworkFactoryImpl`, e.g. `consent-logcat-raw.txt:569`). It is a
  framework-level package, not a user app: no launcher entry, nothing to launch, nothing to suspend.
- It is **not** one of the RRO overlays on this device. Those are the separate multi-segment packages
  `android.frameworkres.overlay.*`, `com.android.*.overlay`, `android.auto_generated_rro_product__` (`device_packages.txt:2-5`,
  and many `*.overlay` entries), which are static overlay APKs and do pass the current regex.
- Exact APK path and manifest label are not in the repository evidence; the description above is of its role, and the only firm
  device fact is that the package manager exposes it to the app.

Android application-id rules: the build tools require at least one dot for *app* ids, but the platform itself uses single-segment
names for framework packages (`android`, and OEM equivalents such as `oplus`). A validator applied to
`PackageManager.getInstalledPackages()` output therefore cannot assume two segments.

---

## 4. Tests: what shapes are asserted, and do they encode the bug?

`supabase/functions/_shared/validation_test.ts:84-98` ("hex, uuid and package validation"):

- `:91` — accepts `com.example.app`
- `:92` — `assertApiError(() => readPackageName("com", "p"), "validation_error", "no dot");`
- `:93` — rejects `1com.example`

`:92` **is** the faulty assumption encoded as a test: it asserts that a single-segment name is invalid. It must change.

Other tests:

- `supabase/functions/_shared/policy_test.ts` uses only `com.example.*` names (`:35-39,105,113,127-176,222`); it does not assert
  single-segment behaviour, but `policy.ts:85` and `:130` reuse `readPackageName`, so policy payloads inherit the same restriction.
- `supabase/tests/40_functions.sql:345-380` exercise `replace_device_apps` with `com.example.kid` / `com.example.new`; the SQL layer
  only enforces length (`core.sql:399-400`). No test asserts the regex at the database level.
- Kotlin: only `android/app/src/test/kotlin/com/parentcontrol/parent_control/policy/PolicyEvaluatorTest.kt` exists. No test covers
  `InstalledAppsProvider`, sorting or package-name shape.
- Flutter: no test asserts the package regex, but the client duplicates it at
  `lib/features/app_restrictions/app_restrictions_controller.dart:22-23`
  (`RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')`), used at `:195,199,224-225,251,277,384`.

So: one Deno test encodes the bug; the SQL/Kotlin/Flutter suites do not.

---

## 5. Retry and impact

Retry behaviour

- One failed attempt per `tick()` (scheduled every 10 s, `GuardianService.kt:121-126`) for as long as the process is awake, forever:
  `lastAppsUploadAt` (`:82`) is only advanced on success (`:218`), so `APPS_UPLOAD_MS` (`:40`) is dead after the first failure.
  No exponential backoff, no attempt cap, no "remember and skip".
- Every `sync_policy` (`:288-291`) and successful `apply_policy` (`:278-279`) adds another attempt.
- Each attempt re-sends all 342 entries; the server validates from index 0 and throws at index 13, returning HTTP 400 with the
  message above; the client stores `App list upload failed: apps[13].package_name is not a valid Android package name.` (`:419`).
- Error state flapping while awake: a successful poll calls `clearError()` (`:232`) every ~20 s (`POLL_INTERVAL_MS`, `:37`), and the
  app upload in the same tick sets it again (`:419` → `:552-559`). The foreground notification is therefore rebuilt several times a
  minute and briefly flips to "Syncing device status with your family. Tap to review." before returning to
  "Background sync needs attention. Tap to review." (`strings.xml:6-7`); each flip rewrites the secure prefs (`SecureStore.kt:149-155`).

Child UI

- Home tab "Background protection" card shows `Service: Running with a visible notification`
  (`lib/features/child/controllers/child_shell_controller.dart:101`) plus the `Last error` row
  (`lib/features/child/tabs/child_home_tab.dart:285,292-296`) with the full server message. Confirmed verbatim in
  `.tools/evidence/qa-20261028/device/5HXWRGQ4IFU8WS4T_ui_text.txt` and `SUMMARY.md:42,69`. The child is told the sync failed but
  is given no action that can fix it (the cause is server-side validation).

Parent UI (what is lost)

- `device_apps` is never populated, so `fetchReportedApps` (`supabase_device_repository.dart:124-133`) returns `[]` and the restriction
  screen shows the "No app snapshot reported" banner (`app_restrictions_page.dart:336-343`) with subtitle
  "This device has not reported its installed apps yet. An empty snapshot is not the same as 'no apps installed'."
  (`app_restrictions_controller.dart:70-80`).
- Consequences: no app rows to toggle (`:353-368`), the allowed-app picker refuses to open
  ("No installed-app snapshot is available, so allowed apps cannot be picked yet.", `app_restrictions_page.dart:526-532`),
  the Instagram shortcut never appears (`app_restrictions_controller.dart:104-105`), `blockedSystemApps` is always empty (`:109-111`),
  and the parent cannot block any app at all from the UI — there is no free-text package entry, only toggles over the snapshot.
- "Request device sync" (`app_restrictions_controller.dart:430-450`) still reports
  "Sync requested. The device will apply its saved policy on its next check-in." and the device's `sync_policy` ack is
  `succeeded` (`GuardianService.kt:283-297` computes status from the policy apply only; `apps_uploaded:false` is merely a result
  field). The parent therefore gets no failure signal; only the child screen and the device's `last_error` do.
- Everything else stays fresh (heartbeat at `GuardianService.kt:214-216`, usage, location), so the device looks healthy while its
  inventory is frozen. Staleness is not surfaced on the parent's app list because there is no snapshot to timestamp.

Policy enforcement: not blocked by this bug (`uploadApps` return value is ignored at `GuardianService.kt:278-280`).

Usage upload: not the observed failure, but it shares the same validator (`index.ts:183-186` → `validation.ts:212-222`) and the
collector has no filter (`UsageReporter.kt:50-53` keeps any package with `totalTimeInForeground > 0`; `:85` sorts). Framework
packages accumulate no foreground time, which is why usage is unaffected here — that is luck, not a guarantee. A single-segment
package with usage time would fail the identical way and block the whole `entries` array.

---

## 6. Minimal correct fix (proposal only, nothing implemented)

### (a) Relax `PACKAGE_RE` to allow single-segment ids — recommended

`supabase/functions/_shared/validation.ts:9` becomes
`/^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$/` (the `+` on the group becomes `*`), and the comment at `:8` is corrected.

Why this is the right minimal fix:

- The rejected strings are **valid package ids emitted by `PackageManager` itself**; the data is not malformed. The validator's
  assumption is the defect (`validation.ts:8-9`).
- One-line server change, no client release, no migration, no data loss, no change to the snapshot contract.
- Fixes the same latent bug in `usage_upload` (`index.ts:183`) and in policy payloads (`policy.ts:85,130`) in one place.

Operational notes: the hosted function must be rebuilt/redeployed; the minified deploy bundle
`.tools/deploy/device-telemetry.ts:1` embeds the identical `ne=/^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/` and would keep
rejecting until regenerated. Also align the Dart duplicate at
`lib/features/app_restrictions/app_restrictions_controller.dart:22-23`, otherwise rules for such packages are silently dropped when a
policy is loaded (`:195,199`) or edited (`:251,277`).

### (b) Client-side filtering of non-launchable/framework packages — not recommended as the fix

Filter `InstalledAppsProvider` (e.g. keep only packages with a `CATEGORY_LAUNCHER` activity, or drop `isSystem`). It would stop this
failure with a client-only release, but it contradicts the stated contract that the snapshot is the installed inventory
(`docs/api-contract.md:491-494`), hides legitimate system packages the parent may want to see, adds PackageManager queries to every
upload, and leaves the server rejecting names the platform legitimately produces — the next OEM single-segment package regresses.
It masks the root cause instead of fixing it. Acceptable only as a temporary client-side mitigation.

### (c) Server-side skip-with-report — second choice

Catch the `readPackageName` failure per index, collect `{index, reason}`, continue, and return
`{accepted, skipped:[...]}`. Pros: no data loss for the rest of the batch, robust to any future bad name. Cons: silently drops
legitimate apps unless the parent surfaces the skip list; requires a contract change, new response field, docs and tests; hides
validation drift; still leaves `usage_upload` and policy validation rejecting the same names. It treats valid ids as errors rather
than fixing the error definition.

### Tests that must change for (a)

1. `supabase/functions/_shared/validation_test.ts:92` — replace the "no dot" reject with accepts for `android` and `oplus`
   (`assertEqual(readPackageName("android","p"), "android", ...)`); keep `:93` (digit start). Add rejects for `".android"`,
   `"android."`, `"android..x"`, `"andro id"`, `"-android"`, and a 151-character name.
2. `supabase/functions/_shared/policy_test.ts` — add one case proving `blocked_packages`/`app_rules` accept a single-segment name
   (policy.ts:85,130), so the relaxation is intentional there too.
3. No SQL, Kotlin or Flutter test changes are required; optionally add a Dart unit test for the relaxed `_packagePattern`.
4. Docs: `docs/api-contract.md:484-494` ("validates package name/size") should state that single-segment framework ids are accepted.

### Security implications of relaxing the regex

Unchanged: 1..150 char cap (`validation.ts:213`, `:209`), fixed alphabet `[A-Za-z][A-Za-z0-9_]*` per segment, no leading dot, no
spaces, `/`, `:`, `-`, no empty segments; batch cap 500 (`index.ts:359`); duplicate rejection (`index.ts:376-383`, `policy.ts:178-186`);
values are only ever used as parameterized data (PostgREST/RPC), never interpolated into SQL or paths.

Changed: identifiers are no longer guaranteed to be two-segment app ids, so a policy could name `android` or `oplus`. That is
already safe on the enforcement path — `android` is in `CRITICAL_PACKAGES` (`PolicyEvaluator.kt:27-29`) and rejected with
"is a protected system component and was not suspended." (`PolicyApplier.kt:58-66`); `oplus` is not listed, so adding it to
`CRITICAL_PACKAGES` is cheap defense in depth (this device is not Device Owner, so `setPackagesSuspended` cannot run at all).
If policy payloads should stay strict, the alternative is to relax only the telemetry path (a `readReportedPackageName`) and keep
`readPackageName` strict for `policy.ts`; that is more code for little gain, since the local guard already covers `android`.

---

## 7. Limitations of this audit

- No `adb`, no device queries, no hosted-function invocation, no DB access were performed; findings are code + existing evidence.
- No label snapshot exists for the 342 packages, so `apps[13]` is derived from the first-invalid-index logic and the two candidates'
  labels, not observed directly (Section 2).
- The exact APK path and manifest label of package `oplus` are not in the repository evidence.
