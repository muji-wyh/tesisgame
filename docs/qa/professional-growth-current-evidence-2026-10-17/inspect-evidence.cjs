'use strict';
// Read-only evidence reconciliation. No project imports, validators, tests, or compilers.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const output = __dirname;
const q = 'build/professional-english/morphology-null-review/';
const browserDir = 'build/tests/jelly-r2/core-desktop-source/';
const pins = new Map();
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const jsonHash = value => hash(JSON.stringify(value));
function read(relative) {
  const bytes = fs.readFileSync(path.join(root, relative));
  const pin = {path: relative, bytes: bytes.length, sha256: hash(bytes)};
  const previous = pins.get(relative);
  if (previous && JSON.stringify(previous) !== JSON.stringify(pin)) throw Error('Input changed: ' + relative);
  pins.set(relative, pin);
  return bytes;
}
const json = relative => JSON.parse(read(relative).toString('utf8'));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const requireTrue = (value, message) => {if (!value) throw Error(message);};
const overlay = prefix => ({words: json(prefix + 'words.json'), index: json(prefix + 'data/vocabulary/morphology/index.json'), cohorts: Array.from({length: 10}, (_, i) => json(prefix + 'data/vocabulary/morphology/age-' + String(i + 3).padStart(2, '0') + '.json'))});
const current = overlay('');
const candidate = overlay(q + 'hold9-growth-candidate/');
const runtime = json(q + 'hold9-final-runtime-validation.json');
const proposal = json(q + 'hold9-proposal.json');
const independent = json(q + 'independent-hold9.json');
const history = json('docs/vocabulary/review-history/2026-10-16-nine-bound-family-resolutions.json');
const corrections = json('docs/vocabulary/review-history/2026-10-16-bound-family-corrections.json');
const initial = json('build/professional-english/growth-morphology-release-audit.json');
requireTrue(jsonHash(current) === runtime.current_overlay_json_sha256 && same(current, candidate), 'Current complete overlay differs from accepted final evidence.');
requireTrue(jsonHash(proposal) === runtime.accepted_proposal_json_sha256 && independent.proposal_json_sha256 === jsonHash(proposal) && independent.accepted === true, 'Independent acceptance does not match proposal.');
requireTrue(jsonHash(history) === runtime.history.json_sha256 && hash(read(runtime.history.path)) === runtime.history.raw_sha256, 'Durable resolution history differs.');
const entries = current.cohorts.flatMap(cohort => cohort.entries);
const entryById = new Map(entries.map(entry => [entry.id, entry]));
const counts = {total: entries.length, reviewed: 0, pending: 0, atomic: 0, compound: 0, morphological: 0, phrase: 0, context_only: current.words.filter(word => !word.image).length, named_sources: Object.keys(current.index.sources).length};
for (const entry of entries) {counts[entry.review.status]++; counts[entry.analysis.kind]++;}
requireTrue(counts.reviewed === 1550 && counts.pending === 0 && counts.atomic === 1206 && counts.compound === 114 && counts.morphological === 230 && counts.context_only === 265, 'Unexpected current raw counts.');
const identity = word => ({id: word.id, text: word.text, min_age: word.min_age, part_of_speech: word.part_of_speech || '', meaning: word.meaning || ''});
const fingerprint = jsonHash(current.words.map(identity).sort((a, b) => a.id.localeCompare(b.id, 'en')));
requireTrue(fingerprint === current.index.inventory_sha256, 'Current original-word identity fingerprint changed.');
const nine = history.changes.map(change => ({id: change.id, accepted_after_sha256: change.after_sha256, current_sha256: jsonHash(entryById.get(change.id)), exact: same(entryById.get(change.id), change.proposed_entry)}));
requireTrue(nine.every(row => row.exact && row.current_sha256 === row.accepted_after_sha256), 'A resolved entry differs.');
const six = corrections.changes.filter(change => change.after_entry.review.status === 'reviewed').map(change => ({id: change.entry_id, accepted_after_sha256: change.after_entry_sha256, current_sha256: jsonHash(entryById.get(change.entry_id)), exact: same(entryById.get(change.entry_id), change.after_entry)}));
requireTrue(six.length === 6 && six.every(row => row.exact && row.current_sha256 === row.accepted_after_sha256), 'An earlier accepted correction differs.');
const sourceRegistration = Object.entries(history.newly_consulted_sources).map(([id, source]) => ({id, exact: same(source, current.index.sources[id])}));
requireTrue(sourceRegistration.length === 22 && sourceRegistration.every(row => row.exact), 'Final source registrations differ.');
const sourcePaths = ['tools/author-growth-morphology.cjs', 'tools/validate-growth-morphology.cjs', ...Array.from({length: 7}, (_, i) => 'tools/growth-morphology/age-' + String(i + 6).padStart(2, '0') + '.cjs')];
const authoring = sourcePaths.map(relative => ({path: relative, current_sha256: hash(read(relative)), candidate_sha256: hash(read(q + 'hold9-growth-candidate/' + relative))}));
requireTrue(authoring.every(row => row.current_sha256 === row.candidate_sha256), 'Authoring or validator differs from candidate.');
for (const row of proposal.growth.authoring_edits) requireTrue(hash(read(row.path)) === row.after_raw_sha256, 'Accepted author source differs: ' + row.path);
const testPins = Object.entries(runtime.test_raw_sha256).map(([relative, expected]) => ({path: relative, expected_sha256: expected, current_sha256: hash(read(relative))}));
requireTrue(testPins.every(row => row.expected_sha256 === row.current_sha256), 'A final test source differs.');
const logs = [runtime.node, ...runtime.native.suites].map(item => ({path: item.log, expected_sha256: item.raw_sha256, current_sha256: hash(read(item.log)), tail: read(item.log).toString('utf8').trim().split(/\r?\n/).slice(-8)}));
requireTrue(logs.every(row => row.expected_sha256 === row.current_sha256), 'A final log differs.');
const before = json(browserDir + 'before.json'), after = json(browserDir + 'after.json');
const browserReport = json('build/tests/jelly-r2/core-desktop-report.json');
const browserSources = before.sources.map(row => ({path: row.path, historical_sha256: row.sha256, historical_snapshot_sha256: hash(read(browserDir + row.path)), current_sha256: hash(read(row.path)), before_after_exact: same(row, after.sources.find(other => other.path === row.path))}));
requireTrue(browserSources.length === 17 && browserSources.every(row => row.before_after_exact && row.historical_sha256 === row.historical_snapshot_sha256), 'Historical browser capture differs.');
const documentaryPaths = ['docs/qa/2026-10-16-growth-morphology.md', 'docs/vocabulary/growth-morphology.md', 'docs/plans/2026-10-15-professional-english-and-morphology.md', 'docs/plans/history/2026-10-16-tesis-iter-4-checkpoint.md', q + 'integrate-hold9-growth.cjs', q + 'hold9-checks-validation.json', q + 'hold9-growth-persisted-validation.json', q + 'hold9-final-author-replay.log', q + 'growth-final-node-validation.json', q + 'growth-final-runtime-validation.json', q + 'growth-final-native-regression.json'];
documentaryPaths.forEach(read);
const currentRuntimePaths = ['scripts/growth_morphology.gd', 'scripts/morphology_analysis.gd', 'scripts/morphology_resolver.gd', 'scripts/learning_content_resolver.gd', 'scripts/learning_context.gd', 'scripts/word_jelly_model.gd', 'scripts/word_jelly.gd', 'scripts/jelly_footprint.gd', 'scripts/game_data.gd', 'scripts/ui_style.gd', 'scripts/professional_catalog.gd', 'scripts/game_model.gd'];
currentRuntimePaths.forEach(read);
const checkpointWording = 'Growth morphology content audit is complete for all 1,550 unchanged Growth identities: 1,206 atomic, 114 compound and 230 morphological analyses, zero pending, 265 preserved context-only image gaps and 209 named sources. The current overlay exactly matches the accepted nine-family resolution fingerprint 0fd492358e6a812c6923ca75ec8993272fbe0917fc4af13c9edde5b6792cb6f7. Preserved final evidence records a strict complete-migration audit with zero errors, Node 23/23 and six native suites with 21,324 checks/assertions and zero failures; this evidence and all nine pinned test sources still match. The review is AI editorial work, not human linguistic approval. Later-build runtime, complete game and device acceptance remain separately required; the historical five-case Chromium r2 run is not acceptance for the current build.';
const review = {
  schema: 1, created_at: new Date().toISOString(), status: 'current_growth_content_audit_completion_confirmed', reviewer: 'Codex subagent commit_review (AI evidence reconciliation; not human approval)',
  scope: 'Read-only current raw JSON, source and SHA-256 reconciliation against preserved evidence. No project imports, validation execution, tests, compiler, renderer, browser or source edits.',
  counts, inventory_sha256: fingerprint, current_overlay_json_sha256: jsonHash(current), overlay_hash_algorithm: 'SHA-256 of JSON.stringify({words, index, cohorts}), preserving JSON key order and age 03 through 12 cohort order as tools/validate-growth-morphology.cjs lines 8-12.',
  accepted_proposal_json_sha256: jsonHash(proposal), accepted_independent_review: independent, current_six_corrections: six, current_nine_resolutions: nine, final_source_registration: sourceRegistration, authoring_and_validator: authoring,
  preserved_final_runtime: {receipt_path: q + 'hold9-final-runtime-validation.json', receipt_raw_sha256: hash(read(q + 'hold9-final-runtime-validation.json')), strict_complete_migration_audit: runtime.strict_complete_migration_audit, node: runtime.node, native: runtime.native, author_replay: runtime.author_replay, test_pins: testPins, log_pins: logs},
  history: {initial_completion_summary: initial.summary, initial_document_scope: 'The old completion table (1,220 atomic / 114 compound / 216 morphological; 159 sources; seven Node tests / 20,503 native assertions) is an earlier milestone. Its figures must not replace the later exact nine-resolution evidence.', pending_nine_scope: 'The earlier six-correction stage correctly had 1,541 reviewed / nine pending. Its strict release failure and initial stale-host Node failure remain historical and immutable.', final_resolution_scope: 'Eight inherited-family graphs and one explicitly reviewed explore whole stem resolved all nine; the six earlier corrections remain exact.'},
  browser: {receipt_created_at: before.buildCreatedAt, statistics: browserReport.stats, sources: browserSources, current_different_paths: browserSources.filter(row => row.current_sha256 !== row.historical_sha256).map(row => row.path), scope: 'Five selected desktop Chromium cases on immutable r2 only. All 17 historical source pins remain exact, but five current cohorts (ages 07 through 11) differ. No current export, iPhone WebKit, complete game or physical-device acceptance transfers.'},
  limitations: ['The preserved final receipt pins data, test source files and log files; it does not pin a complete transitive runtime-source closure. Current runtime files are recorded as observations only. No claim that all historical runtime test outcomes have been replayed against later production changes.', 'Current Growth content completion does not complete Professional morphology, language, specialist, images, audio, themes or modules.', 'The agreed live acceptance still includes atomic and 2/3/4+ part behavior, spelling changes, manual/hint/highlight/Auto agreement, readable wide pieces and full-span admission, independent/shared progress rules, rewards, durable storage and bounded loading, accessibility, and required layouts at 320x568, 390x844, 844x390, 1280x800 and undersized pause. Existing scoped acceptance can be retained; this reconciliation grants none of those checks new acceptance.', 'No new human linguistic, participant, device, visual or audio acceptance was performed.'],
  inspection_attempts: [{tool_chunk: '395b0e', exit_code: 1, scope: 'Built-in-only read/hash probe', reason: 'An assumed age-03.cjs source did not exist; no files were written and no project code ran. Corrected read enumerated actual age-06 through age-12 sources and central author source.', superseded_by_tool_chunk: '2edcb1'}],
  recommended_checkpoint_text: checkpointWording,
  recommended_pending_text: 'Retain required later-build runtime, complete game, device, storage/loading and accessibility/layout acceptance; remove the unqualified Growth morphology audit item from unfinished content work.'
};
const inputPins = [...pins.values()].sort((a, b) => a.path.localeCompare(b.path, 'en'));
for (const pin of inputPins) requireTrue(hash(fs.readFileSync(path.join(root, pin.path))) === pin.sha256, 'Input changed before write: ' + pin.path);
for (const name of ['review.json', 'input-pins.json', 'README.md', 'inventory.json']) requireTrue(!fs.existsSync(path.join(output, name)), 'Output already exists: ' + name);
const writeJson = (name, value) => fs.writeFileSync(path.join(output, name), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
writeJson('input-pins.json', {schema: 1, scope: 'Observed raw inputs; all rehashed unchanged immediately before this evidence write.', count: inputPins.length, files: inputPins});
writeJson('review.json', review);
fs.writeFileSync(path.join(output, 'README.md'), '# Current Growth morphology evidence reconciliation\n\n' + checkpointWording + '\n\nThe final receipt is `build/professional-english/morphology-null-review/hold9-final-runtime-validation.json` (SHA-256 `733e5b5851c9f1f12e41dccc919baad965684a800a56b8b60a90ff77b239b2ab`). All nine current test source pins and all seven final test logs match it. Authoring and validator sources match the preserved accepted candidate. The six earlier reviewed corrections, all nine final resolutions and all 22 final source registrations remain exact.\n\nThe earlier QA table is historical: its 1,220 atomic / 216 morphological analyses, 159 sources, seven Node tests and 20,503 native assertions preceded the corrections. The current figures are 1,206 atomic / 230 morphological, 209 sources, and the final historical 23 Node / 21,324 native outcomes. The current overlay has zero pending entries. Keep earlier failures and withdrawals immutable.\n\nThe r2 browser result remains a five-case historical Chromium pass. Its 17 source snapshots still match their saved pins, while five current cohorts differ. The receipt does not establish later-export or physical-device acceptance. The final native receipt has no complete transitive runtime-source closure; current runtime observations are therefore not promoted to freshly tested behavior.\n\n`review.json` contains exact comparisons, scope limits and proposed checkpoint wording. `input-pins.json` records every read input. This was a read-only reconciliation using built-in Node modules only. No project imports, tests, compilers, renderer/browser runs, production edits or saved-profile access occurred. A preliminary missing-file read is retained in the review history.\n', {flag: 'wx'});
const inventoryNames = ['inspect-evidence.cjs', 'input-pins.json', 'review.json', 'README.md'];
writeJson('inventory.json', {schema: 1, files: inventoryNames.map(name => {const bytes = fs.readFileSync(path.join(output, name)); return {path: name, bytes: bytes.length, sha256: hash(bytes)};})});
console.log(JSON.stringify({status: review.status, current_overlay_json_sha256: review.current_overlay_json_sha256, counts, raw_inputs_unchanged: inputPins.length, review_sha256: hash(fs.readFileSync(path.join(output, 'review.json'))), inventory_sha256: hash(fs.readFileSync(path.join(output, 'inventory.json')))}, null, 2));
