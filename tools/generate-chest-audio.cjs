#!/usr/bin/env node
'use strict';

// Original procedural Foley. Every noise source is seeded, and each material
// has its own resonant modes, friction, air and contact layers. No recordings
// or third-party samples are used. Regenerate with node tools/generate-chest-audio.cjs.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const RATE = 22050;
const TAU = Math.PI * 2;
const THEMES = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const CUES = { press: 0.19, charge: 0.8, step: 0.24, 'step-detail': 0.24, 'step-roll': 0.24, cancel: 0.22, opening: 0.24, unlock: 0.31, release: 0.68, settle: 0.48, reward: 0.74 };
const MATERIALS = {
  spring: 'Hollow wood, dry leaf movement and a soft flower bell',
  summer: 'Warm airflow, a cork-like pop and a bright rounded release',
  autumn: 'Heavy wood, a metal latch, a strained hinge and a settled lid',
  winter: 'Glass contact and inharmonic crystal resonance',
  ocean: 'Muffled pressure, rising bubbles and a receding wave',
  space: 'A small servo, magnetic latch and a filtered airlock release',
  jungle: 'Tensioned vine creak, hollow wood and coarse leaves',
  candy: 'Elastic squash, a soft pop and scattered sugar grains'
};
const BODY_FREQUENCIES = { spring: 112, summer: 98, autumn: 82, winter: 128, ocean: 78, space: 90, jungle: 102, candy: 118 };
const PAYOFF_PROFILES = {
  spring: { note: 523.25, air: 0.46, cutoff: 3600, shimmer: 0.15, spread: 0.006 },
  summer: { note: 587.33, air: 0.76, cutoff: 4600, shimmer: 0.13, spread: 0.008 },
  autumn: { note: 392.00, air: 0.40, cutoff: 2700, shimmer: 0.12, spread: 0.014 },
  winter: { note: 783.99, air: 0.42, cutoff: 5200, shimmer: 0.21, spread: 0.004 },
  ocean: { note: 392.00, air: 0.62, cutoff: 1800, shimmer: 0.17, spread: 0.010 },
  space: { note: 440.00, air: 0.69, cutoff: 4100, shimmer: 0.16, spread: 0.012 },
  jungle: { note: 493.88, air: 0.57, cutoff: 2900, shimmer: 0.12, spread: 0.016 },
  candy: { note: 659.25, air: 0.39, cutoff: 3800, shimmer: 0.20, spread: 0.008 }
};

function random(seed) {
  let state = 2166136261;
  for (const c of seed) state = Math.imul(state ^ c.charCodeAt(0), 16777619) >>> 0;
  return () => {
    state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
    return (state >>> 0) / 4294967296;
  };
}

function envelope(time, duration, attack = 0.008, decay = 5) {
  if (time < 0 || time >= duration) return 0;
  return Math.min(1, time / attack) * Math.exp(-time * decay / duration) * Math.min(1, (duration - time) / 0.035);
}

