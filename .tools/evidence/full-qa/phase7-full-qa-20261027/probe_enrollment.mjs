// Probe: is a fresh device enrollment possible right now for the QA children?
// Non-destructive: a blocked registration only writes an audit marker.
import { qa, login, fn, code, ok, record } from './_lib.mjs';

const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);
const childA = await login(qa.CHILD_A_USER, qa.CHILD_A_PASS);
const parentB = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);

for (const [label, who, fam] of [
  ['childC/familyB', childC, '4c4dd6fe-e727-4f66-bfba-7edd801114a8'],
  ['childA/familyA', childA, 'c4e15505-05f4-4faf-a268-789f454fbcd4'],
]) {
  const r = await fn('device-register', who.token, {
    action: 'register', family_id: fam,
    installation_id: `qa-probe-${label.split('/')[0]}-${Date.now()}`,
    secret_hash: 'a'.repeat(64), display_name: 'QA Phase7 Probe', platform: 'android',
  });
  record(`probe.register.${label}`, ok(r) ? 'POSSIBLE' : 'BLOCKED', {
    status: r.status, code: code(r), msg: r.json?.error?.message ?? null,
  });
}

const memC = await parentB.client.from('family_members')
  .select('user_id,role,status').eq('family_id', '4c4dd6fe-e727-4f66-bfba-7edd801114a8');
record('probe.familyB_membership', 'INFO', { rows: memC.data ?? memC.error?.message });
