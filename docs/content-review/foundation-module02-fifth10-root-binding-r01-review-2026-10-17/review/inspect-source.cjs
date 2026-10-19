'use strict';
// Independent raw source/JSON/hash inspection. Never import or run the reviewed helper.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const own = 'build/professional-english/foundation02-fifth10-root-binding-independent-review-r01';
const source = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r01';
const prep = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const output = path.join(root, own, 'inspection-r01');
assert(!fs.existsSync(output), 'Never replay a consumed independent inspection.');
fs.mkdirSync(output);
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const inputs = new Map(), checks = [], fragments = [];
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
function save(name, value) { fs.writeFileSync(path.join(output, name), encode(value), {flag: 'wx'}); }
function at(relative) {
  assert.equal(typeof relative, 'string');
  assert(!path.isAbsolute(relative) && !relative.includes('\\'));
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return result;
}
function raw(relative) {
  const bytes = fs.readFileSync(at(relative));
  const pin = {path: relative, bytes: bytes.length, raw_sha256: sha(bytes)};
  if (inputs.has(relative)) assert.deepEqual(inputs.get(relative), pin, 'Input changed: ' + relative);
  else inputs.set(relative, pin);
  return bytes;
}
function json(relative) { return JSON.parse(raw(relative)); }
function text(relative) { return raw(relative).toString('utf8').replaceAll('\r\n', '\n'); }
function check(label, value) { checks.push({label, passed: Boolean(value)}); }
function equal(label, left, right) { let same = true; try { assert.deepEqual(left, right); } catch { same = false; } check(label, same); }
function pin(row, prefix = '') {
  const bytes = raw(prefix + row.path);
  check('Raw pinned bytes: ' + prefix + row.path, bytes.length === row.bytes && sha(bytes) === (row.raw_sha256 || row.sha256));
}
function section(value, first, last) {
  const start = value.indexOf(first), end = value.indexOf(last, start + first.length);
  assert(start >= 0 && end > start, 'Missing raw text boundary');
  return value.slice(start, end).trim();
}
function compareFragment(label, actual, expected) {
  equal(label, actual, expected);
  fragments.push({label, actual_text_sha256: sha(actual), expected_text_sha256: sha(expected), same: actual === expected, method: 'Raw source text correspondence only; no JavaScript parsing, import, eval or execution'});
}
save('start.json', {schema: 1, started_at: new Date().toISOString(), method: 'Independent raw-source, JSON and SHA256 inspection only', helper_or_project_execution: false, actual_binding_created: false});
try {
  equal('Exact frozen helper inventory', sha(raw(source + '/source-inventory.json')), '706a57585e1d96755755ac6c081b1623ac19bd55a0d83cb7f4742ae963797c9a');
  const inventory = json(source + '/source-inventory.json');
  equal('Seven frozen helper members', inventory.files.length, 7);
  for (const row of inventory.files) pin(row, source + '/');
  equal('Exact frozen helper source', sha(raw(source + '/capture.cjs')), '884dee02200c7216fe1ed0d4b498c3b39fba005c83c511b27ba6de55a460493a');
  const helper = text(source + '/capture.cjs');
  const originalBinding = text(prep + '/binding.cjs'), originalProjection = text(prep + '/projection.cjs');
  const originalInventory = json(prep + '/source-inventory.json');
  for (const row of originalInventory.files) pin(row, prep + '/');
  compareFragment('Predecessor functions are exact frozen-r03 source text', section(helper, 'function at(relative)', 'function one(rows, id)'), section(originalBinding, 'function at(relative)', 'function openSession(inputPath, inputHash)'));
  const expectedRegistry = section(originalProjection, 'function one(rows, id)', 'function project(ctx)').replaceAll('  B.assertSession(ctx);\n', '').replaceAll('B.hash(', 'hash(');
  compareFragment('Registry/count/context functions differ only in local hash and removed session guard', section(helper, 'function one(rows, id)', 'function inspectAndProject(ctx)'), expectedRegistry);
  const originalProject = section(originalProjection, 'function project(ctx)', '  const originals=');
  const expectedProject = (originalProject.replace('function project(ctx)', 'function inspectAndProject(ctx)')
    .replace('  B.assertSession(ctx);\n', '')
    .replace('  assert.equal(B.hash(before),ctx.binding.registry_before_sha256);\n', '')
    .replace('  assert.deepEqual(measured,ctx.binding.counts);assert.equal(B.hash(next),ctx.binding.registry_after_sha256);\n', '')
    .replaceAll('B.own+', 'prep+').replaceAll('B.hash(', 'hash(').replaceAll('B.sha(', 'sha(')
    + '\n  return {before,next,measured,delta,requiredImmutableSources};\n}').trim();
  compareFragment('Accepted projection prefix has only documented substitutions and measured return', section(helper, 'function inspectAndProject(ctx)', 'function main()'), expectedProject);
  const imports = [...helper.matchAll(/require\(([^)]*)\)/g)].map(match => match[1]);
  equal('Only four built-in literal imports', imports, ["'node:fs'", "'node:path'", "'node:crypto'", "'node:assert/strict'"]);
  check('No dynamic source evaluation or process dispatch calls', !/\b(?:eval|Function|spawn|spawnSync|exec|execSync|import)\s*\(/.test(helper));
  equal('One actual mkdir call', [...helper.matchAll(/fs\.mkdirSync\(/g)].length, 1);
  equal('One actual writeFile call confined to save', [...helper.matchAll(/fs\.writeFileSync\(/g)].length, 1);
  const anchors = [
    ["assert.equal(config.output, own + '/execution-r01');", 'Fixed output directory'],
    ["assert.equal(config.execute_project_or_preparation_code, false);", 'No project/preparation dispatch permission'],
    ["assert.equal(config.root_confirms_actual_bag_persisted_success, true);", 'Root persisted-success attestation'],
    ["assert.deepEqual(config.guards, {production_writers_yielded: true, complete_inputs_frozen: true, final_destinations_reviewed: true});", 'Three concrete root guards'],
    ["assert(!configPath.startsWith(config.output + '/'),", 'Root input predates output'],
    ["assert(!fs.existsSync(at(config.output)),", 'Single-use output'],
    ["if (pins.has(pin.path)) assert.deepEqual(pins.get(pin.path), pin, 'Conflicting input pin');", 'No silent pin refresh'],
    ["if (casePaths.has(lower)) assert.equal(casePaths.get(lower), pin.path", 'Reject case-ambiguous inputs'],
    ["assert(pins.has(relative), 'Unpinned read: ' + relative)", 'Every actual read pinned'],
    ["assert.equal(helperReview.status, 'accepted_for_one_root_owned_fifth10_binding_capture');", 'Separate helper acceptance status'],
    ["independentReviewer(helperReview.reviewer);", 'Named independent helper reviewer'],
    ["assert.deepEqual(helperReview.source_inventory, config.helper_source_inventory);", 'Complete reviewed inventory pin'],
    ["assert.equal(helperReview.actual_binding_accepted, false);", 'Helper review does not approve binding'],
    ["assert.equal(helperReview.preparation_execution_accepted, false);", 'Helper review does not approve preparation'],
    ["assert.equal(sourceReview.actual_binding, null);", 'Preserve prior review unbound status'],
    ["assert.equal(sourceReview.preparation_execution_accepted, false);", 'Preserve prior review no preparation acceptance'],
    ["for (const [relative, expected] of Object.entries(bagInput.expected_inputs)) addPath(relative, expected);", 'Inherit every sealed bag input'],
    ["assert.equal(bagInput.expected_inputs[pin.path], pin.sha256", 'Inherited evidence agrees with complete closure'],
    ["for (const relative of supplement.explicit_runtime_dependencies) assert(pins.has(relative), relative);", 'Explicit runtime dependency coverage'],
    ["addPath(originalBagPersisted, config.bag_persisted_receipt.raw_sha256, true);", 'Actual original receipt always retained'],
    ["assert.equal(pins.get(originalBagPersisted).bytes, config.bag_persisted_receipt.bytes);", 'Selected persisted copy matches actual length/hash'],
    ["addPath(path.posix.dirname(originalBagPersisted) + '/' + command.log, command.log_sha256, true);", 'Actual original persisted logs pinned'],
    ["addPath(path.posix.dirname(persistedPin.path) + '/' + command.log, command.log_sha256, true);", 'Selected persisted logs pinned'],
    ["assert.equal(bagCommit.registry_before_sha256, fourthCommit.registry_after_sha256);", 'Fourth-ten/bag registry succession'],
    ["assert.equal(hash(projection.before), bagCommit.registry_after_sha256);", 'Observed baseline must be delivered bag registry'],
    ["assert.equal(projection.measured.before.reviewed_status, 148", 'Frozen transform count anchor'],
    ["for (const relative of replacements) assert(pins.has(relative), relative);", 'All six replacement preimages pinned'],
    ["target: durable + '/retained/' + String(index).padStart(4, '0') + '-' + path.posix.basename(source)", 'Deterministic shallow retained mapping'],
    ["assert.equal(new Set(targetPaths.map(value => value.toLowerCase())).size, targetPaths.length", 'Unique exact target set'],
    ["for (const relative of absent) assert(!fs.existsSync(at(relative))", 'Complete absent additions checked'],
    ["for (const pin of binding.input_files) verifyPin(pin);", 'Complete final input recheck'],
    ["for (const [kind, value] of Object.entries(predecessors)) successfulPredecessor(kind, value, read);", 'Actual predecessor recheck'],
    ["fs.writeFileSync(at(relative), bytes, {flag: 'wx'});", 'Exclusive new output writes'],
    ["save('failed-attempt.json'", 'Consumed failure is retained']
  ];
  for (const [literal, label] of anchors) check('Source gate: ' + label, helper.includes(literal));
  check('All gates precede output mkdir', helper.lastIndexOf('  recheck();', helper.indexOf('fs.mkdirSync(at(config.output))')) >= 0 && helper.indexOf('fs.mkdirSync(at(config.output))') > helper.indexOf('const binding ='));
  const supplement = json(source + '/closure-supplement.json');
  equal('141 supplemental pins', supplement.input_files.length, 141);
  equal('All 141 supplemental sources retained', [...supplement.required_retained_sources].sort(), supplement.input_files.map(row => row.path).sort());
  equal('Eleven complete inventory roots', supplement.inventory_roots.length, 11);
  equal('961 explicit runtime dependency paths', supplement.explicit_runtime_dependencies.length, 961);
  const available = new Map(), supplementMembers = new Set();
  for (const row of supplement.input_files) { pin(row); available.set(row.path, row.raw_sha256); supplementMembers.add(row.path); }
  let inventoriedMembers = 0;
  for (const rootPin of supplement.inventory_roots) {
    pin(rootPin); const packet = json(rootPin.path);
    const rows = packet.files || packet.artifacts;
    check('Inventory schema has nonempty member list: ' + rootPin.path, Array.isArray(rows) && rows.length > 0);
    for (const row of rows) {
      const relative = path.posix.dirname(rootPin.path) + '/' + row.path;
      pin({...row, path: relative});
      check('Inventoried member covered by explicit supplement: ' + relative, supplementMembers.has(relative));
      inventoriedMembers++;
    }
  }
  for (const name of ['preparation_source_inventory', 'preparation_source_review', 'bag_persisted_input', 'bag_persisted_source', 'fourth10_commit', 'fourth10_persisted', 'bag_commit']) pin(supplement[name]);
  const bagInput = json(supplement.bag_persisted_input.path);
  equal('Sealed bag input identity', sha(raw(supplement.bag_persisted_input.path)), 'a31cd76e3f21b19fc727a5ce735bac6c3d20c9de8a71fe80b70b587c1907b70f');
  equal('Complete inherited bag input count', Object.keys(bagInput.expected_inputs).length, 11740);
  equal('Case-unique inherited bag input count', new Set(Object.keys(bagInput.expected_inputs).map(value => value.toLowerCase())).size, 11740);
  equal('Complete inherited bag evidence count', bagInput.evidence_files.length, 579);
  equal('Case-unique inherited bag evidence count', new Set(bagInput.evidence_files.map(row => row.path.toLowerCase())).size, 579);
  for (const [relative, hash] of Object.entries(bagInput.expected_inputs)) {
    if (available.has(relative)) equal('Supplement/inherited hash agreement: ' + relative, available.get(relative), hash);
    available.set(relative, hash);
  }
  for (const row of bagInput.evidence_files) equal('Every inherited evidence pin belongs to input union: ' + row.path, bagInput.expected_inputs[row.path], row.sha256);
  for (const relative of supplement.explicit_runtime_dependencies) check('Explicit dependency is in inherited/supplement union: ' + relative, available.has(relative));
  const bagCommit = json(supplement.bag_commit.path);
  equal('Actual bag persisted input selects exact helper commit path/hash', bagInput.commit_receipt, {path: supplement.bag_commit.path, sha256: supplement.bag_commit.raw_sha256});
  equal('Actual bag state link', bagInput.committed_journal, {path: bagCommit.state.path, sha256: bagCommit.state.sha256});
  equal('Actual bag complete target count', bagInput.target_count, bagCommit.target_manifest.length);
  equal('Actual bag expected callbacks', bagInput.expected_tests, 255);
  for (const row of bagCommit.target_manifest) equal('Inherited input pins each actual bag target: ' + row.path, bagInput.expected_inputs[row.path], row.after.sha256);
  const fourthPersisted = json(supplement.fourth10_persisted.path);
  equal('Fourth-ten persisted selects exact helper commit path/hash', fourthPersisted.committed_receipt, {path: supplement.fourth10_commit.path, sha256: supplement.fourth10_commit.raw_sha256});
  const review = json(supplement.preparation_source_review.path);
  check('Frozen r03 review keeps actual binding and execution pending', review.status === 'source_accepted_pending_actual_binding_and_root_guard_validation' && review.actual_binding === null && review.preparation_execution_accepted === false && review.projected_afterimages_accepted === false);
  const guards = json(source + '/guard-cases.json'), template = json(source + '/root-capture-input.template.json');
  equal('Twenty-four unexecuted guard specifications', guards.cases.length, 24);
  check('All guard specifications remain unexecuted', guards.cases.every(row => row.executed === false) && guards.helper_or_guard_execution_performed === false);
  check('Root template is unusable and unbound', template.status === 'UNBOUND_DO_NOT_EXECUTE' && template.root_confirms_actual_bag_persisted_success === false && template.helper_source_inventory === null && template.bag_persisted_receipt === null);
  check('No actual registry/persisted success selected by supplement', supplement.actual_bag_persisted_receipt === null && supplement.actual_registry_binding === null);
  for (const row of inputs.values()) {
    const bytes = fs.readFileSync(at(row.path));
    assert.equal(bytes.length, row.bytes, 'Input changed: ' + row.path);
    assert.equal(sha(bytes), row.raw_sha256, 'Input changed: ' + row.path);
  }
  const failed = checks.filter(row => !row.passed);
  save('inspection.json', {schema: 1, status: failed.length ? 'static_comparisons_have_findings' : 'static_comparisons_passed_source_only', checks_passed: checks.length - failed.length, checks_failed: failed.length, checks, copied_source_fragments: fragments, inventoried_members_checked: inventoriedMembers, literal_source_gates: anchors.length, inherited_bag_inputs: 11740, inherited_evidence_pins: 579, explicit_runtime_paths: 961, inherited_actual_file_bytes_rehashed: false, measured_raw_inputs: inputs.size, all_measured_raw_inputs_rehashed_unchanged: true, actual_bag_persisted_success_selected: false, actual_binding_created: false, helper_or_project_or_guard_execution: false, production_mutated: false});
  save('inputs.json', {schema: 1, files: [...inputs.values()], all_rehashed_unchanged: true});
  console.log(JSON.stringify({checks_passed: checks.length - failed.length, checks_failed: failed.length, measured_inputs: inputs.size, inventoried_members: inventoriedMembers, fragments, failed}));
} catch (error) {
  save('failure.json', {schema: 1, error: error.stack || String(error), partial_checks: checks, inputs: [...inputs.values()], replay_allowed: false});
  throw error;
}
