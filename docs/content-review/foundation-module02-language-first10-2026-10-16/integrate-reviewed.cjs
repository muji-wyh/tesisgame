'use strict';
// One guarded content-and-shared-test transaction, run only by root after late binding.
const L=require('./delivery-lib.cjs');
const {fs,path,assert,root,C,api,hash,raw,read,bytes,local,serialized,save,args}=L;
const a=args(['--binding-sha','--exclusive-window']);assert.equal(a['--exclusive-window'],'confirmed-by-root');
assert.equal(raw(local('binding.json')),a['--binding-sha']);
assert(!fs.existsSync(L.at(C.transaction)),'Do not replay an existing transaction; inspect/recover its journal.');
const binding=read(local('binding.json')),prepared=L.verifyPrepared();
assert.equal(binding.status,'bound_actual_root_authorized_validated_baseline');assert.equal(binding.exclusive_window,'confirmed-by-root');
assert.equal(raw(local('preparation-receipt.json')),binding.preparation_receipt_raw_sha256);assert.equal(raw(local('delivery-proposal.json')),binding.proposal_raw_sha256);assert.equal(raw(local('test-patches.json')),binding.test_patches_raw_sha256);
assert.equal(raw(binding.technical_review.path),binding.technical_review.raw_sha256);const technical=read(binding.technical_review.path);assert.equal(technical.accepted,true);for(const row of technical.reviewed_files)assert.equal(raw(row.path),row.raw_sha256,row.path);
const {data,inputs,composite}=L.validateBaseline(binding.validation.path,binding.validation.raw_sha256);assert.equal(hash(data),binding.registry_before_sha256);assert.deepEqual(inputs,binding.baseline_inputs);assert.deepEqual(composite,binding.composite_baseline);L.verifyScope(data,prepared.e);
const next=L.applyProposal(data,prepared.proposal);assert.equal(hash(next),binding.registry_after_sha256);
const audit=api.auditProfessionalContent({rootDir:root,data:next});assert.equal(audit.errors.length,0);assert.deepEqual(audit.summary,binding.proposed_audit.summary);
for(const[p,sha]of Object.entries(binding.target_preimage_sha256))assert.equal(raw(p),sha,p);
const lexemes=read(C.target),sources=read(C.sources);
for(const p of prepared.proposal.patches){const i=lexemes.lexemes.findIndex(x=>x.id===p.id);assert.deepEqual(lexemes.lexemes[i],p.before);lexemes.lexemes[i]=p.after;}sources.sources.push(...prepared.proposal.sources);
const testPatches=read(local('test-patches.json')).patches;
for(const p of testPatches){assert.equal(raw(p.file),p.before_sha256);assert.equal(raw(local(p.after_artifact)),p.after_sha256);}
assert(!fs.existsSync(L.at(C.docs)));assert(!fs.existsSync(L.at(C.provenance)));
const retainedNames=[...prepared.receipt.files.map(x=>x.path),'preparation-receipt.json','binding.json'];
assert.equal(new Set(retainedNames).size,retainedNames.length);
const retained=retainedNames.map(name=>({path:C.docs+'/'+name,raw_sha256:raw(local(name)),source:local(name)}));
retained.push({path:C.docs+'/technical-review.json',raw_sha256:binding.technical_review.raw_sha256,source:binding.technical_review.path},{path:C.docs+'/root-acceptance.json',raw_sha256:C.acceptanceRaw,source:C.acceptance});
const record={...prepared.proposal,status:'integrated_language_outputs_require_committed_journal',baseline_bound:true,production_mutated:true,integrated_on:'2026-10-16',
 root_acceptance:{...prepared.proposal.root_acceptance,path:C.docs+'/root-acceptance.json'},
 lineage:{validation:{...binding.validation,scope:'Historical R30; current state is verified by the exact composite binding.'},binding:{path:C.docs+'/binding.json',raw_sha256:a['--binding-sha']},registry_before_sha256:binding.registry_before_sha256,registry_after_sha256:binding.registry_after_sha256,
 other_lexemes_json_sha256:binding.other_lexemes_json_sha256,expressions_json_sha256:binding.expressions_json_sha256,courses_json_sha256:binding.courses_json_sha256,themes_json_sha256:binding.themes_json_sha256},
 retained_files:retained.map(({path,raw_sha256})=>({path,raw_sha256})),integration_guards:{transaction_path:C.transaction,helper:{path:C.helper,raw_sha256:C.helperRaw,validation_path:C.helperValidation,validation_raw_sha256:C.helperValidationRaw},technical_review:{path:C.docs+'/technical-review.json',raw_sha256:binding.technical_review.raw_sha256},completion_requires_committed_journal:true},audit:binding.proposed_audit};
const artifacts=[{path:C.target,after:serialized(lexemes),before:bytes(C.target)},{path:C.sources,after:serialized(sources),before:bytes(C.sources)},
 ...retained.map(x=>({path:x.path,after:bytes(x.source),before:null})),{path:C.provenance,after:serialized(record),before:null},
 ...testPatches.map(p=>({path:p.file,after:bytes(local(p.after_artifact)),before:bytes(p.file)}))];
assert.equal(new Set(artifacts.map(x=>x.path)).size,artifacts.length);
const verify=()=>{assert.deepEqual(api.loadProfessionalContent(root),next);for(const [file,sha]of Object.entries(binding.baseline_inputs))if(!artifacts.some(x=>x.path===file))assert.equal(raw(file),sha,'Unrelated validated input '+file);};
assert.equal(raw(C.helper),C.helperRaw);assert.equal(raw(C.helperValidation),C.helperValidationRaw);
const transaction=require(L.at(C.helper));
const options={repositoryRoot:root,transactionDir:L.at(C.transaction),allowedPaths:artifacts.map(x=>L.at(x.path)),changes:artifacts.map(x=>({...x,path:L.at(x.path)})),verify};
const descriptor=transaction.describePlan(options);save('transaction-intent.json',{schema:1,status:'root_authorized_plan_ready_for_guarded_commit',binding_raw_sha256:a['--binding-sha'],plan_sha256:descriptor.planSha256,descriptor:descriptor.descriptor});
const result=transaction.commitTransaction(options);assert.equal(result.status,'committed');assert.equal(result.committed,true);verify();
save('commit-receipt.json',{schema:1,status:'committed',registry_after_sha256:hash(api.loadProfessionalContent(root)),binding_raw_sha256:a['--binding-sha'],provenance_raw_sha256:raw(C.provenance),result});
console.log(JSON.stringify({status:result.status,registry_after_sha256:hash(next),transaction:C.transaction,receipt:local('commit-receipt.json'),provenance:C.provenance}));
