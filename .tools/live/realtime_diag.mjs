import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';

const ROOT = path.resolve(import.meta.dirname, '../..');
const readEnv = (f) => Object.fromEntries(fs.readFileSync(path.join(ROOT, f), 'utf8').split(/\r?\n/).filter((l) => l.includes('=')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]));
const env = readEnv('.tools/live_config.env');
const qa = readEnv('.tools/qa_accounts.env');

const c = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
const { data, error } = await c.auth.signInWithPassword({ email: qa.PARENT_A_USER, password: qa.PARENT_A_PASS });
if (error) throw error;
await c.realtime.setAuth(data.session.access_token);
await c.realtime.connect();
await new Promise((r) => setTimeout(r, 1500));
console.log('socket', { connected: c.realtime.isConnected(), tokenLen: String(c.realtime.accessTokenValue ?? '').length, x: c.realtime._isManualToken?.() });

const pub = c.channel('qa-public-' + Date.now());
const ps = await new Promise((res) => { let s = false; const d = (v) => { if (!s) { s = true; res(v); } }; pub.subscribe((x, e) => d({ x, e: e ? String(e).slice(0, 120) : null })); setTimeout(() => d({ x: 'TIMEOUT' }), 10000); });
console.log('public', JSON.stringify(ps));
await c.removeChannel(pub);

const priv = c.channel('safety-alerts:c4e15505-05f4-4faf-a268-789f454fbcd4', { config: { private: true } });
console.log('private join payload token?', Boolean(priv.params?.config?.private), priv.params?.config?.private);
const rs = await new Promise((res) => { let s = false; const d = (v) => { if (!s) { s = true; res(v); } }; priv.subscribe((x, e) => d({ x, e: e ? String(e).slice(0, 160) : null })); setTimeout(() => d({ x: 'TIMEOUT' }), 10000); });
console.log('private', JSON.stringify(rs));
await c.removeChannel(priv);
process.exit(0);
