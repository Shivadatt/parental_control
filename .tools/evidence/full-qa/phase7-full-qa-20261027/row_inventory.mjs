// Inventory of readable rows per family, used to pick real foreign ids for IDOR.
import { qa, login, FAM_A, FAM_B, save } from './_lib.mjs';

const T = ['devices', 'device_policies', 'device_commands', 'device_apps', 'usage_daily',
  'location_events', 'safe_zones', 'safe_zone_states', 'safety_alerts', 'remote_sessions',
  'webrtc_signals', 'audit_logs', 'pairing_requests'];
const out = {};
for (const [label, email, pw, fam] of [['A', qa.PARENT_A_USER, qa.PARENT_A_PASS, FAM_A], ['B', qa.PARENT_B_USER, qa.PARENT_B_PASS, FAM_B]]) {
  const { client } = await login(email, pw);
  out[label] = {};
  for (const t of T) {
    const r = await client.from(t).select('id').eq('family_id', fam).limit(3);
    out[label][t] = r.error ? `ERR:${r.error.code}` : (r.data ?? []).map((x) => x.id);
  }
}
save('row_inventory.json', out);
console.log(JSON.stringify(out, null, 1));
