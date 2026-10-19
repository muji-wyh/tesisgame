'use strict';

// Read-only scoped audit. All writes are exclusive new scratch files beside this script.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../../..'),base=path.dirname(__dirname);
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const {loadProfessionalContent,schemaErrors}=require(path.join(root,'tools/validate-professional-content.cjs'));
const notes=require('./review-notes.cjs');
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const raw=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const at=name=>path.join(base,name);
let checks=0;
const eq=(actual,expected,why)=>{assert.deepEqual(actual,expected,why);checks++;};
const ok=(condition,why)=>{assert.ok(condition,why);checks++;};
const outputNames=['source-provenance.json','language-review-proposal.json','context-scope-audit.json','machine-audit.json','artifact-inventory.json'];
for(const name of outputNames)eq(fs.existsSync(path.join(__dirname,name)),false,'Refuse overwrite '+name);
const inputJsonHashes={
  'preimages.json':'374e9b75aa44fca2b1b6f5f2d64ecb523f49c36d1b345c8576548e435507a324',
  'source-consultations.json':'e9f97e97014ffc915d8a9d37030d8911e7ce72d729bca154848acc7e925e40ee',
  'expression-use-review.json':'6612249e4f0bdb113d1ac4a850184319475040ad8410d8c1a0d1c12e652504f0',
  'language-ledger.json':'459a4f18ee76f142e1191d3c39df6bdf81344f6cef701d8121107c6b0bd52fa8',
  'structural-audit.json':'0817339dffabe0652173a3a7e534503c9b0629e3dc16fba94ba294e4186ca1e3'
};
for(const [file,digest]of Object.entries(inputJsonHashes))eq(hash(read(at(file))),digest,'Pinned frozen JSON '+file);
eq(raw(at('language-ledger.json')),'dc41b9c2cf20c04beecbd513e76a48cdeb3133d5481c028b4a29e7807775d06c','Pinned raw ledger');
const frozenFiles=fs.readdirSync(base).filter(name=>fs.statSync(at(name)).isFile()).sort();
eq(frozenFiles.length,11,'Author package file count');
const inputRawHashes=Object.fromEntries(frozenFiles.map(file=>[file,raw(at(file))]));
const ledger=read(at('language-ledger.json')),pre=read(at('preimages.json')),sources=read(at('source-consultations.json')),contexts=read(at('expression-use-review.json')),structure=read(at('structural-audit.json'));
for(const [key,file]of [['preimages_json_sha256','preimages.json'],['source_ledger_json_sha256','source-consultations.json'],['expression_review_json_sha256','expression-use-review.json']]){
  eq(ledger[key],inputJsonHashes[file],'Author ledger dependency '+key);eq(structure[key],inputJsonHashes[file],'Author structural dependency '+key);
}
eq(structure.language_ledger_json_sha256,inputJsonHashes['language-ledger.json'],'Structure binds ledger');
eq(structure.prepare_script_raw_sha256,raw(at('prepare-ledger.cjs')),'Frozen author script');
eq(sources.preimages_json_sha256,inputJsonHashes['preimages.json'],'Source snapshot link');
eq(contexts.preimages_json_sha256,inputJsonHashes['preimages.json'],'Context snapshot link');
for(const [file,digest]of Object.entries(ledger.input_raw_sha256))eq(raw(path.join(root,file)),digest,'Immutable author input '+file);
eq(ledger.proposed_additive_source_records,sources.proposed_additive_source_records,'Exact source proposals');
eq(notes.sources.length,13,'Thirteen fresh direct pages');
eq(new Set(notes.sources.map(row=>row.url)).size,13,'Thirteen distinct URLs');
eq(notes.sources.map(row=>row.url).sort(),sources.consultations.map(row=>row.url).sort(),'Every supporting page freshly consulted');
for(const s of notes.sources){
  const authored=sources.consultations.find(row=>row.id===s.source_id);ok(authored,'Real source identifier');
  eq(s.url,authored.url,'Selected exact source URL');eq(s.observed_selected_sense_level,authored.observed_selected_sense_level,'Original source label retained '+s.source_id);
  ok(s.independent_observation.length>30,'Independent selected-passage observation');eq(s.assets_acquired,false,'No acquired source assets');eq(s.asset_license,null,'No inferred source license');
}
eq(sources.failed_accesses.length,4,'Four failed Cambridge accesses');
for(const failed of sources.failed_accesses){eq(failed.evidence_used,false,'Failed access not evidence');eq(notes.sources.some(s=>s.url===failed.url),false,'No failed URL promoted');}

