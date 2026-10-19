'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(path.join(root, file));
const write = (name, value) => fs.writeFileSync(path.join(__dirname, name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
const basePath = 'build/professional-english/continuation-validation-r32.json';
const baseline = JSON.parse(read(basePath));
assert.equal(hash(read(basePath)), '951167226fbfa4e362dbb415146385785fdc682115e0591b28e3cb30f81253d9');
assert.equal(baseline.ok, false);
assert.deepEqual(baseline.changed_measured_inputs, []);
assert.equal(baseline.runs.find(run => run.name === 'node').pass, 249);
assert.equal(baseline.runs.find(run => run.name === 'native-audio').failures, 0);
const testPath = 'tests/godot/professional_retail_morphology_tests.gd';
const savedBefore = fs.readFileSync(path.join(__dirname, 'professional_retail_morphology_tests.before.gd'));
assert.equal(hash(savedBefore), baseline.after_input_sha256[testPath]);
const beforeText = savedBefore.toString().replaceAll('\r\n', '\n');
const afterText = read(testPath).toString().replaceAll('\r\n', '\n');
const marker = '\t\tcheck(entry == snapshot.entry, "Persisted legacy entry equals its protected preimage: " + id)';
const inserted = [
'\t\telif id == "attendance.presence-record.n":',
'\t\t\tvar language_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module01-attendance-language-2026-10-17.json"))',
'\t\t\tvar language_patches: Array = language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == id)',
'\t\t\tcheck(language_patches.size() == 1, "Exactly one scoped Foundation attendance language patch is retained")',
'\t\t\tif language_patches.size() != 1:',
'\t\t\t\treturn',
'\t\t\tvar language_patch: Dictionary = language_patches[0]',
'\t\t\tcheck(entry == language_patch.after, "Live attendance equals the exact later Foundation language entry")',
'\t\t\tif entry != language_patch.after:',
'\t\t\t\treturn',
'\t\t\tentry = language_patch.before.duplicate(true)',
''].join('\n');
assert.equal(beforeText.split(marker).length, 2);
assert.equal(afterText, beforeText.replace(marker, inserted + marker));
const paths = Object.keys(baseline.after_input_sha256);
const measure = () => Object.fromEntries(paths.map(file => [file, hash(read(file))]));
const before = measure();
assert.deepEqual(paths.filter(file => before[file] !== baseline.after_input_sha256[file]), [testPath]);
const record = JSON.parse(read('data/professional/provenance/foundation-module01-attendance-language-2026-10-17.json'));
const patches = record.patches.filter(patch => patch.id === 'attendance.presence-record.n');
assert.equal(patches.length, 1);
const patch = patches[0];
const morphology = JSON.parse(read('data/professional/provenance/retail-module03-morphology-fourth10-2026-10-16.json'));
const snapshots = morphology.protected_related_entries.filter(snapshot => snapshot.entry.id === patch.id);
assert.equal(snapshots.length, 1);
const snapshot = snapshots[0];
assert.deepEqual(patch.before, snapshot.entry);
assert.deepEqual(patch.before.morphology, patch.after.morphology);
const live = JSON.parse(read(snapshot.resource.replace(/^res:\/\//, ''))).lexemes.filter(entry => entry.id === patch.id);
assert.equal(live.length, 1);
assert.deepEqual(live[0], patch.after);
const {loadProfessionalContent} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const registryBefore = hash(JSON.stringify(loadProfessionalContent(root)));
assert.equal(registryBefore, baseline.registry_after_sha256);
const args = ['tools/run-godot.cjs', '--headless', '--path', '.', '--script', 'res://' + testPath];
write('execution-inputs.json', {schema: 1, recorded_at: new Date().toISOString(), args, baseline_path: basePath, baseline_sha256: hash(read(basePath)), harness_sha256: hash(fs.readFileSync(__filename)), inputs: before});
const started = Date.now();
const result = spawnSync(process.execPath, args, {cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 32 * 1024 * 1024, windowsHide: true});
const output = (result.stdout || '') + (result.stderr || '');
write('native.log', output);
const match = output.match(/Professional Retail morphology: (\d+) checks, (\d+) failures/);
const after = measure();
const changed = paths.filter(file => before[file] !== after[file]);
const registryAfter = hash(JSON.stringify(loadProfessionalContent(root)));
const ok = result.status === 0 && !result.error && match && Number(match[1]) === 2839 && Number(match[2]) === 0 && changed.length === 0 && registryAfter === registryBefore;
const receipt = {schema: 1, recorded_at: new Date().toISOString(), ok: Boolean(ok), scope: 'Focused native morphology verification after a strict attendance historical-comparison correction. R32 remains a failed historical run. Its passing Node and audio results are unchanged and are not rerun or relabeled here. No production data, browser, performance, or module-readiness acceptance.', baseline_path: basePath, baseline_sha256: hash(read(basePath)), permitted_delta: testPath, permitted_delta_description: 'Require exactly one later attendance language patch and exact live equality with patch.after, then compare its deep-copied patch.before to the protected historical donor. All existing compiler and resolver assertions remain.', test_before_sha256: hash(savedBefore), test_after_sha256: before[testPath], registry_before_sha256: registryBefore, registry_after_sha256: registryAfter, measured_input_count: paths.length, changed_measured_inputs: changed, before_input_sha256: before, after_input_sha256: after, run: {args, status: result.status, signal: result.signal, error: result.error?.message || null, duration_ms: Date.now() - started, checks: match ? Number(match[1]) : -1, failures: match ? Number(match[2]) : -1, log: path.relative(root, path.join(__dirname, 'native.log')).replaceAll('\\', '/'), log_sha256: hash(output)}};
write('receipt.json', receipt);
console.log(JSON.stringify({ok: receipt.ok, status: receipt.run.status, checks: receipt.run.checks, failures: receipt.run.failures, measured_input_count: paths.length, changed, registry: registryAfter, receipt_sha256: hash(fs.readFileSync(path.join(__dirname, 'receipt.json')))}));
process.exitCode = ok ? 0 : 1;
