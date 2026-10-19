'use strict';
// Static text supplement before any candidate execution. Preserves the first derivation record.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const out = path.resolve('Q:/.codex/worktrees/current-age-vocabulary/tesisgame/build/professional-english/foundation02-fourth10-delivery-preparation-r02');
assert.equal(path.resolve(__dirname).toLowerCase(), out.toLowerCase());
assert(!fs.existsSync(path.join(out, 'execution-r01')));
assert(!fs.existsSync(path.join(out, 'author-inventory.json')));
assert(!fs.existsSync(path.join(out, 'coverage-supplement.json')));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const sourceBefore = sha(fs.readFileSync(__filename));
const pins = [['test-transforms.cjs', '8c7d14a179b193bc8d107956e17cdc93d5bf24b02a227c5428b2b0b8c900f786'], ['prepare.cjs', '5f72577a8651ed37c1bc7b6df0a66ad745645f65a6a060e022e967b031656790']];
const before = new Map(pins.map(([name, hash]) => { const raw = fs.readFileSync(path.join(out, name)); assert.equal(sha(raw), hash); return [name, raw]; }));
const marker = "test('Foundation02 fourth-ten language leaves exact morphology, media and historical Foundation donors unchanged', () => {\n";
const added = "  assert.deepEqual(foundation02FourthLanguageRecord.patches.map(p=>p.id),['submit.send-for-consideration.v','approve.authorize.v','reject.decline-acceptance.v','sign.write-name.v','delay.late-occurrence.n','error.mistake.n','fault.equipment-defect.n','damage.physical-harm.n','shortage.insufficient-supply.n','missing.not-present.adj']);\n";
let transformed = before.get('test-transforms.cjs').toString('utf8');
assert.equal(transformed.split(marker).length - 1, 1);
transformed = transformed.replace(marker, marker + added);
const sourceMarker = "'revision-derivation.json', 'freeze-inputs.cjs', 'author-inventory.json']";
const sourceReplacement = "'revision-derivation.json', 'author-coverage-r02.cjs', 'coverage-supplement.json', 'freeze-inputs.cjs', 'author-inventory.json']";
let prepare = before.get('prepare.cjs').toString('utf8');
assert.equal(prepare.split(sourceMarker).length - 1, 1);
prepare = prepare.replace(sourceMarker, sourceReplacement);
const outputs = [['test-transforms.cjs', Buffer.from(transformed)], ['prepare.cjs', Buffer.from(prepare)]];
for (const [name, hash] of pins) assert.equal(sha(fs.readFileSync(path.join(out, name))), hash);
assert.equal(sha(fs.readFileSync(__filename)), sourceBefore);
for (const [name, raw] of outputs) fs.writeFileSync(path.join(out, name), raw);
const record = {
  schema: 1, status: 'pre_execution_exact_id_coverage_supplement', recorded_at: new Date().toISOString(),
  author_source_before_sha256: sourceBefore, author_source_after_sha256: sha(fs.readFileSync(__filename)),
  retained_initial_derivation_sha256: '317d94037e9ccd27a6c38feb34bb199fec697d61f0f22ddbb1a4b6b2b181164c',
  input_sources: pins.map(([path, raw_sha256]) => ({path, raw_sha256})),
  output_sources: outputs.map(([path, raw]) => ({path, bytes: raw.length, raw_sha256: sha(raw)})),
  edits: [{file: 'test-transforms.cjs', before: marker, after: marker + added, count: 1}, {file: 'prepare.cjs', before: sourceMarker, after: sourceReplacement, count: 1}],
  reason: 'Explicit ten-ID coverage before the patch loop prevents any unexpected non-sign ID from inheriting a default count rule. The five histories remain explicit and ordered.',
  candidate_implementation_executed_before_edit: false, production_mutated: false, shared_tests_mutated: false,
  project_modules_imported: false, preparation_dispatched: false, tests_or_native_dispatched: false
};
const raw = Buffer.from(JSON.stringify(record, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'coverage-supplement.json'), raw, {flag: 'wx'});
console.log(JSON.stringify({coverage_supplement_sha256: sha(raw), outputs: record.output_sources}, null, 2));
