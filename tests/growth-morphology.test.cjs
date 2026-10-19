const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { loadGrowthMorphology, auditGrowthMorphology } = require('../tools/validate-growth-morphology.cjs');
const copy = () => structuredClone(loadGrowthMorphology());
const entry = (data, id) => data.cohorts.flatMap(cohort => cohort.entries).find(item => item.id === id);
const rejects = (mutate, expected) => {
  const data = copy();
  mutate(data);
  const audit = auditGrowthMorphology({ data });
  assert.equal(audit.ok, false);
  assert.match(audit.errors.map(error => error.message).join('\n'), expected);
};

test('the separate overlay preserves every Growth sense and every honest media gap', () => {
  const data = copy(), before = JSON.stringify(data.words);
  const audit = auditGrowthMorphology({ data });
  assert.deepEqual(audit.errors, []);
  assert.equal(audit.summary.total, 1550);
  assert.equal(audit.summary.context_only, 265);
  assert.equal(audit.summary.reviewed, 1550);
  assert.equal(audit.summary.pending, 0);
  assert.equal(audit.summary.release_ready, true);
  assert.equal(JSON.stringify(data.words), before);
  for (const cohort of data.cohorts) {
    assert.equal(cohort.entries.length, data.words.filter(word => word.min_age === cohort.age).length);
    for (const item of cohort.entries) {
      assert.equal(Object.hasOwn(item, 'image'), false, 'The overlay cannot replace original art');
      assert.equal(Object.hasOwn(item, 'audio'), false, 'The overlay cannot replace original audio');
      assert.equal(Object.hasOwn(item, 'practice_modes'), false, 'The overlay cannot rewrite game eligibility');
    }
  }
});

test('release readiness cannot silently accept any pending editorial review', () => {
  const data = copy();
  const pending = entry(data, 'cat');
  delete pending.analysis;
  pending.review = { status: 'pending', reason: 'This fixture deliberately withdraws its review.' };
  data.index.ages['3'].reviewed--;
  data.index.ages['3'].pending++;
  const audit = auditGrowthMorphology({ data, release: true });
  assert.equal(audit.ok, false);
  assert.equal(audit.summary.release_ready, false);
  assert.ok(audit.errors.some(error => error.path === 'release'));
});

test('word, sense, age and inventory changes invalidate prior editorial decisions', () => {
  for (const [field, value] of [['meaning', 'a different sense'], ['text', 'Cat'], ['part_of_speech', 'verb'], ['min_age', 4]]) {
    rejects(data => { entry(data, 'cat')[field] = value; }, /sense changed|misplaced/);
  }
  rejects(data => { data.words[0].meaning = 'new meaning'; }, /inventory|sense changed/);
  rejects(data => { data.cohorts[0].entries.push(structuredClone(data.cohorts[0].entries[0])); }, /duplicated/);
  rejects(data => { data.cohorts[0].entries.pop(); }, /enumerate every original word/);
  rejects(data => { data.words.find(word => !word.image).image = 'invented.png'; }, /honest image gaps/);
});

test('review provenance is mandatory and never supplied by a fallback classifier', () => {
  for (const field of ['reviewer', 'date', 'method', 'rationale', 'references']) {
    rejects(data => { delete entry(data, 'cat').review[field]; }, /named reviewer/);
  }
  rejects(data => { entry(data, 'cat').review.references = ['unconsulted-source']; }, /source references/);
  rejects(data => { delete data.index.sources['anderson-morphology'].evidence; }, /evidence scope/);
  rejects(data => { entry(data, 'cat').review.status = 'approved-by-pattern'; }, /explicit pending or reviewed/);
  rejects(data => { entry(data, 'cat').review = {status: 'pending', reason: 'Waiting for individual review.'}; }, /no fabricated playable analysis/);
});

