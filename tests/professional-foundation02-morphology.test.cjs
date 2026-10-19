'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {loadProfessionalContent, auditProfessionalContent, morphologyErrors} = require('../tools/validate-professional-content.cjs');
const root = path.resolve(__dirname, '..');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
const digest = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const without = (value, field) => Object.fromEntries(Object.entries(value).filter(([key]) => key !== field));
const packet = 'build/professional-english/foundation02-morphology-integration-proposal-r01';
const recordPath = 'data/professional/provenance/foundation-module02-morphology-2026-10-17.json';
const modulePath = 'data/professional/lexemes/foundation-module02.json';
const historyPath = packet + '/preimages/' + modulePath;
const reviewPath = 'build/professional-english/foundation02-morphology-integration-independent-review-r01/review.json';
const record = read(recordPath);
const document = read(modulePath);
const history = read(historyPath);
const data = loadProfessionalContent(root);
const byId = new Map(document.lexemes.map(entry => [entry.id, entry]));

test('Foundation02 current graphs equal the independently accepted assembly without changing fifty lexical projections', () => {
  assert.equal(raw(recordPath), '8f2944a6129662d856003b08b8638fda6399db782e7401e2eac277cc4de2c803');
  assert.equal(raw(modulePath), '7d6c2e941d9b5b6c3490c0155f01ecf8fa42ff4ccf998b552aadb56c4cabfa64');
  assert.equal(raw(historyPath), '6cf78346c223e65bb3c4b30af10d2a564f03c10ba1f4593836f8ccbeea2e2576');
  assert.equal(raw(reviewPath), 'b287d6e0ed066ac096cf5239fe23fe519b4992b7f00d781d1819b13ca2e83fe7');
  assert.equal(document.lexemes.length, 50);
  assert.equal(byId.size, 50);
  assert.deepEqual(without(document, 'lexemes'), without(history, 'lexemes'));
  assert.deepEqual(document.lexemes.map(entry => without(entry, 'morphology')), history.lexemes.map(entry => without(entry, 'morphology')));
  assert.deepEqual(document.lexemes.reduce((counts, entry) => {
    counts[entry.morphology.kind] = (counts[entry.morphology.kind] || 0) + 1; return counts;
  }, {}), {atomic:34, morphological:16});
  assert.equal(record.patches.length, 47);
  assert.equal(new Set(record.patches.map(patch => patch.lexeme_id)).size, 47);
  for (const patch of record.patches) {
    const entry = byId.get(patch.lexeme_id);
    assert.deepEqual(entry.morphology, patch.proposed_morphology, entry.id);
    assert.equal(digest(entry.morphology), patch.proposed_morphology_sha256_compact_json);
    assert.equal(digest(without(entry, 'morphology')), patch.nonmorphology_sha256_compact_json);
    assert.deepEqual(without(entry.morphology, 'review'), without(patch.accepted_morphology, 'review'));
    assert.equal(digest(without(entry.morphology, 'review')), patch.graph_excluding_review_sha256_compact_json);
    assert.deepEqual(morphologyErrors(entry.morphology, entry), []);
  }
  assert.deepEqual(record.preserved_entries.map(row => row.lexeme_id), ['collect.bring-together.v', 'inform.give-information.v', 'ensure.make-certain.v']);
  for (const row of record.preserved_entries) {
    const entry = byId.get(row.lexeme_id);
    assert.deepEqual(entry, history.lexemes.find(previous => previous.id === entry.id));
    assert.equal(digest(entry), row.whole_entry_sha256_compact_json);
    assert.equal(digest(entry.morphology), row.morphology_sha256_compact_json);
  }
  for (const entry of document.lexemes) {
    assert.deepEqual(data.lexemes.find(current => current.id === entry.id), entry);
    assert.equal(entry.morphology.review.status, 'reviewed');
    assert.deepEqual(morphologyErrors(entry.morphology, entry), []);
    const memberships = data.courses.flatMap(course => course.modules.filter(module => module.lexeme_ids.includes(entry.id)).map(module => [course.id, module.id]));
    assert.equal(memberships.length, 20);
    assert.ok(memberships.every(([, id]) => id === 'module02'));
  }
});

