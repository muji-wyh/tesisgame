'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const read=f=>JSON.parse(fs.readFileSync(path.join(root,f),'utf8'));
const raw=f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex');
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const data=require('../tools/validate-professional-content.cjs').loadProfessionalContent(root);
const audio=read('data/professional/provenance/retail-cart-basket-approved-audio-2026-10-16.json');
const picture=read('data/professional/provenance/retail-pallet-image-2026-10-16.json');
const nextAudio=read('data/professional/provenance/retail-pallet-shelf-approved-audio-2026-10-16.json');
const bagWrapAudio=read('data/professional/provenance/retail-bag-wrap-approved-audio-2026-10-16.json');
const shelf=read('data/professional/provenance/retail-shelf-image-2026-10-16.json');
const counter=read('data/professional/provenance/retail-counter-image-2026-10-16.json');
const counterCheckoutAudio=read('data/professional/provenance/retail-counter-checkout-approved-audio-2026-10-16.json');
const checkout=read('data/professional/provenance/retail-checkout-image-2026-10-16.json');
const barcode=read('data/professional/provenance/retail-barcode-image-2026-10-16.json');
const cashRegister=read('data/professional/provenance/retail-cash-register-image-2026-10-16.json');
function beforeCheckoutImage(entry) {
  const patch = checkout.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later checkout image and pending-image note delta');
  return structuredClone(patch.before);
}
function beforeCounterCheckoutAudio(entry) {
  entry = beforeCheckoutImage(entry);
  const patch = counterCheckoutAudio.patches.find(item => item.sense_id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later approved counter or checkout audio and note delta');
  return structuredClone(patch.before);
}
const fifthRecord=read('data/professional/provenance/retail-module03-morphology-fifth10-2026-10-16.json');
function beforeFifth10(entry) {
  const patch = fifthRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later fifth-ten graph and note delta');
  return structuredClone(patch.before);
}
const approval=read(audio.approval);
const protectedEntry=(entry,kind)=>{const out=structuredClone(entry);delete out.media[kind];delete out.editorial_notes;return out;};
const beforeLatestAudio=entry=>{
  const patch=nextAudio.patches.find(p=>p.sense_id===entry.id);
  if(!patch)return entry;
  assert.deepEqual(entry,patch.after,'Only an exact accepted later audio patch can restore a historical image entry');
  return structuredClone(patch.before);
};

test('cart and basket listening approval binds exactly the presented immutable bytes',()=>{
  assert.equal(approval.status,'approved_by_user');
  assert.deepEqual(approval.evidence.question_item_id,['request_user_input_async','call_E8Hzra7frLKPH87bFntqL6YM',0]);
  assert.equal(approval.evidence.answer_english,'Both are acceptable.');
  assert.equal(approval.outputs.length,2);assert.equal(audio.patches.length,2);
  assert.equal(raw(audio.approval),audio.approval_raw_sha256);
  assert.deepEqual(approval.profile,{voice:'en-US-AvaNeural',rate:'-15%',pitch:'+8Hz',volume:'+0%',postprocessing:false});
  for(const out of approval.outputs){
    assert.equal(raw(out.presented_path),out.wav_sha256);
    assert.equal(raw(out.retained_wav),out.wav_sha256);
    assert.equal(raw(out.retained_mp3),out.source_mp3_sha256);
    assert.equal(raw(out.acquisition_receipt),out.acquisition_receipt_raw_sha256);
    const acquired=read(out.acquisition_receipt);
    assert.equal(acquired.pronunciation_and_listening_review,'pending','Historical acquisition stays pre-approval.');
    assert.equal(acquired.production_integrated,false);
    const patch=audio.patches.find(p=>p.sense_id===out.sense_id);
    assert.equal(raw(patch.resource.path),out.wav_sha256);
    assert.equal(patch.after.media.audio.review.status,'reviewed');
    assert.equal(patch.resource.decoded_bytes,82554);
  }
});

test('new audio changes only exact approved descriptors and obsolete pending clauses',()=>{
  for(const patch of audio.patches){
    assert.deepEqual(data.lexemes.find(e=>e.id===patch.sense_id),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);
    assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace('word audio remains pending.','the exact Ava word recording has user listening approval and is integrated.'));
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);
  }
  assert.ok(data.courses.every(c=>c.modules.every(m=>m.status==='draft')));
});

