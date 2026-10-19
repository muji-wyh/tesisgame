'use strict';

// Read-only review of frozen inputs and live scoped records. Scratch outputs only.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../../..'), base = path.dirname(__dirname);
const {loadProfessionalContent, schemaErrors} = require(path.join(root, 'tools/validate-professional-content.cjs'));
const notes = require('./review-notes.cjs');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const at = name => path.join(base, name);
const relative = file => path.relative(root, file).replaceAll('\\', '/');
let count = 0;
const eq = (actual, expected, why) => {assert.deepEqual(actual, expected, why); count++;};
const ok = (condition, why) => {assert.ok(condition, why); count++;};
const outputNames = ['language-review-proposal.json','source-provenance.json','context-scope-audit.json','machine-audit.json','artifact-inventory.json'];
for (const name of outputNames) eq(fs.existsSync(path.join(__dirname,name)), false, 'Refuse overwrite ' + name);
const inputJsonHashes = {
  'preimages.json':'4d3b13cdfeb480e350f202636d8124a04a060bd3ca512421be1e661ded7819b6',
  'source-consultations.json':'535cffd40469c13ecdc6fac19a4b431dac54c1e2851500cb7d2f039dd6b9d71c',
  'expression-use-review.json':'f6d9383ae00ba7588b64a4931a49e0c2873c50a2835e7aa02977c99a1b74fec5',
  'language-ledger.json':'8775abfc0238763817545f4799ed00d846a436f4d563e6a3d1123a991cd9aae1',
  'structural-audit.json':'20535604d98d6d40372e268da36ac0b458c92e57743b2507692eb83a45ca8036'
};
const externalPins = {
  'root-review-r01/source-crosschecks.json':'44b1aaa7eca4e28a4f2ae81fc0092848bba25a1e14f21b9f48b5ac32817f954a',
  'client-refinement-review-r01/decision.json':'18100efe6daca59ac0119c63789e688c6476ae9763f2faa7055e2c670aab7cce',
  'client-refinement-review-r01/source-consultation.json':'813a736b52dadabc160d93b349c43523a44168529c2453edb40e29a03ced0e24'
};
for (const [file,digest] of Object.entries(inputJsonHashes)) eq(hash(read(at(file))), digest, 'Pinned input JSON ' + file);
for (const [file,digest] of Object.entries(externalPins)) eq(raw(at(file)), digest, 'Pinned independent evidence ' + file);
const originalFiles = fs.readdirSync(base).filter(name=>fs.statSync(at(name)).isFile()).sort();
eq(originalFiles.length,11,'Original author file count');
const frozenPaths = [...originalFiles,...Object.keys(externalPins),'client-refinement-review-r01/README.md'];
const inputRawHashes = Object.fromEntries(frozenPaths.map(file=>[file,raw(at(file))]));
const ledger=read(at('language-ledger.json')), pre=read(at('preimages.json')), authorSources=read(at('source-consultations.json')), contexts=read(at('expression-use-review.json')), structure=read(at('structural-audit.json'));
const rootSources=read(at('root-review-r01/source-crosschecks.json')), clientReview=read(at('client-refinement-review-r01/decision.json')), clientSource=read(at('client-refinement-review-r01/source-consultation.json'));
eq(raw(at('language-ledger.json')),'ae141726bb134d922ca46e54c2bc2810a73b78e39927f82f0bc36f688771ebb0','Independently pinned raw ledger');
for (const [key,file] of [['preimages_json_sha256','preimages.json'],['source_ledger_json_sha256','source-consultations.json'],['expression_review_json_sha256','expression-use-review.json']]) {
  eq(ledger[key],inputJsonHashes[file],'Ledger link '+key); eq(structure[key],inputJsonHashes[file],'Structural link '+key);
}
eq(structure.language_ledger_json_sha256,inputJsonHashes['language-ledger.json'],'Structural ledger link');
eq(structure.prepare_script_raw_sha256,raw(at('prepare-ledger.cjs')),'Author preparation code link');
for (const [file,digest] of Object.entries(ledger.input_raw_sha256)) eq(raw(path.join(root,file)),digest,'Author immutable input '+file);
for (const [file,digest] of Object.entries(clientReview.author_inputs_before_sha256)) eq(raw(at(file)),digest,'Client-review original author preservation '+file);
eq(clientReview.author_ledger_raw_sha256,inputRawHashes['language-ledger.json'],'Client review parent');
eq(clientReview.source_consultation.raw_sha256,externalPins['client-refinement-review-r01/source-consultation.json'],'Client source link');
eq(authorSources.preimages_json_sha256,inputJsonHashes['preimages.json'],'Source preimage link');
eq(contexts.preimages_json_sha256,inputJsonHashes['preimages.json'],'Context preimage link');
eq(ledger.proposed_additive_source_records,authorSources.proposed_additive_source_records,'Exact additive sources');
eq(notes.sources.length,12,'Fresh supporting page count');
eq(notes.sources.map(row=>row.url).sort(),authorSources.consultations.map(row=>row.url).sort(),'All supporting pages independently consulted');
eq(new Set(notes.sources.map(row=>row.url)).size,12,'Distinct independent supporting URLs');
eq(authorSources.failed_accesses.length,4,'Failed accesses retained separately');
for (const failure of authorSources.failed_accesses) {
  eq(failure.supporting_evidence,false,'Failed access excluded');
  eq(notes.sources.some(row=>row.url===failure.url),false,'Failed access not independent support');
}
for (const row of rootSources.sources) {
  const source=notes.sources.find(source=>source.url===row.url); ok(source,'Root source independently opened');
  eq(source.observed_selected_sense_level,row.selected_sense_level,'Root selected-source level corroborated');
}
eq(rootSources.sources.length,11,'Root independent crosscheck page count');
eq(clientSource.observed_level,'B1','Art client sense level');
eq(clientReview.exact_refined_definition,notes.decisions.find(row=>row.word==='client').exact_definition,'Exact client wording agreed');

