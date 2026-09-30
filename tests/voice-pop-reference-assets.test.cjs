const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { importReference, SOURCE_SHA256, VARIANTS, LAUNCH_WINDOW } = require('../tools/import-pop-reference.cjs');
const { renderLaunch, DESTINATION, SECONDS } = require('../tools/generate-pop-launch.cjs');
const manifest = require('../docs/assets/voice-pop-reference-audio.json');
const root = path.resolve(__dirname, '..');

function readWave(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
  assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
  let format, data;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    assert.ok(offset + 8 + size <= bytes.length, 'The WAV contains no truncated chunk');
    if (id === 'fmt ') format = bytes.subarray(offset + 8, offset + 8 + size);
    if (id === 'data') data = bytes.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + size % 2;
  }
  assert.ok(format && data);
  assert.equal(format.readUInt16LE(0), 1);
  assert.equal(format.readUInt16LE(2), 1);
  assert.equal(format.readUInt32LE(4), 44100);
  assert.equal(format.readUInt16LE(14), 16);
  const samples = Array.from({ length: data.length / 2 }, (_, index) => data.readInt16LE(index * 2) / 32768);
  return { bytes, samples, rate: 44100 };
}

test('the reviewed mono reference and exact blade/cut windows are reproducible', () => {
  assert.equal(manifest.source.sha256, SOURCE_SHA256);
  assert.equal(manifest.source.channels, 1);
  assert.equal(manifest.source.sampleRate, 44100);
  assert.match(manifest.note, /not isolated original stems/);
  assert.deepEqual(manifest.assets.map(asset => asset.id), ['quick', 'juicy', 'crisp']);
  for (const [index, asset] of manifest.assets.entries()) {
    assert.deepEqual(asset.blade, VARIANTS[index].blade);
    assert.deepEqual(asset.cut, VARIANTS[index].cut);
    assert.equal(asset.cutOffsetSeconds, 0.032);
    assert.ok(asset.blade.start + asset.blade.seconds < manifest.source.seconds);
    assert.ok(asset.cut.start + asset.cut.seconds < manifest.source.seconds);
    assert.equal(asset.destination, `assets/imported-audio/pop-reference/${asset.id}.wav`);
  }
  assert.equal(new Set(manifest.assets.map(asset => asset.sha256)).size, 3);
  assert.deepEqual(manifest.assets.map(asset => asset.sha256), [
    'd606dac66a6445ea31658856d69e85e9afcf552f5964fda25e37c78afc2c68ed',
    '01556a54bcd4746f34a836854aef4ca4a2c4a83ec1a93202dad1007d0f71b703',
    '4b947aa7df68be21316916f03fbe2334d7026b4dcc3c5c550dd19310c305bed6',
  ], 'Adding the launch preserves all three reviewed hit waveforms');
});

test('local reference hits contain a short blade lead-in, cut energy and safe tails', t => {
  const assets = manifest.assets.filter(asset => fs.existsSync(path.join(root, asset.destination)));
  if (!assets.length) return t.skip('The private reference bank is absent from this source checkout.');
  assert.equal(assets.length, 3, 'A local reference installation must be complete');
  for (const asset of assets) {
    const { bytes, samples, rate } = readWave(path.join(root, asset.destination));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), asset.sha256);
    assert.equal(samples.length / rate, asset.seconds);
    assert.ok(asset.seconds >= 0.27 && asset.seconds <= 0.33);
    const peak = Math.max(...samples.map(Math.abs));
    const rms = Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) / samples.length);
    assert.ok(peak > 0.50 && peak <= 0.62, 'Transient peaks leave room for three concurrent hits');
    assert.ok(rms >= 0.07 && rms <= 0.13, 'The cut body is audible without being continuously loud');
    assert.ok(Math.abs(20 * Math.log10(peak) - asset.peakDbfs) < 0.001);
    assert.ok(Math.abs(20 * Math.log10(rms) - asset.rmsDbfs) < 0.001);
    assert.equal(samples[0], 0);
    assert.equal(samples.at(-1), 0);
    assert.equal(samples.filter(sample => Math.abs(sample) >= 0.999).length, 0);
    const lead = samples.slice(0, Math.round(0.032 * rate));
    assert.ok(Math.max(...lead.map(Math.abs)) > 0.1, 'The blade is already audible before the impact layer starts');
    const cut = samples.slice(Math.round(0.04 * rate), Math.round(0.13 * rate));
    assert.ok(Math.sqrt(cut.reduce((sum, sample) => sum + sample * sample, 0) / cut.length) > 0.04,
      'The visual rupture has audible cut energy in its first 90 milliseconds');
    assert.ok(peak * manifest.processing.runtimeGain * manifest.processing.maxSimultaneousHits < 0.45);
    const metadata = fs.readFileSync(path.join(root, asset.destination + '.import'), 'utf8');
    for (const setting of ['edit/trim=false', 'edit/normalize=false', 'edit/loop_mode=0', 'compress/mode=0']) {
      assert.ok(metadata.includes(setting), `Godot must preserve the authored transient: ${setting}`);
    }
  }
});