test('pallet image preserves licensed original sources and its separate morphology/domain gates',()=>{
  assert.equal(picture.independent_approval.status,'accepted_exact_pallet_image_and_obsolete_note_only');
  const patch=picture.patches[0],entry=beforeLatestAudio(data.lexemes.find(e=>e.id===patch.id));
  assert.deepEqual(entry,patch.after);assert.equal(hash(patch.before),patch.before_sha256);
  assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);
  assert.equal(entry.media.image.brief,patch.before.media.image.brief);
  assert.equal(entry.media.image.status,'integrated');assert.equal(entry.media.audio.status,'pending');
  assert.equal(entry.review.domain,'pending');assert.equal(entry.morphology.review.status,'reviewed');
  assert.equal(raw(picture.resource.path),picture.independent_approval.image_sha256);
  assert.equal(picture.resource.decoded_bytes,512*278*8);
  const source=read(picture.source_record);
  assert.equal(source.license,'CC0 1.0');assert.equal(source.creator,'Kenney');
  assert.match(source.local_version,/Mini Skate 1\.2/);assert.deepEqual(source.available_animations,[]);
  for(const file of source.files)assert.equal(raw(picture.retained_evidence+'/'+file.retained_path),file.sha256);
  const receipt=read(picture.retained_evidence+'/review-receipt.json');
  assert.equal(raw(picture.retained_evidence+'/review-receipt.json'),picture.independent_approval.receipt_raw_sha256);
  for(const file of receipt.evidence_files)assert.equal(raw(picture.retained_evidence+'/'+file.path),file.sha256);
});

test('the media additions preserve every historical voice and sequential collection clip',()=>{
  assert.equal(audio.preserved_audio_files.length,1897);
  for(const file of audio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);
  assert.equal(nextAudio.preserved_audio_files.length,1899);
  for(const file of nextAudio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);
  assert.equal(bagWrapAudio.preserved_audio_files.length,1901);
  for(const file of bagWrapAudio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);
  assert.equal(counterCheckoutAudio.preserved_audio_files.length,1903);
  for(const file of counterCheckoutAudio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);
  assert.equal(data.lexemes.filter(e=>e.media.audio.status==='integrated').length,10);
  assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,8);
});

test('pallet and shelf approval binds the direct reply to each exact presented recording',()=>{
  const accepted=read(nextAudio.approval);
  assert.equal(raw(nextAudio.approval),nextAudio.approval_raw_sha256);
  assert.equal(accepted.status,'approved_by_user');
  assert.deepEqual(accepted.evidence.question_item_id,['request_user_input_async','call_Zo5YL5cNGetpHbs6DGCTYU6w',0]);
  assert.equal(accepted.evidence.answer_english,'Both are acceptable.');
  assert.deepEqual(accepted.profile,approval.profile);
  assert.deepEqual(accepted.outputs.map(o=>o.sense_id).sort(),['pallet.goods-platform.n','shelf.storage-surface.n']);
  for(const out of accepted.outputs){
    for(const file of [out.presented_path,out.retained_wav])assert.equal(raw(file),out.wav_sha256);
    assert.equal(raw(out.retained_mp3),out.source_mp3_sha256);
    assert.equal(raw(out.acquisition_receipt),out.acquisition_receipt_raw_sha256);
    const acquired=read(out.acquisition_receipt);
    assert.equal(acquired.pronunciation_and_listening_review,'pending');
    assert.equal(acquired.production_integrated,false);
    const patch=nextAudio.patches.find(p=>p.sense_id===out.sense_id);
    assert.equal(raw(patch.resource.path),out.wav_sha256);
    assert.equal(patch.resource.decoded_bytes,82554);
  }
});

test('latest approved audio preserves exact accepted images, graphs and unrelated fields',()=>{
  assert.equal(nextAudio.patches.length,2);
  for(const patch of nextAudio.patches){
    assert.deepEqual(data.lexemes.find(e=>e.id===patch.sense_id),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);
    assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace('word audio remains pending.','the exact Ava word recording has user listening approval and is integrated.'));
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);
    assert.equal(patch.after.media.image.status,'integrated');
    assert.equal(patch.after.morphology.review.status,'reviewed');
    assert.equal(patch.after.review.domain,'pending');
  }
  assert.ok(data.courses.every(c=>c.modules.every(m=>m.status==='draft')));
});

