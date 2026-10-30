// Verify the parent-facing revoke_device response no longer carries
// service-only device fields. Prints only status and key names.
import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';

const ROOT = path.resolve(import.meta.dirname, '../..');
const readEnv = (file) => {
  const out = {};
  for (const line of fs.readFileSync(path.join(ROOT, file), 'utf8').split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return out;
};
const cfg = readEnv('.tools/live_config.env');
const qa = readEnv('.tools/qa_accounts.env');
const URL = cfg.SUPABASE_URL;
const KEY = cfg.SUPABASE_ANON_KEY;
const DEVICE_ID = '9dcadadc-34a4-4409-a6ac-6cc551015c0c';

const client = createClient(URL, KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});
const { data: session, error } = await client.auth.signInWithPassword({
  email: qa.PARENT_B_USER, password: qa.PARENT_B_PASS,
});
if (error) throw new Error(error.message);
const res = await fetch(`${URL}/functions/v1/family-admin`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    apikey: KEY,
    Authorization: `Bearer ${session.session.access_token}`,
  },
  body: JSON.stringify({ action: 'revoke_device', device_id: DEVICE_ID }),
});
const body = await res.json();
const row = body?.data ?? {};
const keys = Object.keys(row).sort();
const leaks = ['installation_id', 'secret_hash'].filter((k) => k in row);
const results = [
  { name: 'revoke_shape.http_ok', status: res.status === 200 ? 'PASS' : 'FAIL', detail: { status: res.status } },
  { name: 'revoke_shape.ok_true', status: body?.ok === true ? 'PASS' : 'FAIL', detail: { ok: body?.ok } },
  { name: 'revoke_shape.status_revoked', status: row.status === 'revoked' ? 'PASS' : 'FAIL', detail: { status: row.status } },
  { name: 'revoke_shape.no_service_only_fields', status: leaks.length === 0 ? 'PASS' : 'FAIL', detail: { leaks } },
];
for (const r of results) console.log(`${r.status} ${r.name} :: ${JSON.stringify(r.detail)}`);
console.log(`KEYS ${JSON.stringify(keys)}`);
fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
fs.writeFileSync(path.join(ROOT, '.tools/live/results/revoke_shape.json'),
  JSON.stringify({ when: new Date().toISOString(), results, keys }, null, 2));
if (results.some((r) => r.status === 'FAIL')) process.exit(1);
