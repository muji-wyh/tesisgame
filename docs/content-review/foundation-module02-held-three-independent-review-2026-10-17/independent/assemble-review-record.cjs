'use strict';
// Reviewer-record assembly only. No project modules, production writes or test dispatch.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const relativeOut = 'build/professional-english/foundation02-held-three-independent-review-r01';
const out = path.resolve(root, relativeOut);
const author = 'build/professional-english/foundation02-held-six-research-r01';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const objectSha = value => sha(JSON.stringify(value));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const assert = (condition, message) => { if (!condition) throw new Error(message); };
assert(path.resolve(__dirname).toLowerCase() === out.toLowerCase(), 'Unexpected assembly directory');
assert(path.resolve(process.cwd()).toLowerCase() === path.resolve(root).toLowerCase(), 'Unexpected working directory');
const read = relative => fs.readFileSync(path.join(root, relative));
const parse = relative => JSON.parse(read(relative));
const local = name => parse(relativeOut + '/' + name);
const permittedOutputs = new Set(['input-verification.json', 'language-projections.json', 'context-checks.json', 'assembly-receipt.json']);
for (const name of permittedOutputs) assert(!fs.existsSync(path.join(out, name)), 'Preserve existing record: ' + name);
assert(!fs.existsSync(path.join(out, 'inventory.json')), 'Review is already frozen');
const sourceBefore = sha(fs.readFileSync(__filename));
const startedAt = new Date().toISOString();
const inventoryBytes = read(author + '/inventory.json');
const expectedAuthorInventory = '68813f88a92eefba3ac1f03921ce2080c65cec6f989d8988f14e4a6958923d22';
assert(sha(inventoryBytes) === expectedAuthorInventory, 'Author inventory hash changed');
const inventory = JSON.parse(inventoryBytes);
assert(inventory.files.length === 15, 'Unexpected author inventory count');
const authorChecks = inventory.files.map(record => {
  const raw = read(author + '/' + record.path);
  const actual = { path: record.path, bytes: raw.length, sha256: sha(raw) };
  assert(actual.bytes === record.bytes && actual.sha256 === record.sha256, 'Author artifact changed: ' + record.path);
  return actual;
});
const context = parse(author + '/context.json');
const proposal = parse(author + '/proposal-fields.json');
const pins = parse(author + '/input-pins.json');
const evidenceBytes = read(relativeOut + '/fresh-independent-http.json');
assert(sha(evidenceBytes) === 'ec0925018bc4a19645c6e1b7c1c0695acc6f05241d373d884f5815e322d1ba84', 'Fresh source receipt changed');
const decisions = local('reviewer-decisions.json');
const observations = local('source-observations.json');
assert(decisions.decisions.length === 3 && decisions.remaining_holds.length === 3, 'Expected three decisions and three unchanged holds');
assert(same(decisions.accepted_scope, ['definition', 'example', 'difficulty']), 'Unexpected accepted scope');
const currentPinRows = pins.files.map(record => {
  const raw = read(record.path);
  return { path: record.path, bytes: raw.length, sha256: sha(raw), author_bytes: record.bytes, author_sha256: record.sha256, matches_author: raw.length === record.bytes && sha(raw) === record.sha256 };
});
assert(currentPinRows.length === 353, 'Unexpected author input count');
const uniquePins = new Map();
for (const row of currentPinRows) {
  if (uniquePins.has(row.path)) assert(same(uniquePins.get(row.path), row), 'Inconsistent duplicate pin');
  else uniquePins.set(row.path, row);
}
assert(uniquePins.size === 352, 'Unexpected unique input count');
const currentModule = parse('data/professional/lexemes/foundation-module02.json');
const frozenModule = parse(author + '/foundation-module02.before.json');
const sixCurrent = context.entries.map(record => {
  const entry = currentModule.lexemes.find(item => item.id === record.id);
  assert(entry && objectSha(entry) === record.object_sha256 && same(entry, record.entry), 'Held entry changed: ' + record.id);
  assert(entry.review.status === 'pending' && entry.review.language === 'pending', 'Whole-entry hold changed');
  return { id: record.id, before_entry_sha256: record.object_sha256, current_entry_sha256: objectSha(entry), current_entry: entry };
});
const oldReviews = [1, 2, 3].map(index => parse(author + '/retained-reviews/' + index + '.json'));
const oldHolds = oldReviews.flatMap((review, index) => (review.held || review.entries).filter(row => context.entries.some(entry => entry.id === row.id)).map(row => ({ id: row.id, original_path: context.retained_review_files[index], retained_path: author + '/retained-reviews/' + (index + 1) + '.json', hold_row_sha256: objectSha(row), hold_row: row })));
assert(oldHolds.length === 6, 'Expected six old hold rows');
const languageProjections = decisions.decisions.map(decision => {
  const before = sixCurrent.find(entry => entry.id === decision.id).current_entry;
  const authorCandidate = proposal.narrow_candidates.find(entry => entry.id === decision.id);
  assert(authorCandidate.before_object_sha256 === objectSha(before), 'Candidate baseline changed');
  assert(authorCandidate.retain_definition === decision.accepted_fields.definition && authorCandidate.retain_example === decision.accepted_fields.example && authorCandidate.proposed_fields.difficulty === decision.accepted_fields.difficulty, 'Decision does not match the exact proposed fields');
  assert(same(Object.keys(decision.accepted_fields), decisions.accepted_scope), 'Unexpected projection field order or scope');
  const projected = structuredClone(before);
  for (const field of decisions.accepted_scope) projected[field] = decision.accepted_fields[field];
  const changed = Object.keys(before).filter(key => !same(before[key], projected[key]));
  assert(same(changed, ['difficulty']) && before.difficulty === 'A2' && projected.difficulty === 'B2', 'Unexpected content change');
  for (const key of Object.keys(before).filter(key => !decisions.accepted_scope.includes(key))) assert(same(before[key], projected[key]), 'Protected field changed: ' + key);
  assert(projected.review.domain === decision.domain_preserved, 'Domain status changed');
  const authorFullCandidate = structuredClone(before);
  Object.assign(authorFullCandidate, authorCandidate.proposed_fields);
  return {
    id: decision.id,
    decision: decision.decision,
    human_or_subject_matter_approval: false,
    production_integrated: false,
    automatic_application_permitted: false,
    before_entry_sha256: objectSha(before),
    author_candidate_row_sha256: objectSha(authorCandidate),
    author_candidate_with_proposed_notes_sha256: objectSha(authorFullCandidate),
    accepted_fields: decision.accepted_fields,
    accepted_fields_sha256: objectSha(decision.accepted_fields),
    accepted_language_projection_sha256: objectSha(projected),
    changed_fields_if_separately_delivered: changed,
    actual_current_production_changes: [],
    protected_fields_preserved: Object.keys(before).filter(key => !decisions.accepted_scope.includes(key)),
    original_editorial_notes_sha256: objectSha(before.editorial_notes),
    proposed_editorial_notes_accepted: false,
    review_gates_changed: false,
    historical_hold: oldHolds.find(row => row.id === decision.id),
    field_rationale: decision.field_rationale,
    source_ids: decision.source_ids,
    context_check: decision.context_check,
    excluded_scope: decision.excluded_scope,
    exact_language_projection: projected
  };
});
const cachedFiles = new Map();
const cached = relative => { if (!cachedFiles.has(relative)) cachedFiles.set(relative, parse(relative)); return cachedFiles.get(relative); };
const expressionChecks = context.expression_context.map(record => {
  const current = cached(record.file).expressions.find(entry => entry.id === record.expression.id);
  assert(current && objectSha(current) === record.object_sha256 && same(current, record.expression), 'Expression changed: ' + record.expression.id);
  assert(current.review.status === 'pending' && current.review.language === 'pending', 'Expression gates changed');
  return { id: current.id, file: record.file, object_sha256: record.object_sha256, focus_ids: record.focus_ids, text: current.text, meaning: current.meaning, context: current.context, focus_lexeme_ids: current.focus_lexeme_ids, review: current.review, decision: 'context_consistency_only_no_expression_acceptance' };
});
assert(expressionChecks.length === 24 && expressionChecks.filter(row => row.focus_ids.length).length === 6, 'Unexpected expression context count');
const ids = context.entries.map(entry => entry.id);
const membershipChecks = [];
for (const name of fs.readdirSync(path.join(root, 'data/professional/courses')).filter(name => name.endsWith('.json')).sort()) {
  const relative = 'data/professional/courses/' + name;
  const course = cached(relative);
  for (const module of course.modules) for (const id of ids) if (module.lexeme_ids.includes(id)) membershipChecks.push({ file: relative, course: course.id, module: module.id, lexeme_id: id, requirements_revision: module.requirements_revision, status: module.status });
}
assert(same(membershipChecks, context.course_memberships) && membershipChecks.length === 120, 'Memberships changed');
assert(new Set(membershipChecks.map(row => row.course)).size === 20 && membershipChecks.every(row => row.module === 'module02' && row.status === 'draft' && row.requirements_revision === 'professional-v1'), 'Unexpected membership state');
const alternativeChecks = context.alternative_inventory.map(record => {
  const current = cached(record.file).lexemes.find(entry => entry.id === record.entry.id);
  assert(current && objectSha(current) === record.object_sha256 && same(current, record.entry), 'Alternative changed');
  return { file: record.file, id: current.id, object_sha256: objectSha(current), definition: current.definition, example: current.example, difficulty: current.difficulty, review: current.review, decision: 'context_only_no_new_acceptance_or_identity_reservation' };
});
const neighborTexts = ['follow', 'arrange', 'report', 'adjust', 'reschedule', 'cancel', 'safe', 'incident', 'procedure'];
const neighborChecks = frozenModule.lexemes.filter(entry => neighborTexts.includes(entry.text)).map(before => {
  const current = currentModule.lexemes.find(entry => entry.id === before.id);
  assert(current && same(before, current), 'Reviewed neighbor changed: ' + before.id);
  return { id: before.id, object_sha256: objectSha(before), definition: before.definition, example: before.example, difficulty: before.difficulty, review: before.review, decision: 'context_only_no_transferred_approval' };
});
assert(neighborChecks.length === 9, 'Unexpected neighbor count');
const sourceAfter = sha(fs.readFileSync(__filename));
assert(sourceBefore === sourceAfter, 'Assembly source changed while running');
for (const row of uniquePins.values()) {
  const raw = read(row.path);
  assert(raw.length === row.bytes && sha(raw) === row.sha256, 'Pinned input changed during assembly: ' + row.path);
}
for (const row of authorChecks) assert(sha(read(author + '/' + row.path)) === row.sha256, 'Author artifact changed during assembly');
assert(sha(read(author + '/inventory.json')) === expectedAuthorInventory, 'Author inventory changed during assembly');
const observationsSha = sha(read(relativeOut + '/source-observations.json'));
const decisionsSha = sha(read(relativeOut + '/reviewer-decisions.json'));
assert(same(observations, local('source-observations.json')) && same(decisions, local('reviewer-decisions.json')), 'Reviewer content changed during assembly');
const outputRecords = [];
const write = (name, value) => {
  assert(permittedOutputs.has(name) && path.dirname(path.join(out, name)) === out, 'Output outside review directory');
  const raw = Buffer.from(JSON.stringify(value, null, 2) + '\n');
  fs.writeFileSync(path.join(out, name), raw, { flag: 'wx' });
  outputRecords.push({ path: name, bytes: raw.length, sha256: sha(raw) });
};
const drift = currentPinRows.filter(row => !row.matches_author);
write('input-verification.json', {
  schema: 1, recorded_at: startedAt, hash_algorithm: 'SHA256', object_hash_format: 'UTF-8 JSON.stringify(object), preserving property order, no trailing newline',
  author_inventory_sha256: expectedAuthorInventory, author_artifacts_checked: authorChecks,
  author_input_records: 353, unique_input_paths: 352, duplicate_record_count: 1,
  rows: currentPinRows, drift, drift_note: 'Drift is observational and remains explicit. Matching exact held-entry, expression, course and neighbor context is checked separately. A prior checkpoint update does not rewrite the frozen author snapshot.',
  all_352_observed_inputs_stable_during_assembly: true, production_mutated_by_this_assembly: false
});
write('language-projections.json', {
  schema: 1, status: 'independently_accepted_three_field_projections_not_delivered', reviewer: decisions.reviewer,
  accepted_scope: decisions.accepted_scope, automatic_application_permitted: false,
  accepted_projection_count: 3, current_whole_entry_holds_preserved: 6,
  source_observations_sha256: observationsSha, reviewer_decisions_sha256: decisionsSha,
  source_receipt_sha256: sha(evidenceBytes), author_inventory_sha256: expectedAuthorInventory,
  entries: languageProjections,
  unchanged_remaining_holds: decisions.remaining_holds.map(row => ({ ...row, ...sixCurrent.find(entry => entry.id === row.id), historical_hold: oldHolds.find(entry => entry.id === row.id) })),
  limits: decisions.context_limits
});
write('context-checks.json', {
  schema: 1, purpose: 'Read-only consistency check supporting selected entry language review, not a production test or runtime validation',
  author_context_sha256: sha(read(author + '/context.json')),
  full_entries: sixCurrent.map(({ current_entry, ...row }) => ({ ...row, review: current_entry.review })),
  expressions: expressionChecks, memberships: membershipChecks, alternatives: alternativeChecks, neighbors: neighborChecks,
  context_subagent: 'held_context_check read-only parallel review found no local semantic conflict; no full-entry or placement acceptance delegated',
  scan_limit: 'Specified surface inflections plus literal IDs; not an exhaustive semantic or derivative scan',
  all_expressions_remain_pending: true, all_memberships_unchanged: true, no_new_identity_reserved: true
});
write('assembly-receipt.json', {
  schema: 1, status: 'review_record_assembly_complete', started_at: startedAt, completed_at: new Date().toISOString(), root,
  assembly_source: relativeOut + '/assemble-review-record.cjs', source_before_sha256: sourceBefore, source_after_sha256: sourceAfter, source_unchanged: true,
  author_inventory_sha256: expectedAuthorInventory, author_artifact_count: 15,
  checked_input_records: 353, checked_unique_inputs: 352, drift_record_count: drift.length, drift_paths: [...new Set(drift.map(row => row.path))],
  exact_held_entries_checked: 6, exact_expression_records_checked: 24, membership_records_checked: 120, alternative_records_checked: 4, neighbor_records_checked: 9,
  accepted_language_projections: 3, production_whole_entry_holds_unchanged: 6, production_review_gates_changed: 0,
  source_observations_sha256: observationsSha, reviewer_decisions_sha256: decisionsSha, outputs_before_receipt: outputRecords.slice(),
  production_mutated: false, project_module_imports: false, preparation_dispatched: false, serializer_dispatched: false, tests_dispatched: false, native_dispatched: false, build_or_browser_dispatched: false,
  runtime_validation_transfer: false, overall_or_language_counts_advanced: false
});
console.log(JSON.stringify({ status: 'review_record_assembly_complete', accepted_projections: languageProjections.map(row => ({ id: row.id, sha256: row.accepted_language_projection_sha256 })), unchanged_current_holds: 6, drift_paths: [...new Set(drift.map(row => row.path))], outputs: outputRecords }, null, 2));
