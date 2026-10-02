const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { renderQuestAudio, generateQuestAudio } = require('../tools/generate-quest-audio.cjs');

const root = path.resolve(__dirname, '..');
const rate = 44100;
const expected = { launch: 0.24, impact: 0.36, defeat: 0.90 };
const rms = values => Math.sqrt(values.reduce((energy, value) => energy + value * value, 0) / values.length);

function decode(id) {
  const bytes = fs.readFileSync(path.join(root, `assets/audio/quest/${id}.wav`));
  const samples = Float64Array.from({ length: (bytes.length - 44) / 2 }, (_, index) => bytes.readInt16LE(44 + index * 2) / 32768);
  return { bytes, samples };
}

// A small radix-2 transform checks the actual PCM spectrum without a native
// decoder or an optional audio library. Power includes the entire one-shot.
function spectrum(samples) {
  const size = 2 ** Math.ceil(Math.log2(samples.length));
  const real = new Float64Array(size), imaginary = new Float64Array(size);
  real.set(samples);
  for (let index = 1, reversed = 0; index < size; index++) {
    let bit = size >> 1;
    while (reversed & bit) { reversed ^= bit; bit >>= 1; }
    reversed ^= bit;
    if (index < reversed) [real[index], real[reversed]] = [real[reversed], real[index]];
  }
  for (let span = 2; span <= size; span *= 2) {
    for (let start = 0; start < size; start += span) {
      for (let offset = 0; offset < span / 2; offset++) {
        const angle = -2 * Math.PI * offset / span;
        const even = start + offset, odd = even + span / 2;
        const oddReal = real[odd] * Math.cos(angle) - imaginary[odd] * Math.sin(angle);
        const oddImaginary = real[odd] * Math.sin(angle) + imaginary[odd] * Math.cos(angle);
        real[odd] = real[even] - oddReal;
        imaginary[odd] = imaginary[even] - oddImaginary;
        real[even] += oddReal;
        imaginary[even] += oddImaginary;
      }
    }
  }
  const bins = Float64Array.from({ length: size / 2 }, (_, index) => real[index] ** 2 + imaginary[index] ** 2);
  const total = bins.reduce((sum, value) => sum + value, 0);
  return (low, high) => bins.slice(Math.ceil(low * size / rate), Math.floor(high * size / rate) + 1)
    .reduce((sum, value) => sum + value, 0) / total;
}

for (const [id, seconds] of Object.entries(expected)) {
  test(`Talk Quest ${id} is an audible, bounded mono PCM one-shot with clean boundaries`, () => {
    const { bytes, samples } = decode(id);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.readUInt32LE(4), bytes.length - 8);
    assert.equal(bytes.toString('ascii', 8, 16), 'WAVEfmt ');
    assert.equal(bytes.readUInt16LE(20), 1, 'Uncompressed PCM');
    assert.equal(bytes.readUInt16LE(22), 1, 'Mono');
    assert.equal(bytes.readUInt32LE(24), rate);
    assert.equal(bytes.readUInt16LE(34), 16, 'PCM16');
    assert.equal(bytes.toString('ascii', 36, 40), 'data');
    assert.equal(bytes.readUInt32LE(40), bytes.length - 44);
    assert.equal(samples.length, Math.round(seconds * rate));
    const peak = samples.reduce((maximum, sample) => Math.max(maximum, Math.abs(sample)), 0);
    assert.ok(peak > 0.4 && peak <= 0.75, `Peak ${peak} leaves mix headroom`);
    assert.ok(rms(samples) >= 0.16 && rms(samples) <= 0.20, 'Comparable audible cue levels');
    assert.ok(Math.abs(samples.reduce((sum, sample) => sum + sample, 0) / samples.length) < 0.00001, 'No DC offset');
    assert.equal(samples[0], 0);
    assert.equal(samples.at(-1), 0);
    assert.ok(rms(samples.slice(-Math.round(0.005 * rate))) < 0.001, 'Smooth silent release');
    assert.ok(rms(samples.slice(0, Math.round(0.02 * rate))) > 0.03, 'Prompt onset rather than leading silence');
    assert.ok(samples.every((sample, index) => index === 0 || Math.abs(sample - samples[index - 1]) < 0.15), 'No isolated abrupt sample jumps');
    const metadata = fs.readFileSync(path.join(root, `assets/audio/quest/${id}.wav.import`), 'utf8');
    assert.match(metadata, /edit\/loop_mode=0/);
    assert.match(metadata, /edit\/normalize=false/);
    assert.match(metadata, /edit\/trim=false/);
  });

  test(`Talk Quest ${id} keeps useful speaker-range energy and a restrained top end`, () => {
    const { samples } = decode(id);
    const power = spectrum(samples);
    assert.ok(power(120, 1800) > 0.80, 'Most energy is in the useful phone-speaker range');
    assert.ok(power(150, 350) > (id === 'defeat' ? 0.10 : 0.30), 'Warm body rather than only a high-pitched beep');
    assert.ok(power(4200, rate / 2 - 1) < 0.025, 'No dominant brittle high-frequency buzz');
    assert.ok(power(0, 80) < 0.01, 'No inaudible low-frequency rumble');
  });
}

