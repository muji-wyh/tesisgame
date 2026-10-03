const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
const { PROFILE, EDGE_TTS_VERSION, MANIFEST_PATH, speechText, messagesFor, assertWave,
  convertVoice, cacheIdentity, cacheKey, generateVoices } = require('../tools/generate-voices.cjs');

function digest(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function wave(rate = 22050, tailSeconds = 0, amplitude = 5000) {
  const dataLength = Math.round(rate * (0.2 + tailSeconds)) * 2;
  const bytes = Buffer.alloc(44 + dataLength);
  bytes.write('RIFF', 0);
  bytes.writeUInt32LE(bytes.length - 8, 4);
  bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(rate, 24);
  bytes.writeUInt32LE(rate * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36);
  bytes.writeUInt32LE(dataLength, 40);
  for (let index = 0; index < Math.round(rate * 0.2); index++) {
    bytes.writeInt16LE(Math.round(Math.sin(index * Math.PI / 30) * amplitude), 44 + index * 2);
  }
  return bytes;
}

function samples(bytes) {
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const length = bytes.readUInt32LE(offset + 4);
    if (bytes.toString('ascii', offset, offset + 4) === 'data') return bytes.subarray(offset + 8, offset + 8 + length);
    offset += 8 + length + length % 2;
  }
  assert.fail('Expected a WAV data chunk.');
}

