'use strict';
// Scratch delivery guards. Requiring this module never writes files or starts Godot.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const base = path.resolve(__dirname, '..');
const root = path.resolve(base, '../../../..');
const {loadProfessionalContent, auditProfessionalContent, schemaErrors} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const constants = Object.freeze({
  revision: 'delivery-r02',
  sense: 'counter.service-surface.n',
  authorSha: 'c06028630c91070f11d42a3eb57349b294b9d9331f0881faf31fc6c00bce7fd0',
  imageSha: 'c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a',
  imagePixelSha: '342eb324b6655d4fb2437974a1dbcc8e83d7d37875459e54c0f6926102be9a98',
  fifth: 'data/professional/provenance/retail-module03-morphology-fifth10-2026-10-16.json',
  fifthReceipt: 'build/professional-english/retail-module03-morphology-review/fifth10/integration-receipt.json',
  provenance: 'data/professional/provenance/retail-counter-image-2026-10-16.json',
  retained: 'docs/assets/sources/professional-retail-counter',
  target: 'data/professional/lexemes/retail-pilot.json',
  helperSource: 'build/professional-english/retail-module03-morphology-review/fifth10/serializer-review-r01/guarded-transaction.cjs',
  transaction: 'build/professional-english/transactions/counter-image-delivery-r02',
  priorPreparationSha: '4d47646097a23f4d2a8fe49e6755e7e2847d0fb086931f5cb75a29721400723f',
  obsolete: 'Picture suitability and word-media production remain pending.',
  replacement: 'The counter image has completed scoped physical-sense picture review and integration; word audio remains pending.',
  deliveryFiles: ['delivery-lib.cjs', 'bind-current-baseline.cjs', 'integrate-reviewed.cjs', 'transaction-plan.cjs',
    'guarded-transaction.cjs', 'helper-origin.json', 'adapter-tests.cjs', 'persisted-test-transforms.cjs', 'update-persisted-tests.cjs',
    'HANDOFF.md', 'source-doc-draft.md', 'v1-risk-review.json']
});
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const serialized = value => JSON.stringify(value, null, 2) + '\n';
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const writeNew = (file, value) => fs.writeFileSync(file, serialized(value), {flag: 'wx'});
function within(directory, relativePath) {
  assert.equal(typeof relativePath, 'string');
  const file = path.resolve(directory, relativePath);
  const rel = path.relative(directory, file);
  assert.ok(rel && rel !== '..' && !rel.startsWith('..' + path.sep) && !path.isAbsolute(rel), 'Path must stay inside the intended directory: ' + relativePath);
  return file;
}
const inRoot = file => within(root, file);
const inBase = file => within(base, file);
function checkSha(value) { assert.match(value || '', /^[a-f0-9]{64}$/); return value; }
function parseArgs(allowedValues, allowedFlags = [], textValues = []) {
  const args = process.argv.slice(2), result = {};
  while (args.length) {
    const key = args.shift();
    assert.equal(Object.hasOwn(result, key), false, 'Duplicate option: ' + key);
    if (allowedFlags.includes(key)) result[key] = true;
    else {
      assert.ok(allowedValues.includes(key) || textValues.includes(key), 'Unsupported option: ' + key);
      result[key] = args.shift();
      if (allowedValues.includes(key)) checkSha(result[key]);
      else assert.ok(typeof result[key] === 'string' && result[key].length > 0, 'Missing value: ' + key);
    }
  }
  for (const key of [...allowedValues, ...textValues]) assert.ok(Object.hasOwn(result, key), 'Required option: ' + key);
  return result;
}
function createChecks() {
  let checks = 0;
  return {same(a, b, label = '') { assert.deepEqual(a, b, label); checks++; }, count() { return checks; }};
}
function professionalFiles() {
  const files = [];
  function visit(rel) {
    for (const entry of fs.readdirSync(inRoot(rel), {withFileTypes: true})) {
      const child = rel + '/' + entry.name;
      if (entry.isDirectory()) visit(child);
      else if (entry.name.endsWith('.json')) files.push(child);
    }
  }
  visit('data/professional');
  return files.sort();
}
function verifyPriorDelivery(same) {
  const priorPath = inBase('delivery-r01/preparation-receipt.json');
  same(raw(priorPath), constants.priorPreparationSha, 'Frozen v1 preparation is preserved');
  const prior = read(priorPath);
  for (const [file, sha] of Object.entries(prior.delivery_files)) same(raw(inBase('delivery-r01/' + file)), sha, 'Frozen v1 delivery file: ' + file);
  return prior;
}
function staticRetainedInputs(receipt, prior) {
  const files = receipt.evidence_files.map(file => file.path).concat(
    'review-receipt.json', 'root-image-review.json',
    ...Object.keys(prior.delivery_files).map(file => 'delivery-r01/' + file),
    'delivery-r01/preparation-receipt.json',
    ...constants.deliveryFiles.map(file => constants.revision + '/' + file),
    constants.revision + '/preparation-receipt.json');
  assert.equal(new Set(files).size, files.length);
  return files.map(file => ({source: file, path: constants.retained + '/' + file, policy: 'immutable'}));
}
function deferredRetainedInputs() {
  return ['preimages.json', 'binding-receipt.json'].map(file => ({source: constants.revision + '/' + file,
    path: constants.retained + '/' + constants.revision + '/' + file, policy: 'create'}));
}
function allowedOutputPaths(receipt, prior) {
  return [constants.target, constants.provenance, 'professional-media/' + constants.imageSha + '.png',
    relative(path.join(__dirname, 'integration-receipt.json')),
    ...staticRetainedInputs(receipt, prior).map(file => file.path), ...deferredRetainedInputs().map(file => file.path)];
}
function observeOutputPreimages(same, receipt, prior) {
  const {observedBytes, sha256} = require('./transaction-plan.cjs');
  const result = {};
  for (const input of staticRetainedInputs(receipt, prior)) {
    const actual = observedBytes(root, input.path);
    if (actual !== null) same(sha256(actual), raw(inBase(input.source)), 'Pre-existing retained evidence must be identical: ' + input.path);
    result[input.path] = actual === null ? null : sha256(actual);
  }
  const imagePath = 'professional-media/' + constants.imageSha + '.png', image = observedBytes(root, imagePath);
  if (image !== null) same(sha256(image), constants.imageSha, 'Pre-existing immutable image bytes');
  result[imagePath] = image === null ? null : sha256(image);
  for (const file of [constants.provenance, relative(path.join(__dirname, 'integration-receipt.json')),
    ...deferredRetainedInputs().map(input => input.path)]) {
    same(observedBytes(root, file), null, 'One-shot output must be absent: ' + file);
    result[file] = null;
  }
  result[constants.target] = raw(inRoot(constants.target));
  same(Object.keys(result).sort(), allowedOutputPaths(receipt, prior).sort());
  return result;
}
function verifyEvidence(same, approvalSha = null) {
  const receiptFile = inBase('review-receipt.json');
  same(raw(receiptFile), constants.authorSha, 'Frozen author receipt');
  const receipt = read(receiptFile);
  same(receipt.sense_id, constants.sense);
  same(receipt.status, 'frozen_scratch_candidate_pending_independent_root_acceptance');
  same(receipt.selected_candidate.file.sha256, constants.imageSha);
  same(receipt.selected_candidate.rgba_pixel_sha256, constants.imagePixelSha);
  same(receipt.selected_candidate.size, [512, 293]);
  same(receipt.selected_candidate.file.bytes, 31426);
  same(receipt.selected_candidate.decoded_cpu_gpu_bytes, 1200128);
  same(receipt.native_validation.selected_checks, 21);
  same(receipt.native_validation.selected_failures, 0);
  same(receipt.source_integrity.original_and_retained_file_checks, 20);
  same(receipt.source_integrity.failures, 0);
  for (const file of receipt.evidence_files) {
    same(raw(inBase(file.path)), file.sha256, file.path);
    same(fs.statSync(inBase(file.path)).size, file.bytes, file.path + ' bytes');
  }
  for (const file of receipt.render_dependencies) same(raw(inRoot(file.path)), file.sha256, file.path);
  const sourceRecords = receipt.sources.map(source => read(inBase(source.record.path)));
  same(receipt.sources.map(source => source.available_animations), [[], []]);
  same(sourceRecords.map(source => source.source), ['https://kenney.nl/assets/furniture-kit', 'https://kenney.nl/assets/car-kit']);
  same(sourceRecords.map(source => source.creator), ['Kenney', 'Kenney']);
  same(sourceRecords.map(source => source.license), ['CC0 1.0', 'CC0 1.0']);
  same(sourceRecords.flatMap(source => source.files).length, 20);
  for (const source of sourceRecords) for (const file of source.files) {
    same(raw(file.original_path), file.sha256, file.original_path);
    same(raw(inBase(file.retained_path)), file.sha256, file.retained_path);
  }
  const image = fs.readFileSync(inBase(receipt.selected_candidate.file.path));
  same(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  same([image.readUInt32BE(16), image.readUInt32BE(20)], [512, 293]);
  let approval = null;
  if (approvalSha) {
    same(raw(inBase('root-image-review.json')), checkSha(approvalSha), 'Exact independent root acceptance');
    approval = read(inBase('root-image-review.json'));
    same(approval.status, 'accepted_exact_counter_image_and_scoped_adaptations_for_integration');
    same(approval.sense_id, constants.sense);
    same(approval.approved_brief, receipt.approved_brief);
    same(approval.image_sha256, constants.imageSha);
    same(approval.review_receipt_raw_sha256, constants.authorSha);
    same(typeof approval.reviewer, 'string');
    same(approval.reviewer.length > 0, true);
    if (approval.evidence_files) same(approval.evidence_files, receipt.evidence_files);
    if (approval.render_dependencies) same(approval.render_dependencies, receipt.render_dependencies);
  }
  return {receipt, approval, sourceRecords};
}
function verifyValidation(same, expected, data) {
  assert.match(expected.path, /^build\/professional-english\/continuation-validation-r[0-9]{2,}\.json$/);
  const file = inRoot(expected.path);
  same(raw(file), checkSha(expected.raw_sha256), 'Exact successful root-selected post-fifth10 receipt');
  const validation = read(file);
  same(validation.ok, true);
  same(validation.registry_before_sha256, hash(data));
  same(validation.registry_after_sha256, hash(data));
  same(validation.changed_measured_inputs, []);
  same(validation.before_input_sha256, validation.after_input_sha256);
  same(validation.measured_input_count, Object.keys(validation.after_input_sha256).length);
  same(validation.runs.map(run => run.name), ['node', 'native', 'native-audio']);
  for (const run of validation.runs) {
    same(run.status, 0); same(run.error, null); same(run.signal, null);
    same(raw(inRoot(run.log)), run.log_sha256, run.log);
    if (run.name === 'node') {
      same(run.tests > 0, true); same(run.pass, run.tests); same(run.fail, 0);
      same(run.cancelled, 0); same(run.skipped, 0);
    } else { same(run.checks > 0, true); same(run.failures, 0); }
  }
  for (const [filePath, sha] of Object.entries(validation.after_input_sha256)) same(raw(inRoot(filePath)), sha, 'Validated measured input: ' + filePath);
  for (const filePath of professionalFiles()) same(validation.after_input_sha256[filePath], raw(inRoot(filePath)), 'Validation covers Professional JSON: ' + filePath);
  return validation;
}
function verifyFifth(same, data) {
  const provenance = read(inRoot(constants.fifth)), receipt = read(inRoot(constants.fifthReceipt));
  same(provenance.status, 'ten_exact_morphology_graphs_independently_reviewed_and_integrated');
  same(provenance.independent_approval.accepted, true);
  same(provenance.independent_approval.accepted_for_exact_candidates, true);
  same(receipt.integrated, true);
  same(receipt.provenance_raw_sha256, raw(inRoot(constants.fifth)));
  same(provenance.integration.proposed_registry_sha256, hash(data));
  same(receipt.proposed_registry_sha256, hash(data));
  same(provenance.patches.length, 10);
  for (const patch of provenance.patches) {
    same(data.lexemes.find(entry => entry.id === patch.id), patch.after, 'Integrated fifth10 entry: ' + patch.id);
    same(patch.after.morphology.review.status, 'reviewed');
  }
  for (const source of provenance.sources) same(data.sources.find(item => item.id === source.id), source);
  for (const file of receipt.files) same(raw(inRoot(file.path)), file.raw_sha256, 'Fifth10 written file: ' + file.path);
  same(provenance.integration.transaction_dir, receipt.transaction_dir);
  same(receipt.transaction_dir, 'build/professional-english/transactions/fifth10-r01');
  const transaction = inRoot(receipt.transaction_dir), preparedFile = path.join(transaction, 'prepared.json');
  const states = fs.readdirSync(path.join(transaction, 'states')).filter(file => /^\d{6}-[a-z-]+\.json$/.test(file)).sort();
  same(states.length > 0, true);
  const committed = read(path.join(transaction, 'states', states.at(-1)));
  same(committed.status, 'committed', 'Fifth10 integration receipt requires committed journal');
  same(committed.prepared_sha256, raw(preparedFile));
  for (const file of read(preparedFile).entries) same(raw(inRoot(file.path)), file.after.sha256, 'Fifth10 committed transaction output: ' + file.path);
  return {provenance, receipt};
}
function protect(entry) {
  const result = structuredClone(entry);
  delete result.media.image;
  delete result.editorial_notes;
  return result;
}
function proposedPatch(same, data, evidence) {
  const before = data.lexemes.find(entry => entry.id === constants.sense);
  same(before.media.image.status, 'pending');
  same(before.media.image.brief, evidence.receipt.approved_brief);
  same(before.definition, evidence.receipt.definition);
  same(before.example, evidence.receipt.example);
  same(data.lexemeOrigins[constants.sense], 'res://' + constants.target);
  same(before.media.audio.status, 'pending', 'This exact note replacement requires pending counter audio');
  same(before.editorial_notes.split(constants.obsolete).length, 2, 'Exactly one obsolete picture clause');
  const after = structuredClone(before), destination = 'professional-media/' + constants.imageSha + '.png';
  Object.assign(after.media.image, {
    status: 'integrated', path: 'res://' + destination, sha256: constants.imageSha,
    source: 'Kenney Furniture Kit 2.1: https://kenney.nl/assets/furniture-kit; Kenney Car Kit 3.1: https://kenney.nl/assets/car-kit',
    creator: 'Kenney', license: 'CC0 1.0', acquisition_status: 'integrated',
    review: {status: 'reviewed', reviewer: evidence.approval.reviewer, reviewed_at: '2026-10-16'},
    adaptations: [
      'Four complete acquired Furniture Kit 2.1 kitchenBar models form a broad raised surface with a solid front and a perpendicular staff-side return. Original geometry, materials, textures and source child transforms are preserved; only complete model roots are placed and rotated, then the common assembly is recentered.',
      'One complete acquired Car Kit 3.1 box model supplies the small sealed parcel. Its original geometry, materials, texture and child transforms are preserved; the root is uniformly scaled to 0.16, rotated -10 degrees and placed at the countertop height of 0.42. No added register, refund receipt, printed label or service-function prop is used.',
      'The orthographic camera is at [-1.1,1.8,4], aimed at [0,0.24,0], size 1.55. Ambient energy 0.18 and directional energy 0.38 illuminate a transparent 768 by 768 render. The complete alpha bounds remain within the frame; a 16-pixel margin and proportional Lanczos downscale produce 512 by 293.',
      'Independent root review covers the exact broad-return image and actual Match 126 by 72 and Memory 144 by 74 cards, including the real badge and matched alpha. The pale top has reduced contour contrast on white and the badge overlaps the far-right return, while the solid front and staff-side recess remain readable. This scoped AI picture review is not a participant recognition study, service-function classification, domain approval or module-readiness claim.'
    ]
  });
  after.editorial_notes = before.editorial_notes.replace(constants.obsolete, constants.replacement);
  same(protect(after), protect(before), 'All fields outside image and exact note clause');
  same(after.media.image.brief, before.media.image.brief);
  same(after.media.image.picture_suitable, before.media.image.picture_suitable);
  same(after.media.image.available_animations, before.media.image.available_animations);
  same(schemaErrors(after, 'lexeme'), []);
  const next = structuredClone(data);
  next.lexemes[next.lexemes.findIndex(entry => entry.id === before.id)] = after;
  for (const key of Object.keys(data)) if (key !== 'lexemes') same(next[key], data[key], 'Protected registry key: ' + key);
  same(next.lexemes.filter(entry => entry.id !== before.id), data.lexemes.filter(entry => entry.id !== before.id));
  const envelope = read(inRoot(constants.target));
  same(envelope.lexemes.filter(entry => entry.id === before.id).length, 1);
  envelope.lexemes[envelope.lexemes.findIndex(entry => entry.id === before.id)] = after;
  const resource = {id: 'sha256:' + constants.imageSha, sha256: constants.imageSha, path: destination,
    kind: 'image', format: 'png', compressed_bytes: 31426, decoded_bytes: 1200128, width: 512, height: 293};
  return {before, after, next, envelope, resource, destination};
}
module.exports = {fs, path, assert, base, root, constants, read, raw, hash, serialized, relative, writeNew, within, inRoot, inBase,
  checkSha, parseArgs, createChecks, professionalFiles, verifyPriorDelivery, staticRetainedInputs, deferredRetainedInputs,
  allowedOutputPaths, observeOutputPreimages, verifyEvidence, verifyValidation, verifyFifth, protect, proposedPatch,
  loadProfessionalContent, auditProfessionalContent};
