'use strict';
// Root dispatches once after inspecting the actual fourth-ten committed journal.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(process.argv.length, 4);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const raw = file => fs.readFileSync(path.join(root, file));
const read = file => JSON.parse(raw(file));
const json = value => JSON.stringify(value, null, 2) + '\n';
const sourceBefore = sha(fs.readFileSync(__filename));
assert.equal(sourceBefore, process.argv[2], 'Supply the reviewed wrapper source hash.');
const docs = 'docs/content-review/foundation-module02-language-fourth10-2026-10-17';
const commitPath = docs + '/commit-receipt.json';
assert.equal(sha(raw(commitPath)), process.argv[3], 'Supply the inspected actual commit receipt hash.');
const commit = read(commitPath);
assert.equal(commit.status, 'committed');
assert.equal(commit.result.committed, true);
const bindingPath = 'build/professional-english/foundation02-fourth10-prepared-output-review-r02/binding.json';
assert.equal(sha(raw(bindingPath)), 'dbacf79ca796410664a1a6af9a577172c93234109b3c33c326ba669a5394dc21');
const binding = read(bindingPath);
const expected = {...binding.expected_inputs};
assert.equal(Object.keys(expected).length, 864);
assert.equal(binding.replacements.length, 5);
for (const row of binding.replacements) expected[row.target] = row.after.raw_sha256;
expected['data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json'] = commit.provenance_sha256;
assert.equal(Object.keys(expected).length, 865);
const check = () => {
  assert.equal(sha(fs.readFileSync(__filename)), sourceBefore);
  assert.equal(sha(raw(commitPath)), process.argv[3]);
  for (const [file, hash] of Object.entries(expected)) assert.equal(sha(raw(file)), hash, file);
};
check();
const attempt = path.join(__dirname, 'attempt-001');
assert(!fs.existsSync(attempt), 'Never replay this persisted validation.');
fs.mkdirSync(attempt);
const write = (file, value) => fs.writeFileSync(path.join(attempt, file), value, {flag: 'wx'});
const began = new Date().toISOString(), commands = [];
write('start.json', json({schema: 1, started_at: began, source_sha256: sourceBefore,
  committed_receipt: {path: commitPath, sha256: process.argv[3]}, expected_inputs: expected}));
let error = null;
function run(args) {
  check();
  const started = new Date().toISOString();
  const outcome = spawnSync(process.execPath, args, {cwd: root, windowsHide: true, encoding: 'utf8',
    timeout: 600000, maxBuffer: 32 * 1024 * 1024});
  const output = Buffer.from((outcome.stdout || '') + (outcome.stderr || ''));
  const log = 'command-' + (commands.length + 1) + '.log';
  write(log, output);
  commands.push({command: [process.execPath, ...args], started_at: started, finished_at: new Date().toISOString(),
    exit_code: outcome.status, signal: outcome.signal, error: outcome.error?.message || null,
    log, log_sha256: sha(output)});
  assert(!outcome.error, outcome.error?.message);
  assert.equal(outcome.status, 0, output.toString('utf8').slice(-5000));
  assert(!/(?:^|\n)(?:SCRIPT )?ERROR:/.test(output.toString('utf8')));
  check();
}
try {
  run(['tools/validate-professional-content.cjs']);
  run(['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs']);
  run(['tools/run-godot.cjs', '--headless', '--path', root, '--script', 'res://tests/godot/professional_retail_morphology_tests.gd']);
  run(['--test', docs + '/committed-evidence.test.cjs']);
} catch (failure) { error = failure.stack || String(failure); }
const sourceAfter = sha(fs.readFileSync(__filename));
if (sourceBefore !== sourceAfter) error = (error || '') + '\nValidation wrapper changed during execution.';
const result = {schema: 1, ok: error === null, started_at: began, finished_at: new Date().toISOString(),
  source_before: sourceBefore, source_after: sourceAfter, committed_receipt: {path: commitPath, sha256: process.argv[3]},
  checked_inputs: Object.keys(expected).length, original_baseline_paths: 864, additional_candidate_paths: 0,
  new_provenance_paths: 1, commands, error,
  scope: 'Fresh persisted draft audit, affected Node suites, native morphology and committed-journal evidence. No full-game, browser, human, specialist, media or module readiness claim.'};
write('receipt.json', json(result));
console.log(json({ok: result.ok, receipt_sha256: sha(Buffer.from(json(result))), commands: commands.length, error}));
process.exitCode = result.ok ? 0 : 1;
