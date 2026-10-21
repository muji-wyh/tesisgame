'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { loadProfessionalContent, auditProfessionalContent } = require('../tools/validate-professional-content.cjs');
const { beforeCardReaderImage, beforeCardReaderImageBytes } = require('./helpers/professional-card-reader-history.cjs');

const root = path.resolve(__dirname, '..');
const bytes = file => fs.readFileSync(path.join(root, file));
const read = file => JSON.parse(bytes(file));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const hash = value => sha(JSON.stringify(value));
const record = read('data/professional/provenance/retail-card-reader-image-2026-10-20.json');
const source = read(record.source_record.path);
const inventory = read(record.retained_evidence.path);
const patch = record.patches[0];
const data = loadProfessionalContent(root);
const entry = data.lexemes.find(item => item.id === patch.id);
const IMAGE_SHA = '67cb3e6f8e0be881b51a7d18ecc28fd1a02fab6b650197a8d60ef9d550b07c59';
const SVG_SHA = '116dca8283535b13345dbd785e846f162bd3701d91816f35603d4aead648a044';
const AUDIO_SHA = 'acd48c920c631906e6ff0775cf3f373c247687fcb128b41e3ce0f3bdf668ba45';
function exactFile(file) {
  assert.equal(bytes(file.path).length, file.bytes, file.path + ': size');
  assert.equal(sha(bytes(file.path)), file.sha256, file.path + ': raw bytes');
}
function protectedEntry(value) {
  const result = structuredClone(value);
  delete result.media.image;
  delete result.editorial_notes;
  return result;
}

test('card-reader installs exactly one image/brief and obsolete note delta in its real origin', () => {
  assert.equal(record.patches.length, 1);
  assert.equal(patch.id, 'card-reader.payment-device.n');
  assert.equal(record.target, 'data/professional/lexemes/retail-pilot.json');
  assert.equal(data.lexemeOrigins[patch.id], patch.origin);
  assert.equal(patch.origin, 'res://' + record.target);
  assert.deepEqual(entry, patch.after);
  assert.equal(hash(patch.before), patch.before_sha256);
  assert.equal(hash(patch.after), patch.after_sha256);
  assert.deepEqual(protectedEntry(patch.after), protectedEntry(patch.before));
  assert.equal(hash(protectedEntry(entry)), patch.protected_fields_sha256);
  assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length, 2);
  assert.equal(entry.editorial_notes, patch.before.editorial_notes.replace(patch.note_change.before, patch.note_change.after));
  assert.equal(patch.note_change.before, 'Picture suitability and word-image production remain pending.');
  assert.deepEqual(patch.allowed_fields, ['media.image', 'editorial_notes: one exact obsolete pending-image clause']);
  const document = read(record.target);
  assert.equal(sha(bytes(record.target)), record.after_file_sha256);
  document.lexemes[document.lexemes.findIndex(item => item.id === patch.id)] = patch.before;
  assert.equal(sha(JSON.stringify(document, null, 2) + '\n'), record.before_file_sha256);
  assert.equal(record.protected_other_entries.length, document.lexemes.length - 1);
  for (const row of record.protected_other_entries) assert.equal(hash(document.lexemes.find(item => item.id === row.id)), row.json_sha256, row.id);
});

test('card-reader source, creator limitation, CC0 and exact static PNG identities are retained', () => {
  exactFile(record.source_record);
  exactFile(record.retained_evidence);
  for (const field of ['original', 'source_page', 'license_page', 'preparation_receipt', 'candidate_record', 'creator_correction', 'source_review', 'native_visual_review', 'native_report']) exactFile(source[field]);
  assert.equal(source.original.sha256, SVG_SHA);
  assert.equal(source.original.bytes, 38428);
  assert.equal(source.source_page.sha256, 'fab25e54beca6ca2224fef0d7bdb39db10a62d1f8d1878dfb3db781ca0cb6fdf');
  assert.equal(source.license_page.sha256, 'abb4d48fc8b85de52b377dd105532c6c549f515d492a8e1712bc99e7316a1f12');
  assert.equal(source.source_url, 'https://freesvg.org/pos-termina-credit-card-payment');
  assert.equal(source.title, 'POS termina credit card payment', 'Retain the source title spelling');
  assert.equal(source.credited_organization, 'publicdomainvectors.org');
  assert.equal(source.individual_artwork_creator, null);
  assert.match(source.creator_limitation, /Vedran is page metadata, not confirmed individual artwork authorship/);
  assert.equal(source.license, 'CC0 1.0 Universal / Public Domain');
  assert.equal(source.license_url, 'https://creativecommons.org/publicdomain/zero/1.0/');
  assert.deepEqual(source.available_animations, []);
  assert.equal(entry.media.image.path, 'res://professional-media/' + IMAGE_SHA + '.png');
  assert.equal(entry.media.image.sha256, IMAGE_SHA);
  assert.equal(entry.media.image.source, 'res://' + record.source_record.path);
  assert.equal(entry.media.image.status, 'integrated');
  assert.equal(entry.media.image.acquisition_status, 'integrated');
  assert.deepEqual(entry.media.image.adaptations, source.adaptations);
  const png = bytes(record.resource.path);
  assert.equal(sha(png), IMAGE_SHA);
  assert.equal(png.length, 77565);
  assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(png.toString('ascii', 12, 16), 'IHDR');
  assert.equal(png.readUInt32BE(16), 512);
  assert.equal(png.readUInt32BE(20), 433);
  assert.equal(record.resource.decoded_bytes, 512 * 433 * 8, 'Production manifest accounts for image and texture storage');
  assert.deepEqual(source.resource, record.resource);
  const prepared = read(source.preparation_receipt.path).images.find(row => row.filename === '206301-cropped-512.png');
  assert.equal(prepared.sha256, IMAGE_SHA);
  assert.equal(prepared.bytes, png.length);
  assert.equal(prepared.metadata.width, 512);
  assert.equal(prepared.metadata.height, 433);
});

