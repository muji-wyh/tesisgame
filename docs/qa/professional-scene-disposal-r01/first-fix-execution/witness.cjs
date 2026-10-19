'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname,'../../..');
const output = path.join(__dirname,'scene-disposal-fix-r01');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
if (fs.existsSync(output)) throw Error('This execution is one-shot. Preserve failures and use an affected supplement.');
const files = ['project.godot','tools/run-godot.cjs','tools/run-tests.cjs','scenes/main.tscn','assets/images/words/absent.png','assets/audio/jelly-match/collect-do.wav'];
for (const directory of ['scripts','tests/godot']) {
  for (const name of fs.readdirSync(path.join(root,directory))) if (name.endsWith('.gd') && name !== 'professional_scene_modes_disposal_tests.gd') files.push(directory+'/'+name);
}
files.sort();
const snapshot = () => files.map(file=>{const raw=fs.readFileSync(path.join(root,file));return {path:file,bytes:raw.length,sha256:digest(raw)};});
fs.mkdirSync(output);
const before=snapshot(), started=new Date().toISOString(), results=[];
fs.writeFileSync(path.join(output,'inputs-before.json'),JSON.stringify(before,null,2)+'\n',{flag:'wx'});
const names=['professional_scene_disposal','professional_play','professional_application_flow','professional_view_teardown','jelly_match_flow','jelly_match_audio'];
const phases=[...['professional_scene_disposal','professional_play'].map(name=>({name,syntax:true})),
  ...names.map(name=>({name,syntax:false}))];
for (const {name,syntax} of phases) {
  const args=['--headless','--path',root,...(syntax?['--check-only']:[]),'--script','res://tests/godot/'+name+'_tests.gd'];
  const label=name+(syntax?'-syntax':'-runtime');
  const began=new Date().toISOString();
  const run=spawnSync(process.env.GODOT_BIN||'godot',args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:180000,maxBuffer:16*1024*1024});
  const log=(run.stdout||'')+(run.stderr||'');
  fs.writeFileSync(path.join(output,label+'.log'),log,{flag:'wx'});
  const ok=run.status===0&&!run.error&&!/(?:^|\n)(?:SCRIPT )?ERROR:|^FAIL:/m.test(log);
  const result={label,command:[process.env.GODOT_BIN||'godot',...args],started_at:began,finished_at:new Date().toISOString(),
    exit_code:run.status,signal:run.signal,error:run.error?.message||null,log_sha256:digest(Buffer.from(log)),ok};
  results.push(result);
  fs.writeFileSync(path.join(output,label+'.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({...result,summary:log.split(/\r?\n/).filter(line=>/checks|failures|ERROR|FAIL:/.test(line)).slice(-12)}));
  if (!ok) break;
}
const after=snapshot();
fs.writeFileSync(path.join(output,'inputs-after.json'),JSON.stringify(after,null,2)+'\n',{flag:'wx'});
const report={schema_version:1,started_at:started,finished_at:new Date().toISOString(),results,
  planned_executions:phases.length,inputs_unchanged:JSON.stringify(before)===JSON.stringify(after),input_count:before.length,
  ok:results.length===phases.length&&results.every(row=>row.ok)&&JSON.stringify(before)===JSON.stringify(after),
  scope:'Affected scene disposal, Play, application, view and Jelly regressions after terminal close/media cleanup fix. No compiled Web success, curriculum, media approval, physical-device, performance or acoustic acceptance.'};
fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({ok:report.ok,executions:results.length,inputs_unchanged:report.inputs_unchanged,receipt_sha256:digest(fs.readFileSync(path.join(output,'receipt.json')))}));
process.exitCode=report.ok?0:1;
