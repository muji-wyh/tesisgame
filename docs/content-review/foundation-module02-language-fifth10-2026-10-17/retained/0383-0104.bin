'use strict';
// Unexecuted source proposal. Produces scratch bytes only; never loads project modules or runs tests.
const assert = require('node:assert/strict');
const provenancePath = 'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json';
const files = ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs'];
const strictHelper = String.raw`function beforeShoppingBagImage(entry) {
  const patches = shoppingBagImageRecord.patches.filter(item => item.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  assert.equal(patch.id, 'shopping-bag.goods-carrier.n');
  assert.deepEqual(entry, patch.after, entry.id + ': exact later shopping-bag image and three note clauses');
  return structuredClone(patch.before);
}`;

const focusedMediaTests = String.raw`

test('Shopping-bag image installs exactly the accepted entry delta and three note clauses', () => {
  const r=shoppingBagImageRecord;
  assert.equal(r.patches.length,1);
  const p=r.patches[0],entry=data.lexemes.find(item=>item.id===p.id);
  assert.equal(p.id,'shopping-bag.goods-carrier.n');assert.deepEqual(entry,p.after);
  assert.equal(hash(p.before),'ba96e5d4ba9911b68ddb630d3413cac52d155a3d27c7452aaee97ba5284f7e07');
  assert.equal(hash(p.after),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');
  assert.equal(hash(p.before),p.before_sha256);assert.equal(hash(p.after),p.after_sha256);
  assert.equal(p.note_change.kind,'three_exact_single_occurrence_replacements');assert.equal(p.note_change.replacements.length,3);
  let notes=p.before.editorial_notes;
  for(const change of p.note_change.replacements){assert.equal(notes.split(change.before).length,2);notes=notes.replace(change.before,change.after);}
  assert.equal(notes,p.after.editorial_notes);
  assert.deepEqual(protectedEntry(p.after,'image'),protectedEntry(p.before,'image'));
  assert.equal(hash(protectedEntry(p.before,'image')),'091cb33bb94c158215dc8db8c4198482b0c2f991ce4b964786321d5114c51d69');
  assert.equal(hash(protectedEntry(p.before,'image')),p.protected_fields_sha256);
  assert.deepEqual(entry.accepted_forms,['shopping bag']);assert.deepEqual(entry.regions,['general']);
  assert.deepEqual(entry.practice_modes,['match','memory','pop','jelly','word_jelly']);
  assert.equal(entry.definition,'A bag used to carry purchased items.');assert.equal(entry.difficulty,'A2');
  assert.deepEqual(entry.media.audio,p.before.media.audio);assert.deepEqual(entry.morphology,p.before.morphology);
  assert.equal(entry.media.audio.review.status,'reviewed');assert.equal(entry.morphology.review.status,'reviewed');
  assert.deepEqual(entry.media.audio.voice_settings,approval.profile);
  assert.equal(r.source_registry_change,false);assert.equal(r.module_or_manifest_change,false);
  assert.equal(raw(r.accepted_proposal.inventory.path),r.accepted_proposal.inventory.raw_sha256);
  assert.equal(r.accepted_proposal.inventory.raw_sha256,'5289682bdc2ebe875adac1f70b7985fe2dd665d4ade232b89b4386f26341716e');
  assert.equal(raw(r.accepted_proposal.review.path),'f56ba6b21b583e4ebb59b933ca82b982394512be31400f1c2fb6e0cf83407f8f');
  assert.equal(read(r.accepted_proposal.review.path).status,'exact_asset_and_entry_proposal_accepted_for_final_rebase_only');
});

test('Shopping-bag image retains exact accepted PNG bytes, descriptor and bounded decoded cost', () => {
  const r=shoppingBagImageRecord,p=r.patches[0],resource=r.resource,image=p.after.media.image;
  const bytes=fs.readFileSync(path.join(root,resource.path));
  assert.deepEqual([...bytes.subarray(0,8)],[137,80,78,71,13,10,26,10]);
  assert.equal(bytes.readUInt32BE(8),13);assert.equal(bytes.toString('ascii',12,16),'IHDR');
  assert.equal(bytes.readUInt32BE(16),414);assert.equal(bytes.readUInt32BE(20),512);
  assert.equal(bytes.length,135843);assert.equal(resource.compressed_bytes,bytes.length);
  assert.equal(resource.decoded_bytes,414*512*8);assert.equal(resource.decoded_bytes,1695744);
  assert.ok(resource.decoded_bytes<=32*1024*1024);assert.ok(resource.compressed_bytes<=10*1024*1024);
  assert.equal(raw(resource.path),'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb');
  assert.equal(resource.sha256,raw(resource.path));assert.equal(image.path,'res://'+resource.path);assert.equal(image.sha256,resource.sha256);
  assert.equal(image.status,'integrated');assert.equal(image.acquisition_status,'integrated');assert.equal(image.review.status,'reviewed');
  assert.equal(image.creator,'Vijay Verma (@realvjy)');assert.equal(image.license,'CC0 1.0');assert.equal(image.source,'res://'+r.source_records[0]);
  assert.equal(image.brief,r.accepted_brief);assert.equal(image.picture_suitable,true);assert.deepEqual(image.available_animations,[]);
  assert.deepEqual(image,read(r.accepted_proposal.image_descriptor.path));
  assert.equal(raw(r.accepted_proposal.image_descriptor.path),r.accepted_proposal.image_descriptor.raw_sha256);
  assert.equal(image.adaptations.length,3);assert.match(image.adaptations[1],/16-source-pixel margin/);assert.match(image.adaptations[1],/Lanczos/);
  assert.equal(data.courses.find(course=>course.id==='retail').modules.find(module=>module.id==='module03').status,'draft');
});

test('Shopping-bag acceptance preserves acquisition history, original mismatch and gift-bag limitation', () => {
  const r=shoppingBagImageRecord;
  for(const file of r.retained_files){assert.equal(raw(file.path),file.sha256,file.path);assert.equal(fs.statSync(path.join(root,file.path)).size,file.bytes,file.path);}
  const source=read(r.source_records[0]),accepted=read(r.candidate_visual_acceptance.path);
  assert.equal(source.review.current_brief_matched,false);assert.equal(source.review.accepted,false);
  assert.equal(source.review.native_wordcard_inspected,false);assert.equal(source.review.production_delivery_verified,false);
  assert.equal(accepted.status,'candidate_and_brief_accepted_for_scoped_production_proposal');
  assert.equal(raw(r.candidate_visual_acceptance.path),'fa9e40fa7475be0bdd5831ba1907577707fb3557f9f177e7b3f0453df569a97b');
  assert.equal(accepted.production_integrated,false);assert.equal(accepted.brief_revision_accepted,true);assert.equal(accepted.image_visually_accepted,true);
  assert.equal(accepted.checks,534);assert.equal(accepted.failures,0);assert.equal(accepted.protected_production_files,1444);
  assert.equal(r.original_brief,accepted.original_brief);assert.equal(r.accepted_brief,accepted.accepted_brief);
  assert.equal(r.patches[0].before.media.image.brief,r.original_brief);assert.notEqual(r.original_brief,r.accepted_brief);
  assert.match(r.original_brief,/reusable fabric/);assert.match(r.original_brief,/purchased items/);
  assert.ok(r.limitations.some(text=>/gift bags may share/.test(text)));assert.ok(r.limitations.some(text=>/not human participant recognition/.test(text)));
  assert.equal(r.audit.new_listening_approval,false);assert.equal(r.audit.ready_module_or_course,false);
});

test('Shopping-bag addition preserves eight prior images, twelve approved recordings and all other content', () => {
  const r=shoppingBagImageRecord,c=r.protected_state;
  assert.equal(r.protected_media.length,20);assert.equal(r.protected_media.filter(item=>item.kind==='image').length,8);assert.equal(r.protected_media.filter(item=>item.kind==='audio').length,12);
  for(const item of r.protected_media){const descriptor=data.lexemes.find(entry=>entry.id===item.sense_id).media[item.kind];assert.deepEqual(descriptor,item.descriptor);assert.equal(hash(descriptor),item.descriptor_json_sha256);assert.equal(raw(item.file.path),item.file.sha256);assert.equal(fs.statSync(path.join(root,item.file.path)).size,item.file.bytes);}
  assert.equal(hash(data.lexemes.filter(entry=>entry.id!=='shopping-bag.goods-carrier.n')),c.other_lexemes_json_sha256);
  for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])assert.equal(hash(data[key]),c[key+'_json_sha256'],key);
  assert.equal(data.lexemes.filter(entry=>entry.media.image.status==='integrated').length,9);
  assert.equal(data.lexemes.filter(entry=>entry.media.audio.status==='integrated').length,12);
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
  assert.equal(cardReaderBarcodeAudio.baseline_summary.integrated_word_images,8);
  assert.equal(cardReaderBarcodeAudio.baseline_summary.integrated_word_audio,10);
});

test('Shopping-bag reversal rejects partial changes and an already reversed bag', () => {
  const p=shoppingBagImageRecord.patches[0];
  assert.deepEqual(beforeShoppingBagImage(p.after),p.before);
  assert.throws(()=>beforeShoppingBagImage(p.before));
  for(const mutate of [
    entry=>{entry.media.image.sha256='0'.repeat(64);},entry=>{entry.media.image.path+='-drift';},
    entry=>{entry.media.image.brief+=' Drift.';},entry=>{entry.editorial_notes+=' Drift.';},
    entry=>{entry.media.audio.voice_settings.pitch='+9Hz';},entry=>{entry.accepted_forms.push('carrier bag');},
    entry=>{entry.morphology.nodes[0].rule+='-drift';}
  ]){const changed=structuredClone(p.after);mutate(changed);assert.throws(()=>beforeShoppingBagImage(changed));}
  const unrelated=data.lexemes.find(entry=>entry.id==='gift-wrap.wrapping-paper.n');assert.equal(beforeShoppingBagImage(unrelated),unrelated);
  const fifth=fifthRecord.patches.find(item=>item.id===p.id);assert.deepEqual(beforeFifth10(p.after),fifth.before);
});
`;

