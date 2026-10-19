'use strict';
// Root-owned projected validation. Dispatch requires concrete reviewed afterimages.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), vm = require('node:vm'), os = require('node:os');
const {createRequire} = require('node:module');
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
assert.equal(input.status, 'root_accepted_prepared_afterimages_for_projected_validation');
const attempt = path.join(__dirname, 'attempt-001');
assert(!fs.existsSync(attempt), 'Never replay a consumed candidate validation.');
fs.mkdirSync(attempt);
const save = (p, v) => fs.writeFileSync(path.join(attempt, p), encode(v), {flag: 'wx'});
save('start.json', {schema: 1, started_at: new Date().toISOString(), source_sha256: sourceHash, input_sha256: process.argv[3]});
const overlay = new Map(), directories = new Set(), actualReads = new Map(), callbacks = [], temporaryRoots = new Set();
let summary = null, failure = null, postcheckError = null;
function check() {
  assert.equal(sha(fs.readFileSync(__filename)), sourceHash);
  assert.equal(sha(fs.readFileSync(inputPath)), process.argv[3]);
  for (const ref of input.evidence_files) assert.equal(sha(raw(ref.path)), ref.sha256, ref.path);
  for (const [p, h] of Object.entries(input.expected_inputs)) assert.equal(sha(raw(p)), h, p);
  for (const p of input.must_remain_absent) assert(!fs.existsSync(path.join(root, p)), p);
}
const key = p => { assert(typeof p === 'string' || Buffer.isBuffer(p)); return path.resolve(String(p)); };
const inTemporaryRoot = p => [...temporaryRoots].some(dir => p === dir || p.startsWith(dir + path.sep));
const writable = p => { const absolute = key(p); assert(inTemporaryRoot(absolute), 'Writes are limited to test-created temporary roots: ' + absolute); return absolute; };
try {
  check();
  const prep = input.preparation_directory, receipt = read(prep + '/preparation-receipt.json');
  assert.equal(receipt.status, 'prepared_pending_independent_afterimage_review_and_root_validation');
  const artifacts = new Map(receipt.artifacts.map(r => [r.path, r]));
  for (const r of artifacts.values()) { const b = raw(prep + '/' + r.path); assert.equal(b.length, r.bytes); assert.equal(sha(b), r.raw_sha256); }
  const binding = read(input.actual_binding.path), plan = read(prep + '/target-plan.json');
  assert.equal(sha(raw(input.actual_binding.path)), input.actual_binding.sha256);
  assert.equal(plan.targets.length, input.target_count);
  assert.deepEqual(plan.targets.map(r => r.path).sort(), [...binding.target_paths].sort());
  assert.deepEqual([...input.must_remain_absent].sort(), [...binding.must_remain_absent].sort());
  for (const row of plan.targets) {
    assert(!path.isAbsolute(row.path) && !row.path.includes('\\') && !row.path.split('/').includes('..'));
    const absolute = path.resolve(root, row.path); assert(absolute.startsWith(root + path.sep));
    assert(!overlay.has(absolute)); assert(artifacts.has(row.artifact));
    const bytes = raw(prep + '/' + row.artifact); assert.equal(bytes.length, row.bytes);
    assert.equal(sha(bytes), row.after_sha256 || row.prepared_sha256);
    if (row.operation === 'replace') assert.equal(sha(raw(row.path)), row.before_sha256);
    else assert(!fs.existsSync(absolute), row.path);
    overlay.set(absolute, bytes);
    for (let dir = path.dirname(absolute); dir !== root; dir = path.dirname(dir)) { assert(dir.startsWith(root + path.sep)); directories.add(dir); }
  }
  assert.equal(plan.targets.filter(r => r.operation === 'replace').length, 6);
  function observedRead(p, ...options) {
    const absolute = key(p), virtual = overlay.get(absolute);
    const bytes = virtual ? Buffer.from(virtual) : fs.readFileSync(p);
    if (!virtual && absolute.startsWith(root + path.sep)) {
      const relative = path.relative(root, absolute).replaceAll('\\', '/');
      assert.equal(sha(bytes), input.expected_inputs[relative], 'Unpinned or changed actual input: ' + relative);
      actualReads.set(relative, sha(bytes));
    } else if (!virtual) assert(inTemporaryRoot(absolute), 'Unexpected external read: ' + absolute);
    const encoding = typeof options[0] === 'string' ? options[0] : options[0]?.encoding;
    return encoding ? bytes.toString(encoding) : bytes;
  }
  const isVirtual = p => overlay.has(p) || directories.has(p);
  const realpath = (p, options) => isVirtual(key(p)) ? (options === 'buffer' || options?.encoding === 'buffer' ? Buffer.from(key(p)) : key(p)) : fs.realpathSync(p, options);
  realpath.native = realpath;
  const virtualStat = absolute => ({size: overlay.get(absolute)?.length || 0, isFile: () => overlay.has(absolute), isDirectory: () => directories.has(absolute), isSymbolicLink: () => false});
  function readdir(p, options) {
    const absolute = key(p); if (!directories.has(absolute)) return fs.readdirSync(p, options);
    assert(!options?.recursive, 'Recursive directory enumeration is not used by these suites');
    const items = new Map();
    if (fs.existsSync(absolute)) for (const entry of fs.readdirSync(absolute, {withFileTypes: true})) items.set(entry.name, entry);
    for (const child of [...directories, ...overlay.keys()]) if (path.dirname(child) === absolute && !items.has(path.basename(child))) {
      items.set(path.basename(child), {name: path.basename(child), ...virtualStat(child)});
    }
    return [...items.values()].sort((a, b) => a.name.localeCompare(b.name)).map(entry => options?.withFileTypes ? entry : options === 'buffer' || options?.encoding === 'buffer' ? Buffer.from(entry.name) : entry.name);
  }
  // The retained Home-preview callback copies only this pinned schema tree.
  function copySchemas(from, to, options) {
    assert.equal(key(from), path.join(root, 'data/professional/schemas'));
    assert.deepEqual(options, {recursive: true});
    const destination = writable(to);
    function copy(source, target) {
      writable(target);
      const stat = fs.lstatSync(source); assert(!stat.isSymbolicLink(), 'No schema copy through symbolic links');
      if (stat.isDirectory()) {
        fs.mkdirSync(target, {recursive: true});
        for (const name of fs.readdirSync(source)) copy(path.join(source, name), path.join(target, name));
      } else { assert(stat.isFile()); fs.writeFileSync(target, observedRead(source)); }
    }
    copy(key(from), destination);
  }
  const overrides = {readFileSync: observedRead, existsSync: p => isVirtual(key(p)) || fs.existsSync(p), realpathSync: realpath, readdirSync: readdir,
    statSync: (p, ...rest) => isVirtual(key(p)) ? virtualStat(key(p)) : fs.statSync(p, ...rest),
    lstatSync: (p, ...rest) => isVirtual(key(p)) ? virtualStat(key(p)) : fs.lstatSync(p, ...rest),
    mkdtempSync: (prefix, options) => { const absolute = key(prefix); assert.equal(path.dirname(absolute), path.resolve(os.tmpdir())); assert(/^(professional-preview-test-|tesis-professional-content-)$/.test(path.basename(absolute))); const dir = fs.mkdtempSync(prefix, options); assert.equal(typeof dir, 'string'); temporaryRoots.add(path.resolve(dir)); return dir; },
    mkdirSync: (p, ...rest) => fs.mkdirSync(writable(p), ...rest), writeFileSync: (p, ...rest) => fs.writeFileSync(writable(p), ...rest),
    cpSync: copySchemas, copyFileSync: (from, to) => fs.writeFileSync(writable(to), observedRead(from)), rmSync: (p, ...rest) => fs.rmSync(writable(p), ...rest)};
  const projectedFs = new Proxy({}, {get(_target, name) { assert(Object.hasOwn(overrides, name), 'Unsupported filesystem operation: ' + String(name)); return overrides[name]; }});
  const modules = new Map(); let currentTests = null;
  function loadModule(absolute) {
    if (modules.has(absolute)) return modules.get(absolute).exports;
    const module = {exports: {}}; modules.set(absolute, module);
    const localRequire = createRequire(absolute);
    const projectedRequire = name => {
      if (name === 'node:fs') return projectedFs;
      if (name === 'node:test') { assert(currentTests); return (title, ...args) => currentTests.push({title, fn: args.at(-1)}); }
      if (name.startsWith('node:')) { assert(['node:assert/strict', 'node:path', 'node:crypto', 'node:os', 'node:util'].includes(name)); return require(name); }
      const resolved = localRequire.resolve(name); assert(resolved.startsWith(root + path.sep));
      assert(/\.(?:cjs|js)$/.test(resolved)); return loadModule(resolved);
    };
    vm.compileFunction(observedRead(absolute, 'utf8'), ['require', '__dirname', 'module', 'exports', '__filename'], {filename: absolute})(projectedRequire, path.dirname(absolute), module, module.exports, absolute);
    return module.exports;
  }
  const api = loadModule(path.join(root, 'tools/validate-professional-content.cjs')), projected = api.loadProfessionalContent(root);
  assert.equal(hash(projected), input.registry_after_sha256);
  const audited = api.auditProfessionalContent({rootDir: root, data: projected});
  assert.equal(audited.errors.length, 0, JSON.stringify(audited.errors));
  assert.deepEqual(audited.summary, input.expected_audit_summary);
  summary = {summary: audited.summary, errors: audited.errors.length, warnings: audited.warnings.length};
  for (const file of ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']) {
    currentTests = []; loadModule(path.join(root, file)); assert(currentTests.length > 0);
    assert.equal(currentTests.length, input.expected_callbacks_by_file[file]);
    for (const test of currentTests) { const outcome = test.fn(); assert(!outcome || typeof outcome.then !== 'function', 'Synchronous projected callbacks only.'); callbacks.push({file, title: test.title, passed: true}); }
  }
  assert.equal(callbacks.length, input.expected_callback_count);
  for (const dir of temporaryRoots) assert(!fs.existsSync(dir), 'Test temporary directory was not removed');
} catch (error) { failure = error.stack || String(error); }
try { check(); for (const [p, h] of actualReads) assert.equal(sha(raw(p)), h, p); } catch (error) { postcheckError = error.stack || String(error); }
const result = {schema: 1, ok: failure === null && postcheckError === null, finished_at: new Date().toISOString(), source_sha256: sourceHash,
  input_sha256: process.argv[3], audit: summary, callbacks, observed_current_inputs: Object.fromEntries(actualReads), error: failure, postcheck_error: postcheckError,
  temporary_roots: [...temporaryRoots].map(p => ({path: p, remains: fs.existsSync(p)})),
  scope: 'Scratch afterimages with actual validator and affected synchronous callbacks. All loaded local modules use the same read overlay. Only test-created temporary roots may be written. No installation, native, browser, listening or ready-module claim.'};
save('receipt.json', result); console.log(JSON.stringify({ok: result.ok, receipt_sha256: sha(encode(result)), callbacks: callbacks.length, error: failure, postcheck_error: postcheckError}));
process.exitCode = result.ok ? 0 : 1;
