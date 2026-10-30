import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
const ROOT = path.resolve(import.meta.dirname, '../..');
const readEnv = (f) => { const o={}; for (const l of fs.readFileSync(path.join(ROOT,f),'utf8').split(/\r?\n/)) { const i=l.indexOf('='); if(i>0)o[l.slice(0,i).trim()]=l.slice(i+1).trim(); } return o; };
const cfg = readEnv('.tools/live_config.env'); const qa = readEnv('.tools/qa_accounts.env');
for (const label of ['A','B']) {
  const c = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, { auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false} });
  const { data, error } = await c.auth.signInWithPassword({ email: qa[`CHILD_${label}_USER`], password: qa[`CHILD_${label}_PASS`] });
  if (error) { console.log(label, 'signin', error.message); continue; }
  const since = new Date(Date.now()-24*3600*1000).toISOString();
  const r = await c.from('device_pairing_tokens').select('id, created_at, expires_at').eq('child_user_id', data.user.id).gte('created_at', since).order('created_at',{ascending:false});
  console.log(label, JSON.stringify({ count: r.data?.length ?? null, error: r.error?.message ?? null, rows: r.data?.map(x=>({created:x.created_at,expires:x.expires_at})) ?? null }));
}
