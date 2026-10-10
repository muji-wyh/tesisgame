'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const bytes = file => fs.readFileSync(file);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const catalog = JSON.parse(bytes(path.join(root, 'data/pip-growth-stages.json')));
const preview = JSON.parse(bytes(path.join(__dirname, 'stages.json')));
const audio = JSON.parse(bytes(path.join(__dirname, 'audio/manifest.json')));
assert.deepEqual(preview, catalog, 'Runtime and preview catalogs must agree.');
assert.deepEqual(catalog.stages.map(stage => stage.age), [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
assert.equal(catalog.stages[0].label, 'Baby');
assert.equal(catalog.stages[10].label, 'Age 12+');
assert.equal(new Set(catalog.stages.map(stage => stage.id)).size, 11);
assert.ok(catalog.stages.every(stage => !Object.hasOwn(stage, 'level')), 'Pip appearance must not depend on mastery level.');
assert.deepEqual(audio.profile, { voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%' });
assert.deepEqual(catalog.voice.profile, audio.profile);
assert.equal(catalog.voice.autoplay, false);
assert.equal(audio.files.length, 10);
const artwork = new Set();
let checked = 0;
catalog.stages.forEach((stage, index) => {
  assert.equal(stage.actions.length, Math.max(1, index), `${stage.id}: repertoire must follow completed curriculum age.`);
  assert.equal(new Set(stage.actions).size, stage.actions.length);
  assert.equal(stage.voices.length, Math.max(1, index));
  assert.equal(stage.actions.at(-1), stage.newAction.id);
  assert.equal(stage.voices.at(-1), stage.newVoice.id);
  if (index > 1) {
    assert.deepEqual(stage.actions.slice(0, -1), catalog.stages[index - 1].actions);
    assert.deepEqual(stage.voices.slice(0, -1), catalog.stages[index - 1].voices);
  }
  for (const [kind, width] of [['regular', 480], ['idle', 480], ['parts', 720], ['expressions', 1200], ['expressionHeads', 1200]]) {
    const source = bytes(path.join(root, stage.art[kind]));
    assert.deepEqual(source, bytes(path.join(__dirname, stage.previewArt[kind])), `${stage.id}: ${kind} preview differs from runtime.`);
    assert.match(source.toString(), new RegExp(`width="${width}" height="120" viewBox="0 0 ${width} 120"`));
    assert.match(bytes(path.join(root, stage.art[kind] + '.import')).toString(), /svg\/scale=3\.0/);
    if (kind === 'parts') artwork.add(hash(source));
    checked += 1;
  }
  const voice = audio.files.find(file => file.id === stage.newVoice.id);
  assert.ok(voice, `${stage.id}: voice metadata missing.`);
  assert.equal(voice.text, stage.newVoice.text);
  assert.equal(voice.path, stage.newVoice.path);
  const recording = bytes(path.join(root, voice.path));
  assert.equal(recording.length, voice.bytes);
  assert.equal(hash(recording), voice.sha256);
  assert.deepEqual(recording, bytes(path.join(__dirname, stage.newVoice.previewPath)));
  assert.ok(recording.length > 3000, `${stage.id}: truncated voice recording.`);
});
assert.equal(artwork.size, 11, 'Baby and all ten ages need distinct authored compositions.');
for (const weight of [600, 800]) assert.deepEqual(bytes(path.join(__dirname, `Nunito-${weight}.ttf`)), bytes(path.join(root, `assets/fonts/Nunito-${weight}.ttf`)));
assert.ok(fs.existsSync(path.join(__dirname, 'FONT-LICENSE.txt')));
console.log(`Pip age asset contract passed: Baby and 10 ages, ${checked} matching SVG sheets, cumulative repertoires, and 10 verified Ava recordings.`);
