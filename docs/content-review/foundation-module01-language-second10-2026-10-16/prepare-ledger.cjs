'use strict';
// Write-once scratch language evidence. Production and shared tests are read-only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
const {loadProfessionalContent,schemaErrors}=require(path.join(root,'tools/validate-professional-content.cjs'));
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const raw=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const base='build/professional-english/foundation-module01-language-review/second10/',prefix='foundation01-language-second10-';
const pre=require('./preimages.json'),notes=require('./decision-notes.cjs'),expressionNotes=require('./expression-notes.cjs');
const {sources,failed_accesses}=require('./source-notes.cjs');
assert.equal(process.argv.length,2);
const outputs=['source-consultations.json','expression-use-review.json','language-ledger.json','structural-audit.json'];
for(const name of outputs)assert.equal(fs.existsSync(path.join(__dirname,name)),false,'Frozen output already exists: '+name);
assert.equal(hash(pre),'374e9b75aa44fca2b1b6f5f2d64ecb523f49c36d1b345c8576548e435507a324');
let guards=0;
const check=(actual,expected,label)=>{assert.deepEqual(actual,expected,label);guards++;};
const unique=(rows,key)=>{const out=new Map();for(const row of rows){const id=key(row);if(out.has(id))check(hash(out.get(id).entry),hash(row.entry),'Duplicate preimage agrees: '+id);else out.set(id,row);}return [...out.values()];};
const protectedEntries=unique([...pre.selected_entries,...pre.unselected_foundation_entries,...pre.related_entries],r=>r.entry.id);
const protectedExpressions=unique([...pre.local_expressions,...pre.expression_uses],r=>r.entry.id);
const ids=pre.selection.ids,selectedById=new Map(pre.selected_entries.map(r=>[r.entry.id,r]));
const sourceById=new Map(sources.map(s=>[s.id,s]));
check(sourceById.size,13,'Thirteen distinct direct source pages');
check(failed_accesses.length,4,'Four failed Cambridge accesses excluded');
check(Object.keys(notes).sort(),pre.selected_entries.map(r=>r.entry.text).sort(),'Exactly ten authored decisions');
check(Object.keys(expressionNotes).sort(),pre.expression_uses.map(r=>r.id).sort(),'Every captured expression has one observation');
const memberships=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
const locations=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.expression_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
const observed=loadProfessionalContent(root);
function verifyScope(data){
  check(data.courses.length,20,'All twenty courses present');
  for(const course of data.courses)check(course.modules.find(m=>m.id==='module01').lexeme_ids.slice(10,20),ids,'Shared second ten order: '+course.id);
  for(const row of protectedEntries)check(hash(data.lexemes.find(e=>e.id===row.entry.id)),row.json_sha256,'Frozen lexeme: '+row.entry.id);
  for(const row of pre.selected_entries)check(memberships(data,row.entry.id),row.memberships,'Selected memberships: '+row.entry.id);
  for(const row of protectedExpressions){check(hash(data.expressions.find(e=>e.id===row.entry.id)),row.json_sha256,'Frozen expression: '+row.entry.id);check(locations(data,row.entry.id),row.locations,'Expression memberships: '+row.entry.id);}
  for(const row of pre.modules)check(hash(data.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id)),row.json_sha256,'Frozen module: '+row.course_id+'/'+row.module_id);
  for(const row of pre.existing_source_records)check(hash(data.sources.find(s=>s.id===row.source.id)),row.json_sha256,'Existing source: '+row.source.id);
  for(const [file,expected]of Object.entries({...pre.growth_raw_sha256,...pre.prior_artifacts_raw_sha256}))check(raw(file),expected,'Frozen raw dependency: '+file);
}
verifyScope(observed);
const sourceRecords=sources.map(s=>({id:s.id,title:s.title,publisher:s.publisher,url:s.url,status:'consulted',consulted_on:s.consulted_on,scope:'Selected ordinary lexical sense, explicitly observed difficulty labels and spelling evidence. AI consultation only; exact language acceptance and all specialist/media gates remain pending. No source text or media acquired.',asset_license:null,assets_acquired:false}));
for(const source of sourceRecords)check(observed.sources.some(s=>s.id===source.id),false,'Additive source ID is new: '+source.id);
const sourceDocument={schema:1,status:'frozen_source_consultation_evidence_not_acceptance',date:'2026-10-16',production_mutated:false,preimages_json_sha256:hash(pre),supporting_direct_pages:sources.length,consultations:sources,failed_accesses,proposed_additive_source_records:sourceRecords,rights_boundary:'Only original short observations are retained. Dictionary consultation supplies no license to redistribute entries, examples, exercises, pictures or audio.',level_boundary:'Labels must belong to the selected headword/sense. Unrelated footers, other senses and frequency bands are excluded. B1+ remains literal and is not converted; the shift B1/B2 disagreement is explicit.'};
const allowed=['definition','example','difficulty','references','editorial_notes'];
const protectedPart=entry=>Object.fromEntries(Object.entries(entry).filter(([key])=>!allowed.includes(key)));
const proposals=pre.selected_entries.map((row,index)=>{
  const before=row.entry,note=notes[before.text],after=structuredClone(before);
  for(const key of Object.keys(note.changes))check(['definition','example','difficulty'].includes(key),true,'Permitted authored content field');
  Object.assign(after,note.changes);
  const sourceIds=note.sources.map(id=>prefix+id);
  for(const id of sourceIds)check(sourceById.has(id),true,'Direct consulted source exists');
  const addedReferences=sourceIds.map(source_id=>({source_id,status:'pending_term_check',scope:'Selected ordinary '+before.text+' noun and bounded source evidence consulted for this original language proposal; independent language acceptance, morphology and all domain/media gates remain unchanged.'}));
  after.references.push(...addedReferences);
  after.editorial_notes+=' Language-only candidate prepared from selected dictionary passages; independent acceptance remains pending. '+note.difficulty_note+(note.spelling_note?' '+note.spelling_note:'');
  const changed=Object.keys(after).filter(key=>hash(after[key])!==hash(before[key]));
  check(changed.every(key=>allowed.includes(key)),true,'Language-only delta: '+before.id);
  check(protectedPart(after),protectedPart(before),'All nonlanguage fields exact: '+before.id);
  check(after.review,before.review,'No language/domain/overall gate promotion');
  check(after.review.language,'pending','Language still pending');
  check(after.morphology,before.morphology,'Exact morphology retained');
  check(after.media,before.media,'Exact media and approved voice retained');
  check(after.accepted_forms,before.accepted_forms,'Accepted forms retained');
  check(after.regions,before.regions,'Regions retained');
  check(after.references.slice(0,before.references.length),before.references,'Existing references retained');
  check(schemaErrors(after,'lexeme'),[],'Candidate lexeme schema');
  return {ordinal:index+11,id:before.id,text:before.text,resource:row.resource,status:'pending_original_language_candidate_not_acceptance',before_entry_json_sha256:row.json_sha256,before_entry:structuredClone(before),candidate_entry:after,candidate_entry_json_sha256:hash(after),changed_fields:changed,substantive_changes:note.changes,protected_nonlanguage_fields_json_sha256:hash(protectedPart(before)),memberships:row.memberships,meaning_decision:note.meaning,example_decision:note.example,spelling_and_region_decision:{accepted_forms:before.accepted_forms,regions:before.regions,decision:note.spelling_note||'Retain the existing standard headword and general region label. No spelling alternative is proposed for this bounded draft; synonyms, inflections and abbreviations do not automatically become exercise answers.',explicit_observed_alternative:before.text==='coordinator'?'co-ordinator':null,acceptance_hold:before.text==='coordinator',limits:note.excluded},difficulty_evidence:{before:before.difficulty,candidate:after.difficulty,observed_selected_source_labels:note.observed_levels,status:note.difficulty_status,notes:note.difficulty_note,independent_acceptance:false},source_record_ids:sourceIds,added_references:addedReferences,review_gates_unchanged:true};
});
check(proposals.filter(p=>p.candidate_entry.difficulty!==p.before_entry.difficulty).map(p=>p.id),['trainee.learner-worker.n','appointment.arranged-meeting.n'],'Only trainee B2 and appointment B1 proposed');
check(proposals.find(p=>p.text==='contact').candidate_entry.difficulty,'A2','Contact stored A2 unchanged and unaccepted');
check(proposals.find(p=>p.text==='shift').candidate_entry.difficulty,'A2','Shift stored A2 unchanged and unaccepted');
check(proposals.find(p=>p.text==='coordinator').candidate_entry.accepted_forms,['coordinator'],'Observed hyphenated variant not silently added');
check(proposals.filter(p=>Object.keys(p.substantive_changes).length).length,4,'Four entries have substantive proposals');
const classifications={
  focus:{classification:'existing_selected_focus_ordinary_workplace_sense',binding:'Retain the existing scored sense without new acceptance.'},
  background:{classification:'ordinary_workplace_background_use',binding:'Compatible background use only; add no scored binding.'},
  compound:{classification:'constituent_of_independent_complete_term',binding:'Keep the complete term independent; do not turn constituent compatibility into full-term acceptance.'},
  verb:{classification:'excluded_communication_verb',binding:'Exclude from the selected helpful-person noun.'},
  communication:{classification:'excluded_communication_event_information_or_means',binding:'Exclude this information/event/means use from the selected helpful-person noun.'},
  verb_and_communication:{classification:'excluded_communication_verb_and_center_compound',binding:'Both literal occurrences are outside the selected helpful-person noun.'},
  physical:{classification:'excluded_physical_contact_use',binding:'Keep physical contact and its specialist compound independent from the helpful-person noun.'},
  ambiguous:{classification:'unresolved_person_or_communication_route',binding:'Hold exact person-sense binding because the text permits a route or service.'},
  mixed_info_role:{classification:'communication_details_and_emergency_role_information',binding:'The information phrases do not directly score the selected person; preserve the complete emergency-contact role.'},
  rendezvous:{classification:'excluded_rendezvous_meeting_point',binding:'Do not bind a gathering place to the selected work-discussion event.'},
  financial_schedule:{classification:'independent_financial_table_schedule_senses',binding:'Do not bind these financial tables to the selected activity time-plan.'},
  platform_access:{classification:'hearing_platform_access_compound_not_event_binding',binding:'Retain the meeting-link label without assigning the hearing to the ordinary work-discussion event sense.'},
  supplier_scope:{classification:'unresolved_goods_provider_or_services_only_supplier',binding:'No new selected goods-provider binding or manufacturing scope acceptance.'}
};
const literal=(text,word)=>new RegExp('(^|[^A-Za-z])'+word.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?:s)?(?:[\u0027\u2019]s)?(?=$|[^A-Za-z])','i').test(text);
const uses=pre.expression_uses.map(row=>{
  const authored=expressionNotes[row.id];
  const words=row.literal_selected_ids.map(id=>selectedById.get(id).entry.text);
  check(Object.keys(authored.classifications).sort(),[...words].sort(),'Each literal match individually classified: '+row.id);
  const matches=row.literal_selected_ids.map(id=>{
    const word=selectedById.get(id).entry.text,code=authored.classifications[word];
    check(Object.hasOwn(classifications,code),true,'Known authored classification');
    check(code==='focus',row.selected_focus_ids.includes(id),'Focus classification matches current exact binding');
    const related=pre.related_entries.filter(r=>r.entry.text!==word&&literal(row.entry.text,r.entry.text)&&literal(r.entry.text,word));
    return {selected_id:id,authored_classification_code:code,...classifications[code],related_complete_lexeme_ids:related.map(r=>r.entry.id),source_record_ids:notes[word].sources.map(s=>prefix+s)};
  });
  return {id:row.id,resource:row.resource,before_expression_json_sha256:row.json_sha256,after_expression_json_sha256:row.json_sha256,action:'retain_exact_no_language_or_domain_acceptance',text:row.entry.text,context:row.entry.context,focus_lexeme_ids:row.entry.focus_lexeme_ids,selected_focus_ids:row.selected_focus_ids,literal_selected_ids:row.literal_selected_ids,locations:row.locations,individual_observation:authored.observation,matches,review:row.entry.review,new_scored_bindings:[],scope:'Only selected-noun compatibility and ambiguity inspected. All text, meaning, context, tokens, focus IDs, sources, media and review gates remain exact. This is not a complete expression review.'};
});
check(uses.length,114,'Exactly 114 unique expression uses');
check(uses.reduce((n,u)=>n+u.locations.length,0),266,'Exactly 266 containing memberships');
check(uses.filter(u=>u.selected_focus_ids.length).length,6,'Exactly six selected-focus expressions');
const codeCount=code=>uses.filter(u=>u.matches.some(m=>m.authored_classification_code===code)).length;
check(codeCount('ambiguous'),2,'Two unresolved person/route contexts');
check(codeCount('supplier_scope'),2,'Two supplier goods/services scope holds');
check(codeCount('physical'),3,'Three physical-contact exclusions');
check(codeCount('financial_schedule'),1,'One expression with two financial table schedules');
const expressionDocument={schema:1,status:'frozen_scoped_expression_observations_not_acceptance',date:'2026-10-16',production_mutated:false,preimages_json_sha256:hash(pre),discovery:'Existing focus bindings or exact headword/regular-plural/possessive matches in expression text. Every captured text and context was read and every literal selected match was individually classified; textual matching never creates a sense binding.',unique_expressions:uses.length,containing_module_memberships:266,selected_focus_expressions:6,classification_legend:classifications,uses,other_local_expressions:pre.local_expressions.filter(r=>!uses.some(u=>u.id===r.entry.id)).map(r=>({id:r.entry.id,before_expression_json_sha256:r.json_sha256,after_expression_json_sha256:r.json_sha256,text:r.entry.text,context:r.entry.context,action:'retain_exact',observation:'No selected second-ten noun occurs in the expression text or focus list. Full local context was read without amending its other targets.'})),related_entry_boundary:pre.related_entries.map(r=>({id:r.entry.id,text:r.entry.text,definition:r.entry.definition,json_sha256:r.json_sha256,action:'retain_exact_context_only_not_complete_lexeme_acceptance'})),scope_limits:['Contractor, trainee and coordinator vocabulary does not establish employment status, qualifications, legal duties or delegated powers.','Helpful-person contact is distinct from communication verbs, information, methods/events and physical or clinical contact.','Point of contact and alternative contact may be persons or routes; unresolved background contexts gain no selected binding.','Specialist provider, role, work-period, appointment, financial-table and meeting compounds keep complete identities and all domain gates.','Remote or hybrid participation fits a discussion meeting, but a rendezvous point or hearing access link does not automatically establish that event sense.']};
const inputFiles=['capture-preimages.cjs','preimages.json','source-notes.cjs','decision-notes.cjs','expression-notes.cjs','prepare-ledger.cjs'];
const inputs=Object.fromEntries(inputFiles.map(file=>[base+file,raw(base+file)]));
const end=loadProfessionalContent(root);verifyScope(end);
for(const [file,expected]of Object.entries(inputs))check(raw(file),expected,'Author input exact: '+file);
const ledger={schema:1,status:'frozen_foundation01_second10_language_candidates_awaiting_independent_review',date:'2026-10-16',author:'Codex retail_content (AI source consultation and original authoring; not human or specialist approval)',production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,scope:'Only Foundation module01 positions11-20 across all twenty courses. This package proposes language fields and additive references; every review gate, morphology, media, practice mode, accepted form, region, identity, membership and release status remains exact.',selection:pre.selection,selected_memberships:200,preimages_json_sha256:hash(pre),source_ledger_json_sha256:hash(sourceDocument),expression_review_json_sha256:hash(expressionDocument),input_raw_sha256:inputs,proposals,proposed_additive_source_records:sourceRecords,review_boundary:{language:'All ten retain exact pending language/reviewer/date fields. This author package grants no acceptance.',difficulty:'Trainee B2 and appointment B1 are sourced proposals. Contact B1+ is outside the exact schema and shift has B1/B2 source disagreement; both retain stored A2 explicitly unaccepted. Contractor/supplier A2 and coordinator B1 lack selected level evidence. Meeting A1 is below the A2 course floor.',spelling:'Oxford British co-ordinator is explicitly observed; coordinator-only accepted_forms remain unchanged with an independent spelling decision held.',morphology:'Every graph, edge, review status and provenance stays exact. No decomposition or mastery approval is supplied.',media:'All image/audio values, briefs, suitability flags and approved Ava Sweet settings stay exact.',domain:'Existing not_required values on these ordinary nouns remain exact. No employment, legal, clinical, financial, safety or other specialist approval is implied.',release:'No module or course is promoted. Every selected entry retains twenty shared memberships.',runtime:'No native engine, compiler, runtime probe or shared test was invoked. Schema and preservation checks are scratch preparation only.'},structural_checks:{candidate_entries:10,schema_errors:0,expression_mutations:0},registry_json_sha256_informational:{capture:pre.registry_json_sha256_informational,start:hash(observed),end:hash(end)},remaining:['Independently review the exact ten candidate entries, original source observations and protected preimages before any integration.','Resolve or explicitly defer contact B1+ and shift B1/B2 difficulty holds without silently mapping levels or altering the enum.','Decide whether British co-ordinator must be accepted before promoting coordinator language; this package preserves the old accepted_forms only.','Assess unsupported contractor/supplier/coordinator difficulty and the meeting course-floor choice, and review the two sourced difficulty proposals.','Do not promote expressions from these selected-sense observations or invent bindings for contact-route, supplier-scope, financial-table or hearing-link ambiguities.','A future production serializer must bind current exact preimages and preserve unrelated concurrent work. No serializer is supplied or run here.']};
const changeCount=field=>proposals.filter(p=>p.changed_fields.includes(field)).length;
check(changeCount('definition'),3,'Exactly three definition proposals');
check(changeCount('example'),0,'All original examples retained');
check(changeCount('difficulty'),2,'Exactly two difficulty proposals');
const audit={schema:1,status:'author_structural_and_preservation_checks_passed_not_independent_acceptance',date:'2026-10-16',production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,selected_entries:10,substantively_amended_candidates:4,metadata_only_candidates:6,proposed_definition_changes:3,proposed_example_changes:0,proposed_difficulty_changes:2,difficulty_proposals:{trainee:'B2',appointment:'B1'},explicit_difficulty_holds:{contact:{observed:'B1+',stored_unaccepted:'A2'},shift:{observed:['B1','B2'],stored_unaccepted:'A2'}},coordinator_spelling_hold:'Observed co-ordinator not added to preserved accepted_forms',all_language_gates_pending:true,all_other_gates_exact:true,source_consultations:13,failed_accesses_excluded:4,additive_source_records:13,all20course_second10_identical:true,selected_memberships:200,protected_unique_entries:protectedEntries.length,protected_expressions:protectedExpressions.length,scoped_expression_uses:114,scoped_expression_memberships:266,selected_focus_expressions:6,unresolved_contact_routes:2,unresolved_supplier_scope_contexts:2,physical_contact_exclusions:3,financial_schedule_expression_exclusions:1,meeting_point_exclusions:1,hearing_link_binding_holds:1,protected_modules:pre.modules.length,protected_existing_sources:pre.existing_source_records.length,protected_growth_files:Object.keys(pre.growth_raw_sha256).length,candidate_schema_errors:0,scope_guards_passed:guards,scoped_production_records_unchanged:true,global_registry_changed_during_preparation:hash(observed)!==hash(end),global_registry_hashes_informational:true,preimages_json_sha256:hash(pre),source_ledger_json_sha256:hash(sourceDocument),expression_review_json_sha256:hash(expressionDocument),language_ledger_json_sha256:hash(ledger),prepare_script_raw_sha256:raw(base+'prepare-ledger.cjs')};
for(const [file,value]of [['source-consultations.json',sourceDocument],['expression-use-review.json',expressionDocument],['language-ledger.json',ledger],['structural-audit.json',audit]])fs.writeFileSync(path.join(__dirname,file),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...audit,artifacts:Object.fromEntries(outputs.map(file=>[file,{json_sha256:hash(JSON.parse(fs.readFileSync(path.join(__dirname,file),'utf8'))),raw_sha256:raw(base+file)}]))},null,2));
