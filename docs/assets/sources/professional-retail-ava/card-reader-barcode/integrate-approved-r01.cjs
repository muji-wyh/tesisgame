'use strict';
// One-shot integration of the exact pair approved in tesis-iter-4.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../..');
const {loadProfessionalContent, auditProfessionalContent, schemaErrors} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const {assertWave, PROFILE} = require(path.join(root, 'tools/generate-voices.cjs'));
const helper = 'build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/guarded-transaction.cjs';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const raw = file => sha(fs.readFileSync(path.resolve(root, file)));
const read = file => JSON.parse(fs.readFileSync(path.resolve(root, file), 'utf8'));
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const hash = value => sha(JSON.stringify(value));
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const base = relative(__dirname), retained = 'docs/assets/sources/professional-retail-ava/card-reader-barcode';
const target = 'data/professional/lexemes/retail-pilot.json';
const approvalPath = retained + '/listening-approval-2026-10-16.json';
const provenancePath = 'data/professional/provenance/retail-card-reader-barcode-approved-audio-2026-10-16.json';
const transactionPath = 'build/professional-english/transactions/card-reader-barcode-audio-r01';
assert.equal(raw(helper), '1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6');
const {commitTransaction} = require(path.resolve(root, helper));
assert.deepEqual(process.argv.slice(2), ['--integrate'], 'Explicit one-shot integration invocation required');
const qaPath = base + '/technical-qa-r01.json', requestPath = base + '/listening-request.json';
assert.equal(raw(qaPath), 'ef75d3504e385ef1c4037a30609d35658cfeca5636af363d76edccd27d4c49f1');
const qa = read(qaPath), request = read(requestPath), batch = read(base + '/batch.json');
assert.equal(qa.checks, 51); assert.deepEqual(qa.failures, []);
assert.equal(qa.boundaries.production_integrated, false); assert.equal(qa.boundaries.candidate_audio_modified, false);
assert.equal(request.status, 'presented_to_user_pending_listening_response');
assert.equal(request.production_integrated, false); assert.deepEqual(request.profile, PROFILE); assert.equal(request.postprocessing, false);
assert.equal(batch.status, 'acquired_candidates_only'); assert.equal(batch.listening_review, 'pending');
assert.equal(raw(base + '/verify-technical-audio.cjs'), qa.tools.verification_script_raw_sha256);
for (const [file, expected] of Object.entries(qa.provenance_files_raw_sha256)) assert.equal(raw(file), expected, file);
const expected = {
  'card-reader.payment-device.n': 'acd48c920c631906e6ff0775cf3f373c247687fcb128b41e3ce0f3bdf668ba45',
  'barcode.product-code.n': '01b2666324e5e373b75799535d8a78494a6afe8225c4b82147975d55405c96e5'
};
assert.deepEqual(qa.candidates.map(c => c.sense_id), Object.keys(expected));
for (const candidate of qa.candidates) {
  const output = request.outputs.find(item => item.sense_id === candidate.sense_id);
  assert.equal(candidate.wav.sha256, expected[candidate.sense_id]);
  assert.equal(output.wav_sha256, candidate.wav.sha256); assert.equal(raw(output.presented_path), output.wav_sha256);
  assert.equal(raw(candidate.wav.path), candidate.wav.sha256);
  assert.equal(raw(candidate.source_mp3.path), output.source_mp3_sha256);
  assert.equal(raw(candidate.acquisition_receipt.path), output.acquisition_receipt_raw_sha256);
  const acquired = read(candidate.acquisition_receipt.path);
  assert.equal(acquired.pronunciation_and_listening_review, 'pending'); assert.equal(acquired.production_integrated, false);
  assert.deepEqual(acquired.identity, candidate.identity); assert.deepEqual(candidate.identity.profile, PROFILE);
  assert.deepEqual(candidate.identity.client, {name: 'edge-tts', version: '7.3.1'});
  assert.equal(candidate.identity.provider, 'Microsoft Edge TTS'); assert.equal(candidate.identity.synthesis_text, candidate.text + '.');
  assert.equal(candidate.identity.format, '22050-hz-pcm16-mono-no-effects'); assert.equal(hash(candidate.identity), candidate.key);
  const bytes = fs.readFileSync(path.resolve(root, candidate.wav.path)); assertWave(bytes);
  assert.equal(bytes.length, 82598); assert.equal(candidate.wav.data_bytes, 82554); assert.equal(candidate.wav.sample_frames, 41277);
  assert.equal(sha(bytes.subarray(44)), candidate.wav.pcm_sha256);
  assert.equal(candidate.exact_no_effects_redecode.equals_entire_candidate_pcm, true);
  assert.equal(candidate.exact_no_effects_redecode.pcm_sha256, candidate.wav.pcm_sha256);
  assert.equal(candidate.wav.full_scale_clipped_samples, 0);
}
const preserved = [
  ...qa.historical_voices.files.map(f => ({path: f.path, sha256: f.expected_sha256})),
  ...qa.sequential_collection_audio.files.map(f => ({path: f.path, sha256: f.expected_sha256})),
  ...qa.existing_integrated_professional_audio.map(f => ({path: f.path, sha256: f.actual_sha256}))
];
assert.equal(preserved.length, 1905); assert.equal(new Set(preserved.map(f => f.path)).size, 1905);
const master = qa.sequential_collection_audio.source_master;
const verifyPreserved = () => {
  for (const file of preserved) assert.equal(raw(file.path), file.sha256, file.path);
  assert.equal(raw(master.path), master.expected_sha256);
};
verifyPreserved();
const validationPath = 'build/professional-english/continuation-validation-r27.json';
const validation = read(validationPath), data = loadProfessionalContent(root), audit = auditProfessionalContent({rootDir: root, data});
assert.equal(validation.ok, true); assert.equal(hash(data), validation.registry_after_sha256); assert.deepEqual(audit.errors, []);
assert.deepEqual(validation.changed_measured_inputs, []);
for (const [file, expectedSha] of Object.entries(validation.after_input_sha256)) assert.equal(raw(file), expectedSha, file);
assert.equal(audit.summary.integrated_word_images, 8); assert.equal(audit.summary.integrated_word_audio, 10);
const cashPath = 'data/professional/provenance/retail-cash-register-image-2026-10-16.json', cash = read(cashPath);
assert.deepEqual(data.lexemes.find(e => e.id === 'cash-register.sales-device.n'), cash.patches[0].after);
assert.equal(raw(cash.resource.path), cash.resource.sha256);
const images = data.lexemes.filter(e => e.media.image.status === 'integrated').map(e => ({path: e.media.image.path.slice(6), sha256: e.media.image.sha256}));
for (const file of images) assert.equal(raw(file.path), file.sha256);
const human = {
  schema: 1, recorded_at: new Date().toISOString(), status: 'exact_presented_pair_user_approved',
  authority: 'Direct human reply recovered from tesis-iter-4 by the continuing root agent',
  source_thread_id: '01a14325-e5ce-72a2-8b1a-b746c89e20c6', source_turn_id: '01a144de-9fa7-7b03-808c-2d0aa3cfc73c',
  question_item_id: ['request_user_input_async', 'call_7xvby6MgGR1DNVzcwIkhjACI', 0],
  question_english: request.question_english, response_english: 'Both are acceptable.',
  translation_note: 'The direct human response is recorded as an English translation; original conversation identifiers preserve its provenance.',
  scope: 'Pronunciation, speaking rate and voice quality of the exact presented card reader and barcode WAVs. Future recordings and the game mix are outside this approval.',
  listening_request_raw_sha256: raw(requestPath), technical_qa_raw_sha256: raw(qaPath), profile: PROFILE, postprocessing: false,
  outputs: request.outputs, production_integrated: false
};
const approval = {
  schema: 1, status: 'approved_by_user', approved_on: '2026-10-16',
  evidence: {source: human.authority, source_thread_id: human.source_thread_id, source_turn_id: human.source_turn_id,
    question_item_id: human.question_item_id, question_english: human.question_english, answer_english: human.response_english,
    translation_note: human.translation_note, human_record: retained + '/human-approval-r01.json', human_record_raw_sha256: sha(json(human))},
  profile: {...PROFILE, postprocessing: false},
  technical_qa: {path: retained + '/technical-qa-r01.json', raw_sha256: raw(qaPath)},
  listening_request: {path: retained + '/listening-request.json', raw_sha256: raw(requestPath)},
  scope: human.scope + ' Original acquisition, technical QA and listening-request records retain their pending historical states.',
  outputs: qa.candidates.map(c => ({sense_id: c.sense_id, text: c.text, synthesis_identity_key: c.key,
    submitted_text: c.identity.synthesis_text, presented_path: c.wav.path, retained_wav: retained + '/' + path.basename(c.wav.path), wav_sha256: c.wav.sha256,
    retained_mp3: retained + '/source-mp3/' + path.basename(c.source_mp3.path), source_mp3_sha256: c.source_mp3.sha256,
    acquisition_receipt: retained + '/' + path.basename(c.acquisition_receipt.path), acquisition_receipt_raw_sha256: c.acquisition_receipt.raw_sha256}))
};
const envelope = read(target), next = structuredClone(data), patches = [];
const protect = entry => {const copy = structuredClone(entry); delete copy.media.audio; delete copy.editorial_notes; return copy;};
for (const candidate of qa.candidates) {
  const before = data.lexemes.find(e => e.id === candidate.sense_id), after = structuredClone(before);
  assert.deepEqual(before.media.audio, candidate.original_production_audio_metadata); assert.equal(before.review.language, 'reviewed');
  const resource = {id: 'sha256:' + candidate.wav.sha256, sha256: candidate.wav.sha256, path: 'professional-media/' + candidate.wav.sha256 + '.wav',
    kind: 'audio', format: 'wav', compressed_bytes: 82598, decoded_bytes: 82554, frames: 41277, channels: 1, sample_rate: 22050};
  after.media.audio = {...before.media.audio, status: 'integrated', path: 'res://' + resource.path, sha256: resource.sha256,
    source: 'res://' + approvalPath, creator: 'Microsoft Ava Neural; original project term text',
    license: 'Microsoft Services Agreement applies to synthesized output; client software licensing is separate.', acquisition_status: 'integrated',
    review: {status: 'reviewed', reviewer: 'User (exact card reader and barcode samples approved in tesis-iter-4; see card-reader-barcode listening-approval-2026-10-16.json)', reviewed_at: '2026-10-16'}};
  const note = candidate.text === 'barcode'
    ? {before: 'word audio remains pending.', after: 'the exact Ava word recording has user listening approval and is integrated.'}
    : {before: 'Picture suitability and word-media production remain pending.', after: 'Picture suitability and word-image production remain pending. The exact Ava word recording has user listening approval and is integrated.'};
  assert.equal(before.editorial_notes.split(note.before).length, 2); after.editorial_notes = before.editorial_notes.replace(note.before, note.after);
  assert.deepEqual(protect(before), protect(after)); assert.deepEqual(schemaErrors(after, 'lexeme'), []);
  patches.push({sense_id: before.id, before, after, before_audio: before.media.audio, after_audio: after.media.audio,
    before_sha256: hash(before), protected_fields_sha256: hash(protect(before)), note_change: note, resource});
  assert.equal(data.lexemeOrigins[before.id], 'res://' + target);
  envelope.lexemes[envelope.lexemes.findIndex(e => e.id === before.id)] = after;
  next.lexemes[next.lexemes.findIndex(e => e.id === before.id)] = after;
}
const copies = ['batch.json', 'manifest.json', 'technical-qa-r01.json', 'verify-technical-audio.cjs', 'listening-request.json', 'integrate-approved-r01.cjs',
  ...qa.candidates.flatMap(c => [path.basename(c.wav.path), path.basename(c.acquisition_receipt.path), 'source-mp3/' + path.basename(c.source_mp3.path)])]
  .map(file => ({source: base + '/' + file, path: retained + '/' + file, raw_sha256: raw(base + '/' + file)}));
