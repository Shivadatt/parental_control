# Phase 9.12: Owner Decision Packet & Authorization Boundary Review

**Document class:** Owner Decision Packet & Authorization Boundary Review.  
**Task Reference:** Phase 9.12 (Owner Decision Packet & Authorization Boundary Review).  
**Repository:** `D:\parentcontrol_app` (`main`, HEAD `a2faa5fb70f84638359154c68d19ce304fadab36`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) — **NOT ACCESSED** in this phase.  
**Date:** 2026-11-06.  
**Predecessors:** [`docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md`](phase9-11-evidence-contradiction-and-decision-readiness-report.md) (contradictions C-01…C-41, decision items J-1…J-11 at `:245-255`) and [`docs/phase9-10-consolidated-release-readiness-governance-blocker-review.md`](phase9-10-consolidated-release-readiness-governance-blocker-review.md) (blocker register §F, verdict §H, authorized/not-authorized §I).  
**Release Verdict Inherited:** **NOT RELEASE READY — NO-GO FOR GENERAL RELEASE / GO FOR LOCAL VERIFICATION BASELINE ONLY.**  
**Companion Documents:**
- Canonical register (root): [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md)
- Canonical register (byte-identical mirror): [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md)
- Hosted-state record: [`docs/supabase-hosted-state-verification-2026-11-05.md`](supabase-hosted-state-verification-2026-11-05.md)
- Approval records: [`docs/dec-12-screen-time-bedtime-decision.md`](dec-12-screen-time-bedtime-decision.md), [`docs/dec-13-device-owner-decision.md`](dec-13-device-owner-decision.md), [`docs/dec-14-fcm-owner-decision.md`](dec-14-fcm-owner-decision.md), [`docs/dec-15-website-filtering-owner-decision.md`](dec-15-website-filtering-owner-decision.md), [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md)
- Blocker/gate registers: [`phase-9-open-gaps.md`](../phase-9-open-gaps.md), [`docs/implementation/phase-9-release-readiness.md`](implementation/phase-9-release-readiness.md), [`phase-8-android-qa-report.md`](../phase-8-android-qa-report.md)

**Strict Governance Invariant:** Zero implementation, zero hosted Supabase access or mutation, zero Firebase provisioning, zero APK builds, zero Gradle tasks, zero ADB commands, zero device or emulator operation, zero audio/TURN/WebRTC testing or configuration, zero scheduler activation, zero historical-report rewriting, zero governance-register modification, and zero agent-executed Git state mutation occurred during this pass. The single file created by this pass is this document.

**Method and its limits.** Every statement below is a restatement of repository evidence with a `file:line` reference, or a directly measured read-only command result. Nothing in this packet is an independent re-verification of historical hosted or device state: the last recorded hosted observation is 2026-11-05 (`docs/supabase-hosted-state-verification-2026-11-05.md:7`, final catalogue read `2026-11-05T07:47:58Z`), and no live inspection occurred on 2026-11-06. Choices are listed **only** where they already exist in repository text; where they do not, the brief records `NO EVIDENCED OPTION SET` rather than inventing one. **No approval may be inferred from silence, from a recommendation, or from this packet.**

---

## A. Executive Owner Summary

