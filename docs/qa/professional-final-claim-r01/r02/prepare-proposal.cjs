'use strict';

// Static authoring only. This script never imports a runner or starts Godot.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const util = require('node:util');
const proposal = __dirname;
const root = path.resolve(proposal, '../../..');
const previous = path.join(root, 'build/professional-english/final-claim-after-preflight-r01');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const bytes = file => fs.readFileSync(file);
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const load = file => JSON.parse(bytes(file));
const write = (name, value) => fs.writeFileSync(path.join(proposal, name), typeof value === 'string' || Buffer.isBuffer(value) ? value : `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
const originalInventorySha256 = '96d02fb46ab915a5c519b9ba3591f7a208b054df5b20d7bd5aa5a62ecf483280';
const originalResultSha256 = 'e73e1432faa400033fa615028ace448d0f41bdb56d7c85580b2a6155d8d7b612';
const originalReceiptSha256 = '4d874bfb9ca40419b97cc06a10289bf13cf4f3d99c0b96df7218dfe5bc797eba';
const startedAt = new Date().toISOString();
const sourceSha256 = hash(bytes(__filename));
write('preparation-start.json', { schema: 1, attempt: 1, started_at: startedAt, source_sha256: sourceSha256, activity: 'Static source copying, narrow proposal editing, retained JSON comparison and hashing only.', native_or_runner_dispatch: false });

try {
  assert.equal(hash(bytes(path.join(previous, 'inventory.json'))), originalInventorySha256);
  assert.equal(hash(bytes(path.join(previous, 'attempt-001/result.json'))), originalResultSha256);
  assert.equal(hash(bytes(path.join(previous, 'attempt-001/receipt.json'))), originalReceiptSha256);
  const oldInventory = load(path.join(previous, 'inventory.json'));
  const oldInputs = load(path.join(previous, 'inputs.json'));
  const oldResult = load(path.join(previous, 'attempt-001/result.json'));
  const oldReceipt = load(path.join(previous, 'attempt-001/receipt.json'));
  for (const item of oldInventory.files) assert.equal(hash(bytes(path.join(previous, item.path))), item.sha256, `Frozen r01 source changed: ${item.path}`);
  for (const item of oldInputs.inputs) assert.equal(hash(bytes(path.join(root, item.path))), item.sha256, `Original runtime input changed: ${item.path}`);
  assert.equal(oldInputs.inputs.length, 559);
  assert.equal(oldResult.checks, 104);
  assert.equal(oldResult.failures, 1);
  assert.deepEqual(oldResult.assertions.filter(item => !item.ok), [{ message: 'Restoration retains the exact accepted progress', ok: false }]);
  assert.ok(util.isDeepStrictEqual(oldResult.observations.baseline.session_progress, oldResult.observations.restored.session.progress));
  const canonicalJson = value => Array.isArray(value)
    ? `[${value.map(canonicalJson).join(',')}]`
    : value && typeof value === 'object'
      ? `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`
      : JSON.stringify(value);
  const canonicalBefore = canonicalJson(oldResult.observations.baseline.session_progress);
  const canonicalAfter = canonicalJson(oldResult.observations.restored.session.progress);
  assert.equal(canonicalBefore, canonicalAfter);

  function replaceOnce(text, from, to) {
    assert.equal(text.split(from).length, 2, `Expected one source occurrence: ${from}`);
    return text.replace(from, to);
  }
  let probe = bytes(path.join(previous, 'probe.gd')).toString('utf8').replaceAll('\r\n', '\n').replaceAll('final-claim-after-preflight-r01', 'final-claim-after-preflight-r02');
  probe = replaceOnce(probe, 'const Medal = preload("res://scripts/medal_progress.gd")', 'const Medal = preload("res://scripts/medal_progress.gd")\nconst Progress = preload("res://scripts/professional_progress.gd")');
  probe = replaceOnce(probe, '\tbaseline["session_progress"] = progress.duplicate(true)', '\tbaseline["session_progress"] = progress.duplicate(true)\n\tbaseline["session_progress_types"] = _progress_type_profile(progress)');
  probe = replaceOnce(probe,
    '\tcheck(app.professional.session.snapshot().progress == baseline.session_progress, "Restoration retains the exact accepted progress")',
    '\tvar restored_progress: Dictionary = app.professional.session.snapshot().progress\n' +
    '\tvar baseline_canonical: String = Progress.canonical(baseline.session_progress)\n' +
    '\tvar restored_canonical: String = Progress.canonical(restored_progress)\n' +
    '\tobservations["progress_comparison"] = {\n' +
    '\t\t"raw_dictionary_equal": restored_progress == baseline.session_progress,\n' +
    '\t\t"canonical_equal": restored_canonical == baseline_canonical,\n' +
    '\t\t"baseline_canonical": baseline_canonical, "restored_canonical": restored_canonical,\n' +
    '\t\t"baseline_canonical_sha256": baseline_canonical.sha256_text(),\n' +
    '\t\t"restored_canonical_sha256": restored_canonical.sha256_text(),\n' +
    '\t\t"baseline_types": baseline.session_progress_types.duplicate(true),\n' +
    '\t\t"restored_types": _progress_type_profile(restored_progress)}\n' +
    '\tcheck(restored_canonical == baseline_canonical, "Restoration retains the exact accepted progress under persistence canonicalization")');
  const helper = `func _progress_type_profile(value: Variant, value_path: String = "$") -> Array:
\t# Capture types before JSON output erases StringName/String and int/float distinctions.
\tvar rows: Array = []
\tvar type_id: int = typeof(value)
\tif value is Dictionary:
\t\trows.append({"path": value_path, "role": "container", "type_id": type_id,
\t\t\t"type_name": type_string(type_id), "size": value.size()})
\t\tfor key in value:
\t\t\tvar child_path: String = value_path + "[" + JSON.stringify(str(key)) + "]"
\t\t\trows.append({"path": child_path, "role": "dictionary_key", "key": str(key),
\t\t\t\t"type_id": typeof(key), "type_name": type_string(typeof(key))})
\t\t\trows.append_array(_progress_type_profile(value[key], child_path))
\telif value is Array:
\t\trows.append({"path": value_path, "role": "container", "type_id": type_id,
\t\t\t"type_name": type_string(type_id), "size": value.size()})
\t\tfor index in range(value.size()):
\t\t\trows.append_array(_progress_type_profile(value[index], value_path + "[" + str(index) + "]"))
\telse:
\t\trows.append({"path": value_path, "role": "value", "type_id": type_id,
\t\t\t"type_name": type_string(type_id), "value": value})
\treturn rows


`;
  probe = replaceOnce(probe, 'func _saved_state() -> Dictionary:', helper + 'func _saved_state() -> Dictionary:');
  write('probe.gd', probe);
  write('probe_ui.gd', bytes(path.join(previous, 'probe_ui.gd')));
  write('probe_ui.tscn', bytes(path.join(previous, 'probe_ui.tscn')).toString('utf8').replaceAll('final-claim-after-preflight-r01', 'final-claim-after-preflight-r02'));
  write('assets.md', bytes(path.join(previous, 'assets.md')));
  // Retain all original production and fixture pins. This is not a rebase or recapture.
  write('inputs.json', bytes(path.join(previous, 'inputs.json')));
  let runner = bytes(path.join(previous, 'run-once.cjs')).toString('utf8').replaceAll('\r\n', '\n').replaceAll('final-claim-after-preflight-r01', 'final-claim-after-preflight-r02').replaceAll('rerun r01', 'rerun r02').replaceAll('consumes r01', 'consumes r02');
  runner = replaceOnce(runner, '|| !result.observations.restored) {',
    '|| !result.observations.restored\n' +
    '      || !result.observations.progress_comparison\n' +
    '      || result.observations.progress_comparison.canonical_equal !== true\n' +
    '      || !Array.isArray(result.observations.progress_comparison.baseline_types)\n' +
    '      || result.observations.progress_comparison.baseline_types.length === 0\n' +
    '      || !Array.isArray(result.observations.progress_comparison.restored_types)\n' +
    '      || result.observations.progress_comparison.restored_types.length === 0) {');
  write('run-once.cjs', runner);
  const attemptEvidence = fs.readdirSync(path.join(previous, 'attempt-001')).filter(name => fs.statSync(path.join(previous, 'attempt-001', name)).isFile()).sort().map(name => {
    const content = bytes(path.join(previous, 'attempt-001', name));
    return { path: `attempt-001/${name}`, sha256: hash(content), bytes: content.length };
  });
  for (const name of fs.readdirSync(path.join(previous, 'attempt-001/progress')).sort()) {
    const content = bytes(path.join(previous, 'attempt-001/progress', name));
    attemptEvidence.push({ path: `attempt-001/progress/${name}`, sha256: hash(content), bytes: content.length });
  }
  write('diagnosis-and-lineage.json', {
    schema: 1, status: 'static_diagnosis_and_unexecuted_correction_proposal',
    predecessor: { directory: 'build/professional-english/final-claim-after-preflight-r01', inventory_sha256: originalInventorySha256, files: oldInventory.files, retained_attempt_files: attemptEvidence, frozen_sources_modified: false },
    observed_failure: { checks: oldResult.checks, failures: oldResult.failures, assertion: oldResult.assertions.filter(item => !item.ok), native_exit_code: oldReceipt.steps.find(item => item.name === 'native-probe').status, result_sha256: originalResultSha256, receipt_sha256: originalReceiptSha256, result_note: 'r01 receipt.result is absent because the runner throws on native exit 1 before extracting the structured result. The retained result.json exists and was independently inspected.' },
    independent_retained_json_comparison: { deeply_equal: true, baseline_canonical_json_sha256: hash(canonicalBefore), restored_canonical_json_sha256: hash(canonicalAfter), baseline_sequence: oldResult.observations.baseline.session_progress.sequence, restored_sequence: oldResult.observations.restored.session.progress.sequence, baseline_skills: oldResult.observations.baseline.session_progress.skills, restored_skills: oldResult.observations.restored.session.progress.skills, method: 'Node deep comparison and sorted-key JSON serialization of already retained JSON; no Godot run and no claim to recover lost runtime Variant subtypes.' },
    code_evidence: [
      { path: 'scripts/professional_progress.gd', sha256: hash(bytes(path.join(root, 'scripts/professional_progress.gd'))), lines: [28, 48], finding: 'Production canonicalization stringifies dictionary keys and normalizes whole numeric values; its existing comment identifies StringName keys from property assignment versus String keys from parsed JSON.' },
      { path: 'scripts/professional_progress.gd', lines: [204, 232], finding: 'apply_event returns mutated progress, with integer sequence, exposures and streak assignments.' },
      { path: 'scripts/professional_store.gd', sha256: hash(bytes(path.join(root, 'scripts/professional_store.gd'))), lines: [183, 225], finding: 'record returns the in-memory applied progress; load returns state.progress from a fresh native read.' },
      { path: 'scripts/professional_store.gd', lines: [243, 264], finding: 'Native read parses persisted JSON before returning state.' },
      { path: 'scripts/professional_session.gd', sha256: hash(bytes(path.join(root, 'scripts/professional_session.gd'))), lines: [239, 245], finding: 'Session validates and duplicates returned progress on each relevant response.' }
    ],
    diagnosis: 'The single raw Dictionary assertion compares an in-memory event result with a later JSON-loaded representation. Retained JSON is structurally identical, and production already defines key/integer canonicalization for persistence. Representation mismatch is the supported explanation to test, not a proven runtime subtype diagnosis from r01.',
    correction: 'Replace only that progress assertion with equality under existing Progress.canonical. Retain raw equality as a diagnostic and capture every progress dictionary key and leaf value type before JSON serialization. No actual progress mutation is allowed by the canonical comparison.',
    diagnostic_limits: ['A passing r02 result is not assumed.', 'r01 JSON cannot reveal whether its mismatch came from StringName/String keys, int/float values, or their combination.', 'r02 captures type profiles without requiring a particular engine-specific subtype difference.', 'All original byte-preservation, model/control/resource/lease identity, context restoration, no-settlement and cleanup assertions remain active.'],
    changes: ['New revision paths and probe identifier.', 'Preload existing production Progress canonicalizer.', 'Capture baseline progress types before replacement.', 'Replace one raw session-progress assertion with canonical equality and retain raw/canonical/type diagnostics.', 'Add read-only recursive type-profile helper.', 'Require the new canonical comparison and nonempty type profiles in the runner success result.'],
    inherited_input_count: 559, inherited_input_drift: 0, inputs_recaptured: false,
    production_or_shared_tests_modified: false, godot_parser_run: false, native_probe_run: false, build_export_or_browser_run: false
  });
  let readme = bytes(path.join(previous, 'README.md')).toString('utf8').replaceAll('\r\n', '\n').replaceAll('final-claim-after-preflight-r01', 'final-claim-after-preflight-r02').replaceAll('frozen r01', 'frozen r02');
  readme = replaceOnce(readme,
    'Prepared on 2026-10-17. This directory is an isolated regression proposal. Its author has not run a parser, test, native game process, build, preparation, export, or storage transaction. The coordinating agent owns review and execution. No production script or shared test is changed by this proposal.',
    'Prepared on 2026-10-17. This is an unexecuted correction proposal derived from frozen r01. Its author performed static source editing, retained JSON comparison and hashing only, and has not run a Godot parser, test, native game process, build, export or storage transaction. The coordinating agent owns review and execution. No production script, shared test or frozen r01 file is changed.');
  readme = replaceOnce(readme, 'After asynchronous restoration, native progress/events/outbox must equal the accepted baseline, while the legitimate context write restores Retail.', 'After asynchronous restoration, native progress/events/outbox must equal the accepted baseline, while the legitimate context write restores Retail. In-memory session progress is compared with the existing production Progress.canonical function, preserving persisted values while normalizing StringName/String keys and integral numeric representation. Raw equality and complete key/value type profiles are retained for diagnosis.');
  readme += '\n## r01 failure and narrow r02 correction\n\nThe retained r01 run reached 104 checks and one failure: its raw session-progress Dictionary comparison. Baseline and restored progress in result.json are structurally identical, including sequence 1 and the accepted recognition streak/exposures. The result remains a failed r01 attempt. Its JSON cannot recover runtime Variant subtypes, so a StringName/String or int/float mismatch is a supported hypothesis rather than a proven cause. Production returns mutated progress after recording and JSON-parsed progress on restoration, and its existing Progress.canonical explicitly normalizes these representations.\n\nThis revision changes only the session-progress assertion to canonical equality and adds read-only type observations. The baseline profile is captured before replacement; restored types and both canonical values/hashes come from the same restored snapshot used by the assertion. All key types and leaf value types are recorded with paths before JSON serialization can erase them. Raw equality remains an observation, not a pass requirement. A particular type mismatch is not forced. Every original model/control/resource/lease, exact synchronous file-byte, native progress/events/outbox, no-settlement and cleanup assertion remains active.\n\nThe seven original proposal files and all retained r01 attempt outputs are pinned in diagnosis-and-lineage.json. The original 559-input ledger is inherited byte-for-byte and currently has zero drift; no production input was recaptured or rebased. inventory.json also binds this static preparation source and its receipts. The proposal runner has not been invoked, and attempt-001 does not exist in r02. Any execution result, including its type evidence, must be reviewed before claiming this gap is closed.\n\nIf native execution fails, retain and inspect attempt-001/result.json directly when present: the inherited runner throws on nonzero native exit before adding receipt.result. This behavior is recorded, not silently changed by this narrow revision. Do not replay r01 or reuse a consumed r02 attempt.\n';
  write('README.md', readme);
  assert.equal(hash(bytes(__filename)), sourceSha256);
  // Assert r01 and inherited runtime pins remained exact through static authoring.
  for (const item of oldInventory.files) assert.equal(hash(bytes(path.join(previous, item.path))), item.sha256);
  for (const item of oldInputs.inputs) assert.equal(hash(bytes(path.join(root, item.path))), item.sha256);
  for (const item of attemptEvidence) assert.equal(hash(bytes(path.join(previous, item.path))), item.sha256);
  write('preparation-result.json', { schema: 1, status: 'completed_once_proposal_unexecuted', started_at: startedAt, completed_at: new Date().toISOString(), source_sha256: sourceSha256, executed_source_equality_verified: true, predecessor_source_files_verified: 7, predecessor_attempt_files_verified: attemptEvidence.length, inherited_inputs_verified: 559, inherited_input_drift: 0, retained_json_deep_equal: true, godot_parser_run: false, native_or_runner_dispatch: false, production_mutated: false });
  const files = fs.readdirSync(proposal).sort().filter(name => name !== 'inventory.json').map(name => { const content = bytes(path.join(proposal, name)); return { path: name, sha256: hash(content), bytes: content.length }; });
  write('inventory.json', { schema: 1, status: 'frozen-prepared-not-executed', date: '2026-10-17', scope: 'r02 narrow canonical session-progress assertion and runtime type diagnostics; inherited real lifecycle and all preservation guards; static authoring only.', predecessor_inventory_sha256: originalInventorySha256, excludes: ['inventory.json', 'future attempt-001 output'], files });
  console.log(JSON.stringify({ status: 'frozen-prepared-not-executed', inventory_sha256: hash(bytes(path.join(proposal, 'inventory.json'))), probe_sha256: hash(bytes(path.join(proposal, 'probe.gd'))), runner_sha256: hash(bytes(path.join(proposal, 'run-once.cjs'))), proposal_file_count: files.length, input_count: 559, production_or_native_dispatch: false }, null, 2));
} catch (error) {
  write('preparation-failure.json', { schema: 1, status: 'failed_static_preparation_do_not_replay', source_sha256: sourceSha256, error: String(error.stack || error), native_or_runner_dispatch: false });
  throw error;
}
