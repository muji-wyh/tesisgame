'use strict';
// Root-owned audio transaction; default is read-only and rollback is explicit.
const lib=require('./delivery-lib.cjs');
const {fs,path,root,C,plan,read,raw,hash,inRoot}=lib;
const {describePlan,commitTransaction,recoverTransaction}=require('./guarded-transaction.cjs');
const options=lib.args(['--preimages-sha256'],['--integrate','--recover']);
lib.assert.ok(!(options['--integrate']&&options['--recover']));
const check=lib.checks(),{same}=check,preFile=path.join(__dirname,'preimages.json'),bindingFile=path.join(__dirname,'binding-receipt.json');
same(raw(preFile),options['--preimages-sha256']);
const pre=read(preFile),binding=read(bindingFile),bindingSha=raw(bindingFile);
same(pre.status,'frozen_exact_validated_counter_image_state_for_approved_pair_audio');same(pre.target,C.target);
same(binding.status,'transactional_audio_baseline_bound_no_production_writes');same(binding.preimages_raw_sha256,raw(preFile));same(binding.serializer_raw_sha256,raw(__filename));same(binding.production_content_written,false);
same(binding.baseline_registry_sha256,pre.baseline_registry_sha256);same(binding.proposed_registry_sha256,pre.proposed_registry_sha256);same(binding.validation_raw_sha256,pre.validation.raw_sha256);same(binding.counter_image_delivery_raw_sha256,pre.counter_image_delivery.raw_sha256);
function immutable(){
  same(raw(preFile),options['--preimages-sha256']);same(raw(bindingFile),bindingSha);same(raw(path.join(__dirname,'preparation-receipt.json')),pre.preparation_receipt_raw_sha256);
  same(Object.keys(pre.delivery_files).sort(),[...C.files].sort());for(const[file,sha]of Object.entries(pre.delivery_files))same(raw(path.join(__dirname,file)),sha);
  same(pre.human_approval_raw_sha256,C.humanSha);same(pre.technical_qa_raw_sha256,C.qaSha);same(raw(inRoot(pre.validation.path)),pre.validation.raw_sha256);same(raw(inRoot(pre.counter_image_delivery.path)),pre.counter_image_delivery.raw_sha256);same(raw(inRoot(C.imageProvenance)),pre.counter_image_provenance_raw_sha256);
  same(lib.verifyHelper(same),pre.helper);const sources=lib.verifySources(same);same(sources.preserved,pre.preserved_audio_files);same(lib.outputPaths(sources),pre.allowed_output_paths);same(Object.keys(pre.output_preimages).sort(),[...pre.allowed_output_paths].sort());return sources;
}
const sources=immutable();
function baseline(){
  immutable();same(lib.professionalFiles(),Object.keys(pre.professional_json_raw_sha256));for(const[file,sha]of Object.entries(pre.professional_json_raw_sha256))same(raw(inRoot(file)),sha);
  same(raw(inRoot(C.target)),pre.target_raw_sha256);const data=lib.loadProfessionalContent(root);same(hash(data),pre.baseline_registry_sha256);
  const validation=lib.verifyValidation(same,pre.validation,data);same(validation.after_input_sha256,pre.validated_measured_inputs);lib.verifyImageDelivery(same,pre.counter_image_delivery,data);
  same(lib.observePreimages(same,sources),pre.output_preimages);same(lib.auditProfessionalContent({rootDir:root,data}).errors,[]);return data;
}
// Trust only the explicit preimages hash; never parse a partial live registry to recover.
const beforeBytes=Buffer.from(pre.target_before_base64,'base64');same(plan.sha256(beforeBytes),pre.target_raw_sha256);
const output=lib.buildArtifacts(pre,sources,raw(preFile),bindingSha);
same(output.artifacts.map(file=>file.path).sort(),[...pre.allowed_output_paths].sort());
const changes=plan.trustedChanges({repositoryRoot:root,artifacts:output.artifacts,expectedPreimages:pre.output_preimages,replacementPreimages:{[C.target]:beforeBytes}});
const helperOptions={repositoryRoot:root,transactionDir:inRoot(C.transaction),allowedPaths:pre.allowed_output_paths.map(inRoot),changes:changes.map(change=>({...change,path:inRoot(change.path)}))};
const described=describePlan(helperOptions);
if(options['--recover']){
  const result=recoverTransaction({repositoryRoot:root,transactionDir:inRoot(C.transaction),allowedPaths:helperOptions.allowedPaths,expectedPlanSha256:described.planSha256});
  if(result.status==='committed'){same(result.targetFilesMutated,false);console.log(JSON.stringify({committed:true,recovered:false,checks:check.count(),transaction:result}));process.exit(0);}
  same(['rolled-back','not-prepared'].includes(result.status),true);baseline();
  console.log(JSON.stringify({baseline_confirmed:true,recovered:result.status==='rolled-back',checks:check.count(),registry_sha256:pre.baseline_registry_sha256,transaction:result}));process.exit(0);
}
same(fs.existsSync(inRoot(C.transaction)),false,'Existing attempt requires explicit inspected recovery or a new revision');
const data=baseline(),proposed=lib.propose(same,data,sources);same(proposed.patches,pre.patches);same(hash(proposed.next),pre.proposed_registry_sha256);
const audit=lib.auditProfessionalContent({rootDir:root,data:proposed.next});
same(audit.errors,pre.patches.filter(p=>pre.output_preimages[p.resource.path]===null).map(p=>({code:'media.missing',path:'lexeme/'+p.sense_id+'/audio',message:'Referenced asset does not exist'})).sort((a,b)=>a.path.localeCompare(b.path)));
same({errors:0,warnings:audit.warnings.length,summary:audit.summary},pre.proposed_audit);
same(plan.makeChanges({repositoryRoot:root,artifacts:output.artifacts,expectedPreimages:pre.output_preimages}),changes);plan.verifyChanges(root,changes,'before');
const summary={dry_run:!options['--integrate'],integration_ready:true,checks:check.count(),before_registry_sha256:pre.baseline_registry_sha256,proposed_registry_sha256:pre.proposed_registry_sha256,transaction_plan_sha256:described.planSha256,transaction_path:C.transaction,preserved_audio_files:1903,changes:changes.map(change=>({path:change.path,before_sha256:change.before===null?null:plan.sha256(change.before),after_sha256:plan.sha256(change.after),preserved_identical:change.before!==null&&change.before.equals(change.after)}))};
if(!options['--integrate']){console.log(JSON.stringify(summary));process.exit(0);}
const transaction=commitTransaction({...helperOptions,verify(){
  plan.verifyChanges(root,changes,'after');same(lib.loadProfessionalContent(root),proposed.next);
  const actual=lib.auditProfessionalContent({rootDir:root,data:proposed.next});same(actual.errors,[]);same({errors:0,warnings:actual.warnings.length,summary:actual.summary},pre.proposed_audit);
  same(lib.professionalFiles(),[...Object.keys(pre.professional_json_raw_sha256),C.provenance].sort());
  for(const[file,sha]of Object.entries(pre.validated_measured_inputs))same(raw(inRoot(file)),file===C.target?output.integration.target_after_raw_sha256:sha,'Protected measured input: '+file);
  immutable();
}});
console.log(JSON.stringify({...output.integration,checks:check.count(),transaction_plan_sha256:described.planSha256,transaction}));
