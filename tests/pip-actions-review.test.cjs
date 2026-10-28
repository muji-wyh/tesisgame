const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const directory = path.join(root, 'web', 'preview', 'pip-growth');
const read = file => fs.readFileSync(path.join(root, ...file.split('/')), 'utf8');
const catalog = JSON.parse(read('web/preview/pip-growth/action-catalog.json'));
const stages = JSON.parse(read('data/pip-growth-stages.json'));
const motions = JSON.parse(read('data/pip-age-motions.json'));
const native = read('scripts/duck_mascot.gd');

test('the review uses current native source samples, not stale or invented choreography', () => {
  assert.equal(catalog.version, 1);
  assert.equal(catalog.fps, 24);
  for (const [file, hash] of Object.entries(catalog.sources)) {
    const bytes = fs.readFileSync(path.join(root, ...file.split('/')));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), hash,
      `${file} changed: regenerate the native Pip review catalog`);
  }
  assert.deepEqual(JSON.parse(read('web/preview/pip-growth/stages.json')), stages);
});

test('all signature, inherited, facial and application response families are present', () => {
  const ids = catalog.actions.map(action => action.id);
  assert.equal(new Set(ids).size, ids.length);
  assert.deepEqual(catalog.actions.filter(action => action.category === 'signature')
    .map(action => action.id).sort(), Object.keys(motions.clips).sort());
  const inherited = [...native.match(/const GROWTH_ACTION_SECONDS := \{([\s\S]*?)\}/)[1]
    .matchAll(/"([^"]+)":/g)].map(match => `inherited:${match[1]}`).sort();
  assert.deepEqual(catalog.actions.filter(action => action.category === 'inherited')
    .map(action => action.id).sort(), inherited);
  assert.deepEqual(catalog.actions.filter(action => action.kind === 'expression')
    .map(action => action.face), stages.expressions);
  for (const id of ['idle', 'speaking', 'attention:listening', 'attention:thinking',
    'hello:delighted', 'hello:wink', 'hello:proud', 'curious',
    'answer:delighted', 'answer:wink', 'answer:proud', 'answer:encourage', 'celebration']) {
    assert.ok(ids.includes(id), `${id} must not disappear behind the age gestures`);
  }
  const shell = read('web/shell.html');
  const loadingIds = [...shell.match(/const pipReactionLabels = \{([\s\S]*?)\};/)[1]
    .matchAll(/^\s*(\w+):/gm)].map(match => `loading:${match[1]}`);
  assert.deepEqual(catalog.actions.filter(action => action.kind === 'loading').map(action => action.id), loadingIds);
  assert.equal(catalog.actions.find(action => action.id === 'celebration').seconds, 3);
});

test('all legal age variants have complete finite frames, real atlas cells and native reduced poses', () => {
  let count = 0;
  const cells = new Map(stages.stages.flatMap(stage => ['regular', 'expressions'].map(sheet => {
    const bytes = fs.readFileSync(path.join(root, ...stage.art[sheet].split('/')));
    return [`${stage.age}:${sheet}`, bytes.readUInt32BE(16) / 360];
  })));
  for (const action of catalog.actions) {
    const expected = action.kind === 'loading' ? ['loading'] : stages.stages.filter(stage =>
      (!Object.hasOwn(action, 'age') || stage.age === action.age) &&
      (action.category !== 'inherited' || stage.actions.includes(action.native_id))).map(stage => String(stage.age));
    assert.deepEqual(Object.keys(action.performances).sort(), expected.sort(), action.id);
    for (const [age, performance] of Object.entries(action.performances)) {
      count++;
      const stage = stages.stages.find(stage => stage.age === Number(age));
      const expectedFrames = action.held ? 1 : Math.ceil(action.seconds * catalog.fps) + 1;
      assert.equal(performance.frames.length, expectedFrames, `${action.id} native duration`);
      for (const frame of [...performance.frames, performance.reduced]) {
        const matrix = value => assert.ok(value.length === 6 && value.every(Number.isFinite));
        if (frame.mode === 'parts') {
          assert.equal(frame.parts.length, 6);
          frame.parts.forEach(matrix);
          assert.ok(!frame.face || stages.expressions.includes(frame.face));
          assert.ok(frame.shadow.every(Number.isFinite));
          assert.ok(frame.shadow[2] > 0 && frame.shadow[3] > 0);
        } else {
          assert.equal(frame.mode, 'sheet');
          matrix(frame.transform);
          assert.ok(Number.isInteger(frame.cell) && frame.cell >= 0 && frame.cell < cells.get(`${age}:${frame.sheet}`));
        }
      }
    }
  }
  assert.equal(count, catalog.performances);
  assert.equal(catalog.native_performances, 331);
  assert.equal(count, 334);
  const loading = catalog.contexts.loading;
  assert.deepEqual(fs.readFileSync(path.join(directory, ...loading.previewArt.parts.split('/'))),
    fs.readFileSync(path.join(root, ...loading.originalArt.split('/'))));
});

test('the gallery is wired into the local review and separates future work from actual motion', () => {
  const html = fs.readFileSync(path.join(directory, 'actions.html'), 'utf8');
  const index = fs.readFileSync(path.join(directory, 'index.html'), 'utf8');
  const script = fs.readFileSync(path.join(directory, 'actions.js'), 'utf8');
  assert.match(index, /href="actions\.html">All actions/);
  assert.match(html, /Proposed next · not implemented/);
  assert.match(html, /No Duolingo artwork or audio is integrated/);
  assert.match(html, /not a set of newly authored animations/);
  assert.match(script, /visibilitychange/);
  assert.match(script, /prefers-reduced-motion/);
  assert.doesNotMatch(script, /localStorage|wordBuddiesHost|new Audio|speechSynthesis/);
  for (const id of ['category', 'age', 'search', 'variant-age', 'display-size', 'timeline', 'reduced-motion']) {
    assert.ok(html.includes(`id="${id}"`), `${id} review control is reachable`);
  }
});