const allowed=['definition','example','difficulty','references','editorial_notes'];
const protectedPart=entry=>Object.fromEntries(Object.entries(entry).filter(([key])=>!allowed.includes(key)));
const unique=rows=>{const map=new Map();for(const row of rows){if(map.has(row.entry.id))eq(map.get(row.entry.id).entry,row.entry,'Duplicate snapshot agrees');else map.set(row.entry.id,row);}return [...map.values()];};
const protectedEntries=unique([...pre.selected_entries,...pre.unselected_foundation_entries,...pre.related_entries]);
const protectedExpressions=unique([...pre.local_expressions,...pre.expression_uses]);
eq(protectedEntries.length,163,'Complete protected entries');eq(protectedExpressions.length,118,'Complete protected expressions');
eq(pre.related_entries.length,64,'Related entries');eq(pre.modules.length,108,'Containing modules');eq(pre.existing_source_records.length,133,'Existing sources');
eq(Object.keys(pre.growth_raw_sha256).length,10,'All Growth morphology files');
const ids=notes.decisions.map(row=>row.id);
eq(ids,pre.selection.ids,'Independent identities');eq(ledger.proposals.map(row=>row.id),ids,'Exact author identities');
const memberships=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
const locations=(data,id)=>data.courses.flatMap(c=>c.modules.filter(m=>m.expression_ids.includes(id)).map(m=>({course_id:c.id,module_id:m.id})));
function verifyScope(data){
  const lexemes=new Map(data.lexemes.map(row=>[row.id,row])),expressions=new Map(data.expressions.map(row=>[row.id,row])),sourceMap=new Map(data.sources.map(row=>[row.id,row]));
  eq(data.courses.length,20,'All courses retained');
  for(const c of data.courses)eq(c.modules.find(m=>m.id==='module01').lexeme_ids.slice(10,20),ids,'Positions 11-20 '+c.id);
  for(const row of protectedEntries){eq(hash(row.entry),row.json_sha256,'Frozen entry hash '+row.entry.id);eq(lexemes.get(row.entry.id),row.entry,'Complete current entry '+row.entry.id);eq(data.lexemeOrigins[row.entry.id],row.resource,'Entry resource');}
  for(const row of pre.selected_entries){eq(memberships(data,row.entry.id),row.memberships,'Selected memberships');eq(row.memberships.length,20,'Twenty memberships per selected entry');}
  for(const row of protectedExpressions){eq(hash(row.entry),row.json_sha256,'Frozen expression hash');eq(expressions.get(row.entry.id),row.entry,'Complete current expression '+row.entry.id);eq(data.expressionOrigins[row.entry.id],row.resource,'Expression resource');eq(locations(data,row.entry.id),row.locations,'Exact expression memberships');}
  for(const row of pre.modules){eq(hash(row.module),row.json_sha256,'Frozen module hash');eq(data.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id),row.module,'Complete containing module');}
  for(const row of pre.existing_source_records){eq(hash(row.source),row.json_sha256,'Frozen source hash');eq(sourceMap.get(row.source.id),row.source,'Existing source remains exact');}
  for(const [file,digest]of Object.entries({...pre.growth_raw_sha256,...pre.prior_artifacts_raw_sha256}))eq(raw(path.join(root,file)),digest,'Protected prior artifact '+file);
}
const data=loadProfessionalContent(root),registryBefore=hash(data);verifyScope(data);
eq(pre.selected_entries.reduce((n,row)=>n+row.memberships.length,0),200,'All selected memberships');
eq(read(path.join(root,'data/professional/schemas/lexeme.schema.json')).properties.difficulty.enum,['A2','B1','B2'],'Exact existing difficulty enum');
const proposals=[];
for(const decision of notes.decisions){
  const authored=ledger.proposals.find(row=>row.id===decision.id),before=authored.before_entry,candidate=structuredClone(authored.candidate_entry);
  eq(hash(authored.candidate_entry),decision.author_hash,'Pinned candidate '+decision.word);eq(authored.candidate_entry_json_sha256,decision.author_hash,'Author candidate checksum');
  eq(hash(before),authored.before_entry_json_sha256,'Author preimage checksum');eq(before,pre.selected_entries.find(row=>row.entry.id===decision.id).entry,'Author selected preimage');
  eq(authored.memberships,memberships(data,decision.id),'All candidate memberships');
  const changes=Object.keys(candidate).filter(key=>hash(candidate[key])!==hash(before[key]));
  eq(changes,authored.changed_fields,'Exact authored field delta');ok(changes.every(key=>allowed.includes(key)),'Language field allowlist');
  const substantive=Object.fromEntries(changes.filter(key=>['definition','example','difficulty'].includes(key)).map(key=>[key,candidate[key]]));
  eq(substantive,authored.substantive_changes,'Exact substantive author delta');
  eq(hash(protectedPart(before)),authored.protected_nonlanguage_fields_json_sha256,'Protected hash');eq(protectedPart(candidate),protectedPart(before),'Protected author fields');
  eq(candidate.references.slice(0,before.references.length),before.references,'Old references preserved');eq(candidate.references.slice(before.references.length),authored.added_references,'Only additive references');
  eq(authored.source_record_ids,authored.added_references.map(row=>row.source_id),'Source IDs exact');
  for(const ref of authored.added_references){ok(notes.sources.some(s=>s.source_id===ref.source_id),'Reference freshly consulted');eq(ref.status,'pending_term_check','No inherited source approval');}
  const observed=Object.fromEntries(authored.source_record_ids.map(id=>{const s=notes.sources.find(row=>row.source_id===id);return[id.split('-').at(-2),s.observed_selected_sense_level];}));
  eq(observed,authored.difficulty_evidence.observed_selected_source_labels,'All labels literal and sense-specific');
  eq(candidate.definition,decision.definition,'Exact reviewed definition');eq(candidate.example,decision.example,'Exact reviewed original example');
  eq(schemaErrors(candidate,'lexeme',path.join(root,'data/professional/schemas')),[],'Author candidate schema');
  if(decision.independent_refinement){
    candidate.difficulty=decision.editorial_level;
    candidate.editorial_notes=before.editorial_notes+' Independent language review r01 proposes editorial '+decision.editorial_level+' for this exact learning item. '+decision.level_basis+' This scratch candidate retains every pending review gate; acceptance evidence is separate and production integration remains unperformed.';
    eq(Object.keys(candidate).filter(key=>hash(candidate[key])!==hash(authored.candidate_entry[key])),['difficulty','editorial_notes'],'Only independently resolved level and explanatory notes refined');
  }
  eq(candidate.difficulty,decision.editorial_level,'Exact independent editorial level');eq(candidate.definition,authored.candidate_entry.definition,'No reviewer definition rewrite');eq(candidate.example,before.example,'Every original example unchanged');
  eq(schemaErrors(candidate,'lexeme',path.join(root,'data/professional/schemas')),[],'Reviewed candidate schema');
  eq(protectedPart(candidate),protectedPart(before),'All final nonlanguage fields preserved');eq(candidate.review,before.review,'Every review field exact');eq(candidate.review.language,'pending','Saved candidate language pending');
  eq(candidate.morphology,before.morphology,'Full morphology exact');eq(candidate.media,before.media,'Full media and voice exact');eq(candidate.accepted_forms,[decision.word],'Protected accepted forms');eq(candidate.regions,['general'],'Protected regions');
  proposals.push({id:decision.id,text:decision.word,author_candidate_entry_json_sha256:decision.author_hash,reviewed_candidate_entry_json_sha256:hash(candidate),full_language_gate_decision:decision.full_language_gate,wording_decision:decision.wording,example_decision:'Retain exact original example; independently read with its selected noun meaning.',difficulty:{stored:before.difficulty,author_candidate:authored.candidate_entry.difficulty,reviewed_candidate:candidate.difficulty,observed_selected_source_labels:observed,independent_editorial_basis:decision.level_basis,dictionary_level_certification:false},spelling_and_region_decision:decision.spelling,scope_limit:decision.scope_limit,source_record_ids:authored.source_record_ids,memberships:authored.memberships,protected_nonlanguage_fields_json_sha256:hash(protectedPart(candidate)),candidate_entry:candidate,candidate_review_fields_mutated:false});
}
eq(ledger.proposals.filter(row=>row.changed_fields.includes('definition')).map(row=>row.text),['trainee','supplier','shift'],'Only three author definition changes');
eq(ledger.proposals.filter(row=>row.changed_fields.includes('difficulty')).map(row=>row.text),['trainee','appointment'],'Only two author difficulty changes');
eq(ledger.proposals.filter(row=>row.changed_fields.includes('example')).length,0,'No author example changes');
eq(proposals.filter(row=>row.full_language_gate_decision==='accept_scoped_ai_language').length,9,'Nine full language proposals');
eq(proposals.filter(row=>row.full_language_gate_decision==='hold_pending_spelling').map(row=>row.id),['coordinator.organizer.n'],'Coordinator spelling alone holds full acceptance');
eq(notes.decisions.filter(row=>row.independent_refinement).map(row=>row.word),['contact','shift'],'Only two reviewer difficulty refinements');

