const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const revision = '9cbab9f400c5de44e2bc58839cca07294aadb086';
const levels = ['basic', 'growing', 'advanced'];
const topics = ['actions-and-routines', 'feelings-and-people', 'describe-and-compare',
  'places-and-time', 'nature-and-science', 'food-and-home', 'school-and-play'];
const partsOfSpeech = ['noun', 'verb', 'adjective', 'adverb', 'preposition', 'number'];
const imageSize = 192;
const manifestPath = path.join(root, 'docs/assets/mulberry-vocabulary.json');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

function additions() {
  return levels.flatMap(level => {
    const entries = JSON.parse(fs.readFileSync(path.join(root, `docs/vocabulary/${level}-expansion.json`)));
    if (entries.length !== 300 || entries.some(word => word.level !== level ||
        !partsOfSpeech.includes(word.part_of_speech) || !topics.includes(word.topic) ||
        typeof word.meaning !== 'string' || word.meaning.trim().split(/\s+/).length < 3 ||
        word.meaning.trim().split(/\s+/).length > 9)) {
      throw new Error(`${level} must add exactly 300 words.`);
    }
    for (const topic of topics) {
      if (entries.filter(word => word.topic === topic).length < 5) {
        throw new Error(`${level} needs at least five words in ${topic}.`);
      }
    }
    return entries;
  });
}

function validateSvg(source) {
  // CSS and text are rendered into the finished PNG rather than depending on
  // Godot's narrower SVG support. The pinned source must remain self-contained.
  const match = source.trim().match(/^<svg\b([^>]*)>([\s\S]*)<\/svg>$/);
  const viewBox = match?.[1].match(/\bviewBox="([0-9. ]+)"/)?.[1];
  if (!viewBox || !viewBox.startsWith('0 0 ')) throw new Error('Unsupported source canvas.');
  for (const [, reference] of source.matchAll(/url\s*\(([^)]*)\)/gi)) {
    const font = reference.trim().replace(/^["']|["']$/g, '')
      .match(/^data:(?:font\/[\w+-]+|application\/[\w+-]+)?;base64,([A-Za-z0-9+/=]+)$/);
    const header = font && Buffer.from(font[1], 'base64').subarray(0, 4);
    if (!header || !(['OTTO', 'wOFF', 'wOF2'].includes(header.toString('ascii')) ||
        header.equals(Buffer.from([0, 1, 0, 0])))) {
      throw new Error('Only embedded font data is supported in source CSS.');
    }
  }
  if (/<(?:script|foreignObject|image|use|animate\w*|set)\b|\b(?:href|on\w+)\s*=|@import|<!\s*(?:DOCTYPE|ENTITY)/i.test(source)) {
    throw new Error('Source must be a self-contained static illustration.');
  }
}

function pngDimensions(bytes) {
  if (bytes.length < 33 || !bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ||
      bytes.toString('ascii', 12, 16) !== 'IHDR') throw new Error('Invalid vocabulary PNG.');
  return {width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20)};
}

async function rasterizeSvg(bytes, sharp) {
  validateSvg(bytes.toString('utf8'));
  return sharp(bytes, {density: 96, limitInputPixels: 25000000})
    .resize(imageSize, imageSize, {fit: 'contain', background: {r: 0, g: 0, b: 0, alpha: 0}})
    .png({compressionLevel: 9, adaptiveFiltering: true, palette: false}).toBuffer();
}

function check() {
  const entries = additions();
  const manifest = JSON.parse(fs.readFileSync(manifestPath));
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json')));
  if (manifest.revision !== revision || manifest.files.length !== 900 || words.length < 1250 ||
      manifest.license !== 'CC-BY-SA-4.0' || manifest.renderer?.width !== imageSize ||
      manifest.renderer?.height !== imageSize) {
    throw new Error('Vocabulary or provenance count mismatch.');
  }
  const sources = new Set(), ids = new Set(), images = new Set();
  for (const entry of entries) {
    const record = manifest.files.find(file => file.id === entry.id);
    const word = words.find(word => word.id === entry.id);
    const bytes = word && fs.readFileSync(path.join(root, word.image));
    const dimensions = bytes && pngDimensions(bytes);
    if (!record || !word || word.level !== entry.level || word.part_of_speech !== entry.part_of_speech ||
        word.meaning !== entry.meaning || word.topic !== entry.topic || record.source !== entry.source ||
        JSON.stringify(word.confusable || []) !== JSON.stringify(entry.confusable || []) ||
        word.art_key !== `mulberry/${entry.source}` || record.path !== word.image ||
        word.image !== `assets/images/words/${entry.id}.png` || digest(bytes) !== record.sha256 ||
        !/^[a-f0-9]{64}$/.test(record.sourceSha256) ||
        record.url !== `https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/${revision}/EN/${encodeURIComponent(entry.source)}` ||
        dimensions.width !== imageSize || dimensions.height !== imageSize ||
        ids.has(entry.id) || sources.has(entry.source) || images.has(record.sha256)) {
      throw new Error(`Vocabulary mismatch: ${entry.id}`);
    }
    ids.add(entry.id);
    sources.add(entry.source);
    images.add(record.sha256);
  }
  console.log('Verified 900 sourced vocabulary illustrations and three 300-word additions.');
}