test('Foundation02 keeps complete irregular bases, scoped affix meanings and authored boundaries', () => {
  const cases = [
    ['clarification.clearer-explanation.n', 'clarify', 'english.stem.clarify.make-understandable', 'english.affix.ation.action-result', []],
    ['submit.send-for-consideration.v', 'sub', 'english.affix.sub.under', 'english.root.mit.send', [3]],
    ['reject.decline-acceptance.v', 're', 'english.affix.re.back', 'english.root.ject.throw', [2]],
    ['error.mistake.n', 'err', 'english.stem.err.make-mistake', 'english.affix.or.state-activity', [3]],
    ['missing.not-present.adj', 'miss', 'english.stem.miss.absence', 'english.affix.ing.participial-adjective', [4]],
    ['broken.not-working.adj', 'break', 'english.stem.break.damage', 'english.affix.en.participle', [4]],
    ['urgent.needing-prompt-attention.adj', 'urge', 'english.stem.urge.press-for-action', 'english.affix.ent.adjective', [3]],
    ['solution.problem-answer.n', 'solve', 'growth.solve', 'english.affix.ion.result', [5]],
    ['procedure.agreed-method.n', 'proceed', 'english.stem.proceed.carry-on-activity', 'english.affix.ure.process-noun', [6]]
  ];
  for (const [id, base, first, second, boundaries] of cases) {
    const entry = byId.get(id), graph = entry.morphology;
    assert.equal(graph.parts.length, 2); assert.equal(graph.nodes.length, 1);
    assert.equal(graph.parts[0].surface, base);
    assert.deepEqual(graph.parts.map(part => part.canonical_id), [first, second]);
    assert.equal(graph.nodes[0].surface, entry.text);
    assert.deepEqual(graph.nodes[0].break_offsets, boundaries);
  }
  for (const id of ['replace.put-instead.v', 'reschedule.change-time.v']) {
    assert.equal(byId.get(id).morphology.parts[0].canonical_id, 'english.affix.re.again');
    assert.notEqual(byId.get(id).morphology.parts[0].canonical_id, byId.get('reject.decline-acceptance.v').morphology.parts[0].canonical_id);
  }
  for (const id of ['request.asking-action.n', 'return.send-back.v', 'approve.authorize.v', 'postpone.delay-until-later.v']) {
    const entry = byId.get(id);
    assert.equal(entry.morphology.kind, 'atomic');
    assert.equal(entry.morphology.parts[0].surface, entry.text);
    assert.deepEqual(entry.morphology.nodes, []);
  }
});

test('Foundation02 acceptance preserves original author gates, independent decisions and consulted-only source additions', () => {
  assert.equal(record.status, 'proposed_exact_source_assembly_pending_integration_review_and_validation');
  assert.match(record.assembly_author, /not an independent reviewer/);
  assert.deepEqual(record.independent_reviews.map(row => [row.group, row.accepted_count]), [['A',23],['B',18],['C',6]]);
  assert.match(record.independent_reviews.find(row => row.group === 'C').independence_disclosure, /authored the older Part B atomic recommendations/);
  for (const review of record.independent_reviews) assert.equal(raw(review.path), review.sha256);
  for (const patch of record.patches) {
    const prior = history.lexemes.find(entry => entry.id === patch.lexeme_id);
    assert.deepEqual(patch.original_morphology, prior.morphology);
    assert.equal(digest(patch.original_morphology), patch.before_morphology_sha256_compact_json);
    assert.equal(patch.accepted_morphology.review.status, 'pending');
    assert.equal(patch.accepted_morphology.review.reviewer, null);
    assert.equal(digest(patch.accepted_morphology), patch.accepted_morphology_sha256_compact_json);
    assert.deepEqual(patch.review_metadata_delta.before, patch.accepted_morphology.review);
    assert.deepEqual(patch.review_metadata_delta.after, patch.proposed_morphology.review);
    assert.equal(patch.proposed_morphology.review.original_author_review_sha256_compact_json, digest(patch.accepted_morphology.review));
    assert.match(patch.proposed_morphology.review.reviewer, /independent.*AI.*review.*not human or specialist approval/);
  }
  const priorSourcesPath = packet + '/preimages/data/professional/sources.json';
  assert.equal(raw(priorSourcesPath), '9fae4c21ffafb8e18382d9fd278a5763f89113922d3791604192fa11964adb4e');
  const priorSources = read(priorSourcesPath);
  assert.equal(raw('data/professional/sources.json'), '60a07ed186a938cfc021428afc0ec1c07e608f18d8ed1a866926f04cf9381ac2');
  assert.equal(priorSources.sources.length, 1068);
  assert.deepEqual(data.sources.slice(0, 1068), priorSources.sources);
  assert.equal(record.appended_sources.length, 61);
  assert.deepEqual(data.sources.slice(1068), record.appended_sources);
  assert.equal(data.sources.length, 1129);
  assert.equal(new Set(data.sources.map(row => row.id)).size, 1129);
  for (const row of record.appended_sources) {
    assert.equal(row.status, 'consulted'); assert.equal(row.assets_acquired, false); assert.equal(row.asset_license, null);
  }
  assert.equal(record.source_url_bindings.length, 80);
  for (const entry of document.lexemes) {
    const review = entry.morphology.review;
    for (const id of review.source_registry_ids || []) {
      const row = data.sources.find(source => source.id === id);
      assert.ok(row, id); assert.equal(row.status, 'consulted'); assert.ok(review.references.includes(row.url));
    }
  }
});

test('Foundation02 morphology does not promote media, specialist, module or overall release gates', () => {
  for (const entry of document.lexemes) {
    const prior = history.lexemes.find(row => row.id === entry.id);
    assert.deepEqual(entry.review, prior.review);
    assert.deepEqual(entry.media, prior.media);
    for (const kind of ['image', 'audio']) assert.equal(entry.media[kind].status, 'pending');
  }
  const audit = auditProfessionalContent({rootDir:root, data});
  assert.deepEqual(audit.errors, []);
  assert.equal(audit.summary.morphology_reviewed, 189);
  assert.equal(audit.summary.reviewed_lexemes, 156);
  assert.equal(audit.summary.integrated_word_images, 10);
  assert.equal(audit.summary.integrated_word_audio, 12);
  assert.equal(audit.summary.ready_modules, 0);
  assert.equal(audit.summary.release_ready, false);
  for (const id of ['unsafe.presenting-danger.adj', 'hazard.possible-harm.n']) assert.equal(byId.get(id).review.domain, 'pending');
});
