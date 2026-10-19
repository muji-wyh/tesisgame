'use strict';
// Root-only fresh verification of actual installed shopping-bag bytes.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(path.resolve(process.cwd()), root);
assert.equal(process.argv.length, 4);
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const sourceHash = sha(fs.readFileSync(__filename));
assert.equal(sourceHash, process.argv[2]);
const inputPath = path.join(__dirname, 'input.json');
assert.equal(sha(fs.readFileSync(inputPath)), process.argv[3]);
const input = JSON.parse(fs.readFileSync(inputPath));
const attempt = path.join(__dirname, 'attempt-001');
assert(!fs.existsSync(attempt), 'Never replay a consumed persisted verification.');
fs.mkdirSync(attempt);
const save = (name, value) => fs.writeFileSync(path.join(attempt, name), Buffer.isBuffer(value) ? value : encode(value), {flag: 'wx'});
const started = new Date().toISOString(), commands = [];
save('start.json', {schema: 1, started_at: started, source_sha256: sourceHash, input_sha256: process.argv[3]});
function absolute(p) {
  assert.equal(typeof p, 'string');
  assert(!path.isAbsolute(p) && !p.includes('\\') && !p.split('/').includes('..'));
  const result = path.resolve(root, p);
  assert(result.startsWith(root + path.sep));
  return result;
}
const read = p => JSON.parse(fs.readFileSync(absolute(p)));
function check() {
  assert.equal(sha(fs.readFileSync(__filename)), sourceHash);
  assert.equal(sha(fs.readFileSync(inputPath)), process.argv[3]);
  assert.equal(input.status, 'root_confirmed_actual_bag_commit_for_persisted_validation');
  assert(Object.keys(input.expected_inputs).length >= 5120);
  for (const [p, h] of Object.entries(input.expected_inputs)) assert.equal(sha(fs.readFileSync(absolute(p))), h, p);
  for (const r of input.evidence_files) assert.equal(sha(fs.readFileSync(absolute(r.path))), r.sha256, r.path);
  assert.equal(sha(fs.readFileSync(absolute(input.committed_journal.path))), input.committed_journal.sha256);
  const journal = read(input.committed_journal.path);
  assert.equal(journal.status, 'committed');
  assert.equal(journal.targets.length, input.target_count);
  for (const r of journal.targets) {
    const b = fs.readFileSync(absolute(r.path));
    assert.equal(b.length, r.bytes, r.path);
    assert.equal(sha(b), r.sha256, r.path);
  }
  assert.equal(sha(fs.readFileSync(absolute(input.commit_receipt.path))), input.commit_receipt.sha256);
  assert.equal(read(input.commit_receipt.path).status, 'committed');
  const states = fs.readdirSync(path.dirname(absolute(input.committed_journal.path))).filter(n => /^\d+-.*\.json$/.test(n)).sort();
  assert.equal(states.at(-1), path.basename(input.committed_journal.path));
}
let failure = null, audit = null, tests = null;
try {
  check();
  const calls = [['tools/validate-professional-content.cjs', '--json'], ['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']];
  for (const args of calls) {
    check();
    const began = new Date().toISOString();
    const result = spawnSync(process.execPath, args, {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 600000, maxBuffer: 64 * 1024 * 1024});
    const log = Buffer.from((result.stdout || '') + (result.stderr || ''));
    const name = 'command-' + (commands.length + 1) + '.log';
    save(name, log);
    commands.push({args, started_at: began, finished_at: new Date().toISOString(), exit_code: result.status, signal: result.signal,
      error: result.error?.message || null, log: name, log_sha256: sha(log)});
    assert(!result.error, result.error?.message);
    assert.equal(result.status, 0, 'See ' + name);
    if (commands.length === 1) {
      const value = JSON.parse(result.stdout);
      assert.equal(value.ok, true); assert.equal(value.errors.length, 0);
      for (const [k, v] of Object.entries(input.expected_audit_summary)) assert.equal(value.summary[k], v, k);
      audit = {summary: value.summary, errors: value.errors.length, warnings: value.warnings.length};
    } else {
      const number = label => { const matches = [...result.stdout.matchAll(new RegExp('^(?:#|ℹ) ' + label + ' (\\d+)\\r?$', 'gm'))]; assert.equal(matches.length, 1, 'Missing or ambiguous Node test summary: ' + label); return Number(matches[0][1]); };
      tests = {tests: number('tests'), pass: number('pass'), fail: number('fail'), cancelled: number('cancelled'), skipped: number('skipped')};
      assert.equal(tests.tests, input.expected_tests); assert.equal(tests.pass, input.expected_tests);
      assert.equal(tests.fail, 0); assert.equal(tests.cancelled, 0); assert.equal(tests.skipped, 0);
    }
    check();
  }
} catch (error) { failure = error.stack || String(error); }
let postcheckError = null;
try { check(); } catch (error) { postcheckError = error.stack || String(error); }
const receipt = {schema: 1, ok: failure === null && postcheckError === null, started_at: started, finished_at: new Date().toISOString(),
  source_sha256: sourceHash, input_sha256: process.argv[3], commands, audit, tests, error: failure, postcheck_error: postcheckError,
  scope: 'Fresh actual persisted audit and affected Node suites, committed journal targets and protected input hashes. No native/browser/listening/release claim.'};
save('receipt.json', receipt);
console.log(JSON.stringify({ok: receipt.ok, receipt_sha256: sha(encode(receipt)), commands: commands.length, audit: audit?.summary, tests, error: failure, postcheck_error: postcheckError}));
process.exitCode = receipt.ok ? 0 : 1;
