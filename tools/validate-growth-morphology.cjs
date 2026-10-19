const fs = require('node:fs');
const path = require('node:path');
const { fingerprint, identity } = require('./author-growth-morphology.cjs');
const ROOT = path.resolve(__dirname, '..');
const PART_TYPES = new Set(['atomic', 'root', 'stem', 'prefix', 'suffix', 'compound', 'combining_form', 'word', 'abbreviation']);
const text = value => typeof value === 'string' && value.trim().length > 0 && !/[\r\n\t]/.test(value);

function loadGrowthMorphology(root = ROOT) {
  const read = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));
  return {words: read('words.json'), index: read('data/vocabulary/morphology/index.json'),
    cohorts: Array.from({length: 10}, (_, i) => read(`data/vocabulary/morphology/age-${String(i + 3).padStart(2, '0')}.json`))};
}

function graphErrors(analysis, word) {
  const errors = [], fail = message => errors.push(message);
  if (!analysis || analysis.schema !== 1 || !text(analysis.id) || analysis.lexeme_id !== word.id || analysis.text !== word.text) return ['Analysis identity or exact spelling is invalid.'];
  if (!['atomic', 'compound', 'morphological', 'phrase'].includes(analysis.kind)) fail('Unknown analysis kind.');
  if (!Array.isArray(analysis.parts) || analysis.parts.length < 1 || analysis.parts.length > 64 || !Array.isArray(analysis.nodes) || analysis.nodes.length > 256 || !Array.isArray(analysis.roots) || !analysis.roots.length) return [...errors, 'Invalid bounded graph arrays.'];
  const items = new Map(), spans = new Map();
  const add = item => { if (!item || !text(item.id) || items.has(item.id)) fail('Duplicate or invalid graph identity.'); else items.set(item.id, item); };
  analysis.parts.forEach((part, i) => {
    add(part);
    if (!part || !PART_TYPES.has(part.type) || !text(part.canonical_id) || !text(part.canonical) || !text(part.surface)) fail('Incomplete canonical part.');
    else spans.set(part.id, [i, i + 1]);
  });
  for (const node of analysis.nodes) { add(node); if (!node || !text(node.left) || !text(node.right) || !text(node.surface) || !text(node.rule)) fail('Incomplete authored binary join.'); }
  if (errors.length) return errors;
  for (const item of items.values()) {
    if (item.break_offsets !== undefined && !Array.isArray(item.break_offsets)) { fail('Break offsets must be an array.'); continue; }
    let previous = 0;
    for (const offset of item.break_offsets || []) {
      if (!Number.isInteger(offset) || offset <= previous || offset >= [...item.surface].length) fail('Invalid approved break offset.');
      previous = offset;
    }
  }
  const visiting = new Set(), reached = new Set();
  function walk(id) {
    if (!items.has(id)) { fail(`Missing composition reference: ${id}`); return null; }
    if (visiting.has(id)) { fail('Cyclic composition graph.'); return null; }
    reached.add(id);
    if (spans.has(id)) return spans.get(id);
    visiting.add(id);
    const item = items.get(id), left = walk(item.left), right = walk(item.right);
    visiting.delete(id);
    if (!left || !right) return null;
    if (left[1] !== right[0]) { fail('A join reorders, overlaps or omits parts.'); return null; }
    const span = [left[0], right[1]]; spans.set(id, span); return span;
  }
  if (new Set(analysis.roots).size !== analysis.roots.length) fail('Completion roots must be distinct.');
  for (const root of analysis.roots) {
    const span = walk(root);
    if (!span || span[0] !== 0 || span[1] !== analysis.parts.length || items.get(root)?.surface !== word.text) fail('A completion must cover every part and preserve exact spelling.');
  }
  if (reached.size !== items.size) fail('Unreachable authored graph element.');
  if (analysis.kind === 'atomic' ? analysis.parts.length !== 1 || analysis.nodes.length !== 0 : analysis.parts.length < 2 || analysis.nodes.length < 1) fail('Whole and composed forms have inconsistent structures.');
  return errors;
}

