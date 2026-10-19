const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { collectProfessionalMedia, packageProfessionalMedia } = require('../tools/package-professional-media.cjs');
const { inlineMascot } = require('../tools/prepare-godot.cjs');
const root = path.resolve(__dirname, '..');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'professional-media-package-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const write = (name, value) => {
    const filename = path.join(directory, name);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, typeof value === 'object' && !Buffer.isBuffer(value) ? JSON.stringify(value) : value);
  };
  const bytes = fs.readFileSync(path.join(root, 'assets/images/words/absent.png'));
  const sha256 = hash(bytes);
  const resource = { id: `sha256:${sha256}`, sha256, path: `professional-media/${sha256}.png`, kind: 'image', format: 'png',
    compressed_bytes: bytes.length, width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20),
    decoded_bytes: bytes.readUInt32BE(16) * bytes.readUInt32BE(20) * 8 };
  write(resource.path, bytes);
  const courses = ['retail', 'nursing'].map(id => ({ id, manifest: `res://data/professional/courses/${id}.json` }));
  write('data/professional/catalog.json', { courses });
  for (const { id } of courses) {
    const manifest = Buffer.from(JSON.stringify({ schema_version: 1, course_id: id, module_id: 'module03', curriculum_revision: 'test-v1', resources: [resource] }));
    write(`data/professional/media-manifests/${id}.json`, manifest);
    write(`data/professional/courses/${id}.json`, { id, curriculum_revision: 'test-v1', modules: [
      { id: 'module03', status: 'ready', media_manifest: { path: `res://data/professional/media-manifests/${id}.json`, sha256: hash(manifest) } },
      { id: 'module04', status: 'draft' }
    ] });
  }
  return { directory, resource, bytes, write };
}

test('ready module media stays loose and shared hashes ship once', t => {
  const value = fixture(t);
  const resources = collectProfessionalMedia(value.directory);
  assert.equal(resources.length, 1);
  const output = path.join(value.directory, 'export');
  assert.deepEqual(packageProfessionalMedia(value.directory, output), { resources: 1, bytes: value.bytes.length });
  assert.deepEqual(fs.readFileSync(path.join(output, value.resource.path)), value.bytes);
  assert.equal(fs.readdirSync(output).join(','), 'professional-media');
});

test('manifest and asset integrity failures abort before copying', t => {
  const value = fixture(t);
  const damaged = Buffer.from(value.bytes);
  damaged[damaged.length - 1] ^= 1;
  value.write(value.resource.path, damaged);
  const output = path.join(value.directory, 'export');
  assert.throws(() => packageProfessionalMedia(value.directory, output), /hash mismatch/);
  assert.equal(fs.existsSync(output), false);
  value.write(value.resource.path, value.bytes);
  value.write('data/professional/media-manifests/retail.json', '{}');
  assert.throws(() => collectProfessionalMedia(value.directory), /manifest hash mismatch/);
});

test('versioned shared delivery groups are consistent across courses and ship each resource once', t => {
  const value = fixture(t);
  const bytes = fs.readFileSync(path.join(root, 'assets/images/words/after.png'));
  const sha256 = hash(bytes);
  const other = { ...value.resource, id: `sha256:${sha256}`, sha256, path: `professional-media/${sha256}.png`,
    width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), compressed_bytes: bytes.length,
    decoded_bytes: bytes.readUInt32BE(16) * bytes.readUInt32BE(20) * 8 };
  value.write(other.path, bytes);
  const publish = (id, bundles) => {
    const manifest = Buffer.from(JSON.stringify({ schema_version: 2, course_id: id, module_id: 'module03',
      curriculum_revision: 'grouped-v1', resources: [value.resource, other], bundles }));
    value.write(`data/professional/media-manifests/${id}.json`, manifest);
    value.write(`data/professional/courses/${id}.json`, { id, curriculum_revision: 'grouped-v1', modules: [
      { id: 'module03', status: 'ready', media_manifest: { path: `res://data/professional/media-manifests/${id}.json`, sha256: hash(manifest) } }
    ] });
  };
  const pair = { id: 'shared-word-pictures', revision: '1', resource_ids: [value.resource.id, other.id] };
  publish('retail', [pair]);
  publish('nursing', [{ ...pair, resource_ids: [...pair.resource_ids].reverse() }]);
  assert.equal(collectProfessionalMedia(value.directory).length, 2);
  const changed = [{ ...pair, resource_ids: [value.resource.id] }, { id: 'shared-second-picture', revision: '1', resource_ids: [other.id] }];
  publish('nursing', changed);
  const output = path.join(value.directory, 'export');
  assert.throws(() => packageProfessionalMedia(value.directory, output), /bundle revision/);
  assert.equal(fs.existsSync(output), false, 'A conflicting group must fail before creating output');
  changed[0].revision = '2';
  publish('nursing', changed);
  assert.deepEqual(packageProfessionalMedia(value.directory, output), { resources: 2, bytes: value.bytes.length + bytes.length });
});

test('web shell includes both lazy bridges and metadata export excludes raw media', () => {
  const html = inlineMascot(fs.readFileSync(path.join(root, 'web/shell.html'), 'utf8'));
  assert.ok(!html.includes('$PROFESSIONAL_MEDIA_JS') && !html.includes('$PROFESSIONAL_PROGRESS_JS'));
  assert.ok(html.includes('createProfessionalMediaBridge') && html.includes('professionalMediaCancel(generation)'));
  assert.ok(html.includes('createProfessionalProgressBridge') && html.includes('professionalProgressRequest(text, callback)'));
  const presets = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
  assert.match(presets, /include_filter="[^\n]*data\/professional\/media-manifests\/\*\.json/);
  assert.match(presets, /exclude_filter="professional-media\/\*/);
  const config = JSON.parse(fs.readFileSync(path.join(root, 'web/staticwebapp.config.json')));
  assert.match(config.routes.find(route => route.route === '/professional-media/*').headers['Cache-Control'], /immutable/);
});
