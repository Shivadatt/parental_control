# Supabase Dashboard Read-Only Audit — 2026-10-28

**Audit timestamp:** 2026-10-28 18:42 IST (13:12 UTC)
**Method:** In-app browser only (`browser-use` MCP: navigate, accessibility snapshot, rendered-DOM text reads). No Supabase CLI. No SQL executed. No schema, policy, function, setting or project created/changed/deleted.
**Sign-in status:** Signed in. Dashboard session active; project pages load normally (Table Editor, Database, Policies, Edge Functions).
**Evidence limitation:** The in-app browser reported no visible viewport (`NATIVE_BROWSER_VIEWPORT_UNAVAILABLE`), so no screenshots were captured. All evidence below comes from page titles plus the accessibility tree / rendered text, which is why some data is quoted instead of imaged.

---

## 1. Project identification

Local expected config (`D:\parentcontrol_app\.tools\live_config.env`) contains `SUPABASE_URL` whose host is `https://<ref>.supabase.co`, giving project ref **`hhqgreaoqulmfwfwarhc`**. The anon key was not read out, printed, or captured.

Dashboard project list (single personal org, Free plan):

| Project name | Ref | Region | Compute | Matches repo ref |
|---|---|---|---|---|
| `parent-control-prod` | `hhqgreaoqulmfwfwarhc` | `ap-northeast-2` | NANO | Yes |

- Total projects visible in the organization: **1**. Org header states "1 project".
- **No extra project exists**, and none was created during this audit.
- `docs/backend.md` independently names the same ref (`hhqgreaoqulmfwfwarhc`, `parent-control-prod`, Seoul `ap-northeast-2`, NANO), consistent with the dashboard.

**Data API exposure (observed, informational):** Data API integration is installed; Settings shows "2 of 3 schemas exposed" but **"0 of 19 tables exposed"**. Every table card on Database > Policies carries an "API DISABLED" badge. No settings were changed.

---

## 2. `public.remote_sessions`

- Listed in Database > Tables: **17 columns, 25 rows (est.), 128 kB, Realtime Enabled**.
- Definition read via Table Editor > `remote_sessions` > Definition (read-only SQL definition, no SQL execution).

### Columns

| Column | Type | Constraints |
|---|---|---|
| `id` | uuid | PRIMARY KEY, NOT NULL, default `gen_random_uuid()` |
| `family_id` | uuid | FK → `families(id)` ON DELETE CASCADE, NOT NULL |
| `device_id` | uuid | FK → `devices(id)` ON DELETE CASCADE, NOT NULL |
| `parent_user_id` | uuid | FK → `profiles(id)` ON DELETE CASCADE, NOT NULL |
| `child_user_id` | uuid | FK → `profiles(id)` ON DELETE CASCADE, NOT NULL |
| `kind` | text | NOT NULL, CHECK `kind in ('audio','video')` |
| `status` | text | NOT NULL, default `'requested'::text`, CHECK `status in ('requested','accepted','active','declined','ended','expired','failed')` |
| `requested_at` | timestamptz | NOT NULL, default `now()` |
| `accepted_at` | timestamptz | NULL |
| `started_at` | timestamptz | NULL |
| `ended_at` | timestamptz | NULL |
| `expires_at` | timestamptz | NOT NULL (no default) |
| `ended_by` | uuid | FK → `profiles(id)` ON DELETE SET NULL, NULL |
| `ended_reason` | text | NULL, CHECK `ended_reason is null or char_length(ended_reason) <= 200` |
| `consent_recorded` | bool | NOT NULL, default `false` |
| `session_nonce` | uuid | NULL |
| `created_at` | timestamptz | NOT NULL, default `now()` |

### Constraints (exact names)

- `remote_sessions_pkey` — PRIMARY KEY (`id`)
- `remote_sessions_device_id_fkey` — FK `device_id` → `devices(id)` ON DELETE CASCADE
- `remote_sessions_ended_by_fkey` — FK `ended_by` → `profiles(id)` ON DELETE SET NULL
- `remote_sessions_family_id_fkey` — FK `family_id` → `families(id)` ON DELETE CASCADE
- `remote_sessions_child_user_id_fkey` — FK `child_user_id` → `profiles(id)` ON DELETE CASCADE
- `remote_sessions_parent_user_id_fkey` — FK `parent_user_id` → `profiles(id)` ON DELETE CASCADE
- `remote_sessions_status_check` — CHECK status in the seven allowed values
- `remote_sessions_ended_reason_check` — CHECK ended_reason null or ≤ 200 chars
- `remote_sessions_kind_check` — CHECK kind in ('audio','video')

