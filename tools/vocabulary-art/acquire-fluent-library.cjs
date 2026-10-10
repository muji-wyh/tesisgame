// Download only the explicitly reviewed selections from the pinned MIT source.
// The gallery and source downloads remain in ignored local authoring storage.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const mapPath = path.join(__dirname, 'fluent-library-map.json');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

async function main() {
  const manifest = JSON.parse(await fs.readFile(mapPath, 'utf8'));
  const sourceRoot = path.join(root, 'build/word-art-review/library-source');
  await fs.mkdir(path.join(sourceRoot, 'fluent'), {recursive: true});
  const existing = JSON.parse(await fs.readFile(path.join(root, 'docs/assets/lv3-vocabulary.json'), 'utf8'));
  const cache = new Map();
  for (const sourceFile of ['candidate-mapping.json', 'alternative-mapping.json', 'source-manifest.json']) {
    const directory = path.join(root, 'build/word-art-review/fluent-source');
    let data;
    try { data = JSON.parse(await fs.readFile(path.join(directory, sourceFile), 'utf8')); }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    for (const item of Array.isArray(data) ? data : data.files) {
      cache.set(item.path || item.source, path.join(directory, item.local));
    }
  }
  let cursor = 0;
  let fetched = 0;
  const worker = async () => {
    while (cursor < manifest.files.length) {
      const file = manifest.files[cursor++];
      const destination = path.join(root, file.local);
      const expected = file.sha256 || existing.files.find(item => item.id === file.id && item.source.path === file.path)?.source.sha256;
      let bytes;
      for (const candidate of [expected ? destination : null, cache.get(file.path)].filter(Boolean)) {
        try {
          const content = await fs.readFile(candidate);
          if (!expected || hash(content) === expected) { bytes = content; break; }
        } catch (error) { if (error.code !== 'ENOENT') throw error; }
      }
      if (!bytes) {
        for (let attempt = 0; attempt < 4; attempt++) {
          try {
            const response = await fetch(file.url);
            if (!response.ok) throw new Error(`${response.status} ${file.url}`);
            bytes = Buffer.from(await response.arrayBuffer());
            break;
          } catch (error) {
            if (attempt === 3) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
          }
        }
        fetched++;
      }
      if (!bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) throw new Error(`Not a PNG: ${file.id}`);
      const sha256 = hash(bytes);
      if (expected && expected !== sha256) throw new Error(`Source hash differs: ${file.id}`);
      await fs.writeFile(destination, bytes);
      Object.assign(file, {sha256, bytes: bytes.length, width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20),
        status: 'Acquired locally from pinned official source; not yet integrated'});
    }
  };
  await Promise.all(Array.from({length: 6}, worker));
  manifest.status = 'Curated sources acquired locally; contact sheets prepared for visual review; integration tracked separately';
  manifest.licenseSha256 = hash(await fs.readFile(path.join(root, manifest.licenseFile)));
  await fs.writeFile(mapPath, JSON.stringify(manifest, null, 2) + '\n');
  const sharp = require(process.env.SHARP_MODULE || 'sharp');
  const sheets = [];
  for (let offset = 0; offset < manifest.files.length; offset += 64) {
    const group = manifest.files.slice(offset, offset + 64);
    const width = 8 * 136;
    const height = Math.ceil(group.length / 8) * 148;
    const layers = [];
    for (let index = 0; index < group.length; index++) {
      const file = group[index];
      const left = (index % 8) * 136;
      const top = Math.floor(index / 8) * 148;
      const thumbnail = await sharp(path.join(root, file.local)).trim().resize(112, 112, {fit: 'inside'}).png().toBuffer();
      const meta = await sharp(thumbnail).metadata();
      layers.push({input: thumbnail, left: left + Math.floor((136 - meta.width) / 2), top: top + Math.floor((118 - meta.height) / 2)});
      layers.push({input: Buffer.from(`<svg width="136" height="26"><text x="68" y="18" font-family="Arial" font-size="14" text-anchor="middle" fill="#193a43">${escape(file.id)}</text></svg>`), left, top: top + 118});
    }
    const output = path.join(sourceRoot, `fluent-contact-${Math.floor(offset / 64) + 1}.png`);
    await sharp({create: {width, height, channels: 4, background: '#f1f5f7'}}).composite(layers).png().toFile(output);
    sheets.push(path.relative(root, output).replaceAll('\\', '/'));
  }
  await fs.writeFile(path.join(sourceRoot, 'fluent-contact-sheets.json'), JSON.stringify({count: manifest.files.length, sheets}, null, 2) + '\n');
  console.log(JSON.stringify({acquired: manifest.files.length, fetched, bytes: manifest.files.reduce((sum, file) => sum + file.bytes, 0), sheets}, null, 2));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
