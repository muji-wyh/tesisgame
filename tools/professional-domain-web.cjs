const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');

const GENERATED_ROOT = 'res://data/professional/domain-policy/generated/';
const DESCRIPTOR_PATH = `${GENERATED_ROOT}release.json`;
const PIN_PATH = 'res://scripts/professional_domain_release.gd';
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const same = isDeepStrictEqual;

function pinConstants(descriptor) {
  return {
    SCHEMA_VERSION: 1, POLICY_VERSION: 'ordinary-lexical-v3',
    CONTEXT_BOUNDARY: 'containing-modules-v1', DESCRIPTOR_PATH,
    DESCRIPTOR_BYTES: descriptor.bytes, DESCRIPTOR_SHA256: descriptor.sha256,
    GENERATED_ROOT
  };
}

function expectedPackManifest(release) {
  const validFile = file => file && typeof file.path === 'string' &&
    Number.isSafeInteger(file.bytes) && file.bytes > 0 && /^[a-f0-9]{64}$/.test(file.sha256);
  if (!validFile(release?.descriptor) || release.descriptor.path !== DESCRIPTOR_PATH ||
      !validFile(release?.pin) || release.pin.path !== PIN_PATH ||
      !Array.isArray(release.generated_inventory) || release.generated_inventory.length < 3) {
    throw new Error('Professional domain export needs an audited release descriptor, pin and inventory.');
  }
  const files = release.generated_inventory.map(file => ({ path: file.path, bytes: file.bytes, sha256: file.sha256 }));
  if (files.some(file => !validFile(file) || !file.path.startsWith(GENERATED_ROOT) ||
      !/^[a-z0-9/-]+\.json$/.test(file.path.slice(GENERATED_ROOT.length)) || file.path.includes('//', 6)) ||
      new Set(files.map(file => file.path)).size !== files.length) {
    throw new Error('Professional domain export inventory must contain unique fixed-root JSON paths.');
  }
  files.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  if (!same(files.find(file => file.path === DESCRIPTOR_PATH), {
    path: DESCRIPTOR_PATH, bytes: release.descriptor.bytes, sha256: release.descriptor.sha256
  })) throw new Error('Professional domain descriptor is absent or mismatched in its export inventory.');
  return { schema_version: 1, kind: 'professional_domain_pack_verification_v1',
    generated_inventory: files, pin_constants: pinConstants(release.descriptor) };
}

function rawPackIdentity(filename) {
  const bytes = fs.readFileSync(filename);
  if (!bytes.length) throw new Error('The raw Web pack is empty.');
  return { bytes: bytes.length, sha256: digest(bytes) };
}

function preparePackVerification({ release, workDir, packPath }) {
  const manifest = expectedPackManifest(release);
  const manifestPath = path.join(workDir, 'web-pack-manifest.json');
  const proofPath = path.join(workDir, 'web-pack-proof.json');
  if (fs.existsSync(proofPath)) throw new Error('A domain pack proof cannot be reused.');
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
  return { manifestPath, proofPath, rawPack: rawPackIdentity(packPath) };
}

function validatePackProof(release, proof) {
  const expected = expectedPackManifest(release);
  if (proof?.schema_version !== 1 || proof.kind !== 'professional_domain_pack_proof_v1' || proof.ok !== true ||
      !same(proof.generated_inventory, expected.generated_inventory) ||
      !same(Object.keys(proof.pin_constants || {}).sort(), Object.keys(expected.pin_constants).sort()) ||
      Object.entries(expected.pin_constants).some(([key, value]) => proof.pin_constants[key] !== value)) {
    throw new Error('Native Web pack proof does not match the audited Professional domain release.');
  }
  return proof;
}

function finishPackVerification({ release, packPath, preparation }) {
  if (!same(rawPackIdentity(packPath), preparation.rawPack)) {
    throw new Error('The raw Web pack changed during native domain verification.');
  }
  const proof = JSON.parse(fs.readFileSync(preparation.proofPath, 'utf8'));
  validatePackProof(release, proof);
  return { release, native_proof: proof, decoded_pack: preparation.rawPack };
}

function requiresDomainEvidence(root) {
  return ['data/professional/catalog.json', 'data/professional/domain-policy', 'scripts/professional_domain_release.gd']
    .some(relative => fs.existsSync(path.join(root, relative)));
}

function verifyDomainEvidence(root, evidence, decodedPack) {
  if (!requiresDomainEvidence(root) && evidence == null) return;
  if (!evidence) throw new Error('Professional domain Web export requires audited native pack evidence.');
  validatePackProof(evidence.release, evidence.native_proof);
  require('./professional-domain/package.cjs').verifyPreparedRelease({ rootDir: root, report: evidence.release });
  if (!decodedPack || !same(evidence.decoded_pack, { bytes: decodedPack.length, sha256: digest(decodedPack) })) {
    throw new Error('The decoded Web pack does not match the Professional domain native verification.');
  }
}

module.exports = { expectedPackManifest, preparePackVerification, finishPackVerification,
  validatePackProof, requiresDomainEvidence, verifyDomainEvidence };
