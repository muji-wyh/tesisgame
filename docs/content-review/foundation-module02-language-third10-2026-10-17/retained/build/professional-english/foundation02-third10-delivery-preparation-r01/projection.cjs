'use strict';
// Unexecuted authoring proposal. This module has no write, transaction or test dispatch API.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../../..');
const expectedRoot = 'q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const author = 'docs/content-review/foundation-module02-language-third10-research-2026-10-17';
const reviewer = 'docs/content-review/foundation-module02-language-third10-independent-review-2026-10-17';
const target = 'data/professional/lexemes/foundation-module02.json';
const sourceFile = 'data/professional/sources.json';
const provenance = 'data/professional/provenance/foundation-module02-language-third10-2026-10-17.json';
const acceptedIds = ['correct.put-right.v', 'adjust.change-slightly.v', 'reschedule.change-time.v',
  'cancel.stop-arrangement.v', 'resolve.solve-problem.v', 'assist.help.v',
  'locate.find-position.v', 'attach.add-to-message.v'];
const heldIds = ['postpone.delay-until-later.v', 'verify.establish-accuracy.v'];
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const hash = value => sha(JSON.stringify(value));
const serialize = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');

function at(relative) {
  assert.equal(root.replaceAll('\\', '/').toLowerCase(), expectedRoot);
  assert.equal(path.isAbsolute(relative), false);
  assert.equal(relative.includes('\\'), false);
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return result;
}
const bytes = relative => fs.readFileSync(at(relative));
const read = relative => JSON.parse(bytes(relative));
const raw = relative => sha(bytes(relative));

// Remove only the intended delivery fields. Nested domain and every other review key stay protected.
function protect(entry) {
  const value = structuredClone(entry);
  for (const key of ['definition', 'example', 'difficulty', 'references', 'editorial_notes']) delete value[key];
  for (const key of ['status', 'language', 'reviewer', 'reviewed_at']) delete value.review[key];
  return value;
}

function verifyInputs() {
  const pins = JSON.parse(fs.readFileSync(path.join(__dirname, 'input-pins.json')));
  for (const row of [...pins.files, pins.source_manifest, pins.historical_input_pathlist]) {
    assert.match(row.raw_sha256, /^[a-f0-9]{64}$/);
    assert.equal(raw(row.path), row.raw_sha256, row.path);
  }
  const context = read(pins.source_manifest.path);
  const sourcePins = context[pins.source_manifest.property];
  assert.equal(sourcePins.length, pins.source_manifest.expected_count);
  assert.equal(new Set(sourcePins.map(row => row.path)).size, sourcePins.length);
  for (const row of sourcePins) assert.equal(raw(row.path), row.raw_sha256, row.path);
  for (const missing of pins.must_remain_absent) assert(!fs.existsSync(at(missing)), 'Already exists: ' + missing);
  for (const directory of [author, reviewer]) {
    const inventory = read(directory + '/inventory.json');
    for (const row of inventory.artifacts) assert.equal(raw(directory + '/' + row.path), row.sha256, row.path);
  }
  return {pins, context, sourcePins};
}

function loadStaticRegistry() {
  const catalog = read('data/professional/catalog.json');
  const resource = value => {
    assert(value.startsWith('res://'));
    return value.slice(6);
  };
  const data = {catalog, themes: read(resource(catalog.themes)).profiles,
    sources: read(resource(catalog.sources)).sources, courses: [], lexemes: [],
    expressions: [], lexemeOrigins: {}, expressionOrigins: {}};
  for (const course of catalog.courses) data.courses.push(read(resource(course.manifest)));
  for (const [kind, origins, files] of [['lexemes', 'lexemeOrigins', catalog.lexeme_files],
    ['expressions', 'expressionOrigins', catalog.expression_files]]) {
    for (const file of files) for (const entry of read(resource(file))[kind]) {
      data[kind].push(entry);
      data[origins][entry.id] = file;
    }
  }
  return data;
}