function fixture(t) {
  const build = path.join(root, 'build');
  fs.mkdirSync(build, { recursive: true });
  const directory = fs.mkdtempSync(path.join(build, 'word-buddies-voice-test-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, 'words.json'), JSON.stringify([words[0]]));
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify(prompts));
  const output = path.join(directory, 'assets', 'audio', 'voice');
  fs.mkdirSync(output, { recursive: true });
  const original = Buffer.from('Keep the existing recording until the complete batch succeeds.');
  for (const id of [...Object.keys(prompts), `word-${words[0].id}`]) {
    fs.writeFileSync(path.join(output, `${id}.wav`), original);
  }
  return { directory, output, original };
}

async function synthesize({ manifest }) {
  for (const request of manifest.requests) fs.writeFileSync(request.output, `Audio for ${request.text}`);
}

function convert(bytes, destination) {
  fs.writeFileSync(destination, wave(22050, 0.12, 4000 + bytes.length));
}

function generate(directory, overrides = {}) {
  return generateVoices({ root: directory, synthesizeBatch: synthesize, convert, ...overrides });
}

function unchanged(output, original) {
  for (const filename of fs.readdirSync(output)) assert.deepEqual(fs.readFileSync(path.join(output, filename)), original);
}

function manifestFor(directory) {
  return JSON.parse(fs.readFileSync(path.join(directory, MANIFEST_PATH), 'utf8'));
}

function removeCached(directory, text) {
  for (const suffix of ['mp3', 'wav', 'json']) {
    fs.rmSync(path.join(directory, 'build', 'voice-cache', `${cacheKey(text)}.${suffix}`), { force: true });
  }
}

test('the generator pins the exact approved, unprocessed Ava preset and Edge TTS client', () => {
  assert.deepEqual(PROFILE, { voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%' });
  assert.equal(EDGE_TTS_VERSION, '7.2.8');
  assert.equal(fs.readFileSync(path.join(root, 'tools/voice-requirements.txt'), 'utf8').trim(), 'edge-tts==7.2.8');
  assert.equal(speechText('apple'), 'apple.');
  assert.equal(speechText('kite'), 'A kite.');
  assert.equal(speechText("Let's play again!"), "Let's play again!");
  assert.throws(() => speechText('<audio src="https://example.com"/>'), /English/);
});

test('voice generation derives exactly 350 words and ten prompts from maintained catalogs', () => {
  const messages = messagesFor(root);
  assert.equal(messages.length, 360);
  assert.equal(new Set(messages.map(message => message.id)).size, 360);
  for (const word of words) {
    assert.deepEqual(messages.find(message => message.id === `word-${word.id}`),
      { id: `word-${word.id}`, text: word.text });
  }
});

test('catalog validation supports two-to-ten-letter words and rejects malformed text, paths, and prompts', t => {
  const { directory } = fixture(t);
  const vocabulary = ['ox', 'sweater', 'elephant', 'pineapple', 'microphone'].map(text => ({
    id: text, text, audio: `assets/audio/voice/word-${text}.wav`
  }));
  fs.writeFileSync(path.join(directory, 'words.json'), JSON.stringify(vocabulary));
  assert.equal(messagesFor(directory).length, Object.keys(prompts).length + vocabulary.length);
  for (const text of ['', 'a', 'watermelons', 'Microphone', 'ice-cream', 'two words', 'café', 'kiwi\n', 'robot!', 'robot2', null]) {
    fs.writeFileSync(path.join(directory, 'words.json'), JSON.stringify([{ id: 'invalid', text, audio: 'assets/audio/voice/word-invalid.wav' }]));
    assert.throws(() => messagesFor(directory), /short English word/, JSON.stringify(text));
  }
  fs.writeFileSync(path.join(directory, 'words.json'), JSON.stringify([{ ...words[0], audio: '../outside.wav' }]));
  assert.throws(() => messagesFor(directory), /audio path/);
  fs.writeFileSync(path.join(directory, 'words.json'), JSON.stringify([words[0], words[0]]));
  assert.throws(() => messagesFor(directory), /unique/);
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify({ ...prompts, extra: 'Hello!' }));
  assert.throws(() => messagesFor(directory), /required prompt IDs/);
});

test('voice WAV validation rejects corruption, incompatible formats, silence, and isolated clicks', () => {
  assert.doesNotThrow(() => assertWave(wave()));
  assert.throws(() => assertWave(wave(24000)), /format/);
  assert.throws(() => assertWave(wave().subarray(0, 100)), /WAV/);
  assert.throws(() => assertWave(Buffer.from('{"error":"not audio"}')), /WAV/);
  for (const amplitude of [0, 1]) assert.throws(() => assertWave(wave(22050, 0, amplitude)), /silent|audible/);
  const click = wave(22050, 0, 0);
  click.writeInt16LE(32767, 44);
  assert.throws(() => assertWave(click), /silent|audible/);
  assert.doesNotThrow(() => assertWave(wave(22050, 0, 500)));
});

test('format conversion preserves the complete delivery, volume, and trailing silence without effects', t => {
  const { directory } = fixture(t);
  const source = wave(22050, 0.6);
  const destination = path.join(directory, 'conversion.wav');
  convertVoice(source, destination);
  const converted = fs.readFileSync(destination);
  assertWave(converted);
  assert.deepEqual(samples(converted), samples(source), 'Already-compatible PCM samples remain identical, including the full tail.');
  const resampled = path.join(directory, 'resampled.wav');
  convertVoice(wave(24000, 0.6), resampled);
  const convertedSamples = samples(fs.readFileSync(resampled));
  assert.ok(Math.abs(convertedSamples.length / 44100 - 0.8) <= 1 / 22050, 'Resampling preserves the untrimmed duration.');
});

test('the complete batch is validated before publishing audio and its truthful provenance manifest', async t => {
  const { directory, output, original } = fixture(t);
  let converted = 0;
  const count = await generate(directory, {
    synthesizeBatch: async ({ manifest, manifestPath }) => {
      assert.deepEqual(JSON.parse(fs.readFileSync(manifestPath, 'utf8')), manifest);
      assert.deepEqual(manifest.profile, PROFILE);
      assert.equal(manifest.edgeTtsVersion, EDGE_TTS_VERSION);
      assert.deepEqual(manifest.requests.map(request => request.text), messagesFor(directory).map(message => speechText(message.text)));
      unchanged(output, original);
      await synthesize({ manifest });
    },
    convert: (bytes, destination) => {
      unchanged(output, original);
      assert.ok(!fs.existsSync(path.join(directory, MANIFEST_PATH)));
      converted += 1;
      convert(bytes, destination);
    }
  });
  assert.equal(count, 11);
  assert.equal(converted, count);
  const manifest = manifestFor(directory);
  assert.deepEqual(manifest.profile, PROFILE);
  assert.equal(manifest.provider, 'Microsoft Edge TTS');
  assert.deepEqual(manifest.client, { name: 'edge-tts', version: '7.2.8' });
  assert.equal(manifest.files.length, count);
  for (const message of messagesFor(directory)) {
    const file = manifest.files.find(file => file.id === message.id);
    const bytes = fs.readFileSync(path.join(directory, file.path));
    assertWave(bytes);
    assert.equal(file.text, message.text);
    assert.equal(file.synthesisText, speechText(message.text));
    assert.equal(file.bytes, bytes.length);
    assert.equal(file.sha256, digest(bytes));
  }
  assert.deepEqual(fs.readdirSync(path.join(directory, 'build')), ['voice-cache']);
});

test('a failed synthesis preserves all originals and resumes only uncached requests', async t => {
  const { directory, output, original } = fixture(t);
  await assert.rejects(generate(directory, {
    synthesizeBatch: async ({ manifest }) => {
      await synthesize({ manifest: { ...manifest, requests: manifest.requests.slice(0, 2) } });
      throw new Error('Simulated service interruption');
    }
  }), /service interruption/);
  unchanged(output, original);
  assert.ok(!fs.existsSync(path.join(directory, MANIFEST_PATH)));
  assert.deepEqual(fs.readdirSync(path.join(directory, 'build')), ['voice-cache']);
  let requested;
  assert.equal(await generate(directory, {
    synthesizeBatch: async ({ manifest }) => {
      requested = manifest.requests.map(request => request.id);
      await synthesize({ manifest });
    }
  }), 11);
  assert.deepEqual(requested, messagesFor(directory).slice(2).map(message => message.id));
});

test('a failed conversion preserves originals, retains validated cache entries, and retries the damaged source', async t => {
  const { directory, output, original } = fixture(t);
  let converted = 0;
  await assert.rejects(generate(directory, {
    convert: (bytes, destination) => {
      if (++converted === 3) throw new Error('Corrupt MP3');
      convert(bytes, destination);
    }
  }), /conversion failed.*Corrupt MP3/);
  unchanged(output, original);
  assert.ok(!fs.existsSync(path.join(directory, MANIFEST_PATH)));
  const third = messagesFor(directory)[2];
  let requested;
  converted = 0;
  await generate(directory, {
    synthesizeBatch: async ({ manifest }) => {
      requested = manifest.requests.map(request => request.id);
      await synthesize({ manifest });
    },
    convert: (bytes, destination) => { converted += 1; convert(bytes, destination); }
  });
  assert.deepEqual(requested, [third.id]);
  assert.equal(converted, 9, 'The first two validated WAVs resume without another decode.');
});

test('cache keys include every voice setting, the final spoken text, client, and output format', () => {
  const original = cacheKey('cat');
  assert.equal(cacheKey('cat'), original);
  assert.notEqual(cacheKey('dog'), original);
  for (const [key, value] of Object.entries({ voice: 'other', rate: '-8%', pitch: '+0Hz', volume: '-1%' })) {
    assert.notEqual(cacheKey('cat', { ...PROFILE, [key]: value }), original, key);
  }
  assert.deepEqual(cacheIdentity('kite'), {
    schema: 1, provider: 'Microsoft Edge TTS', edgeTtsVersion: '7.2.8', profile: PROFILE,
    text: 'A kite.', output: '22050-hz-pcm16-mono-no-effects'
  });
});

test('a completed cache avoids requests and conversion, while changed text regenerates only that clip', async t => {
  const { directory, output } = fixture(t);
  await generate(directory);
  const before = new Map(fs.readdirSync(output).map(name => [name, digest(fs.readFileSync(path.join(output, name)))]));
  await generate(directory, {
    synthesizeBatch: () => assert.fail('Validated cache must avoid requests.'),
    convert: () => assert.fail('Validated cache must avoid conversion.')
  });
  for (const [name, hash] of before) assert.equal(digest(fs.readFileSync(path.join(output, name))), hash);
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify({ ...prompts, wrong: 'Try once more!' }));
  let requested;
  await generate(directory, {
    synthesizeBatch: async ({ manifest }) => {
      requested = manifest.requests;
      await synthesize({ manifest });
    }
  });
  assert.equal(requested.length, 1);
  assert.equal(requested[0].id, 'wrong');
  assert.equal(requested[0].text, 'Try once more!');
  assert.equal(manifestFor(directory).files.find(file => file.id === 'wrong').synthesisText, 'Try once more!');
});

test('corrupted WAV cache data and changed profile metadata cannot be reused as approved audio', async t => {
  const { directory } = fixture(t);
  await generate(directory);
  const messages = messagesFor(directory);
  const first = path.join(directory, 'build', 'voice-cache', cacheKey(messages[0].text));
  fs.writeFileSync(`${first}.wav`, wave(22050, 0, 6000));
  const second = path.join(directory, 'build', 'voice-cache', cacheKey(messages[1].text));
  const metadata = JSON.parse(fs.readFileSync(`${second}.json`, 'utf8'));
  metadata.identity.profile.pitch = '+0Hz';
  fs.writeFileSync(`${second}.json`, JSON.stringify(metadata));
  let conversions = 0;
  await generate(directory, {
    synthesizeBatch: () => assert.fail('The intact source MP3s remain reusable.'),
    convert: (bytes, destination) => { conversions += 1; convert(bytes, destination); }
  });
  assert.equal(conversions, 2);
  assert.equal(JSON.parse(fs.readFileSync(`${second}.json`, 'utf8')).identity.profile.pitch, '+8Hz');
});

test('missing-only generation rejects undocumented previous voices instead of relabeling them as Ava', async t => {
  const { directory, output, original } = fixture(t);
  fs.unlinkSync(path.join(output, 'word-cat.wav'));
  await assert.rejects(generate(directory, {
    onlyMissing: true,
    synthesizeBatch: () => assert.fail('Mixed-profile generation must fail before network requests.')
  }), /Cannot use --missing.*full generation/);
  unchanged(output, original);
  assert.ok(!fs.existsSync(path.join(directory, MANIFEST_PATH)));
});

test('missing-only generation preserves documented Ava files and requests only absent recordings', async t => {
  const { directory, output } = fixture(t);
  await generate(directory);
  const missing = ['jungle-theme', 'candy-theme'];
  for (const id of missing) {
    fs.unlinkSync(path.join(output, `${id}.wav`));
    removeCached(directory, prompts[id]);
  }
  const before = new Map(fs.readdirSync(output).map(name => [name, fs.readFileSync(path.join(output, name))]));
  let requested;
  assert.equal(await generate(directory, {
    onlyMissing: true,
    synthesizeBatch: async ({ manifest }) => {
      requested = manifest.requests.map(request => request.id);
      for (const id of missing) assert.ok(!fs.existsSync(path.join(output, `${id}.wav`)));
      await synthesize({ manifest });
    }
  }), 2);
  assert.deepEqual(requested, missing);
  for (const [name, bytes] of before) assert.deepEqual(fs.readFileSync(path.join(output, name)), bytes);
  assert.equal(manifestFor(directory).files.length, 11);
  assert.equal(await generate(directory, {
    onlyMissing: true,
    synthesizeBatch: () => assert.fail('Complete approved catalog makes no requests.'),
    convert: () => assert.fail('Complete approved catalog makes no conversions.')
  }), 0);
});

test('missing-only generation rejects mismatching profile, text, or file hashes in prior provenance', async t => {
  const { directory, output } = fixture(t);
  await generate(directory);
  const manifestPath = path.join(directory, MANIFEST_PATH);
  const approvedManifest = fs.readFileSync(manifestPath);
  const manifest = manifestFor(directory);
  manifest.profile.pitch = '+0Hz';
  fs.writeFileSync(manifestPath, JSON.stringify(manifest));
  await assert.rejects(generate(directory, { onlyMissing: true }), /full generation/);
  fs.writeFileSync(manifestPath, approvedManifest);
  fs.writeFileSync(path.join(output, 'wrong.wav'), wave(22050, 0, 9000));
  await assert.rejects(generate(directory, { onlyMissing: true }), /wrong.*full generation/);
  await generate(directory);
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify({ ...prompts, wrong: 'A new prompt.' }));
  await assert.rejects(generate(directory, { onlyMissing: true }), /wrong.*full generation/);
});
