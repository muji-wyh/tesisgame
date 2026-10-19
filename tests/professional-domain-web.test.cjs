const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { expectedPackManifest, preparePackVerification, finishPackVerification,
  validatePackProof, requiresDomainEvidence, verifyDomainEvidence } = require('../tools/professional-domain-web.cjs');
const { snapshotInputs } = require('../tools/web-build-receipt.cjs');

const generated = 'res://data/professional/domain-policy/generated/';
const row = (file, contents) => ({ path: file, bytes: Buffer.byteLength(contents),
  sha256: createHash('sha256').update(contents).digest('hex') });
function releaseFixture() {
  const descriptor = row(`${generated}release.json`, 'descriptor bytes');
  return { descriptor, pin: row('res://scripts/professional_domain_release.gd', 'pin source'),
    generated_inventory: [row(`${generated}themes.json`, 'themes'), descriptor, row(`${generated}index.json`, 'index')] };
}
function proofFor(release) {
  return { ...expectedPackManifest(release), kind: 'professional_domain_pack_proof_v1', ok: true };
}
function directory(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'professional-domain-web-'));
  t.after(() => {
    assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir()) + path.sep));
    fs.rmSync(root, { recursive: true, force: true });
  });
  return root;
}

test('native proof binds exact file bytes and loaded pin constants independent of JSON key order', () => {
  const release = releaseFixture(), proof = proofFor(release);
  proof.generated_inventory = proof.generated_inventory.map(({ path, bytes, sha256 }) => ({ bytes, sha256, path }));
  assert.equal(validatePackProof(release, proof), proof);
  for (const mutate of [
    value => { value.generated_inventory[0].sha256 = '0'.repeat(64); },
    value => { value.generated_inventory[0].bytes++; },
    value => { value.generated_inventory.pop(); },
    value => { value.generated_inventory.push(row(`${generated}stale.json`, 'stale')); },
    value => { value.pin_constants.DESCRIPTOR_SHA256 = '0'.repeat(64); },
    value => { value.pin_constants.DESCRIPTOR_BYTES++; },
    value => { value.pin_constants.POLICY_VERSION = 'other-policy'; },
    value => { value.pin_constants.ACCEPTED_IDS = ['unreviewed']; },
    value => { value.ok = false; }
  ]) {
    const changed = structuredClone(proof); mutate(changed);
    assert.throws(() => validatePackProof(release, changed), /does not match/);
  }
});

test('export inventory rejects caller-selected paths, duplicate artifacts and mismatched descriptor pins', () => {
  for (const bad of ['res://elsewhere/index.json', `${generated}../index.json`, `${generated}modules//a.json`,
    `${generated}modules\\a.json`, `${generated}index.json/child.json`]) {
    const release = releaseFixture(); release.generated_inventory[0].path = bad;
    assert.throws(() => expectedPackManifest(release), /unique fixed-root/);
  }
  const duplicate = releaseFixture(); duplicate.generated_inventory.push(duplicate.generated_inventory[0]);
  assert.throws(() => expectedPackManifest(duplicate), /unique fixed-root/);
  const changed = releaseFixture(); changed.descriptor = { ...changed.descriptor, bytes: 2 };
  assert.throws(() => expectedPackManifest(changed), /descriptor is absent or mismatched/);
});

test('only a fresh native proof for the unchanged raw PCK can become build evidence', t => {
  const workDir = directory(t), packPath = path.join(workDir, 'index.pck'), release = releaseFixture();
  fs.writeFileSync(packPath, 'raw native PCK bytes');
  const preparation = preparePackVerification({ release, workDir, packPath });
  assert.throws(() => finishPackVerification({ release, packPath, preparation }), /ENOENT/);
  fs.writeFileSync(preparation.proofPath, JSON.stringify(proofFor(release)));
  const evidence = finishPackVerification({ release, packPath, preparation });
  assert.deepEqual(evidence.decoded_pack, preparation.rawPack);
  assert.throws(() => preparePackVerification({ release, workDir, packPath }), /cannot be reused/);
  fs.appendFileSync(packPath, 'changed');
  assert.throws(() => finishPackVerification({ release, packPath, preparation }), /changed during native/);
});

test('a Professional checkout cannot write a legacy receipt without domain proof', t => {
  const root = directory(t);
  assert.equal(requiresDomainEvidence(root), false);
  verifyDomainEvidence(root, undefined, Buffer.from('legacy fixture'));
  const target = path.join(root, 'data/professional/catalog.json');
  fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, '{}');
  assert.equal(requiresDomainEvidence(root), true);
  assert.throws(() => verifyDomainEvidence(root, undefined, Buffer.from('pack')), /requires audited native pack evidence/);
});

test('the build source inventory protects domain tooling and the external native closure verifier', t => {
  const root = directory(t);
  const inputs = ['tools/professional-domain/compiler.cjs', 'tools/professional-domain/audit.cjs',
    'tools/professional-domain-web.cjs', 'tests/godot/professional_domain_pack_verifier.gd'];
  for (const name of inputs) {
    const target = path.join(root, name); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, name);
  }
  assert.deepEqual(snapshotInputs(root).map(file => file.path).sort(), inputs.sort());
});
