'use strict';
// Read-only source capture. Writes only to this research directory and never loads production serializers.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const out = __dirname;
const ids = ['collect.gather.v', 'notify.inform.v', 'postpone.delay-until-later.v', 'verify.establish-accuracy.v', 'unsafe.presenting-danger.adj', 'hazard.possible-harm.n'];
const historicalHashes = [
  '177f9fc35b0d348ddcc3cdf60c43dd5119d145acfe781d17c2b988e1b6d77981',
  '7aaf8490d372bb3c8490c2824955a59e92c3d3dfe4416cb73d772cc6413a0cdc',
  'ba004741e07d1dddcc8e1f69ebea15717ad97d90ea87f483e72559846a17cded',
  'd900dc371a4f37e536e5b252470b50fc85e988fc799ab279f2ef836e9ea43e9a',
  'b03ac8acf04932b9dfc3d44775939399ad37f73a1149faf72b708f244fc23286',
  'e513da37995090db5f5ef68c255e5beffde131c10afe12478e644651361c1045'
];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pins = [];
const read = relative => {
  const bytes = fs.readFileSync(path.join(root, relative));
  pins.push({ path: relative, bytes: bytes.length, sha256: sha(bytes) });
  return bytes;
};
const write = (name, object) => fs.writeFileSync(path.join(out, name), JSON.stringify(object, null, 2) + '\n', { flag: 'wx' });
if (fs.existsSync(path.join(out, 'context.json'))) throw new Error('Capture already exists. Preserve it.');
const raw = read('data/professional/lexemes/foundation-module02.json');
fs.writeFileSync(path.join(out, 'foundation-module02.before.json'), raw, { flag: 'wx' });
const entries = JSON.parse(raw).lexemes.filter(e => ids.includes(e.id));
if (entries.length !== 6) throw new Error('Six unique entries required.');
for (let i = 0; i < ids.length; i++) {
  const entry = entries.find(e => e.id === ids[i]);
  if (sha(JSON.stringify(entry)) !== historicalHashes[i]) throw new Error('Entry changed: ' + ids[i]);
}
const scan = directory => fs.readdirSync(path.join(root, directory)).filter(n => n.endsWith('.json')).sort().map(n => ({ relative: directory + '/' + n, data: JSON.parse(read(directory + '/' + n)) }));
const courseMemberships = [];
for (const { relative, data } of scan('data/professional/courses')) {
  for (const module of data.modules) {
    for (const id of ids) {
      if (module.lexeme_ids.includes(id)) courseMemberships.push({ file: relative, course: data.id, module: module.id, lexeme_id: id, requirements_revision: module.requirements_revision, status: module.status });
    }
  }
}
const surface = /\b(collect(?:s|ed|ing)?|notif(?:y|ies|ied|ying)|postpon(?:e|es|ed|ing)|verif(?:y|ies|ied|ying)|unsafe|hazards?)\b/i;
const expressions = [];
for (const { relative, data } of scan('data/professional/expressions')) {
  for (const expression of data.expressions) {
    const serialized = JSON.stringify(expression);
    const focusIds = ids.filter(id => serialized.includes('"' + id + '"'));
    if (surface.test(expression.text) || focusIds.length) expressions.push({ file: relative, object_sha256: sha(serialized), focus_ids: focusIds, expression });
  }
}
const alternatives = [];
const alternativeTexts = new Set(['check', 'delay', 'inform', 'danger', 'dangerous', 'risk', 'warn', 'gather', 'pick up', 'double-check']);
for (const { relative, data } of scan('data/professional/lexemes')) {
  for (const entry of data.lexemes) {
    if (alternativeTexts.has(entry.text.toLowerCase())) alternatives.push({ file: relative, object_sha256: sha(JSON.stringify(entry)), entry });
  }
}
const retainedReviewFiles = [
  'docs/content-review/foundation-module02-language-second10-proposals-2026-10-17/review.json',
  'docs/content-review/foundation-module02-language-third10-independent-review-2026-10-17/review.json',
  'docs/content-review/foundation-module02-language-fifth10-independent-review-2026-10-17/review-ledger.json'
];
fs.mkdirSync(path.join(out, 'retained-reviews'));
for (let i = 0; i < retainedReviewFiles.length; i++) fs.writeFileSync(path.join(out, 'retained-reviews', String(i + 1) + '.json'), read(retainedReviewFiles[i]), { flag: 'wx' });
for (const relative of [
  'data/professional/sources.json',
  'build/professional-english/foundation02-third10-persisted-validation-r01/attempt-001/receipt.json',
  'docs/plans/2026-10-15-professional-english-and-morphology.md',
  'docs/plans/professional-english-checkpoint.md'
]) read(relative);
write('context.json', {
  status: 'research_only_unaccepted', captured_at: new Date().toISOString(), root,
  branch: 'codex/current-age-vocabulary', head: '1a8e2c4d13b31e0da9b73adbf63f5327b8fab243',
  entries: ids.map((id, i) => ({ id, object_sha256: historicalHashes[i], entry: entries.find(e => e.id === id) })),
  course_memberships: courseMemberships, expression_context: expressions, alternative_inventory: alternatives,
  retained_review_files: retainedReviewFiles,
  scope: 'No production changes; no new acceptance; snapshots preserve existing whole-entry holds.'
});
write('input-pins.json', { captured_at: new Date().toISOString(), hash_algorithm: 'SHA256', object_hash_format: 'JSON.stringify(object), UTF-8, no trailing newline', files: pins });
console.log(JSON.stringify({ entries: entries.length, memberships: courseMemberships.length, surface_or_focus_expressions: expressions.length, focus_expressions: expressions.filter(e => e.focus_ids.length).length, alternative_headwords: alternatives.map(e => e.entry.id), source_pins: pins.length }));
