'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const api=require(path.join(root,'tools/validate-professional-content.cjs'));
const C=Object.freeze({id:'attendance.presence-record.n',target:'data/professional/lexemes/foundation-module01.json',sources:'data/professional/sources.json',
  provenance:'data/professional/provenance/foundation-module01-attendance-language-2026-10-17.json',
  docs:'docs/content-review/foundation-module01-attendance-language-2026-10-17',transaction:'build/professional-english/transactions/foundation01-attendance-language-r01',
  research:'build/professional-english/foundation-module01-language-review/attendance-research-r02/research.json',researchRaw:'ce942440d12226494de805eedfefb9e09b4c23e517b5f643c2e2ad0421049a4b',
  acceptance:'build/professional-english/foundation-module01-language-review/attendance-research-r02-independent-review-r01/independent-review.json',acceptanceRaw:'979297a9ea44542fff7ec7082346edae11fa66587787190f2a81730bc77a35b4',
  helper:'build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs',helperRaw:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
  helperValidation:'build/professional-english/retail-module03-morphology-review/fifth10/serializer-review-r01/validation-attempt-XE9O6l/receipt.json',helperValidationRaw:'abd19b9952fe3085ef8cab5b87e430ef442780ed05f3a9a2105f909f968a9bae',
  tests:['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs']});
