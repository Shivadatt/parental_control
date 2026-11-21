# 11 — Future Authorization Matrix

**Purpose:** Separate every future action into an independently approved gate. **No gate is executed in Phase 4.** Approval of one gate never implies another.

**Current status of every gate: `NOT GRANTED`.**

---

## 1. Gate definitions

### Gate A — Owner approves the selected recovery design
**Authorizes:** accepting Option C (report 04) as the intended remediation, including the security limitations in report 05 and the transaction requirement in report 06.  
**Does not authorize:** code, schema, deployment, device changes, or tests.  
**Prerequisites:** this report set read; owner decisions in report 12 resolved or explicitly deferred.  
**Evidence of approval:** written owner decision naming Option C and the accepted residual risks.

### Gate B — Owner authorizes source-code implementation
**Authorizes:** editing Dart, Kotlin, and Edge Function source on a branch, plus unit tests.  
**Does not authorize:** migrations, database changes, deployment to any environment, or installing on a real device.  
**Prerequisites:** Gate A.  
**Scope limits:** exact file list from report 07 §9; no unrelated refactors; no changes to `requireDevice` semantics; no automatic recovery.  
**Evidence:** approved change list + branch name + reviewer.

### Gate C — Owner authorizes schema / RPC changes
**Authorizes:** a new additive migration: recovery-challenge table, RLS/grants, two SECURITY DEFINER RPCs, audit event types.  
**Does not authorize:** applying it to production, altering existing tables/columns, changing existing RPCs, or touching data.  
**Prerequisites:** Gate A; RPC contract frozen (report 06); transaction/race tests designed (report 09 §6); security review of grants.  
**Evidence:** migration diff review, grant matrix, rollback plan, test plan reference.

### Gate D — Owner authorizes deployment to a specifically named environment
**Authorizes:** deploying the approved Edge Functions and migration to **one named** environment (e.g. staging project ref).  
**Does not authorize:** any other environment; production is a separate, explicit decision even if staging passes.  
**Prerequisites:** Gates B and C complete for that artifact; build/reproducibility record; rollback/kill-switch verified.  
**Evidence:** environment name, project ref, deployed function versions, migration checksum, deployment log.

### Gate E — Owner authorizes test-device credential recovery
**Authorizes:** performing a credential rotation on a **named test device / test family**, or on the specific device the owner names, using a Parent approval.  
**Does not authorize:** touching other families/devices; reading or exporting secrets; using production data beyond the named test scope.  
**Prerequisites:** Gate D in the target environment; test plan RC-05/RC-24/RC-25 ready; rollback plan.  
**Evidence:** device/family identifiers, before/after public device rows, audit rows, redacted HTTP results.

### Gate F — Owner authorizes full two-device regression testing
**Authorizes:** the complete physical two-device E2E matrix (report 09 §8) and compatibility matrix, including reinstall/reboot/negative tests.  
**Does not authorize:** production deployment of the feature beyond the tested environment, or changes outside the test families.  
**Prerequisites:** Gate E successful for the core path; named devices and builds; test data plan.  
**Evidence:** full test log, screenshots/dumps, APK SHA-256, build commit, pass/fail per RC ID.

---

## 2. Artifact × gate matrix

`✔` = required for that artifact. Empty = not covered by that gate.

| Artifact / action | A Design | B Source | C Schema/RPC | D Deploy (named env) | E Test-device rotation | F Two-device regression |
|---|---|---|---|---|---|---|
| Accept Option C design | ✔ | | | | | |
| Freeze challenge/RPC contract | ✔ | | ✔ | | | |
| Dart changes (Parent + Child) | | ✔ | | | | |
| Kotlin changes (classification/resync) | | ✔ | | | | |
| Edge Function handlers | | ✔ | | | | |
| Unit tests (Dart/Kotlin/Deno) | | ✔ | | | | |
| New table + RLS + grants | | | ✔ | | | |
| New RPCs (request/redeem) | | | ✔ | | | |
| SQL integration tests | | | ✔ | | | |
| Migration applied to staging | | | | ✔ | | |
| Functions deployed to staging | | | | ✔ | | |
| APK built and installed on test Child | | | | ✔* | ✔ | ✔ |
| Credential rotated on a real device | | | | | ✔ | ✔ |
| Full two-device matrix | | | | | | ✔ |
| Production deploy | separate | separate | separate | separate (production) | separate | separate |

`*` Build/install is an environment action that must be named in the Gate D decision; it is not implicitly authorized by Gate B.

---

## 3. Explicit non-implications

- **A ≠ B.** Approving the design does not authorize writing code.
- **B ≠ C.** Code that calls a non-existent RPC is not a reason to create it.
- **C ≠ D.** A migration file existing in the repo does not authorize applying it anywhere.
- **D(staging) ≠ D(production).** Each environment is named separately.
- **E ≠ F.** One successful test-device rotation does not authorize broad regression on other devices/families.
- **F ≠ release.** Passing regression does not authorize a production rollout or a store release.
- **Any gate ≠ reading credentials.** No gate authorizes reading, printing, exporting or storing a device secret, JWT, service-role key or hash.
- **Any gate ≠ altering unrelated defects.** E2E-002/003/004 remain separate workstreams.

---

## 4. Pre-conditions checklist per gate

### Gate A
- [ ] Reports 01–12 reviewed
- [ ] Recommended option accepted or changed
- [ ] Residual risks (no physical-possession proof; compromised parent session) accepted
- [ ] Owner decisions in report 12 resolved or marked "deferred with default"

### Gate B
- [ ] Gate A recorded
- [ ] Branch named
- [ ] File list approved
- [ ] No-auto-recovery rule acknowledged
- [ ] Secret-logging prohibition acknowledged

### Gate C
- [ ] Gate A recorded
- [ ] RPC contract frozen (inputs, outputs, locks, error codes)
- [ ] Grant/RLS review complete
- [ ] Additive-only migration confirmed
- [ ] Rollback plan written
- [ ] Race/atomicity tests designed

### Gate D
- [ ] Gates B and C complete for the artifacts
- [ ] Environment + project ref named
- [ ] Migration checksum and function versions recorded
- [ ] Kill-switch/feature flag verified
- [ ] Rollback rehearsal plan

### Gate E
- [ ] Gate D successful in the target environment
- [ ] Test device/family named
- [ ] Core RC tests ready
- [ ] Redaction rules for evidence
- [ ] Owner present or reachable

### Gate F
- [ ] Gate E core path passed
- [ ] Devices/builds/APKs recorded
- [ ] Full RC matrix scheduled
- [ ] Test-data cleanup plan
- [ ] Separate production decision not implied

---

## 5. Evidence retention

For every granted gate, retain:
- the written approval (who, what, when, environment, scope);
- the exact commit/branch;
- migration checksum and function versions;
- redacted test output;
- public-column before/after snapshots;
- audit records;
- any rollback performed.

No credential value may appear in any retained artifact.

---

## 6. Current authorization state

| Gate | State |
|---|---|
| A | **NOT GRANTED** |
| B | **NOT GRANTED** |
| C | **NOT GRANTED** |
| D | **NOT GRANTED** |
| E | **NOT GRANTED** |
| F | **NOT GRANTED** |

Phase 4 stops at the owner decision record.
