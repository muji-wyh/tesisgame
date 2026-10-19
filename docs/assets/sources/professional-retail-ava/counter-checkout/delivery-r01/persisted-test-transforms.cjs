'use strict';
const assert=require('node:assert/strict');
const testPaths=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs','tests/godot/professional_approved_audio_tests.gd'];
const provenance='data/professional/provenance/retail-counter-checkout-approved-audio-2026-10-16.json';
function replace(text,before,after,count=1){assert.equal(text.split(before).length,count+1,'Expected exact test anchor: '+before.slice(0,150));return text.split(before).join(after);}
const reverseFunction=record=>`function beforeCounterCheckoutAudio(entry) {
  const patch = ${record}.patches.find(item => item.sense_id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later approved counter or checkout audio and note delta');
  return structuredClone(patch.before);
}`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const outputs={};
  for(const file of testPaths){
    const newline=inputs[file].includes('\r\n')?'\r\n':'\n';let text=inputs[file].replaceAll('\r\n','\n');
    assert.equal(text.includes(provenance),false,'Pair update is one-shot');
    if(file.endsWith('/professional-content.test.cjs')){
      const anchor='const retail03MediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord];';
      text=replace(text,anchor,"const counterCheckoutAudioRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '"+provenance+"'), 'utf8'));\n"+anchor.replace('counterImageRecord]','counterImageRecord, counterCheckoutAudioRecord]'));
      text=replace(text,'assert.equal(result.summary.integrated_word_audio, 8);','assert.equal(result.summary.integrated_word_audio, 10);');
    }else if(file.endsWith('/professional-retail-morphology.test.cjs')){
      const anchor='const mediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord];';
      text=replace(text,anchor,"const counterCheckoutAudioRecord = JSON.parse(fs.readFileSync(path.join(root, '"+provenance+"')));\n"+anchor.replace('counterImageRecord]','counterImageRecord, counterCheckoutAudioRecord]')+'\n'+reverseFunction('counterCheckoutAudioRecord'));
      text=replace(text,'function beforeCounterImage(entry) {\n','function beforeCounterImage(entry) {\n  entry = beforeCounterCheckoutAudio(entry);\n');
    }else if(file.endsWith('/professional-retail-media.test.cjs')){
      const anchor="const counter=read('data/professional/provenance/retail-counter-image-2026-10-16.json');";
      text=replace(text,anchor,anchor+"\nconst counterCheckoutAudio=read('"+provenance+"');\n"+reverseFunction('counterCheckoutAudio'));
      text=replace(text,"assert.equal(data.lexemes.filter(e=>e.media.audio.status==='integrated').length,8);","assert.equal(counterCheckoutAudio.preserved_audio_files.length,1903);\n  for(const file of counterCheckoutAudio.preserved_audio_files)assert.equal(raw(file.path),file.sha256,file.path);\n  assert.equal(data.lexemes.filter(e=>e.media.audio.status==='integrated').length,10);");
      text=replace(text,"const patch=counter.patches[0],entry=data.lexemes.find(item=>item.id==='counter.service-surface.n');","const patch=counter.patches[0],entry=beforeCounterCheckoutAudio(data.lexemes.find(item=>item.id==='counter.service-surface.n'));");
      text+=`
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
    assert.deepEqual(data.lexemes.find(entry=>entry.id===patch.sense_id),patch.after);
    assert.equal(hash(patch.before),patch.before_sha256);assert.equal(hash(protectedEntry(patch.before,'audio')),patch.protected_fields_sha256);
    assert.deepEqual(protectedEntry(patch.after,'audio'),protectedEntry(patch.before,'audio'));
    assert.equal(patch.after.editorial_notes,patch.before.editorial_notes.replace(patch.note_change.before,patch.note_change.after));
    assert.equal(patch.before.editorial_notes.split(patch.note_change.before).length,2);
    assert.deepEqual(patch.after.media.audio.voice_settings,approval.profile);assert.equal(patch.after.media.audio.review.status,'reviewed');
    assert.deepEqual(patch.after.media.image,patch.before.media.image);assert.deepEqual(patch.after.morphology,patch.before.morphology);assert.equal(patch.after.review.domain,'pending');
  }
  const counterPatch=counterCheckoutAudio.patches.find(patch=>patch.sense_id==='counter.service-surface.n');
  assert.deepEqual(counterPatch.before,counter.patches[0].after);assert.equal(counterPatch.after.media.image.sha256,'c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a');
  assert.ok(data.courses.every(course=>course.modules.every(module=>module.status==='draft')));
});
`;
    }else{
      const anchor='\t\t_read("res://data/professional/provenance/retail-bag-wrap-approved-audio-2026-10-16.json"),';
      text=replace(text,anchor,anchor+'\n\t\t_read("res://'+provenance+'"),');
      for(const[before,after,count]of [
        ['patches.size() == 8','patches.size() == 10',1],['All eight exact user-approved recordings','All ten exact user-approved recordings',1],
        ['audio-delivery-review-4','audio-delivery-review-5',2],['decoded_total == 660432','decoded_total == 825540',1],
        ['Eight immutable recording receipts','Ten immutable recording receipts',1],['All eight exact sense dependencies','All ten exact sense dependencies',1],
        ['all eight immutable production WAV files','all ten immutable production WAV files',1],['all eight approved audio resources','all ten approved audio resources',1],
        ['active.resources == 8','active.resources == 10',1],['Eight complete clips','Ten complete clips',1]
      ])text=replace(text,before,after,count);
    }
    outputs[file]=text.replaceAll('\n',newline);
  }
  return outputs;
}
module.exports={testPaths,transformTests};
