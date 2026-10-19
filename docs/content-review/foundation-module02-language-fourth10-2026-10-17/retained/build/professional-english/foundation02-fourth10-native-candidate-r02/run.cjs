'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../../..'),base='build/professional-english/foundation02-fourth10-delivery-preparation-r02/execution-r01';
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),json=v=>JSON.stringify(v,null,2)+'\n';
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const bind=p=>{const raw=fs.readFileSync(path.join(root,p));return{path:p,bytes:raw.length,sha256:hash(raw)}};
const rel=p=>path.relative(root,p).replaceAll('\\','/');
const dispatch=read(rel(path.join(__dirname,'dispatch-source.json')));assert.equal(dispatch.wrapper_sha256,hash(fs.readFileSync(__filename)));assert.equal(dispatch.execution,false);
for(const row of dispatch.accepted_inputs) assert.equal(bind(row.path).sha256,row.sha256,row.path);
const prep=read(base+'/preparation-receipt.json'),record=read(base+'/accepted-language.json');
assert.equal(prep.status,'frozen_preparation_pending_independent_technical_review');assert.equal(read(base+'/execution-end.json').status,'prepared_pending_independent_technical_review');
const sources={...prep.measured_input_sha256};for(const row of prep.source_baseline.source_pins){if(sources[row.path])assert.equal(sources[row.path],row.raw_sha256);sources[row.path]=row.raw_sha256;}
function verify(){for(const [file,expected] of Object.entries(sources))assert.equal(bind(file).sha256,expected,file);for(const row of [...prep.source_files,...prep.artifacts])assert.equal(bind(row.path).sha256,row.raw_sha256,row.path);for(const row of dispatch.accepted_inputs)assert.equal(bind(row.path).sha256,row.sha256,row.path);}
verify();const out=path.join(__dirname,'attempt-001');assert(!fs.existsSync(out),'Preserve every consumed native candidate attempt.');fs.mkdirSync(out);
const write=(file,raw)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw,{flag:'wx'});};
const started=new Date().toISOString(),commands=[],copies=[];let failure=null;
write(path.join(out,'start.json'),json({schema:1,started_at:started,wrapper_sha256:dispatch.wrapper_sha256,accepted_inputs:dispatch.accepted_inputs,measured_input_sha256:sources,scope:'Exact prepared native afterimage in isolated copied project; no production mutation.'}));
try{
  const project=path.join(out,'project');fs.mkdirSync(project);
  const overlays=new Map([
    ['data/professional/lexemes/foundation-module02.json','foundation-module02.json.after'],
    ['data/professional/sources.json','sources.json.after'],
    ['data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json','accepted-language.json'],
    ['tests/godot/professional_retail_morphology_tests.gd','professional_retail_morphology_tests.gd.after']
  ]);
  function copy(file){const source=overlays.has(file)?base+'/'+overlays.get(file):file,raw=fs.readFileSync(path.join(root,source));write(path.join(project,file),raw);copies.push({path:file,source,bytes:raw.length,sha256:hash(raw)});overlays.delete(file);}
  function walk(dir){for(const e of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){assert(!e.isSymbolicLink());const p=dir+'/'+e.name;if(e.isDirectory())walk(p);else if(e.isFile())copy(p);}}
  walk('data/professional');walk('data/vocabulary/morphology');
  for(const file of ['words.json','scripts/morphology_analysis.gd','scripts/morphology_resolver.gd','scripts/growth_morphology.gd'])copy(file);
  for(const file of [...overlays.keys()])copy(file);
  const config=Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Fourth Ten Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
  write(path.join(project,'project.godot'),config);copies.push({path:'project.godot',source:'root-authored isolated test configuration',bytes:config.length,sha256:hash(config)});
  write(path.join(out,'copied-inputs.json'),json(copies));
  for(const checkOnly of [true,false]){
    const args=['tools/run-godot.cjs','--headless','--path',project,...(checkOnly?['--check-only']:[]),'--script','res://tests/godot/professional_retail_morphology_tests.gd'];
    const began=new Date().toISOString(),run=spawnSync(process.execPath,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:600000,maxBuffer:32*1024*1024});
    const raw=Buffer.from((run.stdout||'')+(run.stderr||'')),log='command-'+(commands.length+1)+'.log';write(path.join(out,log),raw);
    commands.push({command:[process.execPath,...args],started_at:began,finished_at:new Date().toISOString(),exit_code:run.status,error:run.error?.message||null,signal:run.signal,log,log_sha256:hash(raw)});
    assert(!run.error,run.error?.message);assert.equal(run.status,0,raw.toString().slice(-6000));assert(!/(?:^|\n)(?:SCRIPT )?ERROR:/.test(raw.toString()),raw.toString().slice(-6000));
  }
  for(const row of copies)assert.equal(hash(fs.readFileSync(path.join(project,row.path))),row.sha256,row.path);
  verify();assert.equal(hash(fs.readFileSync(__filename)),dispatch.wrapper_sha256);
}catch(error){failure=error.stack||String(error);}
const receipt={schema:1,ok:failure===null,started_at:started,finished_at:new Date().toISOString(),wrapper_sha256:dispatch.wrapper_sha256,accepted_inputs:dispatch.accepted_inputs,preparation:bind(base+'/preparation-receipt.json'),current_input_count:Object.keys(sources).length,commands,copied_input_count:copies.length,registry_after_sha256:record.source_baseline.registry_after_sha256,error:failure,scope:'Exact native afterimage parsed and executed in an isolated copied content project. No persisted integration acceptance.'};
write(path.join(out,'receipt.json'),json(receipt));console.log(json({ok:receipt.ok,commands,error:failure,receipt:bind(rel(path.join(out,'receipt.json')))}));process.exitCode=receipt.ok?0:1;