test('invalid, reordered and cyclic authored graphs fail without granting eligibility', () => {
  rejects(data => { entry(data, 'rainbow').analysis.nodes[0].left = 'whole'; }, /Cyclic/);
  rejects(data => { entry(data, 'rainbow').analysis.nodes[0].left = 'missing'; }, /Missing composition/);
  rejects(data => { entry(data, 'rainbow').analysis.parts.reverse(); }, /reorders/);
  rejects(data => { entry(data, 'rainbow').analysis.nodes[0].surface = 'rainbowe'; }, /exact spelling/);
  rejects(data => { entry(data, 'rainbow').analysis.nodes[0].break_offsets = [0, 99]; }, /break offset/);
  rejects(data => { entry(data, 'rainbow').analysis.nodes.push({id: 'unused', left: 'part1', right: 'part2', surface: 'rainbow', rule: 'unused'}); }, /Unreachable/);
  rejects(data => { entry(data, 'cat').analysis.kind = 'compound'; }, /inconsistent structures/);
});

test('approved compounds and irregular joins retain their particular meanings and exact output', () => {
  const data = copy();
  assert.deepEqual(entry(data, 'rainbow').analysis.parts.map(part => part.canonical), ['rain', 'bow']);
  assert.equal(entry(data, 'rainbow').analysis.parts[1].canonical_id, 'growth.part.bow.arc');
  assert.equal(entry(data, 'breakfast').analysis.parts[1].canonical_id, 'growth.part.fast.abstention');
  assert.equal(entry(data, 'friendly').analysis.parts[1].canonical_id, 'english.affix.ly.adjective');
  assert.deepEqual(entry(data, 'has').analysis.parts.map(part => part.canonical), ['have', '-s']);
  assert.equal(entry(data, 'has').analysis.nodes[0].surface, 'has');
  assert.equal(entry(data, 'angry').analysis.parts[0].canonical, 'anger');
  assert.equal(entry(data, 'angry').analysis.nodes[0].surface, 'angry');
  for (const id of ['mother', 'father', 'flower', 'paper', 'number', 'happy', 'hungry', 'chicken', 'scissors']) {
    assert.equal(entry(data, id).analysis.kind, 'atomic', `${id} must not inherit a misleading suffix split`);
  }
});

test('later cohorts keep semantic identities and ordered multi-stage constructions', () => {
  const data = copy();
  const parts = id => entry(data, id).analysis.parts;
  assert.deepEqual(parts('helicopter').map(part => part.canonical), ['helico-', '-pter']);
  assert.deepEqual(parts('archery').map(part => part.canonical), ['archer', '-ery']);
  assert.equal(parts('blackcurrant')[1].canonical_id, 'growth.part.currant.fresh-berry');
  assert.equal(parts('earwig')[0].type, 'atomic');
  assert.equal(parts('raspberry')[0].canonical_id, 'growth.part.rasp.fruit');
  assert.equal(parts('slippery')[0].type, 'atomic');
  assert.equal(parts('fasten')[0].canonical_id, 'growth.part.fast.secure');
  assert.equal(parts('screwdriver')[1].canonical_id, 'growth.part.drive.turn-fastener');
  assert.equal(parts('birthday')[1].canonical_id, 'growth.part.day.calendar-date');
  assert.equal(parts('basketball')[0].canonical_id, 'growth.part.basket.scoring-target');
  assert.equal(parts('eggplant')[1].canonical_id, 'growth.part.plant.organism');
  assert.equal(parts('pointed')[0].canonical_id, 'growth.part.point.tip');
  assert.equal(parts('global')[0].canonical_id, 'growth.part.globe.earth');
  assert.equal(parts('research')[0].canonical_id, 'english.affix.re.intensive');
  assert.equal(parts('porter')[0].canonical_id, 'english.root.port.carry');
  assert.equal(parts('tractor')[0].canonical_id, parts('subtract')[1].canonical_id);
  assert.equal(parts('saxophone')[0].canonical, 'Sax');
  assert.equal(parts('saxophone')[0].surface, 'sax');
  assert.equal(parts('percent')[1].canonical_id, 'english.root.cent.hundred');
  assert.equal(parts('metronome')[0].canonical_id, 'english.combining.metro.measure');
  assert.equal(entry(data, 'horizontal').analysis.nodes[0].surface, 'horizontal');
  for (const [id, intermediate] of [['hairdryer', 'dryer'], ['earrings', 'earring'], ['sometimes', 'sometime'], ['slippers', 'slipper'], ['earmuffs', 'earmuff'], ['screwdriver', 'driver'], ['lawnmower', 'mower'], ['dishwasher', 'washer'], ['headphones', 'headphone'], ['woodpecker', 'pecker'], ['anteater', 'eater'], ['caretaker', 'taker'], ['binoculars', 'binocular'], ['photocopier', 'copier']]) {
    const analysis = entry(data, id).analysis;
    assert.equal(analysis.parts.length, 3, id);
    assert.equal(analysis.nodes.length, 2, id);
    assert.equal(analysis.nodes[0].surface, intermediate, id);
    assert.equal(analysis.nodes[1].surface, id, id);
    assert.ok([analysis.nodes[1].left, analysis.nodes[1].right].includes(analysis.nodes[0].id), id);
  }
  rejects(data => { entry(data, 'screwdriver').analysis.nodes[1].left = 'part2'; }, /reorders|overlap|partition|cover|unreachable/i);
});

