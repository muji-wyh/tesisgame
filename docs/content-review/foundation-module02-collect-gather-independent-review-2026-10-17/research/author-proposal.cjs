'use strict';
// Proposal-file assembly only. No production serializer, validator, tests or runtime imports.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const rawHash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const write = (file, value) => fs.writeFileSync(path.join(__dirname, file), JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const context = JSON.parse(fs.readFileSync(path.join(__dirname, 'context.json'), 'utf8'));
const before = context.canonical_target.entry;
const phraseBefore = context.affected_expression.entry;
assert.equal(hash(before), '177f9fc35b0d348ddcc3cdf60c43dd5119d145acfe781d17c2b988e1b6d77981');
const live = read(context.canonical_target.file).lexemes.find(item => item.id === before.id);
const livePhrase = read(context.affected_expression.file).expressions.find(item => item.id === phraseBefore.id);
assert.deepEqual(live, before);
assert.deepEqual(livePhrase, phraseBefore);

const sources = [
  {
    id: 'foundation02-collect-repair-oxford-collect',
    title: "Oxford Advanced Learner's Dictionary: collect, gathering sense",
    publisher: 'Oxford University Press',
    url: 'https://www.oxfordlearnersdictionaries.com/definition/english/collect_1',
    status: 'consulted', consulted_on: '2026-10-17',
    scope: 'Fresh gathering sense 1 consultation supports intentional gathering from several sources and the object plus from pattern. Raw collect_sng_2 records cefr=a2. Pickup sense 4 is separate and records cefr=b1; British labels appear on person-pickup examples. The unrelated footer level is excluded. This new B1 teaching proposal is not Oxford B1 certification of gathering and remains unaccepted. No publisher definition, example, image or audio is imported.',
    asset_license: null, assets_acquired: false
  },
  {
    id: 'foundation02-collect-repair-collins-collect',
    title: 'Collins COBUILD: collect, gathering sense',
    publisher: 'HarperCollins',
    url: 'https://www.collinsdictionary.com/dictionary/english/collect',
    status: 'consulted', consulted_on: '2026-10-17',
    scope: 'Fresh rendered COBUILD sense 1 is the multiple-source gathering verb and displays B1. Separate pickup sense 3 displays A2 and British usage with an American preference for pick up; American dictionary sections also include fetching, so pickup is not impossible in American English. The direct HTTP request returned 403; successful rendered consultation is distinct. This source supports proposed editorial B1 but grants no independent language, expression, morphology, domain, visual, listening or release acceptance. No publisher pages or media are retained.',
    asset_license: null, assets_acquired: false
  }
];
const sourceRegistry = read('data/professional/sources.json').sources;
for (const source of sources) assert.ok(!sourceRegistry.some(item => item.id === source.id), 'Proposed source ID already exists.');
const pendingRef = (source_id, scope) => ({ source_id, status: 'pending_term_check', scope });
const after = structuredClone(before);
after.definition = 'To bring items from several people or places into one group.';
after.example = 'Please collect one completed form from each team.';
after.difficulty = 'B1';
after.media.image.brief = 'Show a friendly worker gathering fictional completed forms from three separate teams into one folder. Keep the separate sources and the one growing set clear: one colleague hands over a form while forms from the other teams are already together. Use ordinary workplace characters, a folder and full-size form props from suitable sourced assets. Exclude a reception pickup of a preassembled bundle, money, hobby collections and private information. Do not depend on tiny labels or arrows to explain the action. This is a pending art brief; source selection and actual-size picture suitability still require review.';
after.references.push(...sources.map(source => pendingRef(source.id, 'Consulted selected gathering sense and source-specific level evidence for this unaccepted coordinated repair. B1 is proposed editorial placement; source consultation does not release the historical whole-entry hold or approve the new example, image brief or dependent expression.')));
after.editorial_notes = 'Shared workplace foundation. This unaccepted coordinated repair retains collect.gather.v for intentionally gathering items from several people or places into one group. The example uses one completed form from each team, replacing the former reception-pickup example. Proposed editorial difficulty is B1: Oxford gathering A2 and Collins gathering B1 are kept distinct, with no level borrowed from pickup, hobby collecting or a page footer. The general region is retained for the gathering use; pickup regional guidance does not restrict this sense. The revised pending image brief must show multiple sources becoming one set. The exact whole-entry hold remains historical; independent language/context, picture-suitability, morphology and audio decisions remain pending. Retaining declared practice modes is not release or visual acceptance. Source consultation does not approve the dependent expression, a complete module or any professional procedure.';