function transform(file, input) {
  assert(files.includes(file), 'Unexpected shared test target');
  const original=input.toString('utf8'), newline=original.includes('\r\n')?'\r\n':'\n';
  assert(!original.includes('beforeShoppingBagImage'), 'Shopping-bag boundary already exists');
  let text=original;
  const edits=[];
  const normalize=value=>value.replace(/\r?\n/g,newline);
  const replace=(name,before,after,count=1)=>{
    before=normalize(before);after=normalize(after);
    const found=text.split(before).length-1;assert.equal(found,count,name+': exact anchor count');
    text=text.split(before).join(after);edits.push({name,occurrences:count,before,after});
  };
  const content=file===files[0],morphology=file===files[1];
  const load=content?`const shoppingBagImageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '${provenancePath}'), 'utf8'));`:
    morphology?`const shoppingBagImageRecord = JSON.parse(fs.readFileSync(path.join(root, '${provenancePath}'), 'utf8'));`:
      `const shoppingBagImageRecord=read('${provenancePath}');`;
  replace('one strict image reversal before fifth-ten history','function beforeFifth10(entry) {',
    load+'\n'+strictHelper+(content?'\nconst shoppingBagHistoryLexemes = () => source.lexemes.map(beforeShoppingBagImage);':'')+'\nfunction beforeFifth10(entry) {\n  entry = beforeShoppingBagImage(entry);');
  if(content){
    replace('live image total only','assert.equal(result.summary.integrated_word_images, 8);','assert.equal(result.summary.integrated_word_images, 9);');
    for(const [name,count] of [['beforeAttendanceLanguage',1],['beforeFoundation02SecondLanguage',2],['beforeFoundation02ThirdLanguage',4],['beforeFoundation02FourthLanguage',6]]) {
      replace('full-registry history boundary '+name,'source.lexemes.map('+name+')','shoppingBagHistoryLexemes().map('+name+')',count);
    }
    replace('fourth-ten all-other-lexeme historical hash','hash(source.lexemes.filter(entry=>!ids.has(entry.id))),c.all_other_lexemes_json_sha256',
      'hash(shoppingBagHistoryLexemes().filter(entry=>!ids.has(entry.id))),c.all_other_lexemes_json_sha256');
  } else if(morphology){
    replace('disjoint live counter-history boundary','function beforeCounterImage(entry) {','function beforeCounterImage(entry) {\n  entry = beforeShoppingBagImage(entry);');
    replace('direct fifth-ten afterimage comparison','for (const patch of fifthRecord.patches) {\n    const entry = data.lexemes.find(item => item.id === patch.id);',
      'for (const patch of fifthRecord.patches) {\n    const entry = beforeShoppingBagImage(data.lexemes.find(item => item.id === patch.id));');
  } else {
    replace('live media image total only',"assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,8);", "assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,9);");
    text+=normalize(focusedMediaTests);
  }
  assert(text.startsWith(original.slice(0,original.indexOf('function beforeFifth10(entry) {'))), 'Unrelated leading source changed');
  return {bytes:Buffer.from(text,'utf8'),edits,appended_tests:content||morphology?0:5,native:false};
}
module.exports={files,transform,strictHelper};