function renderTensionTexture(theme) {
  // Sustained material pressure has no repeating attack or rhythmic envelope.
  // Runtime pitch and gain supply the rise; the shared visual timeline owns
  // every audible strike, so the bed cannot introduce a competing pulse.
  const profiles = {
    spring: { base: 360, modes: [1, 2.79, 5.16], air: 0.36, cutoff: 1800, rough: 0 },
    summer: { base: 240, modes: [1, 2, 3.8], air: 0.75, cutoff: 2200, rough: 0 },
    autumn: { base: 210, modes: [1, 2.79, 5.16], air: 0.36, cutoff: 1100, rough: 0.1 },
    winter: { base: 680, modes: [1, 2.83, 4.59], air: 0.3, cutoff: 3200, rough: 0 },
    ocean: { base: 140, modes: [1, 1.96, 3.28], air: 0.8, cutoff: 500, rough: 0 },
    space: { base: 310, modes: [1, 3.27, 5.82], air: 0.4, cutoff: 1750, rough: 0.22 },
    jungle: { base: 260, modes: [1, 2.79, 5.16], air: 0.55, cutoff: 1300, rough: 0.3 },
    candy: { base: 330, modes: [1, 2, 3], air: 0.38, cutoff: 950, rough: 0.08 }
  };
  const profile = profiles[theme];
  const samples = new Float64Array(Math.round(RATE * CUES.charge));
  const rng = random(`${theme}/steady-pressure/v2`);
  const alpha = 1 - Math.exp(-TAU * profile.cutoff / RATE);
  let filtered = 0;
  let sum = 0;
  let peak = 0;
  for (let i = 0; i < samples.length; i++) {
    const time = i / RATE;
    filtered += alpha * (rng() * 2 - 1 - filtered);
    const body = profile.modes.reduce((value, ratio, index) => {
      const frequency = Math.round(profile.base * ratio * CUES.charge) / CUES.charge;
      return value + Math.sin(TAU * frequency * time + profile.rough * Math.sin(TAU * 45 * time)) / (1 + index * 3.2);
    }, 0);
    const seam = Math.min(1, i / (RATE * 0.004), (samples.length - 1 - i) / (RATE * 0.008));
    // Friction and pressure rise above the body hits without turning their
    // low resonance into an increasingly small, high-pitched toy sound.
    samples[i] = (body * 0.075 + filtered * profile.air) * seam;
    sum += samples[i] * samples[i];
    peak = Math.max(peak, Math.abs(samples[i]));
  }
  const gain = Math.min(0.12 / Math.sqrt(sum / samples.length), 0.72 / peak);
  for (let i = 0; i < samples.length; i++) samples[i] *= gain;
  return samples;
}

