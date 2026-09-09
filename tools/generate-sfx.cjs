const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const sampleRate = 22050;
const tau = 2 * Math.PI;

function melody(frequencies, {
  step = 0.16, noteDuration = 0.34, timbre = 'spring', gain = 0.11,
  attack = 0.025, release = 0.22, decay = 0.6
} = {}) {
  const notes = frequencies.map((frequency, index) => ({
    frequency, start: 0.025 + index * step, duration: noteDuration,
    timbre, gain, attack, release, decay
  }));
  return { duration: notes.at(-1).start + noteDuration + 0.045, notes };
}

const sounds = {
  select: melody([659.25], {
    noteDuration: 0.14, gain: 0.07, attack: 0.01, release: 0.07, decay: 0.8
  }),
  correct: melody([523.25, 659.25, 783.99], {
    step: 0.15, noteDuration: 0.28, gain: 0.12, release: 0.16, decay: 0.8
  }),
  wrong: melody([349.23, 293.66], {
    step: 0.23, noteDuration: 0.33, timbre: 'autumn', gain: 0.09, release: 0.20
  }),
  loss: melody([392, 329.63, 261.63], {
    step: 0.24, noteDuration: 0.42, timbre: 'autumn', gain: 0.09, attack: 0.03, release: 0.27
  })
};

const themes = {
  spring: {
    frequencies: [659.25, 783.99, 987.77, 1318.51],
    voice: { timbre: 'spring', gain: 0.11, attack: 0.025, release: 0.22, decay: 0.5 },
    arrive: { step: 0.15, noteDuration: 0.34 },
    open: { step: 0.18, noteDuration: 0.43 }
  },
  summer: {
    frequencies: [523.25, 659.25, 783.99, 1046.5],
    voice: { timbre: 'summer', gain: 0.11, attack: 0.015, release: 0.12, decay: 0.9 },
    arrive: { step: 0.13, noteDuration: 0.23 },
    open: { step: 0.15, noteDuration: 0.26 }
  },
  autumn: {
    frequencies: [392, 493.88, 587.33, 783.99],
    voice: { timbre: 'autumn', gain: 0.12, attack: 0.025, release: 0.22, decay: 0.6 },
    arrive: { step: 0.17, noteDuration: 0.38 },
    open: { step: 0.18, noteDuration: 0.45 }
  },
  winter: {
    frequencies: [783.99, 1046.5, 1174.66, 1567.98],
    voice: { timbre: 'winter', gain: 0.14, attack: 0.015, release: 0.38, decay: 2.4 },
    arrive: { step: 0.17, noteDuration: 0.54 },
    open: { step: 0.18, noteDuration: 0.61 }
  },
  ocean: {
    frequencies: [440, 554.37, 659.25, 880],
    voice: { timbre: 'spring', gain: 0.12, attack: 0.04, release: 0.28, decay: 0.65 },
    arrive: { step: 0.18, noteDuration: 0.40 },
    open: { step: 0.19, noteDuration: 0.45 }
  },
  space: {
    frequencies: [587.33, 880, 1174.66, 1479.98],
    voice: { timbre: 'winter', gain: 0.12, attack: 0.025, release: 0.31, decay: 1.4 },
    arrive: { step: 0.15, noteDuration: 0.43 },
    open: { step: 0.18, noteDuration: 0.53 }
  }
};

for (const [id, theme] of Object.entries(themes)) {
  sounds[`${id}-arrive`] = melody(theme.frequencies, { ...theme.voice, ...theme.arrive });
  const opening = [...theme.frequencies, ...theme.frequencies.slice(0, -1).reverse()];
  sounds[`${id}-open`] = melody(opening, { ...theme.voice, ...theme.open });
}

