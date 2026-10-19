'use strict';
// Root owns the native slot. An interrupted or failed attempt is never replayed.
const C = require('./common.cjs');
const {fs, path, assert, here, root, raw, read, write} = C;
assert.equal(process.cwd().toLowerCase(), root.toLowerCase());
const args = process.argv.slice(2);
assert.equal(args.length, 6);
assert.equal(args[0], '--root-native-slot');
assert.equal(args[1], 'shopping-bag-candidate-r01');
assert.equal(args[2], '--frozen-inputs-sha256');
assert.equal(args[4], '--preparation-receipt-sha256');
for (const index of [3, 5]) assert.match(args[index], /^[0-9a-f]{64}$/);
const frozenFile = path.join(here, 'prepared/frozen-inputs.json');
const preparationFile = path.join(here, 'preparation-receipt.json');
assert.equal(raw(frozenFile), args[3]);
assert.equal(raw(preparationFile), args[5]);
const frozen = read(frozenFile), preparation = read(preparationFile);
assert.equal(preparation.status, 'prepared_pending_root_native_dispatch');
assert.equal(preparation.frozen_inputs_sha256, args[3]);
assert.equal(frozen.status, 'prepared_native_not_run');
assert.equal(frozen.production_acceptance, false);
assert.equal(frozen.brief_revision_accepted, false);
assert.deepEqual(frozen.protected_directories, C.protectedDirectories);
assert.deepEqual(frozen.protected_files, C.protectedFiles);
function guard() {
  assert.equal(raw(frozenFile), args[3]);
  assert.equal(raw(preparationFile), args[5]);
  C.verifyHashes(frozen.inputs_raw_sha256);
  assert.deepEqual(C.production(), frozen.production_raw_sha256, 'Protected production, shared tests and source dependencies changed');
  const fixture = C.scan(path.join(here, 'prepared/fixture'));
  const expected = Object.fromEntries(Object.entries(frozen.inputs_raw_sha256).filter(([file]) => file.startsWith('build/professional-english/shopping-bag-candidate-r01/prepared/fixture/')));
  assert.deepEqual(fixture, expected, 'Scratch fixture file set changed');
}
guard();
for (const name of ['native-attempt-start.json', 'native.log', 'output', 'candidate-receipt.json']) {
  assert(!fs.existsSync(path.join(here, name)), 'Preserve previous attempt: ' + name);
}
const nativeArgs = ['--path', root, '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
  '--script', 'res://build/professional-english/shopping-bag-candidate-r01/render-and-check.gd'];
write(path.join(here, 'native-attempt-start.json'), {schema: 1, started_at: new Date().toISOString(),
  root_native_slot: args[1], frozen_inputs_sha256: args[3], preparation_receipt_sha256: args[5],
  native_args: nativeArgs, timeout_ms: 60000, scope: 'One native image-only candidate attempt; preserve this marker even if interrupted.'});
