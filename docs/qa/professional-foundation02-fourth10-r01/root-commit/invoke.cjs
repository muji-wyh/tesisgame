'use strict';
// Root owns the serialized mutation window. Dispatch only the frozen approved proposal.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(process.argv.length, 4);
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const bytes = p => fs.readFileSync(path.join(root, p));
const read = p => JSON.parse(bytes(p));
const encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const proposal = 'build/professional-english/foundation02-fourth10-commit-proposal-r01';
const reviewPath = 'build/professional-english/foundation02-fourth10-commit-review-r01/review.json';
const inventoryPath = proposal + '/author-inventory.json';
const inventoryHash = 'f0043bfeada59d497be43cde8e3d753c0322cfa982c632fa40eae36cd62838d7';
const sourceHash = sha(fs.readFileSync(__filename));
assert.equal(sourceHash, process.argv[2]);
assert.equal(sha(bytes(reviewPath)), process.argv[3]);
assert.equal(sha(bytes(inventoryPath)), inventoryHash);
const inventory = read(inventoryPath), review = read(reviewPath);
assert.equal(review.status, 'approved_for_root_guarded_commit');
assert.deepEqual(review.proposal_inventory, {path: inventoryPath, sha256: inventoryHash});
const sourceRefs = [...inventory.artifacts.map(r => ({path: proposal + '/' + r.path, sha256: r.sha256})),
  {path: inventoryPath, sha256: inventoryHash}, {path: reviewPath, sha256: process.argv[3]}];
const checkSources = () => {
  assert.equal(sha(fs.readFileSync(__filename)), sourceHash);
  for (const r of sourceRefs) assert.equal(sha(bytes(r.path)), r.sha256, r.path);
};
checkSources();
const attempt = path.join(__dirname, 'execution');
assert(!fs.existsSync(attempt), 'Never replay this root commit wrapper.');
const inputPath = 'build/professional-english/foundation02-fourth10-root-commit-r01/input.json';
assert(!fs.existsSync(path.join(root, inputPath)));
const token = crypto.randomBytes(32).toString('hex');
const manifest = read(proposal + '/root-commit-input.example.json');
manifest.root_window_token_sha256 = sha(token);
manifest.proposal_inventory = {path: inventoryPath, sha256: inventoryHash};
manifest.commit_technical_review = {path: reviewPath, sha256: process.argv[3]};
// The imported contract is read-only; a preflight failure leaves no commit attempt.
const E = require(path.join(root, proposal, 'evidence-contract.cjs'));
E.loadBundle(manifest);
checkSources();
fs.mkdirSync(attempt);
fs.writeFileSync(path.join(root, inputPath), encode(manifest), {flag: 'wx'});
const inputHash = sha(bytes(inputPath));
const write = (name, value) => fs.writeFileSync(path.join(attempt, name), Buffer.isBuffer(value) ? value : encode(value), {flag: 'wx'});
const started = new Date().toISOString();
write('start.json', {schema: 1, started_at: started, wrapper_sha256: sourceHash, source_refs: sourceRefs,
  root_input: {path: inputPath, sha256: inputHash}, raw_token_retained: false});
let outcome, failure = null;
try {
  checkSources();
  outcome = spawnSync(process.execPath, [proposal + '/commit.cjs', '--input', inputPath,
    '--input-sha256', inputHash, '--root-window-token', token],
  {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 600000, maxBuffer: 8 * 1024 * 1024});
  assert(!outcome.error, outcome.error?.message);
  assert.equal(outcome.status, 0, (outcome.stdout || '') + (outcome.stderr || ''));
  checkSources();
} catch (error) { failure = error.stack || String(error); }
const log = Buffer.from((outcome?.stdout || '') + (outcome?.stderr || ''));
write('command.log', log);
const receipt = {schema: 1, ok: failure === null, started_at: started, finished_at: new Date().toISOString(),
  wrapper_sha256: sourceHash, root_input: {path: inputPath, sha256: inputHash}, source_refs: sourceRefs,
  exit_code: outcome?.status ?? null, signal: outcome?.signal ?? null, error: failure,
  log_sha256: sha(log), raw_token_retained: false, persisted_validation_claim: false};
write('receipt.json', receipt);
console.log(JSON.stringify({ok: receipt.ok, receipt_sha256: sha(encode(receipt)), error: failure}));
process.exitCode = receipt.ok ? 0 : 1;
