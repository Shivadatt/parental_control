// Realtime private-channel authorization probe with retries.
import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';

const ROOT = path.resolve(import.meta.dirname, '../..');
const readEnv = (file) => Object.fromEntries(fs.readFileSync(path.join(ROOT, file), 'utf8').split(/\r?\n/).filter((l) => l.includes('=')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]));
const cfg = readEnv('.tools/live_config.env');
const qa = readEnv('.tools/qa_accounts.env');
const URL = cfg.SUPABASE_URL;
const KEY = cfg.SUPABASE_ANON_KEY;
const famA = 'c4e15505-05f4-4faf-a268-789f454fbcd4';

async function signIn(email, password) {
  const client = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
  await client.realtime.setAuth(data.session.access_token);
  return client;
}

async function probe(client, topic, ms = 15000) {
  const channel = client.channel(topic, { config: { private: true } });
  channel.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safety_alerts' }, () => {});
  const out = await new Promise((resolve) => {
    let settled = false;
    const done = (v) => { if (!settled) { settled = true; resolve(v); } };
    channel.subscribe((s, err) => done({ status: s, error: err ? String(err).slice(0, 200) : null }));
    setTimeout(() => done({ status: 'TIMEOUT' }), ms);
  });
  try { await client.removeChannel(channel); } catch { /* ignore */ }
  return out;
}

const parentA = await signIn(qa.PARENT_A_USER, qa.PARENT_A_PASS);
const childA = await signIn(qa.CHILD_A_USER, qa.CHILD_A_PASS);
const parentB = await signIn(qa.PARENT_B_USER, qa.PARENT_B_PASS);
const anon = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

const membership = await childA.from('family_members').select('family_id, role, status').eq('user_id', qa.CHILD_A_ID);
console.log('child membership visible:', JSON.stringify(membership.data), membership.error?.code ?? '');

for (let attempt = 1; attempt <= 3; attempt += 1) {
  const parent = await probe(parentA, `safety-alerts:${famA}`);
  const child = await probe(childA, `safety-alerts:${famA}`);
  const remote = await probe(parentA, `remote-session-family:${famA}`);
  const foreign = await probe(parentB, `safety-alerts:${famA}`);
  const guest = await probe(anon, `safety-alerts:${famA}`);
  console.log(`attempt ${attempt}:`, JSON.stringify({ parent, child, remote, foreign, guest }));
  if (parent.status === 'SUBSCRIBED' && child.status === 'SUBSCRIBED') break;
  await new Promise((r) => setTimeout(r, 4000));
}
process.exit(0);