test('new source-based bound-family reviews retain exact semantic parts and surfaces', () => {
  const data = copy();
  const expected = {
    attract: [['english.affix.ad.toward', 'ad-', 'at', 'prefix'], ['english.root.tract.pull', 'tract', 'tract', 'root']],
    connect: [['english.affix.com.together', 'com-', 'con', 'prefix'], ['english.root.nect.bind', 'nect', 'nect', 'root']],
    include: [['english.affix.in.inside', 'in-', 'in', 'prefix'], ['english.root.clude.close', 'clude', 'clude', 'root']],
    receive: [['english.affix.re.back', 're-', 're', 'prefix'], ['english.root.ceive.take', 'ceive', 'ceive', 'root']],
    reflect: [['english.affix.re.back', 're-', 're', 'prefix'], ['english.root.flect.bend', 'flect', 'flect', 'root']],
    adapt: [['english.affix.ad.toward', 'ad-', 'ad', 'prefix'], ['english.root.apt.fit', 'apt', 'apt', 'root']]
  };
  for (const [id, parts] of Object.entries(expected)) {
    const item = entry(data, id);
    assert.equal(item.analysis.kind, 'morphological', id);
    assert.deepEqual(item.analysis.parts.map(part => [part.canonical_id, part.canonical, part.surface, part.type]), parts, id);
    assert.equal(item.review.reviewer, 'Codex (AI editorial review; not human approval)');
    assert.ok(item.review.references.includes('mw-' + id + '-new'), id + ' needs its newly consulted word history');
    assert.ok(item.review.references.includes('anderson-2e-roots-new'));
  }
});

test('individually resolved historical families preserve distinct roots and exact boundaries', () => {
  const data = copy(), parts = id => entry(data, id).analysis.parts;
  assert.notEqual(parts('compare')[1].canonical_id, parts('separate')[1].canonical_id);
  assert.equal(parts('compare')[1].canonical_id, 'english.root.par.equal');
  assert.equal(parts('compare')[1].surface, 'pare');
  assert.equal(parts('separate')[1].canonical_id, 'english.root.par.prepare');
  assert.equal(parts('divide')[0].canonical_id, 'english.affix.dis.apart');
  assert.equal(parts('divide')[1].canonical_id, 'english.root.vide.separate');
  assert.equal(parts('retire')[1].canonical_id, 'english.root.tir.draw');
  assert.equal(parts('retire')[1].surface, 'tire');
  assert.deepEqual(parts('suggest').map(p => [p.canonical, p.surface]), [['sub-', 'sug'], ['gest', 'gest']]);
  assert.equal(parts('multiply')[1].canonical_id, 'english.root.ply.fold');
  assert.equal(parts('estimate')[1].canonical_id, 'english.affix.ate.verb');
  for (const [id, intermediate] of [['investigate', 'investig'], ['separate', 'separ']]) {
    const graph = entry(data, id).analysis;
    assert.deepEqual(graph.nodes.map(n => n.surface), [intermediate, id]);
    assert.equal(graph.nodes[1].left, graph.nodes[0].id);
    assert.equal(graph.nodes[1].right, 'part3');
  }
  assert.equal(entry(data, 'explore').analysis.kind, 'atomic');
  assert.equal(entry(data, 'explore').analysis.nodes.length, 0);
  for (const id of ['compare', 'investigate', 'suggest', 'explore', 'separate', 'multiply', 'divide', 'estimate', 'retire']) {
    const item = entry(data, id);
    assert.equal(item.review.reviewer, 'Codex (AI editorial review; not human approval)');
    assert.ok(item.review.references.includes('etym-' + id + '-hold9'));
  }
  assert.equal(auditGrowthMorphology({data, release: true}).ok, true);
});

