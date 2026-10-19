'use strict';
// Pure text transformations. Root owns the guarded write and all test execution.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const inputHashes=Object.freeze({'tests/professional-content.test.cjs':'81cba7943627748dfbd776efe15e7ec593d025268500469b42e382a8c3c25a22','tests/professional-retail-morphology.test.cjs':'647bc28e65369af25e3845bb4e5bf597ba693aad8d1bcdbfef00738afbec1868'});
const testPaths=Object.keys(inputHashes),hash=text=>crypto.createHash('sha256').update(text).digest('hex');
function once(text,needle,replacement){assert.equal(text.split(needle).length,2,'Exact unique test anchor: '+needle);return text.replace(needle,replacement);}
const helper=String.raw`function beforeFoundationFourthLanguage(entry) {
  const patch = foundationFourthLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later fourth-ten language, reference and note delta');
  return structuredClone(patch.before);
}`;
const mainTests=String.raw`

test('Foundation fourth ten install ten exact language candidates and twenty scoped sources', () => {
  const record=foundationFourthLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(record.patches.length,10);assert.equal(record.sources.length,20);assert.equal(record.held.length,2);
  assert.equal(record.proposal.root_acceptance_raw_sha256,'8d9bb9b255f29580cee19684bd3b5b1bfaa1bdc4c301bb932bebc46f3866ed0c');
  assert.equal(record.proposal.author_ledger_json_sha256,'7b0912391dfa6f852769379622f23ed6a764d3f0f86fe1c798deae0ba04d32e8');
  assert.equal(record.proposal.accepted_memberships,200);assert.equal(record.proposal.preserved_selected_memberships,200);
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
  assert.equal(memberships,200);assert.equal(addedReferences,20);
  for(const expected of record.sources){assert.deepEqual(source.sources.find(item=>item.id===expected.id),expected);assert.equal(expected.status,'consulted');assert.equal(expected.assets_acquired,false);assert.equal(expected.asset_license,null);}
  for(const item of record.retained_files)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,item.path))).digest('hex'),item.raw_sha256,item.path);
});


test('Foundation fourth ten preserve literal levels and contrast-only voicemail evidence', () => {
  const r=foundationFourthLanguageRecord,byText=text=>r.patches.find(p=>p.after.text===text),consult=id=>r.historical_source_consultations.consultations.find(s=>s.id==='foundation01-language-fourth10-'+id);
  for(const text of ['announcement','greeting']){assert.deepEqual(byText(text).difficulty.observed_selected_source_labels,{oxford:null,collins:'B1+'});assert.equal(byText(text).after.difficulty,'B2');assert.equal(consult('collins-'+text).observed_selected_sense_level,'B1+');}
  assert.deepEqual(byText('extension').difficulty.observed_selected_source_labels,{oxford:'C1',collins:'B2'});assert.equal(byText('extension').after.difficulty,'B2');
  assert.deepEqual(byText('voicemail').difficulty.observed_selected_source_labels,{oxford:null,collins:null,mw:null});assert.equal(byText('voicemail').after.difficulty,'B1');assert.deepEqual(consult('oxford-voicemail').other_sense_labels_not_applied,{recording_system:'B1'});
  for(const source of ['oxford','collins']){const ref=byText('voicemail').after.references.find(ref=>ref.source_id==='foundation01-language-fourth10-'+source+'-voicemail');assert.match(ref.scope,/Verified contrast-only recording-system consultation/);assert.match(ref.scope,/does not independently support the selected countable-message definition or its editorial difficulty/);assert.equal(consult(source+'-voicemail').observed_selected_sense_level,null);}
  assert.match(consult('mw-voicemail').finding,/single message/);assert.equal(consult('mw-voicemail').observed_selected_sense_level,null);
  assert.deepEqual(byText('introduction').difficulty.observed_selected_source_labels,{oxford:null,collins:null});assert.equal(byText('introduction').after.difficulty,'B1');assert.deepEqual(consult('oxford-introduction').other_sense_labels_not_applied,{book_or_speech_opening:'A2'});assert.deepEqual(consult('collins-introduction').other_sense_labels_not_applied,{book_or_talk_opening:'B2',introductory_subject_book:'B2'});
  for(const text of ['message','phone call']){assert.deepEqual(byText(text).difficulty.observed_selected_source_labels,{oxford:'A1',collins:'A1'});assert.equal(byText(text).after.difficulty,'A2');}
  assert.deepEqual(byText('email').difficulty.observed_selected_source_labels,{oxford:null,collins:'A1'});assert.equal(byText('email').after.difficulty,'A2');assert.deepEqual(byText('conversation').difficulty.observed_selected_source_labels,{oxford:null,collins:'A2'});assert.deepEqual(byText('discussion').difficulty.observed_selected_source_labels,{oxford:'A2'});
  assert.equal(byText('announcement').after.definition,'A spoken or written statement that gives information to a group of people.');assert.equal(byText('voicemail').after.definition,'A spoken message recorded in a phone messaging system for someone to hear later.');assert.equal(byText('conversation').after.definition,'A usually informal exchange of spoken information or ideas between people.');assert.equal(byText('introduction').after.example,'The manager made an introduction so that the two new colleagues could meet.');
  assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('definition')).map(p=>p.after.text),['announcement','voicemail','conversation']);assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('example')).map(p=>p.after.text),['introduction']);assert.deepEqual(r.patches.filter(p=>p.changed_fields.includes('difficulty')).map(p=>p.after.text),['announcement','voicemail','extension','introduction','greeting']);
  for(const patch of r.patches)assert.equal(patch.difficulty.dictionary_level_certification,false);
  assert.equal(r.historical_source_consultations.consultations.length,20);assert.equal(r.historical_source_consultations.failed_accesses.length,3);for(const failed of r.historical_source_consultations.failed_accesses){assert.equal(failed.source_evidence_used,false);assert.equal(failed.level_or_meaning_inferred,false);assert.equal(r.sources.some(s=>s.url===failed.url),false);}
});

test('Foundation fourth ten preserve prior entry holds and all current and prior expression holds', () => {
  const r=foundationFourthLanguageRecord,context=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.deepEqual(r.held.map(row=>row.id),['supervisor.work-overseer.n','attendance.presence-record.n']);
  for(const held of r.held){assert.deepEqual(source.lexemes.find(e=>e.id===held.id),held.value);assert.equal(hash(held.value),held.json_sha256);assert.equal(held.value.difficulty,'A2');assert.equal(held.value.review.language,'pending');assert.equal(held.value.review.status,'pending');assert.equal(held.production_reference_or_note_additions,0);assert.equal(r.patches.some(p=>p.id===held.id),false);}
  assert.deepEqual(r.proposal.excluded_source_ids,['foundation01-language-third10-oxford-attendance','foundation01-language-third10-collins-attendance']);for(const id of r.proposal.excluded_source_ids)assert.equal(source.sources.some(s=>s.id===id),false);
  assert.equal(context.expressions.length,58);assert.equal(context.modules.length,57);assert.equal(context.sources.length,89);assert.equal(context.held_entries.length,2);
  for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(source.lexemes.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.expressions){assert.deepEqual(source.expressions.find(e=>e.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  for(const row of context.modules)assert.deepEqual(source.courses.find(c=>c.id===row.course_id).modules.find(m=>m.id===row.module_id),row.module);
  for(const row of context.sources){assert.deepEqual(source.sources.find(s=>s.id===row.source.id),row.source);assert.equal(hash(row.source),row.json_sha256);}
  let memberships=0;for(const row of context.selected_memberships){const current=source.courses.flatMap(c=>c.modules.filter(m=>m.lexeme_ids.includes(row.id)).map(m=>({course_id:c.id,module_id:m.id})));assert.deepEqual(current,row.memberships);memberships+=current.length;}assert.equal(memberships,200);
  for(const[file,sha]of Object.entries({...context.growth_raw_sha256,...context.prior_artifacts_raw_sha256}))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,file))).digest('hex'),sha,file);
  const review=context.context_review;assert.equal(review.uses.length,46);assert.equal(review.containing_module_memberships,103);assert.equal(review.selected_focus_expressions,3);assert.equal(review.other_local_expressions.length,7);assert.equal(review.related_entry_boundaries.length,40);assert.equal(review.all_selected_containing_module_expressions.modules.length,20);assert.equal(review.all_selected_containing_module_expressions.unique_expression_ids.length,10);assert.equal(review.all_selected_containing_module_expressions.all_expressions_captured,true);
  const holds=review.uses.filter(row=>row.matches.some(m=>m.authored_classification_code.startsWith('hold_'))).map(row=>row.id).sort();assert.deepEqual(holds,['expr.foundation.module01.03','expr.foundation.module01.08','expr.hospitality_tourism.module05.04','expr.office_admin.module05.07']);assert.deepEqual(r.proposal.expression_hold_ids,holds);
  const prior=['expr.customer_support.module07.08','expr.hospitality_tourism.module09.02','expr.hospitality_tourism.module09.08','expr.office_admin.module06.03','expr.transport_delivery.module09.06'];assert.deepEqual(review.prior_third10_expression_hold_ids,prior);assert.deepEqual(r.proposal.prior_expression_hold_ids,prior);assert.deepEqual(review.prior_third10_expression_holds_preserved.map(row=>row.id),prior);
  for(const row of review.uses){assert.deepEqual(row.new_scored_bindings,[]);assert.equal(row.before_expression_json_sha256,row.after_expression_json_sha256);}
  for(const row of review.prior_third10_expression_holds_preserved){assert.deepEqual(source.expressions.find(e=>e.id===row.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}
  const release=auditProfessionalContent({data:source,release:true});assert.equal(release.summary.ready_modules,0);assert.equal(release.summary.release_ready,false);
});

test('Fourth-ten historical reversal refuses arbitrary field changes and requires committed R25 lineage', () => {
  const r=foundationFourthLanguageRecord;
  for(const patch of r.patches){
    assert.deepEqual(beforeFoundationFourthLanguage(patch.after),patch.before);assert.deepEqual(beforeFoundationThirdLanguage(patch.after),patch.before);assert.deepEqual(beforeFoundationSecondLanguage(patch.after),patch.before);
    const mutate=[e=>{e.definition+=' Unexpected.';},e=>{e.accepted_forms.push('unexpected');},e=>{e.review.reviewer='unexpected';},e=>{e.references[0].scope+=' Unexpected.';},e=>{e.morphology.review.status='reviewed';},e=>{e.media.audio.voice='unexpected';},e=>{e.editorial_notes+=' Unexpected.';},e=>{e.regions.push('US');}];for(const change of mutate){const altered=structuredClone(patch.after);change(altered);assert.throws(()=>beforeFoundationFourthLanguage(altered));}
  }
  for(const held of r.held)assert.deepEqual(beforeFoundationFourthLanguage(held.value),held.value);
  assert.equal(r.lineage.validation.path,'build/professional-english/continuation-validation-r25.json');assert.equal(r.lineage.validation.raw_sha256,'15d98eef33b5b27d00ac6852ef63c9213f24679a491cfd9c0163679abeba8012');
  const raw=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(rootDir,file))).digest('hex');assert.equal(raw(r.lineage.validation.path),r.lineage.validation.raw_sha256);assert.equal(JSON.parse(fs.readFileSync(path.join(rootDir,r.lineage.validation.path))).ok,true);
  const transaction=r.integration_guards.transaction_path,states=fs.readdirSync(path.join(rootDir,transaction,'states')).filter(f=>/^\d{6}-[a-z-]+\.json$/.test(f)).sort(),committed=JSON.parse(fs.readFileSync(path.join(rootDir,transaction,'states',states.at(-1))));assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,raw(transaction+'/prepared.json'));
});
`;
const morphologyTest=String.raw`

test('Fourth-ten Foundation reversal preserves exact historical Retail donor snapshots', () => {
  for(const [id,record]of [['greeting.welcome-message.n',fifthRecord],['announcement.public-message.n',retail04FirstRecord]]){
    const patch=foundationFourthLanguageRecord.patches.find(p=>p.id===id),entry=data.lexemes.find(e=>e.id===id),historical=record.protected_related_entries.find(row=>row.entry.id===id);
    assert.deepEqual(entry,patch.after);assert.deepEqual(beforeFoundationFourthLanguage(entry),patch.before);assert.deepEqual(beforeFoundationLanguage(entry),historical.entry);assert.deepEqual(entry.morphology,historical.entry.morphology);assert.equal(entry.morphology.review.status,'pending');
    const wrong=structuredClone(entry);wrong.morphology.review.status='reviewed';assert.throws(()=>beforeFoundationFourthLanguage(wrong));
  }
  for(const patch of foundationFourthLanguageRecord.patches){assert.deepEqual(data.lexemes.find(e=>e.id===patch.id).morphology,patch.before.morphology);assert.equal(patch.after.morphology.review.status,'pending');}
});
`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const output={};
  for(const file of testPaths){let text=inputs[file];assert.equal(hash(text),inputHashes[file],'Exact successful R25 shared-test preimage '+file);const eol=text.includes('\r\n')?'\r\n':'\n',format=value=>value.replace(/\r?\n/g,eol),variable=file===testPaths[0]?'rootDir':'root';
    const thirdLine="const foundationThirdLanguageRecord = JSON.parse(fs.readFileSync(path.join("+variable+", 'data/professional/provenance/foundation-module01-language-third10-2026-10-16.json'), 'utf8'));";
    const fourthLine="const foundationFourthLanguageRecord = JSON.parse(fs.readFileSync(path.join("+variable+", 'data/professional/provenance/foundation-module01-language-fourth10-2026-10-16.json'), 'utf8'));";
    text=once(text,thirdLine,thirdLine+eol+fourthLine+eol+format(helper));text=once(text,'function beforeFoundationThirdLanguage(entry) {','function beforeFoundationThirdLanguage(entry) {'+eol+'  entry = beforeFoundationFourthLanguage(entry);');
    if(file===testPaths[0]){
      const correction='const entry = beforeRetail04Third10(source.lexemes.find(item => item.id === patch.id)), decision = record.independent_acceptance.accepted_pairs.find(item => item.pair[0] === patch.id);';assert.equal(text.split(correction).length,2,'Root R24 picture-exclusion correction present');
      text=once(text,'...foundationLanguageRecord.patches, ...foundationSecondLanguageRecord.patches, ...foundationThirdLanguageRecord.patches','...foundationLanguageRecord.patches, ...foundationSecondLanguageRecord.patches, ...foundationThirdLanguageRecord.patches, ...foundationFourthLanguageRecord.patches');text=once(text,'assert.equal(result.summary.reviewed_lexemes, 90);','assert.equal(result.summary.reviewed_lexemes, 100);');
      text=once(text,'for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(source.lexemes.find(entry=>entry.id===row.entry.id),row.entry);assert.equal(hash(row.entry),row.json_sha256);}','for(const row of [...context.lexemes,...context.held_entries]){assert.deepEqual(beforeFoundationFourthLanguage(source.lexemes.find(entry=>entry.id===row.entry.id)),row.entry);assert.equal(hash(row.entry),row.json_sha256);}');
      text+=format(mainTests);assert.equal(text.split(correction).length,2,'Root correction preserved exactly');
    }else text+=format(morphologyTest);
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
