const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function pairFeedbackFixture(root, writeImport) {
  const assets = ['right', 'wrong'].map((id, index) => {
    const frames = 44100 * (0.82 + index * 0.04), bytes = Buffer.alloc(44 + Math.round(frames) * 2);
    bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
    bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
    bytes.writeUInt32LE(44100, 24); bytes.writeUInt32LE(88200, 28);
    bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34);
    bytes.write('data', 36); bytes.writeUInt32LE(bytes.length - 44, 40);
    for (let frame = 0; frame < Math.round(frames); frame++) bytes.writeInt16LE(Math.round(Math.sin(frame * 0.04) * 8000), 44 + frame * 2);
    const destination = `assets/imported-audio/pair-feedback/${id}.wav`;
    fs.mkdirSync(path.dirname(path.join(root, destination)), { recursive: true });
    fs.writeFileSync(path.join(root, destination), bytes);
    writeImport(destination);
    return { id, destination, sha256: createHash('sha256').update(bytes).digest('hex'),
      seconds: (bytes.length - 44) / 88200, sampleRate: 44100, channels: 1, bitDepth: 16 };
  });
  const manifestPath = path.join(root, 'docs/assets/pair-feedback-audio.json');
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  const writeManifest = () => fs.writeFileSync(manifestPath, JSON.stringify({ assets }));
  writeManifest();
  return { assets, manifestPath, writeManifest };
}

module.exports = { pairFeedbackFixture };