test('card-reader evidence preserves failed attempts and every reviewed native capture as raw bytes', () => {
  assert.equal(new Set(inventory.files.map(row => row.path)).size, inventory.files.length);
  for (const file of inventory.files) exactFile(file);
  for (const name of ['141617.svg', '206301.svg']) {
    const failed = inventory.files.find(row => row.path.endsWith('/acquisition-r01/' + name));
    assert.equal(failed.bytes, 0);
    assert.equal(failed.sha256, sha(Buffer.alloc(0)));
  }
  const review = read(source.native_visual_review.path);
  const native = read(source.native_report.path);
  assert.equal(review.status, 'accepted_scoped_ai_image_and_brief_suitability');
  assert.equal(review.exact_candidate_sha256, IMAGE_SHA);
  assert.equal(review.native_report.sha256, source.native_report.sha256);
  assert.equal(native.status, 'technical_comparison_passed_pending_independent_visual_review', 'Do not rewrite the earlier technical result as later visual acceptance');
  assert.equal(native.checks.length, 5451);
  assert.equal(native.failures.length, 0);
  assert.ok(native.checks.every(row => row.ok === true));
  assert.equal(native.input_pins.length, 144);
  assert.equal(native.captures.length, 32);
  assert.equal(review.reviewed_captures.length, 32);
  assert.equal(record.native_review.phase, 'preintegration_candidate_comparison');
  const sizes = ['320x568', '390x844', '844x390', '1280x800'];
  for (const size of sizes) {
    const rows = review.reviewed_captures.filter(row => row.viewport.join('x') === size);
    assert.equal(rows.length, 8);
    assert.equal(rows.filter(row => row.mode === 'match').length, 4);
    assert.equal(rows.filter(row => row.mode === 'memory').length, 4);
  }
  for (const capture of review.reviewed_captures) {
    const retained = inventory.files.filter(row => row.source === capture.path);
    assert.equal(retained.length, 1);
    assert.equal(retained[0].sha256, capture.sha256);
    assert.equal(retained[0].bytes, capture.bytes);
    assert.equal(native.captures.filter(row => row.file === path.basename(capture.path) && row.sha256 === capture.sha256).length, 1);
  }
  for (const attempt of ['captures-r01', 'captures-r02', 'captures-r03']) {
    const file = inventory.files.find(row => row.path.endsWith('/' + attempt + '/report.json'));
    assert.ok(file);
    assert.ok(read(file.path).failures.length > 0, 'Failed evidence remains failed: ' + attempt);
  }
  assert.match(review.observations.join(' '), /badge touches or covers a small part of the secondary receipt tip/);
  assert.match(source.retained_failure_limits.join(' '), /without numeric tolerance or alpha normalization/);
});