test('shelf keeps the licensed source, documented visibility adaptation and accepted pixels',()=>{
  const patch=shelf.patches[0],entry=beforeLatestAudio(data.lexemes.find(e=>e.id===patch.id));
  assert.deepEqual(entry,patch.after);assert.equal(hash(patch.before),patch.before_sha256);
  assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);
  assert.equal(entry.media.image.brief,patch.before.media.image.brief);
  assert.equal(raw(shelf.resource.path),'bddc3c2dd3b889c785195a572b95a33455c047e097e927232c735b3b43a24f04');
  assert.equal(shelf.resource.decoded_bytes,512*309*8);
  const source=read(shelf.source_record);
  assert.equal(source.license,'CC0 1.0');assert.equal(source.creator,'Kenney');
  assert.deepEqual(source.additional_credits,['Fleur Keijsers','Guus Vermeulen']);
  assert.match(source.local_version,/Mini Market 1\.0/);assert.deepEqual(source.available_animations,[]);
  for(const file of source.files)assert.equal(raw(shelf.retained_evidence+'/'+file.retained_path),file.sha256);
  const receipt=read(shelf.retained_evidence+'/review-receipt.json');
  assert.equal(raw(shelf.retained_evidence+'/review-receipt.json'),'d20283010366f4f1dc293882c323a30102fbceea9c40e9e5e19cd0b0ca70f341');
  assert.equal(raw(shelf.retained_evidence+'/root-image-review.json'),'ada7ad8dee8f16143e4c18b193651fd08260e5766bf735a389cf39c10a0d58ad');
  assert.deepEqual(receipt.candidate.omitted_source_nodes,['carton','carton2','carton3','carton4','carton5','carton6','box3','box4']);
  for(const file of receipt.evidence_files)assert.equal(raw(shelf.retained_evidence+'/'+file.path),file.sha256);
});

test('shopping bag and gift wrap retain the exact human-approved samples and pending acquisition history',()=>{
  const accepted=read(bagWrapAudio.approval);
  assert.equal(raw(bagWrapAudio.approval),bagWrapAudio.approval_raw_sha256);
  assert.equal(accepted.status,'approved_by_user');
  assert.deepEqual(accepted.evidence.question_item_id,['request_user_input_async','call_gl3ZkQHtOHUHev3ulmRyYH3a',0]);
  assert.equal(accepted.evidence.answer_english,'Both are acceptable.');
  assert.deepEqual(accepted.profile,approval.profile);
  assert.deepEqual(accepted.outputs.map(o=>o.sense_id).sort(),['gift-wrap.wrapping-paper.n','shopping-bag.goods-carrier.n']);
  for(const out of accepted.outputs){
    for(const file of [out.presented_path,out.retained_wav])assert.equal(raw(file),out.wav_sha256);
    assert.equal(raw(out.retained_mp3),out.source_mp3_sha256);
    assert.equal(raw(out.acquisition_receipt),out.acquisition_receipt_raw_sha256);
    const acquired=read(out.acquisition_receipt);
    assert.equal(acquired.pronunciation_and_listening_review,'pending');
    assert.equal(acquired.production_integrated,false);
    const patch=bagWrapAudio.patches.find(p=>p.sense_id===out.sense_id);
    assert.equal(raw(patch.resource.path),out.wav_sha256);
    assert.equal(patch.resource.decoded_bytes,82554);
  }
});

test('bag and wrap approval changes only audio and the exact obsolete pending-media clause',()=>{
  assert.equal(bagWrapAudio.patches.length,2);
  const validation=read(bagWrapAudio.lineage.validation);
  assert.equal(raw(bagWrapAudio.lineage.validation),bagWrapAudio.lineage.validation_raw_sha256);
  assert.equal(validation.ok,true);
  assert.equal(validation.registry_after_sha256,bagWrapAudio.before_registry_sha256);
  for(const patch of bagWrapAudio.patches){
    assert.deepEqual(beforeFifth10(data.lexemes.find(e=>e.id===patch.sense_id)),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);
    assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace('Picture suitability and word-media production remain pending.','Picture suitability and word-image production remain pending. The exact Ava word recording has user listening approval and is integrated.'));
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);
    assert.equal(patch.after.media.image.status,'pending');
    assert.equal(patch.after.morphology.review.status,'pending');
  }
  assert.ok(data.courses.every(c=>c.modules.every(m=>m.status==='draft')));
});