function project() {
  const {pins, context, sourcePins} = verifyInputs();
  const data = loadStaticRegistry();
  assert.equal(hash(data), pins.registry_json_sha256);
  const review = read(reviewer + '/review.json');
  const ledger = read(author + '/candidate-ledger.json');
  const index = read(author + '/source-index.json');
  assert.equal(review.status, 'completed_independent_AI_language_review_no_production_promotion');
  assert.equal(review.author_package.inventory_sha256, raw(author + '/inventory.json'));
  assert.equal(review.author_package.candidate_ledger_sha256, raw(author + '/candidate-ledger.json'));
  assert.equal(review.author_package.source_index_sha256, raw(author + '/source-index.json'));
  assert.equal(review.author_package.context_screen_sha256, raw(author + '/context-screen.json'));
  assert.equal(review.author_package.successful_execution_sha256, raw(author + '/assembly-attempt-r02.json'));
  assert.equal(review.production_baseline.registry_json_sha256, hash(data));
  assert.equal(review.production_baseline.raw_sha256, raw(target));
  assert.equal(review.summary.language_decisions, 8);
  assert.equal(review.summary.whole_entry_holds, 2);
  assert.deepEqual(review.entries.filter(row => row.accepted_fields).map(row => row.id), acceptedIds);
  assert.deepEqual(review.entries.filter(row => !row.accepted_fields).map(row => row.id), heldIds);

  const limits = 'No human, subject-matter, morphology, media, domain, whole-expression, module or release approval is claimed.';
  const evidenceLimits = 'The independent AI language reviewer assessed frozen author-recorded observations and did not reopen the original publisher pages. Oxford HTML bodies were not retained and cannot be independently rehashed; Collins rendered observations were not freshly retrieved by that reviewer. Literal source disagreements and missing selected labels remain explicit. Editorial difficulty is a teaching judgment, not psychometric CEFR certification.';
  const sources = [], observations = [];
  const patches = acceptedIds.map(id => {
    const a = review.entries.find(row => row.id === id);
    const candidate = ledger.entries.find(row => row.id === id);
    const before = structuredClone(candidate.before_entry);
    assert.equal(a.decision, 'accept_exact_bounded_language_fields');
    assert.equal(a.human_or_specialist_acceptance, false);
    assert.equal(candidate.disposition, 'proposed');
    assert.equal(hash(before), a.before_entry_sha256);
    assert.equal(hash(before), candidate.before_entry_sha256);
    assert.deepEqual(data.lexemes.find(entry => entry.id === id), before);
    const acceptedContent = structuredClone(before);
    Object.assign(acceptedContent, a.accepted_fields);
    assert.equal(hash(acceptedContent), a.content_projection_sha256);
    assert.equal(hash(acceptedContent), candidate.content_projection_sha256);
    assert.deepEqual(acceptedContent, candidate.content_projection);
    assert.equal(a.accepted_fields.definition, before.definition);
    assert.equal(a.accepted_fields.example, before.example);
    assert.deepEqual(a.selected_source_observations.map(row => row.id), candidate.source_ids);
    const after = structuredClone(acceptedContent);
    // Proposed delivery metadata, independently reviewable; not part of the frozen field acceptance.
    after.review = {...before.review, status: 'reviewed', language: 'reviewed',
      reviewer: review.reviewer, reviewed_at: review.reviewed_on};
    const refs = a.selected_source_observations.map(selected => {
      const observed = index.sources.find(row => row.id === selected.id);
      assert(observed);
      assert.equal(observed.publisher, selected.publisher);
      assert.equal(observed.url, selected.url);
      assert.deepEqual(observed.observed_html_selected_levels, selected.observed_html_selected_levels);
      assert.equal(observed.observed_rendered_selected_level, selected.observed_rendered_selected_level);
      assert(!data.sources.some(row => row.id === observed.id));
      observations.push(structuredClone(observed));
      const scope = 'Selected ordinary lexical sense only. ' + a.rationale +
        ' Literal selected-source observation: ' + JSON.stringify(selected) + '. ' + evidenceLimits +
        ' Source consultation only; no publisher page, exercise, dataset, example or media is imported. ' + limits;
      sources.push({id: observed.id,
        title: (observed.publisher === 'Oxford University Press' ? "Oxford Advanced Learner's Dictionary" : 'Collins COBUILD Dictionary') + ': ' + candidate.term + ' selected verb sense',
        publisher: observed.publisher, url: observed.url, status: 'consulted',
        consulted_on: observed.consulted_on, scope, asset_license: null, assets_acquired: false});
      return {source_id: observed.id, status: 'verified',
        scope: 'Verified only for the exact independently accepted definition, example and editorial difficulty of ' + id + '. ' + scope};
    });
    after.references.push(...refs);
    after.editorial_notes = 'Shared workplace foundation. The exact selected-sense definition, example and editorial difficulty have scoped independent AI language acceptance. ' +
      a.rationale + ' ' + a.excluded_scope + ' ' + a.context_action + ' ' + evidenceLimits + ' ' + limits +
      ' Canonical identity, accepted forms, regions, practice modes, historical reference prefix, morphology, image/audio, domain status, memberships and all expressions remain unchanged. Separate pending gates prevent complete-module readiness.';
    assert.deepEqual(protect(after), protect(before));
    assert.deepEqual(after.references.slice(0, before.references.length), before.references);
    const changedFields = Object.keys(before).filter(key => JSON.stringify(before[key]) !== JSON.stringify(after[key]));
    assert(changedFields.every(key => ['difficulty', 'review', 'references', 'editorial_notes'].includes(key)));
    return {id, before, after, before_sha256: hash(before), after_sha256: hash(after),
      protected_fields_sha256: hash(protect(before)), changed_fields: changedFields,
      accepted_content: acceptedContent, accepted_content_json_sha256: hash(acceptedContent),
      accepted_fields: structuredClone(a.accepted_fields), accepted_fields_json_sha256: hash(a.accepted_fields),
      decision: a.rationale, source_ids: candidate.source_ids,
      selected_source_observations: structuredClone(a.selected_source_observations),
      dictionary_or_lesson_level_certification: false};
  });
  assert.equal(patches.filter(row => row.before.difficulty !== row.after.difficulty).length, 7);
  assert.equal(sources.length, 16);
  assert.equal(new Set(sources.map(row => row.id)).size, 16);

  const held = heldIds.map(id => {
    const a = review.entries.find(row => row.id === id);
    const candidate = ledger.entries.find(row => row.id === id);
    assert.equal(a.decision, 'hold_whole_entry_unchanged');
    assert.equal(candidate.disposition, 'held_unchanged');
    assert.equal(hash(candidate.before_entry), a.before_entry_sha256);
    assert.deepEqual(candidate.before_entry, candidate.content_projection);
    assert.deepEqual(data.lexemes.find(entry => entry.id === id), candidate.before_entry);
    for (const sourceId of candidate.source_ids) assert(!data.sources.some(row => row.id === sourceId));
    return {id, value: structuredClone(candidate.before_entry), whole_entry_json_sha256: a.before_entry_sha256,
      decision: a.rationale, reference_or_note_additions: 0, review_gate_changes: 0};
  });
  for (const row of context.prior_lexical_holds) {
    assert.equal(hash(data.lexemes.find(entry => entry.id === row.id)), row.whole_entry_json_sha256);
    assert.deepEqual(data.lexemes.find(entry => entry.id === row.id), row.before_entry);
  }
  assert.deepEqual(context.prior_lexical_holds.map(row => row.id), ['collect.gather.v', 'notify.inform.v']);
  assert.equal(context.selected_memberships.length, 200);
  for (const m of context.selected_memberships) assert.equal(data.courses.find(c => c.id === m.course_id).modules.find(row => row.id === m.module_id).lexeme_ids[m.index], m.lexeme_id);
  for (const m of context.containing_modules) assert.equal(hash(data.courses.find(c => c.id === m.course_id).modules.find(row => row.id === m.module_id)), m.module_json_sha256);
  for (const row of context.expression_uses) assert.equal(hash(data.expressions.find(entry => entry.id === row.id)), row.expression_json_sha256);
  for (const row of context.focus_expressions) assert.deepEqual(data.expressions.find(entry => entry.id === row.id), row.before_entry);
  for (const row of context.inherited_expression_holds) assert.equal(hash(data.expressions.find(entry => entry.id === row.id)), row.before_entry_json_sha256);
  for (const row of context.related_entry_boundaries) assert.equal(hash(data.lexemes.find(entry => entry.id === row.id)), row.entry_json_sha256);
  assert.equal(hash(data.lexemes.find(entry => entry.id === 'complete.finish.v')), context.complete_existing_form_scope_mismatch.current_whole_entry_json_sha256);
  assert.deepEqual([context.expression_uses.length, context.focus_expressions.length, context.related_entry_boundaries.length, context.inherited_expression_holds.length], [39, 4, 43, 17]);

  const next = structuredClone(data);
  for (const patch of patches) next.lexemes[next.lexemes.findIndex(entry => entry.id === patch.id)] = structuredClone(patch.after);
  next.sources.push(...structuredClone(sources));
  const ids = new Set(acceptedIds);
  assert.deepEqual(next.lexemes.filter(entry => !ids.has(entry.id)), data.lexemes.filter(entry => !ids.has(entry.id)));
  for (const key of ['catalog', 'themes', 'courses', 'expressions', 'lexemeOrigins', 'expressionOrigins']) assert.deepEqual(next[key], data[key]);
  const record = {schema: 1, status: 'accepted_content_with_proposed_delivery_metadata',
    prepared_by: 'Codex language_delivery proposal author', new_language_approval: false,
    independent_review: {path: reviewer + '/review.json', raw_sha256: raw(reviewer + '/review.json'),
      reviewer: review.reviewer, reviewed_on: review.reviewed_on, accepted: true,
      human_or_specialist_approval: false, acceptance_scope: review.scope,
      limitations: structuredClone(review.limitations)},
    accepted_evidence: {author_directory: author, reviewer_directory: reviewer,
      author_inventory_sha256: raw(author + '/inventory.json'), review_inventory_sha256: raw(reviewer + '/inventory.json'),
      candidate_sha256: raw(author + '/candidate-ledger.json'), context_sha256: raw(author + '/context-screen.json')},
    patches, held, sources, source_observations: observations,
    excluded_source_ids: heldIds.flatMap(id => ledger.entries.find(row => row.id === id).source_ids),
    protected_context: {memberships: context.selected_memberships, modules: context.containing_modules,
      expressions: context.expression_uses, focus_expressions: context.focus_expressions,
      related_entries: context.related_entry_boundaries, inherited_expression_holds: context.inherited_expression_holds,
      expression_hold_ids: context.inherited_expression_hold_ids, prior_lexical_holds: context.prior_lexical_holds,
      context_boundaries: context.context_boundaries,
      complete_pending_form_image_mismatch: context.complete_existing_form_scope_mismatch,
      all_other_lexemes_json_sha256: hash(data.lexemes.filter(entry => !ids.has(entry.id))),
      all_expressions_json_sha256: hash(data.expressions), all_courses_json_sha256: hash(data.courses),
      all_themes_json_sha256: hash(data.themes), previous_sources_json_sha256: hash(data.sources)},
    delivery_scope: {lexeme_file: target, sources_file: sourceFile, provenance_file: provenance,
      production_runtime_changed: false, module_acceptance: false},
    expected_counts_only: {review_status: {before: 130, after: 138}, review_language: {before: 317, after: 325},
      foundation02_language: {before: 18, after: 26, total: 50}, ready_modules: 0},
    source_baseline: {kind: 'source_snapshot_not_validation', registry_before_sha256: hash(data),
      registry_after_sha256: hash(next), source_pins: sourcePins}};
  const lexemes = read(target), sourceEnvelope = read(sourceFile);
  for (const patch of patches) {
    assert.equal(lexemes.lexemes.filter(entry => entry.id === patch.id).length, 1);
    lexemes.lexemes[lexemes.lexemes.findIndex(entry => entry.id === patch.id)] = structuredClone(patch.after);
  }
  sourceEnvelope.sources.push(...structuredClone(sources));
  return {before: data, next, record, proposed_files: [
    {path: target, before: bytes(target), after: serialize(lexemes)},
    {path: sourceFile, before: bytes(sourceFile), after: serialize(sourceEnvelope)}]};
}

module.exports = {project, verifyInputs, protect, sha, hash, serialize, at, raw, bytes, read};
