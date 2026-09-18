const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const mapping = require('../docs/assets/voice-pop-sfx.json');

const sourceRoot = process.argv[2];
if (!sourceRoot) {
  throw new Error('Usage: node tools/import-pop-sfx.cjs "D:/uwork/AssetsSource"');
}
const source = path.resolve(sourceRoot, mapping.source);
const bytes = fs.readFileSync(source);
const digest = createHash('sha256').update(bytes).digest('hex');
if (digest !== mapping.sha256) throw new Error('Cut2.wav differs from the selected source; import stopped.');
const destination = path.resolve(__dirname, '..', mapping.destination);
fs.mkdirSync(path.dirname(destination), { recursive: true });
fs.writeFileSync(destination, bytes);
console.log(`Imported ${mapping.pack}/Cut2.wav unchanged (${bytes.length} bytes, ${Math.round(mapping.seconds * 1000)} ms).`);
