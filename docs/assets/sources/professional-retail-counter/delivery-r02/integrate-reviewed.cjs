'use strict';
// Root-owned transactional serializer. Default is read-only; recovery is always explicit.
const lib = require('./delivery-lib.cjs');
const plan = require('./transaction-plan.cjs');
const {fs, path, constants, read, raw, hash, serialized, inRoot, inBase, createChecks, parseArgs,
  professionalFiles, verifyEvidence, verifyValidation, verifyFifth, proposedPatch,
  loadProfessionalContent, auditProfessionalContent, root} = lib;
const args = parseArgs(['--preimages-sha256'], ['--integrate', '--recover']);
lib.assert.ok(!(args['--integrate'] && args['--recover']), 'Choose integration or interrupted recovery');
const checks = createChecks(), {same} = checks;
const prePath = path.join(__dirname, 'preimages.json'), bindingPath = path.join(__dirname, 'binding-receipt.json');
same(raw(prePath), args['--preimages-sha256'], 'Explicit root-selected frozen baseline');
const pre = read(prePath), binding = read(bindingPath), bindingRaw = raw(bindingPath);
same(pre.status, 'frozen_exact_post_fifth10_validated_registry_for_transactional_counter_image_integration');
same(pre.sense_id, constants.sense); same(pre.target, constants.target);
same(pre.author_receipt_raw_sha256, constants.authorSha);
same(pre.fifth10.provenance_path, constants.fifth); same(pre.fifth10.receipt_path, constants.fifthReceipt);
same(pre.transaction_path, constants.transaction);
same(pre.prior_preparation_receipt_raw_sha256, constants.priorPreparationSha);
same(binding.preimages_raw_sha256, raw(prePath));
same(binding.status, 'transactional_scratch_baseline_bound_no_production_writes');
same(binding.production_content_written, false);
same(binding.baseline_registry_sha256, pre.baseline_registry_sha256);
same(binding.proposed_registry_sha256, pre.proposed_registry_sha256);
same(binding.validation_raw_sha256, pre.validation.raw_sha256);
same(binding.root_image_review_raw_sha256, pre.root_image_review_raw_sha256);
same(binding.serializer_raw_sha256, raw(__filename));
same(Object.keys(pre.delivery_files).sort(), [...constants.deliveryFiles].sort());
function verifyImmutableInputs() {
  same(raw(prePath), args['--preimages-sha256']); same(raw(bindingPath), bindingRaw);
  same(raw(path.join(__dirname, 'preparation-receipt.json')), pre.preparation_receipt_raw_sha256);
  for (const [file, sha] of Object.entries(pre.delivery_files)) same(raw(path.join(__dirname, file)), sha, 'Delivery source changed: ' + file);
  same(pre.helper.source, constants.helperSource);
  same(raw(path.join(__dirname, 'guarded-transaction.cjs')), pre.helper.raw_sha256);
  same(raw(inRoot(pre.helper.validation.path)), pre.helper.validation.raw_sha256);
  same(raw(inRoot(pre.validation.path)), pre.validation.raw_sha256);
  same(raw(inRoot(constants.fifth)), pre.fifth10.provenance_raw_sha256);
  same(raw(inRoot(constants.fifthReceipt)), pre.fifth10.receipt_raw_sha256);
  const prior = lib.verifyPriorDelivery(same), evidence = verifyEvidence(same, pre.root_image_review_raw_sha256);
  same([...pre.allowed_output_paths].sort(), lib.allowedOutputPaths(evidence.receipt, prior).sort());
  same(Object.keys(pre.output_preimages).sort(), [...pre.allowed_output_paths].sort());
  return {evidence, prior};
}
const immutable = verifyImmutableInputs();
const {commitTransaction, recoverTransaction, describePlan} = require('./guarded-transaction.cjs');
function verifyBaseline() {
  verifyImmutableInputs();
  same(professionalFiles(), Object.keys(pre.professional_json_raw_sha256));
  for (const [file, sha] of Object.entries(pre.professional_json_raw_sha256)) same(raw(inRoot(file)), sha, 'Professional JSON changed: ' + file);
  same(raw(inRoot(constants.target)), pre.target_raw_sha256);
  const current = loadProfessionalContent(root);
  same(hash(current), pre.baseline_registry_sha256);
  const validation = verifyValidation(same, pre.validation, current);
  same(validation.after_input_sha256, pre.validated_measured_inputs);
  same(validation.measured_input_count, pre.validation.measured_input_count);
  verifyFifth(same, current);
  same(lib.observeOutputPreimages(same, immutable.evidence.receipt, immutable.prior), pre.output_preimages);
  return current;
}
// Reconstruct trusted outputs from the bound raw preimage before parsing any live registry.
const targetBefore = Buffer.from(pre.target_before_base64, 'base64');
same(plan.sha256(targetBefore), pre.target_raw_sha256);
const targetEnvelope = JSON.parse(targetBefore.toString('utf8'));
same(targetEnvelope.lexemes.filter(entry => entry.id === constants.sense).length, 1);
same(targetEnvelope.lexemes.find(entry => entry.id === constants.sense), pre.proposed_patch.before);
targetEnvelope.lexemes[targetEnvelope.lexemes.findIndex(entry => entry.id === constants.sense)] = structuredClone(pre.proposed_patch.after);
const evidence = immutable.evidence;
let data = null, patch = {before: pre.proposed_patch.before, after: pre.proposed_patch.after,
  envelope: targetEnvelope, resource: pre.resource, destination: 'professional-media/' + constants.imageSha + '.png'};
