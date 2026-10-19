'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {themeMotionErrors} = require('../tools/validate-theme-motion.cjs');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {loadProfessionalContent, auditProfessionalContent} = require('../tools/validate-professional-content.cjs');
const fixture = () => ({ambient_motion: {status: 'ready', review: {status: 'reviewed'}, clips: [{
  id: 'fixture', image: {status: 'integrated', review: {status: 'reviewed'}, path: 'res://fixture.png', sha256: 'a'.repeat(64), source: 'fixture', creator: 'fixture', license: 'fixture'},
  columns: 2, rows: 2, frame_count: 4, rest_frame: 1, frames_per_second: 2, rect: [0.1, 0.2, 0.3, 0.4]
}]}});

test('pending motion never counts as required delivery and ready clips need timing review', () => {
  assert.deepEqual(themeMotionErrors({ambient_motion: {status: 'pending', clips: []}}), []);
  assert.ok(themeMotionErrors({ambient_motion: {status: 'pending', clips: []}}, true).length);
  assert.deepEqual(themeMotionErrors(fixture(), true), []);
  const unreviewed = fixture(); delete unreviewed.ambient_motion.review;
  assert.ok(themeMotionErrors(unreviewed).length);
});

test('frame addressing, placement, identity, image review and clip count fail closed', () => {
  for (const mutate of [
    clip => { clip.columns = 0; }, clip => { clip.rows = 9; },
    clip => { clip.frame_count = 5; }, clip => { clip.rest_frame = 4; },
    clip => { clip.rest_frame = 0.5; }, clip => { clip.frames_per_second = Infinity; },
    clip => { clip.frames_per_second = 25; }, clip => { clip.rect = [0.8, 0, 0.4, 1]; },
    clip => { clip.rect = [0, 0, 0, 1]; }, clip => { clip.rect = [0, 0, 1, NaN]; },
    clip => { clip.image.review.status = 'pending'; }, clip => { clip.image.sha256 = 'invalid'; },
    clip => { clip.image.source = null; }
  ]) {
    const candidate = fixture(); mutate(candidate.ambient_motion.clips[0]);
    assert.ok(themeMotionErrors(candidate).length, mutate.toString());
  }
  const repeated = fixture(); repeated.ambient_motion.clips.push(structuredClone(repeated.ambient_motion.clips[0]));
  assert.ok(themeMotionErrors(repeated).length);
  const excessive = fixture(); excessive.ambient_motion.clips = Array.from({length: 5}, (_, i) => ({...excessive.ambient_motion.clips[0], id: `clip${i}`}));
  assert.ok(themeMotionErrors(excessive).length);
});

test('ambient sheets are required immutable delivery dependencies, including reduced-motion frames', () => {
  const project = path.resolve(__dirname, '..');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'tesis-motion-delivery-'));
  try {
    const schemas = path.join(temporary, 'data/professional/schemas');
    fs.mkdirSync(schemas, {recursive: true});
    for (const file of fs.readdirSync(path.join(project, 'data/professional/schemas'))) fs.copyFileSync(path.join(project, 'data/professional/schemas', file), path.join(schemas, file));
    const data = loadProfessionalContent(project);
    const module = data.courses.find(course => course.id === 'retail').modules[2];
    const theme = data.themes.find(item => item.course_id === 'retail');
    const image = '1'.repeat(64), audio = '2'.repeat(64), sheet = '3'.repeat(64);
    const set = (asset, hash, format) => Object.assign(asset, {sha256: hash, path: `res://professional-media/${hash}.${format}`});
    for (const entry of data.lexemes.filter(entry => module.lexeme_ids.includes(entry.id))) { set(entry.media.image, image, 'png'); set(entry.media.audio, audio, 'wav'); }
    for (const entry of data.expressions.filter(entry => module.expression_ids.includes(entry.id))) set(entry.media.audio, audio, 'wav');
    for (const asset of Object.values(theme.art)) set(asset, image, 'png');
    theme.ambient_motion = {...fixture().ambient_motion, brief: 'Technical fixture only.'};
    theme.ambient_motion.clips[0].image = structuredClone(theme.art.environment);
    set(theme.ambient_motion.clips[0].image, sheet, 'png');
    Object.assign(theme.ambient_motion.clips[0].image, {status: 'integrated', review: {status: 'reviewed'}});
    const picture = hash => ({id: 'sha256:' + hash, sha256: hash, path: `professional-media/${hash}.png`, kind: 'image', format: 'png', compressed_bytes: 64, decoded_bytes: 32, width: 2, height: 2});
    const manifest = {schema_version: 1, course_id: 'retail', module_id: 'module03', curriculum_revision: 'professional-v1', resources: [picture(image), {id: 'sha256:' + audio, sha256: audio, path: `professional-media/${audio}.wav`, kind: 'audio', format: 'wav', compressed_bytes: 64, decoded_bytes: 2, frames: 1, channels: 1, sample_rate: 22050}]};
    const relative = 'data/professional/media-manifests/motion-test.json';
    const inspect = () => {
      const bytes = Buffer.from(JSON.stringify(manifest));
      fs.mkdirSync(path.dirname(path.join(temporary, relative)), {recursive: true});
      fs.writeFileSync(path.join(temporary, relative), bytes);
      module.media_manifest = {path: 'res://' + relative, sha256: crypto.createHash('sha256').update(bytes).digest('hex')};
      return auditProfessionalContent({rootDir: temporary, data}).errors;
    };
    assert.ok(inspect().some(issue => issue.code === 'delivery.coverage'));
    manifest.resources.push(picture(sheet));
    assert.equal(inspect().some(issue => issue.code === 'delivery.coverage'), false);
    theme.ambient_motion.clips[0].image.path = 'res://professional-media/wrong.png';
    assert.ok(inspect().some(issue => issue.code === 'delivery.coverage'));
  } finally {
    assert.ok(path.resolve(temporary).startsWith(path.resolve(os.tmpdir()) + path.sep));
    fs.rmSync(temporary, {recursive: true, force: true});
  }
});
