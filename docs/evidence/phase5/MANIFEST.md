# Phase 5 evidence pack (EVD-01)

Prepared 2026-11-03 by the coordinator. **Not committed** — the owner's Gate A
ruling for this phase was "no commit; leave everything uncommitted", so this
directory is staged-ready evidence, not a delivered commit.

Every artifact here was produced on this machine against the working tree at
branch `main`, HEAD `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` (no commit was
made, so HEAD equals the Phase 4 entry point; the Phase 5 changes live in the
index and the worktree — see `tree-digest.txt`).

## 1. Toolchain actually used (version lines, not assumptions)

| Tool | Version line as printed |
|---|---|
| Flutter | `Flutter 3.44.6 • channel [user-branch]`, framework `ee80f08bbf`, engine hash `d3a3293399556a85388faf8c6f0723a7a5597aa8` |
| Dart | `Dart SDK version: 3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on "windows_x64"` |
| Deno | `deno 2.9.4 (stable, release, x86_64-pc-windows-msvc)` / `v8 15.0.245.2-rusty` / `typescript 6.0.3` |
| Gradle | wrapper, `https://docs.gradle.org/9.1.0/...` in the build output (Gradle 9.1.0) |
| PostgreSQL | `psql (PostgreSQL) 16.9`, server binary in `.tools/pgsql16/pgsql/bin` |

## 2. Commands executed, with exit codes and result lines

Launcher paths are the ones this machine has: FVM Flutter at
`./.fvm/flutter_sdk/bin/`, Deno at
`/c/Users/ASUS/AppData/Local/Microsoft/WinGet/Links/deno`, all from the
repository root (Gradle from `android/`), in Git Bash.

