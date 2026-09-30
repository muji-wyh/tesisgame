const fs = require('node:fs');
const path = require('node:path');
const { RATE, normalize, wave, importMetadata } = require('./import-pop-reference.cjs');

const DESTINATION = 'assets/audio/sfx/pop-launch.wav';
const SECONDS = 0.22;

function renderLaunch() {
  const samples = new Float64Array(Math.round(RATE * SECONDS));
  let seed = 0x706f7021, low = 0, body = 0, phase = 0;
  for (let index = 0; index < samples.length; index++) {
    const time = index / RATE, progress = index / (samples.length - 1);
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const noise = seed / 2147483648 - 1;
    // An opening low-pass filter lifts the air texture as the word rises.
    // A broad, soft envelope avoids a second cut-like impact at launch.
    low += (noise - low) * (0.065 + 0.26 * progress);
    body += (low - body) * 0.022;
    phase += Math.PI * 2 * (190 + 360 * progress) / RATE;
    const envelope = Math.sin(Math.PI * progress) ** 1.5 * Math.min(1, time / 0.014);
    samples[index] = ((low - body) * 0.92 + Math.sin(phase) * 0.035) * envelope;
  }
  samples[0] = 0;
  samples[samples.length - 1] = 0;
  return wave(normalize(samples, 0.085, 0.45));
}

function generateLaunch(root = path.resolve(__dirname, '..')) {
  const destination = path.join(root, DESTINATION);
  const bytes = renderLaunch();
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (!fs.existsSync(destination) || !fs.readFileSync(destination).equals(bytes)) fs.writeFileSync(destination, bytes);
  importMetadata(destination, DESTINATION);
  return bytes;
}

if (require.main === module) {
  console.log(`Generated the original ${SECONDS * 1000} ms Voice Pop launch fallback (${generateLaunch().length} bytes).`);
}

module.exports = { DESTINATION, SECONDS, renderLaunch, generateLaunch };
