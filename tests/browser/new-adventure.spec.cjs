const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseTheme, chooseMode, rendered, enterGame, openGame, matchWords, discoverMatchCards,
  headerPoint, boardPoint, resultPoint, openRewards, collectionHeaderRect, acceptCelebration } = require('./game-ui.cjs');

const GROWTH_KEY = 'growWithPip.growth.v1';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const INTRO = 'Find 5 word–picture pairs.';

async function record(page, key = GROWTH_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

async function pieceCount(page) {
  const counts = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return [...counts.matchAll(/:\s*(\d+)/g)].reduce((total, match) => total + Number(match[1]), 0);
}

async function finishMatch(page, knownCards = null) {
  await chooseMode(page, 'match');
  await expect.poll(async () => (await metrics(page)).library?.visible).toBe(false);
  const bounds = await metrics(page), cards = new Map();
  for (const { index, kind, word } of knownCards || await discoverMatchCards(page)) {
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
  }
  const pairs = [...cards].filter(([, pair]) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(5);
  const attempts = pairs.length;
  for (let index = 0; index < attempts; index++) {
    const [word, pair] = pairs[index];
    const written = boardPoint(bounds, pair.Word);
    const pictured = boardPoint(bounds, pair.Picture);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === attempts - 1 ? 'You did it!' : 'Find 5 word');
  }
  await acceptCelebration(page);
  return [...cards.keys()];
}

test('New adventure appears at the bottom-right after opening the chest and starts Match directly', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseTheme(page, 5);
  const world = await page.locator('meta[name="theme-color"]').getAttribute('content');
  const originalCards = await discoverMatchCards(page), pieces = await pieceCount(page);
  const originalWords = [...new Set(originalCards.map(card => card.word))];
  expect((await finishMatch(page, originalCards)).sort()).toEqual([...originalWords].sort());
  await page.screenshot({ path: testInfo.outputPath('result-chest-closed.png'), scale: 'css' });
  const next = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  expect(await pieceCount(page), 'The future floating-button area cannot skip an unopened chest.').toBe(pieces);
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  } finally {
    await page.mouse.up();
  }
  expect(await pieceCount(page)).toBe(pieces + 1);
  const saved = await record(page);
  await page.mouse.move(0, 0);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('result-chest-open-floating-adventure.png'), scale: 'css' });
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', world);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('direct-next-lesson-complete.png'), scale: 'css' });
  const nextWords = await matchWords(page);
  expect(nextWords.filter(word => originalWords.includes(word)), 'A direct New adventure rotates the five-word selection without a picker.').toEqual([]);
  const changed = await record(page);
  expect(changed, 'Starting a lesson preserves accepted learning attempts').toBe(saved);
  expect(await pieceCount(page), 'Starting the next lesson cannot award the opened chest again.').toBe(pieces + 1);
  expect(errors).toEqual([]);
});

test('Growth notebook and Back preserve the Match board and selected card', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const cards = await discoverMatchCards(page), selected = cards[3];
  const point = boardPoint(await metrics(page), selected.index);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  const saved = await record(page), medals = await record(page, MEDAL_KEY);
  await openRewards(page);
  await expect(page.locator('#game-status')).toContainText('Lv0');
  await expect(page.locator('#game-status')).toContainText('Six correct answers');
  await page.screenshot({ path: testInfo.outputPath('more-worlds-preserves-lesson.png'), scale: 'css' });
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  await tap(page, point.x, point.y);
  expect(await discoverMatchCards(page)).toEqual(cards);
  expect(await record(page)).toBe(saved);
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});
