const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const DEFAULT_SOURCE = 'C:\\uworks\\tesisgameu\\Assets\\Modern 2D Animated Chests Pack_FREE Demo';
const SOURCE_NAME = 'Modern 2D Animated Chests Pack_FREE Demo 1.0.2';
const root = path.join(__dirname, '..');
const partNames = ['chest', ...Array.from({ length: 8 }, (_, index) => String(index + 1).padStart(2, '0'))];
const particles = {
  glow: 'assets/chests/particles/portal_glow.png',
  ring: 'assets/chests/particles/ring.png',
  spark: 'assets/chests/particles/sparkle3.png',
  ray: 'assets/chests/particles/lightray1.png',
  burst: 'assets/chests/particles/explosion_spike01.png',
  orb: 'assets/chests/particles/magic_orb2.png'
};
const crystalImages = partNames.map((name) => ({
  name,
  path: `assets/chests/crystal/${name === 'chest' ? 'base' : `part_${name}`}.png`,
  source: `Chests/Crystal/Sprites/SPR_${name}.png`
}));
const selectedImages = [
  ...['Royal', 'Energy'].flatMap((style) => [
    { path: `assets/chests/${style.toLowerCase()}/closed.png`, source: `Chests/${style}/Sprites/SPR_${style}_Close.png` },
    { path: `assets/chests/${style.toLowerCase()}/open.png`, source: `Chests/${style}/Sprites/SPR_${style}_Open.png` }
  ]),
  ...crystalImages,
  ...Object.values(particles).map((filename) => ({
    path: filename, source: `Particles/Textures/${path.posix.basename(filename)}`
  }))
];
const allowedOutputs = new Set([
  ...selectedImages.map((image) => image.path), 'assets/chests/SOURCE.txt', 'assets/chests/manifest.json'
]);
const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const resolvePath = (directory, relativePath) => path.join(directory, ...relativePath.split('/'));
const normalizeText = (text) => text.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');

function requireValue(condition, message) {
  if (!condition) throw new Error(message);
}

function field(text, key, label, indent = 2) {
  const matches = [...text.matchAll(new RegExp(`^${' '.repeat(indent)}${key}:[ \\t]*(.*)$`, 'gm'))];
  requireValue(matches.length > 0, `Missing ${key} in ${label}.`);
  requireValue(matches.length === 1, `Duplicate ${key} in ${label}.`);
  return matches[0][1].trim();
}

function flowMap(value, label, keys) {
  requireValue(/^\{.*\}$/.test(value), `Unsupported flow-map syntax in ${label}.`);
  const result = Object.create(null);
  for (const item of value.slice(1, -1).split(',')) {
    const match = /^\s*([A-Za-z_]\w*):\s*(.*?)\s*$/.exec(item);
    requireValue(match && !Object.hasOwn(result, match[1]), `Invalid or duplicate flow-map field in ${label}.`);
    result[match[1]] = match[2];
  }
  if (keys) {
    requireValue(Object.keys(result).length === keys.length && keys.every((key) => Object.hasOwn(result, key)),
      `Unsupported fields in ${label}; expected ${keys.join(', ')}.`);
  }
  return result;
}

function number(value, label) {
  requireValue(/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(value), `Invalid number for ${label}: ${value}`);
  const result = Number(value);
  requireValue(Number.isFinite(result), `Non-finite number for ${label}.`);
  return result;
}

function integer(value, label) {
  requireValue(/^-?\d+$/.test(value), `Invalid integer for ${label}.`);
  const result = Number(value);
  requireValue(Number.isSafeInteger(result), `Invalid integer range for ${label}.`);
  return result;
}

function vector(text, key, keys, label) {
  const values = flowMap(field(text, key, label), `${label}.${key}`, keys);
  return Object.fromEntries(keys.map((axis) => [axis, number(values[axis], `${label}.${key}.${axis}`)]));
}