test('authoring rejects conflicting, unknown, duplicate or empty reopen decisions before writes', () => {
  const filename = require.resolve('../tools/author-growth-morphology.cjs');
  const fixtures = [
    {withdrawCat: false, age7: {cat: 'Conflicts with a reviewed decision.'}},
    {withdrawCat: false, age7: {unknown_fixture_word: 'Unknown identity.'}},
    {withdrawCat: true, age7: {cat: 'First withdrawal.'}, age8: {cat: 'Duplicate withdrawal.'}},
    {withdrawCat: true, age7: {cat: ''}}
  ];
  for (const fixture of fixtures) {
    let writes = 0;
    const isolated = {exports: {}};
    const readOnlyFs = {...fs, mkdirSync() {writes++;}, writeFileSync() {writes++;}};
    const load = name => {
      if (name === 'node:fs') return readOnlyFs;
      const value = require(name);
      const pending = name.endsWith('age-07.cjs') ? fixture.age7 : name.endsWith('age-08.cjs') ? fixture.age8 : null;
      return pending ? args => {
        const cohort = value(args);
        return {...cohort, pending: {...cohort.pending, ...pending}};
      } : value;
    };
    let source = fs.readFileSync(filename, 'utf8');
    if (fixture.withdrawCat) source = source.replace(/^cat\|[^\r\n]+/m, '');
    vm.runInNewContext(source, {module: isolated, exports: isolated.exports, require: load, __dirname: path.dirname(filename)}, {filename});
    assert.throws(() => isolated.exports.build(path.resolve(__dirname, '..')), /Invalid or conflicting reopened review/);
    assert.equal(writes, 0, 'Invalid editorial input must not begin serializing an overlay');
  }
});

test('ending a fast and damaging an object retain different break identities through authoring', () => {
  const data = copy();
  const authored = require('../tools/author-growth-morphology.cjs').decisions();
  const expected = { breakfast: 'english.stem.break.end-fast', broken: 'english.stem.break.damage' };
  const parts = Object.keys(expected).map(id => entry(data, id).analysis.parts[0]);
  assert.equal(parts[0].canonical, parts[1].canonical, 'These components deliberately display the same base form');
  assert.equal(parts[0].surface, parts[1].surface);
  assert.notEqual(parts[0].canonical_id, parts[1].canonical_id, 'Same spelling must not make ending a fast interchangeable with damage');
  for (const [id, canonicalId] of Object.entries(expected)) {
    const item = entry(data, id);
    const sourceWord = data.words.find(word => word.id === id);
    const authoredPart = authored.get(id).parts[0];
    assert.equal(item.analysis.parts[0].canonical_id, canonicalId);
    assert.deepEqual(
      [authoredPart.canonical_id, authoredPart.canonical, authoredPart.surface, authoredPart.type],
      [canonicalId, 'break', 'break', item.analysis.parts[0].type],
      'Regenerating the overlay must retain the selected meaning: ' + id
    );
    assert.equal(item.analysis.id, 'growth.' + id + '.analysis.v1');
    assert.equal(item.analysis.lexeme_id, sourceWord.id);
    assert.equal(item.analysis.text, sourceWord.text);
    assert.equal(item.min_age, sourceWord.min_age);
    assert.equal(item.analysis.nodes[0].surface, sourceWord.text);
    assert.equal(item.review.status, 'reviewed');
  }
  assert.equal(entry(data, 'breakfast').analysis.parts[1].canonical_id, 'growth.part.fast.abstention');
  assert.equal(entry(data, 'broken').analysis.parts[1].canonical_id, 'english.affix.en.participle');
});
