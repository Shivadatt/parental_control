// Classify the single isolation_round2 FAIL (device-command create -> 401
// unauthorized where every sibling control returns 403). Three calls, all
// expected to be denied, none mutate state:
//   1) parent B + OWN family device   -> is the 401 tied to the token?
//   2) parent B + FOREIGN family device-> the original FAIL
//   3) parent A + OWN family device    -> control (may create a command; use
//      a bogus idempotency key and an unknown type so validation rejects it)
import { qa, FAM_A, FAM_B, login, fn, code, save, record, summary } from './_lib.mjs';

const OWN_B = 'a3b7b74e-77a4-4b95-85c4-b1ccf782be9a';   // family B, revoked
const FOREIGN_A = 'ff9b0b44-db94-4234-8221-73bd3f28182e'; // family A, revoked

const B = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
const A = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);

async function probe(label, bearer, deviceId, familyId, type) {
  const r = await fn('device-command', bearer, {
    action: 'create', device_id: deviceId, family_id: familyId, type,
    payload: {}, idempotency_key: `p7cls-${Date.now()}`,
  });
  record(label, 'INFO', {
    status: r.status, code: code(r),
    error_code: r.json?.error?.code, message: (r.json?.error?.message ?? JSON.stringify(r.json)).slice(0, 90),
    role_expected: 'parent',
  });
  return r;
}

const c1 = await probe('dc.parentB_own_family_device', B.token, OWN_B, FAM_B, 'sync_policy');
const c2 = await probe('dc.parentB_foreign_family_device', B.token, FOREIGN_A, FAM_A, 'sync_policy');
const c3 = await probe('dc.parentA_unknown_type_control', A.token, FOREIGN_A, FAM_A, '__not_a_type__');

const tokenOk = c1.status !== 401 || c2.status !== 401;
record('dc.status_code_consistency',
  [403, 404].includes(c2.status) ? 'PASS' : 'FAIL',
  {
    own_B: `${c1.status}/${code(c1)}`, foreign_B: `${c2.status}/${code(c2)}`,
    control_A: `${c3.status}/${code(c3)}`,
    note: c2.status === 401
      ? 'foreign-device create answers 401 unauthorized while foreign-device policy update and family-admin revoke answer 403 forbidden; a valid parent JWT is rejected before the family check, so the denial is not attributable to the IDOR guard'
      : 'foreign device create is denied with a family-scoped status',
  });
save('device_command_401_probe.json', { c1, c2, c3 });
process.exit(summary('device_command_401_probe') === 0 ? 0 : 1);