test('counter preserves both licensed originals, exact accepted pixels and all unrelated review gates',()=>{
  const patch=counter.patches[0],entry=beforeCounterCheckoutAudio(data.lexemes.find(item=>item.id==='counter.service-surface.n'));
  assert.equal(counter.patches.length,1);assert.equal(patch.id,entry.id);assert.deepEqual(entry,patch.after);
  assert.equal(hash(patch.before),patch.before_sha256);
  assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);
  const expected=structuredClone(patch.before);expected.media.image=patch.after.media.image;
  expected.editorial_notes=expected.editorial_notes.replace('Picture suitability and word-media production remain pending.','The counter image has completed scoped physical-sense picture review and integration; word audio remains pending.');
  assert.deepEqual(entry,expected);
  assert.equal(entry.media.audio.status,'pending');assert.equal(entry.review.domain,'pending');
  assert.deepEqual(entry.morphology,patch.before.morphology);assert.equal(entry.morphology.review.status,'reviewed');
  assert.equal(entry.media.image.brief,patch.before.media.image.brief);assert.deepEqual(entry.media.image.available_animations,[]);
  assert.equal(counter.independent_approval.status,'accepted_exact_counter_image_and_scoped_adaptations_for_integration');
  assert.equal(raw(counter.resource.path),'c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a');
  assert.equal(counter.resource.compressed_bytes,31426);assert.equal(counter.resource.decoded_bytes,512*293*8);
  assert.equal(counter.resource.width,512);assert.equal(counter.resource.height,293);
  const records=counter.source_records.map(read);
  assert.deepEqual(records.map(record=>record.source),['https://kenney.nl/assets/furniture-kit','https://kenney.nl/assets/car-kit']);
  assert.deepEqual(records.map(record=>record.creator),['Kenney','Kenney']);assert.deepEqual(records.map(record=>record.license),['CC0 1.0','CC0 1.0']);
  assert.equal(records.flatMap(record=>record.files).length,20);
  for(const record of records)for(const file of record.files)assert.equal(raw(counter.retained_evidence+'/'+file.retained_path),file.sha256);
  const receipt=read(counter.retained_evidence+'/review-receipt.json');
  assert.equal(raw(counter.retained_evidence+'/review-receipt.json'),'c06028630c91070f11d42a3eb57349b294b9d9331f0881faf31fc6c00bce7fd0');
  assert.equal(raw(counter.retained_evidence+'/root-image-review.json'),'ea82b3f6d34b192268bda35332f749870d18608201e22a87e41a5288739bec88');
  assert.deepEqual(receipt.sources.map(source=>source.available_animations),[[],[]]);
  assert.equal(receipt.native_validation.selected_checks,21);assert.equal(receipt.native_validation.selected_failures,0);
  assert.equal(receipt.selected_candidate.rgba_pixel_sha256,'342eb324b6655d4fb2437974a1dbcc8e83d7d37875459e54c0f6926102be9a98');
  for(const file of receipt.evidence_files)assert.equal(raw(counter.retained_evidence+'/'+file.path),file.sha256);
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});

test('counter and checkout preserve the exact presented pair and direct human approval',()=>{
  const accepted=read(counterCheckoutAudio.approval),human=read(accepted.evidence.human_record);
  assert.equal(raw(counterCheckoutAudio.approval),counterCheckoutAudio.approval_raw_sha256);
  assert.equal(accepted.status,'approved_by_user');
  assert.deepEqual(accepted.evidence.question_item_id,['request_user_input_async','call_fBfAoFlUyKmhWveN2mNUORiZ',0]);
  assert.equal(accepted.evidence.answer_english,'Both are acceptable');
  assert.equal(raw(accepted.evidence.human_record),'d9487d9a2a2a93805fa597f87dcf775f1cebae88c89fc97c13de90acbece2e82');
  assert.equal(human.status,'exact_presented_pair_user_approved');
  assert.equal(raw(accepted.technical_qa.path),'5300530a5630b15ca27921f488f123ef228fab38d89cc9ad982e3f71460b608b');
  assert.equal(raw(accepted.listening_request.path),'10cdbe11ca4e9a0ae1122dc5ae2acffc69228db3d68bc7245988186667359bab');
  assert.equal(read(accepted.listening_request.path).status,'presented_to_user_pending_listening_response');
  assert.deepEqual(accepted.profile,approval.profile);
  assert.deepEqual(accepted.outputs.map(item=>item.sense_id),['counter.service-surface.n','checkout.payment-area.n']);
  const expected=['685b544dbb353f3a1f3fb999fbe3f541cb94874d0e4543ad0cba774c39fd4bc3','39df6ba3406a891283f99379ca8526d93fc8f3279b571134c0213dd824282224'];
  for(const [index,out]of accepted.outputs.entries()){
    assert.equal(out.wav_sha256,expected[index]);
    for(const file of [out.presented_path,out.retained_wav])assert.equal(raw(file),out.wav_sha256);
    assert.equal(raw(out.retained_mp3),out.source_mp3_sha256);assert.equal(raw(out.acquisition_receipt),out.acquisition_receipt_raw_sha256);
    const acquired=read(out.acquisition_receipt);assert.equal(acquired.pronunciation_and_listening_review,'pending');assert.equal(acquired.production_integrated,false);
    const patch=counterCheckoutAudio.patches.find(item=>item.sense_id===out.sense_id);
    assert.equal(raw(patch.resource.path),out.wav_sha256);assert.equal(patch.resource.decoded_bytes,82554);assert.equal(patch.resource.frames,41277);
  }
});

