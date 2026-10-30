// Hosted end-to-end check for BUG-024 device recovery (family B).
// Re-link child B -> register device -> recovery authorization -> replay denial
// -> audit -> fresh pairing with a new device credential. Secrets stay local.
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

async function membership(parent, childId) {
  const r = await parent.client.from('family_members')
    .select('family_id, role, status').eq('family_id', FAM).eq('user_id', childId).maybeSingle();
  return r.data?.status ?? null;
}

async function ensureLinked(parent, child) {
  if ((await membership(parent, child.id)) === 'active') return { already: true };
  const create = await fn('pairing', child.token, { action: 'create' });
  pass(ok(create) && typeof create.json?.data?.code === 'string', 'recover.setup_code_created', {
    status: create.status, code: code(create),
  });
  if (!ok(create)) throw new Error('code creation failed');
  const redeem = await fn('pairing', parent.token, {
    action: 'redeem', code: create.json.data.code, family_id: FAM,
  });
  const requestId = redeem.json?.data?.request_id ?? redeem.json?.data?.id;
  pass(ok(redeem) && !!requestId, 'recover.setup_redeemed', {
    status: redeem.status, code: code(redeem),
  });
  if (!ok(redeem)) throw new Error('redeem failed');
  const respond = await fn('pairing', child.token, {
    action: 'respond', request_id: requestId, approve: true,
  });
  pass(ok(respond) && respond.json?.data?.status === 'approved', 'recover.setup_approved', {
    status: respond.status, code: code(respond),
  });
  pass((await membership(parent, child.id)) === 'active', 'recover.setup_membership_active', {});
  return { already: false };
}

async function register(parent, child, label) {
  void parent;
  const deviceSecret = crypto.randomBytes(32).toString('hex');
  const reg = await fn('device-register', child.token, {
    action: 'register',
    family_id: FAM,
    installation_id: `qa-recovery-${label}-${Date.now()}`,
    secret_hash: crypto.createHash('sha256').update(deviceSecret).digest('hex'),
    display_name: `QA Recovery ${label}`,
    platform: 'android',
    app_version: '1.0.0-qa',
  });
  const id = reg.json?.data?.id;
  pass(ok(reg) && !!id, `recover.${label}_registered`, { status: reg.status, code: code(reg) });
  if (!id) throw new Error('registration failed');
  return { id, secret: deviceSecret };
}