const provenance = {schema: 1, status: 'exact_user_approved_audio_integrated_pending_native_delivery_verification', integrated_on: '2026-10-16',
  approval: approvalPath, approval_raw_sha256: sha(json(approval)),
  lineage: {validation: validationPath, validation_raw_sha256: raw(validationPath), cash_register_image_provenance: cashPath, cash_register_image_provenance_raw_sha256: raw(cashPath)},
  scope: 'Only two audio descriptors and their obsolete pending-audio clauses change. Images, lexical fields, morphology, review and curriculum gates remain exact.',
  before_registry_sha256: hash(data), after_registry_sha256: hash(next), patches, preserved_audio_files: preserved,
  preserved_collection_master: {path: master.path, sha256: master.expected_sha256}, preserved_images: images, retained_files: copies,
  integration_guards: {helper, helper_raw_sha256: raw(helper), serializer: base + '/integrate-approved-r01.cjs', serializer_raw_sha256: raw(base + '/integrate-approved-r01.cjs'), transaction_path: transactionPath},
  baseline_summary: audit.summary};
const artifacts = copies.map(file => ({path: file.path, after: fs.readFileSync(path.resolve(root, file.source))}));
for (const candidate of qa.candidates) artifacts.push({path: 'professional-media/' + candidate.wav.sha256 + '.wav', after: fs.readFileSync(path.resolve(root, candidate.wav.path))});
artifacts.push({path: base + '/human-approval-r01.json', after: json(human)}, {path: retained + '/human-approval-r01.json', after: json(human)},
  {path: approvalPath, after: json(approval)}, {path: provenancePath, after: json(provenance)}, {path: target, after: json(envelope)});
