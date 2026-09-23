'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { VoiceProfileStore, SPEAKER_MODEL_VERSION } = require('../web/voice-profiles.js');

function fixture() {
  const values = new Map();
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
  const store = new VoiceProfileStore({ storage, env: { crypto: { randomUUID: () => 'generated-id' } } });
  return { store, storage, values };
}
const profile = (id = 'p1') => ({ id, name: 'Alex', emoji: '🐱', modelVersion: SPEAKER_MODEL_VERSION,
  embedding: [2, ...new Array(255).fill(0)] });

test('voice profiles persist only validated features and metadata, and explicit Save creates a stable ID', () => {
  const { store, values } = fixture();
  assert.deepEqual(store.list(), []);
  assert.equal(values.size, 0, 'Reading an empty library does not write anything');
  const value = profile(); delete value.id;
  const saved = store.save({ ...value, samples: [0.1], recording: 'raw audio', extra: 'discard' });
  assert.equal(saved.id, 'generated-id');
  assert.equal(saved.embedding[0], 1);
  assert.equal(Math.hypot(...saved.embedding), 1);
  assert.deepEqual(Object.keys(saved), ['id', 'name', 'emoji', 'embedding', 'modelVersion']);
  const snapshot = store.snapshot();
  assert.equal(snapshot.revision, 1);
  assert.equal(snapshot.schemaVersion, 1);
  assert.equal(snapshot.modelVersion, SPEAKER_MODEL_VERSION);
  assert.doesNotMatch([...values.values()][0], /recording|samples|raw audio|extra/);
  saved.embedding[0] = 0;
  snapshot.profiles[0].name = 'Mutated';
  assert.equal(store.list()[0].name, 'Alex');
  assert.equal(store.list()[0].embedding[0], 1);
});

test('ten profiles allow metadata changes and rerecording but reject an eleventh without changing storage', () => {
  const { store, values } = fixture();
  for (let i = 0; i < 10; i++) store.save(profile(`p${i}`));
  const before = [...values.values()][0];
  assert.throws(() => store.save(profile('p11')), { code: 'full' });
  assert.equal([...values.values()][0], before);
  store.update('p3', { name: 'New name', emoji: '🦊', embedding: [] });
  assert.equal(store.list()[3].name, 'New name');
  assert.equal(store.list()[3].embedding[0], 1, 'Metadata edits cannot silently replace voice evidence');
  const updated = store.save({ ...profile('p3'), name: 'Rerecorded', embedding: [0, 1, ...new Array(254).fill(0)] });
  assert.equal(updated.embedding[1], 1);
  assert.equal(store.list().length, 10);
  assert.equal(store.remove('p3'), true);
  assert.equal(store.remove('p3'), false);
  assert.equal(store.snapshot().revision, 13);
  store.save(profile('replacement'));
  assert.equal(store.list().length, 10);
});

test('blocked or failed storage never returns successful profile changes', () => {
  const { store, storage } = fixture();
  store.save(profile());
  const before = store.snapshot();
  storage.setItem = () => { throw new Error('Quota exceeded'); };
  for (const mutate of [() => store.save(profile('p2')), () => store.update('p1', { name: 'Not saved' }),
    () => store.addVoice('p1', { ...profile(), name: 'Not saved' }), () => store.remove('p1')]) {
    assert.throws(mutate, { code: 'storage_unavailable' });
    assert.deepEqual(store.snapshot(), before);
  }
  storage.setItem = () => {};
  assert.throws(() => store.update('p1', { name: 'Silently discarded' }), { code: 'storage_unavailable' });
  const denied = new VoiceProfileStore({ env: Object.defineProperty({}, 'localStorage', { get() { throw new Error('Blocked'); } }) });
  assert.throws(() => denied.list(), { code: 'storage_unavailable' });
});

test('corrupt and unsupported libraries are never silently reset or overwritten', () => {
  for (const text of ['broken json', 'null', JSON.stringify({ schemaVersion: 2, revision: 1, profiles: [] }),
    JSON.stringify({ schemaVersion: 1, revision: 0, profiles: [{ ...profile(), embedding: [1] }] }),
    JSON.stringify({ schemaVersion: 1, revision: 0, profiles: [profile(), profile()] })]) {
    const { store, values } = fixture(); values.set(store.key, text);
    for (const action of [() => store.list(), () => store.save(profile('new')), () => store.update('p1', { name: 'New' }), () => store.remove('p1')]) {
      assert.throws(action, { code: 'corrupt_store' });
      assert.equal(values.get(store.key), text);
    }
  }
});

