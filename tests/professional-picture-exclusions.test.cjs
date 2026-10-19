'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {loadProfessionalContent, auditProfessionalContent, schemaErrors} = require('../tools/validate-professional-content.cjs');
const {pictureReachableIds, modulePictureRoutes} = require('../tools/professional-picture-pools.cjs');
const source = loadProfessionalContent();
const schemaDir = path.resolve(__dirname, '../data/professional/schemas');

test('Picture exclusions accept known cross-file senses without changing readiness', () => {
  const data = structuredClone(source);
  const before = auditProfessionalContent({data});
  data.lexemes[0].media.image.confusable_with = [data.lexemes.at(-1).id];
  const after = auditProfessionalContent({data});
  assert.deepEqual(after.errors, before.errors);
  assert.deepEqual(after.summary, before.summary);
  assert.deepEqual(after.warnings, before.warnings);
});

test('Unknown and self-referential picture exclusions fail even in draft content', () => {
  for (const target of ['unknown.picture-sense', source.lexemes[0].id]) {
    const data = structuredClone(source);
    data.lexemes[0].media.image.confusable_with = [target];
    assert.ok(auditProfessionalContent({data}).errors.some(x => x.code === 'image.confusable'));
  }
});

test('Malformed exclusion lists cannot pass authoring schema validation', () => {
  const valid = source.lexemes[1].id;
  for (const value of [valid, [valid, valid], [''], [42]]) {
    const entry = structuredClone(source.lexemes[0]);
    entry.media.image.confusable_with = value;
    assert.ok(schemaErrors(entry, 'lexeme', schemaDir, new Map()).length);
  }
});

function picture(id, text = id, exclusions = []) {
  return {id, text, practice_modes: ['match', 'memory', 'jelly', 'pop'],
    media: {image: {picture_suitable: true, confusable_with: exclusions}}};
}

test('A valid picture pool does not imply that every sense can join it', () => {
  const specifics = Array.from({length: 5}, (_, i) => picture('specific' + i));
  const broad = picture('broad', 'broad', specifics.map(word => word.id));
  const words = [broad, ...specifics];
  assert.deepEqual([...pictureReachableIds(words, 5)].sort(), specifics.map(word => word.id).sort());
  assert.equal(pictureReachableIds(words, 1).size, 6);
  const routes = modulePictureRoutes({lexeme_ids: words.map(word => word.id)}, new Map(words.map(word => [word.id, word])));
  assert.equal(routes.get('match').has('broad'), false);
  assert.equal(routes.get('jelly').has('broad'), true);
  specifics.forEach(word => { word.practice_modes = ['match']; });
  assert.equal(modulePictureRoutes({lexeme_ids: words.map(word => word.id)}, new Map(words.map(word => [word.id, word])))
    .get('memory').size, 0, 'Other modes cannot supply missing Memory partners');
});

test('Duplicate labels keep alternative senses until a feasible pool is established', () => {
  const words = [picture('blocked', ' Charge ', ['one', 'two', 'three', 'four']), picture('usable', 'charge'),
    ...['one', 'two', 'three', 'four'].map(id => picture(id))];
  assert.deepEqual([...pictureReachableIds(words, 5)].sort(), ['usable', 'one', 'two', 'three', 'four'].sort());
  words[0].media.image.confusable_with = [];
  assert.equal(pictureReachableIds(words, 5).size, 6, 'Both senses have separate five-label witnesses');
  words.pop();
  assert.equal(pictureReachableIds(words, 5).size, 0, 'Five senses with only four labels do not meet the minimum');
});

test('Anchored feasibility agrees with exhaustive small choice-set enumeration', () => {
  let random = 131071;
  const next = () => (random = (Math.imul(random, 1664525) + 1013904223) >>> 0);
  for (let sample = 0; sample < 64; sample++) {
    const words = Array.from({length: 7}, (_, i) => picture('sense' + i, 'label' + (i === 6 && sample % 2 ? 0 : i)));
    for (let a = 0; a < words.length; a++) for (let b = a + 1; b < words.length; b++) {
      if (next() % 5 === 0) words[a].media.image.confusable_with.push(words[b].id);
    }
    const expected = new Set();
    for (let mask = 0; mask < 128; mask++) {
      const choice = words.filter((_, index) => mask & (1 << index));
      if (choice.length !== 5 || new Set(choice.map(word => word.text)).size !== 5) continue;
      if (choice.some(word => choice.some(other => word.media.image.confusable_with.includes(other.id)))) continue;
      choice.forEach(word => expected.add(word.id));
    }
    assert.deepEqual([...pictureReachableIds(words, 5)].sort(), [...expected].sort(), 'sample ' + sample);
  }
});

function groupedPictures(groups, duplicateLabels = false) {
  const words = Array.from({length: 50}, (_, index) => picture('sense' + index,
    duplicateLabels ? 'label' + (index % groups) : 'label' + index));
  if (!duplicateLabels) {
    for (let first = 0; first < words.length; first++) for (let second = first + 1; second < words.length; second++) {
      if (first % groups === second % groups) words[first].media.image.confusable_with.push(words[second].id);
    }
  }
  return words;
}

