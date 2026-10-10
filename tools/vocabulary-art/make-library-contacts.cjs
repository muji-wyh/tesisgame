const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.env.SHARP_MODULE || 'sharp');

const root = path.resolve(__dirname, '../..');
const review = path.join(root, 'build/word-art-review/library');
const esc = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

async function main() {
  const manifest = JSON.parse(fs.readFileSync(path.join(review, 'manifest.json')));
  const files = [...manifest.files].sort((a, b) => a.id.localeCompare(b.id));
  const output = path.join(review, 'contacts');
  fs.mkdirSync(output, {recursive: true});
  const sheets = [];
  for (let offset = 0; offset < files.length; offset += 64) {
    const group = files.slice(offset, offset + 64);
    const height = Math.ceil(group.length / 8) * 112 + 32;
    const layers = [{input: Buffer.from(`<svg width="896" height="32"><text x="12" y="22" font-family="Arial" font-size="16" fill="#193a43">Vocabulary output review · ${offset}–${offset + group.length - 1} · 80 px artwork</text></svg>`), left: 0, top: 0}];
    for (let index = 0; index < group.length; index++) {
      const file = group[index];
      const left = (index % 8) * 112;
      const top = Math.floor(index / 8) * 112 + 32;
      const image = await sharp(path.join(review, 'pictures', `${file.id}.webp`)).resize(80, 80).png().toBuffer();
      layers.push({input: image, left: left + 16, top});
      const label = `<svg width="112" height="26"><text x="56" y="18" font-family="Arial" font-size="13" text-anchor="middle" fill="#193a43">${esc(file.id)}</text></svg>`;
      layers.push({input: Buffer.from(label), left, top: top + 80});
    }
    const name = `library-contact-${String(sheets.length + 1).padStart(2, '0')}.png`;
    await sharp({create: {width: 896, height, channels: 4, background: '#fffdf7'}}).composite(layers).png().toFile(path.join(output, name));
    sheets.push({path: `build/word-art-review/library/contacts/${name}`, first: offset, last: offset + group.length - 1,
      words: group.map(file => file.id)});
  }
  fs.writeFileSync(path.join(output, 'index.json'), JSON.stringify({pictures: files.length, pictureSize: 80, sheets}, null, 2) + '\n');
  console.log(JSON.stringify({pictures: files.length, sheets: sheets.length, directory: output}));
}

main().catch(error => {console.error(error); process.exitCode = 1;});
