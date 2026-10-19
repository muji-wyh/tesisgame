'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const revision=process.argv[2]||'r01';
assert.match(revision,/^r\d{2}$/);
const receiptFile=path.join(__dirname,'continuation-validation-'+revision+'.json');
assert.ok(!fs.existsSync(receiptFile),'Use a fresh revision; earlier evidence is immutable.');
const suites=['professional-content','professional-retail-morphology','professional-retail-media','professional-approved-audio','professional-picture-exclusions','theme-motion','test-runner'];
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const files=[];
function collect(relative) {
  for(const entry of fs.readdirSync(path.join(root,relative),{withFileTypes:true})) {
    const file=relative+'/'+entry.name;
    if(entry.isDirectory()) collect(file);
    else if(/\.(?:json|gd|cjs)$/.test(file)) files.push(file);
  }
}
for(const dir of ['data/professional','data/vocabulary/morphology','scripts','tools']) collect(dir);
for(const suite of suites) files.push('tests/'+suite+'.test.cjs');
files.push('tests/godot/professional_retail_morphology_tests.gd');
files.push('tests/godot/professional_approved_audio_tests.gd');
files.push('build/professional-english/validate-continuation.cjs');
files.push('docs/assets/sources/innerscene-kenney-nursing-theme/theme-acceptance-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/cart-basket/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/pallet-shelf/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/bag-wrap/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/counter-checkout/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/counter-checkout/human-approval-r01.json');
files.push('docs/assets/sources/professional-retail-ava/card-reader-barcode/listening-approval-2026-10-16.json');
files.push('docs/assets/sources/professional-retail-ava/card-reader-barcode/human-approval-r01.json');
const {loadProfessionalContent}=require(path.join(root,'tools/validate-professional-content.cjs'));
const data=loadProfessionalContent(root);
for(const entry of data.lexemes) for(const media of Object.values(entry.media)) if(media?.status==='integrated'&&media.path?.startsWith('res://')) files.push(media.path.slice(6));
for(const theme of data.themes) if(theme.status==='ready') {
  for(const media of Object.values(theme.art||{})) if(media.path?.startsWith('res://')) files.push(media.path.slice(6));
  for(const clip of theme.ambient_motion?.clips||[]) if(clip.image.path?.startsWith('res://')) files.push(clip.image.path.slice(6));
}
const paths=[...new Set(files)].sort();
const measure=()=>Object.fromEntries(paths.map(file=>[file,hash(fs.readFileSync(path.join(root,file)))]));
const before=measure(), registryBefore=hash(JSON.stringify(data)), runs=[];
const run=(name,args,timeout)=>{
  const log=path.join(__dirname,'continuation-'+name+'-'+revision+'.log');
  assert.ok(!fs.existsSync(log));
  const started=Date.now();
  const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout,maxBuffer:32*1024*1024,windowsHide:true});
  const output=(result.stdout||'')+(result.stderr||'');
  fs.writeFileSync(log,output,{flag:'wx'});
  const summary={name,args,status:result.status,signal:result.signal,error:result.error?.message||null,duration_ms:Date.now()-started,
    log:path.relative(root,log).replaceAll('\\','/'),log_sha256:hash(output)};
  if(name==='node') for(const field of ['tests','pass','fail','cancelled','skipped']) summary[field]=Number(output.match(new RegExp('^[#ℹ] '+field+' (\\d+)','m'))?.[1]??-1);
  else {const pattern=name==='native-audio'?/Professional approved audio: (\d+) checks, (\d+) failures/:/Professional Retail morphology: (\d+) checks, (\d+) failures/;const match=output.match(pattern);summary.checks=match?Number(match[1]):-1;summary.failures=match?Number(match[2]):-1;}
  runs.push(summary); console.log(JSON.stringify(summary));
};
run('node',['--test',...suites.map(s=>'tests/'+s+'.test.cjs')],360000);
run('native',['tools/run-godot.cjs','--headless','--path','.','--script','res://tests/godot/professional_retail_morphology_tests.gd'],180000);
run('native-audio',['tools/run-godot.cjs','--headless','--path','.','--script','res://tests/godot/professional_approved_audio_tests.gd'],180000);
const after=measure(), changed=paths.filter(file=>before[file]!==after[file]);
const registryAfter=hash(JSON.stringify(loadProfessionalContent(root)));
const ok=runs.every(r=>r.status===0&&!r.error&&(r.name==='node'?r.tests>0&&r.pass===r.tests&&r.fail===0&&r.skipped===0:r.checks>0&&r.failures===0))&&changed.length===0&&registryBefore===registryAfter;
const receipt={schema:1,recorded_at:new Date().toISOString(),ok,scope:'Complete Professional content suite plus selected morphology/media/audio/picture/motion/runner suites and native persisted Retail morphology and all '+data.lexemes.filter(entry=>entry.media.audio.status==='integrated').length+' approved recordings. No browser, full game, additional human listening or module acceptance claim.',
  runs,registry_before_sha256:registryBefore,registry_after_sha256:registryAfter,measured_input_count:paths.length,changed_measured_inputs:changed,before_input_sha256:before,after_input_sha256:after};
fs.writeFileSync(receiptFile,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({ok,receipt:path.relative(root,receiptFile).replaceAll('\\','/'),changed}));
process.exitCode=ok?0:1;
