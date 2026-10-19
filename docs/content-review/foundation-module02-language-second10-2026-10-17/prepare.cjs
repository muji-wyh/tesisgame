'use strict';
// Scratch preparation only; the separately reviewed composite verifier guards the current baseline.
const L=require('./delivery-lib.cjs'),vm=require('node:vm'),{createRequire}=require('node:module');
const {fs,path,assert,root,C,api,hash,byteHash,raw,read,local,at,bytes,serialize,save}=L;
const {transform}=require('./test-transforms.cjs');
assert.equal(process.argv.length,2);assert(!fs.existsSync(at(local('preparation-receipt.json'))),'A frozen preparation cannot be replayed.');
const codeNames=['delivery-lib.cjs','test-transforms.cjs','prepare.cjs','deliver.cjs','baseline-config.json','HANDOFF.md'];
const executionManifest={path:local('execution-start.json'),raw_sha256:raw(local('execution-start.json'))},executionStart=read(executionManifest.path);
assert.equal(executionStart.status,'preparation_dispatch_recorded');assert.equal(executionStart.entrypoint,local('prepare.cjs'));assert.equal(executionStart.production_mutated,false);
assert.deepEqual(executionStart.source_files.map(row=>row.path),codeNames.map(local));
for(const row of executionStart.source_files)assert.equal(raw(row.path),row.raw_sha256,'Before preparation: '+row.path);
const e=L.evidence(),p=L.proposal(e),baseline=L.baseline(),data=baseline.data,next=L.apply(data,p);
const beforeAudit=api.auditProfessionalContent({rootDir:root,data}),afterAudit=api.auditProfessionalContent({rootDir:root,data:next});
assert.equal(beforeAudit.errors.length,0);assert.equal(afterAudit.errors.length,0);assert.equal(beforeAudit.summary.reviewed_lexemes,122);assert.equal(afterAudit.summary.reviewed_lexemes,130);
for(const k of Object.keys(beforeAudit.summary))if(k!=='reviewed_lexemes')assert.deepEqual(afterAudit.summary[k],beforeAudit.summary[k],k);
const ids=new Set(p.patches.map(x=>x.id));Object.assign(p.protected_context,{all_other_lexemes_json_sha256:hash(data.lexemes.filter(x=>!ids.has(x.id))),all_expressions_json_sha256:hash(data.expressions),all_courses_json_sha256:hash(data.courses),all_themes_json_sha256:hash(data.themes),previous_sources_json_sha256:hash(data.sources)});
assert.equal(hash(next.lexemes.filter(x=>!ids.has(x.id))),p.protected_context.all_other_lexemes_json_sha256);
for(const k of ['catalog','expressions','courses','themes','lexemeOrigins','expressionOrigins'])assert.deepEqual(next[k],data[k]);
p.candidate_audit={summary:afterAudit.summary,errors:0,warnings:afterAudit.warnings.length};
const outputs=new Map(),testPatches=[],checks=[],excluded=[];
const add=(name,value)=>{assert(!outputs.has(name));outputs.set(name,Buffer.isBuffer(value)?value:serialize(value));};
add('accepted-language.json',p);
const projectedLexemes=read(C.target);for(const patch of p.patches)projectedLexemes.lexemes[projectedLexemes.lexemes.findIndex(x=>x.id===patch.id)]=patch.after;
const projectedSources=read(C.sources);projectedSources.sources.push(...p.sources);
const virtualFiles=new Map([[at(C.provenance),serialize(p)],[at(C.target),serialize(projectedLexemes)],[at(C.sources),serialize(projectedSources)]]);
for(const file of C.tests){
  const before=bytes(file);assert.equal(byteHash(before),baseline.inputs[file]);const transformed=transform(file,before),stem=path.basename(file);let count=0;
  if(!transformed.native){
    new vm.Script(transformed.bytes.toString('utf8'),{filename:file});const callbacks=[],nativeRequire=createRequire(at(file));
    const projectedFs=new Proxy(fs,{get(target,key){if(key==='readFileSync')return (file,...options)=>{const fake=virtualFiles.get(path.resolve(file));if(!fake)return target.readFileSync(file,...options);const encoding=typeof options[0]==='string'?options[0]:options[0]?.encoding;return encoding?fake.toString(encoding):Buffer.from(fake);};return target[key];}});
    const projectedApi={...api,loadProfessionalContent:(...args)=>!args[0]||path.resolve(args[0])===root?structuredClone(next):api.loadProfessionalContent(...args)};
    const projectedRequire=name=>name==='node:test'?((title,...rest)=>callbacks.push({title,fn:rest.at(-1)})):name==='node:fs'?projectedFs:name==='../tools/validate-professional-content.cjs'?projectedApi:nativeRequire(name);
    const compile=vm.compileFunction(transformed.bytes.toString('utf8'),['require','__dirname','module','exports','__filename'],{filename:file}),module={exports:{}};
    compile(projectedRequire,path.dirname(at(file)),module,module.exports,at(file));
    for(const callback of callbacks){
      if(callback.title==='Foundation02 second-ten delivery binds explicit composite evidence and committed guarded journal'){excluded.push({file,title:callback.title,reason:'Requires real retained delivery evidence and committed journal after root integration.'});continue;}
      assert.equal(typeof callback.fn,'function');const result=callback.fn();assert(!result||typeof result.then!=='function','Projected callbacks must remain synchronous.');checks.push({file,title:callback.title,passed:true});count++;
    }
    assert(count>0);
  }
  add(stem+'.before',before);add(stem+'.after',transformed.bytes);
  testPatches.push({file,before_sha256:byteHash(before),after_sha256:byteHash(transformed.bytes),before_artifact:stem+'.before',after_artifact:stem+'.after',exact_anchor_edits:transformed.edits,appended_tests:transformed.appended_tests,projected_callbacks_passed:count,native:transformed.native,syntax_valid:transformed.native?null:true,native_execution_required_after_delivery:transformed.native});
}
assert.equal(excluded.length,1);assert.equal(hash(api.loadProfessionalContent(root)),hash(data));for(const [file,sha]of Object.entries(baseline.inputs))assert.equal(raw(file),sha,file);
add('test-patches.json',{schema:1,status:'exact_shared_test_replacements_prepared',patches:testPatches,production_mutated:false});
add('scratch-validation.json',{schema:1,ok:true,scope:'Candidate audit plus every synchronous callback in the two affected Node suites against an in-memory projection, excluding only the new committed-journal callback. Native test replacement has exact anchors; its actual execution remains a required post-delivery check. No new full combined validation is claimed.',production_mutated:false,projected_callback_count:checks.length,projected_callbacks:checks,excluded_persisted_callbacks:excluded,native_not_executed_in_preparation:true,before_audit:{summary:beforeAudit.summary,errors:0,warnings:beforeAudit.warnings.length},after_audit:p.candidate_audit});
const binding={schema:1,status:'bound_current_composite_baseline_pending_technical_review',validation:baseline.validation,registry_before_sha256:hash(data),registry_after_sha256:hash(next),baseline_inputs:baseline.inputs,accepted_language_raw_sha256:byteHash(outputs.get('accepted-language.json')),test_patches_raw_sha256:byteHash(outputs.get('test-patches.json')),candidate_audit:p.candidate_audit,production_mutated:false};
add('binding.json',binding);
const frozenSources=codeNames.map(name=>({path:local(name),raw_sha256:raw(local(name))}));assert.deepEqual(frozenSources,executionStart.source_files,'Executed code/config/HANDOFF must equal the final frozen source inventory.');assert.equal(raw(executionManifest.path),executionManifest.raw_sha256);
const inventory=[...frozenSources,executionManifest,...Array.from(outputs,([name,buffer])=>({path:local(name),raw_sha256:byteHash(buffer)}))];
for(const name of outputs.keys())assert(!fs.existsSync(at(local(name))),name);
for(const [name,buffer]of outputs)save(name,buffer);
save('preparation-receipt.json',{schema:1,status:'frozen_preparation_pending_independent_technical_review',recorded_at:new Date().toISOString(),baseline_bound:true,baseline_kind:'composite_validation_baseline',production_mutated:false,executed_source_manifest:executionManifest,executed_source_equality_verified:true,files:inventory,projected_callbacks:checks.length,excluded_persisted_callbacks:excluded.length,native_execution_pending:true});
console.log(JSON.stringify({status:'prepared_pending_technical_review',receipt:local('preparation-receipt.json'),receipt_sha256:raw(local('preparation-receipt.json')),binding_sha256:raw(local('binding.json')),projected_callbacks:checks.length,errors:0,reviewed_lexemes:130,ready_modules:0,native_execution_pending:true,production_mutated:false}));
