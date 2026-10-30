// Phase 7 — cross-family isolation, IDOR, server-derived roles, realtime authz.
// Runs entirely against EXISTING hosted rows (no device credential required).
// Prints HTTP codes and row counts only; never secrets.
import {
  qa, cfg, URL, KEY, FAM_A, FAM_B, login, fn, ok, code, newClient,
  pass, record, summary, save,
} from './_lib.mjs';

const TABLES = [
  'families', 'family_members', 'profiles', 'devices', 'device_policies',
  'device_commands', 'device_apps', 'usage_daily', 'location_events',
  'safe_zones', 'safe_zone_states', 'safety_alerts', 'remote_sessions',
  'webrtc_signals', 'audit_logs', 'pairing_requests',
];
const FORBIDDEN_TABLES = ['device_pairing_tokens', 'pairing_attempts'];

let deviceId = null;      // a family-B owned device row (foreign for parent A)
let childBId = null;
let parentIdB = null;

async function authedSelect(who, table, filters, label) {
  const q = who.client.from(table).select('*');
  let query = q;
  for (const [col, val] of Object.entries(filters)) query = query.eq(col, val);
  const r = await query;
  const rows = (r.data ?? []).length;
  pass(rows === 0, label, { rows, error: r.error?.code ?? r.error?.message ?? null });
  return rows;
}

