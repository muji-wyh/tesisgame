'use strict';
// Root dispatches this scratch-only preparation once after final source review.
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
const manifestPath = path.join(__dirname, 'input.json');
assert.equal(sha(fs.readFileSync(manifestPath)), process.argv[3]);
const input = JSON.parse(fs.readFileSync(manifestPath));
const attempt = path.join(__dirname, 'attempt-001');
assert(!fs.existsSync(attempt), 'Never replay this attempt, including a preflight failure.');
fs.mkdirSync(attempt);
const save = (name, value) => fs.writeFileSync(path.join(attempt, name), Buffer.isBuffer(value) ? value : encode(value), {flag: 'wx'});
const started = new Date().toISOString(), commands = [];
save('start.json', {schema: 1, started_at: started, source_sha256: sourceHash, input_sha256: process.argv[3]});
const absolute = p => {
  assert.equal(typeof p, 'string');
  assert(!path.isAbsolute(p) && !p.includes('\\') && !p.split('/').includes('..'));
  const result = path.resolve(root, p);
  assert(result.startsWith(root + path.sep));
  return result;
};
function check() {
  assert.equal(sha(fs.readFileSync(__filename)), sourceHash);
  assert.equal(sha(fs.readFileSync(manifestPath)), process.argv[3]);
  assert.equal(input.status, 'root_accepted_final_preparation_sources');
  assert(Array.isArray(input.source_files) && input.source_files.length >= 7);
  assert.equal(new Set(input.source_files.map(r => r.path)).size, input.source_files.length);
  for (const r of input.source_files) assert.equal(sha(fs.readFileSync(absolute(r.path))), r.sha256, r.path);
  for (const r of [input.independent_review, input.actual_binding]) assert.equal(sha(fs.readFileSync(absolute(r.path))), r.sha256, r.path);
  const binding = JSON.parse(fs.readFileSync(absolute(input.actual_binding.path)));
  assert.equal(binding.status, 'root_confirmed_actual_fourth10_persisted_baseline');
  assert(binding.fourth10.actual_commit_confirmed && binding.fourth10.actual_persisted_validation_confirmed);
  for (const r of binding.input_files) {
    const bytes = fs.readFileSync(absolute(r.path));
    assert.equal(bytes.length, r.bytes, r.path);
    assert.equal(sha(bytes), r.raw_sha256, r.path);
  }
}
let failure = null;
try {
  check();
  const prep = 'build/professional-english/shopping-bag-delivery-preparation-r02';
  assert(!fs.existsSync(absolute(prep + '/execution-r01')));
  const calls = [['--check', prep + '/test-transforms.cjs'], ['--check', prep + '/prepare.cjs'],
    [prep + '/prepare.cjs', '--root-dispatch', 'confirmed-actual-fourth10-persisted']];
  for (const args of calls) {
    check();
    const began = new Date().toISOString();
    const result = spawnSync(process.execPath, args, {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 600000, maxBuffer: 8 * 1024 * 1024});
    const log = Buffer.from((result.stdout || '') + (result.stderr || ''));
    const name = 'command-' + (commands.length + 1) + '.log';
    save(name, log);
    commands.push({args, started_at: began, finished_at: new Date().toISOString(), exit_code: result.status,
      signal: result.signal, error: result.error?.message || null, log: name, log_sha256: sha(log)});
    assert(!result.error, result.error?.message);
    assert.equal(result.status, 0, log.toString('utf8'));
    check();
  }
} catch (error) { failure = error.stack || String(error); }
const receipt = {schema: 1, ok: failure === null, started_at: started, finished_at: new Date().toISOString(),
  source_sha256: sourceHash, input_sha256: process.argv[3], commands, error: failure,
  scope: 'Syntax checks and scratch afterimage preparation only. No production mutation, project test, native or browser dispatch.'};
save('receipt.json', receipt);
console.log(JSON.stringify({ok: receipt.ok, receipt_sha256: sha(encode(receipt)), commands: commands.length, error: failure}));
process.exitCode = receipt.ok ? 0 : 1;
