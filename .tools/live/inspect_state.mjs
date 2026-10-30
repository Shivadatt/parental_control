// Read-only snapshot of hosted QA families for recovery verification planning.
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
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

for (const label of ['A', 'B']) {
  const { data: session, error } = await client.auth.signInWithPassword({
    email: qa[`PARENT_${label}_USER`],
    password: qa[`PARENT_${label}_PASS`],
  });
  if (error) {
    console.log(label, 'signin error', error.message);
    continue;
  }
  const families = await client
    .from('family_members')
    .select('family_id, user_id, role, status')
    .eq('user_id', session.user.id)
    .eq('role', 'parent');
  const familyId = families.data?.[0]?.family_id ?? null;
  const members = familyId
    ? await client.from('family_members')
      .select('user_id, role, status')
      .eq('family_id', familyId)
    : { data: [] };
  const devices = familyId
    ? await client.from('devices')
      .select('id, display_name, status, child_user_id, credential_revoked_at, last_seen_at')
      .eq('family_id', familyId)
    : { data: [] };
  const tokens = familyId
    ? await client.from('device_pairing_tokens')
      .select('id, child_user_id, redeemed_at, revoked_at, expires_at')
      .eq('family_id', familyId)
    : { data: [] };
  console.log(JSON.stringify({
    label,
    familyId,
    members: members.data,
    devices: devices.data,
    tokens: tokens.data,
    errors: [families.error, members.error, devices.error, tokens.error]
      .filter(Boolean).map((e) => e.message),
  }, null, 2));
}