test('card-reader revised brief preserves its sense, approved audio and unfinished domain gates', () => {
  const candidate = read(source.candidate_record.path);
  const review = read(source.native_visual_review.path);
  assert.equal(entry.media.image.brief, candidate.proposed_picture_brief);
  assert.equal(entry.media.image.brief, review.brief_decision.brief);
  assert.equal(source.brief.before, patch.before.media.image.brief);
  assert.equal(source.brief.after, entry.media.image.brief);
  assert.match(source.brief.after, /does not claim a particular card-reading method or a completed payment/);
  assert.equal(entry.text, 'card reader');
  assert.equal(entry.definition, 'A device that reads payment information from a bank card.');
  assert.equal(entry.example, 'The customer held a card near the card reader.');
  assert.deepEqual(entry.media.audio, patch.before.media.audio);
  assert.deepEqual(entry.media.audio, record.approved_audio.descriptor);
  assert.equal(entry.media.audio.sha256, AUDIO_SHA);
  exactFile(record.approved_audio.file);
  assert.equal(record.approved_audio.file.sha256, AUDIO_SHA);
  assert.equal(record.approved_audio.change, 'none');
  assert.equal(entry.media.audio.voice, 'ava-sweet');
  assert.deepEqual(entry.media.audio.voice_settings, { voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%', postprocessing: false });
  assert.deepEqual(entry.morphology, patch.before.morphology);
  assert.deepEqual(entry.review, patch.before.review);
  assert.equal(entry.review.status, 'pending');
  assert.equal(entry.review.domain, 'pending');
  assert.equal(entry.media.image.picture_suitable, true);
  assert.equal(entry.media.image.review.status, 'reviewed');
  assert.match(entry.media.image.review.reviewer, /independent AI/);
  assert.match(entry.media.image.review.reviewer, /not human or subject-matter approval/);
  assert.deepEqual(record.scope, source.review_scope);
  for (const key of ['human_recognition', 'human_visual_acceptance', 'full_game_exercise_acceptance', 'physical_device_acceptance', 'full_animation_review', 'audio_or_listening_approval_changed', 'module_or_release_ready']) assert.equal(source.review_scope[key], false, key);
  assert.equal(source.review_scope.all_32_native_boards_inspected, true);
  assert.equal(record.integration_guards.historical_records_replayed, false);
  for (const row of record.protected_curriculum) assert.equal(hash(data.courses.find(course => course.id === row.id)), row.json_sha256, row.id);
  assert.ok(data.courses.every(course => course.modules.every(module => module.status === 'draft')));
  const audit = auditProfessionalContent({ rootDir: root, data });
  assert.equal(audit.ok, true, JSON.stringify(audit.errors));
  assert.equal(audit.summary.ready_modules, 0);
  assert.equal(audit.summary.release_ready, false);
});

test('card-reader historical reversal accepts only the two complete exact states and clones its result', () => {
  for (const state of [patch.before, patch.after]) {
    const reversed = beforeCardReaderImage(state);
    assert.deepEqual(reversed, patch.before);
    assert.notEqual(reversed, patch.before);
    assert.notEqual(reversed.media, patch.before.media);
    reversed.media.image.status = 'changed clone';
    assert.equal(patch.before.media.image.status, 'pending');
  }
  const unrelated = data.lexemes.find(item => item.id === 'barcode.product-code.n');
  assert.equal(beforeCardReaderImage(unrelated), unrelated);
  const drift = [
    value => { value.definition += ' Changed.'; },
    value => { value.example += ' Changed.'; },
    value => { value.text = 'payment terminal'; },
    value => { value.media.audio.sha256 = '0'.repeat(64); },
    value => { value.media.audio.voice = 'unexpected'; },
    value => { value.media.image.sha256 = '0'.repeat(64); },
    value => { value.media.image.brief += ' Changed.'; },
    value => { value.media.image.license = 'unexpected'; },
    value => { value.morphology.parts[0].canonical_id = 'unexpected'; },
    value => { value.review.domain = 'reviewed'; },
    value => { value.review.language = 'pending'; },
    value => { value.practice_modes.pop(); },
    value => { value.editorial_notes += ' Changed.'; },
    value => { value.accepted_forms.push('payment terminal'); },
    value => { value.extra = true; }
  ];
  for (const state of [patch.before, patch.after]) for (const mutate of drift) {
    const changed = structuredClone(state);
    mutate(changed);
    assert.throws(() => beforeCardReaderImage(changed), assert.AssertionError);
  }
  const mixed = structuredClone(patch.after);
  mixed.editorial_notes = patch.before.editorial_notes;
  assert.throws(() => beforeCardReaderImage(mixed), assert.AssertionError);
});

test('card-reader raw-file reversal preserves exact historical bytes and rejects any other file drift', () => {
  const current = bytes(record.target);
  const historical = beforeCardReaderImageBytes(current);
  assert.equal(sha(historical), record.before_file_sha256);
  assert.equal(sha(current), record.after_file_sha256);
  assert.deepEqual(beforeCardReaderImageBytes(historical), historical);
  assert.notEqual(beforeCardReaderImageBytes(historical), historical);
  assert.deepEqual(JSON.parse(historical).lexemes.find(row => row.id === patch.id), patch.before);
  for (const state of [current, historical]) {
    const changed = Buffer.from(state);
    changed[changed.length - 2] ^= 1;
    assert.throws(() => beforeCardReaderImageBytes(changed), assert.AssertionError);
    assert.throws(() => beforeCardReaderImageBytes(Buffer.from(state.toString().replace('The cereal is in the next aisle.', 'Unrelated lexical change.'))), assert.AssertionError);
  }
});
