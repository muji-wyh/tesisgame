'use strict';
// Importing this file performs no reads or writes. Only run() dispatches a transaction.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const AUTHOR='Codex morph_review', ROOT_ID='q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const SELF='build/professional-english/shopping-bag-commit-proposal-r01/commit.cjs';
const PREP='build/professional-english/shopping-bag-delivery-preparation-r02';
const OUT=PREP+'/execution-r01';
const PRIOR='build/professional-english/shopping-bag-projected-validation-r01';
const MEDIA='build/professional-english/shopping-bag-projected-validation-r02';
const CANDIDATE_SOURCE_SHA='815e2387471801fbaeb148a1c27a668265fe352a6b3875b37b381b948bf03073';
const HELPER='build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs';
const TRANSACTION='build/professional-english/transactions/shopping-bag-image-r01';
const ATTEMPT='build/professional-english/shopping-bag-root-commit-r01/execution-r01';
const INPUT='build/professional-english/shopping-bag-root-commit-r01/input.json';
const FINAL_PREFIX='docs/assets/sources/shopping-bag-delivery-review-2026-10-17/final-evidence/';
const FINAL_TARGETS=['data/professional/provenance/retail-shopping-bag-image-2026-10-17.json','docs/assets/professional-retail-shopping-bag.md'];
const SUITES=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs'];
const BEFORE='9a9b3c8665ce920fcddd584456e4ca47b8c365d8d2c43daacb9ea908c540ee1c';
const AFTER='dcfe28d7c7c6048206b740459a65ce9b482ba2768d388b0b29d7ab31174ed1a0';
const PINS={
  [HELPER]:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
  [PREP+'/actual-baseline-binding.json']:'1506caf881745539b971881e978e5a5f60fc8de8640066169953f6ee45417da6',
  [OUT+'/target-plan.json']:'321b6ed0a4d0b66721b36c2d53de9bd3416277641fa1fd227650dd5a45321e98',
  [OUT+'/preparation-receipt.json']:'153b3071e6d24e51da2bd26cf39bb3e0873f684182d19fd289960ae88deab443',
  [OUT+'/projection-observation.json']:'4e1ea7e83606656a73af0258f27673456ba9c425f28d0f96635d0db79cec3177',
  [PRIOR+'/input.json']:'e391994e98771ff5148da8b8ff85fd55b6e5af885d8a371333a4a876a388e484',
  [PRIOR+'/dependency-supplement.json']:'08c8fbcf2d1b1427954a0e1951b216ae23e361184613e8b08c2bc874b3fa46d8',
  [MEDIA+'/input.json']:'0d25315b1d2ab178fbe4445d4412e54b7de03743d9f241822d14554f84900408',
  [MEDIA+'/dependency-supplement.json']:'b938822e5668fec48d5670af8faa208362befce63c53d96c814abd4c9663882d'
};
const VALIDATOR_FILES=['tools/validate-professional-content.cjs','tools/validate-theme-motion.cjs','tools/professional-picture-pools.cjs','web/professional-media.js'];
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const encode=v=>Buffer.from(JSON.stringify(v,null,2)+'\n');
const objectHash=v=>sha(JSON.stringify(v));
const pinHash=v=>sha(encode(Object.fromEntries(Object.entries(v).sort(([a],[b])=>a.localeCompare(b)))));
const nonempty=v=>typeof v==='string'&&v.trim().length>0;
function relative(p){
  assert.equal(typeof p,'string','Path must be a string');
  assert(p.length>0&&!/[\\:<>"|?*\x00-\x1f\x7f]/.test(p)&&!p.startsWith('/')&&!p.endsWith('/'),'Non-normalized path: '+p);
  for(const s of p.split('/'))assert(s&&s!=='.'&&s!=='..'&&!/[. ]$/.test(s)&&!/^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(s),'Unsafe path segment: '+p);
  return p;
}
function shaValue(h,label){assert.equal(typeof h,'string',label);assert.match(h,/^[0-9a-f]{64}$/,label);return h;}
function pinned(io,p,h){relative(p);shaValue(h,'Expected SHA256');const b=io.read(p);assert(Buffer.isBuffer(b),'Read adapter must return Buffer');assert.equal(sha(b),h,'Changed source/input: '+p);return b;}
function descriptor(io,r){assert(r&&typeof r==='object');assert(Number.isSafeInteger(r.bytes)&&r.bytes>=0,'Descriptor needs byte length');const b=pinned(io,r.path,r.sha256);assert.equal(b.length,r.bytes,'Descriptor length: '+r.path);return b;}
function readPinnedJson(io,p,h){return JSON.parse(pinned(io,p,h));}
function assertIndependent(name){assert(nonempty(name),'Independent reviewer required');assert.notEqual(name.trim().toLowerCase(),AUTHOR.toLowerCase(),'Author cannot approve own source');assert.notEqual(name.trim().toLowerCase(),'codex root','Dispatcher cannot be the independent reviewer');}
function overlaps(a,b){a=relative(a).toLowerCase();b=relative(b).toLowerCase();return a===b||a.startsWith(b+'/')||b.startsWith(a+'/');}
function targetRows(changes){return changes.map(c=>({path:c.path,before:c.before===null?null:{bytes:c.before.length,sha256:sha(c.before)},after:{bytes:c.after.length,sha256:sha(c.after)},noop:c.before!==null&&c.before.equals(c.after)}));}
function noOverlap(paths){
  const normalized=paths.map(relative).map(p=>p.toLowerCase());assert.equal(new Set(normalized).size,normalized.length,'Duplicate target');
  const forbidden=[TRANSACTION,ATTEMPT,'build/professional-english/transactions'];
  for(let i=0;i<normalized.length;i++){
    for(const f of forbidden)assert(normalized[i]!==f&&!normalized[i].startsWith(f+'/')&&!f.startsWith(normalized[i]+'/'),'Target overlaps transaction history');
    for(let j=0;j<i;j++)assert(!normalized[i].startsWith(normalized[j]+'/')&&!normalized[j].startsWith(normalized[i]+'/'),'Ancestor target overlap');
  }
}
function assertEvidenceSeparate(targets,evidence){for(const t of targets)for(const p of evidence)assert(!overlaps(t,p),'Target overlaps input evidence: '+t+' / '+p);}
function candidatePaths(spec){
  assert(spec&&typeof spec==='object','Exact candidate specification required');relative(spec.directory);
  const match=/^build\/professional-english\/shopping-bag-projected-validation-r(\d+)$/.exec(spec.directory);
  assert(match&&Number(match[1])>=3,'A fresh reviewed candidate revision is required; r01 failed and r02 is undispatched');
  assert.equal(spec.runner.path,spec.directory+'/run.cjs');assert.equal(spec.runner.sha256,CANDIDATE_SOURCE_SHA);
  assert.equal(spec.input.path,spec.directory+'/input.json');assert.equal(spec.receipt.path,spec.directory+'/attempt-001/receipt.json');
  assert(Array.isArray(spec.dependency_supplements)&&spec.dependency_supplements.length>0,'Explicit additional dependency closure required');
  const names=new Set();for(const r of spec.dependency_supplements){relative(r.path);assert(r.path.startsWith(spec.directory+'/'),'Supplement outside reviewed candidate directory');assert(!names.has(r.path),'Duplicate supplement');names.add(r.path);}
  return spec;
}
function readPreparation(io){
  const plan=readPinnedJson(io,OUT+'/target-plan.json',PINS[OUT+'/target-plan.json']);
  const receipt=readPinnedJson(io,OUT+'/preparation-receipt.json',PINS[OUT+'/preparation-receipt.json']);
  assert.equal(plan.targets.length,34);assert.equal(plan.targets.filter(t=>t.operation==='replace').length,4);
  assert.equal(receipt.status,'prepared_pending_independent_source_and_afterimage_review');
  assert.equal(receipt.production_mutated,false);assert.equal(receipt.project_or_test_execution,false);
  const artifacts=new Map();
  for(const r of receipt.artifacts){relative(r.file);assert(!artifacts.has(r.file),'Duplicate preparation artifact');artifacts.set(r.file,r);const b=pinned(io,OUT+'/'+r.file,r.raw_sha256);assert.equal(b.length,r.bytes);}
  return {plan,artifacts};
}
// Read-only: explicitly supplied artifacts and exact prepared targets produce Buffers.
function buildChanges(contract,io){
  const {plan,artifacts}=readPreparation(io);
  assert(Array.isArray(contract.finalized)&&contract.finalized.length===2,'Exactly two finalized artifacts required');
  assert.deepEqual(contract.finalized.map(r=>r.target).sort(),FINAL_TARGETS.slice().sort(),'Finalization target mismatch');
  const final=new Map(contract.finalized.map(r=>[r.target,r]));
  const changes=[];
  for(const row of plan.targets){
    relative(row.path);assert(artifacts.has(row.artifact),'Unrecorded prepared artifact');
    let after;
    if(FINAL_TARGETS.includes(row.path)){
      const r=final.get(row.path);after=descriptor(io,r.source);
      assert(r.source.path.startsWith('build/professional-english/'),'Final source must be a frozen build artifact');
      assert.notEqual(sha(after),artifacts.get(row.artifact).raw_sha256,'Construction-stage metadata is not final');
    }else{after=io.read(OUT+'/'+row.artifact);assert.equal(sha(after),row.after_sha256);if(row.bytes!==undefined)assert.equal(after.length,row.bytes);}
    let before=null;
    if(row.operation==='replace'){before=io.read(row.path);assert.equal(sha(before),row.before_sha256,'Replacement preimage drift: '+row.path);}
    else assert.equal(io.exists(row.path),false,'Addition already exists: '+row.path);
    changes.push({path:row.path,before,after});
  }
  assert(Array.isArray(contract.evidence_additions)&&contract.evidence_additions.length<=128,'Explicit evidence addition list required');
  for(const row of contract.evidence_additions){
    relative(row.target);assert(row.target.startsWith(FINAL_PREFIX),'Additional target is outside final evidence prefix');
    assert.equal(io.exists(row.target),false,'Evidence addition already exists');
    changes.push({path:row.target,before:null,after:descriptor(io,row.source)});
  }
  noOverlap(changes.map(c=>c.path));
  assert.equal(sha(encode(targetRows(changes))),contract.target_commitment_sha256,'Exact target commitment mismatch');
  return changes;
}
function assertCandidate(contract,io,candidateInput){
  const spec=candidatePaths(contract.candidate);
  const r=JSON.parse(descriptor(io,spec.receipt));
  assert.equal(r.schema,1);assert.equal(r.ok,true,'Candidate did not pass');assert.equal(r.error,null,'Candidate has error');
  assert.equal(r.source_sha256,spec.runner.sha256);assert.equal(r.input_sha256,spec.input.sha256);
  assert(Number.isSafeInteger(spec.expected_callbacks)&&spec.expected_callbacks>0,'Exact callback count required');
  assert.equal(r.callbacks.length,spec.expected_callbacks,'Incomplete candidate callbacks');
  const callbackNames=new Set();
  for(const row of r.callbacks){assert(SUITES.includes(row.file));assert.equal(row.passed,true);assert(nonempty(row.title));const key=row.file+'\0'+row.title;assert(!callbackNames.has(key),'Duplicate candidate callback');callbackNames.add(key);}
  for(const file of SUITES)assert(r.callbacks.some(row=>row.file===file),'Candidate omitted affected suite');
  assert.equal(r.audit.errors,0);assert.equal(r.audit.summary.integrated_word_images,9);assert.equal(r.audit.summary.integrated_word_audio,12);
  assert.equal(r.audit.summary.reviewed_lexemes,148);assert.equal(r.audit.summary.ready_modules,0);
  assert(Object.keys(r.observed_current_inputs).length>0,'Empty candidate read witness');
  for(const [p,h] of Object.entries(r.observed_current_inputs))assert.equal(candidateInput.expected_inputs[p],h,'Candidate observed unpinned input');
  assert.deepEqual(spec.root_command.args,['node',spec.runner.path,spec.runner.sha256,spec.input.sha256]);
  assert.equal(spec.root_command.exit_code,0,'Candidate command failed');assert.equal(spec.root_command.signal,null);assert.equal(spec.root_command.error,null);
  assert.equal(spec.root_command.receipt_sha256,spec.receipt.sha256,'Command witness receipt mismatch');
  return r;
}
function checkPins(io,inputs,changes=null){
  const after=new Map((changes||[]).map(c=>[c.path,sha(c.after)]));
  for(const [p,h]of Object.entries(inputs))pinned(io,p,after.get(p)||h);
}
function checkSources(io,witnesses){for(const r of witnesses)descriptor(io,r);}
function inputUnion(io,spec,candidateInput){
  const binding=readPinnedJson(io,PREP+'/actual-baseline-binding.json',PINS[PREP+'/actual-baseline-binding.json']);
  const prior=readPinnedJson(io,PRIOR+'/dependency-supplement.json',PINS[PRIOR+'/dependency-supplement.json']);
  const media=readPinnedJson(io,MEDIA+'/dependency-supplement.json',PINS[MEDIA+'/dependency-supplement.json']);
  assert.equal(binding.input_files.length,5085);assert.equal(prior.files.length,23);assert.equal(media.files.length,23);
  const union=Object.create(null),sizes=Object.create(null),folded=new Map();
  const add=rows=>{assert(Array.isArray(rows)&&rows.length>0);for(const r of rows){
    const p=relative(r.path),h=shaValue(r.raw_sha256||r.sha256,'Input SHA256');assert(Number.isSafeInteger(r.bytes)&&r.bytes>=0,'Input length required');
    if(r.raw_sha256&&r.sha256)assert.equal(r.raw_sha256,r.sha256,'Conflicting input hashes');
    const key=p.toLowerCase();if(folded.has(key))assert.equal(folded.get(key),p,'Case alias in input union');else folded.set(key,p);
    if(p in union){assert.equal(union[p],h,'Conflicting input pin');assert.equal(sizes[p],r.bytes,'Conflicting input length');}
    union[p]=h;sizes[p]=r.bytes;
  }};
  add(binding.input_files);add(prior.files);
  assert.equal(Object.keys(union).length,5097);assert.equal(pinHash(union),pinHash(readPinnedJson(io,PRIOR+'/input.json',PINS[PRIOR+'/input.json']).expected_inputs));
  add(media.files);assert.equal(Object.keys(union).length,5120);
  assert.equal(pinHash(union),pinHash(readPinnedJson(io,MEDIA+'/input.json',PINS[MEDIA+'/input.json']).expected_inputs));
  for(const r of spec.dependency_supplements)add(JSON.parse(descriptor(io,r)).files);
  assert(Object.keys(union).length>5120,'Missing additional callback dependency closure');
  assert.equal(pinHash(union),pinHash(candidateInput.expected_inputs),'Candidate input union differs from exact reviewed dependencies');
  return {pins:{...union},sizes:{...sizes}};
}
// Read-only and injection-friendly. io supplies read/exists only; no filesystem mutation.
function validate(input,io,invocation){
  assert.equal(String(invocation.repository_root).replaceAll('\\','/').toLowerCase(),ROOT_ID,'Wrong repository root');
  assert.equal(input.schema,1);assert.equal(input.status,'root_authorized_single_shopping_bag_commit');
  assert.equal(input.dispatcher,'Codex root');assert.equal(input.author,AUTHOR);assert.equal(input.writer_window,'root-exclusive');
  assert.equal(input.recovery,false,'Recovery is a separate explicitly reviewed action');
  assert.match(invocation.token,/^[0-9a-f]{64}$/,'Exclusive root token required');
  assert.equal(sha(invocation.token),input.exclusive_token_sha256,'Exclusive root token mismatch');
  assert.equal(input.contract.transaction_dir,TRANSACTION);assert.equal(input.contract.attempt_dir,ATTEMPT);
  assert.equal(io.exists(ATTEMPT),false,'Consumed root attempt');assert.equal(io.exists(TRANSACTION),false,'Existing journal requires recovery review');
  assert.equal(io.exists('build/professional-english/transactions/active-transaction.json'),false,'Existing transaction lock requires recovery review');
  const c=input.contract;
  assert.equal(c.registry_before_sha256,BEFORE);assert.equal(c.registry_after_sha256,AFTER);
  const review=JSON.parse(descriptor(io,input.independent_review));
  assert.equal(review.status,'accepted_exact_shopping_bag_commit_contract');assert.equal(review.accepted,true);assertIndependent(review.reviewer);
  assert.equal(review.contract_sha256,sha(encode(c)),'Independent review binds a different contract');
  const spec=candidatePaths(c.candidate);
  assert(Array.isArray(c.source_witnesses)&&c.source_witnesses.length>=7,'Nonempty ordered source witnesses required');
  const witnesses=new Map();
  for(const r of c.source_witnesses){relative(r.path);assert(!witnesses.has(r.path),'Duplicate source witness');witnesses.set(r.path,r);}
  for(const p of [SELF,HELPER,spec.runner.path,...VALIDATOR_FILES])assert(witnesses.has(p),'Missing source witness: '+p);
  assert.equal(witnesses.get(SELF).sha256,invocation.source_sha256,'Reviewed commit source mismatch');
  assert.equal(witnesses.get(HELPER).sha256,PINS[HELPER]);assert.deepEqual(witnesses.get(spec.runner.path),spec.runner);
  checkSources(io,c.source_witnesses);
  for(const[p,h]of Object.entries(PINS))pinned(io,p,h);
  const ci=JSON.parse(descriptor(io,spec.input));descriptor(io,spec.runner);
  assert.equal(ci.schema,1);
  assert.equal(ci.status,'root_accepted_prepared_afterimages_for_projected_validation');assert.equal(ci.registry_after_sha256,AFTER);
  assert.equal(ci.preparation_directory,OUT,'Wrong preparation directory');
  assert.equal(pinHash(ci.expected_inputs),c.expected_inputs_sha256,'Changed input-map commitment');
  const union=inputUnion(io,spec,ci);assert.equal(c.expected_input_count,Object.keys(union.pins).length,'Incomplete input count');
  for(const p of VALIDATOR_FILES)assert.equal(witnesses.get(p).sha256,union.pins[p],'Unbound validator closure');
  for(const r of ci.evidence_files)pinned(io,r.path,r.sha256);
  const candidate=assertCandidate(c,io,ci);
  const changes=buildChanges(c,io);
  const immutablePaths=[...Object.keys(PINS),...ci.evidence_files.map(r=>r.path),...c.source_witnesses.map(r=>r.path),input.independent_review.path,spec.input.path,spec.receipt.path,...spec.dependency_supplements.map(r=>r.path),...c.finalized.map(r=>r.source.path),...c.evidence_additions.map(r=>r.source.path),INPUT];
  assertEvidenceSeparate(changes.map(r=>r.path),immutablePaths);
  const replacementPaths=new Set(changes.filter(r=>r.before!==null).map(r=>r.path));assert.equal(replacementPaths.size,4);
  for(const p of replacementPaths)assert(p in union.pins,'Replacement absent from protected union');
  assertEvidenceSeparate(changes.map(r=>r.path),Object.keys(union.pins).filter(p=>!replacementPaths.has(p)));
  checkPins(io,union.pins);for(const[p,size]of Object.entries(union.sizes))assert.equal(io.read(p).length,size,'Protected input length changed: '+p);
  return {contract_sha256:sha(encode(c)),inputs:union.pins,evidence_files:ci.evidence_files,changes,target_manifest:targetRows(changes),candidate_callbacks:candidate.callbacks.length,source_witnesses:c.source_witnesses,input_union:{path:spec.input.path,sha256:spec.input.sha256,count:Object.keys(union.pins).length,pin_map_sha256:c.expected_inputs_sha256},unaffected_input_count:Object.keys(union.pins).length-replacementPaths.size};
}
// Built-in-only verifier. Persisted callers pin the receipt, then pass its exact state and manifest.
function verifyCommittedJournal(io,expected){
  assert.equal(expected.transaction_dir,TRANSACTION);shaValue(expected.plan_sha256,'Trusted plan hash');
  shaValue(expected.prepared_sha256,'Trusted prepared hash');shaValue(expected.state.sha256,'Trusted committed-state hash');
  assert.equal(io.exists('build/professional-english/transactions/active-transaction.json'),false,'Transaction lock remains active');
  noOverlap(expected.target_manifest.map(r=>r.path));
  const pb=io.read(TRANSACTION+'/prepared.json'),p=JSON.parse(pb);assert.equal(p.schema,1);
  assert.equal(sha(pb),expected.prepared_sha256,'Prepared journal hash mismatch');
  assert.equal(sha(encode(p.plan)),p.plan_sha256);assert.equal(p.plan_sha256,expected.plan_sha256);
  assert.equal(String(p.plan.repository_root).replaceAll('\\','/').toLowerCase(),ROOT_ID);
  assert.deepEqual(p.plan.entries,expected.target_manifest,'Journal targets differ from trusted manifest');
  assert.deepEqual(p.plan.allowed_paths,[...expected.target_manifest.map(r=>r.path)].sort((a,b)=>a.toLowerCase().localeCompare(b.toLowerCase())));
  assert.equal(p.entries.length,expected.target_manifest.length);
  p.entries.forEach((r,i)=>{
    const {path:target,before,after,noop}=r;assert.deepEqual({path:target,before,after,noop},expected.target_manifest[i]);
    assert.equal(r.staged,'staged/'+String(i).padStart(4,'0')+'.bin');
    assert.equal(r.backup,before===null?null:'backups/'+String(i).padStart(4,'0')+'.bin');
    for(const [file,d]of[[r.staged,after],[r.backup,before]])if(file!==null){const b=pinned(io,TRANSACTION+'/'+file,d.sha256);assert.equal(b.length,d.bytes);}
    const current=pinned(io,target,after.sha256);assert.equal(current.length,after.bytes);
  });
  const names=io.list(TRANSACTION+'/states').slice().sort();assert(names.length>0);let previous=null,final=null;
  const sequence=[{status:'prepared'}];
  expected.target_manifest.forEach((r,index)=>{
    if(!r.noop)sequence.push({status:'applying',path:r.path});
    sequence.push({status:r.noop?'noop':'applied',path:r.path,index});
  });sequence.push({status:'committed'});assert.equal(names.length,sequence.length,'Incomplete journal state history');
  names.forEach((name,i)=>{
    assert.match(name,/^\d{6}-[a-z-]+\.json$/);const b=io.read(TRANSACTION+'/states/'+name),s=JSON.parse(b);
    assert.equal(s.schema,1);assert.equal(s.sequence,i+1);assert.equal(name,String(i+1).padStart(6,'0')+'-'+s.status+'.json');
    assert.equal(s.prepared_sha256,sha(pb));assert.equal(s.previous_state_sha256,previous);
    for(const[k,v]of Object.entries(sequence[i]))assert.equal(s[k],v,'Journal transition mismatch');
    if(s.status==='applying')assert.match(s.work,/^work\/[0-9a-f-]+\.bin$/,'Invalid transaction work path');
    previous=sha(b);final=s;
  });
  assert.equal(final.status,'committed','Terminal state is not committed');
  assert.deepEqual(final.targets,expected.target_manifest.map(r=>({path:r.path,...r.after,noop:r.noop})));
  assert.equal(expected.state.path,TRANSACTION+'/states/'+names.at(-1),'Trusted final state path mismatch');
  assert.equal(previous,expected.state.sha256,'Trusted final state hash mismatch');
  return {status:'committed',prepared_sha256:sha(pb),plan_sha256:p.plan_sha256,state:{path:TRANSACTION+'/states/'+names.at(-1),sha256:previous},state_count:names.length,verified_targets:expected.target_manifest.length};
}
function realAdapter(root){
  const exists=f=>{try{fs.lstatSync(f);return true;}catch(error){if(error.code==='ENOENT')return false;throw error;}};
  const abs=p=>{relative(p);const full=path.resolve(root,p);assert(full.toLowerCase().startsWith(root.toLowerCase()+path.sep));let cursor=root;
    for(const s of p.split('/')){cursor=path.join(cursor,s);if(exists(cursor)){const st=fs.lstatSync(cursor);assert(!st.isSymbolicLink(),'Symlink/junction path: '+p);if(cursor!==full)assert(st.isDirectory());}}return full;};
  return {read:p=>{const f=abs(p);assert(fs.lstatSync(f).isFile(),'Expected regular file');return fs.readFileSync(f);},exists:p=>exists(abs(p)),list:p=>fs.readdirSync(abs(p)),abs};
}
function run(argv=process.argv.slice(2)){
  assert.equal(argv.length,4,'Expected source SHA, exact input path, input SHA and exclusive token');
  const [sourceHash,inputPath,inputHash,token]=argv;shaValue(sourceHash,'Source hash');shaValue(inputHash,'Input hash');assert.equal(inputPath,INPUT);
  const root=path.resolve(__dirname,'../../..');assert.equal(root.replaceAll('\\','/').toLowerCase(),ROOT_ID);
  assert(!fs.lstatSync(root).isSymbolicLink());const io=realAdapter(root);
  pinned(io,SELF,sourceHash);const input=JSON.parse(pinned(io,INPUT,inputHash));
  const context=validate(input,io,{source_sha256:sourceHash,token,repository_root:root});
  fs.mkdirSync(io.abs(ATTEMPT));const save=(name,v)=>fs.writeFileSync(io.abs(ATTEMPT+'/'+name),encode(v),{flag:'wx'});
  save('start.json',{schema:1,started_at:new Date().toISOString(),dispatcher:'Codex root',input:{path:INPUT,sha256:inputHash},source_sha256:sourceHash,exclusive_token_sha256:sha(token),contract_sha256:context.contract_sha256});
  let transaction=null;
  const immutableCheck=()=>{pinned(io,SELF,sourceHash);pinned(io,INPUT,inputHash);descriptor(io,input.independent_review);checkSources(io,context.source_witnesses);for(const[p,h]of Object.entries(PINS))pinned(io,p,h);for(const r of context.evidence_files)pinned(io,r.path,r.sha256);for(const r of [input.contract.candidate.input,input.contract.candidate.receipt,...input.contract.candidate.dependency_supplements])descriptor(io,r);for(const r of [...input.contract.finalized,...input.contract.evidence_additions])descriptor(io,r.source);};
  try{
    immutableCheck();checkPins(io,context.inputs);
    const helper=require(io.abs(HELPER));const loader=require(io.abs(VALIDATOR_FILES[0]));
    assert.equal(objectHash(loader.loadProfessionalContent(root)),BEFORE,'Actual loaded registry preimage mismatch');
    const changes=context.changes.map(c=>({...c,path:io.abs(c.path)}));
    const options={repositoryRoot:root,transactionDir:io.abs(TRANSACTION),allowedPaths:changes.map(c=>c.path),changes,
      verify:()=>{immutableCheck();checkPins(io,context.inputs,context.changes);assert.equal(objectHash(loader.loadProfessionalContent(root)),AFTER,'Actual loaded registry afterimage mismatch');}};
    const described=helper.describePlan(options);assert.deepEqual(described.descriptor.entries,context.target_manifest);
    save('intent.json',{schema:1,plan_sha256:described.planSha256,target_manifest:context.target_manifest,input_union:context.input_union});
    immutableCheck();checkPins(io,context.inputs);
    transaction=helper.commitTransaction(options);assert.equal(transaction.status,'committed');assert.equal(transaction.committed,true);assert.equal(transaction.planSha256,described.planSha256);
    const committedState={path:path.relative(root,transaction.state.path).replaceAll('\\','/'),sha256:transaction.state.sha256};
    const journal=verifyCommittedJournal(io,{transaction_dir:TRANSACTION,plan_sha256:transaction.planSha256,prepared_sha256:transaction.preparedSha256,state:committedState,target_manifest:context.target_manifest});
    immutableCheck();checkPins(io,context.inputs,context.changes);assert.equal(objectHash(loader.loadProfessionalContent(root)),AFTER);
    const receipt={schema:1,status:'committed',committed:true,finished_at:new Date().toISOString(),dispatcher:'Codex root',author:AUTHOR,input:{path:INPUT,sha256:inputHash},source_sha256:sourceHash,contract_sha256:context.contract_sha256,independent_review:input.independent_review,source_witnesses:context.source_witnesses,candidate_receipt:input.contract.candidate.receipt,candidate_callbacks:context.candidate_callbacks,input_union:context.input_union,unaffected_input_count:context.unaffected_input_count,transaction_dir:TRANSACTION,plan_sha256:transaction.planSha256,prepared_sha256:transaction.preparedSha256,state:committedState,target_manifest:context.target_manifest,journal,registry_before_sha256:BEFORE,registry_after_sha256:AFTER,persisted_validation_completed:false,persisted_validation_receipt:null};
    save('receipt.json',receipt);return receipt;
  }catch(error){save('failure.json',{schema:1,status:'failed',finished_at:new Date().toISOString(),error:error.stack||String(error),transaction:transaction||error.transactionResult||null,replay_allowed:false});throw error;}
}
module.exports={validate,buildChanges,verifyCommittedJournal,targetRows,pinHash,encode,sha,run,realAdapter,relative,noOverlap,assertEvidenceSeparate,candidatePaths,constants:{SELF,INPUT,ATTEMPT,TRANSACTION,HELPER,AUTHOR,BEFORE,AFTER}};
if(require.main===module){try{const r=run();console.log(JSON.stringify({status:r.status,targets:r.target_manifest.length,plan_sha256:r.plan_sha256,receipt_sha256:sha(encode(r))}));}catch(e){console.error(e.stack||String(e));process.exitCode=1;}}
