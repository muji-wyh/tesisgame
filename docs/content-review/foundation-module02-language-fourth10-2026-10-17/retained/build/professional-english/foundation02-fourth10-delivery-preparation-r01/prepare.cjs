'use strict';
// Root-dispatched scratch preparation only. Authored but never executed by runtime_recovery.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {createRequire} = require('node:module');
const L = require('./projection.cjs');
const {transform, files: tests} = require('./test-transforms.cjs');
const root = path.resolve(__dirname, '../../..');
const output = path.join(__dirname, 'execution-r01');
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const sourceNames = ['input-pins.json', 'input-freeze-receipt.json', 'projection.cjs', 'test-transforms.cjs', 'prepare.cjs', 'HANDOFF.md', 'TRANSACTION.md', 'author-inventory.json'];
const save = (name, value) => fs.writeFileSync(path.join(output, name),
  Buffer.isBuffer(value) ? value : L.serialize(value), {flag: 'wx'});
assert.equal(process.argv.length, 4);
assert.equal(process.argv[2], '--root-dispatch');
assert.equal(process.argv[3], 'confirmed-by-root');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert(!fs.existsSync(output), 'This preparation revision may run only once; retain every failed attempt.');
fs.mkdirSync(output);
const sources = sourceNames.map(name => ({path: relative(path.join(__dirname, name)),
  raw_sha256: L.sha(fs.readFileSync(path.join(__dirname, name)))}));
save('execution-start.json', {schema: 1, status: 'preparation_dispatch_recorded',
  recorded_at: new Date().toISOString(), entrypoint: relative(__filename), source_files: sources,
  production_mutated: false, native_dispatched: false, historical_scripts_replayed: false});
