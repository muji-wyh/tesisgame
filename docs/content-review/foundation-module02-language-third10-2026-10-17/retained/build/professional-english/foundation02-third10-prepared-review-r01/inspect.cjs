'use strict';
// Evidence-only inspection: direct reads, JSON comparisons and text reconstruction.
// No production loader, projection module, test callback or native process is invoked.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const own='build/professional-english/foundation02-third10-prepared-review-r01';
const prep='build/professional-english/foundation02-third10-delivery-preparation-r01';
const out=prep+'/execution-r01',witness='build/professional-english/foundation02-third10-root-prepare-r01';
const at=p=>path.resolve(root,p),bytes=p=>fs.readFileSync(at(p)),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),raw=p=>sha(bytes(p)),read=p=>JSON.parse(bytes(p));
const save=(n,v)=>fs.writeFileSync(at(own+'/'+n),JSON.stringify(v,null,2)+'\n',{flag:'wx'});
assert.equal(path.resolve(process.cwd()).toLowerCase(),path.resolve(root).toLowerCase());
assert(!fs.existsSync(at(own+'/inspection.json')),'Preserve this one-shot inspection.');
const start=read(out+'/execution-start.json'),end=read(out+'/execution-end.json'),receipt=read(out+'/preparation-receipt.json');
const measured=read(out+'/measured-inputs-before.json'),checks=read(out+'/projection-checks.json');
const rootReceipt=read(witness+'/execution/receipt.json');
const pins=read(prep+'/input-pins.json'),record=read(out+'/accepted-language.json'),patches=read(out+'/test-patches.json').patches;
const authorDir='docs/content-review/foundation-module02-language-third10-research-2026-10-17';
const languageReview=read('docs/content-review/foundation-module02-language-third10-independent-review-2026-10-17/review.json');
const ledger=read(authorDir+'/candidate-ledger.json');
const compared=[];
function pin(p,h){assert.equal(raw(p),h,p);compared.push({path:p,sha256:h});}
assert.equal(raw(witness+'/execution/receipt.json'),'e67c73a1197237ba2b0cb4ef1d720d603fef0cbd3343fd162075cc591e902e9d');
assert.equal(rootReceipt.ok,true);assert.deepEqual(rootReceipt.before,rootReceipt.after);assert.equal(rootReceipt.commands.length,4);
const commands=[['--check',prep+'/projection.cjs'],['--check',prep+'/test-transforms.cjs'],['--check',prep+'/prepare.cjs'],[prep+'/prepare.cjs','--root-dispatch','confirmed-by-root']];
rootReceipt.commands.forEach((r,i)=>{assert.equal(r.exit_code,0);assert.equal(r.signal,null);assert.equal(r.error,null);assert.deepEqual(r.command.slice(1),commands[i]);pin(witness+'/execution/command-'+(i+1)+'.log',r.log_sha256);});
for(const r of rootReceipt.before)pin(r.path,r.sha256);
pin(rootReceipt.static_review.path,rootReceipt.static_review.sha256);
assert.equal(start.status,'preparation_dispatch_recorded');assert.equal(end.status,'prepared_pending_independent_technical_review');
assert.equal(receipt.status,'frozen_preparation_pending_independent_technical_review');
assert.deepEqual(start.source_files,end.source_files_after);assert.deepEqual(start.source_files,receipt.source_files);
assert.deepEqual(measured.current_sha256,receipt.measured_input_sha256);assert.equal(Object.keys(measured.current_sha256).length,680);
for(const r of [...receipt.source_files,...receipt.artifacts])pin(r.path,r.raw_sha256);
for(const [p,h] of Object.entries(measured.current_sha256))pin(p,h);
for(const r of [...pins.files,pins.source_manifest,pins.historical_input_pathlist])pin(r.path,r.raw_sha256);
for(const r of read(pins.source_manifest.path)[pins.source_manifest.property])pin(r.path,r.raw_sha256);
for(const p of pins.must_remain_absent)assert(!fs.existsSync(at(p)),p+' must remain absent.');
assert.equal(checks.ok,true);assert.equal(checks.current_persisted_node_execution,false);assert.equal(checks.native_dispatched,false);assert(checks.callbacks.every(r=>r.passed===true));
assert.equal(receipt.projected_callback_count,checks.callbacks.length);assert.equal(checks.before_audit.errors,0);assert.equal(checks.after_audit.errors,0);
assert.equal(checks.before_audit.summary.reviewed_lexemes,130);assert.equal(checks.after_audit.summary.reviewed_lexemes,138);
assert.equal(checks.after_audit.summary.ready_modules,0);assert.equal(checks.after_audit.summary.release_ready,false);
const original=read(out+'/foundation-module02.json.before'),next=read(out+'/foundation-module02.json.after');
const beforeSources=read(out+'/sources.json.before'),afterSources=read(out+'/sources.json.after');
assert(bytes(pins.files[0].path).equals(bytes(out+'/foundation-module02.json.before')));assert(bytes(pins.files[1].path).equals(bytes(out+'/sources.json.before')));
assert.equal(record.patches.length,8);assert.equal(record.sources.length,16);assert.equal(record.held.length,2);assert.equal(record.new_language_approval,false);
const projected=structuredClone(original);
const protect=e=>{const x=structuredClone(e);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete x[k];for(const k of ['status','language','reviewer','reviewed_at'])delete x.review[k];return x;};
for(const p of record.patches){
  const a=languageReview.entries.find(v=>v.id===p.id),c=ledger.entries.find(v=>v.id===p.id);
  assert.equal(original.lexemes.filter(v=>v.id===p.id).length,1);assert.equal(next.lexemes.filter(v=>v.id===p.id).length,1);
  assert.equal(sha(JSON.stringify(p.before)),a.before_entry_sha256);assert.deepEqual(p.before,c.before_entry);assert.deepEqual(p.accepted_fields,a.accepted_fields);
  assert.deepEqual(p.accepted_content,c.content_projection);assert.equal(sha(JSON.stringify(p.accepted_content)),a.content_projection_sha256);
  assert.deepEqual(protect(p.after),protect(p.before));assert.equal(p.after.definition,p.before.definition);assert.equal(p.after.example,p.before.example);
  assert.equal(p.after.difficulty,a.accepted_fields.difficulty);assert.equal(p.after.review.status,'reviewed');assert.equal(p.after.review.language,'reviewed');
  assert.equal(p.after.review.reviewer,languageReview.reviewer);assert.equal(p.after.review.reviewed_at,languageReview.reviewed_on);
  assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);assert.equal(p.after.references.length,p.before.references.length+2);
  assert.deepEqual(p.after.references.slice(-2).map(v=>v.source_id),p.source_ids);assert(p.after.references.slice(-2).every(v=>v.status==='verified'));
  for(const v of [p.after.editorial_notes,...p.after.references.slice(-2).map(v=>v.scope)]){assert.match(v,/did not reopen/);assert.match(v,/No human, subject-matter/);assert.match(v,/not psychometric CEFR certification/);}
  assert.equal(sha(JSON.stringify(p.after)),p.after_sha256);assert.deepEqual(original.lexemes.find(v=>v.id===p.id),p.before);assert.deepEqual(next.lexemes.find(v=>v.id===p.id),p.after);
  projected.lexemes[projected.lexemes.findIndex(v=>v.id===p.id)]=p.after;
}
assert.deepEqual(projected,next);assert.equal(record.patches.filter(p=>p.before.difficulty!==p.after.difficulty).length,7);
assert.deepEqual(afterSources,{...beforeSources,sources:[...beforeSources.sources,...record.sources]});
for(const r of record.sources){assert.equal(r.status,'consulted');assert.equal(r.asset_license,null);assert.equal(r.assets_acquired,false);}
for(const r of record.held){assert.deepEqual(original.lexemes.find(v=>v.id===r.id),r.value);assert.deepEqual(next.lexemes.find(v=>v.id===r.id),r.value);assert.equal(r.reference_or_note_additions,0);assert.equal(r.review_gate_changes,0);}
for(const r of record.protected_context.prior_lexical_holds)assert.deepEqual(next.lexemes.find(v=>v.id===r.id),r.before_entry);
for(const id of record.excluded_source_ids)assert(!afterSources.sources.some(v=>v.id===id));
const transformSource=bytes(prep+'/test-transforms.cjs').toString('utf8');
function appended(name){const open='const '+name+' = String.raw`';const begin=transformSource.indexOf(open);assert(begin>=0);const end=transformSource.indexOf('`;',begin+open.length);assert(end>=0);return transformSource.slice(begin+open.length,end);}
for(const p of patches){
  const before=bytes(out+'/'+p.before_artifact),after=bytes(out+'/'+p.after_artifact);pin(p.path,p.before_sha256);assert.equal(sha(before),p.before_sha256);assert.equal(sha(after),p.after_sha256);
  let text=before.toString('utf8');for(const edit of p.exact_anchor_edits){assert.equal(text.split(edit.before).length-1,edit.count);text=text.split(edit.before).join(edit.after);}
  text+=appended(p.native?'nativeTests':p.path.includes('professional-content')?'contentTests':'morphologyTests');
  assert.equal(text,after.toString('utf8'));assert.equal(p.native_parse_and_execution_pending,p.native);
}
const afterCheck=Object.entries(measured.current_sha256).every(([p,h])=>raw(p)===h);assert(afterCheck);
const artifacts=[...new Set([prep+'/author-inventory.json',...receipt.source_files.map(r=>r.path),...fs.readdirSync(at(out)).filter(n=>fs.statSync(at(out+'/'+n)).isFile()).map(n=>out+'/'+n),witness+'/invoke.cjs',witness+'/execution/receipt.json',...commands.map((_,i)=>witness+'/execution/command-'+(i+1)+'.log'),rootReceipt.static_review.path])].sort().map(p=>({path:p,sha256:raw(p)}));
const inspection={schema:1,ok:true,reviewed_at:new Date().toISOString(),method:'Direct frozen JSON/raw hashing and exact-anchor string reconstruction; no author module, validator, suite, native or commit execution.',inspector:{path:own+'/inspect.cjs',sha256:raw(own+'/inspect.cjs')},hash_comparisons:compared.length,distinct_compared_files:new Set(compared.map(v=>v.path)).size,current_measurement_count:680,current_measurement_start_end_match:true,executed_sources_start_end_match:true,root_commands_passed:4,projected_callbacks:checks.callbacks.length,callbacks_by_file:Object.fromEntries([...new Set(checks.callbacks.map(v=>v.file))].map(f=>[f,checks.callbacks.filter(v=>v.file===f).length])),prepared_test_afterimages_reconstructed:3,accepted_patches:8,source_additions:16,new_whole_entry_holds:2,prior_whole_entry_holds:2,protected_context_counts:{memberships:record.protected_context.memberships.length,modules:record.protected_context.modules.length,expressions:record.protected_context.expressions.length,focus_expressions:record.protected_context.focus_expressions.length,related_entries:record.protected_context.related_entries.length,inherited_holds:record.protected_context.inherited_expression_holds.length},native_afterimage_execution_still_required:true,fresh_current_baseline_still_required:true,commit_code_acceptance:false,production_mutated:false,artifacts};
save('inspection.json',inspection);
save('review.json',{schema:1,status:'independent_prepared_output_review_no_blocker_found',reviewer:'Codex recover_delivery, independent of the preparation author',reviewed_at:inspection.reviewed_at,scope:'Executed preparation output, language-to-metadata projection, protected contexts and history only. This is not approval of the separate commit implementation.',inspection:{path:own+'/inspection.json',sha256:raw(own+'/inspection.json')},reviewed_files:artifacts,findings:['All four root-dispatched commands succeeded and source-start/end manifests match current frozen sources.','All 680 freshly measured inputs match preparation receipt and remain unchanged; R33 provides paths only.','Eight accepted language projections, sixteen bounded consulted sources, four lexical holds and all protected nonlanguage fields match.','All three test afterimages reconstruct exactly from recorded anchor edits and frozen appended source blocks. Historical reversals reject partial whole-entry and source-suffix drift in the retained projected callback results.','The pending complete form-image mismatch, 17 inherited expression holds and zero-ready-module boundary remain exact.'],limitations:['This inspection did not rerun publisher consultation, author modules, validators, suites or native code.',String(checks.callbacks.length)+' projected callbacks are recorded; they are not described as persisted Node execution.','Fresh scoped current baseline and isolated native afterimage evidence remain required before any commit.','The new commit implementation and persisted journal test require separate independent review and guard probes; this review does not self-approve them.'],production_mutated:false,commit_implementation_approved:false});
save('binding.json',{schema:1,status:'prepared_output_binding_for_future_reviewed_commit',repository_root:root,preparation_directory:prep,prepared_artifacts:artifacts,prepared_review:{path:own+'/review.json',sha256:raw(own+'/review.json')},inspection:{path:own+'/inspection.json',sha256:raw(own+'/inspection.json')},source_baseline:receipt.source_baseline,current_inputs:receipt.measured_input_sha256,production_replacements:[{path:pins.files[0].path,before_artifact:out+'/foundation-module02.json.before',after_artifact:out+'/foundation-module02.json.after'},{path:pins.files[1].path,before_artifact:out+'/sources.json.before',after_artifact:out+'/sources.json.after'},...patches.map(p=>({path:p.path,before_artifact:out+'/'+p.before_artifact,after_artifact:out+'/'+p.after_artifact}))].map(p=>({...p,before_sha256:raw(p.before_artifact),after_sha256:raw(p.after_artifact)})),provenance_prepared:{path:out+'/accepted-language.json',sha256:raw(out+'/accepted-language.json')},required_future_evidence:['Fresh successful scoped current baseline','Successful isolated native afterimage parse and execution','Independent exact commit-source technical review and guard probes','Root exclusive mutation-window token','Committed helper journal and persisted postcommit tests'],independent_commit_acceptance:false});
console.log(JSON.stringify({ok:true,inspection_sha256:raw(own+'/inspection.json'),review_sha256:raw(own+'/review.json'),binding_sha256:raw(own+'/binding.json'),callbacks:checks.callbacks.length,hash_comparisons:compared.length},null,2));
