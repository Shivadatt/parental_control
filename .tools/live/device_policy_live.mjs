// On-device policy delivery: one benign policy must be enforced and one
// app-block policy must be acknowledged as failed on a non-Device-Owner phone.
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

const results = [];
const record = (name, status, detail) => {
  results.push({ name, status, detail });
  console.log(`${status} ${name}${detail ? ' :: ' + JSON.stringify(detail) : ''}`);
};
const pass = (cond, name, detail) => record(name, cond ? 'PASS' : 'FAIL', detail);

const parent = createClient(URL, KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});
const { data: session, error: signInError } = await parent.auth.signInWithPassword({
  email: qa.PARENT_B_USER, password: qa.PARENT_B_PASS,
});
if (signInError) throw new Error(signInError.message);
const token = session.session.access_token;

async function fn(name, body) {
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
const errCode = (r) => r.json?.error?.code ?? `http_${r.status}`;

let device = null;
const deviceDeadline = Date.now() + 600000;
while (Date.now() < deviceDeadline) {
  const { data: devices, error: deviceError } = await parent
    .from('devices')
    .select('id, display_name, status, last_seen_at, policy_version')
    .eq('child_user_id', qa.CHILD_B_ID)
    .eq('status', 'active');
  if (deviceError) throw new Error(deviceError.message);
  device = devices?.[0] ?? null;
  if (device) break;
  console.log('waiting for the app to register child B device...');
  await new Promise((resolve) => setTimeout(resolve, 5000));
}
if (!device) throw new Error('no active device for child B');
console.log(`device: ${device.id} (${device.display_name})`);

const stamp = Date.now();
const benign = await fn('device-policy', {
  action: 'update',
  device_id: device.id,
  idempotency_key: `qa-live-benign-${stamp}`,
  policy: {
    enforce_app_blocks: false,
    block_all_except_allowed: false,
    blocked_packages: [],
    app_rules: [],
    daily_screen_time_limit_minutes: 120,
    bedtime_start_minutes: 1320,
    bedtime_end_minutes: 390,
  },
});
const benignPolicy = benign.json?.data?.policy;
pass(ok(benign) && benignPolicy?.version >= 1, 'device_policy.benign_created', {
  status: benign.status, version: benignPolicy?.version, code: errCode(benign),
});

const blocking = await fn('device-policy', {
  action: 'update',
  device_id: device.id,
  idempotency_key: `qa-live-blocking-${stamp}`,
  policy: {
    enforce_app_blocks: true,
    block_all_except_allowed: false,
    blocked_packages: ['com.cricbuzz.android'],
    app_rules: [{ package_name: 'com.cricbuzz.android', label: 'Cricbuzz', blocked: true, windows: [] }],
    daily_screen_time_limit_minutes: 120,
  },
});
const blockingPolicy = blocking.json?.data?.policy;
pass(ok(blocking) && blockingPolicy?.version > (benignPolicy?.version ?? 0),
  'device_policy.blocking_created', {
    status: blocking.status, version: blockingPolicy?.version, code: errCode(blocking),
  });

async function waitForPolicy(policyId, predicate, label, timeoutMs = 120000) {
  const deadline = Date.now() + timeoutMs;
  let row = null;
  while (Date.now() < deadline) {
    const { data, error } = await parent
      .from('device_policies')
      .select('version, enforcement_status, acknowledged_at, last_error')
      .eq('id', policyId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    row = data;
    if (row && predicate(row)) return row;
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  console.log(`${label} timed out; last row: ${JSON.stringify(row)}`);
  return row;
}

const benignSettled = await waitForPolicy(
  benignPolicy?.id,
  (row) => row.acknowledged_at !== null,
  'benign policy ack',
);
pass(benignSettled?.enforcement_status === 'enforced',
  'device_policy.benign_acked_enforced', benignSettled);

const blockingSettled = await waitForPolicy(
  blockingPolicy?.id,
  (row) => row.acknowledged_at !== null,
  'blocking policy ack',
);
pass(blockingSettled?.enforcement_status === 'failed',
  'device_policy.blocking_reported_failed', blockingSettled);
pass(
  typeof blockingSettled?.last_error === 'string' &&
    /Device Owner|DeviceOwner/i.test(blockingSettled.last_error),
  'device_policy.failure_names_device_owner',
  { last_error: blockingSettled?.last_error ?? null },
);

const { data: after, error: afterError } = await parent
  .from('devices')
  .select('policy_version, last_seen_at, status')
  .eq('id', device.id)
  .maybeSingle();
pass(!afterError && after?.policy_version === benignPolicy?.version,
  'device_policy.version_reflects_successful_ack',
  { policy_version: after?.policy_version, expected: benignPolicy?.version, error: afterError?.code ?? null });

fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
fs.writeFileSync(path.join(ROOT, '.tools/live/results/device_policy_live.json'),
  JSON.stringify({ when: new Date().toISOString(), deviceId: device.id, results }, null, 2));
const failed = results.filter((result) => result.status === 'FAIL');
console.log(`\nSUMMARY device_policy: ${results.length - failed.length}/${results.length} passed`);
if (failed.length) process.exit(1);
