'use strict';
// Write-once language-review artifacts; production and shared tests are read-only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
const {loadProfessionalContent,schemaErrors}=require(path.join(root,'tools/validate-professional-content.cjs'));
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const raw=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const base='build/professional-english/foundation-module01-language-review/first10/';
const pre=require('./preimages.json'),notes=require('./decision-notes.cjs'),expressionNotes=require('./expression-notes.cjs');
const {sources,failed_accesses}=require('./source-notes.cjs');
const prefix='foundation01-language-first10-';
const outputs=['source-consultations.json','expression-use-review.json','language-ledger.json','structural-audit.json'];
for(const name of outputs)assert.equal(fs.existsSync(path.join(__dirname,name)),false,'Frozen output already exists: '+name);
assert.equal(hash(pre),'4d3b13cdfeb480e350f202636d8124a04a060bd3ca512421be1e661ded7819b6');
let guards=0;
const check=(actual,expected,label)=>{assert.deepEqual(actual,expected,label);guards++;};
const unique=(rows,key)=>{const out=new Map();for(const row of rows){const id=key(row);if(out.has(id))check(hash(out.get(id).entry),hash(row.entry),'Duplicate preimage agrees: '+id);else out.set(id,row);}return [...out.values()];};
const protectedEntries=unique([...pre.selected_entries,...pre.unselected_foundation_entries,...pre.related_entries],r=>r.entry.id);
const protectedExpressions=unique([...pre.local_expressions,...pre.expression_uses],r=>r.entry.id);
const ids=pre.selection.ids,selectedById=new Map(pre.selected_entries.map(r=>[r.entry.id,r]));
const sourceById=new Map(sources.map(s=>[s.id,s]));
check(sourceById.size,12,'Twelve distinct direct pages');
check(Object.keys(notes).sort(),pre.selected_entries.map(r=>r.entry.text).sort(),'Exactly ten authored decisions');
check(Object.keys(expressionNotes).sort(),pre.expression_uses.map(r=>r.id).sort(),'Every captured expression has one individual observation');
const memberships=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
const locations=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.expression_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
const observed=loadProfessionalContent(root);
function verifyScope(data){
  check(data.courses.length,20,'All twenty courses present');
  for(const course of data.courses)check(course.modules.find(m=>m.id==='module01').lexeme_ids.slice(0,10),ids,'Shared first ten order: '+course.id);
  for(const row of protectedEntries)check(hash(data.lexemes.find(e=>e.id===row.entry.id)),row.json_sha256,'Frozen lexeme: '+row.entry.id);
  for(const row of pre.selected_entries)check(memberships(data,row.entry.id),row.memberships,'Selected memberships: '+row.entry.id);
  for(const row of protectedExpressions){check(hash(data.expressions.find(e=>e.id===row.entry.id)),row.json_sha256,'Frozen expression: '+row.entry.id);check(locations(data,row.entry.id),row.locations,'Expression memberships: '+row.entry.id);}
  for(const row of pre.modules)check(hash(data.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id)),row.json_sha256,'Frozen module: '+row.course_id+'/'+row.module_id);
  for(const row of pre.existing_source_records)check(hash(data.sources.find(s=>s.id===row.source.id)),row.json_sha256,'Existing source: '+row.source.id);
  for(const [file,expected]of Object.entries({...pre.growth_raw_sha256,...pre.prior_artifacts_raw_sha256}))check(raw(file),expected,'Frozen raw dependency: '+file);
}
verifyScope(observed);
const sourceRecords=sources.map(s=>({id:s.id,title:s.title,publisher:s.publisher,url:s.url,status:'consulted',consulted_on:s.consulted_on,scope:'Selected ordinary lexical meaning and expressly observed topic-level evidence. AI consultation only; exact candidate language, difficulty and specialist acceptance remain pending. No source text or media acquired.',asset_license:null,assets_acquired:false}));
for(const source of sourceRecords)check(observed.sources.some(s=>s.id===source.id),false,'Additive source ID is new: '+source.id);
const sourceDocument={schema:1,status:'frozen_source_consultation_evidence_not_acceptance',date:'2026-10-16',production_mutated:false,preimages_json_sha256:hash(pre),supporting_direct_pages:sources.length,consultations:sources,failed_accesses,proposed_additive_source_records:sourceRecords,rights_boundary:'Only original short observations are retained. Dictionary consultation supplies no license to redistribute entries, examples, exercises, pictures or audio.',level_boundary:'Only labels attached to the relevant headword/sense are reported. Unrelated footer/Word of the Day labels, source frequency bands and levels for other senses are excluded. No numeric level conversion is performed.'};
const allowed=['definition','example','difficulty','references','editorial_notes'];
const protectedPart=entry=>Object.fromEntries(Object.entries(entry).filter(([key])=>!allowed.includes(key)));
const proposals=pre.selected_entries.map((row,index)=>{
  const before=row.entry,note=notes[before.text],after=structuredClone(before);
  for(const key of Object.keys(note.changes))check(['definition','example','difficulty'].includes(key),true,'Permitted authored content field');
  Object.assign(after,note.changes);
  const sourceIds=note.sources.map(id=>prefix+id);
  for(const id of sourceIds)check(sourceById.has(id),true,'Direct consulted source exists');
  const addedReferences=sourceIds.map(source_id=>({source_id,status:'pending_term_check',scope:'Selected ordinary '+before.text+' noun and bounded difficulty evidence consulted for this original language proposal; independent language acceptance, morphology and all domain/media gates remain unchanged.'}));
  after.references.push(...addedReferences);
  after.editorial_notes+=' Language-only candidate prepared from selected dictionary passages; independent acceptance remains pending. '+note.difficulty_note;
  const changed=Object.keys(after).filter(key=>hash(after[key])!==hash(before[key]));
  check(changed.every(key=>allowed.includes(key)),true,'Language-only delta: '+before.id);
  check(protectedPart(after),protectedPart(before),'All nonlanguage fields exact: '+before.id);
  check(after.review,before.review,'No language/domain/overall gate promotion');
  check(after.morphology,before.morphology,'Exact morphology retained');
  check(after.media,before.media,'Exact media and approved voice retained');
  check(after.accepted_forms,before.accepted_forms,'Accepted forms retained');
  check(after.regions,before.regions,'Regions retained');
  check(after.references.slice(0,before.references.length),before.references,'Existing references retained');
  check(schemaErrors(after,'lexeme'),[],'Candidate lexeme schema');
  return {ordinal:index+1,id:before.id,text:before.text,resource:row.resource,status:'pending_original_language_candidate_not_acceptance',before_entry_json_sha256:row.json_sha256,before_entry:structuredClone(before),candidate_entry:after,candidate_entry_json_sha256:hash(after),changed_fields:changed,substantive_changes:note.changes,protected_nonlanguage_fields_json_sha256:hash(protectedPart(before)),memberships:row.memberships,meaning_decision:note.meaning,example_decision:note.example,spelling_and_region_decision:{accepted_forms:before.accepted_forms,regions:before.regions,decision:'Retain the current standard headword and general region label; no alternative spelling established by these selected passages is proposed. Synonyms, regular plurals, possessives and abbreviations are not automatically added as exact exercise answers.',limits:note.excluded},difficulty_evidence:{before:before.difficulty,candidate:after.difficulty,observed_selected_source_label:note.observed_level,status:note.difficulty_status,notes:note.difficulty_note,independent_acceptance:false},source_record_ids:sourceIds,added_references:addedReferences,review_gates_unchanged:true};
});
check(proposals.filter(p=>p.candidate_entry.difficulty!==p.before_entry.difficulty).map(p=>p.id),['client.service-customer.n'],'Only sourced client B1 proposed');
check(proposals.find(p=>p.text==='supervisor').candidate_entry.difficulty,'A2','Supervisor field remains unchanged provisional A2');
check(proposals.filter(p=>Object.keys(p.substantive_changes).length).length,6,'Six entries have substantive wording/difficulty proposals');
const escape=text=>text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
const literal=(text,word)=>new RegExp('(^|[^A-Za-z])'+escape(word)+'(?:s)?(?:[\u0027\u2019]s)?(?=$|[^A-Za-z])','i').test(text);
const softwareMatches=new Set(['expr.software_data.equipment.04','expr.hospitality_tourism.module09.02','expr.it_support.module09.08']);
const uses=pre.expression_uses.map(row=>{
  const compoundEntries=pre.related_entries.filter(r=>literal(row.entry.text,r.entry.text));
  const matches=row.literal_selected_ids.map(id=>{
    const word=selectedById.get(id).entry.text;
    const relatedCompounds=compoundEntries.filter(r=>literal(r.entry.text,word));
    let classification=row.selected_focus_ids.includes(id)?'existing_selected_focus_ordinary_workplace_sense':relatedCompounds.length?'constituent_of_independent_complete_term':'ordinary_workplace_background_use';
    let binding='No new scored binding; existing focus lists remain exact.';
    if(softwareMatches.has(row.id)&&word==='manager'){classification='different_software_tool_sense';binding='Excluded from the Foundation human-manager sense; existing software lexeme remains independent.';}
    if(word==='visitor'&&row.id==='expr.sales_marketing.module07.06'){classification='physical_or_digital_visitor_not_fixed';binding='Do not bind to the selected physical visitor; reporting population needs its own contextual choice.';}
    if(word==='visitor'&&row.id==='expr.sales_marketing.module05.09'){classification='demonstration_visitor_channel_not_explicit';binding='Physical visitors are plausible from context, but no channel or new scored sense is asserted.';}
    if(word==='customer'&&row.id==='expr.sales_marketing.module05.09'){classification='interested_customer_or_prospect_context';binding='Retain the background expression; do not widen the Foundation buyer definition or infer a completed transaction.';}
    return {selected_id:id,classification,related_complete_lexeme_ids:relatedCompounds.map(r=>r.entry.id),binding,source_record_ids:notes[word].sources.map(s=>prefix+s)};
  });
  return {id:row.id,resource:row.resource,before_expression_json_sha256:row.json_sha256,after_expression_json_sha256:row.json_sha256,action:'retain_exact_no_language_or_domain_acceptance',text:row.entry.text,context:row.entry.context,focus_lexeme_ids:row.entry.focus_lexeme_ids,selected_focus_ids:row.selected_focus_ids,literal_selected_ids:row.literal_selected_ids,locations:row.locations,individual_observation:expressionNotes[row.id],matches,review:row.entry.review,new_scored_bindings:[],scope:'Only selected-noun compatibility and ambiguity inspected. All text, meaning, context, tokens, focus IDs, sources, media and review gates remain exact. This is not a complete expression review.'};
});
check(uses.length,167,'Exactly 167 unique expression uses');
check(uses.reduce((n,u)=>n+u.locations.length,0),357,'Exactly 357 containing memberships');
check(uses.filter(u=>u.selected_focus_ids.length).length,8,'Exactly eight selected-focus expressions');
check(uses.filter(u=>u.matches.some(m=>m.classification==='different_software_tool_sense')).length,3,'Three nonhuman-manager uses');
const expressionDocument={schema:1,status:'frozen_scoped_expression_observations_not_acceptance',date:'2026-10-16',production_mutated:false,preimages_json_sha256:hash(pre),discovery:'Existing focus bindings or exact headword/regular-plural/possessive matches in expression text. A textual match is not an automatic sense binding. All captured texts and contexts were read; individual observations preserve full expressions.',unique_expressions:uses.length,containing_module_memberships:uses.reduce((n,u)=>n+u.locations.length,0),selected_focus_expressions:8,uses,other_local_expressions:pre.local_expressions.filter(r=>!uses.some(u=>u.id===r.entry.id)).map(r=>({id:r.entry.id,before_expression_json_sha256:r.json_sha256,after_expression_json_sha256:r.json_sha256,text:r.entry.text,context:r.entry.context,action:'retain_exact',observation:'No selected first-ten noun occurs in the expression text or focus list. Full local module context was inspected without amending other targets.'})),related_entry_boundary:pre.related_entries.map(r=>({id:r.entry.id,text:r.entry.text,definition:r.entry.definition,json_sha256:r.json_sha256,action:'retain_exact_context_only_not_complete_lexeme_acceptance'})),scope_limits:['Employee and employer observations are ordinary vocabulary, not legal employment-status classifications.','Human manager and supervisor roles do not imply a fixed hierarchy or universal authority.','Customer and client overlap in service contexts; neither establishes a legally defined relationship by itself.','No software-manager, website-visitor or specialized compound is reassigned to a selected Foundation sense.','All clinical, legal, safety, employment, financial, privacy and authorization statements retain their own domain gates.']};
const inputFiles=['capture-preimages.cjs','preimages.json','source-notes.cjs','decision-notes.cjs','expression-notes.cjs','prepare-ledger.cjs'];
const inputs=Object.fromEntries(inputFiles.map(file=>[base+file,raw(base+file)]));
const end=loadProfessionalContent(root);verifyScope(end);
for(const [file,expected]of Object.entries(inputs))check(raw(file),expected,'Author input exact: '+file);
const ledger={schema:1,status:'frozen_foundation01_first10_language_candidates_awaiting_independent_review',date:'2026-10-16',author:'Codex retail_content (AI source consultation and original authoring; not human or specialist approval)',production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,scope:'Only Foundation module01 positions01-10 across all twenty courses. This package proposes language fields and additive references; all review gates, morphology, media, practice modes, accepted forms, regions, identities, memberships and release statuses remain exact.',selection:pre.selection,selected_memberships:200,preimages_json_sha256:hash(pre),source_ledger_json_sha256:hash(sourceDocument),expression_review_json_sha256:hash(expressionDocument),input_raw_sha256:inputs,proposals,proposed_additive_source_records:sourceRecords,review_boundary:{language:'All ten remain pending, including existing review status/reviewer/date fields.',difficulty:'Client has a sourced B1 proposal. Supervisor C1 conflicts with the allowed schema and remains an explicit acceptance hold with stored A2 unchanged. Team lacks an observed selected-sense level; customer and physical visitor have A1 evidence below the schema floor.',morphology:'Every current graph and its review/provenance remain exact, including employee/employer/supervisor/customer pending analyses.',media:'All image/audio data, briefs, suitability flags and Ava Sweet settings remain exact.',domain:'Existing not_required values on these ordinary Foundation nouns are retained; no legal, clinical, employment or other specialist approval is implied.',release:'No module or course is promoted; the 20 shared memberships per entry are preserved.',runtime:'No native engine, compiler or runtime probe was invoked. Language evidence does not grant morphology mastery or media release.'},structural_checks:{candidate_entries:10,schema_errors:0,expression_mutations:0},registry_json_sha256_informational:{capture:pre.registry_json_sha256_informational,start:hash(observed),end:hash(end)},remaining:['Independent review of the exact ten proposed entries and source scope before any integration.','Resolve or explicitly defer supervisor difficulty acceptance; this package neither downlevels C1 nor changes schema.','Review client B1 proposal and the provisional course-floor treatment for customer/visitor plus the unlabelled working-team sense.','Do not promote expression language/domain gates from these scoped observations.','Any future production serializer must bind exact current preimages and preserve independent concurrent work; none is supplied or run here.']};
const audit={schema:1,status:'author_structural_and_preservation_checks_passed_not_independent_acceptance',date:'2026-10-16',production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,selected_entries:10,substantively_amended_candidates:6,metadata_only_candidates:4,proposed_definition_changes:5,proposed_example_changes:3,proposed_difficulty_changes:1,proposed_client_difficulty:'B1',supervisor_source_level:'C1',supervisor_candidate_field_retained:'A2',all_language_gates_pending:true,all_other_gates_exact:true,source_consultations:12,failed_accesses_excluded:4,additive_source_records:12,all20course_first10_identical:true,selected_memberships:200,protected_unique_entries:protectedEntries.length,protected_expressions:protectedExpressions.length,scoped_expression_uses:167,scoped_expression_memberships:357,selected_focus_expressions:8,software_manager_exclusions:3,visitor_reporting_ambiguities:1,demonstration_visitor_channel_holds:1,protected_modules:pre.modules.length,protected_existing_sources:pre.existing_source_records.length,protected_growth_files:Object.keys(pre.growth_raw_sha256).length,candidate_schema_errors:0,scope_guards_passed:guards,scoped_production_records_unchanged:true,global_registry_changed_during_preparation:hash(observed)!==hash(end),global_registry_hashes_informational:true,preimages_json_sha256:hash(pre),source_ledger_json_sha256:hash(sourceDocument),expression_review_json_sha256:hash(expressionDocument),language_ledger_json_sha256:hash(ledger),prepare_script_raw_sha256:raw(base+'prepare-ledger.cjs')};
check(proposals.filter(p=>p.changed_fields.includes('definition')).length,audit.proposed_definition_changes,'Definition change count');
check(proposals.filter(p=>p.changed_fields.includes('example')).length,audit.proposed_example_changes,'Example change count');
audit.scope_guards_passed=guards;
for(const [file,value]of [['source-consultations.json',sourceDocument],['expression-use-review.json',expressionDocument],['language-ledger.json',ledger],['structural-audit.json',audit]])fs.writeFileSync(path.join(__dirname,file),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...audit,artifacts:Object.fromEntries(outputs.map(file=>[file,{json_sha256:hash(JSON.parse(fs.readFileSync(path.join(__dirname,file),'utf8'))),raw_sha256:raw(base+file)}]))},null,2));
