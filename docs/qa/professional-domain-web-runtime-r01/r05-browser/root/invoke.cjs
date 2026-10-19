'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..'), stage = process.argv[2];
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert(['materialize','browser'].includes(stage));
const hash = raw => crypto.createHash('sha256').update(raw).digest('hex');
const bind = file => { const raw=fs.readFileSync(path.join(root,file)); return {path:file,bytes:raw.length,sha256:hash(raw)}; };
const harness='build/professional-english/domain-runtime-web-browser-r05';
const expected={
  'inventory.json':'86978ca1b5921ef3a945c806d0c6c92d25bf2b467c636d820bf8b9c1168e4a24',
  'proposal.json':'3b52a39be761dc8f8566e605877965a87129a9fae44b4df232ed0fbf14b60ce3',
  'inherited-inputs.json':'e38f78572410065afc3c5bfc4f8053b332e9c911c6e9af83c1824a72a85af432'
};
const inputs=Object.entries(expected).map(([file,sha])=>{const row=bind(harness+'/'+file);assert.equal(row.sha256,sha);return row;});
const inventory=JSON.parse(fs.readFileSync(path.join(root,harness,'inventory.json'),'utf8'));
for(const row of inventory.files) assert.deepEqual(bind(harness+'/'+row.path),{...row,path:harness+'/'+row.path});
const witnessFile=path.join(__dirname,'dispatch-source.json');
const witness=JSON.parse(fs.readFileSync(witnessFile,'utf8'));
assert.equal(witness.wrapper_sha256,hash(fs.readFileSync(__filename)));
assert.equal(witness.dispatch_performed,false);
if(stage==='browser') {
  const inspection=JSON.parse(fs.readFileSync(path.join(__dirname,'materialized-inspection.json'),'utf8'));
  assert.equal(inspection.ok,true);
  assert.equal(inspection.actual_receipt.sha256,bind(harness+'/attempt-001/shell-supplement.json').sha256);
}
const directory=path.join(__dirname,stage);
assert(!fs.existsSync(directory),'Preserve prior root witness.'); fs.mkdirSync(directory);
const args=[harness+'/'+stage+'.cjs'],started=new Date().toISOString(),source=bind(args[0]);
const write=(name,value)=>fs.writeFileSync(path.join(directory,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
write('start.json',{schema:1,started_at:started,command:[process.execPath,...args],inputs,source,dispatch_source:bind(path.relative(root,witnessFile))});
const run=spawnSync(process.execPath,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:600000,maxBuffer:32*1024*1024});
const output=(run.stdout||'')+(run.stderr||''); fs.writeFileSync(path.join(directory,'execution.log'),output,{flag:'wx'});
const unchanged=inputs.every(row=>bind(row.path).sha256===row.sha256)&&bind(source.path).sha256===source.sha256;
const receipt={schema:1,stage,command:[process.execPath,...args],started_at:started,finished_at:new Date().toISOString(),exit_code:run.status,signal:run.signal,error:run.error?.message||null,inputs,source,inputs_unchanged:unchanged,log_sha256:hash(Buffer.from(output)),ok:run.status===0&&!run.error&&unchanged,scope:'One browser-only supplement stage of the successful r04 export; no new export or native proof, no production acceptance.'};
write('receipt.json',receipt); process.stdout.write(output); console.log(JSON.stringify({ok:receipt.ok,stage,receipt:bind(path.relative(root,path.join(directory,'receipt.json')))}));
process.exitCode=receipt.ok?0:1;
