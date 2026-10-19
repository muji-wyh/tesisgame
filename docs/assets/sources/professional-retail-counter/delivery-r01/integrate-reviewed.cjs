'use strict';
// Root-owned one-shot serializer. Without --integrate this is strictly read-only.
const lib = require('./delivery-lib.cjs');
const {fs, path, constants, read, raw, hash, serialized, writeNew, inRoot, inBase, createChecks, parseArgs, professionalFiles,
  verifyEvidence, verifyValidation, verifyFifth, proposedPatch, loadProfessionalContent, auditProfessionalContent, root} = lib;
const args = parseArgs(['--preimages-sha256'], ['--integrate']);
const integrate = args['--integrate'] === true, checks = createChecks(), {same} = checks;
const prePath = path.join(__dirname, 'preimages.json'), bindingPath = path.join(__dirname, 'binding-receipt.json');
same(raw(prePath), args['--preimages-sha256'], 'Explicit root-selected frozen baseline');
const pre = read(prePath), binding = read(bindingPath), bindingRaw = raw(bindingPath);
same(pre.status, 'frozen_exact_post_fifth10_validated_registry_for_root_counter_image_integration');
same(pre.sense_id, constants.sense); same(pre.target, constants.target);
same(pre.author_receipt_raw_sha256, constants.authorSha);
same(pre.fifth10.provenance_path, constants.fifth); same(pre.fifth10.receipt_path, constants.fifthReceipt);
same(binding.preimages_raw_sha256, raw(prePath));
same(binding.status, 'scratch_baseline_bound_no_production_writes');
same(binding.production_content_written, false);
same(binding.baseline_registry_sha256, pre.baseline_registry_sha256);
same(binding.proposed_registry_sha256, pre.proposed_registry_sha256);
same(binding.validation_raw_sha256, pre.validation.raw_sha256);
same(binding.root_image_review_raw_sha256, pre.root_image_review_raw_sha256);
same(binding.serializer_raw_sha256, raw(__filename));
same(Object.keys(pre.delivery_files).sort(), [...constants.deliveryFiles].sort());
const data = loadProfessionalContent(root);
function verifyBaseline() {
  same(raw(prePath), args['--preimages-sha256']); same(raw(bindingPath), bindingRaw);
  same(raw(path.join(__dirname, 'preparation-receipt.json')), pre.preparation_receipt_raw_sha256);
  for (const [file, sha] of Object.entries(pre.delivery_files)) same(raw(path.join(__dirname, file)), sha, 'Delivery file changed: ' + file);
  same(professionalFiles(), Object.keys(pre.professional_json_raw_sha256));
  for (const [file, sha] of Object.entries(pre.professional_json_raw_sha256)) same(raw(inRoot(file)), sha, 'Professional JSON changed: ' + file);
  same(raw(inRoot(constants.target)), pre.target_raw_sha256);
  same(raw(inRoot(constants.fifth)), pre.fifth10.provenance_raw_sha256);
  same(raw(inRoot(constants.fifthReceipt)), pre.fifth10.receipt_raw_sha256);
  const validation = verifyValidation(same, pre.validation, data);
  same(validation.after_input_sha256, pre.validated_measured_inputs);
  same(validation.measured_input_count, pre.validation.measured_input_count);
  verifyFifth(same, data);
  same(hash(data), pre.baseline_registry_sha256);
  same(hash(loadProfessionalContent(root)), pre.baseline_registry_sha256, 'Registry changed after preparation');
  return verifyEvidence(same, pre.root_image_review_raw_sha256);
}
const evidence = verifyBaseline();
same(auditProfessionalContent({rootDir: root, data}).errors, []);
const patch = proposedPatch(same, data, evidence);
same(patch.before, pre.counter_entry);
same(hash(lib.protect(patch.before)), pre.protected_counter_fields_sha256);
same({before: patch.before, after: patch.after}, pre.proposed_patch);
same(hash(patch.next), pre.proposed_registry_sha256); same(patch.resource, pre.resource);
for (const file of [constants.provenance, constants.retained, patch.destination]) same(fs.existsSync(inRoot(file)), false, 'One-shot output already exists: ' + file);
const retainedFiles = evidence.receipt.evidence_files.map(file => file.path).concat(
  'review-receipt.json', 'root-image-review.json',
  ...constants.deliveryFiles.map(file => 'delivery-r01/' + file),
  'delivery-r01/preimages.json', 'delivery-r01/binding-receipt.json', 'delivery-r01/preparation-receipt.json');
