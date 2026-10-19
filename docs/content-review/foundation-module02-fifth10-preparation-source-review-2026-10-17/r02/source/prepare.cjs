'use strict';
// Root-only one-shot scratch preparation. Authored but undispatched by runtime_recovery.
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const B=require('./binding.cjs');
assert.equal(process.argv.length,6);
assert.equal(process.argv[2],'--root-input');assert.equal(process.argv[4],'--root-input-sha256');
const ctx=B.openSession(process.argv[3],process.argv[5]);
// No projection or transformer is imported until actual predecessor and root gates pass.
const output=B.at(B.own+'/execution-r01');assert(!fs.existsSync(output),'Single-use preparation; preserve earlier attempts');
fs.mkdirSync(output);
function save(name,value){
  assert(!path.isAbsolute(name)&&!name.includes('\\')&&!name.startsWith('../'));
  const destination=path.resolve(output,name);assert.equal(path.relative(output,destination).replaceAll('\\','/'),name);
  const bytes=Buffer.isBuffer(value)?value:typeof value==='string'?Buffer.from(value):B.serialize(value);
  fs.writeFileSync(destination,bytes,{flag:'wx'});return {artifact:name,bytes:bytes.length,raw_sha256:B.sha(bytes)};
}
save('execution-start.json',{schema:1,status:'started',started_at:new Date().toISOString(),root_input:ctx.rootInputPin,actual_binding:ctx.input.binding,source_inventory:ctx.input.source_inventory,independent_source_review:ctx.input.independent_source_review,project_or_test_execution:false,production_mutated:false});
let status='failed';
try{
  const P=require('./projection.cjs'),T=require('./test-transforms.cjs');
  const p=P.project(ctx),targetPlan=[],edits=[];
  function replacement(target,before,after,stem){
    save(stem+'.before',before);const artifact=save(stem+'.after',after);
    targetPlan.push({path:target,operation:'replace',before_sha256:B.sha(before),after_sha256:artifact.raw_sha256,bytes:artifact.bytes,artifact:artifact.artifact});
  }
  for(const row of p.proposedFiles)replacement(row.path,row.before,row.after,path.basename(row.path));
  for(const target of T.files){
    const before=ctx.read(target),result=T.transform(ctx,target,before,p.record);
    replacement(target,before,result.bytes,path.basename(target));
    edits.push({path:target,edits:result.edits,appended_tests:result.appended_tests,native:result.native});
  }
  const provenanceTarget=P.provenance,documentTarget='docs/content-review/foundation-module02-language-fifth10-2026-10-17/DELIVERY.md';
  for(const target of [provenanceTarget,documentTarget])assert(ctx.binding.must_remain_absent.includes(target));
  const provenanceArtifact=save('production-provenance.prepared.json',p.record);
  const document=save('production-document.prepared.md',[
    '# Foundation02 fifth-ten lexical delivery preparation','',
    'Construction-stage afterimage. Actual fifth-ten commit and persisted validation are pending. This file must be finalized and reviewed with the actual transaction lineage before publication.','',
    'Eight accepted lexical entries receive the exact reviewed content, metadata, references and notes. Six complete lexical holds, fifty complete historical donor rows, all expression contexts, memberships, pending morphology, media and domain gates remain preserved. Sixteen consulted source rows are appended without changing the actual source prefix.','',
    'Broken and solution retain their original definition, example and editorial difficulty. Across six other entries, four definitions, one example and five difficulty values change. Publisher differences and source-access limits remain literal; no new language, morphology, media, expression, specialist or release acceptance is created.','',
    'The actual delivered shopping-bag remains intact. Its historical test paths stay separate from Foundation reversals. Full predecessor receipts and accepted evidence are retained under the individual target manifest.','',
    'Preparation performs built-in JSON and byte construction only. Root must separately run projected Node/validator checks, independent output review, native validation, guarded installation and fresh persisted checks.',''
  ].join('\n'));
  for(const [target,artifact]of [[provenanceTarget,provenanceArtifact],[documentTarget,document]])targetPlan.push({path:target,operation:'add_absent_pending_actual_stage_finalization',prepared_sha256:artifact.raw_sha256,bytes:artifact.bytes,artifact:artifact.artifact,final_transaction_bytes_frozen:false});
  fs.mkdirSync(path.join(output,'retained-evidence'));
  for(const [index,row]of p.retained.entries()){
    const bytes=ctx.read(row.source);assert.equal(bytes.length,row.bytes);assert.equal(B.sha(bytes),row.raw_sha256);
    const artifact=save('retained-evidence/'+String(index).padStart(3,'0')+'.bin',bytes);
    targetPlan.push({path:row.target,operation:'add_absent',source:row.source,before_sha256:null,after_sha256:row.raw_sha256,bytes:row.bytes,artifact:artifact.artifact});
  }
  assert.equal(new Set(targetPlan.map(row=>row.path.toLowerCase())).size,targetPlan.length,'Duplicate production target');
  const additions=targetPlan.filter(row=>row.operation!=='replace').map(row=>row.path).sort();
  assert.deepEqual(additions,[...ctx.binding.must_remain_absent].sort(),'Exact complete absence allowlist required');
  assert.deepEqual(targetPlan.map(row=>row.path).sort(),[...ctx.binding.target_paths].sort(),'Exact root-bound target set required');
  save('test-edit-ledger.json',{schema:1,status:'scratch_afterimages_not_executed',files:edits});
  save('target-plan.json',{schema:1,status:'scratch_plan_not_commit_authorization',targets:targetPlan,production_mutated:false,project_or_test_execution:false});
  save('projection-observation.json',{schema:1,status:'built_in_json_projection_only',registry_before_sha256:B.hash(p.before),registry_after_sha256:B.hash(p.next),counts:p.record.counts,content_delta:p.record.content_delta,actual_validator_loaded:false,test_callbacks_executed:false,native_executed:false,production_mutated:false});
  ctx.recheck();
  const list=[];
  for(const entry of fs.readdirSync(output,{withFileTypes:true})){
    if(entry.isDirectory()){assert.equal(entry.name,'retained-evidence');for(const name of fs.readdirSync(path.join(output,entry.name)))list.push(entry.name+'/'+name);}else list.push(entry.name);
  }
  const artifacts=list.sort().map(name=>{const bytes=fs.readFileSync(path.join(output,name));return {path:name,bytes:bytes.length,raw_sha256:B.sha(bytes)};});
  save('preparation-receipt.json',{schema:1,status:'prepared_pending_independent_afterimage_review_and_root_validation',actual_binding:ctx.input.binding,source_inventory:ctx.input.source_inventory,independent_source_review:ctx.input.independent_source_review,artifacts,target_count:targetPlan.length,project_or_test_execution:false,native_executed:false,production_mutated:false,actual_fifth10_commit:false,actual_fifth10_persisted_validation:false});
  status='prepared_pending_independent_review';
}catch(error){
  save('failed-attempt.json',{schema:1,status:'failed',recorded_at:new Date().toISOString(),error:error.stack||String(error),production_mutated:false,instruction:'Preserve sources and this consumed attempt. Corrections require a new revision and independent review.'});throw error;
}finally{
  save('execution-end.json',{schema:1,status,finished_at:new Date().toISOString(),production_mutated:false});
}
console.log(JSON.stringify({status,output:B.own+'/execution-r01',production_mutated:false,project_or_test_execution:false}));
