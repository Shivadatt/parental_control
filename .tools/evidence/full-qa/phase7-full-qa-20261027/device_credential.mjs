// Phase 7 — device credential validation (task 5), runnable subset.
// Positive-path checks need a live credential; none exists today (see BLOCKED).
import crypto from 'node:crypto';
import {
  qa, URL, KEY, FAM_A, FAM_B, login, fn, ok, code, pass, record, summary, save,
} from './_lib.mjs';

const hex64 = crypto.randomBytes(32).toString('hex');

async function main() {
  const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const parentB = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);

  // An existing (revoked) device row of family A used as the target id.
  const devARow = await parentA.client.from('devices').select('id,status').eq('family_id', FAM_A).limit(1).maybeSingle();
  const devBRow = await parentB.client.from('devices').select('id,status').eq('family_id', FAM_B).limit(1).maybeSingle();
  const devA = devARow.data;
  const devB = devBRow.data;
  const revokedId = devA?.id ?? devB?.id;
  record('fixture.targets', 'INFO', {
    familyA_device_status: devA?.status ?? null, familyB_device_status: devB?.status ?? null,
    all_familyA_devices: 'revoked',
  });

  const unknownId = crypto.randomUUID();
  const goodSecret = hex64;

  // --- 1. Missing / malformed credentials ---------------------------------
  const noHdr = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 });
  pass(noHdr.status === 401 && code(noHdr) === 'device_auth_required', 'cred.missing_headers_rejected', { status: noHdr.status, code: code(noHdr) });
  const halfHdr = await fn('device-telemetry', null, { action: 'heartbeat' }, { 'x-device-id': revokedId });
  pass(halfHdr.status === 401, 'cred.partial_headers_rejected', { status: halfHdr.status, code: code(halfHdr) });
  const shortSecret = await fn('device-telemetry', null, { action: 'heartbeat' }, { 'x-device-id': revokedId, 'x-device-secret': 'short' });
  pass(shortSecret.status === 401 && code(shortSecret) === 'invalid_device_credentials', 'cred.short_secret_rejected', { status: shortSecret.status, code: code(shortSecret) });
  const badUuid = await fn('device-telemetry', null, { action: 'heartbeat' }, { 'x-device-id': 'not-a-uuid', 'x-device-secret': goodSecret });
  pass(badUuid.status === 401, 'cred.malformed_device_id_rejected', { status: badUuid.status, code: code(badUuid) });

  // --- 2. Wrong secret on a real (revoked) device -------------------------
  const wrongOnReal = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 }, { 'x-device-id': revokedId, 'x-device-secret': goodSecret });
  pass(wrongOnReal.status === 401 && code(wrongOnReal) === 'invalid_device_credentials', 'cred.wrong_secret_on_existing_device_rejected', { status: wrongOnReal.status, code: code(wrongOnReal) });
  const unknownWithGood = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 50 }, { 'x-device-id': unknownId, 'x-device-secret': goodSecret });
  pass(unknownWithGood.status === 401 && code(unknownWithGood) === 'invalid_device_credentials', 'cred.unknown_device_rejected', { status: unknownWithGood.status, code: code(unknownWithGood) });
  pass(unknownWithGood.status === wrongOnReal.status && code(unknownWithGood) === code(wrongOnReal),
    'cred.unknown_id_and_wrong_secret_are_indistinguishable', { a: `${unknownWithGood.status}/${code(unknownWithGood)}`, b: `${wrongOnReal.status}/${code(wrongOnReal)}` });

  // --- 3. Command endpoints with bad credentials --------------------------
  const poll = await fn('device-command', null, { action: 'poll' }, { 'x-device-id': revokedId, 'x-device-secret': goodSecret });
  pass(poll.status === 401, 'cred.command_poll_wrong_secret_rejected', { status: poll.status, code: code(poll) });
  const pollNoHdr = await fn('device-command', null, { action: 'poll' });
  pass(pollNoHdr.status === 401 && code(pollNoHdr) === 'device_auth_required', 'cred.command_poll_without_credential_rejected', { status: pollNoHdr.status, code: code(pollNoHdr) });
  const cmdsA = await parentA.client.from('device_commands').select('id,status,device_id,expires_at').eq('family_id', FAM_A).order('created_at', { ascending: false }).limit(20);
  const expired = (cmdsA.data ?? []).filter((c) => new Date(c.expires_at) < new Date());
  const stalePending = expired.filter((c) => c.status === 'pending');
  record('cred.expired_command_census', 'INFO', {
    total: (cmdsA.data ?? []).length, past_expiry: expired.length,
    statuses_past_expiry: [...new Set(expired.map((c) => c.status))],
    pending_but_expired: stalePending.length,
    note: 'no cron is configured, so pending commands past expires_at are only flipped to expired when the device next acks/polls',
  });
  if (stalePending[0]) {
    const ack = await fn('device-command', null, { action: 'ack', command_id: stalePending[0].id, status: 'succeeded' }, { 'x-device-id': stalePending[0].device_id, 'x-device-secret': goodSecret });
    pass(ack.status === 401 || ack.status === 403, 'cred.expired_command_ack_needs_valid_credential', { status: ack.status, code: code(ack), command_id: stalePending[0].id });
  } else {
    record('cred.expired_command_ack_rejected_410', 'BLOCKED', { reason: 'no pending-but-expired command exists and no valid device credential can be minted today' });
  }

  // --- 4. User tokens cannot impersonate a device -------------------------
  const asUserBearer = await fetch(`${URL}/functions/v1/device-telemetry`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: KEY, Authorization: `Bearer ${parentA.token}`, 'x-device-id': revokedId, 'x-device-secret': goodSecret },
    body: JSON.stringify({ action: 'heartbeat' }),
  }).then(async (r) => ({ status: r.status, json: await r.json().catch(() => ({})) }));
  pass(asUserBearer.status === 401, 'cred.user_bearer_does_not_authenticate_device', { status: asUserBearer.status, code: code(asUserBearer) });

  // --- 5. Clients cannot forge telemetry rows -----------------------------
  const forgeUsage = await parentA.client.from('usage_daily').insert({ family_id: FAM_A, device_id: revokedId, day: '2026-10-27', package_name: 'com.forexample', total_ms: 1 });
  pass(forgeUsage.error !== null, 'cred.rest_insert_usage_daily_denied', { error: forgeUsage.error?.code ?? forgeUsage.error?.message ?? null });
  const forgeLoc = await parentA.client.from('location_events').insert({ family_id: FAM_A, device_id: revokedId, lat: 37.5, lng: 127, accuracy_m: 5, recorded_at: new Date().toISOString() });
  pass(forgeLoc.error !== null, 'cred.rest_insert_location_events_denied', { error: forgeLoc.error?.code ?? forgeLoc.error?.message ?? null });
  const forgeAlert = await parentA.client.from('safety_alerts').insert({ family_id: FAM_A, device_id: revokedId, type: 'low_battery', severity: 'high', message: 'forge' });
  pass(forgeAlert.error !== null, 'cred.rest_insert_safety_alerts_denied', { error: forgeAlert.error?.code ?? forgeAlert.error?.message ?? null });
  const forgeCmd = await parentB.client.from('device_commands').insert({ family_id: FAM_A, device_id: revokedId, type: 'sync_policy', status: 'pending' });
  pass(forgeCmd.error !== null, 'cred.rest_insert_device_commands_denied', { error: forgeCmd.error?.code ?? forgeCmd.error?.message ?? null });
  const forgePolicy = await childC.client.from('device_policies').insert({ family_id: FAM_B, device_id: devB?.id, version: 99, policy: {} });
  pass(forgePolicy.error !== null, 'cred.child_rest_insert_device_policies_denied', { error: forgePolicy.error?.code ?? forgePolicy.error?.message ?? null });
  const ackUpdate = await parentA.client.from('device_commands').update({ status: 'succeeded' }).eq('family_id', FAM_A).eq('status', 'expired');
  pass(ackUpdate.error !== null || (ackUpdate.data ?? []).length === 0, 'cred.rest_update_command_status_denied', { error: ackUpdate.error?.code ?? null });

  // --- 6. Telemetry payload validation is reachable only with a credential
  for (const [label, body] of [
    ['duplicate_usage', { action: 'usage_upload', entries: [{ day: '2026-10-27', package_name: 'com.example', total_ms: 1 }, { day: '2026-10-27', package_name: 'com.example', total_ms: 2 }] }],
    ['stale_location', { action: 'location_upload', lat: 37.5, lng: 127, accuracy_m: 5, recorded_at: new Date(Date.now() - 30 * 86400 * 1000).toISOString() }],
    ['empty_apps', { action: 'apps_upload', apps: [] }],
  ]) {
    const r = await fn('device-telemetry', null, body, { 'x-device-id': revokedId, 'x-device-secret': goodSecret });
    pass(r.status === 401, `cred.${label}_rejected_before_validation`, { status: r.status, code: code(r) });
  }

  record('cred.heartbeat_after_revocation_403', 'BLOCKED', {
    reason: 'the correct secret for a revoked row is not recoverable (sha256 stored, .tools/live/device_a.env deleted) and no new device can be enrolled: device-register returns 403 device_revoked for child C and 403 forbidden for the unlinked children, and re-linking needs a pairing code (429 rate_limited)',
  });
  record('cred.duplicate_and_stale_telemetry_positive', 'BLOCKED', { reason: 'same as above — requires a valid device credential' });

  const rc = summary('device_credential');
  save('device_credential_targets.json', { revokedId, familyBDevice: devB?.id });
  process.exit(rc ? 1 : 0);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(2); });
