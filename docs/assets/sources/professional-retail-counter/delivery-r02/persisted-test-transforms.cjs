'use strict';
const assert = require('node:assert/strict');
const testPaths = ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs'];
function once(text, before, after) {
  assert.equal(text.split(before).length, 2, 'Expected one exact test anchor: ' + before.slice(0, 150));
  return text.replace(before, after);
}
function transformTests(inputs) {
  assert.deepEqual(Object.keys(inputs).sort(), [...testPaths].sort());
  const outputs = {};
  for (const file of testPaths) {
    const newline = inputs[file].includes('\r\n') ? '\r\n' : '\n';
    let text = inputs[file].replaceAll('\r\n', '\n');
    assert.equal(text.includes('retail-counter-image-2026-10-16.json'), false, 'Counter test update is one-shot');
    if (file.endsWith('/professional-content.test.cjs')) {
      const anchor = 'const retail03MediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord];';
      text = once(text, anchor,
        "const counterImageRecord = JSON.parse(fs.readFileSync(path.join(rootDir, 'data/professional/provenance/retail-counter-image-2026-10-16.json'), 'utf8'));\n" +
        'const retail03MediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord];');
      text = once(text, 'assert.equal(result.summary.integrated_word_images, 4);', 'assert.equal(result.summary.integrated_word_images, 5);');
    } else if (file.endsWith('/professional-retail-morphology.test.cjs')) {
      const anchor = 'const mediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord];';
      text = once(text, anchor,
        "const counterImageRecord = JSON.parse(fs.readFileSync(path.join(root, 'data/professional/provenance/retail-counter-image-2026-10-16.json')));\n" +
        'const mediaRecords = [cartBasketAudioRecord, palletImageRecord, shelfImageRecord, palletShelfAudioRecord, bagWrapAudioRecord, counterImageRecord];\n' +
        'function beforeCounterImage(entry) {\n' +
        '  const patch = counterImageRecord.patches.find(item => item.id === entry.id);\n' +
        '  if (!patch) return entry;\n' +
        "  assert.deepEqual(entry, patch.after, entry.id + ': exact later counter image and note delta');\n" +
        '  return structuredClone(patch.before);\n' +
        '}');
      text = once(text,
        'for (const snapshot of fifthRecord.protected_related_entries) assert.deepEqual(data.lexemes.find(entry => entry.id === snapshot.entry.id), snapshot.entry);',
        'for (const snapshot of fifthRecord.protected_related_entries) assert.deepEqual(beforeCounterImage(data.lexemes.find(entry => entry.id === snapshot.entry.id)), snapshot.entry);');
      text = once(text,
        'for (const [id, expected] of Object.entries(fifthRecord.protected_first40_entry_json_sha256)) assert.equal(hash(data.lexemes.find(entry => entry.id === id)), expected);',
        'for (const [id, expected] of Object.entries(fifthRecord.protected_first40_entry_json_sha256)) assert.equal(hash(beforeCounterImage(data.lexemes.find(entry => entry.id === id))), expected);');
    } else {
      const anchor = "const shelf=read('data/professional/provenance/retail-shelf-image-2026-10-16.json');";
      text = once(text, anchor, anchor + "\nconst counter=read('data/professional/provenance/retail-counter-image-2026-10-16.json');");
      text = once(text, "assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,4);",
        "assert.equal(data.lexemes.filter(e=>e.media.image.status==='integrated').length,5);");
      text += `
test('counter preserves both licensed originals, exact accepted pixels and all unrelated review gates',()=>{
  const patch=counter.patches[0],entry=data.lexemes.find(item=>item.id==='counter.service-surface.n');
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
`;
    }
    outputs[file] = text.replaceAll('\n', newline);
  }
  return outputs;
}
module.exports = {testPaths, transformTests};
