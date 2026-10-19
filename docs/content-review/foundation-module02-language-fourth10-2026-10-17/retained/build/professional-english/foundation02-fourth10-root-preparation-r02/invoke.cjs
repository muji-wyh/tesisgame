'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../../..'),base='build/professional-english/foundation02-fourth10-delivery-preparation-r02';
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const bind=p=>{const b=fs.readFileSync(path.join(root,p));return{path:p,bytes:b.length,sha256:hash(b)}};
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const inventory=bind(base+'/author-inventory.json');assert.equal(inventory.sha256,'aece2564d2a9f0d6261ba57f8613fc862b5541f5fba01e80bb3f8c8651384ff6');
const review=bind('build/professional-english/foundation02-fourth10-preparation-source-review-r02/review.json');assert.equal(review.sha256,'2511462555e4235129d032aa51bd214aa3d0ae725b92b8cc9cd251de34c7d969');
const names=['input-pins.json','input-freeze-receipt.json','projection.cjs','test-transforms.cjs','prepare.cjs','HANDOFF.md','TRANSACTION.md','author-r02.cjs','revision-derivation.json','author-coverage-r02.cjs','coverage-supplement.json','freeze-inputs.cjs','author-inventory.json'];
const sources=names.map(n=>bind(base+'/'+n));
const witness=read('build/professional-english/foundation02-fourth10-root-preparation-r02/dispatch-source.json');assert.equal(witness.wrapper_sha256,hash(fs.readFileSync(__filename)));assert.equal(witness.execution,false);
assert(!fs.existsSync(path.join(root,base,'execution-r01')));
const out=path.join(__dirname,'execution');assert(!fs.existsSync(out));fs.mkdirSync(out);
const write=(name,v)=>fs.writeFileSync(path.join(out,name),JSON.stringify(v,null,2)+'\n',{flag:'wx'});
const commands=[['--check',base+'/projection.cjs'],['--check',base+'/test-transforms.cjs'],['--check',base+'/prepare.cjs'],[base+'/prepare.cjs','--root-dispatch','confirmed-by-root']];
const started=new Date().toISOString();write('start.json',{schema:1,started_at:started,review,inventory,sources,commands,wrapper_sha256:witness.wrapper_sha256});
const results=[];
for(const args of commands){
  assert(sources.every(row=>bind(row.path).sha256===row.sha256));
  const began=new Date().toISOString(),run=spawnSync(process.execPath,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:600000,maxBuffer:32*1024*1024});
  const output=(run.stdout||'')+(run.stderr||''),log='command-'+String(results.length+1)+'.log';fs.writeFileSync(path.join(out,log),output,{flag:'wx'});
  results.push({command:[process.execPath,...args],started_at:began,finished_at:new Date().toISOString(),exit_code:run.status,error:run.error?.message||null,signal:run.signal,log,log_sha256:hash(Buffer.from(output))});
  process.stdout.write(output);if(run.status!==0||run.error)break;
}
const sourcesAfter=sources.map(row=>bind(row.path)),unchanged=JSON.stringify(sources)===JSON.stringify(sourcesAfter);
const receipt={schema:1,ok:results.length===4&&results.every(r=>r.exit_code===0&&!r.error)&&unchanged,started_at:started,finished_at:new Date().toISOString(),review,inventory,sources,sources_after:sourcesAfter,sources_unchanged:unchanged,commands:results,scope:'Single scratch preparation; no production, native or persisted acceptance.'};
write('receipt.json',receipt);console.log(JSON.stringify({ok:receipt.ok,receipt:bind(path.relative(root,path.join(out,'receipt.json')))}));process.exitCode=receipt.ok?0:1;
