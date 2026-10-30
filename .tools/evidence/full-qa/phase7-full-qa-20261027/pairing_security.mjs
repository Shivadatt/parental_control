// Phase 7 — pairing security (task 4), runnable subset.
// A fresh code cannot be created today (see pairing_blocked evidence), so this
// covers every check that does not need one, plus the brute-force limiter.
import {
  qa, FAM_A, FAM_B, login, fn, ok, code, pass, record, summary, save,
} from './_lib.mjs';

async function main() {
  const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const parentB = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childA = await login(qa.CHILD_A_USER, qa.CHILD_A_PASS);
  const childB = await login(qa.CHILD_B_USER, qa.CHILD_B_PASS);
  const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);

  // --- Fresh-code availability (fixture state probe) ----------------------
  for (const [label, who] of [['childA', childA], ['childB', childB], ['childC', childC]]) {
    const r = await fn('pairing', who.token, { action: 'create' });
    record(`pairing.create_quota.${label}`, r.status === 200 ? 'AVAILABLE' : 'BLOCKED', {
      status: r.status, code: code(r), msg: (r.json?.error?.message ?? '').slice(0, 60),
    });
  }

  // --- Who may create a code ---------------------------------------------
  const asParent = await fn('pairing', parentA.token, { action: 'create' });
  pass(!ok(asParent) && asParent.status === 403, 'pairing.parent_cannot_create_code', { status: asParent.status, code: code(asParent) });
  const asAnon = await fn('pairing', null, { action: 'create' });
  pass(asAnon.status === 401, 'pairing.anon_cannot_create_code', { status: asAnon.status, code: code(asAnon) });

  // --- Redeem authorisation (no valid code required) ----------------------
  const foreignFamily = await fn('pairing', parentA.token, { action: 'redeem', code: 'ABCDEFGH', family_id: FAM_B });
  pass(!ok(foreignFamily) && foreignFamily.status === 403, 'pairing.redeem_into_foreign_family_denied', { status: foreignFamily.status, code: code(foreignFamily) });
  const asChild = await fn('pairing', childC.token, { action: 'redeem', code: 'ABCDEFGH', family_id: FAM_B });
  pass(!ok(asChild) && asChild.status === 403, 'pairing.child_cannot_redeem', { status: asChild.status, code: code(asChild) });
  const anonRedeem = await fn('pairing', null, { action: 'redeem', code: 'ABCDEFGH', family_id: FAM_A });
  pass(anonRedeem.status === 401, 'pairing.anon_redeem_denied', { status: anonRedeem.status, code: code(anonRedeem) });
  const badFamilyUuid = await fn('pairing', parentA.token, { action: 'redeem', code: 'ABCDEFGH', family_id: 'not-a-uuid' });
  pass(badFamilyUuid.status === 400, 'pairing.redeem_malformed_family_rejected', { status: badFamilyUuid.status, code: code(badFamilyUuid) });

  // --- Enumeration resistance: unknown codes are answered uniformly ------
  // Budget: at most 3 invalid redemptions per parent, so the 5-per-10-minute
  // window is not exhausted for the concurrently running device agent.
  const c1 = await fn('pairing', parentA.token, { action: 'redeem', code: 'ZZZZZZZZ', family_id: FAM_A });
  const c2 = await fn('pairing', parentA.token, { action: 'redeem', code: 'QQQQ2468', family_id: FAM_A });
  const uniform = c1.status === c2.status && code(c1) === code(c2) && c1.status === 400;
  pass(uniform, 'pairing.unknown_codes_uniform_error', { a: c1.status, b: c2.status, code_a: code(c1), code_b: code(c2) });
  const short = await fn('pairing', parentA.token, { action: 'redeem', code: 'AB', family_id: FAM_A });
  pass(short.status === 400, 'pairing.short_code_rejected', { status: short.status, code: code(short) });
  const injection = await fn('pairing', parentB.token, { action: 'redeem', code: "' OR 1=1--", family_id: FAM_B });
  pass(!ok(injection) && [400, 401, 403].includes(injection.status), 'pairing.sqlish_code_rejected', { status: injection.status, code: code(injection) });

  record('pairing.parent_attempt_rate_limit_enforced', 'NOT_RUN', {
    reason: 'triggering the 5-per-10-minute window would lock PARENT_A/PARENT_B out of redeeming the code the device agent is pairing with right now',
    implementation: 'supabase/functions/_shared/rate_limit.ts MAX_ATTEMPTS_PER_PARENT=5, MAX_ATTEMPTS_PER_TOKEN=10, CODE_CREATIONS_PER_24H=5',
  });
  const stillFree = await fn('pairing', parentB.token, { action: 'redeem', code: 'KZ999999', family_id: FAM_B });
  pass(stillFree.status !== 429, 'pairing.attempt_window_not_exhausted_by_qa_run', { status: stillFree.status, code: code(stillFree) });

  // --- Foreign-object targeting on the consent/cancel paths --------------
  const respondForeign = await fn('pairing', childB.token, { action: 'respond', request_id: crypto.randomUUID(), approve: true });
  pass(!ok(respondForeign) && [403, 404, 410].includes(respondForeign.status), 'pairing.respond_random_request_denied', { status: respondForeign.status, code: code(respondForeign) });
  const respondA = await fn('pairing', childA.token, { action: 'respond', request_id: qa.CHILD_B_ID, approve: true });
  pass(respondA.status === 400, 'pairing.respond_malformed_request_id_rejected', { status: respondA.status, code: code(respondA) });
  const cancelForeign = await fn('pairing', parentA.token, { action: 'cancel', request_id: crypto.randomUUID() });
  pass(!ok(cancelForeign) && [403, 404].includes(cancelForeign.status), 'pairing.cancel_unknown_request_denied', { status: cancelForeign.status, code: code(cancelForeign) });
  const pendingAsParent = await fn('pairing', parentA.token, { action: 'pending_child' });
  pass(!ok(pendingAsParent) && pendingAsParent.status === 403, 'pairing.pending_child_requires_child_role', { status: pendingAsParent.status, code: code(pendingAsParent) });

  // --- Unlink authorisation ----------------------------------------------
  const unlinkSelfAsChild = await fn('pairing', childA.token, { action: 'unlink', family_id: FAM_A, child_user_id: qa.CHILD_A_ID });
  pass(!ok(unlinkSelfAsChild) && [403, 404].includes(unlinkSelfAsChild.status), 'pairing.unlink_removed_child_denied', { status: unlinkSelfAsChild.status, code: code(unlinkSelfAsChild) });

  record('pairing.expiry_replay_and_cross_family_redeem', 'BLOCKED', {
    reason: 'needs a fresh code; device_pairing_tokens cap (5 per child per 24 h) is exhausted for CHILD_A/CHILD_B/CHILD_C — create returns 429 rate_limited',
  });

  save('pairing_blocked_proof.json', {
    when: new Date().toISOString(),
    create_results: { note: 'see pairing.create_quota.* rows in this run log' },
    code_spec: { length: 8, alphabet_size: 30, keyspace: '30^8 ~= 6.5e11', ttl_minutes: 10, max_attempts_per_token: 10, attempts_per_parent_per_10min: 5, creations_per_24h: 5 },
  });
  const rc = summary('pairing_security');
  process.exit(rc ? 1 : 0);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(2); });
