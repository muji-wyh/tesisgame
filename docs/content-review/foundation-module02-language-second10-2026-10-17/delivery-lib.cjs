'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const api=require(path.join(root,'tools/validate-professional-content.cjs'));
const C=Object.freeze({target:'data/professional/lexemes/foundation-module02.json',sources:'data/professional/sources.json',
  evidence:'docs/content-review/foundation-module02-language-second10-proposals-2026-10-17',
  acceptanceRaw:'2d95fb5e1f08ed79a2b9de27ad2e031e36139385acf0d6d0e3e7a13b1a6f865e',
  provenance:'data/professional/provenance/foundation-module02-language-second10-2026-10-17.json',
  docs:'docs/content-review/foundation-module02-language-second10-2026-10-17',
  transaction:'build/professional-english/transactions/foundation02-second10-language-r02',
  helper:'build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs',
  helperRaw:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
  helperValidation:'build/professional-english/retail-module03-morphology-review/fifth10/serializer-review-r01/validation-attempt-XE9O6l/receipt.json',
  helperValidationRaw:'abd19b9952fe3085ef8cab5b87e430ef442780ed05f3a9a2105f909f968a9bae',
  tests:['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd']});
const relative=file=>path.relative(root,file).replaceAll('\\','/');
const at=file=>{assert.equal(path.isAbsolute(file),false);assert(!file.includes('\\'));const p=path.resolve(root,file);assert.equal(relative(p),file);assert(!file.startsWith('../'));return p;};
const bytes=file=>fs.readFileSync(at(file)),byteHash=value=>crypto.createHash('sha256').update(value).digest('hex'),hash=value=>byteHash(JSON.stringify(value));
const raw=file=>byteHash(bytes(file)),read=file=>JSON.parse(bytes(file)),local=name=>relative(path.join(__dirname,name));
const serialize=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),Buffer.isBuffer(value)?value:serialize(value),{flag:'wx'});
function protect(entry){const v=structuredClone(entry);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete v[k];for(const k of ['status','language','reviewer','reviewed_at'])delete v.review[k];return v;}
function evidence(){
  assert.equal(raw(C.evidence+'/review.json'),C.acceptanceRaw);assert.equal(raw(C.helper),C.helperRaw);assert.equal(raw(C.helperValidation),C.helperValidationRaw);
  const review=read(C.evidence+'/review.json'),inventory=read(C.evidence+'/inventory.json');
  assert.equal(raw(C.evidence+'/inventory.json'),review.reviewed_package.inventory_sha256);
  for(const row of inventory.artifacts)assert.equal(raw(C.evidence+'/'+row.path),row.sha256,row.path);
  for(const row of review.reviewer_evidence)assert.equal(raw(C.evidence+'/'+row.path),row.sha256,row.path);
  assert.equal(review.status,'independent_ai_language_review_complete_pending_future_delivery');assert.equal(review.accepted.length,8);assert.equal(review.held.length,2);
  const ledger=read(C.evidence+'/candidate-ledger.json'),correction=read(C.evidence+'/deliver-correction-r01.json'),context=read(C.evidence+'/context-screen.json'),index=read(C.evidence+'/source-index.json');
  assert.equal(raw(C.evidence+'/candidate-ledger.json'),correction.supersedes_only.artifact_sha256);
  for(const a of review.accepted){const row=ledger.entries.find(x=>x.id===a.id),projection=a.source_artifact==='deliver-correction-r01.json'?correction.content_projection:row.content_projection;
    assert.equal(row.disposition,'proposed');assert.equal(hash(row.before_entry),a.before_entry_json_sha256);assert.equal(hash(projection),a.accepted_content_projection_json_sha256);
    assert.equal(hash(a.accepted_fields),a.accepted_fields_json_sha256);for(const k of ['definition','example','difficulty'])assert.equal(projection[k],a.accepted_fields[k]);
    assert.equal(byteHash(row.proposed_editorial_note_for_future_review),a.proposed_editorial_note_text_sha256);
  }
  for(const held of review.held){const row=ledger.entries.find(x=>x.id===held.id);assert.equal(row.disposition,'held_unchanged');assert.equal(hash(row.before_entry),held.whole_entry_json_sha256);assert.deepEqual(row.before_entry,row.content_projection);}
  assert.equal(context.inherited_expression_holds.length,17);assert.equal(context.focus_expressions.length,6);assert.equal(index.sources.length,20);
  return {review,ledger,correction,context,index,inventory};
}
function proposal(e){
  const limits='No human, subject-matter, morphology, media, domain, whole-expression, module or release approval is claimed.';
  const sources=[],observations=[];
  const patches=e.review.accepted.map(a=>{
    const row=e.ledger.entries.find(x=>x.id===a.id),before=structuredClone(row.before_entry),after=structuredClone(before);
    const deliveryDecision=a.id==='complete.finish.v'?'The exact finishing-work/activity definition and task example have independent AI language acceptance at editorial A2. The two publishers separate form filling, so the former merged-sense claim is not accepted. Collins selected A2 supports placement; Oxford selected A1 metadata remains explicit. The former merged-sense editorial note is retained only in the historical preimage and has been replaced by bounded finishing-only provenance. The existing form-image brief remains live, unchanged, mismatched, pending and unapproved; this scope mismatch prevents any claim of picture readiness.':a.decision;
    const deliveryMediaIssue=a.id==='complete.finish.v'?'':(row.media_issue||'');
    Object.assign(after,a.accepted_fields);after.review={...before.review,status:'reviewed',language:'reviewed',reviewer:e.review.reviewer,reviewed_at:e.review.reviewed_on};
    const refs=a.source_ids.map(id=>{
      const observation=e.index.sources.find(x=>x.id===id);assert(observation);observations.push(structuredClone(observation));
      const selected=id.includes('-oxford-')?{html:a.selected_source_levels.oxford_html,rendered_topic:a.selected_source_levels.oxford_rendered_topic}:{rendered_selected:a.selected_source_levels.collins_rendered};
      const scope='Selected ordinary lexical sense only. '+deliveryDecision+' Literal selected-source observation: '+JSON.stringify(selected)+'. Oxford rendered topic labels and public HTML metadata are separate evidence; unrelated footer levels are excluded. This is editorial placement, not unanimous dictionary or lesson certification. Source consultation is recorded in the independently reviewed original-publisher evidence; no source pages, exercises, datasets, examples or media are imported. '+limits;
      sources.push({id,title:(id.includes('-oxford-')?'Oxford Advanced Learner\'s Dictionary':'Collins COBUILD Dictionary')+': '+row.term+' selected verb sense',publisher:observation.publisher,url:observation.url,status:'consulted',consulted_on:'2026-10-17',scope,asset_license:null,assets_acquired:false});
      return {source_id:id,status:'verified',scope:'Verified only for the exact independently accepted definition, example and editorial difficulty of '+a.id+'. '+scope};
    });
    after.references.push(...refs);
    after.editorial_notes='Shared workplace foundation. The exact selected-sense definition, example and editorial difficulty have scoped independent AI language acceptance. '+deliveryDecision+' '+row.excluded_scope+' '+deliveryMediaIssue+' '+(row.expression_context_issue||'')+' '+limits+' Canonical identity, accepted forms, regions, practice modes, historical reference prefix, morphology, image/audio, domain status, course memberships and all expressions remain unchanged. Only the two new lexical references are verified for this bounded language decision; separate pending gates prevent complete-module readiness.';
    assert.deepEqual(protect(after),protect(before));assert.deepEqual(after.references.slice(0,before.references.length),before.references);
    const changed=Object.keys(before).filter(k=>JSON.stringify(before[k])!==JSON.stringify(after[k]));assert(changed.every(k=>['definition','example','difficulty','review','references','editorial_notes'].includes(k)));
    const acceptedContent=structuredClone(before);Object.assign(acceptedContent,a.accepted_fields);assert.equal(hash(acceptedContent),a.accepted_content_projection_json_sha256);
    return {id:a.id,before,after,before_sha256:hash(before),after_sha256:hash(after),protected_fields_sha256:hash(protect(before)),changed_fields:changed,accepted_content:acceptedContent,accepted_content_json_sha256:hash(acceptedContent),accepted_fields:structuredClone(a.accepted_fields),accepted_fields_json_sha256:a.accepted_fields_json_sha256,decision:a.decision,source_ids:a.source_ids,selected_source_levels:a.selected_source_levels,dictionary_or_lesson_level_certification:false};
  });
  assert.equal(sources.length,16);assert.equal(new Set(sources.map(x=>x.id)).size,16);
  const held=e.review.held.map(h=>({id:h.id,value:structuredClone(e.ledger.entries.find(x=>x.id===h.id).before_entry),whole_entry_json_sha256:h.whole_entry_json_sha256,decision:h.decision,reference_or_note_additions:0,review_gate_changes:0}));
  return {schema:1,status:'accepted_content_with_proposed_delivery_metadata',prepared_by:'Codex attendance_review delivery author',new_language_approval:false,
    independent_review:{path:C.evidence+'/review.json',raw_sha256:C.acceptanceRaw,reviewer:e.review.reviewer,reviewed_on:e.review.reviewed_on,accepted:true,human_or_specialist_approval:false,acceptance_scope:e.review.acceptance_scope},
    accepted_evidence:{directory:C.evidence,inventory_sha256:raw(C.evidence+'/inventory.json'),candidate_sha256:raw(C.evidence+'/candidate-ledger.json'),correction_sha256:raw(C.evidence+'/deliver-correction-r01.json'),context_sha256:raw(C.evidence+'/context-screen.json')},
    patches,held,sources,source_observations:observations,
    excluded_source_ids:e.review.held.flatMap(h=>e.ledger.entries.find(x=>x.id===h.id).source_ids),
    protected_context:{memberships:e.context.selected_memberships,modules:e.context.containing_modules,expressions:e.context.expression_uses,focus_expressions:e.context.focus_expressions,related_entries:e.context.related_entry_boundaries,inherited_expression_holds:e.context.inherited_expression_holds,expression_hold_ids:e.context.inherited_expression_hold_ids,context_boundaries:e.context.context_boundaries,complete_pending_form_image_mismatch:e.context.complete_existing_form_scope_mismatch},
    delivery_scope:{lexeme_file:C.target,sources_file:C.sources,provenance_file:C.provenance,review_directory:C.docs,production_runtime_changed:false,module_acceptance:false}};
}
function verifyScope(data,p){
  for(const patch of p.patches)assert.deepEqual(data.lexemes.find(x=>x.id===patch.id),patch.before);
  for(const held of p.held){assert.deepEqual(data.lexemes.find(x=>x.id===held.id),held.value);assert.equal(hash(held.value),held.whole_entry_json_sha256);}
  for(const m of p.protected_context.memberships){const course=data.courses.find(x=>x.id===m.course_id);assert.equal(course.modules.find(x=>x.id===m.module_id).lexeme_ids[m.index],m.lexeme_id);}
  assert.equal(p.protected_context.memberships.length,200);
  for(const m of p.protected_context.modules)assert.equal(hash(data.courses.find(x=>x.id===m.course_id).modules.find(x=>x.id===m.module_id)),m.module_json_sha256);
  for(const row of p.protected_context.expressions)assert.equal(hash(data.expressions.find(x=>x.id===row.id)),row.expression_json_sha256);
  for(const row of p.protected_context.focus_expressions)assert.deepEqual(data.expressions.find(x=>x.id===row.id),row.before_entry);
  for(const row of p.protected_context.inherited_expression_holds)assert.equal(hash(data.expressions.find(x=>x.id===row.id)),row.before_entry_json_sha256);
  for(const row of p.protected_context.related_entries)assert.equal(hash(data.lexemes.find(x=>x.id===row.id)),row.entry_json_sha256);
  for(const s of p.sources)assert(!data.sources.some(x=>x.id===s.id));for(const id of p.excluded_source_ids)assert(!data.sources.some(x=>x.id===id));
}
function apply(data,p){verifyScope(data,p);const next=structuredClone(data);for(const patch of p.patches)next.lexemes[next.lexemes.findIndex(x=>x.id===patch.id)]=structuredClone(patch.after);next.sources.push(...structuredClone(p.sources));return next;}
function baseline(){
  const config=read(local('baseline-config.json'));for(const row of config.pinned_files)assert.equal(raw(row.path),row.raw_sha256,row.path);
  assert.equal(raw(config.independent_review.path),config.independent_review.raw_sha256);const review=read(config.independent_review.path);assert.equal(review.accepted,true);assert.equal(review.review_kind,'technical_only');assert.equal(review.status,'accepted_independent_composite_baseline_technical_review');assert.equal(review.baseline.path,config.baseline.path);assert.equal(review.baseline.raw_sha256,config.baseline.raw_sha256);assert.deepEqual(review.findings,[]);assert(review.reviewed_files.some(x=>x.path===config.verifier.path&&x.raw_sha256===config.verifier.raw_sha256));
  assert.equal(raw(config.verifier.path),config.verifier.raw_sha256);const verifier=require(at(config.verifier.path));assert.equal(typeof verifier.verifyBaseline,'function');
  const result=verifier.verifyBaseline(config.baseline.path,config.baseline.raw_sha256);assert(result&&typeof result.then!=='function');
  assert.equal(result.baseline.kind,'composite_validation_baseline');assert.equal(result.baseline.ok,true);assert.equal(result.baseline.full_combined_validation_of_current_state,false);
  const data=result.data,inputs=result.inputs;assert.equal(hash(data),result.baseline.current_registry_sha256);assert.deepEqual(inputs,result.baseline.current_input_sha256);
  for(const [file,expected]of Object.entries(inputs))assert.equal(raw(file),expected,file);
  return {data,inputs,validation:{...config.baseline,kind:'composite_validation_baseline',full_combined_validation_of_current_state:false,registry_sha256:hash(data),verifier:config.verifier,independent_review:config.independent_review,pinned_files:config.pinned_files,configuration:{path:local('baseline-config.json'),raw_sha256:raw(local('baseline-config.json'))}}};
}
function args(keys){const out={};assert.equal(process.argv.length,2+keys.length*2);for(let i=2;i<process.argv.length;i+=2){assert(keys.includes(process.argv[i]));assert(!Object.hasOwn(out,process.argv[i]));out[process.argv[i]]=process.argv[i+1];}for(const k of keys)assert(out[k]);return out;}
module.exports={fs,path,assert,root,C,api,relative,at,bytes,byteHash,hash,raw,read,local,serialize,save,protect,evidence,proposal,verifyScope,apply,baseline,args};
