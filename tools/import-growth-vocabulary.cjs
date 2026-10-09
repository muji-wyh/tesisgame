const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { rasterizeSvg, pngDimensions, revision, imageSize } = require('./import-vocabulary.cjs');

const root = path.resolve(__dirname, '..');
const manifestPath = path.join(root, 'docs/assets/growth-vocabulary.json');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8'));

function validateCurriculum(words = read('words.json'), curriculum = read('curriculum.json'), phrases = read('phrases.json')) {
  if (words.length !== 1550 || curriculum.schema !== 1 || curriculum.total_words !== words.length ||
      curriculum.tiers.length !== 10) throw new Error('Expected the 1,550-word, ten-tier curriculum.');
  const byId = new Map(words.map(word => [word.id, word]));
  const assigned = new Set();
  for (let index = 0; index < curriculum.tiers.length; index += 1) {
    const tier = curriculum.tiers[index];
    if (tier.age !== index + 3 || tier.id !== String(tier.age) || tier.count !== tier.word_ids.length || !tier.count) {
      throw new Error(`Invalid curriculum tier: ${tier.id}`);
    }
    for (const id of tier.word_ids) {
      if (!byId.has(id) || assigned.has(id) || byId.get(id).min_age !== tier.age) {
        throw new Error(`Duplicate or inconsistent curriculum membership: ${id}`);
      }
      assigned.add(id);
    }
  }
  if (assigned.size !== words.length) throw new Error('Every word needs exactly one tier.');
  const phraseIds = new Set(), phraseTexts = new Set(), contextualCoverage = new Set();
  for (const phrase of phrases) {
    const members = phrase.words.map(id => byId.get(id));
    if (members.some(word => !word) || members.length < 2 || members.length > 6 ||
        new Set(phrase.words).size !== phrase.words.length || phrase.text !== phrase.words.join(' ') ||
        phrase.min_age !== Math.max(...members.map(word => word.min_age)) ||
        phraseIds.has(phrase.id) || phraseTexts.has(phrase.text) ||
        (phrase.picture_id && (!phrase.words.includes(phrase.picture_id) || !byId.get(phrase.picture_id).image))) {
      throw new Error(`Invalid or unreachable phrase: ${phrase.id}`);
    }
    phraseIds.add(phrase.id);
    phraseTexts.add(phrase.text);
    for (const word of members) if (phrase.min_age <= word.min_age) contextualCoverage.add(word.id);
  }
  for (const word of words) {
    if (!Number.isInteger(word.min_age) || word.min_age < 3 || word.min_age > 12 || !Array.isArray(word.practice_modes) ||
        !word.practice_modes.length || word.practice_modes.some(mode => !['match', 'memory', 'pop', 'phrase'].includes(mode))) {
      throw new Error(`Invalid practice metadata: ${word.id}`);
    }
    if (!word.image && (JSON.stringify(word.practice_modes) !== '["phrase"]' || !contextualCoverage.has(word.id))) {
      throw new Error(`Contextual word has no reachable same-tier phrase: ${word.id}`);
    }
  }
  return { words: words.length, phrases: phrases.length, contextualWords: words.filter(word => !word.image).length };
}

