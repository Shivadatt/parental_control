import fs from 'node:fs';
import path from 'node:path';

const dir = 'audit/_work';
const sources = [
  ['inv-a-family-dashboard-alerts.md', 'FA', 'Family, dashboard, alerts, extra'],
  ['inv-b-camera-screen-audio.md', 'FB', 'Camera, screen, audio'],
  ['inv-c-controls-monitoring.md', 'FC', 'Controls and monitoring'],
  ['inv-d-web-location.md', 'FD', 'Web, location, geofence'],
];

const statuses = [
  'FULLY IMPLEMENTED — VERIFIED',
  'IMPLEMENTED — PARTIALLY VERIFIED',
  'PARTIALLY IMPLEMENTED',
  'UI ONLY',
  'BACKEND ONLY',
  'CODE EXISTS — NOT TESTED',
  'BROKEN',
  'MISSING',
  'BLOCKED — ACCESS REQUIRED',
  'NOT APPLICABLE',
];

const rec = {
  'FULLY IMPLEMENTED — VERIFIED': 'Keep; extend runtime regression coverage to edge cases.',
  'IMPLEMENTED — PARTIALLY VERIFIED': 'Verify the remaining subfeatures on hardware; add a device/integration test.',
  'PARTIALLY IMPLEMENTED': 'Close the listed gaps before counting this toward parity.',
  'UI ONLY': 'Connect to backend/device enforcement or remove the surface.',
  'BACKEND ONLY': 'Expose in the UI and verify the end-to-end path.',
  'CODE EXISTS — NOT TESTED': 'Add a device/integration test before release.',
  'BROKEN': 'Fix the referenced defect before release.',
  'MISSING': 'Implement end-to-end, or explicitly descope it from the roadmap.',
  'BLOCKED — ACCESS REQUIRED': 'Resolve the access/permission blocker, then verify.',
  'NOT APPLICABLE': 'No action — platform-specific capability.',
};

function splitRow(line) {
  const inner = line.trim().replace(/^\|/, '').replace(/\|$/, '');
  // Split on | that is not inside backticks.
  const cells = [];
  let cur = '';
  let inTick = false;
  for (const ch of inner) {
    if (ch === '`') inTick = !inTick;
    if (ch === '|' && !inTick) { cells.push(cur.trim()); cur = ''; continue; }
    cur += ch;
  }
  cells.push(cur.trim());
  return cells;
}

const anomalies = [];
const rows = [];
for (const [file, prefix, label] of sources) {
  const text = fs.readFileSync(path.join(dir, file), 'utf8');
  let n = 0;
  const seen = new Set();
  for (const line of text.split(/\r?\n/)) {
    if (!line.startsWith('| F-')) continue;
    const cells = splitRow(line);
    if (cells.length !== 12) {
      anomalies.push(`${file}: expected 12 cells, got ${cells.length}: ${line.slice(0, 120)}`);
      continue;
    }
    const status = cells[10].replace(/\s+/g, ' ').trim();
    if (!statuses.includes(status)) {
      anomalies.push(`${file}: unknown status "${status}" in ${cells[0]}`);
    }
    let id = cells[0].replace(/^\|\s*/, '').trim();
    if (seen.has(id)) anomalies.push(`${file}: duplicate id ${id}`);
    seen.add(id);
    n += 1;
    id = `${prefix}-${String(n).padStart(3, '0')}`;
    const gap = cells[11];
    const pri = (gap.match(/\bP[0-3]\b/g) || []).slice(-1)[0] || '—';
    const missingRisk = gap.replace(/\bP[0-3]\b\s*$/, '').trim();
    rows.push({
      id, area: label, cat: cells[1], feature: cells[2], ui: cells[3], flutter: cells[4],
      android: cells[5], backend: cells[6], e2e: cells[7], tests: cells[8], runtime: cells[9],
      status, missingRisk, pri, rec: rec[status] || '—',
    });
  }
  console.log(`${file}: ${n} rows`);
}

const counts = Object.fromEntries(statuses.map((s) => [s, 0]));
for (const r of rows) counts[r.status] += 1;

const out = [];
out.push('# 01 — Complete feature inventory (merged)');
out.push('');
out.push(`Generated from the four inventory fragments in \`audit/_work/\` (A ${rows.filter(r=>r.area.startsWith('Family')).length}, B ${rows.filter(r=>r.area.startsWith('Camera')).length}, C ${rows.filter(r=>r.area.startsWith('Controls')).length}, D ${rows.filter(r=>r.area.startsWith('Web')).length} rows). Feature IDs were renumbered sequentially per area (FA/FB/FC/FD); the original per-file IDs collided and are not reused.`);
out.push('');
out.push('Column note: the auditing agents produced one combined "missing parts / risk / priority" cell, which is split here into **Missing parts & risk** and **Priority** (last `P0`–`P3` token). **Recommendation** is rule-derived from the status (documented in `scripts` of this merge) and is intentionally generic; per-feature engineering recommendations live in [10_GAP_ANALYSIS_AND_PRIORITIES.md](10_GAP_ANALYSIS_AND_PRIORITIES.md). Cells are abbreviated; full detail and line-level citations are in the four source fragments.');
out.push('');
out.push('## Counts (computed from the rows below)');
out.push('');
out.push('| Status | Rows |');
out.push('|---|---|');
for (const s of statuses) out.push(`| ${s} | ${counts[s]} |`);
out.push(`| **Total** | **${rows.length}** |`);
out.push('');
out.push('## Inventory');
out.push('');
out.push('| Feature ID | AirDroid category | Feature | Existing UI | Flutter implementation | Android implementation | Backend implementation | End-to-end integration | Automated tests | Runtime evidence | Current status | Missing parts & risk | Priority | Recommendation |');
out.push('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
for (const r of rows) {
  const c = [r.id, r.cat, r.feature, r.ui, r.flutter, r.android, r.backend, r.e2e, r.tests, r.runtime, r.status, r.missingRisk, r.pri, r.rec];
  out.push(`| ${c.map((x) => x.replace(/\|/g, '\\|')).join(' | ')} |`);
}

out.push('');
out.push('## Anomalies detected during merge');
out.push('');
out.push(anomalies.length ? anomalies.map((a) => `- ${a}`).join('\n') : 'None: every row had exactly 12 cells and a status from the approved vocabulary; no duplicate IDs within a source.');
out.push('');
out.push('## Integrity note');
out.push('');
out.push('Rows were not edited or re-classified during the merge; only IDs, the status column and the priority cell were normalized. Where a source used "FULLY VERIFIED"/"partially_verified" shorthand in its count block, the actual row text was authoritative.');
out.push('');

fs.writeFileSync('audit/01_COMPLETE_FEATURE_INVENTORY.md', out.join('\n'));
console.log('total rows:', rows.length);
console.log(counts);
console.log('anomalies:', anomalies.length);
for (const a of anomalies) console.log(' -', a);