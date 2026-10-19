'use strict';

// One-shot evidence assembly. This does not load or alter production APIs.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const relativeDirectory = 'build/professional-english/foundation-module02-language-review/fifth10-research-r01';
const directory = path.resolve(root, relativeDirectory);
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const read = name => JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8'));
const write = (name, value) => fs.writeFileSync(path.join(directory, name), JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const clone = value => JSON.parse(JSON.stringify(value));
const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const assert = (condition, message) => { if (!condition) throw new Error(message); };
assert(path.resolve(process.cwd()).toLowerCase() === path.resolve(root).toLowerCase(), 'Run only in the authorized Q worktree.');
assert(!fs.existsSync(path.join(directory, 'assembly-start.json')), 'Do not replay a completed or failed attempt.');

const author = 'Codex recover_delivery research author; not an independent language approver';
const consultedOn = '2026-10-17';
const method = 'Original Oxford and Collins publisher pages freshly opened through the web connector. Oxford sense attributes were separately retrieved and hashed without retaining publisher bodies. Authored summaries, definitions and examples are distinct from literal level observations.';
const globalLimits = [
  'Evidence only. No production content, review gate, reference, note, expression, source registry or runtime is changed.',
  'All proposals require a separate independent decision. No human, specialist, expression, morphology, media, module or release acceptance is claimed.',
  'Difficulty is an editorial teaching proposal. Literal Oxford cefr and fkcefr attributes, missing labels, Collins B1+ values and disagreements remain explicit.',
  'Whole-entry hazard, collect, notify, postpone and verify holds remain exact. All 17 inherited expression holds and every containing Foundation02 expression remain exact.',
  'Source consultation is not an asset license or acquisition. No publisher definitions, examples, exercises, illustrations, audio or page bodies are imported.',
  'Third10 and fourth10 proposals remain unintegrated. Complete retains its existing pending, unapproved form-image brief mismatch.'
];
const failedAccesses = [
  { url: 'https://dictionary.cambridge.org/dictionary/english/unsafe', result: 'Web connector internal error; no usable selected-sense evidence.', http_status: null, raw_body_sha256: null, supports_proposal: false },
  { url: 'https://dictionary.cambridge.org/dictionary/english/hazard', result: 'Web connector internal error; no usable selected-sense evidence.', http_status: null, raw_body_sha256: null, supports_proposal: false },
  { url: 'https://www.oxfordlearnersdictionaries.com/definition/english/incident', result: 'Initial web connector internal error. The corrected incident_1 URL was separately consulted successfully.', http_status: null, raw_body_sha256: null, supports_proposal: false }
];
const excludedConsultations = [{
  url: 'https://www.oxfordlearnersdictionaries.com/definition/english/concern_1',
  result: 'The opened page was the verb. It was excluded from noun support; concern_2 was subsequently consulted.',
  selected_sense_support: false,
  http_status: null,
  raw_body_sha256: null
}];

const research = [
  {
    term: 'broken', id: 'broken.not-working.adj', disposition: 'proposed',
    proposed_fields: { definition: 'Damaged or unable to work as intended.', example: 'The handle on this case is broken.', difficulty: 'A2' },
    selected_sense: 'The adjective for a damaged or nonfunctioning object, illustrated by a case handle.',
    language_rationale: 'Retain the original concise definition and concrete handle example. They fit the selected object sense without importing promise, relationship or emotional meanings.',
    difficulty_rationale: 'Retain editorial A2 on Oxford selected adjective sense 1 cefr a2. Collins A2 belongs to its past-participle cross-reference, not to a separately graded adjective; the relevant British adjective senses show no level.',
    hold_reason: null,
    excluded_scope: 'Broken promises, relationships, interrupted sleep or lines, limited language proficiency and a demoralized person are separate. Break as a verb and its other inflections are not accepted through this adjective.',
    context_boundary: 'Foundation02.06 retains report/fault/replace and its exact pending expression. Broken seals, glass and a broken link are distinct context uses; this research creates no bindings or content approval for them.',
    proposed_note: 'Retain the original object adjective and editorial A2. No expression, morphology or asset gate is accepted.',
    sources: [
      { kind: 'oxford', suffix: 'broken_1', sense_ids: ['broken_sng_1'], selected_section: 'Adjective sense 1, rendered lines 108-125', rendered_selected_level: 'A2', rendered_label_scope: 'Health problems topic attached to selected sense 1', summary: 'The selected adjective describes a damaged object or one unable to function.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'The page separately lists promises and relationships, interruption, uneven lines, language and emotional senses.' },
      { kind: 'collins', suffix: 'broken', sense_ids: [], selected_section: 'British dictionary adjective sense 2, lines 289-293, and sense 7, lines 321-324', rendered_selected_level: null, rendered_label_scope: null, other_observed_labels: [{ literal: 'A2', scope: 'COBUILD past-participle cross-reference, lines 222-224; not selected adjective level evidence' }], summary: 'The relevant British adjective senses cover objects divided by breakage and objects that do not work.', regional_register: 'British dictionary section; no selected usage restriction observed.', other_sense_boundary: 'The COBUILD A2 label is attached to the participle cross-reference. Other adjective meanings are outside the selected object sense.' }
    ]
  },
  {
    term: 'urgent', id: 'urgent.needing-prompt-attention.adj', disposition: 'proposed',
    proposed_fields: { definition: 'Needing attention or action without delay.', example: 'This message is urgent because the delivery leaves shortly.', difficulty: 'B2' },
    selected_sense: 'A matter needing prompt attention or action, in an ordinary delivery-message context.',
    language_rationale: 'The original revision replaces very soon with without delay to express the selected need for prompt action. Retain the original delivery-message example.',
    difficulty_rationale: 'Propose editorial B2 from Oxford selected sense 1 cefr b2. Collins labels its selected sense B1+ literally. The difference remains explicit; this is not a consensus claim or a conversion of B1+.',
    hold_reason: null,
    excluded_scope: 'An insistent voice or expression is a separate sense. Clinical urgency, triage thresholds and response-time duties are not established by this ordinary message example.',
    context_boundary: 'Foundation02.05 remains exact and pending with concern, solution and unintegrated resolve. Caregiving07.04 concerns urgent medical assessment; lexical consultation does not approve that clinical claim or bind this lexeme there.',
    proposed_note: 'Proposed original wording and editorial B2 for prompt attention. Collins B1+ is preserved as a distinct observed label.',
    sources: [
      { kind: 'oxford', suffix: 'urgent', sense_ids: ['urgent_sng_1'], selected_section: 'Adjective sense 1, rendered lines 105-118', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected adjective concerns something requiring immediate attention or action.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Voice or manner expressing strong insistence is a separate sense. Unrelated Word of the Day/footer B2 is not selected-sense evidence.' },
      { kind: 'collins', suffix: 'urgent', sense_ids: [], selected_section: 'COBUILD adjective sense 1, rendered lines 222-230', rendered_selected_level: 'B1+', rendered_label_scope: 'Selected needing-prompt-action sense', summary: 'The selected use calls for immediate dealing with a matter.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'A voice or manner communicating urgency is distinct from a matter that needs attention.' }
    ]
  },
  {
    term: 'unclear', id: 'unclear.not-understandable.adj', disposition: 'proposed',
    proposed_fields: { definition: 'Difficult to understand or not stated precisely.', example: 'The instructions are unclear about the start time.', difficulty: 'B1' },
    selected_sense: 'Wording or information that is not expressed clearly enough to understand precisely.',
    language_rationale: 'Retain the original wording and start-time example. They describe unclear information rather than declaring that a person lacks understanding.',
    difficulty_rationale: 'Propose editorial B1 on Oxford selected sense 1 cefr b1 and its selected B1 topic. Collins COBUILD unknown-or-uncertain sense 1 is B2 and its broader British ambiguous/not-definite definition is ungraded. Their scopes and labels are not collapsed.',
    hold_reason: null,
    excluded_scope: 'A person unsure about something is a separate sense. Clear, clearly, clarify and clarification remain distinct forms and identities; no inference about morphology or language teaching is accepted.',
    context_boundary: 'No selected focus expression currently binds this entry. OfficeAdmin05.07 is an inherited whole-expression hold; retail use-by-date and commercial-relationship contexts remain unscored and pending.',
    proposed_note: 'Retain the original information adjective with editorial B1; preserve Collins B2 and the separate person-uncertainty sense.',
    sources: [
      { kind: 'oxford', suffix: 'unclear', sense_ids: ['unclear_sng_1'], selected_section: 'Adjective sense 1, rendered lines 113-118', rendered_selected_level: 'B1', rendered_label_scope: 'Topic label attached to selected information/wording sense', summary: 'The selected sense concerns something that is not clear or definite enough to understand.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'A person who is uncertain or does not understand is a separate sense.' },
      { kind: 'collins', suffix: 'unclear', sense_ids: [], selected_section: 'COBUILD sense 1, lines 222-232; British dictionary definition, lines 276-280', rendered_selected_level: 'B2', rendered_label_scope: 'COBUILD unknown-or-uncertain situation sense 1, related but not an exact separate wording label', summary: 'COBUILD discusses an unknown or uncertain situation. The British definition also supports an ambiguous or indefinite meaning without a separate level.', regional_register: 'No selected regional restriction observed; the ungraded British section is kept distinct.', other_sense_boundary: 'COBUILD person-not-understanding sense 2 is also B2 but is not the selected instruction wording.' }
    ]
  },
  {
    term: 'safe', id: 'safe.free-from-unacceptable-danger.adj', disposition: 'proposed',
    proposed_fields: { definition: 'Unlikely to cause harm or put someone in danger.', example: 'The team asked whether the route was safe to use.', difficulty: 'A2' },
    selected_sense: 'A thing, route or activity unlikely to cause harm, as a question about using a route.',
    language_rationale: 'The authored definition selects the route-not-causing-harm sense and removes the unestablished unacceptable-risk criterion and the separate protected-person sense. The original question example does not guarantee a route is safe.',
    difficulty_rationale: 'Retain editorial A2 on Oxford selected sense 2 cefr a2 and Collins physical-danger sense 1 A2. The lexical label does not establish a professional safety threshold.',
    hold_reason: null,
    excluded_scope: 'Protected or unharmed people, secure possessions, reliable predictions, lack of controversy and the safe container noun are distinct. This is not a risk-acceptance standard, route assessment or guarantee.',
    context_boundary: 'Foundation02.09 remains exact with its domain gate pending. Hospitality room safe and accounting safe are container nouns, not instances of this adjective. Safely, safety and safeguards remain separate.',
    proposed_note: 'Proposed original route/object adjective definition with editorial A2; all safety-domain judgments remain pending.',
    sources: [
      { kind: 'oxford', suffix: 'safe_1', sense_ids: ['safe_sng_2'], selected_section: 'Adjective sense 2, rendered lines 146-161', rendered_selected_level: null, rendered_label_scope: null, summary: 'Selected sense 2 concerns a thing or activity that does not put someone in danger or cause harm.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Protected-from-harm sense 1 and other adjective senses are separate; the container noun is not on the selected adjective scope.' },
      { kind: 'collins', suffix: 'safe', sense_ids: [], selected_section: 'COBUILD physical-danger adjective sense 1, rendered lines 224-234', rendered_selected_level: 'A2', rendered_label_scope: 'Selected thing/activity free-from-physical-danger sense', summary: 'The selected adjective describes an activity or thing that does not expose people to physical harm.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Separate protected, unharmed, place and journey uses do not license a safety assessment; noun container uses remain distinct.' }
    ]
  },
  {
    term: 'unsafe', id: 'unsafe.presenting-danger.adj', disposition: 'proposed',
    proposed_fields: { definition: 'Presenting a risk of harm in the situation.', example: 'The worker reported an unsafe storage area.', difficulty: 'B1' },
    selected_sense: 'A thing, place or activity that may cause harm, illustrated by a reported storage area.',
    language_rationale: 'Retain the original definition and reported-area example. They fit the dangerous-place sense without approving an inspection or defining the conditions that make an area unsafe.',
    difficulty_rationale: 'Propose B1 only as an editorial teaching judgment for the concrete dangerous-place adjective in a simple report. Oxford selected sense 1 has neither cefr nor fkcefr, and Collins displays no selected level. Cambridge was inaccessible. There is no observed publisher certification for B1; the independent reviewer may hold this proposal if a direct level source is required.',
    hold_reason: null,
    excluded_scope: 'A person exposed to danger and the British legal meaning of an unsafe conviction are separate. No threshold, hazard evaluation, work instruction or morphology approval follows from the proposal.',
    context_boundary: 'Foundation02.09 remains exact and domain pending with safe and procedure. This is the sole selected surface/focus expression. No additional scored binding is proposed.',
    proposed_note: 'Retain the original dangerous-place wording and propose editorial B1 without a publisher-level claim. Domain review remains pending.',
    sources: [
      { kind: 'oxford', suffix: 'unsafe', sense_ids: ['unsafe_sng_1'], selected_section: 'Adjective thing/place/activity sense 1, rendered lines 103-106', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected sense concerns things, places or activities that may harm people.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'People in danger and British legal unsafe convictions are separate. No selected cefr or fkcefr attribute was observed.' },
      { kind: 'collins', suffix: 'unsafe', sense_ids: [], selected_section: 'COBUILD adjective sense 1, rendered lines 222-230', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected adjective covers a place, thing or activity likely to endanger someone.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Person-at-risk and legal conviction senses are separate; the selected dangerous-thing sense displays no level.' }
    ]
  },
  {
    term: 'hazard', id: 'hazard.possible-harm.n', disposition: 'hold', proposed_fields: null,
    selected_sense: 'A dangerous thing or situation with potential to cause harm, currently illustrated by a trip hazard.',
    language_rationale: 'The existing meaning and trip-hazard example have ordinary lexical support, but the entire entry remains on hold. No content or review field is projected for acceptance.',
    difficulty_rationale: 'Oxford selected noun has no cefr attribute and literal fkcefr c1, with a rendered Danger C1 topic. Collins selected noun has no observed level. The current A2 draft is not accepted, and the C1 evidence is not clamped to B2 or treated as lower-level support.',
    hold_reason: 'Whole-entry hold: the consulted selected-sense level evidence is C1, so there is no supported lower-level Foundation projection. The entire current A2 entry stays exact as an unapproved draft pending a separate decision on scope and level.',
    excluded_scope: 'Hazard as a verb, hazard a guess, gambling or golf meanings, occupational classifications and actual risk controls are not accepted.',
    context_boundary: 'Foundation02.10 remains exact, pending and unapproved with incident and report. All trip, slip, choking, electrical and pictogram compounds remain separate specialist contexts with no new bindings or procedures approved.',
    proposed_note: 'Whole-entry hold; preserve the original entry unchanged. Record literal Oxford fkcefr c1 and C1 topic without lowering them.',
    sources: [
      { kind: 'oxford', suffix: 'hazard_1', sense_ids: ['hazard_sng_1'], selected_section: 'Dangerous-thing noun, rendered lines 105-120', rendered_selected_level: 'C1', rendered_label_scope: 'Danger topic attached to selected noun', summary: 'The selected noun denotes something dangerous that can cause injury or damage.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Verb and specialist compound meanings do not provide a lower level for this noun. Literal fkcefr c1 remains distinct from absent cefr.' },
      { kind: 'collins', suffix: 'hazard', sense_ids: [], selected_section: 'COBUILD noun sense 1, rendered lines 224-232', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected noun covers a dangerous thing or situation with a risk of harm.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Verb, golf and chance-related meanings are separate. No selected level was observed.' }
    ]
  },
  {
    term: 'incident', id: 'incident.workplace-event.n', disposition: 'proposed',
    proposed_fields: { definition: 'An event at work, especially one that is unusual or causes a problem.', example: 'The supervisor recorded the incident after speaking with the team.', difficulty: 'B2' },
    selected_sense: 'An individual event, narrowed by this lexeme to the workplace and often unusual or problematic.',
    language_rationale: 'The authored definition removes the unsupported universal requirement for attention or recording. The original example reports a supervisor recording one event; it does not define a recording duty.',
    difficulty_rationale: 'Propose editorial B2 on Oxford ordinary-event sense 1 cefr b2 and Collins selected noun B2. Collins formal register is preserved.',
    hold_reason: null,
    excluded_scope: 'A violent event and a diplomatic clash are separately described senses. Incident forms, IT incident response and domain-specific reporting classifications or duties are not approved by the ordinary event meaning.',
    context_boundary: 'Foundation02.10 remains exact with the hazard whole-entry hold and its domain gate pending. Eleven external incident uses include form compounds and IT/service response contexts; none gains a selected binding or reporting approval.',
    proposed_note: 'Propose original workplace-event definition and editorial B2; retain the narrative recording example without creating a duty.',
    sources: [
      { kind: 'oxford', suffix: 'incident_1', sense_ids: ['incident_sng_1'], selected_section: 'Ordinary-event noun sense 1, rendered lines 105-122', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected noun identifies an event, commonly unusual, unpleasant or significant in a sequence.', regional_register: 'No explicit register or regional label observed on selected sense 1.', other_sense_boundary: 'Serious or violent events and diplomatic clashes are separate B2 senses; those meanings are not merged into this workplace definition.' },
      { kind: 'collins', suffix: 'incident', sense_ids: [], selected_section: 'COBUILD noun, rendered lines 224-237', rendered_selected_level: 'B2', rendered_label_scope: 'Selected event noun', summary: 'The selected noun describes a particular event, commonly one that is unusual or unpleasant.', regional_register: 'Formal is explicitly displayed for the selected use.', other_sense_boundary: 'Particular event wording does not impose recording or escalation obligations.' }
    ]
  },
  {
    term: 'concern', id: 'concern.worrying-matter.n', disposition: 'proposed',
    proposed_fields: { definition: 'A matter that worries someone.', example: 'I have a concern about the delivery address.', difficulty: 'B2' },
    selected_sense: 'A countable matter or situation that causes worry.',
    language_rationale: 'The original revision removes the separate needs-attention/priority meaning and selects a worrying matter. Retain the original delivery-address example.',
    difficulty_rationale: 'Propose editorial B2 on Collins exact countable worrying-fact/situation sense 3 B2. Oxford worry sense 1 cefr b2 is related noun evidence; its important-matter sense 3 is separate and is not silently substituted for the exact countable sense.',
    hold_reason: null,
    excluded_scope: 'The verb meaning is about, concern for another person, a responsibility or priority, a company and going concern are separate. Safeguarding, security and clinical compounds need their own context decisions.',
    context_boundary: 'Foundation02.05 remains exact and pending. Many surface concerns are verbs meaning is about; the other external uses span ordinary worries and specialist concerns. No selected noun binding, specialist meaning or reporting practice is added.',
    proposed_note: 'Proposed original countable worrying-matter definition and editorial B2. Oxford related emotional noun evidence and Collins exact countable evidence remain distinguishable.',
    sources: [
      { kind: 'oxford', suffix: 'concern_2', sense_ids: ['concern_sng_6'], selected_section: 'Related noun worry sense 1, rendered lines 108-138; separate important-matter sense 3', rendered_selected_level: null, rendered_label_scope: null, evidence_scope: 'Related worry noun, not an exact independent label for the selected countable worrying fact', summary: 'Noun sense 1 supports the state or feeling of worry. The selected countable worrying matter is evidenced more directly by Collins sense 3.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Oxford important-matter sense 3 concern_sng_8 is separately B2; care for someone, company and going concern remain distinct. The initial concern_1 verb page is excluded.' },
      { kind: 'collins', suffix: 'concern', sense_ids: [], selected_section: 'COBUILD countable noun sense 3, rendered lines 261-268', rendered_selected_level: 'B2', rendered_label_scope: 'Exact countable worrying fact or situation sense', summary: 'The selected countable noun names a fact or situation that worries people.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Worry as an emotion, protective interest, responsibility and business meanings are separate; verb concerns does not bind this noun.' }
    ]
  },
  {
    term: 'solution', id: 'solution.problem-answer.n', disposition: 'proposed',
    proposed_fields: { definition: 'A way to deal with a problem successfully.', example: 'The team agreed on a practical solution.', difficulty: 'A2' },
    selected_sense: 'A successful way of dealing with a problem.',
    language_rationale: 'Retain the original definition and practical-team-response example. They select a response to a problem and avoid the chemical mixture sense.',
    difficulty_rationale: 'Retain editorial A2 on Oxford selected problem-response sense 1 cefr a2. Collins selected sense 1 is B1+ literally. The different publisher labels remain explicit.',
    hold_reason: null,
    excluded_scope: 'A puzzle or mathematical answer is separately listed, and a dissolved chemical mixture is a different sense. Solving derivatives and cleaning-solution compounds are not accepted through this entry.',
    context_boundary: 'Foundation02.05 stays exact and pending. Retail08.01, FoodService08.05 and CleaningFacilities06.06 use cleaning solution in the mixture sense. EducationChildcare05.06 is a related problem-solving use but remains unscored for this selected entry.',
    proposed_note: 'Retain original problem-response wording and editorial A2 while preserving Collins B1+. No chemical solution or expression gate is accepted.',
    sources: [
      { kind: 'oxford', suffix: 'solution', sense_ids: ['solution_sng_1'], selected_section: 'Problem-response noun sense 1, rendered lines 105-124', rendered_selected_level: null, rendered_label_scope: null, summary: 'The selected noun names a way to solve a problem or handle a difficult situation.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Puzzle answer sense 2 is A2; chemical mixture sense 3 is B2. Neither expands the selected problem-response scope.' },
      { kind: 'collins', suffix: 'solution', sense_ids: [], selected_section: 'COBUILD noun sense 1, rendered lines 224-231', rendered_selected_level: 'B1+', rendered_label_scope: 'Selected way-to-deal-with-a-problem sense', summary: 'The selected noun refers to a way of dealing successfully with a problem.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Answers to puzzles and chemical mixtures are separate uses; B1+ is retained literally.' }
    ]
  },
  {
    term: 'procedure', id: 'procedure.agreed-method.n', disposition: 'proposed',
    proposed_fields: { definition: 'An established way of carrying out an activity.', example: 'We followed the procedure for requesting replacement equipment.', difficulty: 'B2' },
    selected_sense: 'An established method for doing something, illustrated by requesting equipment.',
    language_rationale: 'Retain the original definition. The authored example uses follow a procedure directly instead of making procedure mean a document that explains a method.',
    difficulty_rationale: 'Propose editorial B2 on Oxford selected established-method sense 1 cefr b2 with its B2 Scientific research topic, and Collins general-method B2.',
    hold_reason: null,
    excluded_scope: 'A formal law or business process, medical operation, computing procedure and particular occupational methods are not accepted as the same reviewed teaching scope.',
    context_boundary: 'Foundation02.09 remains exact and domain pending. Isolation, lockout/tagout, housekeeping methods and treatment procedure remain specialist contexts. No actual method, safety arrangement or medical action is approved.',
    proposed_note: 'Retain established-method definition, propose original follow-the-procedure example and editorial B2. Specialist methods and all domain gates remain pending.',
    sources: [
      { kind: 'oxford', suffix: 'procedure', sense_ids: ['procedure_sng_1'], selected_section: 'Established-method noun sense 1, rendered lines 105-126', rendered_selected_level: 'B2', rendered_label_scope: 'Scientific research topic attached to selected method sense', summary: 'The selected noun describes the usual or established way to carry out something.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Formal law/business process sense 2 has no selected level recorded here; medical operation sense 3 is B2 and remains separate.' },
      { kind: 'collins', suffix: 'procedure', sense_ids: [], selected_section: 'COBUILD general-method noun, rendered lines 224-235', rendered_selected_level: 'B2', rendered_label_scope: 'Selected method noun', summary: 'The selected noun names a way of doing something, often an established method.', regional_register: 'No selected regional restriction or explicit register label observed.', other_sense_boundary: 'Medical and legal contexts in examples do not grant acceptance of those actions, methods or requirements.' }
    ]
  }
];

const scriptSha = sha(fs.readFileSync(__filename));
write('assembly-start.json', { schema: 1, started_at: new Date().toISOString(), script_raw_sha256: scriptSha, scope: 'Evidence-only serializer and invariant checks; no production integration, validator, tests or native dispatch.' });
try {
  const baselineBytes = fs.readFileSync(path.join(directory, 'baseline.json'));
  const baseline = JSON.parse(baselineBytes);
  const baselineSha = sha(baselineBytes);
  assert(baselineSha === '59c33da6c2a31ac2ea3f67bed20966e32f174030c07b16600d13b6f46e3f73e5', 'Frozen baseline drift.');
  const metadata = read('oxford-html-metadata.json');
  const checkSources = () => baseline.source_file_hashes.map(v => ({ path: v.path, expected_sha256: v.raw_sha256, actual_sha256: sha(fs.readFileSync(path.resolve(root, v.path))) })).filter(v => v.expected_sha256 !== v.actual_sha256);
  assert(checkSources().length === 0, 'Bound source drift before evidence assembly.');
  assert(sha(fs.readFileSync(path.join(directory, baseline.target.frozen_copy))) === baseline.target.raw_sha256, 'Frozen original raw copy drift.');
  const captureStart = read('capture-start.json');
  const collectionStart = read('collection-start.json');
  assert(sha(fs.readFileSync(path.join(directory, 'capture-observations.cjs'))) === captureStart.script_raw_sha256, 'Capture source dispatch mismatch.');
  assert(sha(fs.readFileSync(path.join(directory, 'collect-html-metadata.cjs'))) === collectionStart.script_raw_sha256, 'Collection source dispatch mismatch.');
  assert(metadata.script_raw_sha256 === collectionStart.script_raw_sha256, 'Collected metadata script mismatch.');

  const sources = research.flatMap(entry => entry.sources.map(source => {
    const isOxford = source.kind === 'oxford';
    const observed = isOxford ? metadata.observations.find(v => v.term === entry.term) : null;
    const url = isOxford ? 'https://www.oxfordlearnersdictionaries.com/definition/english/' + source.suffix : 'https://www.collinsdictionary.com/dictionary/english/' + source.suffix;
    assert(!isOxford || observed.url === url, 'Oxford URL metadata mismatch for ' + entry.term);
    const selectedLevels = source.sense_ids.map(id => {
      const element = observed.sense_elements.find(v => v.attributes.id === id);
      assert(element, 'Missing selected sense ' + id);
      return { element_id: id, sense_number: element.attributes.sensenum || null, cefr: element.attributes.cefr || null, fkcefr: element.attributes.fkcefr || null, html_offset: element.html_offset };
    });
    return {
      id: 'foundation02-language-fifth10-' + source.kind + '-' + entry.term,
      term: entry.term, publisher: isOxford ? 'Oxford University Press' : 'HarperCollins', url,
      status: 'consulted_only_no_acceptance', consulted_on: consultedOn,
      selected_section: source.selected_section, evidence_scope: source.evidence_scope || 'Selected lexical sense support; level observations and editorial judgment remain separate.',
      summary: source.summary, regional_register: source.regional_register, other_sense_boundary: source.other_sense_boundary,
      observed_rendered_selected_level: source.rendered_selected_level, rendered_label_scope: source.rendered_label_scope,
      other_observed_labels: source.other_observed_labels || [], observed_html_selected_levels: selectedLevels,
      http_status: observed ? observed.http_status : null, raw_body_bytes: observed ? observed.raw_body_bytes : null, raw_body_sha256: observed ? observed.raw_body_sha256 : null,
      metadata_artifact: observed ? 'oxford-html-metadata.json' : null,
      body_hash_limitation: observed ? null : 'Consulted through the web connector; raw HTTP bytes/status were not exposed or separately retained. No raw hash is claimed.',
      source_page_retained: false, assets_acquired: false,
      approval_scope: 'Consultation only. No independent, human, specialist, expression, morphology, media or release acceptance.'
    };
  }));
  write('source-index.json', { schema: 1, status: 'author_source_consultations_pending_independent_acceptance', consulted_on: consultedOn, timezone: 'Asia/Shanghai', method, failed_accesses: failedAccesses, excluded_consultations: excludedConsultations, successful_selected_or_related_consultations: sources.length, sources });
  write('research-notes.json', { schema: 1, status: 'draft_author_research_pending_independent_acceptance', author, consulted_on: consultedOn, timezone: 'Asia/Shanghai', method, failed_accesses: failedAccesses, excluded_consultations: excludedConsultations, global_limits: globalLimits, entries: research });

  const candidates = research.map((entry, index) => {
    const frozen = baseline.selected_entries[index];
    assert(frozen.id === entry.id, 'Selection order mismatch.');
    assert(sha(JSON.stringify(frozen.before_entry)) === frozen.entry_json_sha256, 'Frozen entry pin mismatch.');
    const projection = clone(frozen.before_entry);
    if (entry.proposed_fields) Object.assign(projection, entry.proposed_fields);
    const changed = Object.keys(projection).filter(k => !equal(projection[k], frozen.before_entry[k]));
    assert(changed.every(k => ['definition', 'example', 'difficulty'].includes(k)), 'Projection changed a forbidden field.');
    assert(entry.disposition !== 'hold' || (entry.proposed_fields === null && equal(projection, frozen.before_entry)), 'Whole-entry hold changed.');
    assert(projection.review.language === 'pending' && projection.review.status === 'pending', 'Unexpected accepted review field.');
    return {
      id: entry.id, term: entry.term, position: 41 + index, disposition: entry.disposition, independent_acceptance: 'pending',
      before_entry: clone(frozen.before_entry), before_entry_sha256: frozen.entry_json_sha256,
      proposed_fields: entry.proposed_fields, content_projection: projection, content_projection_sha256: sha(JSON.stringify(projection)), changed_fields: changed,
      source_ids: sources.filter(s => s.term === entry.term).map(s => s.id), selected_sense: entry.selected_sense,
      language_rationale: entry.language_rationale, editorial_difficulty_rationale: entry.difficulty_rationale,
      hold_reason: entry.hold_reason, excluded_scope: entry.excluded_scope, expression_context_issue: entry.context_boundary,
      proposed_editorial_note_for_future_review: entry.proposed_note,
      media_issue: 'All existing media records, briefs, suitability, voice settings and review flags remain exact and pending. This package grants no imagery, asset, morphology, pronunciation or voice approval.'
    };
  });
  const actualChanges = candidates.filter(v => v.changed_fields.length).length;
  write('candidate-ledger.json', {
    schema: 1, status: 'draft_language_proposals_pending_independent_acceptance', author_role: author, created_on: consultedOn,
    scope: 'Foundation02 positions 41-50. Nine exact definition/example/difficulty proposals and one whole-entry hold. No notes, references, gates, morphology or media are projected changes.',
    input: { path: baseline.target.path, raw_sha256: baseline.target.raw_sha256, baseline_raw_sha256: baselineSha, hash_basis: baseline.hash_basis },
    selection: { method: 'Actual parsed source positions 41-50, pinned by exact lexical identities and original entry hashes.', count: 10, proposals: 9, new_holds: 1, earlier_whole_entry_holds_preserved: baseline.previous_whole_entry_holds.map(v => v.id), actual_content_changes: actualChanges },
    source_artifacts: ['baseline.json', 'source-index.json', 'research-notes.json', 'oxford-html-metadata.json', 'context-screen.json'], global_limits: globalLimits, entries: candidates
  });

  const concernVerbIds = new Set([
    'expr.nursing.module04.06', 'expr.caregiving.module04.08', 'expr.education_childcare.module04.02', 'expr.education_childcare.module06.04',
    'expr.education_childcare.module09.03', 'expr.cleaning_facilities.module06.03', 'expr.cleaning_facilities.module06.08', 'expr.sales_marketing.module06.04',
    'expr.sales_marketing.module08.01', 'expr.clinical_medicine.module08.01', 'expr.clinical_medicine.module10.09', 'expr.accounting_finance.module09.10', 'expr.legal_paralegal.module06.04'
  ]);
  const mixtureIds = new Set(['expr.retail.module08.01', 'expr.food_service.module08.05', 'expr.cleaning_facilities.module06.06']);
  const inheritedIds = new Set(baseline.inherited_expression_holds.map(v => v.id));
  function expressionJudgment(expression, match) {
    let classification = 'external_context_preserved_without_new_binding';
    let note = 'This surface match receives no selected-sense binding or expression, domain or process acceptance.';
    if (match.existing_selected_focus) {
      classification = 'existing_selected_focus_preserved_pending';
      note = 'The existing focus binding is observed, not newly accepted. The entire expression and all gates remain exact.';
    } else if (match.term === 'concern' && concernVerbIds.has(expression.id)) {
      classification = 'different_part_of_speech_verb_is_about';
      note = 'Concerns is a verb meaning is about or relates to, not the selected countable worrying-matter noun.';
    } else if (match.term === 'safe') {
      classification = 'different_part_of_speech_container_noun';
      note = 'Room safe or safe is a storage-container noun, not the selected safety adjective.';
    } else if (match.term === 'solution' && mixtureIds.has(expression.id)) {
      classification = 'different_sense_chemical_or_cleaning_mixture';
      note = 'Cleaning solution is a liquid/mixture sense, not a successful response to a problem.';
    } else if (match.term === 'solution') {
      classification = 'related_problem_response_unscored';
      note = 'The problem-response use is related, but no new focus binding or education-context approval is proposed.';
    } else if (match.term === 'urgent') {
      classification = 'specialist_medical_urgency_unscored';
      note = 'The medical-assessment context remains separate; this lexical proposal does not approve clinical urgency or triage advice.';
    } else if (['hazard', 'incident', 'procedure'].includes(match.term)) {
      classification = 'specialist_or_compound_context_unscored';
      note = 'The compound, reporting context or occupational method requires its own decision. No specialist meaning or operational instruction is accepted.';
    }
    return { term: match.term, selected_lexeme_id: match.selected_lexeme_id, classification, note, new_scored_bindings: [], expression_acceptance: false };
  }
  const context = {
    schema: 1, status: 'author_context_screen_no_acceptance', author_role: author, created_at: new Date().toISOString(), consultation_date_local: consultedOn,
    observation_provenance: { path: 'baseline.json', raw_sha256: baselineSha, status: 'Frozen original observations; authored judgments below do not replace observations.' },
    hash_convention: baseline.hash_basis, full_validation_claim: false,
    selected_entries: clone(baseline.selected_entries), selected_memberships: clone(baseline.selected_memberships), containing_modules: clone(baseline.containing_modules),
    containing_module_expressions: baseline.containing_module_expressions.map(v => ({ ...clone(v), author_screen: { completed: true, action: 'retain_exact_no_expression_acceptance', reason: v.id === 'expr.foundation.module02.10' ? 'Hazard is a whole-entry hold; incident lexical research does not accept this expression or its domain.' : 'All words, tokens, focus identities, meanings, contexts and review fields remain exact.' } })),
    expression_uses: baseline.expression_uses.map(v => ({ ...clone(v), author_screen: { completed: true, action: 'retain_exact', inherited_hold: inheritedIds.has(v.id), matches: v.matches.map(m => expressionJudgment(v, m)), new_scored_bindings: [], expression_acceptance: false } })),
    derivative_expression_uses: baseline.derivative_expression_uses.map(v => ({ ...clone(v), author_screen: { completed: true, classification: 'separate_derivative_or_compound_exclusion_screen', action: 'retain_exact', new_scored_bindings: [], expression_acceptance: false, note: 'Surface resemblance does not transfer the selected sense, language level, morphology approval or a domain decision.' } })),
    focus_expressions: clone(baseline.focus_expressions),
    related_entry_boundaries: baseline.related_entry_boundaries.map(v => ({ ...clone(v), author_screen: { completed: true, action: 'retain_exact_distinct_identity', merge_or_reassignment: false } })),
    previous_whole_entry_holds: clone(baseline.previous_whole_entry_holds), inherited_expression_holds: clone(baseline.inherited_expression_holds),
    new_whole_entry_holds: candidates.filter(v => v.disposition === 'hold').map(v => ({ id: v.id, before_entry: clone(v.before_entry), entry_json_sha256: v.before_entry_sha256, reason: v.hold_reason, disposition: 'preserve_exact_whole_entry_hold' })),
    additional_foundation02_preservation: baseline.containing_module_expressions.filter(v => /\.(04|05|07|08)$/.test(v.id)).map(clone),
    complete_existing_form_scope_mismatch: clone(baseline.complete_existing_form_scope_mismatch),
    matching_policy: clone(baseline.matching_policy), counts_by_selected_id: clone(baseline.counts_by_selected_id), source_file_hashes: clone(baseline.source_file_hashes),
    summary: { ...baseline.summary, containing_module_expressions: 10, new_whole_entry_holds: 1, new_expression_acceptances: 0, new_scored_bindings: 0 }, observed_status: clone(baseline.observed_status),
    context_boundaries: research.map(v => ({ id: v.id, selected_scope: v.selected_sense, boundary: v.context_boundary, excluded_scope: v.excluded_scope, new_bindings: [] })),
    gate_boundary: globalLimits.join(' ')
  };
  write('context-screen.json', context);

  assert(equal(context.previous_whole_entry_holds, baseline.previous_whole_entry_holds), 'Prior lexical hold drift.');
  assert(equal(context.inherited_expression_holds, baseline.inherited_expression_holds), 'Inherited expression hold drift.');
  assert(context.inherited_expression_holds.every(v => v.historical_hash_and_review_match), 'Historical expression hold mismatch.');
  assert(equal(context.complete_existing_form_scope_mismatch, baseline.complete_existing_form_scope_mismatch), 'Complete image mismatch record drift.');
  assert(checkSources().length === 0, 'Bound source drift after evidence assembly.');
  assert(sha(fs.readFileSync(__filename)) === scriptSha, 'Executed assembly source changed.');

  const result = {
    schema: 1, status: 'evidence_invariants_passed_not_production_validation', finished_at: new Date().toISOString(), assembly_script_raw_sha256: scriptSha,
    baseline_raw_sha256: baselineSha, selected_original_pins_verified: 10, bound_source_files_verified_before_and_after: baseline.source_file_hashes.length,
    source_drift_count: 0, projection_invariant_errors: 0, proposals: 9, whole_entry_holds: 1, actual_content_changes: actualChanges,
    changed_fields_by_entry: candidates.filter(v => v.changed_fields.length).map(v => ({ id: v.id, fields: v.changed_fields })),
    source_consultations: 20, failed_accesses: failedAccesses.length, excluded_wrong_part_of_speech_consultations: excludedConsultations.length,
    previous_whole_entry_holds_preserved: 4, inherited_expression_holds_preserved: 17, containing_expressions_preserved: 10,
    observed_status: baseline.observed_status, production_writes: false, independent_acceptance: false,
    production_validators_or_tests_run: false, native_or_browser_dispatch_run: false,
    executed_capture_collection_and_assembly_source_equality_verified: true
  };
  write('assembly-result.json', result);
  const handoff = `# Foundation02 final-ten author research\n\nNine exact language projections and one whole-entry hold are ready for independent review. This is evidence-only research; no production entry or review gate is changed.\n\nPositions 41-50 are broken, urgent, unclear, safe, unsafe, hazard, incident, concern, solution and procedure. Proposed editorial levels are A2 for broken/safe/solution, B1 for unclear/unsafe, and B2 for urgent/incident/concern/procedure. Seven entries have actual content changes: six difficulty fields, four definitions and one example. Broken and solution retain their original fields.\n\nHazard stays an exact whole-entry hold. Oxford records no cefr attribute but literal fkcefr c1 and a C1 Danger topic; Collins has no observed selected level. The draft A2 is not accepted or replaced by a lower-level projection. Unsafe B1 is explicitly an editorial judgment with no observed publisher level; Cambridge was inaccessible. Independent review may hold it.\n\nRead candidate-ledger.json with source-index.json, research-notes.json, oxford-html-metadata.json and context-screen.json. All ten Oxford and ten Collins pages were freshly consulted. Broken's Collins A2 is a participle cross-reference, not an adjective label. Oxford concern is related worry-noun support; Collins supplies the exact countable worrying-matter sense. Collins B1+ and Oxford cefr/fkcefr distinctions remain literal. No publisher page bodies, examples, exercises or media were imported.\n\nThe frozen baseline binds 350 source/evidence files and target ${baseline.target.raw_sha256}. Context covers 200 memberships in 20 identical draft modules, all ten containing expressions, 90 surface-hit expressions/100 term-expression pairs, 81 derivative expressions, four focus expressions and 46 related identities. Safe containers, cleaning solutions, concern verbs, medical urgency, incident compounds and specialist procedures remain distinct and unapproved. No focus bindings are added.\n\nCollect, notify, postpone and verify retain exact whole-entry holds. All 17 inherited expression holds and Foundation02.04/.05/.07/.08 remain exact; Foundation02.09/.10 keep pending domain gates. Third10/fourth10 proposals remain unintegrated. Complete's old form-image brief remains live, mismatched, pending and unapproved.\n\nEvidence-only invariant checks confirm all ten original pins, zero drift across 350 bound files and unchanged non-content fields in every projection. This is not a production validator or suite result. Raw observed status remains 317 language-reviewed, 130 overall-reviewed, Foundation02 18/50 language-reviewed and zero ready modules. No production tests, native Godot, builds, exports or browser dispatch ran in this package.\n\nTwo Cambridge lookups and the initial Oxford incident URL returned internal errors; the corrected incident_1 URL succeeded. The initial Oxford concern_1 page was a verb and was excluded. A nonexistent courses/foundation.json read failed harmlessly before the actual shared lexeme file was located. One oversized read was truncated; compact follow-up reads recovered the required schema and values. These read-only limitations are recorded rather than treated as evidence.\n\nCapture, HTML collection and this evidence assembly each ran once. Their executed source hashes match their dispatch records. No collection or assembly attempt failed. Do not replay the completed scripts; use a fresh revision with explicit lineage. No production integration serializer or acceptance transaction is included.\n`;
  fs.writeFileSync(path.join(directory, 'HANDOFF.md'), handoff, { flag: 'wx' });
  const files = fs.readdirSync(directory).sort().filter(name => fs.statSync(path.join(directory, name)).isFile());
  write('inventory.json', {
    schema: 1, status: 'frozen_author_research_pending_independent_acceptance', recorded_at: new Date().toISOString(), directory: relativeDirectory,
    production_mutated: false, independent_acceptance: false, executed_source_equality_verified: true,
    inventory_self_hash_excluded: true,
    artifacts: files.map(name => { const bytes = fs.readFileSync(path.join(directory, name)); return { path: name, sha256: sha(bytes), bytes: bytes.length }; })
  });
  console.log(JSON.stringify({ ok: true, directory: relativeDirectory, proposals: 9, holds: 1, actual_content_changes: actualChanges, inventory_sha256: sha(fs.readFileSync(path.join(directory, 'inventory.json'))), checks: result }, null, 2));
} catch (error) {
  write('assembly-failure.json', { schema: 1, failed_at: new Date().toISOString(), assembly_script_raw_sha256: scriptSha, error: String(error.stack || error), production_writes: false });
  throw error;
}
