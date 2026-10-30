// Hosted live verification phase 2: devices, policy, commands, telemetry,
// remote sessions, RLS and private Realtime.
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

const results = [];
const record = (name, status, detail) => {
  results.push({ name, status, detail });
  console.log(`${status} ${name}${detail ? ' :: ' + JSON.stringify(detail) : ''}`);
};
const pass = (cond, name, detail) => record(name, cond ? 'PASS' : 'FAIL', detail);

const users = {};
async function signIn(label, email, password) {
  const client = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`signin ${label}: ${error.message}`);
  users[label] = { client, token: data.session.access_token, id: data.user.id };
}
async function fn(name, who, body, extra = {}) {
  const bearer = who === null ? KEY : users[who].token;
  const res = await fetch(`${URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: KEY, Authorization: `Bearer ${bearer}`, ...extra },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text.slice(0, 300) }; }
  return { status: res.status, json };
}
const ok = (r) => r.json?.ok === true;
const errCode = (r) => r.json?.error?.code ?? `http_${r.status}`;

const famA = 'c4e15505-05f4-4faf-a268-789f454fbcd4';
const famB = '4c4dd6fe-e727-4f66-bfba-7edd801114a8';

const deviceSecret = crypto.randomBytes(32).toString('hex');
const deviceSecretHash = crypto.createHash('sha256').update(deviceSecret).digest('hex');
const installationId = `qa-install-a-${Date.now()}`;

async function subscribeStatus(client, topic, ms = 12000) {
  const channel = client.channel(topic, { config: { private: true } });
  const status = await new Promise((resolve) => {
    let settled = false;
    const done = (v) => { if (!settled) { settled = true; resolve(v); } };
    channel.subscribe((s, err) => done({ status: s, error: err ? String(err) : null }));
    setTimeout(() => done({ status: 'TIMEOUT' }), ms);
  });
  try { await client.removeChannel(channel); } catch { /* ignore */ }
  return status;
}

async function main() {
  await signIn('parentA', qa.PARENT_A_USER, qa.PARENT_A_PASS);
  await signIn('childA', qa.CHILD_A_USER, qa.CHILD_A_PASS);
  await signIn('parentB', qa.PARENT_B_USER, qa.PARENT_B_PASS);
  await signIn('childB', qa.CHILD_B_USER, qa.CHILD_B_PASS);

  // --- Device registration -------------------------------------------------
  const parentReg = await fn('device-register', 'parentA', {
    action: 'register', family_id: famA, installation_id: `${installationId}-p`,
    secret_hash: deviceSecretHash, display_name: 'QA Parent Attempt',
  });
  pass(!ok(parentReg) && parentReg.status === 403, 'device.parent_cannot_register_as_child', { status: parentReg.status, code: errCode(parentReg) });

  const reg = await fn('device-register', 'childA', {
    action: 'register', family_id: famA, installation_id: installationId,
    secret_hash: deviceSecretHash, display_name: 'QA Test Phone A', platform: 'android',
    android_version: '14', app_version: '1.0.0-qa',
  });
  const device = reg.json?.data;
  const deviceId = device?.id;
  pass(ok(reg) && deviceId && device.status === 'active', 'device.register', {
    status: reg.status, device_id: deviceId, leaked_secret_hash: Object.hasOwn(device ?? {}, 'secret_hash'),
    leaked_installation: Object.hasOwn(device ?? {}, 'installation_id'),
  });
  if (!deviceId) throw new Error('device registration failed');

  const hdr = { 'x-device-id': deviceId, 'x-device-secret': deviceSecret };
  const wrongHdr = { 'x-device-id': deviceId, 'x-device-secret': crypto.randomBytes(32).toString('hex') };

  const beatBad = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 }, wrongHdr);
  pass(beatBad.status === 401, 'device.heartbeat_wrong_secret_denied', { status: beatBad.status, code: errCode(beatBad) });

  const beat = await fn('device-telemetry', null, {
    action: 'heartbeat', battery_level: 15, is_charging: false, online: true,
    capabilities: { enforcement_mode: 'device_owner', usage_access_granted: true, location_granted: true },
  }, hdr);
  pass(ok(beat), 'device.heartbeat', { status: beat.status, pending_policy_version: beat.json?.data?.pending_policy_version });

  // --- Foreign family cannot control this device --------------------------
  const foreignPolicy = await fn('device-policy', 'parentB', {
    action: 'update', device_id: deviceId, idempotency_key: 'qa-foreign-policy-1',
    policy: { enforce_app_blocks: true },
  });
  pass(!ok(foreignPolicy), 'security.foreign_parent_policy_denied', { status: foreignPolicy.status, code: errCode(foreignPolicy) });

  const foreignCommand = await fn('device-command', 'parentB', {
    action: 'create', device_id: deviceId, type: 'sync_policy', payload: {}, idempotency_key: 'qa-foreign-cmd-1',
  });
  pass(!ok(foreignCommand), 'security.foreign_parent_command_denied', { status: foreignCommand.status, code: errCode(foreignCommand) });

  // --- Policy version + command + ack ------------------------------------
  const policyUpdate = await fn('device-policy', 'parentA', {
    action: 'update', device_id: deviceId, idempotency_key: 'qa-policy-a-1',
    policy: {
      enforce_app_blocks: true,
      block_all_except_allowed: false,
      blocked_packages: ['com.instagram.android'],
      app_rules: [{ package_name: 'com.instagram.android', label: 'Instagram', blocked: true, windows: [] }],
      daily_screen_time_limit_minutes: 120,
      bedtime_start_minutes: 1320,
      bedtime_end_minutes: 390,
    },
  });
  const policy = policyUpdate.json?.data?.policy;
  const policyCommandId = policyUpdate.json?.data?.command?.id;
  pass(ok(policyUpdate) && policy?.version === 1 && policyCommandId, 'policy.update_creates_version', {
    status: policyUpdate.status, version: policy?.version, command_id: policyCommandId,
    enforcement_status: policy?.enforcement_status,
  });

  const poll = await fn('device-command', null, { action: 'poll' }, hdr);
  const polled = poll.json?.data?.commands ?? [];
  pass(ok(poll) && polled.some((c) => c.id === policyCommandId), 'command.poll_delivers_policy', {
    status: poll.status, count: polled.length,
  });

  const ack = await fn('device-command', null, {
    action: 'ack', command_id: policyCommandId, status: 'succeeded',
    result: { success: true, suspended: ['com.instagram.android'], appliedAt: new Date().toISOString() },
  }, hdr);
  pass(ok(ack) && ack.json?.data?.command?.status === 'succeeded', 'command.ack_apply_policy', {
    status: ack.status, command_status: ack.json?.data?.command?.status,
  });

  const policyRow = await users.parentA.client.from('device_policies').select('version, enforcement_status, acknowledged_at').eq('device_id', deviceId).order('version', { ascending: false }).limit(1);
  pass((policyRow.data ?? [])[0]?.enforcement_status === 'enforced', 'policy.enforcement_recorded', { rows: policyRow.data ?? [], error: policyRow.error?.code ?? null });

  const deviceRow = await users.parentA.client.from('devices').select('id, status, policy_version, last_seen_at, battery_level, enforcement_mode').eq('id', deviceId).single();
  pass(deviceRow.data?.policy_version === 1 && deviceRow.data?.battery_level === 15, 'device.state_visible_to_parent', { row: deviceRow.data, error: deviceRow.error?.code ?? null });

  // --- Telemetry uploads --------------------------------------------------
  const today = new Date().toISOString().slice(0, 10);
  const usage = await fn('device-telemetry', null, {
    action: 'usage_upload',
    entries: [{ day: today, package_name: 'com.instagram.android', app_label: 'Instagram', total_ms: 3600000, last_used_at: new Date().toISOString() }],
  }, hdr);
  pass(ok(usage) && usage.json?.data?.accepted === 1, 'telemetry.usage_upload', { status: usage.status });

  const usageDup = await fn('device-telemetry', null, {
    action: 'usage_upload',
    entries: [
      { day: today, package_name: 'com.instagram.android', total_ms: 1 },
      { day: today, package_name: 'com.instagram.android', total_ms: 2 },
    ],
  }, hdr);
  pass(!ok(usageDup) && usageDup.status === 400, 'telemetry.usage_duplicate_rejected', { status: usageDup.status, code: errCode(usageDup) });

  const location = await fn('device-telemetry', null, {
    action: 'location_upload', lat: 37.5665, lng: 126.9780, accuracy_m: 12,
    recorded_at: new Date().toISOString(), source: 'qa',
  }, hdr);
  pass(ok(location) && location.json?.data?.accepted === true, 'telemetry.location_upload', { status: location.status });

  const staleLocation = await fn('device-telemetry', null, {
    action: 'location_upload', lat: 37.5, lng: 127.0, accuracy_m: 10,
    recorded_at: new Date(Date.now() - 8 * 24 * 3600 * 1000).toISOString(),
  }, hdr);
  pass(!ok(staleLocation) && staleLocation.status === 400, 'telemetry.stale_location_rejected', { status: staleLocation.status, code: errCode(staleLocation) });

  const apps = await fn('device-telemetry', null, {
    action: 'apps_upload',
    apps: [{ package_name: 'com.instagram.android', label: 'Instagram', is_system: false, is_suspended: true, version_name: '300.0' }],
  }, hdr);
  pass(ok(apps) && apps.json?.data?.accepted === 1, 'telemetry.apps_upload', { status: apps.status });

  const emptyApps = await fn('device-telemetry', null, { action: 'apps_upload', apps: [] }, hdr);
  pass(!ok(emptyApps) && emptyApps.status === 400, 'telemetry.empty_apps_rejected', { status: emptyApps.status, code: errCode(emptyApps) });

  const alerts = await users.parentA.client.from('safety_alerts').select('type, severity, acknowledged_at').eq('device_id', deviceId);
  pass((alerts.data ?? []).some((x) => x.type === 'low_battery'), 'telemetry.low_battery_alert_visible', { rows: alerts.data ?? [], error: alerts.error?.code ?? null });

  const usageRead = await users.parentA.client.from('usage_daily').select('package_name,total_ms').eq('device_id', deviceId);
  pass((usageRead.data ?? []).some((u) => u.package_name === 'com.instagram.android'), 'rls.parent_reads_child_usage', { rows: (usageRead.data ?? []).length, error: usageRead.error?.code ?? null });

  const locRead = await users.parentA.client.from('location_events').select('lat,lng').eq('device_id', deviceId);
  pass((locRead.data ?? []).length >= 1, 'rls.parent_reads_child_location', { rows: (locRead.data ?? []).length, error: locRead.error?.code ?? null });

  const foreignDeviceRead = await users.parentB.client.from('devices').select('id').eq('id', deviceId);
  pass((foreignDeviceRead.data ?? []).length === 0, 'rls.foreign_parent_cannot_read_device', { rows: (foreignDeviceRead.data ?? []).length, error: foreignDeviceRead.error?.code ?? null });

  const childSecretRead = await users.childA.client.from('devices').select('secret_hash').eq('id', deviceId);
  pass(childSecretRead.error !== null, 'rls.child_cannot_read_secret_hash', { error: childSecretRead.error?.code ?? null });

  const childDeviceUpdate = await users.childA.client.from('devices').update({ display_name: 'hijack' }).eq('id', deviceId).select('id');
  pass(childDeviceUpdate.error !== null || (childDeviceUpdate.data ?? []).length === 0, 'rls.child_cannot_update_device', { error: childDeviceUpdate.error?.code ?? null, rows: (childDeviceUpdate.data ?? []).length });

  // --- Remote assistance consent flow ------------------------------------
  const sessionReq = await fn('remote-session', 'parentA', { action: 'request', device_id: deviceId, kind: 'audio' });
  const sessionId = sessionReq.json?.data?.id;
  pass(ok(sessionReq) && sessionId && sessionReq.json?.data?.status === 'requested', 'remote.request', { status: sessionReq.status, session_id: sessionId });

  const pendingChild = await fn('remote-session', 'childA', { action: 'pending_child' });
  pass(ok(pendingChild) && (pendingChild.json?.data ?? []).some((s) => s.id === sessionId), 'remote.visible_to_child', { status: pendingChild.status });

  const foreignRespond = await fn('remote-session', 'childB', { action: 'respond', session_id: sessionId, accept: true });
  pass(!ok(foreignRespond) && foreignRespond.status === 403, 'remote.foreign_child_cannot_respond', { status: foreignRespond.status, code: errCode(foreignRespond) });

  const accept = await fn('remote-session', 'childA', { action: 'respond', session_id: sessionId, accept: true });
  pass(ok(accept) && accept.json?.data?.status === 'accepted' && accept.json?.data?.consent_recorded === true, 'remote.child_accepts_with_consent', { status: accept.status, status_value: accept.json?.data?.status });

  const start = await fn('remote-session', 'childA', { action: 'start', session_id: sessionId });
  pass(ok(start) && start.json?.data?.status === 'active', 'remote.start_after_consent', { status: start.status });

  const iceChild = await fn('remote-session', 'childA', { action: 'ice', session_id: sessionId });
  const iceServers = iceChild.json?.data?.ice_servers ?? [];
  const turnConfigured = iceChild.json?.data?.turn_configured === true;
  pass(ok(iceChild) && JSON.stringify(iceServers).includes('stun:'), 'remote.ice_config_uses_stun', { status: iceChild.status, servers: iceServers.length, turn_configured: turnConfigured });

  const iceForeign = await fn('remote-session', 'parentB', { action: 'ice', session_id: sessionId });
  pass(!ok(iceForeign) && iceForeign.status === 403, 'remote.foreign_parent_ice_denied', { status: iceForeign.status, code: errCode(iceForeign) });

  const end = await fn('remote-session', 'parentA', { action: 'end', session_id: sessionId, reason: 'qa_complete' });
  pass(ok(end) && end.json?.data?.status === 'ended', 'remote.parent_ends_session', { status: end.status });

  // --- Realtime private topics -------------------------------------------
  const rtA = await subscribeStatus(users.parentA.client, `safety-alerts:${famA}`);
  pass(rtA.status === 'SUBSCRIBED', 'realtime.family_parent_subscribes', rtA);
  const rtChild = await subscribeStatus(users.childA.client, `safety-alerts:${famA}`);
  pass(rtChild.status === 'SUBSCRIBED', 'realtime.family_child_subscribes', rtChild);
  const rtForeign = await subscribeStatus(users.parentB.client, `safety-alerts:${famA}`);
  pass(rtForeign.status !== 'SUBSCRIBED', 'realtime.foreign_parent_denied', rtForeign);
  const anon = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const rtAnon = await subscribeStatus(anon, `safety-alerts:${famA}`);
  pass(rtAnon.status !== 'SUBSCRIBED', 'realtime.anonymous_denied', rtAnon);

  // --- Command TTL expiry (real wait) ------------------------------------
  const expCmd = await fn('device-command', 'parentA', {
    action: 'create', device_id: deviceId, type: 'request_usage', payload: { days: 1 },
    idempotency_key: `qa-expiry-${Date.now()}`, ttl_seconds: 60,
  });
  const expCmdId = expCmd.json?.data?.command?.id;
  pass(ok(expCmd) && expCmdId, 'command.create_with_ttl', { status: expCmd.status, ttl: 60 });
  console.log('waiting 62s for command TTL expiry...');
  await new Promise((r) => setTimeout(r, 62000));
  const expiredAck = await fn('device-command', null, { action: 'ack', command_id: expCmdId, status: 'succeeded' }, hdr);
  pass(!ok(expiredAck) && expiredAck.status === 410, 'command.expired_ack_rejected', { status: expiredAck.status, code: errCode(expiredAck) });
  const expStatus = await users.parentA.client.from('device_commands').select('status').eq('id', expCmdId).single();
  pass(expStatus.data?.status === 'expired', 'command.expired_status_recorded', { status: expStatus.data?.status, error: expStatus.error?.code ?? null });

  // --- Revoked device is denied ------------------------------------------
  const revoke = await fn('family-admin', 'parentA', { action: 'revoke_device', device_id: deviceId });
  pass(ok(revoke), 'device.revoke', { status: revoke.status });

  const revokedBeat = await fn('device-telemetry', null, { action: 'heartbeat' }, hdr);
  pass(!ok(revokedBeat) && [401, 403].includes(revokedBeat.status), 'device.revoked_telemetry_denied', { status: revokedBeat.status, code: errCode(revokedBeat) });

  const revokedPoll = await fn('device-command', null, { action: 'poll' }, hdr);
  pass(!ok(revokedPoll) && [401, 403].includes(revokedPoll.status), 'device.revoked_command_poll_denied', { status: revokedPoll.status, code: errCode(revokedPoll) });

  const revokedControl = await fn('device-command', 'parentA', {
    action: 'create', device_id: deviceId, type: 'sync_policy', payload: {}, idempotency_key: `qa-revoked-${Date.now()}`,
  });
  pass(!ok(revokedControl), 'device.revoked_device_control_denied', { status: revokedControl.status, code: errCode(revokedControl) });

  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/phase2.json'), JSON.stringify({
    when: new Date().toISOString(), deviceId, results,
  }, null, 2));
  fs.writeFileSync(path.join(ROOT, '.tools/live/device_a.env'), `DEVICE_A_ID=${deviceId}\nINSTALLATION_ID=${installationId}\nDEVICE_A_SECRET=${deviceSecret}\n`, { mode: 0o600 });
  const failed = results.filter((r) => r.status === 'FAIL');
  console.log(`\nSUMMARY phase2: ${results.length - failed.length}/${results.length} passed, ${failed.length} failed`);
  for (const f of failed) console.log('FAILED:', f.name, JSON.stringify(f.detail));
}

main().catch((e) => {
  console.error('FATAL', e.message);
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/phase2-error.json'), JSON.stringify({ error: e.message, results }, null, 2));
  process.exit(1);
});
