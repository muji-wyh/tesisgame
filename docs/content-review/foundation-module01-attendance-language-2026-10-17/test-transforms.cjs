'use strict';
const {assert,C,byteHash}=require('./delivery-lib.cjs');
const helper=String.raw`function beforeAttendanceLanguage(entry) {
  const patch = attendanceLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  // Only exact historical or later accepted entries may cross this chronology boundary.
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later independently accepted attendance language and metadata delta');
  return structuredClone(patch.before);
}`;
const contentTests=String.raw`

test('Attendance delivery installs exact independently accepted presence content and bounded metadata', () => {
  const r=attendanceLanguageRecord,p=r.patches[0],hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(r.patches.length,1);assert.equal(r.sources.length,6);assert.equal(r.new_language_approval,false);
  assert.equal(r.independent_review.accepted,true);assert.equal(r.independent_review.human_or_specialist_approval,false);
  assert.equal(r.independent_review.raw_sha256,'979297a9ea44542fff7ec7082346edae11fa66587787190f2a81730bc77a35b4');
  assert.equal(p.id,'attendance.presence-record.n');assert.equal(hash(p.before),p.before_sha256);assert.equal(hash(p.after),p.after_sha256);
  assert.equal(hash(p.accepted_content),p.accepted_content_json_sha256);assert.equal(p.accepted_content_json_sha256,'b7c42d9ce09b8ad3c2a322cd7f6272eb1432a6ef935fc1abf83c0fea333813d1');
  assert.deepEqual(source.lexemes.find(e=>e.id===p.id),p.after);assert.deepEqual(p.changed_fields,['difficulty','review','references','editorial_notes']);
  for(const key of Object.keys(p.accepted_content).filter(k=>!['review','references','editorial_notes'].includes(k)))assert.deepEqual(p.after[key],p.accepted_content[key],key);
  const protect=entry=>{const x=structuredClone(entry);for(const k of ['difficulty','references','editorial_notes'])delete x[k];for(const k of ['language','status','reviewer','reviewed_at'])delete x.review[k];return x;};
  assert.deepEqual(protect(p.after),protect(p.before));assert.equal(hash(protect(p.after)),p.protected_fields_sha256);
  assert.equal(p.after.definition,'Being present at work, a meeting, or another scheduled activity.');assert.equal(p.after.example,'The trainer recorded attendance at the session.');assert.equal(p.after.difficulty,'B2');
  assert.deepEqual(p.after.review,{...p.before.review,status:'reviewed',language:'reviewed',reviewer:r.independent_review.reviewer,reviewed_at:'2026-10-16'});
  assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);
  assert.deepEqual(p.after.references.slice(p.before.references.length).map(x=>x.source_id),r.sources.map(x=>x.id));
  for(const s of r.sources){assert.deepEqual(source.sources.find(x=>x.id===s.id),s);assert.equal(s.consulted_on,'2026-10-16');assert.equal(s.assets_acquired,false);assert.equal(s.asset_license,null);}
  for(const ref of p.after.references.slice(p.before.references.length)){assert.equal(ref.status,'verified');assert.match(ref.scope,/No human, subject-matter, morphology, media, domain, expression or release approval is claimed/);}
  assert.equal(p.after.morphology.review.status,'pending');assert.equal(p.after.media.image.status,'pending');assert.equal(p.after.media.audio.status,'pending');assert.equal(p.after.review.domain,'not_required');
});

test('Attendance editorial B2 retains Oxford C1 and distinct headword and whole-lesson evidence', () => {
  const r=attendanceLanguageRecord,p=r.patches[0],d=p.difficulty;
  assert.deepEqual(d.source_observations,{cefrj_v1_5_headword_pos:'B2',oxford_selected_presence_topics:'C1',collins_selected_presence_level:null,english_flows_whole_lesson:'B1 / B2'});
  assert.equal(d.dictionary_or_unanimous_level_certification,false);assert.equal(d.active_mastery_certification,false);
  assert.match(d.independent_editorial_basis,/headword\/POS/);assert.match(d.independent_editorial_basis,/Oxford.*C1/);assert.match(d.independent_editorial_basis,/not an automatic clamp/);
  const checks=r.independent_review.source_checks;assert.equal(checks.length,6);assert.equal(checks[0].selected_row,'attendance,noun,B2,,,');assert.equal(checks[0].raw_sha256,'b0dd3c635f1c9a4fdf1490c7e5b7c48e8bbe55b652ad0c9860a95f98e10ae498');
  assert.match(checks[0].observation,/no sense definition/);assert.match(checks[1].observation,/different CC BY-SA/);assert.match(checks[2].limits,/1.6 workbook was not acquired/);assert.equal(checks[3].observed_selected_level,'C1');assert.equal(checks[4].observed_selected_level,null);assert.equal(checks[5].observed_level,'B1 / B2');
  assert.equal(r.historical_boundary.previous_A2_candidate_accepted,false);assert.equal(r.historical_boundary.prior_hold_artifacts_immutable,true);
  for(const id of r.historical_boundary.excluded_third10_source_ids)assert.equal(source.sources.some(s=>s.id===id),false);
  assert.equal(r.author_research.accepted,false);assert.match(p.after.editorial_notes,/record-object or headcount/);
});

test('Attendance chronology rejects unrecognized field drift and preserves historical hold snapshots', () => {
  const p=attendanceLanguageRecord.patches[0];
  const reversals=[beforeAttendanceLanguage,beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage];
  for(const state of [p.before,p.after]){
    for(const reverse of reversals)assert.deepEqual(reverse(state),p.before);
    for(const change of [e=>{e.definition+=' Unexpected.';},e=>{e.example+=' Unexpected.';},e=>{e.difficulty='B1';},e=>{e.review.reviewer='unexpected';},e=>{e.review.domain='reviewed';},e=>{e.references[0].scope+=' Unexpected.';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.practice_modes.push('phrase');},e=>{e.extra=true;}]){
      const altered=structuredClone(state);change(altered);for(const reverse of reversals)assert.throws(()=>reverse(altered));
    }
  }
  const returned=beforeAttendanceLanguage(p.after);returned.definition='mutated clone';assert.notEqual(returned.definition,p.before.definition);
  assert.deepEqual(beforeAttendanceLanguage(source.lexemes.find(e=>e.id===p.id)),foundationThirdLanguageRecord.held[0].value);
  for(const held of foundationFifthLanguageRecord.held)assert.deepEqual(beforeFoundationFifthLanguage(held.value),held.value);
});

test('Attendance delivery preserves every other entry, expression, source prefix, membership and readiness gate', () => {
  const r=attendanceLanguageRecord,p=r.patches[0],c=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(hash(source.lexemes.filter(e=>e.id!==p.id)),c.all_other_lexemes_json_sha256);
  assert.equal(hash(source.expressions),c.all_expressions_json_sha256);assert.equal(hash(source.courses),c.all_courses_json_sha256);assert.equal(hash(source.themes),c.all_themes_json_sha256);
  assert.equal(hash(source.sources.slice(0,-r.sources.length)),c.previous_sources_json_sha256);
  assert.equal(c.expressions.length,2);for(const row of c.expressions){assert.equal(hash(source.expressions.find(e=>e.id===row.id)),row.entry_json_sha256);assert.equal(row.decision,'preserve_exact_no_expression_acceptance_or_new_binding');}
  const memberships=source.courses.flatMap(course=>course.modules.filter(m=>m.lexeme_ids.includes(p.id)).map(m=>({course_id:course.id,module_id:m.id})));
  assert.deepEqual(memberships,p.memberships);assert.equal(memberships.length,20);assert.ok(memberships.every(m=>m.module_id==='module01'));
  assert.equal(source.lexemes.filter(e=>source.lexemeOrigins[e.id]==='res://data/professional/lexemes/foundation-module01.json'&&e.review.language==='reviewed').length,50);
  const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,122);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
});

test('Attendance delivery requires the exact successful baseline and committed guarded journal', () => {
  const r=attendanceLanguageRecord,raw=file=>fs.readFileSync(path.join(rootDir,file)),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(r.status,'integrated_language_outputs_require_committed_journal');assert.equal(r.baseline_bound,true);
  assert.equal(sha(raw(r.lineage.validation.path)),r.lineage.validation.raw_sha256);const baseline=JSON.parse(raw(r.lineage.validation.path));assert.equal(baseline.ok,true);assert.equal(baseline.registry_after_sha256,r.lineage.registry_before_sha256);
  assert.equal(sha(raw(r.lineage.binding.path)),r.lineage.binding.raw_sha256);const b=JSON.parse(raw(r.lineage.binding.path));assert.equal(b.registry_before_sha256,r.lineage.registry_before_sha256);assert.equal(b.registry_after_sha256,r.lineage.registry_after_sha256);
  const states=fs.readdirSync(path.join(rootDir,r.integration_guards.transaction_path,'states')).filter(n=>/^\d+-.*\.json$/.test(n)).sort();assert.ok(states.length>0);assert.equal(JSON.parse(raw(r.integration_guards.transaction_path+'/states/'+states.at(-1))).status,'committed');
  for(const item of r.retained_files)assert.equal(sha(raw(item.path)),item.raw_sha256,item.path);
});
`;
const morphologyTests=String.raw`

test('Attendance language reversal preserves pending morphology and rejects graph or identity drift', () => {
  const p=attendanceLanguageRecord.patches[0],entry=data.lexemes.find(e=>e.id===p.id);
  assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.equal(entry.morphology.review.status,'pending');
  for(const state of [p.before,p.after]){
    assert.deepEqual(beforeFoundationLanguage(state),p.before);
    for(const change of [e=>{e.morphology.review.status='reviewed';},e=>{e.morphology.parts[0].canonical_id+='unexpected';},e=>{e.morphology.text+='unexpected';},e=>{e.media.audio.voice='unexpected';},e=>{e.id+='unexpected';}]){
      const altered=structuredClone(state);change(altered);if(altered.id===p.id)assert.throws(()=>beforeFoundationLanguage(altered));else assert.notDeepEqual(beforeFoundationLanguage(altered),p.before);
    }
  }
});
`;
function transform(file,before){
  assert(C.tests.includes(file));let text=before.toString('utf8');const edits=[];
  function replace(old,next,count=1){assert.equal(text.split(old).length-1,count,file+': exact anchor '+old);text=text.split(old).join(next);edits.push({before:old,after:next,count});}
  const rootName=file.includes('professional-content')?'rootDir':'root';
  replace('function beforeFoundation02FirstLanguage(entry) {',`const attendanceLanguageRecord = JSON.parse(fs.readFileSync(path.join(${rootName}, '${C.provenance}'), 'utf8'));\n${helper}\nfunction beforeFoundation02FirstLanguage(entry) {\n  entry = beforeAttendanceLanguage(entry);`);
  if(rootName==='rootDir'){
    replace('...foundation02FirstLanguageRecord.patches].map(item => item.id)','...foundation02FirstLanguageRecord.patches, ...attendanceLanguageRecord.patches].map(item => item.id)');
    replace('assert.equal(result.summary.reviewed_lexemes, 121);','assert.equal(result.summary.reviewed_lexemes, 122);');
    replace("test('Foundation third ten retain the entire attendance hold and literal source difficulty evidence'","test('Foundation third ten retain the historical attendance hold and literal source difficulty evidence'");
    replace('assert.deepEqual(source.lexemes.find(entry=>entry.id===held.id),held.value);','assert.deepEqual(beforeAttendanceLanguage(source.lexemes.find(entry=>entry.id===held.id)),held.value);');
    replace('assert.equal(hash(source.lexemes.find(e=>e.id===r.protected_context.attendance.id)),r.protected_context.attendance.json_sha256);','assert.equal(hash(beforeAttendanceLanguage(source.lexemes.find(e=>e.id===r.protected_context.attendance.id))),r.protected_context.attendance.json_sha256);');
    replace("assert.equal(source.lexemes.find(e=>e.id==='attendance.presence-record.n').review.language,'pending');","assert.equal(beforeAttendanceLanguage(source.lexemes.find(e=>e.id==='attendance.presence-record.n')).review.language,'pending');");
    replace('for(const row of c.related_entries)assert.equal(hash(source.lexemes.find(e=>e.id===row.id)),row.json_sha256,row.id);','for(const row of c.related_entries)assert.equal(hash(beforeAttendanceLanguage(source.lexemes.find(e=>e.id===row.id))),row.json_sha256,row.id);');
    replace('assert.equal(hash(source.lexemes.filter(e=>!selected.has(e.id))),r.lineage.other_lexemes_json_sha256);','assert.equal(hash(source.lexemes.map(beforeAttendanceLanguage).filter(e=>!selected.has(e.id))),r.lineage.other_lexemes_json_sha256);');
    text+=contentTests;
  }else{
    replace('assert.deepEqual(data.lexemes.find(item=>item.id===attendance.id),attendance.value);','assert.deepEqual(beforeAttendanceLanguage(data.lexemes.find(item=>item.id===attendance.id)),attendance.value);');
    text+=morphologyTests;
  }
  return {bytes:Buffer.from(text),edits,appended_tests:rootName==='rootDir'?5:1,before_sha256:byteHash(before),after_sha256:byteHash(text)};
}
module.exports={transform};
