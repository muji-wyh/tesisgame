const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { validateCurriculum, check } = require('../tools/import-growth-vocabulary.cjs');
const root = path.resolve(__dirname, '..');
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8'));

test('the ten growth tiers contain every word exactly once with reachable practice', () => {
  assert.deepEqual(validateCurriculum(), {words: 1550, phrases: 330, contextualWords: 265});
  assert.equal(read('curriculum.json').tiers[0].count, 80);
});

test('the growth illustrations retain audited source provenance and exact output hashes', () => {
  assert.equal(check().words, 1550);
});

test('a duplicate curriculum word cannot silently inflate upgrade progress', () => {
  const curriculum = read('curriculum.json');
  curriculum.tiers[1].word_ids[0] = curriculum.tiers[0].word_ids[0];
  assert.throws(() => validateCurriculum(read('words.json'), curriculum, read('phrases.json')), /membership/);
});

test('contextual words cannot require a later tier to become playable', () => {
  const words = read('words.json');
  const phrases = read('phrases.json').filter(phrase => !phrase.words.includes('responsibility'));
  assert.throws(() => validateCurriculum(words, read('curriculum.json'), phrases), /Contextual word.*responsibility/);
});

test('a phrase cannot present unlearnable tokens or invented pictures', () => {
  const phrases = read('phrases.json');
  phrases[0].words[0] = 'unlisted';
  assert.throws(() => validateCurriculum(read('words.json'), read('curriculum.json'), phrases), /Invalid or unreachable phrase/);
  const invalidPicture = read('phrases.json');
  invalidPicture[0].picture_id = 'please';
  assert.throws(() => validateCurriculum(read('words.json'), read('curriculum.json'), invalidPicture), /Invalid or unreachable phrase/);
});

test('the first tier practices actions and social language as well as names', () => {
  const first = read('words.json').filter(word => word.min_age === 3);
  for (const id of ['cat', 'milk', 'jump', 'clap', 'happy', 'please', 'friend']) {
    assert.ok(first.some(word => word.id === id), `${id} should be reachable at the first tier`);
  }
  assert.ok(first.some(word => word.part_of_speech === 'verb'));
  assert.ok(first.some(word => word.part_of_speech === 'adjective'));
  assert.ok(first.some(word => word.part_of_speech === 'pronoun'));
});
