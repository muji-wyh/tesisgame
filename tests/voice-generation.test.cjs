const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));

function generator() {
  const filename = path.join(root, 'tools', 'generate-voices.cjs');
  assert.ok(fs.existsSync(filename), 'The prerecorded neural-voice generator must exist.');
  return require(filename);
}

function wave(rate = 24000, tailSeconds = 0) {
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
    bytes.writeInt16LE(index >= rate * 0.19 ? 32 :
      Math.round(Math.sin(index * Math.PI / 30) * 5000), 44 + index * 2);
  }
  return bytes;
}

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'word-buddies-voice-test-'));
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

const supportedVoice = [{
  ShortName: 'en-US-JennyNeural', VoiceType: 'Neural', Locale: 'en-US', StyleList: ['friendly']
}];

test('the voice profile uses warm neural speech with clear, gently paced words', () => {
  const { PROFILE, speechMarkup } = generator();
  assert.equal(PROFILE.voice, 'en-US-JennyNeural');
  assert.equal(PROFILE.style, 'friendly');
  assert.equal(PROFILE.format, 'riff-24khz-16bit-mono-pcm');
  const ssml = speechMarkup('apple');
  assert.match(ssml, /<voice name="en-US-JennyNeural">/);
  assert.match(ssml, /<mstts:express-as style="friendly" styledegree="1\.15">/);
  assert.match(ssml, /<prosody rate="-8%">/);
  assert.match(ssml, /<s>apple\.<\/s>/);
  assert.match(ssml, /type="Leading-exact" value="60ms"/);
  assert.match(ssml, /type="Tailing-exact" value="100ms"/);
  assert.match(speechMarkup("Let's play again!"), /Let(?:'|&apos;)s play again!/);
  assert.throws(() => speechMarkup('<audio src="https://example.com"/>'), /English/);
});

test('voice generation derives exactly 140 words and twenty-two prompts from the maintained lists', () => {
  const messages = generator().messagesFor(root);
  assert.equal(messages.length, 162);
  assert.equal(new Set(messages.map(message => message.id)).size, 162);
  for (const word of words) {
    assert.deepEqual(messages.find(message => message.id === `word-${word.id}`),
      { id: `word-${word.id}`, text: word.text });
  }
});

test('voice generation rejects incomplete prompts and unexpected output paths', (t) => {
  const { directory } = fixture(t);
  const { messagesFor } = generator();
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify({ ...prompts, extra: 'Hello!' }));
  assert.throws(() => messagesFor(directory), /required prompt IDs/);
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify(prompts));
  fs.writeFileSync(path.join(directory, 'words.json'),
    JSON.stringify([{ ...words[0], audio: '../outside.wav' }]));
  assert.throws(() => messagesFor(directory), /audio path/);
});

test('voice WAV validation rejects corruption, incompatible formats, and silent clips', () => {
  const { assertWave } = generator();
  assert.doesNotThrow(() => assertWave(wave(22050), 22050));
  assert.throws(() => assertWave(wave(24000), 22050), /format/);
  const truncated = wave(22050).subarray(0, 100);
  assert.throws(() => assertWave(truncated, 22050), /WAV/);
  const silent = wave(22050);
  silent.fill(0, 44);
  assert.throws(() => assertWave(silent, 22050), /silent/);
  assert.throws(() => assertWave(Buffer.from('{"error":"not audio"}'), 22050), /WAV/);
});

test('voice validation rejects noise-floor audio and isolated clicks without rejecting quiet speech', () => {
  const { assertWave } = generator();
  const noise = wave(22050);
  for (let index = 44; index < noise.length; index += 2) noise.writeInt16LE(1, index);
  assert.throws(() => assertWave(noise, 22050), /silent|audible/);
  const click = wave(22050);
  click.fill(0, 44);
  click.writeInt16LE(32767, 44);
  assert.throws(() => assertWave(click, 22050), /silent|audible/);
  const quietSpeech = wave(22050);
  for (let index = 44; index < quietSpeech.length; index += 2) {
    quietSpeech.writeInt16LE(Math.round(quietSpeech.readInt16LE(index) / 10), index);
  }
  assert.doesNotThrow(() => assertWave(quietSpeech, 22050));
});

test('missing credentials or an invalid region cannot start requests or replace recordings', async (t) => {
  const { directory, output, original } = fixture(t);
  const { generateVoices } = generator();
  const options = {
    root: directory, key: '', region: 'eastasia',
    fetchImpl: () => assert.fail('No network request is allowed before credential validation.')
  };
  await assert.rejects(generateVoices(options), /SPEECH_KEY/);
  await assert.rejects(generateVoices({ ...options, key: 'test-key', region: 'eastasia.example.com' }), /SPEECH_REGION/);
  assert.deepEqual(fs.readFileSync(path.join(output, 'word-cat.wav')), original);
});

