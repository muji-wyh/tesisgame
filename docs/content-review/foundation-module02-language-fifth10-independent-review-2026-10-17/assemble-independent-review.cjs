'use strict';

// One-use static evidence assembly. This file does not import or run production code.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const output = __dirname;
const repo = path.resolve(output, '../../..');
assert.equal(repo.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const researchRelative = 'build/professional-english/foundation-module02-language-review/fifth10-research-r01';
const research = path.join(repo, researchRelative);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const objectHash = value => hash(JSON.stringify(value));
const read = file => fs.readFileSync(file);
const load = file => JSON.parse(read(file));
const write = (name, value) => fs.writeFileSync(path.join(output, name), typeof value === 'string' ? value : `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
const scriptSha256 = hash(read(__filename));
const startedAt = new Date().toISOString();
const expected = {
  'inventory.json': 'd605cd61042c2f7532090a4aa838b791ad822f800165afe2ad7081624ea4300b',
  'candidate-ledger.json': '171ce3798449f6915be6079f713e2e4c9211cf12d9e98e6945aad249efe9a5e1',
  'baseline.json': '59c33da6c2a31ac2ea3f67bed20966e32f174030c07b16600d13b6f46e3f73e5',
  'context-screen.json': 'b0be816fd3836b7ee321a715286aae0459c7b775ac69993b4a0d5ba6dfab2c52',
  'source-index.json': 'a52cbdcd9c83c7c1a21b5ae1416d8f1bdbf07cba76e35b89f5edfbd259746b15',
  'oxford-html-metadata.json': 'bdfe7ef9db4a4c753e6188b82c6b836c7c5b877147d462c55227445057172543',
  'original-foundation-module02.json': '03953236a30d636a7d6db0f0f921d076910886e1f2f1834730ba1302b5b0ac41'
};
write('assembly-start.json', { schema: 1, started_at: startedAt, script_sha256: scriptSha256, attempt: 1, method: 'Read-only JSON and SHA256 comparison; write new evidence only under this directory.', production_dispatch: false });

try {
  const inputPins = Object.entries(expected).map(([name, expectedSha256]) => {
    const bytes = read(path.join(research, name));
    const actual = hash(bytes);
    assert.equal(actual, expectedSha256, `Frozen author input changed: ${name}`);
    return { path: `${researchRelative}/${name}`, bytes: bytes.length, sha256: actual, expected_sha256: expectedSha256, matches: true };
  });
  const authorInventory = load(path.join(research, 'inventory.json'));
  const candidates = load(path.join(research, 'candidate-ledger.json'));
  const baseline = load(path.join(research, 'baseline.json'));
  const sources = load(path.join(research, 'source-index.json'));
  const context = load(path.join(research, 'context-screen.json'));
  const original = load(path.join(research, 'original-foundation-module02.json'));
  const authorArtifacts = authorInventory.artifacts.map(item => {
    const file = path.resolve(research, item.path);
    assert.ok(file.startsWith(`${research}${path.sep}`));
    const bytes = read(file);
    assert.equal(hash(bytes), item.sha256, `Author artifact changed: ${item.path}`);
    assert.equal(bytes.length, item.bytes);
    return { ...item, matches: true };
  });
  assert.equal(authorArtifacts.length, 16);
  const sourceFileAudit = baseline.source_file_hashes.map(item => {
    const absolute = path.resolve(repo, item.path);
    assert.ok(absolute.startsWith(`${repo}${path.sep}`));
    const exists = fs.existsSync(absolute);
    const bytes = exists ? read(absolute) : null;
    const current = bytes ? hash(bytes) : null;
    return { path: item.path, frozen_sha256: item.raw_sha256, frozen_bytes: item.bytes, current_sha256: current, current_bytes: bytes ? bytes.length : null, matches: current === item.raw_sha256 && bytes.length === item.bytes };
  });
  assert.equal(sourceFileAudit.length, 350);
  const drift = sourceFileAudit.filter(row => !row.matches);
  // A drift record is evidence, never permission to overwrite current data.
  const currentTargetBytes = read(path.join(repo, baseline.target.path));
  const currentTarget = JSON.parse(currentTargetBytes);
  const currentTargetHash = hash(currentTargetBytes);
  const currentLexemes = new Map(currentTarget.lexemes.map(entry => [entry.id, entry]));
  const frozenLexemes = new Map(original.lexemes.map(entry => [entry.id, entry]));
  const allowed = ['definition', 'example', 'difficulty'];
  const candidateAudit = candidates.entries.map(candidate => {
    assert.deepEqual(candidate.before_entry, frozenLexemes.get(candidate.id));
    assert.equal(objectHash(candidate.before_entry), candidate.before_entry_sha256);
    const projection = candidate.proposed_fields ? { ...candidate.before_entry, ...candidate.proposed_fields } : candidate.before_entry;
    assert.deepEqual(projection, candidate.content_projection);
    assert.equal(objectHash(projection), candidate.content_projection_sha256);
    if (candidate.proposed_fields) assert.deepEqual(Object.keys(candidate.proposed_fields), allowed);
    const changed = Object.keys(candidate.before_entry).filter(key => JSON.stringify(candidate.before_entry[key]) !== JSON.stringify(projection[key]));
    assert.deepEqual(changed, candidate.changed_fields);
    assert.ok(changed.every(key => allowed.includes(key)));
    const current = currentLexemes.get(candidate.id);
    return { id: candidate.id, position: candidate.position, author_disposition: candidate.disposition, preimage_sha256: objectHash(candidate.before_entry), proposed_projection_sha256: objectHash(projection), changed_fields: changed, non_content_fields_unchanged: true, current_preimage_sha256: current ? objectHash(current) : null, current_preimage_matches: Boolean(current && objectHash(current) === candidate.before_entry_sha256) };
  });
  assert.equal(candidateAudit.length, 10);

  const frozenContextPins = [];
  for (const section of ['selected_entries', 'containing_modules', 'containing_module_expressions', 'expression_uses', 'derivative_expression_uses', 'focus_expressions', 'related_entry_boundaries', 'previous_whole_entry_holds', 'inherited_expression_holds', 'additional_foundation02_preservation']) {
    for (const item of context[section]) {
      const expectedPin = item.entry_json_sha256 || item.module_json_sha256 || item.before_entry_json_sha256;
      assert.equal(objectHash(item.before_entry), expectedPin, `Context preimage ${section}: ${item.id || item.course_id}`);
      frozenContextPins.push({ section, id: item.id || `${item.course_id}/${item.module_id}`, preimage_sha256: expectedPin, matches: true });
    }
  }
  assert.equal(objectHash(context.complete_existing_form_scope_mismatch.before_entry), context.complete_existing_form_scope_mismatch.entry_json_sha256);
  assert.equal(context.complete_existing_form_scope_mismatch.entry_json_sha256, '63f724e5609017e7ea9077c84221bd2cd68f5c7f70b212034eb2d8603dbcec14');
  const lexemeFiles = baseline.source_file_hashes.filter(item => item.path.startsWith('data/professional/lexemes/') && item.path.endsWith('.json'));
  const allLexemes = lexemeFiles.flatMap(item => load(path.join(repo, item.path)).lexemes);
  assert.ok(allLexemes.every(Boolean));
  const courses = baseline.source_file_hashes.filter(item => item.path.startsWith('data/professional/courses/') && item.path.endsWith('.json')).map(item => load(path.join(repo, item.path)));
  const observedCurrent = {
    senses: allLexemes.length,
    language_reviewed: allLexemes.filter(entry => entry.review.language === 'reviewed').length,
    whole_entry_reviewed: allLexemes.filter(entry => entry.review.status === 'reviewed').length,
    foundation02_language_reviewed: currentTarget.lexemes.filter(entry => entry.review.language === 'reviewed').length,
    raw_ready_status_modules: courses.flatMap(course => course.modules).filter(module => module.status === 'ready').length
  };
  const scope = 'Exact definition, original example and editorial difficulty only; independent AI language review, not human, subject-matter, morphology, media, domain, whole-expression, module or release approval.';
  const exclusions = ['canonical identity', 'accepted forms', 'regions', 'practice modes', 'morphology', 'image and audio', 'notes', 'references and source registry', 'domain and overall review gates', 'course membership', 'expressions and scored bindings'];
  const rationales = {
    broken: {
      definition: 'The retained wording covers the selected physical-object damage and loss-of-function adjective. Oxford adjective sense 1 and the two ungraded Collins British adjective senses support those linked applications; promises, emotional collapse and interrupted language are outside this entry.',
      example: 'The case-handle sentence gives a concrete object whose damage prevents its ordinary use. It is grammatical and illustrates the selected adjective without prescribing a repair or asserting a specialist cause.',
      difficulty: 'Accept editorial A2 from selected Oxford adjective metadata cefr a2, corroborated by the Health problems A2 topic. Collins A2 belongs to its participle cross-reference and is excluded as adjective-level evidence; its relevant British adjective senses are ungraded.'
    },
    urgent: {
      definition: 'Without delay expresses the prompt-attention/action meaning more precisely than the draft very soon. Both selected dictionary adjective sections support immediacy; this is no medical triage or regulatory deadline definition.',
      example: 'An imminent delivery departure supplies a plausible reason for prompt action on a message. The sentence is natural and does not add a duty, emergency classification or exact response threshold.',
      difficulty: 'Accept editorial B2 using frozen Oxford selected cefr b2. Fresh Collins selected B1+ is a differing literal label, not B1 or B2 and not converted. The evidence supports a bounded placement judgment, not source unanimity.'
    },
    unclear: {
      definition: 'The retained definition fits information or wording that is hard to understand or insufficiently definite. Oxford selected sense 1 directly supports it; Collins British wording is ungraded related support, while its COBUILD B2 unknown/uncertain-situation sense is not an exact separate wording label.',
      example: 'Instructions lacking a clear start time directly illustrate the chosen information sense. The sentence does not transfer acceptance to a person who is uncertain or to an illegible label.',
      difficulty: 'Accept editorial B1 based on Oxford selected cefr b1 and its rendered B1 topic. Preserve Collins B2 on its related uncertain-situation sense; the British wording section is ungraded. Do not flatten distinct sense evidence into consensus.'
    },
    safe: {
      definition: 'The revised wording selects a thing or activity unlikely to harm someone and removes the unsupported unacceptable-risk threshold and merged protected-person wording. Oxford sense 2 and Collins physical-danger sense 1 support this lexical sense. It grants no occupational safety guarantee.',
      example: 'The team asks about using a route; the interrogative context illustrates the adjective without certifying the route as safe. The secure-container noun and protected-person sense remain separate.',
      difficulty: 'Accept editorial A2: frozen Oxford safe_sng_2 cefr a2 and fresh Collins selected A2 both concern the thing/activity physical-danger meaning. No source level is inferred from unrelated safe senses.'
    },
    incident: {
      definition: 'The revised definition keeps the workplace editorial restriction and the ordinary unusual/problematic event meaning. It removes the unsupported requirement that every incident needs recording or attention. Violent, diplomatic, clinical and technical reporting categories are separate.',
      example: 'A supervisor recording an event after consultation is a coherent original workplace example. It describes an action without defining a compulsory reporting workflow or approving the surrounding incident-report expressions.',
      difficulty: 'Accept editorial B2 from Oxford selected cefr b2 and Collins event-noun B2. Collins explicitly marks the use formal; that register remains recorded, and the label is not extended to specialist incident compounds.'
    },
    concern: {
      definition: 'A matter that worries someone narrows the entry to the countable worrying fact or situation and removes the broader needs-attention alternative. Collins noun sense 3 is direct evidence. Oxford worry noun sense 1 supports the semantic family only; its important-matter sense is not substituted.',
      example: 'I have a concern about the delivery address naturally names one worrying matter. The countable noun is clear and distinct from a business, a priority, protective interest, or the verb concerns meaning is about.',
      difficulty: 'Accept editorial B2 chiefly from the exact Collins countable worrying-matter sense. Oxford concern_sng_6 cefr b2 is only related worry-noun metadata, not proof of an identical countable selected sense.'
    },
    solution: {
      definition: 'The retained definition selects a successful way to deal with a problem. Oxford and Collins problem-response noun sections support it; a chemical mixture and a puzzle or mathematical answer are not silently included.',
      example: 'Agreement on a practical solution is natural workplace wording for a response to a problem. It adds no unsupported technical effectiveness claim and contains no chemical-mixture meaning.',
      difficulty: 'Accept editorial A2 following frozen Oxford selected solution_sng_1 cefr a2. Collins labels the selected problem-response sense B1+; preserve that difference literally. A2 is an editorial choice, not a conversion of B1+ or agreement between publishers.'
    },
    procedure: {
      definition: 'The retained definition expresses an established way of doing an activity. Oxford general-method sense 1 and Collins method noun support it. A surgical operation and particular legal or regulated processes are separate applications requiring their own review.',
      example: 'Following a procedure for requesting equipment directly demonstrates an established method. It improves on the draft personification of a procedure explaining something, while making no claim that a particular organization uses this method.',
      difficulty: 'Accept editorial B2 from frozen Oxford selected cefr b2, its rendered Scientific research B2 topic, and fresh Collins general-method B2. The topic label remains distinct from the literal HTML attribute and does not approve research or clinical procedures.'
    }
  };
  const holdReasons = {
    unsafe: 'Whole-entry hold. The ordinary dangerous-place/activity sense and storage-area example have lexical support, but neither fresh selected Oxford/Collins section nor frozen selected Oxford metadata supplies a level. This evidence does not adequately support the proposed A2-to-B1 change. Transparent un- morphology and example simplicity are not measured placement evidence. Missing labels do not establish that B1 is false. Keep every original field, including draft A2, exact and unapproved; no partial definition/example acceptance.',
    hazard: 'Whole-entry hold retained. Oxford rendered Danger C1 and frozen hazard_sng_1 fkcefr c1 are explicit; cefr is null, and Collins supplies no selected level. Do not relabel fkcefr as cefr or clamp C1 to the course range. No lower-level projection is accepted. Keep every original field, including draft A2, exact and unapproved.'
  };
  const reviewEntries = candidates.entries.map(candidate => {
    const accepted = Boolean(rationales[candidate.term]);
    return {
      id: candidate.id, term: candidate.term, position: candidate.position,
      independent_decision: accepted ? 'accept_exact_three_field_projection_for_ai_language_review_only' : 'hold_entire_original_entry',
      author_disposition: candidate.disposition,
      original_entry_sha256: candidate.before_entry_sha256,
      author_candidate_projection_sha256: candidate.content_projection_sha256,
      accepted_projection_sha256: accepted ? candidate.content_projection_sha256 : null,
      preserved_entry_sha256: accepted ? null : candidate.before_entry_sha256,
      before_fields: Object.fromEntries(allowed.map(field => [field, candidate.before_entry[field]])),
      author_proposed_fields: candidate.proposed_fields,
      accepted_fields: accepted ? candidate.proposed_fields : null,
      actual_content_changes_if_integrated: accepted ? candidate.changed_fields : [],
      field_decisions: Object.fromEntries(allowed.map(field => [field, { decision: accepted ? 'accept_exact_value' : 'hold_no_partial_acceptance', value: accepted ? candidate.proposed_fields[field] : candidate.before_entry[field], rationale: accepted ? rationales[candidate.term][field] : holdReasons[candidate.term], source_ids: candidate.source_ids }])),
      hold_reason: accepted ? null : holdReasons[candidate.term],
      accepted_projection: accepted ? candidate.content_projection : null,
      held_original_entry: accepted ? null : candidate.before_entry,
      source_ids: candidate.source_ids,
      scope, excluded_scope: exclusions,
      production_integrated: false, review_gates_changed: false
    };
  });
  const acceptedEntries = reviewEntries.filter(entry => entry.accepted_fields);
  const counts = {
    reviewed_entries: 10, author_proposals: 9, author_holds: 1,
    accepted_exact_projections: acceptedEntries.length,
    held_whole_entries: reviewEntries.length - acceptedEntries.length,
    accepted_field_decisions: acceptedEntries.length * 3,
    accepted_entries_with_content_edits: acceptedEntries.filter(entry => entry.actual_content_changes_if_integrated.length).length,
    unchanged_accepted_projections: acceptedEntries.filter(entry => !entry.actual_content_changes_if_integrated.length).length,
    accepted_content_edits: acceptedEntries.reduce((sum, entry) => sum + entry.actual_content_changes_if_integrated.length, 0),
    content_edits_by_field: Object.fromEntries(allowed.map(field => [field, acceptedEntries.filter(entry => entry.actual_content_changes_if_integrated.includes(field)).length]))
  };
  assert.deepEqual(counts, { reviewed_entries: 10, author_proposals: 9, author_holds: 1, accepted_exact_projections: 8, held_whole_entries: 2, accepted_field_decisions: 24, accepted_entries_with_content_edits: 6, unchanged_accepted_projections: 2, accepted_content_edits: 10, content_edits_by_field: { definition: 4, example: 1, difficulty: 5 } });
  write('review-ledger.json', { schema: 1, status: 'frozen_independent_language_review_unintegrated', reviewer: '/root/runtime_recovery, independent of /root/recover_delivery author; AI review only', consultation_date_local: '2026-10-17', scope, input_pins: inputPins, hash_convention: 'SHA256 of UTF-8 JSON.stringify(parsed entry), preserving parsed key order, for entry/projection pins; raw bytes for files.', counts, global_limits: exclusions, production_mutated: false, entries: reviewEntries });

  const fresh = {
    broken: [
      { section: 'Adjective sense 1, rendered lines 112-125', summary: 'Physical damage or inability to function; selected Health problems topic A2.', level: 'A2', label_scope: 'Health problems topic attached to selected adjective sense 1', boundary: 'Promises, interrupted activity/language and emotional uses remain separate.' },
      { section: 'COBUILD lines 222-224; British adjective sense 2, lines 289-293, and sense 7, lines 321-324', summary: 'The British adjective sections support physical breakage and nonfunctioning, with no observed level on those sections.', level: null, label_scope: null, other_labels: [{ literal: 'A2', scope: 'COBUILD past-participle cross-reference', use_as_selected_adjective_level: false }], boundary: 'Do not use the participle cross-reference level as an adjective-sense level.' }
    ],
    urgent: [
      { section: 'Adjective sense 1, lines 105-118', summary: 'Attention or action is needed immediately; no selected rendered level observed.', level: null, label_scope: null, boundary: 'No medical triage, legal deadline or obligatory response threshold accepted.' },
      { section: 'COBUILD adjective sense 1, lines 222-230', summary: 'The selected prompt-action meaning has literal B1+.', level: 'B1+', label_scope: 'Selected needing-prompt-action adjective sense', boundary: 'B1+ remains literal and differs from Oxford selected b2 metadata.' }
    ],
    unclear: [
      { section: 'Adjective sense 1, lines 113-118', summary: 'Information or wording not definite or easy to understand; selected topic B1.', level: 'B1', label_scope: 'Topic attached to selected information/wording sense', boundary: 'A person who does not understand is a distinct use.' },
      { section: 'COBUILD sense 1, lines 222-232; British dictionary lines 276-280', summary: 'COBUILD B2 describes an unknown or uncertain situation; British ambiguous/not-definite wording is ungraded.', level: 'B2', label_scope: 'Related unknown/uncertain situation sense; not an exact separate wording level', boundary: 'The B2 person-not-understanding sense is also separate; no averaging of sense labels.' }
    ],
    safe: [
      { section: 'Adjective sense 2, lines 150-165', summary: 'Things or activities unlikely to cause physical harm; no selected rendered level observed.', level: null, label_scope: null, boundary: 'Protected person/property sense 1 and secure-container noun are distinct.' },
      { section: 'COBUILD adjective sense 1, lines 224-234', summary: 'Things or activities that do not cause physical harm; selected A2.', level: 'A2', label_scope: 'Selected physical-danger thing/activity adjective', boundary: 'No technical unacceptable-risk threshold or safety certification follows.' }
    ],
    unsafe: [
      { section: 'Adjective sense 1, lines 103-106', summary: 'Dangerous thing, place or activity; no selected level observed.', level: null, label_scope: null, other_labels: [{ literal: 'B2', scope: 'Word of the Day reasonably in footer', use_as_selected_adjective_level: false }], boundary: 'A person in danger and an unsafe legal conviction are distinct; footer B2 is excluded.' },
      { section: 'COBUILD adjective sense 1, lines 222-230', summary: 'A dangerous building, machine, activity or area; no selected level observed.', level: null, label_scope: null, boundary: 'Person and conviction meanings do not establish the level of this selected sense.' }
    ],
    hazard: [
      { section: 'Dangerous-thing noun, lines 105-120', summary: 'A dangerous thing or situation; the selected Danger topic is C1.', level: 'C1', label_scope: 'Danger topic attached to selected noun', boundary: 'Preserve C1 without clamping; frozen fkcefr c1 is not cefr.' },
      { section: 'COBUILD noun sense 1, lines 224-232', summary: 'A dangerous thing or situation; no selected level observed.', level: null, label_scope: null, boundary: 'No lower-level evidence or specialist hazard-category acceptance follows.' }
    ],
    incident: [
      { section: 'Noun sense 1, lines 105-122', summary: 'An ordinary event, often unusual or unpleasant; no selected rendered level observed.', level: null, label_scope: null, boundary: 'Violent and diplomatic senses remain separate.' },
      { section: 'COBUILD noun, lines 224-237', summary: 'The selected event noun has B2 and explicit formal register.', level: 'B2', label_scope: 'Selected event noun', register: 'formal', boundary: 'No reporting duty or specialist incident definition is approved.' }
    ],
    concern: [
      { section: 'Related worry-noun sense 1, lines 108-126', summary: 'A feeling of worry is related lexical evidence, not the exact countable worrying-matter sense.', level: null, label_scope: null, boundary: 'Important-matter sense 3 and the verb page cannot substitute for the selected countable noun.' },
      { section: 'COBUILD countable noun sense 3, lines 261-268', summary: 'A worrying fact or situation directly supports the selected countable matter sense, with B2.', level: 'B2', label_scope: 'Exact countable worrying-fact/situation noun', boundary: 'Verb, company, priority and protective-interest uses remain separate.' }
    ],
    solution: [
      { section: 'Problem-response noun sense 1, lines 105-124', summary: 'A way to deal with a problem; no selected rendered level observed.', level: null, label_scope: null, boundary: 'Puzzle answers and chemical mixtures are distinct senses.' },
      { section: 'COBUILD noun sense 1, lines 224-231', summary: 'The selected problem-response sense has literal B1+.', level: 'B1+', label_scope: 'Selected way-to-deal-with-a-problem sense', boundary: 'Preserve disagreement with Oxford selected a2; do not convert B1+.' }
    ],
    procedure: [
      { section: 'Established-method noun sense 1, lines 105-126', summary: 'An established or usual method; selected Scientific research topic B2.', level: 'B2', label_scope: 'Scientific research topic attached to selected method sense', boundary: 'A medical operation and specialist procedures are separate.' },
      { section: 'COBUILD general-method noun, lines 224-235', summary: 'A general method of doing something; selected B2.', level: 'B2', label_scope: 'Selected general-method noun', boundary: 'No clinical, legal, isolation or lockout method is approved.' }
    ]
  };
  const sourceObservations = sources.sources.map(source => {
    const publisherIndex = source.publisher.includes('Oxford') ? 0 : 1;
    const observation = fresh[source.term][publisherIndex];
    return {
      source_id: source.id, term: source.term, publisher: source.publisher, url: source.url,
      fresh_reviewer_rendered_consultation: { consulted_on: '2026-10-17', mechanism: 'web connector open', succeeded: true, ...observation, response_http_status: null, raw_body_sha256: null, limitation: 'The connector rendered page text; HTTP status and raw body hashes were not exposed or independently recorded.' },
      frozen_author_metadata_only: { provenance: `${researchRelative}/source-index.json`, provenance_sha256: expected['source-index.json'], metadata_artifact: source.metadata_artifact || null, metadata_artifact_sha256: source.metadata_artifact ? expected['oxford-html-metadata.json'] : null, observed_html_selected_levels: source.observed_html_selected_levels, author_http_status: source.http_status ?? null, author_raw_body_bytes: source.raw_body_bytes ?? null, author_raw_body_sha256: source.raw_body_sha256 ?? null, independently_downloaded_html: false },
      source_page_retained: false, source_content_imported: false, assets_acquired: false,
      rights_scope: 'Public dictionary consultation only; no license grant for copying, media acquisition, or redistribution is claimed.'
    };
  });
  assert.equal(sourceObservations.length, 20);
  write('source-observations.json', {
    schema: 1, status: 'frozen_independent_rendered_consultation_with_attributed_author_metadata',
    method: 'Reviewer freshly opened all twenty original Oxford and Collins pages and inspected selected or explicitly related sense sections. HTML attributes/body hashes below come only from frozen author artifacts. No publisher page bodies, definitions, examples, exercises or media are imported.',
    requests: { total_open_requests: 30, unique_successful_original_dictionary_pages: 20, failed_additional_pages: 1, followup_requests: 9 },
    failed_additional_access: { url: 'https://dictionary.cambridge.org/dictionary/english/unsafe', result: 'Internal Error', evidence_used: false, http_status: null, body_hash: null },
    followup_limitations: ['Three followups using prior connector references resolved to incident, procedure and solution rather than the intended broken, safe and unclear pages. Those responses were excluded for the intended targets; fresh canonical-URL followups recovered and inspected the intended sections.', 'One other procedure followup correctly displayed the selected Scientific research B2 topic.', 'Rendered line numbers describe the consulted snapshots and may change when publisher pages change. Canonical URLs are authoritative identifiers.'],
    level_policy: 'Record labels literally and attribute their sense and source. B1+ is not silently rounded. Missing labels are missing evidence, not a proof of absence of difficulty. Oxford cefr and fkcefr are distinct literal attributes. Topic labels, selected metadata, related senses and unrelated footers remain separate.',
    sources: sourceObservations
  });

  const boundaries = {
    broken: 'Accept only physical damage/nonfunctioning adjective language in the exact lexical projection. Broken seals, glass, links, repairs, reporting and external expression scoring remain separately pending.',
    urgent: 'No medical assessment, emergency classification, response deadline or duty is accepted; caregiving urgency remains specialist context.',
    unclear: 'No acceptance transfers to unclear use-by dates, inherited office-admin holds, uncertain commercial relationships, or clear/clarify family derivatives.',
    safe: 'Safe-container nouns are separate from the physical-danger adjective. Safety/safely/safeguard derivatives and route or workplace safety judgments stay pending.',
    unsafe: 'Entire lexical entry is held; no expression receives language or domain acceptance. Unsafe storage language does not approve a risk threshold.',
    hazard: 'Entire lexical entry is held. Trip, slip, choking, electrical and pictogram contexts remain specialist/compound uses without approval.',
    incident: 'Only the ordinary workplace-event lexical projection is accepted. Reporting forms, clinical incidents, IT response and incident-response compounds stay pending.',
    concern: 'The countable worrying-matter noun is bounded. Plural concerns can be a noun or the verb is about; verb, priority, company and protective-interest contexts are not accepted.',
    solution: 'Problem-response noun acceptance does not cover cleaning/chemical mixtures, problem-solving derivatives or new external scored bindings.',
    procedure: 'Only the general established-method lexical projection is accepted. Isolation, lockout, housekeeping, medical and other specialist procedures are not approved.'
  };
  const concernVerbs = [
    'expr.nursing.module04.06', 'expr.caregiving.module04.08', 'expr.education_childcare.module04.02',
    'expr.education_childcare.module06.04', 'expr.education_childcare.module09.03',
    'expr.cleaning_facilities.module06.03', 'expr.cleaning_facilities.module06.08',
    'expr.sales_marketing.module06.04', 'expr.sales_marketing.module08.01',
    'expr.clinical_medicine.module08.01', 'expr.clinical_medicine.module10.09',
    'expr.accounting_finance.module09.10', 'expr.legal_paralegal.module06.04'
  ];
  const safeNouns = ['expr.hospitality_tourism.module03.10', 'expr.accounting_finance.module03.03'];
  const solutionMixtures = ['expr.retail.module08.01', 'expr.food_service.module08.05', 'expr.cleaning_facilities.module06.06'];
  const focusJudgments = {
    'expr.foundation.module02.05': 'Urgent, concern and solution have bounded lexical acceptance; resolve remains an unintegrated proposal at this baseline. Preserve the entire expression and existing scoring pending separate acceptance.',
    'expr.foundation.module02.06': 'Broken handle is compatible with the selected adjective; report, fault and replace remain separately scoped. Preserve the entire expression and all existing scoring; no expression acceptance.',
    'expr.foundation.module02.09': 'Unsafe is a whole-entry hold, while safe/procedure have bounded lexical acceptance. Preserve report/follow scope and the pending domain gate; no expression or specialist safety acceptance.',
    'expr.foundation.module02.10': 'Hazard remains a whole-entry hold; incident has bounded lexical acceptance. Preserve report scope and the pending domain gate; no expression or specialist incident/hazard acceptance.'
  };
  const expressionJudgment = item => {
    const special = [];
    if (concernVerbs.includes(item.id)) special.push('The concerns surface is the verb meaning is about; do not bind it to concern.worrying-matter.n.');
    if (safeNouns.includes(item.id)) special.push('Safe denotes a secure container noun; exclude the selected adjective binding.');
    if (solutionMixtures.includes(item.id)) special.push('Solution denotes a cleaning/chemical mixture; exclude solution.problem-answer.n.');
    if (focusJudgments[item.id]) special.push(focusJudgments[item.id]);
    return special.length ? special.join(' ') : 'Preserve the entire expression and its current scoring. Surface occurrence alone gives no sense acceptance, new binding, or language/domain gate change; apply the term-specific boundaries in this review.';
  };
  const expressionRows = items => items.map(item => ({ id: item.id, resource: item.resource || 'res://data/professional/expressions/foundation-module02.json', preimage_sha256: item.entry_json_sha256, text: item.before_entry.text, matches: item.matches || null, focus_lexeme_ids: item.before_entry.focus_lexeme_ids, review_before: item.before_entry.review, independent_judgment: expressionJudgment(item), action: 'preserve_exact_no_acceptance_or_new_scored_binding' }));
  const surfaceIds = new Set(context.expression_uses.map(item => item.id));
  for (const id of [...concernVerbs, ...safeNouns, ...solutionMixtures]) assert.ok(surfaceIds.has(id), `Expected context not found: ${id}`);
  for (const item of context.focus_expressions) assert.ok(focusJudgments[item.id]);
  const complete = context.complete_existing_form_scope_mismatch;
  write('context-review.json', {
    schema: 1, status: 'frozen_independent_context_review_no_expression_acceptance',
    provenance: { frozen_context_path: `${researchRelative}/context-screen.json`, sha256: expected['context-screen.json'], method: 'Reviewer inspected the containing module and expression texts, all surface and derivative context texts, related-identity definitions, historical holds and current gates. The static assembler verifies pins and writes the recorded judgments; it is not an automated semantic review or production validator.' },
    frozen_scope_counts: context.summary,
    independently_accepted_expression_count: 0, new_scored_binding_count: 0,
    independent_whole_entry_hold_count: 2,
    term_boundaries: boundaries,
    explicit_sense_exclusions: { secure_container_safe: safeNouns, chemical_mixture_solution: solutionMixtures, concern_verb_is_about: concernVerbs },
    matching_policy: context.matching_policy,
    counts_by_selected_id: context.counts_by_selected_id,
    selected_memberships: context.selected_memberships,
    containing_modules: context.containing_modules.map(item => ({ course_id: item.course_id, module_id: item.module_id, preimage_sha256: item.module_json_sha256, status_before: item.before_entry.status, action: 'preserve_exact_draft_module_and_membership_no_readiness' })),
    containing_module_expressions: expressionRows(context.containing_module_expressions),
    surface_expression_review: expressionRows(context.expression_uses),
    derivative_expression_review: context.derivative_expression_uses.map(item => ({ id: item.id, resource: item.resource, preimage_sha256: item.entry_json_sha256, text: item.before_entry.text, matches: item.matches, focus_lexeme_ids: item.before_entry.focus_lexeme_ids, review_before: item.before_entry.review, independent_judgment: 'Derivative or related-form occurrence is not the selected lexical sense; preserve exact current text, scoring and gates without transferring acceptance.' })),
    selected_focus_expression_review: expressionRows(context.focus_expressions),
    related_identity_review: context.related_entry_boundaries.map(item => ({ id: item.id, resource: item.resource, preimage_sha256: item.entry_json_sha256, definition: item.before_entry.definition, review_before: item.before_entry.review, action: 'preserve_exact_separate_identity_no_transfer_of_acceptance' })),
    previous_whole_entry_holds: context.previous_whole_entry_holds.map(item => ({ ...item, independent_action: 'preserve_exact_whole_entry_hold_no_partial_acceptance' })),
    current_whole_entry_holds: reviewEntries.filter(item => !item.accepted_fields).map(item => ({ id: item.id, preimage_sha256: item.preserved_entry_sha256, reason: item.hold_reason, action: 'preserve_entire_original_entry_and_draft_difficulty_unapproved' })),
    inherited_expression_holds: context.inherited_expression_holds.map(item => ({ ...item, independent_action: 'preserve_exact_inherited_expression_hold' })),
    additional_foundation02_preservation: context.additional_foundation02_preservation.map(item => ({ ...item, independent_action: 'preserve_exact_no_expression_acceptance' })),
    pending_domain_expressions: context.focus_expressions.filter(item => ['expr.foundation.module02.09', 'expr.foundation.module02.10'].includes(item.id)).map(item => ({ id: item.id, preimage_sha256: item.entry_json_sha256, domain_before: item.before_entry.review.domain, action: 'preserve_pending_domain_gate' })),
    complete_existing_form_scope_mismatch: { id: complete.id, preimage_sha256: complete.entry_json_sha256, current_image_brief: complete.before_entry.media.image.brief, image_status: complete.before_entry.media.image.status, image_review_status: complete.before_entry.media.image.review.status, action: 'The old form-image brief remains live, unchanged, mismatched to the finishing-work/task sense, pending and unapproved. No picture-readiness claim.' },
    prior_unintegrated_work: 'Third10 and fourth10 projections are unintegrated at this pinned baseline; this package does not integrate them.',
    gate_boundary: 'No identity, morphology, media, source registry, note/reference, specialist/domain, expression, scoring, course, module or release gate is edited or accepted by this package.'
  });

  const audit = {
    schema: 1, status: drift.length ? 'frozen_evidence_verified_current_source_drift_recorded' : 'frozen_evidence_and_current_source_pins_match',
    audit_type: 'Independent static JSON/hash/projection comparison only; not production validation, test suite, native execution, export or build.',
    input_pins: inputPins, author_artifact_audit: authorArtifacts,
    source_file_count: sourceFileAudit.length, source_file_audit: sourceFileAudit,
    drift_count: drift.length, drift,
    target: { path: baseline.target.path, frozen_sha256: baseline.target.raw_sha256, current_sha256: currentTargetHash, matches: currentTargetHash === baseline.target.raw_sha256 },
    candidate_audit: candidateAudit,
    context_preimage_pin_audit: frozenContextPins,
    frozen_observed_status: context.observed_status,
    current_raw_lexical_and_module_status_observations: observedCurrent,
    count_limits: 'Lexical counts are separate from expression counts. Raw flags do not certify readiness. No production readiness validator ran; with zero bound-file drift the frozen evidence reports zero ready modules and remains exact.',
    production_writes: false, source_registry_writes: false, tests_run: false, native_godot_run: false, builds_or_exports_run: false
  };
  write('input-audit.json', audit);
  assert.equal(drift.length, 0, 'Current source drift was recorded; a new revision/rebase review is required before integration.');
  assert.ok(candidateAudit.every(item => item.current_preimage_matches));
  assert.deepEqual(observedCurrent, { senses: 4939, language_reviewed: 317, whole_entry_reviewed: 130, foundation02_language_reviewed: 18, raw_ready_status_modules: 0 });
  const readme = `# Foundation02 fifth-ten independent language review\n\nEight exact definition/example/editorial-difficulty projections are independently accepted for AI language review only. Unsafe and hazard remain exact whole-entry holds. This reviewer is separate from the research author. All projections remain unintegrated; no production file, source registry, note, reference or gate is changed.\n\nAccepted levels: broken A2; urgent B2; unclear B1; safe A2; incident B2; concern B2; solution A2; procedure B2. Six accepted entries have content edits: four definitions, one example and five difficulties. Broken and solution retain their original three fields. The twenty-four field decisions each have a distinct rationale in review-ledger.json.\n\nUnsafe has ordinary lexical meaning/example support but insufficient evidence here for the proposed A2-to-B1 change. Both selected dictionaries lack an observed label; transparent morphology and example simplicity do not establish that placement. This does not prove B1 false. No field receives partial acceptance, and its original A2 remains an unapproved draft. Hazard retains its author's whole-entry hold: Oxford rendered Danger C1 and frozen fkcefr c1 are explicit, cefr is null, and Collins has no selected level. There is no clamping to a lower level; the original A2 remains an unapproved draft.\n\nAll twenty original Oxford and Collins pages were freshly consulted through the web connector. Selected Oxford cefr/fkcefr attributes and body hashes were inspected only in frozen author evidence, not independently downloaded. Broken's Collins A2 participle cross-reference is excluded as adjective-level evidence; concern's Oxford worry noun is related support only, while Collins supplies the exact countable worrying-matter B2 sense. Collins B1+ labels, the unclear sense distinction, incident's formal register and every missing label remain explicit. No publisher bodies, examples, exercises, audio or artwork were imported.\n\nThe context review covers twenty identical containing draft modules, two hundred memberships, all ten containing expressions, ninety surface expressions with one hundred term-expression pairs, eighty-one derivative expressions, four selected-focus expressions and forty-six related identities. Safe-container nouns, chemical-mixture solutions and thirteen verb uses of concerns remain separate. No expression or specialist use is accepted and no scored binding is added. Collect, notify, postpone and verify retain exact lexical holds; all seventeen inherited expression holds and Foundation02.04/.05/.07/.08 remain exact. Foundation02.09/.10 retain pending domain gates. Third10 and fourth10 remain unintegrated at this baseline. Complete's old form-image brief remains live, mismatched, pending and unapproved.\n\nIndependent static comparison found zero drift across 350 author-bound files, all sixteen author artifacts, ten candidate preimages and exact projections. Raw lexical counts remain 4,939 senses, 317 language-reviewed and 130 overall-reviewed; Foundation02 remains 18/50 language-reviewed. Zero modules have a raw ready status, and frozen unchanged evidence reports zero ready modules. Expression counts are separate. No production validator, tests, native Godot, build, export, packaging or deployment ran.\n\nThe authoritative author inventory SHA256 is ${expected['inventory.json']}; candidate ledger SHA256 is ${expected['candidate-ledger.json']}. Entry, source, metadata and context pins are in the JSON artifacts. inventory.json binds every delivery file except itself.\n\nOne additional Cambridge unsafe lookup failed with Internal Error and yielded no evidence. Three followups resolved stale connector references to different pages; those responses were excluded for the intended terms and corrected with canonical URLs. Oversized local reads were truncated; compact followups recovered the relevant fields. These limitations do not count as successful evidence.\n\nThis is immutable evidence. The assembly script runs once and writes only this new directory. Do not rerun it or the author scripts; any revision requires a new directory with explicit lineage.\n`;
  write('README.md', readme);
  const finalSourceSha256 = hash(read(__filename));
  assert.equal(finalSourceSha256, scriptSha256);
  write('assembly-result.json', {
    schema: 1, status: 'completed_once', started_at: startedAt, completed_at: new Date().toISOString(),
    attempt: 1, script_sha256_at_start: scriptSha256, script_sha256_at_end: finalSourceSha256, executed_source_equality_verified: true,
    counts, author_artifacts_verified: 16, bound_source_files_verified: 350, bound_source_file_drift: 0,
    candidate_preimages_verified: 10, candidate_projections_verified: 10,
    context_preimage_pins_verified: frozenContextPins.length + 1,
    production_mutated: false, production_validator_or_test_dispatched: false, native_godot_dispatched: false, build_export_or_browser_dispatched: false
  });
  const artifacts = fs.readdirSync(output).sort().filter(name => name !== 'inventory.json').map(name => {
    const bytes = read(path.join(output, name));
    return { path: name, sha256: hash(bytes), bytes: bytes.length };
  });
  write('inventory.json', { schema: 1, status: 'frozen_independent_review', recorded_at: new Date().toISOString(), directory: path.relative(repo, output).replaceAll('\\', '/'), inventory_self_hash_excluded: true, production_mutated: false, executed_source_equality_verified: true, artifacts });
  console.log(JSON.stringify({ status: 'completed_once', directory: path.relative(repo, output).replaceAll('\\', '/'), inventory_sha256: hash(read(path.join(output, 'inventory.json'))), review_ledger_sha256: hash(read(path.join(output, 'review-ledger.json'))), script_sha256: scriptSha256, counts, bound_file_drift: 0, production_dispatch: false }, null, 2));
} catch (error) {
  write('assembly-failure.json', { schema: 1, status: 'failed_attempt_preserved_do_not_replay', started_at: startedAt, failed_at: new Date().toISOString(), script_sha256: scriptSha256, error: String(error.stack || error), production_dispatch: false });
  throw error;
}
