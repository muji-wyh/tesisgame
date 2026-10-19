const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');
const { validateManifest, bundleInventory, LIMITS } = require('../web/professional-media.js');

const hash = bytes => createHash('sha256').update(bytes).digest('hex');

function readMetadata(root, source, maxBytes = 8 * 1024 * 1024) {
  if (typeof source !== 'string' || !/^res:\/\/data\/professional\/[a-zA-Z0-9_./-]+\.json$/.test(source) || source.includes('..')) {
    throw new Error('Professional metadata needs a safe repository JSON path.');
  }
  const filename = path.join(root, source.slice(6));
  const stat = fs.lstatSync(filename);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size > maxBytes) throw new Error('Professional metadata is invalid or too large.');
  return fs.readFileSync(filename);
}

function collectProfessionalMedia(root) {
  const catalogPath = path.join(root, 'data/professional/catalog.json');
  if (!fs.existsSync(catalogPath)) return [];
  const catalog = JSON.parse(readMetadata(root, 'res://data/professional/catalog.json'));
  const resources = new Map();
  const bundles = new Map();
  for (const entry of catalog.courses) {
    const course = JSON.parse(readMetadata(root, entry.manifest));
    if (course.id !== entry.id) throw new Error('Professional course identity changed.');
    for (const module of course.modules) {
      if (module.status !== 'ready') continue;
      const descriptor = module.media_manifest;
      if (!descriptor || !/^[a-f0-9]{64}$/.test(descriptor.sha256)) throw new Error('A ready module needs a hashed media manifest.');
      const bytes = readMetadata(root, descriptor.path, LIMITS.manifest);
      if (hash(bytes) !== descriptor.sha256) throw new Error('Professional media manifest hash mismatch.');
      const manifest = validateManifest(JSON.parse(bytes), { course_id: course.id, module_id: module.id,
        curriculum_revision: course.curriculum_revision });
      for (const [key, members] of bundleInventory(manifest)) {
        if (bundles.has(key) && !isDeepStrictEqual(bundles.get(key), members)) {
          throw new Error('Shared bundle membership changed without a new bundle revision.');
        }
        bundles.set(key, members);
      }
      for (const resource of manifest.resources) {
        const previous = resources.get(resource.id);
        if (previous && !isDeepStrictEqual(previous, resource)) throw new Error('Shared media metadata conflicts.');
        resources.set(resource.id, resource);
      }
    }
  }
  const result = [];
  for (const resource of resources.values()) {
    const source = path.join(root, resource.path);
    const stat = fs.lstatSync(source);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.size !== resource.compressed_bytes) throw new Error(`Professional media size mismatch: ${resource.path}`);
    const bytes = fs.readFileSync(source);
    if (hash(bytes) !== resource.sha256) throw new Error(`Professional media hash mismatch: ${resource.path}`);
    result.push({ ...resource, source, bytes });
  }
  return result;
}

function packageProfessionalMedia(root, output) {
  // Validate the complete selection before writing any output. Media stays loose
  // and content addressed so Godot can release it instead of mounting more PCKs.
  const resources = collectProfessionalMedia(root);
  if (resources.length) fs.mkdirSync(path.join(output, 'professional-media'), { recursive: true });
  for (const resource of resources) fs.writeFileSync(path.join(output, resource.path), resource.bytes);
  return { resources: resources.length, bytes: resources.reduce((sum, resource) => sum + resource.compressed_bytes, 0) };
}

module.exports = { collectProfessionalMedia, packageProfessionalMedia };
