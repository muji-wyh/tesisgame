'use strict';
const assert=require('node:assert/strict');
const provenance='data/professional/provenance/foundation-module02-language-first10-2026-10-16.json';
const helper=String.raw`function beforeFoundation02FirstLanguage(entry) {
  const patch = foundation02FirstLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  // Exact earlier snapshots remain valid; arbitrary partial or later edits do not.
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later module02 first-ten language and metadata delta');
  return structuredClone(patch.before);
}`;
const mainTests=String.raw`

test('Foundation module02 first ten install exact accepted candidates with bounded integration metadata', () => {
  const r=foundation02FirstLanguageRecord, hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(r.patches.length,10); assert.equal(r.sources.length,20);
  assert.equal(r.root_acceptance.raw_sha256,'ef532122536c440871f4ea81eef48252dd0fa156e011758264520dac318d9db6');
  const acceptance=JSON.parse(fs.readFileSync(path.join(rootDir,r.root_acceptance.path),'utf8'));
  const protect=entry=>{const value=structuredClone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete value[key];for(const key of ['language','status','reviewer','reviewed_at'])delete value.review[key];return value;};
  let memberships=0,addedReferences=0;
  for(const p of r.patches){
    const entry=source.lexemes.find(e=>e.id===p.id),record=JSON.parse(fs.readFileSync(path.join(rootDir,p.candidate_artifact),'utf8'));
    const candidate=(record.proposals?.find(x=>x.id===p.id)||record.proposal).candidate_entry;
    const decision=acceptance.accepted_candidates.find(x=>x.id===p.id);
    assert.equal(hash(candidate),p.reviewed_candidate_entry_json_sha256);assert.equal(hash(candidate),decision.candidate_entry_json_sha256);
    assert.deepEqual(entry,p.after);assert.equal(hash(p.before),p.before_sha256);assert.equal(hash(entry),p.after_sha256);
    assert.deepEqual(protect(entry),protect(p.before));assert.equal(hash(protect(entry)),p.protected_fields_sha256);
    for(const field of Object.keys(candidate).filter(f=>!['review','references','editorial_notes'].includes(f)))assert.deepEqual(entry[field],candidate[field]);
    assert.deepEqual(entry.review,{...p.before.review,language:'reviewed',status:'reviewed',reviewer:r.reviewer,reviewed_at:'2026-10-16'});
    assert.deepEqual(entry.references.slice(0,p.before.references.length),p.before.references);
    const additions=entry.references.slice(p.before.references.length);assert.equal(additions.length,2);addedReferences+=additions.length;
    assert.deepEqual(additions.map(x=>x.source_id),p.source_record_ids);
    for(const ref of additions){assert.equal(ref.status,'verified');assert.match(ref.scope,/No human, subject-matter, morphology, media, domain, expression or release approval is claimed/);}
    assert.equal(p.integration_metadata_delta.author_editorial_notes_sha256,hash(candidate.editorial_notes));assert.equal(p.integration_metadata_delta.integrated_editorial_notes_sha256,hash(entry.editorial_notes));
    assert.deepEqual(p.integration_metadata_delta.review_after,entry.review);assert.deepEqual(p.integration_metadata_delta.review_before,p.before.review);
    assert.doesNotMatch(entry.editorial_notes,/independent acceptance remains pending|Meaning, difficulty, imagery, and morphological classification remain editorial drafts/);
    const current=source.courses.flatMap(c=>c.modules.flatMap(m=>{const index=m.lexeme_ids.indexOf(p.id);return index<0?[]:[{lexeme_id:p.id,course_id:c.id,module_id:m.id,index}];}));
    assert.deepEqual(current,p.memberships);memberships+=current.length;
    for(const k of ['morphology','media','accepted_forms','regions','pos','id','text','display_text'])assert.deepEqual(entry[k],p.before[k]);
  }
  assert.equal(memberships,200);assert.equal(addedReferences,20);
  for(const expected of r.sources){assert.deepEqual(source.sources.find(s=>s.id===expected.id),expected);assert.equal(expected.assets_acquired,false);assert.equal(expected.asset_license,null);}
  for(const artifact of r.evidence_artifacts)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,artifact.path))).digest('hex'),artifact.raw_sha256,artifact.path);
});

test('Foundation module02 keeps corrected confirm levels, editorial placements and sense limits exact', () => {
  const r=foundation02FirstLanguageRecord,byText=text=>r.patches.find(p=>p.after.text===text);
  const expected={request:['B1',{oxford:null,collins:'B1+'}],instruction:['A2',{oxford:null,collins:null}],clarification:['B1',{oxford:null,collins:null}],question:['A2',{oxford:null,collins:'A1'}],answer:['A2',{oxford:null,collins:'A1'}],repeat:['A2',{oxford:null,collins:'A2'}],explain:['A2',{oxford:null,collins:'A2'}],confirm:['B2',{oxford:'B2',collins:'B1+'}],check:['A2',{oxford:null,collins:'A2'}],follow:['A2',{oxford:'A2',collins:'B1'}]};
  for(const [text,[level,labels]]of Object.entries(expected)){const p=byText(text);assert.equal(p.after.difficulty,level);assert.deepEqual(p.difficulty.observed_selected_source_labels,labels);assert.equal(p.difficulty.dictionary_level_certification,false);for(const[publisher,value]of Object.entries(labels))assert.equal(r.source_observations.find(s=>s.id==='foundation02-language-first10-'+publisher+'-'+text).observed_selected_sense_level,value);}
  assert.equal(byText('confirm').reviewed_candidate_entry_json_sha256,'72bbbbec8f9abc92e5f931f4b0491a05866ad8937f807fb8c89ef06f806a92b3');
  assert.equal(r.rejected_confirm_candidate.candidate_entry_json_sha256,'e367633854ed63585c94e7cc11c1d4c9fcff7ef864f27d7bc3dda185ca107bb3');
  assert.equal(byText('confirm').after.definition,'To state that an arrangement, such as an appointment, is definite.');assert.equal(byText('confirm').after.example,'Please confirm our appointment for Tuesday.');
  const oxford=r.source_observations.find(s=>s.id==='foundation02-language-first10-oxford-confirm');assert.match(oxford.section,/line164/);assert.equal(oxford.other_sense_labels_not_applied.truth_or_evidence_topic,'B1');
  assert.equal(byText('instruction').after.example,'Please read each instruction before starting.');assert.equal(byText('answer').after.definition,'Something someone says or writes in response to a question.');
  assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('definition')).map(p=>p.after.text),['request','instruction','answer','confirm']);
  assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('example')).map(p=>p.after.text),['instruction','confirm']);assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('difficulty')).map(p=>p.after.text),['request','confirm']);
});

test('Foundation module02 preserves every context hold, membership and separate release gate', () => {
  const r=foundation02FirstLanguageRecord,c=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(c.expressions.length,523);assert.equal(c.related_entries.length,64);assert.equal(c.modules.length,20);assert.equal(c.expression_hold_ids.length,5);assert.equal(c.prior_expression_hold_ids.length,12);
  assert.ok(c.expression_hold_ids.includes('expr.foundation.module02.02'));
  for(const row of c.expressions)assert.equal(hash(source.expressions.find(e=>e.id===row.id)),row.json_sha256,row.id);
  for(const row of c.related_entries)assert.equal(hash(source.lexemes.find(e=>e.id===row.id)),row.json_sha256,row.id);
  for(const row of c.modules)assert.equal(hash(source.courses.find(e=>e.id===row.course_id).modules.find(m=>m.id===row.module_id)),row.json_sha256);
  for(const row of c.prior_expression_holds)assert.equal(hash(source.expressions.find(e=>e.id===row.id)),row.expression_json_sha256);
  for(const id of [...c.expression_hold_ids,...c.prior_expression_hold_ids])assert.equal(source.expressions.find(e=>e.id===id).review.language,'pending');
  for(const id of ['expr.foundation.module02.09','expr.foundation.module02.10'])assert.equal(source.expressions.find(e=>e.id===id).review.domain,'pending');
  for(const p of r.patches){assert.equal(p.after.morphology.review.status,'pending');assert.equal(p.after.media.image.status,'pending');assert.equal(p.after.media.audio.status,'pending');}
  assert.equal(source.lexemes.find(e=>e.id==='attendance.presence-record.n').review.language,'pending');
  assert.deepEqual(source.lexemes.find(e=>e.id==='supervisor.work-overseer.n'),supervisorLanguageRecord.patches[0].after);
  const selected=new Set(r.patches.map(p=>p.id));assert.equal(hash(source.lexemes.filter(e=>!selected.has(e.id))),r.lineage.other_lexemes_json_sha256);
  assert.equal(hash(source.expressions),r.lineage.expressions_json_sha256);assert.equal(hash(source.courses),r.lineage.courses_json_sha256);assert.equal(hash(source.themes),r.lineage.themes_json_sha256);
  assert.equal(auditProfessionalContent({data:source}).summary.ready_modules,0);
});

test('Module02 chronological reversal rejects every unrecognized field drift before older Foundation history', () => {
  for(const p of foundation02FirstLanguageRecord.patches){
    for(const state of [p.before,p.after]){
      for(const reverse of [beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage])assert.deepEqual(reverse(state),p.before);
      for(const change of [e=>{e.definition+=' Unexpected.';},e=>{e.example+=' Unexpected.';},e=>{e.difficulty='C2';},e=>{e.review.reviewer='unexpected';},e=>{e.review.domain='pending';},e=>{e.references[0].scope+=' Unexpected.';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.editorial_notes+=' Unexpected.';},e=>{e.extra=true;}]){
        const changed=structuredClone(state);change(changed);assert.throws(()=>beforeFoundation02FirstLanguage(changed));assert.throws(()=>beforeSupervisorLanguage(changed));
      }
    }
    const returned=beforeFoundation02FirstLanguage(p.after);returned.definition='mutated clone';assert.notEqual(returned.definition,p.before.definition);
  }
});

test('Module02 language delivery requires the actual composite baseline and committed guarded journal', () => {
  const r=foundation02FirstLanguageRecord,raw=relative=>fs.readFileSync(path.join(rootDir,relative)),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(r.status,'integrated_language_outputs_require_committed_journal');assert.equal(r.baseline_bound,true);
  assert.equal(hash(raw(r.lineage.validation.path)),r.lineage.validation.raw_sha256);const validation=JSON.parse(raw(r.lineage.validation.path));assert.equal(validation.ok,true);
  assert.equal(hash(raw(r.lineage.binding.path)),r.lineage.binding.raw_sha256);const binding=JSON.parse(raw(r.lineage.binding.path));assert.equal(binding.registry_before_sha256,r.lineage.registry_before_sha256);assert.equal(binding.registry_after_sha256,r.lineage.registry_after_sha256);
  const composite=binding.composite_baseline;assert.equal(composite.ok,true);assert.equal(composite.full_combined_validation_of_current_state,false);assert.equal(composite.historical_full_validation.registry_sha256,validation.registry_after_sha256);assert.equal(composite.current_registry_sha256,r.lineage.registry_before_sha256);assert.deepEqual(composite.current_input_sha256,binding.baseline_inputs);assert.equal(composite.deltas.length,7);for(const item of composite.evidence)assert.equal(hash(raw(item.path)),item.raw_sha256,item.path);
  const states=fs.readdirSync(path.join(rootDir,r.integration_guards.transaction_path,'states')).filter(n=>/^\d+-.*\.json$/.test(n)).sort();assert.ok(states.length>0);const committed=JSON.parse(raw(r.integration_guards.transaction_path+'/states/'+states.at(-1)));assert.equal(committed.status,'committed');
  for(const item of r.retained_files)assert.equal(hash(raw(item.path)),item.raw_sha256,item.path);
});
`;
const morphologyTests=String.raw`

test('Module02 language reversal preserves exact pending morphology and rejects identity or graph drift', () => {
  for(const p of foundation02FirstLanguageRecord.patches){
    const entry=data.lexemes.find(e=>e.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.equal(entry.morphology.review.status,'pending');
    for(const state of [p.before,p.after]){
      assert.deepEqual(beforeFoundationLanguage(state),p.before);
      for(const change of [e=>{e.morphology.review.status='reviewed';},e=>{e.morphology.parts[0].canonical_id+='unexpected';},e=>{e.morphology.text+='unexpected';},e=>{e.media.audio.voice='unexpected';},e=>{e.accepted_forms.push('unexpected');},e=>{e.id+='unexpected';}]){
        const altered=structuredClone(state);change(altered);if(altered.id===p.id)assert.throws(()=>beforeFoundation02FirstLanguage(altered));else assert.notDeepEqual(beforeFoundationLanguage(altered),p.before);
      }
    }
  }
});
`;
function transform(file,input){
 let text=input.toString('utf8');const edits=[];
 const replace=(before,after,count=1)=>{assert.equal(text.split(before).length-1,count,file+': exact anchor '+before.slice(0,70));text=text.split(before).join(after);edits.push({before,after,count});};
 const root=file.includes('professional-content')?'rootDir':'root';
 replace('function beforeSupervisorLanguage(entry) {',`const foundation02FirstLanguageRecord = JSON.parse(fs.readFileSync(path.join(${root}, '${provenance}'), 'utf8'));
${helper}
function beforeSupervisorLanguage(entry) {
  entry = beforeFoundation02FirstLanguage(entry);`);
 if(root==='rootDir'){
  replace('...supervisorLanguageRecord.patches].map(item => item.id)','...supervisorLanguageRecord.patches, ...foundation02FirstLanguageRecord.patches].map(item => item.id)');
  replace('assert.equal(result.summary.reviewed_lexemes, 111);','assert.equal(result.summary.reviewed_lexemes, 121);');
  text+=mainTests;
 }else text+=morphologyTests;
 return {bytes:Buffer.from(text),edits,appended_tests:root==='rootDir'?5:1};
}
module.exports={transform,helper};