function reference(text, key, label) {
  const values = flowMap(field(text, key, label), `${label}.${key}`, ['fileID']);
  requireValue(/^-?\d+$/.test(values.fileID), `Invalid fileID in ${label}.${key}.`);
  return values.fileID;
}

function parseSpriteMetadata(text, label = 'sprite metadata') {
  text = normalizeText(text);
  const guid = field(text, 'guid', label, 0);
  requireValue(/^[a-f0-9]{32}$/.test(guid), `Invalid sprite GUID in ${label}.`);
  requireValue(field(text, 'spriteMode', label) === '1' && field(text, 'textureType', label) === '8',
    `Only single-sprite texture metadata is supported: ${label}.`);
  const ppu = number(field(text, 'spritePixelsToUnits', label), `${label}.spritePixelsToUnits`);
  requireValue(ppu > 0, `Sprite PPU must be positive: ${label}.`);
  const pivot = vector(text, 'spritePivot', ['x', 'y'], label);
  requireValue(pivot.x >= 0 && pivot.x <= 1 && pivot.y >= 0 && pivot.y <= 1, `Invalid sprite pivot in ${label}.`);
  return { guid, ppu, pivot: [pivot.x, pivot.y] };
}

function unityDocuments(text) {
  text = normalizeText(text);
  const headers = [...text.matchAll(/^--- !u!(\d+) &(-?\d+)([^\n]*)\n/gm)];
  requireValue(headers.length > 0, 'Missing Unity YAML document headers.');
  const ids = new Set();
  const documents = [];
  for (let index = 0; index < headers.length; index += 1) {
    const header = headers[index];
    const [, type, id, suffix] = header;
    // FileIDs are decimal strings: adjacent 64-bit IDs must never become JS Numbers.
    requireValue(!ids.has(id), `Duplicate Unity fileID: ${id}.`);
    ids.add(id);
    if (!['1', '4', '212'].includes(type)) continue;
    requireValue(suffix.trim() === '', `Unsupported stripped Unity document: ${id}.`);
    documents.push({
      type, id,
      body: text.slice(header.index + header[0].length, headers[index + 1]?.index ?? text.length)
    });
  }
  return documents;
}

function gameObjectName(body, label) {
  const value = field(body, 'm_Name', label);
  if (value.startsWith('"')) {
    const decoded = JSON.parse(value);
    requireValue(typeof decoded === 'string', `Invalid GameObject name in ${label}.`);
    return decoded;
  }
  if (value.startsWith("'")) {
    requireValue(/^'(?:[^']|'')*'$/.test(value), `Unsupported GameObject name in ${label}.`);
    return value.slice(1, -1).replace(/''/g, "'");
  }
  return value;
}

function checkedMatrix(matrix, label) {
  requireValue(matrix.every(Number.isFinite), `Non-finite Transform matrix in ${label}.`);
  const determinant = matrix[0] * matrix[3] - matrix[1] * matrix[2];
  requireValue(Number.isFinite(determinant) && determinant !== 0, `Singular or invalid Transform matrix in ${label}.`);
  return matrix;
}

function localMatrix(body, label) {
  const position = vector(body, 'm_LocalPosition', ['x', 'y', 'z'], label);
  const scale = vector(body, 'm_LocalScale', ['x', 'y', 'z'], label);
  const rotation = vector(body, 'm_LocalRotation', ['x', 'y', 'z', 'w'], label);
  requireValue(Math.abs(position.z) <= 1e-7 && Math.abs(rotation.x) <= 1e-7 && Math.abs(rotation.y) <= 1e-7,
    `Unsupported non-2D Transform in ${label}.`);
  requireValue(Math.abs(Math.hypot(rotation.z, rotation.w) - 1) <= 1e-5, `Invalid 2D quaternion in ${label}.`);
  const angle = 2 * Math.atan2(rotation.z, rotation.w);
  const cosine = Math.cos(angle);
  const sine = Math.sin(angle);
  return checkedMatrix([
    cosine * scale.x, sine * scale.x, -sine * scale.y, cosine * scale.y, position.x, position.y
  ], label);
}

