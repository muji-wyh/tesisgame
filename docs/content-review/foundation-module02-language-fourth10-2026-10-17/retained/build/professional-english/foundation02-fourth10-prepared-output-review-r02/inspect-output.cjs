'use strict';
// Independent inspection of existing JSON/bytes. Never imports candidate/project code.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const out = 'build/professional-english/foundation02-fourth10-prepared-output-review-r02';
const proposal = 'build/professional-english/foundation02-fourth10-delivery-preparation-r02';
const execution = proposal + '/execution-r01';
const witness = 'build/professional-english/foundation02-fourth10-root-preparation-r02';
const sourceReview = 'build/professional-english/foundation02-fourth10-preparation-source-review-r02';
const diagnosis = 'build/professional-english/foundation02-fourth10-preparation-failure-review-r01';
const author = 'docs/content-review/foundation-module02-language-fourth10-research-2026-10-17';
const languageReview = 'docs/content-review/foundation-module02-language-fourth10-independent-review-2026-10-17';
assert.equal(path.resolve(process.cwd()).replaceAll('\\', '/').toLowerCase(), root.toLowerCase());
assert.equal(path.resolve(__dirname).replaceAll('\\', '/').toLowerCase(), `${root}/${out}`.toLowerCase());
const raw = file => fs.readFileSync(path.join(root, file));
const read = file => JSON.parse(raw(file));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const jsha = value => sha(JSON.stringify(value));
const serialize = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const ref = file => { const value = raw(file); return {path: file, bytes: value.length, raw_sha256: sha(value)}; };
const write = (name, value) => { assert.match(name, /^[a-z0-9-]+\.json$/); fs.writeFileSync(path.join(root, out, name), serialize(value), {flag: 'wx'}); };
function files(directory) {
  return fs.readdirSync(path.join(root, directory), {withFileTypes: true}).flatMap(item => {
    assert.ok(!item.isSymbolicLink());
    const file = directory + '/' + item.name;
    return item.isDirectory() ? files(file) : [file];
  }).sort();
}
const ids = ['submit.send-for-consideration.v','approve.authorize.v','reject.decline-acceptance.v','sign.write-name.v','delay.late-occurrence.n','error.mistake.n','fault.equipment-defect.n','damage.physical-harm.n','shortage.insufficient-supply.n','missing.not-present.adj'];
const target = 'data/professional/lexemes/foundation-module02.json';
const sourcesFile = 'data/professional/sources.json';
const provenanceTarget = 'data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json';
const started = new Date().toISOString();
const receiptPath = execution + '/preparation-receipt.json';
const witnessPath = witness + '/execution/receipt.json';
assert.equal(ref(receiptPath).raw_sha256, 'b6f797200a9c856b189dfcc3bf1dc20e65a8b9aac361b62bd3959ae460311f4d');
assert.equal(ref(witnessPath).raw_sha256, 'b3597a51b6d3a501ddcd507471582b6370eff9c1a1904bbc557d84cfff69a82c');
const receipt = read(receiptPath), rootReceipt = read(witnessPath);
assert.equal(receipt.status, 'frozen_preparation_pending_independent_technical_review');
assert.equal(rootReceipt.ok, true); assert.equal(rootReceipt.sources_unchanged, true);
assert.deepEqual(rootReceipt.sources_after, rootReceipt.sources);
assert.equal(rootReceipt.sources.length, 13);
for (const row of rootReceipt.sources) assert.deepEqual(ref(row.path), {path: row.path, bytes: row.bytes, raw_sha256: row.sha256});
assert.equal(rootReceipt.commands.length, 4);
for (const [i, command] of rootReceipt.commands.entries()) {
  assert.equal(command.exit_code, 0); assert.equal(command.error, null); assert.equal(command.signal, null);
  assert.equal(ref(witness + '/execution/' + command.log).raw_sha256, command.log_sha256);
  assert.deepEqual(command.command.slice(1), i < 3 ? ['--check', proposal + '/' + ['projection.cjs','test-transforms.cjs','prepare.cjs'][i]] : [proposal + '/prepare.cjs','--root-dispatch','confirmed-by-root']);
}
assert.equal(ref(witness + '/invoke.cjs').raw_sha256, read(witness + '/dispatch-source.json').wrapper_sha256);
assert.equal(rootReceipt.review.sha256, ref(sourceReview + '/review.json').raw_sha256);
assert.equal(rootReceipt.inventory.sha256, ref(proposal + '/author-inventory.json').raw_sha256);
const sourceRefs = rootReceipt.sources.map(row => ref(row.path));
assert.deepEqual(receipt.source_files, sourceRefs.map(row => ({path: row.path, raw_sha256: row.raw_sha256})));
assert.deepEqual(read(execution + '/execution-start.json').source_files, receipt.source_files);
const end = read(execution + '/execution-end.json');
assert.equal(end.status, 'prepared_pending_independent_technical_review');
assert.deepEqual(end.source_files_after, receipt.source_files);
assert.equal(receipt.projected_callback_count, 230); assert.equal(receipt.measured_input_count, 864);
for (const artifact of receipt.artifacts) assert.equal(ref(artifact.path).raw_sha256, artifact.raw_sha256);
const preparedRefs = files(execution).map(ref);
assert.equal(preparedRefs.length, 17);
assert.deepEqual(preparedRefs.map(row => row.path).sort(), [...receipt.artifacts.map(row => row.path), receiptPath, execution + '/execution-end.json'].sort());
const witnessRefs = files(witness).map(ref);
const pins = read(proposal + '/input-pins.json');
const expectedInputs = Object.fromEntries(pins.files.map(row => [row.path, row.raw_sha256]));
assert.equal(Object.keys(expectedInputs).length, 864);
assert.deepEqual(receipt.measured_input_sha256, expectedInputs);
assert.deepEqual(read(execution + '/measured-inputs-before.json').current_sha256, expectedInputs);
const inputBefore = pins.files.map(row => { const current = ref(row.path); assert.deepEqual(current, row); return current; });
for (const absent of pins.must_remain_absent) assert.equal(fs.existsSync(path.join(root, absent)), false);
const r = read(execution + '/accepted-language.json');
const accepted = read(languageReview + '/review-ledger.json');
const ledger = read(author + '/candidate-ledger.json');
const context = read(author + '/context-screen.json');
const index = read(author + '/source-index.json');
const observations = read(languageReview + '/source-observations.json');
const notes = read(author + '/research-notes.json');
assert.equal(r.new_language_approval, false); assert.equal(r.independent_review.human_or_specialist_approval, false);
assert.equal(ref(r.independent_review.path).raw_sha256, r.independent_review.raw_sha256);
assert.equal(r.independent_review.raw_sha256, '58993d8767ec701e37613fdee70d75e94f22a68d467b94157ea41a211bc9f8bd');
assert.deepEqual(r.independent_review.limitations, accepted.limits);
assert.deepEqual(r.patches.map(p => p.id), ids); assert.deepEqual(accepted.entries.map(p => p.id), ids);
assert.deepEqual(r.held, []); assert.deepEqual(r.excluded_source_ids, []);
const beforeEnvelope = read(execution + '/foundation-module02.json.before');
const afterEnvelope = read(execution + '/foundation-module02.json.after');
const beforeSources = read(execution + '/sources.json.before');
const afterSources = read(execution + '/sources.json.after');
assert.deepEqual(raw(target), raw(execution + '/foundation-module02.json.before'));
assert.deepEqual(raw(sourcesFile), raw(execution + '/sources.json.before'));
assert.deepEqual(Object.keys(beforeEnvelope), Object.keys(afterEnvelope));
for (const key of Object.keys(beforeEnvelope)) if (key !== 'lexemes') assert.deepEqual(afterEnvelope[key], beforeEnvelope[key]);
assert.deepEqual(Object.keys(beforeSources), Object.keys(afterSources));
for (const key of Object.keys(beforeSources)) if (key !== 'sources') assert.deepEqual(afterSources[key], beforeSources[key]);
assert.deepEqual(afterEnvelope.lexemes.map(e => e.id), beforeEnvelope.lexemes.map(e => e.id));
const selected = new Set(ids), patchMap = new Map(r.patches.map(p => [p.id, p]));
assert.deepEqual(afterEnvelope.lexemes.filter(e => !selected.has(e.id)), beforeEnvelope.lexemes.filter(e => !selected.has(e.id)));
const languageChanges = [], metadataChecks = [];
const scopeLimits = 'No human, subject-matter, morphology, media, domain, whole-expression, module or release approval is claimed.';
for (const p of r.patches) {
  const a = accepted.entries.find(row => row.id === p.id), authored = ledger.entries.find(row => row.id === p.id);
  assert.deepEqual(p.before, authored.before_entry);
  assert.deepEqual(p.before, beforeEnvelope.lexemes.find(row => row.id === p.id));
  assert.deepEqual(p.after, afterEnvelope.lexemes.find(row => row.id === p.id));
  assert.equal(jsha(p.before), p.before_sha256); assert.equal(jsha(p.after), p.after_sha256);
  assert.equal(p.before_sha256, a.before_entry_sha256);
  assert.deepEqual(p.accepted_fields, a.accepted_fields); assert.deepEqual(p.field_decisions, a.field_decisions);
  assert.equal(jsha(p.accepted_fields), p.accepted_fields_json_sha256);
  assert.deepEqual(p.accepted_content, authored.content_projection);
  assert.equal(jsha(p.accepted_content), a.accepted_content_projection_sha256);
  assert.deepEqual(Object.keys(p.after), Object.keys(p.before));
  const allowed = new Set(['definition','example','difficulty','review','references','editorial_notes']);
  const changed = Object.keys(p.before).filter(key => jsha(p.before[key]) !== jsha(p.after[key]));
  assert.deepEqual(changed, p.changed_fields); assert.ok(changed.every(key => allowed.has(key)));
  for (const key of Object.keys(p.before)) if (!allowed.has(key)) assert.deepEqual(p.after[key], p.before[key]);
  for (const field of ['definition','example','difficulty']) {
    assert.equal(p.after[field], a.accepted_fields[field]);
    if (p.after[field] !== p.before[field]) languageChanges.push({id: p.id, field, before: p.before[field], after: p.after[field]});
  }
  assert.deepEqual(p.after.review, {...p.before.review, status: 'reviewed', language: 'reviewed', reviewer: accepted.reviewer, reviewed_at: accepted.date_local});
  assert.equal(p.after.morphology.review.status, 'pending');
  assert.deepEqual(p.after.references.slice(0, p.before.references.length), p.before.references);
  assert.equal(p.after.references.length, p.before.references.length + 2);
  assert.deepEqual(p.source_ids, a.source_ids);
  assert.deepEqual(p.after.references.slice(-2).map(row => row.source_id), p.source_ids);
  assert.deepEqual(p.selected_source_observations, p.source_ids.map(id => observations.observations.find(row => row.source_id === id)));
  assert.deepEqual(p.author_source_observations, p.source_ids.map(id => index.sources.find(row => row.id === id)));
  assert.equal(p.dictionary_or_lesson_level_certification, false);
  assert.equal(p.historical_research_context_boundary, a.context_boundary);
  for (const decision of Object.values(a.field_decisions)) assert.ok(p.after.editorial_notes.includes(decision.rationale));
  assert.ok(p.after.editorial_notes.includes(notes.entries.find(row => row.id === p.id).excluded_scope));
  assert.ok(p.after.editorial_notes.includes(p.current_delivery_context_boundary));
  for (const text of [p.after.editorial_notes, ...p.after.references.slice(-2).map(row => row.scope)]) {
    assert.ok(text.includes(scopeLimits));
    assert.ok(text.includes('raw HTML was not independently retrieved'));
    assert.ok(text.includes('not source consensus or psychometric CEFR certification'));
  }
  for (const reference of p.after.references.slice(-2)) {
    assert.equal(reference.status, 'verified');
    assert.ok(reference.scope.startsWith('Verified only for the exact independently accepted definition, example and editorial difficulty of ' + p.id + '. '));
  }
  metadataChecks.push({id: p.id, changed_fields: changed, reference_prefix_preserved: true, added_scoped_references: 2,
    review_metadata_matches_named_AI_language_review: true, protected_fields_equal: true, media_morphology_domain_unchanged: true});
}
assert.deepEqual(['difficulty','definition','example'].map(field => languageChanges.filter(row => row.field === field).length), [6,1,1]);
assert.equal(new Set(languageChanges.map(row => row.id)).size, 6);
assert.deepEqual(afterSources.sources.slice(0, beforeSources.sources.length), beforeSources.sources);
assert.deepEqual(afterSources.sources.slice(beforeSources.sources.length), r.sources);
assert.equal(r.sources.length, 20); assert.equal(new Set(afterSources.sources.map(s => s.id)).size, afterSources.sources.length);
assert.deepEqual(r.sources.map(s => s.id), r.patches.flatMap(p => p.source_ids));
for (const source of r.sources) {
  const original = index.sources.find(row => row.id === source.id), observed = observations.observations.find(row => row.source_id === source.id);
  assert.equal(source.publisher, original.publisher); assert.equal(source.url, original.url); assert.equal(source.consulted_on, original.consulted_on);
  assert.equal(source.status, 'consulted'); assert.equal(source.assets_acquired, false); assert.equal(source.asset_license, null);
  assert.ok(source.scope.includes(JSON.stringify({author: original, reviewer: observed})));
  assert.ok(source.scope.includes(scopeLimits));
  assert.equal(observed.independent_consultation.fresh_raw_html_retrieval, false);
  assert.equal(observed.independent_consultation.fresh_raw_body_sha256, null);
  assert.equal(observed.source_pages_imported, false); assert.equal(observed.source_examples_imported, false); assert.equal(observed.media_acquired, false);
}
assert.deepEqual(r.source_observations, r.sources.map(source => ({author: index.sources.find(row => row.id === source.id), reviewer: observations.observations.find(row => row.source_id === source.id)})));
const catalog = read('data/professional/catalog.json');
const resource = value => {assert.ok(value.startsWith('res://')); return value.slice(6);};
const beforeRegistry = {catalog, themes: read(resource(catalog.themes)).profiles, sources: beforeSources.sources,
  courses: catalog.courses.map(course => read(resource(course.manifest))), lexemes: [], expressions: [], lexemeOrigins: {}, expressionOrigins: {}};