const phraseAfter = structuredClone(phraseBefore);
phraseAfter.text = 'Could you assist me while I collect one form from each team and return the borrowed key?';
phraseAfter.meaning = 'Ask a colleague to help gather forms from several teams and give a borrowed key back.';
phraseAfter.context = 'A worker gathers one fictional workshop form from each of three teams and gives a borrowed meeting-room key back to reception.';
phraseAfter.tokens = [...phraseAfter.text.matchAll(/[A-Za-z]+(?:['-][A-Za-z]+)*|[^\s]/g)].map((match, index) => ({ index, text: match[0], start: match.index, end: match.index + match[0].length }));
phraseAfter.references.push(...sources.map(source => pendingRef(source.id, 'The proposed form-from-each-team clause assesses gathering, not reception pickup. This source consultation does not independently approve the exact sentence, tokenization, focus binding, courtesy/register or context.')));
phraseAfter.references.push(
  pendingRef('foundation02-language-third10-oxford-assist', 'The separately accepted assist.help.v sense is helping a person with an activity. Fresh Oxford assist sense 1 also supports assist plus a person and marks the verb formal. The exact new expression still awaits independent review.'),
  pendingRef('foundation02-language-second10-collins-return', 'The separately accepted return.send-back.v sense is giving a borrowed item back. Fresh Collins COBUILD return sense 3 supports this selected use; the new borrowed-key wording and reception context exclude purchased-goods returns and intransitive travel. The exact expression is unaccepted.')
);
assert.deepEqual(after.review, before.review);
assert.deepEqual(after.morphology, before.morphology);
assert.deepEqual(after.media.audio, before.media.audio);
assert.deepEqual(phraseAfter.review, phraseBefore.review);
assert.deepEqual(phraseAfter.media, phraseBefore.media);
assert.deepEqual(phraseAfter.focus_lexeme_ids, ['assist.help.v', 'collect.gather.v', 'return.send-back.v']);
const protectLexeme = entry => {
  const out = structuredClone(entry);
  for (const key of ['definition', 'example', 'difficulty', 'editorial_notes', 'references']) delete out[key];
  delete out.media.image.brief;
  return out;
};
const protectExpression = entry => {
  const out = structuredClone(entry);
  for (const key of ['text', 'meaning', 'context', 'tokens', 'references']) delete out[key];
  return out;
};
assert.deepEqual(protectLexeme(after), protectLexeme(before));
assert.deepEqual(protectExpression(phraseAfter), protectExpression(phraseBefore));

const bindings = phraseAfter.focus_lexeme_ids.map(id => {
  const text = id.split('.')[0];
  const token = phraseAfter.tokens.find(item => item.text === text);
  const prior = phraseBefore.tokens.find(item => item.text === text);
  assert.ok(token && prior);
  return { sense_id: id, before_token: prior, proposed_token: token, morphological_form: 'base form', binding: 'Unchanged expression-level focus_lexeme_ids; token locations are review evidence, not a new production field.' };
});
assert.equal(phraseAfter.tokens.map(token => phraseAfter.text.slice(token.start, token.end)).join(''), phraseAfter.text.replaceAll(' ', ''));
const oldHolds = [1, 2, 3].map(number => 'build/professional-english/foundation02-held-six-research-r01/retained-reviews/' + number + '.json');
const historyPaths = [
  'build/professional-english/foundation02-held-six-research-r01/inventory.json',
  'build/professional-english/foundation02-held-six-research-r01/PROPOSALS.md',
  'build/professional-english/foundation02-held-six-research-r01/SOURCE-LEDGER.md',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/REVIEW.md',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/reviewer-decisions.json',
  'docs/content-review/foundation-module02-held-three-independent-review-2026-10-17/independent/inventory.json',
  ...oldHolds
];
const pin = file => { const bytes = fs.readFileSync(path.join(root, file)); return { path: file, bytes: bytes.length, sha256: rawHash(bytes) }; };
write('lexeme-before.json', before);
write('lexeme-after.proposed.json', after);
write('expression-before.json', phraseBefore);
write('expression-after.proposed.json', phraseAfter);
write('source-additions.proposed.json', { schema: 1, status: 'consulted_source_rows_proposed_not_installed', sources, final_order_and_shared_sources_hash: null });
write('patches.proposed.json', {
  schema: 1, status: 'unaccepted_coordinated_repair_proposal_only',
  lexeme: { id: before.id, file: context.canonical_target.file, before_sha256: hash(before), after_sha256: hash(after), changed_fields: ['definition', 'example', 'difficulty', 'media.image.brief', 'references', 'editorial_notes'], protected_projection_sha256: hash(protectLexeme(before)), before, after },
  expression: { id: phraseBefore.id, file: context.affected_expression.file, before_sha256: hash(phraseBefore), after_sha256: hash(phraseAfter), changed_fields: ['text', 'meaning', 'context', 'tokens', 'references'], protected_projection_sha256: hash(protectExpression(phraseBefore)), before: phraseBefore, after: phraseAfter },
  membership_changes: [], canonical_identity_changes: [], progress_aliases: [], gate_changes: [],
  final_production_source_test_registry_binding: null
});
write('token-and-binding-review.json', {
  schema: 1, status: 'authored_token_and_semantic_binding_proposal_unreviewed',
  expression_id: phraseAfter.id, before_text: phraseBefore.text, proposed_text: phraseAfter.text,
  before_token_count: phraseBefore.tokens.length, proposed_token_count: phraseAfter.tokens.length,
  proposed_tokens: phraseAfter.tokens, assessed_bindings: bindings,
  contextual_sense_rationale: {
    'assist.help.v': 'The speaker requests help with two named routine activities; assist me selects the existing helping-a-person sense. The formal register remains intentional.',
    'collect.gather.v': 'One form from each of three teams produces a set from multiple sources. No preassembled reception bundle is being fetched.',
    'return.send-back.v': 'Borrowed explicitly modifies key, and the context supplies giving it back to reception. This matches the existing borrowed-item sense without widening to purchased-goods returns.'
  },
  production_schema_rule: 'Production uses expression-level focus_lexeme_ids and ordered character-position tokens. No token-to-lexeme binding field exists here; this review map must not be copied as one.',
  assessment_rule: 'The exact new complete sentence, context and token sequence require independent language/context review. Neighboring term approvals do not approve it.',
  source_consultations_fresh: [
    { url: 'https://www.oxfordlearnersdictionaries.com/definition/english/assist_1', section: 'Sense 1, formal label and assist somebody pattern', observed_on: '2026-10-17', method: 'rendered_web_consultation', body_retained: false },
    { url: 'https://www.collinsdictionary.com/dictionary/english/return', section: 'COBUILD sense 3 borrowed/taken item, A2; separate sense 4 purchased-item return', observed_on: '2026-10-17', method: 'rendered_web_consultation', body_retained: false }
  ]
});
write('history-pins.json', { schema: 1, status: 'historical_holds_and_research_preserved', files: historyPaths.map(pin), preserved_collect_whole_entry_hash: hash(before), old_hold_released: false, shared_source_or_test_baseline: null });

const morphShared = [];
for (const name of fs.readdirSync(path.join(root, 'data/professional/lexemes')).filter(name => name.endsWith('.json')).sort()) {
  const file = 'data/professional/lexemes/' + name;
  for (const entry of read(file).lexemes || []) {
    const parts = entry.morphology?.parts?.filter(part => part.canonical_id === 'morph.collect') || [];
    if (parts.length) morphShared.push({ file, sense_id: entry.id, morphology_review: entry.morphology.review?.status ?? null, parts });
  }
}
write('impact-decisions.json', {
  schema: 1, status: 'research_dispositions_not_acceptance',
  target_memberships: context.target_memberships,
  affected_expression_memberships: context.expression_memberships,
  affected_assessed_expression_ids: [phraseBefore.id],
  other_literal_inflected_expression_uses: context.literal_inflected_expression_scan.hits.filter(row => !row.focus_matches_target).map(row => ({ id: row.entry.id, matched_fields: row.matched_fields, text: row.entry.text, meaning: row.entry.meaning, context: row.entry.context, disposition: 'Preserve exactly. The surface use is explanatory meaning/context, not a scored focus of collect.gather.v; it does not acquire acceptance from this repair.' })),
  related_identity_count: context.related_identities.length,
  related_identities: context.related_identities.map(row => ({ id: row.entry.id, text: row.entry.text, definition: row.entry.definition, disposition: 'Separate canonical entry; preserve all fields and gates. A collection/pickup/gather derivative or definition use is not an alias or automatically scored gather verb.' })),
  shared_morph_collect_parts: morphShared,
  morphology_limit: 'Shared morph.collect spelling/family parts do not merge canonical lexical sense progress. This repair approves no graph or family and does not alter existing pending atomic/multipart analyses.',
  existing_pickup_collect_verb_identity: null,
  identity_inventory_observation: 'The scanned live lexemes contain one exact collect headword: collect.gather.v. No exact gather or pick up headword was found. Existing pickup and collection compounds retain their distinct identities.',
  no_production_changes: true
});
write('progress-revision-decision.proposed.json', {
  schema: 1, status: 'required_future_activation_guard_proposed_not_implemented',
  collect_sense_id: before.id, proposed_expression_id: phraseBefore.id,
  canonical_gather_identity_retained: true,
  saved_records_may_be_assumed_absent: false,
  current_revision_observed: 'professional-v1',
  required_before_repaired_expression_activation: 'Choose and independently review a fresh curriculum/requirements revision unequal to professional-v1, then bind the repaired expression content and actual accepted release under that revision.',
  reason: 'Professional expression completions are indexed by course/module/requirements_revision. Requirement fingerprints include expression IDs but not text. Changing this text under the old ID and revision would not itself prevent old completion from satisfying the materially changed requirement.',
  future_coordinated_revision_scope: 'The current validator requires course.curriculum_revision to equal catalog.curriculum_revision and each module.requirements_revision to equal its course revision. A revision-only release under the current contract must coordinate catalog, all 20 courses and their 200 module requirements, plus any generated manifests and compiled policies. Changing only the 20 Module02 requirement strings would violate that contract.',
  changed_requirement_namespaces: context.expression_memberships.map(row => ({ course_id: row.course_id, module_id: row.module_id, old_requirements_revision: 'professional-v1', new_requirements_revision: null })),
  proposed_completion_policy: 'Keep old saved requirements, expression flags and completion receipts untouched in their old namespace. Do not copy, alias, merge or infer old expression completion into the new namespace. The repaired expression must be answered correctly and unassisted under the new requirements before its completion can count there.',
  canonical_skill_policy: 'Retain existing collect.gather.v skill history without automatic rename, alias, deletion or a new earned flag. This repair is not evidence of mastery. Any evidence from the former pickup assessment remains semantically questionable; do not certify it as gathering evidence. If such saved records exist, review their provenance separately before claiming valid gathering mastery. Current aggregate skill storage does not identify the exact older expression text.',
  draft_state_limit: 'All 20 affected modules are draft/unready, so no release revision or saved progress is modified by this research packet. Draft status does not prove that no saved experimental or imported history exists and does not waive the new-revision requirement before activation.',
  current_production_revision_changes: [], current_saved_progress_changes: [],
  implementation_and_independent_review_required: true
});
write('assembly-observation.json', {
  schema: 1, status: 'proposal_artifacts_assembled_only', source_file: 'author-proposal.cjs',
  lexeme_before_json_sha256: hash(before), lexeme_after_json_sha256: hash(after),
  expression_before_json_sha256: hash(phraseBefore), expression_after_json_sha256: hash(phraseAfter),
  current_target_and_expression_still_match_preimages: true,
  source_additions_proposed: sources.length, token_count: phraseAfter.tokens.length,
  memberships_preserved: context.target_memberships.length, expression_memberships_preserved: context.expression_memberships.length,
  whole_entry_hold_released: false, independent_acceptance: false,
  production_writes: [], project_serializer_test_native_browser_dispatches: []
});
process.stdout.write(JSON.stringify({status:'proposal_only',lexeme_after_sha256:hash(after),expression_after_sha256:hash(phraseAfter),tokens:phraseAfter.tokens.length,bindings,shared_morph_collect:morphShared.map(row=>row.sense_id)})+'\n');
