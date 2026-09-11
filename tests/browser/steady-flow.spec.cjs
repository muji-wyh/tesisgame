const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint,
  memoryPoint, feedbackPoint, choicePoint, choiceTargetPoint, resultPoint, visibleColorCount } = require('./game-ui.cjs');

async function click(page, point) {
  await tap(page, point.x, point.y);
  await rendered(page);
}

async function geometry(page) {
  return page.locator('#canvas').evaluate(canvas => {
    const { x, y, width, height } = canvas.getBoundingClientRect();
    return { x, y, width, height, scrollX, scrollY, timeOrigin: performance.timeOrigin };
  });
}

async function patch(page, point, width = 48, height = 28) {
  const b = await metrics(page);
  await page.mouse.move(0, 0);
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    x: b.x + (point.x - width / 2) * b.scale, y: b.y + (point.y - height / 2) * b.scale,
    width: width * b.scale, height: height * b.scale
  } });
}

async function shot(page, testInfo, name) {
  await rendered(page);
  const png = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  expect(await visibleColorCount(page, png), `${name}: stable patches must belong to a rendered game, not two blank frames.`).toBeGreaterThan(20);
}

async function start(page, reducedMotion) {
  if (reducedMotion === 'no-preference') await page.setViewportSize({ width: 320, height: 568 });
  return openGame(page, { reducedMotion });
}

