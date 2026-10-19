'use strict';
// Read-only guards and deterministic artifacts for the exact approved pair.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base=path.resolve(__dirname,'..'),root=path.resolve(base,'../../../..');
const {loadProfessionalContent,auditProfessionalContent,schemaErrors}=require(path.join(root,'tools/validate-professional-content.cjs'));
const {assertWave,PROFILE}=require(path.join(root,'tools/generate-voices.cjs'));
const plan=require('./transaction-plan.cjs');
const C=Object.freeze({
  target:'data/professional/lexemes/retail-pilot.json',
  provenance:'data/professional/provenance/retail-counter-checkout-approved-audio-2026-10-16.json',
  retained:'docs/assets/sources/professional-retail-ava/counter-checkout',
  approval:'docs/assets/sources/professional-retail-ava/counter-checkout/listening-approval-2026-10-16.json',
  transaction:'build/professional-english/transactions/counter-checkout-audio-r01',
  testTransaction:'build/professional-english/transactions/counter-checkout-audio-tests-r01',
  imageProvenance:'data/professional/provenance/retail-counter-image-2026-10-16.json',
  imageSha:'c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a',
  qaSha:'5300530a5630b15ca27921f488f123ef228fab38d89cc9ad982e3f71460b608b',
  humanSha:'d9487d9a2a2a93805fa597f87dcf775f1cebae88c89fc97c13de90acbece2e82',
  listeningSha:'10cdbe11ca4e9a0ae1122dc5ae2acffc69228db3d68bc7245988186667359bab',
  expected:{'counter.service-surface.n':'685b544dbb353f3a1f3fb999fbe3f541cb94874d0e4543ad0cba774c39fd4bc3','checkout.payment-area.n':'39df6ba3406a891283f99379ca8526d93fc8f3279b571134c0213dd824282224'},
  files:['delivery-lib.cjs','bind-current-baseline.cjs','integrate-reviewed.cjs','transaction-plan.cjs','guarded-transaction.cjs','helper-origin.json','persisted-test-transforms.cjs','update-persisted-tests.cjs','HANDOFF.md','source-doc-draft.md']
});
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const raw=file=>plan.sha256(fs.readFileSync(file));
const hash=value=>plan.sha256(Buffer.from(JSON.stringify(value)));
const serialized=value=>JSON.stringify(value,null,2)+'\n';
const relative=file=>path.relative(root,file).replaceAll('\\','/');
const inRoot=file=>plan.resolveTarget(root,file);
const inBase=file=>{const result=path.resolve(base,file),rel=path.relative(base,result);assert.ok(rel&&rel!=='..'&&!rel.startsWith('..'+path.sep)&&!path.isAbsolute(rel));return result;};
const writeNew=(file,value)=>fs.writeFileSync(file,serialized(value),{flag:'wx'});
function checks(){let count=0;return {same(a,b,label=''){assert.deepEqual(a,b,label);count++;},count(){return count;}};}
function args(hashes,flags=[],texts=[]){const values={},items=process.argv.slice(2);while(items.length){const key=items.shift();assert.equal(Object.hasOwn(values,key),false,'Duplicate option');if(flags.includes(key))values[key]=true;else{assert.ok(hashes.includes(key)||texts.includes(key),'Unknown option: '+key);values[key]=items.shift();if(hashes.includes(key))assert.match(values[key]||'',/^[a-f0-9]{64}$/);else assert.ok(values[key]);}}for(const key of [...hashes,...texts])assert.ok(Object.hasOwn(values,key),'Required option: '+key);return values;}
function professionalFiles(){const result=[];function visit(rel){for(const item of fs.readdirSync(inRoot(rel),{withFileTypes:true})){const file=rel+'/'+item.name;if(item.isDirectory())visit(file);else if(file.endsWith('.json'))result.push(file);}}visit('data/professional');return result.sort();}
function protect(entry){const copy=structuredClone(entry);delete copy.media.audio;delete copy.editorial_notes;return copy;}
function verifySources(same){
  same(raw(inBase('technical-qa-r01.json')),C.qaSha);same(raw(inBase('human-approval-r01.json')),C.humanSha);same(raw(inBase('listening-request.json')),C.listeningSha);
  const qa=read(inBase('technical-qa-r01.json')),human=read(inBase('human-approval-r01.json')),listening=read(inBase('listening-request.json')),batch=read(inBase('batch.json'));
  same(qa.checks,51);same(qa.failures,[]);same(qa.boundaries.production_integrated,false);same(qa.boundaries.candidate_audio_modified,false);
  same(human.status,'exact_presented_pair_user_approved');same(human.authority,'Direct human reply in the current root conversation');
  same(human.question_call_id,'call_fBfAoFlUyKmhWveN2mNUORiZ');same(human.response_english,'Both are acceptable');
  same(human.listening_request_raw_sha256,C.listeningSha);same(human.technical_qa_raw_sha256,C.qaSha);same(listening.technical_qa_raw_sha256,C.qaSha);
  same(human.profile,PROFILE);same(listening.profile,PROFILE);same(human.postprocessing,false);same(listening.postprocessing,false);
  same(human.outputs,listening.outputs);same(human.production_integrated,false);same(listening.status,'presented_to_user_pending_listening_response');
  same(batch.status,'acquired_candidates_only');same(batch.listening_review,'pending');same(batch.missing_recordings,0);
  same(qa.candidates.map(c=>c.sense_id),Object.keys(C.expected));same(batch.terms.map(c=>c.sense_id),Object.keys(C.expected));
  for(const [file,sha]of Object.entries(qa.provenance_files_raw_sha256))same(raw(path.isAbsolute(file)?file:inRoot(file)),sha,'Acquisition evidence: '+file);
  same(raw(inBase('verify-technical-audio.cjs')),qa.tools.verification_script_raw_sha256);
  for(const candidate of qa.candidates){
    const out=human.outputs.find(item=>item.sense_id===candidate.sense_id),acquired=read(inRoot(candidate.acquisition_receipt.path)),term=batch.terms.find(item=>item.sense_id===candidate.sense_id);
    same(candidate.wav.sha256,C.expected[candidate.sense_id]);same(out.wav_sha256,candidate.wav.sha256);
    same(raw(out.presented_path),candidate.wav.sha256);same(raw(inRoot(candidate.wav.path)),candidate.wav.sha256);
    same(raw(inRoot(candidate.source_mp3.path)),candidate.source_mp3.sha256);same(out.source_mp3_sha256,candidate.source_mp3.sha256);
    same(raw(inRoot(candidate.acquisition_receipt.path)),candidate.acquisition_receipt.raw_sha256);same(out.acquisition_receipt_raw_sha256,candidate.acquisition_receipt.raw_sha256);
    same(acquired.identity,candidate.identity);same(term.identity,candidate.identity);same(candidate.identity.profile,PROFILE);
    same(candidate.identity.client,{name:'edge-tts',version:'7.3.1'});same(candidate.identity.provider,'Microsoft Edge TTS');
    same(candidate.identity.synthesis_text,candidate.text+'.');same(candidate.identity.format,'22050-hz-pcm16-mono-no-effects');
    same(hash(candidate.identity),candidate.key);same(acquired.pronunciation_and_listening_review,'pending');same(acquired.production_integrated,false);
    same(acquired.wav_sha256,candidate.wav.sha256);same(acquired.source_mp3_sha256,candidate.source_mp3.sha256);
    const bytes=fs.readFileSync(inRoot(candidate.wav.path));assertWave(bytes);same(bytes.length,82598);
    same(candidate.wav.data_bytes,82554);same(candidate.wav.sample_frames,41277);same(candidate.wav.channels,1);same(candidate.wav.sample_rate_hz,22050);
    same(plan.sha256(bytes.subarray(44)),candidate.wav.pcm_sha256);same(candidate.exact_no_effects_redecode.equals_entire_candidate_pcm,true);
    same(candidate.exact_no_effects_redecode.pcm_sha256,candidate.wav.pcm_sha256);same(candidate.wav.full_scale_clipped_samples,0);
  }
  const preserved=[...qa.historical_voices.files.map(f=>({path:f.path,sha256:f.expected_sha256})),...qa.sequential_collection_audio.files.map(f=>({path:f.path,sha256:f.expected_sha256})),...qa.existing_integrated_professional_audio.map(f=>({path:f.path,sha256:f.actual_sha256}))];
  same(preserved.length,1903);same(new Set(preserved.map(f=>f.path)).size,1903);
  for(const file of preserved)same(raw(inRoot(file.path)),file.sha256,'Preserved prior audio: '+file.path);
  const master=qa.sequential_collection_audio.source_master;same(raw(inRoot(master.path)),master.expected_sha256);
  return {qa,human,listening,preserved};
}
function verifyHelper(same){const origin=read(path.join(__dirname,'helper-origin.json'));same(raw(path.join(__dirname,'guarded-transaction.cjs')),origin.helper_raw_sha256);same(raw(inRoot(origin.helper_source)),origin.helper_raw_sha256);same(raw(inRoot(origin.helper_validation.path)),origin.helper_validation.raw_sha256);same(raw(path.join(__dirname,'transaction-plan.cjs')),origin.adapter_raw_sha256);same(raw(inRoot(origin.adapter_source)),origin.adapter_raw_sha256);same(raw(inRoot(origin.adapter_validation.path)),origin.adapter_validation.raw_sha256);return origin;}
function verifyValidation(same,expected,data){
  assert.match(expected.path,/^build\/professional-english\/continuation-validation-r[0-9]{2,}\.json$/);same(raw(inRoot(expected.path)),expected.raw_sha256);
  const record=read(inRoot(expected.path));same(record.ok,true);same(record.registry_before_sha256,hash(data));same(record.registry_after_sha256,hash(data));same(record.changed_measured_inputs,[]);same(record.before_input_sha256,record.after_input_sha256);same(record.measured_input_count,Object.keys(record.after_input_sha256).length);
  same(record.runs.map(run=>run.name),['node','native','native-audio']);for(const run of record.runs){same(run.status,0);same(run.error,null);same(run.signal,null);same(raw(inRoot(run.log)),run.log_sha256);if(run.name==='node'){same(run.tests>0,true);same(run.pass,run.tests);same(run.fail,0);same(run.skipped,0);same(run.cancelled,0);}else{same(run.checks>0,true);same(run.failures,0);}}
  for(const[file,sha]of Object.entries(record.after_input_sha256))same(raw(inRoot(file)),sha,'Validated input: '+file);
  for(const file of professionalFiles())same(record.after_input_sha256[file],raw(inRoot(file)),'Validation covers Professional JSON: '+file);
  return record;
}
function verifyImageDelivery(same,expected,data){
  assert.match(expected.path,/^build\/professional-english\/retail-term-art-review\/counter-r01\/production-delivery-r[0-9]{2}\/production-check-r[0-9]{2}\.json$/);
  same(raw(inRoot(expected.path)),expected.raw_sha256);const receipt=read(inRoot(expected.path)),directory=path.dirname(inRoot(expected.path));
  same(receipt.ok,true);same(receipt.status,0);same(receipt.failures,0);same(receipt.guard_error,null);same(receipt.registry_before_sha256,hash(data));same(receipt.registry_after_sha256,hash(data));
  for(const key of ['image_pixels_exact','all_four_crops_pixel_equal','cache_teardown_zero','resource_reference_released'])same(receipt[key],true);
  same(raw(path.join(directory,'frozen-inputs.json')),receipt.frozen_inputs_raw_sha256);
  same(raw(path.join(directory,'verification/report.json')),receipt.report_raw_sha256);
  for(const artifact of receipt.artifacts)same(raw(path.join(directory,artifact.path)),artifact.raw_sha256);
  const provenance=read(inRoot(C.imageProvenance)),entry=data.lexemes.find(e=>e.id==='counter.service-surface.n');
  same(entry,provenance.patches[0].after);same(entry.media.image.sha256,C.imageSha);same(raw(inRoot(provenance.resource.path)),C.imageSha);
  return receipt;
}
function propose(same,data,sources){
  const next=structuredClone(data),envelope=read(inRoot(C.target)),patches=[];
  for(const candidate of sources.qa.candidates){
    const before=data.lexemes.find(e=>e.id===candidate.sense_id),after=structuredClone(before);
    same(before.media.audio,candidate.original_production_audio_metadata);same(before.text,candidate.text);same(data.lexemeOrigins[before.id],'res://'+C.target);
    const destination='professional-media/'+candidate.wav.sha256+'.wav';
    after.media.audio={...before.media.audio,status:'integrated',path:'res://'+destination,sha256:candidate.wav.sha256,source:'res://'+C.approval,creator:'Microsoft Ava Neural; original project term text',license:'Microsoft Services Agreement applies to synthesized output; client software licensing is separate.',acquisition_status:'integrated',review:{status:'reviewed',reviewer:'User (exact counter and checkout samples approved in the continuation chat; see counter-checkout listening-approval-2026-10-16.json)',reviewed_at:'2026-10-16'}};
    const old=candidate.text==='counter'?'word audio remains pending.':'Picture suitability and word-media production remain pending.';
    const replacement=candidate.text==='counter'?'the exact Ava word recording has user listening approval and is integrated.':'Picture suitability and word-image production remain pending. The exact Ava word recording has user listening approval and is integrated.';
    same(before.editorial_notes.split(old).length,2);after.editorial_notes=before.editorial_notes.replace(old,replacement);
    same(protect(after),protect(before));same(schemaErrors(after,'lexeme'),[]);
    const resource={id:'sha256:'+candidate.wav.sha256,sha256:candidate.wav.sha256,path:destination,kind:'audio',format:'wav',compressed_bytes:82598,decoded_bytes:82554,frames:41277,channels:1,sample_rate:22050};
    patches.push({sense_id:before.id,before,after,before_audio:before.media.audio,after_audio:after.media.audio,before_sha256:hash(before),protected_fields_sha256:hash(protect(before)),note_change:{before:old,after:replacement},resource});
    same(envelope.lexemes.filter(e=>e.id===before.id).length,1);envelope.lexemes[envelope.lexemes.findIndex(e=>e.id===before.id)]=after;next.lexemes[next.lexemes.findIndex(e=>e.id===before.id)]=after;
  }
  for(const key of Object.keys(data))if(key!=='lexemes')same(next[key],data[key]);
  same(next.lexemes.filter(e=>!C.expected[e.id]),data.lexemes.filter(e=>!C.expected[e.id]));
  return {next,envelope,patches};
}
function retainedInputs(sources,includeDeferred=true){
  const names=['batch.json','manifest.json','technical-qa-r01.json','verify-technical-audio.cjs','listening-request.json','human-approval-r01.json'];
  for(const candidate of sources.qa.candidates)names.push(path.relative(base,inRoot(candidate.wav.path)).replaceAll('\\','/'),path.relative(base,inRoot(candidate.source_mp3.path)).replaceAll('\\','/'),path.relative(base,inRoot(candidate.acquisition_receipt.path)).replaceAll('\\','/'));
  names.push(...C.files.map(file=>'delivery-r01/'+file),'delivery-r01/preparation-receipt.json');
  const copies=names.map(file=>({source:relative(inBase(file)),path:C.retained+'/'+file,policy:'immutable'}));
  if(includeDeferred)for(const file of ['preimages.json','binding-receipt.json'])copies.push({source:relative(path.join(__dirname,file)),path:C.retained+'/delivery-r01/'+file,policy:'create'});
  return copies;
}
function outputPaths(sources){return [...retainedInputs(sources).map(f=>f.path),...sources.qa.candidates.map(c=>'professional-media/'+c.wav.sha256+'.wav'),C.target,C.approval,C.provenance,relative(path.join(__dirname,'integration-receipt.json'))];}
function observePreimages(same,sources){
  const immutable=retainedInputs(sources,false).concat(sources.qa.candidates.map(c=>({source:c.wav.path,path:'professional-media/'+c.wav.sha256+'.wav'}))),result={};
  for(const item of immutable){const current=plan.observedBytes(root,item.path);if(current!==null)same(plan.sha256(current),raw(inRoot(item.source)),'Existing immutable output must match: '+item.path);result[item.path]=current===null?null:plan.sha256(current);}
  for(const file of outputPaths(sources).filter(f=>f!==C.target&&!Object.hasOwn(result,f))){same(plan.observedBytes(root,file),null,'One-shot output must be absent: '+file);result[file]=null;}
  result[C.target]=raw(inRoot(C.target));same(Object.keys(result).sort(),outputPaths(sources).sort());return result;
}
function buildArtifacts(pre,sources,preSha,bindingSha){
  const envelope=JSON.parse(Buffer.from(pre.target_before_base64,'base64').toString('utf8'));
  for(const patch of pre.patches){assert.deepEqual(envelope.lexemes.find(e=>e.id===patch.sense_id),patch.before);envelope.lexemes[envelope.lexemes.findIndex(e=>e.id===patch.sense_id)]=patch.after;}
  const copies=retainedInputs(sources),retained=copies.map(file=>({...file,raw_sha256:raw(inRoot(file.source))}));
  const approval={schema:1,status:'approved_by_user',approved_on:'2026-10-16',evidence:{source:sources.human.authority,question_item_id:['request_user_input_async',sources.human.question_call_id,0],question_english:sources.human.question_english,answer_english:sources.human.response_english,translation_note:sources.human.translation_note,human_record:C.retained+'/human-approval-r01.json',human_record_raw_sha256:C.humanSha},profile:{...PROFILE,postprocessing:false},technical_qa:{path:C.retained+'/technical-qa-r01.json',raw_sha256:C.qaSha},listening_request:{path:C.retained+'/listening-request.json',raw_sha256:C.listeningSha},scope:'Only the exact presented counter and checkout WAVs are approved. Acquisition, technical QA and listening-request records retain their original pre-approval states. Future recordings and the game mix are outside this approval.',outputs:sources.qa.candidates.map(c=>({sense_id:c.sense_id,text:c.text,synthesis_identity_key:c.key,submitted_text:c.identity.synthesis_text,presented_path:c.wav.path,retained_wav:C.retained+'/'+path.basename(c.wav.path),wav_sha256:c.wav.sha256,retained_mp3:C.retained+'/source-mp3/'+path.basename(c.source_mp3.path),source_mp3_sha256:c.source_mp3.sha256,acquisition_receipt:C.retained+'/'+path.basename(c.acquisition_receipt.path),acquisition_receipt_raw_sha256:c.acquisition_receipt.raw_sha256}))};
  const approvalBytes=Buffer.from(serialized(approval));
  const provenance={schema:1,status:'exact_user_approved_audio_integrated_pending_native_delivery_verification',integrated_on:'2026-10-16',approval:C.approval,approval_raw_sha256:plan.sha256(approvalBytes),lineage:{validation:pre.validation.path,validation_raw_sha256:pre.validation.raw_sha256,historical_registry_sha256:pre.baseline_registry_sha256,counter_image_delivery:pre.counter_image_delivery,counter_image_provenance_raw_sha256:pre.counter_image_provenance_raw_sha256},scope:'Only two audio descriptors and their exact obsolete pending-audio clauses change. All images, lexical fields, morphology, review and curriculum gates remain exact.',before_registry_sha256:pre.baseline_registry_sha256,after_registry_sha256:pre.proposed_registry_sha256,patches:pre.patches,preserved_audio_files:sources.preserved,retained_files:retained,integration_guards:{preimages_raw_sha256:preSha,binding_receipt_raw_sha256:bindingSha,delivery_files:pre.delivery_files,helper:pre.helper,transaction_path:C.transaction},audit:pre.proposed_audit};
  const provenanceBytes=Buffer.from(serialized(provenance));
  const integration={schema:1,integrated:true,status:'audio_outputs_installed_completion_requires_committed_journal',preimages_raw_sha256:preSha,binding_receipt_raw_sha256:bindingSha,before_registry_sha256:pre.baseline_registry_sha256,after_registry_sha256:pre.proposed_registry_sha256,provenance:C.provenance,provenance_raw_sha256:plan.sha256(provenanceBytes),approval:C.approval,approval_raw_sha256:plan.sha256(approvalBytes),target:C.target,target_after_raw_sha256:plan.sha256(Buffer.from(serialized(envelope))),transaction_path:C.transaction,preserved_audio_files:1903,audit:pre.proposed_audit,native_delivery_executed:false,receipt_boundary:'This receipt participates in the guarded transaction. Only the committed journal confirms integration; interruption requires explicit recovery.'};
  const artifacts=copies.map(file=>({path:file.path,after:fs.readFileSync(inRoot(file.source)),policy:file.policy}));
  for(const candidate of sources.qa.candidates)artifacts.push({path:'professional-media/'+candidate.wav.sha256+'.wav',after:fs.readFileSync(inRoot(candidate.wav.path)),policy:'immutable'});
  artifacts.push({path:C.target,after:Buffer.from(serialized(envelope)),policy:'replace'},{path:C.approval,after:approvalBytes,policy:'create'},{path:C.provenance,after:provenanceBytes,policy:'create'},{path:relative(path.join(__dirname,'integration-receipt.json')),after:Buffer.from(serialized(integration)),policy:'create'});
  return {artifacts,integration,provenance};
}
module.exports={fs,path,assert,base,root,C,plan,read,raw,hash,serialized,relative,inRoot,inBase,writeNew,checks,args,professionalFiles,protect,verifySources,verifyHelper,verifyValidation,verifyImageDelivery,propose,retainedInputs,outputPaths,observePreimages,buildArtifacts,loadProfessionalContent,auditProfessionalContent};
