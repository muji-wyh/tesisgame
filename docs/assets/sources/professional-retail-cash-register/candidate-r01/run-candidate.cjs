'use strict';
// Root owns native execution. Do not reuse this attempt or overwrite evidence.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const here = __dirname, base = path.resolve(here, '..'), root = path.resolve(base, '../../../..');
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const args = process.argv.slice(2);
assert.equal(args.length, 4);
assert.equal(args[0], '--root-granted-native-slot');
assert.equal(args[1], 'cash-register-r04-candidate-r01');
assert.equal(args[2], '--frozen-inputs-sha256');
assert.match(args[3], /^[0-9a-f]{64}$/);
assert.equal(process.cwd().toLowerCase(), root.toLowerCase());
const frozenPath = path.join(here, 'frozen-inputs.json'), frozenSha = raw(frozenPath), frozen = read(frozenPath);
assert.equal(frozenSha, args[3]);
function scan(relative, result = {}) {
  for (const item of fs.readdirSync(path.join(root, relative), {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
    const rel = (relative + '/' + item.name).replaceAll('\\', '/');
    if (item.isDirectory()) scan(rel, result);
    else result[rel] = raw(path.join(root, rel));
  }
  return result;
}
function production() {
  const result = {};
  for (const directory of frozen.protected_directories) Object.assign(result, scan(directory));
  for (const file of frozen.protected_files) result[file] = raw(path.join(root, file));
  return result;
}
function guard() {
  assert.equal(raw(frozenPath), frozenSha);
  assert.deepEqual(production(), frozen.production_raw_sha256, 'Production, shared tests and UI font files must remain exact');
  for (const [relative, sha] of Object.entries(frozen.inputs_raw_sha256)) assert.equal(raw(path.join(root, relative)), sha, relative);
  for (const [file, sha] of Object.entries(frozen.system_files_raw_sha256)) assert.equal(raw(file), sha, file);
}
guard();
for (const relative of ['output', 'native-attempt-start.json', 'native.log', 'review-aids.log', 'candidate-receipt.json']) assert.equal(fs.existsSync(path.join(here, relative)), false, 'Preserve prior attempt: ' + relative);
const nativeArgs = ['--path', '.', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://build/professional-english/retail-term-art-review/cash-register-r04/candidate-r01/render-and-check.gd'];
fs.writeFileSync(path.join(here, 'native-attempt-start.json'), JSON.stringify({started_at: new Date().toISOString(), frozen_inputs_raw_sha256: frozenSha, root_native_slot: args[1], native_args: nativeArgs, scope: 'One scratch-only native candidate attempt. Preserve this marker even if interrupted.'}, null, 2) + '\n', {flag: 'wx'});
const started = Date.now();
let output = '', nativeError = null, guardError = null, resultError = null, aidError = null, report = null;
try {
  const result = require(path.join(root, 'tools/run-godot.cjs')).runGodot(nativeArgs, {timeout: 60000});
  output = (result.stdout || '') + (result.stderr || '');
} catch (error) { nativeError = String(error.stack || error); output = nativeError; }
fs.writeFileSync(path.join(here, 'native.log'), output, {flag: 'wx'});
try { guard(); } catch (error) { guardError = String(error.stack || error); }
try {
  const match = output.match(/Cash-register scratch candidate delivery: (\d+) checks, (\d+) failures/);
  assert(match && Number(match[1]) >= 60 && Number(match[2]) === 0);
  report = read(path.join(here, 'output/report.json'));
  assert.equal(report.status, 'candidate_probe_passed_pending_visual_review');
  assert.equal(report.failed, 0);
  assert.equal(report.checks.length, Number(match[1]));
  assert(report.checks.every(check => check.passed === true));
  assert.equal(report.production_acceptance, false);
  assert.equal(report.cue_visibility_acceptance, false);
  assert.equal(report.loaded_image_rgba_pixel_sha256, report.candidate_rgba_pixel_sha256);
  assert.equal(raw(path.join(here, 'output/cash-register.png')), report.resource.sha256);
  assert.equal(raw(path.join(here, 'output/fixture', report.resource.path)), report.resource.sha256);
  assert.equal(report.resource.width, 512);
  assert.equal(report.resource.decoded_bytes, report.resource.width * report.resource.height * 8);
  assert.equal(report.conversion.source_view.file, 'positive-z-right-low.png');
  assert.equal(report.conversion.source_view.sha256, '7b90fe5375e245c81c4297e246febbff42a8f85f231d56d9f60315d263fd34f8');
  assert.equal(report.conversion.picture_review, 'pending_root_visual_review');
  assert.equal(report.captures.length, 4);
  for (const [index, state] of ['match-unmatched', 'match-matched', 'memory-unmatched', 'memory-matched'].entries()) {
    const capture = report.captures[index];
    assert.equal(capture.state, state);
    assert.equal(raw(path.join(here, 'output', state + '.png')), capture.raw_sha256);
    assert.deepEqual(capture.card_size, index < 2 ? [126, 72] : [144, 74]);
    assert.deepEqual(capture.picture_size, index < 2 ? [102, 52] : [120, 54]);
    assert.equal(capture.badge_visible, index % 2 === 1);
    assert(Math.abs(capture.picture_alpha - (index % 2 === 1 ? 0.68 : 1)) < 0.00001);
    assert(Object.values(capture.cue_visibility).every(value => value === 'pending_root_visual_review'));
  }
  for (const key of ['resources', 'resident_bytes', 'pinned_bytes', 'reserved_bytes', 'leases']) assert.equal(report.released_cache[key], 0);
  assert.deepEqual(report.released_cache.active_ids, []);
  assert.equal(report.released_texture_reference, true);
  assert.equal(report.released_scoped_url, true);
} catch (error) { resultError = String(error.stack || error); }
if (!nativeError && !guardError && !resultError) {
  const aid = spawnSync(frozen.python_executable, [path.join(here, 'make-review-aids.py')], {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024});
  fs.writeFileSync(path.join(here, 'review-aids.log'), (aid.stdout || '') + (aid.stderr || ''), {flag: 'wx'});
  if (aid.error || aid.status !== 0 || aid.signal) aidError = String(aid.error || aid.stderr || 'Review aids failed');
  try { guard(); } catch (error) { guardError = String(error.stack || error); }
}
const artifacts = [];
function outputs(directory) {
  for (const item of fs.readdirSync(directory, {withFileTypes: true})) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) outputs(file);
    else artifacts.push({path: path.relative(here, file).replaceAll('\\', '/'), bytes: fs.statSync(file).size, sha256: raw(file)});
  }
}
if (fs.existsSync(path.join(here, 'output'))) outputs(path.join(here, 'output'));
const ok = !nativeError && !guardError && !resultError && !aidError;
const receipt = {schema: 1, status: ok ? 'candidate_ready_for_independent_visual_review' : 'failed_attempt_preserved', ok, scope: 'Scratch source conversion and actual Loader/cache/Access/WordArt/minimum WordCard path. Not production integration, image approval, complete round, or module readiness.', frozen_inputs_raw_sha256: frozenSha, native_timeout_ms: 60000, native_args: nativeArgs, duration_ms: Date.now() - started, native_error: nativeError, guard_error: guardError, result_error: resultError, review_aids_error: aidError, checks: report?.checks?.length || 0, failures: report?.failed ?? null, guarded_production_files: Object.keys(frozen.production_raw_sha256).length, guarded_inputs: Object.keys(frozen.inputs_raw_sha256).length, source_files_unchanged: !guardError, candidate_sha256: report?.resource?.sha256 || null, native_log_sha256: raw(path.join(here, 'native.log')), report_raw_sha256: fs.existsSync(path.join(here, 'output/report.json')) ? raw(path.join(here, 'output/report.json')) : null, artifacts, production_writes: false, production_unchanged: !guardError, image_acceptance: false, cue_visibility_acceptance: false, native_outputs_replay_allowed: false};
fs.writeFileSync(path.join(here, 'candidate-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(receipt, null, 2));
process.exitCode = ok ? 0 : 1;
