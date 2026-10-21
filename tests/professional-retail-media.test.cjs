'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const read=f=>JSON.parse(fs.readFileSync(path.join(root,f),'utf8'));
const raw=f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex');
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const data=require('../tools/validate-professional-content.cjs').loadProfessionalContent(root);
// Pre-morphology language/donor assertions use the exact immutable Foundation02 snapshot.
// Current graphs and all protected lexical fields have separate exact current coverage.
const foundation02HistoryPath = 'build/professional-english/foundation02-morphology-integration-proposal-r01/preimages/data/professional/lexemes/foundation-module02.json';
const foundation02HistoryBytes = fs.readFileSync(path.join(root, foundation02HistoryPath));
assert.equal(crypto.createHash('sha256').update(foundation02HistoryBytes).digest('hex'), '6cf78346c223e65bb3c4b30af10d2a564f03c10ba1f4593836f8ccbeea2e2576');
const historicalFoundation02Entries = new Map(JSON.parse(foundation02HistoryBytes).lexemes.map(entry => [entry.id, entry]));
const foundation02HistoryLexemes = data.lexemes.map(entry => historicalFoundation02Entries.get(entry.id) || entry);

// Preserve old whole-entry comparisons without undoing later live image changes.
const historicalRetailPath = 'build/professional-english/foundation02-held-six-work-r01/historical-source/data/professional/lexemes/retail-pilot.json';
const historicalRetailBytes = fs.readFileSync(path.join(root, historicalRetailPath));
assert.equal(raw(historicalRetailPath), 'e5029b78d5093acc9d35440df78a5e34e0fdd29d08a2617104a8f7c57efa0df2');
const historicalRetail = JSON.parse(historicalRetailBytes);
const giftWrapImageRecord = read('data/professional/provenance/retail-gift-wrap-image-2026-10-17.json');

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
const cardReaderBarcodeAudio=read('data/professional/provenance/retail-card-reader-barcode-approved-audio-2026-10-16.json');
const { beforeCardReaderImage, beforeCardReaderImageBytes } = require('./helpers/professional-card-reader-history.cjs');
function beforeCardReaderBarcodeAudio(entry) {
  entry = beforeCardReaderImage(entry);
  const patch = cardReaderBarcodeAudio.patches.find(item => item.sense_id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later user-approved card reader or barcode audio and note delta');
  return structuredClone(patch.before);
}
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
const shoppingBagImageRecord=read('data/professional/provenance/retail-shopping-bag-image-2026-10-17.json');
const foundation02FifthLanguageRecord = JSON.parse(fs.readFileSync(path.join(root, 'data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json'), 'utf8'));
function beforeFoundation02FifthLanguage(entry) {
  const patches = foundation02FifthLanguageRecord.patches.filter(patch => patch.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact fifth-ten language and metadata');
  return structuredClone(patch.before);
}
function beforeFoundation02FifthSources(sources) {
  const additions = foundation02FifthLanguageRecord.sources;
  assert.equal(additions.length, 16);
  assert.equal(new Set(additions.map(row => row.id)).size, 16);
  assert.deepEqual(sources.slice(-16), additions, 'Exact fifth-ten sixteen-source suffix required');
  const prefix = sources.slice(0, -16);
  for (const addition of additions) assert.equal(prefix.some(row => row.id === addition.id), false);
  return prefix;
}
function fifthLanguageHash(value) {
  return require('node:crypto').createHash('sha256').update(JSON.stringify(value)).digest('hex');
}
function verifyFifthLanguageDonors(registry, readHistory) {
  const rows = foundation02FifthLanguageRecord.history.rows;
  assert.equal(rows.length, 50);
  assert.equal(new Set(rows.map(row => row.history_path + '/' + row.id)).size, 50);
  for (const expected of rows) {
    const historical = readHistory(expected.history_path).protected_context.lexemes;
    assert.equal(expected.exact_count, 1);
    assert.equal(historical.filter(row => row.entry.id === expected.id).length, 1);
    const actual = historical[expected.index];
    assert.deepEqual(actual, expected.whole_row);
    assert.equal(fifthLanguageHash(actual), expected.whole_row_json_sha256);
    assert.equal(fifthLanguageHash(actual.entry), actual.json_sha256);
    assert.equal(registry.lexemeOrigins[expected.id], actual.resource);
    assert.deepEqual(beforeFoundation02FifthLanguage(historicalFoundation02Entries.get(expected.id) || registry.lexemes.find(entry => entry.id === expected.id)), actual.entry);
  }
}
function beforeShoppingBagImage(entry) {
  const patches = shoppingBagImageRecord.patches.filter(item => item.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  assert.equal(patch.id, 'shopping-bag.goods-carrier.n');
  assert.deepEqual(entry, patch.after, entry.id + ': exact later shopping-bag image and three note clauses');
  return structuredClone(patch.before);
}
function beforeFifth10(entry) {
  entry = beforeShoppingBagImage(entry);
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
  assert.equal(cardReaderBarcodeAudio.preserved_audio_files.length,1905);
  for(const file of cardReaderBarcodeAudio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);
  assert.equal(data.lexemes.filter(e=>e.media.audio.status==='integrated').length,12);
  assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,11);
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
    assert.deepEqual(beforeFifth10(historicalRetail.lexemes.find(e=>e.id===patch.sense_id)),patch.after);
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
  const patch=barcode.patches[0],entry=beforeCardReaderBarcodeAudio(data.lexemes.find(item=>item.id==='barcode.product-code.n'));
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

test('card reader and barcode bind the recovered human reply to the exact presented recordings',()=>{
  const accepted=read(cardReaderBarcodeAudio.approval),human=read(accepted.evidence.human_record);
  assert.equal(raw(cardReaderBarcodeAudio.approval),cardReaderBarcodeAudio.approval_raw_sha256);
  assert.equal(accepted.status,'approved_by_user');
  assert.equal(accepted.evidence.source_thread_id,'01a14325-e5ce-72a2-8b1a-b746c89e20c6');
  assert.equal(accepted.evidence.source_turn_id,'01a144de-9fa7-7b03-808c-2d0aa3cfc73c');
  assert.deepEqual(accepted.evidence.question_item_id,['request_user_input_async','call_7xvby6MgGR1DNVzcwIkhjACI',0]);
  assert.equal(accepted.evidence.answer_english,'Both are acceptable.');
  assert.equal(raw(accepted.evidence.human_record),accepted.evidence.human_record_raw_sha256);
  assert.equal(human.status,'exact_presented_pair_user_approved');
  assert.deepEqual(human.question_item_id,accepted.evidence.question_item_id);
  assert.equal(raw(accepted.technical_qa.path),'ef75d3504e385ef1c4037a30609d35658cfeca5636af363d76edccd27d4c49f1');
  assert.equal(raw(accepted.listening_request.path),accepted.listening_request.raw_sha256);
  assert.equal(read(accepted.listening_request.path).status,'presented_to_user_pending_listening_response');
  assert.deepEqual(accepted.profile,approval.profile);
  assert.deepEqual(accepted.outputs.map(item=>item.sense_id),['card-reader.payment-device.n','barcode.product-code.n']);
  const expected=['acd48c920c631906e6ff0775cf3f373c247687fcb128b41e3ce0f3bdf668ba45','01b2666324e5e373b75799535d8a78494a6afe8225c4b82147975d55405c96e5'];
  for(const [index,out]of accepted.outputs.entries()){
    assert.equal(out.wav_sha256,expected[index]);
    for(const file of [out.presented_path,out.retained_wav])assert.equal(raw(file),out.wav_sha256);
    assert.equal(raw(out.retained_mp3),out.source_mp3_sha256);assert.equal(raw(out.acquisition_receipt),out.acquisition_receipt_raw_sha256);
    const acquired=read(out.acquisition_receipt);assert.equal(acquired.pronunciation_and_listening_review,'pending');assert.equal(acquired.production_integrated,false);
    const patch=cardReaderBarcodeAudio.patches.find(item=>item.sense_id===out.sense_id);
    assert.equal(raw(patch.resource.path),out.wav_sha256);assert.equal(patch.resource.decoded_bytes,82554);assert.equal(patch.resource.frames,41277);
  }
  for(const file of cardReaderBarcodeAudio.retained_files){assert.equal(raw(file.path),file.raw_sha256);assert.equal(raw(file.source),file.raw_sha256);}
});

test('card reader and barcode audio preserve every prior image, lexical field and review gate',()=>{
  assert.equal(cardReaderBarcodeAudio.patches.length,2);
  const validation=read(cardReaderBarcodeAudio.lineage.validation);
  assert.equal(raw(cardReaderBarcodeAudio.lineage.validation),cardReaderBarcodeAudio.lineage.validation_raw_sha256);
  assert.equal(validation.ok,true);assert.equal(validation.registry_after_sha256,cardReaderBarcodeAudio.before_registry_sha256);
  assert.equal(cardReaderBarcodeAudio.baseline_summary.integrated_word_images,8);
  assert.equal(cardReaderBarcodeAudio.baseline_summary.integrated_word_audio,10);
  for(const patch of cardReaderBarcodeAudio.patches){
    assert.deepEqual(beforeCardReaderImage(data.lexemes.find(entry=>entry.id===patch.sense_id)),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length,2);
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace(patch.note_change.before,patch.note_change.after));
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);assert.equal(patch.after.media.audio.review.status,'reviewed');
    assert.deepEqual(patch.after.media.image,patch.before.media.image);assert.deepEqual(patch.after.morphology,patch.before.morphology);
    assert.deepEqual(patch.after.review,patch.before.review);assert.equal(patch.after.review.domain,'pending');assert.equal(patch.after.review.status,'pending');
    const changed=structuredClone(patch.after);changed.definition+=' Unexpected change.';assert.throws(()=>beforeCardReaderBarcodeAudio(changed));
  }
  const barcodePatch=cardReaderBarcodeAudio.patches.find(item=>item.sense_id==='barcode.product-code.n');
  assert.deepEqual(barcodePatch.before,barcode.patches[0].after);
  assert.equal(barcodePatch.after.media.image.sha256,'a818b742ce3fe1543298ce2330464e59cdfa341508062c67834a62c73774a69c');
  assert.equal(cardReaderBarcodeAudio.patches.find(item=>item.sense_id==='card-reader.payment-device.n').after.media.image.status,'pending');
  assert.equal(cardReaderBarcodeAudio.preserved_images.length,8);
  for(const file of cardReaderBarcodeAudio.preserved_images)assert.equal(raw(file.path),file.sha256);
  const master=cardReaderBarcodeAudio.preserved_collection_master;assert.equal(raw(master.path),master.sha256);
  const transaction=cardReaderBarcodeAudio.integration_guards.transaction_path;
  const states=fs.readdirSync(path.join(root,transaction,'states')).filter(file=>/^\d{6}-[a-z-]+\.json$/.test(file)).sort();
  const committed=read(transaction+'/states/'+states.at(-1));assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,raw(transaction+'/prepared.json'));
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});


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
  assert.equal(data.lexemes.filter(entry=>entry.media.image.status==='integrated').length,11);
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


