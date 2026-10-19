'use strict';
// Root dispatches only after the scoped persisted third-ten validation passes.
const C = require('./common.cjs');
const {fs, path, assert, here, root, resolve, relative, raw, read, write} = C;
assert.equal(process.cwd().toLowerCase(), root.toLowerCase());
const args = process.argv.slice(2);
assert.equal(args.length, 6);
assert.equal(args[0], '--root-preparation-slot');
assert.equal(args[1], 'shopping-bag-candidate-r01');
assert.equal(args[2], '--proposal-inventory-sha256');
assert.equal(args[4], '--baseline-receipt-sha256');
assert.match(args[5], /^[0-9a-f]{64}$/);
for (const name of ['preparation-attempt-start.json', 'prepared', 'preparation-receipt.json', 'native-attempt-start.json', 'output']) {
  assert(!fs.existsSync(path.join(here, name)), 'Preserve previous attempt: ' + name);
}
const inputs = C.inventory(here, args[3]);
const sourceBase = resolve('docs/assets/sources/shopping-bag-additional-leads-2026-10-17');
Object.assign(inputs, C.inventory(sourceBase, '39acb66b86d26ab894da4b0862e59ab2886d98f6133f6bc05d5630dae79a0931'));
const baselineRel = 'build/professional-english/foundation02-third10-persisted-validation-r01/attempt-001/receipt.json';
const baselineFile = resolve(baselineRel), baseline = read(baselineFile);
assert.equal(raw(baselineFile), args[5]);
assert.equal(baseline.ok, true);
assert.equal(baseline.error, null);
assert.equal(baseline.source_before, baseline.source_after);
assert.equal(baseline.commands.length, 4);
const wrapperRel = 'build/professional-english/foundation02-third10-persisted-validation-r01/invoke.cjs';
assert.equal(raw(resolve(wrapperRel)), baseline.source_before);
const startRel = 'build/professional-english/foundation02-third10-persisted-validation-r01/attempt-001/start.json';
const start = read(resolve(startRel));
assert.equal(start.source_sha256, baseline.source_before);
assert.deepEqual(start.committed_receipt, baseline.committed_receipt);
assert.equal(Object.keys(start.expected_inputs).length, baseline.checked_inputs);
C.verifyHashes(start.expected_inputs);
assert.equal(raw(resolve(baseline.committed_receipt.path)), baseline.committed_receipt.sha256);
assert.equal(read(resolve(baseline.committed_receipt.path)).status, 'committed');
const commands = [
  ['tools/validate-professional-content.cjs'],
  ['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs'],
  ['tools/run-godot.cjs', '--headless', '--path', root, '--script', 'res://tests/godot/professional_retail_morphology_tests.gd'],
  ['--test', 'docs/content-review/foundation-module02-language-third10-2026-10-17/committed-evidence.test.cjs']
];
for (const [index, command] of baseline.commands.entries()) {
  assert.deepEqual(command.command.slice(1), commands[index]);
  assert.equal(command.exit_code, 0);
  assert.equal(command.signal, null);
  assert.equal(command.error, null);
  assert.equal(command.log, 'command-' + (index + 1) + '.log');
  const rel = path.posix.dirname(baselineRel) + '/' + command.log;
  assert.equal(raw(resolve(rel)), command.log_sha256);
  inputs[rel] = command.log_sha256;
}
for (const rel of [baselineRel, wrapperRel, startRel, baseline.committed_receipt.path]) inputs[rel] = raw(resolve(rel));
Object.assign(inputs, start.expected_inputs);
const before = C.production();
const lexemesRel = 'data/professional/lexemes/retail-pilot.json';
const entries = read(resolve(lexemesRel)).lexemes;
const entry = entries.find(value => value.id === 'shopping-bag.goods-carrier.n');
const basket = entries.find(value => value.id === 'shopping-basket.store-container.n');
const brief = read(path.join(here, 'brief-revision-proposal.json'));
assert(entry && basket);
assert.equal(entry.definition, brief.definition_unchanged);
assert.equal(entry.media.image.brief, brief.original_brief);
assert.equal(entry.media.image.status, 'pending');
assert.equal(entry.media.image.path, null);
assert.equal(entry.media.image.sha256, null);
assert.equal(entry.media.image.review.status, 'pending');
assert.equal(entry.media.audio.status, 'integrated');
assert.equal(entry.media.audio.sha256, '6c7d2ac0e733214faf920a4a0781d0458b6b891a92aa07b7ab433b501d19de72');
assert.deepEqual(entry.media.audio.voice_settings, {voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%', postprocessing: false});
assert.equal(raw(resolve(entry.media.audio.path.replace(/^res:\/\//, ''))), entry.media.audio.sha256);
assert.equal(basket.media.image.status, 'integrated');
assert.equal(basket.media.image.review.status, 'reviewed');
assert.equal(basket.media.image.sha256, 'fbbdcb9b9eb07999d6891eb900d07ab84de5b9946913c55b6cde36d92b7c9eb3');
const course = read(resolve('data/professional/courses/retail.json'));
assert(course.modules.length > 0 && course.modules.every(value => value.status === 'draft'));
const source = read(path.join(sourceBase, 'source-record.json'));
assert.equal(source.review.accepted, false);
const bagFile = path.join(sourceBase, 'size-study/bag-crop-512-study.png');
const basketFile = resolve(basket.media.image.path.replace(/^res:\/\//, ''));
const bagResource = C.pngResource(bagFile, {sha256: 'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb', bytes: 135843, width: 414, height: 512});
const basketResource = C.pngResource(basketFile, {sha256: basket.media.image.sha256, bytes: 105604, width: 512, height: 454});
const resources = [bagResource, basketResource];
const manifest = {schema_version: 1, course_id: 'retail', module_id: 'shopping-bag-candidate-r01', curriculum_revision: 'scratch-review-r01', resources};
const sourceReview = read(path.join(sourceBase, 'candidate-stage-authorization.json'));
assert.equal(sourceReview.final_visual_acceptance, false);
assert.equal(sourceReview.production_integration_authorized_by_this_record, false);
C.verifyHashes(inputs);
assert.deepEqual(C.production(), before, 'No drift during preparation checks');
write(path.join(here, 'preparation-attempt-start.json'), {schema: 1, started_at: new Date().toISOString(), proposal_inventory_sha256: args[3], baseline_receipt_sha256: args[5], scope: 'Scratch-only input freeze. Preserve this marker if interrupted.'});
const prepared = path.join(here, 'prepared');
fs.mkdirSync(path.join(prepared, 'fixture/professional-media'), {recursive: true});
for (const [index, file] of [bagFile, basketFile].entries()) {
  const output = path.join(prepared, 'fixture', resources[index].path);
  fs.copyFileSync(file, output, fs.constants.COPYFILE_EXCL);
  assert.equal(raw(output), resources[index].sha256);
}
write(path.join(prepared, 'bag-entry-preimage.json'), entry);
write(path.join(prepared, 'basket-entry-preimage.json'), basket);
write(path.join(prepared, 'manifest.json'), manifest);
Object.assign(inputs, C.scan(prepared));
const frozen = {schema: 1, status: 'prepared_native_not_run', prepared_at: new Date().toISOString(),
  baseline: {path: baselineRel, sha256: args[5], scope: baseline.scope, inherited_scope: 'Scoped persisted audit, two affected Node suites, native morphology and committed evidence only. Not a whole-continuation or media baseline.'},
  proposal_inventory_sha256: args[3], source_inventory_sha256: '39acb66b86d26ab894da4b0862e59ab2886d98f6133f6bc05d5630dae79a0931',
  sense_id: entry.id, lexemes_raw_sha256: raw(resolve(lexemesRel)), original_brief: entry.media.image.brief,
  proposed_brief: brief.proposed_brief, brief_revision_accepted: false,
  resources, protected_directories: C.protectedDirectories, protected_files: C.protectedFiles,
  production_raw_sha256: before, inputs_raw_sha256: inputs, native_run: false,
  production_acceptance: false, caller_presentation: 'WordCard component captures use caller-equivalent alpha, pair tint and focus. No complete game-board interaction claim.',
  runtime_cache_side_effect: 'Root runs the current real project. Godot may update .godot runtime/import caches; protected source and fixture hashes must remain unchanged.'};
C.verifyHashes(inputs);
assert.deepEqual(C.production(), before, 'Production unchanged after scratch preparation');
write(path.join(prepared, 'frozen-inputs.json'), frozen);
const receipt = {schema: 1, status: 'prepared_pending_root_native_dispatch', frozen_inputs_sha256: raw(path.join(prepared, 'frozen-inputs.json')),
  guarded_production_files: Object.keys(before).length, guarded_input_files: Object.keys(inputs).length,
  baseline_receipt_sha256: args[5], source_bytes_unchanged: true, brief_revision_accepted: false,
  scripts_parsed: false, tests_run: false, native_run: false, image_accepted: false, production_writes: false};
write(path.join(here, 'preparation-receipt.json'), receipt);
console.log(JSON.stringify(receipt, null, 2));
