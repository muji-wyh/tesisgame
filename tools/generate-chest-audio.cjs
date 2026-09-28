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
const CUES = { press: 0.19, charge: 0.44, step: 0.24, cancel: 0.22, opening: 0.24, unlock: 0.31, release: 0.68, settle: 0.48, reward: 0.74 };
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

function render(theme, cue) {
  assert.ok(THEMES.includes(theme) && Object.hasOwn(CUES, cue));
  const duration = CUES[cue];
  const samples = new Float64Array(Math.round(RATE * duration));
  const rng = random(`${theme}/${cue}/v1`);
  const force = { press: 0.62, charge: 0.45, step: 0.62, cancel: 0.42, opening: 0.45, unlock: 0.9, release: 0.82, settle: 0.63, reward: 0.75 }[cue];
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

  switch (theme) {
    case 'spring':
      wood(settle ? 174 : 246, settle ? 0.44 : 0.32);
      leaves(0.025, duration * 0.7, opening ? 0.34 : 0.19, opening ? 8 : 4);
      if (reward || cue === 'unlock' || cue === 'release') bells(1046.5, reward ? 0.2 : 0.11);
      break;
    case 'summer':
      noise(0, duration * 0.94, opening ? 0.66 : 0.29, 2200, opening ? 0.04 : 0.008, 2.4);
      sweep(0.006, Math.min(duration, 0.19), 0.44, settle ? 300 : 540, settle ? 100 : 155, 6);
      if (reward || cue === 'release') bells(784, 0.19);
      break;
    case 'autumn':
      wood(settle ? 102 : 154, 0.6);
      if (opening) {
        sweep(0.026, duration * 0.8, 0.16, 310, 180, 1.9, 1.6);
        noise(0.012, duration * 0.86, 0.36, 1600, 0.024, 2, 0.9);
      }
      if (cue === 'unlock' || cue === 'step' || reward) metal(680, 0.2);
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
      if (cue === 'unlock' || cue === 'step') metal(890, 0.22, 0.08);
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