test('counter and checkout audio changes preserve the exact image, graphs and all other fields',()=>{
  assert.equal(counterCheckoutAudio.patches.length,2);
  const validation=read(counterCheckoutAudio.lineage.validation);
  assert.equal(raw(counterCheckoutAudio.lineage.validation),counterCheckoutAudio.lineage.validation_raw_sha256);
  assert.equal(validation.ok,true);assert.equal(validation.registry_after_sha256,counterCheckoutAudio.before_registry_sha256);
  const delivery=read(counterCheckoutAudio.lineage.counter_image_delivery.path);
  assert.equal(raw(counterCheckoutAudio.lineage.counter_image_delivery.path),counterCheckoutAudio.lineage.counter_image_delivery.raw_sha256);
  assert.equal(delivery.ok,true);assert.equal(delivery.all_four_crops_pixel_equal,true);assert.equal(delivery.resource_reference_released,true);
  for(const patch of counterCheckoutAudio.patches){
    assert.deepEqual(beforeCheckoutImage(data.lexemes.find(entry=>entry.id===patch.sense_id)),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace(patch.note_change.before,patch.note_change.after));
    assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length,2);
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);assert.equal(patch.after.media.audio.review.status,'reviewed');
    assert.deepEqual(patch.after.media.image,patch.before.media.image);assert.deepEqual(patch.after.morphology,patch.before.morphology);
    assert.deepEqual(patch.after.review,patch.before.review);
    assert.equal(patch.after.review.domain,{'counter.service-surface.n':'pending','checkout.payment-area.n':'not_required'}[patch.sense_id]);
  }
  const counterPatch=counterCheckoutAudio.patches.find(patch=>patch.sense_id==='counter.service-surface.n');
  assert.deepEqual(counterPatch.before,counter.patches[0].after);assert.equal(counterPatch.after.media.image.sha256,'c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a');
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});

test('checkout image preserves exact payment-area scope and the human-approved Ava audio',()=>{
  const patch=checkout.patches[0],entry=data.lexemes.find(item=>item.id==='checkout.payment-area.n');
  assert.equal(checkout.patches.length,1);assert.equal(patch.id,entry.id);assert.deepEqual(entry,patch.after);
  assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);
  assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);
  assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  const expected=structuredClone(patch.before);expected.media.image=patch.after.media.image;
  expected.editorial_notes=expected.editorial_notes.replace('Picture suitability and word-image production remain pending.','The checkout image has completed scoped payment-area picture review.');
  assert.deepEqual(entry,expected);assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length,2);
  assert.equal(entry.editorial_notes.includes('The exact Ava word recording has user listening approval and is integrated.'),true);
  assert.deepEqual(entry.media.audio,patch.before.media.audio);assert.equal(entry.media.audio.sha256,'39df6ba3406a891283f99379ca8526d93fc8f3279b571134c0213dd824282224');
  assert.equal(raw(entry.media.audio.path.slice(6)),entry.media.audio.sha256);assert.equal(entry.media.audio.review.status,'reviewed');
  assert.equal(entry.media.image.brief,patch.before.media.image.brief);assert.deepEqual(entry.media.image.available_animations,[]);
  assert.deepEqual(entry.morphology,patch.before.morphology);assert.deepEqual(entry.review,patch.before.review);
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});

