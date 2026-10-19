'use strict';
// Read-only contract on import. Root owns review, fixture probes, dispatch and persisted validation.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const C={
  root:'Q:/.codex/worktrees/current-age-vocabulary/tesisgame',
  own:'build/professional-english/foundation02-fourth10-commit-proposal-r01',
  prep:'build/professional-english/foundation02-fourth10-delivery-preparation-r02',
  root_prep:'build/professional-english/foundation02-fourth10-root-preparation-r02',
  review:'build/professional-english/foundation02-fourth10-prepared-output-review-r02',
  native:'build/professional-english/foundation02-fourth10-native-candidate-r02',
  prior:'build/professional-english/foundation02-third10-persisted-validation-r01',
  docs:'docs/content-review/foundation-module02-language-fourth10-2026-10-17',
  provenance:'data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json',
  transaction:'build/professional-english/transactions/foundation02-fourth10-language-r01',
  helper:'build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs',
  helper_sha256:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
  binding_sha256:'dbacf79ca796410664a1a6af9a577172c93234109b3c33c326ba669a5394dc21',
  native_receipt_sha256:'1dbb1e3a9d34226b77381502edd6a9d745605f0e05d320297519e45106c5bc0c',
  native_source_sha256:'5e53f7cdeb13a9d45a031f1aec08e46b9752fc445cc0f6815cc6163e657664e2',
  native_copies_sha256:'9c8005d0a81412dc9186cd8ae8f58008a9d8cd855e54edd4d5ab7b70c06dc029',
  prior_receipt_sha256:'509d64c10012756c7d44d0cdf6fb9b204a3c1cbfe1c4e0e76434ea2af36a33f8',
  prior_commit_sha256:'e247462f7d41a03b2b00b1dee17314987954d26df82f4b6949ddc2982fbbea35',
  replacements:['data/professional/lexemes/foundation-module02.json','data/professional/sources.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd'],
  source_names:['commit.cjs','evidence-contract.cjs','committed-evidence.test.cjs','INPUTS.md','root-commit-input.example.json','evidence-inputs.json','author-inventory.json'],
  preparation_source_names:['input-pins.json','input-freeze-receipt.json','projection.cjs','test-transforms.cjs','prepare.cjs','HANDOFF.md','TRANSACTION.md','author-r02.cjs','revision-derivation.json','author-coverage-r02.cjs','coverage-supplement.json','freeze-inputs.cjs','author-inventory.json'],
  postcommit_files:['execution-start.json','transaction-intent.json','commit-receipt.json','postcommit-inventory.json'],
  guard_cases:['exact_before_and_after','allowed_field_drift','protected_field_drift','source_suffix_drift','missing_identity','duplicate_identity','input_drift','duplicate_destination','overlapping_destination','preexisting_destination','missing_receipt','forged_receipt','prepared_afterimage_mismatch','one_shot_attempt','committed_journal_required','missing_reviewer_rejected','empty_reviewer_rejected','empty_source_witness_rejected','scoped_overlapping_destination_rejected','author_reviewer_rejected','postcommit_plan_hash_drift_rejected']
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
function exactPaths(actual,expected){
  const normalized=actual.map(v=>v.toLowerCase()).sort();
  assert.equal(new Set(normalized).size,actual.length,'Duplicate normalized paths.');
  const destinations=new Set(normalized);for(const file of normalized){const parts=file.split('/');for(let i=1;i<parts.length;i++)assert(!destinations.has(parts.slice(0,i).join('/')),'Overlapping destinations.');}
  same([...actual].sort(),[...expected].sort());for(const p of actual)at(p);
}
function assertRef(ref){assert(ref&&typeof ref.path==='string');assert.match(ref.sha256,/^[a-f0-9]{64}$/);at(ref.path);}
const normalizedRef=r=>({path:r.path,sha256:r.sha256||r.raw_sha256});
function assertReviewer(value){
  assert.equal(typeof value,'string','Independent reviewer identity is required.');
  const identity=value.trim().toLowerCase().replace(/\s+/g,' ');assert(identity.length>0,'Independent reviewer identity cannot be empty.');
  for(const author of ['codex runtime_recovery','codex root','runtime_recovery','root','/root/runtime_recovery']){
    assert(identity!==author&&![' ',':','(','[','/'].some(mark=>identity.startsWith(author+mark)),'The proposal author or dispatcher cannot approve this source.');
  }
}
function cleanReceipt(receipt,count){
  assert.equal(receipt.schema,1);assert.equal(receipt.ok,true);assert.equal(receipt.error,null);assert.equal(receipt.commands.length,count);
  for(const r of receipt.commands){assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);assert.match(r.log_sha256,/^[a-f0-9]{64}$/);}
}
function loadBundle(manifest,options={}){
  assert.equal(manifest.schema,1);assert.equal(manifest.status,'root_authorized_scoped_language_commit');
  assert.equal(manifest.repository_root,C.root);assert.equal(manifest.exclusive_content_mutation_window,true);assert.match(manifest.root_window_token_sha256,/^[a-f0-9]{64}$/);
  const retained=options.retained===true,refs=new Map();
  function pinned(ref){
    const normalized=normalizedRef(ref);assertRef(normalized);
    if(ref.sha256&&ref.raw_sha256)assert.equal(ref.sha256,ref.raw_sha256);
    const key=normalized.path.toLowerCase(),prior=refs.get(key);if(prior)same(prior,normalized);else refs.set(key,normalized);
    const location=retained?C.docs+'/retained/'+normalized.path:normalized.path,bytes=fs.readFileSync(at(location));
    assert.equal(sha(bytes),normalized.sha256,location);if(Object.hasOwn(ref,'bytes'))assert.equal(bytes.length,ref.bytes,location);return bytes;
  }
  const json=ref=>JSON.parse(pinned(ref));
  const find=(rows,file)=>{const matches=rows.filter(r=>r.path===file);assert.equal(matches.length,1,'Exactly one evidence ref: '+file);return matches[0];};
  assert.equal(manifest.proposal_inventory.path,C.own+'/author-inventory.json');
  const inventory=json(manifest.proposal_inventory);assert.equal(inventory.status,'unexecuted_commit_proposal_pending_independent_review');
  exactPaths(inventory.artifacts.map(r=>C.own+'/'+r.path),C.source_names.filter(n=>n!=='author-inventory.json').map(n=>C.own+'/'+n));
  for(const row of inventory.artifacts)pinned({path:C.own+'/'+row.path,sha256:row.sha256,bytes:row.bytes});
  const evidence=json({path:C.own+'/evidence-inputs.json',sha256:find(inventory.artifacts,'evidence-inputs.json').sha256});
  assert.equal(evidence.status,'actual_evidence_references_for_unexecuted_commit_proposal');
  for(const r of [...evidence.native,...evidence.prior_baseline,evidence.prior_committed_receipt])pinned(r);

  same(manifest.prepared_binding,{path:C.review+'/binding.json',sha256:C.binding_sha256});
  const binding=json(manifest.prepared_binding);assert.equal(binding.status,'frozen_prepared_output_binding_pending_root_native_and_commit_review');
  assert.equal(binding.repository_root,C.root);assert.equal(binding.measurement_count,864);assert.equal(Object.keys(binding.expected_inputs).length,864);
  // Keep measured scratch evidence verifiable after the original scratch directories are removed.
  for(const [file,expected] of Object.entries(binding.expected_inputs))if(file.startsWith('build/'))pinned({path:file,sha256:expected});
  assert.equal(binding.projected_callback_count,230);assert.equal(binding.native_acceptance,false);assert.equal(binding.production_commit_acceptance,false);assert.equal(binding.persisted_acceptance,false);
  for(const r of [binding.output_review,binding.inspection,binding.inspection_source,binding.current_measurements,binding.proposal_inventory,binding.source_review,...binding.prepared_sources,...binding.prepared_artifacts,...binding.root_witness_files])pinned(r);
  const preparedReview=json(binding.output_review),inspection=json(binding.inspection);assertReviewer(preparedReview.reviewer);
  assert.equal(preparedReview.status,'accepted_actual_prepared_outputs_for_root_candidate_native_validation');assert.equal(preparedReview.technical_prepared_output_accepted,true);assert.equal(preparedReview.production_or_commit_accepted,false);
  assert.equal(inspection.status,'actual_prepared_output_inspection_complete');assert.equal(inspection.projected_callbacks.total,230);assert.equal(inspection.projected_callbacks.content,192);assert.equal(inspection.projected_callbacks.morphology,38);assert.equal(inspection.all_864_inputs_unchanged,true);
  same(inspection.prepared_sources,binding.prepared_sources);same(inspection.prepared_artifacts,binding.prepared_artifacts);same(inspection.root_witness_files,binding.root_witness_files);
  exactPaths(binding.replacements.map(v=>v.target),C.replacements);same(binding.required_absences,[C.provenance,C.docs,C.transaction]);
  assert.equal(binding.provenance_addition.target,C.provenance);assert.equal(binding.provenance_addition.must_be_absent,true);
  const pRef=suffix=>find(binding.prepared_artifacts,C.prep+'/execution-r01/'+suffix);
  const prep=json(binding.preparation_receipt),start=json(pRef('execution-start.json')),end=json(pRef('execution-end.json'));
  same(binding.preparation_receipt,pRef('preparation-receipt.json'));
  assert.equal(prep.status,'frozen_preparation_pending_independent_technical_review');assert.equal(start.status,'preparation_dispatch_recorded');assert.equal(end.status,'prepared_pending_independent_technical_review');
  same(binding.prepared_sources.map(r=>r.path),C.preparation_source_names.map(n=>C.prep+'/'+n));
  const expectedPreparationSources=binding.prepared_sources.map(r=>({path:r.path,raw_sha256:r.raw_sha256}));
  same(start.source_files,expectedPreparationSources);same(end.source_files_after,expectedPreparationSources);same(prep.source_files,expectedPreparationSources);
  same(prep.measured_input_sha256,binding.expected_inputs);assert.equal(prep.measured_input_count,864);assert.equal(prep.projected_callback_count,230);assert.equal(prep.production_mutated,false);
  assert.equal(prep.artifacts.length,15);for(const r of prep.artifacts){same(normalizedRef(r),normalizedRef(find(binding.prepared_artifacts,r.path)));pinned(r);}
  assert.equal(binding.prepared_artifacts.length,17);same(prep.source_baseline,binding.source_baseline);assert.equal(binding.source_baseline.kind,'source_snapshot_not_validation');
  for(const r of binding.source_baseline.source_pins)assert.equal(binding.expected_inputs[r.path],r.raw_sha256,r.path);assert.equal(binding.source_baseline.source_pins.length,355);
  for(const row of binding.replacements){same(row.before,find(binding.prepared_artifacts,row.before.path));same(row.after,find(binding.prepared_artifacts,row.after.path));assert.equal(binding.expected_inputs[row.target],row.before.raw_sha256);}
  same(binding.provenance_addition.after,pRef('accepted-language.json'));
  const preparedRecord=json(binding.provenance_addition.after);assert.equal(preparedRecord.status,'accepted_content_with_proposed_delivery_metadata');assert.equal(preparedRecord.patches.length,10);assert.equal(preparedRecord.sources.length,20);assert.equal(preparedRecord.held.length,0);same(preparedRecord.source_baseline,binding.source_baseline);

  const rootReceipt=json(binding.root_preparation_witness),rootStart=json(find(binding.root_witness_files,C.root_prep+'/execution/start.json'));
  assert.equal(rootReceipt.ok,true);assert.equal(rootReceipt.sources_unchanged,true);assert.equal(rootReceipt.commands.length,4);
  const rootSources=binding.prepared_sources.map(r=>({path:r.path,bytes:r.bytes,sha256:r.raw_sha256}));
  same(rootStart.sources,rootSources);same(rootReceipt.sources,rootSources);same(rootReceipt.sources_after,rootSources);
  same(normalizedRef(rootReceipt.review),normalizedRef(binding.source_review));same(rootReceipt.review,rootStart.review);same(rootReceipt.inventory,rootStart.inventory);
  same(normalizedRef(rootReceipt.inventory),normalizedRef(binding.proposal_inventory));
  const rootCommands=[['--check',C.prep+'/projection.cjs'],['--check',C.prep+'/test-transforms.cjs'],['--check',C.prep+'/prepare.cjs'],[C.prep+'/prepare.cjs','--root-dispatch','confirmed-by-root']];
  same(rootStart.commands,rootCommands);
  rootReceipt.commands.forEach((r,i)=>{assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);same(r.command.slice(1),rootCommands[i]);pinned({path:C.root_prep+'/execution/command-'+(i+1)+'.log',sha256:r.log_sha256});});
  const rootDispatch=json(find(binding.root_witness_files,C.root_prep+'/dispatch-source.json'));
  assert.equal(rootStart.wrapper_sha256,find(binding.root_witness_files,C.root_prep+'/invoke.cjs').raw_sha256);assert.equal(rootDispatch.wrapper_sha256,rootStart.wrapper_sha256);
  assert.equal(rootDispatch.execution,false);assert.equal(rootDispatch.author_inventory_sha256,binding.proposal_inventory.raw_sha256);assert.equal(rootDispatch.independent_review_sha256,binding.source_review.raw_sha256);

  const baselineTransfer=manifest.baseline_dependency_transfer;
  assert.equal(baselineTransfer.accepted,true);assert.equal(baselineTransfer.scope,'unchanged_prior_baseline_only');
  same(baselineTransfer.receipt,{path:C.prior+'/attempt-001/receipt.json',sha256:C.prior_receipt_sha256});
  const baseline=json(baselineTransfer.receipt),baselineStart=json(find(evidence.prior_baseline,C.prior+'/attempt-001/start.json'));cleanReceipt(baseline,4);
  assert.equal(baseline.checked_inputs,686);assert.equal(Object.keys(baselineStart.expected_inputs).length,686);
  const priorSource=find(evidence.prior_baseline,C.prior+'/invoke.cjs');assert.equal(baselineStart.source_sha256,priorSource.sha256);assert.equal(baseline.source_before,priorSource.sha256);assert.equal(baseline.source_after,priorSource.sha256);
  same(baseline.committed_receipt,baselineStart.committed_receipt);same(normalizedRef(evidence.prior_committed_receipt),baseline.committed_receipt);assert.equal(evidence.prior_committed_receipt.sha256,C.prior_commit_sha256);
  const priorCommit=json(evidence.prior_committed_receipt);assert.equal(priorCommit.status,'committed');assert.equal(priorCommit.result.committed,true);assert.equal(priorCommit.registry_after_sha256,binding.registry_before_sha256);
  for(const [p,h] of Object.entries(baselineStart.expected_inputs))assert.equal(binding.expected_inputs[p],h,'Prior baseline dependency changed: '+p);
  const baselineCommands=[['tools/validate-professional-content.cjs'],['--test',C.replacements[2],C.replacements[3]],['tools/run-godot.cjs','--headless','--path',path.resolve(C.root),'--script','res://'+C.replacements[4]],['--test','docs/content-review/foundation-module02-language-third10-2026-10-17/committed-evidence.test.cjs']];
  baseline.commands.forEach((r,i)=>{same(r.command.slice(1),baselineCommands[i]);pinned({path:C.prior+'/attempt-001/'+r.log,sha256:r.log_sha256});});

  same(manifest.native_receipt,{path:C.native+'/attempt-001/receipt.json',sha256:C.native_receipt_sha256});
  same(manifest.candidate_copied_inputs,{path:C.native+'/attempt-001/copied-inputs.json',sha256:C.native_copies_sha256});
  const candidate=json(manifest.native_receipt),candidateStart=json(find(evidence.native,C.native+'/attempt-001/start.json')),dispatch=json(find(evidence.native,C.native+'/dispatch-source.json'));cleanReceipt(candidate,2);
  assert.equal(candidate.current_input_count,864);assert.equal(candidate.copied_input_count,434);assert.equal(candidate.registry_after_sha256,binding.registry_after_sha256);
  for(const v of [candidate,candidateStart,dispatch])assert.equal(v.wrapper_sha256,C.native_source_sha256);
  assert.equal(find(evidence.native,C.native+'/run.cjs').sha256,C.native_source_sha256);assert.equal(dispatch.execution,false);
  const acceptedPaths=['binding.json','input-measurements.json','inspect-output.cjs','inspection.json','README.md','review.json','inventory.json'].map(n=>C.review+'/'+n).concat([C.prep+'/execution-r01/preparation-receipt.json',C.prep+'/execution-r01/execution-end.json'],['invoke.cjs','dispatch-source.json','execution/command-1.log','execution/command-2.log','execution/command-3.log','execution/command-4.log','execution/receipt.json','execution/start.json'].map(n=>C.root_prep+'/'+n));
  same(dispatch.accepted_inputs.map(r=>r.path),acceptedPaths);same(candidateStart.accepted_inputs,dispatch.accepted_inputs);same(candidate.accepted_inputs,dispatch.accepted_inputs);
  for(const r of dispatch.accepted_inputs)pinned(r);same(candidateStart.measured_input_sha256,binding.expected_inputs);same(normalizedRef(candidate.preparation),normalizedRef(binding.preparation_receipt));
  const candidateProject=path.resolve(C.root,C.native+'/attempt-001/project');
  candidate.commands.forEach((r,i)=>{same(r.command.slice(1),['tools/run-godot.cjs','--headless','--path',candidateProject,...(i===0?['--check-only']:[]),'--script','res://'+C.replacements[4]]);pinned({path:C.native+'/attempt-001/'+r.log,sha256:r.log_sha256});});
  const copies=json(manifest.candidate_copied_inputs);assert.equal(copies.length,434);exactPaths(copies.map(r=>r.path),copies.map(r=>r.path));
  const overlays=new Map([[C.replacements[0],pRef('foundation-module02.json.after')],[C.replacements[1],pRef('sources.json.after')],[C.provenance,pRef('accepted-language.json')],[C.replacements[4],pRef('professional_retail_morphology_tests.gd.after')]]);
  const config=Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Fourth Ten Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
  const extraInputs={};let baselineCopies=0;
  for(const row of copies){
    at(row.path);assert(Number.isInteger(row.bytes)&&row.bytes>=0);
    if(overlays.has(row.path)){const r=overlays.get(row.path);same(row.source,r.path);same(row.sha256,r.raw_sha256);same(row.bytes,r.bytes);}
    else if(row.path==='project.godot'){assert.equal(row.source,'root-authored isolated test configuration');assert.equal(row.sha256,sha(config));assert.equal(row.bytes,config.length);}
    else{assert.equal(row.source,row.path);if(Object.hasOwn(binding.expected_inputs,row.path)){assert.equal(row.sha256,binding.expected_inputs[row.path],row.path);baselineCopies++;}else extraInputs[row.path]=row.sha256;}
    if(!retained){const bytes=fs.readFileSync(at(C.native+'/attempt-001/project/'+row.path));assert.equal(sha(bytes),row.sha256,row.path);assert.equal(bytes.length,row.bytes,row.path);}
  }
  for(const p of [...overlays.keys(),'project.godot'])assert.equal(copies.filter(r=>r.path===p).length,1);
  assert.equal(baselineCopies,429);same(extraInputs,{});

  const technical=json(manifest.commit_technical_review);assert.equal(technical.status,'approved_for_root_guarded_commit');assertReviewer(technical.reviewer);
  same(technical.proposal_inventory,manifest.proposal_inventory);same(technical.prepared_binding,manifest.prepared_binding);
  same(technical.baseline_dependency_transfer,manifest.baseline_dependency_transfer);same(technical.native_receipt,manifest.native_receipt);
  const expectedReviewed=inventory.artifacts.map(row=>({path:C.own+'/'+row.path,sha256:row.sha256}));
  for(const r of expectedReviewed)assert(technical.reviewed_files.some(v=>v.path===r.path&&v.sha256===r.sha256),'Unreviewed proposal source: '+r.path);
  for(const r of technical.reviewed_files)pinned(r);
  const probes=json(technical.guard_probe_evidence);assert.equal(probes.ok,true);same(probes.proposal_inventory,manifest.proposal_inventory);
  for(const name of C.guard_cases)assert.equal(probes.cases.filter(r=>r.name===name&&r.passed===true).length,1,'Missing independent guard case: '+name);
  assert(probes.cases.every(r=>r.passed===true));for(const r of probes.evidence_files||[])pinned(r);for(const r of technical.evidence_files||[])pinned(r);
  const inputPins=json(find(binding.prepared_sources,C.prep+'/input-pins.json'));assert.equal(inputPins.files.length,864);
  same(Object.fromEntries(inputPins.files.map(r=>[r.path,r.raw_sha256])),binding.expected_inputs);
  const helperRef=find(inputPins.files,C.helper);assert.equal(helperRef.raw_sha256,C.helper_sha256);pinned(helperRef);
  if(!retained){for(const [p,h] of Object.entries(binding.expected_inputs))assert.equal(raw(p),h,p);for(const p of binding.required_absences)assert(!fs.existsSync(at(p)),'Destination already exists: '+p);}
  return {manifest,binding,prep,preparedRecord,baseline,candidate,copies,extraInputs,technical,probes,inventory,refs:[...refs.values()].sort((a,b)=>a.path.localeCompare(b.path)),pinned};
}
function lineage(bundle,rootHash){
  return {root_commit_input:{path:C.docs+'/root-commit-input.json',sha256:rootHash},prepared_binding:bundle.manifest.prepared_binding,prepared_review:bundle.binding.output_review,baseline_dependency_transfer:bundle.manifest.baseline_dependency_transfer,native_receipt:bundle.manifest.native_receipt,candidate_copied_inputs:bundle.manifest.candidate_copied_inputs,commit_technical_review:bundle.manifest.commit_technical_review,registry_before_sha256:bundle.binding.registry_before_sha256,registry_after_sha256:bundle.binding.registry_after_sha256};
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
  same(record.lineage,lineage(bundle,receipt.root_commit_input_sha256));assert.equal(record.integrated_on,'2026-10-17');
  const original=structuredClone(record);for(const k of ['production_mutated','integrated_on','lineage','retained_files','integration_guards'])delete original[k];original.status='accepted_content_with_proposed_delivery_metadata';same(original,bundle.preparedRecord);
  const retainedList=read(C.docs+'/retained-files.json');
  same(retainedList.files,bundle.refs.map(r=>({source:r.path,path:C.docs+'/retained/'+r.path,sha256:r.sha256})));
  for(const r of retainedList.files)assert.equal(raw(r.path),r.sha256,r.path);same(record.retained_files,retainedList.files);
  for(const r of bundle.binding.replacements)assert.equal(raw(r.target),r.after.raw_sha256,r.target);
  for(const row of journal.prepared.entries){const replacement=bundle.binding.replacements.find(r=>r.target===row.path);if(replacement){assert(row.before);assert.equal(row.before.sha256,replacement.before.raw_sha256);assert.equal(row.before.bytes,replacement.before.bytes);assert.equal(row.after.sha256,replacement.after.raw_sha256);assert.equal(row.after.bytes,replacement.after.bytes);}else{assert.equal(row.before,null);assert(row.path===C.provenance||row.path.startsWith(C.docs+'/'),'Unapproved new output family.');}}
  const changed=new Set(C.replacements);for(const [p,h] of Object.entries(bundle.binding.expected_inputs))if(!changed.has(p))assert.equal(raw(p.startsWith('build/')?C.docs+'/retained/'+p:p),h,p);
  const index=read(C.docs+'/inventory.json');for(const r of index.files){const b=fs.readFileSync(at(r.path));assert.equal(sha(b),r.sha256,r.path);assert.equal(b.length,r.bytes,r.path);}
  const expected=[...C.replacements,C.provenance,...index.files.filter(r=>r.path!==C.provenance).map(r=>r.path),C.docs+'/inventory.json'];exactPaths(journal.prepared.plan.allowed_paths,expected);
  const post=read(C.docs+'/postcommit-inventory.json');assert.equal(post.status,'committed_evidence_copied_no_persisted_suite_claim');assert.equal(post.transaction_plan_sha256,intent.plan_sha256);
  exactPaths(post.files.map(r=>r.path),C.postcommit_files.filter(n=>n!=='postcommit-inventory.json').map(n=>C.docs+'/'+n));for(const r of post.files){const b=fs.readFileSync(at(r.path));assert.equal(sha(b),r.sha256,r.path);assert.equal(b.length,r.bytes,r.path);}
  const start=read(C.docs+'/execution-start.json');assert.equal(start.root_commit_input_sha256,receipt.root_commit_input_sha256);
  const expectedSources=C.source_names.map(name=>{const file=C.own+'/'+name,pin=bundle.refs.find(r=>r.path===file);assert(pin,'Missing retained proposal source: '+file);return {path:file,sha256:pin.sha256};});
  same(start.source_files,expectedSources);same(receipt.source_files_after,expectedSources);for(const r of expectedSources)assert.equal(raw(C.docs+'/retained/'+r.path),r.sha256,r.path);
  assert.equal(receipt.registry_after_sha256,bundle.binding.registry_after_sha256);assert.equal(receipt.provenance_sha256,raw(C.provenance));assert.equal(receipt.persisted_suite_execution_claim,false);
  const api=require(at('tools/validate-professional-content.cjs'));assert.equal(hash(api.loadProfessionalContent(C.root)),bundle.binding.registry_after_sha256);
  return {ok:true,plan_sha256:intent.plan_sha256,prepared_journal_sha256:journal.preparedRaw,committed_state_sha256:journal.final.sha256,retained_files:retainedList.files.length,current_inputs:864,retained_scratch_input_count:Object.keys(bundle.binding.expected_inputs).filter(p=>p.startsWith('build/')).length,additional_candidate_inputs:0,scope:'864 exact measured input bindings: current non-build files plus retained scratch inputs. Fresh root audit, affected Node suites and native validation remain separate.'};
}
module.exports={C,sha,hash,encode,at,raw,read,exactPaths,assertRef,assertReviewer,cleanReceipt,loadBundle,lineage,verifyCommittedJournal,verifyPersisted};