let finalStatus = 'failed';
try {
  const {pins} = L.verifyInputs();
  const measuredPaths = pins.measurement_paths;
  assert.equal(measuredPaths.length, pins.measurement_path_count);
  const measuredInputs = Object.fromEntries(measuredPaths.map(file => [file, L.raw(file)]));
  save('measured-inputs-before.json', {schema: 1, kind: 'fresh_source_measurement_not_validation',
    pathlist_origin: pins.third10_measurement_manifest, current_sha256: measuredInputs,
    historical_result_transferred: false});
  const p = L.project();
  const api = require(L.at('tools/validate-professional-content.cjs'));
  assert.deepEqual(api.loadProfessionalContent(root), p.before);
  const beforeAudit = api.auditProfessionalContent({rootDir: root, data: p.before});
  const afterAudit = api.auditProfessionalContent({rootDir: root, data: p.next});
  assert.equal(beforeAudit.errors.length, 0);assert.equal(afterAudit.errors.length, 0);
  assert.equal(beforeAudit.summary.reviewed_lexemes, 138);assert.equal(afterAudit.summary.reviewed_lexemes, 148);
  assert.equal(beforeAudit.summary.ready_modules, 0);assert.equal(afterAudit.summary.ready_modules, 0);
  for (const key of Object.keys(beforeAudit.summary)) if (key !== 'reviewed_lexemes') assert.deepEqual(afterAudit.summary[key], beforeAudit.summary[key], key);
  for (const [field, before, after] of [['status', 138, 148], ['language', 325, 335]]) {
    assert.equal(p.before.lexemes.filter(entry => entry.review[field] === 'reviewed').length, before);
    assert.equal(p.next.lexemes.filter(entry => entry.review[field] === 'reviewed').length, after);
  }
  for (const [registry, expected] of [[p.before, 26], [p.next, 36]]) {
    assert.equal(registry.lexemes.filter(entry => registry.lexemeOrigins[entry.id] === 'res://data/professional/lexemes/foundation-module02.json' && entry.review.language === 'reviewed').length, expected);
  }
  const virtualFiles = new Map(p.proposed_files.map(row => [L.at(row.path), row.after]));
  virtualFiles.set(L.at(p.record.delivery_scope.provenance_file), L.serialize(p.record));
  const callbacksPassed = [], patches = [];
  for (const file of tests) {
    const before = L.bytes(file), transformed = transform(file, before);
    const stem = path.basename(file);
    if (!transformed.native) {
      new vm.Script(transformed.bytes.toString('utf8'), {filename: file});
      const callbacks = [], nativeRequire = createRequire(L.at(file));
      const projectedFs = new Proxy(fs, {get(target, key) {
        if (key !== 'readFileSync') return target[key];
        return (file, ...options) => {
          const fake = virtualFiles.get(path.resolve(file));
          if (!fake) return target.readFileSync(file, ...options);
          const encoding = typeof options[0] === 'string' ? options[0] : options[0]?.encoding;
          return encoding ? fake.toString(encoding) : Buffer.from(fake);
        };
      }});
      const projectedApi = {...api, loadProfessionalContent: (...args) =>
        !args[0] || path.resolve(args[0]) === root ? structuredClone(p.next) : api.loadProfessionalContent(...args)};
      const projectedRequire = name => name === 'node:test' ? ((title, ...rest) => callbacks.push({title, fn: rest.at(-1)})) :
        name === 'node:fs' ? projectedFs : name === '../tools/validate-professional-content.cjs' ? projectedApi : nativeRequire(name);
      const compile = vm.compileFunction(transformed.bytes.toString('utf8'),
        ['require', '__dirname', 'module', 'exports', '__filename'], {filename: file});
      const module = {exports: {}};
      compile(projectedRequire, path.dirname(L.at(file)), module, module.exports, L.at(file));
      assert(callbacks.length > 0);
      for (const callback of callbacks) {
        const result = callback.fn();
        assert(!result || typeof result.then !== 'function', 'Only synchronous projection callbacks are supported.');
        callbacksPassed.push({file, title: callback.title, passed: true});
      }
    }
    save(stem + '.before', before);save(stem + '.after', transformed.bytes);
    patches.push({path: file, before_sha256: L.sha(before), after_sha256: L.sha(transformed.bytes),
      before_artifact: stem + '.before', after_artifact: stem + '.after',
      exact_anchor_edits: transformed.edits, appended_tests: transformed.appended_tests,
      native: transformed.native, native_parse_and_execution_pending: transformed.native});
  }
  for (const row of p.proposed_files) {
    const stem = row.path === p.record.delivery_scope.lexeme_file ? 'foundation-module02.json' : 'sources.json';
    save(stem + '.before', row.before);save(stem + '.after', row.after);
  }
  save('accepted-language.json', p.record);
  save('test-patches.json', {schema: 1, status: 'prepared_exact_anchor_replacements', patches, production_mutated: false});
  save('projection-checks.json', {schema: 1, ok: true, production_mutated: false,
    scope: 'Current draft audit and every synchronous affected Node callback against an in-memory projection. No native, browser, full runtime, human, specialist, expression or release acceptance.',
    callbacks: callbacksPassed, before_audit: {summary: beforeAudit.summary, errors: 0, warnings: beforeAudit.warnings.length},
    after_audit: {summary: afterAudit.summary, errors: 0, warnings: afterAudit.warnings.length},
    current_persisted_node_execution: false, native_dispatched: false});
  L.verifyInputs();
  assert.deepEqual(api.loadProfessionalContent(root), p.before);
  for (const [file, expected] of Object.entries(measuredInputs)) assert.equal(L.raw(file), expected, file);
  for (const row of sources) assert.equal(L.raw(row.path), row.raw_sha256);
  const artifacts = fs.readdirSync(output).sort().map(name => ({path: relative(path.join(output, name)),
    raw_sha256: L.sha(fs.readFileSync(path.join(output, name)))}));
  save('preparation-receipt.json', {schema: 1, status: 'frozen_preparation_pending_independent_technical_review',
    source_baseline: p.record.source_baseline, source_files: sources, artifacts,
    measured_input_sha256: measuredInputs, measured_input_count: measuredPaths.length,
    projected_callback_count: callbacksPassed.length, production_mutated: false,
    native_parse_and_execution_pending: true, delivery_script_not_authored: true,
    fresh_current_validation_or_reviewed_dependency_transfer_required: true});
  finalStatus = 'prepared_pending_independent_technical_review';
  console.log(JSON.stringify({status: finalStatus, output: relative(output),
    receipt_sha256: L.sha(fs.readFileSync(path.join(output, 'preparation-receipt.json'))),
    projected_callbacks: callbacksPassed.length, production_mutated: false}));
} catch (error) {
  save('failed-attempt.json', {schema: 1, status: 'failed', recorded_at: new Date().toISOString(),
    error: error.stack || String(error), source_files: sources, production_mutated: false,
    instruction: 'Preserve this attempt and sources; any correction must use a distinct revision and execution directory.'});
  throw error;
} finally {
  save('execution-end.json', {schema: 1, status: finalStatus, recorded_at: new Date().toISOString(),
    source_files_after: sourceNames.map(name => ({path: relative(path.join(__dirname, name)),
      raw_sha256: L.sha(fs.readFileSync(path.join(__dirname, name)))})), production_mutated: false});
}
