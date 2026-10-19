'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),vm=require('node:vm');
const root=path.resolve(__dirname,'../../../..');
const {loadProfessionalContent,auditProfessionalContent}=require(path.join(root,'tools/validate-professional-content.cjs'));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const jsonHash=value=>hash(JSON.stringify(value));
const read=file=>fs.readFileSync(path.join(root,file));
const local=file=>fs.readFileSync(path.join(__dirname,file));
const serialize=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
const save=(file,value)=>fs.writeFileSync(path.join(__dirname,file),serialize(value),{flag:'wx'});
assert.ok(!fs.existsSync(path.join(__dirname,'transaction-prepared.json')),'One-shot delivery: do not replay.');
const binding=JSON.parse(local('binding.json')),record=JSON.parse(local('accepted-language.json')),tests=JSON.parse(local('test-patches.json'));
assert.equal(hash(local('accepted-language.json')),binding.accepted_language_raw_sha256);
const technical=JSON.parse(local('technical-review-r01.json'));
assert.equal(technical.accepted,true,'Separate technical review must finish before mutation.');
assert.ok(Array.isArray(technical.reviewed_files)&&technical.reviewed_files.length>0);
for(const row of technical.reviewed_files) assert.equal(hash(read(row.path)),row.raw_sha256,row.path);
for(const file of ['accepted-language.json','test-patches.json','deliver.cjs']) assert.ok(technical.reviewed_files.some(row=>row.path.endsWith('/'+file)),file+' must be reviewed');
const baseline=JSON.parse(read(binding.baseline_path));
assert.equal(hash(read(binding.baseline_path)),binding.baseline_raw_sha256);assert.equal(baseline.ok,true);
for(const [file,sha] of Object.entries(binding.inputs)) assert.equal(hash(read(file)),sha,file);
const beforeData=loadProfessionalContent(root);assert.equal(jsonHash(beforeData),binding.registry_sha256);
assert.deepEqual(beforeData.lexemes.find(e=>e.id===record.patches[0].id),record.patches[0].before);
const scope=record.delivery_scope,patch=record.patches[0];
const lexemes=JSON.parse(read(scope.lexeme_file)),sources=JSON.parse(read(scope.sources_file));
assert.equal(lexemes.lexemes.filter(e=>e.id===patch.id).length,1);
lexemes.lexemes[lexemes.lexemes.findIndex(e=>e.id===patch.id)]=patch.after;
assert.ok(record.sources.every(s=>!sources.sources.some(before=>before.id===s.id)));sources.sources.push(...record.sources);
const expectedData=structuredClone(beforeData);expectedData.lexemes[expectedData.lexemes.findIndex(e=>e.id===patch.id)]=patch.after;expectedData.sources.push(...record.sources);
assert.equal(jsonHash(expectedData.lexemes.filter(e=>e.id!==patch.id)),record.protected_context.all_other_lexemes_sha256);
assert.equal(jsonHash(expectedData.expressions),record.protected_context.all_expression_registry_sha256);
assert.equal(jsonHash(expectedData.courses),record.protected_context.all_courses_sha256);
assert.equal(jsonHash(expectedData.themes),record.protected_context.all_themes_sha256);
const audit=auditProfessionalContent({data:expectedData});assert.equal(audit.errors.length,0);assert.equal(audit.summary.reviewed_lexemes,111);assert.equal(audit.summary.ready_modules,0);
const docs=scope.review_directory;
assert.ok(!fs.existsSync(path.join(root,docs)),'Retained review evidence must use a fresh directory.');
const retainedNames=['accepted-language.json','binding.json','test-patches.json','technical-review-r01.json','prepare.cjs','prepare-tests.cjs','deliver.cjs','professional-content.test.cjs.before','professional-content.test.cjs.after','professional-retail-morphology.test.cjs.before','professional-retail-morphology.test.cjs.after'];
record.status='integrated_independent_ai_language_acceptance';record.integrated_on='2026-10-16';
record.technical_review={path:docs+'/technical-review-r01.json',raw_sha256:hash(local('technical-review-r01.json')),language_independence_claim:false};
record.retained_files=retainedNames.map(name=>({path:docs+'/'+name,raw_sha256:hash(local(name))}));
record.integration_guards={prepared_path:docs+'/transaction-prepared.json',committed_path:docs+'/transaction-committed.json',baseline_input_count:Object.keys(binding.inputs).length,registry_before_sha256:binding.registry_sha256,registry_after_sha256:jsonHash(expectedData),one_shot:true};
const writes=[{path:scope.lexeme_file,bytes:serialize(lexemes)},{path:scope.sources_file,bytes:serialize(sources)},{path:scope.provenance_file,bytes:serialize(record)}];
for(const patch of tests.patches){
  assert.equal(hash(read(patch.file)),patch.before_sha256);
  const bytes=local(path.basename(patch.file)+'.after');assert.equal(hash(bytes),patch.after_sha256);
  new vm.Script(bytes.toString('utf8'),{filename:patch.file});
  writes.push({path:patch.file,bytes});
}
assert.ok(!fs.existsSync(path.join(root,scope.provenance_file)));
const prepared={schema:1,status:'prepared',recorded_at:new Date().toISOString(),registry_before_sha256:binding.registry_sha256,registry_expected_sha256:jsonHash(expectedData),baseline_inputs:Object.keys(binding.inputs).length,writes:writes.map(w=>({path:w.path,before_sha256:fs.existsSync(path.join(root,w.path))?hash(read(w.path)):null,after_sha256:hash(w.bytes)})),audit:{summary:audit.summary,errors:0,warnings:audit.warnings.length}};
const originals=new Map(writes.map(w=>[w.path,fs.existsSync(path.join(root,w.path))?read(w.path):null]));
fs.mkdirSync(path.join(__dirname,'preimages'),{recursive:false});
for(const [file,bytes] of originals) if(bytes) fs.writeFileSync(path.join(__dirname,'preimages',path.basename(file)),bytes,{flag:'wx'});
save('transaction-prepared.json',prepared);
fs.mkdirSync(path.join(root,docs),{recursive:true});
for(const name of retainedNames)fs.writeFileSync(path.join(root,docs,name),local(name),{flag:'wx'});
fs.writeFileSync(path.join(root,docs,'transaction-prepared.json'),local('transaction-prepared.json'),{flag:'wx'});
const written=[];
try{
  for(const item of writes){
    const target=path.join(root,item.path),temporary=target+'.supervisor-reconsideration-r01.tmp';
    assert.ok(!fs.existsSync(temporary));fs.writeFileSync(temporary,item.bytes,{flag:'wx'});fs.renameSync(temporary,target);written.push(item);
  }
  assert.deepEqual(loadProfessionalContent(root),expectedData);
  for(const item of prepared.writes)assert.equal(hash(read(item.path)),item.after_sha256,item.path);
  for(const [file,sha] of Object.entries(binding.inputs))if(!writes.some(w=>w.path===file))assert.equal(hash(read(file)),sha,file);
  const committed={schema:1,status:'committed',recorded_at:new Date().toISOString(),prepared_sha256:hash(local('transaction-prepared.json')),registry_after_sha256:jsonHash(loadProfessionalContent(root)),writes:prepared.writes,preserved_baseline_inputs:Object.keys(binding.inputs).length-writes.filter(w=>binding.inputs[w.path]).length,unrelated_entries_preserved:beforeData.lexemes.length-1,other_gates_preserved:true,git_commit_created:false};
  save('transaction-committed.json',committed);fs.writeFileSync(path.join(root,docs,'transaction-committed.json'),local('transaction-committed.json'),{flag:'wx'});
  console.log(JSON.stringify(committed));
}catch(error){
  const restored=[];
  for(const item of written.reverse()){
    if(hash(read(item.path))!==hash(item.bytes))throw new Error('Concurrent drift during rollback: '+item.path+'; original failure: '+error.message);
    const previous=originals.get(item.path);if(previous===null)fs.unlinkSync(path.join(root,item.path));else fs.writeFileSync(path.join(root,item.path),previous);restored.push(item.path);
  }
  save('transaction-failed.json',{schema:1,status:'failed_rolled_back',error:error.message,restored});throw error;
}
