'use strict';
// Built-in-only scratch finalization after an actual successful candidate.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(path.resolve(process.cwd()), root);
const sha = b => crypto.createHash('sha256').update(b).digest('hex'), encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const at = p => { assert(typeof p === 'string' && !path.isAbsolute(p) && !p.includes('\\') && !p.split('/').includes('..')); return path.join(root, p); };
const raw = p => fs.readFileSync(at(p)), read = p => JSON.parse(raw(p));
const input = read('build/professional-english/shopping-bag-final-artifacts-r01/input.json');
assert.equal(input.status, 'root_confirmed_actual_candidate_success_for_final_artifacts');
for (const r of input.references) assert.equal(sha(raw(r.path)), r.sha256, r.path);
const candidate = input.candidate_directory;
assert(/^build\/professional-english\/shopping-bag-projected-validation-r\d+$/.test(candidate));
const receipt = read(candidate + '/attempt-001/receipt.json');
assert.equal(receipt.ok, true); assert.equal(receipt.error, null); assert(receipt.callbacks.length >= 235);
assert(receipt.callbacks.every(r => r.passed === true)); assert.equal(receipt.audit.errors, 0);
assert.equal(receipt.audit.summary.integrated_word_images, 9); assert.equal(receipt.audit.summary.integrated_word_audio, 12);
assert.equal(receipt.audit.summary.ready_modules, 0);
const prep = 'build/professional-english/shopping-bag-delivery-preparation-r02/execution-r01';
const destination = 'docs/assets/sources/shopping-bag-delivery-review-2026-10-17';
const prepared = read(prep + '/production-provenance.prepared.json');
const retained = new Map(prepared.retained_delivery_evidence.map(r => [r.source, r.target]));
const sourceFiles = [...new Set([...read(candidate + '/input.json').evidence_files.map(r => r.path), ...input.references.map(r => r.path),
  candidate + '/run.cjs', candidate + '/input.json', candidate + '/attempt-001/start.json', candidate + '/attempt-001/receipt.json',
  'build/professional-english/shopping-bag-final-artifacts-r01/finalize.cjs', 'build/professional-english/shopping-bag-final-artifacts-r01/input.json'])];
const additions = [];
for (const source of sourceFiles) {
  if (retained.has(source)) continue;
  const target = destination + '/final-evidence/' + source;
  assert(!fs.existsSync(at(target)), target);
  const b = raw(source);
  retained.set(source, target);
  additions.push({source, target, bytes: b.length, sha256: sha(b)});
}
const ref = source => { assert(retained.has(source), source); return {path: retained.get(source), raw_sha256: sha(raw(source))}; };
prepared.status = 'reviewed_image_delivery_requires_actual_committed_journal';
prepared.integration_approval = ref(input.dispatch_review);
prepared.lineage.reviewed_test_delta = ref(prep + '/test-edit-ledger.json');
prepared.lineage.successful_projected_validation = ref(candidate + '/attempt-001/receipt.json');
prepared.lineage.successful_projected_validation_source = ref(candidate + '/run.cjs');
prepared.lineage.successful_projected_validation_input = ref(candidate + '/input.json');
prepared.finalization_rule = 'This immutable delivery record binds approved image and test afterimages. Actual commit and persisted success are recorded separately after those events; the null/false construction-time fields are not claims that installation failed.';
prepared.delivery_completion = {
  condition: 'Require the actual committed journal and successful fresh persisted receipt; candidate validation alone does not establish installation.',
  transaction: 'build/professional-english/transactions/shopping-bag-image-r01',
  committed_receipt: destination + '/commit/receipt.json',
  persisted_receipt: 'docs/qa/professional-shopping-bag-r01/persisted/attempt-001/receipt.json',
  actual_success_not_predeclared: true
};
prepared.retained_final_evidence = additions;
assert.equal(prepared.audit.production_integrated, false); assert.equal(prepared.audit.fresh_production_delivery_verified, false);
assert.equal(prepared.lineage.guarded_commit_receipt, null); assert.equal(prepared.lineage.fresh_persisted_verification, null);
let document = raw(prep + '/production-document.prepared.md').toString('utf8');
const opening = '**Proposal template. No production integration or persisted verification has occurred.** Replace this opening only with the actual later status and evidence after the independently reviewed transaction. Do not publish this template as an integration success.';
assert(document.includes(opening));
document = document.replace(opening, '**Reviewed image delivery package.** The exact image and entry/test afterimages passed projected validation. Actual installation and fresh persisted validation are recorded separately in the linked receipts below; this document does not predeclare those outcomes.');
document = document.replace('Its proposed raw path is', 'Its raw delivery path is').replace('## Proposed entry and delivery scope', '## Reviewed entry and delivery scope').replace('The planned integration changes only', 'The reviewed integration changes only');
const ending = 'Record the actual later integration review, post-fourth-ten baseline, guarded commit, installed descriptor/hash/budget checks, persisted suite/audit results and protected-state evidence here only after they occur. Retain candidate acceptance separately and do not replay its consumed one-shot probe. No production verification result is filled in this template.';
assert(document.includes(ending));
document = document.replace(ending, 'The exact post-fourth-ten baseline, prepared changes and independent dispatch review are retained with the provenance. Projected validation passed ' + receipt.callbacks.length + ' affected Node callbacks with zero audit errors, nine integrated image descriptors, twelve approved recordings and zero ready modules. Its actual receipt is `' + ref(candidate + '/attempt-001/receipt.json').path + '` (SHA256 `' + sha(raw(candidate + '/attempt-001/receipt.json')) + '`). The failed first candidate and undispatched revisions remain preserved.\n\nActual installation requires a committed guarded journal. Its later immutable receipt is `docs/assets/sources/shopping-bag-delivery-review-2026-10-17/commit/receipt.json`; fresh installed-state results are recorded at `docs/qa/professional-shopping-bag-r01/persisted/attempt-001/receipt.json`. These are separate evidence stages. The consumed 534-check native candidate probe was not replayed.');
const out = path.join(__dirname, 'output'); assert(!fs.existsSync(out)); fs.mkdirSync(out);
const write = (name, bytes) => fs.writeFileSync(path.join(out, name), bytes, {flag: 'wx'});
write('production-provenance.final.json', encode(prepared)); write('production-document.final.md', Buffer.from(document));
write('additional-retained-files.json', encode({schema: 1, status: 'explicit_absent_additions_for_final_transaction', files: additions}));
write('receipt.json', encode({schema: 1, status: 'final_artifacts_prepared_no_production_mutation', candidate_receipt: ref(candidate + '/attempt-001/receipt.json'),
  outputs: ['production-provenance.final.json', 'production-document.final.md', 'additional-retained-files.json'].map(file => ({file, sha256: sha(fs.readFileSync(path.join(out, file)))})),
  production_mutated: false, actual_commit_claimed: false, persisted_validation_claimed: false}));
console.log(JSON.stringify({prepared: true, retained_additions: additions.length, receipt_sha256: sha(fs.readFileSync(path.join(out, 'receipt.json')))}));
