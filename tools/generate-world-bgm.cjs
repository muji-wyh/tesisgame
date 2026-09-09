const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { makeWave } = require('./generate-sfx.cjs');

// Original 16-beat tunes. Reuse the gently enveloped SFX voices at a lower register.
const scores = {
  ocean: {
    timbre: 'spring',
    melody: [69, 73, 76, 73, 71, 73, 76, 78, 76, 73, 71, 68, 69, 73, 71, 69],
    bass: [45, 50, 52, 45]
  },
  space: {
    timbre: 'winter',
    melody: [74, 78, 81, 86, 81, 78, 76, 81, 78, 74, 73, 78, 76, 73, 69, 74],
    bass: [50, 54, 45, 50]
  }
};

function soundtrack(id) {
  const score = scores[id];
  if (!score) throw new Error(`Unknown world soundtrack: ${id}`);
  const beat = 0.6;
  const notes = [];
  for (let bar = 0; bar < 2; bar++) {
    for (let index = 0; index < score.melody.length; index++) {
      notes.push({
        frequency: 440 * 2 ** ((score.melody[index] - 69) / 12),
        start: 0.08 + (bar * 16 + index) * beat, duration: 0.5,
        timbre: score.timbre, gain: 0.065, attack: 0.045, release: 0.28, decay: 1.1
      });
      if (index % 4 === 0) {
        for (const interval of [0, 7]) {
          notes.push({
            frequency: 440 * 2 ** ((score.bass[index / 4] + interval - 69) / 12),
            start: 0.08 + (bar * 16 + index) * beat, duration: 2.18,
            timbre: 'autumn', gain: 0.025, attack: 0.22, release: 0.65, decay: 0.6
          });
        }
      }
    }
  }
  return { duration: 19.2, notes };
}

function generateWorldBgm() {
  const output = path.join(__dirname, '..', 'assets', 'audio', 'bgm');
  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'word-buddies-bgm-'));
  try {
    for (const id of Object.keys(scores)) {
      const destination = path.join(staging, `${id}.wav`);
      const result = spawnSync('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-nostdin', '-n', '-i', 'pipe:0',
        '-ac', '2', '-ar', '44100', '-c:a', 'pcm_s16le', '-map_metadata', '-1',
        '-fflags', '+bitexact', destination
      ], { input: makeWave(soundtrack(id)), windowsHide: true, timeout: 30000 });
      if (result.error) throw result.error;
      if (result.status !== 0) throw new Error(`BGM conversion failed: ${result.stderr.toString().trim()}`);
    }
    fs.mkdirSync(output, { recursive: true });
    for (const id of Object.keys(scores)) fs.copyFileSync(path.join(staging, `${id}.wav`), path.join(output, `${id}.wav`));
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
  console.log('Generated two original world soundtracks (44100 Hz, PCM16 stereo).');
}

if (require.main === module) generateWorldBgm();
module.exports = { soundtrack, generateWorldBgm };