test('the complete neural batch is resampled to mobile PCM and published only after success', async (t) => {
  const { directory, output, original } = fixture(t);
  const { generateVoices, assertWave } = generator();
  const waits = [];
  let posts = 0;
  const count = await generateVoices({
    root: directory, key: 'test-key', region: 'eastasia',
    wait: async milliseconds => { waits.push(milliseconds); },
    fetchImpl: async (url, options) => {
      assert.match(url, /^https:\/\/eastasia\.tts\.speech\.microsoft\.com\//);
      assert.equal(options.headers['Ocp-Apim-Subscription-Key'], 'test-key');
      assert.equal(options.redirect, 'error');
      assert.ok(options.signal instanceof AbortSignal);
      if (url.endsWith('/voices/list')) return Response.json(supportedVoice);
      posts += 1;
      assert.equal(options.method, 'POST');
      assert.equal(options.headers['X-Microsoft-OutputFormat'], 'riff-24khz-16bit-mono-pcm');
      assert.match(options.body, /style="friendly"/);
      for (const filename of fs.readdirSync(output)) {
        assert.deepEqual(fs.readFileSync(path.join(output, filename)), original,
          'No old recording is replaced while requests are still in progress.');
      }
      return new Response(wave(24000, 0.8), { headers: { 'Content-Type': 'audio/wav' } });
    }
  });
  assert.equal(count, Object.keys(prompts).length + 1);
  assert.equal(posts, count);
  assert.equal(waits.length, count);
  assert.ok(waits.every(milliseconds => milliseconds >= 3200), 'Requests stay below the F0 rate limit.');
  for (const filename of fs.readdirSync(output)) {
    const audio = fs.readFileSync(path.join(output, filename));
    assertWave(audio, 22050);
    assert.ok(audio.length / 44100 >= 0.34 && audio.length / 44100 < 0.41,
      'Excess sentence-boundary silence is removed, with a gentle tail retained.');
    let lastQuietEnding = 0;
    for (let index = 44; index < audio.length; index += 2) {
      if (Math.abs(audio.readInt16LE(index)) > 25) lastQuietEnding = (index - 44) / 44100;
    }
    assert.ok(lastQuietEnding >= 0.196, 'Quiet word endings must remain audible.');
  }
  assert.deepEqual(fs.readdirSync(path.join(directory, 'build')), []);
});

test('a failed batch preserves every original clip and never falls back to the robotic voice', async (t) => {
  const { directory, output, original } = fixture(t);
  const { generateVoices } = generator();
  let posts = 0;
  await assert.rejects(generateVoices({
    root: directory, key: 'private-test-key', region: 'eastasia', wait: async () => {},
    fetchImpl: async url => {
      if (url.endsWith('/voices/list')) return Response.json(supportedVoice);
      posts += 1;
      return posts === 1 ? new Response(wave()) :
        new Response('private-test-key must not appear in the error', { status: 401 });
    }
  }), error => /HTTP 401/.test(error.message) && !error.message.includes('private-test-key'));
  assert.equal(posts, 2);
  for (const filename of fs.readdirSync(output)) {
    assert.deepEqual(fs.readFileSync(path.join(output, filename)), original);
  }
  assert.deepEqual(fs.readdirSync(path.join(directory, 'build')), []);
});

test('an unavailable friendly neural style is an explicit error before synthesis', async (t) => {
  const { directory } = fixture(t);
  await assert.rejects(generator().generateVoices({
    root: directory, key: 'test-key', region: 'eastasia',
    fetchImpl: async () => Response.json([{ ...supportedVoice[0], StyleList: [] }])
  }), /friendly/);
});

test('missing-only synthesis preserves existing recordings and requests only absent words', async (t) => {
  const { directory, output, original } = fixture(t);
  const destination = path.join(output, 'word-cat.wav');
  fs.unlinkSync(destination);
  const posted = [];
  const count = await generator().generateVoices({
    root: directory, key: 'test-key', region: 'eastasia', onlyMissing: true,
    wait: async () => {},
    fetchImpl: async (url, options) => {
      if (url.endsWith('/voices/list')) return Response.json(supportedVoice);
      posted.push(options.body);
      return new Response(wave());
    }
  });
  assert.equal(count, 1);
  assert.equal(posted.length, 1);
  assert.match(posted[0], /<s>cat\.<\/s>/);
  generator().assertWave(fs.readFileSync(destination), 22050);
  for (const id of Object.keys(prompts)) {
    assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original);
  }
  assert.equal(await generator().generateVoices({
    root: directory, key: 'test-key', region: 'eastasia', onlyMissing: true,
    fetchImpl: () => assert.fail('A complete catalog makes no speech requests.')
  }), 0);
});
