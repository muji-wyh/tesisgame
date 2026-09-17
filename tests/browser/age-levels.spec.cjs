const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const { openGame, openRewards, metrics, tap, rendered, ageButtonRect, collectionHeaderRect,
  boardPoint, chooseMode, swipeLearn, memoryPoint, roomControl, withMemoryPeek } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const NAMES = { all: 'All words', '4-6': 'Ages 4-6', '7-9': 'Ages 7-9', '10-plus': 'Ages 10+' };
const WORD = /^Learn: ([a-z]+)\. Swipe to explore\. Tap the picture to hear\.$/;
const vocabulary = new Map(words.map(word => [word.id, word]));

async function saved(page) {
  return page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
}

async function age(page, id, input = 'touch') {
  const bounds = await metrics(page), rect = ageButtonRect(bounds, id);
  if (input === 'mouse') {
    await page.mouse.click(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
      bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  } else {
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  }
  await rendered(page);
}

async function closeMore(page) {
  const rect = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await rendered(page);
}

async function matchCards(page) {
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    cards.push(await page.locator('#selection-status').textContent());
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

async function learnWords(page) {
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(WORD);
  await swipeLearn(page, 'previous');
  const result = [];
  for (let index = 0; index < 5; index++) {
    if (index) await swipeLearn(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(WORD);
    result.push((await page.locator('#game-status').textContent()).match(WORD)[1]);
  }
  expect(new Set(result).size).toBe(5);
  return result;
}

async function memoryWords(page) {
  const bounds = await metrics(page), result = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    result.push((await page.locator('#selection-status').textContent()).match(/: ([a-z]+)\.$/)[1]);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return result;
}

test('age choices preserve the current lesson in all modes and apply after reload', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  const errors = await openGame(page, { mode: 'match' });
  const before = await matchCards(page);
  const originalWords = [...new Set(before.map(card => card.split(': ')[1]))].sort();
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const rewards = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await openRewards(page);
  const originalSave = await saved(page);
  for (const id of ['4-6', '7-9', '10-plus', 'all', '4-6']) {
    await age(page, id);
    await expect(page.locator('#game-status')).toContainText(`Next lesson: ${NAMES[id]}`);
    expect(await saved(page)).toBe(originalSave.replace(/^age_band="all"$/m, `age_band="${id}"`));
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
  }
  await page.screenshot({ path: testInfo.outputPath('age-choices.png'), scale: 'css' });
  await closeMore(page);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await tap(page, first.x, first.y);
  expect(await matchCards(page)).toEqual(before);
  await chooseMode(page, 'learn');
  expect((await learnWords(page)).sort()).toEqual(originalWords);
  await chooseMode(page, 'memory');
  const remembered = await memoryWords(page);
  expect([...new Set(remembered)].sort()).toEqual(originalWords);
  for (const word of originalWords) expect(remembered.filter(value => value === word)).toHaveLength(2);
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(rewards);
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  const nextWords = (await matchCards(page)).map(card => card.split(': ')[1]);
  expect(nextWords.every(word => vocabulary.get(word).level === 'basic')).toBe(true);
  await openRewards(page);
  await page.screenshot({ path: testInfo.outputPath('saved-age-after-reload.png'), scale: 'css' });
  expect(await saved(page)).toContain('age_band="4-6"');
  expect(errors).toEqual([]);
});

test('age saving retries in place with mouse, touch and keyboard at compact widths', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  await openRewards(page);
  await age(page, '7-9');
  await expect(page.locator('#game-status')).toContainText('Next lesson: Ages 7-9');
  const confirmed = await saved(page);
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Age preference blocked for test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreAgeSaving = () => { Storage.prototype.setItem = save; };
  });
  try {
    await age(page, '10-plus', 'mouse');
    await expect(page.locator('#game-status')).toContainText('Not saved. Tap an age to retry.');
    expect(await saved(page)).toBe(confirmed);
    await page.screenshot({ path: testInfo.outputPath('age-save-retry.png'), scale: 'css' });
  } finally {
    await page.evaluate(() => window.restoreAgeSaving());
  }
  await age(page, '10-plus', 'mouse');
  await expect(page.locator('#game-status')).toContainText('Next lesson: Ages 10+');
  expect(await saved(page)).toContain('age_band="10-plus"');
  await age(page, 'all', 'mouse');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Next lesson: Ages 4-6');
  expect(await saved(page)).toContain('age_band="4-6"');
  await page.setViewportSize({ width: 320, height: 568 });
  await rendered(page);
  for (const id of Object.keys(NAMES)) {
    const bounds = await metrics(page), rect = ageButtonRect(bounds, id);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(48);
    expect(rect.height * bounds.scale).toBeGreaterThanOrEqual(48);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(320);
    await age(page, id);
    await expect(page.locator('#game-status')).toContainText(`Next lesson: ${NAMES[id]}`);
    expect(await saved(page)).toContain(`age_band="${id}"`);
  }
  await page.screenshot({ path: testInfo.outputPath('age-choices-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a new gift lesson uses advanced vocabulary across Learn, Match and Memory', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  await page.addInitScript(key => {
    if (!localStorage.getItem(key)) {
      localStorage.setItem(key, '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite=""\n'
        + '\n[learning]\nage_band="4-6"\n');
    }
  }, ROOM_KEY);
  const errors = await openGame(page, { mode: 'match' });
  await openRewards(page);
  await age(page, '10-plus');
  await expect(page.locator('#game-status')).toContainText('Next lesson: Ages 10+');
  expect(await saved(page)).toContain('age_band="10-plus"');
  await roomControl(page, 'winter');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Winter bell.');
  await roomControl(page, 'goal', { locked: true, item: 'winter' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Music makers. Learn five words.');
  const lesson = await learnWords(page);
  expect(lesson[0]).toBe('bell');
  expect(lesson.slice(1).every(word => vocabulary.get(word).level === 'advanced')).toBe(true);
  expect(lesson.some(word => word.length >= 9)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('advanced-learn.png'), scale: 'css' });
  await chooseMode(page, 'match');
  expect([...new Set((await matchCards(page)).map(card => card.split(': ')[1]))].sort()).toEqual([...lesson].sort());
  await page.screenshot({ path: testInfo.outputPath('advanced-match.png'), scale: 'css' });
  await chooseMode(page, 'memory');
  expect([...new Set(await memoryWords(page))].sort()).toEqual([...lesson].sort());
  await withMemoryPeek(page, async () => {
    await page.screenshot({ path: testInfo.outputPath('advanced-memory.png'), scale: 'css' });
  });
  expect(await saved(page)).toContain('age_band="10-plus"');
  expect(errors).toEqual([]);
});
