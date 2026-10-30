// Re-link QA child B after the failed device run: unlink -> new code -> parent
// redeem -> child approves. Prints only statuses and ids, never codes.
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
const FAM = '4c4dd6fe-e727-4f66-bfba-7edd801114a8';

const results = [];
const record = (name, status, detail) => {
  results.push({ name, status, detail });
  console.log(`${status} ${name}${detail ? ' :: ' + JSON.stringify(detail) : ''}`);
};
const pass = (cond, name, detail) => record(name, cond ? 'PASS' : 'FAIL', detail);

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
  const parentB = await signIn(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childB = await signIn(qa.CHILD_B_USER, qa.CHILD_B_PASS);

  const unlink = await call('pairing', parentB.token, {
    action: 'unlink', family_id: FAM, child_user_id: childB.id,
  });
  pass(ok(unlink), 'relink_b.unlink_child', { status: unlink.status, code: code(unlink) });

  const create = await call('pairing', childB.token, { action: 'create' });
  pass(ok(create) && typeof create.json?.data?.code === 'string', 'relink_b.code_created', {
    status: create.status, code: code(create),
  });
  const pairCode = create.json?.data?.code;
  if (!ok(create)) throw new Error('code creation failed');

  const redeem = await call('pairing', parentB.token, {
    action: 'redeem', code: pairCode, family_id: FAM,
  });
  pass(ok(redeem), 'relink_b.redeem', { status: redeem.status, code: code(redeem) });
  const requestId = redeem.json?.data?.request_id ?? redeem.json?.data?.id;
  if (!ok(redeem)) throw new Error('redeem failed');

  const pending = await call('pairing', childB.token, { action: 'pending_child' });
  pass(ok(pending) && (pending.json?.data ?? []).some((r) => r.id === requestId),
    'relink_b.visible_to_child', { status: pending.status, code: code(pending) });

  const respond = await call('pairing', childB.token, {
    action: 'respond', request_id: requestId, approve: true,
  });
  pass(ok(respond) && respond.json?.data?.status === 'approved', 'relink_b.child_approved', {
    status: respond.status, code: code(respond), value: respond.json?.data?.status,
  });

  const membership = await childB.client.from('family_members')
    .select('family_id, role, status').eq('family_id', FAM).eq('user_id', childB.id).maybeSingle();
  pass(membership.data?.status === 'active' && membership.data?.role === 'child',
    'relink_b.membership_active', { error: membership.error?.code ?? null });

  const failed = results.filter((r) => r.status === 'FAIL');
  console.log(`\nSUMMARY relink_b: ${results.length - failed.length}/${results.length} passed`);
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/relink_b.json'),
    JSON.stringify({ when: new Date().toISOString(), results }, null, 2));
  if (failed.length) process.exit(1);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
