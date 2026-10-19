'use strict';
// Root-owned scratch-only binding; requires successful post-fifth10 validation and exact root acceptance.
const lib = require('./delivery-lib.cjs');
const {fs, path, constants, read, raw, hash, writeNew, inRoot, inBase, createChecks, parseArgs, professionalFiles,
  verifyEvidence, verifyValidation, verifyFifth, proposedPatch, loadProfessionalContent, auditProfessionalContent, root} = lib;
const args = parseArgs(['--root-approval-sha256', '--validation-sha256'], [], ['--validation-path']);
const checks = createChecks(), {same} = checks;
const prePath = path.join(__dirname, 'preimages.json'), receiptPath = path.join(__dirname, 'binding-receipt.json');
same(fs.existsSync(prePath), false, 'Frozen baseline must not be overwritten');
same(fs.existsSync(receiptPath), false, 'Binding receipt must not be overwritten');
const preparationPath = path.join(__dirname, 'preparation-receipt.json'), preparation = read(preparationPath);
same(preparation.status, 'prepared_unbound_no_production_writes');
same(preparation.production_content_written, false); same(preparation.baseline_bound, false);
same(Object.keys(preparation.delivery_files).sort(), [...constants.deliveryFiles].sort());
for (const [file, sha] of Object.entries(preparation.delivery_files)) same(raw(path.join(__dirname, file)), sha);
const evidence = verifyEvidence(same, args['--root-approval-sha256']);
const data = loadProfessionalContent(root);
const validationRecord = {path: args['--validation-path'], raw_sha256: args['--validation-sha256']};
const validation = verifyValidation(same, validationRecord, data);
verifyFifth(same, data);
same(auditProfessionalContent({rootDir: root, data}).errors, []);
const patch = proposedPatch(same, data, evidence);
const pre = {
  schema: 1, status: 'frozen_exact_post_fifth10_validated_registry_for_root_counter_image_integration',
  recorded_at: new Date().toISOString(), sense_id: constants.sense,
  author_receipt_raw_sha256: constants.authorSha, root_image_review_raw_sha256: args['--root-approval-sha256'],
  validation: {...validationRecord, measured_input_count: validation.measured_input_count},
  fifth10: {provenance_path: constants.fifth, provenance_raw_sha256: raw(inRoot(constants.fifth)),
    receipt_path: constants.fifthReceipt, receipt_raw_sha256: raw(inRoot(constants.fifthReceipt))},
  baseline_registry_sha256: hash(data), proposed_registry_sha256: hash(patch.next),
  counter_entry: patch.before, protected_counter_fields_sha256: hash(lib.protect(patch.before)),
  target: constants.target, target_raw_sha256: raw(inRoot(constants.target)),
  professional_json_raw_sha256: Object.fromEntries(professionalFiles().map(file => [file, raw(inRoot(file))])),
  validated_measured_inputs: validation.after_input_sha256,
  delivery_files: Object.fromEntries(constants.deliveryFiles.map(file => [file, raw(path.join(__dirname, file))])),
  preparation_receipt_raw_sha256: raw(preparationPath),
  proposed_patch: {before: patch.before, after: patch.after}, resource: patch.resource,
  scope: 'Only the exact counter image descriptor and one obsolete picture clause may change. Pending audio, reviewed morphology, language/domain status and every other registry field remain exact. Production loader and post-integration validation remain separate root work.'
};
verifyEvidence(same, pre.root_image_review_raw_sha256);
verifyValidation(same, pre.validation, data);
verifyFifth(same, data);
same(hash(loadProfessionalContent(root)), pre.baseline_registry_sha256);
same(professionalFiles(), Object.keys(pre.professional_json_raw_sha256));
for (const [file, sha] of Object.entries(pre.professional_json_raw_sha256)) same(raw(inRoot(file)), sha);
for (const [file, sha] of Object.entries(pre.delivery_files)) same(raw(path.join(__dirname, file)), sha);
same(raw(preparationPath), pre.preparation_receipt_raw_sha256);
writeNew(prePath, pre);
const receipt = {schema: 1, status: 'scratch_baseline_bound_no_production_writes', checks: checks.count(),
  preimages_raw_sha256: raw(prePath), baseline_registry_sha256: pre.baseline_registry_sha256,
  proposed_registry_sha256: pre.proposed_registry_sha256, validation_raw_sha256: pre.validation.raw_sha256,
  root_image_review_raw_sha256: pre.root_image_review_raw_sha256,
  serializer_raw_sha256: pre.delivery_files['integrate-reviewed.cjs'], production_content_written: false};
writeNew(receiptPath, receipt);
console.log(JSON.stringify(receipt));