const relative=file=>path.relative(root,file).replaceAll('\\','/');
const at=file=>{assert.equal(path.isAbsolute(file),false);assert(!file.includes('\\'));const p=path.resolve(root,file);assert.equal(relative(p),file);assert(!file.startsWith('../'));return p;};
const bytes=file=>fs.readFileSync(at(file));
const byteHash=value=>crypto.createHash('sha256').update(value).digest('hex');
const hash=value=>byteHash(JSON.stringify(value));
const raw=file=>byteHash(bytes(file));
const read=file=>JSON.parse(bytes(file));
const local=name=>relative(path.join(__dirname,name));
const serialize=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),Buffer.isBuffer(value)?value:serialize(value),{flag:'wx'});
function protect(entry){const v=structuredClone(entry);for(const key of ['difficulty','references','editorial_notes'])delete v[key];for(const key of ['status','language','reviewer','reviewed_at'])delete v.review[key];return v;}
function evidence(){
  assert.equal(raw(C.research),C.researchRaw);assert.equal(raw(C.acceptance),C.acceptanceRaw);
  assert.equal(raw(C.helper),C.helperRaw);assert.equal(raw(C.helperValidation),C.helperValidationRaw);
  const research=read(C.research),acceptance=read(C.acceptance);
  assert.equal(acceptance.accepted,true);assert.equal(acceptance.status,'independent_ai_language_content_accepted_pending_delivery');
  assert.equal(acceptance.independence.current_proposal_authored_by_reviewer,false);assert.equal(acceptance.research.raw_sha256,C.researchRaw);
  assert.equal(hash(research.before),acceptance.candidate.before_entry_json_sha256);assert.equal(hash(research.proposed_content),acceptance.candidate.accepted_content_entry_json_sha256);
  const reconstructed=structuredClone(research.proposed_content);reconstructed.difficulty='A2';assert.deepEqual(reconstructed,research.before);
  assert.deepEqual(acceptance.candidate.difficulty.source_observations,{cefrj_v1_5_headword_pos:'B2',oxford_selected_presence_topics:'C1',collins_selected_presence_level:null,english_flows_whole_lesson:'B1 / B2'});
  assert.equal(acceptance.candidate.difficulty.dictionary_or_unanimous_level_certification,false);assert.equal(acceptance.candidate.difficulty.active_mastery_certification,false);
  return {research,acceptance};
}
function proposal(e){
  const {research,acceptance}=e,before=structuredClone(research.before),after=structuredClone(research.proposed_content);
  const limits='No human, subject-matter, morphology, media, domain, expression or release approval is claimed.';
  const basis='B2 is an independently accepted course editorial placement for ordinary presence. CEFR-J v1.5 lists the exact headword/POS at B2 without a sense definition; its A1-B2 coverage is not universal proof for every sense or active mastery. Oxford labels the selected presence topics C1, retained as conflicting evidence. Collins supports the selected meaning without an observed selected CEFR level. English Flows labels the whole workplace lesson B1 / B2; this is contextual teachability, not word- or sense-level certification. B2 is not an automatic clamp of C1 or a level transferred from attend.';
  const ids=['cefrj-v15','cefrj-attribution','cefrj-methodology','oxford-presence','collins-presence','englishflows-lesson'];
  const titles=['The CEFR-J Wordlist Version 1.5: attendance noun','CEFR-J v1.5 repository attribution and use terms','CEFR-J official wordlist methodology','Oxford Advanced Learner\'s Dictionary: attendance presence sense','Collins English Dictionary: attendance presence sense','English Flows: Attendance, time off and absenteeism'];
  const publishers=['Yukio Tono / Tono Laboratory, Tokyo University of Foreign Studies; Open Language Profiles redistribution','Open Language Profiles; Tono Laboratory, Tokyo University of Foreign Studies','Tono Laboratory, Tokyo University of Foreign Studies','Oxford University Press','HarperCollins','English Flows'];
  assert.equal(acceptance.direct_source_checks.length,6);
  const sources=acceptance.direct_source_checks.map((s,i)=>({id:'foundation01-attendance-reconsideration-'+ids[i],title:titles[i],publisher:publishers[i],url:s.url,status:'consulted',consulted_on:'2026-10-16',scope:s.observation+' '+(s.limits||'')+' '+(s.citation||'')+' Consulted by the recorded independent AI language reviewer; source media, dictionary page copies and complete datasets were not acquired or imported. '+limits,asset_license:null,assets_acquired:false}));
  after.review={...before.review,status:'reviewed',language:'reviewed',reviewer:acceptance.reviewer,reviewed_at:'2026-10-16'};
  after.references.push(...sources.map(s=>({source_id:s.id,status:'verified',scope:s.scope+' '+basis})));
  after.editorial_notes='Shared workplace foundation. The original ordinary-presence definition, trainer/session example and editorial B2 placement have independent AI language acceptance. '+basis+' The stable legacy ID is retained for progress continuity; it does not introduce a record-object or headcount sense. Recording attendance means recording whether participants are present. '+limits+' Accepted forms, regions, prior references, morphology, image/audio and domain states, practice modes, memberships and expressions remain unchanged; separate pending gates still prevent complete-module readiness.';
  assert.deepEqual(protect(after),protect(before));assert.deepEqual(after.references.slice(0,before.references.length),before.references);
  const changed=Object.keys(before).filter(k=>JSON.stringify(before[k])!==JSON.stringify(after[k]));assert.deepEqual(changed,['difficulty','review','references','editorial_notes']);
  return {schema:1,status:'accepted_content_with_proposed_integration_metadata',reviewer:acceptance.reviewer,prepared_by:'Codex attendance_review continuation delivery author',new_language_approval:false,
    author_research:{path:C.research,raw_sha256:C.researchRaw,accepted:false},
    independent_review:{path:C.acceptance,raw_sha256:C.acceptanceRaw,accepted:true,reviewer:acceptance.reviewer,recorded_at:acceptance.recorded_at,human_or_specialist_approval:false,decision:acceptance.independent_decision,source_checks:acceptance.direct_source_checks},
    patches:[{id:C.id,before,after,before_sha256:hash(before),after_sha256:hash(after),accepted_content:research.proposed_content,accepted_content_json_sha256:hash(research.proposed_content),protected_fields_sha256:hash(protect(before)),changed_fields:changed,difficulty:{...acceptance.candidate.difficulty,independent_editorial_basis:basis},memberships:acceptance.protected_scope.memberships}],sources,
    historical_boundary:{previous_A2_candidate_accepted:false,prior_hold_artifacts_immutable:true,excluded_third10_source_ids:['foundation01-language-third10-oxford-attendance','foundation01-language-third10-collins-attendance']},
    protected_context:{expressions:acceptance.protected_scope.attendance_surface_expressions,all_expressions_json_sha256:acceptance.protected_scope.all_expressions_json_sha256},
    delivery_scope:{lexeme_file:C.target,sources_file:C.sources,provenance_file:C.provenance,review_directory:C.docs,production_runtime_changed:false,module_acceptance:false}};
}
function verifyScope(data,p){
  assert.deepEqual(data.lexemes.find(x=>x.id===C.id),p.patches[0].before);
  const memberships=data.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(C.id)).map(m=>({course_id:c.id,module_id:m.id})));
  assert.deepEqual(memberships,p.patches[0].memberships);assert.equal(memberships.length,20);
  assert.equal(hash(data.expressions),p.protected_context.all_expressions_json_sha256);
  for(const row of p.protected_context.expressions)assert.equal(hash(data.expressions.find(x=>x.id===row.id)),row.entry_json_sha256);
  for(const source of p.sources)assert(!data.sources.some(x=>x.id===source.id));
  for(const id of p.historical_boundary.excluded_third10_source_ids)assert(!data.sources.some(x=>x.id===id));
}
function apply(data,p){verifyScope(data,p);const next=structuredClone(data);next.lexemes[next.lexemes.findIndex(x=>x.id===C.id)]=structuredClone(p.patches[0].after);next.sources.push(...structuredClone(p.sources));return next;}
function baseline(file,sha){
  assert.equal(raw(file),sha);const r=read(file);assert.equal(r.ok,true);assert.equal(r.changed_measured_inputs.length,0);assert.equal(r.registry_before_sha256,r.registry_after_sha256);
  assert.deepEqual(r.runs.map(x=>x.name),['node','native','native-audio']);
  for(const run of r.runs){assert.equal(run.status,0);assert.equal(run.error,null);assert.equal(run.signal,null);assert.equal(raw(run.log),run.log_sha256);if(run.name==='node'){assert(run.tests>0);assert.equal(run.pass,run.tests);assert.equal(run.fail,0);assert.equal(run.cancelled,0);assert.equal(run.skipped,0);}else{assert(run.checks>0);assert.equal(run.failures,0);}}
  assert(r.after_input_sha256&&Object.keys(r.after_input_sha256).length>600);
  assert.deepEqual(r.before_input_sha256,r.after_input_sha256);for(const [p,h]of Object.entries(r.after_input_sha256))assert.equal(raw(p),h,p);
  const data=api.loadProfessionalContent(root);assert.equal(hash(data),r.registry_after_sha256);
  return {data,inputs:r.after_input_sha256,validation:{path:file,raw_sha256:sha,registry_sha256:r.registry_after_sha256}};
}
function args(keys){const out={};assert.equal(process.argv.length,2+keys.length*2);for(let i=2;i<process.argv.length;i+=2){assert(keys.includes(process.argv[i]));assert(!Object.hasOwn(out,process.argv[i]));out[process.argv[i]]=process.argv[i+1];}for(const k of keys)assert(out[k]);return out;}
module.exports={fs,path,assert,root,C,api,relative,at,bytes,byteHash,hash,raw,read,local,serialize,save,protect,evidence,proposal,verifyScope,apply,baseline,args};