function multiply(parent, local) {
  return [
    parent[0] * local[0] + parent[2] * local[1],
    parent[1] * local[0] + parent[3] * local[1],
    parent[0] * local[2] + parent[2] * local[3],
    parent[1] * local[2] + parent[3] * local[3],
    parent[0] * local[4] + parent[2] * local[5] + parent[4],
    parent[1] * local[4] + parent[3] * local[5] + parent[5]
  ];
}

function buildCrystalParts(prefabText, sprites) {
  requireValue(Array.isArray(sprites) && sprites.length === 9, 'Crystal requires exactly nine sprite metadata records.');
  const byGuid = new Map();
  const names = new Set();
  for (const sprite of sprites) {
    const selected = crystalImages.find((image) => image.name === sprite.name);
    requireValue(selected && selected.path === sprite.texture && !names.has(sprite.name), `Invalid or duplicate Crystal part name: ${sprite.name}.`);
    requireValue(typeof sprite.guid === 'string' && /^[a-f0-9]{32}$/.test(sprite.guid), `Invalid Crystal sprite GUID: ${sprite.name}.`);
    requireValue(!byGuid.has(sprite.guid), `Duplicate Crystal sprite GUID: ${sprite.guid}.`);
    requireValue(Number.isFinite(sprite.ppu) && sprite.ppu > 0, `Invalid sprite PPU: ${sprite.name}.`);
    requireValue(Array.isArray(sprite.pivot) && sprite.pivot.length === 2 &&
      sprite.pivot.every((value) => Number.isFinite(value) && value >= 0 && value <= 1), `Invalid sprite pivot: ${sprite.name}.`);
    names.add(sprite.name);
    byGuid.set(sprite.guid, sprite);
  }

  const objects = new Map();
  const transforms = new Map();
  const transformByObject = new Map();
  const renderers = [];
  for (const document of unityDocuments(prefabText)) {
    const label = `Unity fileID ${document.id}`;
    if (document.type === '1') {
      objects.set(document.id, gameObjectName(document.body, label));
    } else if (document.type === '4') {
      const gameObject = reference(document.body, 'm_GameObject', label);
      requireValue(!transformByObject.has(gameObject), `Duplicate Transform for GameObject ${gameObject}.`);
      transforms.set(document.id, {
        ...document, gameObject, father: reference(document.body, 'm_Father', label)
      });
      transformByObject.set(gameObject, document.id);
    } else {
      renderers.push(document);
    }
  }

  const worldMatrices = new Map();
  const visiting = new Set();
  function worldMatrix(id) {
    if (worldMatrices.has(id)) return worldMatrices.get(id);
    const transform = transforms.get(id);
    requireValue(transform, `Unresolved parent Transform fileID ${id}.`);
    requireValue(!visiting.has(id), `Cyclic Transform parent chain at fileID ${id}.`);
    requireValue(objects.has(transform.gameObject), `Unresolved parent GameObject ${transform.gameObject}.`);
    visiting.add(id);
    const local = localMatrix(transform.body, `Transform ${id}`);
    const world = transform.father === '0' ? local : multiply(worldMatrix(transform.father), local);
    checkedMatrix(world, `world Transform ${id}`);
    visiting.delete(id);
    worldMatrices.set(id, world);
    return world;
  }

  const parts = new Map();
  for (const renderer of renderers) {
    const label = `SpriteRenderer ${renderer.id}`;
    const spriteReference = flowMap(field(renderer.body, 'm_Sprite', label), `${label}.m_Sprite`);
    const sprite = byGuid.get(spriteReference.guid);
    if (!sprite) continue;
    requireValue(!parts.has(sprite.name), `Duplicate Crystal SpriteRenderer for ${sprite.name}.`);
    requireValue(spriteReference.fileID === '21300000' && spriteReference.type === '3',
      `Unsupported single-sprite reference for ${sprite.name}.`);
    requireValue(field(renderer.body, 'm_DrawMode', label) === '0', `Unsupported sliced/tiled draw mode for ${sprite.name}.`);
    const gameObject = reference(renderer.body, 'm_GameObject', label);
    requireValue(objects.get(gameObject) === sprite.name, `Expected GameObject name ${sprite.name} for SpriteRenderer ${renderer.id}.`);
    const transformId = transformByObject.get(gameObject);
    requireValue(transformId, `Missing Transform for Crystal part ${sprite.name}.`);
    const world = worldMatrix(transformId);
    const pixelsPerTexturePixel = 100 / sprite.ppu;
    // Both coordinate systems change handedness: H * world * H, then pixel scaling.
    const transform = checkedMatrix([
      world[0] * pixelsPerTexturePixel, -world[1] * pixelsPerTexturePixel,
      -world[2] * pixelsPerTexturePixel, world[3] * pixelsPerTexturePixel,
      world[4] * 100, -world[5] * 100
    ], `Godot part ${sprite.name}`).map((value) => value === 0 ? 0 : value);
    const flipX = field(renderer.body, 'm_FlipX', label);
    const flipY = field(renderer.body, 'm_FlipY', label);
    requireValue(['0', '1'].includes(flipX) && ['0', '1'].includes(flipY), `Invalid flip flags for ${sprite.name}.`);
    parts.set(sprite.name, {
      name: sprite.name, texture: sprite.texture, transform, pivot: [...sprite.pivot],
      order: integer(field(renderer.body, 'm_SortingOrder', label), `${label}.m_SortingOrder`),
      flip_h: flipX === '1', flip_v: flipY === '1'
    });
  }
  for (const name of partNames) requireValue(parts.has(name), `Missing Crystal part ${name}.`);
  return [...parts.values()].sort((a, b) => a.order - b.order || a.name.localeCompare(b.name));
}

