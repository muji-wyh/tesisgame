'use strict';
// Root-owned raw-file inspection and exact durable copies; no project imports.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = process.cwd();
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const encode = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const raw = p => fs.readFileSync(p);
const read = p => JSON.parse(raw(p));
const save = (p, b) => { fs.mkdirSync(path.dirname(p), {recursive: true}); fs.writeFileSync(p, Buffer.isBuffer(b) ? b : encode(b), {flag: 'wx'}); };
const base = 'build/professional-english/shopping-bag-persisted-validation-r02';
const dest = 'docs/qa/professional-shopping-bag-r01';
assert(!fs.existsSync(dest + '/persisted') && !fs.existsSync(dest + '/field-recount.json'), 'Do not overwrite retained evidence.');
const sourceHash = '6e138489e51f4789c1f2fd6a4039aa7e2f1af44ec435ff4309c33e568053bac5';
const inputHash = 'a31cd76e3f21b19fc727a5ce735bac6c3d20c9de8a71fe80b70b587c1907b70f';
assert.equal(sha(raw(base + '/invoke.cjs')), sourceHash);
assert.equal(sha(raw(base + '/input.json')), inputHash);
const input = read(base + '/input.json'), receiptPath = base + '/attempt-001/receipt.json';
const receipt = read(receiptPath), receiptHash = sha(raw(receiptPath));
assert.equal(receipt.ok, true); assert.equal(receipt.error, null); assert.equal(receipt.postcheck_error, null);
assert.equal(receipt.source_sha256, sourceHash); assert.equal(receipt.input_sha256, inputHash);
assert.deepEqual(receipt.tests, {tests: 255, pass: 255, fail: 0, cancelled: 0, skipped: 0});
assert.equal(receipt.audit.errors, 0); assert.equal(receipt.audit.warnings, 29395);
assert.deepEqual(receipt.audit.summary, input.expected_audit_summary);
assert.equal(receipt.commands.length, 2);
for (const c of receipt.commands) {
  assert.equal(c.exit_code, 0); assert.equal(c.error, null); assert.equal(c.signal, null);
  assert.equal(sha(raw(base + '/attempt-001/' + c.log)), c.log_sha256);
}
const inputPins = new Map(Object.entries(input.expected_inputs));
for (const r of input.evidence_files) { if (inputPins.has(r.path)) assert.equal(inputPins.get(r.path), r.sha256); inputPins.set(r.path, r.sha256); }
assert.equal(inputPins.size, 12230);
const tx = 'build/professional-english/transactions/shopping-bag-image-r01';
assert(!fs.existsSync('build/professional-english/transactions/active-transaction.json'));
const preparedRaw = raw(tx + '/prepared.json'), prepared = JSON.parse(preparedRaw), preparedHash = sha(preparedRaw);
assert.equal(preparedHash, 'e70ae73d803941d2400d0a9973a6b851ae9f8e06ba3d0b1771686fecb46dfc3a');
assert.equal(sha(encode(prepared.plan)), prepared.plan_sha256);
assert.equal(prepared.plan_sha256, '28c763178d2247e7e1fdce7290fa11799d8cce05709d3da696e2f7aeec9dfeb6');
const names = fs.readdirSync(tx + '/states').sort(); assert.equal(names.length, 308);
let previous = null, finalState;
for (const [index, name] of names.entries()) {
  const p = tx + '/states/' + name, b = raw(p), state = JSON.parse(b);
  assert.equal(state.sequence, index + 1); assert.equal(state.previous_state_sha256, previous);
  assert.equal(state.prepared_sha256, preparedHash); assert.equal(sha(b), inputPins.get(p));
  const status = index === 0 ? 'prepared' : index === 307 ? 'committed' : index % 2 === 1 ? 'applying' : 'applied';
  assert.equal(state.status, status);
  if (index > 0 && index < 307) assert.equal(state.path, prepared.entries[Math.floor((index - 1) / 2)].path);
  previous = sha(b); finalState = state;
}
assert.equal(previous, input.committed_journal.sha256);
assert.equal(tx + '/states/' + names.at(-1), input.committed_journal.path);
assert.deepEqual(finalState.targets, prepared.plan.entries.map(r => ({path: r.path, ...r.after, noop: r.noop})));
let stages = 0, backups = 0;
for (const [index, r] of prepared.entries.entries()) {
  assert.deepEqual({path: r.path, before: r.before, after: r.after, noop: r.noop}, prepared.plan.entries[index]);
  for (const [p, expected] of [[r.path, r.after], [tx + '/' + r.staged, r.after]]) {
    const b = raw(p); assert.equal(b.length, expected.bytes, p); assert.equal(sha(b), expected.sha256, p);
  }
  stages++;
  if (r.before) { const b = raw(tx + '/' + r.backup); assert.equal(b.length, r.before.bytes); assert.equal(sha(b), r.before.sha256); backups++; }
}
assert.equal(stages, 153); assert.equal(backups, 4);
const commit = read(input.commit_receipt.path);
assert.equal(sha(raw(input.commit_receipt.path)), input.commit_receipt.sha256);
assert.equal(commit.status, 'committed'); assert.deepEqual(commit.target_manifest, prepared.plan.entries);
const inspection = {schema: 1, status: 'actual_persisted_success_independently_inspected', receipt: {path: receiptPath, sha256: receiptHash},
  complete_journal_states: names.length, committed_state_sha256: previous, installed_targets: 153, staged_files: stages, backups,
  active_lock_absent: true, production_mutated: false, project_code_imported: false,
  scope: 'Raw receipt/log/complete journal chain and transitions/installed target inspection after the single persisted run. No test or native replay.'};