Phase 9 governance work is documentation-mature and release-immature. Sixteen owner decisions are registered: seven are recorded APPROVED, two are PENDING/BLOCKED P1 release blockers, and seven are carried forward without any owner ruling. This packet puts **eleven** specific, independent questions to the owner, each derived one-to-one from the Phase 9.11 §J items (J-1…J-11 at [`docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md:245-255`](phase9-11-evidence-contradiction-and-decision-readiness-report.md#L245)).

The five things the owner most needs to know before answering:

1. **The two hard blockers are owner-held, not agent-held.** DEC-02 (hosted migrations/preflights/functions) and DEC-03 (Android APK/ADB/75-row QA) are both recorded `PENDING OWNER AUTHORIZATION` / `STRICTLY PROHIBITED — BLOCKED` ([`phase-9-owner-decision-register.md:171`](../phase-9-owner-decision-register.md#L171), [`:172`](../phase-9-owner-decision-register.md#L172), `:289`, `:290`). A repository-wide sweep found **no document anywhere** that grants either one; every grant-shaped hit is a negation, a future condition, a gate statement, or an unchecked sign-off box (Phase 9.11 C-35, `:98`; [`docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md:126`](evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md#L126)).
2. **DEC-02 is the only decision with a live security consequence.** Because Migrations 1–4 are unapplied, the direct client `DELETE` privilege on `public.safe_zones` "is **still live on hosted** as of 2026-11-05" (register [`:322`](../phase-9-owner-decision-register.md#L322)), and `phase-9-open-gaps.md:10` states that "no remediation may be claimed until authorised hosted deployment plus post-deployment verification actually occur."
3. **Documentation completeness is not functional proof.** All 75 QA rows remain `NOT RUN` (mechanically re-counted: 75 row identifiers, 75 rows ending `NOT RUN`; see §I). Candidate microphone-foreground-service status, human audibility, endurance, and relay capability are all recorded `NOT TESTED` / `NOT VERIFIED` / `ABSENT` (Phase 9.11 §D `:131`).
4. **The repo contains mutually inconsistent current-tense statements** that the owner must normalize: two different blocker sets and two severities for the same blockers (C-36, `:99`), four stale "remain PROPOSED" lines in otherwise-superseded decision documents (C-30/C-31/C-32, `:93-95`), and six HEAD hashes with four different staged-file counts each phrased as current (C-40, `:108`).
5. **One item has no owning decision at all.** No DEC covers TURN/relay infrastructure (`F4`) — Phase 9.11 §H item 9 records "**Owner must open a decision (DEC-17 or equivalent)**" because "the register currently has no decision covering relay infrastructure" (`:221`).

---

## B. Current Release Verdict

**Verdict: NOT RELEASE READY — NO-GO FOR GENERAL RELEASE. GO FOR LOCAL VERIFICATION BASELINE ONLY.**

- Formal gate line in the canonical register: "Gate A CLEARED (local baseline only) | Gate B BLOCKED | Gate C BLOCKED | Gate D NO-GO … **NO-GO FOR GENERAL PRODUCTIO[N RELEASE]**" ([`phase-9-owner-decision-register.md:412`](../phase-9-owner-decision-register.md#L412)).
- Phase 9.10 verdict: "**NOT RELEASE READY.**" with the repository status "**NO-GO FOR GENERAL RELEASE / GO FOR LOCAL VERIFICATION BASELINE**" ([`docs/phase9-10-…:8`](phase9-10-consolidated-release-readiness-governance-blocker-review.md#L8), [`:277`](phase9-10-consolidated-release-readiness-governance-blocker-review.md#L277)).
- Phase 9.11 conservative verdict: [`docs/phase9-11-…:228`](phase9-11-evidence-contradiction-and-decision-readiness-report.md#L228).
- Standing release rule: "General production release is **strictly prohibited until Gates B and C have independently passed**" ([`docs/implementation/phase-9-release-readiness.md:286`](implementation/phase-9-release-readiness.md#L286)).

This packet does not change the verdict. It cannot: a verdict moves only when an owner ruling is recorded and the work that ruling authorizes has actually been executed and verified.

---

## C. Eleven Independent Decision Briefs

Each brief ends **Status: `AWAITING OWNER DECISION`**. Nothing below is approved, recommended as decided, or treated as permission.

### C.1 J-1 — DEC-02: Hosted migrations, preflights and Edge Function deployment

**Decision ID:** J-1 (owner packet) → registered decision **DEC-02 — Hosted Migration & Function Deployment Readiness**.

**Current recorded status:** `PENDING OWNER AUTHORIZATION` / `STRICTLY PROHIBITED — BLOCKED`, severity **P1 (Release Blocker)**, "Closes GAP HOST-01" ([`phase-9-owner-decision-register.md:30`](../phase-9-owner-decision-register.md#L30), [`:171`](../phase-9-owner-decision-register.md#L171), [`:198`](../phase-9-owner-decision-register.md#L198), [`:289`](../phase-9-owner-decision-register.md#L289)). Both sign-off boxes are unchecked (`[ ] DEC-02`, `:118` and `:151`) with the pending option marked.

**Background and exact evidence references.** The register states DEC-02 "registers **exactly three things**: execution of 5 Preflight Queries, application of Migrations 1–4, and deployment of the Edge Functions `account`, `family-admin`, `device-command`" (`:313`) and that the scope "remains **0% executed**" (`:313`).
- *Four unapplied migrations*, each verified absent by object probe on 2026-11-05: Migration 1 `20261030000100_abandoned_session_sweep.sql` (`public.expire_abandoned_sessions(...)` ABSENT), Migration 2 `20261030000200_phase1_authorization.sql` (`private.is_parent_of_family(uuid, uuid)` ABSENT), Migration 3 `20261030000300_retention_sweep.sql` (`public.run_retention_sweep()` ABSENT), Migration 4 `20261103000100_zone_delete_atomic_rpc.sql` (`public.delete_safe_zone_audited(...)` ABSENT) — register `:317-320`; corroborated at `docs/supabase-hosted-state-verification-2026-11-05.md:84-87` and `:179`.
- *Directory arithmetic:* "`supabase/migrations/` holds **14** files (measured: `ls supabase/migrations | wc -l` → `14`); **9** consistent with live state (baseline 7 + Stage 7 2), **4** proven not applied, and `20261028000100_remote_session_concurrency.sql` is **NOT VERIFIED (indistinguishable)**" (register `:337`). "**Stage 7 and DEC-02 are disjoint sets**" (register `:331`; two applied migrations belong to Stage 7, `:324`, `:328-329`).
- *Five unexecuted preflights:* "Preflight Queries 1–5: **not executed**" (register `:322`); "Five read-only preflight queries are fully prepared and validated locally, but **none have been executed against hosted**" (register `:201`). They exist **only as markdown text** at `docs/implementation/phase-9-release-readiness.md:71-136` (Query 1 at `:74`, 2 at `:84`, 3 at `:103`, 4 at `:114`, 5 at `:124`) and as a differently-named set at `docs/implementation/phase-8-deployment-log.md:61,75,87,104,113`. Measured: `find . -iname '*preflight*.sql' -not -path './.git/*'` → **0 files**; `find supabase -name '*.sql'` yields 14 migrations and 20 `.sql` test files, none preflight.
- *Function deployment scope and the 3/4/9/10 counts:* 3 = DEC-02 target functions (register `:30`, `:199`, `:313`); 4 = Stage 3 playbook deploy steps, whose 4th is a **redeploy** of already-hosted `remote-session` (`docs/implementation/phase-9-release-readiness.md:152-168`, step 4 at `:166`); 9 = historically deployed inventory, "newest deployment timestamp **2026-10-27T18:07:08Z**" (register `:322`; `docs/supabase-hosted-state-verification-2026-11-05.md:137`); 10 = on-disk function directories (measured: `ls -1 -d supabase/functions/*/ | grep -v _shared | wc -l` → `10`). Phase 9.11 classifies this as apparent, class-resolvable conflict C-17 (`:75`).
- *Missing migration ledger:* `docs/supabase-hosted-state-verification-2026-11-05.md:147` — "The Overview tile reads **LAST MIGRATION: "No migrations"** … the `supabase_migrations` schema **does not exist** … migrations here were applied through the SQL Editor, which never writes that schema." Consequence recorded as C-22: "**There is no tracked migration ledger.** Future DEC-02 applies must be verified by **object probes**, not by CLI/`db push` history; re-applying an already-applied file would not be caught."
- *Playbook is frozen:* "**FROZEN ON STANDBY**. No step may be executed until explicit written approval for DEC-02 and DEC-03 is recorded" (`docs/implementation/phase-9-release-readiness.md:67`).

**Available choices (existing evidence only).** (a) **Approve in full** — the three registered items as scoped. (b) **Refuse / continue to withhold** — the state recorded today (`:289`). (c) **Scope-limit** — the register's own reconciliation language anticipates partial rulings; the four migrations, five preflights and three functions are separately enumerated objects (`:313`, `:317-320`, `:322`), so a ruling may name a subset. (d) **Approve the read-only preflights only** — they are characterized as "Read-Only" (`docs/implementation/phase-9-release-readiness.md:71`) and would produce the evidence base for (a)/(c) without any write. No fifth option exists in the repository.

**Technical and operational consequences.** Full or partial approval ends the "0% executed" state and makes Gate C closable; it requires an operator window against the production project, a post-apply verification pass, and (per C-22) an object-probe verification method because history bookkeeping is absent. Withholding keeps the standby playbook intact and costs nothing operationally. Approving preflights only yields current hosted facts without mutation but also closes nothing.

**Security, privacy, reliability and release impact.** Security: with Migrations 2 and 4 unapplied, "Direct client `DELETE` privilege on `public.safe_zones` remains live on hosted PostgreSQL … **OPEN — HARD RELEASE BLOCKER**. Withheld under DEC-02 negative boundary" (`phase-9-open-gaps.md:28`), and the audit-coverage defect is documented at `phase-9-open-gaps.md:50` (§3.1 begins at `:47`): "If the audit insert failed, the deletion remained committed without audit coverage". Privacy: zone data is child-location-adjacent; the exposure is a client-writable deletion path, not a disclosure path. Reliability: Migration 1 (`expire_abandoned_sessions`) and Migration 3 (`run_retention_sweep`) remain absent, so abandoned-session expiry and retention sweeping stay manual (retention is DEC-05 Choice B on-demand only; see §D). Release: GAP HOST-01 **BLOCKS GATE C & D** (`phase-9-open-gaps.md:166`); GATE-HOST-01 appears in the DEC-12/9.3 gate diagrams (`docs/dec-12-screen-time-bedtime-decision.md:182`, `docs/phase9-3-dec12-approval-governance-consolidation.md:154`). Withholding is explicitly not a mitigation: `phase-9-open-gaps.md:10` — "What DEC-02 protects is the boundary against unauthorised hosted mutation … It does not revoke, mitigate or remediate the privilege."

**Dependencies on other decisions.** J-9 (apply mechanism) is a prerequisite for any approval to be executed safely. J-11 (preflight artifacts) determines whether preflights are transcribed from markdown or run from files. DEC-14 delivery behavior, Realtime (`docs/api-contract.md:524` "Hosted Realtime behavior is **NOT TESTED**") and Stage-8 defect `F1` fixes depend on deployment: the fix "exists at HEAD but is not deployed (deployment not authorised)" (`docs/evidence/stage8/f1-expiry-12-16Z.txt:29-30`; `docs/runtime-failure-analysis.md:49`). **DEC-02 approval does not touch DEC-03, DEC-05, DEC-13 safe-exit or any client code.**

**What approval would authorize.** Only what the register registers: execution of the 5 named preflight queries, application of the 4 named migrations, and deployment of the 3 named Edge Functions to `hhqgreaoqulmfwfwarhc` — plus the verification needed to prove those specific objects exist and behave as intended, if the owner scopes it in.

**What approval would explicitly NOT authorize.** No APK builds, no Gradle, no ADB, no device or emulator operation, no QA-row execution (DEC-03 owns those — "Approval of DEC-01 or DEC-05 never implies approval of DEC-02 or DEC-03", register `:292`, restated `:10`, `:18`). No Flutter/Dart/Kotlin/TypeScript source changes. No scheduler, `pg_cron`, recurring trigger or webhook (DEC-05 Choice B, register `:291`). No Firebase/FCM provisioning or secret creation (DEC-14 records "**Implementation Authorization:** **NONE.**", `docs/dec-14-fcm-owner-decision.md:9`). No TURN provisioning (J-4 — no decision covers it). No Device Owner/Managed Mode work (DEC-13 + GATE-EXIT-01). No rewriting of historical evidence. No new canonical tracker. Approval of DEC-02 also does not convert DEC-12…DEC-16 architecture approvals into implementation permission (register `:377`; `docs/dec-15-…:44`, `docs/dec-16-…:46`).

**Recommended questions for the owner.** (1) Full, refused, or subset? If subset, which of the four migrations, and does that subset change the `safe_zones` exposure? (2) Which apply path, given no migration ledger — SQL Editor with object probes, or CLI with a ledger that has never existed in this project? (3) Who executes, and against which project, with what rollback expectation? (4) Should preflights run first as a read-only gate on the write step? (5) What post-apply verification is required before GAP HOST-01 may be re-labeled? (6) Does `20261028000100_remote_session_concurrency.sql` (NOT VERIFIED — indistinguishable) need resolution first?

**Status: `AWAITING OWNER DECISION`**

### C.2 J-2 — DEC-03: Android APK, ADB and 75-row QA authorization

**Decision ID:** J-2 → **DEC-03 — Android QA Hardware Execution Readiness**.

**Current recorded status:** `PENDING OWNER AUTHORIZATION` / `STRICTLY PROHIBITED — BLOCKED`, **P1 (Release Blocker)**, "Closes GAP AND-01" ([`phase-9-owner-decision-register.md:31`](../phase-9-owner-decision-register.md#L31), `:172`, `:290`, `:351-355` "DEC-03 — UNCHANGED"). Both sign-off boxes unchecked (`:122`, `:155`). Gate B BLOCKED (`:248`).

**Background and exact evidence references.** Scope as registered: "Building APKs, connecting via ADB, and executing the 75-row QA matrix on physical Realme 7 (`RMX2161`, API 31) and Pixel 9a AVD (`emulator-5554`, API 37). Closes GAP AND-01" (`:31`). Ten privacy invariants are listed at `:71-78`, of which "ADB connectivity status: Reported strictly as **UNKNOWN**" (`:71-78`).
- *Matrix state (measured this pass):* `grep -cE '^\| \*\*[A-Z]+-[0-9]+\*\* \|' phase-8-android-qa-report.md` → **75**; with `NOT RUN` in the status column → **75**. Documented at `phase-8-android-qa-report.md:12` ("**75 / 75 Rows Strictly NOT RUN (100% Unexecuted)**"), `:227`, `:322`, `:410`, and mirrored at `phase-9-regression-matrix.md:12` ("**75/75 QA ROWS NOT RUN (DEC-03 HARD STOP)**") and `:128`.
- *Counting discrepancy already on record:* matrix prose says P0 18 / P1 38 / P2 18 / P3 1 (`phase-8-android-qa-report.md:223-226`, `:322`); a mechanical recount of the `Risk Level` column yields P0 18 / **P1 39** / **P2 17** / P3 1. The register documents both and concludes "**all 75 rows are NOT RUN under either counting**" (`:355`).
- *Policy precedent:* "## 9. AND-01 / Gate B — device execution · **decided: no device execution** … **No device execution yet.** … **STOPPED.** No APK built … no `adb` run against QA hardware" (`docs/implementation/phase-5-owner-decision-log.md:101-107`), cited as "Ruling #9" at `phase-8-android-qa-report.md:40`.
- *Explicit non-grant:* "**Gate Enforcement:** Owner Decision DEC-03 has not been granted. Gate B remains formally **CLOSED**" (`phase-8-android-qa-report.md:408`); "No active, written owner instruction authoring DEC-03 has been issued" (`:30-32`); "Android Gate B (DEC-03) was **NOT authorized**; zero debug or release APKs compiled" (`docs/evidence/phase7/MANIFEST.md:61`, `docs/evidence/phase8/MANIFEST.md:69`).
- *Verified non-grant sweep:* repo-wide case-insensitive search pairing DEC-03 with approved/granted/authorized yields only negations, future conditions ("(When DEC-03 Authorized)"), unchecked boxes (`docs/implementation/phase-9-release-readiness.md:213`) and PENDING/BLOCKED headers; 155 explicit non-grant statements. **No grant exists.**

**Available choices (existing evidence only).** (a) **Approve full matrix execution.** (b) **Refuse / continue to withhold** — today's state (`:290`). (c) **Scope-limit by device/time budget and defect-triage path** — the phrasing Phase 9.11 §H item 2 uses for the next DEC-03 ruling (`:213`). (d) **Approve preparation only** — what is already permitted today: "Preparation of the execution plan and pass/fail criteria" (`docs/phase9-11-…:213`). No option in the repo authorizes partial pass claims: rows are `NOT RUN`, and the historical refusal precedent is recorded as a full stop.

**Technical and operational consequences.** Approval consumes physical hardware time (Realme 7 `RMX2161` + Pixel 9a AVD), produces per-row verdicts that can contradict earlier dated observations (C-01/C-15 pattern), and opens a defect-triage queue (the audio ladder gaps are the largest block). Withholding keeps Gate B BLOCKED and every functional gap open; it costs no time and breaks nothing. A scoped approval still requires an artifact identity discipline: Phase 9.11 records that build attribution is the missing property in C-01 ("A cannot be attributed to a build"), C-06 ("4007/4008 provenance is external and unevidenced") and C-07 ("Installation of *the candidate-fix* build: NOT ESTABLISHED").

**Security, privacy, reliability and release impact.** Reliability: the entire device-facing reliability case is unverified on a release candidate — candidate FGS runtime `NOT TESTED`, human audibility `NOT TESTED / NOT VERIFIED`, 5-minute and 15-minute locked-screen endurance `NOT TESTED`, long-duration locked-screen reliability `NOT VERIFIED`, `MIC-01` and `MIC-02` open (Phase 9.11 §D `:131`; `docs/mic_only_test_report.md:166`, `:167`, `:118`; `docs/runtime-mic-test-report.md:126`, `:175`). Privacy: ten registered invariants are unverified on live devices (`phase-9-open-gaps.md:29`), and the mic privacy indicator is recorded "FAIL — not observed … ROM-level (ColorOS)" (`docs/mic_only_test_report.md:90`) with QA row `PERM-05` NOT RUN (`phase-8-android-qa-report.md:286`). Release: GAP AND-01 is a "**CRITICAL RELEASE BLOCKER** … **BLOCKS GATE B & D**" (`phase-9-open-gaps.md:29`, `:167`) and Gate D depends on B and C (`docs/implementation/phase-9-release-readiness.md:286`).

**Dependencies on other decisions.** Independent of DEC-02: DEC-03 authorizes no hosted SQL, no migration, no Edge Function deployment. Some QA rows are *unexecutable regardless of DEC-03* because they need hosted state (e.g. `NET-06` TURN credential refresh is "BLOCKED: no relay deployed", `phase-8-android-qa-report.md:280`; Stage 7 rows blocked by hosted RLS, `docs/stage7_two_device_end_to_end_report.md:353`). J-6 (audio acceptance plan) is scoped under DEC-03 execution. DEC-13 Managed-Mode QA depends additionally on GATE-EXIT-01 (J-5). `dec-13-…:86`: "Approving Option B does **not** authorize … DEC-03 device QA testing"; `dec-15-…:367`: "It does **NOT** authorize hardware testing, ADB commands, or APK builds (gated by DEC-03)."

**What approval would authorize.** APK builds, ADB connectivity, and execution of the 75-row controlled matrix on the two named targets, with evidence capture per the existing conventions, scoped however the owner scopes it.

**What approval would explicitly NOT authorize.** Any hosted migration, preflight execution, or Edge Function deployment (DEC-02's exclusive scope). Any scheduler or `pg_cron` activation (DEC-05 Choice B, `:291`). Any TURN provisioning or secret creation (J-4). Any Firebase/FCM provisioning (DEC-14 `:9`). Any Device Owner provisioning or Managed Mode release (DEC-13 + GATE-EXIT-01). Any rewrite or supersession claim about historical evidence reports — new runs are new dated records, not corrections of old ones. Any claim that historical `PASS` rows constitute repeatable QA (Phase 9.11 invariants; "historical observation ≠ repeatable QA").

**Recommended questions for the owner.** (1) Approve, refuse, or scope to a device/time budget — and if scoped, which subsystems first (18 SESS/LIFE rows? 7 PERM rows?)? (2) Which artifact is the release candidate — a build compiled from `a2faa5f`, and must its SHA-256 and versionCode be recorded before any row runs? (3) Do endurance legs get their own isolated acceptance criteria (5 m / 15 m), separate from mixed legs? (4) Will a named human listener sign audibility rows, and on which device? (5) What is the defect-triage path when a row fails — fix-and-rebuild, or record-and-stop? (6) Which rows are legitimately deferred as blocked-on-DEC-02/J-4 rather than counted as failures?

**Status: `AWAITING OWNER DECISION`**

### C.3 J-3 — Release severity: P0/P1 terminology and authoritative blocker set

**Decision ID:** J-3 — severity lexicon and blocker-set normalization (Phase 9.11 C-36, `:99`).

**Current recorded status:** No owner ruling exists on this question. It is not itself a DEC; it is an unresolved governance conflict between live documents. The register asserts "P1 release blockers remain **exactly GAP HOST-01 (DEC-02)** and **GAP AND-01 / GATE-B-01 (DEC-03)**" (`:412`, same wording `:279`), while DEC-15 and DEC-16 documents name a broader **P0** set.

**Background and exact evidence references.**
- Register model (two P1 blockers): `:412`, `:171`, `:172`; gap register rows `phase-9-open-gaps.md:28` (HOST-01, P1) and `:29` (AND-01/GATE-B-01, P1).
- Broader P0 model: `docs/dec-15-website-filtering-owner-decision.md:117` "Focus engineering & testing on **P0** release blockers (**keystore, migrations, Android QA, DEC-12**)", `:186` "closing the active **P0** release blockers"; `docs/dec-16-screen-mirroring-recording-owner-decision.md:138` and `:268` use the same P0 framing.
- Severity definitions **do** exist (this corrects the assumption that none does): `phase-8-open-gaps.md:35-40` defines P0 as "Critical active defect … actively compromising live user data … Emergency Hotfix / Immediate Stop" and P1 as "Release Blocker / Controlled Validation Blocker … Hard Gate"; mirrored at `docs/implementation/phase-7-open-gaps.md:30-36` and `phase-6-open-gaps.md:12-19`. A third P0/P1/P2/P3 usage exists as *row risk levels* inside the QA matrix (`phase-8-android-qa-report.md:223-226`).
- Consequence recorded as C-36: "Not only P1-vs-P0 labeling — a **different blocker set**: the P0 list adds keystore and DEC-12 … Both live in the repo; no document defines P0≡P1" (`docs/phase9-11-…:99`). Phase 9.10 kept it open too (§F.1, `:254-256`).
- Related gate IDs that surface in either set: GATE-KEY-01 (keystore), GATE-EXIT-01, GATE-PROV-01, GATE-DA-01, GATE-DEC12-01, SCHED-01, GAP DUR-01 (Phase 9.10 blocker register `:234-252`).

**Available choices (existing evidence only).** (a) **Adopt the register's narrow model** as authoritative: exactly two P1 blockers, and treat keystore/DEC-12 gates as sub-items or separate categories. (b) **Adopt the broader P0 set** from DEC-15/DEC-16, and amend nothing else. (c) **Define the mapping** — publish a severity table (the `phase-8-open-gaps.md:35-40` definitions already exist) and state explicitly whether P0 and P1 both block release, then re-label each gate/gap once. (d) **Leave it unresolved** — the current state. These are the only positions the repository supports.

**Technical and operational consequences.** Any of (a)–(c) is a documentation-only edit to registers or decision documents, so it requires a distinct authorization from the owner (J-7 makes the same class of question explicit for the stale-wording items). Choosing (a) or (b) changes which items must be closed before a release candidate can be declared, and therefore changes what "ready" means for Gate D. (d) leaves two live documents disagreeing about the blocker list itself.

**Security, privacy, reliability and release impact.** Direct release-impact only; no code or hosted consequence. Risk of the unresolved state is operational: a reader of DEC-15/DEC-16 believes keystore and DEC-12 gates block release, while a reader of the register believes exactly two items block it. Neither reading changes the underlying `NOT TESTED` facts, but they yield different go/no-go answers from the same evidence.

**Dependencies on other decisions.** Feeds B (verdict wording) and D (dependency map). Interacts with J-7 (both are documentation-edit authorizations) and with J-5 (whether GATE-EXIT-01 counts as a release blocker in the canonical set). Independent of DEC-02/DEC-03 substance: normalizing labels grants no execution authorization of any kind.

**What approval would authorize.** A single, owner-ratified severity vocabulary and blocker set, written into the canonical register (with its mirror), with no change to any decision's approved choice and no change to any historical evidence report.

**What approval would explicitly NOT authorize.** No implementation, no hosted access, no device activity, no re-classification of DEC-01…DEC-16 approvals, and no relabeling of `NOT RUN` / `NOT TESTED` / `NOT VERIFIED` findings as anything more favorable. Register modification is separately gated: this phase performed none (both registers re-verified byte-identical, §I).

**Recommended questions for the owner.** (1) Is P0 a *hotfix* class and P1 a *release-gate* class (as `phase-8-open-gaps.md:35-40` says), or is P0 the stronger blocker? (2) Is the authoritative blocker set the register's two items, or the DEC-15/DEC-16 four-item list? (3) Are GATE-KEY-01, GATE-EXIT-01, GATE-PROV-01, GATE-DA-01 and GATE-DEC12-01 release-blocking in their own right or children of DEC-02/DEC-03? (4) Once decided, may the register be edited, and must the `docs/implementation/` mirror be rewritten in the same pass to keep SHA-256 identity?

**Status: `AWAITING OWNER DECISION`**

### C.4 J-4 — TURN infrastructure: whether to open a separate decision

**Decision ID:** J-4 — **open** a relay-infrastructure decision. This is not a ruling on an existing decision, because none exists: Phase 9.11 records "**No decision exists — this is a capability gap, `F4`**" and "**Owner must open a decision (DEC-17 or equivalent)** — the register currently has no decision covering relay infrastructure" ([`docs/phase9-11-…:221`](phase9-11-evidence-contradiction-and-decision-readiness-report.md#L221), J-4 at `:248`).

**Current recorded status:** **NO OWNING DECISION.** Registered defect: `F4` "No TURN relay configured (risk, not a failure in this run)" (`docs/runtime-failure-analysis.md:88-95`). QA row `NET-06` = `NOT RUN` / BLOCKED. Gap severity: `F4` listed P1 in the Phase 9.10 blocker register (`docs/phase9-10-…:234-252`).

**Background and exact evidence references.**
- *Absence, measured historically:* "ICE candidates gathered for the live session: `host` 37, `srflx` **10**, `relay` **0**" (`docs/runtime-failure-analysis.md:88-95`); `docs/evidence/stage8/media-verified-11-55Z.txt:10` "host 37, srflx 10, relay 0 (no TURN configured)" and `:13` banner `"Relay not configured"`; `docs/mic_only_test_report.md:212` "this build has `turn_configured:false` … so sessions are expected to fail on carrier NAT or strict-firewall networks".
- *Secrets absent:* `docs/microphone_configuration_audit.md:46` — "Supabase project `hhqgreaoqulmfwfwarhc` has **no `TURN_URL` or `TURN_SECRET` configured**. ICE relies entirely on Google STUN … Symmetric NATs, carrier firewalls, or cellular-to-Wi-Fi routing will fail media establishment"; `docs/turn_configuration.md:50` "Secrets were never created".
- *No relay ever demonstrated:* `docs/turn_configuration.md:393-401` (bottom line) — "Relay use has **never** been demonstrated: there is no relay, no second device, and no TURN-only run."
- *Code path exists but inert:* `supabase/functions/_shared/turn.ts:35` reads `TURN_URL` from the environment; `turn.ts:84-93` is "the whole gate"; the `turn_configured: true` branch at `turn.ts:103` appears only as a conditional return and in the unit fixture `supabase/functions/_shared/turn_test.ts:187`. `.env.example:13` is a **commented placeholder** (`#   TURN_URL=turn:turn.example.com:3478`). `android/` has zero TURN references. The only stored hosted observation is `turn_configured: false` (`.tools/live/results/phase2.json:252`).
- *Unproven cross-network behavior:* `docs/runtime-mic-test-report.md:162` G4 "Network switch (Wi-Fi ↔ cellular) … **NOT TESTED**"; `docs/stage2_device_verification_report.md:84` N2 "Wi-Fi ↔ cellular handover … NOT TESTED — no session"; `docs/two-device-webrtc-test-plan.md:445` N2 "Parent Wi-Fi, child cellular (and the reverse) … Whether media connects without TURN"; `docs/implementation/phase-7-regression-matrix.md:145` NET-02 "WebRTC connection across separate mobile networks … **NOT RUN**".
- *Reference design exists:* `docs/turn_configuration.md` §5 "Minimal coturn reference configuration" (`:143`) uses placeholders only (`turn.example.com`, TEST-NET addresses); §4 env contract `:115`; §6 verification procedure `:195`; §7 privacy/security rules `:285`; §8 "What needs authorization" `:308`.
- *TTL sub-defect:* `docs/turn_configuration.md:92` §3 ("TTL defect (present in code, fix needs authorization)"); `docs/mic_full_audit_report.md:115` recommends `TURN_TTL_SECONDS=3600` but "needs authorization".

**Available choices (existing evidence only).** The four work classes are enumerated in `docs/turn_configuration.md:308-325`: (1) create the `TURN_URL` / `TURN_SECRET` hosted secrets — "a config change"; (2) redeploy `remote-session` — "a deployment"; (3) "Provisioning coturn (VM, DNS, TLS certificate, firewall/security-group changes, quota tuning) — **infrastructure and cost**" (`:317-318`); (4) client-side TTL-aware ICE refetch / stats / ICE restart — "code and release". A fifth, no-cost position is also evidenced: keep STUN-only and formally scope `NET-06` as `UNSUPPORTED (STUN-only)` — `phase-8-android-qa-report.md:359` "Owner must decide whether TURN relay credentials will be provisioned. If unprovisioned, NET-06 must remain formally scoped as `UNSUPPORTED (STUN-only)`." **NOT FOUND:** any cost figure, vendor, budget or sizing statement; the only cost framing is qualitative (`docs/phase9-11-…:248` "New product infrastructure commitment and cost").

**Technical and operational consequences.** Provisioning turns relay candidates available and makes the cross-network case testable at all; it also introduces an ongoing operational dependency (a coturn host, TLS certificate renewal, credential TTL behavior) and a new secret to manage. Choosing STUN-only-with-formal-exclusion keeps the product simpler but records cellular/carrier-NAT audio as unsupported, which for a parental-assistance feature is a product-scope statement, not merely an infrastructure one. Nothing in the current repository makes relay work executable: it needs both a decision and, per §8 of `docs/turn_configuration.md`, separate hosted and infrastructure authorization.

**Security, privacy, reliability and release impact.** Reliability: today, audio works "on paths where host/srflx candidates succeed" (`docs/runtime-mic-test-report.md:213-214`); "on carrier-grade NAT or strict firewall networks the session would fail with no fallback" (`docs/runtime-failure-analysis.md:88-95`). Privacy: relayed media transits third-party infrastructure, so `docs/turn_configuration.md:285` §7 states privacy rules that any deployment must honor; credential TTL is currently 600 s against a 1800 s session (`docs/mic_full_audit_report.md:115`). Security: new secrets = new secret-management surface; no secret was inspected in this phase. Release: `F4` is carried as P1 in the blocker register; `NET-06`/`NET-02` rows stay `NOT RUN` until either relay exists or the exclusion is ratified.

**Dependencies on other decisions.** Independent of DEC-02 *as scoped* (DEC-02's three objects do not include TURN), but functionally entangled: deploying `remote-session` is a DEC-02-class act (register `:313` names only `account`, `family-admin`, `device-command`; `remote-session` appears only as the Stage-3 4th step, `docs/implementation/phase-9-release-readiness.md:166`). Any relay *test* requires DEC-03 (J-2). A TTL code fix requires an implementation authorization no architecture approval provides. J-6's acceptance plan should state whether relay legs are in or out of scope.

**What approval would authorize** (if the owner opens and rules the decision): the specific classes the owner names — secrets creation, `remote-session` redeploy, coturn provisioning, and/or client-side TTL work — each of which is separately enumerated and separately gated today.

**What approval would explicitly NOT authorize.** It would not authorize DEC-02's registered three objects, would not authorize any device/QA execution (DEC-03), would not authorize scheduler activation (DEC-05), would not authorize Firebase provisioning, and would not license any claim that relayed or cross-network audio works until a relay-only run is actually evidenced (`docs/turn_configuration.md:393-401`).

**Recommended questions for the owner.** (1) Should this become DEC-17 (or another register slot), and should the register gain that row at all in a documentation-only pass? (2) Is cross-network/cellular assistance a release requirement, a post-release requirement, or out of scope (as DEC-15/DEC-16 did for other capabilities)? (3) If relay is wanted: coturn self-hosted or managed, and who owns cost? (4) If relay is not wanted: do you ratify `NET-02`/`NET-06` as `UNSUPPORTED (STUN-only)` in the product documentation? (5) Should the TTL fix ride with relay work or be authorized separately?

**Status: `AWAITING OWNER DECISION`**

### C.5 J-5 — Managed Mode safe exit: design priority and release-blocking implications

**Decision ID:** J-5 — order the `GATE-EXIT-01` safe-exit design, or accept Managed Mode staying blocked.

**Current recorded status:** Approved *requirement*, un-designed *gate*, no design work authorized. Register: "A safe, non-destructive in-app Device Owner exit mechanism is mandatory before Managed Mode can be released to production. Factory reset must not be the only supported consumer exit mechanism. | **APPROVED REQUIREMENT / RELEASE BLOCKER**" ([`phase-9-owner-decision-register.md:455`](../phase-9-owner-decision-register.md#L455)). Gate: "**GATE-EXIT-01** | Safe In-App DO Teardown | **NOT DESIGNED / RELEASE BLOCKER** | Required before Managed Mode can ship" (`docs/dec-12-screen-time-bedtime-decision.md:198`). DEC-13 itself is `APPROVED (Option B)` (`:669`).

**Background and exact evidence references.** DEC-13 Option B made safe exit a **mandatory release blocker** ("Approved with mandatory safe-exit release blocker and DA retirement", `:669`; `docs/dec-13-device-owner-decision.md:7`). A 12-step specification exists as a *future implementation specification*: `docs/dec-13-device-owner-decision.md:379-395` (parent auth → server RPC → restore suspensions → `clearDeviceOwnerApp()` → cleanup → idempotent recovery → honest failure). It is not implemented: `clearDeviceOwnerApp` is recorded NOT IMPLEMENTED (`docs/p0-decision-specifications.md:159`), factory reset is the only exit path documented (`docs/device-owner-provisioning.md:709-724`). Sibling gates: GATE-KEY-01, GATE-PROV-01, GATE-DA-01 (`docs/dec-13-device-owner-decision.md:496-499`). Phase 9.10 records "Design work NOT AUTHORIZED" (`docs/phase9-10-…:237`) and lists GATE-EXIT-01 as "Release Blocker (DEC-13)" in the blocker register (`:234-252`). Missing evidence: "GATE-EXIT-01 design work since 2026-11-05 = `NOT AVAILABLE`" (`docs/phase9-11-…:42`). Register sequencing: DEC-13 first (`docs/phase9-11-…:249`, J-5 rationale).

**Available choices (existing evidence only).** (a) **Authorize safe-exit design work now** (specification only; the 12-step protocol already exists as a specification to be completed at `docs/dec-13-…:379-395`, `:496`). (b) **Keep it blocked and defer Managed Mode** — "accept Managed Mode staying blocked" is the explicit alternative in J-5 (`docs/phase9-11-…:249`). (c) **Order it after DEC-02/DEC-03 execution** — consistent with the register's gate ordering (Gate B/C before D, `docs/implementation/phase-9-release-readiness.md:286`). No documented option removes GATE-EXIT-01: the requirement is *approved* and labeled a release blocker, and nothing in the repo proposes dropping it.

**Technical and operational consequences.** Option (a) produces a design artifact (and later needs code + hardware verification). Option (b) is free and consistent with today's state, but pins Managed Mode — and every enforcement capability that presumes it (DEC-12 mode-split enforcement, device-policy/telemetry surfaces) — behind an unshipped teardown path. Operationally, shipping Managed Mode without in-app exit means the only consumer exit is a factory reset, which is why the requirement was registered as mandatory.

**Security, privacy, reliability and release impact.** Privacy/child-safety: a Device Owner install that cannot be removed without factory reset is a consumer-harm and trust exposure; the requirement text says exactly that ("Factory reset must not be the only supported consumer exit mechanism", `:455`). Reliability: the 12-step protocol specifies idempotent recovery and honest failure, i.e. teardown partially applied is the failure mode being designed against. Release: GATE-EXIT-01 blocks Managed Mode shipping; whether it blocks the *entire* release is the same question J-3 leaves open. Design-only approval has zero hosted and zero device consequence.

**Dependencies on other decisions.** Depends on J-3 for whether GATE-EXIT-01 is release-blocking in the canonical set. Any *implementation* eventually needs DEC-03-class device verification (Managed Mode behaviors cannot be QA'd without hardware; `docs/dec-13-…:86` states Option B approval does not authorize DEC-03 testing). Some teardown steps involve server RPC, so a later deploy question overlaps DEC-02's neighborhood without being inside its three registered objects. DA retirement is part of the same approved ruling (`:669`). Independent of DEC-05 and of DEC-15/DEC-16 scope exclusions.

**What approval would authorize.** The ordering/priority ruling, and — if the owner words it that way — design or specification work for the safe-exit protocol. Design work output would be documents, not shipped behavior.

**What approval would explicitly NOT authorize.** No Device Owner or Device Administrator state change, no provisioning (`docs/device-owner-provisioning.md` behavior), no code implementing `clearDeviceOwnerApp`, no APK/ADB/device verification (DEC-03), no hosted RPC deployment (DEC-02), and no release of Managed Mode. Architecture approval ≠ implementation authorization: "Approval of any one of them would not authorise implementation" (register `:377`).

**Recommended questions for the owner.** (1) Design now, or after DEC-02/DEC-03 execution? (2) Is GATE-EXIT-01 release-blocking for the whole product or only for Managed-Mode SKUs (a J-3 consequence)? (3) Should Standard-mode-only be the shippable configuration while this stays blocked? (4) Does the 12-step protocol need a review pass, or is it accepted as-is for later implementation? (5) Should DA retirement have its own gate line, or ride inside GATE-EXIT-01?

**Status: `AWAITING OWNER DECISION`**

### C.6 J-6 — Audio acceptance: scope of a future controlled audio acceptance plan

**Decision ID:** J-6 — approve or reject a scoped audio-acceptance test plan covering the identified audio gaps.

**Current recorded status:** **NO APPROVED PLAN.** Two plan documents exist on disk, both unexecuted: `docs/mic-lifecycle-test-plan.md` — "Status: **armed, waiting on parent authentication**. Baseline recorded 2026-10-29" (`:3`) — and `docs/two-device-webrtc-test-plan.md`, whose §0 is titled "Why this cannot run today" (`:12`). Execution is DEC-03-gated; nothing has been approved to run.

**Background and exact evidence references.**
- *What is unproven (the plan's content):* Phase 9.11 §C.1 lists sixteen audio/Android contradictions (C-01…C-16, `:54-71`) and §H item 8 says the owner should "approve a scoped audio-acceptance test plan (the 16 gaps in §D/§C.1 define its content)" (`:220`), listing the missing artifacts: "Artifact-tied install record; controlled endurance legs; listening confirmation; timezone-explicit logs" (`:220`), plus "A named-listener confirmation on one hash-identified build" (`:60`), "Re-run as isolated lock-only endurance legs" (`:59`), "An install record naming the artifact hash" (`:60`), "Acoustic verification" (`:63`), "Raw logs with explicit timezones" (C-16).
- *Conservative status union to preserve:* `docs/phase9-11-…:131` — candidate FGS runtime `NOT TESTED / NOT VERIFIED`; APK inclusion `NOT VERIFIED`; installation `NOT ESTABLISHED`; human audibility `NOT TESTED / NOT VERIFIED`; 5-minute and 15-minute locked-screen endurance `NOT TESTED`; long-duration locked-screen reliability `NOT VERIFIED`; TURN relay `ABSENT`; `MIC-01`, `MIC-02` P1 open; 75/75 QA rows `NOT RUN`.
- *Named defects to close:* `MIC-01` "No microphone foreground-service type in build 4005" (`docs/mic_only_test_report.md:166`), fix present in worktree `NOT TESTED`; `MIC-02` "A failed media connection does not stop capture or end the session" (`:167`; "Automatic media recovery … **FAIL** (no renegotiation)", `docs/stage6_account_and_media_recovery_report.md:244`; "not implemented", `:268`). Naming-collision caution: `docs/microphone_configuration_audit.md:31`, `:35` use **BUG-MIC-01 / BUG-MIC-02** for *different* defects (receive-only parent; no `setSpeakerphoneOn`) — a plan must not conflate them.
- *Endurance and audibility ceilings:* the longest clean child-side locked-screen observation is ~2 minutes, `D1 | Lock child 2 min … mWakefulness=Asleep, RTP +7,084 pkts … **PASS**` (`docs/runtime-mic-test-report.md:123`) on versionCode `1`, same-LAN, relay 0 (`docs/phase9-11-…:129`); `D4 | Lock both 5/15 min … NOT TESTED` (`:126`); "15/30-min screen-off standby … NOT TESTED" (`:175`). Audibility: "Case 5.4 … **NOT TESTED** | No human listener … The phrase content cannot be inferred from levels" (`docs/mic_only_test_report.md:118`); "Audibility by a human listener is not provable from dumpsys; that remains a manual check" (`docs/evidence/stage8/media-verified-11-55Z.txt:22-23`).
- *The 8m14s leg must not be reused as endurance:* `docs/evidence/stage8/e1-15min.txt:15-16` "VERDICT: FAIL — interrupted at 8m14s by server-side expiry, not by the child backgrounding"; recorded as C-13 dual-reading (`docs/phase9-11-…:66`).
- *Reusable structure (all existing, none invented):* `docs/mic-lifecycle-test-plan.md` §1 roles "never reversed" (`:7-16`), §2 build-under-test with APK SHA-256 (`:17-25`), §4 evidence method (`:44`), §5 test matrix (`:66`), §6 stop conditions (`:187`), §8 disjoint workstream ownership (`:202`); `docs/two-device-webrtc-test-plan.md` §3 script (`:100`), §4 network matrix N1/N2/N5 (`:440-451`), §6 pass/fail criteria (`:483`); `docs/two-device-e2e-checklist.md` failure-report template (`:82`) and "What this checklist does not cover" (`:97`); executed-scope precedent `docs/stage2_device_verification_report.md:5` "Outcome: BLOCKED — no test in the T/N/Q matrix was executed … Nothing below should be read as a device pass"; QA rows to inherit `SESS-06` (`phase-8-android-qa-report.md:271`), `PERM-05` (`:286`), `NET-06` (`:280`), `NET-01` (`:275`); evidence-file conventions of `docs/evidence/stage8/` (device-prefixed screenshots `rmx-`/`emu-`, small `.txt` observation files with model+serial, session UUID, dual IST/Z timestamps, verbatim `dumpsys`/`appops`/RTP excerpts, then an explicit `VERDICT:` line).

**Available choices (existing evidence only).** (a) **Approve the plan scope as written** (16 gaps, artifact-tied). (b) **Approve a reduced scope** — e.g. the FGS/lock-screen endurance legs and listener confirmation only. (c) **Approve preparation now, execution later** — the split Phase 9.11 §H item 2 already describes as authorized-today (`:213`). (d) **Reject / defer.** (a)–(d) are all supported; note that a plan approved without DEC-03 still cannot execute.

**Technical and operational consequences.** Approving a plan converts diffuse "NOT TESTED" into named, artifact-bound acceptance criteria with a defined stop condition, and creates an obligation to record the build hash for every leg — which is precisely what C-01/C-06/C-07 show past runs failing to do. Reduced scope is cheaper but leaves the audibility and endurance gaps open. Preparation-only costs no device time and produces no evidence.

**Security, privacy, reliability and release impact.** Privacy: the plan touches child microphone capture, so it must preserve the privacy invariants (register `:71-78`), the notification/channel behavior observed as `NONE` vs configured `IMPORTANCE_LOW` (C-09, `:62`), and the unobserved green indicator on ColorOS (C-08, `:61`). Reliability: this is the only path from "historical observation" to "repeatable QA". Release: without it, the core assistance feature stays functionally unverified and Gate B cannot pass. No security impact on hosted systems.

**Dependencies on other decisions.** Hard-depends on DEC-03 (J-2) for any execution. Cross-network legs depend on J-4 (relay exists or are formally excluded). Endurance legs past 30 min depend on `F1` being fixed and deployed, i.e. DEC-02-class deployment (`docs/evidence/stage8/f1-expiry-12-16Z.txt:29-30`). Independent of DEC-05, DEC-13 safe exit, DEC-15/DEC-16 exclusions.

**What approval would authorize.** Approval of *scope and acceptance criteria* for a future plan (and, if the owner words it so, authoring of that plan document). It is a documentation/scope act.

**What approval would explicitly NOT authorize.** It does **not** authorize building or installing APKs, ADB, device or emulator operation, or running any row — those are DEC-03's alone. It does not authorize hosted deployment of the `F1` fix (DEC-02), TURN provisioning (J-4), or any scheduler. It does not authorize restating any present `NOT TESTED` / `NOT VERIFIED` finding as a pass, and it does not license converting the 2-minute observation into an endurance pass or RTP deltas into human audibility.

**Recommended questions for the owner.** (1) Full 16-gap scope or reduced? (2) Must every leg bind to an APK SHA-256 and versionCode before it can count? (3) What exactly is the pass criterion for audibility — a named listener, and on which device (speaker vs headset)? (4) Endurance ladder: which durations are acceptance criteria (5 m / 15 m / 30 m)? (5) Do relay/network-switch legs belong in this plan or wait on J-4? (6) Does this plan subsume the QA matrix rows or run beside them?

**Status: `AWAITING OWNER DECISION`**

### C.7 J-7 — Documentation corrections: stale present-tense statuses

**Decision ID:** J-7 — authorize (or refuse) four documentation-only wording corrections for stale present-tense statuses.

**Current recorded status:** **NOT AUTHORIZED — none of the four files was edited in any pass of this phase.** Proposed remedy wording, per Phase 9.11: "annotate or supersede (a documentation-only edit)" (C-30 `:93`), "a forward-pointer, not a rewrite" (C-28 `:91`), "The phrase 'in force' makes dated snapshots read as current" (C-31 `:94`).

**Background and exact evidence references.** The four live-but-stale statements, each with its superseding authority:
1. `docs/p0-decision-specifications.md:104` — "…**DEC-12 remains strictly PROPOSED awaiting explicit owner decision**" inside the "10. Recommended option — recommendation only, not approval" line; superseded by the same file's own header `:4` "DEC-12 is APPROVED (Choices D1-B, B1-B, O1-C, P1-A, DEFER) … by explicit owner rulings on 2026-11-05 (Phases 9.2, 9.3, 9.5, 9.7 & 9.9)" and `:49`. Classified C-30 `CONTRADICTORY (misleading)` — "pre-approval residue in a document otherwise treated as current" (`docs/phase9-11-…:93`).
2. `docs/dec-13-device-owner-decision.md:13` — "**Governance in force:** … DEC-12 PROPOSED · DEC-14…DEC-16 PROPOSED"; superseded by register `:668-672`. Header is dated (`:4` "Status on 2026-11-05 (Phase 9.2)").
3. `docs/dec-12-screen-time-bedtime-decision.md:8` — "**Related Governance:** … DEC-14…DEC-16 PROPOSED"; superseded by register `:670-672`. Dated header at `:4`.
4. `docs/dec-14-fcm-owner-decision.md:28-29` — "DEC-15: **PROPOSED**" / "DEC-16: **PROPOSED — Scope Exclusion Confirmed**"; superseded by Phase 9.7 (register `:671`) and Phase 9.9 (`:672`). Dated header at `:7` "Approval Date: 2026-11-05 (Phase 9.5)". Classified C-32 — "Correct as of Phase 9.5; superseded by Phases 9.7 and 9.9 … Forward-pointer only" (`:95`).
Plus the fifth, structurally different case: register `:412` "DEC-12…DEC-16 remain **PROPOSED**" *inside* the "DEC-02 SCOPE-SPECIFIC RECONCILIATION ADDENDUM (Dated 2026-11-05)" opened at `:298`. Phase 9.11 treats the dated body as legitimate history whose "Verdict — UNCHANGED" label is now inaccurate; remedy is a forward-pointer, not a rewrite (`:91`).
Authoritative approvals live at register `:668` (DEC-12), `:669` (DEC-13), `:670` (DEC-14), `:671` (DEC-15), `:672` (DEC-16), with approval-addendum headings at `:444`, `:487`, `:530`, `:582`, `:633` respectively.

**Available choices (existing evidence only).** (a) **Add dated forward-pointers** (annotate) — the remedy Phase 9.11 recommends. (b) **Supersede the sentences** with corrected present-tense text plus a dated note. (c) **Leave dated bodies untouched** and instead publish a single "current status" footer convention. (d) **Refuse** — leave as-is. All four are documentation-only and all four preserve or discard history differently.

**Technical and operational consequences.** Consequential only for *reader error risk*: today a reader landing on `p0:104`, `dec-13:13`, `dec-12:8` or `dec-14:28-29` concludes DEC-12…DEC-16 are undecided, which is false. Any edit to the canonical register (`:412`) additionally requires rewriting the byte-identical mirror `docs/implementation/phase-9-owner-decision-register.md` in the same pass or the SHA-256 identity breaks (currently both `3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f`, verified this pass by `sha256sum` + `cmp`).

**Security, privacy, reliability and release impact.** Zero functional, security or privacy impact. Reliability of *governance reading* improves. Release impact: none directly, but the stale lines are what Phase 9.11's area-C contradiction cluster (C-28…C-32) exists to describe, so this item is the remediation half of that finding. Note the boundary from the task instruction and from Phase 9.11's own handling of C-37: **historical evidence reports are not rewritten** — the Phase 9.9.2.2 `.git/index` mtime sentence was deliberately left unedited rather than corrected (`docs/phase9-11-…:277`).

**Dependencies on other decisions.** Same class of documentation-edit authorization as J-3. Independent of DEC-02/DEC-03: editing status wording changes no state and grants no execution rights. Interacts with the standing rule "Do not update owner decision statuses" used in prior closure passes — a ruling here is what makes an edit permissible at all.

**What approval would authorize.** A narrowly scoped, dated, documentation-only annotation/supersession of the four named lines (and, if approved, the register `:412` forward-pointer with its mirror re-synchronized), recorded as a new dated pass.

**What approval would explicitly NOT authorize.** No change to any approved choice, no status upgrade of any pending decision, no rewrite of historical test reports or evidence files, no register edit beyond what is explicitly named, no implementation, no hosted access, no Git commit or staging. Silence here does not authorize anything: today the correct reading remains "no edit authorized, no edit performed."

**Recommended questions for the owner.** (1) Annotate (a), supersede (b), footer convention (c), or leave (d)? (2) Is the register `:412` sentence in scope — noting that touching it breaks mirror byte-identity unless both files are rewritten together? (3) Does "dated body text = history, present-tense framing = defect" become the repo's written rule for future passes? (4) Should Phase 9.9.x reports with similar phrasing be swept under the same rule?

**Status: `AWAITING OWNER DECISION`**

### C.8 J-8 — DEC-04 and DEC-06…DEC-11: individual rulings or reclassification

**Decision ID:** J-8 — rule on DEC-04 and DEC-06 through DEC-11, or reclassify them as non-decisions.

**Current recorded status:** **`NOT AVAILABLE` — no owner ruling exists** for any of the seven (Phase 9.11 C-34 classification, `:97`). They are carried forward with original status words: DEC-04 `PREFLIGHT FORMULATED / READY` (`:33`) → `PREFLIGHT PREPARED / READY` (`:174`) → `READY / CARRIED FORWARD` (`:665`); DEC-06 `PRESERVED ADDITIVELY / DEFERRED` (`:175`); DEC-07 `RETAINED AS REVIEWED FALLBACK` (`:176`); DEC-08 `SPECIFICATION DRAFTED / READY` (`:177`); DEC-09 `PRESERVED ON STANDBY` (`:178`); DEC-10 `PREPARED FOR POST-APPLY` (`:179`); DEC-11 `DOCUMENTED SPECIFICATION / RATIFIED` (`:180`); all `CARRIED FORWARD` at `:667`.

**Background and exact evidence references.** Register: "The owner ruled on none of these on 2026-11-05 … **No approval, closure or progression may be inferred**" (`:363`); "carry forward their original register statuses and await a future ruling" (`:277`); "DEC-04 and DEC-06 through DEC-11 were relabelled as carried-forward, not ruled" (`:282`). Phase 9.10 records, per decision, "**No owner ruling recorded — approved option NOT AVAILABLE**" (`docs/phase9-10-…:49-56`) and counts 7 of 16 decisions as "Registered but with NO owner ruling" (`:69`), noting "DEC-11's `RATIFIED` is a status word, not a recorded owner ruling" (`:56`). C-33 records three different DEC-04 status variants (`:96`); C-34 recommends "Rulings, or explicit reclassification as non-decisions" (`:97`). Also noted there: DEC-07's "Owner Ruling #2" (`:35`, `:176`) concerns *retaining a fallback*, not selecting a DEC-07 option. Other mentions: `docs/implementation/phase-9-decision-execution-log.md:55-62`, `:171-177`; `phase-9-open-gaps.md:31-40`, `:171-178`; `docs/phase9-owner-decision-reconciliation-report.md:77-79`, `:234`. DEC-04 is directly tied to DEC-02's preflights: "Preflight Queries 1–5: **not executed** — DEC-04 therefore still reads PREFLIGHT FORMULATED / READY" (`:322`).

**Available choices (existing evidence only).** Per decision: (a) **Rule** (approve/refuse/scope) as an actual decision; (b) **Reclassify as a non-decision / prepared specification** so the register stops presenting them as pending rulings; (c) **Leave carried forward** (today). Phase 9.11 frames exactly these: "Rule on DEC-04 and DEC-06–DEC-11 (or reclassify them as non-decisions)" (`:252`). No evidence supports treating any of them as already ruled.

**Technical and operational consequences.** Reclassification (b) is the cheapest fix for the misleading-presentation finding: it removes the implication that seven decisions are waiting when only two are. Ruling (a) on DEC-04 in particular would have to distinguish "approve the preflight formulation" (a document state) from "authorize running them" (a DEC-02 act) — the register already pairs them at `:322`. Leaving (c) keeps C-33/C-34 contradictions live.

**Security, privacy, reliability and release impact.** Governance-clarity impact only; no functional consequence. Reliability of decision-making matters: an owner skimming the register may believe DEC-08 or DEC-11 has been approved when no ruling exists. Nothing here changes the two real P1 blockers.

**Dependencies on other decisions.** DEC-04 rides with DEC-02 (J-1) and J-11 (preflight artifacts). DEC-06…DEC-11 are standby/historical architecture records, explicitly "carried forward" and superseded in practice by DEC-12…DEC-16 (`:667`). J-8 requires no device, hosted, or code action, and does not touch the seven APPROVED decisions.

**What approval would authorize.** Either real rulings recorded with owner identity and date, or explicit reclassification wording in the register (plus mirror). Nothing else.

**What approval would explicitly NOT authorize.** No implementation, deployment, device activity, or hosted access; no inference that any carried-forward specification is approved; no re-opening or alteration of DEC-01, DEC-05, DEC-12…DEC-16 approvals; no conversion of a status word into permission.

**Recommended questions for the owner.** (1) For each of DEC-04, DEC-06…DEC-11: rule, reclassify, or leave? (2) If DEC-04 is ruled, does that mean only "formulation accepted", leaving execution inside DEC-02? (3) Should DEC-11's `RATIFIED` be re-labeled so it no longer reads like an owner ruling? (4) Should reclassified items move to a separate "specifications, not decisions" section of the register?

**Status: `AWAITING OWNER DECISION`**

### C.9 J-9 — DEC-02 apply mechanism given the absent migration ledger

**Decision ID:** J-9 — choose the DEC-02 apply/verification mechanism.

**Current recorded status:** **NOT DECIDED.** Phase 9.11 C-22 remedy: "Owner to choose an apply mechanism under DEC-02; **NOT AUTHORIZED**" (`docs/phase9-11-…:80`), and J-9 "Operational risk decision … Migration work could double-apply undetected" (`:253`).

**Background and exact evidence references.** There is no bookkeeping: `supabase_migrations` "does not exist (`to_regnamespace('supabase_migrations')` is NULL; a direct query raised `42P01: relation "supabase_migrations.schema_migrations" does not exist`) … migrations here were applied through the SQL Editor, which never writes that schema" (`docs/supabase-hosted-state-verification-2026-11-05.md:147`; also `:167`, and `docs/stage7_hosted_migration_apply_2026-10-29.md:26`, `:92-93`). Verification therefore has to be object-level, as the register's own DEC-02 addendum already demonstrates: each of the four migrations was classified by probing for its function signature (`:317-320`). One file is *unresolvable* by that method — `20261028000100_remote_session_concurrency.sql` is "**NOT VERIFIED (indistinguishable)**" (`:337`) — which is the ledger problem in miniature. Last hosted observation is 2026-11-05; state after that is `NOT AVAILABLE` (`docs/phase9-11-…:42`; `docs/phase9-10-…:102`, `:106`).

**Available choices (existing evidence only).** (a) **SQL Editor apply + object probes**, the method already used for the 2026-11-05 verification (`docs/supabase-hosted-state-verification-2026-11-05.md` throughout) — no new tooling, no ledger. (b) **Supabase CLI** apply so a ledger is written going forward — but C-22 warns that CLI/`db push` history is precisely what cannot be trusted here, because "re-applying an already-applied file would not be caught". (c) **Apply with a hand-maintained ledger note** in the repo for each pass. (d) **Read-only preflights first, then decide** — the playbook's own Stage 1 is titled "Supabase Dashboard SQL Editor Preflights (Read-Only)" (`docs/implementation/phase-9-release-readiness.md:71`). These are evidenced mechanisms; the repository does not offer a fifth.

**Technical and operational consequences.** (a) is lowest-risk operationally but requires a *pre-apply* probe for every object the migrations create, plus a *post-apply* probe, because idempotency cannot be inferred. (b) creates a ledger only if CLI state is reconciled with the existing reality first — otherwise it produces a false "0 migrations applied" baseline. (c) is documentation-heavy but human-readable. (d) converts uncertainty into facts before any write, at the cost of one extra window.

**Security, privacy, reliability and release impact.** Reliability is the whole question: double-apply or partial-apply on a production schema could break RLS or session handling silently; there is no rollback evidence on record (LAST BACKUP: "No backups", `docs/supabase-hosted-state-verification-2026-11-05.md:147`). Security: Migrations 2 and 4 are the ones that close the `safe_zones` client-DELETE exposure (`phase-9-open-gaps.md:47-58`), so a mechanism that silently half-applies them would leave an believed-closed hole. Privacy: no new data handling either way. Release: DEC-02 gates Gate C; a broken apply pass is worse than a withheld one because it changes hosted state without authorization traceability.

**Dependencies on other decisions.** Strictly downstream of J-1 (no mechanism matters until DEC-02 is ruled) and alongside J-11 (if preflights become real `.sql` artifacts, mechanism (d) becomes trivially executable). Requires its own owner statement even where DEC-02 is approved: approving *what* to apply is not approving *how*. Independent of DEC-03, DEC-05, DEC-13, DEC-15/16.

**What approval would authorize.** A stated apply-and-verify procedure for DEC-02 work (pre-apply object probes, the apply channel, post-apply verification, and how the result is recorded), plus whatever read-only checks the mechanism needs.

**What approval would explicitly NOT authorize.** It does not by itself authorize the DEC-02 writes (J-1 owns those), any Edge Function deployment, any device/QA work (DEC-03), any scheduler (`pg_cron` is recorded absent both on disk — "There is no pg_cron and no hosted scheduler in this phase", `supabase/migrations/20261030000300_retention_sweep.sql:6` — and hosted, `docs/supabase-hosted-state-verification-2026-11-05.md:145`), or any backup/restore/DML operation beyond the named migrations.

**Recommended questions for the owner.** (1) Which channel — SQL Editor with probes, or CLI? (2) Must pre-flights run in the same window, before the first write? (3) What is the rollback expectation given "LAST BACKUP: No backups"? (4) Who resolves `20261028000100…` indistinguishability? (5) Must each apply be recorded with the probing evidence attached, and where?

**Status: `AWAITING OWNER DECISION`**

### C.10 J-10 — Git governance: fate of staged and uncommitted governance documents

**Decision ID:** J-10 — decide the fate of the staged and uncommitted governance files.

**Current recorded status:** **NOT DECIDED — left exactly as found by instruction.** Measured this pass: `git rev-parse HEAD` → `a2faa5fb70f84638359154c68d19ce304fadab36`; `git rev-parse --abbrev-ref HEAD` → `main`; `git status --porcelain` →
```
AM docs/phase9-9-2-2-documentation-completion-acceptance-record.md
?? docs/phase9-10-consolidated-release-readiness-governance-blocker-review.md
?? docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md
```
`git stash list` → empty. Phase 9.11 C-41 records the same condition and "no cleanup performed" (`:109`); J-10 frames it as "Commit authorization is withheld from this phase | 2026-11-06 dates have no commit backing" (`:254`).

**Background and exact evidence references.**
- The `AM` file: staged as a new file (`git diff --cached --stat` → 239 insertions; index blob `100644 8ff72278d6319d1dd82840ac89e3e05148225f51 0`) and additionally modified in the worktree (`git hash-object` → `a38a8443eb4dfe4822e6f92b250d8ecfc7c6673b`; worktree-vs-index `git diff --stat` → 18 insertions, 3 deletions), with a live "LF will be replaced by CRLF" warning under `core.autocrlf=true`.
- The staging cause is unexplained and was investigated read-only: `.git/hooks` contains only `.sample` files, `filter.*` config holds git-lfs entries only, `.gitattributes` does not exist, `git check-attr -a` returns nothing (Phase 9.11 C-38, `:106`). No mutating Git command is evidenced by any reflog or commit (`:107`).
- Conventions that a commit would follow: `git ls-files | wc -l` → 752 tracked files; `build/` ignored at `.gitignore:54 **/build/` and `*.log` at `.gitignore:22` (confirmed with `git check-ignore -v`); `docs/evidence/` is **committed, not ignored** — 154 tracked files (relevant to DEC-01 Choice B local-only evidence, GAP DUR-01).
- Precedent for "clean tree" claims being unreliable: `phase-9-regression-matrix.md:3` warns that the CI line "working tree verified clean" "is emitted by the local CI script and is not evidence of a clean tree" (quoted in C-40, `:108`); `phase-9-git-integrity-report.md:49` carries a dated correction that "the label 'clean working tree' is wrong for a tree with 37 staged files".
- Historical snapshots, all phrased as current: "Exactly **37 staged files** (8,137 insertions, 3 deletions)" (`phase-9-git-integrity-report.md:23`), "23 staged files" (`:111`), "**53** staged files" (`phase-9-report.md:276`, `phase-9-open-gaps.md:222`, `phase-9-release-readiness.md:311`, register `:275`), and the dated correction "HEAD `75d1a52…`, 0 staged, 15 unstaged modifications, 1 untracked" (`:24`). Six distinct HEAD hashes circulate as "current": `b12659b`, `75d1a52`, `65b3948`, `b398ab8`, `953b337`, `a2faa5f` (C-40, `:108`); only `a2faa5f` is current.

**Available choices (existing evidence only).** (a) **Commit the Phase 9.10/9.11/9.12 governance documents** as a docs-only commit, giving the 2026-11-06 work commit backing (consistent with commit style `c8239e9 docs: add Phase 9 governance, decision, and implementation records`). (b) **Leave everything uncommitted** (today). (c) **Commit and also resolve the `AM` half** so the index and worktree agree. (d) **Establish a written convention** for dated "state as at <timestamp>" footers so the six-HEAD/four-count pattern stops recurring (C-40 remedy at `:108` proposes precisely this). All four are evidenced; nothing in the repo authorizes any of them today.

**Technical and operational consequences.** Uncommitted governance documents are invisible to any reader working from a clone and are lost to a careless `git clean`; committing them makes the audit chain reproducible but is an irreversible shared-state act and would make the 2026-11-06 dates traceable — which is exactly what C-40/C-41 say is missing today. Leaving the `AM` entry inconsistent means any future commit picks up a partially staged file.

**Security, privacy, reliability and release impact.** No security or privacy impact (these are governance texts; no secrets, no evidence media added by this phase). Reliability: the repo's own clean-tree claims are demonstrably weak (`phase-9-regression-matrix.md:3`). Release: neither committing nor withholding moves Gate A/B/C/D; no document links Git state to release readiness.

**Dependencies on other decisions.** Independent of J-1/J-2 (a commit authorizes no hosted or device action). Interacts with J-3 and J-7: if register edits are ever authorized (J-7), both register copies must change together to keep SHA-256 identity, and that pass is a natural commit window. J-10's answer also determines whether Phase 9.12's own file is left untracked like its predecessors.

**What approval would authorize.** A commit of named files with a named message, and/or a written dated-state convention — that is all: no push unless separately stated.

**What approval would explicitly NOT authorize.** No `git reset`, `checkout`, `restore`, `clean`, `stash`, force-push or history rewrite; no discarding the existing staged state as "noise" (it is the 9.9.2.2 record); no un-staging of that file as a side effect; no source, hosted, device or deployment action; and no assumption that a commit endorses the *content* of any pending decision — a commit records documents, it does not approve DEC-02/DEC-03.

**Recommended questions for the owner.** (1) Commit Phase 9.10/9.11/9.12 (and 9.9.2.2) or continue leaving them uncommitted? (2) Should the 9.9.2.2 file's worktree edit be staged too, so its status stops reading `AM`? (3) Push, or local commit only? (4) Should a "state as at <timestamp>" footer convention be adopted, per C-40? (5) Is `docs/evidence/` still the right place for future device evidence, given DEC-01 Choice B and GAP DUR-01?

**Status: `AWAITING OWNER DECISION`**

### C.11 J-11 — Realtime evidence status and preflight SQL artifacts

**Decision ID:** J-11 — adjudicate the two hosted-scope documentation items: the Realtime evidence conflict (C-24) and whether preflight SQL files should be created (C-27).

**Current recorded status:** **NOT DECIDED.** Both are documentation-scope authoring questions, framed as J-11 at `docs/phase9-11-…:255` with blocking effect "Contradictory statements stay in force."

**Background and exact evidence references.**
- *Realtime side:* `docs/api-contract.md:524` states "Hosted Realtime behavior is **NOT TESTED**", while a 2026-10-26 subscribe/deny probe is recorded elsewhere as a direct observation (Phase 9.11 C-24). DEC-14 is approved as the transport decision — "APPROVED (Option B)" Realtime + FCM non-authoritative wake-up (register `:670`) — with "**Implementation Authorization: NONE**" (`docs/dec-14-fcm-owner-decision.md:9`), so the approval itself settles nothing about test status. Phase 9.10 keeps "Realtime/SMTP" as a P2 row in the blocker register (`:234-252`).
- *Preflight side:* the five DEC-02 preflight queries exist only as markdown (`docs/implementation/phase-9-release-readiness.md:71-136`; second naming at `docs/implementation/phase-8-deployment-log.md:61,75,87,104,113`) and none has been executed (register `:201`, `:322`). Measured absence this pass: `find . -iname '*preflight*.sql' -not -path './.git/*'` → **0**. C-27's consequence: "**Preflights are document text, not executable artifacts. Executing them later means transcribing from a markdown table**" (`:85`), with remedy "Owner: normalize preflights into `.sql` files under DEC-02". For comparison, the repository does keep executable SQL artifacts elsewhere: `supabase/tests/` holds 20 `.sql` files (measured: 19 at the top level + 1 in `fixtures/`), plus `run_sql_chain.sh` / `.ps1` runners.
- *Related:* DEC-04 is the preflight-formulation row and is itself unruled (J-8); the indistinguishable `20261028000100` migration (J-9) is the same class of "record is not machine-checkable" problem.

**Available choices (existing evidence only).** For Realtime: (a) record both statements with their dates and class of test, and stop treating either as the single truth (this is how C-17/C-26 handled count conflicts); (b) mark hosted Realtime `NOT TESTED` as the authoritative reading and annotate the 2026-10-26 probe as a limited historical observation; (c) require a fresh behavioral Realtime test (which needs DEC-02-class access). For preflights: (d) create `supabase/tests/`-style `.sql` artifacts under authorization; (e) leave them as markdown and accept transcription risk. All five are supported by existing text; none is currently in force as a ruling.

**Technical and operational consequences.** Creating preflight `.sql` files makes a future DEC-02 window mechanical and reviewable instead of hand-transcribed, at the cost of adding executable artifacts that must be kept in sync with the readiness playbook. Leaving Realtime status ambiguous means an owner could read approval (DEC-14 Option B) as though delivery behavior had been proven — which Phase 9.10's own rule forbids ("deployed Edge Function ≠ verified delivery behavior").

**Security, privacy, reliability and release impact.** Reliability: Realtime is the parent-alert delivery path in the approved architecture; its hosted behavior status must be stated accurately or alerts may be assumed working. Privacy: no new surface. Security: none. Release: both items are P2-class in the Phase 9.10 register, not among the two P1 blockers, but the Realtime statement is part of what DEC-14 delivery acceptance would eventually need.

**Dependencies on other decisions.** Preflight artifacts feed J-9 (mechanism) and J-1 (execution), and are the operational body of DEC-04 (J-8). Realtime status depends on DEC-14's "implementation authorization: NONE" boundary and on DEC-02-class deployment for any new test. Independent of DEC-03 and DEC-05.

**What approval would authorize.** A wording/adjudication ruling (and, if the owner so states, the creation of preflight `.sql` artifact files as a documentation-tooling act).

**What approval would explicitly NOT authorize.** Creating preflight files does not authorize running them (DEC-02 owns execution). No approval here authorizes hosted access, Realtime configuration, Edge Function deployment, FCM/Firebase provisioning, device testing (DEC-03), or any change to DEC-14's approved status. A preflight `.sql` file is an artifact, not a permission.

**Recommended questions for the owner.** (1) Which Realtime statement governs, and should the older probe be labeled a limited historical observation? (2) Should `supabase/tests/preflight_*.sql` (or another path) be created, and by which phase? (3) Should the readiness playbook's markdown tables become the generated output of those files instead of the source of truth? (4) Is a behavioral hosted Realtime test part of DEC-02's window, a later pass, or out of scope?

**Status: `AWAITING OWNER DECISION`**

---

## D. Decision Dependencies

```
                     J-1  DEC-02 ruling  ──────────────┐
                        │                               │
                        ├── J-9   apply mechanism (needs a channel before any write)
                        ├── J-11  preflight .sql artifacts (mechanical execution aid)
                        ├── J-8   DEC-04 = the preflight formulation row
                        └──► enables Gate C closure ──┐
                                                      │
J-2  DEC-03 ruling ──► enables Gate B closure ────────┤
   ├── J-6 audio acceptance plan scope (execution rides on DEC-03)
   ├── J-4 relay legs (a plan cannot test relay until relay exists)
   └── J-5 Managed-Mode device verification (later)

J-3 severity/blocker set ──► defines what "ready" and "blocking" mean for everything above
J-5 GATE-EXIT-01 ordering ──► blocks Managed Mode release; interacts with J-3, needs J-2 for QA
J-4 TURN ──► independent capability decision; any deployment act touches the DEC-02 class of act
J-7 stale-wording edits ──┐
J-10 commit / state convention ─┴─► documentation-and-repo hygiene only; both are independent of J-1…J-6

HARD ORDERING RULES (documented, not assumed):
  • DEC-02 ⊥ DEC-03. Neither grants the other's scope. (register :292, restated :10, :18)
  • No approval may be inferred from silence, from a recommendation, or from this packet. (register :10 "Never assume owner approval.")
  • General release is prohibited until Gates B and C have independently passed.
    (docs/implementation/phase-9-release-readiness.md:286)
  • The standby playbook executes nothing before written approval for both DEC-02 and DEC-03.
    (docs/implementation/phase-9-release-readiness.md:67)
```

Cross-impact of leaving items undecided: J-1 and J-2 undecided keep Gates B and C BLOCKED and Gate D NO-GO (register `:412`); J-3 undecided leaves two different blocker sets in force (C-36); J-4 undecided leaves cross-network audio unprovable (J-4 blocking effect, `:248`); J-5 undecided keeps Managed Mode blocked (`:249`); J-6 undecided leaves the core assistance function unverified (`:250`); J-7 undecided keeps stale statuses in front of readers (`:251`); J-8 undecided lets the register imply decisions that were never made (`:252`); J-9 undecided risks silent double-apply if J-1 is ever approved (`:253`); J-10 undecided leaves the 2026-11-06 work uncommitted (`:254`); J-11 undecided leaves contradictory statements in force (`:255`).

---

## E. Authorization Boundary Matrix

| Operation | Authorized today, without any ruling | Requires which J-item / DEC | Explicitly NOT granted by |
|---|---|---|---|
| Read any file, run read-only git/grep | **YES** | none | — |
| Author documentation-only governance reports | **YES** (this packet) | none | does not authorize edits to registers or history |
| Prepare decision briefs, plans, pass/fail criteria | **YES** (Phase 9.10 §I.1; Phase 9.11 `:213`) | none | does not authorize execution |
| Execute the 5 hosted preflight queries | **NO** | **J-1 / DEC-02** | DEC-03, DEC-05, DEC-12…16 approvals |
| Apply Migrations 1–4 to hosted | **NO** | **J-1 / DEC-02** (+ **J-9** channel) | DEC-03, DEC-14 approval, register edits |
| Deploy Edge Functions `account`, `family-admin`, `device-command` | **NO** | **J-1 / DEC-02** | DEC-03; the 9 already-hosted older bundles |
| Redeploy `remote-session` (the `F1` fix) | **NO** | **J-1 / DEC-02** neighborhood (Stage 3 step 4) | DEC-14 Option B approval |
| Build any APK / run Gradle | **NO** | **J-2 / DEC-03** | DEC-02, DEC-13 Option B, DEC-15, DEC-16 |
| Run ADB / pair a device / operate the emulator | **NO** | **J-2 / DEC-03** | DEC-02 |
| Execute any QA matrix row | **NO** — all **75/75** remain `NOT RUN` | **J-2 / DEC-03** | DEC-02; historical `PASS` observations |
| Hosted behavioral RLS / auth / Realtime / function-behavior tests | **NO** | **J-1 / DEC-02** (+ device rows: DEC-03) | successful database inspection; deployment timestamps |
| Create or change any secret (`TURN_URL`, `TURN_SECRET`, service role, FCM keys) | **NO** | **J-4** (does not exist yet) / DEC-14 has "**Implementation Authorization: NONE**" (`dec-14:9`) | DEC-02's registered three objects |
| Provision or configure coturn / TURN | **NO — no owning decision** | **J-4** | DEC-02, DEC-03, `docs/turn_configuration.md` §5 reference text |
| Activate any scheduler / `pg_cron` / cron webhook | **NO — prohibited by DEC-05 Choice B** | a DEC-05 *change* of ruling, not an approval | any other decision; register `:291` |
| Implement website filtering | **NO — DEC-15 Option D (Deferred)** | a new DEC-15 ruling | DEC-15 approval as recorded |
| Implement screen mirroring / recording / screenshots | **NO — DEC-16 Option A (Excluded)** | a new DEC-16 ruling | DEC-16 approval as recorded |
| Device Owner / Managed Mode work or release | **NO — GATE-EXIT-01 `NOT DESIGNED`** | **J-5** (+ DEC-03 for verification) | DEC-13 Option B approval (`dec-13:86`) |
| Edit the four stale "remain PROPOSED" lines | **NO** | **J-7** | Phase 9.11's findings themselves |
| Edit the canonical register (or its mirror) | **NO** | **J-7** / **J-3** as scoped | any documentation pass's own authority |
| Rewrite historical test reports or evidence | **NO — categorically out of scope** | none; forbidden | J-7 (annotation of decision docs ≠ report rewriting) |
| Commit / push / stage / unstage | **NO** | **J-10** | J-1…J-9, J-11 |
| Start Phase 10 | **NO** | none — separately authorized work | every item in this packet |

**Independence statements (restated so no reader can merge them).** DEC-02 does **not** authorize APK builds, ADB or Android QA (register `:313` scope vs `:31` scope). DEC-03 does **not** authorize hosted SQL, migrations or Edge Function deployments (`:31` scope vs `:313`). DEC-05 remains **on-demand only** (`:291`: "No pg_cron, no Supabase scheduled trigger, no external cron webhook"). DEC-12…DEC-16 remain approved **exactly as recorded** at `:668-672` with implementation authorization expressly withheld ("*No implementation authorization may be inferred from any approved architecture decision*", `docs/dec-15-…:44`, `docs/dec-16-…:46`; register `:377`). No approval is inferred from silence, from any recommendation in this packet, or from the existence of this packet.

---

## F. Decisions That Must Remain Pending

| ID | Recorded status | Must remain | Evidence |
|---|---|---|---|
| **DEC-02** | `PENDING OWNER AUTHORIZATION` — P1 Release Blocker; scope "0% executed" | Pending until the owner rules (J-1) | register `:30`, `:171`, `:198`, `:289`, `:313` |
| **DEC-03** | `PENDING OWNER AUTHORIZATION` — P1 Release Blocker; 75/75 `NOT RUN` | Pending until the owner rules (J-2) | register `:31`, `:172`, `:290`, `:351-355`; `phase-8-android-qa-report.md:408` |
| **DEC-04** | `PREFLIGHT FORMULATED / READY` → `READY / CARRIED FORWARD` — no ruling | Carried forward, unruled | register `:33`, `:174`, `:665`; C-33 `docs/phase9-11-…:96` |
| **DEC-06…DEC-11** | `PRESERVED ADDITIVELY / DEFERRED`, `RETAINED AS REVIEWED FALLBACK`, `SPECIFICATION DRAFTED / READY`, `PRESERVED ON STANDBY`, `PREPARED FOR POST-APPLY`, `DOCUMENTED SPECIFICATION / RATIFIED` — all `CARRIED FORWARD`, no ruling | Carried forward, unruled; `RATIFIED` (DEC-11) remains a status word, not a ruling | register `:175-180`, `:667`, `:363`; `docs/phase9-10-…:56`, `:69`; C-34 `:97` |
| **Severity lexicon / blocker set** | Conflicting live models | Unresolved until J-3 | register `:412` vs `docs/dec-15-…:117`, `docs/dec-16-…:138`; C-36 `:99` |
| **TURN / relay infrastructure** | **No owning decision exists** (`F4` capability gap) | Unowned until J-4 opens it | `docs/phase9-11-…:221`; `docs/runtime-failure-analysis.md:88-95` |
| **GATE-EXIT-01 safe exit** | `NOT DESIGNED / RELEASE BLOCKER`; requirement approved, design unauthorized | Blocked until J-5 orders it | `docs/dec-12-screen-time-bedtime-decision.md:198`; register `:455`; `docs/phase9-10-…:237` |
| **Audio acceptance plan** | Two plans exist, both unexecuted (`armed` / `cannot run today`) | Unapproved until J-6 | `docs/mic-lifecycle-test-plan.md:3`; `docs/two-device-webrtc-test-plan.md:12` |
| **Stale wording corrections** | Findings recorded; zero edits performed | Not performed until J-7 | C-28…C-32 `docs/phase9-11-…:91-95` |
| **Uncommitted governance docs** | One `AM`, two `??`; no commit authorized | Untouched until J-10 | `git status --porcelain` (this pass); C-41 `:109` |
| **Realtime status / preflight artifacts** | Contradictory statements in force | Unadjudicated until J-11 | `docs/api-contract.md:524`; C-24 `:82`; C-27 `:85` |

**Approved and NOT to be reopened by this packet:** DEC-01 (Choice B, local-only evidence; GAP DUR-01 accepted open), DEC-05 (Choice B, on-demand only), DEC-12 (D1-B, B1-B, O1-C, P1-A, DEFER), DEC-13 (Option B), DEC-14 (Option B), DEC-15 (Option D — Deferred), DEC-16 (Option A — Excluded): register `:662`, `:666`, `:668-672`.

---

## G. Not Authorized Operations

Explicitly **not authorized** by this phase, and not performed: applying, executing or testing hosted migrations or preflight queries; deploying or redeploying any Edge Function; any Supabase dashboard, CLI, SQL or network access (including read access); creating, reading, rotating or deleting any secret; any Firebase/FCM provisioning; any RLS, Auth, Realtime or Storage configuration change; building, installing or uninstalling APKs; any Gradle invocation; any ADB command; pairing or operating the Realme 7, the parent emulator or any AVD; executing any of the 75 QA rows; running microphone, camera, audio, screen-capture or network tests; verifying human audibility of any kind; configuring TURN, coturn, ICE or WebRTC; changing Device Owner or Device Administrator state or provisioning Managed Mode; enabling any scheduler, cron job, recurring trigger or webhook; implementing website filtering (DEC-15 Deferred) or screen mirroring/recording/screenshots (DEC-16 Excluded); editing Flutter/Dart/Kotlin/TypeScript/SQL source, `AndroidManifest.xml`, `AudioAssistanceService.kt` or `supabase/`; modifying `phase-9-owner-decision-register.md` or its `docs/implementation/` mirror; rewriting any historical test report, evidence file or the Phase 9.9.2.2 / 9.10 / 9.11 records; creating a new canonical phase tracker; adding any DEC row (including the DEC-17 J-4 contemplates); `git add`, `commit`, `push`, `reset`, `restore`, `checkout`, `clean`, `stash`; converting any `NOT TESTED` / `NOT VERIFIED` / `NOT RUN` / `NOT AVAILABLE` finding into a positive claim; treating an architecture approval as implementation permission; and starting Phase 10.

---

## H. Evidence References

**Primary governance.** [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) (682 lines; DEC-02 row `:30`, DEC-03 row `:31`, status matrix `:170-180`, `:198`, `:201`, `:277`, `:279`, `:282`, `:289-292`, `:313`, `:317-320`, `:322`, `:324`, `:331`, `:337`, `:351-355`, `:359`, `:363`, `:377`, `:412`, `:444`/`:487`/`:530`/`:582`/`:633` approval addenda, `:455` safe exit, `:662-672` current snapshot) and its byte-identical mirror [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md).

**Current-phase analysis chain.** [`docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md`](phase9-11-evidence-contradiction-and-decision-readiness-report.md) (C.1 `:54-71`, C.2 `:75-85`, C.3 `:91-99`, C.4 `:105-109`, §D `:113-131`, §H `:213`-`:221`, §J `:245-255`, verdict `:228`, tally `:271`) → [`docs/phase9-10-consolidated-release-readiness-governance-blocker-review.md`](phase9-10-consolidated-release-readiness-governance-blocker-review.md) (verdict `:8`, hosted `:102`/`:106`/`:143-152`, blocker register `:230-256`, §I `:301-328`) → [`docs/phase9-9-2-2-documentation-completion-acceptance-record.md`](phase9-9-2-2-documentation-completion-acceptance-record.md) (accepted documentation-complete record, currently `AM`).

**Registers and readiness.** [`phase-9-open-gaps.md`](../phase-9-open-gaps.md) (`:10` no-remediation warning, `:28` HOST-01, `:29` AND-01/GATE-B-01, `:40` HOST-02, `:47-57` HOST-01 defect detail (audit-gap sentence at `:50`; the `SQL-05` identifier itself appears in `docs/evidence/phase5/MANIFEST.md:40` and `docs/evidence/phase6/MANIFEST.md:28`), `:166`, `:167`, `:222`), [`docs/implementation/phase-9-release-readiness.md`](implementation/phase-9-release-readiness.md) (`:67` frozen standby, `:71-136` preflights, `:152-168` Stage 3, `:213`, `:286`, `:311`), [`phase-9-regression-matrix.md`](../phase-9-regression-matrix.md) (`:3` clean-tree warning, `:12`, `:111`, `:128`), [`phase-8-android-qa-report.md`](../phase-8-android-qa-report.md) (`:12`, `:30-32`, `:40`, `:220`, `:223-226`, `:271`, `:275`, `:280`, `:286`, `:322`, `:359`, `:408`, `:410`), [`phase-8-open-gaps.md`](../phase-8-open-gaps.md) (`:35-40` severity definitions, `:52`, `:79-85`), [`docs/implementation/phase-5-owner-decision-log.md`](implementation/phase-5-owner-decision-log.md) (`:101-107` Ruling #9), [`docs/implementation/phase-9-git-integrity-report.md`](implementation/phase-9-git-integrity-report.md) (`:23`, `:24`, `:25`, `:49`, `:111`), [`docs/implementation/phase-9-decision-execution-log.md`](implementation/phase-9-decision-execution-log.md) (`:55-62`, `:112`, `:171-177`), [`docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md`](evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md) (`:126`), [`docs/evidence/phase9/MANIFEST.md`](evidence/phase9/MANIFEST.md) (`:9`), [`docs/evidence/phase7/MANIFEST.md`](evidence/phase7/MANIFEST.md) (`:61`), [`docs/evidence/phase8/MANIFEST.md`](evidence/phase8/MANIFEST.md) (`:69`).

**Decision records.** [`docs/p0-decision-specifications.md`](p0-decision-specifications.md) (`:4`, `:49`, `:104`, `:159`), [`docs/dec-12-screen-time-bedtime-decision.md`](dec-12-screen-time-bedtime-decision.md) (`:4`, `:8`, `:17-23`, `:25`, `:182`, `:198`), [`docs/dec-13-device-owner-decision.md`](dec-13-device-owner-decision.md) (`:4`, `:6-10`, `:13`, `:86`, `:302`, `:379-395`, `:496-499`), [`docs/dec-14-fcm-owner-decision.md`](dec-14-fcm-owner-decision.md) (`:6-9`, `:28-29`, `:37-48`), [`docs/dec-15-website-filtering-owner-decision.md`](dec-15-website-filtering-owner-decision.md) (`:6`, `:36`, `:44`, `:117`, `:186`, `:360-368`, `:367`, `:376`), [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md) (`:6`, `:9`, `:46`, `:138`, `:268`, `:295-303`, `:311`), [`docs/phase9-3-dec12-approval-governance-consolidation.md`](phase9-3-dec12-approval-governance-consolidation.md) (`:154`), [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md) / [`docs/phase9-9-dec16-owner-approval-record.md`](phase9-9-dec16-owner-approval-record.md).

**Hosted state (historical, read-only record).** [`docs/supabase-hosted-state-verification-2026-11-05.md`](supabase-hosted-state-verification-2026-11-05.md) (`:5-7` window, `:84-87`, `:137`, `:145`, `:147`, `:167`, `:179`, `:186`), [`docs/stage7_hosted_migration_apply_2026-10-29.md`](stage7_hosted_migration_apply_2026-10-29.md) (`:26`, `:92-93`), [`docs/backend.md`](backend.md) (`:17`, `:101`, `:282`, `:698`, `:786-787`), [`docs/api-contract.md`](api-contract.md) (`:524`), [`docs/implementation/phase-8-deployment-log.md`](implementation/phase-8-deployment-log.md) (`:30`, `:61-113`, `:204`), [`docs/implementation/phase-7-deployment-log.md`](implementation/phase-7-deployment-log.md) (`:378-383`), [`docs/verification-report.md`](verification-report.md) (`:35`).

**Audio / device / relay evidence.** [`docs/mic_only_test_report.md`](mic_only_test_report.md) (`:25-28`, `:47`, `:65`, `:86`, `:87`, `:90`, `:117-118`, `:124`, `:139`, `:166`, `:167`, `:212`), [`docs/runtime-mic-test-report.md`](runtime-mic-test-report.md) (`:36`, `:93-95`, `:123`, `:126`, `:162`, `:175`, `:213-214`, `:218`), [`docs/runtime-failure-analysis.md`](runtime-failure-analysis.md) (`:35`, `:45`, `:49`, `:88-95`), [`docs/mic_full_audit_report.md`](mic_full_audit_report.md) (`:19-32`, `:21`, `:84`, `:115`, `:174`, `:175`), [`docs/microphone_configuration_audit.md`](microphone_configuration_audit.md) (`:31`, `:35`, `:46`, `:72`, `:74`, `:78`, `:89`, `:183`), [`docs/stage2_background_audio_report.md`](stage2_background_audio_report.md) (`:7`, `:45`, `:53`, `:59`, `:115-117`), [`docs/stage2_device_verification_report.md`](stage2_device_verification_report.md) (`:5`, `:68`, `:84`, `:89`, `:102`), [`docs/stage5_background_audio_survival_report.md`](stage5_background_audio_survival_report.md) (`:144`, `:148`, `:175`), [`docs/stage6_account_and_media_recovery_report.md`](stage6_account_and_media_recovery_report.md) (`:216`, `:240`, `:244`, `:260`, `:268`), [`docs/stage7_two_device_end_to_end_report.md`](stage7_two_device_end_to_end_report.md) (`:252`, `:282`, `:353`), [`docs/evidence/stage8/e1-15min.txt`](evidence/stage8/e1-15min.txt) (`:15-16`, `:19-22`, `:26-28`), [`docs/evidence/stage8/f1-expiry-12-16Z.txt`](evidence/stage8/f1-expiry-12-16Z.txt) (`:5-10`, `:29-30`), [`docs/evidence/stage8/media-verified-11-55Z.txt`](evidence/stage8/media-verified-11-55Z.txt) (`:1-4`, `:10`, `:13`, `:22-23`), [`docs/turn_configuration.md`](turn_configuration.md) (`:14-40`, `:50`, `:61`, `:92`, `:115`, `:143-152`, `:195`, `:285`, `:308-325`, `:393-401`), [`docs/two-device-webrtc-test-plan.md`](two-device-webrtc-test-plan.md) (`:12`, `:27`, `:85`, `:100`, `:431`, `:440-451`, `:483`, `:507`, `:529`), [`docs/mic-lifecycle-test-plan.md`](mic-lifecycle-test-plan.md) (`:3`, `:7-16`, `:17-25`, `:44`, `:66`, `:187`, `:196`, `:202`), [`docs/two-device-e2e-checklist.md`](two-device-e2e-checklist.md) (`:82`, `:97`), [`docs/device-owner-provisioning.md`](device-owner-provisioning.md) (`:709-724`), [`docs/implementation/phase-4-android-validation-plan.md`](implementation/phase-4-android-validation-plan.md), [`docs/implementation/phase-7-regression-matrix.md`](implementation/phase-7-regression-matrix.md) (`:145`).

**Source and config (read, never modified).** [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) (`:10`, `:11`, `:15`, `:91-93`), [`android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt`](../android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt) (`:76-77`, `:253`, `:622-629`), [`supabase/functions/_shared/turn.ts`](../supabase/functions/_shared/turn.ts) (`:35`, `:84-93`, `:103`), [`supabase/functions/cron/index.ts`](../supabase/functions/cron/index.ts) (`:38-43`), [`supabase/config.toml`](../supabase/config.toml) (`:92-95`), [`supabase/migrations/20261030000300_retention_sweep.sql`](../supabase/migrations/20261030000300_retention_sweep.sql) (`:6`), [`supabase/migrations/20260101000100_functions.sql`](../supabase/migrations/20260101000100_functions.sql) (`:947-967`), [`.env.example`](file:///d:/parentcontrol_app/.env.example) (`:13`), [`.gitignore`](file:///d:/parentcontrol_app/.gitignore) (`:22`, `:53-54`, `:77-78`).

**Missing-source declarations (`NOT FOUND` / `NOT AVAILABLE`).** No `docs/phase9-12-*` file existed before this pass (this packet is the first). No preflight `.sql` artifact anywhere (measured `0`). No `supabase_migrations` ledger. No grant record for DEC-02 or DEC-03 anywhere. No TURN/relay decision row in the register (`F4` is a defect, not a DEC). No TURN cost, vendor, price or sizing figure. No `phase-8-release-readiness.md`. `docs/implementation/` copies of the DEC-12…DEC-16 records do not exist (root paths only). Post-2026-11-05 hosted state, post-2026-11-05 GATE-EXIT-01 design work, and any owner ruling for DEC-04 / DEC-06…DEC-11 are all `NOT AVAILABLE`.

---

## I. Verification and Change Statement

**Created:** [`docs/phase9-12-owner-decision-packet.md`](file:///d:/parentcontrol_app/docs/phase9-12-owner-decision-packet.md) — this document, and nothing else.

**Modified:** none. **Deleted:** none. **Historical reports:** unmodified, including the deliberately uncorrected Phase 9.9.2.2 `.git/index`-mtime sentence (C-37) and the Phase 9.10 citation items already recorded in Phase 9.11 §L. **Registers:** unmodified and re-verified byte-identical —

```
$ sha256sum phase-9-owner-decision-register.md docs/implementation/phase-9-owner-decision-register.md
3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f *phase-9-owner-decision-register.md
3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f *docs/implementation/phase-9-owner-decision-register.md
$ cmp -s … && echo REGISTERS IDENTICAL
REGISTERS IDENTICAL
```

**Verification performed (read-only, this pass):**
1. `git rev-parse HEAD` → `a2faa5fb70f84638359154c68d19ce304fadab36`; `git rev-parse --abbrev-ref HEAD` → `main`; `git status --porcelain` → the three entries quoted in C.10 (`AM`, `??`, `??`); `git stash list` → empty.
2. Register SHA-256 identity and `cmp` (above).
3. Counts measured directly: `ls supabase/migrations | wc -l` → **14**; `ls -1 -d supabase/functions/*/ | grep -v _shared | wc -l` → **10**; `find . -iname '*preflight*.sql' -not -path './.git/*' | wc -l` → **0**; `find supabase/tests -name '*.sql' | wc -l` → **20** (19 top-level + 1 in `fixtures/`).
4. QA matrix counted mechanically: `grep -cE '^\| \*\*[A-Z]+-[0-9]+\*\* \|' phase-8-android-qa-report.md` → **75**; the same pattern restricted to rows ending `NOT RUN` → **75**. **75/75 `NOT RUN` is preserved exactly; no row was executed.**
5. Direct line reads of every citation quoted in this packet (register `:30`, `:31`, `:171`, `:172`, `:198`, `:201`, `:277`, `:289-292`, `:313`, `:317-320`, `:322`, `:331`, `:337`, `:355`, `:363`, `:377`, `:412`, `:455`, `:662-672`; `docs/dec-12-…:8`/`:198`, `docs/dec-13-…:13`, `docs/dec-14-…:9`/`:28`, `docs/dec-15-…:44`, `docs/dec-16-…:46`, `docs/p0-decision-specifications.md:4`/`:104`, `docs/api-contract.md:524`, `docs/turn_configuration.md:143`/`:316-318`/`:393-401`, `docs/supabase-hosted-state-verification-2026-11-05.md:147`, `phase-9-open-gaps.md:28`/`:29`, `docs/mic-lifecycle-test-plan.md:3`, `docs/implementation/phase-9-release-readiness.md:71`/`:152`/`:166`).
6. Non-grant confirmation: repo-wide grep for DEC-02/DEC-03 approval language returned only negations, future conditions, gate statements and unchecked sign-off boxes — consistent with Phase 9.11 C-35 (`:98`) and `docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md:126`. **No grant found.**
7. Four research subagents (J-1 hosted scope, J-2/J-4/J-6 Android-audio-TURN, governance-status/severity, Git-state/house-style) were run in parallel and their findings cross-checked against direct reads; two citations offered by a subagent were corrected during this pass before being used (the DEC-15/16 cost line is `docs/turn_configuration.md:317-318`, not `:316`; the hosted TURN/audibility statements were re-quoted from `docs/runtime-failure-analysis.md:88-95` and `docs/evidence/stage8/media-verified-11-55Z.txt:22-23`).

**Verification NOT performed:** any hosted access whatsoever (dashboard, CLI, SQL, network) — the backend was not touched, and nothing in this packet was re-verified against hosted state; any Firebase action or secret inspection; any build, Gradle, ADB, install, device, emulator or QA execution; any microphone, audio, network, ICE or TURN test; any behavioral RLS/auth/Realtime/function test; any scheduler check beyond reading files on disk; any Git mutation. **Independent verification is not claimed for any historical finding** — every hosted, device and audio statement above is a citation of a dated repository record.

**Owner-decision accounting:** **11 briefs authored, 0 missing.** Eleven J-items → J-1 … J-11, each ending `AWAITING OWNER DECISION`. **Decisions still awaiting the owner: all eleven** (J-1 DEC-02, J-2 DEC-03, J-3 severity/blocker set, J-4 TURN decision-opening, J-5 safe-exit order, J-6 audio-acceptance scope, J-7 stale-wording authorization, J-8 DEC-04 + DEC-06…DEC-11, J-9 apply mechanism, J-10 Git fate, J-11 Realtime/preflight adjudication), plus the two registered PENDING blockers DEC-02 and DEC-03 and the seven unruled carried-forward decisions DEC-04, DEC-06…DEC-11. **No approval was inferred, assumed, recommended-as-decided, or fabricated.** DEC-02 and DEC-03 remain independent; DEC-05 remains on-demand only; DEC-01, DEC-12, DEC-13, DEC-14, DEC-15 and DEC-16 remain approved exactly as recorded and were not modified.

**Release verdict carried forward unchanged:** **NOT RELEASE READY — NO-GO FOR GENERAL RELEASE / GO FOR LOCAL VERIFICATION BASELINE ONLY.**

**Confirmation:** No implementation change, no hosted Supabase operation or inspection, no Firebase provisioning, no secret change, no APK build, no Gradle execution, no ADB command, no device pairing or hardware testing, no audio testing, no TURN configuration, no Device Owner provisioning, no scheduler activation, no deployment, no historical report rewriting, no governance register modification, and no agent-executed Git state mutation occurred. HEAD remains `a2faa5fb70f84638359154c68d19ce304fadab36` on `main`; the staged Phase 9.9.2.2 record and the uncommitted Phase 9.10 / 9.11 reports are preserved exactly as found — this packet's own file is likewise left uncommitted — measured: `git status --porcelain` lists it as `??` (untracked, **not** staged), unlike the Phase 9.9.2.2 record which remains `AM` — and no cleanup was performed. Phase 10 was NOT started.

---

**STOPPED. Owner decision packet complete: eleven independent briefs authored, every one ending `AWAITING OWNER DECISION`, with zero approval inferred and zero operations performed. The release verdict remains NOT RELEASE READY. Awaiting explicit owner rulings on J-1 … J-11 — DEC-02 and DEC-03 staying independent — before any implementation, hosted, device, deployment, documentation-edit or Git activity.**
