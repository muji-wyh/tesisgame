const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const sharp = require(process.env.SHARP_MODULE || 'sharp');
const { softenVector, normalizePicture } = require('./library-material.cjs');

const root = path.resolve(__dirname, '../..');
const sourceRoot = process.env.MULBERRY_SOURCE || path.join(root, 'build/mulberry-source/EN');
const destination = path.join(root, 'build/word-art-review/library-source/curated');
const revision = '9cbab9f400c5de44e2bc58839cca07294aadb086';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const inputs = new Map();
const sourceHashes = {
  'grains.svg': '606b2f7764149bc14fc6b19dc0a4e203b7ad95a7ed9dfe000693788d570f9d52',
  'picture.svg': 'cb9829286b0a6963ecd99ed76a9ff2fc6368f7a39cdedb52830fbe368589de02',
  'next.svg': '083cb0fcc58d14f8b872d0db6941fbf1dd4d90383bd826b76dbaa91e64302568'
};

function source(name) {
  const bytes = fs.readFileSync(path.join(sourceRoot, name));
  if (hash(bytes) !== sourceHashes[name]) throw new Error(`Pinned Mulberry source changed: ${name}`);
  inputs.set(name, { path: name, sha256: hash(bytes),
    url: `https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/${revision}/EN/${encodeURIComponent(name)}` });
  return bytes.toString('utf8');
}

function paths(svg) { return [...svg.matchAll(/<path\b[^>]*\/>/g)].map(match => match[0]); }
function wrap(viewBox, content, width, height) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" width="${width}" height="${height}">${content}</svg>`;
}
async function render(svg, palette = {}) { return sharp(Buffer.from(softenVector(svg, palette))).png().toBuffer(); }

async function prepare() {
  fs.mkdirSync(destination, { recursive: true });
  const records = [];
  async function save(id, bytes, names, meaning, transformation) {
    const output = path.join(destination, `${id}.png`);
    fs.writeFileSync(output, bytes);
    const primary = inputs.get(names[0]);
    records.push({ id, local: path.relative(root, output).split(path.sep).join('/'),
      source: { provider: 'mulberry', creator: 'Steve Lee; original symbol design project by Garry Paxton; Grow with Pip (composition adaptation)',
        license: 'CC-BY-SA-4.0', licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
        url: primary.url, path: primary.path, revision, sha256: hash(bytes),
        originalSha256: primary.sha256, inputs: names.map(name => inputs.get(name)), meaning, transformation,
        acquisitionStatus: 'Acquired source paths recomposed and visually reviewed at card size.', availableAnimations: [] },
      review: 'Original source and derived picture inspected at 80 px and 256 px for the intended sense.' });
    fs.writeFileSync(path.join(destination, `${id}.webp`), await normalizePicture(bytes));
  }

  // Keep the authored wheat paths and enlarge its actual grain silhouette.
  const grainPaths = paths(source('grains.svg'));
  const stalk = grainPaths.slice(0, 8).join('') + '<g fill="none" stroke="#231f20">' + grainPaths.slice(13, 20).join('') + '</g>';
  const stalkPng = await render(wrap('62 72 370 638', stalk, 154, 266), { '#fbee34': '#e2b856' });
  const kernelData = /d="[^"]*?(M311\.24[^\"]+)"/.exec(grainPaths[7])[1];
  const kernelSvg = wrap('247 166 77 108', `<path d="${kernelData}" fill="#e2b856" stroke="#735834" stroke-width="4"/>`, 91, 128);
  const kernel = await render(kernelSvg);
  const tilted = await sharp(kernel).rotate(42, { background: '#00000000' }).resize(108, 126, { fit: 'contain', background: '#00000000' }).png().toBuffer();
  const small = await sharp(kernel).rotate(-34, { background: '#00000000' }).resize(81, 94, { fit: 'contain', background: '#00000000' }).png().toBuffer();
  const grain = await sharp({ create: { width: 300, height: 300, channels: 4, background: '#00000000' } })
    .composite([{ input: stalkPng, left: 5, top: 7 }, { input: kernel, left: 175, top: 94 },
      { input: tilted, left: 113, top: 168 }, { input: small, left: 212, top: 198 }]).png().toBuffer();
  await save('grain', grain, ['grains.svg'], 'A small hard seed grown for food',
    'Retain the acquired wheat stalk, remove bread and pasta, and enlarge three copies of the source top grain silhouette to distinguish the seed from processed foods. Preserve source geometry; apply the shared shaded material.');

  // Sharp source frame and comparison thumbnail distinguish a fuzzy picture
  // from an accidentally low-resolution file or the unrelated tactile sense.
  const picture = source('picture.svg').replace(/M713\.55[^\"]+/, '');
  const picturePaths = paths(picture);
  const photoView = picture.replace(/viewBox="[^"]+"/, 'viewBox="75 249 700 505"').replace(/width="[^"]+"/, 'width="700"').replace(/height="[^"]+"/, 'height="505"');
  const photo = await render(photoView);
  const clear = await sharp(photo).resize(103, 74).png().toBuffer();
  const blurred = await sharp(photo).blur(21).png().toBuffer();
  const frameFill = picturePaths.find(p => p.startsWith('<path d="M139.26'));
  const frameOutlines = picturePaths.filter(p => p.includes('d="M713.17') || p.includes('d="M725.92'));
  const frame = await render(wrap('75 249 700 505', frameFill + '<g fill="none" stroke="#231f20">' + frameOutlines.join('') + '</g>', 700, 505));
  const framed = await sharp(blurred).composite([{ input: frame }]).png().toBuffer();
  const fuzzy = await sharp(framed).resize(228, 165).png().toBuffer();
  const arrowPaths = paths(source('next.svg')).filter(p => p.includes('M480.983') || p.includes('M136.902'));
  const arrow = await render(wrap('117 211 385 215', arrowPaths.join(''), 99, 56));
  const comparison = await sharp({ create: { width: 300, height: 300, channels: 4, background: '#00000000' } })
    .composite([{ input: clear, left: 10, top: 20 }, { input: arrow, left: 137, top: 23 }, { input: fuzzy, left: 59, top: 114 }]).png().toBuffer();
  await save('fuzzy', comparison, ['picture.svg', 'next.svg'], 'Unclear or difficult to see sharply',
    'Compare a sharp thumbnail with a larger optically defocused copy of the same acquired landscape. Remove the hanging wire, keep the frame sharp, blur only the picture, and retain the curved direction arrow from the acquired next symbol. No written answer added.');
  fs.writeFileSync(path.join(root, 'tools/vocabulary-art/curated-library-map.json'), JSON.stringify({ schema: 1,
    status: 'Acquired and visually reviewed', purpose: 'Targeted meaning refinements using inspected production geometry.', files: records }, null, 2) + '\n');
  console.log(JSON.stringify({ prepared: records.map(record => record.id), destination }));
}

if (require.main === module) prepare().catch(error => { console.error(error); process.exitCode = 1; });
module.exports = { prepare };