// Rebuild all literal/focus discovery from the live registry without trusting counts.
const literal=(text,word)=>new RegExp('(^|[^A-Za-z])'+word+'(?:s)?(?:[\u0027\u2019]s)?(?=$|[^A-Za-z])','i').test(text);
const discovered=data.expressions.filter(e=>e.focus_lexeme_ids.some(id=>ids.includes(id))||notes.decisions.some(d=>literal(e.text,d.word)));
eq(discovered.map(row=>row.id),pre.expression_uses.map(row=>row.id),'Complete independent live discovery');eq(discovered.length,114,'Matching expression count');
const contextAudit=[];
for(const entry of discovered){
  const snapshot=pre.expression_uses.find(row=>row.id===entry.id),authored=contexts.uses.find(row=>row.id===entry.id),digest=hash(entry);
  const literalIds=notes.decisions.filter(d=>literal(entry.text,d.word)).map(d=>d.id),selected=entry.focus_lexeme_ids.filter(id=>ids.includes(id));
  eq(digest,snapshot.json_sha256,'Current expression matches snapshot');eq(authored.before_expression_json_sha256,digest,'Context preimage link');eq(authored.after_expression_json_sha256,digest,'No author expression mutation');
  eq(authored.text,entry.text,'Full text read');eq(authored.context,entry.context,'Full framing read');eq(authored.focus_lexeme_ids,entry.focus_lexeme_ids,'Every focus preserved');
  eq(authored.selected_focus_ids,selected,'Selected focus scope');eq(authored.literal_selected_ids,literalIds,'Every literal word');eq(snapshot.literal_selected_ids,literalIds,'Frozen discovery agrees');
  eq(authored.locations,locations(data,entry.id),'Containing memberships');eq(authored.review,entry.review,'Expression gates preserved');eq(authored.new_scored_bindings,[],'No new scoring binding');
  eq(authored.matches.map(m=>m.selected_id),literalIds,'Each selected match classified');ok(authored.individual_observation.length>0,'Individual author note read');
  const matchDecisions=authored.matches.map(m=>{
    const word=notes.decisions.find(d=>d.id===m.selected_id).word;
    const extraHold=word==='supplier'&&notes.extraSupplierHolds.includes(entry.id);
    const code=extraHold?'supplier_scope':m.authored_classification_code;
    ok(Object.hasOwn(notes.categoryNotes,code),'Independent category judgment present');
    const occurrences=[...entry.text.matchAll(new RegExp('\\b'+word+'(?:s)?(?:[\u0027\u2019]s)?\\b','gi'))].map(match=>({text:match[0],start:match.index,end:match.index+match[0].length}));
    ok(occurrences.length>0,'Literal occurrence spans retained');
    return {selected_id:m.selected_id,literal_occurrences:occurrences,author_classification_code:m.authored_classification_code,reviewer_classification_code:code,author_classification_confirmed:!extraHold,independent_observation:notes.categoryNotes[code],new_scored_bindings:[]};
  });
  contextAudit.push({id:entry.id,expression_json_sha256:digest,text:entry.text,context:entry.context,selected_focus_ids:selected,literal_selected_ids:literalIds,locations:authored.locations,independently_read:true,independent_observation:notes.contextNotes[entry.id]||'The exact text and framing were read. Retain the bounded interpretations below; no wording, specialist scope, authority, scoring route or complete-expression approval follows from this lexical compatibility check.',matches:matchDecisions,decision:'preserve_exact_no_whole_expression_acceptance',new_scored_bindings:[],review_gates:entry.review});
}
eq(contextAudit.reduce((sum,row)=>sum+row.locations.length,0),266,'All expression memberships');eq(contextAudit.filter(row=>row.selected_focus_ids.length).length,6,'Six existing selected-focus expressions');
const matchCount=code=>contextAudit.flatMap(row=>row.matches).filter(m=>m.reviewer_classification_code===code).length;
eq(matchCount('supplier_scope'),6,'Two author plus four independent supplier scope holds');eq(matchCount('ambiguous'),2,'Two contact route holds');eq(matchCount('physical'),3,'Three physical-contact exclusions');
eq(matchCount('financial_schedule'),1,'Financial table context');eq(matchCount('rendezvous'),1,'Meeting-point exclusion');eq(matchCount('platform_access'),1,'Hearing access hold');
for(const id of Object.keys(notes.contextNotes))ok(discovered.some(row=>row.id===id),'Independent note targets a captured expression');
for(const id of notes.extraSupplierHolds){const row=contextAudit.find(row=>row.id===id);eq(row.selected_focus_ids,[],'Additional hold is background-only');ok(row.matches.some(m=>m.selected_id==='supplier.goods-provider.n'),'Hold targets actual supplier literal');}
const otherLocal=pre.local_expressions.filter(row=>!discovered.some(e=>e.id===row.entry.id));eq(otherLocal.length,4,'Four other local expressions');eq(otherLocal.map(row=>row.entry.id),contexts.other_local_expressions.map(row=>row.id),'Complete local context coverage');
const expectedModules=data.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.some(id=>ids.includes(id))||m.expression_ids.some(id=>discovered.some(e=>e.id===id))).map(m=>c.id+'/'+m.id));
eq(expectedModules.sort(),pre.modules.map(row=>row.course_id+'/'+row.module_id).sort(),'Complete containing module scope');
const related=data.lexemes.filter(e=>!ids.includes(e.id)&&/\b(contractor|trainee|receptionist|coordinator|co-ordinator|contact|supplier|schedule|shift|appointment|meeting|vendor|courier)\b/i.test(e.text));
eq(related.map(row=>row.id),pre.related_entries.map(row=>row.entry.id),'Independent neighboring scope discovery');
for(const s of ledger.proposed_additive_source_records){eq(data.sources.some(row=>row.id===s.id),false,'Proposed source not integrated');eq(s.assets_acquired,false,'No source acquisition');eq(s.asset_license,null,'No license inferred');}
const dependencies=['tools/validate-professional-content.cjs','data/professional/schemas/lexeme.schema.json','data/professional/schemas/common.schema.json','data/professional/schemas/morphology.schema.json','docs/plans/2026-10-15-professional-english-and-morphology.md'];
const dependencyHashes=Object.fromEntries(dependencies.map(file=>[file,raw(path.join(root,file))]));
const after=loadProfessionalContent(root);verifyScope(after);
for(const [file,digest]of Object.entries(inputRawHashes))eq(raw(at(file)),digest,'Entire author package preserved '+file);
for(const [file,digest]of Object.entries(dependencyHashes))eq(raw(path.join(root,file)),digest,'Review dependency stable '+file);
const reviewer='Codex foundation_review (independent AI editorial language review; not human or subject-matter approval)';
const sourceProvenance={schema:1,status:'fresh_independent_selected_passage_review_complete',date:'2026-10-16',reviewer,method:'All thirteen supporting URLs were freshly opened with the web tool, and the selected definitions, grammar, spelling and labels were read directly. The saved observations are original concise paraphrases; no source page, example, audio or picture is acquired.',sources:notes.sources,failed_author_accesses_excluded:4,difficulty_boundary:'Observed labels remain literal and sense-specific. Editorial curriculum placement is a separate reasoned decision; it neither certifies dictionary CEFR nor translates B1+ into another source label.',rights:'Consultation conveys no asset license. Only original short observations are retained.'};
const proposal={schema:1,status:'independent_language_review_proposal_nine_accept_one_spelling_hold_no_gate_mutation',date:'2026-10-16',reviewer,author_ledger_json_sha256:inputJsonHashes['language-ledger.json'],author_ledger_raw_sha256:inputRawHashes['language-ledger.json'],source_provenance_json_sha256:hash(sourceProvenance),full_language_acceptance_proposals:9,pending_full_language_gates:['coordinator.organizer.n'],reviewer_difficulty_refinements:{contact:'B2',shift:'B1'},decisions:proposals,production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,all_saved_candidate_review_fields_pending:true,scope:'Exact ordinary noun language only. Nine acceptance proposals are separate evidence, not production gate changes. Coordinator wording and B1 placement are acceptable, but full acceptance is held for a separately scoped British spelling amendment.',required_preservation:['All 200 selected memberships, 118 expressions, 108 modules and all existing gates remain exact.','All morphology, media, voice settings, accepted forms, regions, practice modes and domain values remain exact.','Contact Collins B1+; shift Oxford B1 and Collins B2; meeting Oxford A1 all remain literal observations.','Contractor and supplier A2, coordinator B1 are independent editorial choices with no observed selected source CEFR.','No exact helpful-person binding for ambiguous routes and no goods-provider binding in six unresolved supplier contexts.','Root must independently bind any serializer and any future co-ordinator accepted_forms amendment.']};
const contextDocument={schema:1,status:'independent_context_scope_review_preserved_no_expression_acceptance',date:'2026-10-16',reviewer,author_expression_review_json_sha256:inputJsonHashes['expression-use-review.json'],unique_matching_expressions:114,containing_memberships:266,selected_focus_expressions:6,uses:contextAudit,additional_supplier_scope_holds:notes.extraSupplierHolds,other_local_expressions:otherLocal.map(row=>({id:row.entry.id,expression_json_sha256:row.json_sha256,text:row.entry.text,context:row.entry.context,decision:'Read and preserve exact; no selected noun in the text or focuses, and no new binding.'})),related_entry_boundaries:pre.related_entries.map(row=>({id:row.entry.id,text:row.entry.text,definition:row.entry.definition,json_sha256:row.json_sha256,decision:'Preserve exact complete neighboring role, record, compound or alternative sense; no full-entry acceptance.'}))};
const audit={schema:1,status:'independent_machine_scope_and_decision_checks_passed',date:'2026-10-16',reviewer,checks_passed:checks,input_json_sha256:inputJsonHashes,input_raw_sha256:inputRawHashes,review_dependency_raw_sha256:dependencyHashes,proposal_json_sha256:hash(proposal),source_provenance_json_sha256:hash(sourceProvenance),context_audit_json_sha256:hash(contextDocument),counts:{selected_entries:10,full_language_acceptance_proposals:9,full_language_holds:1,author_definition_changes:3,author_difficulty_changes:2,reviewer_difficulty_refinements:2,example_changes:0,author_candidate_schema_errors:0,reviewed_candidate_schema_errors:0,selected_memberships:200,complete_protected_entries:163,neighboring_entries:64,complete_protected_expressions:118,matching_expressions:114,expression_memberships:266,selected_focus_expressions:6,other_local_expressions:4,modules:108,existing_source_records:133,growth_files:10,fresh_source_pages:13,contact_route_holds:2,supplier_scope_holds:6,additional_supplier_scope_holds:4,physical_contact_exclusions:3},scoped_records_exact_before_and_after:true,all_author_files_preserved:frozenFiles.length,registry_hashes_informational:{capture:pre.registry_json_sha256_informational,review_start:registryBefore,review_end:hash(after)},production_mutated:false,shared_tests_mutated:false,native_runtime_executed:false,limits:['Assertions validate exact scope and recorded decisions, not the correctness of language judgment; the latter is documented separately.','No gate promotion, serializer, native runtime, shared test edit or full suite execution occurred.','Independent AI lexical review does not imply human, domain, morphology, media, module or release acceptance.']};
for(const [name,value]of [['source-provenance.json',sourceProvenance],['language-review-proposal.json',proposal],['context-scope-audit.json',contextDocument],['machine-audit.json',audit]])fs.writeFileSync(path.join(__dirname,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const inventory={schema:1,status:'write_once_independent_review_inventory',files:['HANDOFF.md','review-notes.cjs','run-review.cjs',...outputNames.filter(name=>name!=='artifact-inventory.json')].map(name=>({name,bytes:fs.statSync(path.join(__dirname,name)).size,raw_sha256:raw(path.join(__dirname,name)),...(name.endsWith('.json')?{json_sha256:hash(read(path.join(__dirname,name)))}:{})})),inventory_excludes_itself:true};
fs.writeFileSync(path.join(__dirname,'artifact-inventory.json'),JSON.stringify(inventory,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:audit.status,checks_passed:checks,full_language_acceptance_proposals:9,full_language_holds:proposal.pending_full_language_gates,proposal_json_sha256:hash(proposal),proposal_raw_sha256:raw(path.join(__dirname,'language-review-proposal.json')),audit_raw_sha256:raw(path.join(__dirname,'machine-audit.json')),inventory_raw_sha256:raw(path.join(__dirname,'artifact-inventory.json')),reviewed_candidates:proposals.filter(row=>['contact','shift'].includes(row.text)).map(row=>({word:row.text,difficulty:row.candidate_entry.difficulty,json_sha256:row.reviewed_candidate_entry_json_sha256})),production_mutated:false,native_runtime_executed:false},null,2));