async function importVocabulary(sourceDirectory, sharpModule = 'sharp') {
  if (fs.existsSync(path.join(root, 'curriculum.json'))) {
    throw new Error('The growth curriculum is already integrated. Use --check for this historical batch and import-growth-vocabulary.cjs for its additional artwork.');
  }
  sourceDirectory = path.resolve(sourceDirectory);
  const actual = execFileSync('git', ['-C', sourceDirectory, 'rev-parse', 'HEAD'], {encoding: 'utf8', windowsHide: true}).trim();
  if (actual !== revision) throw new Error(`Expected Mulberry revision ${revision}.`);
  if (execFileSync('git', ['-C', sourceDirectory, 'status', '--porcelain', '--', 'EN'],
    {encoding: 'utf8', windowsHide: true}).trim()) {
    throw new Error('Mulberry source illustrations must match the clean pinned checkout.');
  }
  let sharp;
  try { sharp = require(sharpModule); }
  catch { throw new Error('Sharp is required to import artwork. Supply its module path with --sharp <module>.'); }
  const existing = JSON.parse(fs.readFileSync(path.join(root, 'words.json'))).slice(0, 350);
  if (existing.length !== 350 || existing.some(word => word.art_key?.startsWith('mulberry/'))) {
    throw new Error('The original 350 vocabulary entries must remain at the beginning of words.json.');
  }
  const entries = additions();
  const ids = new Set(existing.map(word => word.id));
  const sources = new Set();
  const imageHashes = new Map();
  const files = [];
  const outputs = [];
  for (const entry of entries) {
    if (!/^[a-z]{2,14}$/.test(entry.id) || entry.text !== entry.id || ids.has(entry.id) || sources.has(entry.source) ||
        path.basename(entry.source) !== entry.source || !entry.source.endsWith('.svg')) {
      throw new Error(`Duplicate or invalid vocabulary entry: ${entry.id}`);
    }
    ids.add(entry.id);
    sources.add(entry.source);
    const bytes = fs.readFileSync(path.join(sourceDirectory, 'EN', entry.source));
    const png = await rasterizeSvg(bytes, sharp);
    const imageHash = digest(png);
    if (imageHashes.has(imageHash)) {
      throw new Error(`${entry.id} duplicates the rendered artwork of ${imageHashes.get(imageHash)}.`);
    }
    imageHashes.set(imageHash, entry.id);
    const imagePath = `assets/images/words/${entry.id}.png`;
    outputs.push([imagePath, png]);
    files.push({id: entry.id, source: entry.source,
      url: `https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/${revision}/EN/${encodeURIComponent(entry.source)}`,
      sourceSha256: digest(bytes), path: imagePath, sha256: imageHash});
    existing.push({id: entry.id, text: entry.text, image: imagePath,
      audio: `assets/audio/voice/word-${entry.id}.wav`, level: entry.level,
      part_of_speech: entry.part_of_speech, topic: entry.topic, meaning: entry.meaning,
      art_key: `mulberry/${entry.source}`, ...(entry.confusable?.length ? {confusable: entry.confusable} : {})});
  }
  for (const [relative, png] of outputs) {
    const filename = path.join(root, relative);
    if (!fs.existsSync(filename) || !fs.readFileSync(filename).equals(png)) fs.writeFileSync(filename, png);
  }
  fs.writeFileSync(path.join(root, 'words.json'), JSON.stringify(existing, null, 2) + '\n');
  fs.writeFileSync(manifestPath, JSON.stringify({
    provider: 'Mulberry Symbols', creator: 'Steve Lee; original symbol design project by Garry Paxton',
    source: 'https://github.com/mulberrysymbols/mulberry-symbols', revision,
    license: 'CC-BY-SA-4.0', licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
    status: 'Downloaded and integrated', animations: 'None; static illustrations',
    modifications: 'Original SVG illustrations rasterized to transparent 192 by 192 PNGs with preserved aspect ratio, geometry, colors, CSS, and text. No additional artwork drawn.',
    renderer: {name: 'sharp', version: sharp.versions.sharp, svg: sharp.versions.rsvg,
      width: imageSize, height: imageSize, density: 96, fit: 'contain', background: 'transparent'}, files
  }, null, 2) + '\n');
  check();
}

if (require.main === module) {
  (async () => {
    if (process.argv[2] === '--check') check();
    else if (process.argv.length === 3 || (process.argv.length === 5 && process.argv[3] === '--sharp')) {
      await importVocabulary(process.argv[2], process.argv[4]);
    } else throw new Error('Usage: node tools/import-vocabulary.cjs <pinned-mulberry-checkout> [--sharp <module>] | --check');
  })().catch(error => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { additions, validateSvg, rasterizeSvg, pngDimensions, check, importVocabulary, revision, imageSize };