test('names, avatar, IDs and embeddings are validated before any write', () => {
  const { store, values } = fixture();
  for (const changes of [{ name: '' }, { name: 'a'.repeat(25) }, { name: 'line\nbreak' }, { emoji: '' },
    { id: '../bad' }, { embedding: [] }, { embedding: new Array(256).fill(0) },
    { embedding: new Array(256).fill(NaN) }, { modelVersion: '' }]) {
    assert.throws(() => store.save({ ...profile(), ...changes }), { code: 'invalid_profile' });
    assert.equal(values.size, 0);
  }
  assert.throws(() => store.save({ ...profile(), modelVersion: 'older-model' }), { code: 'model_mismatch' });
  assert.equal(values.size, 0);
  assert.equal(store.save({ ...profile(), name: 'é'.repeat(24) }).name.length, 24);
});

test('older model profiles remain readable and removable while metadata edits preserve their version', () => {
  const { store, values } = fixture();
  values.set(store.key, JSON.stringify({ schemaVersion: 1, revision: 7,
    profiles: [{ ...profile(), modelVersion: 'previous-model' }] }));
  assert.equal(store.list()[0].modelVersion, 'previous-model');
  store.update('p1', { name: 'Still here' });
  assert.equal(store.list()[0].modelVersion, 'previous-model');
  assert.equal(store.remove('p1'), true);
});

test('separate store instances read the latest library instead of erasing another instance changes', () => {
  const { store, storage } = fixture();
  const second = new VoiceProfileStore({ storage });
  store.save(profile('first'));
  second.save(profile('second'));
  store.update('first', { emoji: '🐸' });
  assert.deepEqual(second.list().map(value => value.id), ['first', 'second']);
  assert.equal(second.snapshot().revision, 3);
});

const angledVoice = degrees => {
  const radians = degrees * Math.PI / 180;
  return [Math.cos(radians), Math.sin(radians), ...new Array(254).fill(0)];
};

test('legacy schema 1 libraries stay readable without implicit migration or writes', () => {
  const { store, values, storage } = fixture();
  const legacy = JSON.stringify({ schemaVersion: 1, revision: 17, profiles: [profile()] });
  values.set(store.key, legacy);
  storage.setItem = () => { throw new Error('Read must not write'); };
  const saved = store.snapshot();
  assert.equal(saved.revision, 17);
  assert.equal(saved.profiles[0].templates, undefined);
  assert.equal(saved.profiles[0].embedding[0], 1);
  assert.equal(values.get(store.key), legacy);
});

test('saved templates are normalized, cloned, bounded and preserved by metadata-only edits', () => {
  const { store } = fixture();
  const templates = [angledVoice(10).map(value => value * 3), angledVoice(25)];
  const saved = store.save({ ...profile(), templates });
  assert.equal(saved.templates.length, 2);
  assert.ok(saved.templates.every(vector => Math.abs(Math.hypot(...vector) - 1) < 1e-12));
  templates[0].fill(0);
  saved.templates[1].fill(0);
  const before = store.list()[0];
  store.update('p1', { name: 'Renamed', emoji: '🦊', templates: [], embedding: [] });
  const renamed = store.list()[0];
  assert.equal(renamed.name, 'Renamed');
  assert.deepEqual(renamed.templates, before.templates);
  assert.deepEqual(renamed.embedding, before.embedding);
});

test('malformed template collections cannot be saved or silently treated as legacy evidence', () => {
  const { store, values } = fixture();
  for (const templates of [null, [], {}, [angledVoice(0), []], [new Array(256).fill(0)],
    [new Array(256).fill(Infinity)], Array.from({ length: 9 }, () => angledVoice(0))]) {
    assert.throws(() => store.save({ ...profile(), templates }), { code: 'invalid_profile' });
    assert.equal(values.size, 0);
    const broken = JSON.stringify({ schemaVersion: 1, revision: 1, profiles: [{ ...profile(), templates }] });
    values.set(store.key, broken);
    assert.throws(() => store.list(), { code: 'corrupt_store' });
    assert.equal(values.get(store.key), broken);
    values.delete(store.key);
  }
});

test('adding a voice retains legacy evidence, recomputes its mean and updates metadata atomically', () => {
  const { store } = fixture();
  store.save(profile());
  const source = { embedding: angledVoice(20), templates: [angledVoice(10), angledVoice(30)],
    modelVersion: SPEAKER_MODEL_VERSION, name: 'Alex updated', emoji: '🦊' };
  const saved = store.addVoice('p1', source);
  assert.equal(saved.templates.length, 3);
  assert.deepEqual(saved.templates[0], angledVoice(0));
  assert.equal(saved.name, 'Alex updated');
  assert.equal(saved.emoji, '🦊');
  const expected = saved.templates.reduce((mean, vector) => mean.map((value, i) => value + vector[i]), new Array(256).fill(0));
  const norm = Math.hypot(...expected);
  assert.ok(saved.embedding.every((value, i) => Math.abs(value - expected[i] / norm) < 1e-12));
  assert.equal(store.snapshot().revision, 2, 'Voice and metadata use a single write');
  source.templates[0].fill(0); saved.templates[1].fill(0);
  assert.ok(store.list()[0].templates.every(vector => Math.hypot(...vector) > 0.999));
});

