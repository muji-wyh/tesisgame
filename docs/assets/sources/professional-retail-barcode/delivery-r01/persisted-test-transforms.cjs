'use strict';
const assert=require('node:assert/strict');
const testPaths=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs'];
const provenance='data/professional/provenance/retail-barcode-image-2026-10-16.json';
function once(text,before,after){assert.equal(text.split(before).length,2,'Expected one exact test anchor: '+before.slice(0,150));return text.replace(before,after);}
const reversal=`function beforeBarcodeImage(entry) {
  const patch = barcodeImageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.deepEqual(entry, patch.after, entry.id + ': exact later barcode image and pending-image clause delta');
  return structuredClone(patch.before);
}`;
const newTests=`
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
  const transaction=barcode.integration_guards.transaction_path,states=fs.readdirSync(path.join(root,transaction,'states')).filter(f=>/^\\d{6}-[a-z-]+\\.json$/.test(f)).sort(),committed=read(transaction+'/states/'+states.at(-1));assert.equal(committed.status,'committed');assert.equal(committed.prepared_sha256,raw(transaction+'/prepared.json'));
});
`;
function transformTests(inputs){
 assert.deepEqual(Object.keys(inputs).sort(),[...testPaths].sort());const outputs={};
 for(const file of testPaths){const newline=inputs[file].includes('\r\n')?'\r\n':'\n';let text=inputs[file].replaceAll('\r\n','\n');assert.equal(text.includes(provenance),false,'Barcode image test update is one-shot');
  if(file.endsWith('/professional-content.test.cjs')){
   const anchor='const retail03MediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord, counterCheckoutAudioRecord, checkoutImageRecord];';
   text=once(text,anchor,"const barcodeImageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, '"+provenance+"'), 'utf8'));\n"+anchor.replace('checkoutImageRecord];','checkoutImageRecord, barcodeImageRecord];'));
   text=once(text,'assert.equal(result.summary.integrated_word_images, 6);','assert.equal(result.summary.integrated_word_images, 7);');
  }else if(file.endsWith('/professional-retail-morphology.test.cjs')){
   const anchor='const mediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord, counterCheckoutAudioRecord, checkoutImageRecord];';
   text=once(text,anchor,"const barcodeImageRecord = JSON.parse(fs.readFileSync(path.join(root, '"+provenance+"'), 'utf8'));\n"+anchor.replace('checkoutImageRecord];','checkoutImageRecord, barcodeImageRecord];')+'\n'+reversal);
   text=once(text,'function beforeCounterImage(entry) {\n','function beforeCounterImage(entry) {\n  entry = beforeBarcodeImage(entry);\n');
  }else{
   const anchor="const checkout=read('data/professional/provenance/retail-checkout-image-2026-10-16.json');";text=once(text,anchor,anchor+"\nconst barcode=read('"+provenance+"');");
   text=once(text,"assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,6);","assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,7);");text+=newTests;
  }outputs[file]=text.replaceAll('\n',newline);
 }return outputs;
}
module.exports={testPaths,transformTests};
