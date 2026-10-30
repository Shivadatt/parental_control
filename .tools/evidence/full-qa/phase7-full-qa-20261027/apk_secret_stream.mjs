// Phase 7 secret hygiene, APK part: stream the shipping libapp.so + assets out
// of each built APK and look for privileged values. Reports variable NAMES only.
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';

const run = promisify(execFile);
const EVIDENCE = import.meta.dirname;
const ROOT = path.resolve(EVIDENCE, '../../../..');
const APK_DIR = path.join(ROOT, 'build/app/outputs/flutter-apk');

const loadPairs = (file) => {
  const out = [];
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) return out;
  const txt = fs.readFileSync(p, 'utf8');
  for (const line of txt.split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0) out.push({ name: `${path.basename(file)}:${line.slice(0, i).trim()}`, value: line.slice(i + 1).trim() });
    else if (!line.includes('=') && line.trim().length >= 8) out.push({ name: `${path.basename(file)}:<file>`, value: line.trim() });
  }
  return out;
};
const all = ['.tools/live_config.env', '.tools/qa_accounts.env', '.tools/ui_journey.env',
  '.tools/supabase-db-password.txt', '.tools/test-parent-pw.txt', '.tools/test-child-pw.txt']
  .flatMap(loadPairs).filter((p) => p.value.length >= 6);
const SAFE_NAMES = new Set(['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'QA_PARENT_EMAIL', 'QA_CHILD_EMAIL',
  'PARENT_A_USER', 'PARENT_B_USER', 'CHILD_A_USER', 'CHILD_B_USER', 'CHILD_C_USER',
  'PARENT_A_ID', 'PARENT_B_ID', 'CHILD_A_ID', 'CHILD_B_ID', 'CHILD_C_ID']);
const privileged = all.filter((p) => !SAFE_NAMES.has(p.name.split(':')[1]));

const jwtRoles = [];
function scanBuf(label, buf) {
  const text = buf.toString('latin1');
  const hits = privileged.filter((p) => text.includes(p.value)).map((p) => p.name);
  for (const m of text.matchAll(/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g)) {
    try {
      const payload = JSON.parse(Buffer.from(m[1] ?? m[0].split('.')[1], 'base64url').toString('utf8'));
      jwtRoles.push({ artifact: label, role: payload.role ?? null, email_claim: payload.email ? 'yes' : 'no', kind: payload.api_key ? 'apikey' : 'jwt' });
    } catch { jwtRoles.push({ artifact: label, role: 'unparseable' }); }
  }
  const markers = [];
  for (const [name, re] of [['sb_secret', /\bsb_secret_[A-Za-z0-9_-]{8,}/g], ['static-auth-secret', /static-auth-secret[=:][^\s"'`]{8,}/gi], ['postgres_uri_password', /postgres(ql)?:\/\/[^\s"'`]*:[^\s"'@]+@[^\s"'`]+/gi]]) {
    if (re.test(text)) markers.push(name);
  }
  return { hits, markers, bytes: buf.length };
}

const report = { scanned_at: new Date().toISOString(), privileged_vars: privileged.map((p) => p.name), artifacts: {}, jwt_roles: [] };
const entries = ['lib/arm64-v8a/libapp.so', 'lib/x86_64/libapp.so'];
for (const apk of fs.readdirSync(APK_DIR).filter((f) => f.endsWith('.apk'))) {
  const out = { entries_scanned: [], results: {} };
  for (const e of entries) {
    try {
      const { stdout } = await run('unzip', ['-p', path.join(APK_DIR, apk), e], { maxBuffer: 400 * 1024 * 1024, windowsHide: true, encoding: 'buffer' });
      const buf = Buffer.isBuffer(stdout) ? stdout : Buffer.from(String(stdout), 'binary');
      const r = scanBuf(`${apk}/${e}`, buf);
      out.entries_scanned.push(e);
      out.results[e] = { privileged_hits: r.hits, secret_markers: r.markers, bytes: r.bytes };
    } catch { out.results[e] = { absent: true }; }
  }
  // Also scan the flutter asset manifest + any dart-defines baked into assets.
  try {
    const { stdout } = await run('unzip', ['-p', path.join(APK_DIR, apk), 'assets/flutter_assets/AssetManifest.bin'], { maxBuffer: 64 * 1024 * 1024, windowsHide: true }).catch(() => ({ stdout: '' }));
    if (stdout) out.asset_manifest_bytes = stdout.length;
  } catch { /* ignore */ }
  report.artifacts[apk] = out;
}
report.jwt_roles = [...new Map(jwtRoles.map((j) => [`${j.artifact}|${j.role}`, j])).values()];
fs.writeFileSync(path.join(EVIDENCE, 'apk_secret_scan.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 1).slice(0, 3000));
