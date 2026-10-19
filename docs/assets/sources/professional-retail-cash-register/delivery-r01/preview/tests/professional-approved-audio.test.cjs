'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {assertWave, PROFILE} = require('../tools/generate-voices.cjs');
const {loadProfessionalContent, schemaErrors} = require('../tools/validate-professional-content.cjs');
const root = path.resolve(__dirname, '..');
const read = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const approval = read('docs/assets/sources/professional-retail-ava/listening-approval-2026-10-16.json');
const acquisition = read(approval.historical_acquisition);
const cashRegisterImageRecord=read('data/professional/provenance/retail-cash-register-image-2026-10-16.json');
function beforeCashRegisterImage(entry) {
  const patch = cashRegisterImageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later cash-register image and obsolete pending-media note delta');
  return structuredClone(patch.before);
}

test('the recovered human approval binds the exact two acquired sample files', () => {
  assert.equal(approval.status, 'approved_by_user');
  assert.equal(approval.evidence.user_message_id, '01a14251-9251-79c2-b726-5bf3e383d0bf');
  assert.deepEqual(approval.evidence.question_item_id, ['request_user_input_async', 'call_zXnfvgSMgGM4EROYazqGHQcT', 0]);
  assert.deepEqual(approval.profile, {...PROFILE, postprocessing: false});
  assert.equal(approval.outputs.length, 2);
  assert.equal(acquisition.pronunciation_and_listening_approval, false, 'The original pre-approval acquisition history remains unchanged');
  for (const output of approval.outputs) {
    const original = acquisition.outputs.find(item => item.id === output.id);
    assert.equal(output.submitted_text, original.submitted_text);
    const wav = fs.readFileSync(path.join(root, output.source_path));
    assert.equal(sha(wav), output.wav_sha256);
    assert.equal(sha(fs.readFileSync(path.join(root, original.source_mp3.path))), output.source_mp3_sha256);
    assert.equal(original.wav.sha256, output.wav_sha256);
    assertWave(wav);
  }
});

test('accepted professional audio descriptors use unchanged immutable production bytes', () => {
  const data = loadProfessionalContent(root);
  for (const output of approval.outputs) {
    const entry = data.lexemes.find(item => item.id === output.sense_id);
    assert.deepEqual(schemaErrors(entry, 'lexeme'), []);
    const audio = entry.media.audio;
    assert.equal(audio.status, 'integrated');
    assert.equal(audio.acquisition_status, 'integrated');
    assert.equal(audio.review.status, 'reviewed');
    assert.match(audio.review.reviewer, /User/);
    assert.equal(audio.sha256, output.wav_sha256);
    assert.equal(audio.path, `res://professional-media/${output.wav_sha256}.wav`);
    assert.deepEqual(audio.voice_settings, {...PROFILE, postprocessing: false});
    assert.equal(sha(fs.readFileSync(path.join(root, audio.path.slice(6)))), output.wav_sha256);
    assert.equal(entry.review.status, 'pending');
    assert.equal(beforeCashRegisterImage(entry).media.image.status, 'pending', 'Exact later image patch restores the historical audio-stage image assertion');
    const laterMorphology = read('data/professional/provenance/retail-module03-morphology-first10-2026-10-16.json');
    assert.equal(laterMorphology.independent_approval.accepted, true);
    const patch = laterMorphology.patches.find(item => item.id === entry.id);
    assert.deepEqual(entry.morphology, patch.after.morphology, 'Morphology has its own later independent acceptance');
    assert.deepEqual(audio, patch.before.media.audio, 'Later morphology acceptance preserves the approved audio');
  }
  const retail = data.courses.find(course => course.id === 'retail');
  assert.ok(retail.modules.every(module => module.status === 'draft'), 'Audio approval alone cannot open a module');
});
