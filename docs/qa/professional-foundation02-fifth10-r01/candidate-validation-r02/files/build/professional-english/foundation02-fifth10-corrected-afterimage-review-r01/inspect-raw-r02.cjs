'use strict';
// Independent raw-data inspection only. No project or proposal code is imported.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const util = require('node:util');
const ROOT = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const OWN = 'build/professional-english/foundation02-fifth10-corrected-afterimage-review-r01';
const OLD = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03/execution-r01';
const NEW = 'build/professional-english/foundation02-fifth10-delivery-preparation-r04/execution-r01';
const REPAIR = 'build/professional-english/foundation02-fifth10-root-native-route-repair-r01';
const SOURCE = 'build/professional-english/foundation02-fifth10-native-route-repair-proposal-r01';
const PRIOR = 'build/professional-english/foundation02-fifth10-afterimage-independent-review-r01';
const BINDING = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r02/execution-r01/actual-baseline-binding.json';
const TARGET = 'tests/godot/professional_retail_morphology_tests.gd';
const NATIVE = 'professional_retail_morphology_tests.gd.after';
const EXPECTED_CHANGED = ['execution-end.json', 'execution-start.json', 'preparation-receipt.json', NATIVE, 'target-plan.json', 'test-edit-ledger.json'].sort();
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const clone = v => JSON.parse(JSON.stringify(v));
const observed = new Map(), findings = [], measurements = {};
let checks = 0;
function check(value, message) { checks++; if (!value) { findings.push(message); throw new Error(message); } }
function equal(a, b, message) { check(util.isDeepStrictEqual(a, b), message); }
function at(p) {
  if (typeof p !== 'string' || p.includes('\\') || p.includes(':') || p.split('/').some(x => !x || x === '.' || x === '..')) throw new Error('Unsafe review path: ' + p);
  const absolute = path.resolve(ROOT, p); if (!absolute.startsWith(path.resolve(ROOT) + path.sep)) throw new Error('Escaped root: ' + p);
  return absolute;
}
function raw(p) {
  const absolute = at(p), stat = fs.lstatSync(absolute);
  check(stat.isFile() && !stat.isSymbolicLink(), 'Regular file: ' + p);
  const bytes = fs.readFileSync(absolute), pin = {path: p, bytes: bytes.length, raw_sha256: sha(bytes)};
  if (observed.has(p)) equal(pin, observed.get(p), 'Unchanged repeat read: ' + p); else observed.set(p, pin);
  return bytes;
}
function json(p) { return JSON.parse(raw(p)); }
function pin(p) { raw(p); return observed.get(p); }
function verify(ref) { const bytes = raw(ref.path); equal(bytes.length, ref.bytes, 'Pinned byte count: ' + ref.path); equal(sha(bytes), ref.raw_sha256, 'Pinned hash: ' + ref.path); return bytes; }
function absent(p) { let found = true; try { fs.lstatSync(at(p)); } catch (e) { if (e.code !== 'ENOENT') throw e; found = false; } check(!found, 'Must remain absent: ' + p); }
function listing(p) {
  const result = [];
  function walk(prefix) {
    for (const ent of fs.readdirSync(at(prefix), {withFileTypes: true})) {
      check(!ent.isSymbolicLink(), 'No linked member: ' + prefix + '/' + ent.name);
      if (ent.isDirectory()) walk(prefix + '/' + ent.name);
      else { check(ent.isFile(), 'Regular directory member: ' + ent.name); result.push((prefix + '/' + ent.name).slice(p.length + 1)); }
    }
  }
  walk(p); return result.sort();
}
function unique(rows, label) { equal(new Set(rows.map(x => x.toLowerCase())).size, rows.length, label); }
function verifyRefs(value) {
  if (!value || typeof value !== 'object') return;
  if (!Array.isArray(value) && typeof value.path === 'string' && Number.isInteger(value.bytes) && typeof value.raw_sha256 === 'string') { verify(value); return; }
  for (const child of Object.values(value)) verifyRefs(child);
}
const attempt = OWN + '/inspection-r02';
if (fs.existsSync(at(attempt))) throw new Error('Do not overwrite an inspection attempt.');
fs.mkdirSync(at(attempt));
function save(name, value) { if (!name.startsWith(attempt + '/')) throw new Error('Review output confinement'); fs.writeFileSync(at(name), encode(value), {flag: 'wx'}); }
let error = null;
try {
  raw(OWN + '/inspect-raw-r02.cjs');
  const witness = json(REPAIR + '/dispatch-r01/witness.json');
  equal(pin(REPAIR + '/dispatch-r01/witness.json').raw_sha256, '72a06095d9e8c71cad165e228e8366a5d3e80f7419457968ac79a7fa51bee405', 'Root-reported witness pin');
  equal(pin(REPAIR + '/execution-r01/correction-receipt.json').raw_sha256, '539f1ecce9a3ff4bf72c299251f4f44b3981e164ddc0105324ba2ecc498e91f8', 'Root-reported correction receipt pin');
  equal(pin(REPAIR + '/execution-r01/attempt-end.json').raw_sha256, 'fdefa34ad5be6d7e5f65d6a0728ec102c2578d98a9b9ad45ea7fab26b5856f7e', 'Root-reported correction end pin');
  equal(witness.kind, 'native-route-repair', 'Actual witness kind'); equal(witness.dispatcher, '/root', 'Root dispatcher');
  equal([witness.exit_code, witness.signal, witness.error, witness.token_retained, witness.replay_allowed], [0, null, null, false, false], 'Successful non-replayable repair witness');
  verifyRefs(witness);
  const input = json(REPAIR + '/input.json'), contract = json(REPAIR + '/contract.json');
  equal(input.contract, contract, 'Actual input and exact contract');
  equal(input.status, 'bound_for_root_native_route_repair', 'Bound repair input');
  equal([input.dispatcher, input.author, input.writer_window, input.recovery], ['/root', '/root/recover_delivery', 'root-exclusive', false], 'Repair roles and writer scope');
  equal(contract.attempt_dir, REPAIR + '/execution-r01', 'Repair attempt path'); equal(contract.output_dir, NEW, 'Corrected output path');
  verifyRefs(contract); verify(input.independent_review);
  const sourceReview = json(input.independent_review.path);
  equal(sourceReview.accepted, true, 'Accepted repair source contract'); equal(sourceReview.contract_sha256, sha(encode(contract)), 'Exact reviewed contract');
  equal(sourceReview.source_sha256, witness.source.raw_sha256, 'Exact reviewed repair source');
  const sourceInventory = json(contract.source_inventory.path);
  for (const row of sourceInventory.files) verify({...row, path: SOURCE + '/' + row.path});
  const correction = json(witness.receipt.path), end = json(witness.attempt_end.path);
  equal(correction.status, 'corrected_preparation_pending_fresh_afterimage_review_and_root_validation', 'Correction status');
  equal(end.status, 'corrected_preparation_pending_validation', 'Repair end status');
  for (const k of ['production_mutated', 'project_or_test_execution', 'native_executed', 'actual_fifth10_commit', 'actual_fifth10_persisted_validation', 'original_preparation_replayed']) equal(correction[k], false, 'Correction does not claim ' + k);
  verifyRefs(correction);
  equal(correction.root_input, witness.input, 'Correction input and dispatch input');
  equal(correction.source_inventory, contract.source_inventory, 'Correction source inventory');
  equal(correction.independent_source_review, input.independent_review, 'Correction source review');
  const oldManifest = json(contract.original_output_manifest.path), newManifest = json(correction.output_manifest.path);
  equal([oldManifest.original_directory, oldManifest.file_count, oldManifest.files.length], [OLD, 835, 835], 'Original manifest scope');
  equal([newManifest.directory, newManifest.count, newManifest.files.length], [NEW, 835, 835], 'Corrected manifest scope');
  unique(oldManifest.files.map(r => r.path), 'Original names unique'); unique(newManifest.files.map(r => r.path), 'Corrected names unique');
  equal(listing(OLD), oldManifest.files.map(r => r.path).sort(), 'Original complete directory closure');
  equal(listing(NEW), oldManifest.files.map(r => r.path).sort(), 'Corrected complete directory closure');
  equal(newManifest.files.map(r => r.path).sort(), oldManifest.files.map(r => NEW + '/' + r.path).sort(), 'Same 835 output names');
  const correctedByPath = new Map(newManifest.files.map(r => [r.path, r]));
  const changed = [];
  for (let i = 0; i < oldManifest.files.length; i++) {
    const oldRow = oldManifest.files[i], newRow = correctedByPath.get(NEW + '/' + oldRow.path);
    const before = verify({...oldRow, path: OLD + '/' + oldRow.path}), after = verify(newRow);
    if (!before.equals(after)) changed.push(oldRow.path);
  }
  equal(changed.sort(), EXPECTED_CHANGED, 'Exactly six changed output files');
  equal(correction.changed_output_paths, EXPECTED_CHANGED, 'Correction reports exact change set');
  equal([correction.copied_byte_exact_output_count, correction.output_count, correction.target_count, correction.replacement_count, correction.retained_addition_count, correction.pending_finalization_count, correction.changed_target_afterimage_count], [829, 835, 823, 6, 815, 2, 1], 'Correction exact counts');
  const oldReceipt = json(OLD + '/preparation-receipt.json'), receipt = json(NEW + '/preparation-receipt.json');
  equal(receipt.status, 'prepared_pending_independent_afterimage_review_and_root_validation', 'Prepared status remains scoped');
  equal(receipt.artifacts.length, 833, '833 receipt artifacts');
  equal(receipt.artifacts.map(r => r.path).sort(), oldManifest.files.map(r => r.path).filter(p => !['preparation-receipt.json', 'execution-end.json'].includes(p)).sort(), 'Artifact set excludes only receipt and end');
  for (const row of receipt.artifacts) verify({...row, path: NEW + '/' + row.path});
  const restoredReceipt = clone(receipt); delete restoredReceipt.correction_lineage;
  restoredReceipt.source_inventory = oldReceipt.source_inventory; restoredReceipt.independent_source_review = oldReceipt.independent_source_review; restoredReceipt.artifacts = oldReceipt.artifacts;
  equal(restoredReceipt, oldReceipt, 'Receipt changes only source lineage/artifact pins');
  equal(receipt.actual_binding, contract.actual_binding, 'Prepared binding unchanged');
  equal(receipt.source_inventory, contract.source_inventory, 'Prepared source inventory');
  equal(receipt.independent_source_review, input.independent_review, 'Prepared source review');
  equal(receipt.correction_lineage, correction.lineage, 'Exact shared correction lineage');
  const lineage = receipt.correction_lineage;
  equal(lineage.original_preparation_receipt, pin(OLD + '/preparation-receipt.json'), 'Original receipt lineage');
  equal(lineage.original_execution_end, pin(OLD + '/execution-end.json'), 'Original end lineage');
  equal(lineage.original_source_inventory, oldReceipt.source_inventory, 'Original inventory lineage');
  equal(lineage.original_independent_source_review, oldReceipt.independent_source_review, 'Original review lineage');
  equal(lineage.original_root_input, json(OLD + '/execution-start.json').root_input, 'Original root input lineage');
  equal(lineage.correction_root_input, witness.input, 'Correction root input lineage');
  equal(lineage.correction_receipt_path, witness.receipt.path, 'External correction receipt lineage');
  equal(lineage.failed_native_receipt, contract.failed_native_receipt, 'Failed native evidence lineage');
  equal(lineage.rejected_candidate_review, contract.failed_candidate_review, 'Failed review lineage');
  for (const k of ['production_provenance_inherited_byte_exact', 'production_document_inherited_byte_exact', 'projection_observation_inherited_byte_exact']) equal(lineage[k], true, 'Lineage preserved ' + k);
  for (const k of ['original_preparation_replayed', 'candidate_validation_reused_as_success', 'actual_installation', 'persisted_validation']) equal(lineage[k], false, 'Lineage excludes ' + k);
  const start = json(NEW + '/execution-start.json'), preparedEnd = json(NEW + '/execution-end.json');
  equal(start.root_input, witness.input, 'Prepared start binds actual repair'); equal(start.actual_binding, contract.actual_binding, 'Prepared start binding');
  equal(start.source_inventory, contract.source_inventory, 'Prepared start source'); equal(start.independent_source_review, input.independent_review, 'Prepared start source review');
  equal(start.original_preparation_receipt, lineage.original_preparation_receipt, 'Prepared start original receipt');
  equal([start.operation, preparedEnd.operation], [lineage.kind, lineage.kind], 'Prepared start/end correction kind');
  equal([preparedEnd.status, preparedEnd.production_mutated, preparedEnd.project_or_test_execution], ['prepared_pending_independent_review', false, false], 'Prepared end scope');
  const binding = json(BINDING); equal(binding.input_files.length, 12443, '12443 baseline inputs');
  equal(pin(BINDING).raw_sha256, '7323bcb1baac6ea85817169bcc90325f9b54d587b19d4895ca3106ee7af0e015', 'Actual baseline binding pin');
  const oldPlan = json(OLD + '/target-plan.json'), plan = json(NEW + '/target-plan.json');
  equal(plan.targets.length, 823, '823 targets'); unique(plan.targets.map(r => r.path), 'Target paths unique');
  equal(plan.targets.map(r => r.path).sort(), binding.target_paths.slice().sort(), 'Exact bound target paths');
  equal(plan.targets.filter(r => r.operation !== 'replace').map(r => r.path).sort(), binding.must_remain_absent.slice().sort(), 'Exact absent addition set');
  equal(plan.targets.filter(r => r.operation === 'replace').length, 6, 'Six replacements');
  equal(plan.targets.filter(r => r.operation === 'add_absent').length, 815, '815 retained additions');
  equal(plan.targets.filter(r => r.operation === 'add_absent_pending_actual_stage_finalization').length, 2, 'Two unfinalized metadata files');
  const restoredPlan = clone(plan), oldTarget = oldPlan.targets.find(r => r.path === TARGET), newTarget = plan.targets.find(r => r.path === TARGET);
  const restoredTarget = restoredPlan.targets.find(r => r.path === TARGET); restoredTarget.bytes = oldTarget.bytes; restoredTarget.after_sha256 = oldTarget.after_sha256;
  equal(restoredPlan, oldPlan, 'Only native target bytes/hash change');
  for (const row of plan.targets) {
    const b = raw(NEW + '/' + row.artifact); equal(b.length, row.bytes, 'Target bytes: ' + row.path); equal(sha(b), row.after_sha256 || row.prepared_sha256, 'Target afterimage hash: ' + row.path);
    if (row.operation === 'replace') equal(sha(raw(row.path)), row.before_sha256, 'Production replacement still preimage: ' + row.path);
    else absent(row.path);
    if (row.operation === 'add_absent') check(b.equals(raw(row.source)), 'Retained exact source: ' + row.path);
  }
  const edit = json(contract.route_edit.path), beforeNative = raw(OLD + '/' + NATIVE).toString(), afterNative = raw(NEW + '/' + NATIVE).toString();
  equal(edit.target, TARGET, 'Only declared native target'); equal(edit.occurrences, 1, 'One edit occurrence');
  equal(beforeNative.split(edit.before).length - 1, 1, 'Unique original assertion');
  equal(beforeNative.replace(edit.before, edit.after), afterNative, 'Only exact safe-only assertion replacement');
  equal(raw(NEW + '/' + NATIVE), verify(contract.corrected_native_afterimage), 'Actual native equals accepted source proposal');
  equal(afterNative.length - beforeNative.length, 250, 'Exact native delta');
  equal(afterNative.split('check(').length, beforeNative.split('check(').length, 'Check call count preserved');
  equal(edit.after, '\t\tvar broad_language: Dictionary = {"ok": true, "entry": entry}\n\t\tif id == "safe.free-from-unacceptable-danger.adj":\n\t\t\tbroad_language = _f02_fifth_reverse(entry)\n\t\tcheck(broad_language.ok and broad_language.entry == snapshot.entry and entry.morphology == snapshot.entry.morphology and entry.morphology.review.status == "pending" and not Analysis.compile(entry.morphology).ok, "Related broad Professional graph remains its exact pending preimage: " + id)', 'Reviewed safe-only assertion text');
  check(afterNative.includes('if entry != patch.before and entry != patch.after:\n\t\treturn {"ok": false}\n\treturn {"ok": true, "entry": patch.before.duplicate(true)}'), 'Existing full-entry exact reversal and independent clone retained');
  const oldLedger = json(OLD + '/test-edit-ledger.json'), ledger = json(NEW + '/test-edit-ledger.json'), restoredLedger = clone(ledger);
  const popped = restoredLedger.files.find(r => r.path === TARGET).edits.pop();
  equal(popped, {name: edit.name, occurrences: 1, before: edit.before, after: edit.after}, 'Ledger adds exact reviewed edit'); equal(restoredLedger, oldLedger, 'All prior ledger unchanged');
  const provenance = json(NEW + '/production-provenance.prepared.json'), envelope = json(NEW + '/foundation-module02.json.after'), currentEnvelope = json('data/professional/lexemes/foundation-module02.json');
  equal(provenance.patches.length, 8, 'Eight accepted lexical projections'); equal(provenance.held.length, 6, 'Six complete holds'); equal(provenance.history.rows.length, 50, 'Fifty donor rows');
  const index = new Map(envelope.lexemes.map(r => [r.id, r])); const current = new Map(currentEnvelope.lexemes.map(r => [r.id, r]));
  for (const patch of provenance.patches) {
    equal(index.get(patch.id), patch.after, 'Exact accepted projection: ' + patch.id); equal(current.get(patch.id), patch.before, 'Actual prior entry: ' + patch.id);
    equal(patch.after.morphology, patch.before.morphology, 'Morphology unchanged: ' + patch.id); equal(patch.after.media, patch.before.media, 'Media unchanged: ' + patch.id); equal(patch.after.review.domain, patch.before.review.domain, 'Domain gate unchanged: ' + patch.id);
  }
  for (const hold of provenance.held) { equal(index.get(hold.id), hold.before_entry, 'Complete held entry: ' + hold.id); equal(current.get(hold.id), hold.before_entry, 'Production held entry: ' + hold.id); equal(sha(JSON.stringify(hold.before_entry)), hold.entry_json_sha256, 'Held hash: ' + hold.id); }
  const restoredEnvelope = clone(envelope); for (const patch of provenance.patches) restoredEnvelope.lexemes[restoredEnvelope.lexemes.findIndex(r => r.id === patch.id)] = patch.before;
  equal(restoredEnvelope, currentEnvelope, 'No other lexical field or envelope change');
  for (const row of provenance.history.rows) {
    const history = json(row.history_path), rows = history.protected_context.lexemes;
    equal(rows.filter(r => r.entry.id === row.id).length, 1, 'Unique whole historical donor: ' + row.history_path + '/' + row.id);
    equal(rows[row.index], row.whole_row, 'Exact indexed whole donor row: ' + row.id); equal(sha(JSON.stringify(rows[row.index])), row.whole_row_json_sha256, 'Whole donor row hash: ' + row.id);
    equal(sha(JSON.stringify(row.whole_row.entry)), row.whole_row.json_sha256, 'Historical entry hash: ' + row.id);
  }
  const safe = provenance.patches.find(r => r.id === 'safe.free-from-unacceptable-danger.adj');
  const broadHistory = json('data/professional/provenance/retail-module03-morphology-fifth10-2026-10-16.json');
  equal(broadHistory.protected_related_entries.find(r => r.entry.id === safe.id).entry, safe.before, 'Safe broad donor is exact old state');
  equal(safe.after.morphology.review.status, 'pending', 'Safe morphology stays pending');
  const prior = json(PRIOR + '/review.json'); equal(prior.findings, [], 'Prior afterimage content review has no findings');
  equal(pin(PRIOR + '/projected-review.json').raw_sha256, '65672f5349b942ae7d3b1c7f388d29561a141d0ddb58259511f6e7202ec4a854', 'Immutable prior projected acceptance');
  equal(pin(PRIOR + '/native-review.json').raw_sha256, 'cbfb692c19949c7bd5d138b91343fef429b9f3bd70b11cfb7c810a92f13b1ffc', 'Immutable prior native afterimage acceptance');
  const failed = json(contract.failed_native_receipt.path), failedReview = json(contract.failed_candidate_review.path);
  equal([failed.ok, failed.status, failed.postcheck_error, failed.production_mutated], [false, 'isolated_native_candidate_failed', null, false], 'Original native failure remains failure');
  equal(failed.commands[1].exit_code, 1, 'Original native suite failed'); equal(failedReview.accepted, false, 'Original actual candidate rejection retained');
  const observations = json(correction.source_observations.path); equal(observations.inputs.length, 13292, '13292 original repair observations'); unique(observations.inputs.map(r => r.path), 'Repair observations unique');
  for (const row of binding.input_files) verify(row);
  for (const row of observations.inputs) verify(row);
  for (const p of binding.must_remain_absent) absent(p);
  for (const p of ['build/professional-english/transactions/foundation02-fifth10-language-r01', 'build/professional-english/transactions/active-transaction.json', 'docs/content-review/foundation-module02-language-fifth10-2026-10-17/commit-receipt.json']) absent(p);
  equal(provenance.production_integrated, false, 'Prepared provenance not integrated');
  equal([provenance.lineage.fifth10_commit_receipt, provenance.lineage.fifth10_persisted_receipt], [null, null], 'No installation or persisted lineage');
  measurements.output_count = 835; measurements.byte_identical_outputs = 829; measurements.changed_outputs = changed;
  measurements.targets = 823; measurements.retained_files = 815; measurements.replacements = 6; measurements.pending_finalizations = 2;
  measurements.baseline_files = 12443; measurements.repair_observations = 13292; measurements.accepted_entries = 8; measurements.whole_holds = 6; measurements.whole_donor_rows = 50;
  measurements.expected_callbacks = 263; measurements.expected_native_checks = 3922;
} catch (e) { error = e.stack || String(e); if (!findings.length) findings.push(String(e)); }
const beforePostcheck = [...observed.values()]; let rehashed = 0;
for (const row of beforePostcheck) {
  try { const b = fs.readFileSync(at(row.path)); check(b.length === row.bytes && sha(b) === row.raw_sha256, 'Final unchanged raw input: ' + row.path); rehashed++; }
  catch (e) { if (!error) error = e.stack || String(e); if (!findings.includes(String(e))) findings.push(String(e)); }
}
save(attempt + '/inputs.json', {schema: 1, files: [...observed.values()].sort((a, b) => a.path.localeCompare(b.path))});
save(attempt + '/inspection.json', {schema: 1, reviewer: '/root/commit_review', ok: error === null && findings.length === 0, comparisons_passed: checks - findings.length, findings, error, measurements, inputs_rehashed_at_end: rehashed, scope: {raw_hash_json_text_only: true, project_or_proposal_imports: false, project_tests_or_native_execution: false, production_mutated: false, candidate_success_accepted: false, installation_or_persisted_accepted: false}, inspection_history: [{tool_chunk: '96dfd4', outcome: 'Inspection r01 stopped on reviewer-only manifest order assumption. Original locale order and corrected code-point order differ; exact path sets match. R01 source and failed result preserved. This revision compares keyed paths and exact bytes.'}, {tool_chunk: '1fc83f', outcome: 'PowerShell parse error before data reads or writes; corrected read-only listing followed.'}, {tool_chunk: 'fb81e6', outcome: 'Raw source reconnaissance attempted an uninstalled future provenance destination and received ENOENT; no mutation. Main inspection resolves retained artifacts through the prepared target plan.'}]});
console.log(JSON.stringify({ok: error === null && findings.length === 0, comparisons: checks, findings, error, inputs_rehashed_at_end: rehashed, measurements}));
process.exitCode = error === null && findings.length === 0 ? 0 : 1;
