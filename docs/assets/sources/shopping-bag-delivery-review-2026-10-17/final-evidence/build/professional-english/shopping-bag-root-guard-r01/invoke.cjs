'use strict';
// Root-owned one-shot read-only guards. Cache exact bytes in memory, then rehash real files on every outcome.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(path.resolve(process.cwd()),root);
assert.equal(process.argv.length,5);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),encode=v=>Buffer.from(JSON.stringify(v,null,2)+'\n');
const sourceHash=sha(fs.readFileSync(__filename));assert.equal(sourceHash,process.argv[2]);
const inputPath='build/professional-english/shopping-bag-root-commit-r01/input.json';
const commitPath='build/professional-english/shopping-bag-commit-proposal-r01/commit.cjs';
const probePath='build/professional-english/shopping-bag-commit-proposal-r01/guard-probe.cjs';
const commitHash='b522c987354d2e526cc9194b0dd5239b2592b07aa30f4ddd7bd16261e2c3c087';
const probeHash='606b14e55469c212d39e24e16a0bcbdf51e3c46330bc8ecf5bb23b732a11bdf7';
const absolute=p=>{assert(typeof p==='string'&&!path.isAbsolute(p)&&!p.includes('\\')&&!p.split('/').includes('..'));return path.join(root,p);};
const raw=p=>fs.readFileSync(absolute(p)),inputBytes=raw(inputPath);
assert.equal(sha(inputBytes),process.argv[3]);assert.equal(sha(raw(commitPath)),commitHash);assert.equal(sha(raw(probePath)),probeHash);
const input=JSON.parse(inputBytes),token=process.argv[4];assert.match(token,/^[0-9a-f]{64}$/);assert.equal(sha(token),input.exclusive_token_sha256);
const attempt=path.join(__dirname,'attempt-001');assert(!fs.existsSync(attempt),'Never replay consumed guard attempt');fs.mkdirSync(attempt);
const save=(name,v)=>fs.writeFileSync(path.join(attempt,name),encode(v),{flag:'wx'});
save('start.json',{schema:1,started_at:new Date().toISOString(),source_sha256:sourceHash,input_sha256:process.argv[3],commit_sha256:commitHash,probe_sha256:probeHash});
const pins=new Map([[inputPath,process.argv[3]],[commitPath,commitHash],[probePath,probeHash]]),cache=new Map(),existence=new Map();
let result=null,failure=null,postcheck=null;
const observed={
 read(p){if(!cache.has(p)){const b=raw(p);cache.set(p,b);if(pins.has(p))assert.equal(sha(b),pins.get(p),p);else pins.set(p,sha(b));}return Buffer.from(cache.get(p));},
 exists(p){const found=fs.existsSync(absolute(p));if(existence.has(p))assert.equal(found,existence.get(p),p);else existence.set(p,found);return found;},
 list:p=>fs.readdirSync(absolute(p))
};
try{
 const ci=JSON.parse(raw(input.contract.candidate.input.path));
 const add=(p,h)=>{if(pins.has(p))assert.equal(pins.get(p),h,p);pins.set(p,h);};
 for(const[p,h]of Object.entries(ci.expected_inputs))add(p,h);
 for(const r of [...ci.evidence_files,...input.contract.source_witnesses,input.independent_review,input.contract.candidate.input,input.contract.candidate.receipt,...input.contract.candidate.dependency_supplements,...input.contract.finalized.map(r=>r.source),...input.contract.evidence_additions.map(r=>r.source)])add(r.path,r.sha256);
 for(const[p,h]of pins)assert.equal(sha(observed.read(p)),h,p);
 const probe=require(absolute(probePath));
 result=probe.runProbe(input,observed,{repository_root:root,source_sha256:commitHash,token});
 assert.equal(result.status,'memory_guards_passed');assert(result.cases.every(r=>r.passed));
}catch(error){failure=error.stack||String(error);result={cases:error.probe_cases||[],real_inputs:error.probe_real_inputs||[]};}
try{
 assert.equal(sha(fs.readFileSync(__filename)),sourceHash);
 for(const[p,h]of pins)assert.equal(sha(raw(p)),h,'Real file changed: '+p);
 for(const[p,value]of existence)assert.equal(fs.existsSync(absolute(p)),value,'Real existence changed: '+p);
}catch(error){postcheck=error.stack||String(error);}
const receipt={schema:1,ok:failure===null&&postcheck===null,finished_at:new Date().toISOString(),source_sha256:sourceHash,input_sha256:process.argv[3],commit_sha256:commitHash,probe_sha256:probeHash,result,error:failure,postcheck_error:postcheck,protected_file_count:pins.size,protected_inputs:Object.fromEntries(pins),existence_checks:Object.fromEntries(existence),production_mutated:false,transaction_helper_executed:false,scope:'Cached exact real bytes for read-only validation and synthetic negative guards, followed by real filesystem rehash even after failure. No project tests, registry load, native replay, or installation.'};
save('receipt.json',receipt);console.log(JSON.stringify({ok:receipt.ok,cases:result?.cases?.length,protected_files:pins.size,receipt_sha256:sha(encode(receipt)),error:failure,postcheck_error:postcheck}));process.exitCode=receipt.ok?0:1;
