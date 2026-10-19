'use strict';
// Root-only one-shot probe. All code-under-review filesystem writes are memory-only.
// No production entrypoint is dispatched through native require or a child process.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ROOT = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const OWN = 'build/professional-english/foundation02-third10-commit-review-r01';
assert.equal(process.argv.length, 8);
assert.deepEqual([process.argv[2], process.argv[4], process.argv[6]], ['--inventory-sha256', '--proposal', '--proposal-inventory-sha256']);
const PROPOSAL = process.argv[5];
const INVENTORY_HASH = process.argv[7];
assert.match(PROPOSAL, /^build\/professional-english\/foundation02-third10-commit-proposal-r\d{2,}$/);
assert.match(INVENTORY_HASH, /^[a-f0-9]{64}$/);
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const enc = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const abs = p => path.resolve(ROOT, p);
const rel = p => path.relative(ROOT, p).replaceAll('\\', '/');
const key = p => path.resolve(p).toLowerCase();
const disk = p => fs.readFileSync(abs(p));
const json = p => JSON.parse(disk(p));
const ref = p => ({path: p, sha256: sha(disk(p))});
const attempt = abs(OWN + '/execution-' + path.posix.basename(PROPOSAL));
assert.equal(path.resolve(process.cwd()).toLowerCase(), path.resolve(ROOT).toLowerCase());
assert.equal(path.resolve(__dirname).toLowerCase(), abs(OWN).toLowerCase());
assert.match(process.argv[3], /^[a-f0-9]{64}$/);
assert.equal(sha(disk(OWN + '/inventory.json')), process.argv[3]);
const reviewInventory = json(OWN + '/inventory.json');
for (const r of [...reviewInventory.files, ...reviewInventory.inputs]) assert.equal(sha(disk(r.path)), r.sha256, r.path);
assert.equal(sha(disk(PROPOSAL + '/author-inventory.json')), INVENTORY_HASH);
const proposalInventory = json(PROPOSAL + '/author-inventory.json');
const proposalRefs = [{path: PROPOSAL + '/author-inventory.json', sha256: INVENTORY_HASH}, ...proposalInventory.artifacts.map(r => ({path: PROPOSAL + '/' + r.path, sha256: r.sha256}))];
for (const r of proposalRefs) assert.equal(sha(disk(r.path)), r.sha256, r.path);
assert(!fs.existsSync(attempt), 'Never replay this probe attempt.');
fs.mkdirSync(attempt);
const output = (name, v) => fs.writeFileSync(path.join(attempt, name), enc(v), {flag: 'wx'});
const binding = json('build/professional-english/foundation02-third10-prepared-review-r01/binding.json');
const sourceRefs = [...reviewInventory.files, ...reviewInventory.inputs, ...proposalRefs];
const observedFiles = [...new Set([...Object.keys(binding.current_inputs), ...sourceRefs.map(r => r.path),
  'words.json', 'data/professional/domain-policy/decisions.json', 'data/professional/domain-policy/generated/index.json',
  'data/professional/domain-policy/generated/release.json', 'data/professional/domain-policy/generated/themes.json'])];
const absent = [PROPOSAL + '/execution-r01', 'docs/content-review/foundation-module02-language-third10-2026-10-17',
  'data/professional/provenance/foundation-module02-language-third10-2026-10-17.json',
  'build/professional-english/transactions/foundation02-third10-language-r01'];
function observation() { return {files: observedFiles.map(ref), absent: absent.map(p => ({path: p, absent: !fs.existsSync(abs(p))}))}; }
const before = observation();
assert(before.absent.every(r => r.absent), 'The live commit destinations must remain absent.');
output('start.json', {schema: 1, started_at: new Date().toISOString(), inventory: ref(OWN + '/inventory.json'), before,
  policy: 'Real writes only under this new attempt; exact reviewed modules receive an in-memory filesystem.'});

