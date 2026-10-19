'use strict';
// Read-only evidence contract. No serializer, test suite, native process or transaction runs on import.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const C={
  root:'Q:/.codex/worktrees/current-age-vocabulary/tesisgame',
  own:'build/professional-english/foundation02-third10-commit-proposal-r02',
  prep:'build/professional-english/foundation02-third10-delivery-preparation-r01',
  review:'build/professional-english/foundation02-third10-prepared-review-r01',
  validation:'build/professional-english/foundation02-third10-scoped-validation-r01',
  docs:'docs/content-review/foundation-module02-language-third10-2026-10-17',
  provenance:'data/professional/provenance/foundation-module02-language-third10-2026-10-17.json',
  transaction:'build/professional-english/transactions/foundation02-third10-language-r01',
  helper:'build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs',
  helper_sha256:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
  binding_sha256:'3139e35a051f9fd4eb38dfca0b122fedc87bf602784c621ce56415006c37ad44',
  validation_source_sha256:'38b8936ad6a325fb9c4078e7ef977010fa5a3cc5ce18631d01b1998288bb98fd',
  replacements:['data/professional/lexemes/foundation-module02.json','data/professional/sources.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd'],
  postcommit_files:['execution-start.json','transaction-intent.json','commit-receipt.json','postcommit-inventory.json'],
  guard_cases:['exact_before_and_after','allowed_field_drift','protected_field_drift','source_suffix_drift','missing_identity','duplicate_identity','input_drift','duplicate_destination','overlapping_destination','preexisting_destination','missing_receipt','forged_receipt','prepared_afterimage_mismatch','one_shot_attempt','committed_journal_required','missing_reviewer_rejected','empty_reviewer_rejected','empty_source_witness_rejected']
};
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const encode=v=>Buffer.from(JSON.stringify(v,null,2)+'\n');
const hash=v=>sha(JSON.stringify(v));
function at(relative){
  assert.equal(typeof relative,'string');assert(!relative.includes('\\'));assert(!path.isAbsolute(relative));
  const absolute=path.resolve(C.root,relative);
  assert.equal(path.relative(C.root,absolute).replaceAll('\\','/'),relative);assert(!relative.startsWith('../'));assert(relative.length>0);
  let current=path.resolve(C.root);assert(!fs.lstatSync(current).isSymbolicLink());
  for(const part of relative.split('/')){current=path.join(current,part);if(fs.existsSync(current))assert(!fs.lstatSync(current).isSymbolicLink(),'No symlink/junction: '+relative);}
  return absolute;
}
const raw=p=>sha(fs.readFileSync(at(p)));
const read=p=>JSON.parse(fs.readFileSync(at(p),'utf8'));
const same=(a,b)=>assert.deepEqual(a,b);
function exactPaths(actual,expected){assert.equal(new Set(actual.map(v=>v.toLowerCase())).size,actual.length,'Duplicate normalized paths.');same([...actual].sort(),[...expected].sort());for(const p of actual)at(p);}
function assertRef(ref){assert(ref&&typeof ref.path==='string');assert.match(ref.sha256,/^[a-f0-9]{64}$/);at(ref.path);}
function cleanReceipt(receipt,mode){assert.equal(receipt.schema,1);assert.equal(receipt.ok,true);assert.equal(receipt.mode,mode);assert.equal(receipt.error,null);assert.equal(receipt.commands.length,2);for(const r of receipt.commands){assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);assert.match(r.log_sha256,/^[a-f0-9]{64}$/);}assert.equal(receipt.current_input_count,680);}

