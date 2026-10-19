'use strict';
// Unexecuted memory-only probe. Root supplies the actual reviewed input and read-only adapter.
const assert=require('node:assert/strict');
const api=require('./commit.cjs');
const COMMIT_SHA='b522c987354d2e526cc9194b0dd5239b2592b07aa30f4ddd7bd16261e2c3c087';
const clone=v=>JSON.parse(JSON.stringify(v));

function runProbe(input,io,invocation){
  assert.equal(invocation.source_sha256,COMMIT_SHA);
  assert.equal(api.sha(io.read(api.constants.SELF)),COMMIT_SHA,'Frozen commit source drift');
  const reads=new Map(),existence=new Map(),results=[];
  const observed={
    read(p){const b=io.read(p),r={path:p,bytes:b.length,sha256:api.sha(b)};if(reads.has(p))assert.deepEqual(r,reads.get(p),'Input changed during probe');else reads.set(p,r);return b;},
    exists(p){const exists=io.exists(p);if(existence.has(p))assert.equal(exists,existence.get(p),'Existence changed during probe');else existence.set(p,exists);return exists;},
    list:p=>io.list(p)
  };
  function check(name,fn,pattern=null){
    try{
      if(pattern){assert.throws(fn,pattern,name);results.push({name,passed:true,expected_rejection:true});}
      else{fn();results.push({name,passed:true,expected_rejection:false});}
    }catch(error){error.probe_cases=[...results,{name,passed:false,expected_rejection:pattern!==null}];error.probe_real_inputs=[...reads.values()];throw error;}
  }
  let baseline;
  check('exact actual reviewed input passes read-only validation',()=>{baseline=api.validate(input,observed,invocation);});
  function variant(){
    const value=clone(input),overrides=new Map(),present=new Map();
    const adapter={read:p=>overrides.has(p)?overrides.get(p):observed.read(p),exists:p=>present.has(p)?present.get(p):observed.exists(p),list:p=>observed.list(p)};
    const put=(descriptor,value)=>{const b=api.encode(value);overrides.set(descriptor.path,b);descriptor.bytes=b.length;descriptor.sha256=api.sha(b);};
    const review=()=>JSON.parse(adapter.read(value.independent_review.path));
    // This is an isolated synthetic reviewer envelope for negative guard checks, never a disk review.
    const seal=()=>{const r=review();r.contract_sha256=api.sha(api.encode(value.contract));put(value.independent_review,r);};
    return {value,overrides,present,adapter,put,review,seal};
  }
  function reject(name,mutate,pattern,seal=true){
    const v=variant();mutate(v);if(seal)v.seal();
    check(name,()=>api.validate(v.value,v.adapter,invocation),pattern);
  }
  check('wrong repository is rejected',()=>api.validate(input,observed,{...invocation,repository_root:'C:/uworks/tesisgame'}),/Wrong repository/);
  check('wrong exclusive token is rejected',()=>api.validate(input,observed,{...invocation,token:'0'.repeat(64)===invocation.token?'1'.repeat(64):'0'.repeat(64)}),/token mismatch/);
  reject('wrong dispatcher is rejected',v=>{v.value.dispatcher='Another writer';},/Codex root/);
  reject('wrong author is rejected',v=>{v.value.author='Another author';},/Codex morph_review/);
  reject('recovery cannot use commit dispatch',v=>{v.value.recovery=true;},/Recovery is a separate/);
  reject('nonexclusive writer window is rejected',v=>{v.value.writer_window='shared';},/root-exclusive/);
  for(const reviewer of [undefined,'','Codex morph_review','CODEX ROOT']){
    reject('invalid reviewer '+String(reviewer),v=>{const r=v.review();if(reviewer===undefined)delete r.reviewer;else r.reviewer=reviewer;v.put(v.value.independent_review,r);},/reviewer|required|own source|Dispatcher/);
  }
  reject('unaccepted independent review is rejected',v=>{const r=v.review();r.accepted=false;v.put(v.value.independent_review,r);},/false|true/);
  reject('review contract mismatch is rejected',v=>{v.value.contract.expected_input_count++;},/different contract/,false);
  reject('empty source witnesses are rejected',v=>{v.value.contract.source_witnesses=[];},/source witnesses/);
  reject('missing helper witness is rejected',v=>{v.value.contract.source_witnesses=v.value.contract.source_witnesses.filter(r=>r.path!==api.constants.HELPER);},/source witnesses|Missing source witness/);
  reject('changed source witness is rejected',v=>{v.value.contract.source_witnesses.find(r=>r.path==='tools/validate-theme-motion.cjs').sha256='0'.repeat(64);},/Changed source\/input/);
  reject('old failed candidate revision is rejected',v=>{v.value.contract.candidate.directory='build/professional-english/shopping-bag-projected-validation-r01';},/fresh reviewed candidate/);
  reject('candidate outside the exact family is rejected',v=>{v.value.contract.candidate.directory='build/professional-english/arbitrary';},/fresh reviewed candidate/);
  reject('supplement outside actual candidate is rejected',v=>{v.value.contract.candidate.dependency_supplements[0].path='build/professional-english/arbitrary.json';},/Supplement outside/);
  reject('empty additional closure is rejected',v=>{v.value.contract.candidate.dependency_supplements=[];},/additional dependency closure/);
  reject('incorrect final union count is rejected',v=>{v.value.contract.expected_input_count--;},/Incomplete input count/);
  reject('dropped historical input pin is rejected',v=>{
    const d=v.value.contract.candidate.input,c=JSON.parse(v.adapter.read(d.path));delete c.expected_inputs['assets/audio/bgm/spring.wav'];v.put(d,c);v.value.contract.expected_inputs_sha256=api.pinHash(c.expected_inputs);
  },/input union differs/);
  function receiptCase(name,edit,pattern){reject(name,v=>{const s=v.value.contract.candidate,r=JSON.parse(v.adapter.read(s.receipt.path));edit(r,s);v.put(s.receipt,r);s.root_command.receipt_sha256=s.receipt.sha256;},pattern);}
  receiptCase('failed actual candidate is rejected',r=>{r.ok=false;},/Candidate did not pass/);
  receiptCase('candidate error is rejected',r=>{r.error='Synthetic failure';},/Candidate has error/);
  receiptCase('zero callbacks are rejected',(r,s)=>{r.callbacks=[];s.expected_callbacks=0;},/callback count/);
  receiptCase('incomplete callbacks are rejected',r=>{r.callbacks.pop();},/Incomplete candidate callbacks/);
  receiptCase('candidate source mismatch is rejected',r=>{r.source_sha256='0'.repeat(64);},/815e238/);
  receiptCase('candidate audit errors are rejected',r=>{r.audit.errors=1;},/1|0/);
  reject('failed root candidate command is rejected',v=>{v.value.contract.candidate.root_command.exit_code=1;},/Candidate command failed/);
  for(const[p,label]of [[api.constants.ATTEMPT,'Consumed root attempt'],[api.constants.TRANSACTION,'Existing journal'],['build/professional-english/transactions/active-transaction.json','Existing transaction lock']]){
    reject('existing '+label+' is rejected',v=>{v.present.set(p,true);},new RegExp(label));
  }
  reject('existing new image is rejected',v=>{v.present.set(baseline.changes.find(r=>r.path.startsWith('professional-media/')).path,true);},/Addition already exists/);
  reject('replacement preimage drift is rejected',v=>{v.overrides.set(baseline.changes.find(r=>r.before!==null).path,Buffer.from('drift'));},/Replacement preimage drift/);
  reject('protected non-target input drift is rejected',v=>{v.overrides.set('docs/assets/jelly-garden.json',Buffer.from('drift'));},/Changed source\/input/);
  reject('missing finalized artifacts are rejected',v=>{v.value.contract.finalized=[];},/two finalized artifacts/);
  reject('changed target commitment is rejected',v=>{v.value.contract.target_commitment_sha256='0'.repeat(64);},/target commitment mismatch/);
  reject('additional evidence outside prefix is rejected',v=>{v.value.contract.evidence_additions.push({target:'docs/unrelated.json',source:v.value.contract.finalized[0].source});},/outside final evidence prefix/);
  reject('ancestor evidence targets are rejected',v=>{
    const prefix='docs/assets/sources/shopping-bag-delivery-review-2026-10-17/final-evidence/__synthetic_probe_ancestor';
    v.value.contract.evidence_additions.push({target:prefix,source:v.value.contract.finalized[0].source},{target:prefix+'/child.json',source:v.value.contract.finalized[0].source});
  },/Ancestor target overlap/);
  for(const p of ['../escape','C:/escape','a\\b','nul.txt','a/COM1','a?.txt','a/\0b','a /b','x.','/x','x//y']){
    check('unsafe path '+JSON.stringify(p),()=>api.relative(p),/Unsafe|Non-normalized/);
  }
  check('case-folded duplicate targets are rejected',()=>api.noOverlap(['docs/a.json','DOCS/A.JSON']),/Duplicate target/);
  check('ancestor targets are rejected',()=>api.noOverlap(['docs/a','docs/a/b.json']),/Ancestor target overlap/);
  check('transaction-history target is rejected',()=>api.noOverlap([api.constants.TRANSACTION+'/state.json']),/transaction history/);
  check('source ancestor overlap is rejected',()=>api.assertEvidenceSeparate(['docs/evidence'],['docs/evidence/source.json']),/overlaps input evidence/);
  check('source descendant overlap is rejected',()=>api.assertEvidenceSeparate(['docs/evidence/source.json'],['docs/evidence']),/overlaps input evidence/);

  // A complete synthetic journal exercises verifier semantics without calling the transaction helper.
  const transaction=api.constants.TRANSACTION,files=new Map(),manifest=baseline.target_manifest;
  const plan={schema:1,repository_root:invocation.repository_root,allowed_paths:manifest.map(r=>r.path).sort((a,b)=>a.toLowerCase().localeCompare(b.toLowerCase())),entries:manifest};
  const prepared={schema:1,plan,plan_sha256:api.sha(api.encode(plan)),entries:manifest.map((r,i)=>({...r,backup:r.before===null?null:'backups/'+String(i).padStart(4,'0')+'.bin',staged:'staged/'+String(i).padStart(4,'0')+'.bin'}))};
  const preparedBytes=api.encode(prepared),preparedHash=api.sha(preparedBytes);files.set(transaction+'/prepared.json',preparedBytes);
  baseline.changes.forEach((c,i)=>{files.set(c.path,c.after);files.set(transaction+'/'+prepared.entries[i].staged,c.after);if(c.before!==null)files.set(transaction+'/'+prepared.entries[i].backup,c.before);});
  let sequence=0,previous=null,lastPath;
  function append(status,details={}){sequence++;lastPath=transaction+'/states/'+String(sequence).padStart(6,'0')+'-'+status+'.json';const b=api.encode({schema:1,sequence,status,prepared_sha256:preparedHash,previous_state_sha256:previous,recorded_at:'synthetic-memory-only',...details});files.set(lastPath,b);previous=api.sha(b);}
  append('prepared');manifest.forEach((r,index)=>{if(!r.noop)append('applying',{path:r.path,work:'work/00000000-0000-0000-0000-000000000000.bin'});append(r.noop?'noop':'applied',{index,path:r.path});});
  append('committed',{targets:manifest.map(r=>({path:r.path,...r.after,noop:r.noop}))});
  const expected={transaction_dir:transaction,plan_sha256:prepared.plan_sha256,prepared_sha256:preparedHash,state:{path:lastPath,sha256:previous},target_manifest:manifest};
  const memory=source=>({read(p){assert(source.has(p),'Missing synthetic file: '+p);return source.get(p);},exists:p=>source.has(p),list:p=>[...source.keys()].filter(f=>f.startsWith(p+'/')).map(f=>f.slice(p.length+1))});
  check('complete synthetic committed journal passes',()=>api.verifyCommittedJournal(memory(files),expected));
  const tampered=new Map(files),changedFinal=JSON.parse(tampered.get(lastPath));changedFinal.recorded_at='rewritten';tampered.set(lastPath,api.encode(changedFinal));
  check('self-consistent rewritten terminal state is rejected',()=>api.verifyCommittedJournal(memory(tampered),expected),/Trusted final state hash mismatch/);
  const broken=new Map(files);broken.delete(transaction+'/states/000001-prepared.json');
  check('missing journal state is rejected',()=>api.verifyCommittedJournal(memory(broken),expected),/Incomplete journal state history/);
  check('missing trusted final state hash is rejected',()=>api.verifyCommittedJournal(memory(files),{...expected,state:{path:lastPath}}),/Trusted committed-state hash/);
  const afterDrift=new Map(files);afterDrift.set(manifest[0].path,Buffer.from('drift'));
  check('journal target afterimage drift is rejected',()=>api.verifyCommittedJournal(memory(afterDrift),expected),/Changed source\/input/);
  const stageDrift=new Map(files);stageDrift.set(transaction+'/'+prepared.entries[0].staged,Buffer.from('drift'));
  check('journal stage drift is rejected',()=>api.verifyCommittedJournal(memory(stageDrift),expected),/Changed source\/input/);
  const locked=new Map(files);locked.set('build/professional-english/transactions/active-transaction.json',Buffer.from('{}'));
  check('active journal lock is rejected',()=>api.verifyCommittedJournal(memory(locked),expected),/lock remains active/);

  for(const[p,r]of reads){const b=io.read(p);assert.equal(b.length,r.bytes,'Real file length changed during probe');assert.equal(api.sha(b),r.sha256,'Real file changed during probe: '+p);}
  for(const[p,exists]of existence)assert.equal(io.exists(p),exists,'Real existence changed during probe: '+p);
  return {schema:1,status:'memory_guards_passed',source_sha256:COMMIT_SHA,production_mutated:false,project_or_native_execution:false,transaction_helper_executed:false,cases:results,real_read_count:reads.size,real_existence_count:existence.size,unchanged_real_inputs:[...reads.values()],scope:'Read-only validation of actual reviewed inputs plus isolated memory mutations. Synthetic reviews and journals provide guard evidence only; no transaction, loaded-registry audit or persisted acceptance.'};
}
module.exports={runProbe};
