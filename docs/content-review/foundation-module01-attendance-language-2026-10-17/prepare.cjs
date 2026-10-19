'use strict';
// Reads one successful current baseline and writes scratch artifacts only.
const L=require('./delivery-lib.cjs'),vm=require('node:vm'),{createRequire}=require('node:module');
const {fs,path,assert,root,C,api,hash,byteHash,raw,read,local,at,bytes,serialize,save}=L;
const {transform}=require('./test-transforms.cjs');
const args=L.args(['--baseline','--baseline-sha']);
assert(!fs.existsSync(at(local('preparation-receipt.json'))),'Frozen preparations are immutable; choose a fresh revision.');
const e=L.evidence(),p=L.proposal(e),b=L.baseline(args['--baseline'],args['--baseline-sha']),data=b.data;
L.verifyScope(data,p);const next=L.apply(data,p),beforeAudit=api.auditProfessionalContent({rootDir:root,data}),afterAudit=api.auditProfessionalContent({rootDir:root,data:next});
assert.equal(beforeAudit.errors.length,0);assert.equal(afterAudit.errors.length,0);assert.equal(beforeAudit.summary.reviewed_lexemes,121);assert.equal(afterAudit.summary.reviewed_lexemes,122);
for(const k of Object.keys(beforeAudit.summary))if(k!=='reviewed_lexemes')assert.deepEqual(afterAudit.summary[k],beforeAudit.summary[k],k);
Object.assign(p.protected_context,{all_other_lexemes_json_sha256:hash(data.lexemes.filter(x=>x.id!==C.id)),all_courses_json_sha256:hash(data.courses),all_themes_json_sha256:hash(data.themes),previous_sources_json_sha256:hash(data.sources)});
assert.equal(hash(next.lexemes.filter(x=>x.id!==C.id)),p.protected_context.all_other_lexemes_json_sha256);
for(const k of ['catalog','expressions','courses','themes','lexemeOrigins','expressionOrigins'])assert.deepEqual(next[k],data[k],k);
p.candidate_audit={summary:afterAudit.summary,errors:0,warnings:afterAudit.warnings.length};
const outputs=new Map(),testPatches=[],checks=[],excluded=[];
const add=(name,value)=>{assert(!outputs.has(name));outputs.set(name,Buffer.isBuffer(value)?value:serialize(value));};
add('accepted-language.json',p);
for(const file of C.tests){
  const before=bytes(file);assert.equal(byteHash(before),b.inputs[file]);const transformed=transform(file,before),stem=path.basename(file);
  new vm.Script(transformed.bytes.toString('utf8'),{filename:file});
  const callbacks=[],nativeRequire=createRequire(at(file));
  const projectedFs=new Proxy(fs,{get(target,key){if(key==='readFileSync')return (targetFile,...options)=>path.resolve(targetFile)===at(C.provenance)?(options[0]==='utf8'?serialize(p).toString('utf8'):serialize(p)):target.readFileSync(targetFile,...options);return target[key];}});
  const projectedRequire=name=>name==='node:test'?((title,...rest)=>callbacks.push({title,fn:rest.at(-1)})):name==='node:fs'?projectedFs:name==='../tools/validate-professional-content.cjs'?{...api,loadProfessionalContent:()=>structuredClone(next)}:nativeRequire(name);
  const compile=vm.compileFunction(transformed.bytes.toString('utf8'),['require','__dirname','module','exports','__filename'],{filename:file}),module={exports:{}};
  compile(projectedRequire,path.dirname(at(file)),module,module.exports,at(file));
  let count=0;
  for(const c of callbacks){
    if(c.title==='Attendance delivery requires the exact successful baseline and committed guarded journal'){excluded.push({file,title:c.title,reason:'The real attendance binding, retained evidence and committed transaction will be checked after root integrates.'});continue;}
    if(!/Foundation|Supervisor|Module02|Attendance|historical reversal|Fifth-ten reversal|Fourth-ten historical/.test(c.title))continue;
    assert.equal(typeof c.fn,'function');const result=c.fn();assert(!result||typeof result.then!=='function');checks.push({file,title:c.title,passed:true});count++;
  }
  assert(count>0);add(stem+'.before',before);add(stem+'.after',transformed.bytes);
  testPatches.push({file,before_sha256:byteHash(before),after_sha256:byteHash(transformed.bytes),before_artifact:stem+'.before',after_artifact:stem+'.after',exact_anchor_edits:transformed.edits,appended_tests:transformed.appended_tests,projected_callbacks_passed:count,syntax_valid:true});
}
assert.equal(excluded.length,1);assert.equal(testPatches.reduce((n,p)=>n+p.appended_tests,0),6);
assert.equal(hash(api.loadProfessionalContent(root)),hash(data));for(const [file,sha]of Object.entries(b.inputs))assert.equal(raw(file),sha,file);
add('test-patches.json',{schema:1,status:'exact_shared_test_replacements_prepared',patches:testPatches,production_mutated:false});
add('scratch-validation.json',{schema:1,ok:true,scope:'Candidate audit and focused projected callbacks against the proposed in-memory registry, including exact chronological historical reversals and negative mutation checks. This is not persisted or complete combined validation.',production_mutated:false,projected_callback_count:checks.length,projected_callbacks:checks,excluded_persisted_callbacks:excluded,before_audit:{summary:beforeAudit.summary,errors:0,warnings:beforeAudit.warnings.length},after_audit:p.candidate_audit});
const codeNames=['delivery-lib.cjs','test-transforms.cjs','prepare.cjs','deliver.cjs','HANDOFF.md'];
const binding={schema:1,status:'bound_successful_current_validation_pending_technical_review',validation:b.validation,registry_before_sha256:hash(data),registry_after_sha256:hash(next),baseline_inputs:b.inputs,accepted_language_raw_sha256:byteHash(outputs.get('accepted-language.json')),test_patches_raw_sha256:byteHash(outputs.get('test-patches.json')),candidate_audit:p.candidate_audit,production_mutated:false};
add('binding.json',binding);
const inventory=[...codeNames.map(name=>({path:local(name),raw_sha256:raw(local(name))})),...Array.from(outputs,([name,buffer])=>({path:local(name),raw_sha256:byteHash(buffer)}))];
for(const name of outputs.keys())assert(!fs.existsSync(at(local(name))),name);
for(const [name,buffer]of outputs)save(name,buffer);
save('preparation-receipt.json',{schema:1,status:'frozen_preparation_pending_independent_technical_review',recorded_at:new Date().toISOString(),baseline_bound:true,production_mutated:false,files:inventory,projected_callbacks:checks.length,excluded_persisted_callbacks:excluded.length});
console.log(JSON.stringify({status:'prepared_pending_technical_review',receipt:local('preparation-receipt.json'),receipt_sha256:raw(local('preparation-receipt.json')),binding_sha256:raw(local('binding.json')),candidate_entry_sha256:p.patches[0].after_sha256,projected_callbacks:checks.length,errors:0,reviewed_lexemes:122,ready_modules:0,production_mutated:false}));
