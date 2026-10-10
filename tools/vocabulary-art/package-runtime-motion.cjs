// Produce card-sized runtime atlases from the locally reviewed Blender frames.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_MODULE || 'sharp');
const root = path.resolve(__dirname, '../..');
const source = path.join(root, 'build/word-art-review/animated');
const target = path.join(root, 'assets/images/word-motion');
const side = 128;
async function main() {
  fs.mkdirSync(target, { recursive: true });
  const clips = JSON.parse(fs.readFileSync(path.join(source, 'manifest.json')));
  const files = [];
  for (const clip of clips) {
    const tiles = [];
    for (let i = 0; i < clip.frames; i++) {
      const input = await sharp(path.join(source, clip.id, `frame-${String(i + 1).padStart(4, '0')}.png`))
        .resize(side, side).png().toBuffer();
      tiles.push({ input, left: i % 8 * side, top: Math.floor(i / 8) * side });
    }
    const output = path.join(target, `${clip.id}.webp`);
    await sharp({ create: { width: side * 8, height: Math.ceil(clip.frames / 8) * side, channels: 4, background: '#00000000' } })
      .composite(tiles).webp({ quality: 90, alphaQuality: 100, effort: 5 }).toFile(output);
    const bytes = fs.readFileSync(output);
    files.push({ id: clip.id, path: path.relative(root, output).replaceAll('\\', '/'), frames: clip.frames,
      fps: clip.fps, frameSide: side, columns: 8, posterFrame: clip.posterFrame,
      bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') });
  }
  fs.writeFileSync(path.join(root, 'docs/assets/lv3-word-motion.json'), JSON.stringify({
    creator: 'Kenney (source meshes); Grow with Pip (skeletal motion and renders)',
    license: 'CC0-1.0', sourceRecord: 'docs/assets/lv3-vocabulary.json',
    adaptations: 'Cheerful smile, timed blinks, head and torso counter-motion, action-specific anticipation and recovery; clip durations unchanged.',
    skins: ['child-cheerful.png', 'child-cheerful-blink.png'].map(name => {
      const skin = `tools/vocabulary-art/skins/${name}`;
      return { path: skin, sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(root, skin))).digest('hex') };
    }),
    status: 'Integrated in all word-picture consumers', files
  }, null, 2) + '\n');
  console.log(`Packaged ${files.length} runtime atlases (${files.reduce((n, f) => n + f.bytes, 0)} bytes).`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
