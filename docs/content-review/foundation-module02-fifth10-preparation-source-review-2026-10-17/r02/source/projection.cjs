'use strict';
// Authored, undispatched. Built-in JSON projection only; no project imports or writes.
const assert = require('node:assert/strict');
const B = require('./binding.cjs');
const target = 'data/professional/lexemes/foundation-module02.json';
const sourceFile = 'data/professional/sources.json';
const provenance = 'data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json';
const bagProvenance = 'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json';
const acceptedIds = ['broken.not-working.adj','urgent.needing-prompt-attention.adj','unclear.not-understandable.adj','safe.free-from-unacceptable-danger.adj','incident.workplace-event.n','concern.worrying-matter.n','solution.problem-answer.n','procedure.agreed-method.n'];
const heldIds = ['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v','unsafe.presenting-danger.adj','hazard.possible-harm.n'];
const clone = value => structuredClone(value);
function one(rows, id) {const matches=rows.filter(row=>row.id===id);assert.equal(matches.length,1,id);return matches[0];}
function protect(entry) {
  const copy=clone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete copy[key];
  for(const key of ['status','language','reviewer','reviewed_at'])delete copy.review[key];return copy;
}
function loadRegistry(ctx) {
  B.assertSession(ctx);
  const resource=value=>{assert(value.startsWith('res://'));return value.slice(6);};
  const catalog=ctx.parse('data/professional/catalog.json');
  const data={catalog,themes:ctx.parse(resource(catalog.themes)).profiles,sources:ctx.parse(resource(catalog.sources)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
  for(const item of catalog.courses)data.courses.push(ctx.parse(resource(item.manifest)));
  for(const [key,origin,resources]of [['lexemes','lexemeOrigins',catalog.lexeme_files],['expressions','expressionOrigins',catalog.expression_files]])for(const file of resources){
    const envelope=ctx.parse(resource(file));assert.equal(envelope.schema_version,1);assert(Array.isArray(envelope[key]));
    for(const entry of envelope[key]){assert(!Object.hasOwn(data[origin],entry.id),'Duplicate registry ID');data[key].push(entry);data[origin][entry.id]=file;}
  }
  return data;
}
function counts(data) {return {
  reviewed_status:data.lexemes.filter(entry=>entry.review.status==='reviewed').length,
  reviewed_language:data.lexemes.filter(entry=>entry.review.language==='reviewed').length,
  foundation02_language:data.lexemes.filter(entry=>data.lexemeOrigins[entry.id]==='res://'+target&&entry.review.language==='reviewed').length,
  sources:data.sources.length,lexemes:data.lexemes.length,expressions:data.expressions.length,
  images:data.lexemes.filter(entry=>entry.media.image.status==='integrated').length,
  audio:data.lexemes.filter(entry=>entry.media.audio.status==='integrated').length,
  ready_modules:data.courses.flatMap(course=>course.modules).filter(module=>module.status==='ready').length
};}
function checkContext(data, context) {
  for(const row of context.whole_entry_holds){assert.deepEqual(one(data.lexemes,row.id),row.before_entry);assert.equal(B.hash(row.before_entry),row.entry_json_sha256);}
  for(const row of context.groups.related_entry_boundaries){assert.deepEqual(one(data.lexemes,row.id),row.before_entry);assert.equal(B.hash(row.before_entry),row.entry_json_sha256);}
  for(const group of ['containing_module_expressions','expression_uses','derivative_expression_uses','focus_expressions','inherited_expression_holds','additional_foundation02_preservation'])for(const row of context.groups[group]){
    assert.deepEqual(one(data.expressions,row.id),row.before_entry);assert.equal(B.hash(row.before_entry),row.entry_json_sha256||row.before_entry_json_sha256);
  }
  for(const row of context.groups.containing_modules){const module=one(one(data.courses,row.course_id).modules,row.module_id);assert.deepEqual(module,row.before_entry);assert.equal(B.hash(module),row.module_json_sha256);}
  for(const row of context.groups.selected_memberships)assert.equal(one(one(data.courses,row.course_id).modules,row.module_id).lexeme_ids[row.index],row.lexeme_id);
  const selectedIds=new Set(context.groups.selected_memberships.map(row=>row.lexeme_id));
  const actualMemberships=[];
  for(const course of data.courses)for(const module of course.modules)for(const [index,id]of module.lexeme_ids.entries())if(selectedIds.has(id))actualMemberships.push({course_id:course.id,module_id:module.id,index,lexeme_id:id});
  const canonical=rows=>rows.map(row=>JSON.stringify(row)).sort();
  assert.deepEqual(canonical(actualMemberships),canonical(context.groups.selected_memberships));
  const mismatch=context.complete_existing_form_scope_mismatch;assert.deepEqual(one(data.lexemes,mismatch.id),mismatch.before_entry);
  for(const row of context.pending_domain_expressions){const entry=one(data.expressions,row.id);assert.equal(B.hash(entry),row.preimage_sha256);assert.equal(entry.review.domain,row.domain_before);}
}
function project(ctx) {
  B.assertSession(ctx);
  const immutablePackets=[
    ['build/professional-english/foundation02-fifth10-delivery-proposal-r01','0e806ef501bbd9e90b1a026857292f13c40e96a5a53906a2ec476800f8b71db9'],
    ['build/professional-english/foundation02-fifth10-proposal-review-r01','b357729273451d34436cb6ea3ec4f81b943594f9c875938c6d83400f4b6c2ebf']
  ];
  const requiredImmutableSources=[];
  for(const [directory,expected]of immutablePackets){
    const filename=directory+'/inventory.json';assert.equal(B.sha(ctx.read(filename)),expected);requiredImmutableSources.push(filename);
    for(const row of ctx.parse(filename).artifacts){const relative=directory+'/'+row.path,bytes=ctx.read(relative);assert.equal(bytes.length,row.bytes);assert.equal(B.sha(bytes),row.raw_sha256||row.sha256);requiredImmutableSources.push(relative);}
  }
  const evidencePath=immutablePackets[0][0]+'/evidence-pins.json',evidence=ctx.parse(evidencePath);
  for(const pin of [...evidence.evidence,...evidence.history_files]){const bytes=ctx.read(pin.path);assert.equal(bytes.length,pin.bytes);assert.equal(B.sha(bytes),pin.raw_sha256);}
  const contractPath=B.own+'/accepted-contract.json',contextPath=B.own+'/context-contract.json',donorPath=B.own+'/donor-row-contract.json';
  assert.equal(B.sha(ctx.read(contractPath)),'e930b6e65c44daa4ab27b44523241edc41e10942d92b25f2254f47073acd2235');
  assert.equal(B.sha(ctx.read(contextPath)),'5cf815fb77ebdc45325063e40eb2b1940718e721ed18f46f347277689dd2993a');
  assert.equal(B.sha(ctx.read(donorPath)),'119814498724b14dd5d272a005ecdcc19f646651d321dd78dcafef0fe1c3d638');
  const contract=ctx.parse(contractPath),context=ctx.parse(contextPath),history=ctx.parse(donorPath),before=loadRegistry(ctx);
  assert.equal(B.hash(before),ctx.binding.registry_before_sha256);
  assert.equal(contract.acceptance.delivery_metadata_technical_acceptance,true);assert.equal(contract.acceptance.new_language_acceptance,false);
  assert.deepEqual(contract.patches.map(row=>row.id),acceptedIds);assert.equal(contract.sources.length,16);
  assert.deepEqual([...context.whole_entry_holds.map(row=>row.id)].sort(),[...heldIds].sort());
  checkContext(before,context);
  const delta={definition:0,example:0,difficulty:0};
  for(const p of contract.patches){
    assert.deepEqual(one(before.lexemes,p.id),p.before);assert.equal(before.lexemeOrigins[p.id],'res://'+target);
    assert.equal(B.hash(p.before),p.before_entry_json_sha256);assert.equal(B.hash(p.after),p.after_entry_json_sha256);
    const accepted=one(contract.acceptance.accepted_delivery_entries,p.id);assert.equal(B.hash(p.after),accepted.accepted_delivery_entry_json_sha256);
    assert.deepEqual(protect(p.before),protect(p.after));assert.equal(B.hash(protect(p.before)),p.protected_fields_json_sha256);
    for(const key of Object.keys(delta)){assert.deepEqual(p.after[key],p.accepted_fields[key]);if(p.before[key]!==p.after[key])delta[key]++;}
    assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);
    assert.equal(p.after.references.length-p.before.references.length,2);assert.deepEqual(p.after.references.slice(p.before.references.length).map(row=>row.source_id),p.source_ids);
    for(const id of p.source_ids)one(contract.sources,id);
  }
  assert.deepEqual(delta,{definition:4,example:1,difficulty:5});
  assert.equal(history.rows.length,50);assert.equal(new Set(history.rows.map(row=>row.history_path+'/'+row.id)).size,50);
  for(const pin of history.history_files){const bytes=ctx.read(pin.path);assert.equal(bytes.length,pin.bytes);assert.equal(B.sha(bytes),pin.raw_sha256);}
  for(const expected of history.rows){
    const rows=ctx.parse(expected.history_path).protected_context.lexemes;
    assert.equal(rows.filter(row=>row.entry.id===expected.id).length,1);assert.equal(expected.exact_count,1);
    assert.deepEqual(rows[expected.index],expected.whole_row);assert.equal(B.hash(rows[expected.index]),expected.whole_row_json_sha256);
    assert.equal(B.hash(rows[expected.index].entry),rows[expected.index].json_sha256);
    assert.deepEqual(one(before.lexemes,expected.id),expected.whole_row.entry);
  }
  const bag=ctx.parse(bagProvenance);assert.equal(bag.patches.length,1);const bagPatch=bag.patches[0];
  assert.equal(bagPatch.id,'shopping-bag.goods-carrier.n');assert.deepEqual(one(before.lexemes,bagPatch.id),bagPatch.after);
  assert.equal(B.hash(bagPatch.after),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');
  assert.equal(B.sha(ctx.read(bag.resource.path)),'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb');
  assert.equal(new Set(before.sources.map(row=>row.id)).size,before.sources.length);
  assert.equal(new Set(contract.sources.map(row=>row.id)).size,16);
  for(const source of contract.sources){assert(!before.sources.some(row=>row.id===source.id));assert.equal(source.status,'consulted');assert.equal(source.assets_acquired,false);assert.equal(source.asset_license,null);}
  for(const id of contract.excluded_source_ids)assert(![...before.sources,...contract.sources].some(row=>row.id===id));
  const map=new Map(contract.patches.map(row=>[row.id,row]));
  const next=clone(before);next.lexemes=before.lexemes.map(row=>clone(map.get(row.id)?.after||row));next.sources.push(...clone(contract.sources));
  assert.deepEqual(next.sources.slice(0,before.sources.length),before.sources);
  const measured={before:counts(before),after:counts(next)};
  assert.deepEqual(measured,ctx.binding.counts);assert.equal(B.hash(next),ctx.binding.registry_after_sha256);
  for(const key of ['lexemes','expressions','images','audio','ready_modules'])assert.equal(measured.before[key],measured.after[key]);
  assert.equal(measured.after.sources-measured.before.sources,16);assert.equal(measured.after.reviewed_language-measured.before.reviewed_language,8);
  assert.equal(measured.after.foundation02_language-measured.before.foundation02_language,8);assert.equal(measured.after.ready_modules,0);
  const originals=[{path:target,kind:'lexemes'},{path:sourceFile,kind:'sources'}];
  const proposedFiles=originals.map(item=>{
    const bytes=ctx.read(item.path),envelope=JSON.parse(bytes),after=clone(envelope);
    if(item.kind==='lexemes')after.lexemes=envelope.lexemes.map(entry=>clone(map.get(entry.id)?.after||entry));else after.sources.push(...clone(contract.sources));
    const newline=bytes.includes(Buffer.from('\r\n'))?'\r\n':'\n';
    return {path:item.path,before:bytes,after:Buffer.from((JSON.stringify(after,null,2)+'\n').replace(/\n/g,newline))};
  });
  const deferredPins={actual_binding:ctx.input.binding,independent_source_review:ctx.input.independent_source_review,root_input:ctx.rootInputPin};
  assert.deepEqual(ctx.binding.deferred_retained_targets.map(row=>row.kind).sort(),Object.keys(deferredPins).sort());
  const retained=[...ctx.binding.retained_files,...ctx.binding.deferred_retained_targets.map(row=>({source:deferredPins[row.kind].path,target:row.target,bytes:deferredPins[row.kind].bytes,raw_sha256:deferredPins[row.kind].raw_sha256}))];
  assert(retained.length>0);assert.equal(new Set(retained.map(row=>row.target.toLowerCase())).size,retained.length);
  for(const row of retained){assert(row.target.startsWith('docs/content-review/foundation-module02-language-fifth10-2026-10-17/'));assert(ctx.binding.must_remain_absent.includes(row.target));const bytes=ctx.read(row.source);assert.equal(bytes.length,row.bytes);assert.equal(B.sha(bytes),row.raw_sha256);}
  function retainedPin(relative){const rows=retained.filter(row=>row.source===relative);assert.equal(rows.length,1,'Required durable evidence: '+relative);return {path:rows[0].target,bytes:rows[0].bytes,raw_sha256:rows[0].raw_sha256};}
  for(const relative of ctx.binding.required_retained_sources)retainedPin(relative);
  for(const relative of requiredImmutableSources)retainedPin(relative);
  for(const relative of [contractPath,contextPath,donorPath,ctx.input.binding.path,ctx.input.source_inventory.path,ctx.input.independent_source_review.path,ctx.inputPath])retainedPin(relative);
  for(const predecessor of [ctx.binding.predecessors.fourth10,ctx.binding.predecessors.shopping_bag])for(const key of ['committed_receipt','committed_journal','persisted_receipt'])retainedPin(predecessor[key].path);
  const state={all_other_lexemes_json_sha256:B.hash(before.lexemes.filter(entry=>!map.has(entry.id)))};
  for(const key of ['catalog','themes','courses','expressions','sources','lexemeOrigins','expressionOrigins'])state[key+'_json_sha256']=B.hash(before[key]);
  const record={schema:1,status:'prepared_afterimage_pending_independent_review_and_actual_delivery',production_integrated:false,
    accepted_contract:retainedPin(contractPath),context_contract:retainedPin(contextPath),donor_contract:retainedPin(donorPath),
    patches:clone(contract.patches),sources:clone(contract.sources),held:clone(context.whole_entry_holds),excluded_source_ids:clone(contract.excluded_source_ids),
    context:clone(context),history:clone(history),source_observations:clone(contract.source_review),
    counts:measured,content_delta:delta,registry_before_sha256:B.hash(before),registry_after_sha256:B.hash(next),protected_state:state,
    source_prefix:{count:before.sources.length,json_sha256:B.hash(before.sources),rows:before.sources.map((entry,index)=>({index,id:entry.id,json_sha256:B.hash(entry)}))},
    delivered_bag:{entry:clone(bagPatch.after),entry_json_sha256:B.hash(bagPatch.after),provenance:{path:bagProvenance,...ctx.pins.get(bagProvenance)}},
    lineage:{root_input:retainedPin(ctx.inputPath),actual_binding:retainedPin(ctx.input.binding.path),source_inventory:retainedPin(ctx.input.source_inventory.path),independent_source_review:retainedPin(ctx.input.independent_source_review.path),
      predecessors:Object.fromEntries(Object.entries(ctx.binding.predecessors).map(([name,item])=>[name,Object.fromEntries(['committed_receipt','committed_journal','persisted_receipt'].map(key=>[key,retainedPin(item[key].path)]))])),
      fifth10_commit_receipt:null,fifth10_persisted_receipt:null},
    retained_files:clone(retained),audit:{new_language_acceptance:false,new_morphology_acceptance:false,new_expression_acceptance:false,new_media_acceptance:false,ready_module_or_course:false,project_validation_performed:false},
    delivery_scope:{lexeme_file:target,sources_file:sourceFile,provenance_file:provenance}};
  return {before,next,record,proposedFiles,retained,retainedPin};
}
module.exports={project,loadRegistry,counts,protect,acceptedIds,heldIds,target,sourceFile,provenance};
