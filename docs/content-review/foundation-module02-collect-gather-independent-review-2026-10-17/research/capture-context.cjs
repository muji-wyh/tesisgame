'use strict';
// Read-only content inspection; no project serializer, validator or test imports.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
if (root.replaceAll('\\', '/').toLowerCase() !== 'q:/.codex/worktrees/current-age-vocabulary/tesisgame') throw new Error('Wrong workspace.');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const rows = (dir, key) => fs.readdirSync(path.join(root, dir)).filter(name => name.endsWith('.json')).sort().flatMap(name => {
  const file = dir + '/' + name;
  return (read(file)[key] || []).map(entry => ({ file, object_sha256: hash(entry), entry }));
});
const lexemes = rows('data/professional/lexemes', 'lexemes');
const expressions = rows('data/professional/expressions', 'expressions');
const courses = fs.readdirSync(path.join(root, 'data/professional/courses')).filter(name => name.endsWith('.json')).sort().map(name => ({ file: 'data/professional/courses/' + name, course: read('data/professional/courses/' + name) }));
const target = lexemes.find(row => row.entry.id === 'collect.gather.v');
const expression = expressions.find(row => row.entry.id === 'expr.foundation.module02.08');
const verbal = /\bcollect(?:s|ed|ing)?\b/i;
const related = /\b(?:collect(?:s|ed|ing|ion|ions|or)?|pick[ -]?up|gather(?:s|ed|ing)?)\b/i;
const memberships = id => courses.flatMap(({ file, course }) => (course.modules || []).flatMap(module => {
  const kinds = ['lexeme_ids', 'expression_ids'].filter(key => (module[key] || []).includes(id));
  return kinds.map(key => ({ file, course_id: course.id, module_id: module.id, status: module.status, curriculum_revision: course.curriculum_revision ?? course.revision ?? null, membership_kind: key, index: module[key].indexOf(id), module_json_sha256: hash(module) }));
}));
const expressionHits = expressions.filter(({ entry }) => (entry.focus_lexeme_ids || []).includes(target.entry.id) || [entry.text, entry.meaning, entry.context].some(value => verbal.test(value || ''))).map(row => ({
  ...row,
  matched_fields: ['text', 'meaning', 'context'].filter(key => verbal.test(row.entry[key] || '')),
  focus_matches_target: (row.entry.focus_lexeme_ids || []).includes(target.entry.id),
  token_hits: (row.entry.tokens || []).filter(token => verbal.test(token.text)),
  memberships: memberships(row.entry.id)
}));
const relatedIdentities = lexemes.filter(({ entry }) => related.test(entry.id) || related.test(entry.text)).map(row => ({ ...row, memberships: memberships(row.entry.id) }));
const lexicalUses = lexemes.filter(({ entry }) => [entry.definition, entry.example, entry.media?.image?.brief].some(value => verbal.test(value || ''))).map(({ file, object_sha256, entry }) => ({ file, object_sha256, id: entry.id, text: entry.text, definition: entry.definition, example: entry.example, image_brief: entry.media?.image?.brief, matched_fields: ['definition', 'example'].filter(key => verbal.test(entry[key] || '')), morphology_review: entry.morphology?.review?.status ?? null }));
const source = read('data/professional/sources.json');
const sourceRows = Array.isArray(source) ? source : source.sources;
const contextualSourceIds = new Set([target, expression, ...lexemes.filter(row => ['assist.help.v', 'return.send-back.v', 'form.information-template.n', 'team.working-group.n'].includes(row.entry.id))].flatMap(row => (row.entry.references || []).map(ref => ref.source_id)));
const context = {
  schema: 1, status: 'read_only_context_for_unaccepted_collect_gather_repair', observed_at: new Date().toISOString(),
  canonical_target: target,
  target_memberships: memberships(target.entry.id),
  affected_expression: expression,
  expression_memberships: memberships(expression.entry.id),
  literal_inflected_expression_scan: { forms: ['collect', 'collects', 'collected', 'collecting'], fields: ['text', 'meaning', 'context', 'tokens', 'focus_lexeme_ids'], total_expressions_inspected: expressions.length, hits: expressionHits, limitation: 'Literal inflections and exact focus binding only. Derivatives such as collection are separately recorded as related identities, not automatically treated as this verb.' },
  related_identities: relatedIdentities,
  lexical_context_uses: lexicalUses,
  neighboring_entries: lexemes.filter(row => ['assist.help.v', 'return.send-back.v'].includes(row.entry.id)),
  relevant_source_records: sourceRows.filter(item => contextualSourceIds.has(item.id)),
  direct_collect_source_records: sourceRows.filter(item => /collect(?:_1)?(?:$|[?#])/.test(item.url || '') || /collect/.test(item.id || '')),
  inspection_totals: { lexemes: lexemes.length, expressions: expressions.length, courses: courses.length },
  shared_file_or_registry_baseline_frozen: false,
  production_changes: []
};
fs.writeFileSync(path.join(__dirname, 'context.json'), JSON.stringify(context, null, 2) + '\n', { flag: 'wx' });
process.stdout.write(JSON.stringify({target_hash:target.object_sha256, memberships:context.target_memberships.length, expression_memberships:context.expression_memberships.length, expression_hits:expressionHits.map(row=>({id:row.entry.id,text:row.entry.text,meaning:row.entry.meaning,fields:row.matched_fields,focus:row.focus_matches_target})),related_ids:relatedIdentities.map(row=>row.entry.id),lexical_uses:lexicalUses.map(row=>({id:row.id,example:row.example})),source_ids:context.direct_collect_source_records.map(row=>row.id)})+'\n');