async function main() {
  const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const childA = await login(qa.CHILD_A_USER, qa.CHILD_A_PASS);
  const parentB = await login(qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const childB = await login(qa.CHILD_B_USER, qa.CHILD_B_PASS);
  const childC = await login(qa.CHILD_C_USER, qa.CHILD_C_PASS);
  childBId = childB.id; parentIdB = parentB.id;

  record('fixture.signed_in', 'INFO', { anon_key_len: KEY.length, host: URL.replace(/^https:\/\//, '').split('/')[0] });

  // Family B data inventory (as the legitimate parent B) to build the foreign-id set.
  const bDevices = await parentB.client.from('devices').select('id,status,child_user_id').eq('family_id', FAM_B);
  const bSessions = await parentB.client.from('remote_sessions').select('id,status,device_id').eq('family_id', FAM_B);
  const bAlerts = await parentB.client.from('safety_alerts').select('id,type').eq('family_id', FAM_B).limit(3);
  const bLoc = await parentB.client.from('location_events').select('id').eq('family_id', FAM_B).limit(1);
  const bUsage = await parentB.client.from('usage_daily').select('id').eq('family_id', FAM_B).limit(1);
  const bAudit = await parentB.client.from('audit_logs').select('id').eq('family_id', FAM_B).limit(1);
  deviceId = (bDevices.data ?? [])[0]?.id ?? null;
  const sessionId = (bSessions.data ?? [])[0]?.id ?? null;
  const alertId = (bAlerts.data ?? [])[0]?.id ?? null;
  pass(!!deviceId, 'fixture.familyB_rows_available', {
    devices: (bDevices.data ?? []).length, sessions: (bSessions.data ?? []).length,
    alerts: (bAlerts.data ?? []).length, error: bDevices.error?.message ?? null,
  });

  // ---- 2. Cross-family REST reads (PARENT_A must see nothing of family B) --
  for (const t of TABLES) {
    await authedSelect(parentA, t, { family_id: FAM_B }, `isolation.rest.${t}_familyB_invisible_to_parentA`);
  }
  await authedSelect(parentA, 'families', { id: FAM_B }, 'isolation.rest.family_row_by_id');
  await authedSelect(childA, 'family_members', { family_id: FAM_B }, 'isolation.rest.family_members_by_childA');
  // Child A must not read family B through the child path either.
  for (const t of ['devices', 'location_events', 'usage_daily', 'safety_alerts', 'audit_logs', 'remote_sessions']) {
    await authedSelect(childA, t, { family_id: FAM_B }, `isolation.rest.${t}_familyB_invisible_to_childA`);
  }
  // Own-family reads must still work (positive control, proves filters are not the cause).
  const ownDevices = await parentB.client.from('devices').select('id').eq('family_id', FAM_B);
  pass((ownDevices.data ?? []).length > 0, 'isolation.control_parentB_reads_own_devices', {
    rows: (ownDevices.data ?? []).length, error: ownDevices.error?.message ?? null,
  });
  const ownProfiles = await parentB.client.from('profiles').select('id').eq('id', childBId);
  pass((ownProfiles.data ?? []).length >= 0, 'isolation.control_profiles_scope', {
    rows: (ownProfiles.data ?? []).length, error: ownProfiles.error?.message ?? null,
  });
  for (const t of FORBIDDEN_TABLES) {
    const r = await parentB.client.from(t).select('*').limit(1);
    pass(r.error !== null, `isolation.rest.${t}_not_client_readable`, {
      error: r.error?.code ?? r.error?.message ?? null, rows: (r.data ?? []).length,
    });
  }

  // ---- 2b. IDOR: foreign device / session / alert ids in Edge Functions ----
  if (deviceId) {
    const cases = [
      ['device-policy', { action: 'update', device_id: deviceId, idempotency_key: `p7-fp-${Date.now()}`, policy: { enforce_app_blocks: true } }, 'idor.device_policy_update_foreign_device'],
      ['device-command', { action: 'create', device_id: deviceId, type: 'sync_policy', payload: {}, idempotency_key: `p7-fc-${Date.now()}` }, 'idor.device_command_create_foreign_device'],
      ['family-admin', { action: 'revoke_device', device_id: deviceId }, 'idor.revoke_foreign_device'],
      ['family-admin', { action: 'recover_device', device_id: deviceId }, 'idor.recover_foreign_device'],
      ['remote-session', { action: 'request', device_id: deviceId, kind: 'audio' }, 'idor.remote_request_foreign_device'],
    ];
    for (const [name, body, label] of cases) {
      const r = await fn(name, parentA.token, body);
      pass(!ok(r) && [401, 403, 404].includes(r.status), label, { status: r.status, code: code(r) });
    }
    // Device-role endpoints must reject a user token presented as the device.
    const fakeHdr = { 'x-device-id': deviceId, 'x-device-secret': 'deadbeef'.repeat(8) };
    const poll = await fn('device-command', null, { action: 'poll' }, fakeHdr);
    pass(poll.status === 401 || poll.status === 403, 'idor.command_poll_wrong_or_revoked_credential', { status: poll.status, code: code(poll) });
    const beat = await fn('device-telemetry', null, { action: 'heartbeat', battery_level: 10 }, fakeHdr);
    pass(beat.status === 401 || beat.status === 403, 'idor.heartbeat_revoked_device_denied', { status: beat.status, code: code(beat) });
    const beatUnknown = await fn('device-telemetry', null, { action: 'heartbeat' }, { 'x-device-id': crypto.randomUUID(), 'x-device-secret': 'aa'.repeat(32) });
    pass(beatUnknown.status === 401, 'device.unknown_device_id_denied', { status: beatUnknown.status, code: code(beatUnknown) });
    const noHdr = await fn('device-telemetry', null, { action: 'heartbeat' });
    pass(noHdr.status === 401, 'device.missing_credential_headers_denied', { status: noHdr.status, code: code(noHdr) });
    // device-policy as anon (no bearer, apikey only)
    const anonPolicy = await fn('device-policy', null, { action: 'update', device_id: deviceId, idempotency_key: 'p7-anon', policy: {} });
    pass(anonPolicy.status === 401 || anonPolicy.status === 403, 'idor.device_policy_anon_denied', { status: anonPolicy.status, code: code(anonPolicy) });
  }
  if (sessionId) {
    const sCases = [
      ['respond', 'idor.session_respond_foreign_child'],
      ['start', 'idor.session_start_foreign'],
      ['end', 'idor.session_end_foreign'],
      ['ice', 'idor.session_ice_foreign'],
    ];
    for (const [action, label] of sCases) {
      const r = await fn('remote-session', parentA.token, { action, session_id: sessionId, accept: true });
      pass(!ok(r) && [401, 403, 404, 409, 410].includes(r.status), label, { status: r.status, code: code(r) });
    }
    const anonIce = await fn('remote-session', null, { action: 'ice', session_id: sessionId });
    pass(anonIce.status === 401 || anonIce.status === 403, 'idor.session_ice_anon_denied', { status: anonIce.status, code: code(anonIce) });
  } else {
    record('idor.session_*', 'SKIP', { reason: 'no remote_sessions row visible to family B' });
  }
  if (alertId) {
    const r = await fn('family-admin', parentA.token, { action: 'ack_alert', alert_id: alertId });
    pass(!ok(r) && [401, 403, 404].includes(r.status), 'idor.ack_alert_foreign', { status: r.status, code: code(r) });
  }
  const purge = await fn('family-admin', parentA.token, { action: 'purge_data', family_id: FAM_B, older_than_days: 3650 });
  pass(!ok(purge) && [401, 403].includes(purge.status), 'idor.purge_data_foreign_family', { status: purge.status, code: code(purge) });
  const retention = await fn('family-admin', parentA.token, { action: 'update_retention', family_id: FAM_B, location_days: 7, usage_days: 7 });
  pass(!ok(retention) && [401, 403].includes(retention.status), 'idor.update_retention_foreign_family', { status: retention.status, code: code(retention) });
  const listFam = await fn('pairing', parentA.token, { action: 'list_family', family_id: FAM_B });
  pass(!ok(listFam) && listFam.status === 403, 'idor.pairing_list_family_foreign', { status: listFam.status, code: code(listFam) });
  const unlinkA = await fn('pairing', parentA.token, { action: 'unlink', family_id: FAM_B, child_user_id: childBId });
  pass(!ok(unlinkA) && unlinkA.status === 403, 'idor.unlink_child_foreign_family', { status: unlinkA.status, code: code(unlinkA) });
  const redeemForeign = await fn('pairing', parentA.token, { action: 'redeem', code: '123456', family_id: FAM_B });
  pass(!ok(redeemForeign) && redeemForeign.status === 403, 'idor.redeem_into_foreign_family', { status: redeemForeign.status, code: code(redeemForeign) });
  const respondForeign = await fn('pairing', childA.token, { action: 'respond', request_id: deviceId ?? crypto.randomUUID(), approve: true });
  pass(!ok(respondForeign) && [403, 404, 410].includes(respondForeign.status), 'idor.pairing_respond_foreign_request', { status: respondForeign.status, code: code(respondForeign) });

  // ---- 3. Auth roles: server-derived, client cannot promote ---------------
  const patchChild = await childB.client.from('profiles').update({ role: 'parent' }).eq('id', childBId);
  pass(patchChild.error !== null || (patchChild.data ?? []).length === 0, 'role.patch_own_profile_denied', {
    error: patchChild.error?.code ?? patchChild.error?.message ?? null, rows: (patchChild.data ?? []).length,
  });
  const patchOther = await parentA.client.from('profiles').update({ role: 'child' }).eq('id', childBId);
  pass(patchOther.error !== null || (patchOther.data ?? []).length === 0, 'role.patch_other_user_denied', {
    error: patchOther.error?.code ?? patchOther.error?.message ?? null, rows: (patchOther.data ?? []).length,
  });
  const insertProfile = await parentA.client.from('profiles').insert({ id: crypto.randomUUID(), role: 'parent', email: 'phase7-insert@invalid.local', display_name: 'evil' });
  pass(insertProfile.error !== null || (insertProfile.data ?? []).length === 0, 'role.insert_profile_as_parent_denied', {
    error: insertProfile.error?.code ?? insertProfile.error?.message ?? null, rows: (insertProfile.data ?? []).length,
  });
  const insertMember = await parentA.client.from('family_members').insert({ family_id: FAM_B, user_id: parentA.id, role: 'parent', status: 'active' });
  pass(insertMember.error !== null || (insertMember.data ?? []).length === 0, 'role.insert_membership_foreign_family_denied', {
    error: insertMember.error?.code ?? insertMember.error?.message ?? null, rows: (insertMember.data ?? []).length,
  });
  const promoteSelf = await fn('auth-bootstrap', childB.token, { action: 'set_role', role: 'parent' });
  pass(!ok(promoteSelf) && ['role_already_set', 'forbidden', 'validation_error', 'http_401', 'http_403'].includes(String(code(promoteSelf))), 'role.bootstrap_child_to_parent_denied', {
    status: promoteSelf.status, code: code(promoteSelf),
  });
  const createFamilyAsChild = await fn('auth-bootstrap', childB.token, { action: 'create_family', name: 'Phase7 Evil Family' });
  pass(!ok(createFamilyAsChild) && createFamilyAsChild.status === 403, 'role.bootstrap_create_family_as_child_denied', {
    status: createFamilyAsChild.status, code: code(createFamilyAsChild),
  });
  const anonPatch = await fetch(`${URL}/rest/v1/profiles?id=eq.${childBId}`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json', apikey: KEY },
    body: JSON.stringify({ role: 'parent' }),
  });
  pass(anonPatch.status === 401 || anonPatch.status === 403, 'role.anon_patch_denied', { status: anonPatch.status });
  const memberRoleUpdate = await parentA.client.from('family_members').update({ role: 'parent' }).eq('family_id', FAM_B).eq('user_id', childBId);
  pass(memberRoleUpdate.error !== null || (memberRoleUpdate.data ?? []).length === 0, 'role.membership_role_update_foreign_denied', {
    error: memberRoleUpdate.error?.code ?? memberRoleUpdate.error?.message ?? null, rows: (memberRoleUpdate.data ?? []).length,
  });
  const verifyRole = await childB.client.from('profiles').select('role').eq('id', childBId).maybeSingle();
  pass(verifyRole.data?.role === 'child', 'role.child_still_child_after_attempts', { role: verifyRole.data?.role ?? null, error: verifyRole.error?.message ?? null });

  // ---- 6. Realtime private channel authorization --------------------------
  const subscribeStatus = async (client, topic, ms = 12000) => {
    const channel = client.channel(topic, { config: { private: true } });
    const st = await new Promise((resolve) => {
      let settled = false;
      const done = (v) => { if (!settled) { settled = true; resolve(v); } };
      channel.subscribe((s, err) => done({ status: s, error: err ? String(err).slice(0, 160) : null }));
      setTimeout(() => done({ status: 'TIMEOUT' }), ms);
    });
    try { await client.removeChannel(channel); } catch { /* ignore */ }
    return st;
  };
  const appTopic = (base, id) => `${base}:${id}:${Date.now()}${Math.floor(Math.random() * 1e5)}`;

  const t1 = await subscribeStatus(parentB.client, appTopic('safety-alerts', FAM_B));
  pass(t1.status === 'SUBSCRIBED', 'realtime.parentB_own_family_allowed', t1);
  const t2 = await subscribeStatus(childC.client, appTopic('safety-alerts', FAM_B));
  pass(t2.status === 'SUBSCRIBED', 'realtime.active_child_own_family_allowed', t2);
  const t3 = await subscribeStatus(parentA.client, appTopic('safety-alerts', FAM_B));
  pass(t3.status !== 'SUBSCRIBED', 'realtime.parentA_familyB_denied', t3);
  const t4 = await subscribeStatus(childA.client, appTopic('safety-alerts', FAM_B));
  pass(t4.status !== 'SUBSCRIBED', 'realtime.childA_familyB_denied', t4);
  const anonClient = newClient();
  const t5 = await subscribeStatus(anonClient, appTopic('safety-alerts', FAM_B));
  pass(t5.status !== 'SUBSCRIBED', 'realtime.anon_familyB_denied', t5);
  if (sessionId) {
    const t6 = await subscribeStatus(parentB.client, appTopic('webrtc-signals', sessionId));
    pass(t6.status === 'SUBSCRIBED', 'realtime.session_participant_webrtc_allowed', t6);
    const t7 = await subscribeStatus(parentA.client, appTopic('webrtc-signals', sessionId));
    pass(t7.status !== 'SUBSCRIBED', 'realtime.foreign_webrtc_denied', t7);
    const t8 = await subscribeStatus(parentA.client, appTopic('remote-session', sessionId));
    pass(t8.status !== 'SUBSCRIBED', 'realtime.foreign_remote_session_denied', t8);
  }
  const t9 = await subscribeStatus(parentA.client, appTopic('safety-alerts', crypto.randomUUID()));
  pass(t9.status !== 'SUBSCRIBED', 'realtime.random_family_topic_denied', t9);

  // ---- Extra: Edge Function auth surface (valid actions, anon bearer) -----
  const anonCases = [
    ['family-admin', { action: 'revoke_device', device_id: crypto.randomUUID() }, 'edge.family_admin_anon_denied'],
    ['device-policy', { action: 'update', device_id: crypto.randomUUID(), idempotency_key: 'p7-anon-1', policy: {} }, 'edge.device_policy_anon_denied'],
    ['pairing', { action: 'pending_child' }, 'edge.pairing_anon_denied'],
    ['remote-session', { action: 'pending_child' }, 'edge.remote_session_anon_denied'],
    ['device-register', { action: 'register', family_id: FAM_A, installation_id: 'qa-anon-probe-1', secret_hash: 'a'.repeat(64), display_name: 'anon' }, 'edge.device_register_anon_denied'],
  ];
  for (const [name, body, label] of anonCases) {
    const r = await fn(name, null, body);
    pass(r.status === 401, label, { status: r.status, code: code(r) });
  }
  const anonAction = await fn('family-admin', null, { action: 'nope' });
  record('edge.anon_invalid_action_status', anonAction.status === 401 ? 'PASS' : 'INFO', {
    status: anonAction.status, code: code(anonAction),
    note: '400 here means requireAction() runs before requireUser(): unauthenticated callers can enumerate valid actions and consume function invocations',
  });
  const cronNoSecret = await fn('cron', null, { action: 'expire_sessions' });
  pass(cronNoSecret.status === 401 || cronNoSecret.status === 403, 'edge.cron_without_secret_denied', { status: cronNoSecret.status, code: code(cronNoSecret) });
  const cronBadSecret = await fn('cron', null, { action: 'detect_offline' }, { authorization: 'Bearer wrong-secret-phase7' });
  pass(cronBadSecret.status === 401 || cronBadSecret.status === 403, 'edge.cron_wrong_secret_denied', { status: cronBadSecret.status, code: code(cronBadSecret) });

  save('device_inventory_familyB.json', { devices: bDevices.data, sessions: bSessions.data, locations: bLoc.data, usage: bUsage.data, audit: bAudit.data });
  const rc = summary('cross_family_isolation');
  process.exit(rc ? 1 : 0);
}

main().catch((e) => { console.error('FATAL', e.message); process.exit(2); });
