'use strict';
// UNEXECUTED proposal. Only root may bind accepted real outputs and dispatch this file.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const ROOT = path.resolve(__dirname, '../../..');
const OWN = 'build/professional-english/foundation02-fifth10-native-candidate-proposal-r01';
const PREP = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const PREP_OUT = PREP + '/execution-r01';
const BINDING_PATH = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r02/execution-r01/actual-baseline-binding.json';
const BINDING_HASH = '7323bcb1baac6ea85817169bcc90325f9b54d587b19d4895ca3106ee7af0e015';
const AUTHOR = '/root/morph_review';
const NATIVE = 'tests/godot/professional_retail_morphology_tests.gd';
const PROVENANCE = 'data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json';
const COPIED_ROOTS = ['data/professional', 'data/vocabulary/morphology', 'professional-media'];
const COPIED_SINGLE_FILES = ['words.json', 'scripts/morphology_analysis.gd', 'scripts/morphology_resolver.gd', 'scripts/growth_morphology.gd'];
const OVERLAYS = [
  {target:'data/professional/lexemes/foundation-module02.json',artifact:'foundation-module02.json.after',operation:'replace'},
  {target:'data/professional/sources.json',artifact:'sources.json.after',operation:'replace'},
  {target:PROVENANCE,artifact:'production-provenance.prepared.json',operation:'add_absent_pending_actual_stage_finalization'},
  {target:NATIVE,artifact:'professional_retail_morphology_tests.gd.after',operation:'replace'}
];
const CONFIG = Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Fifth Ten Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const jsonHash = v => hash(JSON.stringify(v));
const serial = v => Buffer.from(JSON.stringify(v, null, 2) + '\n');
const pins = new Map();
function at(p) {
  assert.equal(ROOT.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
  assert.equal(typeof p,'string');assert(p && !p.includes('\\') && !path.isAbsolute(p));
  const absolute=path.resolve(ROOT,p);assert.equal(path.relative(ROOT,absolute).replaceAll('\\','/'),p);return absolute;
}
function exactPin(p) {
  assert(p);assert.deepEqual(Object.keys(p).sort(),['bytes','path','raw_sha256']);
  at(p.path);assert(Number.isSafeInteger(p.bytes)&&p.bytes>=0);assert.match(p.raw_sha256,/^[a-f0-9]{64}$/);return p;
}
function raw(p) {const absolute=at(p);assert(fs.lstatSync(absolute).isFile(),'Regular input file required: '+p);return fs.readFileSync(absolute);}
function verify(p) {exactPin(p);const b=raw(p.path);assert.equal(b.length,p.bytes,p.path);assert.equal(hash(b),p.raw_sha256,p.path);return b;}
function add(p) {
  const b=verify(p),key=p.path.toLowerCase();
  if(pins.has(key))assert.deepEqual(pins.get(key),p,'Conflicting/case-ambiguous pin: '+p.path);
  else pins.set(key,structuredClone(p));return b;
}
function parsed(p) {return JSON.parse(add(p));}
function reviewer(value, forbidden) {assert.equal(typeof value,'string');assert.match(value,/^\/root(?:\/[a-z0-9_]+)?$/);assert(!forbidden.includes(value),'Reviewer is not independent for this artifact');}
function inventory(p) {
  const v=parsed(p),names=new Set();assert.equal(v.status,'frozen_unexecuted_fifth10_native_candidate_sources');assert.equal(v.author,AUTHOR);
  assert(Array.isArray(v.files)&&v.files.length>0);
  for(const r of v.files){assert.equal(typeof r.path,'string');assert(!r.path.includes('\\')&&!r.path.startsWith('../')&&!path.posix.isAbsolute(r.path));assert(!names.has(r.path.toLowerCase()));names.add(r.path.toLowerCase());add({path:path.posix.dirname(p.path)+'/'+r.path,bytes:r.bytes,raw_sha256:r.raw_sha256});}
  return v;
}
function descendants(directory) {
  const found=[];
  function walk(p){for(const e of fs.readdirSync(at(p),{withFileTypes:true})){assert(!e.isSymbolicLink(),'Symlink in copied closure: '+p+'/'+e.name);const next=p+'/'+e.name;if(e.isDirectory())walk(next);else {assert(e.isFile());found.push(next);}}}
  walk(directory);return found.sort();
}
function runtimeBytes(runtime) {
  assert.deepEqual(Object.keys(runtime).sort(),['bytes','path','raw_sha256']);
  assert.equal(typeof runtime.path,'string');assert(path.isAbsolute(runtime.path));assert.equal(runtime.path,runtime.path.trim());assert.match(runtime.path,/\.exe$/i);
  assert(Number.isSafeInteger(runtime.bytes)&&runtime.bytes>0);assert.match(runtime.raw_sha256,/^[a-f0-9]{64}$/);
  assert(fs.lstatSync(runtime.path).isFile());const b=fs.readFileSync(runtime.path);assert.equal(b.length,runtime.bytes);assert.equal(hash(b),runtime.raw_sha256);return b;
}
function gates() {
  assert.equal(process.argv.length,6);assert.equal(process.argv[2],'--root-input');assert.equal(process.argv[4],'--root-input-sha256');
  const inputPath=process.argv[3],inputHash=process.argv[5];assert.match(inputHash,/^[a-f0-9]{64}$/);
  const inputBytes=raw(inputPath);assert.equal(hash(inputBytes),inputHash);const rootInputPin={path:inputPath,bytes:inputBytes.length,raw_sha256:inputHash};
  const config=parsed(rootInputPin);
  assert.equal(config.schema,1);assert.equal(config.status,'root_authorized_one_shot_fifth10_native_candidate');
  assert.equal(config.dispatcher,'/root');assert.equal(config.proposal_author,AUTHOR);
  assert.equal(config.entrypoint,OWN+'/run.cjs');assert.equal(config.output,OWN+'/execution-r01');assert(!inputPath.startsWith(config.output+'/'));
  assert.equal(config.execute_native,true);assert.equal(config.execute_project_node_tests,false);
  assert.deepEqual(config.guards,{production_writers_yielded:true,source_and_output_acceptances_complete:true,isolated_destination_reviewed:true});
  assert(!fs.existsSync(at(config.output)),'Consumed native attempts are immutable; a failure needs a fresh reviewed revision.');
  assert.equal(config.source_inventory.path,OWN+'/source-inventory.json');inventory(config.source_inventory);
  const sourceReview=parsed(config.independent_source_review);
  assert.equal(sourceReview.status,'accepted_for_one_root_owned_fifth10_native_candidate');
  reviewer(sourceReview.reviewer,[AUTHOR]);assert.equal(sourceReview.source_execution_accepted,true);
  assert.deepEqual(sourceReview.source_inventory,config.source_inventory);
  assert.equal(config.actual_binding.path,BINDING_PATH);assert.equal(config.actual_binding.bytes,3187477);assert.equal(config.actual_binding.raw_sha256,BINDING_HASH);
  const binding=parsed(config.actual_binding);
  assert.equal(binding.status,'root_bound_actual_post_bag_persisted_baseline');assert.equal(binding.bound,true);
  assert.deepEqual(binding.roles,{preparation_author:'/root/recover_delivery',inherited_preparation_author:'/root/runtime_recovery',dispatcher:'/root',independent_reviewer:'/root/morph_review'});
  assert.equal(binding.input_files.length,12443);assert.equal(new Set(binding.input_files.map(p=>p.path.toLowerCase())).size,binding.input_files.length);
  for(const p of binding.input_files)add(p);
  const closure=JSON.parse(raw(OWN+'/closure.json'));
  assert.equal(closure.status,'unbound_copy_closure_derived_only_from_actual_binding_metadata');
  assert.deepEqual(closure.actual_binding,config.actual_binding);
  assert.deepEqual(closure.copy_roots,COPIED_ROOTS);assert.deepEqual(closure.copy_single_files,COPIED_SINGLE_FILES);
  const selected=binding.input_files.filter(p=>COPIED_ROOTS.some(r=>p.path.startsWith(r+'/'))||COPIED_SINGLE_FILES.includes(p.path));
  assert.deepEqual(closure.baseline_files,selected);assert.deepEqual(closure.future_overlays,OVERLAYS);
  for(const dir of COPIED_ROOTS)assert.deepEqual(descendants(dir),selected.filter(p=>p.path.startsWith(dir+'/')).map(p=>p.path).sort(),'Unpinned or missing copied directory file: '+dir);
  for(const p of selected)assert.deepEqual(pins.get(p.path.toLowerCase()),p);
  const preparation=config.preparation;
  assert.deepEqual(Object.keys(preparation).sort(),['execution_end','projection_observation','receipt','root_input','target_plan']);
  const required={receipt:'preparation-receipt.json',execution_end:'execution-end.json',target_plan:'target-plan.json',projection_observation:'projection-observation.json'};
  for(const [k,name]of Object.entries(required))assert.equal(preparation[k].path,PREP_OUT+'/'+name);
  const receipt=parsed(preparation.receipt),end=parsed(preparation.execution_end),plan=parsed(preparation.target_plan),projection=parsed(preparation.projection_observation),prepInput=parsed(preparation.root_input);
  assert.equal(receipt.status,'prepared_pending_independent_afterimage_review_and_root_validation');assert.equal(end.status,'prepared_pending_independent_review');
  assert.equal(plan.status,'scratch_plan_not_commit_authorization');assert.equal(projection.status,'built_in_json_projection_only');
  for(const [v,keys]of [[receipt,['project_or_test_execution','native_executed','production_mutated','actual_fifth10_commit','actual_fifth10_persisted_validation']],[end,['production_mutated']],[plan,['production_mutated','project_or_test_execution']],[projection,['actual_validator_loaded','test_callbacks_executed','native_executed','production_mutated']]])for(const k of keys)assert.equal(v[k],false,k);
  assert.deepEqual(receipt.actual_binding,config.actual_binding);
  assert.equal(receipt.source_inventory.path,PREP+'/source-inventory.json');assert.equal(receipt.source_inventory.raw_sha256,'2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3');
  add(receipt.source_inventory);const bindingAcceptance=parsed(receipt.independent_source_review);
  assert.equal(bindingAcceptance.status,'accepted_for_one_root_owned_fifth10_scratch_preparation');assert.equal(bindingAcceptance.preparation_execution_accepted,true);assert.deepEqual(bindingAcceptance.actual_binding,config.actual_binding);assert.deepEqual(bindingAcceptance.source_inventory,receipt.source_inventory);
  assert.equal(prepInput.status,'root_authorized_one_shot_scratch_preparation');assert.equal(prepInput.dispatcher,'/root');assert.equal(prepInput.entrypoint,PREP+'/prepare.cjs');assert.equal(prepInput.output,PREP_OUT);assert.equal(prepInput.execute_project_tests,false);
  assert.deepEqual(prepInput.binding,config.actual_binding);assert.deepEqual(prepInput.source_inventory,receipt.source_inventory);assert.deepEqual(prepInput.independent_source_review,receipt.independent_source_review);
  const artifactMap=new Map();
  for(const p of receipt.artifacts){assert.equal(typeof p.path,'string');assert(!p.path.includes('\\')&&!path.posix.isAbsolute(p.path)&&!p.path.startsWith('../'));assert(!artifactMap.has(p.path.toLowerCase()));const full={...p,path:PREP_OUT+'/'+p.path};add(full);artifactMap.set(p.path.toLowerCase(),full);}
  for(const k of ['target_plan','projection_observation'])assert.deepEqual(artifactMap.get(path.posix.basename(preparation[k].path).toLowerCase()),preparation[k]);
  const startPin=artifactMap.get('execution-start.json');assert(startPin);const start=parsed(startPin);
  assert.equal(start.status,'started');assert.deepEqual(start.root_input,preparation.root_input);assert.deepEqual(start.actual_binding,config.actual_binding);assert.deepEqual(start.source_inventory,receipt.source_inventory);assert.deepEqual(start.independent_source_review,receipt.independent_source_review);
  assert(!fs.existsSync(at(PREP_OUT+'/failed-attempt.json')),'Failed preparation is never a valid native candidate');
  const outputAcceptance=parsed(config.independent_afterimage_review);
  assert.equal(outputAcceptance.status,'accepted_for_root_owned_fifth10_native_candidate_validation');
  reviewer(outputAcceptance.reviewer,['/root','/root/recover_delivery','/root/runtime_recovery']);
  assert.equal(outputAcceptance.projected_afterimages_accepted,true);assert.equal(outputAcceptance.native_candidate_execution_accepted,true);
  assert.deepEqual(outputAcceptance.actual_binding,config.actual_binding);assert.deepEqual(outputAcceptance.preparation,preparation);
  assert.deepEqual(outputAcceptance.preparation_source_inventory,receipt.source_inventory);
  assert.equal(receipt.target_count,binding.target_paths.length);assert.equal(plan.targets.length,receipt.target_count);
  assert.equal(new Set(plan.targets.map(r=>r.path.toLowerCase())).size,plan.targets.length);
  assert.deepEqual(plan.targets.map(r=>r.path).sort(),binding.target_paths.slice().sort());
  const targetMap=new Map();
  for(const r of plan.targets){
    at(r.path);assert.equal(typeof r.artifact,'string');const p=artifactMap.get(r.artifact.toLowerCase());assert(p,'Missing prepared artifact: '+r.path);
    assert.equal(p.path,PREP_OUT+'/'+r.artifact);assert.equal(p.bytes,r.bytes);assert.equal(p.raw_sha256,r.after_sha256||r.prepared_sha256);
    if(r.operation==='replace'){const prior=pins.get(r.path.toLowerCase());assert(prior);assert.equal(r.before_sha256,prior.raw_sha256);}
    else {assert(['add_absent','add_absent_pending_actual_stage_finalization'].includes(r.operation));assert(binding.must_remain_absent.includes(r.path));assert(!fs.existsSync(at(r.path)),'Production addition already exists: '+r.path);}
    targetMap.set(r.path,r);
  }
  const overlayMap=new Map();
  for(const expected of OVERLAYS){const actual=targetMap.get(expected.target);assert(actual);assert.equal(actual.artifact,expected.artifact);assert.equal(actual.operation,expected.operation);overlayMap.set(expected.target,artifactMap.get(expected.artifact.toLowerCase()));}
  assert.equal(projection.registry_before_sha256,binding.registry_before_sha256);assert.equal(projection.registry_after_sha256,binding.registry_after_sha256);assert.deepEqual(projection.counts,binding.counts);
  const record=JSON.parse(verify(overlayMap.get(PROVENANCE)));
  assert.equal(record.status,'prepared_afterimage_pending_independent_review_and_actual_delivery');assert.equal(record.production_integrated,false);
  assert.equal(record.registry_before_sha256,binding.registry_before_sha256);assert.equal(record.registry_after_sha256,binding.registry_after_sha256);assert.deepEqual(record.counts,binding.counts);
  assert.equal(record.lineage.fifth10_commit_receipt,null);assert.equal(record.lineage.fifth10_persisted_receipt,null);
  assert.equal(record.history.rows.length,50);
  for(const p of record.history.history_files){assert(selected.some(v=>v.path===p.path),'Complete donor history must be copied: '+p.path);assert.deepEqual(pins.get(p.path.toLowerCase()),p);}
  const bagFile='data/professional/provenance/retail-shopping-bag-image-2026-10-17.json';
  assert(selected.some(p=>p.path===bagFile));const bag=JSON.parse(verify(pins.get(bagFile.toLowerCase())));
  assert(selected.some(p=>p.path===bag.resource.path));assert.equal(pins.get(bag.resource.path.toLowerCase()).raw_sha256,'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb');
  assert.deepEqual(record.delivered_bag.entry,bag.patches[0].after);assert.equal(jsonHash(record.delivered_bag.entry),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');
  runtimeBytes(config.godot_binary);
  const copyRows=selected.map(p=>({path:p.path,source:overlayMap.get(p.path)||p}));
  for(const [target,p]of overlayMap)if(!copyRows.some(r=>r.path===target))copyRows.push({path:target,source:p});
  assert.equal(new Set(copyRows.map(r=>r.path.toLowerCase())).size,copyRows.length);assert(!copyRows.some(r=>r.path==='project.godot'));
  return {config,rootInputPin,binding,receipt,record,copyRows,sourcePins:[...pins.values()]};
}
function main() {
  // Gating reads only raw bytes/JSON. No project import or child process precedes this gate.
  const ctx=gates(),out=at(ctx.config.output);fs.mkdirSync(out);
  const started=new Date().toISOString(),project=path.join(out,'project'),commands=[],copies=[],postchecks=[];
  let failure=null,finalPostcheckError=null;
  function save(name,value){assert.equal(typeof name,'string');assert(!name.includes('\\')&&!path.isAbsolute(name)&&!name.startsWith('../'));const p=path.resolve(out,name);assert.equal(path.relative(out,p).replaceAll('\\','/'),name);fs.mkdirSync(path.dirname(p),{recursive:true});const b=Buffer.isBuffer(value)?value:serial(value);fs.writeFileSync(p,b,{flag:'wx'});return {path:ctx.config.output+'/'+name,bytes:b.length,raw_sha256:hash(b)};}
  function projectPath(p){at(p);const dest=path.resolve(project,p);assert.equal(path.relative(project,dest).replaceAll('\\','/'),p);return dest;}
  function postcheck(label) {
    const errors=[];let verifiedInputs=0,verifiedCopies=0;
    for(const p of ctx.sourcePins){try{verify(p);verifiedInputs++;}catch(error){errors.push({kind:'source',path:p.path,error:String(error.message||error)});}}
    for(const p of copies){try{const b=fs.readFileSync(projectPath(p.path));assert.equal(b.length,p.bytes);assert.equal(hash(b),p.raw_sha256);verifiedCopies++;}catch(error){errors.push({kind:'isolated_copy',path:p.path,error:String(error.message||error)});}}
    try{runtimeBytes(ctx.config.godot_binary);}catch(error){errors.push({kind:'runtime',path:ctx.config.godot_binary.path,error:String(error.message||error)});}
    for(const p of ctx.binding.must_remain_absent)if(fs.existsSync(at(p)))errors.push({kind:'production_addition',path:p,error:'Expected production absence changed'});
    const result={schema:1,label,recorded_at:new Date().toISOString(),ok:errors.length===0,expected_source_count:ctx.sourcePins.length,verified_source_count:verifiedInputs,expected_isolated_count:copies.length,verified_isolated_count:verifiedCopies,errors};
    const evidence=save('postchecks/'+String(postchecks.length+1).padStart(2,'0')+'-'+label+'.json',result);postchecks.push({label,ok:result.ok,evidence});return result;
  }
  try {
    save('start.json',{schema:1,status:'root_dispatched_one_shot_native_candidate',started_at:started,root_input:ctx.rootInputPin,source_inventory:ctx.config.source_inventory,independent_source_review:ctx.config.independent_source_review,actual_binding:ctx.config.actual_binding,preparation:ctx.config.preparation,independent_afterimage_review:ctx.config.independent_afterimage_review,godot_binary:ctx.config.godot_binary,node_executable:process.execPath,production_mutated:false});
    save('source-inputs.json',{schema:1,files:ctx.sourcePins});
    save('planned-copies.json',{schema:1,files:ctx.copyRows,generated_project:{path:'project.godot',bytes:CONFIG.length,raw_sha256:hash(CONFIG)}});
    fs.mkdirSync(project);
    for(const row of ctx.copyRows){const b=verify(row.source),destination=projectPath(row.path);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,b,{flag:'wx'});copies.push({path:row.path,source:row.source,bytes:b.length,raw_sha256:hash(b)});}
    fs.writeFileSync(projectPath('project.godot'),CONFIG,{flag:'wx'});copies.push({path:'project.godot',source:null,bytes:CONFIG.length,raw_sha256:hash(CONFIG)});
    save('copied-inputs.json',{schema:1,files:copies});
    const ready=postcheck('before-native');assert.equal(ready.ok,true,'Pre-native byte recheck failed');
    for(const checkOnly of [true,false]){
      const args=['--headless','--path',project,...(checkOnly?['--check-only']:[]),'--script','res://'+NATIVE];
      const command={sequence:commands.length+1,kind:checkOnly?'check_only':'native_suite',executable:ctx.config.godot_binary,args,cwd:project,started_at:new Date().toISOString(),finished_at:null,exit_code:null,signal:null,error:null,stdout:null,stderr:null,summary:null};
      commands.push(command);let child=null,commandError=null;
      try{
        runtimeBytes(ctx.config.godot_binary);
        child=spawnSync(ctx.config.godot_binary.path,args,{cwd:project,windowsHide:true,encoding:'utf8',timeout:600000,maxBuffer:32*1024*1024});
        command.exit_code=child.status;command.signal=child.signal;command.error=child.error?String(child.error.message||child.error):null;
        command.stdout=save('command-'+command.sequence+'.stdout.log',Buffer.from(child.stdout||''));command.stderr=save('command-'+command.sequence+'.stderr.log',Buffer.from(child.stderr||''));
        const combined=(child.stdout||'')+'\n'+(child.stderr||'');
        assert.equal(command.error,null,'Native spawn error');assert.equal(command.signal,null,'Native process terminated by signal');assert.equal(command.exit_code,0,combined.slice(-6000));
        assert(!/(?:^|\n)(?:(?:SCRIPT )?ERROR:|FAIL:)/m.test(combined),combined.slice(-6000));
        if(!checkOnly){const matches=[...combined.matchAll(/^Professional Retail morphology: (\d+) checks, (\d+) failures\r?$/gm)];assert.equal(matches.length,1,'Exactly one actual suite summary required');command.summary={checks:Number(matches[0][1]),failures:Number(matches[0][2])};assert(command.summary.checks>0);assert.equal(command.summary.failures,0);}
      }catch(error){commandError=error.stack||String(error);if(command.error===null)command.error=String(error.message||error);}
      finally {
        command.finished_at=new Date().toISOString();
        // Both root inputs and completed isolated copies are checked even when spawn/assertion fails.
        const checked=postcheck('after-command-'+command.sequence);command.postcheck_ok=checked.ok;
        save('command-'+command.sequence+'.json',command);
        if(!checked.ok&&!commandError)commandError='Input or isolated-copy drift after native command '+command.sequence;
      }
      if(commandError)throw Error(commandError);
    }
  }catch(error){failure=error.stack||String(error);}
  finally {
    try{save('completed-copies.json',{schema:1,files:copies,complete:copies.length===ctx.copyRows.length+1});}
    catch(error){finalPostcheckError='Could not retain completed-copy manifest: '+String(error.stack||error);}
    try{const final=postcheck('final');if(!final.ok)finalPostcheckError='Final source/runtime/copy/absence recheck failed';}
    catch(error){finalPostcheckError=error.stack||String(error);}
    const ok=failure===null&&finalPostcheckError===null&&commands.length===2&&commands.every(c=>c.exit_code===0&&c.error===null&&c.signal===null&&c.postcheck_ok===true);
    const receipt={schema:1,status:ok?'isolated_native_candidate_passed':'isolated_native_candidate_failed',ok,started_at:started,finished_at:new Date().toISOString(),root_input:ctx.rootInputPin,source_inventory:ctx.config.source_inventory,independent_source_review:ctx.config.independent_source_review,actual_binding:ctx.config.actual_binding,preparation:ctx.config.preparation,independent_afterimage_review:ctx.config.independent_afterimage_review,godot_binary:ctx.config.godot_binary,source_input_count:ctx.sourcePins.length,planned_copy_count:ctx.copyRows.length+1,completed_copy_count:copies.length,registry_after_sha256:ctx.record.registry_after_sha256,commands,postchecks,error:failure,postcheck_error:finalPostcheckError,production_mutated:false,project_node_tests_executed:false,persisted_integration_accepted:false,scope:'Exact accepted native/lexical/source/provenance afterimages in one isolated copied project. No production integration or full-game/device/release acceptance.'};
    const pin=save('receipt.json',receipt);console.log(JSON.stringify({ok,status:receipt.status,receipt:pin,error:failure,postcheck_error:finalPostcheckError}));process.exitCode=ok?0:1;
  }
}
main();