save('build/professional-english/shopping-bag-postpersist-r02/inspection.json', inspection);
const resource = p => { assert(p.startsWith('res://')); return read(p.slice(6)); };
const catalog = resource('res://data/professional/catalog.json');
const data = {catalog, themes: resource(catalog.themes).profiles, sources: resource(catalog.sources).sources,
  courses: [], lexemes: [], expressions: [], lexemeOrigins: {}, expressionOrigins: {}};
for (const item of catalog.courses) data.courses.push(resource(item.manifest));
for (const [key, origins, resources] of [['lexemes', 'lexemeOrigins', catalog.lexeme_files], ['expressions', 'expressionOrigins', catalog.expression_files]]) {
  for (const p of resources) for (const row of resource(p)[key]) { data[key].push(row); data[origins][row.id] = p; }
}
const registryHash = sha(JSON.stringify(data)); assert.equal(registryHash, commit.registry_after_sha256);
const counts = {overall_reviewed: data.lexemes.filter(r => r.review.status === 'reviewed').length,
  language_reviewed: data.lexemes.filter(r => r.review.language === 'reviewed').length,
  foundation02_language_reviewed: data.lexemes.filter(r => data.lexemeOrigins[r.id] === 'res://data/professional/lexemes/foundation-module02.json' && r.review.language === 'reviewed').length,
  unique_lexemes: data.lexemes.length, integrated_images: data.lexemes.filter(r => r.media.image.status === 'integrated').length,
  integrated_recordings: data.lexemes.filter(r => r.media.audio.status === 'integrated').length,
  ready_modules: data.courses.flatMap(r => r.modules).filter(r => r.status === 'ready').length};
assert.deepEqual(counts, {overall_reviewed: 148, language_reviewed: 335, foundation02_language_reviewed: 36, unique_lexemes: 4939, integrated_images: 9, integrated_recordings: 12, ready_modules: 0});
const recount = {schema: 1, scope: 'Raw JSON field recount after actual successful shopping-bag persisted verification', ...counts,
  registry_sha256: registryHash, sources_sha256: sha(raw('data/professional/sources.json')), persisted_validation_receipt_sha256: receiptHash};
assert.equal(recount.sources_sha256, '310be48d81d29917146db162b26d9927007b68ed12380df4a113458d2de7b330');
const mapping = [['invoke.cjs', 'persisted/invoke.cjs'], ['input.json', 'persisted/input.json'], ...['start.json', 'command-1.log', 'command-2.log', 'receipt.json'].map(n => ['attempt-001/' + n, 'persisted/attempt-001/' + n])].map(([s,t]) => ({source: base + '/' + s, target: dest + '/' + t}));
for (const name of ['persisted-input-inspection.json', 'persisted-input-review.json', 'persisted-input-review-inventory.json', 'persisted-inspection-authoring-failure-r01.json']) mapping.push({source: 'build/professional-english/shopping-bag-commit-independent-review-r01/' + name, target: dest + '/persisted/independent-review/' + name});
mapping.push({source: 'build/professional-english/shopping-bag-preparation-source-review-r02/persisted-validator-source-review-r01.json', target: dest + '/persisted/independent-review/persisted-validator-source-review-r01.json'});
for (const name of ['inspect-and-retain.cjs', 'inspection.json']) mapping.push({source: 'build/professional-english/shopping-bag-postpersist-r02/' + name, target: dest + '/persisted/root/' + name});
for (const name of ['review.json', 'inspection.json', 'inventory.json']) mapping.push({source: 'build/professional-english/shopping-bag-persisted-independent-review-r02/' + name, target: dest + '/persisted/r02-independent-review/' + name});
mapping.push({source: base + '/revision.json', target: dest + '/persisted/revision.json'});
const copies = mapping.map(r => ({...r, raw: raw(r.source)}));
for (const r of copies) { save(r.target, r.raw); assert.deepEqual(raw(r.target), raw(r.source)); }
save(dest + '/field-recount.json', recount);
const copyReceipt = {schema: 1, status: 'actual_persisted_evidence_exact_copies', files: copies.map(r => ({source: r.source, target: r.target, bytes: r.raw.length, sha256: sha(r.raw)}))};
save(dest + '/copy-receipt.json', copyReceipt);
console.log(JSON.stringify({ok: true, receipt_sha256: receiptHash, copied_files: copies.length, copy_receipt_sha256: sha(encode(copyReceipt)), inspection_sha256: sha(encode(inspection)), recount}));