for (const [kind, origins, list] of [['lexemes','lexemeOrigins',catalog.lexeme_files],['expressions','expressionOrigins',catalog.expression_files]]) {
  for (const file of list) for (const entry of read(resource(file))[kind]) {beforeRegistry[kind].push(entry); beforeRegistry[origins][entry.id] = file;}
}
assert.equal(jsha(beforeRegistry), 'fb45e1d9c7cbf479bf06ac0c00b39ec28de473c96c86cc1b071c72a572f8d437');
const afterRegistry = structuredClone(beforeRegistry);
afterRegistry.lexemes = beforeRegistry.lexemes.map(entry => selected.has(entry.id) ? afterEnvelope.lexemes.find(row => row.id === entry.id) : entry);
afterRegistry.sources = afterSources.sources;
assert.equal(jsha(afterRegistry), '9a9b3c8665ce920fcddd584456e4ca47b8c365d8d2c43daacb9ea908c540ee1c');
assert.equal(r.source_baseline.registry_before_sha256, jsha(beforeRegistry));
assert.equal(r.source_baseline.registry_after_sha256, jsha(afterRegistry));
assert.deepEqual(receipt.source_baseline, r.source_baseline);
const reversedFourth = structuredClone(afterRegistry);
reversedFourth.lexemes = reversedFourth.lexemes.map(entry => patchMap.has(entry.id) ? patchMap.get(entry.id).before : entry);
reversedFourth.sources = reversedFourth.sources.slice(0, -20);
assert.deepEqual(reversedFourth, beforeRegistry);
const third = read('data/professional/provenance/foundation-module02-language-third10-2026-10-17.json');
assert.equal(third.patches.length, 8); assert.equal(third.sources.length, 16);
const historical = structuredClone(reversedFourth);
for (const p of third.patches) {const i = historical.lexemes.findIndex(e => e.id === p.id); assert.deepEqual(historical.lexemes[i], p.after); historical.lexemes[i] = p.before;}
assert.deepEqual(historical.sources.slice(-16), third.sources); historical.sources = historical.sources.slice(0,-16);
assert.equal(jsha(historical), 'f470936fc3bff7ff619b3af057a20cf5e05034013bbf08948e380847228dc4c5');
const oldEnvelope = structuredClone(beforeEnvelope), oldSourceEnvelope = structuredClone(beforeSources);
for (const p of third.patches) oldEnvelope.lexemes[oldEnvelope.lexemes.findIndex(e => e.id === p.id)] = p.before;
oldSourceEnvelope.sources = oldSourceEnvelope.sources.slice(0,-16);
for (const [file, value] of [[target, oldEnvelope],[sourcesFile, oldSourceEnvelope]]) assert.equal(sha(serialize(value)), context.source_file_hashes.find(row => row.path === file).raw_sha256);
const c = r.protected_context;
const groupMap = {memberships:'selected_memberships',modules:'containing_modules',expressions:'expression_uses',derivative_expressions:'derivative_expression_uses',focus_expressions:'focus_expressions',containing_module_expressions:'containing_module_expressions',additional_foundation02_preservation:'additional_foundation02_preservation',inherited_expression_holds:'inherited_expression_holds',prior_lexical_holds:'previous_whole_entry_holds',historical_context_boundaries:'context_boundaries',complete_pending_form_image_mismatch:'complete_existing_form_scope_mismatch'};
for (const [dest, origin] of Object.entries(groupMap)) assert.deepEqual(c[dest], context[origin]);
for (const name of ['expressions','derivative_expressions','focus_expressions','containing_module_expressions','additional_foundation02_preservation','inherited_expression_holds']) for (const row of c[name]) assert.deepEqual(beforeRegistry.expressions.find(e => e.id === row.id), row.before_entry);
for (const row of c.memberships) assert.equal(beforeRegistry.courses.find(course => course.id === row.course_id).modules.find(module => module.id === row.module_id).lexeme_ids[row.index], row.lexeme_id);
for (const row of c.modules) assert.equal(jsha(beforeRegistry.courses.find(course => course.id === row.course_id).modules.find(module => module.id === row.module_id)), row.module_json_sha256);
assert.deepEqual(c.prior_lexical_holds.map(row => row.id), ['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v']);
for (const row of c.prior_lexical_holds) {assert.deepEqual(afterRegistry.lexemes.find(e => e.id === row.id), row.before_entry); assert.equal(row.before_entry.review.language, 'pending');}
assert.equal(c.related_entries.length, 63);
for (const row of c.related_entries) {
  assert.deepEqual(row.before_entry, beforeRegistry.lexemes.find(e => e.id === row.id));
  assert.equal(row.entry_json_sha256, jsha(row.before_entry));
  assert.equal(row.historical_entry_json_sha256, jsha(historical.lexemes.find(e => e.id === row.id)));
}
assert.deepEqual(beforeRegistry.lexemes.find(e => e.id === 'complete.finish.v'), c.complete_pending_form_image_mismatch.before_entry);
assert.equal(jsha(c.complete_pending_form_image_mismatch.before_entry), '63f724e5609017e7ea9077c84221bd2cd68f5c7f70b212034eb2d8603dbcec14');
assert.equal(c.all_other_lexemes_json_sha256, jsha(afterRegistry.lexemes.filter(e => !selected.has(e.id))));
for (const [field,key] of [['expressions','all_expressions_json_sha256'],['courses','all_courses_json_sha256'],['themes','all_themes_json_sha256']]) assert.equal(c[key], jsha(afterRegistry[field]));
assert.equal(c.previous_sources_json_sha256, jsha(beforeRegistry.sources));
const ownDonor = read(diagnosis + '/donor-review.json'), donorChecks = [];
for (const h of ownDonor.histories) {
  assert.equal(ref(h.path).raw_sha256, h.sha256);
  const history = read(h.path);
  for (const p of r.patches) {
    const rows = history.protected_context.lexemes.map((row, index) => ({row,index})).filter(item => item.row.entry.id === p.id);
    const expected = h.groups.find(group => group.id === p.id);
    assert.equal(rows.length, expected.expected_count);
    for (const item of rows) assert.deepEqual(item.row, {resource:'res://data/professional/lexemes/foundation-module02.json', json_sha256:p.before_sha256, entry:p.before});
    assert.deepEqual(rows.map(item => item.index), expected.rows.map(row => row.index_zero_based));
    donorChecks.push({history:h.key,id:p.id,exact_count:rows.length,indices:rows.map(item=>item.index),every_whole_row_matches_before:true});
  }
}
assert.equal(donorChecks.length, 50); assert.equal(donorChecks.reduce((sum,row)=>sum+row.exact_count,0), 51);
const patches = read(execution + '/test-patches.json').patches;
assert.deepEqual(patches.map(row => row.path), ['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd']);
assert.deepEqual(patches.map(row=>row.exact_anchor_edits.length), [10,2,2]);
assert.deepEqual(patches.map(row=>row.appended_tests), [5,1,1]);
const transformText = raw(proposal + '/test-transforms.cjs').toString('utf8');
const testChecks = [];
for (const [i, p] of patches.entries()) {
  const before = raw(execution + '/' + p.before_artifact), after = raw(execution + '/' + p.after_artifact);
  assert.deepEqual(raw(p.path), before); assert.equal(sha(before), p.before_sha256); assert.equal(sha(after), p.after_sha256);
  const label = ['contentTests','morphologyTests','nativeTests'][i];
  const begin = 'const ' + label + ' = String.raw' + String.fromCharCode(96);
  const start = transformText.indexOf(begin) + begin.length;
  assert.ok(start >= begin.length); const stop = transformText.indexOf(String.fromCharCode(96) + ';', start);
  const append = transformText.slice(start, stop);
  assert.ok(after.toString('utf8').endsWith(append));
  let reversed = after.toString('utf8').slice(0, -append.length);
  for (const edit of [...p.exact_anchor_edits].reverse()) {
    assert.equal(edit.count, 1); assert.equal(reversed.split(edit.after).length - 1, 1);
    reversed = reversed.replace(edit.after, edit.before);
  }
  assert.deepEqual(Buffer.from(reversed), before);
  assert.equal(p.native, i === 2); assert.equal(p.native_parse_and_execution_pending, i === 2);
  testChecks.push({path:p.path, before_sha256:p.before_sha256, after_sha256:p.after_sha256,
    exact_anchor_edits:p.exact_anchor_edits.length, appended_tests:p.appended_tests,
    appended_text_matches_frozen_reviewed_source:true, removing_only_recorded_additions_restores_every_preimage_byte:true,
    native_execution_pending:p.native});
}
const checks = read(execution + '/projection-checks.json');
assert.equal(checks.ok,true); assert.equal(checks.callbacks.length,230); assert.ok(checks.callbacks.every(row=>row.passed===true));
assert.equal(checks.callbacks.filter(row=>row.file===patches[0].path).length,192);
assert.equal(checks.callbacks.filter(row=>row.file===patches[1].path).length,38);
assert.equal(checks.before_audit.errors,0); assert.equal(checks.after_audit.errors,0);
assert.equal(checks.after_audit.summary.ready_modules,0); assert.equal(checks.after_audit.summary.release_ready,false);
assert.equal(checks.native_dispatched,false); assert.equal(checks.current_persisted_node_execution,false);
const count = registry => ({reviewed:registry.lexemes.filter(e=>e.review.status==='reviewed').length,
  language_reviewed:registry.lexemes.filter(e=>e.review.language==='reviewed').length,
  foundation02_language:registry.lexemes.filter(e=>registry.lexemeOrigins[e.id]==='res://'+target && e.review.language==='reviewed').length});
