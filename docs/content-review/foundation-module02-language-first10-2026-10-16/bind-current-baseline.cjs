'use strict';
// Root runs this after technical review and its explicit frozen binding window.
const L=require('./delivery-lib.cjs');
const {assert,C,api,root,hash,raw,read,local,save,args}=L;
const a=args(['--validation','--validation-sha','--technical-review','--technical-review-sha','--exclusive-window']);
assert.equal(a['--exclusive-window'],'confirmed-by-root');
assert(!L.fs.existsSync(L.at(local('binding.json'))),'One-shot binding already exists.');
const prepared=L.verifyPrepared();
assert.equal(raw(a['--technical-review']),a['--technical-review-sha']);
const technical=read(a['--technical-review']);assert.equal(technical.accepted,true,'Independent technical review required.');
for(const row of technical.reviewed_files)assert.equal(raw(row.path),row.raw_sha256,row.path);
for(const name of ['delivery-lib.cjs','composite-baseline.cjs','prepare-delivery.cjs','persisted-test-transforms.cjs','bind-current-baseline.cjs','integrate-reviewed.cjs','preparation-receipt.json','delivery-proposal.json','test-patches.json'])assert(technical.reviewed_files.some(x=>x.path===local(name)),name+' requires technical review');
const {v,data,inputs,composite}=L.validateBaseline(a['--validation'],a['--validation-sha']);
L.verifyScope(data,prepared.e);
const tests=read(local('test-patches.json'));
for(const p of tests.patches)assert.equal(raw(p.file),p.before_sha256,p.file);
const proposed=L.applyProposal(data,prepared.proposal),audit=api.auditProfessionalContent({rootDir:root,data:proposed});assert.equal(audit.errors.length,0);
assert.equal(audit.summary.reviewed_lexemes,121);assert.equal(audit.summary.ready_modules,0);
const selected=new Set(prepared.proposal.patches.map(p=>p.id));
assert.equal(hash(data.lexemes.filter(x=>!selected.has(x.id))),hash(proposed.lexemes.filter(x=>!selected.has(x.id))));
for(const k of Object.keys(data).filter(k=>!['lexemes','sources'].includes(k)))assert.deepEqual(data[k],proposed[k]);
assert.deepEqual(proposed.sources.slice(0,data.sources.length),data.sources);
for(const target of [C.provenance,C.docs,C.transaction])assert(!L.fs.existsSync(L.at(target)),'Fresh output required: '+target);
save('binding.json',{schema:1,status:'bound_actual_root_authorized_validated_baseline',recorded_at:new Date().toISOString(),exclusive_window:'confirmed-by-root',
 validation:{path:a['--validation'],raw_sha256:a['--validation-sha'],json_sha256:hash(v)},technical_review:{path:a['--technical-review'],raw_sha256:a['--technical-review-sha']},
 preparation_receipt_raw_sha256:raw(local('preparation-receipt.json')),proposal_raw_sha256:raw(local('delivery-proposal.json')),test_patches_raw_sha256:raw(local('test-patches.json')),
 registry_before_sha256:hash(data),registry_after_sha256:hash(proposed),baseline_inputs:inputs,composite_baseline:composite,
 target_preimage_sha256:Object.fromEntries([C.target,C.sources,...C.tests].map(p=>[p,raw(p)])),
 other_lexemes_json_sha256:hash(data.lexemes.filter(x=>!selected.has(x.id))),expressions_json_sha256:hash(data.expressions),courses_json_sha256:hash(data.courses),themes_json_sha256:hash(data.themes),
 proposed_audit:{summary:audit.summary,errors:0,warnings:audit.warnings.length},production_mutated:false});
console.log(JSON.stringify({binding:local('binding.json'),raw_sha256:raw(local('binding.json')),registry_before_sha256:hash(data),registry_after_sha256:hash(proposed),production_mutated:false}));
