const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { RATE, normalize, statistics, wave, importMetadata } = require('./import-pop-reference.cjs');

const TAU = Math.PI * 2;
const CUES = Object.freeze({
  launch: { seconds: 0.24, gain: 0.50, rms: 0.18, seed: 0x514c4155 },
  impact: { seconds: 0.36, gain: 0.50, rms: 0.18, seed: 0x51484954 },
  defeat: { seconds: 0.90, gain: 0.55, rms: 0.17, seed: 0x51454e44 },
});

function envelope(time, start, duration, attack, release, decay = 0) {
  const age = time - start;
  if (age < 0 || age >= duration) return 0;
  return Math.sin(Math.min(1, age / attack) * Math.PI / 2) ** 2 *
    Math.sin(Math.min(1, (duration - age) / release) * Math.PI / 2) ** 2 * Math.exp(-age * decay);
}

function noiseSource(seed) {
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 2147483648 - 1;
  };
}

function lowpass(hz) {
  const coefficient = 1 - Math.exp(-TAU * hz / RATE);
  let previous = 0;
  return value => (previous += coefficient * (value - previous));
}

function renderSamples(id) {
  const cue = CUES[id];
  if (!cue) throw new Error(`Unknown Talk Quest audio cue: ${id}`);
  const samples = new Float64Array(Math.round(cue.seconds * RATE));
  const noise = noiseSource(cue.seed);
  const airFilter = lowpass(3600), noiseBodyFilter = lowpass(380);
  const smoothA = lowpass(4200), smoothB = lowpass(4200), dcFilter = lowpass(30);
  let phase = 0, bodyPhase = 0;
  for (let index = 0; index < samples.length; index++) {
    const time = index / RATE;
    const air = airFilter(noise());
    const grain = air - noiseBodyFilter(air);
    let value = 0;
    if (id === 'launch') {
      // A warm moving core and a soft, rising air rush make a magic projectile,
      // with a rounded FM tip instead of a brittle sawtooth or weapon report.
      phase += TAU * (410 + 660 * Math.exp(-time / 0.064)) / RATE;
      bodyPhase += TAU * (220 + 125 * Math.sin(Math.min(1, time / 0.18) * Math.PI / 2)) / RATE;
      const motion = envelope(time, 0, cue.seconds, 0.018, 0.090);
      const tip = Math.sin(phase + 0.8 * Math.exp(-time / 0.048) * Math.sin(TAU * 170 * time));
      value = (0.30 * Math.sin(bodyPhase) + 0.16 * tip) * motion;
      value += 0.72 * grain * envelope(time, 0.007, 0.205, 0.062, 0.095);
    } else if (id === 'impact') {
      // A low, rounded thump stays audible on phone speakers. Short filtered
      // grains add contact, followed by two quiet pitched sparks.
      bodyPhase += TAU * (165 + 100 * Math.exp(-time / 0.032)) / RATE;
      value = 0.65 * Math.sin(bodyPhase) * envelope(time, 0, 0.33, 0.004, 0.095, 8.0);
      value += 0.23 * Math.sin(TAU * 315 * time) * envelope(time, 0.006, 0.25, 0.006, 0.080, 7.0);
      value += 0.75 * grain * envelope(time, 0, 0.12, 0.003, 0.070, 14);
      for (const [start, frequency, gain] of [[0.018, 880, 0.13], [0.047, 1174.66, 0.10]]) {
        const age = time - start;
        value += gain * Math.sin(TAU * frequency * age) * envelope(time, start, 0.27, 0.009, 0.090, 7);
      }
    } else {
      // Three loose, descending pieces suggest a friendly monster crumbling
      // away. An ascending C-major resolve is musical without a spoken prompt.
      for (const [start, frequency, gain] of [[0, 250, 0.40], [0.085, 205, 0.29], [0.185, 170, 0.23]]) {
        const age = time - start;
        const fall = frequency * age + 1.1 * (1 - Math.exp(-Math.max(0, age) / 0.022));
        value += gain * (Math.sin(TAU * fall) + 0.70 * grain) *
          envelope(time, start, 0.32, 0.005, 0.11, 7.0);
      }
      for (const [start, frequency, gain] of [[0.12, 523.25, 0.19], [0.25, 659.25, 0.19], [0.40, 783.99, 0.23]]) {
        const age = time - start;
        const tone = Math.sin(TAU * frequency * age) + 0.10 * Math.sin(TAU * frequency * 2 * age);
        value += gain * tone * envelope(time, start, cue.seconds - start, 0.018, 0.20, 1.8);
      }
    }
    // The gentle saturation reduces crest factor before gain staging; it never
    // hard-clips. Two filters soften the top end, and the final fade reaches zero.
    const smooth = smoothB(smoothA(Math.tanh(value * 1.25)));
    samples[index] = (smooth - dcFilter(smooth)) * envelope(time, 0, cue.seconds, 0.002, 0.030);
  }
  // Remove the remaining finite-window DC with a faded correction. Unlike a
  // constant subtraction, this keeps both file boundaries at exact silence.
  let mean = 0, weight = 0;
  for (let index = 0; index < samples.length; index++) {
    mean += samples[index];
    weight += envelope(index / RATE, 0, cue.seconds, 0.006, 0.035);
  }
  for (let index = 0; index < samples.length; index++) {
    samples[index] -= mean / weight * envelope(index / RATE, 0, cue.seconds, 0.006, 0.035);
  }
  samples[0] = 0;
  samples[samples.length - 1] = 0;
  return normalize(samples, cue.rms, 0.74);
}

function renderQuestAudio(id) {
  return wave(renderSamples(id));
}

function generateQuestAudio(root = path.resolve(__dirname, '..')) {
  return Object.entries(CUES).map(([id, cue]) => {
    const relative = `assets/audio/quest/${id}.wav`;
    const destination = path.join(root, relative);
    const samples = renderSamples(id);
    const bytes = wave(samples);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    if (!fs.existsSync(destination) || !fs.readFileSync(destination).equals(bytes)) fs.writeFileSync(destination, bytes);
    importMetadata(destination, relative);
    return { id, file: relative, seconds: cue.seconds, sampleRate: RATE, channels: 1, bitDepth: 16,
      bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'),
      ...statistics(samples), recommendedGain: cue.gain };
  });
}

if (require.main === module) console.log(JSON.stringify(generateQuestAudio(), null, 2));

module.exports = { CUES, renderSamples, renderQuestAudio, generateQuestAudio };
