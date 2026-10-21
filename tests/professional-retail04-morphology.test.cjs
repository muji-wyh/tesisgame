'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {morphologyErrors, schemaErrors} = require('../tools/validate-professional-content.cjs');
const root = path.resolve(__dirname, '..');
const read = resource => JSON.parse(fs.readFileSync(path.join(root, resource), 'utf8'));
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const document = read('data/professional/lexemes/retail-module04.json');
const record = read('data/professional/provenance/retail-module04-morphology-remaining20-2026-10-20.json');
const byText = new Map(document.lexemes.map(entry => [entry.text, entry]));
const without = (value, field) => Object.fromEntries(Object.entries(value).filter(([key]) => key !== field));
const graph = text => byText.get(text).morphology;
const pairs = text => graph(text).parts.map(part => [part.canonical_id, part.canonical]);
const candidate = text => record.candidates.find(row => row.text === text);

test('Retail04 completes fifty analyses while protecting all lexical fields and the earlier thirty graphs', () => {
  assert.equal(document.lexemes.length, 50);
  assert.equal(new Set(document.lexemes.map(entry => entry.id)).size, 50);
  assert.equal(record.candidate_count, 20);
  assert.deepEqual(record.candidates.map(row => row.id), document.lexemes.slice(30).map(entry => entry.id));
  assert.equal(hash(document.lexemes.slice(0, 30)), record.preservation.first30_sha256);
  assert.equal(hash(document.lexemes.map(entry => without(entry, 'morphology'))), record.preservation.nonmorphology_sha256);
  for (const entry of document.lexemes) {
    assert.equal(entry.morphology.review.status, 'reviewed', entry.text);
    assert.deepEqual(schemaErrors(entry.morphology, 'morphology'), [], entry.text);
    assert.deepEqual(morphologyErrors(entry.morphology, entry), [], entry.text);
  }
  assert.deepEqual(record.preservation.canonical_migrations, []);
  for (const field of ['source_catalog_changed', 'course_status_changed', 'domain_status_changed', 'media_changed']) {
    assert.equal(record.preservation[field], false, field);
  }
});

test('Retail04 installed graphs retain the exact pending candidates and record independent editorial acceptance', () => {
  assert.equal(record.independent_review.status, 'accepted');
  assert.match(record.independent_review.reviewer, /independent.*AI/i);
  assert.match(record.independent_review.reviewer, /not human|not a human/i);
  assert.equal(record.independent_review.decisions.length, 20);
  for (const row of record.candidates) {
    const entry = byText.get(row.text);
    assert.equal(hash(row.candidate_morphology), row.candidate_morphology_sha256, row.text);
    assert.equal(row.candidate_morphology.review.status, 'pending');
    assert.equal(row.candidate_morphology.review.reviewer, null);
    assert.equal(hash(without(entry, 'morphology')), row.nonmorphology_sha256);
    assert.deepEqual(without(entry.morphology, 'review'), without(row.candidate_morphology, 'review'));
    assert.equal(entry.morphology.review.notes, row.rationale);
    assert.match(entry.morphology.review.reviewer, /independent.*AI/i);
    assert.match(entry.morphology.review.reviewer, /not human|not a human/i);
    assert.equal(entry.morphology.review.acceptance_record, 'data/professional/provenance/retail-module04-morphology-remaining20-2026-10-20.json');
    const decision = record.independent_review.decisions.find(decision => decision.id === row.id);
    assert.ok(decision, row.text);
    assert.equal(decision.decision, 'accept_at_declared_teaching_depth');
    assert.ok(decision.reason.length > 10);
  }
});

test('Retail04 atomic analyses expose actual whole bases without false suffix lessons', () => {
  const atomics = ['seam', 'sole', 'heel', 'sleeve', 'collar', 'ingredient', 'allergen', 'portion', 'sample', 'accessory'];
  assert.deepEqual(record.candidates.filter(row => row.candidate_morphology.kind === 'atomic').map(row => row.text), atomics);
  for (const text of atomics) {
    const analysis = graph(text);
    assert.equal(analysis.parts.length, 1);
    assert.equal(analysis.parts[0].surface, text);
    assert.deepEqual(analysis.parts[0].break_offsets, []);
    assert.deepEqual(analysis.nodes, []);
    assert.equal(candidate(text).composition_mastery_eligible, false);
  }
  assert.notEqual(pairs('sample')[0][0], 'morph.sample');
  assert.match(graph('allergen').review.notes, /historical allergy\/-gen relationship is not denied/);
  assert.match(graph('portion').review.notes, /not justify port plus -ion/);
  assert.match(graph('accessory').review.notes, /does not support an access plus ory/);
});

