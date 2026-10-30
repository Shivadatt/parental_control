// Read-only fixture state check for the two QA families.
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

const client = createClient(URL, KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});
await client.auth.signInWithPassword({ email: qa.PARENT_B_USER, password: qa.PARENT_B_PASS });
const members = await client
  .from('family_members')
  .select('family_id, user_id, role, status')
  .order('role');
const devices = await client
  .from('devices')
  .select('id, child_user_id, display_name, status, last_seen_at')
  .order('created_at');
console.log(JSON.stringify({
  members: members.data,
  membersError: members.error?.message ?? null,
  devices: devices.data,
  devicesError: devices.error?.message ?? null,
}, null, 2));
