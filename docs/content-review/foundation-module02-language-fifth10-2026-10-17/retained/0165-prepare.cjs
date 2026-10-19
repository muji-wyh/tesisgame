'use strict';
// Unexecuted root-only scratch preparation. No project module, test, native, browser or transaction dispatch.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {files:testFiles,transform}=require('./test-transforms.cjs');
const root=path.resolve(__dirname,'../../..');
const owned=path.resolve(root,'build/professional-english/shopping-bag-delivery-preparation-r02');
assert.equal(path.resolve(__dirname),owned);assert(root.toLowerCase().startsWith('q:'+path.sep));assert.equal(path.resolve(process.cwd()),root);
assert.deepEqual(process.argv.slice(2),['--root-dispatch','confirmed-actual-fourth10-persisted']);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),hash=value=>sha(JSON.stringify(value));
const file=relative=>{assert(typeof relative==='string'&&!path.isAbsolute(relative)&&!relative.includes('\\')&&!relative.split('/').includes('..'));const absolute=path.resolve(root,relative);assert(absolute.startsWith(root+path.sep));return absolute;};
const bytes=relative=>fs.readFileSync(file(relative)),read=relative=>JSON.parse(bytes(relative));
const bindingPath='build/professional-english/shopping-bag-delivery-preparation-r02/actual-baseline-binding.json';
const binding=read(bindingPath);
assert.equal(binding.schema,1);assert.equal(binding.status,'root_confirmed_actual_fourth10_persisted_baseline');
assert(typeof binding.root_confirmation==='string'&&binding.root_confirmation.length>20);
assert.equal(binding.fourth10.actual_commit_confirmed,true);assert.equal(binding.fourth10.actual_persisted_validation_confirmed,true);
for(const key of ['production_writers_yielded','new_production_targets_absent','final_inputs_frozen'])assert.equal(binding.guards[key],true);
function verifyPin(pin){assert(pin&&/^[a-f0-9]{64}$/.test(pin.raw_sha256));const value=bytes(pin.path);assert.equal(value.length,pin.bytes,pin.path);assert.equal(sha(value),pin.raw_sha256,pin.path);return value;}
for(const name of ['committed_receipt','committed_journal','persisted_validation_receipt']){
  const pin=binding.fourth10[name],value=JSON.parse(verifyPin(pin));assert(Array.isArray(pin.success_assertions)&&pin.success_assertions.length>0);
  for(const assertion of pin.success_assertions){assert(Array.isArray(assertion.keys)&&assertion.keys.length);assert.deepEqual(assertion.keys.reduce((v,k)=>v?.[k],value),assertion.expected,name);}
}
assert(Array.isArray(binding.input_files)&&binding.input_files.length>0);assert.equal(new Set(binding.input_files.map(row=>row.path)).size,binding.input_files.length);
const pins=new Map(binding.input_files.map(row=>[row.path,row]));
function guardedRead(relative){assert(pins.has(relative),'Missing final actual input: '+relative);return verifyPin(pins.get(relative));}
const parse=relative=>JSON.parse(guardedRead(relative));
const proposal='build/professional-english/shopping-bag-delivery-proposal-r01';
const proposalInventory=read(proposal+'/inventory.json');assert.equal(sha(bytes(proposal+'/inventory.json')),'5289682bdc2ebe875adac1f70b7985fe2dd665d4ade232b89b4386f26341716e');
for(const item of proposalInventory.files){const value=bytes(proposal+'/'+item.path);assert.equal(value.length,item.bytes);assert.equal(sha(value),item.sha256);}
const reviewPath='build/professional-english/shopping-bag-proposal-review-r01/review.json';assert.equal(sha(bytes(reviewPath)),'f56ba6b21b583e4ebb59b933ca82b982394512be31400f1c2fb6e0cf83407f8f');
assert.equal(read(reviewPath).status,'exact_asset_and_entry_proposal_accepted_for_final_rebase_only');
const evidence=read(proposal+'/evidence-lock.json');for(const item of evidence.files){const value=bytes(item.path);assert.equal(value.length,item.bytes);assert.equal(sha(value),item.sha256);}
for(const pin of binding.input_files)verifyPin(pin);
const sourceNames=['prepare.cjs','test-transforms.cjs','README.md','CALL-GRAPH.md','TRANSACTION.md','actual-baseline-binding.template.json'];
for(const name of sourceNames)guardedRead('build/professional-english/shopping-bag-delivery-preparation-r02/'+name);
const catalog=parse('data/professional/catalog.json');
const resourcePath=resource=>{assert(resource.startsWith('res://'));return resource.slice(6);};
const before={catalog,themes:parse(resourcePath(catalog.themes)).profiles,sources:parse(resourcePath(catalog.sources)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
for(const info of catalog.courses)before.courses.push(parse(resourcePath(info.manifest)));
for(const [key,origin,resources] of [['lexemes','lexemeOrigins',catalog.lexeme_files],['expressions','expressionOrigins',catalog.expression_files]])for(const resource of resources){const envelope=parse(resourcePath(resource));assert.equal(envelope.schema_version,1);for(const entry of envelope[key]){before[key].push(entry);before[origin][entry.id]=resource;}}
const patch=read(proposal+'/patch.proposed.json');assert.equal(patch.id,'shopping-bag.goods-carrier.n');
const selected=before.lexemes.filter(entry=>entry.id===patch.id);assert.equal(selected.length,1);assert.deepEqual(selected[0],patch.before);assert.equal(hash(selected[0]),patch.before_sha256);
assert.equal(hash(patch.after),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');
assert.deepEqual(patch.after.media.image,read(proposal+'/image-descriptor.proposed.json'));
const protect=entry=>{const copy=structuredClone(entry);delete copy.media.image;delete copy.editorial_notes;return copy;};
assert.deepEqual(protect(patch.before),protect(patch.after));assert.equal(hash(protect(patch.before)),patch.protected_fields_sha256);
let notes=patch.before.editorial_notes;assert.equal(patch.note_change.replacements.length,3);for(const change of patch.note_change.replacements){assert.equal(notes.split(change.before).length,2);notes=notes.replace(change.before,change.after);}assert.equal(notes,patch.after.editorial_notes);
const resource=read(proposal+'/resource.json'),image=bytes(proposal+'/media/'+path.basename(resource.path));
assert.equal(sha(image),resource.sha256);assert.equal(image.length,resource.compressed_bytes);assert.equal(image.readUInt32BE(16),resource.width);assert.equal(image.readUInt32BE(20),resource.height);assert.equal(resource.decoded_bytes,resource.width*resource.height*8);
const protectedMedia=read(proposal+'/protected-media-observation.json').media;
assert.equal(protectedMedia.filter(row=>row.kind==='image').length,8);assert.equal(protectedMedia.filter(row=>row.kind==='audio').length,12);
for(const row of protectedMedia){const entry=before.lexemes.find(value=>value.id===row.sense_id);assert.deepEqual(entry.media[row.kind],row.descriptor);assert.equal(hash(entry.media[row.kind]),row.descriptor_json_sha256);const value=guardedRead(row.file.path);assert.equal(sha(value),row.file.sha256);assert.equal(value.length,row.file.bytes);}
assert.equal(before.lexemes.filter(entry=>entry.media.image.status==='integrated').length,8);assert.equal(before.lexemes.filter(entry=>entry.media.audio.status==='integrated').length,12);
const next=structuredClone(before);next.lexemes[next.lexemes.findIndex(entry=>entry.id===patch.id)]=structuredClone(patch.after);
const lexicalFile='data/professional/lexemes/retail-pilot.json',lexicalBefore=guardedRead(lexicalFile);
const original=lexicalBefore.toString('utf8'),newline=original.includes('\r\n')?'\r\n':'\n';
const serializeEntry=entry=>JSON.stringify(entry,null,2).split('\n').map(line=>'    '+line).join(newline);
const oldText=serializeEntry(patch.before),newText=serializeEntry(patch.after);assert.equal(original.split(oldText).length,2,'Unique exact bag object with current formatting required');
const lexicalAfter=Buffer.from(original.replace(oldText,newText),'utf8'),parsedAfter=JSON.parse(lexicalAfter);
const parsedBefore=JSON.parse(lexicalBefore);assert.equal(parsedAfter.lexemes.length,parsedBefore.lexemes.length);
for(let i=0;i<parsedBefore.lexemes.length;i++)assert.deepEqual(parsedAfter.lexemes[i],parsedBefore.lexemes[i].id===patch.id?patch.after:parsedBefore.lexemes[i]);
const protectedState={other_lexemes_json_sha256:hash(before.lexemes.filter(entry=>entry.id!==patch.id))};
for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])protectedState[key+'_json_sha256']=hash(before[key]);
const record=read(proposal+'/production-provenance-template.json');
record.status='prepared_afterimage_pending_final_integration_review_and_actual_delivery';
record.accepted_proposal={inventory:{path:proposal+'/inventory.json',raw_sha256:sha(bytes(proposal+'/inventory.json'))},review:{path:reviewPath,raw_sha256:sha(bytes(reviewPath))},image_descriptor:{path:proposal+'/image-descriptor.proposed.json',raw_sha256:sha(bytes(proposal+'/image-descriptor.proposed.json'))}};
record.before_registry_sha256=hash(before);record.after_registry_sha256=hash(next);record.protected_media=protectedMedia;record.protected_state=protectedState;
record.lineage.fourth10_committed_receipt=binding.fourth10.committed_receipt;
record.lineage.fourth10_persisted_validation_receipt=binding.fourth10.persisted_validation_receipt;
record.lineage.actual_post_fourth10_baseline={path:bindingPath,raw_sha256:sha(bytes(bindingPath)),registry_json_sha256:hash(before)};
record.audit.integration_proposal_accepted=true;
// Actual bag commit/verification fields intentionally remain null/false in this construction-stage record.
const newTargets=[resource.path,'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json','docs/assets/professional-retail-shopping-bag.md'];
for(const target of newTargets)assert(!fs.existsSync(file(target)),'New production target already exists: '+target);
const transformed=testFiles.map(target=>({target,before:guardedRead(target),result:transform(target,guardedRead(target))}));
const output=path.join(owned,'execution-r01');assert(!fs.existsSync(output),'Preparation is single-use; preserve any prior attempt');
fs.mkdirSync(output);
const save=(name,value)=>fs.writeFileSync(path.join(output,name),Buffer.isBuffer(value)?value:typeof value==='string'?value:JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const targetPlan=[];
save('execution-start.json',{schema:1,status:'started',recorded_at:new Date().toISOString(),actual_binding_sha256:sha(bytes(bindingPath)),project_code_executed:false});
let finalStatus='failed';
try{
  save('retail-pilot.json.before',lexicalBefore);save('retail-pilot.json.after',lexicalAfter);
  targetPlan.push({path:lexicalFile,operation:'replace',before_sha256:sha(lexicalBefore),after_sha256:sha(lexicalAfter),artifact:'retail-pilot.json.after'});
  for(const item of transformed){const stem=path.basename(item.target);save(stem+'.before',item.before);save(stem+'.after',item.result.bytes);targetPlan.push({path:item.target,operation:'replace',before_sha256:sha(item.before),after_sha256:sha(item.result.bytes),artifact:stem+'.after'});}
  save(path.basename(resource.path),image);targetPlan.push({path:resource.path,operation:'add_absent',after_sha256:sha(image),artifact:path.basename(resource.path)});
  save('production-provenance.prepared.json',record);
  save('production-document.prepared.md',bytes(proposal+'/production-document-template.md'));
  targetPlan.push({path:newTargets[1],operation:'add_absent_pending_actual_stage_finalization',artifact:'production-provenance.prepared.json',final_transaction_bytes_frozen:false});
  targetPlan.push({path:newTargets[2],operation:'add_absent_pending_actual_stage_finalization',artifact:'production-document.prepared.md',final_transaction_bytes_frozen:false});
  save('test-edit-ledger.json',{schema:1,status:'prepared_not_executed',files:transformed.map(item=>({path:item.target,edits:item.result.edits,appended_tests:item.result.appended_tests}))});
  save('target-plan.json',{schema:1,status:'scratch_afterimages_not_commit_authorization',targets:targetPlan,source_registry_delta:false,module_manifest_delta:false,native_or_browser_dispatch:false});
  save('projection-observation.json',{schema:1,status:'raw_json_and_bytes_only_no_project_audit_or_tests',before_registry_sha256:hash(before),after_registry_sha256:hash(next),protected_state:protectedState,
    counts_before:{images:8,audio:12},counts_after:{images:9,audio:12},all_modules_remain_draft:next.courses.every(course=>course.modules.every(module=>module.status==='draft')),
    actual_validator_module_not_loaded:true,tests_executed:false,native_replayed:false,production_mutated:false});
  for(const pin of binding.input_files)verifyPin(pin);
  const artifacts=fs.readdirSync(output).sort().map(name=>({file:name,raw_sha256:sha(fs.readFileSync(path.join(output,name))),bytes:fs.statSync(path.join(output,name)).size}));
  save('preparation-receipt.json',{schema:1,status:'prepared_pending_independent_source_and_afterimage_review',actual_binding:{path:bindingPath,raw_sha256:sha(bytes(bindingPath))},artifacts,
    complete_final_transaction:false,production_provenance_and_document_require_actual_stage_finalization:true,project_or_test_execution:false,production_mutated:false});
  finalStatus='prepared_pending_independent_review';
}catch(error){save('failed-attempt.json',{schema:1,status:'failed',recorded_at:new Date().toISOString(),error:error.stack||String(error),production_mutated:false,instruction:'Preserve this attempt and sources; any post-dispatch correction needs a fresh revision.'});throw error;}
finally{save('execution-end.json',{schema:1,status:finalStatus,recorded_at:new Date().toISOString(),production_mutated:false});}
console.log(JSON.stringify({status:finalStatus,output:path.relative(root,output).replaceAll('\\','/'),project_or_test_execution:false,production_mutated:false}));
