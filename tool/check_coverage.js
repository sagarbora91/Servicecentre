// Coverage gate for the Definition of Done: >= 80% line coverage on the
// data + domain layers (lib/features/**/{data,domain}). Reads coverage/lcov.info
// produced by `flutter test --coverage`, sums LF/LH for the matching files,
// prints a per-file + total report, and exits non-zero if below the threshold.
'use strict';
const fs = require('fs');

const LCOV = 'coverage/lcov.info';
const THRESHOLD = 80;
const SCOPE = /lib\/features\/[^/]+\/(data|domain)\//;

if (!fs.existsSync(LCOV)) {
  console.error(`coverage gate: ${LCOV} not found (did 'flutter test --coverage' run?)`);
  process.exit(1);
}

const records = fs.readFileSync(LCOV, 'utf8').split('end_of_record');
let totalLF = 0;
let totalLH = 0;
const rows = [];

for (const rec of records) {
  const sfMatch = rec.match(/SF:(.*)/);
  if (!sfMatch) continue;
  const file = sfMatch[1].trim().replace(/\\/g, '/');
  if (!SCOPE.test(file)) continue;
  if (/\.(g|freezed)\.dart$/.test(file)) continue; // skip generated code
  const lf = parseInt((rec.match(/LF:(\d+)/) || [])[1] || '0', 10);
  const lh = parseInt((rec.match(/LH:(\d+)/) || [])[1] || '0', 10);
  if (lf === 0) continue; // no coverable lines (e.g. abstract interface)
  totalLF += lf;
  totalLH += lh;
  rows.push({ file, lf, lh, pct: (100 * lh) / lf });
}

rows.sort((a, b) => a.pct - b.pct);
console.log('data+domain line coverage:');
for (const r of rows) {
  console.log(`  ${r.pct.toFixed(1).padStart(5)}%  ${r.lh}/${r.lf}  ${r.file}`);
}

if (totalLF === 0) {
  console.error('coverage gate: no data/domain lines found in lcov — cannot verify the DoD.');
  process.exit(1);
}

const pct = (100 * totalLH) / totalLF;
console.log(`TOTAL: ${pct.toFixed(2)}% (${totalLH}/${totalLF}) — threshold ${THRESHOLD}%`);

if (pct < THRESHOLD) {
  console.error(`FAIL: data+domain coverage ${pct.toFixed(2)}% < ${THRESHOLD}%`);
  process.exit(1);
}
console.log('PASS: data+domain coverage meets the threshold.');