test('Talk Quest cues regenerate deterministically and retain their intended temporal character', () => {
  for (const id of Object.keys(expected)) {
    const { bytes } = decode(id);
    assert.deepEqual(renderQuestAudio(id), bytes, `${id} exactly matches its checked-in source`);
    assert.deepEqual(renderQuestAudio(id), renderQuestAudio(id), `${id} has a reproducible seeded noise layer`);
  }
  const launch = decode('launch').samples, impact = decode('impact').samples, defeat = decode('defeat').samples;
  const quarterRms = (samples, quarter) => rms(samples.slice(Math.round(samples.length * quarter / 4), Math.round(samples.length * (quarter + 1) / 4)));
  assert.ok(quarterRms(launch, 1) > quarterRms(launch, 3) * 2, 'Projectile sweeps forward and fades');
  assert.ok(quarterRms(impact, 0) > quarterRms(impact, 2) * 2, 'Impact has a strong short contact');
  assert.ok(quarterRms(defeat, 2) > 0.10, 'Defeat retains an audible musical resolve');
  assert.throws(() => renderQuestAudio('unknown'), /Unknown Talk Quest audio cue/);
});

test('Talk Quest generation preserves unchanged files and stable Godot import identities', (t) => {
  const build = path.join(root, 'build');
  fs.mkdirSync(build, { recursive: true });
  const directory = fs.mkdtempSync(path.join(build, 'quest-audio-test-'));
  t.after(() => {
    assert.ok(path.resolve(directory).startsWith(path.resolve(build) + path.sep));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const generated = generateQuestAudio(directory);
  assert.deepEqual(generated.map(cue => cue.id), ['launch', 'impact', 'defeat']);
  const retainedTime = new Date('2020-01-01T00:00:00Z');
  for (const cue of generated) {
    const file = path.join(directory, cue.file), metadata = file + '.import';
    fs.utimesSync(file, retainedTime, retainedTime);
    fs.writeFileSync(metadata, fs.readFileSync(metadata, 'utf8').replace('type="AudioStreamWAV"', 'type="AudioStreamWAV"\nuid="uid://stablequestsound"'));
  }
  generateQuestAudio(directory);
  for (const cue of generated) {
    const file = path.join(directory, cue.file);
    assert.equal(fs.statSync(file).mtimeMs, retainedTime.getTime(), 'Unchanged WAV is not rewritten');
    assert.match(fs.readFileSync(file + '.import', 'utf8'), /uid="uid:\/\/stablequestsound"/);
    assert.deepEqual(fs.readFileSync(file), renderQuestAudio(cue.id));
  }
});
