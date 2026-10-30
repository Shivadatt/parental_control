// Revoke the uninstalled QA Phone B device credential through the parent API.
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
console.log('revoke', res.status, await res.text());
const devices = await client.from('devices')
  .select('id, status, credential_revoked_at')
  .eq('id', DEVICE_ID)
  .maybeSingle();
console.log(JSON.stringify(devices.data ?? { error: devices.error?.message }, null, 2));