if (!args['--recover']) {
  same(fs.existsSync(inRoot(constants.transaction)), false, 'Transaction attempt already exists; inspect it and use explicit recovery for interruption');
  data = verifyBaseline();
  same(auditProfessionalContent({rootDir: root, data}).errors, []);
  const livePatch = proposedPatch(same, data, evidence);
  same(livePatch.envelope, targetEnvelope);
  patch = livePatch;
}
same(patch.before, pre.counter_entry);
same(hash(lib.protect(patch.before)), pre.protected_counter_fields_sha256);
same({before: patch.before, after: patch.after}, pre.proposed_patch);
if (patch.next) same(hash(patch.next), pre.proposed_registry_sha256);
same(patch.resource, pre.resource);
const retainedInputs = lib.staticRetainedInputs(evidence.receipt, immutable.prior).concat(lib.deferredRetainedInputs());
const retainedManifest = retainedInputs.map(input => ({path: input.source, bytes: fs.statSync(inBase(input.source)).size,
  sha256: raw(inBase(input.source)), destination: input.path, policy: input.policy}));
const expectedAudit = pre.proposed_audit;
if (!args['--recover']) {
  const proposedAudit = auditProfessionalContent({rootDir: root, data: patch.next});
  const expectedMissing = pre.output_preimages[patch.destination] === null
    ? [{code: 'media.missing', path: 'lexeme/' + constants.sense + '/image', message: 'Referenced asset does not exist'}] : [];
  same(proposedAudit.errors, expectedMissing, 'Only the exact not-yet-installed PNG may be missing during preparation');
  same({errors: 0, warnings: proposedAudit.warnings.length, summary: proposedAudit.summary}, expectedAudit);
}
const summary = {schema: 1, dry_run: !args['--integrate'], integrated: false, integration_ready: true,
  before_registry_sha256: pre.baseline_registry_sha256, proposed_registry_sha256: pre.proposed_registry_sha256, resource: patch.resource,
  image_sha256: constants.imageSha, author_receipt_raw_sha256: constants.authorSha,
  root_image_review_raw_sha256: pre.root_image_review_raw_sha256, preimages_raw_sha256: raw(prePath),
  binding_receipt_raw_sha256: bindingRaw, serializer_raw_sha256: raw(__filename),
  delivery_library_raw_sha256: raw(path.join(__dirname, 'delivery-lib.cjs')), helper: pre.helper,
  transaction_path: constants.transaction, validation: pre.validation, fifth10: pre.fifth10,
  retained_file_count: retainedManifest.length,
  only_registry_edits: [constants.sense + ' media.image', constants.sense + ' one obsolete pending-picture clause'],
  scope: 'Scoped physical-sense image integration. Actual production-loader delivery and post-integration validation remain pending.'};
const provenance = {schema: 1, status: 'reviewed_image_integrated_pending_production_delivery_validation',
  independent_approval: evidence.approval,
  source_records: ['source-record.json', 'parcel-source-record.json'].map(file => constants.retained + '/' + file),
  retained_evidence: constants.retained, retained_files: retainedManifest, resource: patch.resource,
  patches: [{id: constants.sense, origin: 'res://' + constants.target, before: patch.before, after: patch.after,
    before_sha256: hash(patch.before), protected_fields_sha256: hash(lib.protect(patch.before))}],
  before_registry_sha256: pre.baseline_registry_sha256, after_registry_sha256: pre.proposed_registry_sha256,
  integration_guards: {serializer_raw_sha256: summary.serializer_raw_sha256,
    delivery_library_raw_sha256: summary.delivery_library_raw_sha256, preimages_raw_sha256: summary.preimages_raw_sha256,
    binding_receipt_raw_sha256: bindingRaw, baseline_registry_sha256: pre.baseline_registry_sha256,
    validation: pre.validation, fifth10: pre.fifth10, transaction_path: constants.transaction, helper: pre.helper},
  audit: expectedAudit};
