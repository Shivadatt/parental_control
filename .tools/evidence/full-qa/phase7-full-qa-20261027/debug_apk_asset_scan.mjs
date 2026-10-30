// Phase 7 secret hygiene: the debug APK carries Dart source in
// flutter_assets/kernel_blob.bin instead of libapp.so — scan it and every
// other flutter asset for privileged values. Names only, never values.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const EVIDENCE = import.meta.dirname;
const ROOT = path.resolve(EVIDENCE, '../../../..');
const TMP = path.join(EVIDENCE, 'debug_assets_extract');
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
const markers = [
  ['role":"service_role', Buffer.from('"role":"service_role"')],
  ['sb_secret_', Buffer.from('sb_secret_')],
  ['static-auth-secret', Buffer.from('static-auth-secret')],
  ['CRON_SECRET=', Buffer.from('CRON_SECRET=')],
  ['TURN_SECRET=', Buffer.from('TURN_SECRET=')],
  ['postgres://', Buffer.from('postgres://')],
];

const report = { scanned_at: new Date().toISOString(), files: [], privileged_hits: [], marker_hits: [] };
for (const apk of ['app-debug.apk', 'app-release.apk']) {
  const ap = path.join(ROOT, 'build/app/outputs/flutter-apk', apk);
  const listing = execFileSync('unzip', ['-Z', '-1', ap, 'assets/flutter_assets/*'], { maxBuffer: 64 * 1024 * 1024 }).toString().split(/\r?\n/).filter(Boolean);
  report.files.push({ apk, asset_count: listing.length });
  for (const entry of listing) {
    const dest = path.join(TMP, `${apk}__${entry.split('/').pop()}`);
    try { execFileSync('unzip', ['-o', '-q', '-j', ap, entry, '-d', TMP], { stdio: 'ignore' }); } catch { continue; }
    const produced = path.join(TMP, path.basename(entry));
    if (!fs.existsSync(produced)) continue;
    fs.renameSync(produced, dest);
    const buf = fs.readFileSync(dest);
    fs.unlinkSync(dest);
    const hits = privileged.filter((p) => buf.includes(p.value)).map((p) => p.name);
    const mk = markers.filter(([, n]) => buf.includes(n)).map(([n]) => n);
    if (hits.length) report.privileged_hits.push({ apk, entry, hits });
    if (mk.length) report.marker_hits.push({ apk, entry, markers: mk, bytes: buf.length });
  }
}
fs.writeFileSync(path.join(EVIDENCE, 'debug_apk_asset_scan.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 1).slice(0, 3000));
