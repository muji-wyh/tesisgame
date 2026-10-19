'use strict';

// Research artifact assembly only. No project modules, serializers, validators or tests.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const owned = path.resolve(root, 'build/professional-english/foundation02-verify-resolution-research-r01');
if (path.resolve(__dirname) !== owned || !root.toLowerCase().startsWith('q:' + path.sep)) throw new Error('Unexpected research workspace');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const objectHash = value => hash(JSON.stringify(value));
const clone = value => JSON.parse(JSON.stringify(value));
const localPath = resource => resource.replace(/^res:\/\//, '');
const catalog = read('data/professional/catalog.json');
const lexemes = catalog.lexeme_files.flatMap(resource => read(localPath(resource)).lexemes.map((entry, index) => ({ file: localPath(resource), index, entry })));
const expressions = catalog.expression_files.flatMap(resource => read(localPath(resource)).expressions.map((entry, index) => ({ file: localPath(resource), index, entry })));
const courses = catalog.courses.map(info => ({ file: localPath(info.manifest), entry: read(localPath(info.manifest)) }));
const oldId = 'verify.establish-accuracy.v';
const newId = 'ensure.make-certain.v';
const expressionId = 'expr.foundation.module02.04';
const target = lexemes.find(row => row.entry.id === oldId);
const phrase = expressions.find(row => row.entry.id === expressionId);
if (!target || !phrase || objectHash(target.entry) !== 'd900dc371a4f37e536e5b252470b50fc85e988fc799ab279f2ef836e9ea43e9a') throw new Error('Target changed; fresh research rebase required');
const membershipsFor = (field, id) => courses.flatMap(course => course.entry.modules.filter(module => module[field].includes(id)).map(module => ({
  course_id: course.entry.id, course_file: course.file, course_revision: course.entry.curriculum_revision,
  module_id: module.id, requirements_revision: module.requirements_revision, module_status: module.status,
  membership_index: module[field].indexOf(id), occurrences: module[field].filter(value => value === id).length,
  vocabulary_count: module.lexeme_ids.length, unique_vocabulary_count: new Set(module.lexeme_ids).size,
  expression_count: module.expression_ids.length, unique_expression_count: new Set(module.expression_ids).size,
  course_unique_vocabulary_count: new Set(course.entry.modules.flatMap(value => value.lexeme_ids)).size,
  course_unique_expression_count: new Set(course.entry.modules.flatMap(value => value.expression_ids)).size,
  course_contains_proposed_new_id: course.entry.modules.some(value => value.lexeme_ids.includes(newId))
})));
const memberships = membershipsFor('lexeme_ids', oldId);
const phraseMemberships = membershipsFor('expression_ids', expressionId);
const verifyPattern = /\bverif(?:y|ies|ied|ying)\b/i;
const ensurePattern = /\bensur(?:e|es|ed|ing)\b/i;
const fields = entry => ({ text: entry.text, display_text: entry.display_text, definition: entry.definition, example: entry.example, brief: entry.media.image.brief });
const matches = (entry, regex, names) => Object.fromEntries(names.filter(name => regex.test(entry[name] || '')).map(name => [name, entry[name]]));
const duplicateCandidates = lexemes.filter(row => row.entry.id === newId || [row.entry.text, row.entry.display_text, ...row.entry.accepted_forms].some(value => /^(ensure|insure|assure)$/i.test(value)));
const expressionUses = expressions.map(row => ({ ...row, surface_fields: matches(row.entry, verifyPattern, ['text', 'meaning', 'context']), direct_focus: row.entry.focus_lexeme_ids.includes(oldId) }))
  .filter(row => row.direct_focus || Object.keys(row.surface_fields).length)
  .map(row => ({ ...row, entry_object_sha256: objectHash(row.entry), memberships: membershipsFor('expression_ids', row.entry.id) }));
const ensureUses = expressions.filter(row => ensurePattern.test(JSON.stringify([row.entry.text, row.entry.meaning, row.entry.context])))
  .map(row => ({ file: row.file, id: row.entry.id, surface_fields: matches(row.entry, ensurePattern, ['text', 'meaning', 'context']), focus_lexeme_ids: row.entry.focus_lexeme_ids }));
const relatedLexemes = lexemes.filter(row => /verif|ensur|insur|assur|double-check/.test(row.entry.id + ' ' + row.entry.text))
  .map(row => ({ ...row, entry_object_sha256: objectHash(row.entry), memberships: membershipsFor('lexeme_ids', row.entry.id) }));
const lexicalUses = lexemes.filter(row => verifyPattern.test(JSON.stringify(fields(row.entry))))
  .map(row => ({ file: row.file, id: row.entry.id, entry_object_sha256: objectHash(row.entry), fields: fields(row.entry) }));
const neighbors = phrase.entry.focus_lexeme_ids.filter(id => id !== oldId).map(id => {
  const row = lexemes.find(value => value.entry.id === id);
  return { ...row, entry_object_sha256: objectHash(row.entry) };
});
const alternateExisting = ['check.examine.v', 'confirm.verify-arrangement.v', 'compare.examine-differences.v', 'test.check-behavior-under-defined-conditions.v', 'inspect.examine-visually.v'];
const existingAlternatives = lexemes.filter(row => alternateExisting.includes(row.entry.id)).map(row => ({ file: row.file, id: row.entry.id, text: row.entry.text,
  definition: row.entry.definition, example: row.entry.example, difficulty: row.entry.difficulty, review: row.entry.review,
  memberships: membershipsFor('lexeme_ids', row.entry.id) }));
const sourceRows = read(localPath(catalog.sources)).sources;
const sourceIds = ['foundation02-verify-resolution-oxford-ensure', 'foundation02-verify-resolution-collins-ensure', 'foundation02-verify-resolution-cefrj-ensure-v15'];
if (sourceIds.some(id => sourceRows.some(row => row.id === id))) throw new Error('Proposed source identity now exists');
if (duplicateCandidates.length || memberships.length !== 20 || phraseMemberships.length !== 20 || memberships.some(row => row.module_id !== 'module02' || row.occurrences !== 1 || row.course_contains_proposed_new_id)) throw new Error('Coverage assumptions changed');

const after = clone(target.entry);
Object.assign(after, {
  id: newId, text: 'ensure', display_text: 'ensure',
  definition: 'To make certain that a required result happens or a required condition is met.',
  example: 'Please ensure that the form includes the reference number.',
  difficulty: 'B2', accepted_forms: ['ensure'], regions: ['general'], morphology: null,
  review: { status: 'pending', language: 'pending', domain: 'not_required', reviewer: null, reviewed_at: null },
  references: sourceIds.map(source_id => ({ source_id, status: 'pending_term_check', scope: 'New ensure outcome sense and original wording proposed for independent language review. Source consultation does not grant acceptance.' })),
  editorial_notes: 'Proposed new shared workplace foundation sense: making a required result or condition certain. This is a curriculum replacement for held verify, not a rename, synonym alias, or transfer of evidence-checking mastery. Editorial B2 is proposed from selected Oxford and Collins B2 evidence; the CEFR-J v1.5 headword/POS row remains B1. The canonical ensure form is used in this candidate. The attested insure variant, especially North American, remains a separate pending regional/form decision; it is not declared incorrect English or conflated with financial insurance. Historical origin does not by itself approve a modern en + sure teaching graph; morphology is unauthored. Image, word audio, expression, curriculum coverage, retirement and progress/revision decisions remain pending.'
});
after.media.image.brief = 'A short three-stage workplace illustration: a friendly worker notices an empty reference-number field on a fictional workshop form, adds the required number, and places the completed form in a submission tray. Emphasize achieving the required inclusion of the number, without suggesting that its accuracy has been established. No real personal information.';
const afterPhrase = clone(phrase.entry);
afterPhrase.text = 'Please check the form, correct any error, and ensure that the reference number is included before you submit it.';
afterPhrase.meaning = 'Ask someone to examine a form, remove mistakes, and make certain it contains a reference number before sending it for processing.';
afterPhrase.context = 'A worker prepares a fictional workshop registration form. Its reference number must be entered before the form is sent for routine processing.';
afterPhrase.tokens = [...afterPhrase.text.matchAll(/[A-Za-z]+(?:['-][A-Za-z]+)*|[^\s]/g)].map((match, index) => ({ index, text: match[0], start: match.index, end: match.index + match[0].length }));
afterPhrase.focus_lexeme_ids = afterPhrase.focus_lexeme_ids.map(id => id === oldId ? newId : id);
afterPhrase.references.push(...sourceIds.slice(0, 2).map(source_id => ({ source_id, status: 'pending_term_check', scope: 'Proposed ensure-that outcome clause only; the full original sentence and all assessed neighboring senses await separate expression review.' })));
const locate = (entry, surface) => entry.tokens.filter(token => token.text.toLowerCase() === surface);
const bindings = [
  [oldId, newId, 'verify', 'ensure', 'Outcome responsibility replaces evidence-based accuracy checking. This changes the assessed target.'],
  ['correct.put-right.v', 'correct.put-right.v', 'correct', 'correct', 'Removing a form error fits the reviewed put-right sense; this full sentence is still pending.'],
  ['error.mistake.n', 'error.mistake.n', 'error', 'error', 'An incorrect item on a fictional form; captured pending neighbor requires the later fourth-ten review state.'],
  ['check.examine.v', 'check.examine.v', 'check', 'check', 'Examination of a form for correctness fits the reviewed ordinary verb.'],
  ['submit.send-for-consideration.v', 'submit.send-for-consideration.v', 'submit', 'submit', 'The form is sent for routine processing; captured pending neighbor requires the later fourth-ten review state.']
].map(([old_id, new_id, old_surface, new_surface, boundary]) => ({ old_id, new_id, before: locate(phrase.entry, old_surface), proposed_after: locate(afterPhrase, new_surface), boundary }));
if (bindings.some(row => row.before.length !== 1 || row.proposed_after.length !== 1)) throw new Error('Focus binding requires manual re-review');
if (afterPhrase.tokens.some(token => afterPhrase.text.slice(token.start, token.end) !== token.text) || afterPhrase.tokens.map(token => token.text).join('') !== afterPhrase.text.replace(/\s/g, '')) throw new Error('Proposal token artifact mismatch');
const affected = memberships.map(row => ({ ...row, operation: 'replace_exact_membership_at_same_index', before: oldId, proposed_after: newId,
  proposed_vocabulary_count: row.vocabulary_count, proposed_unique_vocabulary_count: row.unique_vocabulary_count,
  proposed_course_unique_vocabulary_count: row.course_unique_vocabulary_count,
  apply_status: 'not_applied_pending_independent_curriculum_and_revision_review' }));
const fullSnapshot = {
  status: 'research_only_unaccepted', captured_at: new Date().toISOString(), consultation_date_local: '2026-10-17', timezone: 'Asia/Shanghai',
  workspace: root.replace(/\\/g, '/'), catalog_revision_observed: catalog.curriculum_revision,
  shared_baseline_warning: 'Source registry, compiled registry, serializers, tests and release baselines are deliberately not pinned here. All shared mutation baselines must be prepared after the actual fourth-ten delivery and other writers settle.',
  counts: { courses: courses.length, modules: courses.reduce((sum, row) => sum + row.entry.modules.length, 0), lexemes: lexemes.length, expressions: expressions.length,
    target_memberships: memberships.length, target_expression_memberships: phraseMemberships.length, direct_focus_expressions: expressionUses.filter(row => row.direct_focus).length,
    verify_inflection_expression_uses: expressionUses.length, verify_inflection_expression_text_uses: expressionUses.filter(row => row.surface_fields.text).length,
    verify_inflection_lexical_uses: lexicalUses.length, related_lexemes: relatedLexemes.length, ensure_inflection_expression_uses: ensureUses.length, ensure_insure_assure_identity_or_form_matches: duplicateCandidates.length },
  target: { ...target, entry_object_sha256: objectHash(target.entry) }, assessed_expression: { ...phrase, entry_object_sha256: objectHash(phrase.entry) },
  memberships, expression_memberships: phraseMemberships, neighboring_focus_entries: neighbors, existing_alternatives: existingAlternatives,
  proposed_identity_and_form_collisions: duplicateCandidates, verify_inflection_expression_uses: expressionUses,
  verify_inflection_lexical_uses: lexicalUses, ensure_inflection_expression_uses: ensureUses, related_lexemes: relatedLexemes,
  scan_limits: ['Only the source files named by the live Professional catalog were scanned for these semantic inventories.', 'Inflection scan includes verify, verifies, verified and verifying in expression text, meaning and context; lexical scan covers headword/display, definition, example and pending image brief.', 'Related identity scan covers verif/ensur/insur/assur and double-check substrings and records full objects. Surface matches are not automatic focus bindings or permission for bulk substitution.', 'Growth content and generated bundles were not searched or edited by this research pass.']
};
const historicalPaths = [
  'build/professional-english/foundation02-held-six-research-r01/inventory.json',
  'build/professional-english/foundation02-held-six-research-r01/PROPOSALS.md',
  'build/professional-english/foundation02-held-six-research-r01/SOURCE-LEDGER.md',
  'build/professional-english/foundation02-held-six-research-r01/retained-reviews/1.json',
  'build/professional-english/foundation02-held-six-research-r01/retained-reviews/2.json',
  'build/professional-english/foundation02-held-six-research-r01/retained-reviews/3.json',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/REVIEW.md',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/reviewer-decisions.json',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/inventory.json'
];
const historicalPins = historicalPaths.map(file => { const bytes = fs.readFileSync(path.join(root, file)); return { file, bytes: bytes.length, sha256: hash(bytes), status: 'historical_unchanged_not_new_acceptance' }; });
const sourceAdditions = [
  { id: sourceIds[0], title: "Oxford Advanced Learner's Dictionary: ensure outcome sense", publisher: 'Oxford University Press', url: 'https://www.oxfordlearnersdictionaries.com/definition/english/ensure', status: 'consulted', consulted_on: '2026-10-17', scope: 'Selected ensure_sng_1 has fkcefr=b2; selected certainty topic renders B2. Outcome meaning and ensure-that pattern consulted. The separate footer level is excluded. No independent term, morphology, image, audio, expression or curriculum acceptance.', asset_license: null, assets_acquired: false },
  { id: sourceIds[1], title: 'Collins COBUILD Dictionary: ensure outcome verb', publisher: 'HarperCollins', url: 'https://www.collinsdictionary.com/dictionary/english/ensure', status: 'consulted', consulted_on: '2026-10-17', scope: 'Selected COBUILD outcome verb explicitly shows B2 and formal register. Original proposed wording is not copied from dictionary examples. No independent term, morphology, image, audio, expression or curriculum acceptance.', asset_license: null, assets_acquired: false },
  { id: sourceIds[2], title: 'The CEFR-J Wordlist Version 1.5: ensure verb', publisher: 'Tono Laboratory, Tokyo University of Foreign Studies; hosted by Open Language Profiles', url: 'https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv', status: 'consulted', consulted_on: '2026-10-17', scope: 'Exact ensure verb row is B1 at physical line 2270. This headword/POS placement is not selected-sense certification and is not rewritten as B2. Citation: The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Accessed October 17, 2026 via Open Language Profiles. Research and commercial use require proper citation; copyright Tono Laboratory at TUFS. The separate Octanove CC BY-SA license is not applied. No v1.6 workbook was acquired.', asset_license: null, assets_acquired: false }
];
const observations = {
  status: 'author_consultation_only_unaccepted', date_local: '2026-10-17',
  rendered_pages: [
    { id: 'O-verify', url: 'https://www.oxfordlearnersdictionaries.com/definition/english/verify', selected_section: 'Verb senses 1 and 2', observation: 'Checking truth/accuracy is distinct from showing or stating truth. Both raw selected sense tags carry cefr=c1. Formal register. Rendered Scientific research C1 belongs to sense 1. Footer reasonably B2 is excluded.' },
    { id: 'C-verify', url: 'https://www.collinsdictionary.com/dictionary/english/verify', selected_section: 'COBUILD verb senses 1 and 2', observation: 'Careful examination/investigation supports the current evidence-checking meaning; a separate sense states or confirms truth. Neither selected sense displays a level. Context fit is not lower-level evidence.' },
    { id: 'O-ensure', url: 'https://www.oxfordlearnersdictionaries.com/definition/english/ensure', selected_section: 'Outcome/certainty verb; ensure_sng_1', observation: 'Making an event happen or a condition definite. Selected certainty topic is B2, and raw tag has fkcefr=b2, not cefr=b2. Ensure-that is attested. Insure is also admitted especially in North American English. Historical borrowing is not a reviewed teaching analysis.' },
    { id: 'C-ensure', url: 'https://www.collinsdictionary.com/dictionary/english/ensure', selected_section: 'COBUILD verb, rendered lines 218-237', observation: 'Outcome verb explicitly B2, formal, with a that-clause pattern. Other dictionary sections discuss protection and insurance senses, which the proposed meaning excludes. No automatic examples or publisher recordings were acquired.' }
  ],
  raw_http_evidence: 'fresh-http-metadata.json',
  search_conclusion: 'No reliable A2-B2 selected-sense evidence for verify was established. Do not average away Oxford C1 or infer a level from teacher wording, learner comments, collocation headwords, exam verification pages or unrelated page navigation.',
  failed_retrievals: [
    { url: 'https://dictionary.cambridge.org/dictionary/english/ensure', method: 'web open', result: 'Internal Error; no inspected Cambridge sense or level evidence claimed.' },
    { url: 'https://dictionary.cambridge.org/dictionary/english/verify', method: 'web open', result: 'Internal Error; no inspected Cambridge sense or level evidence claimed.' }
  ],
  retrieval_correction: 'A web open with an unsupported num_lines parameter was rejected before retrieval; the corrected request yielded Collins verify and the two Cambridge errors above.',
  acquisition: { publisher_documents_saved: false, selected_metadata_and_one_profile_row_only: true, artwork_acquired: false, recordings_acquired: false, pronunciation_played: false, publisher_content_redistribution_license_acquired: false }
};
const revisionDecision = {
  status: 'proposed_policy_not_implemented_or_accepted', old_sense_id: oldId, proposed_new_sense_id: newId,
  actual_current_revision_observed: catalog.curriculum_revision, proposed_future_revision: null,
  reason_new_identity: 'Verify checks evidence for accuracy; ensure makes a required result/condition certain. These learning targets are different. Neither ensure, check nor confirm is a mastery alias for verify.',
  skill_history: 'Retain every existing verify skill record and event unchanged under the old ID. Create no ensure history and copy no earned flags, streaks, exposures or rewards. New ensure skills must be earned independently and may then be shared across careers by its new canonical ID.',
  expression_history: 'Keep expr.foundation.module02.04 as the module slot identity only under a fresh requirements namespace. Keep all old expression completion records and receipts untouched. Copy none into the new namespace. The changed text and new focus are materially different assessed requirements.',
  engine_observation: 'Both inspected progress implementations keep skills by sense ID; expression completion uses course/module/requirements_revision plus expression ID. Requirement fingerprints include term IDs/skills and expression IDs, not expression text. Changing the term ID under professional-v1 conflicts with a visited fingerprint; changing only sentence text would escape that protection.',
  old_id_readability: 'Inspected validate_progress functions validate historical skill-key syntax and evidence shape without requiring membership in the current registry. This suggests retired IDs can remain readable; runtime/persistence compatibility still requires later focused testing. No database was read or edited.',
  coordinated_release_scope: ['Select an unused reviewed curriculum revision after all sibling content decisions settle.', 'Current validator requires all 20 course revisions to match the catalog revision and all 200 module requirement revisions to match their course. Update catalog, all courses/modules, generated manifests and compiled requirements/policies together.', 'Retain legacy saved requirements, skills, expression completions, module receipts, pending events/outbox and reward identities unchanged. Do not globally wipe or relabel history.', 'Handle an old active learning context or frozen round by explicit revision selection/reload; never silently score its verify answer as ensure.', 'Consider unaffected-module completion carry-forward separately; a global namespace change must not blindly copy changed assessments or erase historical achievements. No carry-forward is authorized by this packet.'],
  test_requirements_for_future_implementation: ['A legacy verify skill does not satisfy ensure.', 'Legacy module02 expression completion does not satisfy the rewritten expression in the new revision.', 'Legacy history and receipts remain byte-equivalent after load/save with new registry.', 'New ensure correct unassisted evidence is shared by new canonical ID across careers without affecting Growth.', 'Old pending/frozen events fail clearly or stay bound to their legacy context; rewards remain idempotent.', 'All 20 module02 membership substitutions preserve 50 unique terms and all 20 courses preserve 500 unique terms.'],
  tests_run: false
};
const retirement = {
  status: 'proposed_future_action_not_applied', retained_live_hold: true,
  current_object_sha256: objectHash(target.entry), exact_archival_object: 'lexeme-before.json',
  current_source: target.file, current_index: target.index,
  rationale: 'Once all 20 memberships move, retaining verify in any active catalog-listed lexeme file creates membership.orphan under the current validator. There is no retired-entry schema switch in the inspected contract.',
  proposal: ['Before an accepted implementation removes the old active object, preserve its exact object, original source location, object hash, twenty memberships, all old hold/review references and retirement reason in durable content-review evidence outside catalog.lexeme_files.', 'Replace the old active object at its source array position with the separately reviewed ensure object and substitute exactly the 20 memberships. Never change the old object ID or text in place and describe that as a rename.', 'Keep historical verify sources and research/hold snapshots immutable. Do not remove shared morphology parts or references solely because this one active entry retires.', 'Do not add a dummy membership just to evade orphan detection or inflate the 500-term quota.', 'A future course genuinely teaching verify would require explicit scope/level review, the original canonical evidence-checking identity if semantically unchanged, and its own membership/revision decision. This packet does not reserve or approve such a course.'],
  runtime_archive_path: null,
  archive_location_rule: 'Choose and freeze a durable docs/content-review retirement snapshot during the future coordinated delivery. It must not be named in catalog.lexeme_files. This research folder is evidence, not a runtime retirement system.',
  unresolved: ['Independent curriculum approval to replace a foundation learning objective.', 'Independent language/expression and regional-form decision.', 'Complete morphology/media review and actual source/registry rebase after fourth-ten delivery.', 'Focused compatibility verification before activating the new revision.']
};
const impact = {
  status: 'proposed_scope_not_applied', recommendation: 'Retain verify hold now; submit the exact new ensure candidate for independent language and curriculum review.',
  coverage: 'Swap one distinct target in each of 20 Module02 lists; no additional term or expression count is claimed. The live duplicate scan found no ensure/insure/assure headword, display or accepted-form match.',
  discarded_shortcuts: ['Relabelling verify A2/B2 lacks selected lower-level evidence.', 'Replacing verify with check duplicates an existing Module02 member and an existing focus in the same expression.', 'Confirm is already in Module02 and its accepted arrangement sense is different.', 'Double-check adds repeat-checking meaning and lacks inspected level evidence in this packet.', 'Compare and other existing action entries require their own coverage and duplicate analysis rather than an automatic synonym swap.'],
  neighboring_entries: neighbors.map(row => ({ id: row.entry.id, snapshot_sha256: row.entry_object_sha256, observed_review: row.entry.review, change: 'none; snapshot only; rebase to actual fourth-ten delivery before expression acceptance' })),
  other_expression_uses: expressionUses.filter(row => row.entry.id !== expressionId).map(row => ({ file: row.file, id: row.entry.id,
    exact_object_sha256: row.entry_object_sha256, matched_fields: Object.keys(row.surface_fields), direct_verify_focus: row.direct_focus,
    action: 'Preserve exact current object. Queue contextual level/readability review; no bulk verify-to-ensure substitution or specialist approval. A surface occurrence does not bind this old canonical skill.' })),
  other_lexical_uses: 'All retained lexical verify inflections and related verification/insurance/assurance identities require their own level and domain decisions. This proposal resolves only one assessed foundation slot if accepted; it does not certify every expression or description as A2-B2.',
  ensure_context_uses: 'Existing unscored ensure occurrences are retained in context.json as a boundary inventory. They neither reserve the new canonical identity nor prove that every such occurrence has the selected outcome meaning.',
  morphology: 'Null in the new candidate records unauthored morphology. Do not carry over veri + fy or declare ensure atomic without linguistic review. Word Jelly remains a draft mode declaration with no usable analysis.',
  media: 'Both new word and changed expression retain pending Ava Sweet audio. No prior per-term approval transfers. The picture brief is newly authored and unaccepted; picture_suitable remains false. No sources, creators or licenses are fabricated.',
  gates: { verify_language_hold: 'unchanged', new_word_language: 'pending', new_word_overall: 'pending', full_expression: 'pending', curriculum_replacement: 'pending', regional_variant: 'pending', morphology: 'unauthored', word_image: 'pending_not_acquired', word_audio: 'pending_not_acquired', expression_audio: 'pending_not_acquired', visual_acceptance: 'none', listening_acceptance: 'none', module_ready: false, release: false }
};
const changedTopKeys = (before, candidate) => [...new Set([...Object.keys(before), ...Object.keys(candidate)])].filter(key => JSON.stringify(before[key]) !== JSON.stringify(candidate[key]));
const outputs = {
  'context.json': fullSnapshot,
  'lexeme-before.json': target.entry,
  'lexeme-after.proposed.json': after,
  'expression-before.json': phrase.entry,
  'expression-after.proposed.json': afterPhrase,
  'membership-substitutions.proposed.json': { status: 'unaccepted_not_applied', substitutions: affected, expression_memberships_unchanged: phraseMemberships },
  'token-and-binding-review.json': { status: 'author_mapping_not_expression_acceptance', before_text: phrase.entry.text, proposed_text: afterPhrase.text, before_token_count: phrase.entry.tokens.length, proposed_token_count: afterPhrase.tokens.length, bindings, repeated_surface_note: 'The two occurrences of the in the proposed sentence retain distinct token positions. All punctuation tokens and offsets are explicit in the full expression object.' },
  'source-additions.proposed.json': { status: 'unaccepted_not_appended', sources: sourceAdditions },
  'source-observations.json': observations,
  'history-pins.json': { status: 'historical_evidence_preserved', files: historicalPins },
  'progress-revision-decision.proposed.json': revisionDecision,
  'retirement-decision.proposed.json': retirement,
  'impact-decisions.json': impact,
  'patches.proposed.json': { status: 'research_only_not_an_installable_patch', old_object_sha256: objectHash(target.entry), proposed_new_object_sha256: objectHash(after), before_expression_object_sha256: objectHash(phrase.entry), proposed_expression_object_sha256: objectHash(afterPhrase),
    operation: 'reviewed_new_identity_substitution_with_durable_old_object_retirement', lexical_changed_top_level_keys: changedTopKeys(target.entry, after), expression_changed_top_level_keys: changedTopKeys(phrase.entry, afterPhrase),
    lexical_unchanged_projections: ['pos', 'practice_modes', 'media.audio', 'media.image fields other than brief', 'review'],
    phrase_unchanged_projections: ['id', 'practice_modes', 'media', 'review', 'existing references prefix'],
    source_registry_baseline: null, compiled_registry_baseline: null, test_baselines: null, release_revision: null,
    deferred_reason: 'Actual shared baselines and new revision must follow the completed fourth-ten delivery and independent acceptance. This packet runs no project code and contains no integration command.' }
};

outputs['README.md'] = `# Verify: proposed B2 curriculum replacement r01

This research retains the whole-entry hold on \`${oldId}\`. Fresh selected Oxford metadata remains C1, Collins supplies meaning support without a selected level, and CEFR-J v1.5 has no exact verify row. None of those observations justifies the live draft A2 label.

The recommended next review is a new outcome sense, \`${newId}\`, at proposed editorial B2. Oxford's selected ensure tag has \`fkcefr=b2\`; Collins explicitly labels the selected outcome verb B2. The separate CEFR-J headword/POS row is B1 and remains B1. This is a different curriculum objective, not a synonym alias, renamed verify entry, or transfer of mastery.

## Exact proposed content

| Field | Proposed value |
| --- | --- |
| Identity / display | \`${newId}\` / ensure |
| Definition | ${after.definition} |
| Example | ${after.example} |
| Difficulty / form / region | B2 proposed / ensure / general |
| Expression | ${afterPhrase.text} |

The sentence first requests examination and correction, then makes the required inclusion of a reference number explicit before submission for routine processing. It retains the correct, error, check and submit focus identities. Exact proposed tokens and the five focus mappings appear in the JSON artifacts. The old sentence has ${phrase.entry.tokens.length} tokens; the new one has ${afterPhrase.tokens.length}. This is an author proposal, not full-expression acceptance. Captured error/submit review states must be rebased after the actual fourth-ten delivery.

The canonical ensure form is proposed initially. Oxford and Collins also admit insure especially in North American usage; that form is recorded as an unresolved regional/exercise decision, not rejected as incorrect. Financial insurance and protection senses are excluded. The new morphology is null: this honestly records unauthored analysis and does not invent an atomic classification or reuse veri + fy. All media, review and module gates remain pending.

## Coverage and impact

The catalog-based scan observed ${lexemes.length} senses and ${expressions.length} expressions. Verify and its direct focus expression each have twenty Module02 memberships. A one-for-one new-identity substitution preserves the observed fifty distinct terms per affected module and five hundred per course; no new quota credit is claimed. No ensure, insure or assure headword/display/accepted-form collision was found.

There are ${expressionUses.length} expressions with a verify inflection or the direct focus (${expressionUses.filter(row => row.surface_fields.text).length} in learner sentence text), ${lexicalUses.length} lexical field uses and ${relatedLexemes.length} related identities. Only the one foundation expression directly focuses this verify ID. The others are retained with exact objects/hashes and require contextual readability or specialist review where appropriate. No bulk substitution is proposed, and retiring one target does not certify the remaining text as A2-B2. Existing ensure occurrences are also inventoried without assigning them this new skill.

## History and revision

The current validator rejects a lexeme with no active memberships. Therefore, if this replacement is accepted, archive the exact old verify object and all old decisions in durable content-review evidence outside catalog-listed files, then remove it from the active source in the same coordinated delivery as the new entry and twenty membership changes. Do not add a dummy membership, rename the old object, alter historical holds, or delete shared morphology/source records.

Use a fresh curriculum/requirements revision before activation. Skills are keyed globally by sense ID; the new ensure ID receives no copied skill history. Expression completion is keyed by course/module/requirements revision plus expression ID, so no old completion may satisfy the changed sentence. Retain old histories and receipts unchanged. Current validation couples the catalog, twenty course revisions and all two hundred module requirement revisions; generated requirements and active-context compatibility need the same coordinated release. No revision value or migration was installed here.

## Delivery boundary

This folder contains exact before/new objects, twenty membership substitutions, source consultations, old evidence pins, impact inventory, token bindings, retirement policy and progress/revision consequences. It changes no production source, gate, count, save, registry, test, audio or visual asset. No project serializer, validator, test, native Godot, browser or build was run. Shared registry/source/test baselines deliberately remain null until the actual fourth-ten delivery and later writers settle.

Next: independent review of this exact language/curriculum proposal, including the variant decision and phrase naturalness; then a separately prepared coordinated revision/retirement implementation if accepted. See REVIEW-HANDOFF.md.\n`;
outputs['SOURCE-LEDGER.md'] = `# Verify replacement research: source and acquisition ledger

Author consultation on October 17, 2026 (Asia/Shanghai), not independent, human or specialist acceptance. Fresh HTTP timestamps are October 16 UTC. All publisher bodies were transient; retained artifacts contain original summaries, short tag metadata and one profile row. Dictionary definitions/examples, worksheets, artwork and audio were not imported.

| Source | Selected observation | Limit |
| --- | --- | --- |
| [Oxford verify](https://www.oxfordlearnersdictionaries.com/definition/english/verify) | Both selected senses have \`cefr=c1\`. | Preserve C1 and distinguish checking from stating truth. Footer reasonably B2 is unrelated. |
| [Collins verify](https://www.collinsdictionary.com/dictionary/english/verify) | Examination meaning supports current context; no selected level shown. | No B2 placement follows from context fit. |
| [Oxford ensure](https://www.oxfordlearnersdictionaries.com/definition/english/ensure) | Selected \`ensure_sng_1\` has \`fkcefr=b2\`; certainty topic B2. | The attribute is fkcefr, not cefr. Historical origin does not approve a morphology graph. |
| [Collins ensure](https://www.collinsdictionary.com/dictionary/english/ensure) | Selected COBUILD outcome verb B2, formal. | Other protection/insurance senses and automated examples are excluded. |
| [CEFR-J v1.5 CSV](https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv) | \`ensure,verb,B1,,,\` at physical line 2270; no exact verify row. | Headword/POS placement is not selected-sense or productive-mastery certification. No v1.6 file was inspected. |

Fresh successful raw responses, sizes/hashes, selected tags and the exact CSV row are in fresh-http-metadata.json. Raw Oxford bodies were not retained, so an independent reviewer cannot rehash them locally; they may consult the URLs again or explicitly scope reliance on the author observations. Rendered observations are in source-observations.json.

Fresh Cambridge opens for [ensure](https://dictionary.cambridge.org/dictionary/english/ensure) and [verify](https://dictionary.cambridge.org/dictionary/english/verify) returned Internal Error. No Cambridge level or definition is claimed. Earlier search leads pointing to user comments, teacher-facing wording, B2 examinations and footer levels were rejected as target-level evidence.

Citation for the profile row: *The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Accessed October 17, 2026 via Open Language Profiles.* The freshly consulted [repository terms](https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/README.md) permit research and commercial use with proper citation; copyright belongs to Tono Laboratory at TUFS. CC BY-SA 4.0 on that page applies to the separate Octanove dataset and is not assigned to CEFR-J v1.5.

Oxford University Press and HarperCollins retain their content rights. Reference consultation grants no production image/audio license. No media source, creator, license, acquisition, animations, pronunciation acceptance or listening approval has been fabricated. The pending new image brief is original author text; its art direction and sourced production asset remain future work.

The three proposed source rows are consultation records only. Proposed lexeme and expression references remain pending_term_check. Historical held-six and held-three decisions are separately hash-pinned and remain immutable; they are not fresh acceptance of this new candidate.\n`;
outputs['REVIEW-HANDOFF.md'] = `# Independent review handoff

The author recommends retaining verify's hold and considering the exact new ensure candidate. Do not accept a lower verify level from this packet. Review the new target as a curriculum replacement, with its own canonical learning identity.

1. Check fresh Oxford/Collins selected-sense observations and the raw tags/profile row. Preserve verify C1, ensure selected B2 and the CEFR-J B1 row literally. If relying on author-recorded web observations, say so; no full page bodies were retained for independent rehashing.
2. Assess the exact definition, example, formal workplace register, proposed B2 placement, and whether this distinct outcome objective belongs in all twenty shared Foundation02 courses. Check canonical-ID/form collisions again against the actual post-fourth-ten files.
3. Decide the attested insure regional alternative explicitly. This exact candidate accepts only ensure; approving that limited form does not make insure incorrect English or approve an insurance sense. A change to forms produces a different exact candidate hash.
4. Review the complete rewritten expression, every token/offset and all five focus bindings. The contextual form-processing scene must fit the actual accepted error/submit entries after fourth-ten delivery. Check and correct source/entry snapshots are contextual evidence, not automatic sentence approval. The changed sentence needs new audio and later phrase UI review.
5. Evaluate the one-for-one twenty-membership changes and durable old-object retirement. Keep every old hold/review immutable. Current orphan validation prevents retaining an unused verify object in active catalog files; no artificial membership is acceptable.
6. Review fresh revision, canonical skill isolation and historical save preservation. No automatic verify-to-ensure mastery or old-to-new expression completion copy is justified. The existing shared revision contract affects twenty courses and two hundred module requirement revisions; parent must choose/prepare the actual coordinated release.
7. Keep morphology null/unauthored, image/audio/acquisition pending, word/phrase review pending until their separate evidence is accepted. Existing exact Ava profile approval is preserved, but no prior per-term recording approval applies to ensure or this sentence.
8. Treat other verify/ensure surface occurrences and related identities as an explicit remaining review queue. This packet changes only the proposed foundation slot, not every C1 support word or domain procedure.

Before any implementation, rebase against actual fourth-ten delivery and settled writers, prepare new source/registry/test baselines, select a fresh unused revision, and create a bounded delivery proposal. This research directory contains no executable integration command or release authority. Do not rerun a consumed integrated proposal. No deployment or publication is requested.

Exact candidate JSON.stringify hashes are recorded in patches.proposed.json; file-byte hashes appear in inventory.json. All acceptance decisions are absent/pending.\n`;

const filenames = Object.keys(outputs);
for (const name of [...filenames, 'inventory.json']) if (fs.existsSync(path.join(owned, name))) throw new Error('Refusing to overwrite research artifact: ' + name);
for (const [name, value] of Object.entries(outputs)) fs.writeFileSync(path.join(owned, name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const inventory = fs.readdirSync(owned).filter(name => name !== 'inventory.json').sort().map(file => { const bytes = fs.readFileSync(path.join(owned, file)); return { file, bytes: bytes.length, sha256: hash(bytes) }; });
fs.writeFileSync(path.join(owned, 'inventory.json'), JSON.stringify({ schema: 1, status: 'sealed_research_only_unaccepted', created_at: new Date().toISOString(), files: inventory }, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ folder: owned.replace(/\\/g, '/'), files_including_inventory: inventory.length + 1, counts: fullSnapshot.counts,
  proposed_lexeme_object_sha256: objectHash(after), proposed_expression_object_sha256: objectHash(afterPhrase), proposed_token_count: afterPhrase.tokens.length,
  inventory_sha256: hash(fs.readFileSync(path.join(owned, 'inventory.json'))), project_code_executed: false, production_edits: false }, null, 2));
