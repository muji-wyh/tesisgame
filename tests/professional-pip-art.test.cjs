const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'data/pip-professional.json'), 'utf8'));
const courses = JSON.parse(fs.readFileSync(path.join(root, 'data/professional/catalog.json'), 'utf8')).courses;

test('every career owns a complete, distinct, integrity-recorded Pip wardrobe', () => {
  assert.equal(catalog.schema_version, 1);
  assert.equal(catalog.cell_pixels, 360);
  assert.deepEqual(catalog.profiles.map(profile => profile.course_id), courses.map(course => course.id));
  const portraits = new Set();
  for (const profile of catalog.profiles) {
    assert.equal(profile.title, courses.find(course => course.id === profile.course_id).title);
    assert.equal(profile.motionPivots.length, 6);
    for (const [kind, count] of Object.entries({regular:4, idle:4, parts:6, expressions:10, expressionHeads:10})) {
      const file = profile.art[kind];
      assert.match(file, /^assets\/images\/mascots\/professional\/pip-[a-z-]+\.png$/);
      const bytes = fs.readFileSync(path.join(root, file));
      assert.equal(bytes.readUInt32BE(16), count * 360, `${profile.course_id} ${kind} frame count`);
      assert.equal(bytes.readUInt32BE(20), 360, `${profile.course_id} ${kind} frame height`);
      assert.equal(bytes[25], 6, 'Production art retains RGBA transparency');
      assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), profile.sha256[kind]);
    }
    portraits.add(profile.sha256.regular);
  }
  assert.equal(portraits.size, 20, 'Each career has its own authored apparel');
});

test('the Web startup pack includes the raw career catalog and production atlas directory', () => {
  const preset = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
  const included = preset.match(/^include_filter="([^"]*)"$/m)[1].split(',');
  const excluded = preset.match(/^exclude_filter="([^"]*)"$/m)[1].split(',');
  assert.ok(included.includes('data/pip-professional.json'));
  for (const profile of catalog.profiles) for (const file of Object.values(profile.art)) {
    assert.equal(excluded.some(pattern => path.matchesGlob(file, pattern)), false, file);
  }
  const verification = fs.readFileSync(path.join(root, 'tests/godot/verify_web_pack.gd'), 'utf8');
  assert.match(verification, /failures \+= _verify_professional_pip\(\)/);
  assert.match(verification, /res:\/\/data\/pip-professional\.json/);
});