async function main() {
  const parentA = await signIn(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const parentB = await signIn(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childC = await signIn(qa.CHILD_C_USER, qa.CHILD_C_PASS);
  const bootstrap = await fn('auth-bootstrap', childC.token, { action: 'set_role', role: 'child' });
  record('recover.setup_child_role', 'INFO', { status: bootstrap.status, code: code(bootstrap) });

  // A previous run can leave an active device; unlink first so this run starts
  // from a clean, unlinked child like a lost-phone recovery would.
  const reset = await fn('pairing', parentB.token, {
    action: 'unlink', family_id: FAM, child_user_id: childC.id,
  });
  record('recover.setup_reset_unlink', 'INFO', { status: reset.status, code: code(reset) });
  await ensureLinked(parentB, childC);
  const oldDevice = await register(parentB, childC, 'old');
  const hdr = { 'x-device-id': oldDevice.id, 'x-device-secret': oldDevice.secret };
  const beatBefore = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 41 }, hdr);
  pass(ok(beatBefore), 'recover.old_device_credential_valid', {
    status: beatBefore.status, code: code(beatBefore),
  });

  const childAttempt = await fn('family-admin', childC.token, {
    action: 'recover_device', device_id: oldDevice.id,
  });
  pass(childAttempt.status === 403 && code(childAttempt) === 'role_required',
    'recover.child_role_denied', { status: childAttempt.status, code: code(childAttempt) });

  const foreignAttempt = await fn('family-admin', parentA.token, {
    action: 'recover_device', device_id: oldDevice.id,
  });
  pass(foreignAttempt.status === 403 && code(foreignAttempt) === 'forbidden',
    'recover.foreign_parent_denied', { status: foreignAttempt.status, code: code(foreignAttempt) });

  const unknownAttempt = await fn('family-admin', parentB.token, {
    action: 'recover_device', device_id: crypto.randomUUID(),
  });
  pass(unknownAttempt.status === 404 && code(unknownAttempt) === 'device_not_found',
    'recover.unknown_device_denied', { status: unknownAttempt.status, code: code(unknownAttempt) });

  const unknown = await fn('family-admin', parentB.token, {
    action: 'recover_device', device_id: 'not-a-uuid',
  });
  pass(unknown.status === 400 && code(unknown) === 'validation_error',
    'recover.malformed_device_denied', { status: unknown.status, code: code(unknown) });

  // Negative attempts must not have changed anything.
  const stillLinked = await membership(parentB, childC.id);
  pass(stillLinked === 'active', 'recover.denials_leave_membership_active', { status: stillLinked });
  const beatStill = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 41 }, hdr);
  pass(ok(beatStill), 'recover.denials_leave_credential_valid', {
    status: beatStill.status, code: code(beatStill),
  });

  const recovery = await fn('family-admin', parentB.token, {
    action: 'recover_device', device_id: oldDevice.id,
  });
  pass(ok(recovery) && recovery.json?.data?.recovery === 'started',
    'recover.parent_recovery_started', { status: recovery.status, code: code(recovery) });
  pass(recovery.json?.data?.old_device_id === oldDevice.id,
    'recover.old_device_id_echoed', { match: recovery.json?.data?.old_device_id === oldDevice.id });
  pass(Number(recovery.json?.data?.devices_revoked ?? 0) >= 1,
    'recover.device_revoked_count', { count: recovery.json?.data?.devices_revoked ?? null });

  const removedStatus = await membership(parentB, childC.id);
  pass(removedStatus === 'removed', 'recover.membership_removed', { status: removedStatus });
  const oldRow = await parentB.client.from('devices')
    .select('id, status, credential_revoked_at, last_seen_at').eq('id', oldDevice.id).maybeSingle();
  pass(oldRow.data?.status === 'revoked' && !!oldRow.data?.credential_revoked_at,
    'recover.old_device_row_revoked', {
      status: oldRow.data?.status ?? null,
      revoked: !!oldRow.data?.credential_revoked_at,
      error: oldRow.error?.code ?? null,
    });

  const beatAfter = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 41 }, hdr);
  pass(!ok(beatAfter) && (beatAfter.status === 401 || beatAfter.status === 403),
    'recover.old_credential_replay_denied', { status: beatAfter.status, code: code(beatAfter) });

  const childRegister = await fn('device-register', childC.token, {
    action: 'register', family_id: FAM,
    installation_id: `qa-recovery-unlinked-${Date.now()}`,
    secret_hash: crypto.createHash('sha256').update(crypto.randomBytes(32)).digest('hex'),
    display_name: 'QA Recovery Unlinked', platform: 'android',
  });
  pass(childRegister.status === 403, 'recover.unlinked_registration_denied', {
    status: childRegister.status, code: code(childRegister),
  });

  const audit = await parentB.client.from('audit_logs')
    .select('event_type, target_type, target_id, metadata, created_at')
    .eq('family_id', FAM)
    .eq('event_type', 'device_recovery_started')
    .order('created_at', { ascending: false })
    .limit(1);
  const event = audit.data?.[0] ?? null;
  pass(!!event && event.target_id === oldDevice.id, 'recover.audit_event_written', {
    found: !!event, error: audit.error?.code ?? null,
  });
  const meta = event?.metadata ?? {};
  const metaKeys = Object.keys(meta).sort();
  const metaText = JSON.stringify(meta).toLowerCase();
  pass(!/secret|token|password|hash/.test(metaText), 'recover.audit_has_no_secret_fields', {
    keys: metaKeys,
  });

  // Recovery is not complete until a fresh pairing is approved.
  await ensureLinked(parentB, childC);
  const freshDevice = await register(parentB, childC, 'fresh');
  const freshHdr = { 'x-device-id': freshDevice.id, 'x-device-secret': freshDevice.secret };
  const freshBeat = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 55 }, freshHdr);
  pass(ok(freshBeat), 'recover.fresh_credential_valid', {
    status: freshBeat.status, code: code(freshBeat),
  });
  pass(freshDevice.id !== oldDevice.id, 'recover.fresh_device_distinct', {});
  const oldBeatAgain = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 41 }, hdr);
  pass(!ok(oldBeatAgain), 'recover.old_credential_still_revoked', {
    status: oldBeatAgain.status, code: code(oldBeatAgain),
  });

  const failed = results.filter((r) => r.status === 'FAIL');
  console.log(`\nSUMMARY recover_device: ${results.length - failed.length}/${results.length} passed`);
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/recover_device.json'),
    JSON.stringify({ when: new Date().toISOString(), results }, null, 2));
  if (failed.length) process.exit(1);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