// This adapter is not a security boundary for arbitrary hostile code. Its module allowlist
// is restricted to the frozen, independently read sources. Unsupported APIs fail closed.
function memoryView() {
  const nodes = new Map(), hidden = new Set(), handles = new Map();
  const writes = []; let nextFd = 100000;
  const checked = p => { const a = path.resolve(String(p)); assert(a.toLowerCase() === path.resolve(ROOT).toLowerCase() || a.toLowerCase().startsWith(path.resolve(ROOT).toLowerCase() + path.sep)); return a; };
  const isHidden = p => [...hidden].some(h => key(p) === h || key(p).startsWith(h + path.sep));
  const err = (code, p) => Object.assign(new Error(code + ': ' + p), {code});
  const entry = p => { p = checked(p); const n = nodes.get(key(p)); if (n) return n; if (isHidden(p)) throw err('ENOENT', p); const s = fs.lstatSync(p); return {type: s.isDirectory() ? 'dir' : s.isSymbolicLink() ? 'link' : 'file', real: p, stat: s}; };
  const exists = p => { try { entry(p); return true; } catch (e) { if (e.code === 'ENOENT' || e.code === 'ENOTDIR') return false; throw e; } };
  const stat = p => { const n = entry(p); return {isDirectory: () => n.type === 'dir', isFile: () => n.type === 'file', isSymbolicLink: () => n.type === 'link', size: n.bytes?.length ?? n.stat?.size ?? 0}; };
  const read = (p, options) => { const n = entry(p); assert.equal(n.type, 'file', String(p)); const b = n.bytes ? Buffer.from(n.bytes) : fs.readFileSync(n.real); const encoding = typeof options === 'string' ? options : options?.encoding; return encoding ? b.toString(encoding) : b; };
  const dir = p => { p = checked(p); if (exists(p)) { assert(stat(p).isDirectory()); return; } dir(path.dirname(p)); nodes.set(key(p), {type: 'dir', path: p}); };
  const put = (p, b) => { p = checked(p); dir(path.dirname(p)); nodes.set(key(p), {type: 'file', path: p, bytes: Buffer.from(b)}); hidden.delete(key(p)); };
  const write = (p, b, options = {}) => { if (typeof p === 'number') { assert(handles.has(p)); p = handles.get(p); } p = checked(p); assert(stat(path.dirname(p)).isDirectory()); if (options.flag === 'wx' && exists(p)) throw err('EEXIST', p); if (exists(p)) assert(stat(p).isFile()); put(p, Buffer.isBuffer(b) ? b : Buffer.from(b)); writes.push({operation: 'write', path: rel(p)}); };
  const api = {
    existsSync: exists, lstatSync: stat, statSync: stat, readFileSync: read,
    realpathSync: p => { entry(p); return checked(p); },
    mkdirSync: (p, options) => { p = checked(p); if (options?.recursive) return dir(p); if (exists(p)) throw err('EEXIST', p); assert(stat(path.dirname(p)).isDirectory()); nodes.set(key(p), {type: 'dir', path: p}); writes.push({operation: 'mkdir', path: rel(p)}); },
    writeFileSync: write,
    openSync: (p, flags) => { assert.equal(flags, 'wx'); write(p, Buffer.alloc(0), {flag: flags}); const fd = nextFd++; handles.set(fd, checked(p)); return fd; },
    fsyncSync: fd => assert(handles.has(fd)), closeSync: fd => { assert(handles.delete(fd)); },
    unlinkSync: p => { entry(p); nodes.delete(key(p)); hidden.add(key(p)); writes.push({operation: 'unlink', path: rel(p)}); },
    renameSync: (from, to) => { const bytes = read(from); assert(stat(path.dirname(to)).isDirectory()); if (exists(to)) assert(stat(to).isFile()); put(to, bytes); nodes.delete(key(from)); hidden.add(key(from)); writes.push({operation: 'rename', path: rel(to)}); },
    readdirSync: p => { assert(stat(p).isDirectory()); const names = new Set(); if (!isHidden(p) && fs.existsSync(p)) for (const name of fs.readdirSync(p)) if (exists(path.join(p, name))) names.add(name); for (const n of nodes.values()) if (n.path && key(path.dirname(n.path)) === key(p)) names.add(path.basename(n.path)); return [...names]; }
  };
  return {fs: new Proxy(api, {get: (o, p) => { assert(Object.hasOwn(o, p), 'Unsupported filesystem API: ' + String(p)); return o[p]; }}),
    put, dir, read, writes, nodes, hide: p => { nodes.delete(key(p)); hidden.add(key(p)); },
    mutate: (p, change) => { const v = JSON.parse(read(p, 'utf8')); change(v); put(p, enc(v)); return v; }};
}

