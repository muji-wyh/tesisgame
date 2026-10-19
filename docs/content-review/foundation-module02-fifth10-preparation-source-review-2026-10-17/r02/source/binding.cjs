'use strict';
// Authored, undispatched. Only a root-bound actual predecessor state opens a session.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const own = 'build/professional-english/foundation02-fifth10-delivery-preparation-r02';
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
function successfulPredecessor(stage, read) {
  assert(stage && stage.root_confirmed_committed === true && stage.root_confirmed_persisted === true);
  const commit = JSON.parse(read(stage.committed_receipt.path));
  const journal = JSON.parse(read(stage.committed_journal.path));
  const persisted = JSON.parse(read(stage.persisted_receipt.path));
  for (const pin of [stage.committed_receipt, stage.committed_journal, stage.persisted_receipt]) verifyPin(pin);
  assert.equal(commit.status, 'committed');
  assert.equal(commit.result.status, 'committed');
  assert.equal(commit.result.committed, true);
  assert.equal(journal.status, 'committed');
  assert.equal(persisted.ok, true);
  assert.equal(persisted.error, null);
  assert.equal(persisted.source_before, persisted.source_after);
  assert.match(persisted.source_before, /^[a-f0-9]{64}$/);
  assert.equal(persisted.committed_receipt.path, stage.committed_receipt.path);
  assert.equal(persisted.committed_receipt.sha256, stage.committed_receipt.raw_sha256);
  assert(persisted.commands.length > 0);
  for (const command of persisted.commands) {
    assert.equal(command.exit_code, 0);assert.equal(command.error, null);assert.equal(command.signal, null);
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
  return {commit, journal, persisted};
}
function openSession(inputPath, inputHash) {
  assert.match(inputHash, /^[a-f0-9]{64}$/);
  const inputBytes = fs.readFileSync(at(inputPath));
  assert.equal(sha(inputBytes), inputHash);
  const input = JSON.parse(inputBytes);
  assert.equal(input.status, 'root_authorized_one_shot_scratch_preparation');
  assert.equal(input.entrypoint, own + '/prepare.cjs');
  assert.equal(input.output, own + '/execution-r01');
  assert.equal(input.root_selected_actual_baseline, true);
  assert.equal(input.execute_project_tests, false);
  const binding = JSON.parse(verifyPin(input.binding));
  assert.equal(binding.status, 'root_bound_actual_post_bag_persisted_baseline');
  assert.equal(binding.bound, true);
  assert.equal(binding.guards.production_writers_yielded, true);
  assert.equal(binding.guards.complete_inputs_frozen, true);
  assert.equal(binding.guards.final_destinations_reviewed, true);
  assert(binding.input_files.length > 0);
  assert.equal(new Set(binding.input_files.map(pin => pin.path.toLowerCase())).size, binding.input_files.length);
  const pins = new Map(binding.input_files.map(pin => [pin.path, pin]));
  const rootInputPin={path:inputPath,bytes:inputBytes.length,raw_sha256:inputHash};
  const externalPins=new Map([input.binding,input.source_inventory,input.independent_source_review,rootInputPin].map(pin=>[pin.path,pin]));
  const read = relative => {
    const pin=pins.get(relative)||externalPins.get(relative);assert(pin,'Unpinned actual read: '+relative);
    if(pins.has(relative)&&externalPins.has(relative)){assert.equal(pins.get(relative).raw_sha256,externalPins.get(relative).raw_sha256);assert.equal(pins.get(relative).bytes,externalPins.get(relative).bytes);}
    return verifyPin(pin);
  };
  const inventory = JSON.parse(verifyPin(input.source_inventory));
  assert.equal(input.source_inventory.path, own + '/source-inventory.json');
  assert.equal(inventory.status, 'frozen_undispatched_sources_final_binding_unbound');
  for (const row of inventory.files) {
    const pin = {...row, path: own + '/' + row.path};
    assert.deepEqual(read(pin.path), verifyPin(pin));
  }
  const review = JSON.parse(verifyPin(input.independent_source_review));
  assert.equal(review.status, 'accepted_for_one_root_owned_fifth10_scratch_preparation');
  assert.equal(review.source_inventory.raw_sha256, input.source_inventory.raw_sha256);
  assert.equal(review.actual_binding.raw_sha256, input.binding.raw_sha256);
  assert.equal(review.preparation_execution_accepted, true);
  for (const pin of binding.input_files) verifyPin(pin);
  const fourth = successfulPredecessor(binding.predecessors.fourth10, read);
  const bag = successfulPredecessor(binding.predecessors.shopping_bag, read);
  assert.equal(binding.predecessors.fourth10.committed_receipt.raw_sha256, '96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
  assert.equal(binding.predecessors.fourth10.persisted_receipt.raw_sha256, 'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
  assert(binding.predecessors.shopping_bag.installed_targets.length > 0);
  for (const pin of binding.predecessors.shopping_bag.installed_targets) assert.deepEqual(read(pin.path), verifyPin(pin));
  for(const relative of ['data/professional/lexemes/retail-pilot.json','data/professional/provenance/retail-shopping-bag-image-2026-10-17.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs'])assert(binding.predecessors.shopping_bag.installed_targets.some(pin=>pin.path===relative),'Actual bag installed target missing: '+relative);
  assert.equal(bag.commit.registry_after_sha256,binding.registry_before_sha256,'Fifth-ten must start from the actual delivered bag registry');
  assert(binding.must_remain_absent.length > 0);
  assert.equal(new Set(binding.must_remain_absent.map(value => value.toLowerCase())).size, binding.must_remain_absent.length);
  for (const relative of binding.must_remain_absent) assert(!fs.existsSync(at(relative)), 'Required absent target exists: ' + relative);
  const ctx = {input, inputPath, inputHash, rootInputPin, binding, pins, read, parse: relative => JSON.parse(read(relative)), fourth, bag,
    recheck() {
      assert.deepEqual(fs.readFileSync(at(inputPath)), inputBytes);
      verifyPin(input.binding);verifyPin(input.source_inventory);verifyPin(input.independent_source_review);
      for (const pin of binding.input_files) verifyPin(pin);
      for (const relative of binding.must_remain_absent) assert(!fs.existsSync(at(relative)), relative);
    }};
  sessions.add(ctx);
  return ctx;
}
function assertSession(ctx) {assert(sessions.has(ctx), 'Actual successful bag evidence and root binding required before projection or transformation');}
module.exports = {root, own, at, sha, hash, serialize, verifyPin, openSession, assertSession};