test('checkout retains licensed full models and bounded successful pixels without relabeling the failed aggregate',()=>{
  assert.equal(checkout.independent_approval.status,'accepted_exact_checkout_image_and_scoped_adaptations_for_integration');
  assert.equal(raw(checkout.resource.path),'eac283976fb82cf02f379188ea62c524207c422fc15eda02e93e204b060743fe');
  assert.equal(checkout.resource.compressed_bytes,148338);assert.equal(checkout.resource.decoded_bytes,512*393*8);
  assert.equal(checkout.resource.width,512);assert.equal(checkout.resource.height,393);
  const source=read(checkout.source_records[0]),receipt=read(checkout.retained_evidence+'/review-receipt.json');
  assert.deepEqual(source.packs.map(pack=>pack.source),['https://kenney.nl/assets/mini-market','https://kenney.nl/assets/mini-characters','https://kenney.nl/assets/food-kit']);
  assert.deepEqual(source.packs.map(pack=>pack.creator),['Kenney','Kenney','Kenney']);assert.deepEqual(source.packs.map(pack=>pack.license),['CC0 1.0','CC0 1.0','CC0 1.0']);
  assert.equal(source.files.length,24);for(const file of source.files)assert.equal(raw(checkout.retained_evidence+'/'+file.retained_path),file.sha256);
  assert.equal(raw(checkout.retained_evidence+'/review-receipt.json'),'0eb077b0f57d88626abbc38a0b6067263fdbfd9789eadd837e3e3eadb8c2cad3');
  assert.equal(raw(checkout.retained_evidence+'/root-image-review.json'),'9f91735ea130c4b035c053084e46ac289aa60ad8184816a6c9a8f0344f1b0a47');
  assert.equal(receipt.native_validation.selected_candidate.checks,18);assert.equal(receipt.native_validation.selected_candidate.failures,0);
  assert.equal(receipt.native_validation.aggregate.ok,false);assert.equal(receipt.native_validation.aggregate.checks,72);assert.equal(receipt.native_validation.aggregate.failures,2);
  assert.deepEqual(receipt.native_validation.aggregate.failed_checks.map(row=>row.check),['tiled-three-quarter: complete scene in viewport','tiled-high: complete scene in viewport']);
  assert.equal(receipt.selected_candidate.rgba_pixel_sha256,'15cf24c616d3741e7b4fceb39994322eb2548a76c1183fb32951115f723776ad');
  assert.equal(receipt.selected_candidate.source_instances.length,5);assert.equal(receipt.selected_candidate.card_crops.length,4);
  assert.deepEqual(receipt.selected_candidate.source_instances.filter(item=>item.source_pose.clip).map(item=>[item.source_pose.clip,item.source_pose.seconds]),[['idle',0],['interact-right',0.333]]);
  for(const file of receipt.evidence_files)assert.equal(raw(checkout.retained_evidence+'/'+file.path),file.sha256);
  for(const crop of receipt.selected_candidate.card_crops)assert.equal(raw(checkout.retained_evidence+'/'+crop.path),crop.sha256);
});

test('barcode image changes only the exact reviewed picture and obsolete image clause',()=>{
  const patch=barcode.patches[0],entry=data.lexemes.find(item=>item.id==='barcode.product-code.n');
  assert.equal(barcode.patches.length,1);assert.equal(patch.id,entry.id);assert.deepEqual(entry,patch.after);
  assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);
  assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);
  assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  const expected=structuredClone(patch.before);expected.media.image=patch.after.media.image;
  expected.editorial_notes=expected.editorial_notes.replace('Picture suitability and word-media production remain pending.','The barcode image has completed scoped picture review; word audio remains pending.');
  assert.deepEqual(entry,expected);assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length,2);
  assert.equal(entry.media.image.brief,patch.before.media.image.brief);assert.deepEqual(entry.media.image.available_animations,[]);
  assert.equal(entry.media.image.status,'integrated');assert.equal(entry.media.image.review.status,'reviewed');
  assert.deepEqual(entry.media.audio,patch.before.media.audio);assert.equal(entry.media.audio.status,'pending');assert.equal(entry.media.audio.path,null);assert.equal(entry.media.audio.review.status,'pending');
  assert.deepEqual(entry.media.audio.voice_settings,{voice:'en-US-AvaNeural',rate:'-15%',pitch:'+8Hz',volume:'+0%',postprocessing:false});
  assert.deepEqual(entry.morphology,patch.before.morphology);assert.equal(entry.morphology.review.status,'reviewed');assert.deepEqual(entry.review,patch.before.review);assert.equal(entry.review.domain,'pending');
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});