for (const motion of ['reduce', 'no-preference']) {
test(`Match keeps its board through answers and the chest (${motion})`, async ({ page }, testInfo) => {
  const errors = await start(page, motion);
  await chooseMode(page, 1);
  const beforeGeometry = await geometry(page);
  const b = await metrics(page), cards = [];
  // Discover identities with actual taps, then reuse those exact locations.
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(b, index);
    await click(page, point);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    cards.push({ index, kind, word, point });
    await click(page, point);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]
  ).filter(([, picture]) => picture);
  expect(pairs).toHaveLength(3);
  const [word] = pairs[0];
  const wrong = pairs[1][1];
  const untouched = cards.find(card => card.kind === 'Word' && card.index !== word.index);
  const still = await patch(page, untouched.point);
  await shot(page, testInfo, 'match-before');
  await click(page, word.point);
  await click(page, wrong.point);
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  await shot(page, testInfo, 'match-wrong');
  expect((await patch(page, untouched.point)).equals(still), 'Wrong feedback must leave the untouched card visible at the same position.').toBe(true);
  const continuePoint = lessonPoint(b, 'action', { match: true, multiple: true });
  const continueButton = await patch(page, continuePoint);
  await click(page, continuePoint);
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  for (const [index, pair] of pairs.entries()) {
    await click(page, pair[0].point);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${pair[0].word}`);
    await click(page, pair[1].point);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    if (index === 0) {
      await shot(page, testInfo, 'match-correct');
      expect((await patch(page, untouched.point)).equals(still), 'Correct feedback must keep the rest of the board visible.').toBe(true);
      expect((await patch(page, continuePoint)).equals(continueButton), 'Continue must not move when the correction changes from two words to one.').toBe(true);
    }
    // The same Continue location serves one-word and two-word corrections.
    await click(page, continuePoint);
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
  const chest = resultPoint(b, 'chest');
  await page.mouse.move(b.x + chest.x * b.scale, b.y + chest.y * b.scale);
  await page.mouse.down();
  try { await expect(page.locator('#game-status')).toContainText(/Piece 1 of 3|A new piece!/); }
  finally { await page.mouse.up(); }
  await shot(page, testInfo, 'match-chest-claimed');
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});

test(`Memory keeps remembered positions through corrections and a full garden (${motion})`, async ({ page }, testInfo) => {
  const errors = await start(page, motion);
  await chooseMode(page, 4);
  const beforeGeometry = await geometry(page);
  const b = await metrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(b, index);
    await click(page, point);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    const [, number, kind, word] = (await page.locator('#selection-status').textContent()).match(/^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/);
    expect(Number(number)).toBe(index + 1);
    cards.push({ index, kind, word, point });
    await click(page, point);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]);
  expect(pairs).toHaveLength(5);
  const [word, right] = pairs[0], wrong = pairs[1][1];
  const untouched = cards.find(card => ![word.index, right.index, wrong.index].includes(card.index));
  const still = await patch(page, untouched.point);
  await shot(page, testInfo, 'memory-before');
  await click(page, word.point);
  await click(page, wrong.point);
  await expect(page.locator('#game-status')).toContainText('learn these words');
  await shot(page, testInfo, 'memory-wrong');
  expect((await patch(page, untouched.point)).equals(still), 'Wrong feedback cannot remove or move hidden cards.').toBe(true);
  const continuePoint = feedbackPoint(b, 'action', 'memory');
  const continueButton = await patch(page, continuePoint);
  await click(page, continuePoint);
  await expect(page.locator('#game-status')).toContainText('Find a pair.');
  for (const [index, pair] of pairs.entries()) {
    await click(page, pair[0].point);
    await expect(page.locator('#selection-status')).toHaveText(`Memory card ${pair[0].index + 1}. Word: ${pair[0].word}.`);
    await click(page, pair[1].point);
    await expect(page.locator('#game-status')).toContainText('A new flower!');
    if (index === 0) {
      await shot(page, testInfo, 'memory-correct');
      expect((await patch(page, untouched.point)).equals(still), 'Growing a flower must leave all other remembered positions unchanged.').toBe(true);
      expect((await patch(page, continuePoint)).equals(continueButton), 'Continue remains visually fixed after either pair outcome.').toBe(true);
    }
    await click(page, continuePoint);
    await expect(page.locator('#game-status')).toContainText(index === 4 ? 'You did it!' : 'Find a pair.');
  }
  await shot(page, testInfo, 'memory-complete');
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});

for (const [mode, name] of [[2, 'Sky'], [3, 'Listen']]) {
test(`${name} keeps the question visible and retry locations stable (${motion})`, async ({ page }, testInfo) => {
  // Exercise the written Listen target too; separate learning tests cover sound.
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
  });
  const errors = await start(page, motion);
  await chooseMode(page, mode);
  const beforeGeometry = await geometry(page), b = await metrics(page);
  const answerPoints = [choicePoint(b, 0), choicePoint(b, 1)];
  const continuePoint = feedbackPoint(b, 'action');
  const targetPoint = choiceTargetPoint(b);
  // Only the first Sky entrance animates. Wait beyond that deliberate entrance.
  if (motion === 'no-preference' && mode === 2) await page.waitForTimeout(1000);
  const outcomes = new Set();
  let answer = 0;
  for (let attempt = 0; attempt < 12 && outcomes.size < 2; attempt++) {
    const target = await patch(page, targetPoint, 120, 72);
    await shot(page, testInfo, `${name}-${attempt}-before`);
    await click(page, answerPoints[answer]);
    await expect(page.locator('#game-status')).toContainText('Continue');
    const feedback = await page.locator('#game-status').textContent();
    const correct = feedback.startsWith('Yes!');
    outcomes.add(correct ? 'correct' : 'wrong');
    await shot(page, testInfo, `${name}-${attempt}-${correct ? 'correct' : 'wrong'}`);
    expect((await patch(page, targetPoint, 120, 72)).equals(target), 'Answer feedback must keep the same question artwork or written target at its original position.').toBe(true);
    await click(page, answerPoints[1 - answer]);
    await expect(page.locator('#game-status')).toHaveText(feedback);
    await click(page, continuePoint);
    const status = await page.locator('#game-status').textContent();
    if (/You did it!|Try again/.test(status)) {
      await click(page, resultPoint(b, 'repeat'));
      await expect(page.locator('#game-status')).toContainText(mode === 2 ? 'Sky words.' : 'Listen.');
      if (motion === 'no-preference' && mode === 2) await page.waitForTimeout(1000);
    } else if (!correct) {
      expect((await patch(page, targetPoint, 120, 72)).equals(target), 'A wrong answer retries the same target in place.').toBe(true);
    }
    // On a retry the other original answer location is correct.
    answer = correct ? 0 : 1 - answer;
  }
  expect([...outcomes].sort()).toEqual(['correct', 'wrong']);
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});
}
}

test('Learn keeps its controls in place while replacing only the association', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const beforeGeometry = await geometry(page), b = await metrics(page);
  const next = lessonPoint(b, 'next'), previous = lessonPoint(b, 'previous');
  await click(page, next);
  await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\./);
  const second = await page.locator('#game-status').textContent();
  const control = await patch(page, next);
  await shot(page, testInfo, 'learn-second');
  await click(page, next);
  await expect(page.locator('#game-status')).not.toHaveText(second);
  expect((await patch(page, next)).equals(control), 'Next remains at the same position between ordinary lesson cards.').toBe(true);
  await click(page, previous);
  await expect(page.locator('#game-status')).toHaveText(second);
  await shot(page, testInfo, 'learn-returned');
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});
