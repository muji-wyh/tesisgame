'use strict';
// Supplementary raw receipt/source inspection. No callback or project execution.
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const own='build/professional-english/foundation02-fifth10-afterimage-independent-review-r01';
const base='build/professional-english/shopping-bag-projected-validation-r03';
const prep='build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),inputs=new Map();
function read(p){const b=fs.readFileSync(p);const pin={path:p,bytes:b.length,raw_sha256:hash(b)};if(inputs.has(p))assert.deepEqual(pin,inputs.get(p));else inputs.set(p,pin);return b;}
const prior=JSON.parse(read(base+'/attempt-001/receipt.json'));
assert.equal(inputs.get(base+'/attempt-001/receipt.json').raw_sha256,'9a5ee12cf7ac2c4f6f6e41e7a05357a365eab570a5da1d4ce2a696143c73c121');
assert.equal(prior.ok,true);assert.equal(prior.error,null);assert(prior.callbacks.every(r=>r.passed===true));
assert.equal(hash(read(base+'/input.json')),prior.input_sha256);assert.equal(hash(read(base+'/run.cjs')),prior.source_sha256);
const originalInputs=JSON.parse(read(own+'/inspection-r01/inputs.json')).files;
const binding=JSON.parse(read('build/professional-english/foundation02-fifth10-root-binding-proposal-r02/execution-r01/actual-baseline-binding.json'));
const priorPin=inputs.get(base+'/attempt-001/receipt.json');assert.deepEqual(binding.input_files.find(p=>p.path===priorPin.path),priorPin);
const source=read(prep+'/test-transforms.cjs').toString().replaceAll('\r\n','\n');
const files=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs'];
const names=['contentTests','morphologyTests','mediaTests'],expectedPrior=[192,38,25],expectedAdded=[5,2,1];
const measured=[];
for(const [i,file]of files.entries()){
  const old=prior.callbacks.filter(r=>r.file===file).length;assert.equal(old,expectedPrior[i]);
  const marker='const '+names[i]+'=String.raw`',start=source.indexOf(marker),end=source.indexOf('`;',start+marker.length);assert(start>=0&&end>start);
  const suffix=source.slice(start+marker.length,end);assert(!suffix.includes('${'));
  const added=(suffix.match(/^test\(/gm)||[]).length;assert.equal(added,expectedAdded[i]);
  const after=prep+'/execution-r01/'+file.split('/').at(-1)+'.after';read(after);assert.deepEqual(inputs.get(after),originalInputs.find(p=>p.path===after));
  read(file);assert.deepEqual(inputs.get(file),originalInputs.find(p=>p.path===file));
  measured.push({file,prior_actual_projected_callbacks:old,exact_appended_registrations:added,expected_projected_callbacks:old+added});
}
const main=JSON.parse(read(own+'/inspection-r01/inspection.json'));assert.equal(main.status,'independent_afterimage_raw_checks_passed');assert.equal(main.checks_failed,0);
const total=measured.reduce((n,r)=>n+r.expected_projected_callbacks,0);assert.equal(total,263);assert.equal(main.measured.expected_projected_callbacks,total);
for(const p of inputs.values()){const b=fs.readFileSync(p.path);assert.equal(b.length,p.bytes);assert.equal(hash(b),p.raw_sha256);}
const result={schema:1,status:'independent_callback_counts_accepted_from_actual_predecessor_and_exact_registration_delta',reviewer:'/root/morph_review',rows:measured,expected_callbacks_by_file:Object.fromEntries(measured.map(r=>[r.file,r.expected_projected_callbacks])),expected_callback_count:total,actual_fifth10_callbacks_executed:false,basis:'Actual successful bag projected r03 receipt has 192/38/25 passed callbacks. The primary raw review reconstructs the complete current afterimages and every replacement; only the exact 5/2/1 new top-level suffix registrations are added. Bag persisted r02 independently confirms 255 prior callbacks.',inputs:[...inputs.values()],all_inputs_rehashed_at_end:true};
fs.writeFileSync(own+'/callback-counts.json',JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({expected_callbacks_by_file:result.expected_callbacks_by_file,expected_callback_count:total,inputs:inputs.size}));