function render(theme, cue) {
  assert.ok(THEMES.includes(theme) && Object.hasOwn(CUES, cue));
  if (cue === 'charge') return renderTensionTexture(theme);
  const duration = CUES[cue];
  const samples = new Float64Array(Math.round(RATE * duration));
  const rng = random(`${theme}/${cue}/v1`);
  const strike = cue.startsWith('step');
  const strikeStage = ['step', 'step-detail', 'step-roll'].indexOf(cue);
  const force = { press: 0.62, charge: 0.45, step: 0.62, cancel: 0.42, opening: 0.45, unlock: 0.9, release: 0.82, settle: 0.63, reward: 0.75 }[strike ? 'step' : cue];
  const opening = ['opening', 'release', 'charge'].includes(cue);
  const reward = cue === 'reward';
  const settle = cue === 'settle' || cue === 'cancel';

  function layer(start, seconds, gain, signal) {
    const count = Math.min(Math.round(seconds * RATE), samples.length - Math.round(start * RATE));
    for (let i = 0; i < count; i++) samples[Math.round(start * RATE) + i] += signal(i / RATE, i) * gain * force;
  }
  function modes(start, seconds, frequencies, gain, decay = 6) {
    const phases = frequencies.map(() => rng() * 0.5);
    layer(start, seconds, gain, (t) => frequencies.reduce((sum, f, i) =>
      sum + Math.sin(TAU * f * t + phases[i]) * Math.exp(-t * i * 8) / (1 + i * 1.9), 0) * envelope(t, seconds, 0.002, decay));
  }
  function noise(start, seconds, gain, cutoff, attack = 0.012, decay = 3, roughness = 0) {
    let low = 0;
    const alpha = 1 - Math.exp(-TAU * cutoff / RATE);
    layer(start, seconds, gain, (t) => {
      low += alpha * ((rng() * 2 - 1) - low);
      const rub = 1 - roughness * 0.5 + roughness * 0.5 * Math.sin(TAU * (28 + 5 * Math.sin(t * 11)) * t);
      return low * rub * envelope(t, seconds, attack, decay);
    });
  }
  function sweep(start, seconds, gain, frequency, target, decay = 5, rough = 0) {
    layer(start, seconds, gain, (t) => {
      const phase = TAU * (frequency * t + (target - frequency) * t * t / (2 * seconds));
      return (Math.sin(phase + rough * Math.sin(TAU * 39 * t)) + 0.13 * Math.sin(phase * 2.12)) * envelope(t, seconds, 0.007, decay);
    });
  }
  function leaves(start, seconds, gain, count = 5) {
    for (let i = 0; i < count; i++) noise(start + rng() * seconds * 0.65, 0.028 + rng() * 0.042, gain, 1800 + rng() * 2300, 0.004, 3, 0.8);
  }
  function wood(base, gain = 0.5) {
    modes(0.004, Math.min(duration, 0.27), [base, base * 2.79, base * 5.16], gain, 7);
    noise(0, 0.045, 0.2, 2400, 0.001, 6);
  }
  function metal(base, gain, seconds = 0.28, start = 0.004) {
    modes(start, Math.min(seconds, duration - start), [base, base * 1.51, base * 2.17, base * 3.73], gain, 5);
    noise(start, 0.023, gain * 0.8, 5400, 0.001, 5);
  }
  function bells(base, gain) {
    for (let i = 0; i < (reward ? 3 : 1); i++) {
      const start = reward ? 0.045 + i * 0.13 : 0.008;
      modes(start, duration - start, [base * [1, 1.25, 1.5][i], base * [2.76, 3.42, 4.17][i]], gain, 3.5);
    }
  }
  function bodyImpact(base, gain) {
    const seconds = 0.19;
    layer(0, seconds, gain, (t) => {
      const pressure = Math.min(1, t / 0.018) * Math.exp(-t / 0.041);
      const phase = TAU * base * t;
      // Low-mid harmonics retain physical weight on small phone speakers.
      const body = Math.sin(phase) + 0.55 * Math.sin(phase * 2.03) + 0.22 * Math.sin(phase * 3.81);
      return body * pressure * Math.min(1, t / 0.002) * Math.min(1, (seconds - t) / 0.045);
    });
  }
  function weightedContact(start, seconds, base, gain, decay) {
    layer(start, seconds, gain, (t) => {
      // A fast load and tiny downward pitch relaxation read as a solid cavity.
      // The second through sixth harmonics carry weight on phone speakers too.
      const phase = TAU * base * (t + 0.13 * 0.025 * (1 - Math.exp(-t / 0.025)));
      const body = Math.sin(phase) + 0.72 * Math.sin(phase * 2.03)
        + 0.38 * Math.sin(phase * 3.97) + 0.15 * Math.sin(phase * 6.13);
      const pressure = Math.min(1, t / 0.004) * Math.exp(-t / decay);
      return body * pressure * Math.min(1, (seconds - t) / 0.045);
    });
  }

  function bloom(start, seconds, gain, cutoff) {
    // A broad expanding pressure cloud gives the contact room to open into.
    // Its soft front avoids introducing a second strike after the latch crack.
    let low = 0;
    let dark = 0;
    const alpha = 1 - Math.exp(-TAU * cutoff / RATE);
    const darkAlpha = 1 - Math.exp(-TAU * 360 / RATE);
    layer(start, seconds, gain, (t) => {
      const white = rng() * 2 - 1;
      low += alpha * (white - low);
      dark += darkAlpha * (low - dark);
      const swell = (1 - Math.exp(-t / 0.028)) * Math.exp(-t / 0.20);
      return (low - dark * 0.72) * swell * Math.min(1, (seconds - t) / 0.085);
    });
  }

  function shimmer(start, seconds, base, gain, spread, attack = 0.022) {
    // Detuned modal clusters sound like resonant material catching the light,
    // not a sustained oscillator or a sequence of electronic notification beeps.
    const ratios = [1, 1.498, 2.008, 2.756, 3.73];
    const phases = ratios.map(() => rng() * TAU);
    layer(start, seconds, gain, (t) => {
      let sound = 0;
      for (let index = 0; index < ratios.length; index++) {
        const phase = TAU * base * ratios[index] * t + phases[index];
        const cluster = Math.sin(phase) + 0.38 * Math.sin(phase * (1 + spread));
        sound += cluster * Math.exp(-t * index * 1.7) / (1 + index * 1.8);
      }
      const swell = (1 - Math.exp(-t / attack)) * Math.exp(-t / 0.25);
      return sound * swell * Math.min(1, (seconds - t) / 0.095);
    });
  }

  function heldBreath() {
    samples.fill(0);
    let air = 0;
    layer(0, duration, 1.0, (t) => {
      // Close the air and pressure over the same 60 ms as the motion brake.
      // The remaining quiet texture holds its breath until the release cue.
      const progress = Math.min(1, t / 0.060);
      const remaining = (1 - progress) ** 2;
      const alpha = 1 - Math.exp(-TAU * (420 + 1880 * remaining) / RATE);
      air += alpha * (rng() * 2 - 1 - air);
      const base = BODY_FREQUENCIES[theme] * 2.3;
      const phase = TAU * base * t;
      const texture = air * 0.72 + Math.sin(phase) * 0.12 + Math.sin(phase * 1.51) * 0.045;
      return texture * (0.025 + 0.975 * remaining) * Math.min(1, t / 0.006) * Math.min(1, (duration - t) / 0.014);
    });
  }

  switch (theme) {
    case 'spring':
      wood(settle ? 174 : 246, settle ? 0.44 : 0.32);
      leaves(0.025, duration * 0.7, opening ? 0.34 : 0.19, opening ? 8 : 4);
      if (reward || cue === 'unlock') bells(1046.5, reward ? 0.2 : 0.11);
      break;
    case 'summer':
      noise(0, duration * 0.94, opening ? 0.66 : 0.29, 2200, opening ? 0.04 : 0.008, 2.4);
      sweep(0.006, Math.min(duration, 0.19), 0.44, settle ? 300 : 540, settle ? 100 : 155, 6);
      if (reward) bells(784, 0.19);
      break;
    case 'autumn':
      wood(settle ? 102 : 154, 0.6);
      if (opening) {
        sweep(0.026, duration * 0.8, 0.16, 310, 180, 1.9, 1.6);
        noise(0.012, duration * 0.86, 0.36, 1600, 0.024, 2, 0.9);
      }
      if (cue === 'unlock' || strike || reward) metal(680, 0.2);
      if (settle) modes(0.065, duration - 0.065, [92, 221, 511], 0.21, 8);
      if (reward) bells(523.25, 0.11);
      break;
    case 'winter':
      metal(settle ? 980 : 1370, 0.25, duration * 0.9);
      modes(0.005, duration - 0.005, [510, 1445, 2339, 3721], 0.22, 2.1);
      noise(0, Math.min(0.11, duration), 0.15, 5600, 0.002, 5);
      if (opening) noise(0.024, duration * 0.83, 0.13, 3100, 0.04, 1.9);
      if (reward) bells(1046.5, 0.16);
      break;
    case 'ocean':
      noise(0, duration * 0.98, opening ? 0.75 : 0.42, 380, 0.018, 2);
      modes(0.003, Math.min(0.3, duration), [78, 153, 256], 0.35, 4);
      for (let i = 0; i < (opening || reward ? 4 : 2); i++) {
        const start = 0.018 + i * duration * 0.13;
        sweep(start, Math.min(0.15, duration - start), 0.16, 290 + i * 65, 730 + i * 100, 5);
      }
      if (reward) modes(0.13, duration - 0.13, [392, 587.33], 0.11, 3);
      break;
    case 'space':
      modes(0.003, Math.min(duration, 0.14), [122, 399, 820], 0.33, 9);
      if (opening || reward) {
        // Motor teeth and a filtered pressure hiss, not an electronic melody.
        layer(0.016, duration * 0.85, 0.2, (t) => (Math.sin(TAU * (115 * t + 110 * t * t)) + 0.22 * Math.sin(TAU * 710 * t)) *
          (0.65 + 0.35 * Math.sin(TAU * 47 * t)) * envelope(t, duration * 0.85, 0.026, 1.8));
        noise(0.014, duration * 0.9, cue === 'release' ? 0.61 : 0.25, 1750, 0.026, 2.4);
      }
      if (cue === 'unlock' || strike) metal(890, 0.22, 0.08);
      if (reward) modes(0.23, duration - 0.23, [330, 495], 0.14, 4);
      break;
    case 'jungle':
      wood(settle ? 113 : 193, 0.5);
      sweep(0.017, duration * 0.8, opening ? 0.21 : 0.12, 245, settle ? 103 : 410, 2.8, 2.2);
      noise(0.025, duration * 0.8, 0.29, 1300, 0.016, 2.8, 0.9);
      leaves(0.013, duration * 0.68, 0.34, opening ? 8 : 3);
      if (reward) modes(0.2, duration - 0.2, [392, 786, 1780], 0.19, 5);
      break;
    case 'candy':
      sweep(0.004, Math.min(duration, 0.25), 0.43, settle ? 370 : 185, settle ? 95 : 480, 3, 0.3);
      noise(0.01, Math.min(duration, 0.17), 0.28, 950, 0.009, 3);
      if (cue === 'release' || cue === 'unlock' || reward) {
        sweep(0.055, 0.14, 0.3, 650, 140, 8);
        leaves(0.1, duration * 0.7, 0.19, 12);
      }
      if (reward) bells(830.61, 0.13);
      break;
  }

  if (strike) {
    // Layer in rim resonance, strained material and a brighter air edge as
    // tension grows. Every stage retains the same grounded body frequency.
    for (let i = 0; i < samples.length; i++) {
      const tail = ['winter', 'ocean', 'candy'].includes(theme)
        ? Math.exp(-Math.max(0, i / RATE - 0.018) * 26) : 1;
      samples[i] *= [0.38, 0.52, 0.58][strikeStage] * tail;
    }
    bodyImpact(BODY_FREQUENCIES[theme], strikeStage === 2 ? 0.91 : 0.82);
    noise(0, 0.025, 0.12, 2000, 0.001, 5);
    if (strikeStage >= 1) {
      modes(0.007, 0.125, [BODY_FREQUENCIES[theme] * 3.1, BODY_FREQUENCIES[theme] * 6.4], 0.17, 3.4);
      noise(0.012, 0.13, 0.32, 3200, 0.012, 3.0, 0.35);
    }
    if (strikeStage === 2) {
      noise(0.002, 0.145, 0.65, 5700, 0.010, 2.7);
      modes(0.010, 0.13, [BODY_FREQUENCIES[theme] * 8.3, BODY_FREQUENCIES[theme] * 13.7], 0.13, 3.5);
    }
  } else if (cue === 'opening') {
    heldBreath();
  } else if (cue === 'release') {
    // Keep the loaded contact, then open its sound into air and material light.
    // The body lands first; the 0.5-second bloom is its expanding payoff.
    const payoff = PAYOFF_PROFILES[theme];
    for (let i = 0; i < samples.length; i++) samples[i] *= 0.42;
    const base = Math.max(86, BODY_FREQUENCIES[theme]);
    weightedContact(0, 0.36, base, 1.10, 0.085);
    noise(0, 0.024, 0.60, theme === 'ocean' ? 2900 : 5200, 0.0008, 5.0);
    modes(0.006, 0.20, [base * 3.1, base * 5.97, base * 9.04], 0.22, 4.0);
    bloom(0.014, 0.57, payoff.air * 1.9, payoff.cutoff);
    shimmer(0.018, 0.58, payoff.note, payoff.shimmer * 1.85, payoff.spread);
  } else if (reward) {
    // A short resolving gesture is reserved for the saved reward. Staggered
    // material overtones bloom into a consonant fifth, rather than another hit.
    const payoff = PAYOFF_PROFILES[theme];
    for (let i = 0; i < samples.length; i++) samples[i] *= 0.48;
    modes(0.002, 0.13, [payoff.note * 0.5, payoff.note * 1.007], 0.15, 4.0);
    bloom(0.012, 0.37, payoff.air * 0.18, payoff.cutoff);
    shimmer(0.008, 0.57, payoff.note, 0.28, payoff.spread, 0.009);
    shimmer(0.105, 0.56, payoff.note * 1.25, 0.18, payoff.spread, 0.012);
    shimmer(0.205, 0.50, payoff.note * 1.5, 0.30, payoff.spread, 0.015);
  } else if (cue === 'settle') {
    // A quieter mechanical stop and a small damped return anchor the lid.
    // Keep theme detail, but avoid a second long release or reward-like chime.
    for (let i = 0; i < samples.length; i++) samples[i] *= 0.28 * Math.exp(-Math.max(0, i / RATE - 0.025) * 22);
    const base = Math.max(90, BODY_FREQUENCIES[theme] * 1.10);
    weightedContact(0, 0.19, base, 0.80, 0.042);
    weightedContact(0.065, 0.13, base * 0.94, 0.19, 0.028);
    noise(0, 0.019, 0.18, 2400, 0.001, 6.0);
  }

  if (cue === 'release' || cue === 'settle' || reward) {
    // Gentle saturation leaves headroom for the contact and resolving layers.
    for (let i = 0; i < samples.length; i++) samples[i] = 0.8 * Math.tanh(samples[i] / 0.8);
  }
  // Remove any DC bias and taper both boundaries. A looping charge asset has
  // the same zero-value seam as its one-shot siblings, without an audible click.
  const mean = samples.reduce((sum, value) => sum + value, 0) / samples.length;
  let maximum = 0;
  for (let i = 0; i < samples.length; i++) {
    const fade = Math.min(1, i / (RATE * 0.003), (samples.length - 1 - i) / (RATE * 0.018));
    samples[i] = (samples[i] - mean) * fade;
    maximum = Math.max(maximum, Math.abs(samples[i]));
  }
  if (maximum > 0.78) for (let i = 0; i < samples.length; i++) samples[i] *= 0.78 / maximum;
  if (strike || cue === 'release' || cue === 'settle' || cue === 'opening' || reward) {
    // Equal material-strike energy lets the shared crescendo read on every
    // theme, including the otherwise very quiet magnetic and flower locks.
    const rms = Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) / samples.length);
    const target = cue === 'release' ? 0.17 : reward ? 0.12 : cue === 'settle' ? 0.085 : cue === 'opening' ? 0.055 : [0.07, 0.075, 0.082][strikeStage];
    const gain = Math.min(target / rms, 0.78 / Math.min(maximum, 0.78));
    for (let i = 0; i < samples.length; i++) samples[i] *= gain;
  }
  return samples;
}

