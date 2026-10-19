'use strict';
// Independent raw result inspection. No project, proposal or test module is loaded.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {isDeepStrictEqual}=require('node:util');
const ROOT='Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const B='build/professional-english/';
const OWN=B+'foundation02-fifth10-validation-results-review-r02';
const OUT=OWN+'/projected-inspection-r01';
const P=B+'foundation02-fifth10-projected-validation-r03';
const RECEIPT={path:P+'/attempt-001/receipt.json',bytes:472109,raw_sha256:'ea5d48950c11579f39f12c5c020fe64409db1641951084fe2f3d4a61fb4f5650'};
const WITNESS={path:'docs/qa/professional-foundation02-fifth10-r01/root-dispatch/projected-r03.json',bytes:2127,raw_sha256:'b4ccf719129a50f17cf41bd2dd509def2ad832248faac2b6694ce0b4b779bdb7'};
const observed=new Map(),findings=[];let passed=0;let measurement={};
function eq(a,b,label){if(isDeepStrictEqual(a,b))passed++;else findings.push({label,actual:a,expected:b});}
function hash(b){return crypto.createHash('sha256').update(b).digest('hex');}
function abs(p){if(path.isAbsolute(p))return p;if(p.includes('\\')||p.split('/').some(v=>!v||v==='.'||v==='..'))throw Error('Invalid path '+p);return path.resolve(ROOT,p);}
function raw(p){const s=fs.lstatSync(abs(p));eq(s.isFile()&&!s.isSymbolicLink(),true,'Regular file '+p);const b=fs.readFileSync(abs(p)),pin={path:p,bytes:b.length,raw_sha256:hash(b)};if(observed.has(p))eq(pin,observed.get(p),'Repeated input unchanged '+p);observed.set(p,pin);return b;}
function pin(p){if(!observed.has(p))raw(p);return observed.get(p);}
function json(p){return JSON.parse(raw(p));}
function verify(p){eq(pin(p.path),p,'Exact pin '+p.path);}
function save(p,v){fs.writeFileSync(abs(OUT+'/'+p),JSON.stringify(v,null,2)+'\n',{flag:'wx'});}
eq(path.resolve(process.cwd()).toLowerCase(),path.resolve(ROOT).toLowerCase(),'Correct workspace');
fs.mkdirSync(abs(OUT));save('started.json',{schema:1,status:'started',reviewer:'/root/morph_review',at:new Date().toISOString()});
try{
  pin(OWN+'/inspect-projected.cjs');verify(RECEIPT);verify(WITNESS);
  const receipt=json(RECEIPT.path),witness=json(WITNESS.path),input=json(P+'/input.json'),start=json(P+'/attempt-001/start.json');
  eq(receipt.schema,1,'Receipt schema');eq(receipt.ok,true,'Actual projected success');eq(receipt.error,null,'No callback/audit failure');eq(receipt.postcheck_error,null,'Actual complete source/input/observed-read postcheck succeeded');
  eq(receipt.source_sha256,'7961b9c2e01a867d64f68ea4dbed83b9e58ff5025b71e8b986b50bc0f7f29f80','Accepted source hash');
  eq(receipt.input_sha256,'bf9439859335b7dfa72cd7cfd2ca1e48097e683dd2892e6d2307ab51e8ba37b8','Accepted input hash');
  eq(pin(P+'/run.cjs').raw_sha256,receipt.source_sha256,'Actual source remains exact');eq(pin(P+'/input.json').raw_sha256,receipt.input_sha256,'Actual bound input remains exact');
  eq(start.source_sha256,receipt.source_sha256,'Start source identity');eq(start.input_sha256,receipt.input_sha256,'Start input identity');eq(Date.parse(receipt.finished_at)>=Date.parse(start.started_at),true,'Chronological actual result');
  eq(witness.kind,'projected','Root witness kind');eq(witness.dispatcher,'/root','Root witness dispatcher');eq(witness.exit_code,0,'Actual root process exit');eq(witness.signal,null,'Actual root process signal');eq(witness.error,null,'Actual root process error');eq(witness.final_tool_result.exit_code,0,'Terminal tool completion exit');eq(witness.receipt,RECEIPT,'Root witness binds actual receipt');verify(witness.source);verify(witness.input);verify(witness.start);
  eq(witness.command,['node',P+'/run.cjs',receipt.source_sha256,receipt.input_sha256],'Actual root invocation');eq(witness.cwd,ROOT,'Actual dispatch workspace');
  const terminal=JSON.parse(witness.final_tool_result.output.trim());eq(terminal,{ok:true,receipt_sha256:RECEIPT.raw_sha256,callbacks:263,error:null,postcheck_error:null},'Exact actual terminal result');
  eq(witness.actual_installation,false,'No installation claimed');eq(witness.persisted_validation,false,'No persisted validation claimed');
  for(const p of [...Object.values(input.preparation),...Object.values(input.correction),input.independent_afterimage_review,input.independent_validator_source_review,input.correction_outer_completion,input.validator_source_relocation])verify(p);
  const afterimage=json(input.independent_afterimage_review.path),repair=json(input.correction.receipt.path),repairEnd=json(input.correction.attempt_end.path),repairDispatch=json(input.correction.root_dispatch.path),repairOuter=json(input.correction_outer_completion.path);
  eq(afterimage.status,'accepted_for_root_owned_fifth10_projected_validation','Accepted corrected afterimage status');eq(afterimage.projected_afterimages_accepted,true,'Actual corrected afterimages accepted');eq(afterimage.preparation,input.preparation,'Exact corrected preparation accepted');eq(afterimage.correction,input.correction,'Exact correction evidence accepted');
  eq(input.preparation_directory,B+'foundation02-fifth10-delivery-preparation-r04/execution-r01','Actual corrected projection directory');eq(repair.status,'corrected_preparation_pending_fresh_afterimage_review_and_root_validation','External correction succeeded');eq(repairEnd.status,'corrected_preparation_pending_validation','Correction ended successfully');eq(repairDispatch.exit_code,0,'Root repair success');eq(repairDispatch.receipt,input.correction.receipt,'Exact correction receipt witness');eq(repairOuter.exit_code,0,'Repair outer completion success');eq(repairOuter.witness,input.correction.root_dispatch,'Repair outer witness binding');eq(repair.corrected_preparation_receipt,input.preparation.receipt,'Actual r04 preparation selected');eq(repair.root_input,input.preparation.root_input,'Actual repair root input selected');
  eq(receipt.audit.summary,input.expected_audit_summary,'Actual audit summary equals accepted full expectation');eq(receipt.audit.errors,0,'Actual audit errors');eq(receipt.audit.warnings,29382,'Actual audit warnings retained');
  const prior=json(B+'shopping-bag-projected-validation-r03/attempt-001/receipt.json');eq(prior.ok,true,'Actual predecessor callbacks succeeded');eq(prior.callbacks.length,255,'Actual predecessor callback count');
  const additions={
    'tests/professional-content.test.cjs':[
      'Foundation02 fifth-ten installs eight exact accepted pairs and sixteen bounded sources',
      'Foundation02 fifth-ten preserves six complete holds and every protected context',
      'Foundation02 fifth-ten whole-object reversals reject drift and preserve fifty donor rows',
      'Foundation02 fifth-ten restores the actual post-bag registry and keeps readiness separate',
      'Foundation02 fifth-ten retains exact accepted evidence and actual predecessor receipts'],
    'tests/professional-retail-morphology.test.cjs':[
      'Foundation02 fifth-ten preserves exact morphology, media, holds and fifty complete historical donors',
      'Fifth-ten Foundation history and bag history remain disjoint strict routes'],
    'tests/professional-retail-media.test.cjs':[
      'Fifth-ten language history preserves delivered bag media without relaxing bag reversal']};
  const expected=[];const perFile={};
  for(const [file,titles]of Object.entries(additions)){
    const text=raw(input.preparation_directory+'/'+path.posix.basename(file)+'.after').toString('utf8');
    for(const title of titles)eq(text.includes("test('"+title+"',"),true,'Exact accepted authored registration '+title);
    const retained=prior.callbacks.filter(c=>c.file===file);expected.push(...retained,...titles.map(title=>({file,title,passed:true})));
    perFile[file]=receipt.callbacks.filter(c=>c.file===file).length;
  }
  eq(receipt.callbacks,expected,'All exact 263 ordered prior and added callback records');
  eq(new Set(receipt.callbacks.map(c=>c.file+'\n'+c.title)).size,263,'All callback file/title identities unique');
  eq(perFile,input.expected_callbacks_by_file,'Exact observed callback counts by file');eq(receipt.callbacks.length,input.expected_callback_count,'Exact observed callback total');
  eq(Object.keys(input.expected_inputs).length,14319,'Selected protected input count');eq(input.evidence_files.length,1734,'Selected evidence count');
  for(const [p,h]of Object.entries(input.expected_inputs))eq(pin(p).raw_sha256,h,'Current protected input '+p);
  for(const e of input.evidence_files)eq(pin(e.path).raw_sha256,e.sha256,'Current selected evidence '+e.path);
  const readEntries=Object.entries(receipt.observed_current_inputs);eq(readEntries.length,3223,'Actual observed current-input count');
  for(const [p,h]of readEntries){eq(input.expected_inputs[p],h,'Actual read was pinned '+p);eq(pin(p).raw_sha256,h,'Actual-read current bytes unchanged '+p);}
  for(const p of input.must_remain_absent)eq(fs.existsSync(abs(p)),false,'Production addition remains absent '+p);
  eq(receipt.temporary_roots.length,2,'Two actual temporary roots');
  for(const r of receipt.temporary_roots){eq(r.remains,false,'Recorded temporary root removed '+r.path);eq(fs.existsSync(r.path),false,'Actual temporary root absent '+r.path);}
  measurement={callbacks:receipt.callbacks.length,callbacks_by_file:perFile,audit:receipt.audit,protected_inputs:Object.keys(input.expected_inputs).length,evidence_files:input.evidence_files.length,observed_current_inputs:readEntries.length,absent_production_additions:input.must_remain_absent.length,temporary_roots_removed:2,root_dispatch:{kind:'projected',exit_code:witness.exit_code,signal:witness.signal,error:witness.error,receipt:RECEIPT},root_dispatch_witness:WITNESS};
}catch(error){findings.push({label:'Inspection exception',message:String(error),stack:error.stack});}
const finalPins=[...observed.values()];
for(const p of finalPins){try{eq({path:p.path,bytes:fs.statSync(abs(p.path)).size,raw_sha256:hash(fs.readFileSync(abs(p.path)))},p,'Final unchanged inspected input '+p.path);}catch(error){findings.push({label:'Final input check '+p.path,message:String(error)});}}
save('inputs.json',{schema:1,files:finalPins.sort((a,b)=>a.path.localeCompare(b.path))});
const result={schema:1,status:findings.length?'projected_result_review_has_findings':'actual_projected_candidate_result_corroborated',reviewer:'/root/morph_review',at:new Date().toISOString(),receipt:RECEIPT,witness:WITNESS,comparisons_passed:passed,findings,inputs_rehashed_at_end:finalPins.length,measurements:measurement,actual_installation:false,persisted_validation:false,scope:{independent_raw_inspection_only:true,project_or_proposal_modules_executed:false,tests_rerun:false,native_result_not_reviewed_here:true}};
save('inspection.json',result);console.log(JSON.stringify({...result,findings:result.findings.map(f=>({label:f.label,message:f.message}))},null,2));process.exitCode=findings.length?1:0;