test('Fifth-ten language history preserves delivered bag media without relaxing bag reversal', () => {
  const bag=shoppingBagImageRecord.patches[0];assert.deepEqual(data.lexemes.find(e=>e.id===bag.id),bag.after);
  assert.equal(beforeFoundation02FifthLanguage(bag.after),bag.after);assert.throws(()=>beforeShoppingBagImage(bag.before));
  for(const p of foundation02FifthLanguageRecord.patches){const entry=foundation02HistoryLexemes.find(e=>e.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.media,p.before.media);assert.equal(beforeShoppingBagImage(entry),entry);assert.deepEqual(beforeFoundation02FifthLanguage(entry),p.before);}
});

test('Gift-wrap image changes exactly three current fields and preserves every other Retail byte', () => {
  const record = giftWrapImageRecord;
  const id = 'gift-wrap.wrapping-paper.n';
  const entry = data.lexemes.find(item => item.id === id);
  const before = record.entry_before;
  const after = record.entry_after;
  assert.equal(record.sense_id, id);
  assert.deepEqual(before, historicalRetail.lexemes.find(item => item.id === id));
  assert.equal(hash(before), '2fd752205a7a5dbdf35a69ed77cf91d9d35e4342999cc23104b21f5472c50467');
  assert.equal(hash(after), '401ae29f8d864b10de09b9cd5d5ed937257b250768c756deb7c1d8606e0b22b2');
  assert.equal(hash(before), record.patch.before_entry_json_sha256);
  assert.equal(hash(after), record.patch.after_entry_json_sha256);
  assert.deepEqual(entry, after);
  assert.deepEqual(entry.practice_modes, ['word_jelly']);
  assert.equal(entry.media.image.picture_suitable, false);
  assert.equal(before.editorial_notes.split(record.patch.note_replacement.before).length, 2);
  assert.equal(entry.editorial_notes,
    before.editorial_notes.replace(record.patch.note_replacement.before, record.patch.note_replacement.after));
  const unchanged = structuredClone(entry);
  unchanged.media.image = before.media.image;
  unchanged.practice_modes = before.practice_modes;
  unchanged.editorial_notes = before.editorial_notes;
  assert.deepEqual(unchanged, before, 'Audio, graph, forms, example, references and review gates remain exact.');
  for (const key of ['morphology', 'accepted_forms', 'example', 'references', 'review']) {
    assert.deepEqual(entry[key], before[key], key);
  }
  assert.deepEqual(entry.media.audio, before.media.audio);

  const currentRetailBytes = beforeCardReaderImageBytes(fs.readFileSync(path.join(root, 'data/professional/lexemes/retail-pilot.json')));
  const currentRetail = JSON.parse(currentRetailBytes);
  assert.equal(historicalRetail.lexemes.length, 48);
  assert.deepEqual(currentRetail.lexemes.filter(item => item.id !== id),
    historicalRetail.lexemes.filter(item => item.id !== id));
  const expectedRetail = structuredClone(historicalRetail);
  expectedRetail.lexemes[expectedRetail.lexemes.findIndex(item => item.id === id)] = after;
  assert.deepEqual(currentRetail, expectedRetail);
  assert.equal(historicalRetailBytes.toString('utf8'), JSON.stringify(historicalRetail, null, 2) + '\n');
  assert.equal(currentRetailBytes.toString('utf8'),
    JSON.stringify(expectedRetail, null, 2) + '\n', 'The serialized delta preserves every unrelated raw byte.');
  assert.equal(crypto.createHash('sha256').update(currentRetailBytes).digest('hex'),
    'dee9e024d357c343aaa89b75b19cb5edbccdfe9d7d9595ead8613d7b847402c0');
  assert.equal(raw('data/professional/catalog.json'),
    '0f7509c742d1784e0d48562e1d4b60ee3ded9cb9310c3330a1ab548c563c17be');
  assert.equal(raw('data/professional/courses/retail.json'),
    '954ff4d705b71a7bb8833e1a9c11f4b9475446b05b5fa3214bff25d421be8a3e');
  assert.ok(data.courses.every(course => course.modules.every(module => module.status === 'draft')));
  const module = data.courses.find(course => course.id === 'retail').modules.find(module => module.id === 'module03');
  assert.equal(module.media_manifest, undefined);
  assert.ok(module.lexeme_ids.includes(id));
});