function loadBundle(manifest,options={}){
  assert.equal(manifest.schema,1);assert.equal(manifest.status,'root_authorized_scoped_language_commit');
  assert.equal(manifest.repository_root,C.root);assert.equal(manifest.exclusive_content_mutation_window,true);
  assert.match(manifest.root_window_token_sha256,/^[a-f0-9]{64}$/);
  const retained=options.retained===true,refs=new Map();
  function pinned(ref){
    assertRef(ref);const key=ref.path.toLowerCase();const prior=refs.get(key);if(prior)assert.equal(prior.sha256,ref.sha256,'Conflicting evidence pin.');else refs.set(key,{path:ref.path,sha256:ref.sha256});
    const location=retained?C.docs+'/retained/'+ref.path:ref.path;
    const bytes=fs.readFileSync(at(location));assert.equal(sha(bytes),ref.sha256,location);return bytes;
  }
  const json=ref=>JSON.parse(pinned(ref));
  assert.equal(manifest.prepared_binding.path,C.review+'/binding.json');assert.equal(manifest.prepared_binding.sha256,C.binding_sha256);
  const binding=json(manifest.prepared_binding);assert.equal(binding.status,'prepared_output_binding_for_future_reviewed_commit');
  const preparedReview=json(binding.prepared_review),inspection=json(binding.inspection);pinned(inspection.inspector);
  assert.equal(preparedReview.status,'independent_prepared_output_review_no_blocker_found');assert.equal(preparedReview.commit_implementation_approved,false);assert.equal(inspection.ok,true);
  assert.equal(inspection.projected_callbacks,224);assert.equal(inspection.current_measurement_count,680);assert.equal(inspection.executed_sources_start_end_match,true);
  for(const r of binding.prepared_artifacts)pinned(r);
  exactPaths(binding.production_replacements.map(v=>v.path),C.replacements);
  assert.equal(binding.independent_commit_acceptance,false);
  const pRef=suffix=>{const p=C.prep+'/execution-r01/'+suffix;const r=binding.prepared_artifacts.find(v=>v.path===p);assert(r,p);return r;};
  const prep=json(pRef('preparation-receipt.json')),start=json(pRef('execution-start.json')),end=json(pRef('execution-end.json'));
  assert.equal(prep.status,'frozen_preparation_pending_independent_technical_review');assert.equal(end.status,'prepared_pending_independent_technical_review');
  same(start.source_files,end.source_files_after);same(start.source_files,prep.source_files);same(prep.measured_input_sha256,binding.current_inputs);
  for(const r of [...prep.source_files,...prep.artifacts])pinned({path:r.path,sha256:r.raw_sha256});
  const rootRef=binding.prepared_artifacts.find(v=>v.path.endsWith('foundation02-third10-root-prepare-r01/execution/receipt.json'));
  const rootReceipt=json(rootRef);assert.equal(rootReceipt.ok,true);same(rootReceipt.before,rootReceipt.after);assert.equal(rootReceipt.commands.length,4);
  rootReceipt.commands.forEach((r,i)=>{assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);pinned({path:path.posix.dirname(rootRef.path)+'/command-'+(i+1)+'.log',sha256:r.log_sha256});});
  const preparedRecord=json(binding.provenance_prepared);assert.equal(preparedRecord.patches.length,8);assert.equal(preparedRecord.sources.length,16);assert.equal(preparedRecord.held.length,2);

  assert.equal(manifest.validation_witness.path,C.validation+'/root-witness.json');
  const witness=json(manifest.validation_witness);assert.equal(witness.ok,true);assert.equal(witness.no_production_mutation,true);
  assert.equal(witness.source_before_candidate.path,C.validation+'/invoke.cjs');assert.equal(witness.source_before_candidate.sha256,C.validation_source_sha256);same(witness.source_before_candidate,witness.source_after_candidate);
  pinned(witness.source_before_candidate);pinned(witness.source_after_candidate);pinned(witness.retained_source);
  const observation=json(witness.source_observation),candidateStart=json(witness.candidate_start);
  same(observation.source,witness.source_before_candidate);same(candidateStart.source,witness.source_before_candidate);pinned(candidateStart.wrapper);
  assert.equal(observation.baseline_dispatch.source_observation_timing,'after dispatch; not a pre-dispatch witness');
  assert.match(observation.baseline_dispatch.root_authorship,/Created by root/);assert.match(witness.baseline_source_timing,/not a pre-dispatch hash witness/);
  assert.equal(witness.baseline_command_outcome.exit_code,0);assert.equal(witness.baseline_command_outcome.receipt_ok,true);
  assert.equal(witness.candidate_exit_code,0);assert.equal(witness.candidate_error,null);assert.equal(witness.candidate_signal,null);
  same(witness.candidate_command.slice(1),[C.validation+'/invoke.cjs','candidate']);same(candidateStart.candidate_command,witness.candidate_command);
  pinned({path:C.validation+'/candidate-command.log',sha256:witness.candidate_log_sha256});
  const baseline=json(witness.baseline_receipt),candidate=json(witness.candidate_receipt);cleanReceipt(baseline,'baseline');cleanReceipt(candidate,'candidate');
  same(candidateStart.baseline_receipt,witness.baseline_receipt);same(candidateStart.source_observation,witness.source_observation);
  for(const receipt of [baseline,candidate]){same(receipt.current_inputs,binding.current_inputs);same(receipt.preparation,{path:pRef('preparation-receipt.json').path,sha256:pRef('preparation-receipt.json').sha256});for(const r of receipt.commands)pinned({path:C.validation+'/'+receipt.mode+'/'+r.log,sha256:r.log_sha256});}
  same(baseline.commands[0].command.slice(1),['--test',C.replacements[2],C.replacements[3]]);
  same(baseline.commands[1].command.slice(1),['tools/run-godot.cjs','--headless','--path',path.resolve(C.root),'--script','res://'+C.replacements[4]]);
  const candidateProject=path.resolve(C.root,C.validation+'/candidate/project');
  same(candidate.commands[0].command.slice(1),['tools/run-godot.cjs','--headless','--path',candidateProject,'--check-only','--script','res://'+C.replacements[4]]);
  same(candidate.commands[1].command.slice(1),['tools/run-godot.cjs','--headless','--path',candidateProject,'--script','res://'+C.replacements[4]]);
  assert.equal(manifest.candidate_copied_inputs.path,C.validation+'/candidate/copied-inputs.json');
  const copies=json(manifest.candidate_copied_inputs);assert.equal(copies.length,candidate.copied_input_count);assert.equal(new Set(copies.map(r=>r.path)).size,copies.length);
  const overlays=new Map([[C.replacements[0],pRef('foundation-module02.json.after')],[C.replacements[1],pRef('sources.json.after')],[C.provenance,pRef('accepted-language.json')],[C.replacements[4],pRef('professional_retail_morphology_tests.gd.after')]]);
  const config=Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Language Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
  const extraInputs={};
  for(const row of copies){
    at(row.path);if(overlays.has(row.path)){const r=overlays.get(row.path);same(row.source,r.path);same(row.sha256,r.sha256);}else if(row.path==='project.godot'){assert.equal(row.source,'root-authored isolated test configuration');assert.equal(row.sha256,sha(config));}else{assert.equal(row.source,row.path);if(Object.hasOwn(binding.current_inputs,row.path))assert.equal(row.sha256,binding.current_inputs[row.path],row.path);else extraInputs[row.path]=row.sha256;}
    if(!retained)assert.equal(raw(C.validation+'/candidate/project/'+row.path),row.sha256,row.path);
  }
  for(const p of overlays.keys())assert.equal(copies.filter(r=>r.path===p).length,1);
  exactPaths(Object.keys(extraInputs),['data/professional/domain-policy/decisions.json','data/professional/domain-policy/generated/index.json','data/professional/domain-policy/generated/release.json','data/professional/domain-policy/generated/themes.json','words.json']);
  for(const [p,h] of Object.entries(extraInputs))assert.equal(raw(p),h,p+' candidate-only additional input');

  assert.equal(manifest.proposal_inventory.path,C.own+'/author-inventory.json');
  const inventory=json(manifest.proposal_inventory);assert.equal(inventory.status,'unexecuted_commit_proposal_pending_independent_review');
  for(const row of inventory.artifacts)pinned({path:C.own+'/'+row.path,sha256:row.sha256});
  const technical=json(manifest.commit_technical_review);assert.equal(technical.status,'approved_for_root_guarded_commit');assert.equal(typeof technical.reviewer,'string','Independent reviewer identity is required.');assert(technical.reviewer.trim().length>0,'Independent reviewer identity cannot be empty.');assert(!['codex recover_delivery','codex root'].includes(technical.reviewer.trim().toLowerCase()),'The proposal authors cannot approve their own commit source.');
  same(technical.proposal_inventory,manifest.proposal_inventory);same(technical.prepared_binding,manifest.prepared_binding);
  for(const row of inventory.artifacts)assert(technical.reviewed_files.some(r=>r.path===C.own+'/'+row.path&&r.sha256===row.sha256),'Unreviewed proposal source: '+row.path);
  for(const r of technical.reviewed_files)pinned(r);
  const probes=json(technical.guard_probe_evidence);assert.equal(probes.ok,true);same(probes.proposal_inventory,manifest.proposal_inventory);
  for(const name of C.guard_cases)assert(probes.cases.some(r=>r.name===name&&r.passed===true),'Missing independent guard case: '+name);
  assert(probes.cases.every(r=>r.passed===true));for(const r of probes.evidence_files||[])pinned(r);
  for(const r of technical.evidence_files||[])pinned(r);
  const inputPins=json(binding.prepared_artifacts.find(r=>r.path===C.prep+'/input-pins.json'));
  for(const r of inputPins.files.filter(r=>r.path===C.helper||r.path.includes('validation-attempt-')))pinned({path:r.path,sha256:r.raw_sha256});
  assert.equal(inputPins.files.find(r=>r.path===C.helper).raw_sha256,C.helper_sha256);
  if(!retained){
    for(const [p,h] of Object.entries(binding.current_inputs))assert.equal(raw(p),h,p);
    for(const p of [C.docs,C.provenance,C.transaction])assert(!fs.existsSync(at(p)),'Destination already exists: '+p);
  }
  return {manifest,binding,prep,preparedRecord,witness,baseline,candidate,copies,extraInputs,technical,probes,inventory,refs:[...refs.values()].sort((a,b)=>a.path.localeCompare(b.path)),pinned};
}

