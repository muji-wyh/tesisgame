'use strict';
// Static JSON/raw hash evidence only. No application code or validators run.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../../..');
const author = path.join(root, 'build/professional-english/foundation-module02-language-review/third10-research-r01');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const sha = raw => crypto.createHash('sha256').update(raw).digest('hex');
const hash = value => sha(JSON.stringify(value));
const resource = value => path.join(root, value.slice(6));
const ledger = read(path.join(author, 'candidate-ledger.json'));
const context = read(path.join(author, 'context-screen.json'));
const catalog = read(path.join(root, 'data/professional/catalog.json'));
const data = {catalog, themes: read(resource(catalog.themes)).profiles,
  sources: read(resource(catalog.sources)).sources, courses: [], lexemes: [],
  expressions: [], lexemeOrigins: {}, expressionOrigins: {}};
for (const course of catalog.courses) data.courses.push(read(resource(course.manifest)));
for (const [kind, origins, files] of [['lexemes', 'lexemeOrigins', catalog.lexeme_files],
  ['expressions', 'expressionOrigins', catalog.expression_files]]) {
  for (const file of files) for (const entry of read(resource(file))[kind]) {
    data[kind].push(entry);
    data[origins][entry.id] = file;
  }
}
const lexical = new Map(data.lexemes.map(entry => [entry.id, entry]));
const expressions = new Map(data.expressions.map(entry => [entry.id, entry]));
const row = (id, value, expected) => ({id, sha256: hash(value), expected_sha256: expected,
  equal: hash(value) === expected});
const entryHashes = ledger.entries.map(entry => ({id: entry.id,
  before: row(entry.id, lexical.get(entry.id), entry.before_entry_sha256),
  captured_before: row(entry.id, entry.before_entry, entry.before_entry_sha256),
  projection: row(entry.id, entry.content_projection, entry.content_projection_sha256)}));
const inherited = context.inherited_expression_holds.map(entry =>
  row(entry.id, expressions.get(entry.id), entry.before_entry_json_sha256));
const prior = context.prior_lexical_holds.map(entry =>
  row(entry.id, lexical.get(entry.id), entry.whole_entry_json_sha256));
const selected = new Set(ledger.entries.map(entry => entry.id));
const memberships = [], modules = [];
for (const course of data.courses) for (const module of course.modules) {
  for (const [index, id] of module.lexeme_ids.entries()) if (selected.has(id)) {
    memberships.push({course_id: course.id, module_id: module.id, index, lexeme_id: id});
  }
  if (module.lexeme_ids.some(id => selected.has(id))) modules.push({
    course_id: course.id, module_id: module.id, module_json_sha256: hash(module),
    selected_lexeme_ids: module.lexeme_ids.filter(id => selected.has(id))
  });
}
const recordedSources = read(path.join(author, 'source-index.json')).sources;
const metadata = read(path.join(author, 'oxford-html-metadata.json')).observations;
const selectedMetadata = recordedSources.filter(source => source.publisher === 'Oxford University Press').map(source => {
  const observed = metadata.find(item => item.term === source.term);
  const actual = source.observed_html_selected_levels.map(selected => {
    const element = observed.sense_elements.find(item => item.attributes.id === selected.element_id);
    return {element_id: element.attributes.id, sense_number: element.attributes.sensenum || null,
      cefr: element.attributes.cefr || null, fkcefr: element.attributes.fkcefr || null,
      html_offset: element.html_offset};
  });
  return {term: source.term, url_matches_capture_or_response: [observed.url, observed.response_url].includes(source.url),
    body_hash_matches: observed.raw_body_sha256 === source.raw_body_sha256,
    selected_metadata: row(source.id, actual, hash(source.observed_html_selected_levels))};
});
const output = {schema: 1, kind: 'independent_static_json_hash_evidence',
  method: 'Only filesystem reads, JSON parsing and static SHA256 calculations; no production modules imported or tests executed.',
  script_sha256: sha(fs.readFileSync(__filename)),
  registry: row('professional-registry', data, ledger.input.registry_json_sha256),
  entries: entryHashes, inherited_expression_holds: inherited, prior_lexical_holds: prior,
  complete_unchanged: row('complete.finish.v', lexical.get('complete.finish.v'), context.complete_existing_form_scope_mismatch.current_whole_entry_json_sha256),
  memberships: row('selected-memberships', memberships, hash(context.selected_memberships)), membership_count: memberships.length,
  containing_modules: row('containing-modules', modules, hash(context.containing_modules)), containing_module_count: modules.length,
  selected_source_metadata: selectedMetadata};
fs.writeFileSync(path.join(__dirname, 'static-hashes.json'), JSON.stringify(output, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({registry: output.registry, memberships: output.memberships,
  containing_modules: output.containing_modules, entry_hashes_equal: entryHashes.every(entry => entry.before.equal && entry.captured_before.equal && entry.projection.equal),
  inherited_holds_equal: inherited.every(entry => entry.equal), prior_holds_equal: prior.every(entry => entry.equal),
  complete_equal: output.complete_unchanged.equal, selected_metadata_equal: selectedMetadata.every(entry =>
    entry.url_matches_capture_or_response && entry.body_hash_matches && entry.selected_metadata.equal)}));
