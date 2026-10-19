'use strict';
const assert=require('node:assert/strict');
const testPaths=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd'];
const provenance='data/professional/provenance/foundation-module01-language-first10-2026-10-16.json';
function replace(text,before,after,count=1){assert.equal(text.split(before).length,count+1,'Expected exact test anchor: '+before.slice(0,150));return text.split(before).join(after);}
const reverseFunction=`function beforeFoundationLanguage(entry) {
  const patch = foundationLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later Foundation language, reference and note delta');
  return structuredClone(patch.before);
}`;
const addedTests=`
test('Foundation nine accepted language records retain exact candidates, sources and separate gates', () => {
  const record=foundationLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(record.patches.length,9);assert.equal(record.sources.length,9);assert.equal(record.held.length,1);
  assert.equal(record.proposal.root_acceptance_raw_sha256,'7963a7d82f34d00af2b54a6b25a8b9d1b631e8f9c0a56438e61e95c28b211e8c');
  assert.equal(record.proposal.independent_review_raw_sha256,'5c2b512b3869514919f24f7e1ac569436d8e9487edf5d7572ea9f5702fb6dde6');
  assert.equal(record.proposal.accepted_memberships,180);assert.equal(record.proposal.preserved_selected_memberships,200);
  const protect=entry=>{const out=structuredClone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete out[key];for(const key of ['language','status','reviewer','reviewed_at'])delete out.review[key];return out;};
  for(const patch of record.patches){
    const entry=source.lexemes.find(item=>item.id===patch.id),accepted=record.root_acceptance.accepted.find(item=>item.id===patch.id),decision=record.independent_review.decisions.find(item=>item.id===patch.id);
    assert.deepEqual(entry,patch.after);assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);
    assert.equal(hash(decision.candidate_entry),accepted.candidate_entry_json_sha256);assert.equal(patch.reviewed_candidate_entry_json_sha256,accepted.candidate_entry_json_sha256);
    for(const field of ['definition','example','difficulty'])assert.equal(entry[field],decision.candidate_entry[field]);
    assert.deepEqual(protect(entry),protect(patch.before));assert.equal(hash(protect(entry)),patch.protected_fields_sha256);
    assert.deepEqual(entry.review,{...patch.before.review,language:'reviewed',status:patch.before.review.domain==='not_required'?'reviewed':'pending',reviewer:record.reviewer,reviewed_at:'2026-10-16'});
    assert.equal(entry.references.length,patch.before.references.length+1);assert.deepEqual(entry.references.slice(0,-1),patch.before.references);
    assert.equal(entry.references.at(-1).status,'verified');assert.equal(entry.references.at(-1).source_id,patch.source_record_ids[0]);assert.match(entry.references.at(-1).scope,/No human, subject-matter, morphology, media, domain, expression or release approval is claimed/);
    assert.doesNotMatch(entry.editorial_notes,/Meaning, difficulty, imagery, and morphological classification remain editorial drafts|independent acceptance remains pending/);
    assert.equal(entry.morphology.review.status,'pending');assert.equal(entry.media.image.status,'pending');assert.equal(entry.media.audio.status,'pending');
  }
  for(const expected of record.sources){assert.deepEqual(source.sources.find(item=>item.id===expected.id),expected);assert.equal(expected.status,'consulted');assert.equal(expected.assets_acquired,false);assert.equal(expected.asset_license,null);}
  for(const item of record.retained_files)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,item.path))).digest('hex'),item.raw_sha256,item.path);
});

test('Foundation supervisor hold and editorial difficulty distinctions remain explicit', () => {
  const record=foundationLanguageRecord,held=record.held[0],byText=text=>record.patches.find(item=>item.after.text===text);
  assert.equal(held.id,'supervisor.work-overseer.n');assert.equal(held.decision,'preserve_entire_live_record_unchanged');assert.deepEqual(source.lexemes.find(item=>item.id===held.id),held.value);
  assert.equal(held.value.review.language,'pending');assert.equal(held.value.review.status,'pending');assert.equal(held.value.difficulty,'A2');assert.equal(held.reason.observed_selected_source_label,'C1');
  assert.match(held.wording_only_acceptance,/wording only/);assert.match(held.required_resolution,/separately reviewed difficulty or curriculum policy decision/);
  assert.equal(byText('client').after.definition,'A person or organization that receives professional advice or services.');assert.equal(byText('client').after.difficulty,'B1');assert.equal(byText('client').difficulty.observed_selected_source_label,'B1');
  assert.equal(byText('team').difficulty.observed_selected_source_label,null);assert.match(byText('team').difficulty.independent_editorial_basis,/Independent editorial placement/);
  for(const text of ['customer','visitor']){assert.equal(byText(text).after.difficulty,'A2');assert.equal(byText(text).difficulty.observed_selected_source_label,'A1');assert.equal(byText(text).difficulty.dictionary_level_certification,false);}
  assert.equal(source.sources.some(item=>item.id==='foundation01-language-first10-oxford-supervisor'),false);
  assert.equal(source.sources.some(item=>item.id==='foundation01-language-first10-oxford-supervise'),false);
  assert.equal(source.sources.some(item=>item.id==='foundation01-language-first10-collins-supervisor'),false);
});

test('Foundation language acceptance preserves all context and creates no expression or scoring approval', () => {
  const protectedContext=foundationLanguageRecord.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(protectedContext.lexemes.length,178);assert.equal(new Set(protectedContext.lexemes.map(item=>item.entry.id)).size,177);assert.equal(protectedContext.expressions.length,169);assert.equal(protectedContext.modules.length,126);assert.equal(protectedContext.sources.length,158);
  for(const row of protectedContext.lexemes){assert.deepEqual(source.lexemes.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of protectedContext.expressions){assert.deepEqual(source.expressions.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of protectedContext.modules)assert.deepEqual(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id),row.module);
  for(const row of protectedContext.sources){assert.deepEqual(source.sources.find(item=>item.id===row.source.id),row.source);assert.equal(hash(row.source),row.json_sha256);}
  let memberships=0;for(const row of protectedContext.selected_memberships){const current=source.courses.flatMap(course=>course.modules.filter(module=>module.lexeme_ids.includes(row.id)).map(module=>({course_id:course.id,module_id:module.id})));assert.deepEqual(current,row.memberships);memberships+=current.length;}assert.equal(memberships,200);
  for(const[file,sha]of Object.entries(protectedContext.growth_raw_sha256))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,file))).digest('hex'),sha);
  const contexts=protectedContext.context_review;assert.equal(contexts.uses.length,167);assert.equal(contexts.containing_memberships,357);assert.equal(contexts.selected_focus_expressions,8);assert.equal(contexts.other_local_expressions.length,2);
  for(const use of contexts.uses){assert.equal(use.decision,'preserve_exact_no_whole_expression_acceptance');assert.deepEqual(use.new_scored_bindings,[]);}
  assert.deepEqual(contexts.uses.filter(item=>item.classification==='exclude_software_manager').map(item=>item.id).sort(),['expr.hospitality_tourism.module09.02','expr.it_support.module09.08','expr.software_data.equipment.04']);
  assert.deepEqual(contexts.uses.filter(item=>item.classification==='hold_background_sense_binding').map(item=>item.id).sort(),['expr.sales_marketing.module05.09','expr.sales_marketing.module07.06']);
  const release=auditProfessionalContent({data:source,release:true});assert.equal(release.summary.ready_modules,0);assert.equal(release.summary.release_ready,false);
});
`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const outputs={};
  for(const file of testPaths){const newline=inputs[file].includes('\r\n')?'\r\n':'\n';let text=inputs[file].replaceAll('\r\n','\n');assert.equal(text.includes(provenance),false,'Foundation language test update is one-shot');
    if(file.endsWith('/professional-content.test.cjs')){
      const anchor='const source = loadProfessionalContent(rootDir);';text=replace(text,anchor,anchor+"\nconst foundationLanguageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '"+provenance+"'), 'utf8'));\nconst foundationLanguageAcceptedIds = new Set(foundationLanguageRecord.patches.map(item => item.id));");
      text=replace(text,"    assert.equal(entry.review.status,'pending');assert.equal(entry.media.image.status,'pending');assert.equal(entry.media.image.path,null);","    assert.equal(entry.review.status,foundationLanguageAcceptedIds.has(entry.id)?'reviewed':'pending');assert.equal(entry.review.language,foundationLanguageAcceptedIds.has(entry.id)?'reviewed':'pending');assert.equal(entry.media.image.status,'pending');assert.equal(entry.media.image.path,null);");text+=addedTests;
    }else if(file.endsWith('/professional-retail-morphology.test.cjs')){
      const anchor="const root = path.resolve(__dirname, '..');";text=replace(text,anchor,anchor+"\nconst foundationLanguageRecord = JSON.parse(fs.readFileSync(path.join(root, '"+provenance+"')));\n"+reverseFunction);
      text=replace(text,'function beforeRetailMedia(entry) {\n','function beforeRetailMedia(entry) {\n  entry = beforeFoundationLanguage(entry);\n');
    }else{
      const anchor='\t\tcheck(entry == snapshot.entry, "Persisted legacy entry equals its protected preimage: " + id)';
      const replacement='\t\tif id == "customer.buyer.n":\n\t\t\tvar language_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://'+provenance+'"))\n\t\t\tvar language_patches: Array = language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == id)\n\t\t\tcheck(language_patches.size() == 1, "Exactly one scoped Foundation customer language patch is retained")\n\t\t\tif language_patches.size() != 1:\n\t\t\t\treturn\n\t\t\tvar language_patch: Dictionary = language_patches[0]\n\t\t\tcheck(entry == language_patch.after, "Live customer equals the exact later Foundation language entry")\n\t\t\tif entry != language_patch.after:\n\t\t\t\treturn\n\t\t\tentry = language_patch.before.duplicate(true)\n'+anchor;
      text=replace(text,anchor,replacement);
    }
    outputs[file]=text.replaceAll('\n',newline);
  }return outputs;
}
module.exports={testPaths,transformTests};
