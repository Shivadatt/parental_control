// Phase 7 secret hygiene: chunked scan of the DEBUG apk's native payload plus
// every flutter asset, for privileged values. Prints variable names only.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const EVIDENCE = import.meta.dirname;
const ROOT = path.resolve(EVIDENCE, '../../../..');
const TMP = path.join(EVIDENCE, 'debug_apk_extract');
fs.mkdirSync(TMP, { recursive: true });

const loadPairs = (file) => {
  const out = [];
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) return out;
  for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0) { if (line.slice(i + 1).trim().length >= 6) out.push({ name: `${path.basename(file)}:${line.slice(0, i).trim()}`, value: line.slice(i + 1).trim() }); }
    else if (line.trim().length >= 8) out.push({ name: `${path.basename(file)}:<file>`, value: line.trim() });
  }
  return out;
};
const SAFE = new Set(['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'QA_PARENT_EMAIL', 'QA_CHILD_EMAIL',
  'PARENT_A_USER', 'PARENT_B_USER', 'CHILD_A_USER', 'CHILD_B_USER', 'CHILD_C_USER',
  'PARENT_A_ID', 'PARENT_B_ID', 'CHILD_A_ID', 'CHILD_B_ID', 'CHILD_C_ID']);
const all = ['.tools/live_config.env', '.tools/qa_accounts.env', '.tools/ui_journey.env',
  '.tools/supabase-db-password.txt', '.tools/test-parent-pw.txt', '.tools/test-child-pw.txt'].flatMap(loadPairs);
const privileged = all.filter((p) => !SAFE.has(p.name.split(':')[1]));
const clientValues = all.filter((p) => SAFE.has(p.name.split(':')[1]));

const markers = [
  ['service_role_claim', Buffer.from('"role":"service_role"')],
  ['sb_secret_prefix', Buffer.from('sb_secret_')],
  ['static_auth_secret', Buffer.from('static-auth-secret')],
  ['cron_secret_assign', Buffer.from('CRON_SECRET=')],
  ['turn_secret_assign', Buffer.from('TURN_SECRET=')],
  ['postgres_uri', Buffer.from('postgres://')],
  ['postgresql_uri', Buffer.from('postgresql://')],
  ['pgpassword_env', Buffer.from('PGPASSWORD=')],
];

function scanStream(label, src) {
  const hits = [];
  const found = [];
  const CH = 8 * 1024 * 1024;
  return new Promise((resolve) => {
    let carry = Buffer.alloc(0);
    const rs = fs.createReadStream(src, { highWaterMark: CH });
    rs.on('data', (chunk) => {
      const buf = carry.length ? Buffer.concat([carry, chunk]) : chunk;
      for (const p of privileged) if (buf.includes(p.value)) hits.push(p.name);
      for (const p of clientValues) if (buf.includes(p.value) && !found.includes(p.name)) found.push(p.name);
      for (const [name, needle] of markers) if (buf.includes(needle) && !found.includes(`marker:${name}`)) found.push(`marker:${name}`);
      carry = buf.subarray(Math.max(0, buf.length - 64));
    });
    rs.on('close', () => resolve({ label, privileged_hits: [...new Set(hits)], present_client_or_marker: found }));
    rs.on('error', (e) => resolve({ label, error: String(e).slice(0, 80) }));
  });
}

const out = { scanned_at: new Date().toISOString(), privileged_vars: privileged.map((p) => p.name), results: [] };
const jobs = [];
for (const apk of ['app-debug.apk', 'app-arm64-v8a-release.apk', 'app-armeabi-v7a-release.apk', 'app-release.apk']) {
  const ap = path.join(ROOT, 'build/app/outputs/flutter-apk', apk);
  if (!fs.existsSync(ap)) { out.results.push({ apk, missing: true }); continue; }
  for (const entry of ['lib/arm64-v8a/libapp.so', 'lib/x86_64/libapp.so', 'lib/armeabi-v7a/libapp.so', 'assets/flutter_assets/AssetManifest.json']) {
    const dest = path.join(TMP, `${apk}.${entry.replace(/[\\/]/g, '_')}`);
    try { execFileSync('unzip', ['-o', '-q', '-j', ap, entry, '-d', TMP], { stdio: 'ignore' }); } catch { continue; }
    const produced = path.join(TMP, path.basename(entry));
    if (!fs.existsSync(produced)) continue;
    fs.renameSync(produced, dest);
    jobs.push(scanStream(`${apk}/${entry}`, dest).then((r) => { out.results.push(r); try { fs.unlinkSync(dest); } catch { /* keep */ } }));
  }
}
await Promise.all(jobs);
fs.writeFileSync(path.join(EVIDENCE, 'apk_secret_chunked.json'), JSON.stringify(out, null, 2));
console.log(JSON.stringify(out, null, 1).slice(0, 4000));
