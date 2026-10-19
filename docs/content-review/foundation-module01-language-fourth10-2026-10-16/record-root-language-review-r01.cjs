'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const base = __dirname;
const root = path.resolve(base, '../../../..');
assert.equal(root.toLowerCase().replaceAll('\\', '/'), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
assert.equal(raw(path.join(base, 'inventory.json')), 'dc3eeabf98696383be13ea117571a23802d7269000ae2be231c1ca3a934189ff');
for (const item of read(path.join(base, 'inventory.json')).artifacts) {
  const file = path.join(root, item.path);
  assert.equal(raw(file), item.raw_sha256, item.path);
  if (item.json_sha256) assert.equal(hash(read(file)), item.json_sha256, item.path);
}
const ledger = read(path.join(base, 'language-ledger.json'));
const contexts = read(path.join(base, 'expression-use-review.json'));
const pre = read(path.join(base, 'preimages.json'));
assert.equal(hash(ledger), '7b0912391dfa6f852769379622f23ed6a764d3f0f86fe1c798deae0ba04d32e8');
assert.equal(hash(contexts), '8f02831121d93c88510cac103298479bc5fd5214e06c3bbaa26b00aac245b560');
const {loadProfessionalContent} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const data = loadProfessionalContent(root);
const lexemes = new Map(data.lexemes.map(entry => [entry.id, entry]));
for (const item of [...pre.selected_entries, ...pre.unselected_foundation_entries, ...pre.related_entries]) {
  assert.equal(hash(item.entry), item.json_sha256);
  assert.deepEqual(lexemes.get(item.entry.id), item.entry);
}
for (const item of [...pre.local_expressions, ...pre.expression_uses]) {
  assert.equal(hash(item.entry), item.json_sha256);
  assert.deepEqual(data.expressions.find(entry => entry.id === item.id), item.entry);
}
for (const item of pre.modules) assert.deepEqual(data.courses.find(course => course.id === item.course_id).modules.find(module => module.id === item.module_id), item.module);
for (const item of pre.existing_source_records) assert.deepEqual(data.sources.find(source => source.id === item.source.id), item.source);
for (const [file, digest] of Object.entries({...pre.growth_raw_sha256, ...pre.prior_artifacts_raw_sha256})) assert.equal(raw(path.join(root, file)), digest);
const reasons = {
  announcement: 'The revised definition selects an information statement delivered to a group, with speech and writing both included; the opening-hours example is unambiguous. Accept the proposed B2 as a conservative editorial course placement for this public-information noun, while retaining the literal Collins B1+ observation. Neither a conversion nor dictionary B2 certification is claimed.',
  message: 'The recipient-directed information definition and delivery-team example fit the selected communication noun. Retain A2 only as the course floor; the observed Oxford and Collins A1 labels remain literal. Program data packets and a literary central idea are separate senses.',
  email: 'The definition and an email example select one message. Oxford separates the countable message from the service, while Collins uses one A1 variable-noun entry with both. Retain A2 as the course floor without transferring the verb A2 label. Existing email spelling and general region remain exact.',
  'phone call': 'The definition selects an actual telephone conversation, supported by the selected Oxford and Collins A1 evidence. Retain the A2 course floor and exact two-word form. Unanswered attempts and queued calls are not silently narrowed or approved by this sense.',
  voicemail: 'The revised definition accurately selects a stored spoken message for later playback without requiring that every recording follow an unanswered call. Merriam-Webster 2b directly supports the countable message. Accept editorial B1 for familiar recorded-message handling, with no selected-source CEFR certification; system-only B1 evidence is not transferred.',
  extension: 'The stored internal-number meaning is supported by numbered telephone-line definitions and examples. Accept editorial B2 for this bounded everyday office use, preserving the selected Collins B2 and Oxford C1 disagreement. Ext. remains an observation rather than an additional answer form.',
  introduction: 'The revised example clearly introduces two colleagues to one another and removes the introductory-talk ambiguity. Accept the unchanged people-acquaintance definition and editorial B1 for describing this social act. No level from a book opening or introductory course is transferred, and ambiguous expression bindings remain held.',
  greeting: 'Words or actions acknowledging an arriving person and the visitor example match the selected meeting sense. Accept the proposed B2 as a conservative editorial placement for the lexical noun in this course, with literal Collins B1+ retained. This is not a statement that greeting someone or saying hello requires B2 proficiency; written seasonal wishes remain separate.',
  conversation: 'Usually informal accurately qualifies the spoken-exchange definition without making informality mandatory. The schedule example fits and Collins labels the selected talk sense A2. Keep text-only and modality-uncertain contexts separate, without narrowing their existing broader meanings.',
  discussion: 'The topic-focused detailed conversation definition and delivery-problem example are clear. Oxford labels this selected exchange A2 and distinguishes a written treatment. No specialist conclusion, agreement or permission follows from lexical acceptance.'
};
const allowed = new Set(['definition', 'example', 'difficulty', 'references', 'editorial_notes']);
const decisions = ledger.proposals.map(row => {
  assert.equal(hash(row.before_entry), row.before_entry_json_sha256);
  assert.equal(hash(row.candidate_entry), row.candidate_entry_json_sha256);
  assert.deepEqual(lexemes.get(row.id), row.before_entry);
  for (const key of new Set([...Object.keys(row.before_entry), ...Object.keys(row.candidate_entry)])) if (!allowed.has(key)) assert.deepEqual(row.candidate_entry[key], row.before_entry[key], row.id + ':' + key);
  assert.ok(reasons[row.text]);
  return {id: row.id, text: row.text, decision: 'accept_exact_author_language_candidate', candidate_entry_json_sha256: row.candidate_entry_json_sha256, before_entry_json_sha256: row.before_entry_json_sha256, reason: reasons[row.text], editorial_difficulty: row.candidate_entry.difficulty, observed_source_levels: row.difficulty_evidence.observed_selected_source_labels, production_acceptance: false};
});
assert.equal(decisions.length, 10);
assert.deepEqual(contexts.expression_ambiguity_hold_ids, ['expr.foundation.module01.03', 'expr.foundation.module01.08', 'expr.hospitality_tourism.module05.04', 'expr.office_admin.module05.07']);
const crosschecks = [
  ['https://www.collinsdictionary.com/dictionary/english/announcement', 'Selected public-information statement carries B1+; act and printed-notice senses remain distinct.'],
  ['https://www.collinsdictionary.com/dictionary/english/greeting', 'Selected meeting acknowledgment carries B1+ and includes words and actions.'],
  ['https://www.merriam-webster.com/dictionary/voice%20mail', 'Sense 2b supports one recorded message, separate from the system and collective received messages; no CEFR label.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/introduction', 'People sense 2 describes making someone known; the visible A2 topic belongs to the book/speech opening sense.'],
  ['https://www.collinsdictionary.com/dictionary/english/extension', 'Telephone sense 5 carries B2 and provides numbered-extension examples and ext. abbreviation.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/extension', 'Telephone sense 10 carries Phones, email and the internet C1; retain disagreement with Collins.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/message_1', 'Recipient-directed written/spoken information and electronic-message senses show A1; literary ideas and other uses stay separate.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/email_1', 'Countable message is separately defined; the visible A1 topic is under the service sense.'],
  ['https://www.collinsdictionary.com/dictionary/english/email', 'A1 variable noun combines the system and a countable message example; A2 is the separate verb. Spelling variants are recorded without adding answer forms.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/phone-call', 'The act of speaking over the phone has the visible A1 topic label.'],
  ['https://www.collinsdictionary.com/dictionary/english/conversation', 'Selected talking sense is usually informal and carries A2.'],
  ['https://www.oxfordlearnersdictionaries.com/definition/english/discussion', 'Topic-focused conversation has A2; the separate written/speech treatment also has A2 without merging meanings.']
].map(([url, finding]) => ({url, finding, consulted_on: '2026-10-16', access: 'root_direct_web_open_selected_passages'}));
const report = {
  schema: 1, status: 'root_ten_scoped_language_acceptances_pending_guarded_delivery', date: new Date().toISOString(), reviewer: 'Codex root (independent AI language review; not human or specialist approval)', root_review_recorded: true,
  author_ledger_json_sha256: hash(ledger), context_review_json_sha256: hash(contexts), author_inventory_raw_sha256: raw(path.join(base, 'inventory.json')),
  decisions, accepted_candidates: decisions.map(item => ({id: item.id, candidate_json_sha256: item.candidate_entry_json_sha256, scope: 'Ordinary language wording, example and editorial course difficulty; no new answer forms.'})),
  preserved_entry_ids: ['supervisor.work-overseer.n', 'attendance.presence-record.n'],
  root_direct_source_crosschecks: crosschecks,
  context_decision: 'Root inspected all 46 matching expression texts, contexts and per-match observations, seven other local expression observations, and 40 related definitions/boundaries. Preserve all expression records and focus bindings, including the four current and five prior ambiguity holds. A spoken lexical sense does not narrow broader text/signed communication contexts. This is lexical compatibility review, not independent full expression or specialist acceptance.',
  integration_scope: [
    'Integrate the exact ten accepted candidates only after reviewing the guarded delivery against a fresh successful current baseline.',
    'Twenty consulted source records may be added; failed Cambridge accesses remain excluded. Literal source labels and editorial levels remain separate.',
    'Set language review for the ten accepted senses and narrowly scoped lexical references only. Overall status follows existing domain-not-required rules, with morphology and media still separate.',
    'Replace only exact superseded pending-language editorial clauses while retaining original notes in before snapshots and recording acceptance in current notes.',
    'Preserve identity, all noncandidate definitions/examples, accepted forms, regions, practice modes, memberships, all expressions, domain gates, morphology, media, Growth and module readiness.',
    'Supervisor, attendance and all current/prior expression holds remain complete unchanged entries; they are not accepted by this record.'
  ],
  tests_executed: false, native_runtime_executed: false, production_mutated: false, shared_tests_mutated: false, baseline_bound: false,
  next_step: 'Prepare an exact guarded delivery and shared-test previews against successful R25; root must inspect, accept and serialize the result.'
};
for (const id of report.preserved_entry_ids) assert.ok(lexemes.has(id), id);
const file = path.join(base, 'root-language-review-r01.json');
fs.writeFileSync(file, JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({path: file, json_sha256: hash(report), raw_sha256: raw(file), accepted: 10, direct_source_crosschecks: crosschecks.length}));