function auditGrowthMorphology({rootDir = ROOT, data, release = false} = {}) {
  const errors = [], add = (at, message) => errors.push({path: at, message});
  try { data ||= loadGrowthMorphology(rootDir); } catch (error) { return {ok: false, errors: [{path: 'data/vocabulary/morphology', message: error.message}]}; }
  const {words, index, cohorts} = data;
  if (!Array.isArray(words) || !index || !Array.isArray(cohorts)) return {ok: false, errors: [{path: 'overlay', message: 'Missing vocabulary, index or cohorts.'}]};
  const byId = new Map(words.map(word => [word.id, word])), seen = new Set(), analysisIds = new Set(), canonical = new Map(), ages = {};
  if (byId.size !== 1550 || words.length !== 1550) add('words', 'The migration must preserve all 1,550 unique Growth identities.');
  if (index.schema !== 1 || !text(index.revision) || index.total !== words.length || index.inventory_sha256 !== fingerprint(words)) add('index', 'The overlay inventory does not match the unchanged vocabulary identities and senses.');
  const contextOnly = words.filter(word => !word.image).length;
  if (contextOnly !== 265 || index.context_only !== contextOnly) add('index', 'The 265 context-only entries must retain their honest image gaps.');
  if (!index.sources || typeof index.sources !== 'object') add('sources', 'Named source evidence is required.');
  for (const [id, source] of Object.entries(index.sources || {})) {
    if (!text(source.title) || !text(source.author) || !/^https:\/\/[^\s]+$/.test(source.url || '') || !/^\d{4}-\d{2}-\d{2}$/.test(source.consulted || '') || !text(source.evidence)) add(`sources/${id}`, 'A source needs its title, author, URL, consultation date and evidence scope.');
  }
  for (const document of cohorts) {
    const age = document?.age, at = `age-${age}`;
    if (!Number.isInteger(age) || age < 3 || age > 12 || ages[age] || document.schema !== 1 || document.revision !== index.revision || !Array.isArray(document.entries)) { add(at, 'Invalid or duplicated cohort.'); continue; }
    const count = {total: 0, reviewed: 0, pending: 0, atomic: 0, compound: 0, morphological: 0, phrase: 0, reviewed_pictured: 0, reviewed_context_only: 0};
    ages[age] = count;
    for (const entry of document.entries) {
      const location = `${at}/${entry?.id}`, word = byId.get(entry?.id); count.total++;
      if (!word || seen.has(entry.id) || word.min_age !== age) { add(location, 'Unknown, duplicated or misplaced vocabulary identity.'); continue; }
      seen.add(entry.id);
      if (JSON.stringify(identity(entry)) !== JSON.stringify(identity(word))) add(location, 'Word text, age, part of speech or sense changed after review.');
      const review = entry.review;
      if (review?.status === 'pending') {
        count.pending++;
        if (!text(review.reason) || entry.analysis !== undefined) add(location, 'Pending means an explicit reason and no fabricated playable analysis.');
        continue;
      }
      if (review?.status !== 'reviewed') { add(location, 'An explicit pending or reviewed state is required.'); continue; }
      count.reviewed++;
      count[word.image ? 'reviewed_pictured' : 'reviewed_context_only']++;
      if (!text(review.reviewer) || !/^\d{4}-\d{2}-\d{2}$/.test(review.date || '') || !text(review.method) || !text(review.rationale) || review.rationale.length < 25 || !Array.isArray(review.references) || !review.references.length || review.references.some(id => !index.sources?.[id])) add(location, 'Review needs a named reviewer, date, individual rationale and consulted source references.');
      for (const message of graphErrors(entry.analysis, word)) add(location, message);
      if (analysisIds.has(entry.analysis?.id)) add(location, 'Analysis identities must be unique.');
      analysisIds.add(entry.analysis?.id);
      if (Object.hasOwn(count, entry.analysis?.kind)) count[entry.analysis.kind]++;
      for (const part of entry.analysis?.parts || []) {
        if (canonical.has(part.canonical_id) && canonical.get(part.canonical_id) !== part.canonical) add(location, 'A canonical sense has conflicting base forms.');
        canonical.set(part.canonical_id, part.canonical);
      }
    }
    for (const key of ['total', 'reviewed', 'pending']) if (index.ages?.[age]?.[key] !== count[key]) add(at, `Index ${key} disagrees with the cohort.`);
    if (count.total !== words.filter(word => word.min_age === age).length) add(at, 'The cohort must enumerate every original word.');
  }
  if (seen.size !== words.length || Object.keys(ages).length !== 10) add('coverage', 'Every original word must occur exactly once across all ten ages.');
  const reviewed = Object.values(ages).reduce((sum, age) => sum + age.reviewed, 0), pending = Object.values(ages).reduce((sum, age) => sum + age.pending, 0);
  if (release && pending) add('release', `${pending} individual reviews remain incomplete; this is not the full Growth migration.`);
  return {ok: errors.length === 0, errors, summary: {total: words.length, reviewed, pending, context_only: contextOnly, release_ready: errors.length === 0 && pending === 0, ages}};
}
if (require.main === module) {
  const result = auditGrowthMorphology({release: process.argv.includes('--release')});
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exitCode = 1;
}
module.exports = {loadGrowthMorphology, graphErrors, auditGrowthMorphology};
