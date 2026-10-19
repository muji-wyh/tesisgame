'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const base = __dirname;
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const hash = x => crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
const ledger = read(path.join(base, 'language-ledger.json'));
assert.equal(hash(ledger), '4517fbb347f59056b589bc5dd7b26ce3b4b0255ca2ab2fad0b0241094756eb4d');
const contexts = read(path.join(base, 'expression-use-review.json'));
assert.equal(hash(contexts), 'f34ed83ddb41b16dd8082190cc2609d740781773007d14b1765a88ea294c7dd6');
const reasons = {
  deadline: 'The existing latest-time definition and form example are precise. Accept B2 with the observed selected Collins label; unrelated page-footer levels provide no evidence.',
  break: 'The revised short-pause definition covers food as well as rest. Accept the explicit A2 curriculum floor while retaining the actual selected Oxford A1 observation.',
  overtime: 'The hours-explicit example removes time-versus-pay ambiguity. Accept editorial B2 for ordinary additional working time, supported by Collins B2 and retaining the conflicting Oxford C1. No work entitlement or pay rule follows.',
  attendance: 'The ordinary presence meaning and trainer example are clear, but current A2 lacks support and the observed selected Oxford C1 lies outside the current schema. Keep this entire production entry unchanged and language pending. Do not clamp C1 or infer B2 from a footer, related word, or search snippet.',
  availability: 'The revised definition selects whether and when a person is free, distinct from resource/system availability. Accept editorial B1 for this scheduling request; no consulted source certifies the level.',
  calendar: 'The revised organizer definition correctly includes books and applications. Accept B1 from the selected Collins date-display/software evidence and retain general region; especially North American is not exclusive usage.',
  agenda: 'The meeting-topic-list definition and staffing-item example fit. Accept B2 from the selected Oxford Working life label; policy priorities and hidden intentions remain separate.',
  invitation: 'The revised request definition explicitly includes speech and writing. Accept A2 from the selected Collins request sense. A physical card, invitation-to-treat or credentials are not additional answers.',
  update: 'The revised countable report definition fits the original order-progress question and avoids treating every revision as this noun. Accept editorial B1, explicitly without source-level certification; three report-versus-change contexts stay held.',
  reminder: 'The existing message/signal definition includes a calendar notification before an event. Accept editorial B1 without source-level certification; the narrower British overdue-note usage does not restrict the general noun.'
};
const decisions = ledger.proposals.map(row => {
  assert.equal(hash(row.before_entry), row.before_entry_json_sha256);
  assert.equal(hash(row.candidate_entry), row.candidate_entry_json_sha256);
  const current = read(row.resource.replace('res://', '')).lexemes.find(x => x.id === row.id);
  assert.deepEqual(current, row.before_entry);
  assert.ok(reasons[row.text]);
  const accepted = row.text !== 'attendance';
  return {id:row.id,text:row.text,decision:accepted?'accept_exact_author_language_candidate':'hold_entire_entry_unchanged',candidate_entry_json_sha256:row.candidate_entry_json_sha256,before_entry_json_sha256:row.before_entry_json_sha256,reason:reasons[row.text],editorial_difficulty:accepted?row.candidate_entry.difficulty:null,observed_source_levels:row.difficulty_evidence.observed_selected_source_labels,production_acceptance:false};
});
const accepted = decisions.filter(x=>x.decision==='accept_exact_author_language_candidate');
assert.equal(accepted.length,9);
const report = {
  schema:1,status:'root_nine_scoped_language_acceptances_one_hold_pending_guarded_delivery',
  date:new Date().toISOString(),reviewer:'Codex root (independent AI language review; not human or specialist approval)',
  root_review_recorded:true,author_ledger_json_sha256:hash(ledger),context_review_json_sha256:hash(contexts),
  decisions,accepted_candidates:accepted.map(x=>({id:x.id,candidate_json_sha256:x.candidate_entry_json_sha256,scope:'Ordinary language wording, example and editorial difficulty; no new spelling.'})),
  preserved_entry_ids:['attendance.presence-record.n'],
  root_direct_source_crosschecks:[
    {url:'https://www.oxfordlearnersdictionaries.com/definition/english/attendance',finding:'Selected presence meaning carries C1; the page-footer B2 belongs to another word. Presence and number present remain distinct.'},
    {url:'https://www.collinsdictionary.com/dictionary/english/overtime',finding:'Selected additional-work-time noun carries B2, distinct from pay and sporting uses.'},
    {url:'https://www.collinsdictionary.com/dictionary/english/calendar',finding:'Date-display/software entry carries B1 and illustrates phone organizing; British appointment registers also appear.'},
    {url:'https://www.oxfordlearnersdictionaries.com/definition/english/agenda',finding:'Selected meeting-list meaning carries Working life B2.'}
  ],
  further_access_limits:['Direct Cambridge attendance access returned an internal error. Search results did not establish a selected reliable lower CEFR label and are not accepted evidence.'],
  context_decision:'All 53 actual expression texts and contextual observations, six existing selected-focus expressions, and 58 related-term definitions/boundaries were inspected. Preserve all exact expression records and focus bindings; all five ambiguity holds and related policy-update alternative remain.',
  integration_scope:[
    'Integrate only the nine accepted candidates after guarded delivery review. Keep attendance byte-for-byte equivalent as a parsed full entry; retain its source/evidence hold in durable history rather than promoting it.',
    'Only source records referenced by the accepted nine enter the production source registry. Attendance-only sources remain historical scratch evidence.',
    'Set language review only for the accepted nine and their narrowly scoped lexical reference statuses. Overall status may follow existing domain-not-required rules; media and morphology remain separate gates.',
    'Replace or qualify only exact superseded pending-language editorial clauses. Preserve original notes in before snapshots and explain acceptance in current notes.',
    'Preserve all definitions/examples except the exact candidate changes, all forms/regions, identity, practice modes, memberships, morphology, media, Growth, domain requirements and module release gates.'
  ],
  tests_executed:false,native_runtime_executed:false,production_mutated:false,shared_tests_mutated:false,baseline_bound:false,
  next_step:'Prepare a current-preimage delivery proposal; root must review and serialize it against the latest successful continuation baseline.'
};
const file=path.join(base,'root-language-review-r01.json');
fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({path:file,json_sha256:hash(report),raw_sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),accepted:9,held:1}));
