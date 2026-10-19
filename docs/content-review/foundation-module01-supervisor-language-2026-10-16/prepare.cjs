'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../..');
const {loadProfessionalContent, auditProfessionalContent} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const jsonHash = value => hash(JSON.stringify(value));
const read = file => fs.readFileSync(path.join(root, file));
const write = (name, value) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(value, null, 2) + '\n', {flag:'wx'});
const data = loadProfessionalContent(root);
const baselinePath = 'build/professional-english/continuation-validation-r30.json';
const baseline = JSON.parse(read(baselinePath));
assert.equal(baseline.ok, true);
assert.equal(jsonHash(data), baseline.registry_after_sha256);
for (const [file, sha] of Object.entries(baseline.after_input_sha256)) assert.equal(hash(read(file)), sha, file);
const before = data.lexemes.find(e => e.id === 'supervisor.work-overseer.n');
assert.equal(jsonHash(before), '4a2ae571f902632d58bb7d81ea7c5151c1132cd21a52885921eb30071d217583');
const researchPath = 'build/professional-english/foundation-module01-language-review/held-terms-research-r01/source-receipt.json';
const research = JSON.parse(read(researchPath));
const evidence = research.sources.slice(0, 3);
assert.deepEqual(evidence.map(e => e.id), ['british-council-a2-instructions-colleague', 'oxford-supervisor', 'collins-supervisor']);
const sourceIds = ['foundation01-supervisor-reconsideration-british-council-instructions', 'foundation01-supervisor-reconsideration-oxford-supervisor', 'foundation01-supervisor-reconsideration-collins-supervisor'];
assert.ok(sourceIds.every(id => !data.sources.some(s => s.id === id)));
const sources = evidence.map((s, index) => ({
  id: sourceIds[index], title: ['British Council: Instructions for a colleague', "Oxford Advanced Learner's Dictionary: supervisor", 'Collins English Dictionary: supervisor'][index],
  publisher: s.publisher, url: s.url, status: 'consulted', consulted_on: '2026-10-16',
  scope: s.supports + ' ' + s.limits + ' Source consultation supports bounded AI language review only; no assets or exercises were acquired.',
  asset_license: null, assets_acquired: false
}));
const basis = 'Editorial B2 for active learning of this ordinary workplace role. The exact noun occurs in the publisher-authored model text of a British Council A2 workplace lesson; this demonstrates contextual teachability, not word-level A2 or B2 certification. Oxford labels the selected noun topics C1, and that observation is retained. B2 is an independent curriculum placement at the upper end of the specified range, based on the concrete role, a transparent workplace example and graded contextual evidence. It is not an automatic clamp of C1 or a level transferred from supervise; Collins supplies meaning evidence without a selected CEFR label.';
const limits = 'Ordinary work oversight only. No fixed organizational hierarchy, clinical authority, regulated supervision qualification, public-office role, academic supervisor sense or whole-expression approval is established.';
const reviewer = 'Codex root independent AI language review; not human or subject-matter approval';
const after = structuredClone(before);
after.definition = "A person whose job includes directing and checking other people's work.";
after.difficulty = 'B2';
after.review = {...before.review, status:'reviewed', language:'reviewed', reviewer, reviewed_at:'2026-10-16'};
after.references.push(...sources.map((s, index) => ({source_id:s.id, status:'verified', scope:evidence[index].paraphrase + ' ' + evidence[index].limits + ' ' + basis + ' ' + limits})));
after.editorial_notes = 'Shared workplace foundation. The exact ordinary role definition, retained example and editorial B2 placement have independent AI language acceptance. ' + basis + ' ' + limits + ' Accepted forms, region and prior reference state are unchanged. Morphology, image, pronunciation, expressions and module readiness remain under their separate pending gates.';
const protect = value => { const out = structuredClone(value); for (const key of ['definition','difficulty','references','editorial_notes']) delete out[key]; for (const key of ['status','language','reviewer','reviewed_at']) delete out.review[key]; return out; };
assert.deepEqual(protect(after), protect(before));
const memberships = data.courses.flatMap(c => c.modules.filter(m => m.lexeme_ids.includes(before.id)).map(m => ({course_id:c.id,module_id:m.id})));
assert.equal(memberships.length, 20); assert.ok(memberships.every(m => m.module_id === 'module01'));
const contextExpressions = data.expressions.filter(e => /\bsupervisor\b/i.test(e.text));
assert.equal(contextExpressions.length, 21);
const focus = contextExpressions.filter(e => e.focus_lexeme_ids?.includes(before.id));
const record = {
  schema:1, status:'independent_ai_language_accepted_pending_delivery', reviewer,
  author_research:{path:researchPath,raw_sha256:hash(read(researchPath)),author:research.author,acceptance:false},
  independent_review:{reviewer:'Codex root',recorded_on:'2026-10-16',accepted:true,scope:'Exact ordinary supervisor noun definition, retained example and editorial B2 difficulty only',direct_primary_source_crosscheck:true,source_observations:evidence,editorial_basis:basis,limits,human_or_specialist_approval:false},
  patches:[{id:before.id,before,after,before_sha256:jsonHash(before),after_sha256:jsonHash(after),protected_fields_sha256:jsonHash(protect(before)),changed_fields:Object.keys(before).filter(k => JSON.stringify(before[k]) !== JSON.stringify(after[k])),difficulty:{before:'A2',accepted_editorial:'B2',observed_selected_source_labels:{oxford:'C1',collins:null},observed_lesson_level:{british_council:'A2',word_level_certification:false},dictionary_level_certification:false,independent_editorial_basis:basis},memberships}],
  sources,
  protected_context:{attendance:{id:'attendance.presence-record.n',json_sha256:jsonHash(data.lexemes.find(e => e.id === 'attendance.presence-record.n'))},expressions:contextExpressions.map(e=>({id:e.id,entry:e,json_sha256:jsonHash(e),decision:'preserve_exact_no_new_scored_binding_or_expression_approval'})),all_expression_registry_sha256:jsonHash(data.expressions),all_courses_sha256:jsonHash(data.courses),all_themes_sha256:jsonHash(data.themes),all_other_lexemes_sha256:jsonHash(data.lexemes.filter(e=>e.id!==before.id)),previous_sources_sha256:jsonHash(data.sources)},
  historical_boundary:{prior_hold_remains_immutable:true,previous_A2_candidate_accepted:false,excluded_first10_source_ids:['foundation01-language-first10-oxford-supervisor','foundation01-language-first10-oxford-supervise','foundation01-language-first10-collins-supervisor'],attendance_hold_preserved:true},
  lineage:{validation:{path:baselinePath,raw_sha256:hash(read(baselinePath)),registry_sha256:baseline.registry_after_sha256}},
  delivery_scope:{lexeme_file:'data/professional/lexemes/foundation-module01.json',sources_file:'data/professional/sources.json',provenance_file:'data/professional/provenance/foundation-module01-supervisor-language-2026-10-16.json',review_directory:'docs/content-review/foundation-module01-supervisor-language-2026-10-16',production_runtime_changed:false,module_acceptance:false}
};
const candidateData = structuredClone(data); candidateData.lexemes[candidateData.lexemes.findIndex(e=>e.id===before.id)] = after; candidateData.sources.push(...sources);
const audit = auditProfessionalContent({data:candidateData});
assert.equal(audit.errors.length,0); assert.equal(audit.summary.reviewed_lexemes,111); assert.equal(audit.summary.ready_modules,0);
record.candidate_audit = {summary:audit.summary,errors:audit.errors.length,warnings:audit.warnings.length};
write('accepted-language.json',record);
write('binding.json',{schema:1,baseline_path:baselinePath,baseline_raw_sha256:hash(read(baselinePath)),registry_sha256:jsonHash(data),inputs:baseline.after_input_sha256,accepted_language_raw_sha256:hash(fs.readFileSync(path.join(__dirname,'accepted-language.json')))});
console.log(JSON.stringify({candidate:record.patches[0].after_sha256,record:hash(fs.readFileSync(path.join(__dirname,'accepted-language.json'))),memberships:memberships.length,context_expressions:contextExpressions.length,focus_ids:focus.map(e=>e.id),audit:record.candidate_audit}));