function tone(note, time) {
  let phase = tau * note.frequency * time;
  switch (note.timbre) {
    case 'spring':
      phase += note.frequency * 0.0035 / 5.2 * (1 - Math.cos(tau * 5.2 * time));
      return Math.sin(phase);
    case 'summer':
      // A short, softened triangle, without the high-frequency corners.
      return 8 / (Math.PI ** 2) * (
        Math.sin(phase) - Math.sin(3 * phase) / 9 +
        Math.sin(5 * phase) / 25 - Math.sin(7 * phase) / 49
      );
    case 'autumn':
      return (Math.sin(phase) + 0.12 * Math.sin(2 * phase)) / 1.12;
    case 'winter':
      return (
        Math.sin(phase) + 0.09 * Math.sin(3 * phase) * Math.exp(-4 * time) +
        0.04 * Math.sin(4 * phase) * Math.exp(-6 * time)
      ) / 1.13;
    default:
      throw new Error(`Unknown SFX timbre: ${note.timbre}`);
  }
}

function makeWave(sound) {
  assert.ok(Number.isFinite(sound.duration) && sound.duration > 0, 'Invalid sound duration.');
  assert.ok(Array.isArray(sound.notes) && sound.notes.length > 0, 'A sound needs notes.');
  const samples = new Float64Array(Math.ceil(sound.duration * sampleRate));

  for (const note of sound.notes) {
    assert.ok(Number.isFinite(note.frequency) && note.frequency > 0 && note.frequency < sampleRate / 2, 'Invalid note frequency.');
    assert.ok(Number.isFinite(note.start) && note.start >= 0, 'Invalid note start.');
    assert.ok(Number.isFinite(note.duration) && note.duration > 0, 'Invalid note duration.');
    assert.ok(Number.isFinite(note.gain) && note.gain >= 0, 'Invalid note gain.');
    assert.ok(Number.isFinite(note.decay) && note.decay >= 0, 'Invalid note decay.');
    assert.ok(Number.isFinite(note.attack) && note.attack > 0 &&
      Number.isFinite(note.release) && note.release > 0 &&
      note.attack + note.release <= note.duration, 'Invalid note envelope.');
    const start = Math.round(note.start * sampleRate);
    const count = Math.max(2, Math.round(note.duration * sampleRate));
    assert.ok(start + count <= samples.length, 'Note exceeds the sound duration.');
    const attackSamples = Math.max(1, Math.round(note.attack * sampleRate));
    const releaseSamples = Math.max(1, Math.round(note.release * sampleRate));

    for (let index = 0; index < count; index += 1) {
      const time = index / sampleRate;
      const attack = Math.sin(Math.min(1, index / attackSamples) * Math.PI / 2) ** 2;
      const release = Math.sin(Math.min(1, (count - 1 - index) / releaseSamples) * Math.PI / 2) ** 2;
      const envelope = attack * release * Math.exp(-note.decay * time / note.duration);
      samples[start + index] += note.gain * envelope * tone(note, time);
    }
  }

  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  assert.ok(Number.isFinite(peak) && peak < 0.9, `SFX float peak ${peak} must be below 0.9; refusing to clip.`);

  const wave = Buffer.alloc(44 + samples.length * 2);
  wave.write('RIFF', 0, 4, 'ascii');
  wave.writeUInt32LE(wave.length - 8, 4);
  wave.write('WAVE', 8, 4, 'ascii');
  wave.write('fmt ', 12, 4, 'ascii');
  wave.writeUInt32LE(16, 16);
  wave.writeUInt16LE(1, 20);
  wave.writeUInt16LE(1, 22);
  wave.writeUInt32LE(sampleRate, 24);
  wave.writeUInt32LE(sampleRate * 2, 28);
  wave.writeUInt16LE(2, 32);
  wave.writeUInt16LE(16, 34);
  wave.write('data', 36, 4, 'ascii');
  wave.writeUInt32LE(samples.length * 2, 40);
  for (let index = 0; index < samples.length; index += 1) {
    wave.writeInt16LE(Math.round(samples[index] * 32767), 44 + index * 2);
  }
  return wave;
}

if (require.main === module) {
  const outputDirectory = path.join(__dirname, '..', 'assets', 'audio', 'sfx');
  const outputs = Object.entries(sounds).map(([id, sound]) => [id, makeWave(sound)]);
  fs.mkdirSync(outputDirectory, { recursive: true });
  for (const [id, wave] of outputs) {
    fs.writeFileSync(path.join(outputDirectory, `${id}.wav`), wave);
  }
  console.log(`Generated ${outputs.length} original SFX WAVs (22050 Hz, PCM16 mono).`);
}

module.exports = { sounds, makeWave };