const allowed=['definition','example','difficulty','references','editorial_notes'];
const protectedPart=entry=>Object.fromEntries(Object.entries(entry).filter(([key])=>!allowed.includes(key)));
const unique=rows=>{const map=new Map();for(const row of rows){if(map.has(row.entry.id))eq(map.get(row.entry.id).entry,row.entry,'Duplicate preimage agrees');else map.set(row.entry.id,row);}return [...map.values()];};
const protectedEntries=unique([...pre.selected_entries,...pre.unselected_foundation_entries,...pre.related_entries]);
const protectedExpressions=unique([...pre.local_expressions,...pre.expression_uses]);
eq(protectedEntries.length,187,'Complete protected entries'); eq(protectedExpressions.length,169,'Complete protected expressions');
eq(pre.related_entries.length,88,'Related boundary entries'); eq(pre.modules.length,126,'Protected module count');
eq(pre.existing_source_records.length,158,'Existing source count'); eq(Object.keys(pre.growth_raw_sha256).length,10,'Growth file count');
const ids=notes.decisions.map(row=>row.id);
eq(ids,pre.selection.ids,'Independently selected identities'); eq(ledger.proposals.map(row=>row.id),ids,'Author proposal identities');
const memberships=(data,id)=>data.courses.flatMap(course=>course.modules.filter(module=>module.lexeme_ids.includes(id)).map(module=>({course_id:course.id,module_id:module.id})));
const locations=(data,id)=>data.courses.flatMap(course=>course.modules.filter(module=>module.expression_ids.includes(id)).map(module=>({course_id:course.id,module_id:module.id})));
function verifyScope(data) {
  const lexemes=new Map(data.lexemes.map(row=>[row.id,row])), expressions=new Map(data.expressions.map(row=>[row.id,row])), sources=new Map(data.sources.map(row=>[row.id,row]));
  eq(data.courses.length,20,'Twenty courses');
  for(const course of data.courses) eq(course.modules.find(module=>module.id==='module01').lexeme_ids.slice(0,10),ids,'Shared first-ten order '+course.id);
  for(const row of protectedEntries) {
    eq(hash(row.entry),row.json_sha256,'Frozen complete entry digest '+row.entry.id);
    eq(hash(lexemes.get(row.entry.id)),row.json_sha256,'Live complete entry '+row.entry.id);
    eq(data.lexemeOrigins[row.entry.id],row.resource,'Live entry resource '+row.entry.id);
  }
  for(const row of pre.selected_entries) {eq(memberships(data,row.entry.id),row.memberships,'Exact selected memberships');eq(row.memberships.length,20,'Twenty memberships per noun');}
  for(const row of protectedExpressions) {
    eq(hash(row.entry),row.json_sha256,'Frozen complete expression digest '+row.entry.id);
    eq(hash(expressions.get(row.entry.id)),row.json_sha256,'Live complete expression '+row.entry.id);
    eq(data.expressionOrigins[row.entry.id],row.resource,'Expression resource '+row.entry.id);
    eq(locations(data,row.entry.id),row.locations,'Expression locations '+row.entry.id);
  }
  for(const row of pre.modules) {
    eq(hash(row.module),row.json_sha256,'Frozen module digest');
    eq(hash(data.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id)),row.json_sha256,'Complete module '+row.course_id+'/'+row.module_id);
  }
  for(const row of pre.existing_source_records) {eq(hash(row.source),row.json_sha256,'Frozen source digest');eq(hash(sources.get(row.source.id)),row.json_sha256,'Existing source '+row.source.id);}
  for(const [file,digest] of Object.entries({...pre.growth_raw_sha256,...pre.prior_artifacts_raw_sha256})) eq(raw(path.join(root,file)),digest,'Raw preservation '+file);
}
const data=loadProfessionalContent(root), registryBefore=hash(data);
verifyScope(data);
eq(pre.selected_entries.reduce((sum,row)=>sum+row.memberships.length,0),200,'Complete selected membership count');
eq(read(path.join(root,'data/professional/schemas/lexeme.schema.json')).properties.difficulty.enum,['A2','B1','B2'],'Exact current difficulty enum');
const sourceById=new Map(authorSources.consultations.map(row=>[row.id,row]));
const proposals=[];
for(const decision of notes.decisions) {
  const authored=ledger.proposals.find(row=>row.id===decision.id), before=authored.before_entry, candidate=structuredClone(authored.candidate_entry);
  eq(hash(authored.candidate_entry),decision.author_hash,'Independent candidate hash '+decision.id);
  eq(authored.candidate_entry_json_sha256,decision.author_hash,'Author candidate digest '+decision.id);
  eq(hash(before),authored.before_entry_json_sha256,'Complete selected preimage digest');
  eq(before,pre.selected_entries.find(row=>row.entry.id===decision.id).entry,'Selected preimage cross-link');
  eq(authored.memberships,memberships(data,decision.id),'Proposal full memberships');
  const changes=Object.keys(candidate).filter(key=>hash(candidate[key])!==hash(before[key]));
  eq(changes,authored.changed_fields,'Exact authored changed fields'); ok(changes.every(key=>allowed.includes(key)),'Language-only field allowlist');
  const contentKeys=changes.filter(key=>['definition','example','difficulty'].includes(key));
  eq(Object.fromEntries(contentKeys.map(key=>[key,candidate[key]])),authored.substantive_changes,'Exact authored substantive delta');
  eq(hash(protectedPart(before)),authored.protected_nonlanguage_fields_json_sha256,'Protected hash self-check');
  eq(protectedPart(candidate),protectedPart(before),'Every nonlanguage field preserved');
  eq(candidate.references.slice(0,before.references.length),before.references,'All older reference records unchanged');
  eq(candidate.references.slice(before.references.length),authored.added_references,'Exact additive references');
  eq(authored.source_record_ids,authored.added_references.map(row=>row.source_id),'Exact candidate source IDs');
  for(const reference of authored.added_references) {ok(sourceById.has(reference.source_id),'Consulted candidate source');eq(reference.status,'pending_term_check','No source acceptance inheritance');}
  eq(authored.difficulty_evidence.observed_selected_source_label,decision.observed_level,'Observed level remains distinct from editorial level');
  if(decision.word==='client') {
    candidate.definition=decision.exact_definition;
    eq(hash(candidate),decision.reviewed_hash,'Exact independently refined client candidate');
    eq(hash(candidate),clientReview.refined_candidate_entry_json_sha256,'Exact art-refined client agreement');
    eq(Object.keys(candidate).filter(key=>hash(candidate[key])!==hash(authored.candidate_entry[key])),['definition'],'Client refinement changes definition only');
  }
  eq(candidate.difficulty,decision.editorial_level,'Exact proposed editorial difficulty');
  eq(schemaErrors(candidate,'lexeme',path.join(root,'data/professional/schemas')),[],'Reviewed candidate schema '+decision.id);
  eq(candidate.review,before.review,'Every saved review gate remains unchanged');
  eq(candidate.review.language,'pending','Saved language field stays pending'); eq(candidate.review.domain,'not_required','Original domain value unchanged');
  eq(candidate.morphology,before.morphology,'Entire morphology preserved'); eq(candidate.media,before.media,'Entire media and voice preserved');
  eq(candidate.accepted_forms,[decision.word],'No alternative exact answer inferred'); eq(candidate.regions,['general'],'Region exact');
  eq(protectedPart(candidate),protectedPart(before),'Final reviewed candidate protected fields');
  proposals.push({id:decision.id,text:decision.word,author_candidate_entry_json_sha256:decision.author_hash,reviewed_candidate_entry_json_sha256:hash(candidate),full_language_gate_decision:decision.full_language_gate,wording_decision:decision.wording,difficulty:{stored:before.difficulty,reviewed_candidate:candidate.difficulty,observed_selected_source_label:decision.observed_level,independent_editorial_basis:decision.level_basis,dictionary_level_certification:false},limits:decision.limits,hold_resolution:decision.hold_resolution||null,source_record_ids:authored.source_record_ids,memberships:authored.memberships,protected_nonlanguage_fields_json_sha256:hash(protectedPart(candidate)),candidate_entry:candidate,candidate_review_fields_mutated:false});
}
eq(proposals.filter(row=>row.full_language_gate_decision.startsWith('accept')).length,9,'Nine scoped full-language acceptance proposals');
eq(proposals.filter(row=>row.full_language_gate_decision==='hold_pending').map(row=>row.id),['supervisor.work-overseer.n'],'Supervisor alone retains full-language hold');
eq(proposals.filter(row=>row.candidate_entry.difficulty!==ledger.proposals.find(p=>p.id===row.id).before_entry.difficulty).map(row=>row.id),['client.service-customer.n'],'Only client level changes');
eq(ledger.proposals.filter(row=>row.changed_fields.includes('definition')).length,5,'Five author definition proposals');
eq(ledger.proposals.filter(row=>row.changed_fields.includes('example')).length,3,'Three author example proposals');