test('Full modules with four exclusion groups or four labels cannot supply a five-choice witness', () => {
  for (const duplicateLabels of [false, true]) {
    const words = groupedPictures(4, duplicateLabels);
    const before = structuredClone(words);
    assert.equal(pictureReachableIds(words, 5).size, 0);
    assert.equal(pictureReachableIds(words, 1).size, 50, 'Singleton practice is still available');
    assert.deepEqual(words, before, 'Feasibility does not modify shared metadata');
    words.reverse();
    assert.equal(pictureReachableIds(words, 5).size, 0, 'The proof is independent of candidate order');
    const possible = groupedPictures(5, duplicateLabels);
    assert.equal(pictureReachableIds(possible, 5).size, 50, 'Every alternative sense can join its own five-choice witness');
  }
});

test('A coloring bound never substitutes for an exact compatible witness', () => {
  // Joining two five-cycles needs six colors but has no clique larger than four.
  // Duplicate each cycle vertex five times to exercise a full fifty-term module.
  const words = Array.from({length: 50}, (_, index) => picture('sense' + index));
  for (let first = 0; first < words.length; first++) for (let second = first + 1; second < words.length; second++) {
    const a = first % 10, b = second % 10;
    const joined = Math.floor(a / 5) !== Math.floor(b / 5);
    const cycleEdge = [1, 4].includes(Math.abs(a % 5 - b % 5));
    if (!joined && !cycleEdge) words[first].media.image.confusable_with.push(words[second].id);
  }
  assert.equal(pictureReachableIds(words, 5).size, 0);
  assert.equal(pictureReachableIds(words, 4).size, 50, 'The same graph has a real four-choice witness for every sense');
});

test('Authoring rejects a stranded sense even when its module has a valid five-choice pool', () => {
  const data = structuredClone(source);
  const course = data.courses.find(course => course.id === 'retail');
  const module = course.modules.find(module => module.id === 'module03');
  const anchor = data.lexemes.find(word => word.id === 'checkout.payment-area.n');
  anchor.practice_modes = ['match'];
  anchor.media.image.picture_suitable = true;
  anchor.media.image.confusable_with = module.lexeme_ids.filter(id => id !== anchor.id);
  const result = auditProfessionalContent({data});
  assert.ok(result.warnings.some(issue => issue.code === 'exercise.unreachable' && issue.path === 'lexeme/' + anchor.id));
  assert.ok(result.warnings.some(issue => issue.code === 'exercise.module_unreachable' && issue.path.endsWith('/' + anchor.id)));
  const release = auditProfessionalContent({data, release: true});
  assert.ok(release.errors.some(issue => issue.code === 'exercise.module_unreachable' && issue.path.endsWith('/' + anchor.id)));
  anchor.practice_modes.push('jelly');
  const rescued = auditProfessionalContent({data});
  assert.equal(rescued.warnings.some(issue => ['exercise.unreachable', 'exercise.module_unreachable'].includes(issue.code) &&
    issue.path.endsWith('/' + anchor.id)), false, 'A singleton recognition route remains feasible');
});

test('Current gift wrap keeps its spelling declaration while contextual artwork cannot supply a picture answer', () => {
  const gift = source.lexemes.find(entry => entry.id === 'gift-wrap.wrapping-paper.n');
  assert.deepEqual(gift.practice_modes, ['word_jelly']);
  assert.equal(gift.media.image.picture_suitable, false);
  assert.equal(gift.morphology.review.status, 'reviewed');
  assert.equal(gift.morphology.kind, 'phrase');
  assert.deepEqual(gift.morphology.parts.map(part => part.surface), ['gift', 'wrap']);
  assert.equal(gift.practice_modes.includes('phrase'), false);
  const module = source.courses.find(course => course.id === 'retail').modules.find(module => module.id === 'module03');
  const registry = new Map(source.lexemes.map(entry => [entry.id, entry]));
  const modes = ['match', 'memory', 'pop', 'jelly'];
  const routes = modulePictureRoutes(module, registry);
  for (const mode of modes) assert.equal(routes.get(mode).has(gift.id), false, mode);

  // A copied erroneous mode declaration cannot override false picture suitability.
  // The copied positive control demonstrates that this metadata changes real routes.
  const declared = structuredClone(gift);
  declared.practice_modes = [...modes, 'word_jelly'];
  const copiedRegistry = new Map(registry);
  copiedRegistry.set(gift.id, declared);
  const stillExcluded = modulePictureRoutes(module, copiedRegistry);
  for (const mode of modes) assert.equal(stillExcluded.get(mode).has(gift.id), false, mode);
  declared.media.image.picture_suitable = true;
  const positiveControl = modulePictureRoutes(module, copiedRegistry);
  for (const mode of modes) assert.equal(positiveControl.get(mode).has(gift.id), true, mode);
  assert.deepEqual(gift.practice_modes, ['word_jelly']);
  assert.equal(gift.media.image.picture_suitable, false, 'Controls never mutate the current entry.');

  const audit = auditProfessionalContent({data: source});
  const giftFindings = [...audit.errors, ...audit.warnings].filter(issue =>
    ['exercise.picture', 'exercise.unreachable', 'exercise.module_unreachable'].includes(issue.code) &&
    (issue.path === 'lexeme/' + gift.id || issue.path.endsWith('/' + gift.id)));
  assert.deepEqual(giftFindings, []);
  assert.equal(audit.summary.ready_modules, 0);
  assert.equal(audit.summary.release_ready, false);
});
