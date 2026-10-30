// Direct hosted check: after a parent unlinks the child, the child can no longer
// register a device and the unlinked device's old credential is rejected.
// Prints statuses only; never prints the device secret.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
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
async function fn(name, token, body, extra = {}) {
  const bearer = token === null ? KEY : token;
  const res = await fetch(`${URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: KEY,
      Authorization: `Bearer ${bearer}`,
      ...extra,
    },
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
  const parentA = await signIn(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childA = await signIn(qa.CHILD_B_USER, qa.CHILD_B_PASS);

  const deviceSecret = crypto.randomBytes(32).toString('hex');
  const secretHash = crypto.createHash('sha256').update(deviceSecret).digest('hex');
  const installation = `qa-unlink-${Date.now()}`;

  const reg = await fn('device-register', childA.token, {
    action: 'register',
    family_id: FAM,
    installation_id: installation,
    secret_hash: secretHash,
    display_name: 'QA Unlink Device',
    platform: 'android',
    app_version: '1.0.0-qa',
  });
  const deviceId = reg.json?.data?.id;
  pass(ok(reg) && !!deviceId, 'unlinked.setup_device_active', {
    status: reg.status, code: code(reg),
  });
  if (!deviceId) throw new Error('setup registration failed');

  const hdr = { 'x-device-id': deviceId, 'x-device-secret': deviceSecret };
  const before = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 }, hdr);
  pass(ok(before), 'unlinked.setup_heartbeat_works', { status: before.status, code: code(before) });

  const unlink = await fn('pairing', parentA.token, {
    action: 'unlink', family_id: FAM, child_user_id: childA.id,
  });
  pass(ok(unlink), 'unlinked.parent_unlinks_child', { status: unlink.status, code: code(unlink) });

  const rereg = await fn('device-register', childA.token, {
    action: 'register',
    family_id: FAM,
    installation_id: `${installation}-again`,
    secret_hash: crypto.createHash('sha256').update(crypto.randomBytes(32)).digest('hex'),
    display_name: 'QA Unlink Attempt',
    platform: 'android',
  });
  pass(!ok(rereg) && rereg.status === 403, 'unlinked.registration_denied', {
    status: rereg.status, code: code(rereg),
  });

  const after = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 }, hdr);
  pass(!ok(after) && (after.status === 401 || after.status === 403), 'unlinked.telemetry_denied', {
    status: after.status, code: code(after),
  });

  const row = await parentA.client.from('devices')
    .select('id, status, child_user_id').eq('id', deviceId).maybeSingle();
  pass(row.data?.status === 'revoked', 'unlinked.unlink_revoked_device_row', {
    status: row.data?.status ?? null, error: row.error?.code ?? null,
  });

  const failed = results.filter((r) => r.status === 'FAIL');
  console.log(`\nSUMMARY unlinked: ${results.length - failed.length}/${results.length} passed`);
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/unlinked_denial.json'),
    JSON.stringify({ when: new Date().toISOString(), results }, null, 2));
  if (failed.length) process.exit(1);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
