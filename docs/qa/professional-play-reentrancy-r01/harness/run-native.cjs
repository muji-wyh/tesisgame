'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { runGodot } = require('../../../tools/run-godot.cjs');
const root = path.resolve(__dirname, '../../..');
const base = path.relative(root, __dirname).replaceAll('\\', '/');
const digest = raw => crypto.createHash('sha256').update(raw).digest('hex');
const writeNew = (name, value) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
if (process.argv.slice(2).join(' ') !== '--root-granted-native-slot professional-play-reentrancy-r01') throw Error('Root-granted native slot is required');
if (fs.existsSync(path.join(__dirname, 'native-attempt.json'))) throw Error('Existing attempt is immutable');
const selected = new Set([
  `${base}/native_entry.gd`, `${base}/run-native.cjs`, `${base}/preimages/scripts/professional_play.gd`,
  `${base}/preimages/tests/godot/professional_play_tests.gd`, 'tools/run-godot.cjs',
  'data/professional/catalog.json', 'data/professional/themes.json'
]);
function inspect(relative) {
  const raw = fs.readFileSync(path.join(root, relative));
  if (relative.endsWith('.gd')) {
    const source = raw.toString('utf8');
    const matches = [...source.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g),
      ...source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g)];
    for (const match of matches) if (!selected.has(match[1])) { selected.add(match[1]); inspect(match[1]); }
  }
}
for (const relative of [...selected]) inspect(relative);
const inventory = () => [...selected].sort().map(relative => {
  const raw = fs.readFileSync(path.join(root, relative));
  return { path: relative, bytes: raw.length, sha256: digest(raw) };
});
const inputs = inventory();
writeNew('execution-input-inventory.json', { schema: 1, files: inputs });
const started = Date.now();
writeNew('native-attempt.json', { schema: 1, started_at: new Date(started).toISOString(), root,
  command: ['--headless', '--path', root, '--script', `res://${base}/native_entry.gd`],
  timeout_ms: 60000, input_inventory_sha256: digest(fs.readFileSync(path.join(__dirname, 'execution-input-inventory.json'))) });
let error = null, output = '';
try {
  const result = runGodot(['--headless', '--path', root, '--script', `res://${base}/native_entry.gd`], { timeout: 60000 });
  output = result.stdout + result.stderr;
} catch (failure) { error = failure.message; output = failure.message; }
fs.writeFileSync(path.join(__dirname, 'native.log'), output, { flag: 'wx' });
const after = inventory();
const changed = inputs.filter((entry, index) => JSON.stringify(entry) !== JSON.stringify(after[index])).map(entry => entry.path);
let current = null, original = null;
try {
  current = JSON.parse(fs.readFileSync(path.join(__dirname, 'current-report.json'), 'utf8'));
  original = JSON.parse(fs.readFileSync(path.join(__dirname, 'original-reproduction.json'), 'utf8'));
} catch (failure) { error ||= failure.message; }
const retainedPasses = new Set([
  'Pending cancellation preserves the active claimed Access lease',
  'Controller teardown releases that active Access lease exactly once',
  'An unchanged current opening still publishes its original selection and source'
]);
const baselineExpected = original?.count === 17 && original?.invariant_failures === 14 &&
  original.checks.every(row => row.passed === retainedPasses.has(row.check));
const ok = !error && changed.length === 0 && baselineExpected && current?.count === 31 && current.failures === 0 && current.checks.every(row => row.passed);
const receipt = { schema: 1, ok, duration_ms: Date.now() - started, current_checks: current?.count ?? null,
  current_failures: current?.failures ?? null, original_observations: original?.count ?? null,
  original_invariant_failures: original?.invariant_failures ?? null, expected_original_reproduction: baselineExpected,
  guarded_input_count: inputs.length, inputs_unchanged: changed.length === 0, changed_paths: changed, error,
  log_sha256: digest(fs.readFileSync(path.join(__dirname, 'native.log'))),
  current_report_sha256: current ? digest(fs.readFileSync(path.join(__dirname, 'current-report.json'))) : null,
  original_report_sha256: original ? digest(fs.readFileSync(path.join(__dirname, 'original-reproduction.json'))) : null,
  production_scope: ['scripts/professional_play.gd', 'tests/godot/professional_play_tests.gd'],
  domain_policy_installed: false, content_acceptance_changed: false };
writeNew('validation-receipt.json', receipt);
process.stdout.write(JSON.stringify(receipt, null, 2) + '\n');
if (!ok) process.exitCode = 1;