function verifyCommittedJournal(intent,receipt){
  assert.equal(intent.status,'root_authorized_plan_ready_for_guarded_commit');assert.equal(receipt.status,'committed');assert.equal(receipt.result.committed,true);assert.equal(receipt.result.status,'committed');
  const prepared=read(C.transaction+'/prepared.json'),preparedRaw=raw(C.transaction+'/prepared.json');
  same(prepared.plan,intent.descriptor);assert.equal(prepared.plan_sha256,intent.plan_sha256);assert.equal(sha(encode(prepared.plan)),intent.plan_sha256);
  assert.equal(receipt.result.planSha256,intent.plan_sha256);assert.equal(receipt.result.preparedSha256,preparedRaw);assert.equal(receipt.result.transactionDir,path.resolve(C.root,C.transaction));
  exactPaths(prepared.entries.map(r=>r.path),prepared.plan.allowed_paths);
  assert.equal(prepared.plan.repository_root,path.resolve(C.root));
  const transactionIntent=read(C.transaction+'/intent.json');same(transactionIntent.plan,prepared.plan);assert.equal(transactionIntent.plan_sha256,intent.plan_sha256);
  prepared.entries.forEach((r,i)=>{
    same({path:r.path,before:r.before,after:r.after,noop:r.noop},prepared.plan.entries[i]);
    assert.equal(r.staged,'staged/'+String(i).padStart(4,'0')+'.bin');assert.equal(r.backup,r.before===null?null:'backups/'+String(i).padStart(4,'0')+'.bin');
    for(const [p,e] of [[r.staged,r.after],[r.backup,r.before]])if(p!==null){const b=fs.readFileSync(at(C.transaction+'/'+p));assert.equal(b.length,e.bytes);assert.equal(sha(b),e.sha256);}
    const current=fs.readFileSync(at(r.path));assert.equal(current.length,r.after.bytes);assert.equal(sha(current),r.after.sha256,r.path);
  });
  const names=fs.readdirSync(at(C.transaction+'/states')).sort();assert(names.length>0);assert(names.every(n=>/^\d{6}-[a-z-]+\.json$/.test(n)));
  let previous=null;const states=names.map((n,i)=>{const file=C.transaction+'/states/'+n,v=read(file);assert.equal(v.sequence,i+1);assert.equal(v.prepared_sha256,preparedRaw);assert.equal(v.previous_state_sha256,previous);previous=raw(file);return {file,value:v,sha256:previous};});
  const final=states.at(-1);assert.equal(states[0].value.status,'prepared');assert.equal(final.value.status,'committed');
  assert(states.every(s=>['prepared','applying','applied','noop','committed'].includes(s.value.status)),'Unexpected recovery/failure journal state.');
  same(final.value.targets,prepared.entries.map(r=>({path:r.path,...r.after,noop:r.noop})));
  assert.equal(receipt.result.state.path,at(final.file));assert.equal(receipt.result.state.sha256,final.sha256);assert.equal(receipt.result.state.status,'committed');
  return {prepared,preparedRaw,final};
}

