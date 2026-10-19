'use strict';
// Scratch-only preparation. It does not bind current inputs or install any output.
const L=require('./delivery-lib.cjs'),vm=require('node:vm'),{createRequire}=require('node:module');
const {assert,fs,path,root,C,api,hash,byteHash,raw,read,bytes,at,local,save,serialized}=L;
const {transform}=require('./persisted-test-transforms.cjs');
assert(!fs.existsSync(at(local('preparation-receipt.json'))),'Prepared packages are immutable.');
assert(!fs.existsSync(at(local('binding.json'))),'Preparation cannot follow binding.');
const evidence=L.evidence(),data=api.loadProfessionalContent(root);L.verifyScope(data,evidence);
const proposal=L.makeProposal(evidence),candidate=L.applyProposal(data,proposal),selected=new Set(proposal.patches.map(x=>x.id));
const observed=L.validateBaseline('build/professional-english/continuation-validation-r30.json','59db6d773240cd58ab8873472050515894f2586557921551434f7b4c5451bc55');
assert.equal(hash(observed.data),hash(data));
const currentAudit=api.auditProfessionalContent({rootDir:root,data}),candidateAudit=api.auditProfessionalContent({rootDir:root,data:candidate});
assert.deepEqual(currentAudit.errors,[]);assert.deepEqual(candidateAudit.errors,[]);assert.equal(currentAudit.summary.reviewed_lexemes,111);assert.equal(candidateAudit.summary.reviewed_lexemes,121);assert.equal(candidateAudit.summary.ready_modules,0);
for(const key of Object.keys(currentAudit.summary))if(key!=='reviewed_lexemes')assert.deepEqual(candidateAudit.summary[key],currentAudit.summary[key],key);
const aggregate={other_lexemes_json_sha256:hash(data.lexemes.filter(x=>!selected.has(x.id))),expressions_json_sha256:hash(data.expressions),courses_json_sha256:hash(data.courses),themes_json_sha256:hash(data.themes)};
assert.equal(hash(candidate.lexemes.filter(x=>!selected.has(x.id))),aggregate.other_lexemes_json_sha256);
for(const k of ['expressions','courses','themes'])assert.equal(hash(candidate[k]),aggregate[k+'_json_sha256']);
const outputs=new Map(),patches=[],checks=[],excluded=[];
const add=(name,value)=>{assert(!outputs.has(name));outputs.set(name,Buffer.isBuffer(value)?value:serialized(value));};
add('delivery-proposal.json',proposal);
add('observed-current-inputs.json',{...observed.composite,baseline_bound:false,informational_only:true});
// Execute selected callbacks against the proposed in-memory registry. No committed
// module02 provenance, binding, or journal is fabricated; its lineage test is excluded.
const projected={...proposal,lineage:aggregate};
for(const file of C.tests){
 const before=bytes(file),change=transform(file,before),stem=path.basename(file),beforeName=stem+'.before',afterName=stem+'.after';
 new vm.Script(change.bytes.toString('utf8'),{filename:file});
 const callbacks=[],nativeRequire=createRequire(at(file));
 const projectedFs=new Proxy(fs,{get(target,key){if(key==='readFileSync')return (targetFile,...options)=>path.resolve(targetFile)===at(C.provenance)?(options[0]==='utf8'?serialized(projected).toString('utf8'):serialized(projected)):target.readFileSync(targetFile,...options);return target[key];}});
 const requireForProjection=name=>name==='node:test'?((title,...rest)=>callbacks.push({title,fn:rest.at(-1)})):name==='node:fs'?projectedFs:name==='../tools/validate-professional-content.cjs'?{...api,loadProfessionalContent:()=>structuredClone(candidate)}:nativeRequire(name);
 const compile=vm.compileFunction(change.bytes.toString('utf8'),['require','__dirname','module','exports','__filename'],{filename:file});
 const module={exports:{}};compile(requireForProjection,path.dirname(at(file)),module,module.exports,at(file));
 let executed=0;
 for(const item of callbacks){
  if(item.title.includes('actual composite baseline')){excluded.push({file,title:item.title,reason:'Requires the real later binding and committed journal; run by root after integration.'});continue;}
  if(!/Foundation|Supervisor|Module02|historical reversal|Fifth-ten reversal|Fourth-ten historical/.test(item.title))continue;
  assert.equal(typeof item.fn,'function');const result=item.fn();assert(!result||typeof result.then!=='function','Projection expects synchronous focused callbacks.');checks.push({file,title:item.title,passed:true});executed++;
 }
 assert(executed>0);add(beforeName,before);add(afterName,change.bytes);
 patches.push({file,before_sha256:byteHash(before),after_sha256:byteHash(change.bytes),before_artifact:beforeName,after_artifact:afterName,exact_anchor_edits:change.edits,appended_tests:change.appended_tests,syntax_valid:true,projected_focused_callbacks_passed:executed});
}
assert.equal(excluded.length,1);assert.equal(patches.reduce((n,p)=>n+p.appended_tests,0),6);
assert.equal(hash(api.loadProfessionalContent(root)),hash(data));for(const[p,h]of Object.entries(observed.inputs))assert.equal(raw(p),h,p);
add('test-patches.json',{schema:1,status:'exact_shared_test_replacements_prepared_unbound',patches,baseline_bound:false,production_mutated:false});
add('scratch-validation.json',{schema:1,ok:true,scope:'In-memory candidate schema/audit, exact current scope and source verification, transformed-test parse, focused projected callbacks, and strict chronological reversal/mutation checks. This is not a persisted or combined suite run.',baseline_bound:false,production_mutated:false,informational_current_registry_sha256:hash(data),informational_candidate_registry_sha256:hash(candidate),current_audit:{summary:currentAudit.summary,errors:0,warnings:currentAudit.warnings.length},candidate_audit:{summary:candidateAudit.summary,errors:0,warnings:candidateAudit.warnings.length},projected_callback_count:checks.length,projected_callbacks:checks,excluded_callbacks:excluded,protected_aggregate:aggregate,source_mix:{original:18,corrected_confirm:2},original_author_artifacts_unchanged:true});
const names=['delivery-lib.cjs','composite-baseline.cjs','persisted-test-transforms.cjs','prepare-delivery.cjs','bind-current-baseline.cjs','integrate-reviewed.cjs','HANDOFF.md'];
for(const name of [...names,...outputs.keys()])assert(!name.includes('/'));
const inventory=[...names.map(name=>({path:name,raw_sha256:raw(local(name)),bytes:bytes(local(name)).length})),...Array.from(outputs,([name,buffer])=>({path:name,raw_sha256:byteHash(buffer),bytes:buffer.length}))];
for(const name of outputs.keys())assert(!fs.existsSync(at(local(name))),'Fresh scratch artifact required: '+name);
for(const[name,buffer]of outputs)save(name,buffer);
save('preparation-receipt.json',{schema:1,status:'frozen_unbound_delivery_preparation',recorded_at:new Date().toISOString(),baseline_bound:false,production_mutated:false,projected_callback_count:checks.length,excluded_persisted_lineage_callbacks:1,files:inventory,immutable_after_preparation:true});
console.log(JSON.stringify({status:'prepared_unbound',preparation_receipt:local('preparation-receipt.json'),raw_sha256:raw(local('preparation-receipt.json')),files:inventory.length,projected_callbacks:checks.length,current_reviewed:111,candidate_reviewed:121,errors:0,ready_modules:0,baseline_bound:false,production_mutated:false}));