### Indexes (exact names, all non-unique btree)

1. `remote_sessions_family_idx` — (`family_id`, `requested_at` DESC)
2. `remote_sessions_child_status_idx` — (`child_user_id`, `status`)
3. `remote_sessions_device_status_idx` — (`device_id`, `status`)
4. `remote_sessions_expires_idx` — (`expires_at`)

Plus the implicit primary-key index behind `remote_sessions_pkey`.

### Concurrency guard: ABSENT

- There is **no partial unique index** (e.g. unique on `device_id` where status in `('requested','accepted','active')`) and **no unique constraint** other than the primary key.
- Database > Triggers lists 6 triggers project-wide; **none on `remote_sessions`**.
- Database > Functions (schema `public`) lists **13 functions** and does **not** contain `request_remote_session`.
- The `(device_id, status)` index above is a plain lookup index, not a uniqueness/concurrency guard.

### RLS

- RLS is **enabled** on `remote_sessions` (page offers "Disable RLS"; table badge shows API disabled).
- Policies: exactly **one**

| Policy name | Command | Applied to |
|---|---|---|
| `remote_sessions_select_participants` | SELECT | `authenticated` |

- **No INSERT, UPDATE, or DELETE policy exists** on `remote_sessions`; all writes therefore require the service role (i.e. the Edge Function), not a user JWT.

---

## 3. `public.webrtc_signals`

- 7 columns, 387 rows (est.), 376 kB, Realtime Enabled.
- Columns: `id` (uuid PK), `session_id` (uuid, FK → `remote_sessions(id)` ON DELETE CASCADE, NOT NULL), `from_user_id` (uuid, FK → `profiles(id)` ON DELETE CASCADE, default `auth.uid()`), `kind` (text, CHECK `in ('offer','answer','ice')`), `payload` (jsonb, CHECK `octet_length(payload::text) <= 16384`), `created_at` (timestamptz, default `now()`), `sequence` (bigint, generated always as identity, NOT NULL).
- Index: `webrtc_signals_session_sequence_idx` — btree (`session_id`, `sequence`). PK index `webrtc_signals_pkey`.
- RLS enabled; two policies: `webrtc_signals_insert_participant` (INSERT, `authenticated`) and `webrtc_signals_select_participant` (SELECT, `authenticated`).

---

## 4. Edge Function `remote-session`