same(new Set(retainedFiles).size, retainedFiles.length);
const retainedManifest = retainedFiles.map(file => ({path: file, bytes: fs.statSync(inBase(file)).size, sha256: raw(inBase(file))}));
const summary = {schema: 1, dry_run: !integrate, integrated: false, integration_ready: true,
  before_registry_sha256: hash(data), proposed_registry_sha256: hash(patch.next), resource: patch.resource,
  image_sha256: constants.imageSha, author_receipt_raw_sha256: constants.authorSha,
  root_image_review_raw_sha256: pre.root_image_review_raw_sha256,
  preimages_raw_sha256: raw(prePath), binding_receipt_raw_sha256: bindingRaw,
  serializer_raw_sha256: raw(__filename), delivery_library_raw_sha256: raw(path.join(__dirname, 'delivery-lib.cjs')),
  validation: pre.validation, fifth10: pre.fifth10, retained_file_count: retainedManifest.length,
  only_registry_edits: ['counter.service-surface.n media.image', 'counter.service-surface.n one obsolete pending-picture clause'],
  scope: 'Scoped physical-sense image integration. Production-loader delivery and post-integration validation are pending.'};
verifyBaseline();
if (!integrate) { console.log(JSON.stringify({...summary, checks: checks.count()})); process.exit(0); }
const integrationPath = path.join(__dirname, 'integration-receipt.json');
same(fs.existsSync(integrationPath), false, 'Do not repeat an integration');
for (const file of retainedManifest) {
  const from = inBase(file.path), to = lib.within(inRoot(constants.retained), file.path);
  same(raw(from), file.sha256);
  fs.mkdirSync(path.dirname(to), {recursive: true});
  fs.copyFileSync(from, to, fs.constants.COPYFILE_EXCL);
  same(raw(to), file.sha256); same(fs.statSync(to).size, file.bytes);
}
fs.copyFileSync(inBase(evidence.receipt.selected_candidate.file.path), inRoot(patch.destination), fs.constants.COPYFILE_EXCL);
same(raw(inRoot(patch.destination)), constants.imageSha);
// A second complete baseline check protects against concurrent edits during retained-file copies.
verifyBaseline();
fs.writeFileSync(inRoot(constants.target), serialized(patch.envelope));
same(loadProfessionalContent(root), patch.next);
const audit = auditProfessionalContent({rootDir: root, data: patch.next}); same(audit.errors, []);
const provenance = {schema: 1, status: 'reviewed_image_integrated_pending_production_delivery_validation',
  independent_approval: evidence.approval, source_records: ['source-record.json', 'parcel-source-record.json'].map(file => constants.retained + '/' + file),
  retained_evidence: constants.retained, retained_files: retainedManifest, resource: patch.resource,
  patches: [{id: constants.sense, origin: 'res://' + constants.target, before: patch.before, after: patch.after,
    before_sha256: hash(patch.before), protected_fields_sha256: hash(lib.protect(patch.before))}],
  before_registry_sha256: hash(data), after_registry_sha256: hash(patch.next),
  integration_guards: {serializer_raw_sha256: summary.serializer_raw_sha256, delivery_library_raw_sha256: summary.delivery_library_raw_sha256,
    preimages_raw_sha256: summary.preimages_raw_sha256, binding_receipt_raw_sha256: bindingRaw,
    baseline_registry_sha256: pre.baseline_registry_sha256, validation: pre.validation, fifth10: pre.fifth10},
  audit: {errors: 0, warnings: audit.warnings.length, summary: audit.summary}};
writeNew(inRoot(constants.provenance), provenance);
same(hash(loadProfessionalContent(root)), hash(patch.next));
const integrated = {...summary, dry_run: false, integrated: true, checks: checks.count(),
  provenance: constants.provenance, provenance_raw_sha256: raw(inRoot(constants.provenance)),
  target: constants.target, target_after_raw_sha256: raw(inRoot(constants.target)),
  after_registry_sha256: hash(patch.next), audit: provenance.audit};
writeNew(integrationPath, integrated);
console.log(JSON.stringify(integrated));
