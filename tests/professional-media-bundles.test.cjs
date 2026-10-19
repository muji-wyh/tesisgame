const test = require('node:test');
const assert = require('node:assert/strict');
const api = require('../web/professional-media.js');

// Metadata-only boundary cases. These are not artwork or valid encoded files.
const resource = (index, decoded = 16 * 1024 * 1024) => {
  const sha256 = index.toString(16).padStart(64, '0');
  return { id: `sha256:${sha256}`, sha256, path: `professional-media/${sha256}.png`,
    kind: 'image', format: 'png', width: 1024, height: decoded / (1024 * 8),
    decoded_bytes: decoded, compressed_bytes: 1024 };
};
const manifest = (count = 3) => {
  const resources = Array.from({ length: count }, (_, index) => resource(index));
  return { schema_version: 2, course_id: 'retail', module_id: 'module03', curriculum_revision: 'bundle-test-1',
    resources, bundles: resources.map((value, index) => ({ id: `shared-fixture-${index}`, revision: '1', resource_ids: [value.id] })) };
};

test('grouped delivery permits a module over 32 MiB without raising any bundle or residency cap', () => {
  const value = manifest();
  assert.equal(api.validateManifest(value).resources.length, 3);
  assert.equal(api.bundleInventory(value).size, 3);
  assert.equal(api.validateDependencies(value, value.resources.map(item => item.id)).schema_version, 2);
  assert.equal(api.validateManifest(manifest(8)).resources.length, 8, '128 MiB of unique resources is the inclusive cap');
  assert.throws(() => api.validateManifest(manifest(9)), /128 MiB/);
  const oversized = manifest();
  oversized.bundles = [{ id: 'shared-fixture', revision: '1', resource_ids: oversized.resources.map(item => item.id) }];
  assert.throws(() => api.validateManifest(oversized), /32 MiB/);
  const transfer = manifest();
  for (const value of transfer.resources) value.compressed_bytes = 4 * 1024 * 1024;
  assert.throws(() => api.validateManifest(transfer), /10 MiB/);
});

test('bundle coverage, membership and identities fail closed before a transfer', () => {
  for (const bundles of [undefined, null, [], [{ id: 'x', revision: '1', resource_ids: [] }]]) {
    assert.throws(() => api.validateManifest({ ...manifest(), bundles }), /bundle/i);
  }
  const value = manifest();
  assert.throws(() => api.validateManifest({ ...value, bundles: value.bundles.slice(1) }), /Every module/);
  const missing = structuredClone(value);
  missing.bundles[0].resource_ids = [resource(99).id];
  assert.throws(() => api.validateManifest(missing), /absent media/);
  const duplicate = structuredClone(value);
  duplicate.bundles[0].resource_ids.push(duplicate.bundles[0].resource_ids[0]);
  assert.throws(() => api.validateManifest(duplicate), /only once/);
  assert.throws(() => api.validateManifest({ ...value, bundles: [...value.bundles, value.bundles[0]] }), /only once/);
  for (const key of ['id', 'revision']) {
    const invalid = structuredClone(value); invalid.bundles[0][key] = '';
    assert.throws(() => api.validateManifest(invalid), /stable identity/);
  }
});

test('shared media is counted once across stable groups and revisions remain distinct', () => {
  const value = manifest(2);
  const shared = { id: 'shared-pair', revision: '1', resource_ids: value.resources.map(item => item.id) };
  value.bundles.push(shared);
  const inventory = api.bundleInventory(value);
  value.bundles.reverse(); shared.resource_ids.reverse();
  assert.deepEqual(api.bundleInventory(value).get(JSON.stringify(['shared-pair', '1'])), inventory.get(JSON.stringify(['shared-pair', '1'])));
  const other = structuredClone(value); other.bundles[0].revision = '2';
  assert.ok(api.bundleInventory(other).has(JSON.stringify(['shared-pair', '2'])));
  value.resources.push(value.resources[0]);
  assert.throws(() => api.validateManifest(value), /only once/);
});

test('legacy ungrouped manifests retain their original 32 MiB contract', () => {
  const { bundles, ...small } = manifest(2); small.schema_version = 1;
  assert.equal(api.validateManifest(small).schema_version, 1);
  assert.equal(api.bundleInventory(small).size, 0);
  assert.throws(() => api.validateManifest({ ...small, bundles }), /Version 1/);
  assert.throws(() => api.validateManifest({ ...small, resources: manifest(3).resources }), /32 MiB/);
  assert.throws(() => api.validateManifest({ ...manifest(), schema_version: 3 }), /invalid/);
});
