'use strict';
// Independent built-in-only raw inspection; no preparation, transformer or project imports.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),util=require('node:util');
const ROOT='Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const OWN='build/professional-english/foundation02-fifth10-afterimage-independent-review-r01';
const PREP='build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const OUT=PREP+'/execution-r01',CAPTURE=OWN+'/inspection-r01';
const BINDING='build/professional-english/foundation02-fifth10-root-binding-proposal-r02/execution-r01/actual-baseline-binding.json';
const INPUT='build/professional-english/foundation02-fifth10-root-preparation-r03/input.json';
const GUARD='docs/qa/professional-foundation02-fifth10-r01/preparation-guard/inspection-and-copy-receipt.json';
const TARGET='data/professional/lexemes/foundation-module02.json',SOURCES='data/professional/sources.json';
const PROVENANCE='data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json';
const DURABLE='docs/content-review/foundation-module02-language-fifth10-2026-10-17';
const TESTS=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs','tests/godot/professional_retail_morphology_tests.gd'];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),jh=v=>hash(JSON.stringify(v)),serial=v=>Buffer.from(JSON.stringify(v,null,2)+'\n');
const observed=new Map(),failures=[];let passed=0;
function check(label,value){if(value)passed++;else failures.push({label});}
function same(label,a,b){check(label,util.isDeepStrictEqual(a,b));}
function at(p){if(typeof p!=='string'||!p||p.includes('\\')||path.isAbsolute(p))throw Error('Invalid relative path '+p);const a=path.resolve(ROOT,p);if(path.relative(ROOT,a).replaceAll('\\','/')!==p)throw Error('Escaping or noncanonical path '+p);return a;}
function raw(p){const b=fs.readFileSync(at(p)),pin={path:p,bytes:b.length,raw_sha256:hash(b)};if(observed.has(p))same('Repeated input stable '+p,pin,observed.get(p));else observed.set(p,pin);return b;}
function json(p){return JSON.parse(raw(p));}
function pin(p){if(!observed.has(p))raw(p);return observed.get(p);}
function verify(p){same('Raw exact pin '+p.path,pin(p.path),p);return raw(p.path);}
function one(rows,id){const a=rows.filter(r=>r.id===id);same('Unique ID '+id,a.length,1);if(a.length!==1)throw Error('Missing/ambiguous '+id);return a[0];}
function save(name,v){fs.writeFileSync(at(CAPTURE+'/'+name),serial(v),{flag:'wx'});}
if(fs.existsSync(at(CAPTURE)))throw Error('Consumed review capture; preserve it.');fs.mkdirSync(at(CAPTURE));
const started=new Date().toISOString();save('started.json',{schema:1,started_at:started,reviewer:'/root/morph_review',scope:'Independent raw JSON/hash/source inspection'});
let result;
try{
  const actualPins={
    receipt:{path:OUT+'/preparation-receipt.json',bytes:137807,raw_sha256:'44074a72a3bed006177725c5d6a0303d80fa3c4cf792a425b08924dce8abdc8d'},
    execution_end:{path:OUT+'/execution-end.json',bytes:145,raw_sha256:'e4e00da38bd380589bd77ddfb73afd780b08a34faf73d25ba72d16db0fdfa407'},
    target_plan:{path:OUT+'/target-plan.json',bytes:376416,raw_sha256:'cd58e001bfdafac503a8bb9903d2a556afe592d2771244e779d3024b802ab9ac'},
    projection_observation:{path:OUT+'/projection-observation.json',bytes:997,raw_sha256:'8a17f3c1ed0844c749b5b52387a5e5c56ff1e4c9bdfb01f8b170d415d9c17423'},
    root_input:{path:INPUT,bytes:1191,raw_sha256:'f8a61b805220a2d6e64788a92960a35bd280af3c45b1f265dbdcf91955b81549'}
  };
  for(const p of Object.values(actualPins))verify(p);
  const receipt=json(actualPins.receipt.path),end=json(actualPins.execution_end.path),plan=json(actualPins.target_plan.path),projection=json(actualPins.projection_observation.path),input=json(INPUT),binding=json(BINDING);
  same('Fixed actual binding pin',pin(BINDING),{path:BINDING,bytes:3187477,raw_sha256:'7323bcb1baac6ea85817169bcc90325f9b54d587b19d4895ca3106ee7af0e015'});
  same('Actual successful preparation statuses',[receipt.status,end.status,plan.status,projection.status],['prepared_pending_independent_afterimage_review_and_root_validation','prepared_pending_independent_review','scratch_plan_not_commit_authorization','built_in_json_projection_only']);
  check('No failed preparation marker',!fs.existsSync(at(OUT+'/failed-attempt.json')));
  for(const [v,fields]of [[receipt,['project_or_test_execution','native_executed','production_mutated','actual_fifth10_commit','actual_fifth10_persisted_validation']],[end,['production_mutated']],[plan,['production_mutated','project_or_test_execution']],[projection,['actual_validator_loaded','test_callbacks_executed','native_executed','production_mutated']]])for(const k of fields)same('No premature execution/production flag '+k,v[k],false);
  same('Preparation root input identity',[input.status,input.dispatcher,input.preparation_author,input.entrypoint,input.output,input.execute_project_tests],['root_authorized_one_shot_scratch_preparation','/root','/root/recover_delivery',PREP+'/prepare.cjs',OUT,false]);
  same('Receipt binding',receipt.actual_binding,pin(BINDING));same('Input binding',input.binding,pin(BINDING));
  same('Receipt frozen source inventory',receipt.source_inventory,input.source_inventory);same('Receipt independent binding acceptance',receipt.independent_source_review,input.independent_source_review);
  const sourceInventory=JSON.parse(verify(receipt.source_inventory)),bindingReview=JSON.parse(verify(receipt.independent_source_review));
  same('Binding acceptance status',bindingReview.status,'accepted_for_one_root_owned_fifth10_scratch_preparation');same('Binding acceptance exact artifact',bindingReview.actual_binding,pin(BINDING));same('Binding execution approval',bindingReview.preparation_execution_accepted,true);
  for(const r of sourceInventory.files||sourceInventory.artifacts)verify({path:PREP+'/'+r.path,bytes:r.bytes,raw_sha256:r.raw_sha256||r.sha256});
  for(const p of binding.input_files)verify(p);
  same('Full raw baseline input count',binding.input_files.length,12443);
  console.log(JSON.stringify({phase:'baseline_rehashed',files:binding.input_files.length,failures:failures.length}));
  const artifactMap=new Map();
  for(const p of receipt.artifacts){check('Unique preparation artifact '+p.path,!artifactMap.has(p.path.toLowerCase()));const full={...p,path:OUT+'/'+p.path};verify(full);artifactMap.set(p.path.toLowerCase(),full);}
  same('Complete receipt artifact count',artifactMap.size,833);
  const actualFiles=[];
  function walk(dir){for(const e of fs.readdirSync(at(dir),{withFileTypes:true})){check('No output symlink '+dir+'/'+e.name,!e.isSymbolicLink());const p=dir+'/'+e.name;if(e.isDirectory())walk(p);else actualFiles.push(p.slice(OUT.length+1));}}
  walk(OUT);
  same('Exact physical output directory closure',actualFiles.sort(),[...receipt.artifacts.map(p=>p.path),'preparation-receipt.json','execution-end.json'].sort());
  const start=json(OUT+'/execution-start.json');same('Start linkage',[start.root_input,start.actual_binding,start.source_inventory,start.independent_source_review],[actualPins.root_input,pin(BINDING),receipt.source_inventory,receipt.independent_source_review]);
  const guard=json(GUARD);same('Root guard inspection identity',pin(GUARD).raw_sha256,'055071a24019f7fc8f7c5caad44b0e857345ccc81248131f38f88b0182913a96');
  same('Root guard status/counts',[guard.status,guard.cases,guard.negative_specifications,guard.production_mutated,guard.preparation_executed],['root_inspected_actual_guard_success',53,29,false,false]);
  for(const r of guard.copies){verify({path:r.source,bytes:r.bytes,raw_sha256:r.raw_sha256});verify({path:r.target,bytes:r.bytes,raw_sha256:r.raw_sha256});same('Root guard durable copy '+r.target,raw(r.source),raw(r.target));}
  const contract=json(PREP+'/accepted-contract.json'),context=json(PREP+'/context-contract.json'),history=json(PREP+'/donor-row-contract.json');
  const retained=[...binding.retained_files,...binding.deferred_retained_targets.map(r=>{const p={actual_binding:pin(BINDING),independent_source_review:receipt.independent_source_review,root_input:actualPins.root_input}[r.kind];return {source:p.path,target:r.target,bytes:p.bytes,raw_sha256:p.raw_sha256};})];
  same('Complete retained source count',retained.length,815);
  const replacementPaths=[TARGET,SOURCES,...TESTS],expectedPlan=[];
  for(const target of replacementPaths){const stem=path.posix.basename(target),before=raw(target),beforeArtifact=raw(OUT+'/'+stem+'.before'),after=pin(OUT+'/'+stem+'.after');same('Exact saved current preimage '+target,beforeArtifact,before);expectedPlan.push({path:target,operation:'replace',before_sha256:hash(before),after_sha256:after.raw_sha256,bytes:after.bytes,artifact:stem+'.after'});}
  for(const [target,name]of [[PROVENANCE,'production-provenance.prepared.json'],[DURABLE+'/DELIVERY.md','production-document.prepared.md']]){const p=pin(OUT+'/'+name);expectedPlan.push({path:target,operation:'add_absent_pending_actual_stage_finalization',prepared_sha256:p.raw_sha256,bytes:p.bytes,artifact:name,final_transaction_bytes_frozen:false});}
  for(const [i,r]of retained.entries()){const name='retained-evidence/'+String(i).padStart(3,'0')+'.bin';const saved=raw(OUT+'/'+name);same('Exact retained bytes '+r.source,saved,verify({path:r.source,bytes:r.bytes,raw_sha256:r.raw_sha256}));expectedPlan.push({path:r.target,operation:'add_absent',source:r.source,before_sha256:null,after_sha256:r.raw_sha256,bytes:r.bytes,artifact:name});}
  same('Exact complete target plan rows',plan.targets,expectedPlan);same('Receipt target count',receipt.target_count,823);same('Target plan exact binding paths',plan.targets.map(r=>r.path).sort(),binding.target_paths);same('Target plan unique case paths',new Set(plan.targets.map(r=>r.path.toLowerCase())).size,823);
  for(const p of binding.must_remain_absent)check('Production addition remains absent '+p,!fs.existsSync(at(p)));
  const catalog=json('data/professional/catalog.json');
  const data={catalog,themes:json(catalog.themes.slice(6)).profiles,sources:json(catalog.sources.slice(6)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
  for(const r of catalog.courses)data.courses.push(json(r.manifest.slice(6)));
  for(const category of ['lexeme','expression'])for(const file of catalog[category+'_files'])for(const entry of json(file.slice(6))[category+'s']){check('Unique catalog identity '+entry.id,!Object.hasOwn(data[category+'Origins'],entry.id));data[category+'s'].push(entry);data[category+'Origins'][entry.id]=file;}
  const patches=new Map(contract.patches.map(r=>[r.id,r]));same('Eight accepted patches',patches.size,8);
  const next=structuredClone(data);next.lexemes=next.lexemes.map(r=>structuredClone(patches.get(r.id)?.after||r));next.sources.push(...structuredClone(contract.sources));
  const actualLexical=json(OUT+'/foundation-module02.json.after'),actualSources=json(OUT+'/sources.json.after');
  const beforeLexical=json(TARGET),beforeSources=json(SOURCES),expectedLexical=structuredClone(beforeLexical),expectedSources=structuredClone(beforeSources);
  expectedLexical.lexemes=expectedLexical.lexemes.map(r=>structuredClone(patches.get(r.id)?.after||r));expectedSources.sources.push(...structuredClone(contract.sources));
  same('Entire lexical afterimage exact',actualLexical,expectedLexical);same('Entire source afterimage exact',actualSources,expectedSources);
  for(const [target,expected,name]of [[TARGET,expectedLexical,'foundation-module02.json.after'],[SOURCES,expectedSources,'sources.json.after']]){const newline=raw(target).includes(Buffer.from('\r\n'))?'\r\n':'\n';same('Exact serialized afterimage bytes '+target,raw(OUT+'/'+name),Buffer.from((JSON.stringify(expected,null,2)+'\n').replace(/\n/g,newline)));}
  function count(d){return {reviewed_status:d.lexemes.filter(r=>r.review.status==='reviewed').length,reviewed_language:d.lexemes.filter(r=>r.review.language==='reviewed').length,foundation02_language:d.lexemes.filter(r=>d.lexemeOrigins[r.id]==='res://'+TARGET&&r.review.language==='reviewed').length,sources:d.sources.length,lexemes:d.lexemes.length,expressions:d.expressions.length,images:d.lexemes.filter(r=>r.media.image.status==='integrated').length,audio:d.lexemes.filter(r=>r.media.audio.status==='integrated').length,ready_modules:d.courses.flatMap(c=>c.modules).filter(m=>m.status==='ready').length};}
  const counts={before:count(data),after:count(next)};same('Measured before/after counts',counts,binding.counts);same('Registry before exact',jh(data),binding.registry_before_sha256);same('Registry after exact',jh(next),binding.registry_after_sha256);same('Projection observation hashes/counts',[projection.registry_before_sha256,projection.registry_after_sha256,projection.counts],[jh(data),jh(next),counts]);
  const delta={definition:0,example:0,difficulty:0};
  for(const p of contract.patches){same('Whole accepted baseline '+p.id,one(data.lexemes,p.id),p.before);same('Whole accepted afterimage '+p.id,one(actualLexical.lexemes,p.id),p.after);same('Accepted exact object hashes '+p.id,[jh(p.before),jh(p.after)],[p.before_entry_json_sha256,p.after_entry_json_sha256]);for(const k of Object.keys(delta))if(p.before[k]!==p.after[k])delta[k]++;same('Preserved morphology/media/domain/forms/regions/modes '+p.id,[p.after.morphology,p.after.media,p.after.review.domain,p.after.accepted_forms,p.after.regions,p.after.practice_modes],[p.before.morphology,p.before.media,p.before.review.domain,p.before.accepted_forms,p.before.regions,p.before.practice_modes]);}
  same('Exact content delta',delta,{definition:4,example:1,difficulty:5});same('Observation content delta',projection.content_delta,delta);
  for(const r of context.whole_entry_holds){same('Full unchanged hold '+r.id,one(actualLexical.lexemes,r.id),r.before_entry);same('Held language stays pending '+r.id,one(actualLexical.lexemes,r.id).review.language,'pending');}
  same('Six full holds',context.whole_entry_holds.length,6);
  for(const group of ['containing_module_expressions','expression_uses','derivative_expression_uses','focus_expressions','inherited_expression_holds','additional_foundation02_preservation'])for(const r of context.groups[group])same('Expression context '+group+' '+r.id,one(next.expressions,r.id),r.before_entry);
  for(const r of context.groups.related_entry_boundaries)same('Related entry boundary '+r.id,patches.get(r.id)?.before||one(next.lexemes,r.id),r.before_entry);
  for(const r of context.groups.containing_modules)same('Containing module unchanged '+r.course_id,one(one(next.courses,r.course_id).modules,r.module_id),r.before_entry);
  const selectedIds=new Set(context.groups.selected_memberships.map(r=>r.lexeme_id)),memberships=[];
  for(const c of next.courses)for(const m of c.modules)for(const [i,id]of m.lexeme_ids.entries())if(selectedIds.has(id))memberships.push({course_id:c.id,module_id:m.id,index:i,lexeme_id:id});
  same('Complete selected memberships preserved',memberships.map(JSON.stringify).sort(),context.groups.selected_memberships.map(JSON.stringify).sort());
  same('Existing form-scope mismatch preserved',one(next.lexemes,context.complete_existing_form_scope_mismatch.id),context.complete_existing_form_scope_mismatch.before_entry);
  for(const r of context.pending_domain_expressions){const e=one(next.expressions,r.id);same('Pending expression domain '+r.id,[jh(e),e.review.domain],[r.preimage_sha256,r.domain_before]);}
  same('Full donor count/identities',[history.rows.length,new Set(history.rows.map(r=>r.history_path+'/'+r.id)).size],[50,50]);
  for(const r of history.rows){const rows=json(r.history_path).protected_context.lexemes;const donor=rows[r.index];same('Full donor row at accepted index '+r.history_path+' '+r.id,donor,r.whole_row);same('Donor multiplicity and hashes '+r.id,[rows.filter(x=>x.entry.id===r.id).length,r.exact_count,jh(donor),jh(donor.entry)],[1,1,r.whole_row_json_sha256,donor.json_sha256]);same('Restored full donor object '+r.id,patches.get(r.id)?.before||one(next.lexemes,r.id),donor.entry);}
  const bagPath='data/professional/provenance/retail-shopping-bag-image-2026-10-17.json',bag=json(bagPath),bagEntry=one(next.lexemes,'shopping-bag.goods-carrier.n');
  same('Complete delivered bag preserved',bagEntry,bag.patches[0].after);same('Bag accepted entry/image hashes',[jh(bagEntry),pin(bag.resource.path).raw_sha256],['25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85','f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb']);
  function retainedPin(p){const rows=retained.filter(r=>r.source===p);same('Exactly one retained source '+p,rows.length,1);const r=rows[0];return {path:r.target,bytes:r.bytes,raw_sha256:r.raw_sha256};}
  const protectedState={all_other_lexemes_json_sha256:jh(data.lexemes.filter(r=>!patches.has(r.id)))};for(const k of ['catalog','themes','courses','expressions','sources','lexemeOrigins','expressionOrigins'])protectedState[k+'_json_sha256']=jh(data[k]);
  const expectedRecord={schema:1,status:'prepared_afterimage_pending_independent_review_and_actual_delivery',production_integrated:false,accepted_contract:retainedPin(PREP+'/accepted-contract.json'),context_contract:retainedPin(PREP+'/context-contract.json'),donor_contract:retainedPin(PREP+'/donor-row-contract.json'),patches:contract.patches,sources:contract.sources,held:context.whole_entry_holds,excluded_source_ids:contract.excluded_source_ids,context,history,source_observations:contract.source_review,counts,content_delta:delta,registry_before_sha256:jh(data),registry_after_sha256:jh(next),protected_state:protectedState,source_prefix:{count:data.sources.length,json_sha256:jh(data.sources),rows:data.sources.map((e,i)=>({index:i,id:e.id,json_sha256:jh(e)}))},delivered_bag:{entry:bagEntry,entry_json_sha256:jh(bagEntry),provenance:pin(bagPath)},lineage:{root_input:retainedPin(INPUT),actual_binding:retainedPin(BINDING),source_inventory:retainedPin(receipt.source_inventory.path),independent_source_review:retainedPin(receipt.independent_source_review.path),predecessors:Object.fromEntries(Object.entries(binding.predecessors).map(([name,item])=>[name,Object.fromEntries(['committed_receipt','committed_journal','persisted_receipt'].map(k=>[k,retainedPin(item[k].path)]))])),fifth10_commit_receipt:null,fifth10_persisted_receipt:null},retained_files:retained,audit:{new_language_acceptance:false,new_morphology_acceptance:false,new_expression_acceptance:false,new_media_acceptance:false,ready_module_or_course:false,project_validation_performed:false},delivery_scope:{lexeme_file:TARGET,sources_file:SOURCES,provenance_file:PROVENANCE}};
  const record=json(OUT+'/production-provenance.prepared.json');same('Complete provenance object exact',record,expectedRecord);same('Complete provenance serialized bytes exact',raw(OUT+'/production-provenance.prepared.json'),serial(expectedRecord));
  const document=raw(OUT+'/production-document.prepared.md').toString();check('Document keeps preparation/integration boundary',document.includes('Actual fifth-ten commit and persisted validation are pending.')&&document.includes('must be finalized and reviewed')&&document.includes('Root must separately run projected Node/validator checks'));
  const source=raw(PREP+'/test-transforms.cjs').toString().replaceAll('\r\n','\n');
  function literal(name){const marker='const '+name+'=String.raw`',start=source.indexOf(marker);check('Single raw source constant '+name,start>=0&&source.indexOf(marker,start+1)===-1);const end=source.indexOf('`;',start+marker.length);if(start<0||end<0)throw Error('Missing source literal '+name);const s=source.slice(start+marker.length,end);check('No interpolation in raw source literal '+name,!s.includes('${'));return s;}
  const helper=literal('helper'),suffixes=[literal('contentTests'),literal('morphologyTests'),literal('mediaTests'),literal('nativeTests')];
  const ledger=json(OUT+'/test-edit-ledger.json');same('Edit ledger status',ledger.status,'scratch_afterimages_not_executed');same('Exact ledger files',ledger.files.map(r=>r.path),TESTS);
  const allEdits=[];
  for(const [i,file]of TESTS.entries()){
    const before=raw(file),actual=raw(OUT+'/'+path.posix.basename(file)+'.after');const newline=before.includes(Buffer.from('\r\n'))?'\r\n':'\n';const normalize=s=>s.replace(/\r?\n/g,newline);
    const expected=[],load="const foundation02FifthLanguageRecord = JSON.parse(fs.readFileSync(path.join("+(i===0?'rootDir':'root')+", '"+PROVENANCE+"'), 'utf8'));";
    function edit(name,old,next){expected.push({name,occurrences:1,before:normalize(old),after:normalize(next)});}
    if(i===3){
      edit('native runner fifth-ten call','\t_check_foundation02_fourth_language()','\t_check_foundation02_fourth_language()\n\t_check_foundation02_fifth_language()');
      edit('native fourth-ten reaches fifth-ten once','func _f02f_reverse(entry: Dictionary) -> Dictionary:\n','func _f02f_reverse(entry: Dictionary) -> Dictionary:\n\tvar fifth_language: Dictionary = _f02_fifth_reverse(entry)\n\tif not fifth_language.ok:\n\t\treturn {"ok": false}\n\tentry = fifth_language.entry\n');
    }else if(i===2){
      edit('media fifth-ten helpers before separate bag helper','function beforeShoppingBagImage(entry) {',load+'\n'+helper+'\nfunction beforeShoppingBagImage(entry) {');
      edit('bag-time other-lexeme history',"hash(data.lexemes.filter(entry=>entry.id!=='shopping-bag.goods-carrier.n'))","hash(data.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.id!=='shopping-bag.goods-carrier.n'))");
      edit('bag-time source history only',"for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])assert.equal(hash(data[key]),c[key+'_json_sha256'],key);","for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])assert.equal(hash(key==='sources'?beforeFoundation02FifthSources(data.sources):data[key]),c[key+'_json_sha256'],key);");
    }else{
      edit('whole fifth-ten boundary before fourth-ten','function beforeFoundation02FourthLanguage(entry) {',load+'\n'+helper+'\nfunction beforeFoundation02FourthLanguage(entry) {\n  entry = beforeFoundation02FifthLanguage(entry);');
      edit('exact fifth-ten suffix before fourth-ten suffix','function beforeFoundation02FourthSources(sources) {','function beforeFoundation02FourthSources(sources) {\n  sources = beforeFoundation02FifthSources(sources);');
      if(i===0){
        edit('accepted Foundation ID set','...foundation02FourthLanguageRecord.patches].map(item => item.id)','...foundation02FourthLanguageRecord.patches, ...foundation02FifthLanguageRecord.patches].map(item => item.id)');
        edit('live measured reviewed count','assert.equal(result.summary.reviewed_lexemes, 148);','assert.equal(result.summary.reviewed_lexemes, foundation02FifthLanguageRecord.counts.after.reviewed_status);');
        edit('fourth-ten source suffix remains exact','assert.deepEqual(source.sources.slice(-20),r.sources);','assert.deepEqual(beforeFoundation02FifthSources(source.sources).slice(-20),r.sources);');
        edit('fourth-ten all-other bag collection keeps lexical history','hash(shoppingBagHistoryLexemes().filter(entry=>!ids.has(entry.id)))','hash(shoppingBagHistoryLexemes().map(beforeFoundation02FifthLanguage).filter(entry=>!ids.has(entry.id)))');
        edit('fourth-ten historical counts',"assert.equal(source.lexemes.filter(entry=>entry.review.status==='reviewed').length,148);assert.equal(source.lexemes.filter(entry=>entry.review.language==='reviewed').length,335);","assert.equal(source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.review.status==='reviewed').length,148);assert.equal(source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.review.language==='reviewed').length,335);");
        edit('fourth-ten historical module count',"source.lexemes.filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,36","source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,36");
        edit('fourth-ten historical audit restores bag once','const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,148);','const historical={...source,lexemes:shoppingBagHistoryLexemes().map(beforeFoundation02FifthLanguage),sources:beforeFoundation02FifthSources(source.sources)};const audit=auditProfessionalContent({data:historical});assert.equal(audit.summary.reviewed_lexemes,148);');
        edit('third-ten negative still mutates third-ten suffix',"const badSources=structuredClone(source.sources);badSources.at(-21).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));","const badSources=structuredClone(source.sources);badSources.at(-(foundation02FifthLanguageRecord.sources.length+21)).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));");
        edit('fourth-ten negative still mutates fourth-ten suffix',"const badSources=structuredClone(source.sources);badSources.at(-1).scope+=' Drift.';assert.throws(()=>beforeFoundation02FourthSources(badSources));assert.throws(()=>beforeFoundation02ThirdSources(badSources));","const badSources=structuredClone(source.sources);badSources.at(-(foundation02FifthLanguageRecord.sources.length+1)).scope+=' Drift.';assert.throws(()=>beforeFoundation02FourthSources(badSources));assert.throws(()=>beforeFoundation02ThirdSources(badSources));");
      }
    }
    same('Exact independent transformation ledger '+file,ledger.files[i],{path:file,edits:expected,appended_tests:[5,2,1,1][i],native:i===3});
    let constructed=before.toString();for(const e of expected){same('Unique exact transformation anchor '+file+' '+e.name,constructed.split(e.before).length-1,1);constructed=constructed.split(e.before).join(e.after);}
    constructed+=normalize(suffixes[i]);same('Entire independently reconstructed test afterimage '+file,actual,Buffer.from(constructed));
    if(i<3){const beforeBag=before.toString().match(/function beforeShoppingBagImage\(entry\) \{[\s\S]*?\r?\n\}/),afterBag=actual.toString().match(/function beforeShoppingBagImage\(entry\) \{[\s\S]*?\r?\n\}/);check('Strict bag helper present '+file,!!beforeBag&&!!afterBag);same('Strict bag helper exact byte text '+file,afterBag&&afterBag[0],beforeBag&&beforeBag[0]);same('No new common bag reversal '+file,actual.toString().split('entry = beforeShoppingBagImage(entry);').length,before.toString().split('entry = beforeShoppingBagImage(entry);').length);same('New callback declarations '+file,(suffixes[i].match(/^test\(/gm)||[]).length,[5,2,1][i]);}
    allEdits.push({path:file,edits:expected.length,appended_tests:[5,2,1,1][i],afterimage:pin(OUT+'/'+path.posix.basename(file)+'.after')});
  }
  same('Total exact text edits',allEdits.reduce((n,r)=>n+r.edits,0),18);
  const priorBag=json(binding.predecessors.shopping_bag.persisted_receipt.path);same('Actual prior bag callbacks',priorBag.tests,{tests:255,pass:255,fail:0,cancelled:0,skipped:0});
  const expectedCallbacks=priorBag.tests.tests+suffixes.slice(0,3).reduce((n,s)=>n+(s.match(/^test\(/gm)||[]).length,0);same('Expected projected callback count',expectedCallbacks,263);
  const modules=next.courses.flatMap(c=>c.modules),membershipCount=modules.reduce((n,m)=>n+m.lexeme_ids.length,0),expressionCount=modules.reduce((n,m)=>n+m.expression_ids.length,0);
  const expectedAuditSummary={courses:next.courses.length,modules:modules.length,themes:next.themes.length,unique_lexemes:next.lexemes.length,vocabulary_memberships:membershipCount,vocabulary_memberships_target:10000,vocabulary_memberships_remaining:10000-membershipCount,expressions:next.expressions.length,expression_memberships:expressionCount,expression_memberships_target:2000,expression_memberships_remaining:2000-expressionCount,ready_modules:counts.after.ready_modules,reviewed_lexemes:counts.after.reviewed_status,morphology_authored:next.lexemes.filter(r=>r.morphology).length,morphology_reviewed:next.lexemes.filter(r=>r.morphology?.review.status==='reviewed').length,integrated_word_images:counts.after.images,integrated_word_audio:counts.after.audio,release_ready:false};
  same('Accepted audit summary delta',expectedAuditSummary,{...priorBag.audit.summary,reviewed_lexemes:156});
  console.log(JSON.stringify({phase:'artifacts_content_and_transformations_checked',checks:passed,failures:failures.length,observed_inputs:observed.size,expected_callbacks:expectedCallbacks}));
  const beforeFinal=[...observed.values()];for(const p of beforeFinal){const b=fs.readFileSync(at(p.path));same('Final input stable '+p.path,{bytes:b.length,raw_sha256:hash(b)},{bytes:p.bytes,raw_sha256:p.raw_sha256});}
  for(const p of binding.must_remain_absent)check('Final production addition absent '+p,!fs.existsSync(at(p)));
  result={schema:1,status:failures.length?'afterimage_review_findings':'independent_afterimage_raw_checks_passed',reviewer:'/root/morph_review',started_at:started,finished_at:new Date().toISOString(),checks_passed:passed,checks_failed:failures.length,failures,actual_binding:pin(BINDING),preparation:actualPins,preparation_source_inventory:receipt.source_inventory,actual_binding_acceptance:receipt.independent_source_review,root_guard_evidence:pin(GUARD),measured:{baseline_inputs:binding.input_files.length,receipt_artifacts:artifactMap.size,physical_preparation_files:actualFiles.length,targets:plan.targets.length,replacements:6,retained:retained.length,additions:binding.must_remain_absent.length,accepted_entries:patches.size,held_entries:context.whole_entry_holds.length,donor_rows:history.rows.length,counts,content_delta:delta,registry_before_sha256:jh(data),registry_after_sha256:jh(next),transformations:allEdits,expected_projected_callbacks:expectedCallbacks,expected_audit_summary:expectedAuditSummary,expected_audit_errors:0,actual_audit_executed:false,actual_callback_execution:false},inputs_rehashed_at_end:observed.size,scope:{raw_json_hash_source_only:true,preparation_or_transformer_or_project_imported:false,syntax_or_project_or_native_or_transaction_executed:false,production_mutated:false,new_language_morphology_expression_media_specialist_readiness_acceptance:false}};
}catch(error){result={schema:1,status:'independent_raw_inspection_failed',started_at:started,finished_at:new Date().toISOString(),checks_passed:passed,checks_failed:failures.length,failures,error:String(error.stack||error),acceptance:false};}
save('inputs.json',{schema:1,files:[...observed.values()].sort((a,b)=>a.path.localeCompare(b.path))});save('inspection.json',result);console.log(JSON.stringify(result));if(result.status!=='independent_afterimage_raw_checks_passed')process.exitCode=1;