const provenanceBytes = Buffer.from(serialized(provenance));
const integration = {...summary, dry_run: false, integrated: true,
  provenance: constants.provenance, provenance_raw_sha256: plan.sha256(provenanceBytes),
  target: constants.target, target_after_raw_sha256: plan.sha256(Buffer.from(serialized(patch.envelope))),
  after_registry_sha256: pre.proposed_registry_sha256, audit: expectedAudit,
  commit_status_authority: constants.transaction,
  receipt_boundary: 'This receipt is installed with all planned outputs. The transaction journal must be committed; prepared or interrupted journal state requires explicit recovery.'};
const artifacts = retainedInputs.map(input => ({path: input.path, after: fs.readFileSync(inBase(input.source)), policy: input.policy})).concat(
  {path: patch.destination, after: fs.readFileSync(inBase(evidence.receipt.selected_candidate.file.path)), policy: 'immutable'},
  {path: constants.target, after: Buffer.from(serialized(patch.envelope)), policy: 'replace'},
  {path: constants.provenance, after: provenanceBytes, policy: 'create'},
  {path: lib.relative(path.join(__dirname, 'integration-receipt.json')), after: Buffer.from(serialized(integration)), policy: 'create'});
same(artifacts.map(file => file.path).sort(), [...pre.allowed_output_paths].sort());
const changes = plan.trustedChanges({repositoryRoot: root, artifacts, expectedPreimages: pre.output_preimages,
  replacementPreimages: {[constants.target]: targetBefore}});
const helperAllowedPaths = pre.allowed_output_paths.map(inRoot);
const helperChanges = changes.map(change => ({...change, path: inRoot(change.path)}));
const described = describePlan({repositoryRoot: root, transactionDir: inRoot(constants.transaction), allowedPaths: helperAllowedPaths, changes: helperChanges});
const changeSummary = changes.map(change => ({path: change.path, before_sha256: change.before === null ? null : plan.sha256(change.before),
  after_sha256: plan.sha256(change.after), preserved_identical: change.before !== null && change.before.equals(change.after)}));
if (args['--recover']) {
  const result = recoverTransaction({repositoryRoot: root, transactionDir: inRoot(constants.transaction), allowedPaths: helperAllowedPaths,
    expectedPlanSha256: described.planSha256});
  if (result.status === 'committed') {
    same(result.targetFilesMutated, false);
    console.log(JSON.stringify({recovered: false, committed: true, transaction: result, checks: checks.count(),
      scope: 'Committed transaction retained. No interrupted rollback was performed.'}));
    process.exit(0);
  }
  same(['rolled-back', 'not-prepared'].includes(result.status), true, 'Recovery must restore the baseline or confirm preparation never mutated targets');
  if (result.status === 'not-prepared') same(result.targetFilesMutated, false);
  const restored = verifyBaseline();
  same(auditProfessionalContent({rootDir: root, data: restored}).errors, []);
  console.log(JSON.stringify({recovered: result.status === 'rolled-back', baseline_confirmed: true, transaction: result, restored_registry_sha256: hash(restored), checks: checks.count(),
    scope: 'Explicit interrupted transaction recovery only; no integration or native rendering was attempted.'}));
  process.exit(0);
}
same(plan.makeChanges({repositoryRoot: root, artifacts, expectedPreimages: pre.output_preimages}), changes);
verifyBaseline(); plan.verifyChanges(root, changes, 'before');
if (!args['--integrate']) {
  console.log(JSON.stringify({...summary, checks: checks.count(), transaction_plan_sha256: described.planSha256, transaction_changes: changeSummary}));
  process.exit(0);
}
const transaction = commitTransaction({repositoryRoot: root, transactionDir: inRoot(constants.transaction), allowedPaths: helperAllowedPaths,
  changes: helperChanges, verify() {
    plan.verifyChanges(root, changes, 'after');
    same(loadProfessionalContent(root), patch.next);
    const actualAudit = auditProfessionalContent({rootDir: root, data: patch.next});
    same(actualAudit.errors, []);
    same({errors: 0, warnings: actualAudit.warnings.length, summary: actualAudit.summary}, expectedAudit);
    same(professionalFiles(), [...Object.keys(pre.professional_json_raw_sha256), constants.provenance].sort());
    for (const [file, sha] of Object.entries(pre.validated_measured_inputs)) {
      same(raw(inRoot(file)), file === constants.target ? integration.target_after_raw_sha256 : sha, 'Protected measured input after delivery: ' + file);
    }
    verifyImmutableInputs();
  }});
console.log(JSON.stringify({...integration, checks: checks.count(), transaction_plan_sha256: described.planSha256, transaction, transaction_changes: changeSummary}));
