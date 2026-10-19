'use strict';
// Root-only fresh scratch validation; the overlay never writes production files.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), vm = require('node:vm'), {createRequire} = require('node:module');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(process.argv.length, 4);
const sha = b => crypto.createHash('sha256').update(b).digest('hex'), hash = v => sha(JSON.stringify(v));
const encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const raw = p => fs.readFileSync(path.join(root, p)), read = p => JSON.parse(raw(p));
const sourceHash = sha(fs.readFileSync(__filename));
assert.equal(sourceHash, process.argv[2]);
const inputPath = path.join(__dirname, 'input.json');
assert.equal(sha(fs.readFileSync(inputPath)), process.argv[3]);
const input = JSON.parse(fs.readFileSync(inputPath));
const attempt = path.join(__dirname, 'attempt-001');
assert(!fs.existsSync(attempt), 'Never replay a consumed candidate validation.');
fs.mkdirSync(attempt);
const save = (p, v) => fs.writeFileSync(path.join(attempt, p), encode(v), {flag: 'wx'});
save('start.json', {schema: 1, started_at: new Date().toISOString(), source_sha256: sourceHash, input_sha256: process.argv[3]});
const overlay = new Map(), actualReads = new Map(), callbacks = [];
let summary = null, failure = null;
function check() {
  assert.equal(sha(fs.readFileSync(__filename)), sourceHash);
  assert.equal(sha(fs.readFileSync(inputPath)), process.argv[3]);
  for (const ref of input.evidence_files) assert.equal(sha(raw(ref.path)), ref.sha256, ref.path);
  for (const [p, h] of Object.entries(input.expected_inputs)) assert.equal(sha(raw(p)), h, p);
}
try {
  assert.equal(input.status, 'root_accepted_prepared_afterimages_for_projected_validation');
  check();
  const prep = input.preparation_directory;
  const receipt = read(prep + '/preparation-receipt.json');
  const artifacts = new Map(receipt.artifacts.map(r => [r.file, r]));
  for (const r of artifacts.values()) { assert.equal(raw(prep + '/' + r.file).length, r.bytes); assert.equal(sha(raw(prep + '/' + r.file)), r.raw_sha256); }
  const plan = read(prep + '/target-plan.json');
  assert.equal(plan.targets.length, 34);
  for (const row of plan.targets) {
    assert(!path.isAbsolute(row.path) && !row.path.includes('\\') && !row.path.split('/').includes('..'));
    const absolute = path.resolve(root, row.path);
    assert(absolute.startsWith(root + path.sep));
    assert(!overlay.has(absolute));
    assert(artifacts.has(row.artifact));
    const bytes = raw(prep + '/' + row.artifact);
    if (row.after_sha256) assert.equal(sha(bytes), row.after_sha256);
    if (row.operation === 'replace') assert.equal(sha(raw(row.path)), row.before_sha256);
    else assert(!fs.existsSync(absolute), row.path);
    overlay.set(absolute, bytes);
  }
  assert.equal(plan.targets.filter(r => r.operation === 'replace').length, 4);
  const key = p => typeof p === 'string' || Buffer.isBuffer(p) ? path.resolve(String(p)) : null;
  const observedRead = (p, ...options) => {
    const absolute = key(p), virtual = overlay.get(absolute);
    if (virtual) {
      const encoding = typeof options[0] === 'string' ? options[0] : options[0]?.encoding;
      return encoding ? virtual.toString(encoding) : Buffer.from(virtual);
    }
    const bytes = fs.readFileSync(p);
    if (absolute?.startsWith(root + path.sep)) {
      const relative = path.relative(root, absolute).replaceAll('\\', '/');
      assert.equal(sha(bytes), input.expected_inputs[relative], 'Unpinned or changed actual input: ' + relative);
      actualReads.set(relative, sha(bytes));
    }
    const encoding = typeof options[0] === 'string' ? options[0] : options[0]?.encoding;
    return encoding ? bytes.toString(encoding) : bytes;
  };
  const realpath = (p, options) => overlay.has(key(p)) ? (options === 'buffer' || options?.encoding === 'buffer' ? Buffer.from(key(p)) : key(p)) : fs.realpathSync(p, options);
  realpath.native = realpath;
  const virtualStat = bytes => ({size: bytes.length, isFile: () => true, isDirectory: () => false, isSymbolicLink: () => false});
  const projectedFs = new Proxy(fs, {get(target, name) {
    if (name === 'readFileSync') return observedRead;
    if (name === 'existsSync') return p => overlay.has(key(p)) || fs.existsSync(p);
    if (name === 'realpathSync') return realpath;
    if (name === 'statSync' || name === 'lstatSync') return (p, ...rest) => overlay.has(key(p)) ? virtualStat(overlay.get(key(p))) : fs[name](p, ...rest);
    return target[name];
  }});
  const validatorPath = path.join(root, 'tools/validate-professional-content.cjs');
  const module = {exports: {}}, nativeValidatorRequire = createRequire(validatorPath);
  vm.compileFunction(observedRead(validatorPath, 'utf8'), ['require', '__dirname', 'module', 'exports', '__filename'], {filename: validatorPath})(
    name => name === 'node:fs' ? projectedFs : nativeValidatorRequire(name), path.dirname(validatorPath), module, module.exports, validatorPath);
  const api = module.exports, projected = api.loadProfessionalContent(root);
  assert.equal(hash(projected), input.registry_after_sha256);
  const audited = api.auditProfessionalContent({rootDir: root, data: projected});
  assert.equal(audited.errors.length, 0, JSON.stringify(audited.errors));
  assert.equal(audited.summary.integrated_word_images, 9);
  assert.equal(audited.summary.integrated_word_audio, 12);
  assert.equal(audited.summary.reviewed_lexemes, 148);
  assert.equal(audited.summary.ready_modules, 0);
  summary = {summary: audited.summary, errors: audited.errors.length, warnings: audited.warnings.length};
  for (const file of ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']) {
    const absolute = path.join(root, file), pending = [], nativeRequire = createRequire(absolute), testModule = {exports: {}};
    const requireProjected = name => name === 'node:fs' ? projectedFs : name === 'node:test' ? ((title, ...args) => pending.push({title, fn: args.at(-1)})) :
      name === '../tools/validate-professional-content.cjs' ? api : nativeRequire(name);
    vm.compileFunction(observedRead(absolute, 'utf8'), ['require', '__dirname', 'module', 'exports', '__filename'], {filename: absolute})(requireProjected,
      path.dirname(absolute), testModule, testModule.exports, absolute);
    assert(pending.length > 0);
    for (const test of pending) {
      const outcome = test.fn();
      assert(!outcome || typeof outcome.then !== 'function', 'Synchronous projected callbacks only.');
      callbacks.push({file, title: test.title, passed: true});
    }
  }
  check();
  for (const [p, h] of actualReads) assert.equal(sha(raw(p)), h, p);
} catch (error) { failure = error.stack || String(error); }
const result = {schema: 1, ok: failure === null, finished_at: new Date().toISOString(), source_sha256: sourceHash,
  input_sha256: process.argv[3], audit: summary, callbacks, observed_current_inputs: Object.fromEntries(actualReads), error: failure,
  scope: 'Scratch prepared afterimages with the actual validator and synchronous affected test callbacks. Filesystem visibility is overlaid for new bytes. No installation, native, browser, listening or ready-module claim.'};
save('receipt.json', result);
console.log(JSON.stringify({ok: result.ok, receipt_sha256: sha(encode(result)), callbacks: callbacks.length, error: failure}));
process.exitCode = result.ok ? 0 : 1;
