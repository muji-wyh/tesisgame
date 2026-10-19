'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const base='build/professional-english/foundation02-verify-resolution-research-r01';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),hash=v=>sha(JSON.stringify(v));
const bytes=p=>fs.readFileSync(path.join(root,p)),read=p=>JSON.parse(bytes(p));
const bind=p=>({path:p,bytes:bytes(p).length,raw_sha256:sha(bytes(p))});
const save=(n,v)=>fs.writeFileSync(path.join(__dirname,n),JSON.stringify(v,null,2)+'\n',{flag:'wx'});
const inventory=read(base+'/inventory.json');assert.equal(sha(bytes(base+'/inventory.json')),'f98bb9a53ddc26382c3ed9aa0df1af03991e26223077389a569dd9896beee1b9');
for(const row of inventory.files){assert.equal(bytes(base+'/'+row.file).length,row.bytes);assert.equal(sha(bytes(base+'/'+row.file)),row.sha256);}
const before=read(base+'/lexeme-before.json'),candidate=read(base+'/lexeme-after.proposed.json'),eb=read(base+'/expression-before.json'),ea=read(base+'/expression-after.proposed.json'),context=read(base+'/context.json');
assert.equal(hash(candidate),'55863911bc60ebf5368d660615a8fce964e224194a8bfd436fdde55d9c914aad');assert.equal(hash(ea),'c578dec25399c372607843812c30e063865e77174836e9005ecf04f5f9f78ff5');
const measured=new Map(),mr=p=>{measured.set(p,bind(p));return read(p);};
const catalog=mr('data/professional/catalog.json'),res=p=>{assert(p.startsWith('res://'));return p.slice(6);};
const lexemes=catalog.lexeme_files.flatMap(p=>mr(res(p)).lexemes),expressions=catalog.expression_files.flatMap(p=>mr(res(p)).expressions),courses=catalog.courses.map(p=>mr(res(p.manifest)));
assert.equal(lexemes.length,4939);assert.equal(expressions.length,1620);assert.equal(courses.length,20);
assert.deepEqual(lexemes.find(e=>e.id===before.id),before);assert.deepEqual(expressions.find(e=>e.id===eb.id),eb);
assert.equal(lexemes.filter(e=>e.id===candidate.id||[e.text,e.display_text,...e.accepted_forms].some(t=>['ensure','insure','assure'].includes(t.toLowerCase()))).length,0);
assert.deepEqual(expressions.filter(e=>e.focus_lexeme_ids.includes(before.id)).map(e=>e.id),[eb.id]);
const substitutions=read(base+'/membership-substitutions.proposed.json').substitutions;assert.equal(substitutions.length,20);
for(const row of substitutions){
  const c=courses.find(c=>c.id===row.course_id),m=c.modules.find(m=>m.id===row.module_id);assert(c&&m);
  assert.equal(m.lexeme_ids[row.membership_index],before.id);assert.equal(m.lexeme_ids.filter(id=>id===before.id).length,1);
  assert.equal(new Set(m.lexeme_ids).size,50);assert.equal(new Set(c.modules.flatMap(m=>m.lexeme_ids)).size,500);
  const replacement=structuredClone(c);replacement.modules.find(m=>m.id===row.module_id).lexeme_ids[row.membership_index]=candidate.id;
  assert.equal(new Set(replacement.modules.flatMap(m=>m.lexeme_ids)).size,500);assert.equal(new Set(replacement.modules.find(m=>m.id===row.module_id).lexeme_ids).size,50);
  assert.equal(new Set(c.modules.flatMap(m=>m.expression_ids)).size,100);assert(m.expression_ids.includes(eb.id));
}
for(const row of context.verify_inflection_expression_uses){assert.deepEqual(expressions.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.entry_object_sha256);}
for(const row of [...context.related_lexemes,...context.neighboring_focus_entries]){assert.deepEqual(lexemes.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.entry_object_sha256);}
const independentTokens=[...ea.text.matchAll(/\w+|[^\s\w]/g)].map((m,index)=>({index,text:m[0],start:m.index,end:m.index+m[0].length}));
assert.deepEqual(ea.tokens,independentTokens);assert.equal(ea.tokens.length,22);
assert.deepEqual(ea.focus_lexeme_ids,['ensure.make-certain.v','correct.put-right.v','error.mistake.n','check.examine.v','submit.send-for-consideration.v']);
for(const [index,word] of [[1,'check'],[5,'correct'],[7,'error'],[10,'ensure'],[19,'submit']])assert.equal(ea.tokens[index].text,word);
assert.deepEqual(ea.media,eb.media);assert.deepEqual(ea.review,eb.review);assert.equal(candidate.morphology,null);
const preparedPath='build/professional-english/foundation02-fourth10-delivery-preparation-r02/execution-r01/foundation-module02.json.after';
assert.equal(sha(bytes(preparedPath)),'9f698ae9b2572d279709b521e6b7d490ffe3d05b1a8ed362add36e07fd4accbc');
const prepared=mr(preparedPath).lexemes;
const neighbors=ea.focus_lexeme_ids.filter(id=>id!==candidate.id).map(id=>({id,current_entry:lexemes.find(e=>e.id===id),accepted_fourth10_candidate_entry:prepared.find(e=>e.id===id)}));
for(const row of neighbors)assert.equal(row.accepted_fourth10_candidate_entry.review.language,'reviewed');
for(const id of ['check.examine.v','correct.put-right.v'])assert.deepEqual(neighbors.find(r=>r.id===id).current_entry,neighbors.find(r=>r.id===id).accepted_fourth10_candidate_entry);
const observationsPath='build/professional-english/foundation02-verify-root-source-observations-r01/observations.json';
assert.equal(sha(bytes(observationsPath)),'7b3e76ba075065e63d0177f93d12d9841c2d6e163d0f76100b2792e85140c2ae');
const observations=mr(observationsPath);
for(const p of ['scripts/professional_progress.gd','tools/validate-professional-content.cjs'])measured.set(p,bind(p));
const validator=bytes('tools/validate-professional-content.cjs').toString();assert(validator.includes("add('membership.orphan'"));
const fields=Object.fromEntries(['id','text','display_text','pos','definition','example','difficulty','regions'].map(k=>[k,candidate[k]]));fields.accepted_forms=['ensure','insure'];
const phraseFields=Object.fromEntries(['text','meaning','context','tokens','focus_lexeme_ids'].map(k=>[k,ea[k]]));
const review={schema:1,status:'accepted_reviewer_language_and_curriculum_projection_pending_final_rebase',reviewer:'Codex root independent AI language and curriculum reviewer; not human or subject-matter approval',recorded_at:new Date().toISOString(),research_inventory:bind(base+'/inventory.json'),author_new_entry_sha256:hash(candidate),author_expression_sha256:hash(ea),
  accepted_new_lexical_fields:fields,accepted_new_lexical_fields_json_sha256:hash(fields),accepted_expression_fields:phraseFields,accepted_expression_fields_json_sha256:hash(phraseFields),
  variant_decision:{author_ensure_only_forms_accepted:false,accepted_forms:['ensure','insure'],preferred_display:'ensure',regional_note:'Insure is an accepted alternative especially in North American English for this outcome sense. Financial insurance is a separate sense.',reason:'Both freshly consulted Oxford and Collins entries attest this regional alternative; the approved curriculum requires relevant accepted forms. Do not mark it incorrect solely because the display uses ensure.',implementation_note:'This is an exact reviewer-side field projection, not the original full candidate hash. Later final metadata must replace the author pending-variant clause and retain the regional note. Pronunciation, morphology and exercise handling need separate acceptance.'},
  decisions:[
    'Keep verify.establish-accuracy.v on hold. Fresh Oxford selected C1 supports the existing concern; no unsupported lower verify level is accepted.',
    'Accept the new outcome-oriented definition, reference-number example and editorial B2 placement. Fresh selected Collins B2 and Oxford certainty-topic B2 support this bounded formal workplace item. The author CEFR-J B1 headword/POS row remains B1 and was not freshly retrieved by this reviewer.',
    'Accept a distinct ensure.make-certain.v learning objective in the shared instructions/problem-reporting foundation. Ensuring a required condition is met is different from establishing truth or accuracy. No synonym alias or verify skill transfer is permitted.',
    'Accept the exact twenty one-for-one membership substitutions as a curriculum proposal. Each module remains fifty distinct terms and each course five hundred; no extra quota credit follows.',
    'Accept the exact twenty-two-token phrase and five focus bindings against the independently reviewed fourth10 candidate error/submit meanings and unchanged reviewed check/correct meanings. Actual production rebase is still required after fourth10 delivery; pending research neighbor snapshots are not promoted.',
    'Accept durable retirement of the exact old verify object and decisions outside active catalog files before removing that active entry. Preserve old holds, morphology/source records and saved evidence; do not create dummy membership or relabel the old identity.',
    'Require a coordinated fresh curriculum/requirements revision before activation. New ensure skill evidence starts under its new identity; old verify evidence and old expression completion remain intact and are never copied or inferred into the new requirements.',
    'The pending three-stage brief is semantically aligned with achieving inclusion, but it has no sourced-image or recognition acceptance. Keep morphology null/unauthored and all media/exercise/module gates pending.'
  ],
  source_observations:observations.sources,source_limits:'Fresh rendered Oxford ensure/verify and Collins ensure consultations. No independent raw HTML retrieval or full publisher body archive; author fkcefr/cefr tags and CEFR-J row are explicitly historical author evidence. No source definition, example or media is imported.',
  checks:{research_payload_files:inventory.files.length,lexemes:4939,expressions:1620,membership_substitutions:20,preserved_terms_per_module:50,preserved_terms_per_course:500,preserved_expressions_per_course:100,exact_tokens:22,exact_focus_ids:5,current_form_id_collisions:0,unchanged_other_verify_expression_snapshots:context.verify_inflection_expression_uses.length,related_identity_snapshots:context.related_lexemes.length},
  actual_neighbor_state:neighbors.map(r=>({id:r.id,current_entry_json_sha256:hash(r.current_entry),accepted_fourth10_candidate_entry_json_sha256:hash(r.accepted_fourth10_candidate_entry),production_afterimage_delivered:false})),
  unresolved:['Fresh settled production rebase after fourth10, including exact submit/error entries.','Final accepted-variant note and reference/reviewer metadata.','Coordinated new revision, retirement implementation and non-transfer checks.','Other verify surface uses remain a separate readability/domain review queue.','Morphology, still image, pronunciation, phrase audio, layout/reachability and full-module acceptance.'],
  full_author_entry_accepted:false,production_modified:false,old_hold_released:false,saved_data_inspected_or_migrated:false,project_test_native_or_build_dispatched:false,release_accepted:false};
for(const row of measured.values())assert.equal(sha(bytes(row.path)),row.raw_sha256,row.path);
for(const row of inventory.files)assert.equal(sha(bytes(base+'/'+row.file)),row.sha256);
save('review.json',review);save('accepted-lexical-fields.json',fields);save('accepted-expression-fields.json',phraseFields);
save('input-measurement.json',{schema:1,source_sha256:sha(fs.readFileSync(__filename)),inputs:[...measured.values()],research_files:inventory.files,neighbor_entries:neighbors});
save('inventory.json',{schema:1,status:'frozen_independent_reviewer_projection_pending_delivery',artifacts:['capture-review.cjs','review.json','accepted-lexical-fields.json','accepted-expression-fields.json','input-measurement.json'].map(n=>{const raw=fs.readFileSync(path.join(__dirname,n));return{path:n,bytes:raw.length,raw_sha256:sha(raw)};}),self_excluded:true});
console.log(JSON.stringify({review_sha256:sha(fs.readFileSync(path.join(__dirname,'review.json'))),inventory_sha256:sha(fs.readFileSync(path.join(__dirname,'inventory.json'))),accepted_lexical_fields_sha256:hash(fields),accepted_expression_fields_sha256:hash(phraseFields),measured_inputs:measured.size}));
