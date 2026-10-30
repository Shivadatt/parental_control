// Pairing-code expiry scenario. `create` unlinks child A and issues a code,
// saving it to a gitignored file; the dashboard SQL Editor then expires the
// token; `redeem` must return invalid_code without creating a membership.
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
const FAM = 'c4e15505-05f4-4faf-a268-789f454fbcd4';
const CODE_FILE = path.join(ROOT, '.tools/live/pending_code.env');

async function signIn(email, password) {
  const client = createClient(URL, KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`signin: ${error.message}`);
  return { client, token: data.session.access_token, id: data.user.id };
}

async function call(name, token, body) {
  const res = await fetch(`${URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: KEY, Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text.slice(0, 300) }; }
  return { status: res.status, json };
}

const ok = (r) => r.json?.ok === true;
const code = (r) => r.json?.error?.code ?? `http_${r.status}`;

async function main() {
  const mode = process.argv[2];
  const parentA = await signIn(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const childA = await signIn(qa.CHILD_A_USER, qa.CHILD_A_PASS);

  if (mode === 'create') {
    const unlink = await call('pairing', parentA.token, {
      action: 'unlink', family_id: FAM, child_user_id: childA.id,
    });
    if (!ok(unlink)) throw new Error(`unlink failed: ${code(unlink)}`);
    const create = await call('pairing', childA.token, { action: 'create' });
    if (!ok(create)) throw new Error(`create failed: ${code(create)} (${create.status})`);
    fs.writeFileSync(CODE_FILE,
      `PAIR_CODE=${create.json.data.code}\nCHILD_A_ID=${childA.id}\n`, { mode: 0o600 });
    console.log(`PASS pairing.expiry.code_created :: ${JSON.stringify({
      status: create.status, expires_at: create.json.data.expires_at,
    })}`);
    return;
  }

  if (mode === 'redeem') {
    const env = readEnv('.tools/live/pending_code.env');
    const redeem = await call('pairing', parentA.token, {
      action: 'redeem', code: env.PAIR_CODE, family_id: FAM,
    });
    const passed = !ok(redeem) && redeem.status === 400 && code(redeem) === 'invalid_code';
    console.log(`${passed ? 'PASS' : 'FAIL'} pairing.expired_code_rejected :: ${JSON.stringify({
      status: redeem.status, code: code(redeem),
    })}`);
    const membership = await childA.client.from('family_members')
      .select('status').eq('family_id', FAM).eq('user_id', childA.id).maybeSingle();
    const notLinked = !membership.data || membership.data.status !== 'active';
    console.log(`${notLinked ? 'PASS' : 'FAIL'} pairing.expired_code_creates_no_membership :: ${JSON.stringify({
      status: membership.data?.status ?? null, error: membership.error?.code ?? null,
    })}`);
    fs.writeFileSync(path.join(ROOT, '.tools/live/results/pairing_expiry.json'),
      JSON.stringify({ when: new Date().toISOString(), redeem_status: redeem.status, redeem_code: code(redeem), membership: membership.data ?? null }, null, 2));
    if (!passed || !notLinked) process.exit(1);
    return;
  }

  throw new Error('usage: node pairing_expiry.mjs create|redeem');
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
