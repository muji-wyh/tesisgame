'use strict';
// Independent raw-byte/JSON inspection. No helper, preparation, project or test imports.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const util = require('node:util');
const ROOT = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const OWN = 'build/professional-english/foundation02-fifth10-actual-binding-independent-review-r01';
const PREP = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const HELPER = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r02';
const OUTPUT = HELPER + '/execution-r01';
const DURABLE = 'docs/content-review/foundation-module02-language-fifth10-2026-10-17';
const BINDING = OUTPUT + '/actual-baseline-binding.json';
const CONFIG = 'build/professional-english/foundation02-fifth10-root-capture-r02/input.json';
const run = OWN + '/inspection-r01';
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const jsonHash = x => sha(JSON.stringify(x));
const serial = x => Buffer.from(JSON.stringify(x, null, 2) + '\n');
const observed = new Map();
const failures = [];
let passed = 0;
function check(label, condition, detail) {if (condition) passed++; else failures.push({label, ...(detail === undefined ? {} : {detail})});}
function same(label, a, b) {check(label, util.isDeepStrictEqual(a, b));}
function abs(p) {
  if (typeof p !== 'string' || !p || p.includes('\\') || path.isAbsolute(p) || p.startsWith('../')) throw Error('Unsafe relative path: ' + p);
  const a = path.resolve(ROOT, p);
  if (path.relative(ROOT, a).replaceAll('\\', '/') !== p) throw Error('Noncanonical relative path: ' + p);
  return a;
}
function relative(p) {return path.isAbsolute(p) ? path.relative(ROOT, p).replaceAll('\\', '/') : p;}
function raw(p) {
  const b = fs.readFileSync(abs(p));
  const pin = {path: p, bytes: b.length, raw_sha256: sha(b)};
  if (observed.has(p)) same('Repeated raw read stable: ' + p, pin, observed.get(p));
  else observed.set(p, pin);
  return b;
}
function json(p) {return JSON.parse(raw(p));}
function pin(p) {if (!observed.has(p)) raw(p); return observed.get(p);}
function verify(p, label = 'Raw pin') {same(label + ': ' + p.path, pin(p.path), p); return p;}
function one(rows, id) {const a = rows.filter(r => r.id === id);check('Unique ID: ' + id, a.length === 1);if (a.length !== 1) throw Error('Missing/ambiguous ID: ' + id);return a[0];}
function write(name, value) {fs.writeFileSync(abs(run + '/' + name), serial(value), {flag:'wx'});}
if (fs.existsSync(abs(run))) throw Error('Consumed independent inspection; preserve it and use a new revision.');
fs.mkdirSync(abs(run));
const started = new Date().toISOString();
write('started.json', {schema:1, status:'independent_raw_inspection_started', started_at:started, reviewer:'/root/morph_review'});
let result;
try {
  const b = json(BINDING), cfg = json(CONFIG), receipt = json(OUTPUT + '/capture-receipt.json');
  const observation = json(OUTPUT + '/capture-observations.json'), start = json(OUTPUT + '/capture-start.json');
  same('Actual binding frozen pin', pin(BINDING), {path:BINDING,bytes:3187477,raw_sha256:'7323bcb1baac6ea85817169bcc90325f9b54d587b19d4895ca3106ee7af0e015'});
  same('Root capture frozen pin', pin(CONFIG), {path:CONFIG,bytes:11856,raw_sha256:'9e6dd6fd5afa6f230dc79331bfbb94cf2b5c81d622aee4758c6ea466d7a01c1c'});
  same('Binding schema/status/bound', [b.schema,b.status,b.bound], [1,'root_bound_actual_post_bag_persisted_baseline',true]);
  const roles={preparation_author:'/root/recover_delivery',inherited_preparation_author:'/root/runtime_recovery',dispatcher:'/root',independent_reviewer:'/root/morph_review'};
  same('Exact independent roles', b.roles, roles);
  same('Capture author/dispatcher/reviewer', [cfg.author,cfg.dispatcher,cfg.independent_actual_binding_reviewer], [roles.preparation_author,roles.dispatcher,roles.independent_reviewer]);
  same('Capture authorization', [cfg.status,cfg.entrypoint,cfg.output,cfg.execute_project_or_preparation_code,cfg.root_confirms_actual_bag_persisted_success,cfg.root_confirms_original_fourth10_lineage], ['root_authorized_one_shot_fifth10_actual_binding_capture',HELPER+'/capture.cjs',OUTPUT,false,true,true]);
  same('Root guards', cfg.guards, {production_writers_yielded:true,complete_inputs_frozen:true,final_destinations_reviewed:true});
  same('Bound guards equal root', b.guards,cfg.guards);
  same('Receipt status', receipt.status,'constructed_binding_pending_independent_actual_binding_review');
  for(const [k,p] of Object.entries({root_capture_input:pin(CONFIG),helper_source_inventory:cfg.helper_source_inventory,independent_helper_source_review:cfg.independent_helper_source_review,actual_binding:pin(BINDING)})) {same('Receipt pin: '+k,receipt[k],p);verify(p);}
  for(const p of receipt.artifacts) verify(p,'Capture artifact');
  same('Complete capture artifacts',receipt.artifacts.map(p=>p.path),[OUTPUT+'/capture-start.json',BINDING,OUTPUT+'/capture-observations.json']);
  for(const k of ['actual_binding_independently_accepted','preparation_execution_accepted','preparation_executed','project_or_proposal_code_imported','syntax_or_test_or_native_executed','production_mutated']) {same('Receipt no premature acceptance: '+k,receipt[k],false);same('Observation no premature acceptance: '+k,observation[k],false);}
  same('Start root input',start.root_capture_input,pin(CONFIG));
  same('Observation binding',observation.actual_binding,pin(BINDING));
  same('Observation pending delivery', [observation.fifth10_commit_receipt,observation.fifth10_persisted_receipt],[null,null]);
  const inputs = new Map();
  for(const p of b.input_files) {
    same('Exact input descriptor keys: '+p.path,Object.keys(p).sort(),['bytes','path','raw_sha256']);
    check('Unique input case path: '+p.path,!inputs.has(p.path.toLowerCase()));inputs.set(p.path.toLowerCase(),p);
    verify(p,'Binding input bytes');
  }
  same('Complete input count',inputs.size,12443);
  console.log(JSON.stringify({phase:'all_binding_inputs_rehashed',files:inputs.size,bytes:b.input_files.reduce((n,p)=>n+p.bytes,0),failures:failures.length}));
  const expected = new Map(), retain = new Set();
  function expect(p, retained=false) {
    verify(p,'Expected closure pin');
    if(expected.has(p.path)) same('Conflicting closure pin: '+p.path,expected.get(p.path),p);
    expected.set(p.path,p);
    same('Expected pin in binding: '+p.path,inputs.get(p.path.toLowerCase()),p);
    if(retained)retain.add(p.path);
  }
  function inventory(p) {
    expect(p,true);const v=json(p.path), rows=v.files||v.artifacts;
    check('Nonempty source inventory '+p.path,Array.isArray(rows)&&rows.length>0);
    same('Inventory unique member paths '+p.path,new Set(rows.map(x=>x.path.toLowerCase())).size,rows.length);
    for(const r of rows)expect({path:path.posix.dirname(p.path)+'/'+r.path,bytes:r.bytes,raw_sha256:r.raw_sha256||r.sha256},true);
    return v;
  }
  expect(pin(CONFIG),true);inventory(cfg.helper_source_inventory);expect(cfg.independent_helper_source_review,true);
  for(const p of cfg.additional_review_evidence)expect(p,true);
  const supplement=json(HELPER+'/closure-supplement.json');
  for(const p of supplement.input_files)expect(p,supplement.required_retained_sources.includes(p.path));
  for(const p of supplement.required_retained_sources) {check('Explicit retained source is pinned: '+p,expected.has(p));retain.add(p);}
  for(const p of supplement.inventory_roots)inventory(p);
  inventory(supplement.prior_helper_source_inventory);expect(supplement.prior_helper_source_review,true);
  inventory(supplement.preparation_source_inventory);expect(supplement.preparation_source_review,true);
  same('Frozen preparation source inventory',supplement.preparation_source_inventory,{path:PREP+'/source-inventory.json',bytes:3279,raw_sha256:'2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3'});
  const helperReview=json(cfg.independent_helper_source_review.path),prepReview=json(supplement.preparation_source_review.path),priorReview=json(supplement.prior_helper_source_review.path);
  same('Frozen helper accepted only capture',[helperReview.status,helperReview.helper_execution_accepted,helperReview.actual_binding_accepted,helperReview.preparation_execution_accepted],['accepted_for_one_root_owned_fifth10_binding_capture',true,false,false]);
  same('Frozen helper source pin',helperReview.source_inventory,cfg.helper_source_inventory);
  same('Frozen preparation source-only status',[prepReview.status,prepReview.source_design_accepted,prepReview.actual_binding,prepReview.preparation_execution_accepted,prepReview.projected_afterimages_accepted],['source_accepted_pending_actual_binding_and_root_guard_validation',true,null,false,false]);
  same('Frozen preparation source pin',prepReview.source_inventory,supplement.preparation_source_inventory);
  same('Prior rejected helper remains rejected',[priorReview.status,priorReview.helper_execution_accepted,priorReview.actual_binding_accepted,priorReview.preparation_execution_accepted],['source_revision_required_actual_persisted_predecessor_failed',false,false,false]);
  const priorFailure=supplement.prior_bag_persisted_failure;
  expect(priorFailure.receipt,true);expect(priorFailure.copy_receipt,true);
  const failed=json(priorFailure.receipt.path), failureCopies=json(priorFailure.copy_receipt.path);
  same('Prior bag receipt remains failure',failed.ok,false);check('Prior bag error retained',typeof failed.error==='string'&&failed.error.length>0);
  same('Prior failure copy count',failureCopies.files.length,11);
  for(const r of failureCopies.files){expect({path:r.source,bytes:r.bytes,raw_sha256:r.sha256},true);expect({path:r.target,bytes:r.bytes,raw_sha256:r.sha256},true);same('Exact failure copy: '+r.source,raw(r.source),raw(r.target));}
  expect(supplement.bag_persisted_input,true);expect(supplement.bag_persisted_source,true);
  const bagInput=json(supplement.bag_persisted_input.path);
  const union=new Set(Object.keys(bagInput.expected_inputs));let overlap=0,evidenceOnly=0;
  for(const [p,h] of Object.entries(bagInput.expected_inputs)){same('Inherited expected hash '+p,pin(p).raw_sha256,h);expect(pin(p));}
  for(const p of bagInput.evidence_files){same('Inherited evidence hash '+p.path,pin(p.path).raw_sha256,p.sha256);expect(pin(p.path),true);if(union.has(p.path)){overlap++;same('Inherited overlap agrees '+p.path,bagInput.expected_inputs[p.path],p.sha256);}else evidenceOnly++;union.add(p.path);}
  same('Inherited closure independent counts',[Object.keys(bagInput.expected_inputs).length,bagInput.evidence_files.length,overlap,evidenceOnly,union.size],[11740,579,89,490,12230]);
  same('Evidence unique identities',new Set(bagInput.evidence_files.map(p=>p.path.toLowerCase())).size,579);
  for(const p of supplement.explicit_runtime_dependencies)check('Explicit runtime dependency '+p,expected.has(p));
  const originalBagPersisted='build/professional-english/shopping-bag-persisted-validation-r02/attempt-001/receipt.json';
  expect({...cfg.bag_persisted_receipt,path:originalBagPersisted},true);
  const actualBag=json(originalBagPersisted);
  for(const c of actualBag.commands) {const p=path.posix.dirname(originalBagPersisted)+'/'+c.log;same('Original bag log hash '+p,pin(p).raw_sha256,c.log_sha256);expect(pin(p),true);}
  const predecessorSummary={};
  same('Exact predecessor kinds',Object.keys(b.predecessors).sort(),['fourth10','shopping_bag']);
  for(const [kind,s] of Object.entries(b.predecessors)){
    const isFourth=kind==='fourth10';
    same(kind+' root attestations',[s.root_confirmed_committed,s.root_confirmed_persisted],[true,true]);
    same(kind+' genuine schema',s.receipt_schema,isFourth?'foundation02_fourth10_nested_result_v1':'shopping_bag_top_level_commit_and_persisted_input_v1');
    for(const k of ['committed_receipt','committed_journal','prepared_journal','persisted_receipt'])expect(s[k],true);
    const c=json(s.committed_receipt.path),p=json(s.persisted_receipt.path),j=json(s.committed_journal.path),pr=json(s.prepared_journal.path);
    same(kind+' committed and persisted',[c.status,p.ok,p.error,j.status],['committed',true,null,'committed']);
    const ref=isFourth?{transaction:c.result.transactionDir,state:c.result.state,prepared:c.result.preparedSha256,plan:c.result.planSha256}:{transaction:c.transaction_dir,state:c.state,prepared:c.prepared_sha256,plan:c.plan_sha256};
    const tx=relative(ref.transaction),state=relative(ref.state.path);
    same(kind+' original selected journals',[s.committed_journal.path,s.prepared_journal.path,s.journal_copies],[state,tx+'/prepared.json',[]]);
    same(kind+' receipt/state/prepared identities',[s.committed_journal.raw_sha256,s.prepared_journal.raw_sha256,j.prepared_sha256],[ref.state.sha256,ref.prepared,ref.prepared]);
    same(kind+' serialized plan identities',[sha(serial(pr.plan)),pr.plan_sha256],[ref.plan,ref.plan]);
    same(kind+' repository root',path.resolve(pr.plan.repository_root).toLowerCase(),path.resolve(ROOT).toLowerCase());
    const manifest=pr.plan.entries;
    same(kind+' complete manifest uniqueness',new Set(manifest.map(r=>r.path.toLowerCase())).size,manifest.length);
    for(const r of manifest){abs(r.path);same(kind+' target row keys '+r.path,Object.keys(r).sort(),['after','before','noop','path']);check(kind+' manifest afterimage '+r.path,!!r.after&&Number.isSafeInteger(r.after.bytes)&&/^[a-f0-9]{64}$/.test(r.after.sha256));}
    same(kind+' prepared full manifest',pr.entries.map(({path,before,after,noop})=>({path,before,after,noop})),manifest);
    same(kind+' allowed paths',pr.plan.allowed_paths,manifest.map(r=>r.path).sort((a,b)=>a.toLowerCase().localeCompare(b.toLowerCase())));
    same(kind+' committed complete target manifest',j.targets,manifest.map(r=>({path:r.path,...r.after,noop:r.noop})));
    const names=fs.readdirSync(abs(tx+'/states')).filter(n=>/^\d{6}-[a-z-]+\.json$/.test(n)).sort();
    same(kind+' latest state',names.at(-1),path.posix.basename(state));
    let previous=null;
    for(const [i,n] of names.entries()){const file=tx+'/states/'+n;const v=json(file);same(kind+' state chain '+n,[v.sequence,v.previous_state_sha256,v.prepared_sha256],[i+1,previous,ref.prepared]);previous=pin(file).raw_sha256;}
    same(kind+' chain terminal',previous,ref.state.sha256);
    for(const command of p.commands){same(kind+' command succeeds '+command.log,[command.exit_code,command.signal,command.error],[0,null,null]);same(kind+' simple log basename '+command.log,path.posix.basename(command.log),command.log);const log=path.posix.dirname(s.persisted_receipt.path)+'/'+command.log;same(kind+' actual log hash '+log,pin(log).raw_sha256,command.log_sha256);expect(pin(log),true);}
    for(const a of s.success_assertions)same(kind+' supplemental assertion '+a.document+'.'+a.keys.join('.'),a.keys.reduce((v,k)=>v[k],{commit:c,journal:j,persisted:p}[a.document]),a.expected);
    if(isFourth){
      same('Fourth selected durable path',s.committed_receipt.path,'docs/content-review/foundation-module02-language-fourth10-2026-10-17/commit-receipt.json');
      same('Fourth approved hashes',[s.committed_receipt.raw_sha256,s.persisted_receipt.raw_sha256],['96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8','f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7']);
      same('Fourth genuine nested commit',[c.result.status,c.result.committed,c.result.state.status],['committed',true,'committed']);
      same('Fourth persisted receipt link',p.committed_receipt,{path:s.committed_receipt.path,sha256:s.committed_receipt.raw_sha256});
      same('Fourth persisted source unchanged',p.source_before,p.source_after);same('Fourth command/target/state counts',[p.commands.length,manifest.length,names.length],[4,133,268]);
    } else {
      same('Bag genuine top-level commit',[c.committed,Object.hasOwn(c,'result'),p.postcheck_error],[true,false,null]);
      same('Bag selected persisted receipt',s.persisted_receipt,cfg.bag_persisted_receipt);
      same('Bag original/durable receipt bytes',raw(s.persisted_receipt.path),raw(originalBagPersisted));
      same('Bag full receipt manifest',c.target_manifest,manifest);
      same('Bag embedded journal',[c.journal.status,c.journal.prepared_sha256,c.journal.plan_sha256,c.journal.state,c.journal.verified_targets],['committed',ref.prepared,ref.plan,ref.state,manifest.length]);
      expect(s.persisted_source,true);expect(s.persisted_input,true);
      same('Bag persisted raw source/input linkage',[s.persisted_source.raw_sha256,s.persisted_input.raw_sha256],[p.source_sha256,p.input_sha256]);
      same('Bag persisted input commit link',bagInput.commit_receipt,{path:s.committed_receipt.path,sha256:s.committed_receipt.raw_sha256});
      same('Bag persisted input state link',bagInput.committed_journal,{path:state,sha256:ref.state.sha256});
      same('Bag persisted input status',bagInput.status,'root_confirmed_actual_bag_commit_for_persisted_validation');
      same('Bag command/target/state counts',[p.commands.length,manifest.length,names.length,bagInput.target_count],[2,153,308,153]);
      same('Bag actual commands',p.commands.map(v=>v.args),[['tools/validate-professional-content.cjs','--json'],['--test','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs']]);
      same('Bag actual callback summary',p.tests,{tests:255,pass:255,fail:0,cancelled:0,skipped:0});same('Bag input expected callbacks',bagInput.expected_tests,255);
      same('Bag audit success and acceptance bounds',[p.audit.errors,p.audit.summary.integrated_word_images,p.audit.summary.integrated_word_audio,p.audit.summary.ready_modules,p.audit.summary.release_ready],[0,9,12,0,false]);
      for(const [k,v]of Object.entries(bagInput.expected_audit_summary))same('Bag expected audit '+k,p.audit.summary[k],v);
      const log1=json(path.posix.dirname(s.persisted_receipt.path)+'/command-1.log');same('Bag actual audit log summary',log1.summary,p.audit.summary);same('Bag actual audit log errors',log1.errors.length,p.audit.errors);
      const log2=raw(path.posix.dirname(s.persisted_receipt.path)+'/command-2.log').toString();
      for(const [k,v]of Object.entries(p.tests))check('Bag actual test log '+k,new RegExp('(?:^|\\n)(?:#|ℹ) '+k+' '+v+'(?:\\r?\\n|$)').test(log2));
      const complete=manifest.map(r=>({path:r.path,bytes:r.after.bytes,raw_sha256:r.after.sha256}));
      same('Bag installed complete set',s.installed_targets.slice().sort((a,b)=>a.path.localeCompare(b.path)),complete.slice().sort((a,b)=>a.path.localeCompare(b.path)));
      for(const p of complete){expect(p);same('Bag persisted expected installed afterimage '+p.path,bagInput.expected_inputs[p.path],p.raw_sha256);}
      for(const command of p.commands){const basename=command.log;same('Bag original/durable log '+basename,raw(path.posix.dirname(s.persisted_receipt.path)+'/'+basename),raw(path.posix.dirname(originalBagPersisted)+'/'+basename));}
      same('Bag registry continuity',c.registry_after_sha256,b.registry_before_sha256);
    }
    predecessorSummary[kind]={committed_receipt:s.committed_receipt,persisted_receipt:s.persisted_receipt,prepared:s.prepared_journal,committed_state:s.committed_journal,plan_sha256:ref.plan,targets:manifest.length,linked_states:names.length,all_bag_targets_current:isFourth?null:true};
  }
  const proposalEvidence=json('build/professional-english/foundation02-fifth10-delivery-proposal-r01/evidence-pins.json');
  same('Original evidence/history count',proposalEvidence.evidence.length+proposalEvidence.history_files.length,39);
  for(const p of [...proposalEvidence.evidence,...proposalEvidence.history_files]){verify(p);same('Original evidence in binding '+p.path,inputs.get(p.path.toLowerCase()),p);}
  same('Complete independently reconstructed input set',[...expected.keys()].sort(),b.input_files.map(p=>p.path).sort());
  same('Independent input closure count',expected.size,12443);
  same('Exact independent retained-source set',[...retain].sort(),b.required_retained_sources);
  same('Required retained count',retain.size,812);
  const retained=[...retain].sort().map((source,i)=>({source,target:DURABLE+'/retained/'+String(i).padStart(4,'0')+'-'+path.posix.basename(source),bytes:pin(source).bytes,raw_sha256:pin(source).raw_sha256}));
  same('Stable retained destination mapping',b.retained_files,retained);
  const deferred=[{kind:'actual_binding',target:DURABLE+'/binding/actual-baseline-binding.json'},{kind:'independent_source_review',target:DURABLE+'/binding/independent-actual-binding-review.json'},{kind:'root_input',target:DURABLE+'/binding/root-preparation-input.json'}];
  same('Three deferred pins',b.deferred_retained_targets,deferred);
  const replacements=['data/professional/lexemes/foundation-module02.json','data/professional/sources.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs','tests/godot/professional_retail_morphology_tests.gd'];
  const additions=['data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json',DURABLE+'/DELIVERY.md',...retained.map(r=>r.target),...deferred.map(r=>r.target)].sort();
  same('Exact absent-addition closure',b.must_remain_absent,additions);same('Exact complete target closure',b.target_paths,[...replacements,...additions].sort());
  same('Unique target case identities',new Set(b.target_paths.map(p=>p.toLowerCase())).size,823);
  for(const p of additions)check('Addition absent '+p,!fs.existsSync(abs(p)));
  check('Preparation output is absent',!fs.existsSync(abs(PREP+'/execution-r01')));
  check('External binding avoids circular input',!inputs.has(BINDING.toLowerCase()));
  const catalog=json('data/professional/catalog.json');
  const res=p=>{check('Resource scheme '+p,p.startsWith('res://'));return p.slice(6);};
  const data={catalog,themes:json(res(catalog.themes)).profiles,sources:json(res(catalog.sources)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
  for(const r of catalog.courses)data.courses.push(json(res(r.manifest)));
  for(const category of ['lexeme','expression'])for(const resource of catalog[category+'_files']){
    const envelope=json(res(resource));same('Envelope schema '+resource,envelope.schema_version,1);
    for(const entry of envelope[category+'s']){check('Unique registry ID '+entry.id,!Object.hasOwn(data[category+'Origins'],entry.id));data[category+'s'].push(entry);data[category+'Origins'][entry.id]=resource;}
  }
  same('Independent registry before hash',jsonHash(data),b.registry_before_sha256);
  const contract=json(PREP+'/accepted-contract.json'),context=json(PREP+'/context-contract.json'),donors=json(PREP+'/donor-row-contract.json');
  const acceptedIds=['broken.not-working.adj','urgent.needing-prompt-attention.adj','unclear.not-understandable.adj','safe.free-from-unacceptable-danger.adj','incident.workplace-event.n','concern.worrying-matter.n','solution.problem-answer.n','procedure.agreed-method.n'];
  same('Accepted identities',contract.patches.map(r=>r.id),acceptedIds);
  same('Approved contract hashes',[pin(PREP+'/accepted-contract.json').raw_sha256,pin(PREP+'/context-contract.json').raw_sha256,pin(PREP+'/donor-row-contract.json').raw_sha256],['e930b6e65c44daa4ab27b44523241edc41e10942d92b25f2254f47073acd2235','5cf815fb77ebdc45325063e40eb2b1940718e721ed18f46f347277689dd2993a','119814498724b14dd5d272a005ecdcc19f646651d321dd78dcafef0fe1c3d638']);
  same('Contract approval boundary',[contract.acceptance.delivery_metadata_technical_acceptance,contract.acceptance.new_language_acceptance],[true,false]);
  const delta={definition:0,example:0,difficulty:0},patches=new Map();
  function protectedEntry(x){const c=structuredClone(x);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete c[k];for(const k of ['status','language','reviewer','reviewed_at'])delete c.review[k];return c;}
  for(const p of contract.patches){
    same('Accepted current preimage '+p.id,one(data.lexemes,p.id),p.before);same('Accepted correct lexical origin '+p.id,data.lexemeOrigins[p.id],'res://data/professional/lexemes/foundation-module02.json');
    same('Accepted before/after hashes '+p.id,[jsonHash(p.before),jsonHash(p.after)],[p.before_entry_json_sha256,p.after_entry_json_sha256]);
    same('Independent accepted delivery hash '+p.id,jsonHash(p.after),one(contract.acceptance.accepted_delivery_entries,p.id).accepted_delivery_entry_json_sha256);
    same('Protected fields preserved '+p.id,protectedEntry(p.before),protectedEntry(p.after));same('Protected fields accepted hash '+p.id,jsonHash(protectedEntry(p.before)),p.protected_fields_json_sha256);
    for(const k of Object.keys(delta)){same('Accepted '+k+' '+p.id,p.after[k],p.accepted_fields[k]);if(p.before[k]!==p.after[k])delta[k]++;}
    same('Reference prefix preserved '+p.id,p.after.references.slice(0,p.before.references.length),p.before.references);same('Two accepted new references '+p.id,p.after.references.slice(p.before.references.length).map(r=>r.source_id),p.source_ids);same('Reference count '+p.id,p.source_ids.length,2);patches.set(p.id,p.after);
  }
  same('Content field delta',delta,{definition:4,example:1,difficulty:5});
  same('Six held entries',context.whole_entry_holds.map(r=>r.id).sort(),['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v','unsafe.presenting-danger.adj','hazard.possible-harm.n'].sort());
  for(const r of [...context.whole_entry_holds,...context.groups.related_entry_boundaries]){same('Whole protected lexical context '+r.id,one(data.lexemes,r.id),r.before_entry);same('Protected lexical context hash '+r.id,jsonHash(r.before_entry),r.entry_json_sha256);}
  for(const group of ['containing_module_expressions','expression_uses','derivative_expression_uses','focus_expressions','inherited_expression_holds','additional_foundation02_preservation'])for(const r of context.groups[group]){same('Whole expression context '+group+' '+r.id,one(data.expressions,r.id),r.before_entry);same('Expression context hash '+group+' '+r.id,jsonHash(r.before_entry),r.entry_json_sha256||r.before_entry_json_sha256);}
  for(const r of context.groups.containing_modules){const m=one(one(data.courses,r.course_id).modules,r.module_id);same('Containing module context '+r.course_id,m,r.before_entry);same('Containing module hash '+r.course_id,jsonHash(m),r.module_json_sha256);}
  const selected=new Set(context.groups.selected_memberships.map(r=>r.lexeme_id)), memberships=[];
  for(const c of data.courses)for(const m of c.modules)for(const [i,id]of m.lexeme_ids.entries())if(selected.has(id))memberships.push({course_id:c.id,module_id:m.id,index:i,lexeme_id:id});
  same('Complete selected memberships',memberships.map(JSON.stringify).sort(),context.groups.selected_memberships.map(JSON.stringify).sort());
  same('Existing complete form-scope mismatch preserved',one(data.lexemes,context.complete_existing_form_scope_mismatch.id),context.complete_existing_form_scope_mismatch.before_entry);
  for(const r of context.pending_domain_expressions){const v=one(data.expressions,r.id);same('Pending expression domain '+r.id,[jsonHash(v),v.review.domain],[r.preimage_sha256,r.domain_before]);}
  same('Donor row count and unique groups',[donors.rows.length,new Set(donors.rows.map(r=>r.history_path+'/'+r.id)).size],[50,50]);
  for(const p of donors.history_files)verify(p,'Donor history raw pin');
  for(const d of donors.rows){const rows=json(d.history_path).protected_context.lexemes;const row=rows[d.index];same('Complete donor row '+d.history_path+' '+d.id,row,d.whole_row);same('Donor row identity/hash/multiplicity '+d.history_path+' '+d.id,[jsonHash(row),jsonHash(row.entry),rows.filter(r=>r.entry.id===d.id).length,d.exact_count],[d.whole_row_json_sha256,row.json_sha256,1,1]);same('Donor current lexical full preimage '+d.id,one(data.lexemes,d.id),row.entry);}
  const bag=json('data/professional/provenance/retail-shopping-bag-image-2026-10-17.json');
  same('Single shopping-bag patch',bag.patches.length,1);same('Current shopping-bag full accepted object',one(data.lexemes,'shopping-bag.goods-carrier.n'),bag.patches[0].after);
  same('Shopping-bag accepted object/image hashes',[jsonHash(bag.patches[0].after),pin(bag.resource.path).raw_sha256],['25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85','f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb']);
  same('Existing and added unique source IDs',[new Set(data.sources.map(r=>r.id)).size,new Set(contract.sources.map(r=>r.id)).size],[data.sources.length,16]);
  for(const s of contract.sources){same('Consulted-only new source '+s.id,[s.status,s.assets_acquired,s.asset_license],['consulted',false,null]);check('No source collision '+s.id,!data.sources.some(r=>r.id===s.id));}
  for(const id of contract.excluded_source_ids)check('Excluded source stays absent '+id,![...data.sources,...contract.sources].some(r=>r.id===id));
  const next=structuredClone(data);next.lexemes=next.lexemes.map(v=>structuredClone(patches.get(v.id)||v));next.sources.push(...structuredClone(contract.sources));
  same('Independent accepted registry hash',jsonHash(next),b.registry_after_sha256);
  function count(d){return {reviewed_status:d.lexemes.filter(x=>x.review.status==='reviewed').length,reviewed_language:d.lexemes.filter(x=>x.review.language==='reviewed').length,foundation02_language:d.lexemes.filter(x=>d.lexemeOrigins[x.id]==='res://data/professional/lexemes/foundation-module02.json'&&x.review.language==='reviewed').length,sources:d.sources.length,lexemes:d.lexemes.length,expressions:d.expressions.length,images:d.lexemes.filter(x=>x.media.image.status==='integrated').length,audio:d.lexemes.filter(x=>x.media.audio.status==='integrated').length,ready_modules:d.courses.flatMap(c=>c.modules).filter(m=>m.status==='ready').length};}
  const counts={before:count(data),after:count(next)};same('Independent before/after counts',counts,b.counts);same('Observation counts',observation.counts,counts);
  same('Observation deltas',observation.content_delta,delta);
  const anchors=json(PREP+'/author-observations.json').exact_anchor_observations;
  for(const a of anchors){const p=a.source.endsWith('.after')?'tests/'+path.posix.basename(a.source).slice(0,-6):a.source;const source=raw(p).toString().replaceAll('\r\n','\n');same('Actual transform literal anchor '+a.name+' '+p,source.split(a.before).length-1,a.occurrences);if(a.source.endsWith('.after'))same('Actual test equals bag scratch source '+p,raw(p),raw(a.source));}
  same('Exact anchor count',anchors.length,18);
  for(const name of ['accepted-contract.json','context-contract.json','donor-row-contract.json','projection.cjs','test-transforms.cjs','prepare.cjs','CALL-GRAPH.md','author-observations.json'])same('Preserved r02/r03 source '+name,raw(PREP+'/'+name),raw('build/professional-english/foundation02-fifth10-delivery-preparation-r02/'+name));
  const bagCommit=json(b.predecessors.shopping_bag.committed_receipt.path),fourthCommit=json(b.predecessors.fourth10.committed_receipt.path);
  same('Fourth to bag registry continuity',fourthCommit.registry_after_sha256,bagCommit.registry_before_sha256);
  same('Observation closure counts',[observation.input_count,observation.retained_count,observation.deferred_count,observation.additions_count,observation.target_count],[12443,812,3,817,823]);
  console.log(JSON.stringify({phase:'relationships_and_registry_complete',checks:passed,failures:failures.length,raw_files:observed.size}));
  const beforeRecheck=[...observed.values()];
  for(const p of beforeRecheck){const bytes=fs.readFileSync(abs(p.path));same('Final raw input unchanged '+p.path,{bytes:bytes.length,raw_sha256:sha(bytes)},{bytes:p.bytes,raw_sha256:p.raw_sha256});}
  for(const p of additions)check('Final addition remains absent '+p,!fs.existsSync(abs(p)));
  check('Final preparation output absent',!fs.existsSync(abs(PREP+'/execution-r01')));
  result={schema:1,status:failures.length?'independent_actual_binding_findings':'independent_actual_binding_raw_checks_passed',started_at:started,finished_at:new Date().toISOString(),reviewer:'/root/morph_review',binding:pin(BINDING),source_inventory:supplement.preparation_source_inventory,root_capture_input:pin(CONFIG),capture_receipt:pin(OUTPUT+'/capture-receipt.json'),checks_passed:passed,checks_failed:failures.length,failures,measured:{binding_inputs:12443,independent_input_set:expected.size,input_bytes:b.input_files.reduce((n,p)=>n+p.bytes,0),inherited_union:union.size,inherited_overlap:overlap,inherited_evidence_only:evidenceOnly,retained_sources:retain.size,additions:additions.length,targets:b.target_paths.length,deferred_targets:3,registry_before_sha256:jsonHash(data),registry_after_sha256:jsonHash(next),counts,content_delta:delta,whole_entry_holds:context.whole_entry_holds.length,donor_rows:donors.rows.length,anchor_checks:anchors.length,predecessors:predecessorSummary},scope:{raw_json_hash_and_source_only:true,project_or_helper_or_preparation_imported:false,syntax_or_project_tests_executed:false,transforms_executed:false,projected_afterimages_reviewed:false,root_guard_evidence_reviewed:false,production_mutated:false},raw_input_count:observed.size,all_observed_inputs_rehashed_at_end:true};
} catch(error) {result={schema:1,status:'independent_raw_inspection_failed',started_at:started,finished_at:new Date().toISOString(),checks_passed:passed,checks_failed:failures.length,failures,error:String(error.stack||error),raw_input_count:observed.size,acceptance:false};}
write('inputs.json',{schema:1,files:[...observed.values()].sort((a,b)=>a.path.localeCompare(b.path))});
write('inspection.json',result);
console.log(JSON.stringify(result));
if(result.status!=='independent_actual_binding_raw_checks_passed')process.exitCode=1;