assert.deepEqual(count(beforeRegistry),{reviewed:138,language_reviewed:325,foundation02_language:26});
assert.deepEqual(count(afterRegistry),{reviewed:148,language_reviewed:335,foundation02_language:36});
const replacementDefinitions = [
  [target,'foundation-module02.json.before','foundation-module02.json.after'],
  [sourcesFile,'sources.json.before','sources.json.after'],
  ...patches.map(p=>[p.path,p.before_artifact,p.after_artifact])
];
const replacements = replacementDefinitions.map(([target,before,after])=>({target,before:ref(execution+'/'+before),after:ref(execution+'/'+after)}));
const inputAfter = pins.files.map(row => {const current = ref(row.path); assert.deepEqual(current,row); return current;});
assert.deepEqual(inputAfter,inputBefore);
for (const row of [...sourceRefs,...preparedRefs,...witnessRefs]) assert.deepEqual(ref(row.path),row);
write('input-measurements.json',{schema:1,started_at:started,finished_at:new Date().toISOString(),input_count:864,
  before:inputBefore,after:inputAfter,all_current_inputs_match_preparation_and_pins:true,mismatches:[]});
write('inspection.json',{schema:1,status:'actual_prepared_output_inspection_complete',recorded_at:new Date().toISOString(),
  preparation_receipt:ref(receiptPath),root_witness:ref(witnessPath),source_count:13,execution_artifact_count:17,
  prepared_sources:sourceRefs,prepared_artifacts:preparedRefs,root_witness_files:witnessRefs,
  registry_before_sha256:jsha(beforeRegistry),registry_after_sha256:jsha(afterRegistry),historical_registry_sha256:jsha(historical),
  language_field_changes:languageChanges,metadata_checks:metadataChecks,source_additions:20,
  original_source_prefix_preserved:true,all_40_unselected_foundation02_entries_equal:true,
  historical_reversal:{fourth_exact_before:true,third_exact_research_registry:true,source_suffix_counts:[20,16],original_target_and_sources_raw_serialization_recovered:true},
  context_counts:{memberships:c.memberships.length,modules:c.modules.length,expressions:c.expressions.length,derivatives:c.derivative_expressions.length,focus:c.focus_expressions.length,related:c.related_entries.length,inherited_holds:c.inherited_expression_holds.length,module_expressions:c.containing_module_expressions.length,additional_foundation:c.additional_foundation02_preservation.length},
  protected_context_matches_frozen_research_and_exact_current_rebase:true,prior_lexical_holds_preserved:4,
  complete_pending_form_image_mismatch_preserved:true,donor_groups:donorChecks,exact_donor_rows:51,
  shared_test_checks:testChecks,projected_callbacks:{total:230,content:192,morphology:38,root_executed:true,reviewer_replayed:false},
  counts:{before:count(beforeRegistry),after:count(afterRegistry)},audit_observed_from_root_preparation:{before:checks.before_audit,after:checks.after_audit},
  all_864_inputs_unchanged:true,production_modified:false,project_code_imported:false,preparation_test_or_native_replayed:false});
