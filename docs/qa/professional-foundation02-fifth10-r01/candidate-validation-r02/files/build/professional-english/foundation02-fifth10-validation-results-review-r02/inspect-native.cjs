'use strict';
// Independent raw native-result inspection only. Never imports or executes project code.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {isDeepStrictEqual}=require('node:util');
const ROOT='Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const B='build/professional-english/';
const OWN=B+'foundation02-fifth10-validation-results-review-r02';
const OUT=OWN+'/native-inspection-r01';
const N=B+'foundation02-fifth10-native-candidate-proposal-r03';
const INPUT=B+'foundation02-fifth10-root-native-r03/input.json';
const FAILURE='Related broad Professional graph remains its exact pending preimage: safe.free-from-unacceptable-danger.adj';
const observed=new Map(),findings=[];let passed=0;let measurements={};
function eq(a,b,label){if(isDeepStrictEqual(a,b))passed++;else findings.push({label,actual:a,expected:b});}
function hash(b){return crypto.createHash('sha256').update(b).digest('hex');}
function abs(p){if(path.isAbsolute(p))return p;if(p.includes('\\')||p.split('/').some(v=>!v||v==='.'||v==='..'))throw Error('Invalid path '+p);return path.resolve(ROOT,p);}
function raw(p){const s=fs.lstatSync(abs(p));eq(s.isFile()&&!s.isSymbolicLink(),true,'Regular input '+p);const b=fs.readFileSync(abs(p)),pin={path:p,bytes:b.length,raw_sha256:hash(b)};if(observed.has(p))eq(pin,observed.get(p),'Repeated input unchanged '+p);observed.set(p,pin);return b;}
function pin(p){if(!observed.has(p))raw(p);return observed.get(p);}
function json(p){return JSON.parse(raw(p));}
function verify(p){eq(pin(p.path),p,'Exact complete pin '+p.path);}
function save(p,v){fs.writeFileSync(abs(OUT+'/'+p),JSON.stringify(v,null,2)+'\n',{flag:'wx'});}
function sort(v){return [...v].sort((a,b)=>a.path.localeCompare(b.path));}
function add(map,p){if(map.has(p.path))eq(map.get(p.path),p,'Conflict-free source union '+p.path);else map.set(p.path,p);}
eq(path.resolve(process.cwd()).toLowerCase(),path.resolve(ROOT).toLowerCase(),'Correct worktree');
fs.mkdirSync(abs(OUT));save('started.json',{schema:1,status:'started',reviewer:'/root/morph_review',at:new Date().toISOString()});
let selected=null;
try{
  pin(OWN+'/inspect-native.cjs');
  selected=json(OWN+'/native-review-input.json');eq(selected.status,'actual_root_native_results_selected_for_raw_review','Actual receipt selection status');
  verify(selected.receipt);verify(selected.witness);
  const receipt=json(selected.receipt.path),witness=json(selected.witness.path),input=json(INPUT),start=json(N+'/execution-r01/start.json');
  eq(pin(INPUT),{path:INPUT,bytes:4580,raw_sha256:'bf5dfde98504d1a87d92cccad41c9c9b6e698db57c66bc9b9bd718386d40b46b'},'Exact accepted native dispatch input');
  eq(receipt.status,'isolated_native_candidate_passed','Actual native success status');eq(receipt.ok,true,'Native actual success');eq(receipt.error,null,'No native error');eq(receipt.postcheck_error,null,'No final native postcheck failure');
  eq(receipt.production_mutated,false,'Native did not mutate production');eq(receipt.project_node_tests_executed,false,'Native did not rerun Node tests');eq(receipt.persisted_integration_accepted,false,'Native is not persisted acceptance');
  eq(start.status,'root_dispatched_one_shot_native_candidate','Native actual start status');eq(start.root_input,pin(INPUT),'Start exact native input');eq(receipt.root_input,pin(INPUT),'Receipt exact native input');
  for(const key of ['source_inventory','independent_source_review','actual_binding','preparation','independent_afterimage_review','godot_binary','correction']){eq(receipt[key],input[key],'Native receipt identity '+key);eq(start[key],input[key],'Native start identity '+key);}
  eq(witness.kind,'native','Root witness kind');eq(witness.dispatcher,'/root','Root witness dispatcher');eq(witness.exit_code,0,'Actual root native process success exit');eq(witness.signal,null,'Actual root native signal');eq(witness.error,null,'Actual root native process error');eq(witness.receipt,selected.receipt,'Root witness receipt pin');
  verify(witness.source);verify(witness.input);verify(witness.start);eq(witness.source.path,N+'/run.cjs','Actual native source path');eq(witness.source.raw_sha256,'64a924fc9ae48122f51aa36a2c7a986f2e7ff7d93e1989345cde1e2be1be1d15','Exact accepted native source');eq(witness.input,pin(INPUT),'Actual root input pin');eq(witness.start,pin(N+'/execution-r01/start.json'),'Actual root start pin');eq(witness.cwd,ROOT,'Actual root native workspace');
  eq(witness.command,['node',N+'/run.cjs','--root-input',INPUT,'--root-input-sha256',pin(INPUT).raw_sha256],'Actual one-shot native root invocation');eq(witness.replay_allowed,false,'Consumed native must not replay');eq(witness.actual_installation,false,'Root witness does not claim installation');eq(witness.persisted_validation,false,'Root witness does not claim persisted validation');
  eq(witness.final_tool_result.exit_code,0,'Actual root tool completion');eq(JSON.parse(witness.final_tool_result.output.trim()),{ok:true,status:'isolated_native_candidate_passed',receipt:selected.receipt,error:null,postcheck_error:null},'Exact actual outer terminal output');eq(witness.receipt_summary,{check_only_passed:true,native_checks:3922,native_failures:0},'Root observed successful native summary');
  const binding=json(input.actual_binding.path),prep=json(input.preparation.receipt.path),closure=json(N+'/closure.json');
  eq(receipt.registry_after_sha256,binding.registry_after_sha256,'Actual native projected registry');
  const expectedSources=new Map();
  add(expectedSources,pin(INPUT));add(expectedSources,input.source_inventory);
  for(const f of json(input.source_inventory.path).files)add(expectedSources,{...f,path:N+'/'+f.path});
  for(const p of [input.independent_source_review,input.actual_binding,...binding.input_files,...Object.values(input.preparation),prep.source_inventory,prep.independent_source_review,input.independent_afterimage_review])add(expectedSources,p);
  const prepdir=path.posix.dirname(input.preparation.receipt.path);
  for(const p of prep.artifacts)add(expectedSources,{...p,path:prepdir+'/'+p.path});
  const repair=json(input.correction.receipt.path),repairInput=json(input.preparation.root_input.path),repairDispatch=json(input.correction.root_dispatch.path),outputManifest=json(input.correction.output_manifest.path),repairObserved=json(input.correction.source_observations.path),afterimage=json(input.independent_afterimage_review.path),projectedInput=json(B+'foundation02-fifth10-projected-validation-r03/input.json');
  eq(input.preparation,projectedInput.preparation,'Both actual candidates share corrected preparation');eq(input.correction,projectedInput.correction,'Both actual candidates share external correction');eq(afterimage.preparation,input.preparation,'Native corrected afterimage exact preparation');eq(afterimage.correction,input.correction,'Native corrected afterimage exact correction');eq(afterimage.status,'accepted_for_root_owned_fifth10_native_candidate_validation','Corrected native acceptance status');eq(afterimage.native_candidate_execution_accepted,true,'Corrected native execution accepted');eq(repair.status,'corrected_preparation_pending_fresh_afterimage_review_and_root_validation','Successful repair receipt');eq(repairDispatch.exit_code,0,'Successful root repair outcome');eq(repair.corrected_preparation_receipt,input.preparation.receipt,'Exact corrected preparation receipt');
  for(const p of [...Object.values(input.correction),...outputManifest.files,...repairObserved.inputs])add(expectedSources,p);
  const lineage=repair.lineage;
  for(const key of ['original_preparation_receipt','original_execution_end','original_root_input','original_source_inventory','original_independent_source_review','original_output_manifest','failed_native_receipt','rejected_candidate_review','correction_root_input','correction_source_inventory','correction_independent_source_review','route_edit'])add(expectedSources,lineage[key]);
  const repairInventory=json(prep.source_inventory.path);for(const p of repairInventory.files)add(expectedSources,{...p,path:path.posix.dirname(prep.source_inventory.path)+'/'+p.path});
  const originalManifest=json(lineage.original_output_manifest.path);for(const p of originalManifest.files)add(expectedSources,{...p,path:originalManifest.original_directory+'/'+p.path});
  for(const p of [repairDispatch.contract,repairDispatch.stdout,repairDispatch.stderr,repairInput.contract.corrected_native_afterimage])add(expectedSources,p);
  const actualSources=json(N+'/execution-r01/source-inputs.json');
  eq(new Set(actualSources.files.map(p=>p.path)).size,actualSources.files.length,'No duplicate protected native source');
  eq(sort(actualSources.files),sort([...expectedSources.values()]),'Exact entire native protected-source union');
  eq(actualSources.files.length,receipt.source_input_count,'Native receipt source-input count');
  for(const p of actualSources.files)verify(p);
  verify(input.godot_binary);
  const artifacts=new Map(prep.artifacts.map(p=>[p.path,{...p,path:prepdir+'/'+p.path}]));
  const overlays=new Map(closure.future_overlays.map(v=>[v.target,artifacts.get(v.artifact)]));
  const expectedRows=closure.baseline_files.map(p=>({path:p.path,source:overlays.get(p.path)||p}));
  for(const [target,source]of overlays)if(!expectedRows.some(r=>r.path===target))expectedRows.push({path:target,source});
  eq(expectedRows.length,492,'Exact baseline-plus-overlay planned source-copy count');
  const config=Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Fifth Ten Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
  const generated={path:'project.godot',bytes:config.length,raw_sha256:hash(config)};
  const planned=json(N+'/execution-r01/planned-copies.json'),completed=json(N+'/execution-r01/completed-copies.json'),copied=json(N+'/execution-r01/copied-inputs.json');
  eq(planned.files,expectedRows,'Exact native planned source-copy rows');eq(planned.generated_project,generated,'Exact generated project descriptor');
  const expectedCopied=expectedRows.map(r=>({path:r.path,source:r.source,bytes:r.source.bytes,raw_sha256:r.source.raw_sha256}));expectedCopied.push({...generated,source:null});
  eq(copied.files,expectedCopied,'Exact native copied manifest');eq(completed.files,expectedCopied,'Exact native completed manifest');eq(completed.complete,true,'Copy completion true');
  eq(receipt.planned_copy_count,493,'Receipt planned complete project count');eq(receipt.completed_copy_count,493,'Receipt completed project count');
  for(const p of completed.files)verify({path:N+'/execution-r01/project/'+p.path,bytes:p.bytes,raw_sha256:p.raw_sha256});
  eq(raw(N+'/execution-r01/project/project.godot'),config,'Exact generated configuration bytes');
  eq(receipt.commands.length,2,'Exactly two actual native commands');
  const projectPath=path.resolve(ROOT,N,'execution-r01/project');
  for(let i=0;i<2;i++){
    const c=receipt.commands[i];const direct=json(N+'/execution-r01/command-'+(i+1)+'.json');eq(c,direct,'Exact command receipt '+i);eq(c.sequence,i+1,'Command sequence '+i);eq(c.kind,i===0?'check_only':'native_suite','Command kind '+i);eq(c.executable,input.godot_binary,'Exact executable pin '+i);eq(c.cwd,projectPath,'Actual isolated project cwd '+i);
    eq(c.args,['--headless','--path',projectPath,...(i===0?['--check-only']:[]),'--script','res://tests/godot/professional_retail_morphology_tests.gd'],'Exact actual child arguments '+i);
    eq(c.exit_code,0,'Actual successful child exit '+i);eq(c.error,null,'Actual successful child error '+i);eq(c.signal,null,'Child signal '+i);eq(c.postcheck_ok,true,'Child postcheck '+i);verify(c.stdout);verify(c.stderr);
    eq(Date.parse(c.finished_at)>=Date.parse(c.started_at),true,'Child chronological result '+i);
    const combined=raw(c.stdout.path).toString('utf8')+'\n'+raw(c.stderr.path).toString('utf8');eq(/(?:^|\n)(?:SCRIPT )?ERROR:/m.test(combined),false,'No script error in actual child log '+i);
    eq([...combined.matchAll(/^FAIL: (.*)\r?$/gm)].map(m=>m[1].replace(/\r$/,'')),[],'No actual failure lines '+i);
    const summaries=[...combined.matchAll(/^Professional Retail morphology: (\d+) checks, (\d+) failures\r?$/gm)];
    if(i===0){eq(c.summary,null,'Check-only is not suite success');eq(summaries.length,0,'No test-suite summary in check-only log');}
    else {eq(summaries.length,1,'Exactly one actual native summary');if(summaries.length===1){const actual={checks:Number(summaries[0][1]),failures:Number(summaries[0][2])};eq(c.summary,actual,'Successful receipt matches actual raw summary');eq(actual,{checks:3922,failures:0},'Exact actual successful suite summary from raw log');}}
  }
  const labels=['before-native','after-command-1','after-command-2','final'];eq(receipt.postchecks.map(c=>c.label),labels,'All required native postchecks recorded');
  for(const [i,c]of receipt.postchecks.entries()){
    verify(c.evidence);eq(c.ok,true,'Recorded postcheck passed '+c.label);const p=json(c.evidence.path);eq(p.label,labels[i],'Actual postcheck label');eq(p.ok,true,'Actual postcheck passed');eq(p.errors,[],'No native postcheck error');eq(p.expected_source_count,actualSources.files.length,'Postcheck expected sources');eq(p.verified_source_count,actualSources.files.length,'Postcheck all sources verified');eq(p.expected_isolated_count,493,'Postcheck expected isolated count');eq(p.verified_isolated_count,493,'Postcheck all copied files verified');
  }
  for(const p of binding.must_remain_absent)eq(fs.existsSync(abs(p)),false,'Native production addition remains absent '+p);
  const id='safe.free-from-unacceptable-danger.adj';
  const project=N+'/execution-r01/project/';
  const historical=json(project+'data/professional/provenance/retail-module03-morphology-fifth10-2026-10-16.json');
  const lexical=json(project+'data/professional/lexemes/foundation-module02.json');
  const language=json(project+'data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json');
  const snapshots=historical.protected_related_entries.filter(p=>p.entry.id===id),patches=language.patches.filter(p=>p.id===id),live=lexical.lexemes.find(p=>p.id===id);
  eq(snapshots.length,1,'Exactly one historical safe snapshot');eq(patches.length,1,'Exactly one later accepted safe patch');
  eq(live,patches[0].after,'Actual live safe is exact accepted language afterimage');eq(snapshots[0].entry,patches[0].before,'Historical safe snapshot is exact accepted language preimage');
  eq(live.morphology,snapshots[0].entry.morphology,'Safe morphology itself is completely unchanged');eq(live.morphology.review.status,'pending','Safe morphology review remains pending');
  const changed=Object.keys(live).filter(k=>!isDeepStrictEqual(live[k],snapshots[0].entry[k])).sort();eq(changed,['definition','editorial_notes','references','review'],'Exact full-entry difference causing historical assertion failure');
  const testText=raw(project+'tests/godot/professional_retail_morphology_tests.gd').toString('utf8');
  const edit=json(repair.lineage.route_edit.path);eq(testText.split(edit.after).length-1,1,'Exact corrected safe-only assertion executed once');eq(testText.includes(edit.before),false,'Original unadapted historical assertion absent');
  measurements={source_input_count:actualSources.files.length,planned_source_copies:492,complete_isolated_inputs:493,native_summary_from_raw_log:{checks:3922,failures:0},receipt_native_summary:receipt.commands[1].summary,postchecks:labels,absence_checks:binding.must_remain_absent.length,native_planned_copies:pin(N+'/execution-r01/planned-copies.json'),native_completed_copies:pin(N+'/execution-r01/completed-copies.json'),native_source_inputs:pin(N+'/execution-r01/source-inputs.json'),root_dispatch:{kind:'native',exit_code:witness.exit_code,signal:witness.signal,error:witness.error,receipt:selected.receipt},root_dispatch_witness:selected.witness,correction:input.correction,preparation_correction:{receipt:input.correction.receipt,attempt_end:input.correction.attempt_end,dispatch_witness:input.correction.root_dispatch,corrected_preparation_receipt:input.preparation.receipt},correction_confirmation:{id,source:pin(project+'tests/godot/professional_retail_morphology_tests.gd'),actual_entry_equals_accepted_after:true,historical_snapshot_equals_accepted_before:true,morphology_unchanged_and_pending:true,exact_safe_only_reversal_executed:true}};

}catch(error){findings.push({label:'Inspection exception',message:String(error),stack:error.stack});}
const finalPins=[...observed.values()];
for(const p of finalPins){try{eq({path:p.path,bytes:fs.statSync(abs(p.path)).size,raw_sha256:hash(fs.readFileSync(abs(p.path)))},p,'Final unchanged native result input '+p.path);}catch(error){findings.push({label:'Final input check '+p.path,message:String(error)});}}
save('inputs.json',{schema:1,files:sort(finalPins)});
const result={schema:1,status:findings.length?'native_result_review_has_findings':'actual_native_candidate_result_corroborated',reviewer:'/root/morph_review',at:new Date().toISOString(),receipt:selected?.receipt,witness:selected?.witness,comparisons_passed:passed,findings,inputs_rehashed_at_end:finalPins.length,measurements,native_candidate_accepted:findings.length===0,actual_installation:false,persisted_validation:false,scope:{independent_raw_inspection_only:true,project_or_proposal_modules_executed:false,native_not_rerun:true,projected_result_not_reviewed_here:true}};
save('inspection.json',result);console.log(JSON.stringify({...result,findings:findings.map(f=>({label:f.label,message:f.message}))},null,2));process.exitCode=findings.length?1:0;