function pngDimensions(bytes, label) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  requireValue(bytes.length >= 33 && bytes.subarray(0, 8).equals(signature) &&
    bytes.readUInt32BE(8) === 13 && bytes.toString('ascii', 12, 16) === 'IHDR', `Invalid PNG signature or IHDR: ${label}.`);
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  requireValue(width > 0 && height > 0, `Invalid PNG dimensions: ${label}.`);
  return { width, height };
}

function sourceDescription() {
  return `${SOURCE_NAME}

Selected PNG image resources copied byte-for-byte from the free demo.
Unity behaviors were not imported. No Unity prefabs, animations, materials,
scripts, particle systems or .meta files were copied or executed.

Crystal geometry is the serialized rest pose in Chests/Crystal/PF_Chest_Crystal.prefab.
All Transform ancestors are composed through m_Father fileID 0, including the
prefab root. In this version, this retains the Animation 11 _ 03 scale (0.67, 0.67)
and the chest scale (0.85, 1). These are not normalized away.
Coordinates use 100 Godot pixels per Unity world unit, with y-down.
The six matrix values are [x_axis.x, x_axis.y, y_axis.x, y_axis.y, origin.x, origin.y].
Linear terms additionally use 100 / spritePixelsToUnits; origins always use 100.
Draw each texture at (-width * pivot[0], -height * (1 - pivot[1])), then apply
its matrix. Preserve flip_h, flip_v and ascending original sorting order.
Pivots, PPU and GUIDs are read from the nine selected PNG .meta files.
Only rest geometry is reconstructed; native animation, effects and rendering
are the Godot integration's responsibility.

Source-file caveat: 11 original PNGs contain trailing data after IEND:
Royal closed/open, Energy open, and Crystal parts 01 through 08.
Their trailing bytes are preserved byte-for-byte, without normalization.
FFmpeg's stream reader reports an extra-image error for Royal closed.png;
the image payloads of all 19 PNGs decode when bounded by IEND.
Godot import and rendering are validated separately by the native project.

Selected original relative paths -> imported image paths:
${selectedImages.map((image) => `${image.source} -> ${image.path}`).join('\n')}
`;
}

