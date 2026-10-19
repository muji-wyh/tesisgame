'use strict';
// Root-owned proposed test updater. Default is read-only; --apply is guarded and transactional.
const lib = require('./delivery-lib.cjs');
const plan = require('./transaction-plan.cjs');
const {testPaths, transformTests} = require('./persisted-test-transforms.cjs');
const {commitTransaction,recoverTransaction,describePlan} = require('./guarded-transaction.cjs');
const {fs,path,raw,read,hash,inRoot,serialized,root,constants,createChecks,parseArgs}=lib;
const hashArgs=['--preimages-sha256','--integration-receipt-sha256'];
if(process.argv.includes('--recover'))hashArgs.push('--transaction-plan-sha256');
const args=parseArgs(hashArgs,['--apply','--recover']);
lib.assert.ok(!(args['--apply']&&args['--recover']),'Choose test application or explicit recovery');
const check=createChecks(),{same}=check;
const prePath=path.join(__dirname,'preimages.json'),integrationPath=path.join(__dirname,'integration-receipt.json');
same(raw(prePath),args['--preimages-sha256']);same(raw(integrationPath),args['--integration-receipt-sha256']);
const pre=read(prePath),integration=read(integrationPath);
same(integration.integrated,true);same(integration.preimages_raw_sha256,raw(prePath));
same(integration.after_registry_sha256,pre.proposed_registry_sha256);
same(hash(lib.loadProfessionalContent(root)),integration.after_registry_sha256);
same(raw(inRoot(constants.provenance)),integration.provenance_raw_sha256);
same(raw(inRoot(constants.target)),integration.target_after_raw_sha256);
same(raw(inRoot('professional-media/'+constants.imageSha+'.png')),constants.imageSha);
for(const[file,sha]of Object.entries(pre.delivery_files))same(raw(path.join(__dirname,file)),sha);
const statesDir=path.join(inRoot(constants.transaction),'states');
const states=fs.readdirSync(statesDir).filter(file=>/^\d{6}-[a-z-]+\.json$/.test(file)).sort();
same(states.length>0,true);
const committed=read(path.join(statesDir,states.at(-1)));same(committed.status,'committed');
same(committed.prepared_sha256,raw(path.join(inRoot(constants.transaction),'prepared.json')));
const prepared=read(path.join(inRoot(constants.transaction),'prepared.json'));
for(const file of prepared.entries)same(raw(inRoot(file.path)),file.after.sha256,'Committed image transaction output');
const receiptPath=path.join(__dirname,'persisted-tests-update-receipt.json');
const transactionDir=inRoot('build/professional-english/transactions/counter-persisted-tests-r02');
const allowedPaths=[...testPaths.map(inRoot),receiptPath];
if(args['--recover']){
  const result=recoverTransaction({repositoryRoot:root,transactionDir,allowedPaths,expectedPlanSha256:args['--transaction-plan-sha256']});
  if(result.status!=='committed'){
    same(['rolled-back','not-prepared'].includes(result.status),true);
    for(const file of testPaths)same(raw(inRoot(file)),pre.validated_measured_inputs[file]);
    same(fs.existsSync(receiptPath),false);
  }
  same(hash(lib.loadProfessionalContent(root)),integration.after_registry_sha256);
  console.log(JSON.stringify({recovery:result,registry_sha256:integration.after_registry_sha256,checks:check.count()}));process.exit(0);
}
const inputs={};
for(const file of testPaths){same(raw(inRoot(file)),pre.validated_measured_inputs[file],'Test file must match successful pre-image validation');inputs[file]=fs.readFileSync(inRoot(file),'utf8');}
const outputs=transformTests(inputs),changes=testPaths.map(file=>({path:inRoot(file),before:Buffer.from(inputs[file]),after:Buffer.from(outputs[file])}));
const summary={schema:1,dry_run:!args['--apply'],status:'proposed_counter_persisted_test_update',checks:check.count(),
  preimages_raw_sha256:raw(prePath),integration_receipt_raw_sha256:raw(integrationPath),registry_sha256:integration.after_registry_sha256,
  files:changes.map(change=>({path:lib.relative(change.path),before_sha256:plan.sha256(change.before),after_sha256:plan.sha256(change.after)})),
  scope:'Exact counter image reversal is added to earlier media histories and both fifth10 historical full-entry protections. Current image count becomes five. Counter source/provenance assertions are added; native morphology checks stay unchanged.'};
same(fs.existsSync(receiptPath),false);
const receipt={...summary,dry_run:false,status:'counter_persisted_tests_updated_pending_execution'};
changes.push({path:receiptPath,before:null,after:Buffer.from(serialized(receipt))});
const options={repositoryRoot:root,transactionDir,allowedPaths,changes},described=describePlan(options);
if(!args['--apply']){console.log(JSON.stringify({...summary,transaction_plan_sha256:described.planSha256}));process.exit(0);}
const transaction=commitTransaction({...options,verify(){
    for(const change of changes)same(fs.readFileSync(change.path),change.after);
    same(hash(lib.loadProfessionalContent(root)),integration.after_registry_sha256);
    same(raw(inRoot(constants.provenance)),integration.provenance_raw_sha256);
  }});
console.log(JSON.stringify({...receipt,checks:check.count(),transaction_plan_sha256:described.planSha256,transaction}));
