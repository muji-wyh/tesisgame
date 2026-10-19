'use strict';
// Independent, read-only verification. Only this review directory receives output.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'../../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const pkg='build/professional-english/foundation-module02-language-review/second10-delivery-r02';
const rel=f=>path.relative(root,f).replaceAll('\\','/'),at=f=>path.join(root,f);
const raw=f=>fs.readFileSync(at(f)),read=f=>JSON.parse(raw(f)),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),hash=v=>sha(JSON.stringify(v));
const executedSource=sha(fs.readFileSync(__filename));
const prepared=read(pkg+'/preparation-receipt.json');
assert.equal(prepared.status,'frozen_preparation_pending_independent_technical_review');
for(const row of prepared.files)assert.equal(sha(raw(row.path)),row.raw_sha256,row.path);
const executionStart=read(pkg+'/execution-start.json'),attempt=read(pkg+'/preparation-attempt-001.json');
assert.equal(executionStart.status,'preparation_dispatch_recorded');assert.equal(executionStart.entrypoint,pkg+'/prepare.cjs');
assert.equal(prepared.executed_source_equality_verified,true);assert.equal(attempt.status,0);assert.equal(attempt.signal,null);assert.equal(attempt.error,null);assert.equal(attempt.executed_source_equality_verified,true);
assert.deepEqual(prepared.executed_source_manifest,{path:pkg+'/execution-start.json',raw_sha256:sha(raw(pkg+'/execution-start.json'))});
assert.equal(attempt.execution_start_raw_sha256,sha(raw(pkg+'/execution-start.json')));assert.equal(attempt.preparation_receipt_raw_sha256,sha(raw(pkg+'/preparation-receipt.json')));assert.deepEqual(attempt.source_files,executionStart.source_files);
assert.deepEqual(executionStart.source_files.map(x=>path.basename(x.path)),['delivery-lib.cjs','test-transforms.cjs','prepare.cjs','deliver.cjs','baseline-config.json','HANDOFF.md']);
for(const row of executionStart.source_files){assert.equal(sha(raw(row.path)),row.raw_sha256);assert(prepared.files.some(x=>x.path===row.path&&x.raw_sha256===row.raw_sha256));}
const L=require(at(pkg+'/delivery-lib.cjs')),p=read(pkg+'/accepted-language.json'),binding=read(pkg+'/binding.json'),tp=read(pkg+'/test-patches.json'),sv=read(pkg+'/scratch-validation.json');
const inherited=read(L.C.evidence+'/review.json'),e=L.evidence(),b=L.baseline(),before=b.data;
assert.equal(sha(raw(L.C.evidence+'/review.json')),'2d95fb5e1f08ed79a2b9de27ad2e031e36139385acf0d6d0e3e7a13b1a6f865e');
assert.deepEqual(binding.baseline_inputs,b.inputs);assert.deepEqual(binding.validation,b.validation);
assert.equal(binding.registry_before_sha256,hash(before));
assert.equal(binding.accepted_language_raw_sha256,sha(raw(pkg+'/accepted-language.json')));
assert.equal(binding.test_patches_raw_sha256,sha(raw(pkg+'/test-patches.json')));
assert.equal(p.new_language_approval,false);assert.equal(p.independent_review.human_or_specialist_approval,false);
const generated=L.proposal(e);
for(const k of ['patches','held','sources','source_observations','excluded_source_ids','independent_review','accepted_evidence'])assert.deepEqual(p[k],generated[k],k);
assert.deepEqual(p.patches.map(x=>x.id),inherited.accepted.map(x=>x.id));
assert.deepEqual(p.held.map(x=>x.id),['collect.gather.v','notify.inform.v']);
const next=structuredClone(before),ids=new Set(p.patches.map(x=>x.id));
assert.equal(ids.size,8);assert.equal(p.sources.length,16);assert.equal(new Set(p.sources.map(x=>x.id)).size,16);
const decisions=[];
for(const patch of p.patches){
  const accepted=inherited.accepted.find(x=>x.id===patch.id),live=before.lexemes.find(x=>x.id===patch.id);
  assert.deepEqual(patch.before,live);assert.equal(hash(live),accepted.before_entry_json_sha256);
  assert.deepEqual(patch.accepted_fields,accepted.accepted_fields);assert.equal(hash(patch.accepted_content),accepted.accepted_content_projection_json_sha256);
  assert.equal(patch.decision,accepted.decision);assert.deepEqual(patch.selected_source_levels,accepted.selected_source_levels);
  const expected=structuredClone(live);Object.assign(expected,accepted.accepted_fields);
  assert.deepEqual(patch.accepted_content,expected);
  expected.review={...live.review,status:'reviewed',language:'reviewed',reviewer:inherited.reviewer,reviewed_at:inherited.reviewed_on};
  expected.references=patch.after.references;expected.editorial_notes=patch.after.editorial_notes;
  assert.deepEqual(patch.after,expected);assert.deepEqual(patch.after.references.slice(0,live.references.length),live.references);
  const refs=patch.after.references.slice(live.references.length);assert.equal(refs.length,2);assert.deepEqual(refs.map(x=>x.source_id),accepted.source_ids);
  for(const ref of refs){assert.equal(ref.status,'verified');assert.match(ref.scope,/exact independently accepted definition, example and editorial difficulty/);assert.match(ref.scope,/No human, subject-matter/);}
  assert.equal(hash(patch.after),patch.after_sha256);assert.deepEqual(patch.after.media,live.media);assert.deepEqual(patch.after.morphology,live.morphology);
  assert.equal(patch.after.review.domain,live.review.domain);assert.equal(patch.after.morphology.review.status,'pending');
  next.lexemes[next.lexemes.findIndex(x=>x.id===patch.id)]=structuredClone(patch.after);
  decisions.push({id:patch.id,accepted_fields_exact:true,protected_fields_exact:true,history_prefix_exact:true,added_references:refs.length,literal_levels:patch.selected_source_levels});
}
for(const held of p.held){assert.deepEqual(before.lexemes.find(x=>x.id===held.id),held.value);assert.equal(hash(held.value),held.whole_entry_json_sha256);assert.equal(held.reference_or_note_additions,0);assert.equal(held.review_gate_changes,0);}
for(const s of p.sources){assert.equal(before.sources.some(x=>x.id===s.id),false);assert.equal(s.status,'consulted');assert.equal(s.assets_acquired,false);assert.equal(s.asset_license,null);const obs=p.source_observations.find(x=>x.id===s.id);assert.equal(s.url,obs.url);assert.equal(s.publisher,obs.publisher);}
for(const id of p.excluded_source_ids)assert.equal(p.sources.some(x=>x.id===id)||before.sources.some(x=>x.id===id),false);
next.sources.push(...structuredClone(p.sources));assert.deepEqual(next,L.apply(before,p));assert.equal(hash(next),binding.registry_after_sha256);
for(const k of Object.keys(before))if(!['lexemes','sources'].includes(k))assert.deepEqual(next[k],before[k],k);
assert.deepEqual(next.lexemes.filter(x=>!ids.has(x.id)),before.lexemes.filter(x=>!ids.has(x.id)));
const byText=text=>p.patches.find(x=>x.after.text===text);
assert.equal(byText('deliver').accepted_content_json_sha256,'bf7339125c5ec83bd6c1f8170bb68e731fb89d7a8713d36491208677290864ea');
assert.equal(byText('deliver').after.definition,'To take physical items to the person or place they are intended for.');
const complete=byText('complete');assert.match(complete.after.editorial_notes,/form-image brief/);assert.match(complete.after.editorial_notes,/unapproved/);
assert.doesNotMatch(complete.after.editorial_notes,/Finishing a form is an instance of that sense|require separate scoped resolution before future delivery claims|must be replaced by bounded language provenance before any future integration/);
for(const s of p.sources.filter(x=>complete.source_ids.includes(x.id)))assert.doesNotMatch(s.scope,/are preimages only|require separate scoped resolution before future delivery claims/);
assert.match(byText('replace').after.editorial_notes,/sense 3 A2/);assert.match(byText('replace').after.editorial_notes,/sense 3 B1/);assert.match(byText('replace').after.editorial_notes,/sense 2 B1\+/);
const c=p.protected_context;
assert.equal(c.memberships.length,200);assert.equal(c.modules.length,20);assert.equal(c.expressions.length,245);assert.equal(c.focus_expressions.length,6);assert.equal(c.related_entries.length,66);assert.equal(c.inherited_expression_holds.length,17);
L.verifyScope(before,p);
for(const [key,value]of [['all_other_lexemes_json_sha256',next.lexemes.filter(x=>!ids.has(x.id))],['all_expressions_json_sha256',next.expressions],['all_courses_json_sha256',next.courses],['all_themes_json_sha256',next.themes],['previous_sources_json_sha256',before.sources]])assert.equal(hash(value),c[key]);
const audit=L.api.auditProfessionalContent({rootDir:root,data:next});assert.equal(audit.errors.length,0);assert.deepEqual(audit.summary,binding.candidate_audit.summary);assert.equal(audit.summary.reviewed_lexemes,130);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
assert.equal(sv.ok,true);assert.equal(sv.projected_callback_count,217);assert.equal(sv.excluded_persisted_callbacks.length,1);assert.equal(sv.native_not_executed_in_preparation,true);
const virtual=new Map([[at(L.C.provenance),L.serialize(p)]]);
for(const [target,key]of [[L.C.target,'lexemes'],[L.C.sources,'sources']]){const env=read(target);env[key]=key==='lexemes'?env.lexemes.map(x=>ids.has(x.id)?structuredClone(p.patches.find(y=>y.id===x.id).after):x):[...env.sources,...p.sources];virtual.set(at(target),L.serialize(env));}
const projectedFs=new Proxy(fs,{get(target,key){if(key==='readFileSync')return(file,...options)=>{const buffer=virtual.get(path.resolve(file));if(!buffer)return target.readFileSync(file,...options);const enc=typeof options[0]==='string'?options[0]:options[0]?.encoding;return enc?buffer.toString(enc):Buffer.from(buffer);};return target[key];}});
const projectedApi={...L.api,loadProfessionalContent:(...args)=>!args[0]||path.resolve(args[0])===root?structuredClone(next):L.api.loadProfessionalContent(...args)};
const callbacks=[],transforms=[],reversalChecks=[];
const deferred='Foundation02 second-ten delivery binds explicit composite evidence and committed guarded journal';
for(const patch of tp.patches){
  const original=raw(patch.file),savedBefore=raw(pkg+'/'+patch.before_artifact),after=raw(pkg+'/'+patch.after_artifact);
  assert(original.equals(savedBefore));assert.equal(sha(original),patch.before_sha256);assert.equal(sha(after),patch.after_sha256);assert.equal(b.inputs[patch.file],patch.before_sha256);
  let expected=original.toString('utf8');for(const edit of patch.exact_anchor_edits){assert.equal(expected.split(edit.before).length-1,edit.count);expected=expected.split(edit.before).join(edit.after);}
  assert(after.toString('utf8').startsWith(expected));const suffix=after.toString('utf8').slice(expected.length);
  const actual=require(at(pkg+'/test-transforms.cjs')).transform(patch.file,original);assert(actual.bytes.equals(after));assert.deepEqual(actual.edits,patch.exact_anchor_edits);
  if(patch.native){
    assert.equal(patch.exact_anchor_edits.length,2);assert.equal(patch.native_execution_required_after_delivery,true);assert.equal(patch.syntax_valid,null);
    assert.match(suffix,/func _f02s_reverse/);assert.match(suffix,/func _check_foundation02_second_language/);assert.match(suffix,/entry != patch.before and entry != patch.after/);assert.match(suffix,/patch.before.duplicate\(true\)/);
    const start=original.indexOf(Buffer.from('\t\telif id == "attendance.presence-record.n":')),end=original.indexOf(Buffer.from('\n\t\tcheck(entry == snapshot.entry'),start);assert(start>=0&&end>start);assert(after.includes(original.subarray(start,end)));
    transforms.push({file:patch.file,exact_before:true,exact_after:true,anchor_edits:2,attendance_correction_preserved:true,native_execution:false});continue;
  }
  const registered=[],req=createRequire(at(patch.file)),load=name=>name==='node:test'?((title,...rest)=>registered.push({title,fn:rest.at(-1)})):name==='node:fs'?projectedFs:name==='../tools/validate-professional-content.cjs'?projectedApi:req(name);
  const names=['beforeFoundation02SecondLanguage','beforeAttendanceLanguage','beforeFoundation02FirstLanguage','beforeSupervisorLanguage','beforeFoundationFifthLanguage','beforeFoundationFourthLanguage','beforeFoundationThirdLanguage','beforeFoundationSecondLanguage'];
  if(patch.file.includes('retail-morphology'))names.push('beforeFoundationLanguage');
  const text=after.toString('utf8')+'\nmodule.exports={'+names.join(',')+'};\n';
  const fn=vm.compileFunction(text,['require','__dirname','module','exports','__filename'],{filename:patch.file}),module={exports:{}};
  fn(load,path.dirname(at(patch.file)),module,module.exports,at(patch.file));
  assert.deepEqual(registered.filter(x=>x.title!==deferred).map(x=>x.title),sv.projected_callbacks.filter(x=>x.file===patch.file).map(x=>x.title));
  const selected=registered.filter(x=>x.title!==deferred&&(/^(Foundation|Attendance|Fourth-ten Foundation|Third-ten Foundation|Fifth-ten Foundation|Module02 chronological)/.test(x.title)||x.title==='draft audit preserves the complete scope and reports actual authored coverage'||x.title==='Retail04 changes morphology only and preserves complete family, course and source scope'));
  for(const row of selected){assert.equal(typeof row.fn,'function');const result=row.fn();assert(!result||typeof result.then!=='function');callbacks.push({file:patch.file,title:row.title,passed:true});}
  for(const lexical of p.patches){
    let rejected=0,accepted=0;
    for(const state of [lexical.before,lexical.after])for(const [name,reverse]of Object.entries(module.exports)){
      const restored=reverse(state);assert.deepEqual(restored,lexical.before);assert.notEqual(restored,state);accepted++;
      const mutations=[v=>delete v.definition,v=>v.definition+=' drift',v=>v.example+=' drift',v=>v.difficulty='C2',v=>v.review.reviewer='drift',v=>v.review.domain='reviewed',v=>v.references[0].scope+=' drift',v=>v.editorial_notes+=' drift',v=>v.media.audio.voice='drift',v=>v.morphology.review.status='reviewed',v=>v.accepted_forms.push('drift'),v=>v.regions.push('unexpected'),v=>v.practice_modes.push('drift'),v=>v.extra=true];
      for(const mutate of mutations){const changed=structuredClone(state);mutate(changed);assert.throws(()=>reverse(changed),name);rejected++;}
      const clone=reverse(state);clone.media.image.brief='independent clone';clone.references[0].scope='independent clone';assert.notEqual(lexical.before.media.image.brief,clone.media.image.brief);assert.notEqual(lexical.before.references[0].scope,clone.references[0].scope);
    }
    reversalChecks.push({file:patch.file,id:lexical.id,accepted_exact_states:accepted,rejected_mutations:rejected,deep_clone_verified:true});
  }
  assert.equal((suffix.match(/^test\(/gm)||[]).length,patch.appended_tests);
  transforms.push({file:patch.file,exact_before:true,exact_after:true,anchor_edits:patch.exact_anchor_edits.length,registered_callbacks:registered.length,independent_callbacks:selected.length});
}
assert.equal(tp.patches.length,3);
for(const row of prepared.files)assert.equal(sha(raw(row.path)),row.raw_sha256,row.path);
for(const [file,value]of Object.entries(b.inputs))assert.equal(sha(raw(file)),value,file);
assert.equal(hash(L.api.loadProfessionalContent(root)),binding.registry_before_sha256);
const reviewedFiles=[...prepared.files,...['preparation-receipt.json','preparation-attempt-001.json'].map(name=>({path:pkg+'/'+name,raw_sha256:sha(raw(pkg+'/'+name))}))];
assert.equal(sha(fs.readFileSync(__filename)),executedSource);
const out={schema:1,ok:true,review_kind:'technical_only',package:pkg,production_mutated:false,native_dispatched:false,full_combined_validation:false,baseline_input_count:Object.keys(b.inputs).length,registry_before_sha256:binding.registry_before_sha256,registry_after_sha256:binding.registry_after_sha256,reviewed_files:reviewedFiles,accepted_decisions:decisions,held_exact:p.held.map(x=>x.id),source_count:16,context:{memberships:200,modules:20,expressions:245,focus:6,related:66,inherited_holds:17},candidate_audit:{summary:audit.summary,errors:0},transforms,projected_callbacks:callbacks,reversals:reversalChecks,deferred:[deferred,'Persisted combined Node/native/audio validation after root delivery.'],all679_inputs_unchanged:true};
out.executed_reviewer_source={path:rel(__filename),raw_sha256_before:executedSource,raw_sha256_after:sha(fs.readFileSync(__filename)),unchanged:true};
out.author_executed_source_equality={verified:true,manifest:{path:pkg+'/execution-start.json',raw_sha256:sha(raw(pkg+'/execution-start.json'))},attempt:{path:pkg+'/preparation-attempt-001.json',raw_sha256:sha(raw(pkg+'/preparation-attempt-001.json'))},source_count:executionStart.source_files.length};
fs.writeFileSync(path.join(__dirname,'checks.json'),JSON.stringify(out,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({ok:true,reviewed_files:reviewedFiles.length,projected_callbacks:callbacks.length,accepted_reversal_states:reversalChecks.reduce((n,x)=>n+x.accepted_exact_states,0),rejected_reversal_mutations:reversalChecks.reduce((n,x)=>n+x.rejected_mutations,0),checks:rel(path.join(__dirname,'checks.json')),checks_sha256:sha(fs.readFileSync(path.join(__dirname,'checks.json')))}));
