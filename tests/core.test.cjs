const test = require('node:test');
const assert = require('node:assert/strict');
const { loadInline, loadWords } = require('.\\load-inline.cjs');

const core = loadInline('game-core').GameCore;
const words = loadWords();
const round = () => core.createRound(words, () => 0.4);
const ids = (state) => [...new Set(state.cards.map((card) => card.wordId))];

function match(state, id, reverse = false) {
  const kinds = reverse ? ['image', 'word'] : ['word', 'image'];
  return core.chooseCard(core.chooseCard(state, `${id}:${kinds[0]}`), `${id}:${kinds[1]}`);
}

function wrong(state) {
  const [a, b] = ids(state).filter((id) => !state.matched.includes(id));
  return core.chooseCard(core.chooseCard(state, `${a}:word`), `${b}:image`);
}

test('validates vocabulary instead of substituting a built-in list', () => {
  assert.equal(core.validateWords(words).length, 8);
  const invalid = [
    [], words.slice(0, 2), [...words, words[0]],
    [{ ...words[0], image: 'https://example.invalid/cat.svg' }, ...words.slice(1)],
    [{ ...words[0], text: '' }, ...words.slice(1)],
    [{ ...words[0], text: true }, ...words.slice(1)]
  ];
  for (const input of invalid) {
    assert.throws(() => core.validateWords(input), { name: 'TypeError' });
  }
});

test('starts waiting with three complete unique pairs and does not mutate shuffle input', () => {
  const state = round();
  assert.equal(state.phase, 'waiting');
  assert.equal(state.cards.length, 6);
  assert.equal(ids(state).length, 3);
  assert.equal(new Set(state.cards.map((card) => card.id)).size, 6);
  assert.equal(state.successes + state.errors, 0);
  for (const id of ids(state)) {
    assert.deepEqual(
      Array.from(state.cards.filter((card) => card.wordId === id), (card) => card.kind).sort(),
      ['image', 'word']
    );
  }
  const input = [1, 2, 3];
  assert.notDeepEqual(Array.from(core.shuffle(input, () => 0)), input);
  assert.deepEqual(input, [1, 2, 3]);
  assert.throws(() => core.createRound(words, () => 1), { name: 'RangeError' });
  assert.throws(() => core.createRound(words, () => -0.1), { name: 'RangeError' });
});

test('either kind starts; same-card cancels and same-kind reselects without an error', () => {
  const state = round();
  const [a, b] = ids(state);
  for (const kind of ['image', 'word']) {
    const first = core.chooseCard(state, `${a}:${kind}`);
    assert.equal(first.phase, 'matching');
    const next = core.chooseCard(first, `${b}:${kind}`);
    assert.equal(next.selected, `${b}:${kind}`);
    assert.equal(next.errors, 0);
    assert.equal(core.chooseCard(next, `${b}:${kind}`).phase, 'waiting');
  }
  assert.equal(state.selected, null);
  assert.throws(() => core.chooseCard(state, 'unknown:word'), { name: 'RangeError' });
});

test('correct feedback counts once, locks clicks and prevents scoring the pair again', () => {
  const state = round();
  const [a, b] = ids(state);
  const feedback = match(state, a, true);
  assert.equal(feedback.successes, 1);
  assert.equal(feedback.feedback.correct, true);
  assert.equal(core.chooseCard(feedback, `${b}:word`), feedback);
  const ready = core.finishFeedback(feedback);
  assert.equal(core.chooseCard(ready, `${a}:image`), ready);
  assert.equal(state.successes, 0);
});

test('wrong feedback increments only errors and clears selection', () => {
  const feedback = wrong(round());
  assert.equal(feedback.errors, 1);
  assert.equal(feedback.successes, 0);
  assert.equal(feedback.feedback.correct, false);
  const ready = core.finishFeedback(feedback);
  assert.equal(ready.phase, 'waiting');
  assert.equal(ready.selected, null);
  assert.equal(ready.feedback, null);
});

test('three matches win despite an earlier error without rerolling the current theme', () => {
  let state = core.finishFeedback(wrong(round()));
  for (const id of ids(state)) state = core.finishFeedback(match(state, id));
  assert.equal(state.phase, 'won');
  assert.equal(state.theme, 'summer');
  assert.equal(state.errors, 1);
  assert.equal(core.finishFeedback(state), state);
  assert.equal(core.chooseCard(state, state.cards[0].id), state);
});

test('errors accumulate independently, not consecutively or as a combined total', () => {
  let state = core.finishFeedback(wrong(round()));
  state = core.finishFeedback(match(state, ids(state)[0]));
  state = core.finishFeedback(wrong(state));
  assert.equal(state.successes + state.errors, 3);
  assert.equal(state.phase, 'waiting');
  state = core.finishFeedback(wrong(state));
  assert.equal(state.phase, 'lost');
  assert.equal(state.errors, 3);
  assert.equal(state.theme, 'summer');
  assert.equal(core.chooseCard(state, state.cards[0].id), state);
  assert.equal(round().matched.length, 0);
});

test('four equal random intervals choose the corresponding season', () => {
  assert.deepEqual(
    [0, 0.2499, 0.25, 0.5, 0.75, 0.9999].map((value) => core.chooseSeason(() => value).id),
    ['spring', 'spring', 'summer', 'autumn', 'winter', 'winter']
  );
});

test('theme switching preserves selection, feedback, scores and matched cards', () => {
  const initial = round();
  let state = core.chooseCard(initial, `${ids(initial)[0]}:word`);
  const selected = state.selected;
  state = core.setTheme(state, 'winter');
  assert.equal(state.phase, 'matching');
  assert.equal(state.selected, selected);
  state = core.chooseCard(state, `${selected.split(':')[0]}:image`);
  const changed = core.setTheme(state, 'spring');
  assert.equal(changed.phase, 'feedback');
  assert.equal(changed.successes, 1);
  assert.equal(changed.matched, state.matched);
  assert.equal(changed.cards, state.cards);
  assert.equal(core.finishFeedback(changed).theme, 'spring');
  assert.throws(() => core.setTheme(changed, 'unknown'), { name: 'RangeError' });
});
