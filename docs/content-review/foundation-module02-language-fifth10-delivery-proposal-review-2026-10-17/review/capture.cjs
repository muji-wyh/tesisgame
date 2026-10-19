// Static review capture only. No project module, validator, test, or delivery code is loaded.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const output = 'build/professional-english/foundation02-fifth10-proposal-review-r01';
const proposalDir = 'build/professional-english/foundation02-fifth10-delivery-proposal-r01';
const researchDir = 'docs/content-review/foundation-module02-language-fifth10-research-2026-10-17';
const languageDir = 'docs/content-review/foundation-module02-language-fifth10-independent-review-2026-10-17';
const fixedInventory = '0e806ef501bbd9e90b1a026857292f13c40e96a5a53906a2ec476800f8b71db9';
const started = new Date().toISOString();
const rawHash = value => crypto.createHash('sha256').update(value).digest('hex');
const jsonHash = value => rawHash(JSON.stringify(value));
const clone = value => JSON.parse(JSON.stringify(value));
const inputs = new Map();
const checks = [];
function check(condition, subject, details = null) {
  checks.push({ subject, passed: Boolean(condition), details });
}
function same(actual, expected, subject) {
  check(JSON.stringify(actual) === JSON.stringify(expected), subject,
    { actual_json_sha256: jsonHash(actual), expected_json_sha256: jsonHash(expected) });
}
function read(relative) {
  const absolute = path.resolve(root, relative);
  if (!absolute.toLowerCase().startsWith(path.resolve(root).toLowerCase() + path.sep)) throw new Error('Outside authorized worktree');
  if (!inputs.has(relative)) {
    const bytes = fs.readFileSync(absolute);
    inputs.set(relative, { path: relative, bytes: bytes.length, raw_sha256: rawHash(bytes), data: bytes });
  }
  return inputs.get(relative).data;
}
function json(relative) { return JSON.parse(read(relative).toString('utf8').replace(/^\uFEFF/, '')); }
function write(name, value) {
  fs.writeFileSync(path.join(root, output, name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
}
function pin(record, label) {
  const bytes = read(record.path);
  check(bytes.length === record.bytes && rawHash(bytes) === (record.raw_sha256 || record.sha256), label || ('Raw pin ' + record.path));
}
function selected(values, id, label) {
  const found = values.filter(value => value.id === id);
  if (found.length !== 1) throw new Error(label + ': expected exactly one ' + id);
  return found[0];
}
function protectedEntry(value) {
  const result = clone(value);
  for (const key of ['definition', 'example', 'difficulty', 'references', 'editorial_notes']) delete result[key];
  for (const key of ['status', 'language', 'reviewer', 'reviewed_at']) delete result.review[key];
  return result;
}
function directoryJson(relative) {
  return fs.readdirSync(path.join(root, relative)).filter(name => name.endsWith('.json')).sort().map(name => ({ path: relative + '/' + name, value: json(relative + '/' + name) }));
}

write('capture-start.json', { schema: 1, started_at: started, method: 'Built-in raw reads, SHA256 and JSON comparisons only', process_id: process.pid, capture_source_sha256: rawHash(fs.readFileSync(__filename)), rerun_permitted: false });

check(rawHash(read(proposalDir + '/inventory.json')) === fixedInventory, 'Root-specified frozen proposal inventory');
const inventory = json(proposalDir + '/inventory.json');
same(inventory.artifacts.map(row => row.path), ['proposal.json', 'context-preservation.json', 'history-preservation.json', 'evidence-pins.json', 'static-observations.json', 'HANDOFF.md'], 'Exactly six declared static payloads');
same(fs.readdirSync(path.join(root, proposalDir)).sort(), [...inventory.artifacts.map(row => row.path), 'inventory.json'].sort(), 'No undeclared proposal payloads');
for (const row of inventory.artifacts) pin({ ...row, path: proposalDir + '/' + row.path });
const proposal = json(proposalDir + '/proposal.json');
const context = json(proposalDir + '/context-preservation.json');
const history = json(proposalDir + '/history-preservation.json');
const evidence = json(proposalDir + '/evidence-pins.json');
for (const row of [...evidence.evidence, ...evidence.history_files]) pin(row);
const language = json(languageDir + '/review-ledger.json');
const languageSources = json(languageDir + '/source-observations.json');
const languageContext = json(languageDir + '/context-review.json');
const candidate = json(researchDir + '/candidate-ledger.json');
const notes = json(researchDir + '/research-notes.json');
const authorSources = json(researchDir + '/source-index.json');
const frozenContext = json(researchDir + '/context-screen.json');
const original = json(researchDir + '/original-foundation-module02.json');
const fourthAfter = json('build/professional-english/foundation02-fourth10-delivery-preparation-r02/execution-r01/foundation-module02.json.after');
const fourthSources = json(history.observed_fourth10_source_afterimage.path);
const fourthRecord = json(history.accepted_fourth10_record.path);
const currentFoundation = json('data/professional/lexemes/foundation-module02.json');
const expectedAccepted = ['broken.not-working.adj', 'urgent.needing-prompt-attention.adj', 'unclear.not-understandable.adj', 'safe.free-from-unacceptable-danger.adj', 'incident.workplace-event.n', 'concern.worrying-matter.n', 'solution.problem-answer.n', 'procedure.agreed-method.n'];
const expectedHeld = ['unsafe.presenting-danger.adj', 'hazard.possible-harm.n'];
const previousHeld = ['collect.gather.v', 'notify.inform.v', 'postpone.delay-until-later.v', 'verify.establish-accuracy.v'];
const mutable = ['definition', 'example', 'difficulty', 'review', 'references', 'editorial_notes'];
const acceptedFields = ['definition', 'example', 'difficulty'];
same(proposal.patches.map(row => row.id), expectedAccepted, 'Exact eight accepted IDs and order');
same(proposal.held.map(row => row.id), expectedHeld, 'Exact two held IDs and order');
same(proposal.accepted_language_review.reviewer, language.reviewer, 'Historical independent reviewer identity attributed literally');
same(proposal.accepted_language_review.consulted_on, language.consultation_date_local, 'Historical consultation date attributed literally');
same(proposal.accepted_language_review.accepted_fields, acceptedFields, 'Language scope limited to three fields');
pin(proposal.accepted_language_review);

const sourceSuffix = 'All twenty original Oxford and Collins pages were freshly consulted by the separate language reviewer. Selected Oxford HTML attributes and body hashes remain frozen author observations; HTML bodies were not independently downloaded and were not retained for rehashing. Literal B1+ labels, cefr/fkcefr distinctions, related-sense limits, register and missing selected labels remain explicit. No publisher page, example, exercise or media is imported. No human, specialist, domain, whole-expression, morphology, media, module or release approval is claimed. Editorial difficulty is a teaching judgment, not publisher consensus or psychometric CEFR certification.';
const deliveryBoundary = 'Earlier Foundation02 language decisions retain their separately recorded scope. This entry does not approve a containing expression or specialist application, add a scored binding, or change any identity, morphology, media or pending domain gate.';
const noteEnd = 'Canonical identity, accepted forms, regions, practice modes, historical reference prefix, morphology, image/audio, domain status, memberships and all expressions remain unchanged. Separate pending gates prevent complete-module readiness.';
const patchDetails = [];
const sourceDetails = [];
const contentCounts = { definition: 0, example: 0, difficulty: 0 };

for (const patch of proposal.patches) {
  const decision = selected(language.entries, patch.id, 'Language decision');
  const author = selected(candidate.entries, patch.id, 'Author candidate');
  const research = selected(notes.entries, patch.id, 'Research note');
  same(patch.before, author.before_entry, patch.id + ': complete research preimage');
  same(patch.before, selected(original.lexemes, patch.id, 'Original lexeme'), patch.id + ': complete frozen original');
  same(patch.before, selected(currentFoundation.lexemes, patch.id, 'Current lexeme'), patch.id + ': observed current preimage');
  same(patch.before, selected(fourthAfter.lexemes, patch.id, 'Fourth10 candidate lexeme'), patch.id + ': independently reviewed fourth10 candidate preimage');
  same(patch.before_entry_json_sha256, jsonHash(patch.before), patch.id + ': before hash');
  same(patch.after_entry_json_sha256, jsonHash(patch.after), patch.id + ': after hash');
  same(patch.accepted_content_projection, decision.accepted_projection, patch.id + ': exact independently accepted complete content projection');
  same(patch.accepted_content_projection_sha256, decision.accepted_projection_sha256, patch.id + ': accepted projection pin');
  same(patch.accepted_content_projection_sha256, jsonHash(patch.accepted_content_projection), patch.id + ': accepted projection rehash');
  same(patch.accepted_decision_json_sha256, jsonHash(decision), patch.id + ': full frozen decision pin');
  same(patch.candidate_record_json_sha256, jsonHash(author), patch.id + ': full author candidate pin');
  same(patch.research_note_json_sha256, jsonHash(research), patch.id + ': full research note pin');
  same(patch.accepted_fields, decision.accepted_fields, patch.id + ': exact accepted fields');
  same(patch.field_decisions, decision.field_decisions, patch.id + ': all three field rationales');
  same(Object.keys(patch.before), Object.keys(patch.after), patch.id + ': entry schema/key order preserved');
  const changes = Object.keys(patch.before).filter(key => JSON.stringify(patch.before[key]) !== JSON.stringify(patch.after[key]));
  same(changes, patch.changed_fields, patch.id + ': exact claimed changed top-level fields');
  check(changes.every(key => mutable.includes(key)), patch.id + ': changed fields in narrow scope');
  const projected = clone(patch.before);
  for (const key of acceptedFields) {
    projected[key] = decision.accepted_fields[key];
    same(patch.after[key], decision.field_decisions[key].value, patch.id + ': accepted ' + key);
    if (patch.before[key] !== patch.after[key]) contentCounts[key] += 1;
  }
  same(projected, patch.accepted_content_projection, patch.id + ': content projection changes only three accepted fields');
  same(protectedEntry(patch.before), protectedEntry(patch.after), patch.id + ': complete protected fields preserved');
  same(jsonHash(protectedEntry(patch.before)), patch.protected_fields_json_sha256, patch.id + ': protected field hash');
  same(patch.after.review, { ...patch.before.review, status: 'reviewed', language: 'reviewed', reviewer: language.reviewer, reviewed_at: language.consultation_date_local }, patch.id + ': exact scoped review metadata');
  same(patch.after.references.slice(0, patch.before.references.length), patch.before.references, patch.id + ': full historical reference prefix');
  same(jsonHash(patch.before.references), patch.reference_prefix_json_sha256, patch.id + ': reference prefix hash');
  check(patch.after.references.length === patch.before.references.length + 2, patch.id + ': exactly two appended references');
  same(patch.source_ids, decision.source_ids, patch.id + ': accepted source IDs');
  same(patch.source_observations.map(row => row.source_id), patch.source_ids, patch.id + ': source observation order');
  same(patch.historical_context_boundary, research.context_boundary, patch.id + ': historical context preserved');
  same(patch.proposed_delivery_context_boundary, deliveryBoundary, patch.id + ': bounded delivery context');
  check(patch.delivery_metadata_technical_acceptance === false, patch.id + ': author does not self-approve metadata');
  const expectedNote = 'Shared workplace foundation. The exact selected-sense definition, example and editorial difficulty have scoped independent AI language acceptance. ' + acceptedFields.map(key => decision.field_decisions[key].rationale).join(' ') + ' ' + research.excluded_scope + ' ' + deliveryBoundary + ' ' + sourceSuffix + ' ' + noteEnd;
  same(patch.after.editorial_notes, expectedNote, patch.id + ': complete proposed editorial note exact and bounded');
  for (let i = 0; i < patch.source_ids.length; i += 1) {
    const id = patch.source_ids[i];
    const source = selected(proposal.sources, id, 'Proposed source');
    const observed = proposal.source_observations.find(row => row.source_id === id);
    const authored = selected(authorSources.sources, id, 'Frozen author source');
    const reviewed = languageSources.sources.find(row => row.source_id === id);
    same(observed.author, authored, id + ': entire authored observation');
    same(observed.reviewer, reviewed, id + ': entire independent rendered observation');
    same(observed.author_record_json_sha256, jsonHash(authored), id + ': author observation hash');
    same(observed.reviewer_record_json_sha256, jsonHash(reviewed), id + ': reviewer observation hash');
    same(patch.source_observations[i], observed, id + ': identical per-entry and global observation');
    const publisherTitle = id.includes('-oxford-') ? "Oxford Advanced Learner's Dictionary" : 'Collins Dictionary';
    const expectedScope = 'Selected ordinary lexical sense only. ' + research.selected_sense + ' ' + research.excluded_scope + ' Literal author and independent-reviewer observations: ' + JSON.stringify({ author: authored, reviewer: reviewed }) + '. ' + sourceSuffix;
    same(source, { id, title: publisherTitle + ': ' + patch.before.text + ' selected ' + patch.before.pos + ' sense', publisher: authored.publisher, url: authored.url, status: 'consulted', consulted_on: language.consultation_date_local, scope: expectedScope, asset_license: null, assets_acquired: false }, id + ': complete proposed source record');
    same(patch.after.references[patch.before.references.length + i], { source_id: id, status: 'verified', scope: 'Verified only for the exact independently accepted definition, example and editorial difficulty of ' + patch.id + '. ' + expectedScope }, id + ': complete scoped appended reference');
    check(reviewed.fresh_reviewer_rendered_consultation.succeeded === true && reviewed.frozen_author_metadata_only.independently_downloaded_html === false && reviewed.assets_acquired === false && reviewed.source_content_imported === false, id + ': consultation/acquisition boundaries');
    sourceDetails.push({ id, proposed_record_json_sha256: jsonHash(source), author_record_json_sha256: jsonHash(authored), prior_independent_record_json_sha256: jsonHash(reviewed), author_rendered_level: authored.observed_rendered_selected_level, author_html_levels: authored.observed_html_selected_levels, prior_independent_rendered_level: reviewed.fresh_reviewer_rendered_consultation.level, label_scope: reviewed.fresh_reviewer_rendered_consultation.label_scope, boundary: reviewed.fresh_reviewer_rendered_consultation.boundary, acquired: false, asset_license: null });
  }
  patchDetails.push({ id: patch.id, before_entry_json_sha256: jsonHash(patch.before), accepted_projection_sha256: jsonHash(patch.accepted_content_projection), accepted_delivery_entry_json_sha256: jsonHash(patch.after), accepted_note_sha256: rawHash(patch.after.editorial_notes), changed_fields: changes, source_ids: patch.source_ids });
}
same(contentCounts, { definition: 4, example: 1, difficulty: 5 }, 'Four definition, one example and five editorial-difficulty edits');
same(proposal.sources.map(row => row.id), proposal.patches.flatMap(row => row.source_ids), 'Sixteen ordered source records only');
same(proposal.source_observations.map(row => row.source_id), proposal.sources.map(row => row.id), 'Sixteen ordered complete source observations only');
check(new Set(proposal.sources.map(row => row.id)).size === 16, 'Sixteen unique source IDs');
same(proposal.excluded_source_ids, expectedHeld.flatMap(id => ['foundation02-language-fifth10-oxford-' + id.split('.')[0], 'foundation02-language-fifth10-collins-' + id.split('.')[0]]), 'Four exact excluded source IDs');
for (const held of proposal.held) {
  const decision = selected(language.entries, held.id, 'Held independent decision');
  same(held.before_entry, decision.held_original_entry, held.id + ': full independent whole-entry hold');
  same(held.before_entry, selected(currentFoundation.lexemes, held.id, 'Current held entry'), held.id + ': current hold unchanged');
  same(held.before_entry, selected(fourthAfter.lexemes, held.id, 'Fourth10 held entry'), held.id + ': fourth10 candidate hold unchanged');
  same(held.entry_json_sha256, jsonHash(held.before_entry), held.id + ': hold entry hash');
  same(held.reason, decision.hold_reason, held.id + ': literal hold reason');
  check(held.reference_or_note_or_review_change_proposed === false && held.before_entry.difficulty === 'A2' && held.before_entry.review.language === 'pending', held.id + ': original A2 remains unapproved without partial acceptance');
}

// Frozen complete context is a bounded preservation requirement, not a whole-registry freeze.
same(context.counts, frozenContext.summary, 'Full frozen context counts preserved');
same(context.counts, languageContext.frozen_scope_counts, 'Full independently reviewed context counts preserved');
for (const [key, rows] of Object.entries(context.groups)) same(rows, frozenContext[key], 'Complete frozen context group ' + key);
same(context.independent_sense_exclusions, languageContext.explicit_sense_exclusions, 'Safe-container, chemical-mixture and concern-verb exclusions');
same(context.pending_domain_expressions, languageContext.pending_domain_expressions, 'Two pending domain gates preserved');
same(context.complete_existing_form_scope_mismatch, frozenContext.complete_existing_form_scope_mismatch, 'Complete pending form-image mismatch preserved');
same(context.whole_entry_holds.map(row => row.id), [...previousHeld, ...expectedHeld], 'Six complete lexical holds');
const currentLexemes = new Map();
for (const file of directoryJson('data/professional/lexemes')) for (const entry of file.value.lexemes) {
  if (currentLexemes.has(entry.id)) throw new Error('Duplicate active lexeme ID');
  currentLexemes.set(entry.id, { entry, resource: 'res://' + file.path });
}
const currentExpressions = new Map();
for (const file of directoryJson('data/professional/expressions')) for (const entry of file.value.expressions) {
  if (currentExpressions.has(entry.id)) throw new Error('Duplicate active expression ID');
  currentExpressions.set(entry.id, { entry, resource: 'res://' + file.path });
}
const courseFiles = directoryJson('data/professional/courses');
const courses = new Map(courseFiles.map(file => [file.value.id, file.value]));
for (const [key, rows] of Object.entries(context.groups)) {
  if (key === 'selected_memberships') {
    for (const row of rows) {
      const module = selected(courses.get(row.course_id).modules, row.module_id, 'Containing module');
      same(module.lexeme_ids[row.index], row.lexeme_id, 'Exact membership ' + row.course_id + '/' + row.module_id + '/' + row.index);
    }
  } else if (key === 'containing_modules') {
    for (const row of rows) {
      const module = selected(courses.get(row.course_id).modules, row.module_id, 'Containing module');
      same(module, row.before_entry, 'Complete containing module ' + row.course_id + '/' + row.module_id);
      same(jsonHash(module), row.module_json_sha256, 'Containing module hash ' + row.course_id + '/' + row.module_id);
    }
  } else {
    for (const row of rows) {
      const current = (row.id.startsWith('expr.') ? currentExpressions : currentLexemes).get(row.id);
      same(current.entry, row.before_entry, key + ': current complete row ' + row.id);
      same(jsonHash(current.entry), row.entry_json_sha256 || row.before_entry_json_sha256, key + ': row hash ' + row.id);
      if (row.resource) same(current.resource, row.resource, key + ': resource ' + row.id);
    }
  }
}
for (const row of [...context.whole_entry_holds, context.complete_existing_form_scope_mismatch]) {
  same(currentLexemes.get(row.id).entry, row.before_entry, row.id + ': complete protected lexical context');
  same(jsonHash(row.before_entry), row.entry_json_sha256, row.id + ': protected lexical context hash');
}
const selectedIds = new Set([...expectedAccepted, ...expectedHeld]);
const membershipActual = [];
for (const course of courses.values()) for (const module of course.modules) module.lexeme_ids.forEach((id, index) => {
  if (selectedIds.has(id)) membershipActual.push({ course_id: course.id, module_id: module.id, index, lexeme_id: id });
});
const sortMembership = values => values.map(row => JSON.stringify(row)).sort();
same(sortMembership(membershipActual), sortMembership(context.groups.selected_memberships), 'All 200 selected memberships independently enumerated');
function scan(policy) {
  const result = new Map();
  for (const [id, current] of currentExpressions) {
    const matches = [];
    for (const [term, forms] of Object.entries(policy)) {
      const occurrences = [...current.entry.text.matchAll(new RegExp('\\b(?:' + forms.join('|') + ')\\b', 'gi'))].map(match => ({ text: match[0], start: match.index, end: match.index + match[0].length }));
      if (occurrences.length) {
        const lexeme = frozenContext.selected_entries.find(row => row.before_entry.text === term).before_entry;
        matches.push({ term, selected_lexeme_id: lexeme.id, occurrences, existing_selected_focus: current.entry.focus_lexeme_ids.includes(lexeme.id) });
      }
    }
    if (matches.length) result.set(id, matches);
  }
  return result;
}
const surface = scan(frozenContext.matching_policy.forms);
const derivatives = scan(frozenContext.matching_policy.derivatives);
for (const [label, actual, rows] of [['surface', surface, context.groups.expression_uses], ['derivative', derivatives, context.groups.derivative_expression_uses]]) {
  same([...actual.keys()].sort(), rows.map(row => row.id).sort(), 'Independently enumerated ' + label + ' expression identities');
  for (const row of rows) same(actual.get(row.id), row.matches, 'Complete ' + label + ' occurrence positions ' + row.id);
}
check(surface.size === 90 && [...surface.values()].reduce((sum, rows) => sum + rows.length, 0) === 100 && derivatives.size === 81, 'Ninety surface expressions, one hundred pairs and eighty-one derivative expressions');
const focusIds = [...currentExpressions.values()].filter(row => row.entry.focus_lexeme_ids.some(id => selectedIds.has(id))).map(row => row.entry.id).sort();
same(focusIds, context.groups.focus_expressions.map(row => row.id).sort(), 'Four focus expressions independently enumerated');
for (const row of context.pending_domain_expressions) {
  const value = currentExpressions.get(row.id).entry;
  same(jsonHash(value), row.preimage_sha256, row.id + ': whole expression domain preimage');
  same(value.review.domain, row.domain_before, row.id + ': domain gate remains pending');
}
for (const [key, rows] of [['containing_module_expressions', languageContext.containing_module_expressions], ['expression_uses', languageContext.surface_expression_review], ['derivative_expression_uses', languageContext.derivative_expression_review], ['focus_expressions', languageContext.selected_focus_expression_review], ['related_entry_boundaries', languageContext.related_identity_review]]) {
  same(context.groups[key].map(row => row.id).sort(), rows.map(row => row.id).sort(), 'Independent reviewed identity set ' + key);
  for (const row of rows) {
    const retained = context.groups[key].find(item => item.id === row.id);
    same(jsonHash(retained.before_entry), row.preimage_sha256, 'Independent reviewed complete preimage ' + key + '/' + row.id);
  }
}

same(history.history_files, evidence.history_files, 'Five exact history-file bindings');
check(history.donor_group_count === 50 && history.complete_donor_row_count === 50 && history.donor_groups.length === 50, 'Fifty complete donor groups and rows');
const donorDetails = [];
for (const file of history.history_files) {
  const donorRows = json(file.path).protected_context.lexemes;
  for (const id of [...expectedAccepted, ...expectedHeld]) {
    const groups = history.donor_groups.filter(row => row.id === id && row.history_path === file.path);
    check(groups.length === 1, 'Exactly one history/identity group ' + file.path + '/' + id);
    const group = groups[0];
    const found = donorRows.map((row, index) => ({ row, index })).filter(row => row.row.entry.id === id);
    check(found.length === 1 && group.exact_count === 1 && group.rows.length === 1, 'Exact donor multiplicity one ' + file.path + '/' + id);
    const actual = found[0];
    const retained = group.rows[0];
    same(actual.index, retained.index, 'Historical donor index ' + file.path + '/' + id);
    same(actual.row, retained.whole_row, 'Complete resource/json_sha256/entry donor ' + file.path + '/' + id);
    same(jsonHash(actual.row), retained.whole_row_json_sha256, 'Whole donor row hash ' + file.path + '/' + id);
    same(jsonHash(actual.row.entry), actual.row.json_sha256, 'Historical donor entry hash ' + file.path + '/' + id);
    same(actual.row.entry, selected(original.lexemes, id, 'Original donor'), 'Historical complete original donor ' + file.path + '/' + id);
    donorDetails.push({ history_path: file.path, id, index: actual.index, exact_count: 1, whole_row_json_sha256: jsonHash(actual.row) });
  }
}
same(history.observed_source_prefix, fourthSources.sources.map((source, index) => ({ index, id: source.id, entry_json_sha256: jsonHash(source) })), 'All 949 complete observed fourth10 source-prefix row hashes');
check(proposal.sources.every(source => !fourthSources.sources.some(prior => prior.id === source.id)), 'Sixteen proposed source IDs absent from observed fourth10 prefix');
check(proposal.excluded_source_ids.every(id => !proposal.sources.some(source => source.id === id)), 'Four held-source IDs excluded');
same(history.preserved_fourth10_patch_ids, fourthRecord.patches.map(row => row.id), 'Ten fourth10 accepted candidate IDs remain preservation requirements');
for (const object of [proposal, context, history, evidence]) {
  check(object.baseline.bound === false, 'Explicit UNBOUND baseline in ' + object.status);
  check(['registry_before_sha256', 'registry_after_sha256', 'measurement_manifest', 'fourth10_committed_receipt', 'shopping_bag_delivery_receipt', 'persisted_validation_receipt'].every(key => object.baseline[key] === null), 'All final-baseline bindings null in ' + object.status);
}
check(proposal.change_summary.global_counts_unbound === true && proposal.shared_test_changes_proposed === false && proposal.executable_integration_provided === false && proposal.production_integrated === false && proposal.new_language_acceptance === false, 'No delivery, final counts, shared-test changes or new language acceptance');

const inputAudit = [...inputs.values()].map(({ data, ...row }) => ({ ...row, end_raw_sha256: rawHash(fs.readFileSync(path.join(root, row.path))) }));
check(inputAudit.every(row => row.raw_sha256 === row.end_raw_sha256), 'All measured static inputs unchanged during capture');
const failures = checks.filter(row => !row.passed);
const accepted = failures.length === 0;
const review = {
  schema: 1,
  status: accepted ? 'accepted_static_metadata_context_and_history_only_final_baseline_unbound' : 'static_review_failed_preserved',
  reviewer: '/root/fifth_review, independent of the frozen delivery-proposal author and historical language-review participants; AI technical review only',
  recorded_at: new Date().toISOString(),
  proposal_inventory_sha256: fixedInventory,
  proposal_raw_sha256: rawHash(read(proposalDir + '/proposal.json')),
  frozen_language_review_raw_sha256: rawHash(read(languageDir + '/review-ledger.json')),
  delivery_metadata_technical_acceptance: accepted,
  new_language_acceptance: false,
  accepted_delivery_entries: patchDetails,
  source_count: 16,
  content_changes: contentCounts,
  held_entry_ids: [...previousHeld, ...expectedHeld],
  context: { memberships: 200, containing_modules: 20, containing_expressions: 10, surface_expressions: 90, surface_term_pairs: 100, derivative_expressions: 81, focus_expressions: 4, related_identities: 46, inherited_expression_holds: 17, additional_exact_foundation02_expressions: 4, pending_domain_expressions: 2 },
  historical_donor_groups: 50,
  complete_historical_donor_rows: 50,
  observed_fourth10_source_prefix_rows: 949,
  inspected_input_count: inputAudit.length,
  static_comparison_count: checks.length,
  failed_static_comparisons: failures,
  baseline: { bound: false, registry_before_sha256: null, registry_after_sha256: null, current_shared_test_binding: null, actual_fourth10_commit_receipt: null, shopping_bag_delivery_receipt: null, persisted_validation_receipt: null, global_reviewed_counts: null },
  blockers_to_delivery: ['Actual fourth10 delivery and persisted validation must be selected by root.', 'Actual shopping-bag delivery and persisted validation must complete before the fifth10 final freeze.', 'Capture and independently review fresh complete source/test/current-registry inputs; preserve the complete actual source prefix and append exactly these sixteen records without duplicates.', 'Rebase all eight full preimages, six whole-entry holds, complete contexts and donor rows without weakening historical hashes.', 'Fresh preparation, projected checks, independent output/native evidence, guarded commit and persisted checks remain required.'],
  limitations: ['This review reads frozen source evidence and does not claim a fresh web consultation or independent HTML-body download.', 'The earlier independent language review supplies the exact accepted three-field projections. This review accepts only their proposed metadata/reference/source packaging and static preservation.', 'Source consultation is not an image/audio license, acquisition, specialist review, expression approval, morphology acceptance, ready module or release acceptance.', 'Measured current files support bounded object comparisons only. No complete current registry or shared-test baseline is bound, and no actual reviewed/global-count change is claimed.', 'Historical failed accesses, wrong-page followups and held decisions remain immutable in the pinned evidence.'],
  execution: { project_or_proposal_modules_imported: false, syntax_checks_run: false, project_tests_run: false, native_or_build_or_probe_dispatched: false, production_or_shared_tests_written: false, output_directory_only: output }
};
write('inspection.json', { schema: 1, method: 'Static built-in raw/hash/JSON comparisons; not a project test or validator', checks, donor_rows: donorDetails });
write('source-review.json', { schema: 1, scope: 'Frozen author and earlier independent evidence inspected, no new consultation', sources: sourceDetails, preserved_historical_access_limits: { author_failed_accesses: authorSources.failed_accesses, author_excluded_consultations: authorSources.excluded_consultations, independent_failed_additional_access: languageSources.failed_additional_access, independent_followup_limitations: languageSources.followup_limitations } });
write('input-audit.json', { schema: 1, binding_scope: 'Static observed inputs only; not a final fifth10 baseline freeze', files: inputAudit });
write('review.json', review);
write('README.md', '# Foundation02 fifth-ten static delivery proposal review\n\n' + (accepted ? 'Accepted for future rebased preparation. The final registry, actual delivery receipts, shared tests and global counts remain unbound.' : 'Static review failed; preserve this capture and inspect the recorded failures.') + '\n\nThe reviewer independently rehashed the six-payload proposal and its thirty-nine evidence/history pins, compared the eight full content projections with the frozen independent language decisions, and assessed the exact proposed notes, review metadata, sixteen references and sixteen source records. Four definitions, one example and five editorial levels change across six entries; broken and solution retain their original content fields. The exact accepted levels are A2, B2, B1, A2, B2, B2, A2 and B2. No new language approval is created.\n\nAll six lexical holds are complete and unchanged. The review compares the complete 200 memberships, twenty modules, ten containing expressions, ninety surface expressions and one hundred term-expression pairs, eighty-one derivative expressions, four focus expressions, forty-six related identities, seventeen inherited expression holds and four extra Foundation02 expression rows. The two pending domain gates and complete\'s unapproved form-image mismatch remain. Surface and derivative occurrences were independently enumerated from current expression JSON, including exact positions, without scoring or approving a use.\n\nAll fifty history/identity groups contain exactly one donor. Every complete resource/json_sha256/entry row, its recorded index and whole-row hash match the original history. The fourth-ten sign duplicate exception is not used here. All 949 observed fourth-ten source-prefix row hashes match the immutable candidate afterimage; that afterimage is not the eventual fifth-ten source preimage.\n\nLiteral source limits remain explicit: Collins broken A2 labels the participle cross-reference, not the selected adjective; urgent retains Oxford b2 versus Collins B1+; unclear retains Oxford b1 and the related Collins B2 uncertain-situation sense; concern uses exact Collins countable-matter B2 while Oxford is related worry-noun support; solution retains Oxford a2 versus Collins B1+; incident retains Collins formal. Missing rendered labels remain missing. Unsafe remains held because the selected original evidence lacks a level, and hazard preserves Oxford fkcefr c1, cefr null and the C1 topic. Later held-entry research is outside this delivery.\n\nThe proposed records preserve complete attributed author and earlier independent rendered observations. Oxford HTML attributes and raw-body hashes are author evidence; neither the earlier reviewer nor this technical reviewer independently downloaded those bodies. This review performs no new source consultation. Historical failed access and wrong-page followup limitations are retained in source-review.json. All sixteen source records are consulted, with no acquired assets or asset license. No publisher page body or media is imported.\n\nRoot must wait for actual fourth-ten and shopping-bag delivery plus their persisted checks, then select actual receipts, capture the complete final registry/source/test preimages, and review the exact rebase. Preserve the entire actual source prefix and all protected history; append exactly sixteen new sources and reject all held-source IDs and duplicates. Shared-test reversals, projected checks, native evidence, guarded commit and fresh persisted checks remain separate. This packet supplies no executable delivery or test transformation.\n\nOnly built-in raw reads, hashes and JSON comparisons ran. No project/proposal code import, syntax check, project test, native/build/probe dispatch, production write or shared-test edit occurred. The frozen capture must not be rerun.\n');
const artifactNames = fs.readdirSync(path.join(root, output)).sort();
const artifacts = artifactNames.map(name => {
  const bytes = fs.readFileSync(path.join(root, output, name));
  return { path: name, bytes: bytes.length, raw_sha256: rawHash(bytes) };
});
write('inventory.json', { schema: 1, status: accepted ? 'frozen_static_review_accepted_final_baseline_unbound' : 'frozen_static_review_failure', artifacts, baseline_bound: false, inventory_self_excluded: true });
console.log(JSON.stringify({ accepted, inspected_input_count: inputAudit.length, static_comparison_count: checks.length, failures, review_sha256: rawHash(fs.readFileSync(path.join(root, output, 'review.json'))), inventory_sha256: rawHash(fs.readFileSync(path.join(root, output, 'inventory.json'))) }, null, 2));
process.exitCode = accepted ? 0 : 1;
