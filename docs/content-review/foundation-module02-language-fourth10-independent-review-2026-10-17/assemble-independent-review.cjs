'use strict';
// Independent review delivery only. This script does not run the author's scripts or a test suite.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
if (root.replaceAll('\\', '/').toLowerCase() !== 'q:/.codex/worktrees/current-age-vocabulary/tesisgame') throw new Error('Unexpected workspace');
const research = 'docs/content-review/foundation-module02-language-fourth10-research-2026-10-17';
const read = p => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const bytes = p => fs.readFileSync(path.join(root, p));
const sha = x => crypto.createHash('sha256').update(x).digest('hex');
const hash = x => sha(JSON.stringify(x));
const source = name => read(research + '/' + name);
const ledger = source('candidate-ledger.json');
const context = source('context-screen.json');
const baseline = source('baseline.json');
const notes = source('research-notes.json');
const sources = source('source-index.json');
const metadata = source('oxford-html-metadata.json');
const copy = source('copy-receipt.json');
const inventory = source('inventory.json');
const date = new Date().toISOString();
const reviewer = 'Codex runtime_recovery independent AI language reviewer; separate from recover_delivery author; not human or subject-matter approval';
const limits = [
  'Acceptance applies only to each exact definition, example and editorial difficulty projection bound below. It does not accept the entire entry or change a production flag.',
  'No human, specialist, professional-procedure, expression, morphology, media, module, readiness or release approval transfers.',
  'No new focus binding, reference registration, source-registry record, editorial note or review-gate change is made.',
  'The four earlier lexical holds, all 17 inherited expression holds and the additional Foundation02.04/.05/.07/.08 preservation remain exact.',
  'Third10 proposals remain unintegrated. Complete retains its live mismatched form-image brief, pending and unapproved.',
  'Difficulty is an editorial placement for a bounded meaning, not source consensus or lesson certification. B1+ and cefr/fkcefr remain literal observations.',
  'Fresh source consultation used rendered original-publisher pages through the web connector. Oxford HTML metadata and body hashes were inspected only as frozen author evidence; raw HTML was not independently retrieved.'
];
const findings = {
  submit: {
    definition: 'The narrowed object and purpose distinguish sending material for consideration from surrender, a legal assertion, or an arbitrary computer operation. The exact wording is accurate for the preserved sense ID.',
    example: 'The request has a deadline and is sent for consideration. The sentence is grammatical and gives the selected action without inventing a filing procedure.',
    difficulty: 'Accept editorial B2. Fresh Collins sense 2 explicitly displays B2; frozen Oxford sense-1 cefr=b2 corroborates it. The selected rendered Oxford sense did not display a level.',
    boundary: 'The Foundation02 form submission is compatible with consideration, but the expression remains pending with held verify and unintegrated correct. Care-system submission is unscored; submit-button is a separate noun.'
  },
  approve: {
    definition: 'Official agreement or acceptance is appropriate for the transitive plan/request decision. Read the broad object through that selected meaning; it does not merge approve of or certification.',
    example: 'A manager deciding on a revised schedule is a clear instance of official agreement. The example asserts no legal effect or product standard.',
    difficulty: 'Accept editorial B2 using Oxford selected sense 2 and its rendered B2 topic. Fresh Collins gives B1+ for this sense, not B2; B1+ is preserved rather than rounded.',
    boundary: 'Foundation02.03 has ordinary request decisions. Most other hits are approved modifiers or passive statuses whose authorization/suitability distinction is unresolved. Rights clearance remains specialist and unapproved.'
  },
  reject: {
    definition: 'Deciding against acceptance captures ordinary refusal. Proposal, request and item are possible objects, but this acceptance does not define quality-control criteria or biological rejection.',
    example: 'Does not meet the requirements is the idiomatic construction. The team may decline the proposal, and no requirement or professional procedure is prescribed.',
    difficulty: 'Accept editorial B1 for ordinary proposal/request refusal, supported by the fresh Oxford Business B1 topic and frozen cefr=b1. Collins explicitly displays B2, so source disagreement remains.',
    boundary: 'The only surface use is the ordinary request decision in Foundation02.03. Its pending expression gate remains. Reject-rate and employment/medical meanings receive no acceptance.'
  },
  sign: {
    definition: 'Writing a name for identification or agreement accurately isolates the document action. It does not promise that a mark establishes legal validity.',
    example: 'The attendance sheet gives a concrete name-writing purpose. It is an ordinary and natural request.',
    difficulty: 'Accept editorial A2 for this concrete document action, supported by the fresh Oxford selected A2 topics and frozen cefr=a2. Collins labels its corresponding verb B1; the A2 sign-board noun is not used as support.',
    boundary: 'All nine surface uses belong to other nouns, compounds or sign-in. Clinical signs, sign-off, electronic-signature rules and signature stamps remain distinct.'
  },
  delay: {
    definition: 'A wait caused by a late event is the selected countable/uncountable noun meaning. It does not describe deliberately putting off action or the causative verb.',
    example: 'A short delay with the delivery is natural ordinary workplace wording. It supplies no delivery guarantee or cause.',
    difficulty: 'Accept editorial A2 for this simple late-delivery noun using the freshly observed Collins sense-4 A2 label. Frozen Oxford sense-1 cefr=b2 is a material disagreement, not absent evidence. A2 is a bounded editorial choice.',
    boundary: 'Foundation02.02 remains held for the confirm/notify context. The transport expression uses a separately identified causative delay verb; production and delivery compounds remain separate.'
  },
  error: {
    definition: 'Incorrect information, work or operation fits ordinary mistake usage. The wording does not establish a technical error taxonomy, responsibility test or statistical quantity.',
    example: 'An incorrect telephone number is a clear, concrete instance of this noun. The in-complement is idiomatic.',
    difficulty: 'Accept editorial A2 for the concrete information-error sense. Frozen Oxford records fkcefr=a2 with no cefr attribute; this is retained literally, not described as freshly observed CEFR markup. Fresh Collins gives B2. The simple example and bounded meaning support the editorial choice despite that disagreement.',
    boundary: 'Foundation02.04 remains pending with held verify. Error budget, clinical errors, cutoff/payroll errors and system codes retain separate identities and domain gates. Oxford describes error as more formal than mistake.'
  },
  fault: {
    definition: 'The equipment/system restriction clearly selects an operational defect rather than blame. Preventing proper operation does not require complete equipment failure.',
    example: 'Developed a fault is a natural equipment collocation, and a printer is a concrete example. No diagnostic method or repair instruction is asserted.',
    difficulty: 'Accept editorial B2. Fresh Collins sense 3 includes technical faults and displays B2; frozen Oxford equipment sense 3 records cefr=b2. Collins responsibility-sense B1 is excluded.',
    boundary: 'Foundation02.06 names a reported defect and an authorized team; it remains pending. Diagnostic, repair and machine-safety contexts and fault compounds receive no specialist acceptance.'
  },
  damage: {
    definition: 'Physical harm reducing usefulness or sound condition is accurate for the selected mass noun. The definition does not encompass every abstract harmful effect.',
    example: 'Visible damage to an arriving box is a natural mass-noun use. The sentence does not infer cause or determine compensation.',
    difficulty: 'Accept editorial B1 for physical object harm using frozen Oxford sense-1 cefr=b1. Fresh Collins physical noun is B1+, retained literally. The rendered Oxford B2 abstract-harm topic and C1 legal sense are not this evidence.',
    boundary: 'Physical-harm uses and damage-report/surface-damage compounds stay unscored for this ID. Legal plural damages is a separate noun, not this noun pluralized; damaged and damaging are not accepted automatically.'
  },
  shortage: {
    definition: 'Insufficiency relative to a needed amount accurately defines the selected supply meaning. It does not identify the cause of the shortfall.',
    example: 'Packaging can denote needed supplies; a shortage of it can slow dispatch. The sentence is idiomatic and gives no inventory rule or allocation instruction.',
    difficulty: 'Accept editorial B2. Fresh Collins gives B2 and frozen Oxford records fkcefr=b2 with no cefr attribute. The Word-of-the-Day footer is unrelated and excluded.',
    boundary: 'Material and stock shortage compounds remain separately scored. Cash shortage is a discrepancy between counted and recorded cash and must not inherit the needed-supply definition. Short message is unrelated.'
  },
  missing: {
    definition: 'Absence from an expected or needed place is accurate and deliberately cause-neutral. It does not claim whether something was lost, removed or omitted.',
    example: 'A page can be missing from a document through absence or omission; the wording leaves that cause open and is idiomatic.',
    difficulty: 'Accept editorial A2. Frozen Oxford senses 1 and 4 each record cefr=a2. Fresh Collins senses 1 and 2 display A2, while omission sense 3 has no displayed level; no Collins omission label is invented.',
    boundary: 'Object and reference absences fit the ordinary adjective but remain unscored. Missing-value/invoice identities, missing-person status and miss/missed/near-miss constructions remain separate.'
  }
};
const fresh = {
  submit: {oxford: ['Transitive consideration sense 1, lines 112-123', null, 'Sending material to an authority for consideration; yielding and formal assertion are separate.'], collins: ['COBUILD sense 2, lines 235-242', 'B2', 'Formal submission for consideration or decision; unwilling submission is separate.']},
  approve: {oxford: ['Official-agreement sense 2, lines 144-177', 'B2 topic', 'Official agreement to plans/requests; favorable opinion and suitability certification are distinct.'], collins: ['COBUILD sense 3, lines 239-253', 'B1+', 'Authority accepts a plan; separate product/person suitability sense has no selected level.']},
  reject: {oxford: ['Proposal/request sense 1 and boundaries, lines 113-214', 'Business B1 topic', 'Ordinary refusal contrasted with candidates, quality and transplant meanings.'], collins: ['COBUILD sense 1, lines 224-231', 'B2', 'Proposal/request refusal; belief, applicant and interpersonal meanings are separate.']},
  sign: {oxford: ['Your-name sense 1, lines 113-150', 'A2 topics', 'Name-writing action distinguished from recruiting and gestures.'], collins: ['COBUILD document verb sense 6, lines 267-272', 'B1', 'Writing a name on a document; sign-board noun A2 does not label this verb.']},
  delay: {oxford: ['Waiting-period noun sense 1, lines 105-115; contrast sense 2 at 190-193', null, 'Waiting associated with something slow or late; failure to act promptly is separately numbered.'], collins: ['COBUILD variable-noun sense 4, lines 251-257', 'A2', 'An event occurs later than planned; verb labels and procrastination noun remain separate.']},
  error: {oxford: ['General mistake and synonym guidance, lines 103-139', null, 'Ordinary mistakes in facts/work; relative formality and separate technical links are visible.'], collins: ['COBUILD sense 1, lines 224-232', 'B2', 'Incorrect action or mistake; no A2 label appears on the selected rendered sense.']},
  fault: {oxford: ['Equipment-containing sense 3, lines 182-230', null, 'A machine/system defect interferes with proper operation; responsibility and geology are distinct.'], collins: ['COBUILD sense 3, lines 237-248', 'B2', 'Imperfection includes technical equipment faults; responsibility sense 1 is B1.']},
  damage: {oxford: ['Physical noun sense 1, lines 107-121; boundaries at 167-226', null, 'Physical harm is an uncountable noun; abstract effects and legal compensation are separate senses.'], collins: ['COBUILD physical noun sense 3, lines 248-253; boundaries at 255-266', 'B1+', 'Physical-harm mass noun; abstract effects and plural damages are separately listed.']},
  shortage: {oxford: ['Needed-quantity noun, lines 103-121', null, 'Insufficient needed resources; the B2 footer labels a different word.'], collins: ['COBUILD variable noun, lines 224-233', 'B2', 'Insufficient quantity; no shortage expresses abundance in a separate construction.']},
  missing: {oxford: ['Object sense 1, lines 105-119; omission sense 4, lines 188-197', null, 'Absent objects/pages and omitted content are distinct from missing-person senses.'], collins: ['COBUILD senses 1-3, lines 222-244', 'A2 senses 1 and 2; no level observed on sense 3', 'Lost objects, absent parts and omitted content are differentiated; person sense is separate.']}
};
const errors = [];
const check = (ok, message) => { if (!ok) errors.push(message); };
const sourceChecks = baseline.source_file_hashes.map(f => {
  const value = bytes(f.path);
  const actual = sha(value);
  check(actual === f.raw_sha256 && value.length === f.bytes, 'Source drift: ' + f.path);
  return {...f, observed_raw_sha256: actual, unchanged: actual === f.raw_sha256 && value.length === f.bytes};
});
for (const f of copy.files) {
  check(sha(bytes(research + '/' + f.path)) === f.sha256, 'Copy mismatch: ' + f.path);
  check(bytes(research + '/' + f.path).length === f.bytes, 'Copy length: ' + f.path);
  check(sha(bytes(copy.source_directory + '/' + f.path)) === f.sha256, 'Scratch mismatch: ' + f.path);
}
for (const f of inventory.artifacts) check(sha(bytes(research + '/' + f.path)) === f.sha256, 'Inventory mismatch: ' + f.path);
check(sha(bytes(research + '/inventory.json')) === copy.source_inventory_sha256, 'Original inventory mismatch');
check(sha(bytes(research + '/README.md')) === copy.readme_sha256, 'Delivery README mismatch');
// This exported helper reads JSON only. Neither the validator entry point nor its audit is executed.
const data = require(path.join(root, 'tools/validate-professional-content.cjs')).loadProfessionalContent(root);
check(hash(data) === baseline.registry_json_sha256, 'Loaded registry mismatch');
const liveLexemes = new Map(data.lexemes.map(e => [e.id, e]));
const liveExpressions = new Map(data.expressions.map(e => [e.id, e]));
for (const e of ledger.entries) {
  check(hash(e.before_entry) === e.before_entry_sha256, 'Before-entry hash: ' + e.id);
  check(hash(e.content_projection) === e.content_projection_sha256, 'Projection hash: ' + e.id);
  check(hash(liveLexemes.get(e.id)) === e.before_entry_sha256, 'Live preimage: ' + e.id);
  check(hash({...e.before_entry, ...e.proposed_fields}) === e.content_projection_sha256, 'Exact projected fields: ' + e.id);
  const changes = Object.keys(e.before_entry).filter(k => hash(e.before_entry[k]) !== hash(e.content_projection[k]));
  check(hash(changes) === hash(e.changed_fields), 'Declared changes: ' + e.id);
  check(changes.every(k => ['definition', 'example', 'difficulty'].includes(k)), 'Out-of-scope changes: ' + e.id);
}
for (const key of ['selected_entries', 'expression_uses', 'derivative_expression_uses', 'focus_expressions', 'related_entry_boundaries', 'previous_whole_entry_holds', 'additional_foundation02_preservation', 'containing_module_expressions']) {
  for (const e of context[key]) {
    check(hash(e.before_entry) === e.entry_json_sha256, 'Context preimage: ' + key + ':' + e.id);
    const live = e.id.startsWith('expr.') ? liveExpressions.get(e.id) : liveLexemes.get(e.id);
    check(hash(live) === e.entry_json_sha256, 'Live context: ' + key + ':' + e.id);
  }
}
for (const m of context.containing_modules) {
  const live = data.courses.find(c => c.id === m.course_id).modules.find(x => x.id === m.module_id);
  check(hash(live) === m.module_json_sha256 && hash(m.before_entry) === m.module_json_sha256, 'Containing module: ' + m.course_id);
}
for (const h of context.inherited_expression_holds) check(hash(liveExpressions.get(h.id)) === h.before_entry_json_sha256 && h.before_entry_json_sha256 === h.historical_expression_json_sha256 && hash(h.before_entry) === h.before_entry_json_sha256, 'Inherited hold: ' + h.id);
const thirdPath = 'docs/content-review/foundation-module02-language-third10-research-2026-10-17/candidate-ledger.json';
const third = read(thirdPath).entries.map(e => ({id: e.id, before_entry_sha256: e.before_entry_sha256, live_entry_sha256: hash(liveLexemes.get(e.id)), language: liveLexemes.get(e.id).review.language}));
for (const e of third) check(e.live_entry_sha256 === e.before_entry_sha256 && e.language === 'pending', 'Third10 drift: ' + e.id);
const counts = {
  scope: 'Catalog lexical entries only; expression flags are excluded from lexical totals.',
  lexemes: data.lexemes.length,
  raw_lexeme_language_reviewed: data.lexemes.filter(e => e.review.language === 'reviewed').length,
  overall_lexeme_status_reviewed: data.lexemes.filter(e => e.review.status === 'reviewed').length,
  foundation02_language_reviewed: read(ledger.input.path).lexemes.filter(e => e.review.language === 'reviewed').length,
  foundation02_total: 50,
  ready_modules: data.courses.flatMap(c => c.modules).filter(m => m.status === 'ready').length
};
check(counts.raw_lexeme_language_reviewed === 317 && counts.overall_lexeme_status_reviewed === 130 && counts.foundation02_language_reviewed === 18 && counts.ready_modules === 0, 'Production counts changed');
if (errors.length) throw new Error(JSON.stringify(errors));
const researchBindings = fs.readdirSync(path.join(root, research)).filter(f => fs.statSync(path.join(root, research, f)).isFile()).sort().map(f => ({path: research + '/' + f, raw_sha256: sha(bytes(research + '/' + f)), bytes: bytes(research + '/' + f).length}));
const entryBinding = e => ({id: e.id, resource: e.resource || null, entry_json_sha256: e.entry_json_sha256 || e.before_entry_json_sha256, before_review: e.before_entry.review, action: 'preserve_exact_no_acceptance_no_new_focus_binding'});
const entries = ledger.entries.map(e => ({
  id: e.id, term: e.term,
  decision: 'accept_exact_language_projection',
  candidate_record_json_sha256: hash(e),
  before_entry_sha256: e.before_entry_sha256,
  accepted_content_projection_sha256: e.content_projection_sha256,
  accepted_fields_sha256: hash(e.proposed_fields),
  before_fields: Object.fromEntries(['definition', 'example', 'difficulty'].map(k => [k, e.before_entry[k]])),
  accepted_fields: e.proposed_fields,
  changed_fields: e.changed_fields,
  field_decisions: Object.fromEntries(['definition', 'example', 'difficulty'].map(k => [k, {decision: 'accept', rationale: findings[e.term][k]}])),
  context_boundary: findings[e.term].boundary,
  source_ids: e.source_ids,
  research_note_json_sha256: hash(notes.entries.find(x => x.id === e.id)),
  scope: 'Only the exact three language fields are accepted. The full projection hash identifies the candidate context; it does not approve its preserved media, morphology, references or review flags.',
  production_mutated: false
}));
const observations = sources.sources.map(s => {
  const kind = s.publisher === 'Oxford University Press' ? 'oxford' : 'collins';
  const f = fresh[s.term][kind];
  const observation = metadata.observations.find(x => x.term === s.term);
  return {
    source_id: s.id, term: s.term, publisher: s.publisher, url: s.url,
    original_source_record_json_sha256: hash(s),
    source_index_raw_sha256: sha(bytes(research + '/source-index.json')),
    frozen_author_metadata: kind === 'oxford' ? {
      artifact: research + '/oxford-html-metadata.json', artifact_raw_sha256: sha(bytes(research + '/oxford-html-metadata.json')),
      observation_json_sha256: hash(observation), literal_selected_attributes: s.observed_html_selected_levels,
      author_raw_body_sha256: s.raw_body_sha256, author_raw_body_bytes: s.raw_body_bytes,
      provenance: 'Frozen author observation inspected; original HTML body was not retained and was not independently refetched. Body hash is an author observation, not an independent fresh-body hash.'
    } : null,
    independent_consultation: {
      date_local: '2026-10-17', timezone: 'Asia/Shanghai', method: 'Fresh web-connector open of the original publisher URL; rendered response inspected.',
      selected_section: f[0], observed_rendered_selected_level: f[1], independent_observation: f[2],
      fresh_raw_html_retrieval: false, fresh_raw_body_sha256: null,
      label_limit: 'No level is inferred from a missing selected label, another sense or footer. cefr and fkcefr evidence above remains author-frozen metadata.'
    },
    source_pages_imported: false, source_examples_imported: false, media_acquired: false
  };
});
const contextReview = {
  schema: 1, status: 'independent_language_context_screen_complete_no_context_acceptance', reviewer, recorded_at: date,
  source_context_raw_sha256: sha(bytes(research + '/context-screen.json')), source_context_summary: context.summary,
  manual_inspection_scope: 'Read every containing-module expression, all 130 surface-hit expressions, all 42 derivative-screen expressions and all 63 related lexical definitions/examples. Inspected the common 50-entry module, all 20 course identities, four selected-focus expressions and hold records. Repeated complete module objects were verified by exact equality and hash.',
  truncation_note: 'Initial broad display reads were truncated; bounded follow-up reads of the affected source, module, expression, related-identity and hold projections were completed before decisions. No claim relies on a truncated display.',
  containing_modules: context.containing_modules.map(m => ({course_id: m.course_id, module_id: m.module_id, module_json_sha256: m.module_json_sha256, selected_lexeme_ids: m.selected_lexeme_ids, status: m.before_entry.status})),
  selected_memberships: context.selected_memberships,
  containing_expressions: context.containing_module_expressions.map(entryBinding),
  surface_expressions: context.expression_uses.map(e => ({...entryBinding(e), text: e.before_entry.text, context: e.before_entry.context, existing_focus_lexeme_ids: e.before_entry.focus_lexeme_ids, matched_selected_ids: e.matches.map(m => m.selected_lexeme_id), independent_disposition: 'Language boundary inspected; retain existing scoring and gates.'})),
  derivative_expressions: context.derivative_expression_uses.map(e => ({...entryBinding(e), text: e.before_entry.text, context: e.before_entry.context, existing_focus_lexeme_ids: e.before_entry.focus_lexeme_ids, independent_disposition: 'Derivative/compound exclusion screen only; no acceptance transfer.'})),
  selected_focus_expressions: context.focus_expressions.map(entryBinding),
  related_identities: context.related_entry_boundaries.map(e => ({...entryBinding(e), text: e.before_entry.text, pos: e.before_entry.pos, independent_disposition: e.id.startsWith('cash-shortage.') ? 'Keep the counted-versus-recorded discrepancy distinct from insufficient needed supply.' : e.id.startsWith('damages.') ? 'Keep the legal compensation noun distinct from physical-harm damage, including its grammatical number.' : 'Preserve this distinct sense, derivative, compound or part of speech. No acceptance transfers.'})),
  term_boundary_decisions: entries.map(e => ({id: e.id, decision: e.context_boundary})),
  prior_lexical_holds: context.previous_whole_entry_holds.map(entryBinding),
  inherited_expression_holds: context.inherited_expression_holds.map(h => ({...entryBinding(h), historical_source: h.historical_source, historical_expression_json_sha256: h.historical_expression_json_sha256, historical_record_json_sha256: hash(h.historical_record), historical_review_matches: hash(h.before_entry.review) === hash(h.review_before)})),
  additional_foundation02_preservation: context.additional_foundation02_preservation.map(entryBinding),
  complete_form_image_mismatch: {id: 'complete.finish.v', entry_json_sha256: context.complete_existing_form_scope_mismatch.entry_json_sha256, image_record_json_sha256: hash(context.complete_existing_form_scope_mismatch.before_entry.media.image), action: 'Preserve live mismatched form-image brief, pending and unapproved. Finishing-sense language acceptance does not make the picture ready.'},
  third10: {candidate_ledger: thirdPath, candidate_ledger_raw_sha256: sha(bytes(thirdPath)), status: 'unintegrated_all_ten_live_entries_match_original_preimages', entries: third},
  no_new_scored_bindings: true, no_expression_acceptance: true, limits
};
const inputAudit = {
  schema: 1, status: 'passed_independent_static_evidence_comparison', recorded_at: date,
  scope: 'Read-only hash/equality/count comparison, not a test suite, full content validation, native execution or build.',
  assembly_source_raw_sha256: sha(fs.readFileSync(__filename)), errors,
  exact_candidate_records: 10, exact_language_projections: 10, changed_entries: 6, allowed_change_fields: ['definition', 'example', 'difficulty'],
  copied_artifacts_checked: copy.files.length, original_inventory_artifacts_checked: inventory.artifacts.length,
  original_author_inventory_sha256: copy.source_inventory_sha256,
  registry_json_sha256: hash(data), target_raw_sha256: sha(bytes(ledger.input.path)),
  source_files: sourceChecks, research_artifacts: researchBindings,
  production_counts: counts,
  exploratory_count_correction: 'An initial exploratory count added lexeme and expression flags, yielding 369 language and 168 overall across 6,559 entries. Those are combined-type counts, not the lexical metrics. The verified lexical totals are 317 and 130 across 4,939 entries; 1,620 expressions are separate. An exploratory hash of the file inventory was also not the registry hash; the registry hash here uses the unchanged read-only loader object.',
  author_scripts_executed: false, shared_tests_executed: false, native_execution: false, build_execution: false, production_writes: 0
};
const save = (name, value) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
save('review-ledger.json', {schema: 1, status: 'independently_accepted_language_projections_not_integrated', reviewer, recorded_at: date, date_local: '2026-10-17', research_directory: research, candidate_ledger_raw_sha256: sha(bytes(research + '/candidate-ledger.json')), research_artifacts: researchBindings, input_registry_json_sha256: hash(data), hash_convention: 'SHA256 of raw bytes for files; SHA256 of UTF-8 JSON.stringify(value), preserving parsed key order, for JSON values.', accepted: 10, held: 0, accepted_field_decisions: 30, limits, entries});
save('source-observations.json', {schema: 1, status: 'fresh_rendered_consultation_and_frozen_metadata_distinguished', reviewer, recorded_at: date, freshly_consulted_original_pages: 20, fresh_raw_html_pages: 0, failed_accesses: [], observations, limits});
save('context-review.json', contextReview);
save('input-audit.json', inputAudit);
const readme = `# Foundation02 fourth-ten independent language review\n\nAll ten exact definition/example/editorial-difficulty projections are independently accepted for AI language review only. This reviewer is separate from the research author. The accepted projections remain unintegrated; this review changes no production content, source registry, notes, references or approval gates.\n\nAccepted levels: submit B2; approve B2; reject B1; sign A2; delay A2; error A2; fault B2; damage B1; shortage B2; missing A2. Six entries have content changes in their proposed projections. Each of the thirty field decisions has a separate rationale in review-ledger.json.\n\nThe review freshly consulted all twenty original Oxford and Collins pages as rendered through the web connector. Literal Oxford cefr/fkcefr attributes and body hashes were inspected only in frozen author evidence. No raw HTML was independently retrieved, and no publisher pages, examples, exercises, audio or artwork were imported. Source disagreements, Collins B1+, and missing labels are explicit in source-observations.json and the field decisions.\n\nContext inspection covers twenty identical containing modules and two hundred memberships, all ten containing expressions, 130 surface expressions, 42 derivative contexts, four selected-focus expressions and 63 related identities. Context review preserves existing scoring. It accepts no expression or specialist use. Four earlier whole-entry lexical holds, seventeen inherited expression holds and Foundation02.04/.05/.07/.08 remain exact. Third10 is unintegrated. Complete's old form-image brief remains live, mismatched, pending and unapproved.\n\nIndependent static comparison found zero drift across all 355 author-bound source/evidence files, all sixteen copied artifacts, ten candidate preimages and exact projections. Raw lexical language-reviewed flags remain 317; lexical overall-reviewed flags remain 130. Foundation02 remains 18/50 language-reviewed and zero modules are ready. Expression counts are separate. No tests, native execution, export, packaging, build or deployment ran for this review.\n\nThe authoritative candidate ledger SHA256 is ${sha(bytes(research + '/candidate-ledger.json'))}. The original author inventory SHA256 is ${copy.source_inventory_sha256}. The loaded registry JSON SHA256 is ${hash(data)}. Full per-entry, per-source, context and research hashes are in the JSON artifacts. artifact-inventory.json binds every delivery file except itself.\n\nThis package is immutable evidence. Do not rerun either author scripts or this completed delivery script. Any revision requires new artifacts with explicit lineage.\n`;
fs.writeFileSync(path.join(__dirname, 'README.md'), readme, {flag: 'wx'});
// Verify unchanged evidence again after writing the independent output, before freezing it.
for (const f of sourceChecks) if (sha(bytes(f.path)) !== f.raw_sha256) throw new Error('Late source drift: ' + f.path);
for (const f of researchBindings) if (sha(bytes(f.path)) !== f.raw_sha256) throw new Error('Late research drift: ' + f.path);
const artifacts = fs.readdirSync(__dirname).filter(f => f !== 'artifact-inventory.json').sort().map(f => { const b = fs.readFileSync(path.join(__dirname, f)); return {path: f, raw_sha256: sha(b), bytes: b.length}; });
save('artifact-inventory.json', {schema: 1, status: 'frozen_independent_language_review', recorded_at: new Date().toISOString(), reviewer, accepted: 10, held: 0, production_mutated: false, source_files_unchanged: 355, research_artifacts_unchanged: researchBindings.length, registry_json_sha256: hash(data), production_counts: counts, artifacts, self_excluded: true});
console.log(JSON.stringify({status: 'frozen', accepted: 10, held: 0, files: artifacts.length + 1, artifacts, inventory_raw_sha256: sha(fs.readFileSync(path.join(__dirname, 'artifact-inventory.json'))), counts}, null, 2));
