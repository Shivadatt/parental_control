// Phase 7 / task 4 retry, run in a quiet window with a HARD budget of 2
// redeem attempts so the device agent's own pairing flow keeps 3 of the
// 5-per-10-min parent attempts. Goal: confirm an unknown well-formed code
// and a malformed short code are answered identically (no enumeration
// oracle) and that the earlier FAIL was only the 429 attempt window.
import { qa, FAM_B, login, fn, code, save, record, summary } from './_lib.mjs';

const ALPHA = '23456789abcdefghjkmnpqrstvwxyz';
const fake = (n) => Array.from({ length: n }, (_, i) =>
  ALPHA[(i * 7 + 3 + i * i) % ALPHA.length]).join('');

const sess = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
console.log('signed in as PARENT_B (identity not printed)');

const calls = [];
const used = () => calls.filter((c) => c.status !== 0).length;

async function redeem(label, rawCode) {
  if (used() >= 2) {
    record(`pairing.${label}`, 'SKIP', { reason: '2-attempt budget exhausted; protecting the live device-agent pairing window' });
    return null;
  }
  const r = await fn('pairing', sess.token, { action: 'redeem', family_id: FAM_B, code: rawCode });
  calls.push({ label, status: r.status, code: code(r), message: r.json?.error?.message?.slice(0, 60) });
  return r;
}

const a = await redeem('unknown_valid_shape', fake(8));
const b = await redeem('unknown_short_form', 'ABCD');
if (a && b) {
  const same = a.status === b.status && code(a) === code(b);
  record('pairing.unknown_and_short_codes_uniform', same ? 'PASS' : 'FAIL', { calls });
  if (!same && (code(a) === 'rate_limited' || code(b) === 'rate_limited')) {
    record('pairing.attempt_window_reached', 'BLOCKED', {
      reason: '429 fired before the code-shape comparison could complete (MAX_ATTEMPTS_PER_PARENT=5 / 10 min)',
    });
  }
} else {
  record('pairing.unknown_and_short_codes_uniform', 'BLOCKED', { calls });
}
save('pairing_uniform_probe_calls.json', { when: new Date().toISOString(), calls });
process.exit(summary('pairing_uniform_probe') === 0 ? 0 : 1);