- Present in Edge Functions (9 functions total: `auth-bootstrap`, `cron`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`).
- **Deployed:** yes. Overview states "remote-session details loaded. Last deployed **2 days ago**" (i.e. approximately 2026-10-26, relative to this audit). The dashboard exposes **no numeric version and no absolute deploy timestamp**; the list view also shows only "2 days ago".
- Runtime facts shown: "There have been **1,003 invocations** since last deploy and no errors"; 0 invocations in the selected 1-hour window.
- Configuration observed (read-only): "Verify JWT with legacy secret" setting is described as recommended OFF with JWT + custom auth logic; it was **not** toggled.

### Deployed source (Code tab, read-only)

- Deployed file `index.ts` is a **minified bundle, 12,848 characters** (dashboard editor model), i.e. esbuild output, not the TypeScript source.
- Actions present (`case"..."`): **`request`, `pending_child`, `respond`, `start`, `end`, `ice`**.
- **`session_state` is NOT present.** The substring `state` does not appear anywhere in the deployed bundle.
- No `request_remote_session`, no `.rpc(`, no `session_in_progress`, no advisory-lock reference.

The `request` case is a **plain insert** after device lookup; excerpt as shown in the deployed bundle:

```js
case"request":{ ... a=await N(n,s.user.id,d), c=new Date,
  l=await n.from("remote_sessions").insert({family_id:a.family_id,device_id:a.id,
  parent_user_id:s.user.id,child_user_id:a.child_user_id,kind:o,status:"requested",
  requested_at:c.toISOString(),expires_at:new Date(c.getTime()+X).toISOString(),
  consent_recorded:!1}).select(w).single();
```

There is no pre-insert query for existing open sessions and no error mapping for a conflict, so two concurrent `request` calls can both insert.

### Hosted vs local `supabase/functions/remote-session/index.ts`

| Aspect | Hosted (deployed bundle) | Local `index.ts` (12,903 chars TS source) |
|---|---|---|
| `request` implementation | Direct `insert` with `status:"requested"` | `db.rpc("request_remote_session", …)` + `mapRequestRpcError` |
| `session_state` action | Absent (no `state` substring at all) | Present (case at line 142, device-authenticated poll) |
| Guard helper | None | Imports `./guard.ts` (`mapRequestRpcError`, `sessionStatePayload`) |
| `session_in_progress` handling | Absent | Present via error mapping |
| Source form | Minified bundle | TypeScript with `_shared/*` imports |

Local guard artefacts (not deployed): `supabase/functions/remote-session/index.ts`, `guard.ts`, `guard_test.ts`, and migration `supabase/migrations/20261028000100_remote_session_concurrency.sql` (advisory-lock RPC `public.request_remote_session`, service-role only, raises `session_in_progress`).

**Hosted code differs from the local function: yes, materially.**

---

## 5. Verdict

**A hosted migration + Edge Function redeploy is required for the approved concurrency guard: YES.**

Evidence:

1. The hosted DB has **no** `request_remote_session` function (Database > Functions lists 13, none matching), **no** partial unique index on `remote_sessions`, and **no** trigger enforcing one open session per device.
2. The deployed `remote-session` bundle **still performs a plain insert** for action `request` and contains **no** conflict handling.
3. The deployed bundle **lacks the `session_state` action** that the local function and Android foreground service depend on.
4. The local migration `20261028000100_remote_session_concurrency.sql` and the local `index.ts`/`guard.ts` are **not reflected** in the hosted project.

No changes were made; deploying is left to the approved implementation step.

---

## 6. BLOCKED / not inspected

- **BLOCKED (by instruction):** SQL Editor was not opened to execute anything, and no SQL was run. Schema was read from Table Editor > Definition (read-only generated DDL) instead. Anything only obtainable by querying `pg_catalog` (e.g. exact index definitions on system-generated indexes, `pg_stat` details) was not inspected.
- **Not available:** exact deploy timestamp and numeric function version — the dashboard only renders "2 days ago" and no version field.
- **Not available:** screenshots (`NATIVE_BROWSER_VIEWPORT_UNAVAILABLE`); evidence is structural/textual.
- **Not inspected:** function logs, realtime/pg_net settings, auth providers, secrets, cron schedules — outside the requested scope.
- **No permission or login block was encountered.**

---

## 7. Sanitized evidence list

Pages observed (titles / key sections), no secret-bearing URLs, no keys:

1. `supabase.com` — marketing home page (pre-navigation, not signed-in view).
2. Dashboard → Organizations — "Your organizations"; one personal org, "Free Plan · 1 project".
3. Projects list (`parent-control-prod` only) — card shows ref `hhqgreaoqulmfwfwarhc`, `ap-northeast-2`, `NANO`; "1 project".
4. Project → Table Editor landing — "Create a table", "No recent items yet".
5. Project → Database → Tables — "Database Tables", 19 tables; `remote_sessions` 17 columns / 25 rows / Realtime Enabled; `webrtc_signals` 7 columns / 387 rows.
6. Database → Tables → `remote_sessions` — Columns view (17 columns).
7. Table Editor → `public.remote_sessions` → **Definition** — read-only SQL: table DDL + 4 named indexes (no unique/partial index).
8. Table Editor → `public.webrtc_signals` → Definition — table DDL + `webrtc_signals_session_sequence_idx`.
9. Database → Policies (schema public; filtered `remote_sessions`) — RLS enabled; single policy `remote_sessions_select_participants` SELECT authenticated; "API DISABLED" badge.
10. Database → Policies (all 19 tables) — `webrtc_signals_insert_participant` INSERT, `webrtc_signals_select_participant` SELECT.
11. Database → Functions — 13 public functions listed; `request_remote_session` absent.
12. Database → Triggers — 6 triggers; none on `remote_sessions`.
13. Edge Functions — 9 functions; `remote-session` updated "2 days ago".
14. Edge Functions → `remote-session` → Overview — "Last deployed 2 days ago"; "1,003 invocations since last deploy".
15. Edge Functions → `remote-session` → Code — deployed minified `index.ts` (12,848 chars); actions request/pending_child/respond/start/end/ice; no `session_state`; plain insert in `request`.
16. Edge Functions → `remote-session` → Settings — "Verify JWT with legacy secret" option present (untouched).
17. Integrations → Data API → Settings — "0 of 19 tables exposed", "2 of 3 schemas exposed" (read-only).

Local files referenced for comparison (unchanged): `D:\parentcontrol_app\supabase\functions\remote-session\index.ts`, `guard.ts`, `D:\parentcontrol_app\supabase\migrations\20261028000100_remote_session_concurrency.sql`, `D:\parentcontrol_app\docs\backend.md`.
