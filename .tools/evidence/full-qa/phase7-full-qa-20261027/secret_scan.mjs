// Phase 7 secret-hygiene scan (task 7).
// Loads privileged values from the local gitignored .tools files and searches
// the repo working tree + the extracted release APK for them.
// Reports ONLY the variable name and the file path; never a value.
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '../../../..');
const APK = path.join(import.meta.dirname, 'apk_assets_scan/release_universal');

const loadPairs = (file) => {
  const out = [];
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) return out;
  for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0) {
      const name = line.slice(0, i).trim();
      const value = line.slice(i + 1).trim();
      if (value.length >= 6) out.push({ name: `${path.basename(file)}:${name}`, value });
    }
  }
  if (!out.length) {
    const v = fs.readFileSync(p, 'utf8').trim();
    if (v.length >= 6) out.push({ name: `${path.basename(file)}:<file-content>`, value: v });
  }
  return out;
};

const files = [
  '.tools/live_config.env', '.tools/qa_accounts.env', '.tools/ui_journey.env',
  '.tools/supabase-db-password.txt', '.tools/test-parent-pw.txt', '.tools/test-child-pw.txt',
  'supabase/.branches', '.supabase/.env',
];
const all = files.flatMap(loadPairs);
// Client-safe values are expected inside the APK; everything else is privileged.
const SAFE = new Set(['live_config.env:SUPABASE_URL', 'live_config.env:SUPABASE_ANON_KEY',
  'qa_accounts.env:PARENT_A_USER', 'qa_accounts.env:PARENT_B_USER', 'qa_accounts.env:CHILD_A_USER',
  'qa_accounts.env:CHILD_B_USER', 'qa_accounts.env:CHILD_C_USER',
  'qa_accounts.env:PARENT_A_ID', 'qa_accounts.env:PARENT_B_ID', 'qa_accounts.env:CHILD_A_ID',
  'qa_accounts.env:CHILD_B_ID', 'qa_accounts.env:CHILD_C_ID']);
const privileged = all.filter((p) => !SAFE.has(p.name));
const safeValues = all.filter((p) => SAFE.has(p.name));

const SKIP_DIRS = new Set(['.git', 'node_modules', 'build', '.dart_tool', 'ios', 'macos', 'linux', 'windows']);
const report = { scanned_at: new Date().toISOString(), privileged_vars_checked: privileged.map((p) => p.name), hits: [], regex_hits: [], safe_present: [] };

const patterns = [
  ['service_role_jwt', /"role"\s*:\s*"service_role"/],
  ['jwt_payload_service_role_b64', /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]*cml2ZWNlX3JvbGU/i],
  ['sb_secret_key', /\bsb_secret_[A-Za-z0-9_-]{8,}/],
  ['postgres_uri_with_password', /postgres(ql)?:\/\/[^\s"']*:[^\s"'@]+@/],
  ['turn_static_auth_secret', /static-auth-secret\s*=\s*[A-Za-z0-9+/=]{16,}/],
  ['cron_secret_assignment', /CRON_SECRET=[^\s"']{16,}/],
  ['anon_key_jwt', /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}/],
];

function scanFile(fp, buf, isApk) {
  const text = buf.toString('latin1');
  for (const p of privileged) {
    if (text.includes(p.value)) {
      report.hits.push({ var: p.name, file: isApk ? path.relative(APK, fp) : path.relative(ROOT, fp), size: buf.length });
    }
  }
  for (const [name, re] of patterns) {
    const m = text.match(re);
    if (m) {
      // A publishable/anon JWT is expected; do not treat it as a leak.
      let kind = name;
      if (name === 'anon_key_jwt') {
        const isSafe = safeValues.some((s) => s.value === m[0]);
        if (isSafe) { report.safe_present.push({ kind: 'client_anon_jwt_present', file: isApk ? path.relative(APK, fp) : path.relative(ROOT, fp) }); continue; }
        kind = 'unmatched_jwt_in_file';
      }
      report.regex_hits.push({ pattern: kind, file: isApk ? path.relative(APK, fp) : path.relative(ROOT, fp), snippet: m[0].slice(0, 24) + '…' });
    }
  }
}

function walk(dir, isApk, skipTools = false) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!isApk && SKIP_DIRS.has(entry.name)) continue;
    const fp = path.join(dir, entry.name);
    if (entry.isDirectory()) { walk(fp, isApk, skipTools); continue; }
    let st; try { st = fs.statSync(fp); } catch { continue; }
    if (st.size > 40 * 1024 * 1024) continue;
    if (/\.(png|jpg|jpeg|webp|mp4|zip|ttf|woff|woff2|ico|so|dex|jar|apk|bundle|gz)$/i.test(entry.name) && !isApk) continue;
    let buf;
    try { buf = fs.readFileSync(fp); }
    catch (e) { (report.skipped ??= []).push(`${path.relative(ROOT, fp)} (${e.code})`); continue; }
    scanFile(fp, buf, isApk);
  }
}

walk(path.join(ROOT, 'lib'), false);
walk(path.join(ROOT, 'android'), false);
walk(path.join(ROOT, 'supabase'), false);
walk(path.join(ROOT, 'scripts'), false);
walk(path.join(ROOT, 'integration_test'), false);
walk(path.join(ROOT, 'test'), false);
for (const f of ['pubspec.yaml', 'README.md', '.env.example', 'analysis_options.yaml']) {
  const fp = path.join(ROOT, f);
  if (fs.existsSync(fp)) scanFile(fp, fs.readFileSync(fp), false);
}
if (fs.existsSync(APK)) walk(APK, true);
else report.apk_note = 'extracted APK dir missing';

fs.writeFileSync(path.join(import.meta.dirname, 'secret_scan.json'), JSON.stringify(report, null, 2));
console.log(`privileged vars checked: ${privileged.length} (${privileged.map((p) => p.name).join(', ')})`);
console.log(`APK files scanned: ${fs.existsSync(APK) ? 'yes' : 'NO'}`);
console.log(`LEAK HITS: ${report.hits.length}`);
for (const h of report.hits) console.log('  LEAK', h.var, '->', h.file);
console.log(`REGEX HITS: ${report.regex_hits.length}`);
for (const h of report.regex_hits) console.log('  ', h.pattern, '->', h.file, h.snippet);
console.log(`client-safe values present (expected): ${report.safe_present.length + new Set(report.safe_present.map((s) => s.file)).size} file markers`);
