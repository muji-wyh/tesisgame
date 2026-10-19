'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const api=require(path.join(root,'tools/validate-professional-content.cjs'));
const relative=file=>path.relative(root,file).replaceAll('\\','/');
const base=relative(path.dirname(__dirname)), variant=relative(path.resolve(__dirname,'../../first10-confirm-correction-r01'));
const C=Object.freeze({target:'data/professional/lexemes/foundation-module02.json',sources:'data/professional/sources.json',
 provenance:'data/professional/provenance/foundation-module02-language-first10-2026-10-16.json',
 docs:'docs/content-review/foundation-module02-language-first10-2026-10-16',transaction:'build/professional-english/transactions/foundation02-language-first10-r01',
 acceptance:base+'/root-acceptance-r01.json',acceptanceRaw:'ef532122536c440871f4ea81eef48252dd0fa156e011758264520dac318d9db6',
 helper:'build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs',helperRaw:'1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6',
 helperValidation:'build/professional-english/retail-module03-morphology-review/fifth10/serializer-review-r01/validation-attempt-XE9O6l/receipt.json',helperValidationRaw:'abd19b9952fe3085ef8cab5b87e430ef442780ed05f3a9a2105f909f968a9bae',
 tests:['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs']});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
const byteHash=x=>crypto.createHash('sha256').update(x).digest('hex');
const at=file=>{assert.equal(path.isAbsolute(file),false);assert.equal(file.includes('\\'),false);const p=path.resolve(root,file),r=relative(p);assert.equal(r,file);assert(!r.startsWith('../'));return p;};
const bytes=file=>fs.readFileSync(at(file));
const raw=file=>byteHash(bytes(file));
const read=file=>JSON.parse(bytes(file));
const local=name=>relative(path.join(__dirname,name));
const serialized=x=>Buffer.from(JSON.stringify(x,null,2)+'\n');
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),Buffer.isBuffer(value)?value:serialized(value),{flag:'wx'});
const protectedEntry=entry=>{const x=structuredClone(entry);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete x[k];for(const k of ['language','status','reviewer','reviewed_at'])delete x.review[k];return x;};
function evidence(){
 assert.equal(raw(C.acceptance),C.acceptanceRaw);
 const acceptance=read(C.acceptance),author=read(base+'/language-ledger.json'),corrected=read(variant+'/language-ledger.json'),pre=read(base+'/preimages.json'),context=read(base+'/expression-use-review.json');
 assert.equal(acceptance.status,'independent_ai_language_accepted_pending_delivery');assert.equal(acceptance.accepted_candidates.length,10);
 assert.equal(hash(context),acceptance.protected_context.expression_review_json_sha256);
 const consultations=[...read(base+'/source-consultations.json').consultations.filter(x=>!x.id.endsWith('-confirm')),...read(variant+'/source-consultations.json').consultations];
 const records=[...author.proposed_additive_source_records.filter(x=>!x.id.endsWith('-confirm')),...corrected.proposed_additive_source_records];
 const orderedSources=acceptance.sources_to_use.map(s=>{const r=records.find(x=>x.id===s.id);assert.equal(hash(r),s.json_sha256);return r;});assert.equal(orderedSources.length,20);
 const authors=acceptance.accepted_candidates.map(a=>{const p=a.id==='confirm.verify-arrangement.v'?corrected.proposal:author.proposals.find(x=>x.id===a.id);assert.equal(hash(p.candidate_entry),a.candidate_entry_json_sha256);assert.equal(p.before_entry_json_sha256,a.before_entry_json_sha256);assert.equal(a.accepted,true);return p;});
 assert.equal(authors.find(x=>x.id==='confirm.verify-arrangement.v').candidate_entry.difficulty,'B2');
 assert.equal(acceptance.rejected_candidate.candidate_entry_json_sha256,'e367633854ed63585c94e7cc11c1d4c9fcff7ef864f27d7bc3dda185ca107bb3');
 const paths=[C.acceptance,base+'/language-ledger.json',base+'/preimages.json',base+'/source-consultations.json',base+'/expression-use-review.json',base+'/inventory.json',variant+'/language-ledger.json',variant+'/source-consultations.json',variant+'/inventory.json'];
 const artifacts=paths.map(p=>({path:p,raw_sha256:raw(p),json_sha256:hash(read(p))}));
 for(const dir of [base,variant])for(const item of read(dir+'/inventory.json').files)assert.equal(raw(dir+'/'+item.path),item.raw_sha256);
 assert.equal(raw(C.helper),C.helperRaw);assert.equal(raw(C.helperValidation),C.helperValidationRaw);
 return {acceptance,authors,pre,context,consultations,orderedSources,artifacts};
}
function verifyScope(data,e){
 for(const selected of e.pre.selected)assert.equal(hash(data.lexemes.find(x=>x.id===selected.id)),selected.entry_json_sha256,selected.id);
 for(const row of e.context.expression_uses)assert.equal(hash(data.expressions.find(x=>x.id===row.id)),row.expression_json_sha256,row.id);
 for(const row of e.context.related_entry_boundaries)assert.equal(hash(data.lexemes.find(x=>x.id===row.id)),row.entry_json_sha256,row.id);
 for(const row of e.pre.modules)assert.equal(hash(data.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id)),row.module_json_sha256);
 for(const row of e.pre.prior_expression_holds)assert.equal(hash(data.expressions.find(x=>x.id===row.id)),row.expression_json_sha256,row.id);
 const memberships=e.pre.selected.flatMap(s=>data.courses.flatMap(c=>c.modules.flatMap(m=>{const index=m.lexeme_ids.indexOf(s.id);return index<0?[]:[{lexeme_id:s.id,course_id:c.id,module_id:m.id,index}];})));
 assert.deepEqual(memberships,e.pre.memberships);assert.equal(memberships.length,200);
 for(const record of e.orderedSources)assert(!data.sources.some(x=>x.id===record.id));
}
function makeProposal(e){
 const patches=e.authors.map(author=>{
  const decision=e.acceptance.accepted_candidates.find(x=>x.id===author.id),before=e.pre.selected.find(x=>x.id===author.id).entry,candidate=author.candidate_entry,after=structuredClone(candidate);
  assert.equal(hash(before),decision.before_entry_json_sha256);assert.deepEqual(protectedEntry(candidate),protectedEntry(before));assert.deepEqual(candidate.references.slice(0,before.references.length),before.references);
  const additions=after.references.slice(before.references.length);
  for(const ref of additions){const source=e.consultations.find(x=>x.id===ref.source_id);assert(source);assert.equal(ref.status,'pending_term_check');ref.status='verified';ref.scope='Verified selected ordinary-language consultation within root independent AI acceptance. Source finding: '+source.finding+' Literal selected source level: '+(source.observed_selected_sense_level===null?'not observed':source.observed_selected_sense_level)+'. Other-sense labels not applied: '+JSON.stringify(source.other_sense_labels_not_applied)+'. Independent decision: '+decision.independent_reason+' No human, subject-matter, morphology, media, domain, expression or release approval is claimed.';}
  after.review={...before.review,language:'reviewed',status:before.review.domain==='not_required'?'reviewed':'pending',reviewer:e.acceptance.reviewer,reviewed_at:e.acceptance.reviewed_on};
  after.editorial_notes='Shared workplace foundation. The exact ordinary selected-sense definition, example and editorial difficulty have scoped independent AI language acceptance recorded by root. '+decision.independent_reason+' '+author.meaning_decision+' Accepted forms, POS, region, morphology, image, word audio and historical reference prefix remain unchanged. Only the two newly added lexical references are verified for this bounded language decision. No whole expression, specialist procedure, authority, module or release approval is implied.';
  assert.deepEqual(protectedEntry(after),protectedEntry(before));assert.deepEqual(after.references.slice(0,before.references.length),before.references);
  for(const key of Object.keys(candidate).filter(k=>!['review','references','editorial_notes'].includes(k)))assert.deepEqual(after[key],candidate[key]);
  assert.deepEqual(api.schemaErrors(after,'lexeme',at('data/professional/schemas')),[]);
  return {id:after.id,before:structuredClone(before),after,before_sha256:hash(before),after_sha256:hash(after),reviewed_candidate_entry_json_sha256:hash(candidate),candidate_artifact:decision.candidate_path,
   changed_fields:Object.keys(before).filter(k=>hash(before[k])!==hash(after[k])),protected_fields_sha256:hash(protectedEntry(before)),source_record_ids:additions.map(x=>x.source_id),
   memberships:author.memberships,difficulty:{before:before.difficulty,accepted_editorial:after.difficulty,observed_selected_source_labels:decision.observed_source_levels,dictionary_level_certification:false,independent_editorial_basis:decision.independent_reason},
   integration_metadata_delta:{review_before:before.review,review_after:after.review,new_reference_state:'pending_term_check to verified for the two new lexical references only',historical_reference_prefix_exact:true,author_editorial_notes_sha256:hash(candidate.editorial_notes),integrated_editorial_notes_sha256:hash(after.editorial_notes),candidate_definition_example_difficulty_exact:true}};
 });
 return {schema:1,status:'root_accepted_module02_first10_delivery_unbound',reviewer:e.acceptance.reviewer,root_acceptance:{path:C.acceptance,raw_sha256:C.acceptanceRaw,json_sha256:hash(e.acceptance)},patches,sources:e.orderedSources,
  evidence_artifacts:e.artifacts,rejected_confirm_candidate:structuredClone(e.acceptance.rejected_candidate),source_observations:e.consultations.map(x=>({id:x.id,url:x.url,section:x.section,finding:x.finding,observed_selected_sense_level:x.observed_selected_sense_level,other_sense_labels_not_applied:x.other_sense_labels_not_applied})),
  protected_context:{expressions:e.context.expression_uses.map(x=>({id:x.id,json_sha256:x.expression_json_sha256})),related_entries:e.context.related_entry_boundaries.map(x=>({id:x.id,json_sha256:x.entry_json_sha256})),modules:e.pre.modules.map(x=>({course_id:x.course_id,module_id:x.module_id,json_sha256:x.module_json_sha256})),expression_hold_ids:e.context.expression_ambiguity_hold_ids,prior_expression_hold_ids:e.context.prior_expression_hold_ids,prior_expression_holds:e.pre.prior_expression_holds},
  review_boundary:'Ten exact root-accepted ordinary language decisions only. Deterministic review/reference/note integration deltas are recorded separately from accepted author candidate hashes. No new scored expression binding or morphology, media, specialist, module or release approval.',
  baseline_bound:false,production_mutated:false};
}
function applyProposal(data,proposal){const next=structuredClone(data);for(const p of proposal.patches){const index=next.lexemes.findIndex(x=>x.id===p.id);assert.deepEqual(next.lexemes[index],p.before);next.lexemes[index]=structuredClone(p.after);}for(const s of proposal.sources){assert(!next.sources.some(x=>x.id===s.id));next.sources.push(structuredClone(s));}return next;}
function verifyPrepared(){const receipt=read(local('preparation-receipt.json'));assert.equal(receipt.baseline_bound,false);for(const row of receipt.files)assert.equal(raw(local(row.path)),row.raw_sha256,row.path);const e=evidence();const proposal=read(local('delivery-proposal.json'));assert.deepEqual(proposal,makeProposal(e));assert.equal(raw(C.helper),C.helperRaw);return {receipt,e,proposal};}
function validateBaseline(file,sha){return require('./composite-baseline.cjs')(module.exports,file,sha);}
function args(names){const out={},values=process.argv.slice(2);while(values.length){const key=values.shift();assert(names.includes(key),'Unknown option '+key);assert(!Object.hasOwn(out,key));out[key]=values.shift();assert(out[key]);}for(const key of names)assert(out[key],'Required '+key);return out;}
module.exports={fs,path,assert,root,base,variant,C,api,hash,byteHash,at,bytes,raw,read,local,relative,serialized,save,protectedEntry,evidence,verifyScope,makeProposal,applyProposal,verifyPrepared,validateBaseline,args};
