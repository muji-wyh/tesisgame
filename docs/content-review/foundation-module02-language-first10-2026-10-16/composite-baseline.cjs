'use strict';
// Narrow lineage for this delivery: immutable R30 plus two reviewed, focused changes.
module.exports=function validateComposite(L,file,sha){
 const {assert,raw,read,hash,api,root,fs,at}=L;
 const supervisor='build/professional-english/foundation-module01-language-review/supervisor-reconsideration-r01';
 const controller='build/professional-english/professional-play-reentrancy-r01';
 const pinned={
  'build/professional-english/continuation-validation-r30.json':'59db6d773240cd58ab8873472050515894f2586557921551434f7b4c5451bc55',
  [supervisor+'/binding.json']:'0b64efc3103b95f80f884e1759a5fe323cb49e8d499fa4d4e26b60fd8bad71fd',
  [supervisor+'/transaction-prepared.json']:'141728469da320a0e35f1fb48d547417928855f1a7b60b6ba49a2e78af5813df',
  [supervisor+'/transaction-committed.json']:'1f8b94876adb6d7530ccee0d954e7fbc8e7bfbac1d4f7ecb52d92e13cfc422ed',
  [supervisor+'/focused-validation-r01.json']:'ad950690b35a7ffaa847c461cbf5e4a10c73753c691771bbb39a89de1929cbe4',
  [supervisor+'/accepted-language.json']:'0eab2b7ec5f16ead8cbf32b09aa5a5fb1be4e5e68b6ac4e8a4e0f9b2daad02cd',
  [controller+'/validation-receipt.json']:'8b8f1f8cb4b317a250167968b7a58e6a0809895875f35989aba7b03bba0bac78',
  [controller+'/root-static-review-r01.json']:'906b7d41d583a63664437666552ecfd099915d61f2cca91b5eccaa9cf60bf7a5',
  [controller+'/change-journal.json']:'fd224457cf41465fd247fa6125319e541e5f814830eb2332698366737257fee4',
  [controller+'/execution-input-inventory.json']:'36e6c8ac536f79d651f92d003d18d1775f68c08209a6bf050d7b5531c1495371'
 };
 assert.equal(file,'build/professional-english/continuation-validation-r30.json');assert.equal(sha,pinned[file]);
 for(const[p,h]of Object.entries(pinned))assert.equal(raw(p),h,p);
 const v=read(file);assert.equal(v.ok,true);assert.deepEqual(v.changed_measured_inputs,[]);assert.deepEqual(v.before_input_sha256,v.after_input_sha256);assert.equal(Object.keys(v.after_input_sha256).length,676);assert.equal(v.measured_input_count,676);assert.equal(v.registry_before_sha256,v.registry_after_sha256);
 assert.deepEqual(v.runs.map(x=>x.name),['node','native','native-audio']);
 for(const r of v.runs){assert.equal(r.status,0);assert.equal(r.error,null);assert.equal(r.signal,null);assert.equal(raw(r.log),r.log_sha256);if(r.name==='node'){assert.equal(r.tests,233);assert.equal(r.pass,233);assert.equal(r.fail,0);assert.equal(r.skipped,0);assert.equal(r.cancelled,0);}else{assert(r.checks>0);assert.equal(r.failures,0);}}
 const binding=read(supervisor+'/binding.json'),prepared=read(supervisor+'/transaction-prepared.json'),committed=read(supervisor+'/transaction-committed.json'),focused=read(supervisor+'/focused-validation-r01.json');
 assert.equal(binding.baseline_path,file);assert.equal(binding.baseline_raw_sha256,sha);assert.equal(binding.registry_sha256,v.registry_after_sha256);assert.deepEqual(binding.inputs,v.after_input_sha256);assert.equal(binding.accepted_language_raw_sha256,pinned[supervisor+'/accepted-language.json']);
 assert.equal(prepared.registry_before_sha256,v.registry_after_sha256);assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,pinned[supervisor+'/transaction-prepared.json']);assert.deepEqual(committed.writes,prepared.writes);assert.equal(committed.registry_after_sha256,prepared.registry_expected_sha256);
 assert.equal(focused.ok,true);assert.equal(focused.status,0);assert.equal(focused.error,null);assert.deepEqual(focused.counts,{tests:27,pass:27,fail:0,cancelled:0,skipped:0});assert.equal(raw(focused.log),focused.log_sha256);assert.equal(focused.registry_before_sha256,committed.registry_after_sha256);assert.equal(focused.registry_after_sha256,committed.registry_after_sha256);
 assert.deepEqual(committed.writes.map(x=>x.path),['data/professional/lexemes/foundation-module01.json','data/professional/sources.json','data/professional/provenance/foundation-module01-supervisor-language-2026-10-16.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs']);
 const expected={...v.after_input_sha256},deltas=[];
 for(const w of committed.writes){assert.equal(expected[w.path]??null,w.before_sha256,w.path);assert.equal(raw(w.path),w.after_sha256,w.path);expected[w.path]=w.after_sha256;deltas.push({...w,reason:'Accepted supervisor language transaction with 27 focused checks.'});}
 const cv=read(controller+'/validation-receipt.json'),cr=read(controller+'/root-static-review-r01.json'),ci=read(controller+'/execution-input-inventory.json'),cj=read(controller+'/change-journal.json');
 assert.equal(cv.ok,true);assert.equal(cv.current_checks,31);assert.equal(cv.current_failures,0);assert.equal(cv.original_observations,17);assert.equal(cv.original_invariant_failures,14);assert.equal(cv.expected_original_reproduction,true);assert.equal(cv.inputs_unchanged,true);assert.deepEqual(cv.changed_paths,[]);assert.equal(cv.error,null);assert.equal(cv.guarded_input_count,ci.files.length);assert.equal(ci.files.length,24);assert.equal(cr.accepted_for_stated_scope,true);assert.deepEqual(cr.findings,[]);
 assert.equal(raw(controller+'/native.log'),cv.log_sha256);assert.equal(raw(controller+'/current-report.json'),cv.current_report_sha256);assert.equal(raw(controller+'/original-reproduction.json'),cv.original_report_sha256);
 for(const row of cr.reviewed_files)assert.equal(raw(row.path),row.raw_sha256,row.path);
 for(const row of ci.files)assert.equal(raw(row.path),row.sha256,row.path);
 assert.deepEqual(cj.scope,['scripts/professional_play.gd','tests/godot/professional_play_tests.gd']);assert.deepEqual(cv.production_scope,cj.scope);
 for(const w of cj.files){assert.equal(raw(w.preimage),w.sha256);if(Object.hasOwn(expected,w.path))assert.equal(expected[w.path],w.sha256,w.path);const post=ci.files.find(x=>x.path===w.path);assert(post);expected[w.path]=post.sha256;deltas.push({path:w.path,before_sha256:w.sha256,after_sha256:post.sha256,previously_measured:Object.hasOwn(v.after_input_sha256,w.path),reason:'Root accepted controller fix with 31 focused checks and saved-preimage reproduction.'});}
 // Detect added or removed inputs in the same production trees measured by R30.
 const discovered=[];function collect(dir){for(const e of fs.readdirSync(at(dir),{withFileTypes:true})){const p=dir+'/'+e.name;if(e.isDirectory())collect(p);else if(/\.(?:json|gd|cjs)$/.test(p))discovered.push(p);}}
 for(const dir of ['data/professional','data/vocabulary/morphology','scripts','tools'])collect(dir);
 const isTree=p=>['data/professional/','data/vocabulary/morphology/','scripts/','tools/'].some(prefix=>p.startsWith(prefix));
 assert.deepEqual(discovered.sort(),Object.keys(expected).filter(isTree).sort(),'Unexpected production input addition or removal');
 for(const[p,h]of Object.entries(expected))assert.equal(raw(p),h,p);
 const data=api.loadProfessionalContent(root);assert.equal(hash(data),committed.registry_after_sha256);
 const inputs=Object.fromEntries(Object.keys(expected).sort().map(p=>[p,raw(p)]));
 const composite={schema:1,status:'current_inputs_verified_against_historical_r30_and_two_accepted_changes',ok:true,historical_full_validation:{path:file,raw_sha256:sha,registry_sha256:v.registry_after_sha256},evidence:Object.entries(pinned).map(([path,raw_sha256])=>({path,raw_sha256})),deltas,current_registry_sha256:hash(data),current_input_count:Object.keys(inputs).length,current_input_sha256:inputs,full_combined_validation_of_current_state:false,scope:'R30 is historical. Current registry and every measured input match only the committed supervisor and accepted controller changes. R31 remains required after module02 integration.'};
 return {v,data,inputs,composite};
};
