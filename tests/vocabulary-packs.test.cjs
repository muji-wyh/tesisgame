const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { AGES, vocabularyCatalog, importedEntries, writeVocabularyPlan } = require('../tools/vocabulary-packs.cjs');

const root = path.resolve(__dirname, '..');

test('each real age pack contains its exact cohort and all eligible phrase dependencies, without unrelated earlier words', () => {
  const catalog = vocabularyCatalog(root);
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json')));
  const phrases = JSON.parse(fs.readFileSync(path.join(root, 'phrases.json')));
  assert.deepEqual(catalog, JSON.parse(fs.readFileSync(path.join(root, 'data/vocabulary-packs.json'))));
  assert.deepEqual(Object.keys(catalog.ages), AGES);
  for (const age of AGES) {
    const cohort = words.filter(word => word.min_age === Number(age));
    const eligible = phrases.filter(phrase => phrase.min_age <= Number(age));
    const expected = new Set([...cohort.map(word => word.id), ...eligible.flatMap(phrase => phrase.words)]);
    assert.deepEqual(catalog.ages[age].word_ids, [...expected].sort());
    assert.deepEqual(catalog.ages[age].phrase_ids, eligible.map(phrase => phrase.id).sort());
    assert.ok(words.filter(word => expected.has(word.id)).every(word => word.min_age <= Number(age)));
  }
  assert.equal(catalog.ages['3'].word_ids.length, 80);
  assert.ok(catalog.ages['12'].word_ids.length < words.length / 2,
    'Even the oldest age bundle must not turn into a cumulative download of every earlier picture');
});

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'age-vocabulary-packs-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const write = (name, text) => {
    const filename = path.join(directory, name);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, text);
  };
  const words = AGES.map(age => ({ id: `item${age}`, min_age: Number(age),
    image: `assets/images/words/item${age}.svg`, audio: `assets/audio/voice/word-item${age}.wav` }));
  const phrases = AGES.flatMap(age => ['a', 'b', 'c'].map(suffix => ({ id: `phrase${age}${suffix}`,
    min_age: Number(age), words: ['item3', `item${age}`], audio: `assets/audio/voice/phrase-phrase${age}${suffix}.wav` })));
  write('words.json', JSON.stringify(words));
  write('phrases.json', JSON.stringify(phrases));
  fs.mkdirSync(path.join(directory, 'data'));
  const sources = [...words.flatMap(word => [word.audio,
    `assets/images/word-library/${word.id}.webp`, `assets/images/word-motion/${word.id}.webp`]), ...phrases.map(phrase => phrase.audio)];
  for (const source of sources) {
    const extension = source.endsWith('.webp') ? 'ctex' : 'sample';
    const imported = `.godot/imported/${path.basename(source)}-${createHash('md5').update(source).digest('hex')}.${extension}`;
    write(`${source}.import`, `[remap]\npath="res://${imported}"\n`);
    write(imported, `imported bytes for ${source}`);
  }
  return { directory, words, phrases, write, sources };
}

test('pack plans preserve remaps and deduplicate exact age consumers without shipping raw media or local filesystem paths', t => {
  const { directory, sources } = fixture(t);
  const plan = writeVocabularyPlan(directory);
  for (const [age, pack] of Object.entries(plan.packs)) {
    assert.equal(pack.entries.length, pack.sources.length * 2);
    assert.equal(new Set(pack.entries.map(entry => entry.path)).size, pack.entries.length);
    assert.ok(pack.file.startsWith(path.join(directory, 'build', 'vocabulary-packs')));
    assert.ok(pack.entries.every(entry => entry.path.startsWith('res://') && fs.existsSync(entry.source)));
    assert.ok(pack.entries.every(entry => entry.path.endsWith('.import') || entry.path.startsWith('res://.godot/imported/')));
    assert.equal(pack.sources.includes('res://assets/audio/voice/word-item12.wav'), age === '12');
  }
  const runtime = fs.readFileSync(path.join(directory, 'data/vocabulary-packs.json'), 'utf8');
  assert.doesNotMatch(runtime, /source|file|build|[A-Z]:/);
  const first = fs.readFileSync(plan.manifest);
  writeVocabularyPlan(directory);
  assert.deepEqual(fs.readFileSync(plan.manifest), first, 'Identical inputs produce deterministic pack plans');
  assert.equal(Object.values(plan.packs).reduce((sum, pack) => sum + pack.sources.length, 0), sources.length,
    'Every source is stored once, including words and phrases shared by many ages');
  const allPaths = Object.values(plan.packs).flatMap(pack => pack.entries.map(entry => entry.path));
  assert.equal(new Set(allPaths).size, allPaths.length, 'No imported media or remap is duplicated across bundles');
  assert.equal(plan.packs['3'].entries.length, 0, 'An age-only base can be empty when all its media is shared');
  assert.ok(plan.packs['shared-3-4-5-6-7-8-9-10-11-12']);
  for (const age of AGES) {
    const required = [plan.packs[age], ...plan.packs[age].dependencies.map(id => plan.packs[id])];
    const expected = sources.filter(source => {
      const resourceAge = Number(source.match(/(?:item|phrase)(\d+)/)[1]);
      return resourceAge <= Number(age);
    }).map(source => `res://${source}`).sort();
    assert.deepEqual(required.flatMap(pack => pack.sources).sort(), expected,
      `Age ${age} receives all and only its exact source membership`);
  }
  for (const [id, pack] of Object.entries(plan.packs).filter(([id]) => id.startsWith('shared-'))) {
    assert.deepEqual(pack.ages, id.slice(7).split('-'));
    assert.deepEqual(AGES.filter(age => plan.packs[age].dependencies.includes(id)), pack.ages);
  }
});

test('invalid dependencies and remaps fail before publishing pack metadata', t => {
  const { directory, phrases, write } = fixture(t);
  const source = 'assets/images/word-library/item3.webp';
  for (const imported of ['.godot/imported/../outside.ctex', '.godot/imported/subdir/outside.ctex', 'assets/unrelated.ctex']) {
    write(`${source}.import`, `[remap]\npath="res://${imported}"\n`);
    assert.throws(() => importedEntries(directory, source), /Import.*before creating/);
  }
  assert.throws(() => importedEntries(directory, '../private.wav'), /Unexpected deferred/);
  phrases[0].words.push('missing');
  write('phrases.json', JSON.stringify(phrases));
  assert.throws(() => vocabularyCatalog(directory), /Invalid age vocabulary dependency/);
});

test('nonconsecutive age consumers share media without leaking it into the skipped cohorts', t => {
  const { directory, phrases, write } = fixture(t);
  for (const phrase of phrases.filter(phrase => phrase.min_age === 4)) phrase.words = ['item3'];
  phrases.find(phrase => phrase.min_age === 7).words.push('item4');
  write('phrases.json', JSON.stringify(phrases));
  const { packs } = writeVocabularyPlan(directory);
  const id = 'shared-4-7-8-9-10-11-12';
  const source = 'res://assets/audio/voice/word-item4.wav';
  assert.ok(packs[id].sources.includes(source));
  for (const age of AGES) {
    const loaded = [packs[age], ...packs[age].dependencies.map(id => packs[id])].flatMap(pack => pack.sources);
    assert.equal(loaded.includes(source), age === '4' || Number(age) >= 7, `Exact membership for age ${age}`);
  }
});
