'use strict';
// Pure guarded transforms. Tests are installed by the separate transaction.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const settings = require('./delivery-settings.cjs');
const testPaths = ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs'];
const inputHashes = settings.test_input_raw_sha256;
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
function once(text, needle, replacement) {
  assert.equal(text.split(needle).length, 2, 'Exact unique anchor: ' + needle);
  return text.replace(needle, replacement);
}
const helper = String.raw`function beforeFoundationFifthLanguage(entry) {
  const patch = foundationFifthLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later fifth-ten language, reference and note delta');
  return structuredClone(patch.before);
}`;
const mainTests = String.raw`

test('Foundation fifth ten install ten exact language candidates and twenty scoped sources', () => {
  const r = foundationFifthLanguageRecord;
  const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(r.patches.length, 10); assert.equal(r.sources.length, 20); assert.equal(r.held.length, 2);
  assert.equal(r.proposal.root_acceptance_raw_sha256, '__ACCEPTANCE_SHA__');
  assert.equal(r.proposal.author_ledger_json_sha256, 'bbc8b3feab69e52fec9559d34fcc13a9424e4a2182356ef37fd3f0785c7124c8');
  assert.equal(r.proposal.accepted_memberships, 200); assert.equal(r.proposal.preserved_selected_memberships, 200);
  const protect = entry => {
    const value = structuredClone(entry);
    for (const key of ['definition', 'example', 'difficulty', 'references', 'editorial_notes']) delete value[key];
    for (const key of ['language', 'status', 'reviewer', 'reviewed_at']) delete value.review[key];
    return value;
  };
  let memberships = 0, references = 0;
  for (const patch of r.patches) {
    const entry = source.lexemes.find(e => e.id === patch.id);
    const accepted = r.root_acceptance.accepted_candidates.find(e => e.id === patch.id);
    const author = r.author_ledger.proposals.find(e => e.id === patch.id);
    assert.deepEqual(entry, patch.after); assert.equal(hash(patch.before), patch.before_sha256); assert.equal(hash(entry), patch.after_sha256);
    assert.equal(hash(patch.accepted_author_candidate), accepted.candidate_json_sha256);
    assert.deepEqual(patch.accepted_author_candidate, author.candidate_entry);
    assert.equal(patch.reviewed_candidate_entry_json_sha256, accepted.candidate_json_sha256);
    for (const field of Object.keys(author.candidate_entry).filter(f => !['review', 'references', 'editorial_notes'].includes(f))) assert.deepEqual(entry[field], author.candidate_entry[field]);
    assert.deepEqual(protect(entry), protect(patch.before)); assert.equal(hash(protect(entry)), patch.protected_fields_sha256);
    assert.deepEqual(entry.review, {...patch.before.review, language:'reviewed', status:patch.before.review.domain === 'not_required' ? 'reviewed' : 'pending', reviewer:r.reviewer, reviewed_at:'2026-10-16'});
    assert.deepEqual(entry.references.slice(0, patch.before.references.length), patch.before.references);
    const additions = entry.references.slice(patch.before.references.length); references += additions.length;
    assert.deepEqual(additions.map(ref => ref.source_id), patch.source_record_ids);
    for (const ref of additions) { assert.equal(ref.status, 'verified'); assert.match(ref.scope, /No human, subject-matter, morphology, media, domain, expression or release approval is claimed/); }
    assert.equal(patch.editorial_note_transition.before_notes, patch.before.editorial_notes);
    assert.equal(patch.editorial_note_transition.author_candidate_notes, author.candidate_entry.editorial_notes);
    assert.equal(patch.editorial_note_transition.after_notes, entry.editorial_notes);
    assert.doesNotMatch(entry.editorial_notes, /Meaning, difficulty, imagery, and morphological classification remain editorial drafts|independent acceptance remains pending/);
    const current = source.courses.flatMap(c => c.modules.filter(m => m.lexeme_ids.includes(patch.id)).map(m => ({course_id:c.id, module_id:m.id})));
    assert.deepEqual(current, patch.memberships); memberships += current.length;
    assert.equal(entry.morphology.review.status, 'pending'); assert.equal(entry.media.image.status, 'pending'); assert.equal(entry.media.audio.status, 'pending');
  }
  assert.equal(memberships, 200); assert.equal(references, 20);
  for (const expected of r.sources) { assert.deepEqual(source.sources.find(s => s.id === expected.id), expected); assert.equal(expected.status, 'consulted'); assert.equal(expected.assets_acquired, false); assert.equal(expected.asset_license, null); }
  for (const item of r.retained_files) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir, item.path))).digest('hex'), item.raw_sha256, item.path);
});

test('Foundation fifth ten keep source levels separate from editorial difficulty and other senses', () => {
  const r = foundationFifthLanguageRecord, byText = text => r.patches.find(p => p.after.text === text);
  const consult = id => r.historical_source_consultations.consultations.find(s => s.id === 'foundation01-language-fifth10-' + id);
  const expected = {
    feedback: ['B2', {oxford:'B2', collins:'B2'}],
    permission: ['A2', {oxford:'A2', collins:'B1'}],
    responsibility: ['B2', {oxford:null, collins:'B2'}],
    task: ['A2', {oxford:'A2', collins:'B2'}],
    role: ['B2', {oxford:null, collins:'B2'}],
    priority: ['B2', {oxford:null, collins:null}],
    location: ['B1', {oxford:'B1', collins:'B1+'}],
    address: ['A2', {oxford:null, collins:'A1'}],
    signature: ['B1', {oxford:null, collins:'B1'}],
    'time zone': ['B2', {oxford:'B2', collins:null}]
  };
  for (const [text, [difficulty, labels]] of Object.entries(expected)) {
    const patch = byText(text); assert.equal(patch.after.difficulty, difficulty);
    assert.deepEqual(patch.difficulty.observed_selected_source_labels, labels); assert.equal(patch.difficulty.dictionary_level_certification, false);
    for (const [source, level] of Object.entries(labels)) assert.equal(consult(source + '-' + text.replaceAll(' ', '-')).observed_selected_sense_level, level);
  }
  assert.equal(byText('feedback').after.definition, "Comments or information about someone's work or idea, often used to help them improve.");
  assert.equal(byText('role').after.definition, 'The function or part a person or group has in a team, organization, or activity.');
  assert.equal(byText('location').after.definition, 'The place where someone or something is, or where an activity happens.');
  assert.equal(byText('address').after.definition, 'Details that identify where a person or organization is located or can receive mail.');
  assert.equal(byText('responsibility').after.example, 'Ordering supplies is one of my responsibilities.');
  assert.deepEqual(r.patches.filter(p => p.changed_fields.includes('definition')).map(p => p.after.text), ['feedback', 'role', 'location', 'address']);
  assert.deepEqual(r.patches.filter(p => p.changed_fields.includes('example')).map(p => p.after.text), ['responsibility']);
  assert.deepEqual(r.patches.filter(p => p.changed_fields.includes('difficulty')).map(p => p.after.text), ['feedback', 'responsibility', 'role', 'priority', 'location', 'signature', 'time zone']);
  for (const text of ['role', 'priority', 'address']) {
    const others = r.historical_source_consultations.consultations.filter(s => s.term === text || s.id.endsWith('-' + text)).map(s => s.other_sense_labels_not_applied);
    assert.ok(others.some(value => Object.keys(value).length > 0), text + ': distinct other-sense labels retained');
  }
  assert.equal(r.historical_source_consultations.consultations.length, 20); assert.deepEqual(r.historical_source_consultations.failed_accesses, []);
});

test('Foundation fifth ten preserve prior entry holds and twelve expression ambiguities', () => {
  const r = foundationFifthLanguageRecord, context = r.protected_context;
  const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.deepEqual(r.held.map(h => h.id), ['supervisor.work-overseer.n', 'attendance.presence-record.n']);
  for (const held of r.held) {
    assert.deepEqual(source.lexemes.find(e => e.id === held.id), held.value); assert.equal(hash(held.value), held.json_sha256);
    assert.equal(held.value.difficulty, 'A2'); assert.equal(held.value.review.language, 'pending'); assert.equal(held.value.review.status, 'pending');
    assert.equal(held.production_reference_or_note_additions, 0); assert.equal(r.patches.some(p => p.id === held.id), false);
  }
  assert.deepEqual(r.proposal.excluded_source_ids, ['foundation01-language-third10-oxford-attendance', 'foundation01-language-third10-collins-attendance']);
  for (const id of r.proposal.excluded_source_ids) assert.equal(source.sources.some(s => s.id === id), false);
  assert.equal(context.expressions.length, 123); assert.equal(context.modules.length, 97); assert.equal(context.sources.length, 145); assert.equal(context.held_entries.length, 2);
  for (const row of [...context.lexemes, ...context.held_entries]) { assert.deepEqual(source.lexemes.find(e => e.id === row.entry.id), row.entry); assert.equal(hash(row.entry), row.json_sha256); }
  for (const row of context.expressions) { assert.deepEqual(source.expressions.find(e => e.id === row.entry.id), row.entry); assert.equal(hash(row.entry), row.json_sha256); }
  for (const row of context.modules) assert.deepEqual(source.courses.find(c => c.id === row.course_id).modules.find(m => m.id === row.module_id), row.module);
  for (const row of context.sources) { assert.deepEqual(source.sources.find(s => s.id === row.source.id), row.source); assert.equal(hash(row.source), row.json_sha256); }
  let memberships = 0;
  for (const row of context.selected_memberships) { const current = source.courses.flatMap(c => c.modules.filter(m => m.lexeme_ids.includes(row.id)).map(m => ({course_id:c.id,module_id:m.id}))); assert.deepEqual(current, row.memberships); memberships += current.length; }
  assert.equal(memberships, 200);
  for (const [file, sha] of Object.entries({...context.growth_raw_sha256, ...context.prior_artifacts_raw_sha256})) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir, file))).digest('hex'), sha, file);
  const review = context.context_review;
  assert.equal(review.uses.length, 111); assert.equal(review.containing_module_memberships, 206); assert.equal(review.selected_focus_expressions, 5);
  assert.equal(review.other_local_expressions.length, 5); assert.equal(review.related_entry_boundaries.length, 65);
  assert.equal(review.all_selected_containing_module_expressions.modules.length, 20);
  assert.equal(review.all_selected_containing_module_expressions.unique_expression_ids.length, 10); assert.equal(review.all_selected_containing_module_expressions.all_expressions_captured, true);
  const holds = review.uses.filter(row => row.matches.some(m => m.authored_classification_code.startsWith('hold_'))).map(row => row.id).sort();
  assert.deepEqual(holds, ['expr.customer_support.module03.08', 'expr.foundation.module01.06', 'expr.office_admin.module09.01']); assert.deepEqual(r.proposal.expression_hold_ids, holds);
  const prior = ['expr.customer_support.module07.08', 'expr.foundation.module01.03', 'expr.foundation.module01.08', 'expr.hospitality_tourism.module05.04', 'expr.hospitality_tourism.module09.02', 'expr.hospitality_tourism.module09.08', 'expr.office_admin.module05.07', 'expr.office_admin.module06.03', 'expr.transport_delivery.module09.06'];
  assert.deepEqual(review.prior_expression_hold_ids, prior); assert.deepEqual(r.proposal.prior_expression_hold_ids, prior); assert.deepEqual(review.prior_expression_holds_preserved.map(row => row.id), prior);
  for (const row of review.uses) { assert.deepEqual(row.new_scored_bindings, []); assert.equal(row.before_expression_json_sha256, row.after_expression_json_sha256); }
  for (const row of review.prior_expression_holds_preserved) { assert.deepEqual(source.expressions.find(e => e.id === row.id), row.entry); assert.equal(hash(row.entry), row.json_sha256); }
  const release = auditProfessionalContent({data:source, release:true}); assert.equal(release.summary.ready_modules, 0); assert.equal(release.summary.release_ready, false);
});

test('Fifth-ten reversal rejects unrelated drift and requires the committed validated baseline', () => {
  const r = foundationFifthLanguageRecord;
  for (const patch of r.patches) {
    for (const reverse of [beforeFoundationFifthLanguage, beforeFoundationFourthLanguage, beforeFoundationThirdLanguage, beforeFoundationSecondLanguage]) assert.deepEqual(reverse(patch.after), patch.before);
    const mutations = [e => {e.definition += ' Unexpected.';}, e => {e.accepted_forms.push('unexpected');}, e => {e.review.reviewer = 'unexpected';}, e => {e.references[0].scope += ' Unexpected.';}, e => {e.morphology.review.status = 'reviewed';}, e => {e.media.audio.voice = 'unexpected';}, e => {e.editorial_notes += ' Unexpected.';}, e => {e.regions.push('US');}];
    for (const mutate of mutations) { const changed = structuredClone(patch.after); mutate(changed); assert.throws(() => beforeFoundationFifthLanguage(changed)); }
  }
  for (const held of r.held) assert.deepEqual(beforeFoundationFifthLanguage(held.value), held.value);
  assert.equal(r.lineage.validation.path, '__VALIDATION_PATH__'); assert.equal(r.lineage.validation.raw_sha256, '__VALIDATION_SHA__');
  const raw = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir, file))).digest('hex');
  assert.equal(raw(r.lineage.validation.path), r.lineage.validation.raw_sha256); assert.equal(JSON.parse(fs.readFileSync(path.join(rootDir, r.lineage.validation.path))).ok, true);
  const transaction = r.integration_guards.transaction_path;
  const states = fs.readdirSync(path.join(rootDir, transaction, 'states')).filter(f => /^\d{6}-[a-z-]+\.json$/.test(f)).sort();
  const committed = JSON.parse(fs.readFileSync(path.join(rootDir, transaction, 'states', states.at(-1))));
  assert.equal(committed.status, 'committed'); assert.equal(committed.prepared_sha256, raw(transaction + '/prepared.json'));
});
`;
const morphologyTest = String.raw`

test('Fifth-ten Foundation language acceptance preserves all ten pending morphology graphs', () => {
  for (const patch of foundationFifthLanguageRecord.patches) {
    const entry = data.lexemes.find(e => e.id === patch.id);
    assert.deepEqual(entry, patch.after); assert.deepEqual(entry.morphology, patch.before.morphology); assert.equal(entry.morphology.review.status, 'pending');
    assert.deepEqual(entry.references.slice(0, patch.before.references.length), patch.before.references);
    assert.deepEqual(beforeFoundationFifthLanguage(entry), patch.before); assert.deepEqual(beforeFoundationLanguage(entry), patch.before);
    for (const mutate of [e => {e.morphology.review.status = 'reviewed';}, e => {e.references[0].scope += ' Unexpected.';}, e => {e.accepted_forms.push('unexpected');}]) {
      const changed = structuredClone(entry); mutate(changed); assert.throws(() => beforeFoundationFifthLanguage(changed));
    }
  }
});
`;
function transformTests(inputs) {
  assert.deepEqual(Object.keys(inputs).sort(), [...testPaths].sort());
  const output = {};
  for (const file of testPaths) {
    let text = inputs[file]; assert.equal(hash(text), inputHashes[file], 'Exact validated shared-test preimage ' + file);
    const eol = text.includes('\r\n') ? '\r\n' : '\n', format = value => value.replace(/\r?\n/g, eol);
    const variable = file === testPaths[0] ? 'rootDir' : 'root';
    const existing = "const foundationFourthLanguageRecord = JSON.parse(fs.readFileSync(path.join(" + variable + ", 'data/professional/provenance/foundation-module01-language-fourth10-2026-10-16.json'), 'utf8'));";
    const added = "const foundationFifthLanguageRecord = JSON.parse(fs.readFileSync(path.join(" + variable + ", 'data/professional/provenance/foundation-module01-language-fifth10-2026-10-16.json'), 'utf8'));";
    text = once(text, existing, existing + eol + added + eol + format(helper));
    text = once(text, 'function beforeFoundationFourthLanguage(entry) {', 'function beforeFoundationFourthLanguage(entry) {' + eol + '  entry = beforeFoundationFifthLanguage(entry);');
    if (file === testPaths[0]) {
      const correction = 'const entry = beforeRetail04Third10(source.lexemes.find(item => item.id === patch.id)), decision = record.independent_acceptance.accepted_pairs.find(item => item.pair[0] === patch.id);';
      assert.equal(text.split(correction).length, 2, 'Preserve R24 picture exclusion correction');
      text = once(text, '...foundationThirdLanguageRecord.patches, ...foundationFourthLanguageRecord.patches', '...foundationThirdLanguageRecord.patches, ...foundationFourthLanguageRecord.patches, ...foundationFifthLanguageRecord.patches');
      text = once(text, 'assert.equal(result.summary.reviewed_lexemes, 100);', 'assert.equal(result.summary.reviewed_lexemes, 110);');
      text = once(text, 'for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(source.lexemes.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}', 'for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(beforeFoundationFifthLanguage(source.lexemes.find(e=>e.id===row.entry.id)),row.entry);assert.equal(hash(row.entry),row.json_sha256);}');
      text += format(mainTests.replace('__ACCEPTANCE_SHA__', settings.acceptance_raw_sha256).replace('__VALIDATION_PATH__', settings.validation_path).replace('__VALIDATION_SHA__', settings.validation_raw_sha256));
      assert.equal(text.split(correction).length, 2, 'R24 correction remains exact');
    } else text += format(morphologyTest);
    output[file] = text;
  }
  return output;
}
module.exports = {testPaths, inputHashes, transformTests};