test('barcode retains exact source licenses, independent review, unchanged strokes and failed attempt',()=>{
  assert.equal(barcode.independent_approval.status,'accepted_exact_barcode_image_and_scoped_adaptations_for_integration');assert.equal(barcode.independent_approval.root_review_recorded,true);
  assert.equal(raw(barcode.resource.path),'a818b742ce3fe1543298ce2330464e59cdfa341508062c67834a62c73774a69c');assert.equal(barcode.resource.compressed_bytes,27650);assert.equal(barcode.resource.decoded_bytes,512*293*8);assert.equal(barcode.resource.width,512);assert.equal(barcode.resource.height,293);
  const base=barcode.retained_evidence,source=read(barcode.source_records[0]),receipt=read(base+'/review-receipt.json');
  assert.deepEqual(source.packs.map(p=>p.creator),['netalloy','Kenney']);assert.deepEqual(source.packs.map(p=>p.license),['CC0 1.0 Universal','CC0 1.0']);assert.equal(source.packs[0].original_source_downloaded,false);assert.equal(source.packs[0].acquired_from,'https://www.clipsafari.com/clips/o38797-barcode');assert.equal(source.packs[1].source,'https://kenney.nl/assets/car-kit');
  assert.equal(source.files.length,7);for(const f of source.files)assert.equal(raw(base+'/'+f.retained_path),f.sha256);assert.deepEqual(source.parcel_model.animations,[]);assert.deepEqual(source.parcel_model.skins,[]);
  const svg=fs.readFileSync(path.join(root,base,'barcode.svg'),'utf8'),crop=fs.readFileSync(path.join(root,base,'candidate-r02/label-crop.svg'),'utf8');assert.equal(crop,svg.replace('viewBox="0 0 300 300"','viewBox="92 79 173 88"'));
  assert.equal(raw(base+'/review-receipt.json'),'26ec94893e29fce4aafc0d11807707ada5eeb384689b7de996a8150c67762c6b');assert.equal(raw(base+'/independent-image-review-r01.json'),'f05c3c4acbbdb905b68ace326655c6cefedfe17962af7cd649323b25df7b8642');
  assert.equal(receipt.selected_candidate.rgba_pixel_sha256,'c7f66774d8ea0ab8fa8123c4c15c8813e205eaa0fc71e26a082fd43b0bb9acec');assert.equal(receipt.native_validation.selected_candidate.checks,21);assert.equal(receipt.native_validation.selected_candidate.failures,0);assert.equal(receipt.native_validation.prior_attempt.preserved,true);assert.equal(raw(base+'/'+receipt.native_validation.prior_attempt.path),receipt.native_validation.prior_attempt.raw_sha256);
  assert.equal(receipt.selected_candidate.card_crops.length,4);for(const f of receipt.evidence_files)assert.equal(raw(base+'/'+f.path),f.sha256);for(const c of receipt.selected_candidate.card_crops)assert.equal(raw(base+'/'+c.path),c.sha256);
  const proposal=read(base+'/root-image-review-proposal.json');assert.equal(proposal.root_review_recorded,false);assert.deepEqual({...barcode.independent_approval,status:proposal.status,root_review_recorded:false,reviewer:null,recorded_at:null},proposal);
  assert.deepEqual(barcode.patches[0].after.media.image.adaptations,source.adaptations);
  const transaction=barcode.integration_guards.transaction_path,states=fs.readdirSync(path.join(root,transaction,'states')).filter(f=>/^\d{6}-[a-z-]+\.json$/.test(f)).sort(),committed=read(transaction+'/states/'+states.at(-1));assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,raw(transaction+'/prepared.json'));
});

test('cash register image preserves exact sales-device scope and the original approved Ava recording',()=>{
  const patch=cashRegister.patches[0],entry=data.lexemes.find(item=>item.id==='cash-register.sales-device.n');
  assert.equal(cashRegister.patches.length,1);assert.equal(patch.id,entry.id);assert.deepEqual(entry,patch.after);
  assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(entry),patch.after_sha256);assert.equal(hash(protectedEntry(patch.before,'image')),patch.protected_fields_sha256);assert.deepEqual(protectedEntry(entry,'image'),protectedEntry(patch.before,'image'));
  const expected=structuredClone(patch.before);expected.media.image=patch.after.media.image;assert.equal(expected.editorial_notes.split(patch.note_change.before).length,2);expected.editorial_notes=expected.editorial_notes.replace(patch.note_change.before,patch.note_change.after);assert.deepEqual(entry,expected);
  assert.equal(patch.note_change.before,'Picture suitability and word-media production remain pending.');assert.equal(patch.note_change.after,'The cash register image has completed scoped sales-device picture review. The exact Ava word recording has user listening approval and is integrated.');
  assert.equal(entry.media.image.status,'integrated');assert.equal(entry.media.image.review.status,'reviewed');assert.equal(entry.media.image.brief,patch.before.media.image.brief);assert.deepEqual(entry.media.image.available_animations,[]);
  assert.deepEqual(entry.media.audio,patch.before.media.audio);assert.equal(entry.media.audio.sha256,'0f883c09be9a86be9f30e444953d001d3a385ba71034e60ceb4181fc0b9aa763');assert.equal(raw(entry.media.audio.path.slice(6)),entry.media.audio.sha256);assert.equal(entry.media.audio.status,'integrated');assert.equal(entry.media.audio.review.status,'reviewed');assert.deepEqual(entry.media.audio.voice_settings,approval.profile);
  assert.deepEqual(entry.morphology,patch.before.morphology);assert.equal(entry.morphology.review.status,'reviewed');assert.deepEqual(entry.review,patch.before.review);assert.equal(entry.review.domain,'pending');assert.equal(entry.review.language,'reviewed');assert.equal(entry.review.status,'pending');assert.ok(data.courses.every(c=>c.modules.every(m=>m.status==='draft')));
});