write('review.json',{schema:1,status:'accepted_actual_prepared_outputs_for_root_candidate_native_validation',
  reviewer:'Codex recover_delivery independent technical output reviewer',recorded_at:new Date().toISOString(),
  preparation_receipt:ref(receiptPath),root_preparation_witness:ref(witnessPath),source_review:ref(sourceReview+'/review.json'),
  inspection:ref(out+'/inspection.json'),current_input_measurements:ref(out+'/input-measurements.json'),
  technical_prepared_output_accepted:true,accepted_language_decisions:10,new_language_approval:false,
  delivery_metadata_references_and_context_accepted_for_candidate_validation:true,
  findings:[
    'Ten exact accepted language projections; six difficulty edits, one definition edit and one example edit. Every other content field and every unselected Foundation02 entry is exact.',
    'Review metadata names the scoped independent AI language reviewer. Twenty consulted source records and two lexical references per entry preserve source observations, literal disagreements and acquisition limits.',
    'All expressions, courses, themes, memberships, four lexical holds and the complete form/image mismatch are preserved. Exact fourth-then-third data reversal recovers both pinned registries and original research file bytes.',
    'All50 history/ID groups and all51 complete donor rows match before entries. Historical fifth10 sign multiplicity remains two with both complete rows checked.',
    'Three test afterimages contain exactly14 recorded anchor edits plus5 content,1 morphology and1 native appended check. Removing those additions recovers every test preimage byte.',
    'Root witness confirms three syntax commands and one successful scratch preparation, with230 projected callbacks. All864 current inputs and13 proposal sources remain exact.'
  ],
  blockers_to_candidate_native_validation:[],native_parse_and_execution_pending:true,
  actual_persisted_tests_pending:true,guarded_commit_not_reviewed:true,production_or_commit_accepted:false,
  readiness:{ready_modules:0,release_ready:false,domain_morphology_media_human_specialist_gates_unchanged:true},
  reviewer_project_code_imported:false,reviewer_preparation_test_or_native_dispatched:false,production_modified:false});