test('Gift-wrap production PNG is the exact acquired crop with bounded resource accounting', () => {
  const record = giftWrapImageRecord;
  const image = data.lexemes.find(entry => entry.id === record.sense_id).media.image;
  const resource = record.resource;
  assert.deepEqual(image, record.entry_after.media.image);
  assert.equal(resource.path, 'res://professional-media/c97a15eac5680c4ffaf0d70f3c6b7a740fd86a4a804c3d517e13f21d52caf789.png');
  const file = resource.path.slice(6);
  const bytes = fs.readFileSync(path.join(root, file));
  assert.equal(raw(file), 'c97a15eac5680c4ffaf0d70f3c6b7a740fd86a4a804c3d517e13f21d52caf789');
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(8), 13);
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR');
  assert.equal(bytes.readUInt32BE(16), 600);
  assert.equal(bytes.readUInt32BE(20), 173);
  assert.equal(bytes.length, 36970);
  assert.equal(resource.compressed_bytes, bytes.length);
  assert.equal(resource.decoded_bytes, 600 * 173 * 8);
  assert.equal(resource.decoded_bytes, 830400);
  assert.equal(resource.width, 600); assert.equal(resource.height, 173);
  assert.equal(resource.kind, 'image'); assert.equal(resource.format, 'png');
  assert.equal(resource.sha256, raw(file));
  assert.equal(image.path, resource.path); assert.equal(image.sha256, resource.sha256);
  assert.equal(image.status, 'integrated'); assert.equal(image.acquisition_status, 'integrated');
  assert.equal(image.review.status, 'reviewed'); assert.equal(image.picture_suitable, false);
  assert.equal(image.creator, 'j4p4n'); assert.equal(image.license, 'CC0 1.0 Universal / Public Domain');
  assert.equal(image.source, 'res://' + record.source_review.path);
  assert.equal(image.brief, record.revised_brief);
  assert.deepEqual(image.available_animations, []);
});

