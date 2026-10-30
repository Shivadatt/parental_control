// Shared helpers for Phase 7 backend/security harnesses.
// Loads supabase-js from the existing .tools/live/node_modules so no new
// dependency install is required. Never prints secrets.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const ROOT = path.resolve(import.meta.dirname, '../../../..');
export const EVIDENCE = import.meta.dirname;

const SUPA_PATH = path.join(ROOT, '.tools/live/node_modules/@supabase/supabase-js/dist/index.mjs');
const { createClient } = await import(pathToFileURL(SUPA_PATH).href);
export { createClient };

export const readEnv = (file) => {
  const out = {};
  for (const line of fs.readFileSync(path.join(ROOT, file), 'utf8').split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return out;
};

export const cfg = readEnv('.tools/live_config.env');
export const qa = readEnv('.tools/qa_accounts.env');
export const URL = cfg.SUPABASE_URL;
export const KEY = cfg.SUPABASE_ANON_KEY;
export const FAM_A = 'c4e15505-05f4-4faf-a268-789f454fbcd4';
export const FAM_B = '4c4dd6fe-e727-4f66-bfba-7edd801114a8';

export const results = [];
export function record(name, status, detail) {
  results.push({ name, status, detail });
  const line = `${status} ${name}${detail === undefined ? '' : ' :: ' + JSON.stringify(detail)}`;
  console.log(line);
  return line;
}
export const pass = (cond, name, detail) => record(name, cond ? 'PASS' : 'FAIL', detail);

export function newClient() {
  return createClient(URL, KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function signIn(email, password, tries = 4) {
  let last = null;
  for (let i = 0; i < tries; i++) {
    try {
      const client = newClient();
      const { data, error } = await client.auth.signInWithPassword({ email, password });
      if (error) throw new Error(error.message);
      return { client, token: data.session.access_token, id: data.user.id };
    } catch (e) { last = e; await sleep(2000 * (i + 1)); }
  }
  throw new Error(`signin failed after ${tries} attempts: ${last?.message}`);
}

export const login = signIn;

export async function fn(name, bearer, body, extra = {}, tries = 3) {
  let last = null;
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(`${URL}/functions/v1/${name}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: KEY,
          Authorization: `Bearer ${bearer === null ? KEY : bearer}`,
          ...extra,
        },
        body: JSON.stringify(body),
      });
      const text = await res.text();
      let json;
      try { json = JSON.parse(text); } catch { json = { raw: text.slice(0, 200) }; }
      return { status: res.status, json };
    } catch (e) {
      last = { status: 0, json: { network_error: String(e).slice(0, 90) } };
      await sleep(1500 * (i + 1));
    }
  }
  return last;
}

export const ok = (r) => r.json?.ok === true;
export const code = (r) => r.json?.error?.code ?? `http_${r.status}`;

export function save(file, obj) {
  fs.writeFileSync(path.join(EVIDENCE, file), JSON.stringify(obj, null, 2));
}

export function summary(label) {
  const failed = results.filter((r) => r.status === 'FAIL');
  const skipped = results.filter((r) => r.status === 'SKIP' || r.status === 'INFO' || r.status === 'BLOCKED');
  const line = `SUMMARY ${label}: ${results.length - failed.length}/${results.length} not-failed, ${failed.length} FAILED, ${skipped.length} SKIP/INFO/BLOCKED (total ${results.length})`;
  console.log('\n' + line);
  for (const f of failed) console.log('FAILED:', f.name, JSON.stringify(f.detail));
  save(`${label}.json`, { when: new Date().toISOString(), results, totals: {
    total: results.length,
    pass: results.filter((r) => r.status === 'PASS').length,
    fail: failed.length,
    other: results.filter((r) => r.status !== 'PASS' && r.status !== 'FAIL').length,
  } });
  return failed.length;
}
