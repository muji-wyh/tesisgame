'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const base = __dirname;
const root = path.resolve(base, '../../..');
const folder = path.join(base, 'shopping-basket');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const jsonHash = value => sha(Buffer.from(JSON.stringify(value), 'utf8'));
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const fileRecord = file => ({path: path.relative(root, file).replaceAll('\\', '/'), sha256: sha(fs.readFileSync(file)), bytes: fs.statSync(file).size});
const source = read(path.join(folder, 'source-record.json'));
for (const file of source.files) if (sha(fs.readFileSync(path.join(root, file.path))) !== file.sha256) throw new Error('Original source changed: ' + file.path);
const report = read(path.join(folder, 'candidate/report.json'));
if (report.failed !== 0 || report.checks.length !== 32 || !report.checks.every(c => c.passed)) throw new Error('Candidate native QA did not pass');
const pngFile = path.join(folder, 'candidate/shopping-basket.png');
const png = fs.readFileSync(pngFile);
const digest = 'fbbdcb9b9eb07999d6891eb900d07ab84de5b9946913c55b6cde36d92b7c9eb3';
if (sha(png) !== digest || png.readUInt32BE(16) !== 512 || png.readUInt32BE(20) !== 454) throw new Error('Inspected candidate changed');
const entryFile = path.join(root, 'data/professional/lexemes/retail-pilot.json');
const entry = read(entryFile).lexemes.find(e => e.id === source.sense_id);
if (!entry || entry.media.image.brief !== source.current_brief || entry.media.image.status !== 'pending') throw new Error('Unexpected basket image preimage');
const beforeSentence = 'Picture suitability and word-media production remain pending.';
const afterSentence = 'The shopping-basket image has completed scoped physical-sense picture review and integration; word audio remains pending. The empty-basket composition keeps the raised carrying handle and opening readable.';
if (entry.editorial_notes.split(beforeSentence).length !== 2) throw new Error('Unexpected basket note preimage');
const brief = 'Show an empty compact rigid retail shopping basket in a three-quarter view, with its raised hand-carry handle and open basket clearly visible at the actual minimum card size. Keep the handheld basket distinct from a wheeled shopping cart. Exclude wheels, fabric sides, a lid, and groceries that obscure the handle or opening. Use the inspected original Mini Market shopping-basket mesh without geometry or material changes.';
const proposal = {
  status: 'single_candidate_and_exact_empty_brief_revision_pending_independent_root_visual_review',
  sense_id: source.sense_id,
  definition: entry.definition,
  accepted_forms: entry.accepted_forms,
  source: {url: source.source, creator: source.creator, license: source.license, acquisition_status: source.acquisition_status, original_files: source.files, available_animations: []},
  candidate: fileRecord(pngFile),
  prospective_resource: {id: 'sha256:' + digest, sha256: digest, kind: 'image', format: 'png', path: 'professional-media/' + digest + '.png', width: 512, height: 454, compressed_bytes: png.length, decoded_bytes: 512 * 454 * 8},
  exact_brief_revision: {before: entry.media.image.brief, after: brief, reason: 'Root accepted the narrow empty-basket adjustment after source inspection: the raised hand-carry handle, opening and absence of wheels should stay readable at minimum card size. Added groceries would obscure these cues. The original brief is preserved here and in the source record.'},
  exact_future_note_delta: {before: entry.editorial_notes, after: entry.editorial_notes.replace(beforeSentence, afterSentence), replacement_before: beforeSentence, replacement_after: afterSentence, condition: 'Apply only after independent candidate/descriptor acceptance and exact image integration.'},
  preimages: {method: 'SHA-256 of UTF-8 JSON.stringify(value), no trailing newline, native property order', file_sha256: sha(fs.readFileSync(entryFile)), entry_sha256: jsonHash(entry), media_image_sha256: jsonHash(entry.media.image), editorial_notes_sha256: jsonHash(entry.editorial_notes)},
  visual_inspection: {reviewer: 'Codex finish_difficulty agent; independent root candidate review pending', source_views: 4, selected_source_view: 'source-inspection/rear-three-quarter.png', camera: report.camera, findings: ['The original mesh is a rigid green basket with a raised light-colored handle, an open top and no wheels, fabric sides or lid.', 'The chosen rear three-quarter view shades the broad handle face, preserving contrast against the actual light card surface without changing materials.', 'At minimum Match and Memory sizes, the handle and open basket remain visible in both unmatched and matched states.', 'The adjacent accepted cart has a taller body, a rear push handle and visible wheels; the basket has an arching carrying handle and no wheels. The comparison does not depend solely on color.'], limitations: ['The source is stylized and has no independent human scale cue.', 'The eight-card comparison is an agent visual inspection, not a participant recognition test.', 'Native candidate textures were assigned directly to actual WordCard controls for isolated artwork QA; this does not establish production delivery.']},
  native_qa: {process_exit_code: 0, checks: 32, failures: 0, report: fileRecord(path.join(folder, 'candidate/report.json')), four_state_contact: fileRecord(path.join(folder, 'candidate/actual-word-card-contact.png')), confusability_contact: fileRecord(path.join(folder, 'candidate/cart-basket-confusability-contact.png')), actual_dimensions: 'Match 126 x 72 with 102 x 52 picture area; Memory 144 x 74 with 120 x 54 picture area; actual matched badge and 0.68 picture alpha retained.'},
  protected_scope: 'No production change has been made for this basket. A future accepted delta is limited to media.image and the exact note replacement. All other entry fields, all other entries, audio, morphology, language status, course/module status and theme metadata are outside this proposal.',
  adaptations: ['Original acquired source geometry/materials/external colormap, unchanged.', 'One three-quarter static camera with neutral ambient and warm directional lighting; no added grocery or procedural model geometry.', '768 x 768 transparent source render, alpha-bounds crop with 16-pixel margin and Lanczos reduction to 512 x 454.']
};
fs.writeFileSync(path.join(folder, 'review-proposal.json'), JSON.stringify(proposal, null, 2) + '\n');
const evidence = [];
function walk(directory) { for (const item of fs.readdirSync(directory, {withFileTypes: true}).sort((a,b) => a.name.localeCompare(b.name))) { const file = path.join(directory, item.name); if (item.isDirectory()) walk(file); else if (!item.name.endsWith('.import') && !item.name.endsWith('.uid') && item.name !== 'review-receipt.json') evidence.push(fileRecord(file)); } }
walk(folder);
for (const script of ['prepare-shopping-basket-inspection.cjs', 'inspect-shopping-basket.gd', 'render-shopping-basket-candidate.gd', 'prepare-shopping-basket-review.cjs']) evidence.push(fileRecord(path.join(base, script)));
const receipt = {date: '2026-10-16', status: 'one_basket_candidate_pending_independent_root_review', candidate_sha256: digest, source_files: source.files, original_brief_preserved: true, production_changes: false, checks: 32, failures: 0, evidence};
const receiptFile = path.join(folder, 'review-receipt.json');
fs.writeFileSync(receiptFile, JSON.stringify(receipt, null, 2) + '\n');
console.log(JSON.stringify({candidate_sha256: digest, candidate_bytes: png.length, proposal_sha256: sha(fs.readFileSync(path.join(folder, 'review-proposal.json'))), receipt_sha256: sha(fs.readFileSync(receiptFile)), evidence_files: evidence.length, image_preimage_sha256: proposal.preimages.media_image_sha256}, null, 2));