function wav(samples) {
  const buffer = Buffer.alloc(44 + samples.length * 2);
  buffer.write('RIFF'); buffer.writeUInt32LE(buffer.length - 8, 4); buffer.write('WAVEfmt ', 8);
  buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(RATE, 24); buffer.writeUInt32LE(RATE * 2, 28); buffer.writeUInt16LE(2, 32); buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36); buffer.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((sample, index) => buffer.writeInt16LE(Math.round(sample * 32767), 44 + index * 2));
  return buffer;
}

function generate(output = path.resolve(__dirname, '../assets/audio/chests')) {
  fs.mkdirSync(output, { recursive: true });
  const report = [];
  for (const theme of THEMES) for (const cue of Object.keys(CUES)) {
    const samples = render(theme, cue);
    const bytes = wav(samples);
    const peak = samples.reduce((max, value) => Math.max(max, Math.abs(value)), 0);
    const rms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
    assert.ok(peak > 0.03 && peak < 0.8 && rms > 0.008 && rms < 0.2, `${theme}/${cue} has invalid dynamics`);
    assert.equal(Math.abs(samples[0]), 0); assert.equal(Math.abs(samples.at(-1)), 0);
    fs.writeFileSync(path.join(output, `${theme}-${cue}.wav`), bytes);
    report.push({ theme, cue, duration: samples.length / RATE, bytes: bytes.length, peak, rms, sha256: crypto.createHash('sha256').update(bytes).digest('hex') });
  }
  assert.equal(new Set(report.map((entry) => entry.sha256)).size, report.length, 'All material cues must be distinct');
  return report;
}

if (require.main === module) {
  const report = generate();
  console.log(`Generated ${report.length} original material cues (${report.reduce((sum, cue) => sum + cue.bytes, 0).toLocaleString()} bytes).`);
  if (process.argv.includes('--report')) console.log(JSON.stringify({ materials: MATERIALS, assets: report }, null, 2));
}
module.exports = { RATE, THEMES, CUES, MATERIALS, render, wav, generate };
