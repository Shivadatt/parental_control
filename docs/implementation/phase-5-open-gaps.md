# PHASE 5 — open gaps

Severity vocabulary is the one this project has used since Phase 2:

| Level | Meaning |
|---|---|
| **P0** | A live defect in production affecting users or their data **now**. |
| **P1** | Blocks release / controlled QA cannot start without it. |
| **P2** | Correctness, safety or evidence is real but scoped; work around it for now. |
| **P3** | Housekeeping, hygiene, CI friction. |

Nothing in Phase 5 is **P0**, and that statement is itself limited: it holds
because **nothing this phase produced is deployed**. The moment the unapplied
SQL/Edge Function set goes to the hosted project, these rows must be re-graded
against a live system, not against this tree.

---

## 1. Register

| ID | Severity | Gap | Status today | Who can close it | Evidence / pointer |
|---|---|---|---|---|---|
| **HOST-01** | **P1** | The Phase 1 + Phase 5 SQL surface (`20261030000100`, `20261030000200`, `20261030000300`, `20261103000100`) has **never been applied** to the hosted project, so no hosted policy, index, grant or function can be asserted. | **OPEN — NOT FIXED, and explicitly not reported as fixed.** | Owner (dashboard SQL Editor), then a read-only verification pass. | `deployment/manifest.md` §0/§0.1/§4; `_work/p4-hosted.md` (2026-10-30 read-only audit); `phase-5-deployment-readiness.md` §2 |
| **GATE-B-01** | **P1** | Zero device execution this phase: force-stop, recents-swipe, permission revocation, notification visibility, child-consent and mic foreground/background legs are all unverified on hardware — including the new Kotlin `EnforcementMode` path. | **STOPPED by owner ruling (#9).** NOT RUN everywhere in the matrix. | Owner authorises AND-01 + a paired QA parent/child device. | `phase-4-android-validation-plan.md` (still the executable plan); `phase-5-regression-matrix.md` §4 |
| **DUR-01** | **P2** | The evidence pack and every report are **uncommitted**, so all of it exists only on this workstation. `.tools/` and `*.log` are gitignored, so the raw run logs named in the report are not even trackable — only the 12 files deliberately copied into `docs/evidence/phase5/logs/` survive. | **BLOCKED by ruling #10** (which also conflicts with ruling #12, see CONF-01). | Owner: one commit, or an explicit acceptance that the evidence is workstation-only. | `.gitignore:16,22` (measured with `git check-ignore -v`); `docs/evidence/phase5/MANIFEST.md` §6 |
| **CONF-01** | **P2** | Two owner rulings conflict: #12 says commit the selected evidence, #10 says commit nothing. | **OPEN — escalated.** The stricter prohibition was obeyed and the conflict recorded rather than resolved by the coordinator. | Owner tie-break. | `phase-5-owner-decision-log.md` §12 |
| **SQL-06h** | **P2** | The approved wording makes signaling replay protection **conditional** on `webrtc_signals_session_sequence_uniq` existing on the hosted database. The duplicate pre-check has now been written (`deployment/manifest.md` §2) but has **never been run against hosted data**. | **OPEN** — half-closed by documentation; the hosted fact is unknown. | Owner runs one read-only `SELECT` in the dashboard. | `20261030000200:478-486`, NOTICE `:492`, contract `api-contract.md` §5, `tests/75` |
| **PERF-01h** | **P2** | The faster sweep shape is asserted by behaviour (same deleted row set, same batch order, repeatable) on a disposable PostgreSQL 16. **No hosted `EXPLAIN (ANALYZE, BUFFERS)` exists**, and the numbers quoted in the migration comment are Phase 4 local-probe numbers. | **OPEN by design** — the comment now says so instead of implying otherwise. | Owner, post-apply, read-only. | `20261030000300` header (provenance paragraph), `_work/p4-perf01.md` §2-§3, `tests/74` §5 |
| **SQL-04r** | **P2** | Bounded execution was **refused**, so `run_retention_sweep()` is still one transaction walking the entire backlog. A large enough backlog still cannot be swept in one call: it either commits fully or rolls back fully, and the next call repeats the whole scan. | **STOPPED (owner ruling #3).** Not a defect Phase 5 may fix. The migration comment states the limitation plainly rather than hiding it. | Owner, if the backlog ever requires it. | `20261030000300` header ("Not true today, and not achievable inside a function at all") |
| **SCHED-01** | **P2** | **No scheduler is installed anywhere**, so nothing enforces the retention windows on the hosted project. But the *code path exists and is wired*: `supabase/functions/cron/index.ts:84` calls `expire_abandoned_sessions`, and `:106-107` calls `run_retention_sweep`, treating a missing function as a clean skip (`:109-112`). Whether any hosted timer points at that function is **unknown** — no hosted observation since 2026-10-30. | **STOPPED** for installation; **OPEN** as a hosted-fact question. | Owner decision, after HOST-01 — read `phase-5-deployment-readiness.md` §4 first (unbounded execution against an unknown backlog size). | brief §6; `deployment/manifest.md` §1; `cron/index.ts:84,106-112` |
| **GAP-RS-01** | **P2** | Since the handler switched to the RPC, three outcomes are **unreachable from the `delete_zone` path**: `audit_failed` compensation, `zone_restored`, `delete_unaudited`. `delete_zone_atomicity.ts` (and its 8 tests) still exist and are still exercised, but only through the extracted dependency seams. | **KNOWN RESIDUAL, disclosed.** The module was kept deliberately as the reviewed fallback; deleting it was not approved. | Reviewer decision at Gate A. | `family-admin/index.ts:21,173-177,195,214-262`; `delete_zone_atomicity.ts` exports; `delete_zone_atomicity_test.ts` 8 cases |
| **GAP-DEP-01** | **P3** | `family-admin/index.ts` still imports the `ZoneSnapshot` **type** from the unwired module, so a future reader can mistake the module for live code. | **OPEN (cosmetic).** Left as-is because removing the import means touching the reviewed handler again. | Next Gate A pass. | `index.ts:21`, `:195` |
| **CHAIN-01** | **P3** | The 33-file SQL chain is **not re-runnable into one database** (`tests/74` re-inserts fixed `auth.users` ids → `users_pkey` duplicate on a second pass), so every run needs `createdb` first. CI cannot reuse a fixture database. | **OPEN, documented.** Harness handles it; nothing to fix in-product. | Whoever builds a CI runner. | `docs/evidence/phase5/MANIFEST.md` §3; `.tools/p5coord_chain.sh` header |
| **CI-01** | **P3** | There is **no CI at all**: all five suites were run by hand on one Windows workstation with FVM Flutter, WinGet Deno, a repo Gradle wrapper and a private PostgreSQL 16.9 in `.tools/`. Green means "green here". | **OPEN** — out of scope for every phase so far. | Owner. | `MANIFEST.md` §1 (version lines), §7 (re-verification commands) |
| **GAP-EV-05** | **P2** | **Phase 4's delivered-tree digest was computed before the last write of two of its own files.** `.tools/p4-digest-perfile-delivered.txt` has mtime `11-03T11:55`; `phase-4-report.md` `11:56:23`, `phase-4-regression-matrix.md` `11:56:45`. So "digest taken after the four deliverables were written" (§2a of that report) is false by 1–2 minutes, and two of its 29 hashes do not match the delivered bytes. **Count at close: 4 of 29 hashes differ** — the 2 above are Phase 4's own ordering defect; `supabase/tests/README.md` (chain 31→33 `-f` entries) and `docs/implementation/phase-4-owner-approval-register.md` (dated KOT-02 corrections, mtime `11-03T17:03:47`) are **expected Phase 5 edits**, not Phase 4 defects. | **OPEN against Phase 4** (Phase 5 will not rewrite another phase's document body); attributed with measurements, and Phase 5's own digest is taken as the **last** action instead. | Phase 4 owner decision, or accept the correction note in `phase-5-report.md` §1a. | `phase-5-report.md` §1a; `ls -l` mtimes; line-ending hypothesis tested and rejected (`tr -d '\r'` == `sha256sum` for all 4 drifted paths); re-hash basis and aggregate in `phase-5-report.md` §1a |
| **GAP-EV-06** | **P3** | `_work/p4-enf-residual.md:14` shows a runnable-looking `git show HEAD:lib/.../app_restrictions_controller.dart`; the path contains an ellipsis and fails if pasted. Also 13 other ellipsis-style placeholder paths (`android/.../GuardianService.kt`) survive in the older docs. | **OPEN (scratch notes, not deliverables).** Recorded so nobody executes a citation blindly. | Doc-hygiene pass. | mechanical scan of 284 path references inside the changed files |
| **GAP-ENV-01** | **P3** | The disposable PostgreSQL cluster is **still running** (`.tools/pgdata_p5rpc`, port 55581) with the phase's databases `p5rpc_full5/6/9`, `p5rpc_final1`, `p5rpc_neg*` inside it, plus older `.tools/pgdata_p5s`, `pgdata_p5shape`. | **INTENTIONAL, disclosed** — kept for re-inspection, and they are disposable by construction (no hosted data, no credentials). | Whoever cleans up: `pg_ctl -D .tools/pgdata_p5rpc stop -m fast`, then delete the data dirs. | `MANIFEST.md` §6 |
| **IDX-01** | **P3** | The redundant non-unique `webrtc_signals_session_sequence_idx` (from `20260101000000_core.sql`) is still present by design, because the Phase 1 migration stayed additive — the note saying so is `20261030000200:497-499`. | **OPEN — owner-approved cleanup decision needed**, not a Phase 5 action. | Owner. | `20261030000200_phase1_authorization.sql:497-499` |
| **HOST-02** | **P3** | Phase 5 made **no** hosted observation at all — not even read-only. The newest hosted fact this project holds is the 2026-10-30 dashboard audit, which is now four days old and pre-dates Phase 4 and 5 entirely. | **OPEN, disclosed as staleness** rather than dressed up as a current observation. | Owner: one read-only dashboard pass. | `phase-5-owner-decision-log.md` §11; `_work/p4-hosted.md` |
| **GAP-EOL-01** | **P3** | `core.autocrlf=true` with **no `.gitattributes`** anywhere in the repo. Measured on the 69 delivered paths: 7 contain CRLF in the worktree and are stored as `i/lf w/crlf` (the six `docs/evidence/phase5/gradle-junit/*.xml` and `docs/implementation/api-contract.md`), so the moment the owner runs `git add` the committed blob for those 7 **will not equal the bytes the digest pins**. This is a commit-time hazard for whoever verifies `tree-digest-final.txt` after a checkout, not a defect in the work. | **OPEN — nobody acted**, because adding `.gitattributes` or renormalising files is a repo-wide change the owner has not approved and this phase commits nothing. | Owner: decide `.gitattributes` (and possibly `git add --renormalize`), or accept that re-verification must happen on this workstation's bytes. | `git config core.autocrlf` → `true`; `ls .gitattributes` → absent; per-file `wc -c` vs `tr -d '\r' \| wc -c`; `git ls-files --eol` on all seven; `MANIFEST.md` §5 |

---

## 2. What Phase 5 considers **closed**

Only claims with an executed artifact are listed as closed; the rest stay above.

| Item | Closed by | Scope limit, stated |
|---|---|---|
| TEST-01 (untested handler layer) | `handler_test.ts` 24 green + negative control N1 red at exactly two authorization cases | tested against the injected fake, not against a live PostgREST |
| KOT-02 (untestable duplicated enforcement rule) | `EnforcementMode.kt` + 4 JVM tests, both call sites delegating | JVM only; **no device verification** (GATE-B-01) |
| SQL-05 (delete/audit two-transaction window) **in code** | `20261103000100` + `tests/76` 773 lines + N2 red | locally only; **hosted still has the window** — see HOST-01 |
| PERF-01a (shape + honest comment) | shape adopted, `tests/74` §5 behavioural assertions now execute | behaviour, not timing; local, not hosted |
| SQL-06 wording | applied + every citation re-opened | the hosted index's existence remains unknown (SQL-06h) |
| PRIV-01 / WORD-02 | 17 Deno + 11 Flutter disclosure cases | widget tests are render assertions, not device behaviour |
| GOV-02 | ratified with a measured consumer list | ratification authorises nothing new |
| SWP-01 comment over-claim | corrected in place with provenance | — |
| `tests/74` §5 dead assertions | fixed (two syntax errors) | the pre-fix "PASS" logs are now known to be non-evidence |

## 2a. Closed earlier and still closed (spot-checked this phase)

`tests/71` rollback-privilege coverage (extended, not weakened); `tests/75`
duplicate-case guard; the `not_family_parent`/42501 shared error mapping
(`_shared/error_mapping_test.ts`, 13 cases); the device-command per-device active
session guard; the abandoned-session sweep expression index.

---

## 3. Severity roll-up (composition, not just a count)

| Level | Count | Which | Blocking what |
|---|---|---|---|
| **P0** | 0 | — | nothing, *because nothing is deployed* |
| **P1** | 2 | HOST-01, GATE-B-01 | controlled QA start and any release claim |
| **P2** | 8 | DUR-01, CONF-01, SQL-06h, PERF-01h, SQL-04r, SCHED-01, GAP-RS-01, GAP-EV-05 | evidence durability + every hosted-truth claim |
| **P3** | 8 | GAP-DEP-01, CHAIN-01, CI-01, GAP-EV-06, GAP-ENV-01, IDX-01, HOST-02, GAP-EOL-01 | hygiene and reproducibility |
| **total open rows** | **18** | | |

Composition matters more than the total: **12 of the 18 open rows can only be
closed by the owner** (apply migrations, authorise devices, decide the commit,
break the CONF-01 tie-break, run the read-only hosted checks, authorise a
scheduler, approve the index cleanup, approve the Phase 4 correction, clean the
disposable cluster, decide the `.gitattributes` / line-ending policy). The
remaining 6 are either accepted by design (the refused
bounded execution, the deliberately kept fallback module) or CI/housekeeping work
nobody has scoped yet.

One severity call is a judgement, recorded as such: **HOST-02 is graded P3**
because "no fresh hosted observation" is an absence of evidence rather than a
defect — but if a reviewer prefers to read it as P2 (it is the reason SQL-06h and
PERF-01h cannot be closed), that reading is defensible and changes no action.

---

## 4. What Phase 5 did **not** examine

Stated so that absence of a row is not mistaken for a clean bill of health.

- Anything hosted: no dashboard session, no read-only query, no settings check
  (HOST-02). Every hosted statement in the five deliverables is explicitly marked
  unverified.
- Android device behaviour of any kind (GATE-B-01), including the enforcement-mode
  refactor that this phase did change in Kotlin.
- Real-time subscription behaviour under the new scope payload (the PRIV-01 change
  touches only the account retention path).
- Backup/restore, PITR, storage, auth-provider configuration, rate limiting,
  egress/secrets rotation — never in scope in any phase.
- The `cron` Edge Function's **schedule**, in either direction. Its two call sites
  were read and are quoted in SCHED-01 (`:84`, `:106-112`); nothing was verified
  about whether anything invokes it on the hosted project, because that needs a
  hosted observation this phase did not make.
- Load/performance under concurrency: no load test was run in any phase.
