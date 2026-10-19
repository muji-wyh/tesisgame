'use strict';

// Creates proposal artifacts only. This script never writes production files,
// invokes a test runner, spawns a process, or dispatches an engine/browser.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const sourceDir = 'docs/assets/sources/shopping-bag-additional-leads-2026-10-17';
const acceptedDir = 'docs/assets/sources/shopping-bag-candidate-review-2026-10-17';
const imageHash = 'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb';
const rawHash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const jsonHash = value => rawHash(JSON.stringify(value));
const readRaw = file => fs.readFileSync(path.join(root, file));
const read = file => JSON.parse(readRaw(file));
const write = (file, value) => fs.writeFileSync(path.join(__dirname, file), JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const pin = file => { const bytes = readRaw(file); return { path: file, bytes: bytes.length, sha256: rawHash(bytes) }; };

const visualFile = acceptedDir + '/visual-review.json';
const visual = read(visualFile);
assert.equal(rawHash(readRaw(visualFile)), 'fa9e40fa7475be0bdd5831ba1907577707fb3557f9f177e7b3f0453df569a97b');
assert.equal(visual.status, 'candidate_and_brief_accepted_for_scoped_production_proposal');
assert.equal(visual.brief_revision_accepted, true);
assert.equal(visual.image_visually_accepted, true);
assert.equal(visual.production_integrated, false);
assert.equal(visual.candidate_sha256, imageHash);
const beforeFile = acceptedDir + '/candidate/prepared/bag-entry-preimage.json';
const before = read(beforeFile);
assert.equal(jsonHash(before), 'ba96e5d4ba9911b68ddb630d3413cac52d155a3d27c7452aaee97ba5284f7e07');
assert.equal(before.media.image.brief, visual.original_brief);
const retail = read('data/professional/lexemes/retail-pilot.json');
const liveBag = retail.lexemes.find(entry => entry.id === before.id);
assert.deepEqual(liveBag, before, 'Current bag still matches the immutable accepted candidate preimage; this is not a registry baseline.');
const source = read(sourceDir + '/source-record.json');
assert.equal(source.source.creator, 'Vijay Verma (@realvjy)');
assert.equal(source.source.license, 'CC0 1.0 Universal');
assert.equal(source.review.accepted, false, 'Historical acquisition state remains pre-acceptance.');
const manifest = read(acceptedDir + '/candidate/prepared/manifest.json');
const resource = manifest.resources.find(item => item.sha256 === imageHash);
assert.deepEqual(resource, {
  id: 'sha256:' + imageHash, sha256: imageHash,
  path: 'professional-media/' + imageHash + '.png',
  kind: 'image', format: 'png', compressed_bytes: 135843,
  decoded_bytes: 1695744, width: 414, height: 512
});
const sourceImage = acceptedDir + '/candidate/prepared/fixture/' + resource.path;
const imageBytes = readRaw(sourceImage);
assert.equal(rawHash(imageBytes), imageHash);
assert.equal(imageBytes.length, resource.compressed_bytes);
assert.equal(imageBytes.readUInt32BE(16), resource.width);
assert.equal(imageBytes.readUInt32BE(20), resource.height);
assert.equal(resource.decoded_bytes, resource.width * resource.height * 8);

const descriptor = {
  status: 'integrated',
  path: 'res://' + resource.path,
  sha256: imageHash,
  source: 'res://' + sourceDir + '/source-record.json',
  creator: 'Vijay Verma (@realvjy)',
  license: 'CC0 1.0',
  acquisition_status: 'integrated',
  review: {
    status: 'reviewed',
    reviewer: 'Codex root independent AI scoped carrier picture and brief review; see docs/assets/sources/shopping-bag-candidate-review-2026-10-17/visual-review.json',
    reviewed_at: '2026-10-17'
  },
  brief: visual.accepted_brief,
  picture_suitable: true,
  available_animations: [],
  adaptations: [
    'Original acquired 3dicons v1 Bag dynamic-angle color PNG; no redraw, recolor, added contents or changed material.',
    'Alpha-bounds crop with a 16-source-pixel margin, followed by a Lanczos resize to a maximum of 512 pixels.',
    'Exact accepted 414 by 512 transparent PNG retained without further conversion; no source model or animation was acquired.'
  ]
};
const noteReplacements = [
  {
    before: 'Retain the broad purchased-goods carrier, including the current reusable bag example in the art brief.',
    after: 'Retain the broad purchased-goods carrier, including reusable bags; the accepted illustration does not specify material or require visible contents.'
  },
  {
    before: 'Carrier bag is not added globally because the consulted British alternative corresponds specifically to the paper/plastic sense, narrower than this reusable-bag depiction.',
    after: 'Carrier bag is not added globally because the consulted British alternative corresponds specifically to the paper/plastic sense, narrower than the selected broad purchased-goods-carrier sense.'
  },
  {
    before: 'Picture suitability and word-image production remain pending.',
    after: 'The shopping-bag image has completed scoped carrier picture review. The accepted plain open bag brief replaces the original fabric, flexible-side and visible-purchases requirements, which are not depicted. Empty gift bags may share this form; intended shopping use is supplied by context. The original brief and its mismatch remain in retained provenance.'
  }
];
const after = structuredClone(before);
after.media.image = descriptor;
for (const replacement of noteReplacements) {
  assert.equal(after.editorial_notes.split(replacement.before).length - 1, 1);
  after.editorial_notes = after.editorial_notes.replace(replacement.before, replacement.after);
}
const protectedProjection = entry => {
  const value = structuredClone(entry);
  delete value.media.image;
  delete value.editorial_notes;
  return value;
};
assert.deepEqual(protectedProjection(after), protectedProjection(before));
assert.deepEqual(after.practice_modes, ['match', 'memory', 'pop', 'jelly', 'word_jelly']);
assert.deepEqual(after.accepted_forms, ['shopping bag']);
assert.equal(after.media.audio.sha256, '6c7d2ac0e733214faf920a4a0781d0458b6b891a92aa07b7ab433b501d19de72');
const patch = {
  id: before.id,
  before, after,
  before_sha256: jsonHash(before),
  after_sha256: jsonHash(after),
  protected_fields_sha256: jsonHash(protectedProjection(before)),
  note_change: { kind: 'three_exact_single_occurrence_replacements', replacements: noteReplacements },
  resource
};

const evidencePaths = [
  sourceDir + '/README.md',
  sourceDir + '/source-record.json',
  sourceDir + '/source-evidence/icon-page.html',
  sourceDir + '/source-evidence/library-v1-license-page.html',
  sourceDir + '/source-evidence/CC0-1.0-legalcode.txt',
  sourceDir + '/source-evidence/retrievals.json',
  sourceDir + '/acquired/3dicons-bag-dynamic-color.png',
  sourceDir + '/size-study/bag-crop-512-study.png',
  acceptedDir + '/README.md',
  visualFile,
  acceptedDir + '/source-review.json',
  acceptedDir + '/prepared-inspection.json',
  acceptedDir + '/copy-receipt.json',
  acceptedDir + '/candidate/brief-revision-proposal.json',
  acceptedDir + '/candidate/candidate-receipt.json',
  acceptedDir + '/candidate/output/report.json',
  acceptedDir + '/candidate/output/actual-wordcard-comparison.png',
  beforeFile,
  acceptedDir + '/candidate/prepared/basket-entry-preimage.json',
  acceptedDir + '/candidate/prepared/manifest.json',
  sourceImage
];
const evidence = {
  schema: 1,
  status: 'immutable_accepted_candidate_evidence_pinned_for_proposal',
  hash_kind: 'sha256_exact_file_bytes',
  files: evidencePaths.map(pin),
  historical_state_rule: 'Source/acquisition and preparation false or pending gates stay unchanged. Later visual-review.json records scoped image/brief acceptance; neither this proposal nor those historical records establish production integration.',
  shared_baseline_deferred: ['loaded registry', 'sources.json', 'shared test files', 'fourth10 actual committed receipt', 'fourth10 successful persisted-validation receipt']
};
const protectedMedia = [];
for (const entry of retail.lexemes) {
  for (const kind of ['image', 'audio']) {
    const media = entry.media?.[kind];
    if (media?.status !== 'integrated') continue;
    const file = media.path.replace(/^res:\/\//, '');
    assert.equal(rawHash(readRaw(file)), media.sha256);
    protectedMedia.push({ sense_id: entry.id, kind, descriptor: media, descriptor_json_sha256: jsonHash(media), file: pin(file) });
  }
}
assert.equal(protectedMedia.filter(item => item.kind === 'image').length, 8);
assert.equal(protectedMedia.filter(item => item.kind === 'audio').length, 12);

write('image-descriptor.proposed.json', descriptor);
write('resource.json', resource);
write('entry-preimage.json', before);
write('entry-afterimage.proposed.json', after);
write('patch.proposed.json', patch);
write('evidence-lock.json', evidence);
write('protected-media-observation.json', {
  schema: 1,
  status: 'read_only_existing_media_observation_not_final_registry_or_transaction_baseline',
  source: 'data/professional/lexemes/retail-pilot.json',
  media: protectedMedia,
  final_rebase_requirement: 'Recheck all exact descriptors and file hashes from the actual post-fourth10 production state. Existing audio and eight images are protected, not reapproved or replaced.'
});
fs.mkdirSync(path.join(__dirname, 'media'));
fs.writeFileSync(path.join(__dirname, 'media', imageHash + '.png'), imageBytes, { flag: 'wx' });

write('production-provenance-template.json', {
  schema: 1,
  status: 'proposal_only_pending_independent_integration_review_and_post_fourth10_rebase',
  proposed_path: 'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json',
  integrated_on: null,
  integration_approval: null,
  candidate_visual_acceptance: { path: visualFile, sha256: pin(visualFile).sha256, status: visual.status, review_scope: 'Exact source-derived candidate and revised brief; not production integration.' },
  source_records: [sourceDir + '/source-record.json'],
  retained_evidence: [sourceDir, acceptedDir],
  retained_files: evidence.files,
  original_brief: visual.original_brief,
  accepted_brief: visual.accepted_brief,
  resource,
  patches: [patch],
  before_registry_sha256: null,
  after_registry_sha256: null,
  lineage: {
    fourth10_committed_receipt: null,
    fourth10_persisted_validation_receipt: null,
    actual_post_fourth10_baseline: null,
    reviewed_test_delta: null,
    guarded_commit_receipt: null,
    fresh_persisted_verification: null
  },
  source_registry_change: false,
  module_or_manifest_change: false,
  scope: 'Only shopping-bag.goods-carrier.n media.image and the three exact obsolete editorial-note clauses change. The exact accepted PNG is added. All lexical, audio, morphology, review, reference, expression, module, Growth and runtime fields remain exact.',
  limitations: visual.limitations,
  audit: {
    source_acquired: true,
    derivative_visually_accepted: true,
    brief_revision_accepted: true,
    integration_proposal_accepted: false,
    production_integrated: false,
    fresh_production_delivery_verified: false,
    new_listening_approval: false,
    ready_module_or_course: false
  },
  finalization_rule: 'Do not install this template verbatim. Fill the actual independently reviewed rebase/baseline and commit lineage at their real stages; retain candidate acceptance separately. Never set successful integration or delivery flags before the corresponding evidence exists.'
});

write('generation-observation.json', {
  schema: 1,
  status: 'proposal_artifacts_authored_only',
  sense_id: before.id,
  accepted_preimage_matches_observed_live_bag: true,
  proposed_before_entry_json_sha256: patch.before_sha256,
  proposed_after_entry_json_sha256: patch.after_sha256,
  protected_fields_json_sha256: patch.protected_fields_sha256,
  image_descriptor_json_sha256: jsonHash(descriptor),
  exact_note_replacements: noteReplacements.length,
  copied_png_sha256: imageHash,
  production_writes: [],
  test_dispatches: [],
  engine_or_browser_dispatches: [],
  actual_post_fourth10_registry_baseline_bound: false,
  completed_production_integration: false
});
process.stdout.write(JSON.stringify({ status: 'proposal_artifacts_authored_only', after_entry_json_sha256: patch.after_sha256, protected_fields_json_sha256: patch.protected_fields_sha256, evidence_files: evidence.files.length, existing_images: 8, existing_audio: 12 }) + '\n');