function check() {
  const result = validateCurriculum();
  const additions = read('docs/vocabulary/growth-additions.json');
  const words = read('words.json');
  const manifest = read('docs/assets/growth-vocabulary.json');
  if (additions.length !== 300 || manifest.revision !== revision || manifest.license !== 'CC-BY-SA-4.0' ||
      manifest.files.length !== additions.filter(word => word.source).length) {
    throw new Error('Growth vocabulary provenance count mismatch.');
  }
  const sources = new Set(), images = new Set();
  for (const entry of additions) {
    const word = words.find(candidate => candidate.id === entry.id);
    if (!word || word.text !== entry.text || word.min_age !== entry.min_age || word.meaning !== entry.meaning ||
        word.topic !== entry.topic || word.part_of_speech !== entry.part_of_speech || word.image !== entry.image ||
        JSON.stringify(word.practice_modes) !== JSON.stringify(entry.practice_modes)) {
      throw new Error(`Growth vocabulary metadata mismatch: ${entry.id}`);
    }
    if (!entry.source) {
      if (word.image !== '' || word.art_key) throw new Error(`Contextual word has invented picture metadata: ${entry.id}`);
      continue;
    }
    const record = manifest.files.find(file => file.id === entry.id);
    const bytes = fs.readFileSync(path.join(root, word.image));
    const dimensions = pngDimensions(bytes);
    if (!record || record.source !== entry.source || record.path !== word.image || digest(bytes) !== record.sha256 ||
        !/^[a-f0-9]{64}$/.test(record.sourceSha256) || dimensions.width !== imageSize || dimensions.height !== imageSize ||
        word.art_key !== `mulberry/${entry.source}` || sources.has(entry.source) || images.has(record.sha256)) {
      throw new Error(`Growth illustration mismatch: ${entry.id}`);
    }
    sources.add(entry.source);
    images.add(record.sha256);
  }
  console.log(`Verified ${result.words} words, ${result.phrases} phrases, ${result.contextualWords} contextual words, and ${manifest.files.length} sourced growth pictures.`);
  return result;
}

async function importArtwork(sourceDirectory, sharpModule = 'sharp') {
  sourceDirectory = path.resolve(sourceDirectory);
  const actual = execFileSync('git', ['-C', sourceDirectory, 'rev-parse', 'HEAD'], {encoding: 'utf8', windowsHide: true}).trim();
  if (actual !== revision || execFileSync('git', ['-C', sourceDirectory, 'status', '--porcelain', '--', 'EN'],
    {encoding: 'utf8', windowsHide: true}).trim()) throw new Error('Use the clean pinned Mulberry source checkout.');
  validateCurriculum();
  const sharp = require(sharpModule);
  const additions = read('docs/vocabulary/growth-additions.json');
  const files = [];
  for (const entry of additions.filter(word => word.source)) {
    if (path.basename(entry.source) !== entry.source || !entry.source.endsWith('.svg') ||
        entry.image !== `assets/images/words/${entry.id}.png`) throw new Error(`Invalid source path: ${entry.id}`);
    const bytes = fs.readFileSync(path.join(sourceDirectory, 'EN', entry.source));
    const png = await rasterizeSvg(bytes, sharp);
    fs.writeFileSync(path.join(root, entry.image), png);
    files.push({id: entry.id, source: entry.source,
      url: `https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/${revision}/EN/${encodeURIComponent(entry.source)}`,
      sourceSha256: digest(bytes), path: entry.image, sha256: digest(png)});
  }
  fs.writeFileSync(manifestPath, JSON.stringify({
    provider: 'Mulberry Symbols', creator: 'Steve Lee; original symbol design project by Garry Paxton',
    source: 'https://github.com/mulberrysymbols/mulberry-symbols', revision,
    license: 'CC-BY-SA-4.0', licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
    status: 'Downloaded, visually reviewed, and integrated', animations: 'None; static educational illustrations',
    modifications: 'Original source SVGs rasterized to transparent 192 by 192 PNGs with preserved geometry, colors, CSS and text. No replacement artwork drawn.',
    review: 'Source contact sheets reviewed before integration. Ambiguous pictograms and unrelated senses were omitted; context-only words have no picture.',
    renderer: {name: 'sharp', version: sharp.versions.sharp, svg: sharp.versions.rsvg, width: imageSize, height: imageSize, density: 96, fit: 'contain', background: 'transparent'},
    files
  }, null, 2) + '\n');
  return check();
}

if (require.main === module) {
  (async () => {
    const args = process.argv.slice(2);
    if (args.length === 1 && args[0] === '--check') check();
    else if (args.length === 1 || (args.length === 3 && args[1] === '--sharp')) await importArtwork(args[0], args[2]);
    else throw new Error('Usage: node tools/import-growth-vocabulary.cjs <pinned-source> [--sharp <module>] | --check');
  })().catch(error => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { validateCurriculum, check, importArtwork };
