'use strict';
// Scratch-only exact input freeze. Does not invoke Godot or modify production.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const here = __dirname, base = path.resolve(here, '..'), root = path.resolve(base, '../../../..');
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const rel = file => path.relative(root, file).replaceAll('\\', '/');
assert.equal(process.cwd().toLowerCase(), root.toLowerCase());
for (const name of ['entry-preimage.json', 'root-source-review.json', 'frozen-inputs.json', 'preparation-receipt.json', 'native-attempt-start.json', 'output']) assert.equal(fs.existsSync(path.join(here, name)), false, 'Preserve previous preparation: ' + name);
const protectedDirectories = ['data/professional', 'scripts', 'professional-media', 'tests', 'assets/fonts'];
const protectedFiles = ['project.godot', 'export_presets.cfg', 'tools/run-godot.cjs', 'data/word-motion.json'];
function scan(directory, result = {}) {
  for (const item of fs.readdirSync(directory, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) scan(file, result);
    else result[rel(file)] = raw(file);
  }
  return result;
}
function production() {
  const result = {};
  for (const directory of protectedDirectories) Object.assign(result, scan(path.join(root, directory)));
  for (const file of protectedFiles) result[file] = raw(path.join(root, file));
  return result;
}
const before = production();
const source = read(path.join(base, 'source-record.json'));
assert.equal(raw(path.join(base, 'source-record.json')), '3e6184da75cd0fa51efaad7a47369c291b8ed920f1659a3c0d5b891e691149f0');
for (const file of source.files) assert.equal(raw(path.join(base, file.path)), file.sha256);
assert.equal(raw(path.join(base, source.acquisition.archive_path)), source.acquisition.archive_sha256);
const inspection = read(path.join(base, 'inspection-receipt.json'));
assert.equal(inspection.status, 'original_source_inspection_passed_pending_visual_review');
assert.equal(inspection.native_error, null);
assert.equal(inspection.guard_error, null);
assert.equal(raw(path.join(base, 'native-inspection-r01/report.json')), inspection.report_sha256);
const report = read(path.join(base, 'native-inspection-r01/report.json'));
assert.equal(report.captures.length, 6);
for (const capture of report.captures) assert.equal(raw(path.join(base, 'native-inspection-r01', capture.file)), capture.sha256);
const preferred = report.captures.find(capture => capture.file === 'positive-z-right-low.png');
assert.equal(preferred.sha256, '7b90fe5375e245c81c4297e246febbff42a8f85f231d56d9f60315d263fd34f8');
const entry = read(path.join(root, 'data/professional/lexemes/retail-pilot.json')).lexemes.find(item => item.id === 'cash-register.sales-device.n');
assert(entry);
assert.equal(entry.definition, 'A machine used to record sales and handle payments.');
assert.equal(entry.media.image.status, 'pending');
assert.equal(entry.media.image.path, null);
assert.equal(entry.media.image.review.status, 'pending');
assert.equal(entry.review.domain, 'pending');
assert.equal(entry.media.audio.sha256, '0f883c09be9a86be9f30e444953d001d3a385ba71034e60ceb4181fc0b9aa763');
const stages = ['render-and-check.gd', 'run-candidate.cjs', 'prepare-candidate.cjs', 'make-review-aids.py', 'README.md'];
for (const name of ['run-candidate.cjs', 'prepare-candidate.cjs']) {
  const result = spawnSync(process.execPath, ['--check', path.join(here, name)], {windowsHide: true, encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
}
const python = 'C:/ProgramData/Tools/Python/3.12.10/x64/python.exe';
const parsed = spawnSync(python, ['-c', 'import ast, pathlib; from PIL import Image; ast.parse(pathlib.Path(__import__("sys").argv[1]).read_text()); print("Python syntax and Pillow import passed")', path.join(here, 'make-review-aids.py')], {windowsHide: true, encoding: 'utf8'});
assert.equal(parsed.status, 0, parsed.stderr);
fs.writeFileSync(path.join(here, 'entry-preimage.json'), JSON.stringify(entry, null, 2) + '\n', {flag: 'wx'});
const sourceReview = {schema: 1, recorded_at: new Date().toISOString(), status: 'root_authorized_candidate_probe_only', reviewer: 'Codex root; source-only visual review communicated through collaboration', recorder: 'Codex source agent; records the parent instruction without upgrading its scope', root_instruction: 'Root ran original-source inspection once, passed all 1,074 protected files unchanged; six views reviewed visually. Source is promising: keypad, large display, bottom drawer/handle remain clearly visible. Prefer positive-z-right-low framing for candidate (positive-z-right-high secondary).', inspection_receipt_raw_sha256: raw(path.join(base, 'inspection-receipt.json')), inspection_report_raw_sha256: inspection.report_sha256, preferred_view: preferred, source_record_raw_sha256: raw(path.join(base, 'source-record.json')), source_review_scope: 'Original source only, before candidate conversion or minimum-card review.', production_acceptance: false, cue_visibility_at_minimum_size: 'pending', native_execution_owner: 'Codex root'};
fs.writeFileSync(path.join(here, 'root-source-review.json'), JSON.stringify(sourceReview, null, 2) + '\n', {flag: 'wx'});
const inputs = {};
for (const name of stages.concat(['entry-preimage.json', 'root-source-review.json'])) inputs[rel(path.join(here, name))] = raw(path.join(here, name));
for (const name of ['source-record.json', 'archive-inventory.json', 'primary-capture-receipt.json', 'source-page.html', 'creator-post.html', 'prepared-receipt.json', 'inspection-receipt.json', 'inspection.log', 'inspect-source.gd', 'run-inspection.cjs']) inputs[rel(path.join(base, name))] = raw(path.join(base, name));
Object.assign(inputs, scan(path.join(base, 'source')), scan(path.join(base, 'native-inspection-r01')));
for (const term of ['shopping-cart', 'shopping-basket']) for (const state of ['match-unmatched', 'match-matched', 'memory-unmatched', 'memory-matched']) {
  const file = path.resolve(base, '..', term, 'candidate', state + '.png');
  inputs[rel(file)] = raw(file);
}
const systemFiles = {'C:/Windows/Fonts/arial.ttf': raw('C:/Windows/Fonts/arial.ttf')};
assert.deepEqual(production(), before);
const frozen = {schema: 1, status: 'scratch_candidate_inputs_frozen_native_not_run', recorded_at: new Date().toISOString(), sense_id: entry.id, definition: entry.definition, example: entry.example, brief: entry.media.image.brief, lexemes_raw_sha256: raw(path.join(root, 'data/professional/lexemes/retail-pilot.json')), protected_directories: protectedDirectories, protected_files: protectedFiles, production_raw_sha256: before, inputs_raw_sha256: inputs, system_files_raw_sha256: systemFiles, python_executable: python, original_model_animations: [], source_acceptance_scope: 'Root source-only visual review; candidate, minimum-card, and production approval pending', next_native_stage: 'render-and-check.gd', native_run: false, production_writes: false};
fs.writeFileSync(path.join(here, 'frozen-inputs.json'), JSON.stringify(frozen, null, 2) + '\n', {flag: 'wx'});
const receipt = {schema: 1, status: 'candidate_harness_prepared_pending_root_native_execution', recorded_at: new Date().toISOString(), frozen_inputs_raw_sha256: raw(path.join(here, 'frozen-inputs.json')), source_review_raw_sha256: raw(path.join(here, 'root-source-review.json')), entry_preimage_raw_sha256: raw(path.join(here, 'entry-preimage.json')), harness_raw_sha256: raw(path.join(here, 'render-and-check.gd')), runner_raw_sha256: raw(path.join(here, 'run-candidate.cjs')), guarded_production_files: Object.keys(before).length, guarded_input_files: Object.keys(inputs).length, node_syntax_passed: true, python_syntax_and_pillow_import_passed: true, native_execution: 'not_run', production_changes: false, accepted_readiness: false};
fs.writeFileSync(path.join(here, 'preparation-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({...receipt, preparation_receipt_raw_sha256: raw(path.join(here, 'preparation-receipt.json'))}, null, 2));
