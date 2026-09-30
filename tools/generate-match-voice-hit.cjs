const fs = require('node:fs');
const path = require('node:path');
const { RATE, normalize, statistics, wave, importMetadata } = require('./import-pop-reference.cjs');

const DESTINATION = 'assets/audio/sfx/match-voice-hit.wav';
const SECONDS = 0.46;
const RUNTIME_GAIN = 0.48;
const TAU = Math.PI * 2;

function pulse(time, start, duration, attack, decay) {
  const age = time - start;
  if (age < 0 || age >= duration) return 0;
  return Math.sin(Math.min(1, age / attack) * Math.PI / 2) ** 2 *
    Math.exp(-age * decay) * Math.sin(Math.min(1, (duration - age) / 0.04) * Math.PI / 2) ** 2;
}

function renderSamples() {
  const samples = new Float64Array(Math.round(RATE * SECONDS));
  let seed = 0x7a617021, noiseLow = 0, noiseBody = 0, phase = 0, filtered = 0, smooth = 0;
  const lowpass = 1 - Math.exp(-TAU * 4200 / RATE);
  for (let index = 0; index < samples.length; index++) {
    const time = index / RATE;
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const noise = seed / 2147483648 - 1;
    noiseLow += (noise - noiseLow) * 0.36;
    noiseBody += (noiseLow - noiseBody) * 0.06;
    phase += TAU * (520 + 1450 * Math.exp(-time / 0.034)) / RATE;
    // A brief descending FM arc gives electricity its edge without a sawtooth's
    // continuous high-frequency buzz. Seeded, filtered sparks never contain speech.
    const zap = Math.sin(phase + 2.6 * Math.exp(-time / 0.033) * Math.sin(TAU * 310 * time));
    const spark = pulse(time, 0, 0.09, 0.002, 35) +
      0.45 * pulse(time, 0.024, 0.045, 0.0015, 65) + 0.28 * pulse(time, 0.051, 0.04, 0.002, 70);
    let value = 0.30 * zap * pulse(time, 0, 0.17, 0.003, 23) + 0.38 * (noiseLow - noiseBody) * spark;
    // Two overlapping tuned tones rise from G to C and resolve into a quiet
    // shimmer. They support the success beat without becoming a spoken prompt.
    for (const [start, frequency, gain] of [[0.035, 783.99, 0.09], [0.092, 1046.5, 0.125]]) {
      const age = time - start;
      if (age < 0) continue;
      const tone = Math.sin(TAU * frequency * age) + 0.14 * Math.sin(TAU * frequency * 2 * age) * Math.exp(-age * 12);
      value += gain * tone * pulse(time, start, SECONDS - start, 0.008, 9.5);
    }
    // Two gentle low-pass stages take the brittle edge off the transient. The
    // final release reaches exact silence so retriggering cannot produce a click.
    filtered += lowpass * (value - filtered);
    smooth += lowpass * (filtered - smooth);
    const release = Math.sin(Math.min(1, (SECONDS - time) / 0.055) * Math.PI / 2) ** 2;
    samples[index] = smooth * release;
  }
  samples[0] = 0;
  samples[samples.length - 1] = 0;
  return normalize(samples, 0.12, 0.60);
}

function renderMatchVoiceHit() {
  return wave(renderSamples());
}

function generateMatchVoiceHit(root = path.resolve(__dirname, '..')) {
  const destination = path.join(root, DESTINATION);
  const bytes = renderMatchVoiceHit();
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (!fs.existsSync(destination) || !fs.readFileSync(destination).equals(bytes)) fs.writeFileSync(destination, bytes);
  importMetadata(destination, DESTINATION);
  return bytes;
}

if (require.main === module) {
  const bytes = generateMatchVoiceHit();
  console.log(JSON.stringify({ file: DESTINATION, seconds: SECONDS, sampleRate: RATE, channels: 1,
    bytes: bytes.length, ...statistics(renderSamples()), recommendedGain: RUNTIME_GAIN }));
}

module.exports = { DESTINATION, SECONDS, RUNTIME_GAIN, renderSamples, renderMatchVoiceHit, generateMatchVoiceHit };
