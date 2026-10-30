// Phase 7 round 2 — bidirectional cross-family isolation, IDOR with real
// foreign ids, realtime authorisation with the correct active members.
import {
  qa, URL, KEY, FAM_A, FAM_B, login, fn, ok, code, newClient,
  pass, record, summary, save,
} from './_lib.mjs';

const TABLES = [
  'families', 'family_members', 'devices', 'device_policies', 'device_commands',
  'device_apps', 'usage_daily', 'location_events', 'safe_zones', 'safety_alerts',
  'remote_sessions', 'audit_logs', 'pairing_requests',
];

async function readZero(who, table, filters, label) {
  let query = who.client.from(table).select('*');
  for (const [c, v] of Object.entries(filters)) query = query.eq(c, v);
  const r = await query;
  const rows = (r.data ?? []).length;
  pass(rows === 0, label, { rows, error: r.error?.code ?? r.error?.message ?? null });
}

async function main() {
  const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const childA = await login(qa.CHILD_A_USER, qa.CHILD_A_PASS);
  const parentB = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childB = await login(qa.CHILD_B_USER, qa.CHILD_B_PASS);
  const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);

  // Real family-A rows (the victim set for parent B), enumerated by the owner.
  const dev = await parentA.client.from('devices').select('id,status').eq('family_id', FAM_A).limit(1);
  const pol = await parentA.client.from('device_policies').select('id,device_id').eq('family_id', FAM_A).limit(1);
  const cmd = await parentA.client.from('device_commands').select('id,status,device_id').eq('family_id', FAM_A).limit(1);
  const alr = await parentA.client.from('safety_alerts').select('id,type').eq('family_id', FAM_A).limit(1);
  const ses = await parentA.client.from('remote_sessions').select('id,status').eq('family_id', FAM_A).limit(1);
  const loc = await parentA.client.from('location_events').select('id').eq('family_id', FAM_A).limit(1);
  const usa = await parentA.client.from('usage_daily').select('id').eq('family_id', FAM_A).limit(1);
  const prq = await parentA.client.from('pairing_requests').select('id,status').eq('family_id', FAM_A).limit(1);
  const A = {
    device: dev.data?.[0]?.id, policy: pol.data?.[0]?.id, command: cmd.data?.[0]?.id,
    commandDevice: cmd.data?.[0]?.device_id, alert: alr.data?.[0]?.id,
    session: ses.data?.[0]?.id, location: loc.data?.[0]?.id, usage: usa.data?.[0]?.id,
    pairingRequest: prq.data?.[0]?.id,
  };
  record('fixture.familyA_victim_ids', 'INFO', {
    device: !!A.device, policy: !!A.policy, command: !!A.command, alert: !!A.alert,
    session: !!A.session, location: !!A.location, usage: !!A.usage, pairing: !!A.pairingRequest,
    command_status: cmd.data?.[0]?.status ?? null, session_status: ses.data?.[0]?.status ?? null,
  });

  // ---- 2. REST: parent B must not see any family-A row ---------------------
  for (const t of TABLES) {
    await readZero(parentB, t, { family_id: FAM_A }, `isoB.rest.${t}_familyA_invisible_to_parentB`);
  }
  await readZero(parentB, 'families', { id: FAM_A }, 'isoB.rest.family_row_by_id');
  await readZero(childB, 'family_members', { family_id: FAM_A }, 'isoB.rest.family_members_as_removed_childB');
  for (const t of ['devices', 'usage_daily', 'location_events', 'safety_alerts', 'remote_sessions', 'audit_logs', 'device_commands', 'device_policies']) {
    await readZero(childB, t, { family_id: FAM_A }, `isoB.rest.${t}_familyB_child_cannot_read_A`);
  }
  // Column-level: secret-bearing columns must not be readable by the owner either.
  const ownerHash = await parentA.client.from('devices').select('secret_hash').eq('family_id', FAM_A).limit(1);
  pass(ownerHash.error !== null, 'iso.owner_parent_cannot_read_secret_hash_column', {
    error: ownerHash.error?.code ?? ownerHash.error?.message ?? null,
  });
  const instRead = await parentA.client.from('devices').select('installation_id').eq('family_id', FAM_A).limit(1);
  pass(instRead.error !== null, 'iso.owner_parent_cannot_read_installation_id_column', {
    error: instRead.error?.code ?? instRead.error?.message ?? null,
  });
  const tok = await parentA.client.from('device_pairing_tokens').select('*').limit(1);
  pass(tok.error !== null, 'iso.pairing_tokens_table_not_client_readable', { error: tok.error?.code ?? tok.error?.message ?? null });
  const att = await parentA.client.from('pairing_attempts').select('*').limit(1);
  pass(att.error !== null, 'iso.pairing_attempts_table_not_client_readable', { error: att.error?.code ?? att.error?.message ?? null });

  // Positive controls: owner still reads its own rows.
  const ownCnt = await parentA.client.from('location_events').select('id').eq('family_id', FAM_A);
  pass((ownCnt.data ?? []).length > 0, 'iso.control_owner_reads_own_locations', { rows: (ownCnt.data ?? []).length });
  const ownAlerts = await parentA.client.from('safety_alerts').select('id').eq('family_id', FAM_A);
  pass((ownAlerts.data ?? []).length > 0, 'iso.control_owner_reads_own_alerts', { rows: (ownAlerts.data ?? []).length });
  const ownAudit = await parentA.client.from('audit_logs').select('id').eq('family_id', FAM_A);
  pass((ownAudit.data ?? []).length > 0, 'iso.control_owner_reads_own_audit', { rows: (ownAudit.data ?? []).length });
  const ownSessions = await parentA.client.from('remote_sessions').select('id').eq('family_id', FAM_A);
  pass((ownSessions.data ?? []).length > 0, 'iso.control_owner_reads_own_remote_sessions', { rows: (ownSessions.data ?? []).length });

  // ---- 2b. IDOR: foreign ids in Edge Function calls (parent B -> family A) --
  if (A.device) {
    const r1 = await fn('device-policy', parentB.token, { action: 'update', device_id: A.device, idempotency_key: `p7r2-${Date.now()}`, policy: { enforce_app_blocks: true } });
    pass(!ok(r1) && [403, 404].includes(r1.status), 'idorB.device_policy_update_foreign_device', { status: r1.status, code: code(r1) });
    const r2 = await fn('device-command', parentB.token, { action: 'create', device_id: A.device, type: 'sync_policy', payload: {}, idempotency_key: `p7r2c-${Date.now()}` });
    pass(!ok(r2) && [403, 404].includes(r2.status), 'idorB.device_command_create_foreign_device', { status: r2.status, code: code(r2) });
    const r3 = await fn('family-admin', parentB.token, { action: 'revoke_device', device_id: A.device });
    pass(!ok(r3) && [403, 404].includes(r3.status), 'idorB.revoke_device_foreign', { status: r3.status, code: code(r3) });
    const r4 = await fn('family-admin', parentB.token, { action: 'recover_device', device_id: A.device });
    pass(!ok(r4) && [403, 404].includes(r4.status), 'idorB.recover_device_foreign', { status: r4.status, code: code(r4) });
    const r5 = await fn('remote-session', parentB.token, { action: 'request', device_id: A.device, kind: 'audio' });
    pass(!ok(r5) && [403, 404].includes(r5.status), 'idorB.remote_session_request_foreign_device', { status: r5.status, code: code(r5) });
    const r6 = await fn('device-policy', childB.token, { action: 'update', device_id: A.device, idempotency_key: `p7r2d-${Date.now()}`, policy: {} });
    pass(!ok(r6) && [401, 403, 404].includes(r6.status), 'idorB.device_policy_as_foreign_child', { status: r6.status, code: code(r6) });
  }
  if (A.command) {
    const hdr = { 'x-device-id': A.commandDevice, 'x-device-secret': 'ab'.repeat(32) };
    const ack = await fn('device-command', null, { action: 'ack', command_id: A.command, status: 'succeeded' }, hdr);
    pass(ack.status === 401 || ack.status === 403, 'idorB.command_ack_wrong_credential', { status: ack.status, code: code(ack) });
    const poll = await fn('device-command', null, { action: 'poll' }, hdr);
    pass(poll.status === 401 || poll.status === 403, 'device.revoked_or_unknown_credential_poll_denied', { status: poll.status, code: code(poll), device_status: cmd.data?.[0]?.status });
  }
  if (A.session) {
    for (const [action, label] of [['ice', 'idorB.remote_ice_foreign_session'], ['start', 'idorB.remote_start_foreign_session'], ['end', 'idorB.remote_end_foreign_session']]) {
      const r = await fn('remote-session', parentB.token, { action, session_id: A.session });
      pass(!ok(r) && [403, 404, 409, 410].includes(r.status), label, { status: r.status, code: code(r), session_status: ses.data?.[0]?.status });
    }
    const resp = await fn('remote-session', childB.token, { action: 'respond', session_id: A.session, accept: true });
    pass(!ok(resp) && [403, 404, 409, 410].includes(resp.status), 'idorB.remote_respond_foreign_session_as_child', { status: resp.status, code: code(resp) });
    const asChildA = await fn('remote-session', childA.token, { action: 'pending_child' });
    pass(asChildA.status === 401 || asChildA.status === 403 || !ok(asChildA) || (asChildA.json?.data ?? []).length === 0, 'iso.unlinked_child_pending_sessions_empty', { status: asChildA.status, code: code(asChildA), rows: (asChildA.json?.data ?? []).length });
  }
  if (A.alert) {
    const r = await fn('family-admin', parentB.token, { action: 'ack_alert', alert_id: A.alert });
    pass(!ok(r) && [403, 404].includes(r.status), 'idorB.ack_alert_foreign', { status: r.status, code: code(r) });
  }
  if (A.pairingRequest) {
    const r = await fn('pairing', parentB.token, { action: 'cancel', request_id: A.pairingRequest });
    pass(!ok(r) && [403, 404, 409, 410].includes(r.status), 'idorB.pairing_cancel_foreign_request', { status: r.status, code: code(r) });
  }
  const pur = await fn('family-admin', parentB.token, { action: 'purge_data', family_id: FAM_A, older_than_days: 3650 });
  pass(!ok(pur) && [403].includes(pur.status), 'idorB.purge_data_foreign_family', { status: pur.status, code: code(pur) });
  const ret = await fn('family-admin', parentB.token, { action: 'update_retention', family_id: FAM_A, location_days: 7, usage_days: 7 });
  pass(!ok(ret) && [403].includes(ret.status), 'idorB.update_retention_foreign_family', { status: ret.status, code: code(ret) });
  const lf = await fn('pairing', parentB.token, { action: 'list_family', family_id: FAM_A });
  pass(!ok(lf) && lf.status === 403, 'idorB.pairing_list_family_foreign', { status: lf.status, code: code(lf) });
  const un = await fn('pairing', parentB.token, { action: 'unlink', family_id: FAM_A, child_user_id: qa.CHILD_A_ID });
  pass(!ok(un) && un.status === 403, 'idorB.pairing_unlink_foreign_family', { status: un.status, code: code(un) });

  // ---- 6. Realtime private channels ---------------------------------------
  const topic = (k, id) => `${k}:${id}:${Date.now()}${Math.floor(Math.random() * 1e5)}`;
  const subscribe = async (client, t, ms = 12000) => {
    const ch = client.channel(t, { config: { private: true } });
    const st = await new Promise((res) => {
      let s = false;
      const done = (v) => { if (!s) { s = true; res(v); } };
      ch.subscribe((status, err) => done({ status, error: err ? String(err).slice(0, 140) : null }));
      setTimeout(() => done({ status: 'TIMEOUT' }), ms);
    });
    try { await client.removeChannel(ch); } catch { /* ignore */ }
    return st;
  };
  const p1 = await subscribe(parentA.client, topic('safety-alerts', FAM_A));
  pass(p1.status === 'SUBSCRIBED', 'rt.parentA_own_family_allowed', p1);
  const p2 = await subscribe(childC.client, topic('safety-alerts', FAM_B));
  pass(p2.status === 'SUBSCRIBED', 'rt.active_child_own_family_allowed', p2);
  const n1 = await subscribe(parentB.client, topic('safety-alerts', FAM_A));
  pass(n1.status !== 'SUBSCRIBED', 'rt.parentB_familyA_denied', n1);
  const n2 = await subscribe(childA.client, topic('safety-alerts', FAM_A));
  pass(n2.status !== 'SUBSCRIBED', 'rt.removed_child_familyA_denied', n2);
  const n3 = await subscribe(childB.client, topic('safety-alerts', FAM_B));
  pass(n3.status !== 'SUBSCRIBED', 'rt.removed_child_familyB_denied', n3);
  const n4 = await subscribe(newClient(), topic('safety-alerts', FAM_A));
  pass(n4.status !== 'SUBSCRIBED', 'rt.anon_denied', n4);
  if (A.session) {
    const p3 = await subscribe(parentA.client, topic('webrtc-signals', A.session));
    pass(p3.status === 'SUBSCRIBED', 'rt.session_participant_webrtc_allowed', p3);
    const p4 = await subscribe(parentA.client, topic('remote-session', A.session));
    pass(p4.status === 'SUBSCRIBED', 'rt.session_participant_remote_topic_allowed', p4);
    const n5 = await subscribe(parentB.client, topic('webrtc-signals', A.session));
    pass(n5.status !== 'SUBSCRIBED', 'rt.foreign_parent_webrtc_denied', n5);
    const n6 = await subscribe(parentB.client, topic('remote-session', A.session));
    pass(n6.status !== 'SUBSCRIBED', 'rt.foreign_parent_remote_topic_denied', n6);
    const n7 = await subscribe(newClient(), topic('webrtc-signals', A.session));
    pass(n7.status !== 'SUBSCRIBED', 'rt.anon_webrtc_denied', n7);
  }
  const n8 = await subscribe(parentA.client, topic('safety-alerts', crypto.randomUUID()));
  pass(n8.status !== 'SUBSCRIBED', 'rt.unknown_family_topic_denied', n8);

  // ---- Edge Function auth ordering (anon with a valid action) --------------
  const anonValid = await fn('family-admin', null, { action: 'revoke_device', device_id: crypto.randomUUID() });
  pass(anonValid.status === 401, 'edge.anon_valid_action_401', { status: anonValid.status, code: code(anonValid) });
  const anonBadAction = await fn('family-admin', null, { action: 'nope' });
  record('edge.anon_invalid_action_before_auth', anonBadAction.status === 401 ? 'PASS' : 'INFO', {
    status: anonBadAction.status, code: code(anonBadAction),
    note: 'action validation runs before authentication when the status is 400',
  });
  const anonPairing = await fn('pairing', null, { action: 'create' });
  pass(anonPairing.status === 401, 'edge.pairing_anon_create_401', { status: anonPairing.status, code: code(anonPairing) });
  const anonRemote = await fn('remote-session', null, { action: 'pending_child' });
  pass(anonRemote.status === 401, 'edge.remote_session_anon_401', { status: anonRemote.status, code: code(anonRemote) });
  const anonDevicePolicy = await fn('device-policy', null, { action: 'update', device_id: crypto.randomUUID(), idempotency_key: 'x', policy: {} });
  pass(anonDevicePolicy.status === 401 || anonDevicePolicy.status === 403, 'edge.device_policy_anon_401', { status: anonDevicePolicy.status, code: code(anonDevicePolicy) });
  const anonDeviceCmd = await fn('device-command', null, { action: 'poll' });
  pass(anonDeviceCmd.status === 401, 'edge.device_command_poll_without_credential_401', { status: anonDeviceCmd.status, code: code(anonDeviceCmd) });
  const anonTelemetry = await fn('device-telemetry', null, { action: 'heartbeat' });
  pass(anonTelemetry.status === 401, 'edge.telemetry_without_credential_401', { status: anonTelemetry.status, code: code(anonTelemetry) });
  const anonRegister = await fn('device-register', null, { action: 'register', family_id: FAM_A, installation_id: 'x'.repeat(20), secret_hash: 'a'.repeat(64), display_name: 'anon' });
  pass(anonRegister.status === 401, 'edge.device_register_anon_401', { status: anonRegister.status, code: code(anonRegister) });
  const badApiKey = await fetch(`${URL}/functions/v1/pairing`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', apikey: 'invalid-anon-key', Authorization: `Bearer ${parentA.token}` },
    body: JSON.stringify({ action: 'pending_child' }),
  });
  pass(badApiKey.status === 401 || badApiKey.status === 403, 'edge.wrong_apikey_denied', { status: badApiKey.status });
  const getCors = await fetch(`${URL}/functions/v1/pairing`, { method: 'GET', headers: { apikey: KEY } });
  pass(getCors.status === 405, 'edge.get_method_not_allowed', { status: getCors.status });

  save('isolation_round2_ids.json', { victimIds: A, familyA: { devices: dev.data, sessions: ses.data, alerts: alr.data, commands: cmd.data } });
  const rc = summary('isolation_round2');
  process.exit(rc ? 1 : 0);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(2); });
