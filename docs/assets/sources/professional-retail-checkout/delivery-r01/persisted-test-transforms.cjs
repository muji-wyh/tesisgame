'use strict';
const assert=require('node:assert/strict');
const testPaths=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs'];
const provenance='data/professional/provenance/retail-checkout-image-2026-10-16.json';
function once(text,before,after){assert.equal(text.split(before).length,2,'Expected one exact test anchor: '+before.slice(0,150));return text.replace(before,after);}
function reversal(record){return `function beforeCheckoutImage(entry) {
  const patch = ${record}.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later checkout image and pending-image note delta');
  return structuredClone(patch.before);
}`;}
const newTests=`
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
`;
function transformTests(inputs){
  assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const outputs={};
  for(const file of testPaths){const newline=inputs[file].includes('\r\n')?'\r\n':'\n';let text=inputs[file].replaceAll('\r\n','\n');assert.equal(text.includes(provenance),false,'Checkout image test update is one-shot');
    if(file.endsWith('/professional-content.test.cjs')){
      const anchor='const retail03MediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord, counterCheckoutAudioRecord];';
      text=once(text,anchor,"const checkoutImageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '"+provenance+"'), 'utf8'));\n"+anchor.replace('counterCheckoutAudioRecord];','counterCheckoutAudioRecord, checkoutImageRecord];'));
      text=once(text,'assert.equal(result.summary.integrated_word_images, 5);','assert.equal(result.summary.integrated_word_images, 6);');
    }else if(file.endsWith('/professional-retail-morphology.test.cjs')){
      const anchor='const mediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord, counterCheckoutAudioRecord];';
      text=once(text,anchor,"const checkoutImageRecord = JSON.parse(fs.readFileSync(path.join(root, '"+provenance+"')));\n"+anchor.replace('counterCheckoutAudioRecord];','counterCheckoutAudioRecord, checkoutImageRecord];')+'\n'+reversal('checkoutImageRecord'));
      text=once(text,'function beforeCounterCheckoutAudio(entry) {\n','function beforeCounterCheckoutAudio(entry) {\n  entry = beforeCheckoutImage(entry);\n');
    }else{
      const anchor="const counterCheckoutAudio=read('data/professional/provenance/retail-counter-checkout-approved-audio-2026-10-16.json');";
      text=once(text,anchor,anchor+"\nconst checkout=read('"+provenance+"');\n"+reversal('checkout'));
      text=once(text,'function beforeCounterCheckoutAudio(entry) {\n','function beforeCounterCheckoutAudio(entry) {\n  entry = beforeCheckoutImage(entry);\n');
      text=once(text,"assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,5);","assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,6);");
      text=once(text,'assert.deepEqual(data.lexemes.find(entry=>entry.id===patch.sense_id),patch.after);','assert.deepEqual(beforeCheckoutImage(data.lexemes.find(entry=>entry.id===patch.sense_id)),patch.after);');
      text+=newTests;
    }
    outputs[file]=text.replaceAll('\n',newline);
  }return outputs;
}
module.exports={testPaths,transformTests};
