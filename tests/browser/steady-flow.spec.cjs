const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint,
  memoryMetrics, memoryPoint, resultPoint, progressRegion, visibleColorCount } = require('./game-ui.cjs');

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
  const bounds = await metrics(page);
  await page.mouse.move(0, 0);
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    x: bounds.x + (point.x - width / 2) * bounds.scale, y: bounds.y + (point.y - height / 2) * bounds.scale,
    width: width * bounds.scale, height: height * bounds.scale
  } });
}

async function progressPatch(page, bounds) {
  const region = progressRegion(bounds);
  return patch(page, { x: region.x + region.width / 2, y: region.y + region.height / 2 }, region.width, region.height);
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

async function matchCards(page, bounds) {
  const cards = [];
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
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
  return { cards, pairs };
}

for (const motion of ['reduce', 'no-preference']) {
test(`Match keeps its board through automatic answers and the chest (${motion})`, async ({ page }, testInfo) => {
  const errors = await start(page, motion);
  await chooseMode(page, 'match');
  const beforeGeometry = await geometry(page), bounds = await metrics(page);
  const { cards, pairs } = await matchCards(page, bounds);
  const [word] = pairs[0], wrong = pairs[1][1];
  const untouched = cards.find(card => card.kind === 'Word' && card.index !== word.index);
  const still = await patch(page, untouched.point);
  await shot(page, testInfo, 'match-before');
  await click(page, word.point);
  await click(page, wrong.point);
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  await shot(page, testInfo, 'match-wrong');
  expect((await patch(page, untouched.point)).equals(still), 'Wrong feedback leaves the untouched card at the same position.').toBe(true);
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  for (const [index, pair] of pairs.entries()) {
    await click(page, pair[0].point);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${pair[0].word}`);
    await click(page, pair[1].point);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    if (index === 0) {
      await shot(page, testInfo, 'match-correct');
      expect((await patch(page, untouched.point)).equals(still), 'A correct answer cannot move the rest of the board.').toBe(true);
    }
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
  const chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try { await expect(page.locator('#game-status')).toContainText(/Piece 1 of 3|A new piece!/); }
  finally { await page.mouse.up(); }
  await shot(page, testInfo, 'match-chest-claimed');
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});

test(`Memory keeps remembered positions through automatic corrections and a full garden (${motion})`, async ({ page }, testInfo) => {
  const errors = await start(page, motion);
  await chooseMode(page, 'memory');
  const beforeGeometry = await geometry(page), bounds = await memoryMetrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(bounds, index);
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
  await expect(page.locator('#game-status')).toContainText('Try another pair.');
  await shot(page, testInfo, 'memory-wrong');
  expect((await patch(page, untouched.point)).equals(still), 'Wrong feedback cannot remove or move hidden cards.').toBe(true);
  await expect(page.locator('#game-status')).toContainText('Find a pair.');
  for (const [index, pair] of pairs.entries()) {
    await click(page, pair[0].point);
    await expect(page.locator('#selection-status')).toHaveText(`Memory card ${pair[0].index + 1}. Word: ${pair[0].word}.`);
    await click(page, pair[1].point);
    await expect(page.locator('#game-status')).toContainText('A new flower!');
    if (index === 0) {
      await shot(page, testInfo, 'memory-correct');
      expect((await patch(page, untouched.point)).equals(still), 'Growing a flower leaves every other remembered position unchanged.').toBe(true);
    }
    await expect(page.locator('#game-status')).toContainText(index === 4 ? 'You did it!' : 'Find a pair.');
  }
  await shot(page, testInfo, 'memory-complete');
  expect(await geometry(page)).toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});
}

test('Match accepts the next card on the first tap during nonfinal feedback', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 'match');
  const beforeGeometry = await geometry(page), bounds = await metrics(page);
  const { cards, pairs } = await matchCards(page, bounds);
  const progress = () => progressPatch(page, bounds);
  await click(page, pairs[0][0].point);
  await click(page, pairs[1][1].point);
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  const afterWrong = await progress();
  await shot(page, testInfo, 'responsive-match-wrong');
  await click(page, pairs[2][0].point);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${pairs[2][0].word}`);
  await expect(page.locator('#game-status')).toContainText('Now find its match!');
  expect((await progress()).equals(afterWrong), 'Selecting a card to leave feedback cannot change either score.').toBe(true);
  await shot(page, testInfo, 'responsive-match-selected-from-wrong');
  await page.keyboard.press('Space');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${pairs[2][0].word}`);
  expect((await progress()).equals(afterWrong)).toBe(true);
  await click(page, pairs[2][1].point);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  const afterCorrect = await progress();
  expect(afterCorrect.equals(afterWrong), 'An actual correct answer changes the success badges.').toBe(false);
  await shot(page, testInfo, 'responsive-match-correct');
  await click(page, pairs[2][0].point);
  await expect(page.locator('#game-status')).toHaveText(`${pairs[2][0].word}. Look at the picture and say the word.`);
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect((await progress()).equals(afterCorrect), 'Replaying a matched card cannot count another pair.').toBe(true);
  await click(page, pairs[0][0].point);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${pairs[0][0].word}`);
  expect((await progress()).equals(afterCorrect)).toBe(true);
  await shot(page, testInfo, 'responsive-match-selected-from-correct');
  await click(page, pairs[0][1].point);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await click(page, pairs[1][0].point);
  await click(page, pairs[1][1].point);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  const distractor = cards.find(card => !pairs.some(pair => pair.includes(card)));
  await click(page, distractor.point);
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await shot(page, testInfo, 'responsive-match-won');
  expect(await geometry(page), 'The full round reuses its original card coordinates without a layout transition.').toEqual(beforeGeometry);
  expect(errors).toEqual([]);
});
