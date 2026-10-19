'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const base='build/professional-english/foundation02-collect-gather-repair-r01';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),hash=v=>sha(JSON.stringify(v));
const bytes=p=>fs.readFileSync(path.join(root,p)),read=p=>JSON.parse(bytes(p));
const bind=p=>({path:p,bytes:bytes(p).length,raw_sha256:sha(bytes(p))});
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const inventory=read(base+'/inventory.json');assert.equal(sha(bytes(base+'/inventory.json')),'c298c66e6fdf8f1708bbe3f0ab04abe978cc0f74b35f1b0b3890a79a531946bc');
for(const row of inventory.files){assert.equal(bytes(base+'/'+row.path).length,row.bytes);assert.equal(sha(bytes(base+'/'+row.path)),row.sha256);}
const before=read(base+'/lexeme-before.json'),after=read(base+'/lexeme-after.proposed.json');
const eb=read(base+'/expression-before.json'),ea=read(base+'/expression-after.proposed.json');
const context=read(base+'/context.json');
const catalog=read('data/professional/catalog.json');
const resource=p=>{assert(p.startsWith('res://'));return p.slice(6);};
const measured=new Map();
const measuredRead=p=>{measured.set(p,bind(p));return read(p);};
const lexemes=catalog.lexeme_files.flatMap(p=>measuredRead(resource(p)).lexemes);
const expressions=catalog.expression_files.flatMap(p=>measuredRead(resource(p)).expressions);
const courses=catalog.courses.map(p=>measuredRead(resource(p.manifest)));
assert.equal(lexemes.length,4939);assert.equal(expressions.length,1620);assert.equal(courses.length,20);
assert.deepEqual(lexemes.find(e=>e.id===before.id),before);assert.deepEqual(expressions.find(e=>e.id===eb.id),eb);
assert.equal(hash(after),'7e192777256f224040f45d70c4421e1eb2dc15234b82f712a1af1e585d48f004');
assert.equal(hash(ea),'df463c8f619cda04d38d32014f640e6cc721f7d7b24e1ab2fac4dc76b9775d54');
const lp=e=>{const c=structuredClone(e);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete c[k];delete c.media.image.brief;return c;};
const ep=e=>{const c=structuredClone(e);for(const k of ['text','meaning','context','tokens','references'])delete c[k];return c;};
assert.deepEqual(lp(before),lp(after));assert.deepEqual(ep(eb),ep(ea));
assert.deepEqual(after.references.slice(0,before.references.length),before.references);
assert.deepEqual(ea.references.slice(0,eb.references.length),eb.references);
assert(after.references.every(r=>r.status==='pending_term_check'));assert(ea.references.every(r=>r.status==='pending_term_check'));
assert.deepEqual(after.review,before.review);assert.deepEqual(ea.review,eb.review);
const memberships=(id,field)=>courses.flatMap(c=>c.modules.filter(m=>m[field].includes(id)).map(m=>({course_id:c.id,module_id:m.id,index:m[field].indexOf(id),module_json_sha256:hash(m)}))).sort((a,b)=>a.course_id.localeCompare(b.course_id));
for(const [id,field,rows] of [[before.id,'lexeme_ids',context.target_memberships],[eb.id,'expression_ids',context.expression_memberships]]){
  const actual=memberships(id,field);assert.equal(actual.length,20);
  assert.deepEqual(actual,rows.map(r=>({course_id:r.course_id,module_id:r.module_id,index:r.index,module_json_sha256:r.module_json_sha256})).sort((a,b)=>a.course_id.localeCompare(b.course_id)));
}
assert.deepEqual(expressions.filter(e=>e.focus_lexeme_ids.includes(before.id)).map(e=>e.id),[eb.id]);
const literal=expressions.filter(e=>/\bcollect(?:s|ed|ing)?\b/i.test([e.text,e.meaning,e.context,...e.tokens.map(t=>t.text)].join(' ')));
assert.equal(literal.length,5);assert.equal(literal.filter(e=>e.id!==eb.id).length,4);
for(const row of context.literal_inflected_expression_scan.hits){assert.deepEqual(expressions.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.object_sha256);}
for(const row of [...context.related_identities,...context.neighboring_entries]){assert.deepEqual(lexemes.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.object_sha256);}
assert.equal(ea.tokens.length,18);
const independentTokens=[...ea.text.matchAll(/\w+|[^\s\w]/g)].map((m,index)=>({index,text:m[0],start:m.index,end:m.index+m[0].length}));
assert.deepEqual(ea.tokens,independentTokens);assert.deepEqual(ea.focus_lexeme_ids,['assist.help.v','collect.gather.v','return.send-back.v']);
assert.equal(ea.tokens[2].text,'assist');assert.equal(ea.tokens[6].text,'collect');assert.equal(ea.tokens[13].text,'return');
const policy=read(base+'/progress-revision-decision.proposed.json');assert.equal(policy.current_revision_observed,catalog.curriculum_revision);
assert.equal(policy.saved_records_may_be_assumed_absent,false);assert.equal(policy.changed_requirement_namespaces.length,20);
for(const p of ['scripts/professional_progress.gd','scripts/professional_catalog.gd','tools/validate-professional-content.cjs','data/professional/catalog.json'])measured.set(p,bind(p));
const progress=bytes('scripts/professional_progress.gd').toString();
assert(progress.includes('"requirements_revision": row.requirements_revision, "terms": row.terms, "expressions": row.expressions'));
assert(progress.includes('progress.expressions[key][event.expression_id] = true'));
assert(progress.includes('progress.skills[event.sense_id]'));
const validator=bytes('tools/validate-professional-content.cjs').toString();
assert(validator.includes('course.curriculum_revision !== data.catalog.curriculum_revision'));
assert(validator.includes('module.requirements_revision !== course.curriculum_revision'));
const acceptedLexical=Object.fromEntries(['definition','example','difficulty'].map(k=>[k,after[k]]));
const acceptedExpression=Object.fromEntries(['text','meaning','context','tokens','focus_lexeme_ids'].map(k=>[k,ea[k]]));
const review={schema:1,status:'accepted_exact_coordinated_language_projection_pending_delivery_and_revision',reviewer:'Codex root independent AI language and context reviewer; not human or subject-matter approval',recorded_at:new Date().toISOString(),proposal_inventory:bind(base+'/inventory.json'),proposal_lexeme_json_sha256:hash(after),proposal_expression_json_sha256:hash(ea),
  accepted_lexical_fields:acceptedLexical,accepted_lexical_fields_json_sha256:hash(acceptedLexical),
  accepted_expression_fields:acceptedExpression,accepted_expression_fields_json_sha256:hash(acceptedExpression),
  decisions:[
    'Accept the bounded physical-item gathering definition and forms-from-each-team example: they consistently exclude fetching a preassembled reception bundle.',
    'Accept editorial B1 for this teaching item. Fresh Collins gathering B1 supports it; Oxford author HTML A2 remains distinct and was not independently fetched. The fresh Oxford rendered view confirms the gathering sense but does not expose its selected CEFR attribute. No footer level is used.',
    'Accept the exact courteous request, its meaning/context and all eighteen tokens. Assist is formal but natural with a person; borrowed key disambiguates giving a borrowed object back. The coordinated actions are ordinary fictional errands and introduce no specialist procedure.',
    'Retain all three canonical focus IDs. No identity rename, alias or mastery transfer is approved. Four unscored information/privacy uses, pickup/payment compounds and shared pending morphology are separate.',
    'Accept the pending picture brief as an accurate sourcing direction only. A single still may not show multiple origins clearly; inherited picture_suitable true and declared picture modes receive no visual or exercise acceptance.',
    'Accept the proposed fresh requirements/curriculum namespace guard as a necessary future activation condition. Current ID-only requirements cannot detect same-ID wording changes. Keep every old completion and canonical skill record; copy none into the new expression-completion namespace.',
    'The proposed metadata remains author-stage pending wording. A later delivery must separately review its exact final reviewer/status/reference/note delta and preserve historical holds through strict afterimage reversal.'
  ],
  fresh_rendered_sources:[
    {url:'https://www.oxfordlearnersdictionaries.com/definition/english/collect_1',tool_reference:'turn231808view0',selected_sense:'bring together, sense 1',observation:'The transitive gathering sense and object-from-source pattern support the selected physical forms example.',selected_rendered_level:null,author_html_a2_independently_refetched:false},
    {url:'https://www.collinsdictionary.com/dictionary/english/collect',tool_reference:'turn231808view1',selected_sense:'COBUILD sense 1',selected_rendered_level:'B1',observation:'Gathering from several sources is distinct from sense 3 pickup A2 and its regional guidance.'},
    {url:'https://www.oxfordlearnersdictionaries.com/definition/english/assist_1',tool_reference:'turn473952view0',selected_sense:'sense 1',observation:'Formal person-helping use and assist somebody pattern support the local phrase.'},
    {url:'https://www.collinsdictionary.com/dictionary/english/return',tool_reference:'turn473952view1',selected_sense:'COBUILD sense 3',selected_rendered_level:'A2',observation:'Borrowed-object give-back use is distinct from purchased-item returns and movement back.'}
  ],
  source_limits:'Fresh rendered consultations only. No independent raw-HTML retrieval, stored full publisher bodies, copied publisher definitions/examples, acquired media, or psychometric certification. Author direct HTTP metadata and failed retrievals remain historical proposal evidence.',
  checks:{proposal_payload_files:inventory.files.length,lexemes:lexemes.length,expressions:expressions.length,lexeme_memberships:20,expression_memberships:20,assessed_expressions:1,unscored_literal_context_uses:4,related_identity_snapshots:context.related_identities.length,neighbor_snapshots:2,tokens:18,protected_lexeme_and_expression_fields_exact:true,pending_gates_unchanged:true},
  future_activation_blockers:['Fresh coordinated curriculum/requirements revision with non-transfer behavior still needs implementation and verification.','If canonical gather history was earned through the old pickup phrase, its semantic provenance needs separate review before valid gathering mastery is claimed.','Exact final source/test/registry rebase and historical reversals remain pending.','Images, audio, morphology, exercise reachability, module and release acceptance remain pending.'],
  source_inspection_limit:'Progress consequences were checked by reading current source. No saved-data inspection, runtime scenario, project test or migration was dispatched.',production_mutated:false,holds_released_in_production:false,tests_or_native_dispatched:false,full_entry_release_accepted:false};
for(const row of measured.values())assert.equal(sha(bytes(row.path)),row.raw_sha256,row.path);
for(const row of inventory.files)assert.equal(sha(bytes(base+'/'+row.path)),row.sha256);
save('review.json',review);save('input-measurement.json',{schema:1,source_sha256:sha(fs.readFileSync(__filename)),inputs:[...measured.values()],proposal_files:inventory.files});
save('inventory.json',{schema:1,status:'frozen_independent_language_context_acceptance_not_integrated',artifacts:['capture-review.cjs','review.json','input-measurement.json'].map(name=>{const raw=fs.readFileSync(path.join(__dirname,name));return{path:name,bytes:raw.length,raw_sha256:sha(raw)};}),self_excluded:true});
console.log(JSON.stringify({review_sha256:sha(fs.readFileSync(path.join(__dirname,'review.json'))),inventory_sha256:sha(fs.readFileSync(path.join(__dirname,'inventory.json'))),measured_inputs:measured.size}));