write('binding.json',{schema:1,status:'frozen_prepared_output_binding_pending_root_native_and_commit_review',repository_root:root,
  output_review:ref(out+'/review.json'),inspection:ref(out+'/inspection.json'),inspection_source:ref(out+'/inspect-output.cjs'),
  current_measurements:ref(out+'/input-measurements.json'),measurement_count:864,expected_inputs:expectedInputs,
  replacements,provenance_addition:{target:provenanceTarget,after:ref(execution+'/accepted-language.json'),must_be_absent:true},
  required_absences:pins.must_remain_absent,source_baseline:r.source_baseline,
  preparation_receipt:ref(receiptPath),root_preparation_witness:ref(witnessPath),proposal_inventory:ref(proposal+'/author-inventory.json'),
  source_review:ref(sourceReview+'/review.json'),prepared_sources:sourceRefs,prepared_artifacts:preparedRefs,root_witness_files:witnessRefs,
  projected_callback_count:230,registry_before_sha256:jsha(beforeRegistry),registry_after_sha256:jsha(afterRegistry),
  native_acceptance:false,production_commit_acceptance:false,persisted_acceptance:false});
console.log(JSON.stringify({status:'accepted_for_candidate_native_validation',output:out,inputs:864,donor_groups:50,donor_rows:51,
  production_replacements:5,projected_callbacks:230,registry_after:jsha(afterRegistry)},null,2));