const started = Date.now();
let nativeError = null, guardError = null, resultError = null, output = '', report = null;
try {
  const result = require(path.join(root, 'tools/run-godot.cjs')).runGodot(nativeArgs, {timeout: 60000});
  output = (result.stdout || '') + (result.stderr || '');
} catch (error) { nativeError = String(error.stack || error); output = nativeError; }
fs.writeFileSync(path.join(here, 'native.log'), output, {flag: 'wx'});
try { guard(); } catch (error) { guardError = String(error.stack || error); }
const expectedStates = ['match-unmatched', 'memory-unmatched', 'memory-matched'];
for (let lane = 1; lane <= 5; lane++) for (const state of ['settled', 'focused']) expectedStates.push('match-pair-' + lane + '-' + state);
expectedStates.push('match-stress-068', 'memory-stress-068');
function dimensions(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}
try {
  const summary = output.match(/Shopping-bag candidate QA: (\d+) checks, (\d+) failures/);
  assert(summary && Number(summary[1]) >= 450 && Number(summary[2]) === 0, 'Native success summary missing');
  report = read(path.join(here, 'output/report.json'));
  assert.equal(report.status, 'candidate_probe_passed_pending_visual_review');
  assert.equal(report.failed, 0);
  assert.equal(report.checks.length, Number(summary[1]));
  assert(report.checks.every(check => check.passed === true));
  assert.equal(report.frozen_inputs_sha256, args[3]);
  for (const key of ['brief_revision_accepted', 'production_acceptance', 'cue_visibility_acceptance', 'actual_board_execution', 'participant_recognition_study', 'audio_playback']) assert.equal(report[key], false, key);
  assert.deepEqual(report.manifest.resources, frozen.resources);
  assert.deepEqual(report.manifest, read(path.join(here, 'prepared/manifest.json')));
  assert.equal(report.image_pixels.length, 2);
  for (const [index, image] of report.image_pixels.entries()) {
    assert.equal(image.id, frozen.resources[index].id);
    assert.equal(image.source_rgba_sha256, image.decoded_rgba_sha256);
    assert.match(image.source_rgba_sha256, /^[0-9a-f]{64}$/);
  }
  const total = frozen.resources.reduce((sum, resource) => sum + resource.decoded_bytes, 0);
  for (const stats of [report.loaded_cache, report.lease_only_cache]) {
    assert.equal(stats.resources, 2);
    assert.equal(stats.resident_bytes, total);
    assert.equal(stats.pinned_bytes, total);
    assert.equal(stats.reserved_bytes, 0);
    assert.equal(stats.leases, 1);
  }
  assert.deepEqual([...report.loaded_cache.active_ids].sort(), frozen.resources.map(resource => resource.id).sort());
  assert.deepEqual(report.lease_only_cache.active_ids, []);
  for (const key of ['resources', 'resident_bytes', 'pinned_bytes', 'reserved_bytes', 'leases']) assert.equal(report.released_cache[key], 0);
  assert.deepEqual(report.released_cache.active_ids, []);
  assert.deepEqual(report.released_scoped_urls, [true, true]);
  assert.deepEqual(report.released_texture_weakrefs, [true, true]);
  assert.equal(report.captures.length, 30);
  const expectedFiles = ['report.json', 'actual-wordcard-comparison.png', 'actual-wordcard-comparison-3x.png'];
  for (const [stateIndex, name] of expectedStates.entries()) {
    const memory = name.startsWith('memory-'), matched = !name.endsWith('unmatched'), stress = name.endsWith('stress-068');
    const cardSize = memory ? [144, 74] : [126, 72], pictureSize = memory ? [120, 54] : [102, 52];
    const panelName = 'panel-' + name + '.png';
    expectedFiles.push(panelName);
    assert.deepEqual(dimensions(path.join(here, 'output', panelName)), [396, 172]);
    for (let subject = 0; subject < 2; subject++) {
      const capture = report.captures[stateIndex * 2 + subject];
      const filename = (subject === 0 ? 'bag-' : 'basket-') + name + '.png';
      expectedFiles.push(filename);
      assert.equal(capture.file, filename);
      assert.equal(capture.state.name, name);
      assert.equal(capture.subject, subject === 0 ? 'bag_candidate' : 'accepted_basket_reference');
      assert.equal(capture.state.scope, stress ? 'wordcard_only_conservative_stress' : 'current_caller_equivalent');
      assert.equal(capture.badge_visible, matched);
      assert(Math.abs(capture.picture_alpha - (stress ? 0.68 : 1)) < 0.00001);
      assert.equal(capture.control_disabled, matched && (memory || stress));
      assert.deepEqual(capture.card_size, cardSize);
      assert.deepEqual(capture.picture_size, pictureSize);
      assert.deepEqual(dimensions(path.join(here, 'output', filename)), cardSize);
      assert.equal(raw(path.join(here, 'output', filename)), capture.sha256);
      assert(Object.values(capture.cue_visibility).every(value => value === 'pending_root_visual_review'));
    }
  }
  assert.deepEqual(dimensions(path.join(here, 'output/actual-wordcard-comparison.png')), [1188, 860]);
  assert.deepEqual(dimensions(path.join(here, 'output/actual-wordcard-comparison-3x.png')), [3564, 2580]);
  assert.deepEqual(fs.readdirSync(path.join(here, 'output')).sort(), expectedFiles.sort(), 'Exact native evidence file set');
} catch (error) { resultError = String(error.stack || error); }
const artifacts = fs.existsSync(path.join(here, 'output')) ? C.scan(path.join(here, 'output')) : {};
const ok = !nativeError && !guardError && !resultError;
const receipt = {schema: 1, status: ok ? 'candidate_ready_for_independent_root_visual_review' : 'failed_attempt_preserved', ok,
  duration_ms: Date.now() - started, frozen_inputs_sha256: args[3], preparation_receipt_sha256: args[5],
  baseline: frozen.baseline, native_args: nativeArgs, native_timeout_ms: 60000, native_error: nativeError, guard_error: guardError, result_error: resultError,
  native_log_sha256: raw(path.join(here, 'native.log')), checks: report?.checks?.length ?? 0, failures: report?.failed ?? null,
  output_raw_sha256: artifacts, protected_production_files: Object.keys(frozen.production_raw_sha256).length,
  production_sources_unchanged: !guardError, scratch_inputs_unchanged: !guardError,
  original_brief_retained: !guardError, brief_revision_accepted: false, image_accepted: false, cue_visibility_accepted: false,
  actual_board_execution: false, complete_module_delivery: false, participant_recognition_study: false, native_replay_allowed: false,
  runtime_cache_side_effect: frozen.runtime_cache_side_effect,
  scope: 'Native image-only delivery and WordCard component evidence at established review sizes. Root must inspect the exact crops, accept or reject the brief separately, and decide any subsequent production proposal.'};
write(path.join(here, 'candidate-receipt.json'), receipt);
console.log(JSON.stringify(receipt, null, 2));
process.exitCode = ok ? 0 : 1;
