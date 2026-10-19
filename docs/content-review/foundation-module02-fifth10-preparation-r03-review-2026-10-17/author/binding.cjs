'use strict';
// Authored, undispatched r03. Actual predecessor evidence and independent roles open a session.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const own = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const AUTHOR = '/root/recover_delivery';
const INHERITED_AUTHOR = '/root/runtime_recovery';
const DISPATCHER = '/root';
const sessions = new WeakSet();
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hash = value => sha(JSON.stringify(value));
const serialize = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
function at(relative) {
  assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
  assert.equal(typeof relative, 'string');
  assert(relative.length && !relative.includes('\\') && !path.isAbsolute(relative));
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return result;
}
function verifyPin(pin) {
  assert(pin && /^[a-f0-9]{64}$/.test(pin.raw_sha256));
  assert(Number.isSafeInteger(pin.bytes) && pin.bytes >= 0);
  const bytes = fs.readFileSync(at(pin.path));
  assert.equal(bytes.length, pin.bytes, pin.path);
  assert.equal(sha(bytes), pin.raw_sha256, pin.path);
  return bytes;
}
function shaValue(value, label) {assert.equal(typeof value, 'string', label);assert.match(value, /^[a-f0-9]{64}$/, label);}
function readPin(pin, read) {const bytes = read(pin.path);assert.deepEqual(bytes, verifyPin(pin));return bytes;}
function receiptRelative(value) {
  assert.equal(typeof value, 'string');
  const relative = path.isAbsolute(value) ? path.relative(root, value).replaceAll('\\', '/') : value;
  at(relative);return relative;
}
function independentReviewer(value) {
  assert.equal(typeof value, 'string', 'Named independent reviewer required');
  assert(value.length > 0 && value === value.trim(), 'Nonempty exact reviewer identity required');
  assert.match(value, /^\/root\/[a-z0-9_]+$/, 'Use the canonical independent agent identity');
  assert(![AUTHOR, INHERITED_AUTHOR, DISPATCHER].includes(value), 'Author or dispatcher cannot accept preparation');
}
function manifestRows(rows) {
  assert(Array.isArray(rows) && rows.length > 0, 'Complete committed manifest required');
  assert.equal(new Set(rows.map(row => row.path.toLowerCase())).size, rows.length, 'Duplicate committed target');
  for (const row of rows) {
    assert.deepEqual(Object.keys(row).sort(), ['after', 'before', 'noop', 'path']);at(row.path);
    assert.equal(typeof row.noop, 'boolean');
    for (const descriptor of [row.before, row.after]) {
      if (descriptor === null) {assert.notEqual(descriptor, row.after, 'Committed target must have afterimage');continue;}
      assert.deepEqual(Object.keys(descriptor).sort(), ['bytes', 'sha256']);
      assert(Number.isSafeInteger(descriptor.bytes) && descriptor.bytes >= 0);shaValue(descriptor.sha256, row.path);
    }
  }
  return rows;
}
function predecessorJournal(stage, selected, read) {
  shaValue(selected.state.sha256, 'Receipt committed-state hash');shaValue(selected.prepared_sha256, 'Receipt prepared hash');shaValue(selected.plan_sha256, 'Receipt plan hash');
  const transaction = receiptRelative(selected.transaction_dir), canonicalState = receiptRelative(selected.state.path);
  assert.equal(path.posix.dirname(canonicalState), transaction + '/states');
  assert.match(path.posix.basename(canonicalState), /^\d{6}-committed\.json$/);
  const canonicalPrepared = transaction + '/prepared.json';
  const copies = [];
  function exactJournal(key, canonical, expectedHash) {
    const pin = stage[key];assert(pin, 'Missing ' + key);assert.equal(pin.raw_sha256, expectedHash, key);
    const bytes = readPin(pin, read);
    if (pin.path !== canonical) {
      const original = read(canonical);assert.deepEqual(bytes, original, 'Durable journal copy differs from actual original');
      copies.push({kind: key, source_path: canonical, target_path: pin.path, bytes: pin.bytes, raw_sha256: expectedHash});
    }
    return JSON.parse(bytes);
  }
  const journal = exactJournal('committed_journal', canonicalState, selected.state.sha256);
  const prepared = exactJournal('prepared_journal', canonicalPrepared, selected.prepared_sha256);
  assert.deepEqual(stage.journal_copies, copies, 'Explicit exact-content journal-copy binding required; no unused aliases');
  assert.equal(journal.schema, 1);assert.equal(journal.status, 'committed');assert.equal(journal.prepared_sha256, selected.prepared_sha256);
  assert.equal(prepared.schema, 1);assert.equal(prepared.plan.schema, 1);
  assert.equal(path.resolve(prepared.plan.repository_root), root);
  assert.equal(sha(serialize(prepared.plan)), prepared.plan_sha256, 'Prepared plan bytes do not match their identity');
  assert.equal(prepared.plan_sha256, selected.plan_sha256, 'Receipt and journal plan identities differ');
  const manifest = manifestRows(prepared.plan.entries);
  if (selected.target_manifest) assert.deepEqual(manifest, selected.target_manifest, 'Receipt target manifest differs from prepared plan');
  assert.deepEqual(prepared.plan.allowed_paths, manifest.map(row => row.path).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())));
  assert.equal(prepared.entries.length, manifest.length);
  for (const [index, row] of prepared.entries.entries()) {
    const {path: target, before, after, noop} = row;assert.deepEqual({path: target, before, after, noop}, manifest[index]);
  }
  assert.deepEqual(journal.targets, manifest.map(row => ({path: row.path, ...row.after, noop: row.noop})), 'Committed state must contain the complete prepared manifest');
  const names = fs.readdirSync(at(transaction + '/states')).filter(name => /^\d{6}-[a-z-]+\.json$/.test(name)).sort();
  assert.equal(names.at(-1), path.posix.basename(canonicalState), 'Selected committed state is not the latest actual journal state');
  return {journal, prepared, manifest, canonicalState};
}
function successfulPredecessor(kind, stage, read) {
  assert(['fourth10', 'shopping_bag'].includes(kind));
  assert(stage && stage.root_confirmed_committed === true && stage.root_confirmed_persisted === true);
  const commit = JSON.parse(readPin(stage.committed_receipt, read));
  const persisted = JSON.parse(readPin(stage.persisted_receipt, read));
  assert.equal(commit.schema, 1);assert.equal(persisted.schema, 1);
  assert.equal(commit.status, 'committed');assert.equal(persisted.ok, true);assert.equal(persisted.error, null);
  let selected;
  if (kind === 'fourth10') {
    assert.equal(stage.receipt_schema, 'foundation02_fourth10_nested_result_v1');
    assert.equal(stage.committed_receipt.raw_sha256, '96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
    assert.equal(stage.persisted_receipt.raw_sha256, 'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
    assert.equal(commit.result.status, 'committed');assert.equal(commit.result.committed, true);assert.equal(commit.result.state.status, 'committed');
    selected = {transaction_dir: commit.result.transactionDir, state: commit.result.state, prepared_sha256: commit.result.preparedSha256, plan_sha256: commit.result.planSha256};
    assert.equal(persisted.source_before, persisted.source_after);shaValue(persisted.source_before, 'Fourth-ten persisted source');
    assert.equal(persisted.committed_receipt.path, stage.committed_receipt.path);
    assert.equal(persisted.committed_receipt.sha256, stage.committed_receipt.raw_sha256);
    assert.equal(persisted.commands.length, 4);
  } else {
    assert.equal(stage.receipt_schema, 'shopping_bag_top_level_commit_and_persisted_input_v1');
    assert.equal(commit.committed, true);assert.equal(Object.hasOwn(commit, 'result'), false, 'Use the genuine top-level bag receipt');
    selected = {transaction_dir: commit.transaction_dir, state: commit.state, prepared_sha256: commit.prepared_sha256, plan_sha256: commit.plan_sha256, target_manifest: manifestRows(commit.target_manifest)};
    assert.equal(commit.journal.status, 'committed');assert.equal(commit.journal.prepared_sha256, commit.prepared_sha256);assert.equal(commit.journal.plan_sha256, commit.plan_sha256);
    assert.deepEqual(commit.journal.state, commit.state);assert.equal(commit.journal.verified_targets, commit.target_manifest.length);
    assert.equal(persisted.postcheck_error, null);shaValue(persisted.source_sha256, 'Bag persisted source');shaValue(persisted.input_sha256, 'Bag persisted input');
    assert.equal(stage.persisted_source.raw_sha256, persisted.source_sha256);readPin(stage.persisted_source, read);
    assert.equal(stage.persisted_input.raw_sha256, persisted.input_sha256);
    const persistedInput = JSON.parse(readPin(stage.persisted_input, read));
    assert.equal(persistedInput.status, 'root_confirmed_actual_bag_commit_for_persisted_validation');
    assert.equal(persistedInput.commit_receipt.path, stage.committed_receipt.path);assert.equal(persistedInput.commit_receipt.sha256, stage.committed_receipt.raw_sha256);
    assert.equal(persistedInput.committed_journal.path, receiptRelative(commit.state.path));assert.equal(persistedInput.committed_journal.sha256, commit.state.sha256);
    assert.equal(persistedInput.target_count, commit.target_manifest.length);
    assert.equal(persisted.commands.length, 2);assert.equal(persisted.audit.errors, 0);
    assert.deepEqual(persisted.commands.map(command => command.args), [['tools/validate-professional-content.cjs', '--json'], ['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']]);
    assert(Number.isSafeInteger(persistedInput.expected_tests) && persistedInput.expected_tests > 0);
    assert.equal(persisted.tests.tests, persistedInput.expected_tests);assert.equal(persisted.tests.pass, persistedInput.expected_tests);
    for (const key of ['fail', 'cancelled', 'skipped']) assert.equal(persisted.tests[key], 0);
    for (const [key, value] of Object.entries(persistedInput.expected_audit_summary)) assert.equal(persisted.audit.summary[key], value, key);
    assert.equal(persisted.audit.summary.integrated_word_images, 9);assert.equal(persisted.audit.summary.integrated_word_audio, 12);assert.equal(persisted.audit.summary.ready_modules, 0);
    for (const row of commit.target_manifest) assert.equal(persistedInput.expected_inputs[row.path], row.after.sha256, 'Persisted input omits or changes a committed target: ' + row.path);
  }
  const {journal, prepared, manifest, canonicalState} = predecessorJournal(stage, selected, read);
  if (kind === 'shopping_bag') {
    assert(Array.isArray(stage.installed_targets), 'Complete bag installed target pins required');
    assert.equal(new Set(stage.installed_targets.map(pin => pin.path.toLowerCase())).size, stage.installed_targets.length);
    const sorted = rows => rows.slice().sort((a, b) => a.path.localeCompare(b.path));
    const complete = manifest.map(row => ({path: row.path, bytes: row.after.bytes, raw_sha256: row.after.sha256}));
    for (const pin of stage.installed_targets) assert.deepEqual(Object.keys(pin).sort(), ['bytes', 'path', 'raw_sha256']);
    assert.deepEqual(sorted(stage.installed_targets), sorted(complete), 'Installed target pins must equal the complete authoritative bag manifest');
    for (const pin of stage.installed_targets) readPin(pin, read);
  }
  assert(Array.isArray(persisted.commands) && persisted.commands.length > 0);
  for (const command of persisted.commands) {
    assert.equal(command.exit_code, 0);assert.equal(command.error, null);assert.equal(command.signal, null);
    assert.equal(typeof command.log, 'string');assert.equal(path.posix.basename(command.log), command.log);assert(!command.log.includes('\\'));
    const log = path.posix.dirname(stage.persisted_receipt.path) + '/' + command.log;
    assert.equal(sha(read(log)), command.log_sha256, log);
  }
  assert(Array.isArray(stage.success_assertions) && stage.success_assertions.length > 0);
  for (const item of stage.success_assertions) {
    assert(['commit', 'journal', 'persisted'].includes(item.document));
    const document = {commit, journal, persisted}[item.document];
    assert(Array.isArray(item.keys) && item.keys.length > 0);
    assert.deepEqual(item.keys.reduce((value, key) => value[key], document), item.expected);
  }
  return {commit, journal, prepared, persisted, manifest, canonicalState};
}
function openSession(inputPath, inputHash) {
  assert.match(inputHash, /^[a-f0-9]{64}$/);
  const inputBytes = fs.readFileSync(at(inputPath));assert.equal(sha(inputBytes), inputHash);
  const input = JSON.parse(inputBytes);
  assert.equal(input.status, 'root_authorized_one_shot_scratch_preparation');assert.equal(input.dispatcher, DISPATCHER);assert.equal(input.preparation_author, AUTHOR);
  assert.equal(input.entrypoint, own + '/prepare.cjs');assert.equal(input.output, own + '/execution-r01');
  assert.equal(input.root_selected_actual_baseline, true);assert.equal(input.execute_project_tests, false);
  const binding = JSON.parse(verifyPin(input.binding));
  assert.equal(binding.status, 'root_bound_actual_post_bag_persisted_baseline');assert.equal(binding.bound, true);
  assert.deepEqual(Object.keys(binding.predecessors).sort(), ['fourth10', 'shopping_bag']);
  assert.equal(binding.guards.production_writers_yielded, true);assert.equal(binding.guards.complete_inputs_frozen, true);assert.equal(binding.guards.final_destinations_reviewed, true);
  assert.equal(binding.roles.preparation_author, AUTHOR);assert.equal(binding.roles.inherited_preparation_author, INHERITED_AUTHOR);assert.equal(binding.roles.dispatcher, DISPATCHER);independentReviewer(binding.roles.independent_reviewer);
  assert(binding.input_files.length > 0);assert.equal(new Set(binding.input_files.map(pin => pin.path.toLowerCase())).size, binding.input_files.length);
  const pins = new Map(binding.input_files.map(pin => [pin.path, pin]));
  const rootInputPin = {path: inputPath, bytes: inputBytes.length, raw_sha256: inputHash};
  const externalPins = new Map([input.binding, input.source_inventory, input.independent_source_review, rootInputPin].map(pin => [pin.path, pin]));
  const read = relative => {
    const pin = pins.get(relative) || externalPins.get(relative);assert(pin, 'Unpinned actual read: ' + relative);
    if (pins.has(relative) && externalPins.has(relative)) {assert.equal(pins.get(relative).raw_sha256, externalPins.get(relative).raw_sha256);assert.equal(pins.get(relative).bytes, externalPins.get(relative).bytes);}
    return verifyPin(pin);
  };
  const inventory = JSON.parse(verifyPin(input.source_inventory));
  assert.equal(input.source_inventory.path, own + '/source-inventory.json');assert.equal(inventory.status, 'frozen_undispatched_sources_final_binding_unbound');
  assert.equal(inventory.preparation_author, AUTHOR);assert.equal(inventory.inherited_preparation_author, INHERITED_AUTHOR);
  for (const row of inventory.files) {const pin = {...row, path: own + '/' + row.path};assert.deepEqual(read(pin.path), verifyPin(pin));}
  const review = JSON.parse(verifyPin(input.independent_source_review));
  assert.equal(review.status, 'accepted_for_one_root_owned_fifth10_scratch_preparation');independentReviewer(review.reviewer);
  assert.equal(review.reviewer, binding.roles.independent_reviewer);assert.deepEqual(review.roles, binding.roles);
  assert.deepEqual(review.source_inventory, input.source_inventory);assert.deepEqual(review.actual_binding, input.binding);assert.equal(review.preparation_execution_accepted, true);
  for (const pin of binding.input_files) verifyPin(pin);
  const fourth = successfulPredecessor('fourth10', binding.predecessors.fourth10, read);
  const bag = successfulPredecessor('shopping_bag', binding.predecessors.shopping_bag, read);
  for (const [kind, stage] of Object.entries(binding.predecessors)) {
    const required = ['committed_receipt', 'committed_journal', 'prepared_journal', 'persisted_receipt'];
    if (kind === 'shopping_bag') required.push('persisted_input', 'persisted_source');
    for (const key of required) assert(binding.required_retained_sources.includes(stage[key].path), 'Predecessor proof must be retained: ' + key);
  }
  for (const relative of ['data/professional/lexemes/retail-pilot.json', 'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']) assert(binding.predecessors.shopping_bag.installed_targets.some(pin => pin.path === relative), 'Actual bag installed target missing: ' + relative);
  assert.equal(bag.commit.registry_after_sha256, binding.registry_before_sha256, 'Fifth-ten must start from the actual delivered bag registry');
  assert(binding.must_remain_absent.length > 0);assert.equal(new Set(binding.must_remain_absent.map(value => value.toLowerCase())).size, binding.must_remain_absent.length);
  for (const relative of binding.must_remain_absent) assert(!fs.existsSync(at(relative)), 'Required absent target exists: ' + relative);
  const ctx = {input, inputPath, inputHash, rootInputPin, binding, pins, read, parse: relative => JSON.parse(read(relative)), fourth, bag,
    recheck() {
      assert.deepEqual(fs.readFileSync(at(inputPath)), inputBytes);verifyPin(input.binding);verifyPin(input.source_inventory);verifyPin(input.independent_source_review);
      for (const pin of binding.input_files) verifyPin(pin);
      for (const stage of [binding.predecessors.fourth10, binding.predecessors.shopping_bag]) {
        const state = receiptRelative(stage === binding.predecessors.fourth10 ? fourth.commit.result.state.path : bag.commit.state.path);
        const names = fs.readdirSync(at(path.posix.dirname(state))).filter(name => /^\d{6}-[a-z-]+\.json$/.test(name)).sort();assert.equal(names.at(-1), path.posix.basename(state));
      }
      for (const relative of binding.must_remain_absent) assert(!fs.existsSync(at(relative)), relative);
    }};
  sessions.add(ctx);return ctx;
}
function assertSession(ctx) {assert(sessions.has(ctx), 'Actual successful bag evidence and root binding required before projection or transformation');}
module.exports = {root, own, at, sha, hash, serialize, verifyPin, openSession, assertSession};