function verifyPersisted(){
  const manifest=read(C.docs+'/root-commit-input.json'),bundle=loadBundle(manifest,{retained:true});
  const intent=read(C.docs+'/transaction-intent.json'),receipt=read(C.docs+'/commit-receipt.json');
  const journal=verifyCommittedJournal(intent,receipt),record=read(C.provenance);
  assert.equal(record.status,'integrated_language_outputs_require_committed_journal');assert.equal(record.production_mutated,true);
  assert.equal(record.integration_guards.completion_requires_committed_journal,true);assert.equal(record.integration_guards.transaction_path,C.transaction);
  assert.equal(receipt.root_commit_input_sha256,raw(C.docs+'/root-commit-input.json'));assert.equal(intent.root_commit_input_sha256,receipt.root_commit_input_sha256);
  assert.equal(receipt.prepared_binding_sha256,C.binding_sha256);assert.equal(record.lineage.prepared_binding.sha256,C.binding_sha256);
  assert.equal(record.lineage.validation_source_timing,bundle.witness.baseline_source_timing);
  same(record.lineage,{root_commit_input:{path:C.docs+'/root-commit-input.json',sha256:receipt.root_commit_input_sha256},prepared_binding:manifest.prepared_binding,prepared_review:bundle.binding.prepared_review,validation_witness:manifest.validation_witness,validation_source_timing:bundle.witness.baseline_source_timing,candidate_only_additional_inputs:bundle.extraInputs,commit_technical_review:manifest.commit_technical_review,registry_before_sha256:bundle.binding.source_baseline.registry_before_sha256,registry_after_sha256:bundle.binding.source_baseline.registry_after_sha256});
  assert.equal(record.integrated_on,'2026-10-17');
  const original=structuredClone(record);for(const k of ['production_mutated','integrated_on','lineage','retained_files','integration_guards'])delete original[k];original.status='accepted_content_with_proposed_delivery_metadata';same(original,bundle.preparedRecord);
  const retainedList=read(C.docs+'/retained-files.json');
  same(retainedList.files,bundle.refs.map(r=>({source:r.path,path:C.docs+'/retained/'+r.path,sha256:r.sha256})));
  for(const r of retainedList.files)assert.equal(raw(r.path),r.sha256,r.path);
  same(record.retained_files,retainedList.files);
  for(const r of bundle.binding.production_replacements)assert.equal(raw(r.path),r.after_sha256,r.path);
  for(const row of journal.prepared.entries){const replacement=bundle.binding.production_replacements.find(r=>r.path===row.path);if(replacement){assert(row.before);assert.equal(row.before.sha256,replacement.before_sha256);assert.equal(row.after.sha256,replacement.after_sha256);}else{assert.equal(row.before,null);assert(row.path===C.provenance||row.path.startsWith(C.docs+'/'),'Unapproved new output family.');}}
  const changed=new Set(C.replacements);for(const [p,h] of Object.entries(bundle.binding.current_inputs))if(!changed.has(p))assert.equal(raw(p),h,p);
  const index=read(C.docs+'/inventory.json');for(const r of index.files)assert.equal(raw(r.path),r.sha256,r.path);
  const expected=[...C.replacements,C.provenance,...index.files.filter(r=>r.path!==C.provenance).map(r=>r.path),C.docs+'/inventory.json'];
  exactPaths(journal.prepared.plan.allowed_paths,expected);
  const post=read(C.docs+'/postcommit-inventory.json');assert.equal(post.status,'committed_evidence_copied_no_persisted_suite_claim');assert.equal(post.transaction_plan_sha256,intent.plan_sha256);
  exactPaths(post.files.map(r=>r.path),C.postcommit_files.filter(n=>n!=='postcommit-inventory.json').map(n=>C.docs+'/'+n));
  for(const r of post.files)assert.equal(raw(r.path),r.sha256,r.path);
  const start=read(C.docs+'/execution-start.json');assert.equal(start.root_commit_input_sha256,receipt.root_commit_input_sha256);const expectedSources=['commit.cjs','evidence-contract.cjs','committed-evidence.test.cjs','INPUTS.md','root-commit-input.example.json','author-inventory.json'].map(name=>{const file=C.own+'/'+name;const pin=bundle.refs.find(r=>r.path===file);assert(pin,'Missing retained proposal source: '+file);return {path:file,sha256:pin.sha256};});same(start.source_files,expectedSources);same(receipt.source_files_after,expectedSources);
  for(const r of start.source_files){const retained=C.docs+'/retained/'+r.path;assert.equal(raw(retained),r.sha256,r.path);}
  const api=require(at('tools/validate-professional-content.cjs'));assert.equal(hash(api.loadProfessionalContent(C.root)),bundle.binding.source_baseline.registry_after_sha256);
  return {ok:true,plan_sha256:intent.plan_sha256,prepared_journal_sha256:journal.preparedRaw,committed_state_sha256:journal.final.sha256,retained_files:retainedList.files.length,current_inputs:680,additional_candidate_inputs:5,scope:'Persisted transaction evidence only; separate root persisted audit/Node/native results remain required.'};
}
module.exports={C,sha,hash,encode,at,raw,read,exactPaths,assertRef,cleanReceipt,loadBundle,verifyCommittedJournal,verifyPersisted};
