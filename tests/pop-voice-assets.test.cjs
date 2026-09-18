const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { assertWave } = require('../tools/generate-voices.cjs');
const { messagesFor, generatePopVoices } = require('../tools/generate-pop-voices.cjs');
const root = path.resolve(__dirname, '..');

test('every report sentence ships as audible neural PCM and an optional imported resource', () => {
  const prompts = messagesFor(root);
  const directory = path.join(root, 'assets/audio/pop');
  assert.equal(prompts.length, 51);
  assert.deepEqual(fs.readdirSync(directory).filter(name => name.endsWith('.wav')).sort(),
    prompts.map(({ id }) => `${id}.wav`).sort());
  const hashes = new Set();
  const optional = require('../tools/package-web.cjs').collectOptionalAudio(root);
  for (const { id } of prompts) {
    const bytes = fs.readFileSync(path.join(directory, `${id}.wav`));
    assertWave(bytes, 22050);
    hashes.add(createHash('sha256').update(bytes).digest('hex'));
    const entry = optional.find(item => item.source === `res://assets/audio/pop/${id}.wav`);
    assert.ok(entry, `The report must be available through the optional audio map: ${id}`);
    assert.ok(entry.bytes.length > 0);
  }
  assert.equal(hashes.size, prompts.length, 'Each sentence has its own recording');
  const preset = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
  assert.match(preset, /exclude_filter="[^"\n]*assets\/audio\/pop\/\*/);
  assert.match(preset, /include_filter="[^"\n]*pop-voice-prompts\.json/);
});

test('report recordings cover actual counts as whole sentences and keep zero hits encouraging', () => {
  const prompts = Object.fromEntries(messagesFor(root).map(({ id, text }) => [id, text]));
  for (let count = 0; count <= 20; count++) {
    assert.match(prompts[`round-${count}`], new RegExp(`You popped ${count} ${count === 1 ? 'word' : 'words'} in 30 seconds\\.`));
    if (count) assert.match(prompts[`combo-${count}`], new RegExp(`Your best combo was ${count}\\.`));
  }
  assert.match(prompts['round-0'], /practise together/);
  assert.doesNotMatch(prompts['round-0'], /well done|great score/i);
});

test('failed report generation preserves existing audio and cannot fall back to system speech', async t => {
  const directory = fs.mkdtempSync(path.join(root, 'build/pop-voice-test-'));
  t.after(() => {
    assert.equal(path.dirname(directory), path.join(root, 'build'));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  fs.copyFileSync(path.join(root, 'pop-voice-prompts.json'), path.join(directory, 'pop-voice-prompts.json'));
  const output = path.join(directory, 'assets/audio/pop');
  fs.mkdirSync(output, { recursive: true });
  const original = Buffer.from('Keep the published recording.');
  for (const { id } of messagesFor(root)) {
    if (id !== 'high-five') fs.writeFileSync(path.join(output, `${id}.wav`), original);
  }
  await assert.rejects(generatePopVoices({ root: directory, key: '', region: 'eastasia',
    fetchImpl: () => assert.fail('Missing credentials must never start a request') }), /SPEECH_KEY/);
  const waits = [];
  await assert.rejects(generatePopVoices({ root: directory, onlyMissing: true,
    key: 'test-placeholder', region: 'eastasia', wait: async ms => waits.push(ms),
    fetchImpl: async url => url.endsWith('/voices/list')
      ? Response.json([{ ShortName: 'en-US-JennyNeural', VoiceType: 'Neural', Locale: 'en-US', StyleList: ['friendly'] }])
      : new Response(null, { status: 503 }) }), /HTTP 503/);
  assert.deepEqual(waits, [3200]);
  assert.equal(fs.existsSync(path.join(output, 'high-five.wav')), false);
  for (const filename of fs.readdirSync(output)) assert.deepEqual(fs.readFileSync(path.join(output, filename)), original);
});
