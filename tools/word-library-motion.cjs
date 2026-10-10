const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const RUNTIME_KEYS = ['id', 'path', 'frames', 'fps', 'frameSide', 'columns', 'posterFrame'];
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

function atlasCanvas(bytes, id) {
  const invalid = () => { throw new Error(`Invalid or truncated word motion atlas: ${id}`); };
  if (bytes.length < 30 || bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WEBP' ||
      bytes.readUInt32LE(4) + 8 !== bytes.length) invalid();
  let canvas, image = false, offset = 12;
  while (offset + 8 <= bytes.length) {
    const kind = bytes.toString('ascii', offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4), start = offset + 8;
    if (start + size > bytes.length) invalid();
    if (kind === 'VP8X') {
      if (size < 10 || canvas || (bytes[start] & 0x02) || !(bytes[start] & 0x10)) invalid();
      canvas = { width: bytes.readUIntLE(start + 4, 3) + 1, height: bytes.readUIntLE(start + 7, 3) + 1 };
    }
    if (kind === 'VP8 ' || kind === 'VP8L') image = image || size > 0;
    if (kind === 'ANIM' || kind === 'ANMF') invalid();
    offset = start + size + (size % 2);
  }
  if (offset !== bytes.length || !canvas || !image) invalid();
  return canvas;
}

function checkWordLibraryMotion(root = path.resolve(__dirname, '..')) {
  const read = filename => JSON.parse(fs.readFileSync(path.join(root, filename)));
  const words = read('words.json');
  const expected = words.filter(word => word.image).map(word => word.id).sort();
  const manifest = read('docs/assets/word-library-motion.json');
  const runtime = read('data/word-motion.json');
  const library = new Map(read('docs/assets/word-library.json').files.map(file => [file.id, file]));
  const authored = new Map(read('docs/assets/lv3-word-motion.json').files.map(file => [file.id, file]));
  const mapping = read('tools/vocabulary-art/library-motion-map.json');
  const entries = new Map(mapping.files.map(file => [file.id, file]));
  const exactCoverage = files => Array.isArray(files) &&
    JSON.stringify(files.map(file => file.id).sort()) === JSON.stringify(expected);
  if (manifest.schema !== 1 || manifest.status !== 'Integrated' || manifest.count !== expected.length ||
      runtime.schema !== 1 || !exactCoverage(manifest.files) || !exactCoverage(runtime.files) || !exactCoverage(mapping.files)) {
    throw new Error('Word motion must cover every pictured curriculum word exactly once.');
  }
  const live = new Map(runtime.files.map(file => [file.id, file]));
  let bytesTotal = 0, framesTotal = 0, authoredCount = 0;
  for (const file of manifest.files) {
    const still = library.get(file.id), entry = entries.get(file.id), clip = authored.get(file.id);
    if (file.path !== `assets/images/word-motion/${file.id}.webp` || file.frameSide !== 128 || file.columns !== 8 ||
        !Number.isSafeInteger(file.frames) || file.frames <= 1 || file.frames > 256 ||
        !Number.isSafeInteger(file.posterFrame) || file.posterFrame < 0 || file.posterFrame >= file.frames ||
        !Number.isFinite(file.fps) || file.fps <= 0 || file.fps > 60 ||
        RUNTIME_KEYS.some(key => live.get(file.id)[key] !== file[key]) ||
        Object.keys(live.get(file.id)).some(key => !RUNTIME_KEYS.includes(key))) {
      throw new Error(`Invalid or inconsistent runtime motion metadata: ${file.id}`);
    }
    if (!still || file.sourceSha256 !== still.sha256 || file.sourceRecord !== 'docs/assets/word-library.json' ||
        !still.source?.creator || file.creator !== still.source.creator || !still.source.license || file.license !== still.source.license ||
        !file.adaptation || file.profile !== entry.profile || !mapping.profiles?.[file.profile]) {
      throw new Error(`Missing or stale word motion source attribution: ${file.id}`);
    }
    if (clip) {
      authoredCount++;
      if (file.profile !== 'authored_clip' || RUNTIME_KEYS.some(key => clip[key] !== file[key]) ||
          file.sha256 !== clip.sha256 || file.bytes !== clip.bytes) {
        throw new Error(`The reviewed authored motion changed: ${file.id}`);
      }
    } else if (file.profile === 'authored_clip' || file.frames !== 32 || file.fps !== 12 ||
        !Number.isSafeInteger(file.uniqueFrames) || file.uniqueFrames < 8 || file.uniqueFrames > file.frames ||
        !Number.isSafeInteger(file.minimumOpaqueMargin) || file.minimumOpaqueMargin < 1) {
      throw new Error(`Static, clipped or unsupported library motion: ${file.id}`);
    }
    const bytes = fs.readFileSync(path.join(root, file.path));
    if (bytes.length !== file.bytes || digest(bytes) !== file.sha256) {
      throw new Error(`Missing or unreviewed word motion bytes: ${file.id}`);
    }
    const canvas = atlasCanvas(bytes, file.id);
    if (canvas.width !== file.columns * file.frameSide || canvas.height !== Math.ceil(file.frames / file.columns) * file.frameSide) {
      throw new Error(`Word motion atlas dimensions disagree with its frames: ${file.id}`);
    }
    bytesTotal += bytes.length;
    framesTotal += file.frames;
  }
  const actual = fs.readdirSync(path.join(root, 'assets/images/word-motion')).filter(file => !file.endsWith('.import')).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected.map(id => `${id}.webp`))) throw new Error('Orphan word motion atlases.');
  return { clips: expected.length, authored: authoredCount, frames: framesTotal, bytes: bytesTotal };
}

module.exports = { checkWordLibraryMotion, atlasCanvas };
if (require.main === module) console.log(checkWordLibraryMotion());