for (const item of artifacts) assert.equal(item.path === target || !fs.existsSync(path.resolve(root, item.path)), true, 'New immutable output required: ' + item.path);
const changes = artifacts.map(item => ({path: path.resolve(root, item.path), before: item.path === target ? fs.readFileSync(path.resolve(root, target)) : null, after: item.after}));
const transaction = commitTransaction({repositoryRoot: root, transactionDir: path.resolve(root, transactionPath), allowedPaths: changes.map(item => item.path), changes,
  verify() {
    assert.deepEqual(loadProfessionalContent(root), next); const actual = auditProfessionalContent({rootDir: root, data: next}); assert.deepEqual(actual.errors, []);
    assert.equal(actual.summary.integrated_word_audio, 12); assert.equal(actual.summary.integrated_word_images, 8); assert.equal(actual.summary.ready_modules, 0);
    for (const [file, expectedSha] of Object.entries(validation.after_input_sha256)) assert.equal(raw(file), file === target ? sha(json(envelope)) : expectedSha, file);
    verifyPreserved(); for (const file of images) assert.equal(raw(file.path), file.sha256);
    for (const copy of copies) {assert.equal(raw(copy.path), copy.raw_sha256); assert.equal(raw(copy.source), copy.raw_sha256);}
  }});
const receipt = {schema: 1, recorded_at: new Date().toISOString(), integrated: transaction.committed, transaction,
  provenance: provenancePath, provenance_raw_sha256: raw(provenancePath), approval: approvalPath, approval_raw_sha256: raw(approvalPath),
  before_registry_sha256: hash(data), after_registry_sha256: hash(next), preserved_audio_files: preserved.length, preserved_images: images.length,
  summary: auditProfessionalContent({rootDir: root, data: next}).summary, native_delivery_executed: false};
fs.writeFileSync(path.join(__dirname, 'integration-receipt-r01.json'), json(receipt), {flag: 'wx'});
console.log(JSON.stringify(receipt));
