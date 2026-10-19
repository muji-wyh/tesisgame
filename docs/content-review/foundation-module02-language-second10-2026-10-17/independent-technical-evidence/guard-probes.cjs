'use strict';
// Adversarial delivery preflight probes use in-memory fixtures and deny all writes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../../../..'),pkg='build/professional-english/foundation-module02-language-review/second10-delivery-r02';
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const L=require(path.join(root,pkg,'delivery-lib.cjs')),prepared=L.read(pkg+'/preparation-receipt.json');
const reviewed=[...prepared.files,...['preparation-receipt.json','preparation-attempt-001.json'].map(name=>({path:pkg+'/'+name,raw_sha256:L.raw(pkg+'/'+name)}))];
const technicalPath='build/professional-english/in-memory-review-probe.json';
const source=fs.readFileSync(path.join(root,pkg,'deliver.cjs'),'utf8'),sourceHash=L.byteHash(source),selfHash=L.byteHash(fs.readFileSync(__filename));
const compile=vm.compileFunction(source,['require','__dirname','module','exports','__filename'],{filename:pkg+'/deliver.cjs'});
const cases=[
  {name:'missing root exclusive window',args:{'--exclusive-window':'not-confirmed'}},
  {name:'wrong binding hash',args:{'--binding-sha':'0'.repeat(64)}},
  {name:'existing transaction rejects replay',exists:L.C.transaction},
  {name:'existing destination document directory rejects overwrite',exists:L.C.docs},
  {name:'unaccepted technical review',technical:t=>{t.accepted=false;}},
  {name:'omitted native afterimage review',technical:t=>{t.reviewed_files=t.reviewed_files.filter(x=>!x.path.endsWith('/professional_retail_morphology_tests.gd.after'));}},
  {name:'omitted preparation execution witness review',technical:t=>{t.reviewed_files=t.reviewed_files.filter(x=>!x.path.endsWith('/preparation-attempt-001.json'));}},
  {name:'failed preparation completion',change:{file:pkg+'/preparation-attempt-001.json',mutate:x=>{x.status=1;}}},
  {name:'changed preparation source witness',change:{file:pkg+'/preparation-attempt-001.json',mutate:x=>{x.source_files[0].raw_sha256='0'.repeat(64);}}},
];
const results=[];
for(const probe of cases){
  const technical={accepted:true,review_kind:'technical_only',fixture_only:true,reviewed_files:structuredClone(reviewed)};if(probe.technical)probe.technical(technical);
  const techHash=L.hash(technical),args={'--binding-sha':L.raw(pkg+'/binding.json'),'--technical-review':technicalPath,'--technical-sha':techHash,'--exclusive-window':'confirmed-by-root',...probe.args};
  let transactionReached=false,writeReached=false;
  const denied=()=>{writeReached=true;throw Error('Unexpected mutation reached.');};
  const fakeFs=new Proxy(fs,{get(target,key){if(key==='existsSync')return file=>probe.exists&&path.resolve(file)===L.at(probe.exists)?true:target.existsSync(file);if(/^(write|append|rename|unlink|rm|mkdir|copy|truncate|open)/.test(String(key)))return denied;return target[key];}});
  const fake={...L,fs:fakeFs,args:()=>args,save:denied,raw:file=>file===technicalPath?techHash:L.raw(file),read:file=>{if(file===technicalPath)return structuredClone(technical);const value=L.read(file);if(probe.change&&probe.change.file===file)probe.change.mutate(value);return value;}};
  const load=name=>{if(name==='./delivery-lib.cjs')return fake;transactionReached=true;throw Error('Unexpected transaction module reached.');};
  let error;try{compile(load,path.join(root,pkg),{exports:{}},{},path.join(root,pkg,'deliver.cjs'));}catch(e){error=e;}
  assert(error,probe.name+' must reject');assert.equal(error.code,'ERR_ASSERTION',probe.name);assert.equal(writeReached,false);assert.equal(transactionReached,false);
  results.push({name:probe.name,rejected:true,error_code:error.code,transaction_reached:false,mutation_reached:false});
}
assert.equal(L.byteHash(fs.readFileSync(path.join(root,pkg,'deliver.cjs'))),sourceHash);assert.equal(L.byteHash(fs.readFileSync(__filename)),selfHash);
for(const row of reviewed)assert.equal(L.raw(row.path),row.raw_sha256);
const report={schema:1,ok:true,scope:'Nine in-memory negative preflight probes, all writes denied. Synthetic review fixture is not a persisted acceptance.',production_mutated:false,native_dispatched:false,delivery_source:{path:pkg+'/deliver.cjs',raw_sha256:sourceHash},executed_source:{path:path.relative(root,__filename).replaceAll('\\','/'),raw_sha256:selfHash},cases:results};
fs.writeFileSync(path.join(__dirname,'guard-probes.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({ok:true,cases:results.length,guard_probes_sha256:L.byteHash(fs.readFileSync(path.join(__dirname,'guard-probes.json')))}));
