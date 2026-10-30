// Phase 7 — pairing checks re-run after the redeem-attempt window cleared.
import {
  qa, FAM_A, login, fn, ok, code, pass, record, summary,
} from './_lib.mjs';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);

  // Only two invalid redemptions are spent here: the parent attempt window is
  // 5 per 10 minutes and the device agent may need the remaining headroom.
  const c1 = await fn('pairing', parentA.token, { action: 'redeem', code: 'ZZZZZZZZ', family_id: FAM_A });
  await sleep(1500);
  const c2 = await fn('pairing', parentA.token, { action: 'redeem', code: 'QQQQ2468', family_id: FAM_A });
  pass(c1.status === c2.status && code(c1) === code(c2) && c1.status === 400,
    'pairing.unknown_codes_answered_identically', {
      a: `${c1.status}/${code(c1)}`, b: `${c2.status}/${code(c2)}`,
      msg_a: c1.json?.error?.message ?? null, msg_b: c2.json?.error?.message ?? null,
    });

  const badUuid = await fn('pairing', childC.token, { action: 'respond', request_id: 'not-a-uuid', approve: true });
  pass(badUuid.status === 400 && code(badUuid) === 'validation_error', 'pairing.respond_malformed_request_id_400', { status: badUuid.status, code: code(badUuid) });
  const missingApprove = await fn('pairing', childC.token, { action: 'respond', request_id: crypto.randomUUID() });
  pass(missingApprove.status === 400, 'pairing.respond_missing_approve_400', { status: missingApprove.status, code: code(missingApprove) });
  const noRequestId = await fn('pairing', parentA.token, { action: 'cancel' });
  pass(!ok(noRequestId) && noRequestId.status === 400, 'pairing.cancel_missing_request_id_400', { status: noRequestId.status, code: code(noRequestId) });
  const shortCodeNoAttempt = await fn('pairing', parentA.token, { action: 'redeem', code: 'AB', family_id: 'not-a-uuid' });
  pass(shortCodeNoAttempt.status === 400, 'pairing.malformed_family_rejected_before_lookup', { status: shortCodeNoAttempt.status, code: code(shortCodeNoAttempt) });

  const rc = summary('pairing_window_retry');
  process.exit(rc ? 1 : 0);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(2); });
