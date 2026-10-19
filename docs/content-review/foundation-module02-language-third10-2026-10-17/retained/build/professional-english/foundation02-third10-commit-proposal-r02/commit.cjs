'use strict';
// UNEXECUTED proposal. Root must supply a separately reviewed, exact input manifest.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E=require('./evidence-contract.cjs');const {C,at,raw,read,sha,hash,encode}=E;
function main(){
  assert.equal(path.resolve(__dirname).toLowerCase(),at(C.own).toLowerCase(),'Run only the original reviewed proposal.');
  assert.equal(path.resolve(process.cwd()).toLowerCase(),path.resolve(C.root).toLowerCase());
  assert.equal(process.argv.length,8);
  const args=Object.fromEntries([[process.argv[2],process.argv[3]],[process.argv[4],process.argv[5]],[process.argv[6],process.argv[7]]]);
  E.exactPaths(Object.keys(args).map(k=>k.replace(/^--/,'')),['input','input-sha256','root-window-token']);
  assert.match(args['--input-sha256'],/^[a-f0-9]{64}$/);assert.equal(raw(args['--input']),args['--input-sha256']);
  const manifest=read(args['--input']);assert.equal(sha(args['--root-window-token']),manifest.root_window_token_sha256);
  const output=C.own+'/execution-r01';assert(!fs.existsSync(at(output)),'Never replay an attempted commit.');fs.mkdirSync(at(output));
  const write=(name,value)=>fs.writeFileSync(at(output+'/'+name),Buffer.isBuffer(value)?value:encode(value),{flag:'wx'});
  const sourceNames=['commit.cjs','evidence-contract.cjs','committed-evidence.test.cjs','INPUTS.md','root-commit-input.example.json','author-inventory.json'];
  const sourceFiles=()=>sourceNames.map(n=>({path:C.own+'/'+n,sha256:raw(C.own+'/'+n)}));
  const start={schema:1,status:'root_commit_dispatch_recorded',started_at:new Date().toISOString(),root_commit_input:{path:args['--input'],sha256:args['--input-sha256']},root_commit_input_sha256:args['--input-sha256'],source_files:sourceFiles(),raw_token_retained:false};
  write('execution-start.json',start);
  let committed=false;
  try{
    const bundle=E.loadBundle(manifest);assert.equal(raw(C.helper),C.helper_sha256);
    const projection=require(at(C.prep+'/projection.cjs')),transforms=require(at(C.prep+'/test-transforms.cjs'));
    const p=projection.project();assert.deepEqual(p.record,bundle.preparedRecord);assert.equal(hash(p.before),bundle.binding.source_baseline.registry_before_sha256);assert.equal(hash(p.next),bundle.binding.source_baseline.registry_after_sha256);
    const changes=[];
    for(const row of bundle.binding.production_replacements){
      const before=fs.readFileSync(at(row.before_artifact)),after=fs.readFileSync(at(row.after_artifact));
      assert.equal(sha(before),row.before_sha256);assert.equal(sha(after),row.after_sha256);assert(fs.readFileSync(at(row.path)).equals(before));
      const candidate=p.proposed_files.find(v=>v.path===row.path);const recomputed=candidate?candidate.after:transforms.transform(row.path,before).bytes;
      assert(recomputed.equals(after),'Recomputed afterimage mismatch: '+row.path);changes.push({path:row.path,before,after});
    }
    E.exactPaths(changes.map(r=>r.path),C.replacements);
    const add=(file,bytes)=>{assert(file===C.provenance||file.startsWith(C.docs+'/'));assert(!fs.existsSync(at(file)),'New file already exists.');changes.push({path:file,before:null,after:Buffer.from(bytes)});};
    const retained=bundle.refs.map(r=>({source:r.path,path:C.docs+'/retained/'+r.path,sha256:r.sha256}));
    for(const row of retained)add(row.path,fs.readFileSync(at(row.source)));
    add(C.docs+'/root-commit-input.json',fs.readFileSync(at(args['--input'])));
    for(const name of ['evidence-contract.cjs','committed-evidence.test.cjs'])add(C.docs+'/'+name,fs.readFileSync(at(C.own+'/'+name)));
    add(C.docs+'/retained-files.json',encode({schema:1,files:retained}));
    const record={...p.record,status:'integrated_language_outputs_require_committed_journal',production_mutated:true,integrated_on:'2026-10-17',
      lineage:{root_commit_input:{path:C.docs+'/root-commit-input.json',sha256:args['--input-sha256']},prepared_binding:manifest.prepared_binding,prepared_review:bundle.binding.prepared_review,validation_witness:manifest.validation_witness,validation_source_timing:bundle.witness.baseline_source_timing,candidate_only_additional_inputs:bundle.extraInputs,commit_technical_review:manifest.commit_technical_review,registry_before_sha256:hash(p.before),registry_after_sha256:hash(p.next)},retained_files:retained,
      integration_guards:{transaction_path:C.transaction,helper:{path:C.helper,sha256:C.helper_sha256},completion_requires_committed_journal:true,persisted_test:C.docs+'/committed-evidence.test.cjs',scope:'Language fields and bounded delivery metadata only; no new human, specialist, expression, morphology, media, module or release approval.'}};
    add(C.provenance,encode(record));
    const inventory={schema:1,status:'transaction_afterimage_inventory_excluding_self_and_postcommit_evidence',files:changes.filter(r=>r.path.startsWith(C.docs+'/')||r.path===C.provenance).map(r=>({path:r.path,sha256:sha(r.after),bytes:r.after.length})).sort((a,b)=>a.path.localeCompare(b.path)),self_excluded:true,postcommit_evidence_files:C.postcommit_files.map(n=>C.docs+'/'+n)};
    add(C.docs+'/inventory.json',encode(inventory));
    E.exactPaths(changes.map(r=>r.path),[...C.replacements,C.provenance,...inventory.files.filter(r=>r.path!==C.provenance).map(r=>r.path),C.docs+'/inventory.json']);
    const verify=()=>{
      const api=require(at('tools/validate-professional-content.cjs'));assert.deepEqual(api.loadProfessionalContent(C.root),p.next);
      for(const row of changes)assert(fs.readFileSync(at(row.path)).equals(row.after),row.path);
      const replaced=new Set(C.replacements);for(const [file,expected] of Object.entries(bundle.binding.current_inputs))if(!replaced.has(file))assert.equal(raw(file),expected,file);
      for(const [file,expected] of Object.entries(bundle.extraInputs))assert.equal(raw(file),expected,file);
      for(const r of bundle.refs)assert.equal(raw(r.path),r.sha256,r.path);
    };
    const helper=require(at(C.helper));
    const options={repositoryRoot:path.resolve(C.root),transactionDir:at(C.transaction),allowedPaths:changes.map(r=>at(r.path)),changes:changes.map(r=>({...r,path:at(r.path)})),verify};
    const described=helper.describePlan(options);
    const intent={schema:1,status:'root_authorized_plan_ready_for_guarded_commit',root_commit_input_sha256:args['--input-sha256'],prepared_binding_sha256:C.binding_sha256,plan_sha256:described.planSha256,descriptor:described.descriptor};
    write('transaction-intent.json',intent);
    // Recheck every evidence pin and current input immediately before the sole helper call.
    E.loadBundle(manifest);projection.verifyInputs();assert.deepEqual(sourceFiles(),start.source_files);
    const result=helper.commitTransaction(options);assert.equal(result.status,'committed');assert.equal(result.committed,true);committed=true;verify();
    const receipt={schema:1,status:'committed',finished_at:new Date().toISOString(),root_commit_input_sha256:args['--input-sha256'],prepared_binding_sha256:C.binding_sha256,registry_after_sha256:hash(p.next),provenance_sha256:raw(C.provenance),source_files_after:sourceFiles(),result,persisted_suite_execution_claim:false};
    assert.deepEqual(receipt.source_files_after,start.source_files);E.verifyCommittedJournal(intent,receipt);
    write('commit-receipt.json',receipt);
    // These three records become knowable only after the journal commits. They are exclusive new evidence writes, never replacements.
    const postFiles=[];
    for(const name of C.postcommit_files.filter(n=>n!=='postcommit-inventory.json')){const destination=C.docs+'/'+name;assert(!fs.existsSync(at(destination)));const bytes=fs.readFileSync(at(output+'/'+name));fs.writeFileSync(at(destination),bytes,{flag:'wx'});postFiles.push({path:destination,sha256:sha(bytes),bytes:bytes.length});}
    const post={schema:1,status:'committed_evidence_copied_no_persisted_suite_claim',files:postFiles,transaction_plan_sha256:result.planSha256};
    fs.writeFileSync(at(C.docs+'/postcommit-inventory.json'),encode(post),{flag:'wx'});write('postcommit-inventory.json',post);
    console.log(JSON.stringify({committed:true,transaction:C.transaction,receipt:output+'/commit-receipt.json',persisted_test:C.docs+'/committed-evidence.test.cjs',persisted_checks_still_required:true},null,2));
  }catch(error){write('failure.json',{schema:1,failed_at:new Date().toISOString(),committed,transaction_result:error.transactionResult||null,error:error.stack||String(error),instruction:'Preserve this attempt and any journal; do not rerun or automatically recover. Root must inspect the exact failure state.'});throw error;}
}
if(require.main===module)main();
module.exports={main};
