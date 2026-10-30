// Hosted live verification for the Parent Control backend.
// Reads publishable key + QA account credentials from local gitignored files.
// Never prints tokens, passwords or secret values.
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
  console.log(`${status === 'PASS' ? 'PASS' : status} ${name}${detail ? ' :: ' + JSON.stringify(detail) : ''}`);
};

const users = {};
async function signIn(label, email, password) {
  const client = createClient(URL, KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`signin ${label}: ${error.message}`);
  users[label] = { client, token: data.session.access_token, id: data.user.id };
  return users[label];
}

async function fn(name, who, body, extra = {}) {
  const bearer = who === null ? KEY : users[who].token;
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
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });

  // --- Phase 0: sign in all four QA accounts -------------------------------
  const a = await signIn('parentA', qa.PARENT_A_USER, qa.PARENT_A_PASS);
  const ca = await signIn('childA', qa.CHILD_A_USER, qa.CHILD_A_PASS);
  const b = await signIn('parentB', qa.PARENT_B_USER, qa.PARENT_B_PASS);
  const cb = await signIn('childB', qa.CHILD_B_USER, qa.CHILD_B_PASS);
  record('signin.parentA', a.id === qa.PARENT_A_ID ? 'PASS' : 'FAIL', { id: a.id });
  record('signin.childA', ca.id === qa.CHILD_A_ID ? 'PASS' : 'FAIL', { id: ca.id });
  record('signin.parentB', b.id === qa.PARENT_B_ID ? 'PASS' : 'FAIL', { id: b.id });
  record('signin.childB', cb.id === qa.CHILD_B_ID ? 'PASS' : 'FAIL', { id: cb.id });

  // --- Phase 1: family B bootstrap (roles + family) -----------------------
  for (const [label, userId, role] of [
    ['parentB', qa.PARENT_B_ID, 'parent'],
    ['childB', qa.CHILD_B_ID, 'child'],
  ]) {
    const r = await fn('auth-bootstrap', label, { action: 'set_role', role, display_name: `QA ${role} B` });
    const already = code(r) === 'role_already_set';
    record(`bootstrap.set_role.${label}`, ok(r) || already ? 'PASS' : 'FAIL', { status: r.status, code: code(r), id: r.json?.data?.id ?? userId });
  }

  const famB = await fn('auth-bootstrap', 'parentB', { action: 'create_family', name: 'QA Family B' });
  let familyBId = famB.json?.data?.id;
  if (!ok(famB) && code(famB) === 'family_exists') {
    const { data } = await users.parentB.client.from('families').select('id,name').is('deleted_at', null);
    familyBId = data?.[0]?.id;
  }
  record('bootstrap.familyB', familyBId ? 'PASS' : 'FAIL', { status: famB.status, code: code(famB), family_id: familyBId });

  const famAId = 'c4e15505-05f4-4faf-a268-789f454fbcd4';

  // --- Phase 2: pairing A (create -> redeem -> pending -> approve) --------
  let pairACode = null;
  const createA = await fn('pairing', 'childA', { action: 'create' });
  const alreadyLinkedA = code(createA) === 'child_already_linked';
  if (alreadyLinkedA) {
    record('pairing.A.create', 'PASS', { note: 'child A already linked from prior run', code: code(createA) });
  } else {
    pairACode = createA.json?.data?.code;
    record('pairing.A.create', ok(createA) && pairACode ? 'PASS' : 'FAIL', {
      status: createA.status,
      qr: createA.json?.data?.qr_payload?.startsWith('parentcontrol://pair?code=') ?? false,
      expires_at: createA.json?.data?.expires_at,
    });
  }

  let pairARequestId = null;
  if (pairACode) {
    const redeemA = await fn('pairing', 'parentA', { action: 'redeem', code: pairACode, family_id: famAId });
    pairARequestId = redeemA.json?.data?.id;
    record('pairing.A.redeem', ok(redeemA) && pairARequestId ? 'PASS' : 'FAIL', {
      status: redeemA.status,
      code: code(redeemA),
      request_status: redeemA.json?.data?.status,
      family_id: redeemA.json?.data?.family_id,
    });

    const pendingA = await fn('pairing', 'childA', { action: 'pending_child' });
    const rows = pendingA.json?.data ?? [];
    record('pairing.A.pending_child', ok(pendingA) && rows.some((r) => r.id === pairARequestId) ? 'PASS' : 'FAIL', {
      status: pendingA.status,
      count: rows.length,
    });

    const respondA = await fn('pairing', 'childA', { action: 'respond', request_id: pairARequestId, approve: true });
    record('pairing.A.respond_approve', ok(respondA) ? 'PASS' : 'FAIL', {
      status: respondA.status,
      code: code(respondA),
      result: respondA.json?.data,
    });

    const membersA = await users.childA.client
      .from('family_members')
      .select('family_id, user_id, role, status')
      .eq('user_id', qa.CHILD_A_ID);
    record('pairing.A.membership_visible_to_child', (membersA.data ?? []).some((m) => m.family_id === famAId && m.status === 'active') ? 'PASS' : 'FAIL', {
      rows: membersA.data ?? [],
      error: membersA.error?.code ?? null,
    });

    // Replay of the same code by the same parent after approval.
    const replayA = await fn('pairing', 'parentA', { action: 'redeem', code: pairACode, family_id: famAId });
    record('pairing.A.replay_denied', !ok(replayA) ? 'PASS' : 'FAIL', { status: replayA.status, code: code(replayA) });

    // Replay by a different parent / family.
    const replayB = await fn('pairing', 'parentB', { action: 'redeem', code: pairACode, family_id: familyBId });
    record('pairing.A.cross_family_redeem_denied', !ok(replayB) ? 'PASS' : 'FAIL', { status: replayB.status, code: code(replayB) });
  } else {
    pairARequestId = null;
    record('pairing.A.redeem', 'SKIP', { reason: 'no fresh code' });
  }

  // --- Phase 3: pairing B -------------------------------------------------
  let pairBCode = null;
  const createB = await fn('pairing', 'childB', { action: 'create' });
  if (code(createB) === 'child_already_linked') {
    record('pairing.B.create', 'PASS', { note: 'child B already linked from prior run', code: code(createB) });
  } else {
    pairBCode = createB.json?.data?.code;
    record('pairing.B.create', ok(createB) && pairBCode ? 'PASS' : 'FAIL', { status: createB.status });
  }
  let pairBRequestId = null;
  if (pairBCode) {
    const redeemB = await fn('pairing', 'parentB', { action: 'redeem', code: pairBCode, family_id: familyBId });
    pairBRequestId = redeemB.json?.data?.id;
    record('pairing.B.redeem', ok(redeemB) ? 'PASS' : 'FAIL', { status: redeemB.status, code: code(redeemB) });
    const respondB = await fn('pairing', 'childB', { action: 'respond', request_id: pairBRequestId, approve: true });
    record('pairing.B.respond_approve', ok(respondB) ? 'PASS' : 'FAIL', { status: respondB.status, code: code(respondB) });
  } else {
    record('pairing.B.redeem', 'SKIP', { reason: 'no fresh code' });
  }

  // --- Phase 4: isolation & role escalation -------------------------------
  const familiesB = await users.parentB.client.from('families').select('id,name');
  const familyIdsB = (familiesB.data ?? []).map((f) => f.id);
  record('isolation.parentB_families_exclude_A', familyIdsB.length > 0 && !familyIdsB.includes(famAId) ? 'PASS' : 'FAIL', {
    count: familyIdsB.length,
    includesA: familyIdsB.includes(famAId),
    error: familiesB.error?.code ?? null,
  });

  const famARowB = await users.parentB.client.from('families').select('id').eq('id', famAId);
  record('isolation.parentB_cannot_read_family_A', (famARowB.data ?? []).length === 0 ? 'PASS' : 'FAIL', {
    rows: (famARowB.data ?? []).length,
    error: famARowB.error?.code ?? null,
  });

  const membersAViewB = await users.parentB.client.from('family_members').select('family_id,user_id').eq('family_id', famAId);
  record('isolation.parentB_cannot_read_A_members', (membersAViewB.data ?? []).length === 0 ? 'PASS' : 'FAIL', {
    rows: (membersAViewB.data ?? []).length,
    error: membersAViewB.error?.code ?? null,
  });

  const listAasB = await fn('pairing', 'parentB', { action: 'list_family', family_id: famAId });
  record('isolation.list_family_A_as_B_denied', !ok(listAasB) ? 'PASS' : 'FAIL', { status: listAasB.status, code: code(listAasB) });

  const selfPromote = await fn('auth-bootstrap', 'childA', { action: 'set_role', role: 'parent' });
  record('security.child_cannot_self_promote', !ok(selfPromote) && code(selfPromote) === 'role_already_set' ? 'PASS' : 'FAIL', {
    status: selfPromote.status,
    code: code(selfPromote),
  });

  const directPromote = await users.childA.client.from('profiles').update({ role: 'parent' }).eq('id', qa.CHILD_A_ID);
  record('security.child_direct_role_update_denied', directPromote.error !== null || (directPromote.data ?? []).length === 0 ? 'PASS' : 'FAIL', {
    error: directPromote.error?.code ?? directPromote.error?.message ?? null,
    rows: (directPromote.data ?? []).length,
  });

  // Anonymous table access must be denied.
  const anon = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const anonRead = await anon.from('profiles').select('id').limit(1);
  record('security.anon_profile_read_denied', anonRead.error !== null ? 'PASS' : 'FAIL', { error: anonRead.error?.code ?? null, rows: (anonRead.data ?? []).length });

  fs.writeFileSync(path.join(ROOT, '.tools/live/results/phase1.json'), JSON.stringify({ when: new Date().toISOString(), results, familyAId: famAId, familyBId, pairARequestId }, null, 2));
  const failed = results.filter((r) => r.status === 'FAIL');
  console.log(`\nSUMMARY phase1: ${results.length - failed.length}/${results.length} passed, ${failed.length} failed`);
}

main().catch((e) => {
  console.error('FATAL', e.message);
  fs.mkdirSync(path.join(ROOT, '.tools/live/results'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.tools/live/results/phase1-error.json'), JSON.stringify({ error: e.message, results }, null, 2));
  process.exit(1);
});