| # | Command | Exit | Result line | Log in this pack |
|---|---|---|---|---|
| 1 | `./.fvm/flutter_sdk/bin/dart analyze` | 0 | `No issues found!` | `logs/p5-coord-dart-analyze-run2.log` |
| 2 | `./.fvm/flutter_sdk/bin/flutter test` | 0 | `00:30 +408: All tests passed!` | `logs/p5-coord-flutter-run2.log` |
| 3 | `deno test --allow-read supabase/functions/` | 0 | `ok \| 150 passed \| 0 failed (1s)` | `logs/p5-coord-deno-full3.txt` (pre-mutation) and `logs/p5-coord-deno-restored.log` (post-restore; both 150/0) |
| 4 | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed` | `logs/p5-coord-deno-sql05.log` |
| 5 | **Negative control (TEST-01)** `deno test --allow-read supabase/functions/device-command/handler_test.ts` with `await assertFamilyParent(...)` commented out in `supabase/functions/_shared/auth.ts:270` | 1 | `FAILED \| 22 passed \| 2 failed` — the two failures are exactly `a parent of another family cannot command this device, and nothing is written` (`handler_test.ts:219`) and `a soft-deleted family is forbidden before the membership read` (`:239`) | `logs/p5-coord-deno-negative.log` |
| 6 | `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` (from `android/`) | 0 | `BUILD SUCCESSFUL in 50s`, `182 actionable tasks: 182 executed` | `logs/p5-coord-gradle-run1.log` |
| 7 | SQL chain, green run 1 (see §3) | 0 | `CHAIN p5rpc_full5 ... EXIT=0 FILES=33 ASSERT_FAILED=0 ERRORS=0` | `logs/p5coord-chain-run5.log` |
| 8 | SQL chain, green run 2 (repeatability, fresh database) | 0 | identical 646-line log, `EXIT=0`, 0/0 | `logs/p5coord-chain-run6.log` |
| 9 | SQL chain, final green run after the test-76 marker and the migration-comment provenance edit | 0 | `CHAIN p5rpc_full9 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0` | `logs/p5coord-chain-run9.log` |
| 10 | **Negative control (SQL-05)** same chain with the lossy RPC variant injected immediately before `tests/76` | 3 | `ASSERT_FAILED=1` at `supabase/tests/76_zone_delete_atomic_rpc.sql:411` — `ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded` | `logs/p5coord-chain-negative3.log` |
| 11 | **Closing chain re-run, after the deliverables and the evidence pack existed**: `PGPORT=55581 bash .tools/p5coord_chain.sh p5rpc_final1 docs/evidence/phase5/logs/p5coord-chain-run10.log` | 0 | `CHAIN p5rpc_final1 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0` | `logs/p5coord-chain-run10.log` |

Rows 5 and 10 are the two deliberate reds: they exist to show that the
green suites in rows 2–4 and 7–9 are red-reachable, not vacuous.

Row 11 exists because the tree changed after row 9. `diff` of
`logs/p5coord-chain-run9.log` and `logs/p5coord-chain-run10.log` shows **exactly 4
changed lines, all of them values the fixtures invent at run time**: line 344 (the
`apply_policy` JSON dump, containing a fresh policy UUID, a fresh command UUID, a
fresh `family_id` and three timestamps) and lines 378, 388, 418 (three
`safety-alerts:<family uuid>` channel names). No assertion, count, NOTICE position
or exit code differs. So row 11 reproduces row 9's result on bytes that are
random by design, which is what "the delivered tree is green" means here.

## 3. The SQL chain command

`supabase/tests/README.md` documents one invocation. It was executed verbatim,
against a disposable cluster (`postgres -D .tools/pgdata_p5rpc -p 55581`,
created by `initdb` in `.tools/pgsql16`, never the hosted project), into a
**freshly created database every time** — the chain is not re-runnable in one
database (`tests/74` re-inserts fixed `auth.users` ids). The driver script is
`.tools/p5coord_chain.sh`, a coordinator scratch harness, not a deliverable; it
builds exactly the documented 33 `-f` arguments:

```bash
PGPORT=55581 bash .tools/p5coord_chain.sh <dbname> <logfile>          # green
PGPORT=55581 bash .tools/p5coord_chain.sh <dbname> <logfile> <pre-76-file>   # negative control
```

Counts measured on the green runs (row 9 on database `p5rpc_full9`, row 11 on
`p5rpc_final1`): **33 `-f` entries** (14 migrations + 19 test files, incl. the two
local stubs), `EXIT=0`, `ASSERT_FAILED=0`, `ERRORS=0`, `LINES=648` on both, and on
each resulting database: 19 public tables, 66 public indexes,
`webrtc_signals_session_sequence_uniq` present once, and

```text
{postgres=X/postgres,service_role=X/postgres}   -- proacl of public.delete_safe_zone_audited(uuid,uuid)
```

i.e. `anon` and `authenticated` hold no execute privilege at all.

## 4. Gradle JUnit XML (row 6)

Six result classes, 39 tests, 0 failures, 0 errors, 0 skipped — copied verbatim
into `gradle-junit/` from `build/app/test-results/testDebugUnitTest/` (this
project's Gradle build directory is the repo-root `build/`, not `android/app/build/`):

| Class | tests | failures | errors |
|---|---|---|---|
| `AudioAssistanceRecreationTest` | 8 | 0 | 0 |
| `AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 |
| `AudioAssistanceStartGateTest` | 4 | 0 | 0 |
| `AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 |
| `EnforcementModeTest` (KOT-02) | 4 | 0 | 0 |
| `policy.PolicyEvaluatorTest` | 13 | 0 | 0 |
| **total** | **39** | **0** | **0** |

## 5. Tree digest basis (`tree-digest.txt` and `tree-digest-final.txt`)

Named exactly, because a bare hash is not reproducible without it. Two digests are
packed: the **baseline** frozen mid-phase over the tree the suites tested, and the
**final** digest taken as the last action of the phase over everything this phase
delivers.

- **Path set** = union of `git diff HEAD --name-only` and
  `git ls-files --others --exclude-standard`, deduplicated and C-sorted.
  Baseline: **57** paths (`tree-digest.txt`). Final: **69** paths
  (`tree-digest-final.txt`), i.e. the union re-measured at close (73 paths) minus
  the four exclusions below.
- **Per-file hash** = `sha256sum` over the **working-tree bytes as stored on
  disk** — not the git blob, not the staged content, not a diff rendering.
- **Aggregate** = `sha256sum` over the sorted `<hash> *<path>` lines:
  - baseline → `4ee854c2119eee1264f38e41dd575634d97c7e396e2ceb4a8cbcfed3205725e0`
  - final → `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b`
  Both re-verified: `sha256sum <the packed table file>` prints the same value,
  because each packed table *is* those lines (`cut -c67- file` recovers the path
  list; `xargs -a list sha256sum | sha256sum` recovers the aggregate).
- **Exclusion rule (final digest only)** — four paths are deliberately outside the
  hashed set, and this is a rule, not an omission:
  `tree-digest.txt`, `tree-digest-final.txt` (a digest table cannot appear in the
  set it hashes), `MANIFEST.md` and `docs/implementation/phase-5-report.md` (both
  **quote the aggregate value**; including them makes the number depend on its own
  text and no fixed point exists). `phase-5-report.md` §2a states the same rule.
- **The final aggregate moved four times during the phase** — `0eebf9e7…`, then
  `6f4336ed…`, then `102d2701…`, then the published `2bd6b310…`. Every move was a
  documentation edit made after the previous reading (two doc corrections, then one
  hash-provenance correction, then the line-ending finding plus the matrix header);
  the path set never changed and each step was `diff`-checked to contain only hash
  changes. The 57-path baseline keeps its original value on purpose — it describes
  the tree the suites ran against, which is a historical fact, not a stale number
  to be corrected.
- **CRLF caveat, re-measured rather than inherited** — `core.autocrlf=true` and
  there is no `.gitattributes`, so git normalises on check-in. Counting CR bytes
  per file (`wc -c` vs `tr -d '\r' | wc -c`) over the 69 hashed paths gives **7**
  files that actually contain CRLF in the worktree: the six `gradle-junit/*.xml`
  and `docs/implementation/api-contract.md`. `git ls-files --eol` reports all seven
  as `i/lf w/crlf`, so for those seven the digest pins bytes that **differ from the
  blob git would store**. Every other hashed path is LF on disk and identical on
  both bases. Consequence for the owner: a plain `git add` of this tree turns those
  seven into LF, so re-verifying `tree-digest-final.txt` after a fresh checkout
  must expect a different aggregate — registered as **GAP-EOL-01** in
  `docs/implementation/phase-5-open-gaps.md` §1.
  An earlier revision of this manifest asserted "`LF will be replaced by CRLF` was
  printed for 15 of these paths". **That 15 could not be reproduced under any
  measurement tried** — CR-byte count over the baseline 57 = 1; paths reported
  `i/lf w/lf` (the ones git warns about at a future checkout) = 56 of 57; CR-byte
  count over the final 69 = 7. The number is withdrawn; the bullets above are
  counted, not quoted.
- **Scope caveat** — each digest covers *changed* paths only, **not** a
  whole-repository hash and not a content-addressed git tree id.

## 6. What is deliberately NOT in this pack

- No `.env`, key, token, JWT, service-role key, or device credential — and none
  appears in any packed file. Re-scanned on the finished pack (all 20 files) for
  `eyJ[A-Za-z0-9_-]{20,}`, `service_role_key`, `SUPABASE_KEY`, long `Bearer `
  strings and `password`, case-insensitive: **zero matches in the pack**. The same
  patterns run over the five deliverables and `deployment/manifest.md` return two
  lines, both of which are this scan describing itself
  (`phase-5-owner-decision-log.md:137`, `phase-5-report.md:506-507`) — pattern
  names, not values.
- Not the whole `.tools/` directory: it holds the 200 MB PostgreSQL binary, the
  running data directories, and dozens of intermediate probes. Only the twelve
  logs named above and the two digest tables were selected.
- No build outputs (`build/`, `android/app/build/`) beyond the six JUnit XML
  files, and no APK (Gate B — device work — was not authorised this phase).
- The disposable databases (`p5rpc_full*`, `p5rpc_neg*`) and
  `.tools/pgdata_p5rpc` are left in place for re-inspection, on a cluster the
  coordinator started. They are removed, not committed:
  `pg_ctl -D .tools/pgdata_p5rpc stop -m fast` then delete that directory.

## 7. Re-verifying this pack

From the repository root:

```bash
cd docs/evidence/phase5
find gradle-junit logs tree-digest.txt tree-digest-final.txt -type f | sort | xargs sha256sum > /tmp/p5-check.txt
sha256sum -c /tmp/p5-check.txt          # 20 lines, every one must print OK
```

The §8 table is the same 20-file listing with byte sizes; a mismatch between a
table row and a fresh `sha256sum` means the packed file was touched after this
manifest was written. `tree-digest-final.txt` also self-verifies: `sha256sum <
tree-digest-final.txt` prints the aggregate it contains.

## 8. Pack contents

**18 files are ordinary artifacts; 2 of them are digest tables that hash to their
own content** — `tree-digest.txt` prints the 57-path baseline aggregate
(`4ee854c2…`) and `tree-digest-final.txt` prints the 69-path closing aggregate
(`2bd6b310…`; §5 records the three earlier readings it superseded). That is why
the SHA-256 column for those two rows equals the aggregate quoted in §5.

| Path | Bytes | SHA-256 |
|---|---|---|
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceRecreationTest.xml` | 1609 | `d5b6b9780edae3ce5e734b0c479c6812e79af797193f2e813b261ff37c9c7a1a` |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest.xml` | 1361 | `c5b9f04c46a69bc6988080f1f65afd61b55d5a7188f69079908807068e1dd574` |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStartGateTest.xml` | 976 | `27487a227ba7f89ab530d65435cabc2a75406e405b7677154b0cb60115a52b5d` |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest.xml` | 824 | `15068c2ca6b08597ab549b0b37c2e95df43bc30b8f24f9b1669997b0a50f1d60` |
| `gradle-junit/TEST-com.parentcontrol.parent_control.EnforcementModeTest.xml` | 945 | `9e8330d8bdc6883457f8f073033b62506a2c5aef89e14007f23a2f3d37e90467` |
| `gradle-junit/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml` | 2195 | `0e5521555b86161b4ecdbfccc86f334dde347256bbc56ec2afbae32d6e2c8c41` |
| `logs/p5-coord-dart-analyze-run2.log` | 48 | `9fa0431d7192e9d5a61e6274a72d6561a2554228ba491434b05498e59c614982` |
| `logs/p5-coord-deno-full3.txt` | 19608 | `9ebdaedc6b9031d4a5c0a3cd57cd5b05ddc8dcf6d30afe294b1c3a5fbec5d789` |
| `logs/p5-coord-deno-negative.log` | 5672 | `d087186c2a67f3d2115115e209d21ddc63dbe0288859c4dfff4fd636079313ad` |
| `logs/p5-coord-deno-restored.log` | 18609 | `b5589dade24e2bd5ab2f9000cf3057ac6f7cd8e84b4ceb54fa66f7fdad4a24b0` |
| `logs/p5-coord-deno-sql05.log` | 2645 | `8c0e23d7ce45d507e5e184d759debf47834e89f59cb718c86ef422908b6a7295` |
| `logs/p5-coord-flutter-run2.log` | 61521 | `ca2462ccdb8a23db62205678709b1dad3ad9809785608e1f11b667238e5332f6` |
| `logs/p5-coord-gradle-run1.log` | 30685 | `6d14ac08b60553ca64f1a6b48072508dcf4c2c8c4f26df10be36e577a046eba0` |
| `logs/p5coord-chain-negative3.log` | 16844 | `e914ecaaed261bd87c3fc31c28772634d66c9c19161131dfe3cc8aaba4bb6080` |
| `logs/p5coord-chain-run10.log` | 16388 | `4638ad087731369d232512f3f62bac6b25b6b971376b0b190e55201d1f990744` |
| `logs/p5coord-chain-run5.log` | 16316 | `f22aefcdaa17666b7116930f81bbd9fcdb38adb15cf2b3088ae7ac0be6dfbc6d` |
| `logs/p5coord-chain-run6.log` | 16325 | `23c127e039967692b24202bbf5598c114334b54c8e218d7b67292fb4e853840f` |
| `logs/p5coord-chain-run9.log` | 16388 | `4978d306e5458116a3211ad4e9bef4d0d9691381fd70c279aeba12b03397664f` |
| `tree-digest.txt` (57-path baseline) | 6462 | `4ee854c2119eee1264f38e41dd575634d97c7e396e2ceb4a8cbcfed3205725e0` |
| `tree-digest-final.txt` (69-path close) | 8171 | `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` |

### 8a. The two documents that cannot be in this table

`MANIFEST.md` (this file) and `docs/implementation/phase-5-report.md` are excluded
from the 69-path digest because both quote its aggregate (§5). Their hashes at the
moment this manifest was finalised:

| Document | Bytes | SHA-256 |
|---|---|---|
| `docs/implementation/phase-5-report.md` | 49273 | `541628bb96e3a26ca17dd39ef19dbb20ef845d263d254200424bd80ecabd8dfc` |
| `docs/evidence/phase5/MANIFEST.md` | (self-referential — run `wc -c < MANIFEST.md` and `sha256sum MANIFEST.md`; a file cannot print its own hash) | — |

The other four deliverables (`phase-5-regression-matrix.md`,
`phase-5-open-gaps.md`, `phase-5-owner-decision-log.md`,
`phase-5-deployment-readiness.md`) are inside the digest; their per-file lines were
re-checked against the packed `tree-digest-final.txt` and all four match.