test('cash register retains exact Tiny Treats CC0 sources, accepted pixels and immutable failed attempt',()=>{
  const base=cashRegister.retained_evidence,source=read(cashRegister.source_records[0]),receipt=read(base+'/review-receipt.json');
  assert.equal(cashRegister.independent_approval.status,'accepted_exact_candidate_for_guarded_image_only_integration');assert.equal(raw(base+'/root-picture-acceptance-r01.json'),'70f7d183dee631642befddff9f3ebf0a9a7f8401c9ee69c826c48478f08f57c4');assert.deepEqual(cashRegister.independent_approval,read(base+'/root-picture-acceptance-r01.json'));
  assert.equal(raw(cashRegister.resource.path),'f3d4af9b28662c135481459cd0eb9f67ef7e30db3633a745a79ce550c00af262');assert.deepEqual([cashRegister.resource.width,cashRegister.resource.height,cashRegister.resource.compressed_bytes,cashRegister.resource.decoded_bytes],[512,615,172442,2519040]);
  assert.equal(source.source,'https://tinytreats.itch.io/bakery-interior');assert.equal(source.creator,'Isa Lousberg');assert.equal(source.publisher,'Tiny Treats');assert.equal(source.license,'CC0 1.0');assert.equal(source.acquisition.archive_sha256,'1754373c399dd9b7eb074cc12367ea8f31ffc2cf7d1a9f8027b9661a0aafb562');assert.equal(raw(base+'/'+source.acquisition.archive_path),source.acquisition.archive_sha256);assert.deepEqual(source.available_animations,[]);assert.deepEqual(source.skins,[]);
  assert.equal(source.status,'acquired_for_scratch_source_inspection_only');for(const file of source.files)assert.equal(raw(base+'/'+file.path),file.sha256);assert.deepEqual([source.totals.meshes,source.totals.vertices,source.totals.triangles],[2,1643,1612]);
  assert.equal(raw(base+'/review-receipt.json'),'76dc57f2dfde062857cd91636ef9fa1dbcd407a4089c17f0eede8d2f0566c301');assert.equal(receipt.native_validation.selected_candidate.checks,75);assert.equal(receipt.native_validation.selected_candidate.failures,0);assert.equal(receipt.selected_candidate.rgba_pixel_sha256,'9b4c0719804d15ae2a936830a22e89ccaea48ac5b860bb6ca508856d73959297');assert.deepEqual(cashRegister.patches[0].after.media.image.adaptations,receipt.selected_candidate.adaptations);
  assert.equal(receipt.native_validation.prior_attempt.preserved,true);assert.equal(raw(base+'/'+receipt.native_validation.prior_attempt.path),receipt.native_validation.prior_attempt.raw_sha256);assert.equal(read(base+'/'+receipt.native_validation.prior_attempt.path).status,'failed_attempt_preserved');
  for(const file of receipt.evidence_files)assert.equal(raw(base+'/'+file.path),file.sha256);assert.equal(receipt.selected_candidate.card_crops.length,4);for(const crop of receipt.selected_candidate.card_crops)assert.equal(raw(base+'/'+crop.path),crop.sha256);
  const transaction=cashRegister.integration_guards.transaction_path,states=fs.readdirSync(path.join(root,transaction,'states')).filter(f=>/^\d{6}-[a-z-]+\.json$/.test(f)).sort(),committed=read(transaction+'/states/'+states.at(-1));assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,raw(transaction+'/prepared.json'));
});
