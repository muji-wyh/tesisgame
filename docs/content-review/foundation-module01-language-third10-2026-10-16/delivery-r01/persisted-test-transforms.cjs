'use strict';
// Pure text transforms for root's later guarded test transaction. No files are written here.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const inputHashes=Object.freeze({'tests/professional-content.test.cjs':'fa09083e7759c279a1d02a0c39e8eb7706f84a9d153ac2574a2cc9f489d82960','tests/professional-retail-morphology.test.cjs':'4ad35b84a3a18661b467a697389965f5a55055d82e8bd72df2d13685b48b5a7b'});
const testPaths=Object.keys(inputHashes),hash=text=>crypto.createHash('sha256').update(text).digest('hex');
function once(text,needle,replacement){assert.equal(text.split(needle).length,2,'Exact unique test anchor: '+needle);return text.replace(needle,replacement);}
const helper=`function beforeFoundationThirdLanguage(entry) {
  const patch = foundationThirdLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later third-ten language, reference and note delta');
  return structuredClone(patch.before);
}`;
const mainTests=`

test('Foundation third ten install nine exact language candidates and sixteen scoped sources', () => {
  const record=foundationThirdLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(record.patches.length,9);assert.equal(record.sources.length,16);assert.equal(record.held.length,1);
  assert.equal(record.proposal.root_acceptance_raw_sha256,'a921f57e732ba3cf21540b087ed25eaf9da8f9dd1e3700937335b8bd6677f4ad');
  assert.equal(record.proposal.author_ledger_json_sha256,'4517fbb347f59056b589bc5dd7b26ce3b4b0255ca2ab2fad0b0241094756eb4d');
  assert.equal(record.proposal.accepted_memberships,180);assert.equal(record.proposal.preserved_selected_memberships,200);
  const protect=entry=>{const value=structuredClone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete value[key];for(const key of ['language','status','reviewer','reviewed_at'])delete value.review[key];return value;};
  let memberships=0,addedReferences=0;
  for(const patch of record.patches){
    const entry=source.lexemes.find(item=>item.id===patch.id),accepted=record.root_acceptance.accepted_candidates.find(item=>item.id===patch.id),author=record.author_ledger.proposals.find(item=>item.id===patch.id);
    assert.deepEqual(entry,patch.after);assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);assert.equal(hash(patch.accepted_author_candidate),accepted.candidate_json_sha256);assert.deepEqual(patch.accepted_author_candidate,author.candidate_entry);assert.equal(patch.reviewed_candidate_entry_json_sha256,accepted.candidate_json_sha256);
    for(const field of Object.keys(author.candidate_entry).filter(field=>!['review','references','editorial_notes'].includes(field)))assert.deepEqual(entry[field],author.candidate_entry[field]);
    assert.deepEqual(protect(entry),protect(patch.before));assert.equal(hash(protect(entry)),patch.protected_fields_sha256);assert.deepEqual(entry.accepted_forms,patch.before.accepted_forms);assert.deepEqual(entry.regions,patch.before.regions);assert.deepEqual(entry.morphology,patch.before.morphology);assert.deepEqual(entry.media,patch.before.media);
    assert.deepEqual(entry.review,{...patch.before.review,language:'reviewed',status:patch.before.review.domain==='not_required'?'reviewed':'pending',reviewer:record.reviewer,reviewed_at:'2026-10-16'});
    assert.deepEqual(entry.references.slice(0,patch.before.references.length),patch.before.references);const additions=entry.references.slice(patch.before.references.length);assert.deepEqual(additions.map(ref=>ref.source_id),patch.source_record_ids);addedReferences+=additions.length;
    for(const ref of additions){assert.equal(ref.status,'verified');assert.match(ref.scope,/No human, subject-matter, morphology, media, domain, expression or release approval is claimed/);}
    assert.equal(patch.editorial_note_transition.before_notes,patch.before.editorial_notes);assert.equal(patch.editorial_note_transition.author_candidate_notes,author.candidate_entry.editorial_notes);assert.equal(patch.editorial_note_transition.after_notes,entry.editorial_notes);assert.doesNotMatch(entry.editorial_notes,/Meaning, difficulty, imagery, and morphological classification remain editorial drafts|independent acceptance remains pending/);
    const current=source.courses.flatMap(course=>course.modules.filter(module=>module.lexeme_ids.includes(patch.id)).map(module=>({course_id:course.id,module_id:module.id})));assert.deepEqual(current,patch.memberships);memberships+=current.length;
    assert.equal(entry.morphology.review.status,'pending');assert.equal(entry.media.image.status,'pending');assert.equal(entry.media.audio.status,'pending');
  }
  assert.equal(memberships,180);assert.equal(addedReferences,16);
  for(const expected of record.sources){assert.deepEqual(source.sources.find(item=>item.id===expected.id),expected);assert.equal(expected.status,'consulted');assert.equal(expected.assets_acquired,false);assert.equal(expected.asset_license,null);}
  for(const item of record.retained_files)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,item.path))).digest('hex'),item.raw_sha256,item.path);
});

test('Foundation third ten retain the entire attendance hold and literal source difficulty evidence', () => {
  const record=foundationThirdLanguageRecord,held=record.held[0],byText=text=>record.patches.find(patch=>patch.after.text===text);
  assert.equal(held.id,'attendance.presence-record.n');assert.equal(held.decision,'preserve_entire_live_record_unchanged');assert.deepEqual(source.lexemes.find(entry=>entry.id===held.id),held.value);assert.equal(held.value.review.language,'pending');assert.equal(held.value.review.status,'pending');assert.equal(held.value.difficulty,'A2');assert.equal(held.production_reference_or_note_additions,0);assert.deepEqual(held.reason.observed_selected_source_labels,{oxford:'C1',collins:null});assert.equal(record.patches.some(patch=>patch.id===held.id),false);
  assert.deepEqual(record.proposal.excluded_source_ids,['foundation01-language-third10-oxford-attendance','foundation01-language-third10-collins-attendance']);for(const id of record.proposal.excluded_source_ids)assert.equal(source.sources.some(item=>item.id===id),false);
  assert.deepEqual(byText('overtime').difficulty.observed_selected_source_labels,{oxford:'C1',collins:'B2'});assert.equal(byText('overtime').after.difficulty,'B2');assert.equal(byText('overtime').after.example,'The team worked two hours of overtime on Friday.');
  assert.deepEqual(byText('break').difficulty.observed_selected_source_labels,{oxford:'A1'});assert.equal(byText('break').after.difficulty,'A2');
  for(const text of ['availability','update','reminder']){assert.deepEqual(byText(text).difficulty.observed_selected_source_labels,{oxford:null,collins:null});assert.equal(byText(text).after.difficulty,'B1');}
  assert.equal(byText('deadline').after.difficulty,'B2');assert.equal(byText('calendar').after.difficulty,'B1');assert.equal(byText('agenda').after.difficulty,'B2');assert.equal(byText('invitation').after.difficulty,'A2');for(const patch of record.patches)assert.equal(patch.difficulty.dictionary_level_certification,false);
  assert.deepEqual(record.patches.filter(patch=>patch.changed_fields.includes('definition')).map(patch=>patch.after.text),['break','availability','calendar','invitation','update']);assert.deepEqual(record.patches.filter(patch=>patch.changed_fields.includes('example')).map(patch=>patch.after.text),['overtime']);assert.equal(record.patches.filter(patch=>patch.changed_fields.includes('accepted_forms')).length,0);
  assert.equal(record.historical_source_consultations.consultations.length,18);assert.equal(record.author_ledger.proposals.find(row=>row.id===held.id).candidate_entry.review.language,'pending');
});

test('Foundation third ten preserve context, five ambiguity holds and every nonlanguage gate', () => {
  const record=foundationThirdLanguageRecord,context=record.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(context.expressions.length,57);assert.equal(context.modules.length,79);assert.equal(context.sources.length,116);assert.equal(context.held_entries.length,1);
  for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(source.lexemes.find(entry=>entry.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.expressions){assert.deepEqual(source.expressions.find(entry=>entry.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.modules)assert.deepEqual(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id),row.module);
  for(const row of context.sources){assert.deepEqual(source.sources.find(item=>item.id===row.source.id),row.source);assert.equal(hash(row.source),row.json_sha256);}
  let memberships=0;for(const row of context.selected_memberships){const current=source.courses.flatMap(course=>course.modules.filter(module=>module.lexeme_ids.includes(row.id)).map(module=>({course_id:course.id,module_id:module.id})));assert.deepEqual(current,row.memberships);memberships+=current.length;}assert.equal(memberships,200);
  for(const[file,sha]of Object.entries(context.growth_raw_sha256))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,file))).digest('hex'),sha);
  const review=context.context_review;assert.equal(review.uses.length,53);assert.equal(review.containing_module_memberships,186);assert.equal(review.selected_focus_expressions,6);assert.equal(review.other_local_expressions.length,4);assert.equal(review.related_entry_boundaries.length,58);
  for(const row of review.uses){assert.deepEqual(row.new_scored_bindings,[]);assert.equal(row.before_expression_json_sha256,row.after_expression_json_sha256);}
  const holds=review.uses.filter(row=>row.matches.some(match=>match.authored_classification_code.startsWith('hold_'))).map(row=>row.id).sort();assert.deepEqual(holds,['expr.customer_support.module07.08','expr.hospitality_tourism.module09.02','expr.hospitality_tourism.module09.08','expr.office_admin.module06.03','expr.transport_delivery.module09.06']);assert.deepEqual(record.proposal.expression_hold_ids,holds);
  assert.equal(review.related_entry_boundaries.find(row=>row.id==='policy-update.change-or-new-information-about-organizational-policy.n').classification,'report_change_hold');
  const release=auditProfessionalContent({data:source,release:true});assert.equal(release.summary.ready_modules,0);assert.equal(release.summary.release_ready,false);
});

test('Third-ten historical reversal rejects every unexpected later field change', () => {
  for(const patch of foundationThirdLanguageRecord.patches){
    assert.deepEqual(beforeFoundationThirdLanguage(patch.after),patch.before);assert.deepEqual(beforeFoundationSecondLanguage(patch.after),patch.before);
    const mutate=[entry=>{entry.definition+=' Unexpected change.';},entry=>{entry.accepted_forms.push('unexpected');},entry=>{entry.review.reviewer='unexpected';},entry=>{entry.references[0].scope+=' Unexpected change.';},entry=>{entry.morphology.review.status='reviewed';},entry=>{entry.media.audio.voice='unexpected';},entry=>{entry.editorial_notes+=' Unexpected change.';}];
    for(const change of mutate){const altered=structuredClone(patch.after);change(altered);assert.throws(()=>beforeFoundationThirdLanguage(altered));}
  }
  const held=foundationThirdLanguageRecord.held[0];assert.deepEqual(beforeFoundationThirdLanguage(held.value),held.value);
});
`;
const morphologyTest=`

test('Third-ten Foundation language reversal preserves pending Retail legacy morphology donors', () => {
  for(const id of ['update.current-information.n','reminder.memory-prompt.n']){
    const patch=foundationThirdLanguageRecord.patches.find(item=>item.id===id),entry=data.lexemes.find(item=>item.id===id);
    assert.deepEqual(entry,patch.after);assert.deepEqual(beforeFoundationThirdLanguage(entry),patch.before);assert.deepEqual(beforeFoundationLanguage(entry),patch.before);assert.deepEqual(entry.morphology,patch.before.morphology);assert.equal(entry.morphology.review.status,'pending');
    const wrong=structuredClone(entry);wrong.morphology.review.status='reviewed';assert.throws(()=>beforeFoundationThirdLanguage(wrong));
  }
  const attendance=foundationThirdLanguageRecord.held[0];assert.equal(attendance.id,'attendance.presence-record.n');assert.deepEqual(data.lexemes.find(item=>item.id===attendance.id),attendance.value);
});
`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const output={};
  for(const file of testPaths){let text=inputs[file];assert.equal(hash(text),inputHashes[file],'Exact post-barcode shared-test preimage '+file);const eol=text.includes('\r\n')?'\r\n':'\n',format=value=>value.replace(/\n/g,eol),variable=file===testPaths[0]?'rootDir':'root';
    const secondLine=file===testPaths[0]?"const foundationSecondLanguageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, 'data/professional/provenance/foundation-module01-language-second10-2026-10-16.json'), 'utf8'));":"const foundationSecondLanguageRecord = JSON.parse(fs.readFileSync(path.join(root, 'data/professional/provenance/foundation-module01-language-second10-2026-10-16.json')));";
    const thirdLine="const foundationThirdLanguageRecord = JSON.parse(fs.readFileSync(path.join("+variable+", 'data/professional/provenance/foundation-module01-language-third10-2026-10-16.json'), 'utf8'));";
    text=once(text,secondLine,secondLine+eol+thirdLine+eol+format(helper));text=once(text,'function beforeFoundationSecondLanguage(entry) {','function beforeFoundationSecondLanguage(entry) {'+eol+'  entry = beforeFoundationThirdLanguage(entry);');
    if(file===testPaths[0]){text=once(text,'...foundationLanguageRecord.patches, ...foundationSecondLanguageRecord.patches','...foundationLanguageRecord.patches, ...foundationSecondLanguageRecord.patches, ...foundationThirdLanguageRecord.patches');text=once(text,'assert.equal(result.summary.reviewed_lexemes, 81);','assert.equal(result.summary.reviewed_lexemes, 90);');text=once(text,'for(const row of context.lexemes){assert.deepEqual(source.lexemes.find(item=>item.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}','for(const row of context.lexemes){assert.deepEqual(beforeFoundationThirdLanguage(source.lexemes.find(item=>item.id===row.entry.id)),row.entry);assert.equal(hash(row.entry),row.json_sha256);}');text+=format(mainTests);}else text+=format(morphologyTest);
    output[file]=text;
  }
  return output;
}
module.exports={testPaths,inputHashes,transformTests};
if(require.main===module){
  assert.deepEqual(process.argv.slice(2),['--dry-run']);const fs=require('node:fs'),path=require('node:path'),lib=require('./delivery-lib.cjs');
  const inputs=Object.fromEntries(testPaths.map(file=>[file,fs.readFileSync(lib.inRoot(file),'utf8')])),output=transformTests(inputs);
  const plan=testPaths.map(file=>{const preview=path.join(__dirname,'preview',file);assert.equal(fs.readFileSync(preview,'utf8'),output[file],'Exact frozen test preview');return {path:file,before_raw_sha256:inputHashes[file],after_raw_sha256:hash(output[file]),preview:lib.relative(preview)};});
  console.log(JSON.stringify({status:'read_only_frozen_shared_test_transform_plan',production_mutated:false,shared_tests_mutated:false,tests_executed:false,native_executed:false,changes:plan},null,2));
}
