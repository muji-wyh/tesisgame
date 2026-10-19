'use strict';
const assert=require('node:assert/strict');
const testPaths=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd'];
const provenance='data/professional/provenance/foundation-module01-language-second10-2026-10-16.json';
function replace(text,before,after,count=1){assert.equal(text.split(before).length,count+1,'Expected exact test anchor: '+before.slice(0,150));return text.split(before).join(after);}
const reverseFunction=`function beforeFoundationSecondLanguage(entry) {
  const patch = foundationSecondLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later second-ten language, spelling, reference and note delta');
  return structuredClone(patch.before);
}`;
const addedTests=`
test('Foundation second ten language decisions retain exact root accepted candidates and thirteen sources', () => {
  const record=foundationSecondLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(record.patches.length,10);assert.equal(record.sources.length,13);assert.deepEqual(record.held,[]);
  assert.equal(record.proposal.root_acceptance_raw_sha256,'18b4e6af0afafc1f156184f309030dad3cde38370923addeb43c82d64603b922');
  assert.equal(record.proposal.independent_review_raw_sha256,'849fb6af65055e74802af8ad24ade1740dc4a9e75f7cfce38d205d2e06911202');
  assert.equal(record.proposal.coordinator_variant_raw_sha256,'4bb9d2f31a6711f5d3a1c7f8fb4eff2b50f54fbc67cb4333d7ea266f711a2be2');
  assert.equal(record.proposal.accepted_memberships,200);assert.equal(record.proposal.preserved_selected_memberships,200);
  const protect=entry=>{const out=structuredClone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete out[key];if(entry.id==='coordinator.organizer.n')delete out.accepted_forms;for(const key of ['language','status','reviewer','reviewed_at'])delete out.review[key];return out;};
  for(const patch of record.patches){
    const entry=source.lexemes.find(item=>item.id===patch.id),accepted=record.root_acceptance.accepted_candidates.find(item=>item.id===patch.id),decision=record.independent_review.decisions.find(item=>item.id===patch.id),candidate=patch.id===record.coordinator_variant.id?record.coordinator_variant.candidate_entry:decision.candidate_entry;
    assert.deepEqual(entry,patch.after);assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);assert.equal(hash(candidate),accepted.candidate_json_sha256);assert.equal(patch.reviewed_candidate_entry_json_sha256,accepted.candidate_json_sha256);
    for(const field of ['definition','example','difficulty'])assert.equal(entry[field],candidate[field]);assert.equal(entry.example,patch.before.example);
    assert.deepEqual(entry.accepted_forms,candidate.accepted_forms);assert.deepEqual(entry.regions,patch.before.regions);assert.deepEqual(protect(entry),protect(patch.before));assert.equal(hash(protect(entry)),patch.protected_fields_sha256);
    assert.deepEqual(entry.review,{...patch.before.review,language:'reviewed',status:patch.before.review.domain==='not_required'?'reviewed':'pending',reviewer:record.reviewer,reviewed_at:'2026-10-16'});
    assert.equal(entry.references.length,patch.before.references.length+patch.source_record_ids.length);assert.deepEqual(entry.references.slice(0,patch.before.references.length),patch.before.references);
    assert.deepEqual(entry.references.slice(patch.before.references.length).map(ref=>ref.source_id),patch.source_record_ids);
    for(const ref of entry.references.slice(patch.before.references.length)){assert.equal(ref.status,'verified');assert.match(ref.scope,/No human, subject-matter, morphology, media, domain, expression or release approval is claimed/);}
    assert.doesNotMatch(entry.editorial_notes,/Meaning, difficulty, imagery, and morphological classification remain editorial drafts|independent acceptance remains pending/);
    assert.deepEqual(entry.morphology,patch.before.morphology);assert.deepEqual(entry.media,patch.before.media);assert.equal(entry.morphology.review.status,'pending');assert.equal(entry.media.image.status,'pending');assert.equal(entry.media.audio.status,'pending');
  }
  for(const expected of record.sources){assert.deepEqual(source.sources.find(item=>item.id===expected.id),expected);assert.equal(expected.status,'consulted');assert.equal(expected.assets_acquired,false);assert.equal(expected.asset_license,null);}
  for(const item of record.retained_files)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,item.path))).digest('hex'),item.raw_sha256,item.path);
});

test('Foundation second ten preserve literal source levels and the separately reviewed British spelling', () => {
  const record=foundationSecondLanguageRecord,byText=text=>record.patches.find(item=>item.after.text===text);
  assert.equal(byText('contact').after.difficulty,'B2');assert.deepEqual(byText('contact').difficulty.observed_selected_source_labels,{oxford:null,collins:'B1+'});
  assert.equal(byText('shift').after.difficulty,'B1');assert.deepEqual(byText('shift').difficulty.observed_selected_source_labels,{oxford:'B1',merriam:null,collins:'B2'});
  assert.equal(byText('meeting').after.difficulty,'A2');assert.deepEqual(byText('meeting').difficulty.observed_selected_source_labels,{oxford:'A1'});
  for(const text of ['contractor','supplier','coordinator'])assert.deepEqual(byText(text).difficulty.observed_selected_source_labels,{oxford:null});
  assert.equal(byText('contractor').after.difficulty,'A2');assert.equal(byText('supplier').after.difficulty,'A2');assert.equal(byText('coordinator').after.difficulty,'B1');
  assert.equal(byText('trainee').after.difficulty,'B2');assert.equal(byText('appointment').after.difficulty,'B1');
  for(const patch of record.patches)assert.equal(patch.difficulty.dictionary_level_certification,false);
  const coordinator=byText('coordinator');assert.deepEqual(coordinator.before.accepted_forms,['coordinator']);assert.deepEqual(coordinator.after.accepted_forms,['coordinator','co-ordinator']);assert.deepEqual(coordinator.after.regions,['general']);
  assert.equal(coordinator.after.text,'coordinator');assert.equal(coordinator.after.display_text,'coordinator');assert.equal(coordinator.after.morphology.text,'coordinator');assert.deepEqual(coordinator.after.media,coordinator.before.media);
  assert.equal(coordinator.reviewed_candidate_entry_json_sha256,'4418216d47c4ddf15bd3b253d8951ff1fabf3ee0e491c6a3d9fe3cb66b0e1047');
  assert.deepEqual(record.independent_review.pending_full_language_gates,['coordinator.organizer.n']);assert.equal(record.independent_review.decisions.find(row=>row.id===coordinator.id).full_language_gate_decision,'hold_pending_spelling');
  assert.deepEqual(record.coordinator_variant.changed_fields,['accepted_forms']);assert.equal(record.proposal.historical_hold_resolution.parent_review_preserved,true);
  assert.deepEqual(record.patches.filter(p=>p.changed_fields.includes('accepted_forms')).map(p=>p.id),['coordinator.organizer.n']);assert.deepEqual(record.patches.filter(p=>p.changed_fields.includes('definition')).map(p=>p.after.text),['trainee','supplier','shift']);assert.equal(record.patches.filter(p=>p.changed_fields.includes('example')).length,0);
});

test('Foundation second ten preserve every context and all unresolved sense bindings', () => {
  const context=foundationSecondLanguageRecord.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(context.lexemes.length,154);assert.equal(new Set(context.lexemes.map(row=>row.entry.id)).size,153);assert.equal(context.expressions.length,118);assert.equal(context.modules.length,108);assert.equal(context.sources.length,133);
  for(const row of context.lexemes){assert.deepEqual(source.lexemes.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.expressions){assert.deepEqual(source.expressions.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.modules)assert.deepEqual(source.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id),row.module);
  for(const row of context.sources){assert.deepEqual(source.sources.find(item=>item.id===row.source.id),row.source);assert.equal(hash(row.source),row.json_sha256);}
  let memberships=0;for(const row of context.selected_memberships){const current=source.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(row.id)).map(m=>({course_id:c.id,module_id:m.id})));assert.deepEqual(current,row.memberships);memberships+=current.length;}assert.equal(memberships,200);
  for(const[file,sha]of Object.entries(context.growth_raw_sha256))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,file))).digest('hex'),sha);
  const uses=context.context_review;assert.equal(uses.uses.length,114);assert.equal(uses.containing_memberships,266);assert.equal(uses.selected_focus_expressions,6);assert.equal(uses.other_local_expressions.length,4);
  for(const use of uses.uses){assert.equal(use.decision,'preserve_exact_no_whole_expression_acceptance');assert.deepEqual(use.new_scored_bindings,[]);for(const match of use.matches)assert.deepEqual(match.new_scored_bindings,[]);}
  const withCode=code=>uses.uses.filter(row=>row.matches.some(match=>match.reviewer_classification_code===code)).map(row=>row.id).sort();
  assert.deepEqual(withCode('supplier_scope'),['expr.accounting_finance.module05.07','expr.accounting_finance.module09.10','expr.manufacturing_maintenance.module05.06','expr.manufacturing_maintenance.module05.08','expr.office_admin.module07.10','expr.office_admin.module10.04']);
  assert.deepEqual(withCode('ambiguous'),['expr.office_admin.module10.08','expr.sales_marketing.module10.09']);assert.equal(withCode('physical').length,3);
  assert.deepEqual(withCode('financial_schedule'),['expr.accounting_finance.module09.07']);assert.deepEqual(withCode('rendezvous'),['expr.hospitality_tourism.module07.05']);assert.deepEqual(withCode('platform_access'),['expr.legal_paralegal.module09.09']);
  const release=auditProfessionalContent({data:source,release:true});assert.equal(release.summary.ready_modules,0);assert.equal(release.summary.release_ready,false);
});

test('Foundation historical reversal refuses unexpected later field drift', () => {
  for(const patch of foundationSecondLanguageRecord.patches){
    assert.deepEqual(beforeFoundationSecondLanguage(patch.after),patch.before);
    const wrongDefinition=structuredClone(patch.after);wrongDefinition.definition+=' Unexpected change.';assert.throws(()=>beforeFoundationSecondLanguage(wrongDefinition));
    const wrongMorphology=structuredClone(patch.after);wrongMorphology.morphology.review.status='reviewed';assert.throws(()=>beforeFoundationSecondLanguage(wrongMorphology));
  }
  const coordinator=structuredClone(foundationSecondLanguageRecord.patches.find(p=>p.id==='coordinator.organizer.n').after);coordinator.accepted_forms=['coordinator'];assert.throws(()=>beforeFoundationSecondLanguage(coordinator));
});
`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const outputs={};
  for(const file of testPaths){const newline=inputs[file].includes('\r\n')?'\r\n':'\n';let text=inputs[file].replaceAll('\r\n','\n');assert.equal(text.includes(provenance),false,'Second-ten language test update is one-shot');
    if(file.endsWith('/professional-content.test.cjs')){
      const anchor='const foundationLanguageAcceptedIds = new Set(foundationLanguageRecord.patches.map(item => item.id));';
      text=replace(text,anchor,"const foundationSecondLanguageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '"+provenance+"'), 'utf8'));\nconst foundationLanguageAcceptedIds = new Set([...foundationLanguageRecord.patches, ...foundationSecondLanguageRecord.patches].map(item => item.id));\n"+reverseFunction);
      text=replace(text,'assert.equal(result.summary.reviewed_lexemes, 71);','assert.equal(result.summary.reviewed_lexemes, 81);');
      text=replace(text,'for(const row of protectedContext.lexemes){assert.deepEqual(source.lexemes.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}','for(const row of protectedContext.lexemes){assert.deepEqual(beforeFoundationSecondLanguage(source.lexemes.find(item=>item.id===row.entry.id)),row.entry);assert.equal(hash(row.entry),row.json_sha256);}');
      text+=addedTests;
    }else if(file.endsWith('/professional-retail-morphology.test.cjs')){
      text=replace(text,'function beforeFoundationLanguage(entry) {',"const foundationSecondLanguageRecord = JSON.parse(fs.readFileSync(path.join(root, '"+provenance+"')));\n"+reverseFunction+'\nfunction beforeFoundationLanguage(entry) {\n  entry = beforeFoundationSecondLanguage(entry);');
      text=replace(text,'function beforeCounterImage(entry) {\n','function beforeCounterImage(entry) {\n  entry = beforeFoundationSecondLanguage(entry);\n');
      text=replace(text,'for (const row of r.protected_related_entries) assert.deepEqual(data.lexemes.find(e => e.id === row.entry.id), row.entry);','for (const row of r.protected_related_entries) assert.deepEqual(beforeFoundationSecondLanguage(data.lexemes.find(e => e.id === row.entry.id)), row.entry);');
    }else{
      const anchor='\tcheck(current.size() == 1 and current[0] == rows[0].entry, "Retail04 protected actual record remains exact: " + id)\n\treturn current[0].morphology if current.size() == 1 else {}';
      const replacement='\tcheck(current.size() == 1, "Retail04 actual protected record exists: " + id)\n\tif current.size() != 1:\n\t\treturn {}\n\tvar comparable: Dictionary = current[0]\n\tif id == "appointment.arranged-meeting.n":\n\t\tvar language_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://'+provenance+'"))\n\t\tvar language_patches: Array = language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == id)\n\t\tcheck(language_patches.size() == 1, "Exactly one second-ten appointment language patch is retained")\n\t\tif language_patches.size() != 1:\n\t\t\treturn {}\n\t\tvar language_patch: Dictionary = language_patches[0]\n\t\tcheck(comparable == language_patch.after, "Live appointment equals the exact later language record")\n\t\tif comparable != language_patch.after:\n\t\t\treturn {}\n\t\tcomparable = language_patch.before.duplicate(true)\n\tcheck(comparable == rows[0].entry, "Retail04 protected actual record remains exact after scoped language reversal: " + id)\n\tif comparable != rows[0].entry:\n\t\treturn {}\n\treturn current[0].morphology';
      text=replace(text,anchor,replacement);
    }
    outputs[file]=text.replaceAll('\n',newline);
  }return outputs;
}
module.exports={testPaths,transformTests};
