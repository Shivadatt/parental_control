# Audit brief — shared rules for all subagents

Project: `D:\parentcontrol_app` (Flutter 3.44.6 + Kotlin Android + Supabase).
Master prompt: full technical/functional/UI audit vs AirDroid Parental Control.
This file is the shared contract. Each subagent writes **only** its own assigned
file under `audit/_work/`. Do not create or edit anything else.

## Hard rules

1. **AUDIT ONLY.** Never modify `lib/`, `android/`, `android_dpc/`, `supabase/`,
   `test/`, `scripts/`, `docs/` or any tracked file. Do not run formatters,
   codemods, migrations, builds that change state, or `git` write commands.
2. **Never run the Supabase CLI** (`supabase …`) for any reason. Hosted Supabase
   facts come only from the Web Dashboard (only the dashboard subagent touches it).
3. No secrets: never print or copy anon/service keys, JWTs, TURN passwords,
   passwords or `.env` values. Refer to them by name only (`SUPABASE_ANON_KEY`,
   `TURN_PASSWORD`, …).
4. Read-only shell is allowed: `ls`, `find`, `grep`, `rg`, `git log/show/diff`,
   `sed -n`, `wc`. Do not execute app code or tests that mutate data.
5. Do not infer a feature works because a screen, table or service exists.
   Distinguish: code evidence / automated-test evidence / runtime evidence /
   assumption. Mark anything unverified as such.

## Required evidence format

Every factual claim cites `path/to/file.ext:LINE` (line number verified by reading
the file). Runtime claims cite a file under `docs/evidence/stage8/` or a report
under `docs/`. A claim without a citation is an assumption and must be labelled
`(assumption)`.

## Status vocabulary (use exactly these, never percentages)

- `FULLY IMPLEMENTED — VERIFIED`
- `IMPLEMENTED — PARTIALLY VERIFIED`
- `PARTIALLY IMPLEMENTED`
- `UI ONLY`
- `BACKEND ONLY`
- `CODE EXISTS — NOT TESTED`
- `BROKEN`
- `MISSING`
- `BLOCKED — ACCESS REQUIRED`
- `NOT APPLICABLE`

Definitions:
- FULLY IMPLEMENTED — VERIFIED: complete end-to-end path exists **and** there is
  runtime or integration evidence, not just unit tests.
- IMPLEMENTED — PARTIALLY VERIFIED: full path exists; only unit/static evidence,
  or runtime evidence covers only some subfeatures.
- CODE EXISTS — NOT TESTED: reachable code, no test and no runtime proof.
- UI ONLY / BACKEND ONLY: one half exists, the other is missing.
- BROKEN: path exists but is known to fail (cite the evidence).

## Feature inventory row format (inventory subagents)

One markdown table row per **subfeature**, exactly these 12 cells in this order:

`| F-<area><nn> | <AirDroid category> | <subfeature> | <UI route/screen or —> | <Flutter files:line> | <Kotlin/service/permission or —> | <table/function/RLS or —> | <Connected? yes/partial/no> | <tests: path or —> | <runtime evidence or —> | <STATUS> | <gap + risk + priority P0–P3> |`

Do not wrap cells across lines. Keep cells under ~300 chars; details go in prose
below the table. End the file with a count block:

```
counts: fully_verified=N partially_verified=N partial=N ui_only=N backend_only=N
code_untested=N broken=N missing=N blocked=N not_applicable=N
```

## Output shape (every subagent)

```
# <role> findings
## 1. Scope actually covered (files/dirs read; anything skipped and why)
## 2. Findings (tables + prose, each claim cited)
## 3. Evidence gaps / BLOCKED items
## 4. One-paragraph summary a reviewer can trust
```

Report honestly. If a tool cannot reach something, write `BLOCKED — …` rather
than guessing.