test('Retail04 derivations preserve full bases, exact spelling changes and authored wrapping boundaries', () => {
  assert.deepEqual(graph('lining').parts.map(part => part.surface), ['line', 'ing']);
  assert.equal(graph('lining').nodes[0].surface, 'lining');
  assert.deepEqual(graph('lining').nodes[0].break_offsets, [3]);
  assert.deepEqual(graph('demonstration model').parts.map(part => part.surface), ['demonstrate', 'ion', 'model']);
  assert.deepEqual(graph('demonstration model').nodes.map(node => [node.surface, node.break_offsets]), [
    ['demonstration', [10]], ['demonstration model', [10, 14]]
  ]);
  assert.deepEqual(graph('refill').parts.map(part => part.surface), ['re', 'fill']);
  assert.deepEqual(graph('refill').nodes[0].break_offsets, [2]);
  assert.deepEqual(graph('multipack').parts.map(part => part.surface), ['multi', 'pack']);
  assert.deepEqual(graph('multipack').nodes[0].break_offsets, [5]);
  assert.deepEqual(graph('waistband').nodes[0].break_offsets, [5]);
  for (const [text, boundary] of [['care label', 5], ['net weight', 4], ['unit price', 5], ['pack size', 5], ['spare part', 6]]) {
    assert.equal(graph(text).nodes[0].surface, text);
    assert.deepEqual(graph(text).nodes[0].break_offsets, [boundary]);
    assert.equal(text[boundary - 1], ' ');
  }
});

test('Retail04 shares compatible reviewed parts and separates misleading same-spelled parts', () => {
  const growth = [];
  for (const file of fs.readdirSync(path.join(root, 'data/vocabulary/morphology')).filter(file => /^age-\d+\.json$/.test(file))) {
    growth.push(...read('data/vocabulary/morphology/' + file).entries);
  }
  const growthPart = (text, canonical) => {
    const entry = growth.find(entry => entry.text === text);
    assert.equal(entry.review.status, 'reviewed');
    const part = entry.analysis.parts.find(part => part.canonical === canonical);
    return [part.canonical_id, part.canonical];
  };
  assert.deepEqual(pairs('waistband')[1], growthPart('headband', 'band'));
  assert.deepEqual(pairs('care label')[0], growthPart('caretaker', 'care'));
  assert.deepEqual(pairs('refill')[1], growthPart('fill', 'fill'));
  assert.deepEqual(pairs('lining')[1], growthPart('stuffing', '-ing'));
  assert.notDeepEqual(pairs('lining')[1], growthPart('bowling', '-ing'));
  assert.equal(pairs('lining')[0][0], 'english.stem.line.cover-inner-surface');
  assert.equal(pairs('net weight')[0][0], 'english.stem.net.after-deductions');
  assert.notDeepEqual(pairs('net weight')[0], growthPart('network', 'net'));
  assert.deepEqual(pairs('pack size')[0], pairs('multipack')[1]);
  assert.notDeepEqual(pairs('pack size')[0], growthPart('pack', 'pack'));
  assert.notDeepEqual(pairs('pack size')[0], growthPart('backpack', 'pack'));
  assert.notDeepEqual(pairs('pack size')[1], pairs('size')[0]);
  const foundation = read('data/professional/lexemes/foundation-module02.json').lexemes;
  const replacement = foundation.find(entry => entry.text === 'replace').morphology.parts[0];
  const rejection = foundation.find(entry => entry.text === 'reject').morphology.parts[0];
  assert.deepEqual(pairs('refill')[0], [replacement.canonical_id, replacement.canonical]);
  assert.notDeepEqual(pairs('refill')[0], [rejection.canonical_id, rejection.canonical]);
});

test('Retail04 language and morphology records do not claim media, specialist or module completion', () => {
  const sources = read('data/professional/sources.json').sources;
  for (const row of record.candidates) {
    const entry = byText.get(row.text);
    assert.equal(entry.media.image.status, 'pending');
    assert.equal(entry.media.audio.status, 'pending');
    assert.equal(entry.review.language, 'reviewed');
    for (const id of entry.morphology.review.source_record_ids) assert.ok(sources.some(source => source.id === id));
  }
  assert.equal(byText.get('allergen').review.domain, 'pending');
  for (const source of record.source_basis.current_consultations) {
    assert.equal(source.assets_acquired, false);
    assert.equal(source.domain_approval, false);
    assert.equal(source.consulted_on, '2026-10-20');
  }
  const course = read('data/professional/courses/retail.json');
  assert.equal(course.modules.find(module => module.id === 'module04').status, 'draft');
});
