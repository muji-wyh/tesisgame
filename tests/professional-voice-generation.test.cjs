'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {prepareBatch, acquireBatch} = require('../tools/generate-professional-voices.cjs');
const {PROFILE, EDGE_TTS_VERSION} = require('../tools/generate-voices.cjs');
const root = path.resolve(__dirname, '..');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const production = ['data/professional/lexemes/retail-pilot.json', 'docs/assets/ava-voice.json',
  'docs/assets/sources/professional-retail-ava/aisle.wav'];
function fixture(t, senseIds = ['shopping-cart.store-trolley.n', 'shopping-basket.store-container.n']) {
  const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'professional-voice-test-'));
  t.after(() => {
    const resolved = path.resolve(outputDirectory);
    assert.ok(resolved.startsWith(path.resolve(os.tmpdir()) + path.sep));
    assert.ok(path.basename(resolved).startsWith('professional-voice-test-'));
    fs.rmSync(resolved, {recursive: true, force: true});
  });
  return {root, courseId: 'retail', moduleId: 'module03', outputDirectory, senseIds};
}

test('Professional acquisition prepares exact reviewed sense text and never changes production', t => {
  const before = production.map(file => hash(path.join(root, file)));
  const options = fixture(t), result = prepareBatch(options);
  const manifest = JSON.parse(fs.readFileSync(result.manifest_path));
  assert.deepEqual(manifest.profile, PROFILE);
  assert.equal(manifest.edgeTtsVersion, EDGE_TTS_VERSION);
  assert.deepEqual(manifest.requests.map(request => request.text), ['shopping cart.', 'shopping basket.']);
  assert.ok(manifest.requests.every(request => /^[a-z]+(?:-[a-z]+)*$/.test(request.id)));
  assert.equal(result.missing_recordings, 2);
  assert.equal(result.listening_review, 'pending');
  assert.deepEqual(production.map(file => hash(path.join(root, file))), before);
});

test('Candidate batches reject unknown, foreign, duplicated and unreviewed senses', t => {
  const options = fixture(t);
  assert.throws(() => prepareBatch({...options, courseId: 'missing'}), /existing/);
  assert.throws(() => prepareBatch({...options, senseIds: ['absent.sense.n']}), /belong/);
  assert.throws(() => prepareBatch({...options, senseIds: [options.senseIds[0], options.senseIds[0]]}), /unique/);
  assert.throws(() => prepareBatch({...options, moduleId: 'module10', senseIds: []}), /Review the selected/);
  assert.throws(() => prepareBatch({...options, outputDirectory: 'relative'}), /absolute/);
});

test('Missing-only acquisition reuses hash-verified candidates without synthesis or approval', t => {
  const options = fixture(t, ['shopping-cart.store-trolley.n']);
  let requests = 0, conversions = 0;
  // Existing real audio is a transport test fixture, not a recording of the
  // requested shopping-cart term. No listening or linguistic claim is tested.
  const dependencies = {
    run: (_python, args) => {
      requests += 1;
      const manifest = JSON.parse(fs.readFileSync(args[2]));
      for (const request of manifest.requests) fs.copyFileSync(path.join(root, 'docs/assets/sources/professional-retail-ava/aisle.mp3'), request.output);
      return {status: 0};
    },
    convert: (_bytes, destination) => {
      conversions += 1;
      fs.copyFileSync(path.join(root, 'docs/assets/sources/professional-retail-ava/aisle.wav'), destination);
    }
  };
  const first = acquireBatch(options, dependencies);
  assert.equal(first.missing_recordings, 0);
  const receipt = JSON.parse(fs.readFileSync(first.terms[0].receipt));
  assert.equal(receipt.pronunciation_and_listening_review, 'pending');
  assert.equal(receipt.production_integrated, false);
  acquireBatch(options, dependencies);
  assert.equal(requests, 1);
  assert.equal(conversions, 1);
  const bytes = fs.readFileSync(first.terms[0].wave);
  bytes[bytes.length - 2] ^= 1;
  fs.writeFileSync(first.terms[0].wave, bytes);
  assert.throws(() => prepareBatch(options), /provenance or bytes changed/);
});

test('Acquisition failure leaves approved production bytes and candidate review gates intact', t => {
  const options = fixture(t, ['shopping-cart.store-trolley.n']);
  const before = production.map(file => hash(path.join(root, file)));
  assert.throws(() => acquireBatch(options, {run: () => ({status: 1})}), /acquisition failed/);
  assert.deepEqual(production.map(file => hash(path.join(root, file))), before);
  assert.equal(JSON.parse(fs.readFileSync(path.join(options.outputDirectory, 'batch.json'))).listening_review, 'pending');
});
