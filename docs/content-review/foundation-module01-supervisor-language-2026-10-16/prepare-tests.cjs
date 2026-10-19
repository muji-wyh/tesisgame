'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../..');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const binding = JSON.parse(fs.readFileSync(path.join(__dirname, 'binding.json')));
const provenance = 'data/professional/provenance/foundation-module01-supervisor-language-2026-10-16.json';
const patchList = [];
for (const file of ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs']) {
  const original = fs.readFileSync(path.join(root,file));
  assert.equal(hash(original), binding.inputs[file]);
  let changed = original.toString('utf8');
  const edits = [];
  function replace(before, after, count=1) {
    const occurrences = changed.split(before).length-1; assert.equal(occurrences,count,file+': '+before.slice(0,100));
    changed = changed.split(before).join(after); edits.push({before,after,count});
  }
  const rootName = file.includes('content') ? 'rootDir' : 'root';
  const marker = "function beforeFoundationFifthLanguage(entry) {";
  const helper = `const supervisorLanguageRecord = JSON.parse(fs.readFileSync(path.join(${rootName}, '${provenance}'), 'utf8'));
function beforeSupervisorLanguage(entry) {
  const patch = supervisorLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  // Historical snapshots can already contain the exact held entry. Both states remain fully checked.
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later independently reviewed supervisor language delta');
  return structuredClone(patch.before);
}
function beforeFoundationFifthLanguage(entry) {
  entry = beforeSupervisorLanguage(entry);`;
  replace(marker,helper);
  if (file.includes('content')) {
    replace('...foundationFifthLanguageRecord.patches].map(item => item.id)', '...foundationFifthLanguageRecord.patches, ...supervisorLanguageRecord.patches].map(item => item.id)');
    replace('assert.equal(result.summary.reviewed_lexemes, 110);','assert.equal(result.summary.reviewed_lexemes, 111);');
    replace("test('Foundation supervisor hold and editorial difficulty distinctions remain explicit'", "test('Foundation historical supervisor hold and editorial difficulty distinctions remain explicit'");
    replace('assert.deepEqual(source.lexemes.find(item=>item.id===held.id),held.value);','assert.deepEqual(beforeSupervisorLanguage(source.lexemes.find(item=>item.id===held.id)),held.value);');
    replace('assert.deepEqual(source.lexemes.find(e=>e.id===held.id),held.value);','assert.deepEqual(beforeSupervisorLanguage(source.lexemes.find(e=>e.id===held.id)),held.value);');
    replace('assert.deepEqual(source.lexemes.find(e => e.id === held.id), held.value);','assert.deepEqual(beforeSupervisorLanguage(source.lexemes.find(e => e.id === held.id)), held.value);');
    replace('assert.deepEqual(source.lexemes.find(e => e.id === row.entry.id), row.entry); assert.equal(hash(row.entry), row.json_sha256);','assert.deepEqual(beforeSupervisorLanguage(source.lexemes.find(e => e.id === row.entry.id)), row.entry); assert.equal(hash(row.entry), row.json_sha256);');
    changed += `
test('Supervisor reconsideration accepts exact ordinary language while retaining C1 and graded-context limits', () => {
  const r = supervisorLanguageRecord, p = r.patches[0];
  const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(r.patches.length, 1); assert.equal(r.sources.length, 3);
  assert.equal(r.independent_review.accepted, true); assert.equal(r.independent_review.human_or_specialist_approval, false);
  assert.equal(p.id, 'supervisor.work-overseer.n'); assert.equal(hash(p.before), p.before_sha256); assert.equal(hash(p.after), p.after_sha256);
  assert.deepEqual(source.lexemes.find(e => e.id === p.id), p.after);
  assert.deepEqual(p.changed_fields, ['definition','difficulty','review','references','editorial_notes']);
  assert.equal(p.after.example, p.before.example); assert.equal(p.after.difficulty,'B2');
  assert.equal(p.difficulty.observed_selected_source_labels.oxford,'C1'); assert.equal(p.difficulty.observed_selected_source_labels.collins,null);
  assert.deepEqual(p.difficulty.observed_lesson_level,{british_council:'A2',word_level_certification:false});
  assert.equal(p.difficulty.dictionary_level_certification,false); assert.match(p.difficulty.independent_editorial_basis,/not an automatic clamp/);
  for (const key of ['id','text','display_text','pos','accepted_forms','regions','practice_modes','media','morphology']) assert.deepEqual(p.after[key],p.before[key]);
  assert.equal(p.after.review.language,'reviewed'); assert.equal(p.after.review.status,'reviewed'); assert.equal(p.after.review.domain,'not_required');
  assert.match(p.after.review.reviewer,/independent AI language review; not human or subject-matter approval/);
  assert.equal(p.after.morphology.review.status,'pending'); assert.equal(p.after.media.image.status,'pending'); assert.equal(p.after.media.audio.status,'pending');
  assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);
  assert.deepEqual(p.after.references.slice(p.before.references.length).map(s=>s.source_id),r.sources.map(s=>s.id));
  assert.ok(p.after.references.slice(p.before.references.length).every(s=>s.status==='verified'));
  for (const s of r.sources) assert.deepEqual(source.sources.find(v=>v.id===s.id),s);
  for (const id of r.historical_boundary.excluded_first10_source_ids) assert.equal(source.sources.some(s=>s.id===id),false);
  assert.equal(r.author_research.acceptance,false); assert.equal(r.historical_boundary.previous_A2_candidate_accepted,false);
});

test('Supervisor language reversal accepts only exact current or historical full entries', () => {
  const p = supervisorLanguageRecord.patches[0];
  for (const state of [p.before,p.after]) {
    assert.deepEqual(beforeSupervisorLanguage(state),p.before); assert.deepEqual(beforeFoundationFifthLanguage(state),p.before);
    for (const change of [e=>{e.definition+=' Unexpected.';},e=>{e.example+=' Unexpected.';},e=>{e.difficulty='B1';},e=>{e.review.reviewer='unexpected';},e=>{e.references[0].scope+=' Unexpected.';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.extra=true;}]) {
      const altered=structuredClone(state); change(altered); assert.throws(()=>beforeSupervisorLanguage(altered));
    }
  }
  const returned=beforeSupervisorLanguage(p.after); returned.definition='mutated clone'; assert.notEqual(returned.definition,p.before.definition);
  for (const held of foundationFifthLanguageRecord.held) assert.deepEqual(beforeFoundationFifthLanguage(held.value),held.value);
});

test('Supervisor language preserves attendance, context expressions, twenty memberships and readiness', () => {
  const r=supervisorLanguageRecord, p=r.patches[0], hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(hash(source.lexemes.find(e=>e.id===r.protected_context.attendance.id)),r.protected_context.attendance.json_sha256);
  assert.equal(r.protected_context.expressions.length,21);
  for(const row of r.protected_context.expressions) { assert.equal(hash(row.entry),row.json_sha256); assert.deepEqual(source.expressions.find(e=>e.id===row.id),row.entry); assert.equal(row.decision,'preserve_exact_no_new_scored_binding_or_expression_approval'); }
  const memberships=source.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(p.id)).map(m=>({course_id:c.id,module_id:m.id})));
  assert.deepEqual(memberships,p.memberships); assert.equal(memberships.length,20); assert.ok(memberships.every(m=>m.module_id==='module01'));
  assert.equal(hash(source.expressions),r.protected_context.all_expression_registry_sha256); assert.equal(hash(source.courses),r.protected_context.all_courses_sha256); assert.equal(hash(source.themes),r.protected_context.all_themes_sha256);
  assert.equal(r.lineage.validation.path,'build/professional-english/continuation-validation-r30.json');
  const baseline=fs.readFileSync(path.join(rootDir,r.lineage.validation.path)); assert.equal(crypto.createHash('sha256').update(baseline).digest('hex'),r.lineage.validation.raw_sha256); assert.equal(JSON.parse(baseline).ok,true);
  assert.equal(auditProfessionalContent({data:source}).summary.ready_modules,0);
});
`;
  } else {
    changed += `
test('Supervisor language reversal retains exact pending morphology and rejects graph or identity drift', () => {
  const p=supervisorLanguageRecord.patches[0], entry=data.lexemes.find(e=>e.id===p.id);
  assert.deepEqual(entry,p.after); assert.deepEqual(entry.morphology,p.before.morphology); assert.equal(entry.morphology.review.status,'pending');
  assert.deepEqual(beforeFoundationLanguage(entry),p.before); assert.deepEqual(beforeFoundationLanguage(p.before),p.before);
  for (const state of [p.before,p.after]) for (const change of [e=>{e.morphology.review.status='reviewed';},e=>{e.morphology.parts[0].canonical_id+='unexpected';},e=>{e.media.audio.voice='unexpected';},e=>{e.accepted_forms.push('unexpected');}]) {
    const altered=structuredClone(state); change(altered); assert.throws(()=>beforeSupervisorLanguage(altered));
  }
});
`;
  }
  const filename=path.basename(file);
  fs.writeFileSync(path.join(__dirname,filename+'.before'),original,{flag:'wx'});
  fs.writeFileSync(path.join(__dirname,filename+'.after'),changed,{flag:'wx'});
  patchList.push({file,before_sha256:hash(original),after_sha256:hash(changed),edits,appended_tests:file.includes('content')?3:1});
}
fs.writeFileSync(path.join(__dirname,'test-patches.json'),JSON.stringify({schema:1,patches:patchList},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(patchList.map(({file,before_sha256,after_sha256,appended_tests})=>({file,before_sha256,after_sha256,appended_tests}))));