test('voice additions are bounded to eight templates while retaining the original references', () => {
  const { store } = fixture();
  const initial = [angledVoice(0), angledVoice(5)];
  store.save({ ...profile(), templates: initial });
  const incoming = Array.from({ length: 8 }, (_, i) => angledVoice(10 + i * 3));
  const saved = store.addVoice('p1', { embedding: angledVoice(20), templates: incoming, modelVersion: SPEAKER_MODEL_VERSION });
  assert.equal(saved.templates.length, 8);
  for (const [actual, expected] of saved.templates.map((value, i) => [value, [...initial, ...incoming.slice(-6)][i]]))
    assert.ok(actual.every((value, i) => Math.abs(value - expected[i]) < 1e-12));
  const updated = store.addVoice('p1', { embedding: angledVoice(25), modelVersion: SPEAKER_MODEL_VERSION });
  assert.equal(updated.templates.length, 8, 'Embedding-only append is supported for legacy callers');
  assert.deepEqual(updated.templates.slice(0, 2), saved.templates.slice(0, 2));
});

test('a different speaker, hidden template outlier or incompatible model cannot poison a saved voice', () => {
  const { store, values } = fixture();
  store.save(profile());
  const before = values.get(store.key);
  for (const evidence of [
    { embedding: angledVoice(90), templates: [angledVoice(90)] },
    { embedding: angledVoice(0), templates: [angledVoice(0), angledVoice(90)] }
  ]) {
    assert.throws(() => store.addVoice('p1', { ...evidence, modelVersion: SPEAKER_MODEL_VERSION, name: 'Do not save' }),
      { code: 'voice_mismatch' });
    assert.equal(values.get(store.key), before, 'Rejected evidence cannot partially change metadata or storage');
  }
  assert.throws(() => store.addVoice('p1', { embedding: angledVoice(0), modelVersion: 'old' }), { code: 'model_mismatch' });
  assert.throws(() => store.addVoice('missing', { embedding: angledVoice(0), modelVersion: SPEAKER_MODEL_VERSION }), { code: 'not_found' });
  assert.throws(() => store.addVoice('p1', { modelVersion: SPEAKER_MODEL_VERSION }), { code: 'invalid_profile' });
  assert.equal(values.get(store.key), before);
});

test('adding a voice preserves another tab changes if storage changes between read and write', () => {
  const { store, storage, values } = fixture();
  store.save(profile());
  const external = JSON.stringify({ schemaVersion: 1, revision: 2, profiles: [{ ...profile(), name: 'Other tab' }] });
  const get = storage.getItem;
  let reads = 0;
  storage.getItem = key => {
    if (++reads === 2) values.set(key, external);
    return get(key);
  };
  assert.throws(() => store.addVoice('p1', { embedding: angledVoice(10), modelVersion: SPEAKER_MODEL_VERSION, name: 'Lost change' }),
    { code: 'conflict' });
  assert.equal(values.get(store.key), external);
});

test('a voice that clearly matches another saved user cannot be appended to a similar sounding user', () => {
  const { store, values } = fixture();
  store.save(profile('alex'));
  const secondVoice = [0.7, Math.sqrt(1 - 0.7 ** 2), ...new Array(254).fill(0)];
  store.save({ ...profile('ben'), name: 'Ben', embedding: secondVoice, templates: [secondVoice, secondVoice] });
  const before = values.get(store.key);
  for (const evidence of [
    { embedding: secondVoice, templates: [secondVoice, secondVoice] },
    { embedding: angledVoice(0), templates: [angledVoice(0), secondVoice] }
  ]) {
    assert.throws(() => store.addVoice('alex', { ...evidence, modelVersion: SPEAKER_MODEL_VERSION, name: 'Do not save' }),
      { code: 'voice_mismatch' });
    assert.equal(values.get(store.key), before, 'A clear alternative identity blocks every partial voice and metadata change');
  }
  const saved = store.addVoice('alex', { embedding: angledVoice(10), templates: [angledVoice(5), angledVoice(15)],
    modelVersion: SPEAKER_MODEL_VERSION, name: 'Alex updated' });
  assert.equal(saved.templates.length, 3, 'Supported supplementary evidence for the intended user still succeeds');
  assert.equal(saved.name, 'Alex updated');
  assert.deepEqual(store.list().find(value => value.id === 'ben').templates, [secondVoice, secondVoice]);
});
