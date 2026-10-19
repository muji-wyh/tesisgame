'use strict';
// Built-in-only authorship: reads exact current bytes and writes binding files in this directory.
// It never imports project modules, transforms tests, prepares afterimages, runs tests, or mutates production.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..'),own='build/professional-english/shopping-bag-delivery-preparation-r02';
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(path.resolve(process.cwd()),root);assert.equal(path.resolve(root,own),__dirname);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),hash=v=>sha(JSON.stringify(v));
function at(p){assert(typeof p==='string'&&p.length&&!p.includes('\\')&&!path.isAbsolute(p));assert.equal(path.relative(root,path.resolve(root,p)).replaceAll('\\','/'),p);assert(!p.startsWith('../'));return path.resolve(root,p);}
const raw=p=>fs.readFileSync(at(p)),json=p=>JSON.parse(raw(p).toString('utf8').replace(/^\uFEFF/,''));
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
for(const name of ['actual-baseline-binding.json','retained-evidence-allowlist.json','retained-evidence-pins.json','author-inventory.json'])assert(!fs.existsSync(path.join(__dirname,name)),name+' already exists; preserve consumed authorship');
assert(!fs.existsSync(path.join(__dirname,'execution-r01')),'Preparation must remain unexecuted');
const proposal='build/professional-english/shopping-bag-delivery-proposal-r01',proposalReview='build/professional-english/shopping-bag-proposal-review-r01/review.json';
const fourthDocs='docs/content-review/foundation-module02-language-fourth10-2026-10-17';
const commitPath=fourthDocs+'/commit-receipt.json',validationBase='build/professional-english/foundation02-fourth10-persisted-validation-r01';
const receiptPath=validationBase+'/attempt-001/receipt.json',startPath=validationBase+'/attempt-001/start.json';
assert.equal(sha(raw(commitPath)),'96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
assert.equal(sha(raw(receiptPath)),'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
const commit=json(commitPath),receipt=json(receiptPath),start=json(startPath);
assert.equal(commit.status,'committed');assert.equal(commit.result.committed,true);assert.equal(commit.result.status,'committed');
assert.equal(commit.registry_after_sha256,'9a9b3c8665ce920fcddd584456e4ca47b8c365d8d2c43daacb9ea908c540ee1c');
assert.equal(receipt.ok,true);assert.equal(receipt.error,null);assert.equal(receipt.commands.length,4);assert.equal(receipt.checked_inputs,865);
assert.equal(receipt.committed_receipt.sha256,sha(raw(commitPath)));assert.equal(receipt.committed_receipt.path,commitPath);
const statePath=path.relative(root,commit.result.state.path).replaceAll('\\','/'),state=json(statePath);
assert.equal(sha(raw(statePath)),commit.result.state.sha256);assert.equal(state.status,'committed');assert.equal(state.prepared_sha256,commit.result.preparedSha256);
const commandArgs=[['tools/validate-professional-content.cjs'],['--test','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs'],['tools/run-godot.cjs','--headless','--path',root,'--script','res://tests/godot/professional_retail_morphology_tests.gd'],['--test',fourthDocs+'/committed-evidence.test.cjs']];
receipt.commands.forEach((r,i)=>{assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);assert.deepEqual(r.command.slice(1),commandArgs[i]);assert.equal(sha(raw(validationBase+'/attempt-001/'+r.log)),r.log_sha256);});
const pins=new Map(),origins=new Map();
function add(p,expected,category='additional_static_dependency'){
  const b=raw(p),h=sha(b);if(expected)assert.equal(h,expected,p);
  if(pins.has(p))assert.equal(pins.get(p).raw_sha256,h,p);else pins.set(p,{path:p,bytes:b.length,raw_sha256:h});
  if(!origins.has(p))origins.set(p,new Set());origins.get(p).add(category);return b;
}
function addJSON(p,expected,category){return JSON.parse(add(p,expected,category).toString('utf8').replace(/^\uFEFF/,''));}
function walk(p,category){assert(!fs.lstatSync(at(p)).isSymbolicLink());for(const name of fs.readdirSync(at(p)).sort()){const file=p+'/'+name,info=fs.lstatSync(at(file));assert(!info.isSymbolicLink());if(info.isDirectory())walk(file,category);else if(info.isFile())add(file,undefined,category);}}
assert.equal(Object.keys(start.expected_inputs).length,865);
for(const [p,h] of Object.entries(start.expected_inputs))add(p,h,'actual_fourth10_persisted_input');
add(commitPath,sha(raw(commitPath)),'actual_fourth10_success_lineage');add(receiptPath,sha(raw(receiptPath)),'actual_fourth10_success_lineage');add(startPath,undefined,'actual_fourth10_success_lineage');add(statePath,commit.result.state.sha256,'actual_fourth10_success_lineage');
add(validationBase+'/invoke.cjs',receipt.source_before,'actual_fourth10_success_lineage');
for(const r of receipt.commands)add(validationBase+'/attempt-001/'+r.log,r.log_sha256,'actual_fourth10_success_lineage');
walk(fourthDocs,'actual_fourth10_durable_evidence');
const transaction=path.dirname(path.dirname(statePath));
add(transaction+'/prepared.json',commit.result.preparedSha256,'actual_fourth10_success_lineage');add(transaction+'/intent.json',undefined,'actual_fourth10_success_lineage');
walk(transaction+'/states','actual_fourth10_committed_journal_chain');
for(const target of state.targets)add(target.path,target.sha256,'actual_fourth10_committed_target');
const inventory=addJSON(proposal+'/inventory.json','5289682bdc2ebe875adac1f70b7985fe2dd665d4ade232b89b4386f26341716e','accepted_bag_proposal');
for(const row of inventory.files){const b=add(proposal+'/'+row.path,row.sha256,'accepted_bag_proposal');assert.equal(b.length,row.bytes);}
const staticReview=addJSON(proposalReview,'f56ba6b21b583e4ebb59b933ca82b982394512be31400f1c2fb6e0cf83407f8f','accepted_bag_proposal');
assert.equal(staticReview.status,'exact_asset_and_entry_proposal_accepted_for_final_rebase_only');
for(const row of json(proposal+'/evidence-lock.json').files){const b=add(row.path,row.sha256,'accepted_bag_candidate_evidence');assert.equal(b.length,row.bytes);}
// The newly affected media suite reads these concrete retained source, audio and transaction records.
const mediaRecords=['retail-cart-basket-approved-audio','retail-pallet-image','retail-pallet-shelf-approved-audio','retail-bag-wrap-approved-audio','retail-shelf-image','retail-counter-image','retail-counter-checkout-approved-audio','retail-checkout-image','retail-barcode-image','retail-cash-register-image','retail-card-reader-barcode-approved-audio'];
for(const name of mediaRecords){
  const r=addJSON('data/professional/provenance/'+name+'-2026-10-16.json',undefined,'media_suite_provenance');
  if(r.resource)add(r.resource.path,r.resource.sha256,'protected_media_resource');
  if(r.retained_evidence)walk(r.retained_evidence,'media_suite_retained_evidence');
  for(const row of r.preserved_audio_files||[])add(row.path,row.sha256,'protected_historical_audio');
  for(const row of r.preserved_images||[])add(row.path,row.sha256,'protected_historical_images');
  if(r.preserved_collection_master)add(r.preserved_collection_master.path,r.preserved_collection_master.sha256,'protected_collection_master');
  for(const row of r.retained_files||[]){add(row.path,row.raw_sha256||row.sha256,'media_suite_retained_copy');if(row.source)add(row.source,row.raw_sha256||row.sha256,'media_suite_retained_original');}
  for(const p of [r.source_record,...(r.source_records||[])].filter(Boolean))add(p,undefined,'media_suite_source_record');
  if(r.lineage?.validation)add(r.lineage.validation,r.lineage.validation_raw_sha256,'media_suite_lineage');
  if(r.lineage?.counter_image_delivery)add(r.lineage.counter_image_delivery.path,r.lineage.counter_image_delivery.raw_sha256,'media_suite_lineage');
  if(r.approval){
    const accepted=addJSON(r.approval,r.approval_raw_sha256,'approved_audio_evidence');
    for(const out of accepted.outputs){for(const p of [out.presented_path,out.retained_wav])add(p,out.wav_sha256,'approved_audio_evidence');add(out.retained_mp3,out.source_mp3_sha256,'approved_audio_evidence');add(out.acquisition_receipt,out.acquisition_receipt_raw_sha256,'approved_audio_evidence');}
    for(const descriptor of [accepted.technical_qa,accepted.listening_request])if(descriptor?.path)add(descriptor.path,descriptor.raw_sha256||descriptor.sha256,'approved_audio_evidence');
    if(accepted.evidence?.human_record)add(accepted.evidence.human_record,accepted.evidence.human_record_raw_sha256,'approved_audio_evidence');
  }
  if(r.integration_guards?.transaction_path){const t=r.integration_guards.transaction_path;add(t+'/prepared.json',undefined,'historical_media_transaction');walk(t+'/states','historical_media_transaction');}
}
const content=add('tests/professional-content.test.cjs').toString('utf8'),morph=add('tests/professional-retail-morphology.test.cjs').toString('utf8').replace(/\r\n/g,'\n'),media=add('tests/professional-retail-media.test.cjs').toString('utf8');
const fourthPrep='build/professional-english/foundation02-fourth10-delivery-preparation-r02/execution-r01/';
for(const name of ['professional-content.test.cjs','professional-retail-morphology.test.cjs'])assert.equal(sha(raw('tests/'+name)),sha(raw(fourthPrep+name+'.after')));
const anchorCounts=[];
for(const [name,count] of [['beforeAttendanceLanguage',1],['beforeFoundation02SecondLanguage',2],['beforeFoundation02ThirdLanguage',4],['beforeFoundation02FourthLanguage',6]]){const anchor='source.lexemes.map('+name+')';assert.equal(content.split(anchor).length-1,count);anchorCounts.push({anchor,count});}
const lastAnchor='hash(source.lexemes.filter(entry=>!ids.has(entry.id))),c.all_other_lexemes_json_sha256';assert.equal(content.split(lastAnchor).length-1,1);anchorCounts.push({anchor:lastAnchor,count:1});
for(const source of [content,morph,media])assert.equal(source.split('function beforeFifth10(entry) {').length-1,1);
assert.equal(morph.split('function beforeCounterImage(entry) {').length-1,1);
assert.equal(morph.split('for (const patch of fifthRecord.patches) {\n    const entry = data.lexemes.find(item => item.id === patch.id);').length-1,1);
// Reconstruct only JSON envelopes in the loader's documented order; no project loader is imported.
const catalog=addJSON('data/professional/catalog.json'),res=v=>{assert(v.startsWith('res://'));return v.slice(6);};
const data={catalog,themes:addJSON(res(catalog.themes)).profiles,sources:addJSON(res(catalog.sources)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
for(const row of catalog.courses)data.courses.push(addJSON(res(row.manifest)));
for(const [key,origin,resources] of [['lexemes','lexemeOrigins',catalog.lexeme_files],['expressions','expressionOrigins',catalog.expression_files]])for(const resource of resources)for(const entry of addJSON(res(resource))[key]){data[key].push(entry);data[origin][entry.id]=resource;}
assert.equal(hash(data),commit.registry_after_sha256);
const patch=json(proposal+'/patch.proposed.json');assert.deepEqual(data.lexemes.find(r=>r.id===patch.id),patch.before);
const counts={overall_reviewed:data.lexemes.filter(r=>r.review.status==='reviewed').length,language_reviewed:data.lexemes.filter(r=>r.review.language==='reviewed').length,foundation02_language_reviewed:data.lexemes.filter(r=>data.lexemeOrigins[r.id]==='res://data/professional/lexemes/foundation-module02.json'&&r.review.language==='reviewed').length,images:data.lexemes.filter(r=>r.media.image.status==='integrated').length,audio:data.lexemes.filter(r=>r.media.audio.status==='integrated').length,ready_modules:data.courses.flatMap(r=>r.modules).filter(r=>r.status==='ready').length};
assert.deepEqual(counts,{overall_reviewed:148,language_reviewed:335,foundation02_language_reviewed:36,images:8,audio:12,ready_modules:0});
const retainedBase='docs/assets/sources/shopping-bag-delivery-review-2026-10-17',bindingPath=own+'/actual-baseline-binding.json';
const mappings=inventory.files.map(row=>({source:proposal+'/'+row.path,target:retainedBase+'/proposal/'+row.path}));
mappings.push({source:proposal+'/inventory.json',target:retainedBase+'/proposal/inventory.json'},{source:proposalReview,target:retainedBase+'/independent-proposal-review/review.json'});
for(const name of ['invoke.cjs','attempt-001/start.json','attempt-001/receipt.json','attempt-001/command-1.log','attempt-001/command-2.log','attempt-001/command-3.log','attempt-001/command-4.log'])mappings.push({source:validationBase+'/'+name,target:retainedBase+'/fourth10-persisted/'+name});
mappings.push({source:statePath,target:retainedBase+'/fourth10-committed-state.json'},{source:bindingPath,target:retainedBase+'/actual-baseline-binding.json'});
mappings.sort((a,b)=>a.target.localeCompare(b.target));assert.equal(mappings.length,27);assert.equal(new Set(mappings.map(r=>r.target.toLowerCase())).size,27);
for(const r of mappings)assert(!fs.existsSync(at(r.target)),'Durable target already exists: '+r.target);
for(const p of [json(proposal+'/resource.json').path,'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json','docs/assets/professional-retail-shopping-bag.md'])assert(!fs.existsSync(at(p)),p);
save('retained-evidence-allowlist.json',{schema:1,status:'explicit_individual_absent_copy_targets',files:mappings,hash_binding:'Exact source bytes are separately pinned in retained-evidence-pins.json after the self-contained baseline binding is written. Root source inventory pins both files. No directory wildcard or production write is authorized by this authorship.'});
walk(own+'/before-final-binding','preserved_unexecuted_initial_sources');
for(const name of ['prepare.cjs','test-transforms.cjs','README.md','CALL-GRAPH.md','TRANSACTION.md','actual-baseline-binding.template.json','author-final-binding.cjs','retained-evidence-allowlist.json'])add(own+'/'+name,undefined,'final_preparation_source');
const descriptor=(p,assertions)=>({...pins.get(p),success_assertions:assertions});
const success=(keys,expected)=>({keys,expected});
const binding={schema:1,status:'root_confirmed_actual_fourth10_persisted_baseline',root_confirmation:'Root directly confirmed actual fourth10 committed receipt 96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8 and persisted receipt f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7, the exclusive production writer window, and no further production mutation until this proposal is ready.',recorded_at:new Date().toISOString(),fourth10:{actual_commit_confirmed:true,actual_persisted_validation_confirmed:true,committed_receipt:descriptor(commitPath,[success(['status'],'committed'),success(['result','status'],'committed'),success(['result','committed'],true),success(['registry_after_sha256'],commit.registry_after_sha256)]),committed_journal:descriptor(statePath,[success(['status'],'committed'),success(['sequence'],268),success(['prepared_sha256'],commit.result.preparedSha256)]),persisted_validation_receipt:descriptor(receiptPath,[success(['ok'],true),success(['error'],null),success(['checked_inputs'],865),...receipt.commands.flatMap((r,i)=>[success(['commands',i,'exit_code'],0),success(['commands',i,'signal'],null),success(['commands',i,'error'],null)])},input_files:[...pins.values()].sort((a,b)=>a.path.localeCompare(b.path)),input_scope:'865 actual persisted fourth10 inputs, actual committed outputs/journal/receipt/logs, complete accepted bag proposal/evidence, concrete existing media-suite dependencies including preserved audio, and final preparation sources. Fresh exact bytes; no project code executed. Self binding, post-binding retention pins and author inventory are excluded from input_files to avoid circular hashes and are pinned by author inventory/root dispatch.',guards:{production_writers_yielded:true,new_production_targets_absent:true,final_inputs_frozen:true},observations:{registry_json_sha256:hash(data),json_reconstruction_only:true,counts,aggregate_history_anchor_count:14,aggregate_history_anchors:anchorCounts,current_shared_tests_exact_fourth10_afterimages:true,source_category_counts:Object.fromEntries([...new Set([...origins.values()].flatMap(v=>[...v]))].sort().map(category=>[category,[...origins.values()].filter(v=>v.has(category)).length])),project_or_test_execution:false,production_mutated:false}};
for(const row of binding.input_files){const b=raw(row.path);assert.equal(b.length,row.bytes);assert.equal(sha(b),row.raw_sha256,row.path);}
save('actual-baseline-binding.json',binding);
save('retained-evidence-pins.json',{schema:1,status:'exact_individual_absent_copy_targets',files:mappings.map(row=>{const b=raw(row.source);return {...row,bytes:b.length,raw_sha256:sha(b)};}),operation:'add_absent_exact_bytes',production_mutated:false});
const ownFiles=[];function inventoryWalk(rel=''){for(const name of fs.readdirSync(path.join(__dirname,rel)).sort()){const local=rel?rel+'/'+name:name,abs=path.join(__dirname,local);if(fs.statSync(abs).isDirectory())inventoryWalk(local);else{const b=fs.readFileSync(abs);ownFiles.push({path:local,bytes:b.length,raw_sha256:sha(b)});}}}inventoryWalk();
save('author-inventory.json',{schema:1,status:'frozen_actual_baseline_preparation_sources_pending_independent_review',files:ownFiles,input_count:binding.input_files.length,retained_individual_targets:27,total_prepared_targets:34,execution:false,project_or_test_execution:false,production_mutated:false,self_excluded:true});
console.log(JSON.stringify({status:'actual_binding_and_source_inventory_authored_no_preparation_execution',input_count:binding.input_files.length,registry_json_sha256:hash(data),binding_sha256:sha(raw(bindingPath)),inventory_sha256:sha(raw(own+'/author-inventory.json')),retained_individual_targets:27,production_mutated:false}));