function writeImportFiles(outputs) {
  const seen = new Set();
  // Preflight every named output before creating anything. Never replace differing bytes.
  const planned = outputs.map((output) => {
    requireValue(allowedOutputs.has(output.path) && !seen.has(output.path) && Buffer.isBuffer(output.bytes),
      `Invalid or duplicate chest output path: ${output.path}.`);
    seen.add(output.path);
    const filename = resolvePath(root, output.path);
    const existing = fs.lstatSync(filename, { throwIfNoEntry: false });
    if (existing) {
      requireValue(existing.isFile(), `Refusing non-regular chest destination: ${output.path}.`);
      requireValue(fs.readFileSync(filename).equals(output.bytes), `Refusing to overwrite differing destination: ${output.path}.`);
    }
    return { ...output, filename, exists: Boolean(existing) };
  });
  let written = 0;
  for (const output of planned) {
    if (!output.exists) {
      fs.mkdirSync(path.dirname(output.filename), { recursive: true });
      fs.writeFileSync(output.filename, output.bytes, { flag: 'wx' });
      written += 1;
    }
  }
  for (const output of planned) {
    requireValue(fs.readFileSync(output.filename).equals(output.bytes), `Chest output verification failed: ${output.path}.`);
  }
  return { written, unchanged: planned.length - written };
}

function importChests(sourceRoot = DEFAULT_SOURCE) {
  requireValue(typeof sourceRoot === 'string' && sourceRoot.trim().length > 0, 'A source pack directory is required.');
  const images = selectedImages.map((image) => {
    const bytes = fs.readFileSync(resolvePath(sourceRoot, image.source));
    const dimensions = pngDimensions(bytes, image.source);
    if (/\/(?:royal|energy)\//.test(image.path)) {
      requireValue(dimensions.width === 1024 && dimensions.height === 1024, `Expected a complete 1024px chest image: ${image.source}.`);
    }
    return { bytes, file: { path: image.path, source: image.source, sha256: sha256(bytes), ...dimensions } };
  });
  const sprites = crystalImages.map((image) => ({
    name: image.name, texture: image.path,
    ...parseSpriteMetadata(fs.readFileSync(resolvePath(sourceRoot, `${image.source}.meta`), 'utf8'), `${image.source}.meta`)
  }));
  const prefab = fs.readFileSync(path.join(sourceRoot, 'Chests', 'Crystal', 'PF_Chest_Crystal.prefab'), 'utf8');
  const manifest = {
    version: 1,
    source: SOURCE_NAME,
    styles: {
      royal: { closed: 'assets/chests/royal/closed.png', open: 'assets/chests/royal/open.png' },
      energy: { closed: 'assets/chests/energy/closed.png', open: 'assets/chests/energy/open.png' },
      crystal: { parts: buildCrystalParts(prefab, sprites) }
    },
    particles,
    files: images.map((image) => image.file)
  };
  const outputs = [
    ...images.map((image) => ({ path: image.file.path, bytes: image.bytes })),
    { path: 'assets/chests/SOURCE.txt', bytes: Buffer.from(sourceDescription(), 'utf8') },
    { path: 'assets/chests/manifest.json', bytes: Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8') }
  ];
  return { manifest, ...writeImportFiles(outputs) };
}

if (require.main === module) {
  const args = process.argv.slice(2);
  requireValue(args.length <= 1, 'Usage: node tools\\import-chests.cjs [source-pack-directory]');
  const result = importChests(args[0] ?? DEFAULT_SOURCE);
  console.log(`Imported ${result.manifest.files.length} PNGs and nine Crystal rest transforms; ${result.written} files written, ${result.unchanged} identical files preserved.`);
}

module.exports = { DEFAULT_SOURCE, parseSpriteMetadata, buildCrystalParts, writeImportFiles, importChests };