const allowedModules = new Set([...reviewInventory.module_paths, PROPOSAL + '/commit.cjs', PROPOSAL + '/evidence-contract.cjs'].map(p => key(abs(p))));
function environment() {
  const view = memoryView(), cache = new Map(), logs = [];
  const virtualProcess = {argv: [], cwd: () => ROOT, platform: process.platform, pid: process.pid,
    kill: () => { throw new Error('Process inspection is not permitted in these probes.'); }};
  function load(file) {
    file = abs(file); assert(allowedModules.has(key(file)), 'Module outside reviewed allowlist: ' + file);
    if (cache.has(key(file))) return cache.get(key(file)).exports;
    const module = {exports: {}}; cache.set(key(file), module);
    const localRequire = name => {
      if (name === 'node:fs' || name === 'fs') return view.fs;
      if (['node:path', 'node:crypto', 'node:assert/strict', 'node:util'].includes(name)) return require(name);
      assert(name.startsWith('.') || path.isAbsolute(name), 'Blocked module: ' + name);
      return load(path.resolve(path.dirname(file), name));
    };
    localRequire.main = null;
    const wrapper = vm.runInThisContext('(function(exports,require,module,__filename,__dirname,process,console){\n' + view.read(file, 'utf8') + '\n})', {filename: file});
    wrapper(module.exports, localRequire, module, file, path.dirname(file), virtualProcess, {log: (...values) => logs.push(values.join(' '))});
    return module.exports;
  }
  const E = load(PROPOSAL + '/evidence-contract.cjs');
  const manifest = json(PROPOSAL + '/root-commit-input.example.json');
  const synthetic = OWN + '/virtual-fixtures';
  const token = 'memory-only-probe-token-not-a-root-authorization';
  const probePath = synthetic + '/synthetic-probes.json', reviewPath = synthetic + '/synthetic-review.json', inputPath = synthetic + '/synthetic-input.json';
  const mref = p => ({path: p, sha256: sha(view.read(abs(p)))});
  manifest.proposal_inventory = {path: PROPOSAL + '/author-inventory.json', sha256: INVENTORY_HASH};
  manifest.candidate_copied_inputs = ref(E.C.validation + '/candidate/copied-inputs.json');
  manifest.root_window_token_sha256 = sha(token);
  view.put(abs(probePath), enc({ok: true, synthetic_memory_only: true, proposal_inventory: manifest.proposal_inventory,
    cases: E.C.guard_cases.map(name => ({name, passed: true, synthetic_memory_only: true}))}));
  const technical = {status: 'approved_for_root_guarded_commit', reviewer: 'Synthetic memory-only independent reviewer', synthetic_memory_only: true,
    proposal_inventory: manifest.proposal_inventory, prepared_binding: manifest.prepared_binding,
    reviewed_files: json(PROPOSAL + '/author-inventory.json').artifacts.map(r => ({path: PROPOSAL + '/' + r.path, sha256: r.sha256})), guard_probe_evidence: mref(probePath)};
  function sync() { view.put(abs(reviewPath), enc(technical)); manifest.commit_technical_review = mref(reviewPath); view.put(abs(inputPath), enc(manifest)); virtualProcess.argv = ['node', abs(PROPOSAL + '/commit.cjs'), '--input', inputPath, '--input-sha256', mref(inputPath).sha256, '--root-window-token', token]; }
  sync();
  return {view, E, manifest, technical, sync, load, logs, run: () => load(PROPOSAL + '/commit.cjs').main()};
}