// This scan is independently rebuilt from the live text and focus lists; it does
// not trust the author's occurrence classifications or source-ledger counts.
const literal=(text,word)=>new RegExp('(^|[^A-Za-z])'+word+'(?:s)?(?:[\u0027\u2019]s)?(?=$|[^A-Za-z])','i').test(text);
const discovered=data.expressions.filter(entry=>entry.focus_lexeme_ids.some(id=>ids.includes(id))||notes.decisions.some(row=>literal(entry.text,row.word)));
eq(discovered.map(row=>row.id).sort(),pre.expression_uses.map(row=>row.id).sort(),'Complete live text/focus occurrence discovery');
eq(discovered.length,167,'Distinct matching expressions');
eq(contexts.uses.map(row=>row.id).sort(),discovered.map(row=>row.id).sort(),'Every discovered occurrence has author scope evidence');
const contextAudit=[];
for(const entry of discovered) {
  const snapshot=pre.expression_uses.find(row=>row.id===entry.id), authored=contexts.uses.find(row=>row.id===entry.id);
  const exactHash=hash(entry), selected=entry.focus_lexeme_ids.filter(id=>ids.includes(id));
  const literalIds=notes.decisions.filter(row=>literal(entry.text,row.word)).map(row=>row.id);
  eq(authored.before_expression_json_sha256,exactHash,'Context before hash'); eq(authored.after_expression_json_sha256,exactHash,'Context no proposed mutation');
  eq(authored.text,entry.text,'Exact context text'); eq(authored.context,entry.context,'Exact contextual framing');
  eq(authored.focus_lexeme_ids,entry.focus_lexeme_ids,'No focus change'); eq(authored.selected_focus_ids,selected,'Existing selected focuses');
  eq(authored.literal_selected_ids,literalIds,'Literal discovery IDs'); eq(snapshot.literal_selected_ids,literalIds,'Frozen literal discovery IDs');
  eq(authored.locations,locations(data,entry.id),'All expression memberships'); eq(authored.new_scored_bindings,[],'No new scoring binding');
  eq(authored.review,entry.review,'Expression review exact'); ok(authored.individual_observation.length>0,'Individual author note inspected');
  const [classification,observation]=notes.contextNotes[entry.id]||['ordinary_background_or_compound_constituent_only','The selected noun fits a human workplace relationship, work group or related term constituent in this context. Preserve the complete expression and specialist meaning; lexical compatibility neither adds a scored binding nor approves a procedure, policy, authority or whole expression.'];
  contextAudit.push({id:entry.id,expression_json_sha256:exactHash,text:entry.text,context:entry.context,selected_focus_ids:selected,literal_selected_ids:literalIds,locations:authored.locations,classification,independent_observation:observation,decision:'preserve_exact_no_whole_expression_acceptance',new_scored_bindings:[],domain_and_language_gates:entry.review});
}
eq(contextAudit.reduce((sum,row)=>sum+row.locations.length,0),357,'All expression memberships');
eq(contextAudit.filter(row=>row.selected_focus_ids.length).length,8,'Eight selected-focus expressions');
eq(contextAudit.filter(row=>row.classification==='exclude_software_manager').length,3,'Three independent software exclusions');
eq(contextAudit.filter(row=>row.classification==='hold_background_sense_binding').length,2,'Two independent visitor-channel holds');
for(const id of Object.keys(notes.contextNotes))ok(discovered.some(row=>row.id===id),'Independent contextual decision has a real captured occurrence');
const otherLocal=pre.local_expressions.filter(row=>!discovered.some(entry=>entry.id===row.entry.id));
eq(otherLocal.length,2,'Two other exact local expressions');
eq(otherLocal.map(row=>row.entry.id).sort(),contexts.other_local_expressions.map(row=>row.id).sort(),'Unmatched local context coverage');
const expectedModules=data.courses.flatMap(course=>course.modules.filter(module=>module.lexeme_ids.some(id=>ids.includes(id))||module.expression_ids.some(id=>discovered.some(entry=>entry.id===id))).map(module=>course.id+'/'+module.id));
eq(expectedModules.sort(),pre.modules.map(row=>row.course_id+'/'+row.module_id).sort(),'Complete containing module scope');
const related=data.lexemes.filter(entry=>!ids.includes(entry.id)&&/\b(colleague|employee|employer|supervisor|manager|team|department|customer|client|visitor|worker|contractor|staff|guest)\b/i.test(entry.text));
eq(related.map(row=>row.id).sort(),pre.related_entries.map(row=>row.entry.id).sort(),'Independent neighboring-role coverage');
for(const source of ledger.proposed_additive_source_records) {eq(data.sources.some(row=>row.id===source.id),false,'Additive source absent from production');eq(source.assets_acquired,false,'No source media acquired');eq(source.asset_license,null,'No asset license inferred');}

