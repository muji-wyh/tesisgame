const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function checkWordLibrary(root = path.resolve(__dirname, '..')) {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/word-library.json')));
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json')));
  const expected = words.filter(word => word.image).map(word => word.id).sort();
  if (manifest.schema !== 1 || manifest.count !== expected.length || manifest.pictures !== expected.length ||
      manifest.contextOnly !== words.length - expected.length || manifest.status !== 'Integrated' ||
      JSON.stringify(manifest.files.map(file => file.id).sort()) !== JSON.stringify(expected)) {
    throw new Error('The reviewed picture library must cover every pictured curriculum word exactly once.');
  }
  let totalBytes = 0;
  const licenses = new Set(['MIT', 'CC0-1.0', 'CC-BY-SA-4.0', 'CC-BY-4.0', 'CC-BY-SA-3.0', 'CC-BY-3.0',
    'CC-BY-SA-2.5', 'CC-BY-SA-2.0', 'CC-BY-2.0', 'CC-BY-SA-1.0', 'Public domain', 'NASA/JPL image use']);
  for (const file of manifest.files) {
    if (file.path !== `assets/images/word-library/${file.id}.webp` || file.width !== 256 || file.height !== 256 ||
        !file.source?.provider || !file.source.creator || !licenses.has(file.source.license) || !file.source.url && !file.source.record ||
        !/^[a-f0-9]{64}$/.test(file.inputSha256)) throw new Error(`Missing library source or invalid metadata: ${file.id}`);
    const bytes = fs.readFileSync(path.join(root, file.path));
    if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WEBP' ||
        bytes.length !== file.bytes || createHash('sha256').update(bytes).digest('hex') !== file.sha256) {
      throw new Error(`Missing or unreviewed vocabulary picture: ${file.id}`);
    }
    totalBytes += bytes.length;
  }
  const actual = fs.readdirSync(path.join(root, 'assets/images/word-library')).filter(name => !name.endsWith('.import')).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected.map(id => `${id}.webp`))) throw new Error('Orphan images in the reviewed vocabulary library.');
  return { pictures: expected.length, contextOnly: manifest.contextOnly, bytes: totalBytes };
}
module.exports = { checkWordLibrary };
if (require.main === module) console.log(checkWordLibrary());