const cases = [], measurements = {};
function test(name, fn, method) { try { const detail = fn(); cases.push({name, passed: true, method, detail: detail ?? null}); } catch (e) { cases.push({name, passed: false, method, error: e.stack || String(e)}); } }
function rejects(fn, pattern) { let caught; try { fn(); } catch (e) { caught = e; } assert(caught, 'Expected the exact guard to reject the fixture.'); if (pattern) assert.match(caught.message, pattern); return {rejection: caught.message}; }
function withChange(name, p, change, pattern) { test(name, () => { const x = environment(); x.view.mutate(abs(p), change); return rejects(() => x.E.loadBundle(x.manifest), pattern); }, 'New exact loadBundle probe with one memory-only input mutation'); }
let successful;
try {
  test('exact_before_and_after', () => {
    const x = environment(); x.run(); const reconstructed = x.E.verifyPersisted();
    assert.equal(reconstructed.ok, true);
    for (const row of binding.production_replacements) { assert.equal(sha(x.view.read(abs(row.path))), row.after_sha256); assert.equal(sha(disk(row.path)), row.before_sha256); }
    successful = x; measurements.reconstruction = reconstructed;
    measurements.virtual_operations = x.view.writes.length;
    measurements.virtual_commit_log = x.logs;
    return {five_exact_afterimages: true, memory_only_commit_and_journal: true, persisted_contract_reconstructed: true};
  }, 'New exact commit.main and helper execution entirely inside memory, then exact verifyPersisted reconstruction');
  const target = binding.production_replacements[0].path;
  const selected = data => data.lexemes.find(e => e.id === 'correct.put-right.v');
  withChange('allowed_field_drift', target, data => { selected(data).definition += ' Drift.'; });
  withChange('protected_field_drift', target, data => { selected(data).review.domain = 'unexpected'; });
  withChange('source_suffix_drift', 'data/professional/sources.json', data => { data.sources.at(-1).scope += ' Drift.'; });
  withChange('missing_identity', target, data => { data.lexemes = data.lexemes.filter(e => e.id !== 'correct.put-right.v'); });
  withChange('duplicate_identity', target, data => { data.lexemes.push(structuredClone(selected(data))); });
  test('input_drift', () => { const x = environment(); const p = Object.keys(binding.current_inputs).find(p => !x.E.C.replacements.includes(p)); x.view.put(abs(p), Buffer.concat([disk(p), Buffer.from('\n')])); return rejects(() => x.E.loadBundle(x.manifest)); }, 'New unchanged-complement raw-hash guard probe');
  test('duplicate_destination', () => { const x = environment(); return rejects(() => x.E.exactPaths(['data/x.json', 'data/X.json'], ['data/x.json', 'data/X.json']), /Duplicate normalized/); }, 'New exact normalized allowlist guard probe');
  test('overlapping_destination', () => {
    const x = environment(), helper = x.load(x.E.C.helper);
    const parent = abs(OWN + '/virtual-helper-target'), child = path.join(parent, 'child.json');
    const options = {repositoryRoot: abs('.'), transactionDir: abs(OWN + '/virtual-transactions/overlap'), allowedPaths: [parent, child], changes: [{path: parent, before: null, after: Buffer.from('parent')}, {path: child, before: null, after: Buffer.from('child')}]};
    const described = helper.describePlan(options);
    const rejection = rejects(() => helper.commitTransaction(options));
    assert(!x.view.fs.existsSync(parent)); assert(!x.view.fs.existsSync(child));
    return {...rejection, planning_accepted_absent_overlap: true, plan_sha256: described.planSha256, target_bytes_remain_absent: true};
  }, 'New actual helper overlap attempt in memory; characterize commit rejection and preserved target absence');
  test('preexisting_destination', () => {
    const results = [];
    for (const field of ['docs', 'provenance', 'transaction']) { const x = environment(); const p = abs(x.E.C[field]); if (field === 'provenance') x.view.put(p, Buffer.from('preexisting')); else x.view.dir(p); results.push({field, ...rejects(() => x.E.loadBundle(x.manifest), /Destination already exists/)}); }
    return results;
  }, 'New absent destination guards for all three production output families');
  test('missing_receipt', () => { const x = environment(); const w = json(x.manifest.validation_witness.path); x.view.hide(abs(w.baseline_receipt.path)); return rejects(() => x.E.loadBundle(x.manifest), /ENOENT/); }, 'New exact pinned receipt absence probe');
  test('forged_receipt', () => {
    const x = environment(), w = json(x.manifest.validation_witness.path), receipt = json(w.baseline_receipt.path);
    receipt.commands[0].exit_code = 9; x.view.put(abs(w.baseline_receipt.path), enc(receipt));
    const pin = rejects(() => x.E.loadBundle(x.manifest));
    const shape = rejects(() => x.E.cleanReceipt(receipt, 'baseline'));
    return {stale_hash_rejected: pin, structurally_forged_receipt_rejected: shape};
  }, 'New stale pinned hash plus exact receipt semantic guard probes');
  test('prepared_afterimage_mismatch', () => {
    const x = environment(), projection = x.load(x.E.C.prep + '/projection.cjs'), original = projection.project;
    projection.project = () => { const p = original(); p.proposed_files[0].after = Buffer.concat([p.proposed_files[0].after, Buffer.from('\n')]); return p; };
    const outcome = rejects(() => x.run(), /Recomputed afterimage mismatch/);
    assert(!x.view.fs.existsSync(abs(x.E.C.transaction))); return outcome;
  }, 'New exact commit guard with an explicitly fault-injected projection return, without changing source or prepared bytes');
  test('one_shot_attempt', () => {
    assert(successful, 'Positive memory commit must pass first.');
    const repeatedMain = rejects(() => successful.run(), /Never replay/);
    const x = environment(); x.view.dir(abs(x.E.C.own + '/execution-r01')); const preexistingAttempt = rejects(() => x.run(), /Never replay/);
    const helper = x.load(x.E.C.helper), p = abs(OWN + '/virtual-toy/value.txt'), t = abs(OWN + '/virtual-transactions/one-shot');
    x.view.put(p, Buffer.from('before'));
    const options = {repositoryRoot: abs('.'), transactionDir: t, allowedPaths: [p], changes: [{path: p, before: Buffer.from('before'), after: Buffer.from('after')}]};
    helper.commitTransaction(options); const helperReuse = rejects(() => helper.commitTransaction(options), /fresh transaction directory/);
    assert.equal(x.view.read(p, 'utf8'), 'after');
    return {repeatedMain, preexistingAttempt, helperReuse};
  }, 'New proposal-attempt and actual helper-journal reuse guards; all writes stay in memory');
  test('committed_journal_required', () => {
    assert(successful, 'Positive memory reconstruction must pass first.');
    const x = successful, p = abs(x.E.C.transaction + '/prepared.json'), saved = x.view.read(p); x.view.hide(p);
    const result = rejects(() => x.E.verifyPersisted(), /ENOENT/); x.view.put(p, saved); return result;
  }, 'New persisted reconstruction failure when the successful virtual journal is missing');
  test('missing_reviewer_rejected', () => {
    const x = environment(); delete x.technical.reviewer; x.sync(); return rejects(() => x.E.loadBundle(x.manifest));
  }, 'Diagnostic: contract should reject independent review without reviewer identity');
  test('empty_reviewer_rejected', () => {
    const x = environment(); x.technical.reviewer = ''; x.sync(); return rejects(() => x.E.loadBundle(x.manifest));
  }, 'Diagnostic: contract should reject empty independent reviewer identity');
  test('empty_source_witness_rejected', () => {
    assert(successful, 'Positive memory reconstruction must pass first.');
    const x = successful, docs = x.E.C.docs;
    x.view.mutate(abs(docs + '/execution-start.json'), v => { v.source_files = []; });
    x.view.mutate(abs(docs + '/commit-receipt.json'), v => { v.source_files_after = []; });
    x.view.mutate(abs(docs + '/postcommit-inventory.json'), v => { for (const r of v.files) r.sha256 = sha(x.view.read(abs(r.path))); });
    return rejects(() => x.E.verifyPersisted());
  }, 'Diagnostic: exact persisted contract should reject mutually empty source witness arrays even if the untrusted postinventory hashes are refreshed');
} catch (error) { cases.push({name: 'harness', passed: false, error: error.stack || String(error)}); }
const after = observation();
let unchanged = true; try { assert.deepEqual(after, before); } catch (error) { unchanged = false; cases.push({name: 'real_files_unchanged', passed: false, error: error.stack}); }
const result = {schema: 1, ok: cases.every(r => r.passed) && unchanged, status: 'root_executed_independent_memory_probe_results_not_commit_approval',
  finished_at: new Date().toISOString(), proposal_inventory: {path: PROPOSAL + '/author-inventory.json', sha256: INVENTORY_HASH},
  reviewer: 'Codex disposal_test_review independent probe author; root executes', cases, measurements,
  source: ref(OWN + '/probe.cjs'), review_inventory: ref(OWN + '/inventory.json'), real_files_unchanged: unchanged,
  real_files_compared: observedFiles.length, real_write_scope: rel(attempt), real_production_commit_invoked: false,
  synthetic_approval_fixtures: 'Memory only, deliberately sufficient to reach guard logic; no actual approval is emitted.',
  inherited_case_results: [], limits: ['In-memory filesystem semantics are a focused simulation, not native Windows filesystem or power-loss validation.', 'No shared tests, child processes, native runtime, browser, build, export, live transaction or recovery are invoked.', 'Diagnostic failures are preserved findings, never successful approval flags.'], after};
output('result.json', result);
console.log(JSON.stringify({ok: result.ok, result: rel(path.join(attempt, 'result.json')), cases: cases.map(r => ({name: r.name, passed: r.passed})), real_files_unchanged: unchanged}, null, 2));
process.exitCode = result.ok ? 0 : 1;
