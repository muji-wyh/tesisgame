'use strict';
// Static proposal only. Importing this module never writes files or dispatches validation.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const author = 'docs/content-review/foundation-module02-language-fourth10-research-2026-10-17';
const reviewer = 'docs/content-review/foundation-module02-language-fourth10-independent-review-2026-10-17';
const target = 'data/professional/lexemes/foundation-module02.json';
const sourceFile = 'data/professional/sources.json';
const provenance = 'data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json';
const thirdProvenance = 'data/professional/provenance/foundation-module02-language-third10-2026-10-17.json';
const acceptedIds = ['submit.send-for-consideration.v', 'approve.authorize.v', 'reject.decline-acceptance.v',
  'sign.write-name.v', 'delay.late-occurrence.n', 'error.mistake.n', 'fault.equipment-defect.n',
  'damage.physical-harm.n', 'shortage.insufficient-supply.n', 'missing.not-present.adj'];
const heldIds = ['collect.gather.v', 'notify.inform.v', 'postpone.delay-until-later.v', 'verify.establish-accuracy.v'];
const historicalRegistry = 'f470936fc3bff7ff619b3af057a20cf5e05034013bbf08948e380847228dc4c5';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const hash = value => sha(JSON.stringify(value));
const serialize = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
function at(relative) {
  assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
  assert.equal(path.isAbsolute(relative), false);assert.equal(relative.includes('\\'), false);
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);assert(!relative.startsWith('../'));
  return result;
}
const bytes = relative => fs.readFileSync(at(relative));
const read = relative => JSON.parse(bytes(relative));
const raw = relative => sha(bytes(relative));
function protect(entry) {
  const value = structuredClone(entry);
  for (const key of ['definition', 'example', 'difficulty', 'references', 'editorial_notes']) delete value[key];
  for (const key of ['status', 'language', 'reviewer', 'reviewed_at']) delete value.review[key];
  return value;
}
function loadStaticRegistry() {
  const catalog = read('data/professional/catalog.json');
  const resource = value => {assert(value.startsWith('res://'));return value.slice(6);};
  const data = {catalog, themes: read(resource(catalog.themes)).profiles,
    sources: read(resource(catalog.sources)).sources, courses: [], lexemes: [], expressions: [],
    lexemeOrigins: {}, expressionOrigins: {}};
  for (const course of catalog.courses) data.courses.push(read(resource(course.manifest)));
  for (const [kind, origins, files] of [['lexemes', 'lexemeOrigins', catalog.lexeme_files],
    ['expressions', 'expressionOrigins', catalog.expression_files]]) {
    for (const file of files) for (const entry of read(resource(file))[kind]) {
      data[kind].push(entry);data[origins][entry.id] = file;
    }
  }
  return data;
}
function reverseThird(data, third) {
  assert.equal(third.patches.length, 8);assert.equal(third.sources.length, 16);
  assert.equal(new Set(third.patches.map(row => row.id)).size, 8);
  assert(third.patches.every(row => !acceptedIds.includes(row.id)));
  const previous = structuredClone(data);
  for (const patch of third.patches) {
    const index = previous.lexemes.findIndex(entry => entry.id === patch.id);
    assert(index >= 0);assert.deepEqual(previous.lexemes[index], patch.after);
    assert.equal(hash(patch.after), patch.after_sha256);assert.equal(hash(patch.before), patch.before_sha256);
    previous.lexemes[index] = structuredClone(patch.before);
  }
  assert.deepEqual(previous.sources.slice(-16), third.sources);
  previous.sources = previous.sources.slice(0, -16);
  assert.equal(hash(previous), historicalRegistry, 'Only the exact committed third-ten delta may rebase frozen research');
  return previous;
}
function verifyInputs() {
  const pins = JSON.parse(fs.readFileSync(path.join(__dirname, 'input-pins.json')));
  assert.equal(pins.status, 'frozen_after_root_persisted_third10_validation');
  assert.equal(pins.historical_registry_json_sha256, historicalRegistry);
  assert(pins.files.length > 0);assert(pins.measurement_paths.length > 680);
  assert.equal(new Set(pins.files.map(row => row.path)).size, pins.files.length);
  assert.equal(new Set(pins.measurement_paths).size, pins.measurement_paths.length);
  for (const row of pins.files) {assert.match(row.raw_sha256, /^[a-f0-9]{64}$/);assert.equal(raw(row.path), row.raw_sha256, row.path);}
  for (const missing of pins.must_remain_absent) assert(!fs.existsSync(at(missing)), 'Already exists: ' + missing);
  for (const [directory, filename, field] of [[author, 'inventory.json', 'sha256'], [reviewer, 'artifact-inventory.json', 'raw_sha256']]) {
    const inventory = read(directory + '/' + filename);
    for (const row of inventory.artifacts) assert.equal(raw(directory + '/' + row.path), row[field], row.path);
  }
  const context = read(author + '/context-screen.json');
  assert.equal(context.source_file_hashes.length, 355);
  assert.equal(new Set(context.source_file_hashes.map(row => row.path)).size, 355);
  const changed = [];
  const sourcePins = context.source_file_hashes.map(row => {
    const current = raw(row.path);
    if (current !== row.raw_sha256) {
      assert([target, sourceFile].includes(row.path), 'Unapproved research-source drift: ' + row.path);
      const pin = pins.files.find(item => item.path === row.path);assert(pin);assert.equal(current, pin.raw_sha256);
      changed.push(row.path);
    }
    return {path: row.path, raw_sha256: current, historical_raw_sha256: row.raw_sha256};
  });
  assert.deepEqual(changed.sort(), [target, sourceFile].sort());
  const third = read(thirdProvenance), receipt = read(pins.third10_commit_receipt.path);
  assert.equal(receipt.status, 'committed');assert.equal(receipt.registry_after_sha256, pins.registry_json_sha256);
  assert.equal(raw(thirdProvenance), receipt.provenance_sha256);
  assert.equal(raw(pins.third10_commit_receipt.path), pins.third10_commit_receipt.raw_sha256);
  assert.equal(raw(pins.third10_persisted_validation.path), pins.third10_persisted_validation.raw_sha256);
  const validation = read(pins.third10_persisted_validation.path), start = read(pins.third10_measurement_manifest.path);
  assert.equal(validation.ok, true);assert.equal(validation.source_before, validation.source_after);
  assert.equal(start.source_sha256, validation.source_before);assert.equal(validation.commands.length, 4);
  assert.equal(validation.checked_inputs, 686);assert.equal(Object.keys(start.expected_inputs).length, 686);
  assert.equal(validation.committed_receipt.path, pins.third10_commit_receipt.path);
  assert.equal(validation.committed_receipt.sha256, pins.third10_commit_receipt.raw_sha256);
  for (const command of validation.commands) {assert.equal(command.exit_code, 0);assert.equal(command.error, null);}
  for (const [file, expected] of Object.entries(start.expected_inputs)) assert.equal(raw(file), expected, file);
  const oldTarget = read(target), oldSources = read(sourceFile);
  for (const patch of third.patches) {
    const index = oldTarget.lexemes.findIndex(entry => entry.id === patch.id);assert(index >= 0);
    assert.deepEqual(oldTarget.lexemes[index], patch.after);oldTarget.lexemes[index] = structuredClone(patch.before);
  }
  assert.deepEqual(oldSources.sources.slice(-16), third.sources);oldSources.sources = oldSources.sources.slice(0, -16);
  for (const [file, value] of [[target, oldTarget], [sourceFile, oldSources]]) {
    assert.equal(sha(serialize(value)), context.source_file_hashes.find(row => row.path === file).raw_sha256,
      'Exact original file serialization must be reconstructible: ' + file);
  }
  return {pins, context, sourcePins, third};
}
function project() {
  const {pins, context, sourcePins, third} = verifyInputs(), data = loadStaticRegistry();
  assert.equal(hash(data), pins.registry_json_sha256);
  const historical = reverseThird(data, third);
  const review = read(reviewer + '/review-ledger.json'), ledger = read(author + '/candidate-ledger.json');
  const index = read(author + '/source-index.json'), notes = read(author + '/research-notes.json');
  const sourceReview = read(reviewer + '/source-observations.json');
  assert.equal(review.status, 'independently_accepted_language_projections_not_integrated');
  assert.equal(review.input_registry_json_sha256, historicalRegistry);
  assert.equal(review.candidate_ledger_raw_sha256, raw(author + '/candidate-ledger.json'));
  for (const row of review.research_artifacts) assert.equal(raw(row.path), row.raw_sha256, row.path);
  assert.deepEqual([review.accepted, review.held, review.accepted_field_decisions], [10, 0, 30]);
  assert.deepEqual(review.entries.map(row => row.id), acceptedIds);assert.deepEqual(ledger.entries.map(row => row.id), acceptedIds);
  assert.equal(sourceReview.observations.length, 20);assert.equal(index.sources.length, 20);
  const limits = 'No human, subject-matter, morphology, media, domain, whole-expression, module or release approval is claimed.';
  const evidenceLimits = 'The independent AI language reviewer freshly consulted all 20 rendered original Oxford and Collins publisher pages. Oxford HTML attributes and body hashes remain frozen author evidence; raw HTML was not independently retrieved and original bodies were not retained for independent rehashing. Literal source disagreements, B1+, cefr/fkcefr and missing selected labels remain explicit. Editorial difficulty is a teaching judgment, not source consensus or psychometric CEFR certification.';
  const currentBoundary = 'Third-ten lexical language fields are now delivered at the separately pinned committed state. Frozen research descriptions of unintegrated third-ten proposals remain historical. Every expression, existing binding and pending professional gate remains unchanged.';
  const sources = [], observations = [];
  const patches = acceptedIds.map(id => {
    const a = review.entries.find(row => row.id === id), candidate = ledger.entries.find(row => row.id === id);
    const note = notes.entries.find(row => row.id === id), before = structuredClone(candidate.before_entry);
    assert.equal(a.decision, 'accept_exact_language_projection');assert.equal(a.production_mutated, false);
    assert.equal(hash(candidate), a.candidate_record_json_sha256);assert.equal(hash(note), a.research_note_json_sha256);
    assert.equal(candidate.disposition, 'proposed');assert.equal(hash(before), candidate.before_entry_sha256);
    assert.equal(hash(before), a.before_entry_sha256);assert.deepEqual(data.lexemes.find(entry => entry.id === id), before);
    assert.deepEqual(historical.lexemes.find(entry => entry.id === id), before);
    const acceptedContent = structuredClone(before);Object.assign(acceptedContent, a.accepted_fields);
    assert.deepEqual(Object.keys(a.accepted_fields), ['definition', 'example', 'difficulty']);
    assert.deepEqual(a.before_fields, {definition: before.definition, example: before.example, difficulty: before.difficulty});
    assert.deepEqual(a.accepted_fields, candidate.proposed_fields);assert.equal(hash(a.accepted_fields), a.accepted_fields_sha256);
    assert.equal(hash(acceptedContent), a.accepted_content_projection_sha256);
    assert.equal(hash(acceptedContent), candidate.content_projection_sha256);assert.deepEqual(acceptedContent, candidate.content_projection);
    for (const field of ['definition', 'example', 'difficulty']) assert.equal(a.field_decisions[field].decision, 'accept');
    assert.deepEqual(a.changed_fields, candidate.changed_fields);assert.deepEqual(a.source_ids, candidate.source_ids);assert.equal(a.source_ids.length, 2);
    const after = structuredClone(acceptedContent);
    // Delivery metadata is new technical-review scope, separate from the frozen three-field language decision.
    after.review = {...before.review, status: 'reviewed', language: 'reviewed', reviewer: review.reviewer, reviewed_at: review.date_local};
    const selected = [], authored = [];
    for (const sourceId of a.source_ids) {
      const observed = index.sources.find(row => row.id === sourceId), independent = sourceReview.observations.find(row => row.source_id === sourceId);
      assert(observed);assert(independent);assert(!data.sources.some(row => row.id === sourceId));
      assert.equal(hash(observed), independent.original_source_record_json_sha256);
      assert.equal(independent.source_index_raw_sha256, raw(author + '/source-index.json'));
      assert.equal(independent.publisher, observed.publisher);assert.equal(independent.url, observed.url);
      assert.equal(independent.independent_consultation.fresh_raw_html_retrieval, false);
      assert.equal(independent.independent_consultation.fresh_raw_body_sha256, null);
      assert.equal(independent.source_pages_imported, false);assert.equal(independent.source_examples_imported, false);assert.equal(independent.media_acquired, false);
      if (observed.publisher === 'Oxford University Press') {
        assert.deepEqual(independent.frozen_author_metadata.literal_selected_attributes, observed.observed_html_selected_levels);
        assert.equal(independent.frozen_author_metadata.author_raw_body_sha256, observed.raw_body_sha256);
        assert.equal(independent.frozen_author_metadata.author_raw_body_bytes, observed.raw_body_bytes);
      }
      const scope = 'Selected ordinary lexical sense only. ' + note.selected_sense + ' ' + note.excluded_scope +
        ' Literal frozen author and fresh rendered reviewer observations: ' + JSON.stringify({author: observed, reviewer: independent}) +
        '. ' + evidenceLimits + ' Source consultation only; no publisher page, exercise, dataset, example or media is imported. ' + limits;
      sources.push({id: sourceId, title: (observed.publisher === 'Oxford University Press' ? "Oxford Advanced Learner's Dictionary" : 'Collins COBUILD Dictionary') +
        ': ' + candidate.term + ' selected ' + before.pos + ' sense', publisher: observed.publisher, url: observed.url,
        status: 'consulted', consulted_on: observed.consulted_on, scope, asset_license: null, assets_acquired: false});
      after.references.push({source_id: sourceId, status: 'verified',
        scope: 'Verified only for the exact independently accepted definition, example and editorial difficulty of ' + id + '. ' + scope});
      selected.push(structuredClone(independent));authored.push(structuredClone(observed));
      observations.push({author: structuredClone(observed), reviewer: structuredClone(independent)});
    }
    after.editorial_notes = 'Shared workplace foundation. The exact selected-sense definition, example and editorial difficulty have scoped independent AI language acceptance. ' +
      Object.values(a.field_decisions).map(row => row.rationale).join(' ') + ' ' + note.excluded_scope + ' ' + currentBoundary + ' ' + evidenceLimits + ' ' + limits +
      ' Canonical identity, accepted forms, regions, practice modes, historical reference prefix, morphology, image/audio, domain status, memberships and all expressions remain unchanged. Separate pending gates prevent complete-module readiness.';
    assert.deepEqual(protect(after), protect(before));assert.deepEqual(after.references.slice(0, before.references.length), before.references);
    const changedFields = Object.keys(before).filter(key => JSON.stringify(before[key]) !== JSON.stringify(after[key]));
    assert(changedFields.every(key => ['definition', 'example', 'difficulty', 'review', 'references', 'editorial_notes'].includes(key)));
    return {id, before, after, before_sha256: hash(before), after_sha256: hash(after), protected_fields_sha256: hash(protect(before)),
      changed_fields: changedFields, accepted_content: acceptedContent, accepted_content_json_sha256: hash(acceptedContent),
      accepted_fields: structuredClone(a.accepted_fields), accepted_fields_json_sha256: hash(a.accepted_fields),
      field_decisions: structuredClone(a.field_decisions), source_ids: structuredClone(a.source_ids),
      selected_source_observations: selected, author_source_observations: authored,
      historical_research_context_boundary: a.context_boundary, current_delivery_context_boundary: currentBoundary,
      dictionary_or_lesson_level_certification: false};
  });
  assert.deepEqual(['difficulty', 'definition', 'example'].map(field => patches.filter(row => row.before[field] !== row.after[field]).length), [6, 1, 1]);
  assert.equal(patches.filter(row => hash(row.before) !== hash(row.accepted_content)).length, 6);
  assert.equal(sources.length, 20);assert.equal(new Set(sources.map(row => row.id)).size, 20);
  assert.deepEqual(context.previous_whole_entry_holds.map(row => row.id), heldIds);
  for (const row of context.previous_whole_entry_holds) {
    assert.deepEqual(data.lexemes.find(entry => entry.id === row.id), row.before_entry);assert.equal(hash(row.before_entry), row.entry_json_sha256);
  }
  for (const row of context.selected_memberships) assert.equal(data.courses.find(c => c.id === row.course_id).modules.find(m => m.id === row.module_id).lexeme_ids[row.index], row.lexeme_id);
  for (const row of context.containing_modules) assert.equal(hash(data.courses.find(c => c.id === row.course_id).modules.find(m => m.id === row.module_id)), row.module_json_sha256);
  for (const group of ['expression_uses', 'derivative_expression_uses', 'focus_expressions', 'containing_module_expressions', 'additional_foundation02_preservation', 'inherited_expression_holds']) {
    for (const row of context[group]) {
      assert.deepEqual(data.expressions.find(entry => entry.id === row.id), row.before_entry);
      assert.equal(hash(row.before_entry), row.entry_json_sha256 || row.before_entry_json_sha256);
    }
  }
  const related = context.related_entry_boundaries.map(row => {
    assert.deepEqual(historical.lexemes.find(entry => entry.id === row.id), row.before_entry);assert.equal(hash(row.before_entry), row.entry_json_sha256);
    const current = data.lexemes.find(entry => entry.id === row.id);assert(current);
    return {id: row.id, before_entry: structuredClone(current), entry_json_sha256: hash(current), historical_entry_json_sha256: row.entry_json_sha256};
  });
  const complete = context.complete_existing_form_scope_mismatch;
  assert.deepEqual(data.lexemes.find(entry => entry.id === 'complete.finish.v'), complete.before_entry);
  assert.equal(hash(complete.before_entry), '63f724e5609017e7ea9077c84221bd2cd68f5c7f70b212034eb2d8603dbcec14');
  assert.deepEqual([context.selected_memberships.length, context.containing_modules.length, context.expression_uses.length,
    context.derivative_expression_uses.length, context.focus_expressions.length, related.length, context.inherited_expression_holds.length,
    context.containing_module_expressions.length, context.additional_foundation02_preservation.length], [200, 20, 130, 42, 4, 63, 17, 10, 4]);
  assert.equal(context.summary.surface_pairs, 139);
  assert.equal(context.expression_uses.reduce((count, row) => count + row.matches.length, 0), 139);
  const next = structuredClone(data), ids = new Set(acceptedIds);
  for (const patch of patches) next.lexemes[next.lexemes.findIndex(entry => entry.id === patch.id)] = structuredClone(patch.after);
  next.sources.push(...structuredClone(sources));
  assert.deepEqual(next.lexemes.filter(entry => !ids.has(entry.id)), data.lexemes.filter(entry => !ids.has(entry.id)));
  for (const key of ['catalog', 'themes', 'courses', 'expressions', 'lexemeOrigins', 'expressionOrigins']) assert.deepEqual(next[key], data[key]);
  const record = {schema: 1, status: 'accepted_content_with_proposed_delivery_metadata', prepared_by: 'Codex runtime_recovery delivery proposal author',
    new_language_approval: false,
    independent_review: {path: reviewer + '/review-ledger.json', raw_sha256: raw(reviewer + '/review-ledger.json'),
      reviewer: review.reviewer, reviewed_on: review.date_local, accepted: true, human_or_specialist_approval: false,
      acceptance_scope: 'Only the exact definition, example and editorial difficulty projections.', limitations: structuredClone(review.limits)},
    accepted_evidence: {author_directory: author, reviewer_directory: reviewer, author_inventory_sha256: raw(author + '/inventory.json'),
      review_inventory_sha256: raw(reviewer + '/artifact-inventory.json'), candidate_sha256: raw(author + '/candidate-ledger.json'),
      context_sha256: raw(author + '/context-screen.json'), source_observations_sha256: raw(reviewer + '/source-observations.json')},
    rebase: {historical_registry_json_sha256: historicalRegistry, current_registry_json_sha256: hash(data),
      third10_record: {path: thirdProvenance, raw_sha256: raw(thirdProvenance)}, third10_commit_receipt: pins.third10_commit_receipt,
      persisted_validation: pins.third10_persisted_validation, exact_reversed_entries: third.patches.map(row => row.id), exact_reversed_source_count: 16,
      historical_approval_transferred: false, current_context_boundary: currentBoundary},
    patches, held: [], sources, source_observations: observations, excluded_source_ids: [],
    protected_context: {memberships: context.selected_memberships, modules: context.containing_modules, expressions: context.expression_uses,
      derivative_expressions: context.derivative_expression_uses, focus_expressions: context.focus_expressions,
      containing_module_expressions: context.containing_module_expressions, additional_foundation02_preservation: context.additional_foundation02_preservation,
      related_entries: related, inherited_expression_holds: context.inherited_expression_holds, prior_lexical_holds: context.previous_whole_entry_holds,
      historical_context_boundaries: context.context_boundaries, complete_pending_form_image_mismatch: complete,
      all_other_lexemes_json_sha256: hash(data.lexemes.filter(entry => !ids.has(entry.id))), all_expressions_json_sha256: hash(data.expressions),
      all_courses_json_sha256: hash(data.courses), all_themes_json_sha256: hash(data.themes), previous_sources_json_sha256: hash(data.sources)},
    delivery_scope: {lexeme_file: target, sources_file: sourceFile, provenance_file: provenance, production_runtime_changed: false, module_acceptance: false},
    expected_counts_only: {review_status: {before: 138, after: 148}, review_language: {before: 325, after: 335},
      foundation02_language: {before: 26, after: 36, total: 50}, ready_modules: 0},
    source_baseline: {kind: 'source_snapshot_not_validation', registry_before_sha256: hash(data), registry_after_sha256: hash(next), source_pins: sourcePins}};
  const lexemes = read(target), sourceEnvelope = read(sourceFile);
  for (const patch of patches) {
    assert.equal(lexemes.lexemes.filter(entry => entry.id === patch.id).length, 1);
    lexemes.lexemes[lexemes.lexemes.findIndex(entry => entry.id === patch.id)] = structuredClone(patch.after);
  }
  sourceEnvelope.sources.push(...structuredClone(sources));
  return {before: data, next, record, proposed_files: [{path: target, before: bytes(target), after: serialize(lexemes)},
    {path: sourceFile, before: bytes(sourceFile), after: serialize(sourceEnvelope)}]};
}
module.exports = {project, verifyInputs, loadStaticRegistry, reverseThird, protect, sha, hash, serialize, at, raw, bytes, read};
