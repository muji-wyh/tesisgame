const fs = require('node:fs');
const path = require('node:path');

const AGES = Array.from({ length: 10 }, (_, index) => String(index + 3));
const read = (root, name) => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));

function vocabularyCatalog(root) {
  const words = read(root, 'words.json'), phrases = read(root, 'phrases.json');
  const byId = new Map(words.map(word => [word.id, word]));
  if (byId.size !== words.length || !words.length) throw new Error('Vocabulary packs require unique word IDs.');
  const ages = {};
  for (const age of AGES) {
    const ids = new Set(words.filter(word => word.min_age === Number(age)).map(word => word.id));
    const eligible = phrases.filter(phrase => phrase.min_age === Number(age));
    if (!ids.size || eligible.length < 3) throw new Error(`Age ${age} needs words and at least three phrases.`);
    for (const phrase of eligible) {
      for (const id of phrase.words) {
        if (!byId.has(id) || byId.get(id).min_age > phrase.min_age) {
          throw new Error(`Invalid age vocabulary dependency: ${phrase.id} / ${id}`);
        }
        ids.add(id);
      }
    }
    ages[age] = { word_ids: [...ids].sort(), phrase_ids: eligible.map(phrase => phrase.id).sort() };
  }
  return { schema: 1, ages };
}

function importedEntries(root, source) {
  if (!/^assets\/(?:images\/(?:word-library|word-motion)\/[a-z][a-z0-9-]*\.webp|audio\/voice\/(?:word|phrase)-[a-z][a-z0-9-]*\.(?:wav|ogg))$/.test(source)) {
    throw new Error(`Unexpected deferred vocabulary resource: ${source}`);
  }
  const metadata = fs.readFileSync(path.join(root, `${source}.import`), 'utf8');
  const imported = metadata.match(/^path="res:\/\/(\.godot\/imported\/[^"/\\]+\.(?:ctex|sample|oggvorbisstr))"$/m)?.[1];
  if (!imported || !fs.statSync(path.join(root, imported)).size) {
    throw new Error(`Import ${source} before creating vocabulary packs.`);
  }
  return [
    { path: `res://${source}.import`, source: path.join(root, `${source}.import`) },
    { path: `res://${imported}`, source: path.join(root, imported) }
  ];
}

function writeVocabularyPlan(root) {
  const catalog = vocabularyCatalog(root);
  const words = new Map(read(root, 'words.json').map(word => [word.id, word]));
  const phrases = new Map(read(root, 'phrases.json').map(phrase => [phrase.id, phrase]));
  const consumers = new Map();
  for (const age of AGES) {
    const cohort = catalog.ages[age];
    const sources = new Set(cohort.phrase_ids.map(id => phrases.get(id).audio));
    for (const id of cohort.word_ids) {
      const word = words.get(id);
      sources.add(word.audio);
      if (word.image) {
        sources.add(`assets/images/word-library/${id}.webp`);
        sources.add(`assets/images/word-motion/${id}.webp`);
      }
    }
    for (const source of [...sources].sort()) {
      if (!consumers.has(source)) consumers.set(source, []);
      consumers.get(source).push(age);
    }
  }
  const directory = path.join(root, 'build', 'vocabulary-packs');
  fs.mkdirSync(directory, { recursive: true });
  const packs = Object.fromEntries(AGES.map(age => [age, {
    file: path.join(directory, `age-${age}.pck`), ages: [age], dependencies: [], sources: [], entries: []
  }]));
  // Every imported source belongs to exactly one bundle. Sharing is restricted
  // to its exact consumers, so loading an age never downloads unrelated words.
  for (const source of [...consumers.keys()].sort()) {
    const ages = consumers.get(source);
    const id = ages.length === 1 ? ages[0] : `shared-${ages.join('-')}`;
    if (!packs[id]) {
      packs[id] = { file: path.join(directory, `${id}.pck`), ages, sources: [], entries: [] };
      for (const age of ages) packs[age].dependencies.push(id);
    }
    packs[id].sources.push(`res://${source}`);
    packs[id].entries.push(...importedEntries(root, source));
  }
  for (const age of AGES) packs[age].dependencies.sort();
  const catalogPath = path.join(root, 'data', 'vocabulary-packs.json');
  const text = `${JSON.stringify(catalog, null, 2)}\n`;
  if (!fs.existsSync(catalogPath) || fs.readFileSync(catalogPath, 'utf8') !== text) fs.writeFileSync(catalogPath, text);
  const manifest = path.join(directory, 'build-manifest.json');
  fs.writeFileSync(manifest, `${JSON.stringify({ schema: 2, packs }, null, 2)}\n`);
  return { catalog, manifest, packs };
}

module.exports = { AGES, vocabularyCatalog, importedEntries, writeVocabularyPlan };