test('Gift-wrap provenance retains the acquired originals, old brief and exact approved Ava recording', () => {
  const record = giftWrapImageRecord;
  const frozenPath = 'build/professional-english/gift-wrap-integration-proposal-r02/provenance.proposed.json';
  assert.equal(raw(frozenPath), '2d05fe6b4218159203905825c860ea2aa1cdbbc24d3eb651228108f3c39113a9');
  const frozen = read(frozenPath);
  for (const key of ['source_review', 'source', 'resource', 'patch', 'original_brief', 'revised_brief', 'approved_audio']) {
    assert.deepEqual(record[key], frozen[key], key + ': retained source facts are not rewritten as installation evidence');
  }
  for (const retained of [record.source_review, record.source.original, record.source.crop]) {
    assert.equal(raw(retained.path), retained.sha256, retained.path);
    assert.equal(fs.statSync(path.join(root, retained.path)).size, retained.bytes, retained.path);
  }
  const sourceReview = read(record.source_review.path);
  assert.equal(sourceReview.candidate.raster.acquisition_status, 'acquired_published_raster_under_CC0_not_integrated');
  assert.equal(sourceReview.candidate.crop.status, 'Review derivative only, not integrated');
  assert.equal(sourceReview.visual_review.actual_game_render, false);
  assert.equal(sourceReview.candidate.crop.rgba_pixel_mismatches, 0,
    'This is the retained source comparison; header/hash checks do not decode or compare pixels.');
  assert.deepEqual(sourceReview.candidate.crop.source_rect_xywh, [0, 217, 600, 173]);
  assert.equal(record.source.vector_acquired, false);
  assert.deepEqual(record.source.available_animations, []);
  assert.equal(record.original_brief, record.entry_before.media.image.brief);
  assert.equal(record.revised_brief, record.entry_after.media.image.brief);
  assert.notEqual(record.original_brief, record.revised_brief);
  assert.equal(raw(record.approved_audio.path.slice(6)), record.approved_audio.sha256);
  assert.equal(record.approved_audio.sha256, 'cad8619dad6e225ce73c835ce5e90f7252c42af3c546aaa393adcd8db3e0f3a2');
  const audioDescriptor = data.lexemes.find(entry => entry.id === record.sense_id).media.audio;
  assert.deepEqual(audioDescriptor, record.entry_before.media.audio);
  assert.deepEqual(audioDescriptor.voice_settings,
    {voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%', postprocessing: false});
  const acceptedAudio = bagWrapAudio.patches.find(patch => patch.sense_id === record.sense_id);
  assert.deepEqual(audioDescriptor, acceptedAudio.after.media.audio);
});