test('the separate recorded launch precedes every source cut and leaves microphone headroom', t => {
  const asset = manifest.launch;
  assert.equal(asset.id, 'launch');
  assert.equal(asset.destination, 'assets/imported-audio/pop-reference/launch.wav');
  assert.deepEqual(asset.window, LAUNCH_WINDOW);
  assert.ok(asset.window.start + asset.window.seconds < Math.min(...VARIANTS.map(variant => variant.blade.start)));
  assert.ok(manifest.assets.every(hit => hit.destination !== asset.destination));
  assert.equal(asset.processing.runtimeGain, 0.16);
  assert.equal(asset.processing.maxSimultaneousLaunches, 1);
  assert.equal(asset.fallback, DESTINATION);
  const file = path.join(root, asset.destination);
  if (!fs.existsSync(file)) return t.skip('The private launch source is absent; the tracked fallback remains available.');
  const { bytes, samples, rate } = readWave(file);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), asset.sha256);
  assert.equal(samples.length / rate, asset.seconds);
  assert.ok(asset.seconds <= 0.3);
  const peak = Math.max(...samples.map(Math.abs));
  const rms = Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) / samples.length);
  assert.ok(peak > 0.25 && peak <= 0.48);
  assert.ok(rms > 0.04 && rms <= 0.10);
  assert.ok(peak * asset.processing.runtimeGain < 0.077);
  assert.equal(samples[0], 0);
  assert.equal(samples.at(-1), 0);
});

test('the clean-checkout launch is an original reproducible air cue distinct from the hit bank', () => {
  const { bytes, samples, rate } = readWave(path.join(root, DESTINATION));
  assert.deepEqual(bytes, renderLaunch());
  assert.equal(samples.length / rate, SECONDS);
  assert.equal(SECONDS, 0.22);
  const peak = Math.max(...samples.map(Math.abs));
  const rms = Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) / samples.length);
  assert.ok(peak > 0.2 && peak <= 0.45);
  assert.ok(rms > 0.065 && rms <= 0.085);
  assert.equal(samples[0], 0);
  assert.equal(samples.at(-1), 0);
  assert.ok(manifest.assets.every(asset => Math.abs(asset.seconds - SECONDS) > 0.02));
  const metadata = fs.readFileSync(path.join(root, DESTINATION + '.import'), 'utf8');
  for (const setting of ['edit/trim=false', 'edit/normalize=false', 'edit/loop_mode=0', 'compress/mode=0']) {
    assert.ok(metadata.includes(setting));
  }
});

test('an unreviewed input video cannot overwrite existing imported sounds or invoke FFmpeg', t => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'voice-pop-reference-'));
  t.after(() => {
    assert.equal(path.dirname(temporary), os.tmpdir());
    fs.rmSync(temporary, { recursive: true, force: true });
  });
  const source = path.join(temporary, 'wrong.mp4');
  fs.writeFileSync(source, 'This is not the reviewed recording.');
  const destination = path.join(temporary, 'assets/imported-audio/pop-reference/quick.wav');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, 'Preserve the working asset.');
  assert.throws(() => importReference({ source, root: temporary, ffmpeg: 'must-not-run' }), /does not match the reviewed reference/);
  assert.equal(fs.readFileSync(destination, 'utf8'), 'Preserve the working asset.');
  assert.equal(fs.existsSync(path.join(temporary, 'docs/assets/voice-pop-reference-audio.json')), false);
});