const deps=['tools/validate-professional-content.cjs','data/professional/schemas/lexeme.schema.json','data/professional/schemas/common.schema.json','data/professional/schemas/morphology.schema.json','docs/plans/2026-10-15-professional-english-and-morphology.md'];
const dependencyHashes=Object.fromEntries(deps.map(file=>[file,raw(path.join(root,file))]));
const after=loadProfessionalContent(root); verifyScope(after);
for(const [file,digest] of Object.entries(inputRawHashes))eq(raw(at(file)),digest,'All frozen evidence preserved '+file);
for(const [file,digest] of Object.entries(dependencyHashes))eq(raw(path.join(root,file)),digest,'Stable review dependency '+file);
const reviewer='Codex nursing_theme (independent AI editorial language review; not human or subject-matter approval)';
const sourceProvenance={schema:1,status:'fresh_independent_selected_passage_review_complete',reviewer,date:'2026-10-16',method:'The reviewer freshly opened all twelve supporting pages with the web tool and inspected the selected meanings, grammar and topic labels. Only original concise paraphrases are saved. Root and art evidence was separately hash-bound and crosschecked, not substituted for direct reading.',sources:notes.sources,root_crosscheck:{path:relative(at('root-review-r01/source-crosschecks.json')),raw_sha256:externalPins['root-review-r01/source-crosschecks.json'],pages:11},client_refinement:{decision_path:relative(at('client-refinement-review-r01/decision.json')),decision_raw_sha256:externalPins['client-refinement-review-r01/decision.json'],source_path:relative(at('client-refinement-review-r01/source-consultation.json')),source_raw_sha256:externalPins['client-refinement-review-r01/source-consultation.json'],scope:'Exact definition refinement only in that prior independent record; this review separately decides the complete selected language candidate.'},failed_author_accesses_excluded:4,rights:'No full dictionary entries, examples, recordings, images or exercises acquired or integrated. Consultation conveys no asset license.',difficulty_boundary:'Observed source labels are recorded independently of editorial curriculum placement. No frequency-to-CEFR conversion or transfer from another sense or footer occurs.'};
const proposal={schema:1,status:'independent_language_review_proposal_nine_accept_one_hold_no_gate_mutation',date:'2026-10-16',reviewer,author_ledger_json_sha256:inputJsonHashes['language-ledger.json'],author_ledger_raw_sha256:inputRawHashes['language-ledger.json'],source_provenance_json_sha256:hash(sourceProvenance),full_language_acceptance_proposals:9,pending_full_language_gates:['supervisor.work-overseer.n'],decisions:proposals,production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,all_saved_candidate_review_fields_pending:true,scope:'Exact ordinary noun language proposals only. Accept/hold decisions are separate review evidence, not changed production gates or complete expression approval. Root must bind any later serializer independently.',required_preservation:['All 200 selected memberships and full contextual scope.','All morphology, media and voice metadata, domain values, accepted forms, regions, practice modes, modules and course states.','All 90 unselected Foundation records and 88 neighboring records, deduplicated to 187 protected entries.','Supervisor stored A2 remains unaccepted; no C1-to-B2 conversion or schema extension.','Team A2 is editorial only; customer and visitor remain observed A1 and editorial A2 course-floor placements.']};
const contextDocument={schema:1,status:'independent_context_scope_review_preserved_no_expression_acceptance',date:'2026-10-16',reviewer,author_expression_review_json_sha256:inputJsonHashes['expression-use-review.json'],unique_matching_expressions:167,containing_memberships:357,selected_focus_expressions:8,uses:contextAudit,other_local_expressions:otherLocal.map(row=>({id:row.entry.id,expression_json_sha256:row.json_sha256,decision:'Preserve exact; no selected target in text or focus list. Context-only mentions do not create a scoring binding.'})),related_entry_boundaries:pre.related_entries.map(row=>({id:row.entry.id,json_sha256:row.json_sha256,decision:'Preserve exact as an independent neighboring role, compound or alternate sense; no complete-lexeme approval.'}))};
const audit={schema:1,status:'independent_machine_scope_and_decision_checks_passed',date:'2026-10-16',reviewer,checks_passed:count,input_json_sha256:inputJsonHashes,input_raw_sha256:inputRawHashes,review_dependency_raw_sha256:dependencyHashes,proposal_json_sha256:hash(proposal),source_provenance_json_sha256:hash(sourceProvenance),context_audit_json_sha256:hash(contextDocument),counts:{selected_entries:10,full_language_acceptance_proposals:9,full_language_holds:1,author_candidate_schema_errors:0,reviewed_candidate_schema_errors:0,selected_memberships:200,complete_protected_entries:187,neighboring_entries:88,complete_protected_expressions:169,matching_expressions:167,expression_memberships:357,selected_focus_expressions:8,other_local_expressions:2,modules:126,existing_source_records:158,growth_files:10,fresh_source_pages:12,software_manager_exclusions:3,visitor_channel_holds:2,client_definition_refinements:1},scoped_records_exact_before_and_after:true,frozen_evidence_files_preserved:frozenPaths.length,registry_hashes_informational:{capture:pre.registry_json_sha256_informational,review_start:registryBefore,review_end:hash(after)},production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,limits:['Machine assertions validate scope and exact decisions; linguistic judgments are individually documented in the proposal.','No production gate was promoted, no serializer supplied and no native or shared test suite was executed.','Full language acceptance is scoped AI editorial evidence and does not imply human, legal, clinical, safety, morphology or media approval.']};
for(const [file,value] of [['source-provenance.json',sourceProvenance],['language-review-proposal.json',proposal],['context-scope-audit.json',contextDocument],['machine-audit.json',audit]])fs.writeFileSync(path.join(__dirname,file),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const artifactNames=['HANDOFF.md','review-notes.cjs','run-review.cjs',...outputNames.filter(name=>name!=='artifact-inventory.json')];
const inventory={schema:1,status:'write_once_independent_review_inventory',files:artifactNames.map(name=>({name,bytes:fs.statSync(path.join(__dirname,name)).size,raw_sha256:raw(path.join(__dirname,name)),...(name.endsWith('.json')?{json_sha256:hash(read(path.join(__dirname,name)))}:{})})),inventory_excludes_itself:true};
fs.writeFileSync(path.join(__dirname,'artifact-inventory.json'),JSON.stringify(inventory,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:audit.status,checks_passed:count,language_acceptance_proposals:9,full_language_holds:['supervisor.work-overseer.n'],proposal_raw_sha256:raw(path.join(__dirname,'language-review-proposal.json')),proposal_json_sha256:hash(proposal),audit_raw_sha256:raw(path.join(__dirname,'machine-audit.json')),inventory_raw_sha256:raw(path.join(__dirname,'artifact-inventory.json')),production_mutated:false,native_runtime_executed:false},null,2));
