// Read-only hosted state snapshot (Phase 7 pre-run). Prints ids/statuses only.
// Never prints codes, secrets, tokens or passwords.
import fs from 'node:fs';
import path from 'node:path';
import { qa, login, EVIDENCE } from './_lib.mjs';

const snap = { when: new Date().toISOString(), families: {} };
for (const [label, email, pw] of [['A', qa.PARENT_A_USER, qa.PARENT_A_PASS], ['B', qa.PARENT_B_USER, qa.PARENT_B_PASS]]) {
  const { client: c } = await login(email, pw);
  const fams = await c.from('families').select('id,name').is('deleted_at', null);
  const familyId = fams.data?.[0]?.id ?? null;
  const members = familyId ? await c.from('family_members').select('user_id,role,status').eq('family_id', familyId) : { data: [] };
  const devices = familyId ? await c.from('devices').select('id,display_name,child_user_id,status,created_at,last_seen_at,credential_revoked_at').eq('family_id', familyId).order('created_at', { ascending: false }) : { data: [] };
  const tokens = await c.from('device_pairing_tokens').select('id,child_user_id,status,expires_at,created_at').order('created_at', { ascending: false }).limit(8);
  const reqs = familyId ? await c.from('pairing_requests').select('id,child_user_id,status,expires_at,created_at').eq('family_id', familyId).order('created_at', { ascending: false }).limit(8) : { data: [] };
  const audit = familyId ? await c.from('audit_logs').select('event_type,target_type,target_id,created_at').eq('family_id', familyId).order('created_at', { ascending: false }).limit(12) : { data: [] };
  const sessions = familyId ? await c.from('remote_sessions').select('id,device_id,status,created_at').eq('family_id', familyId).order('created_at', { ascending: false }).limit(4) : { data: [] };
  snap.families[label] = {
    familyId,
    members: members.data ?? null,
    activeDevices: (devices.data ?? []).filter((d) => d.status === 'active'),
    deviceCount: (devices.data ?? []).length,
    newestDevices: (devices.data ?? []).slice(0, 4),
    tokensViewable: tokens.data?.length ?? 0,
    tokensError: tokens.error?.message ?? null,
    pairingRequests: reqs.data ?? null,
    recentAudit: audit.data ?? null,
    remoteSessions: sessions.data ?? null,
    errors: [fams.error, members.error, devices.error, reqs.error, audit.error, sessions.error].filter(Boolean).map((e) => e.message),
  };
}
fs.writeFileSync(path.join(EVIDENCE, 'state_snapshot.json'), JSON.stringify(snap, null, 2));
console.log(JSON.stringify(snap, null, 1).slice(0, 7000));
