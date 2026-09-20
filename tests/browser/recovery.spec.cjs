const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, enterGame, openGame, boardPoint,
  resultPoint, headerPoint } = require('./game-ui.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';

async function medalRecord(page) {
  return page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
}

async function pieceCount(page) {
  const counts = (await medalRecord(page))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return [...counts.matchAll(/:\s*(\d+)/g)].reduce((total, match) => total + Number(match[1]), 0);
}

async function resultTap(page, key) {
  const point = resultPoint(await metrics(page), key);
  await tap(page, point.x, point.y);
  await rendered(page);
}

async function winMatch(page) {
  const bounds = await metrics(page);
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = [...cards.entries()].filter(([, pair]) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (const [index, [word, pair]] of pairs.entries()) {
    const written = boardPoint(bounds, pair.Word), pictured = boardPoint(bounds, pair.Picture);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
  await expect(page.locator('#game-status')).toContainText('You did it!');
}

test('unavailable rewards leave practice usable and a visible retry preserves the current card', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    const read = Storage.prototype.getItem;
    Storage.prototype.getItem = function (key) {
      if (key === 'wordBuddies.medalProgress') throw new DOMException('Read blocked for recovery test', 'SecurityError');
      return read.call(this, key);
    };
    window.restoreRewardRead = () => { Storage.prototype.getItem = read; };
  });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Rewards are unavailable.');
  await page.screenshot({ path: testInfo.outputPath('unavailable-rewards-match.png'), scale: 'css' });

  await chooseMode(page, 'match');
  const card = boardPoint(await metrics(page), 0);
  await tap(page, card.x, card.y);
  await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
  await chooseMode(page, 'memory');
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(/^Memory card 1\. (Word|Picture): [a-z]+\.$/);
  const selected = await page.locator('#selection-status').textContent();
  await page.screenshot({ path: testInfo.outputPath('unavailable-rewards-memory.png'), scale: 'css' });
  await page.evaluate(() => window.restoreRewardRead());
  // Retry uses the left progress slot while storage is unavailable.
  const retry = headerPoint(await metrics(page), 'retry');
  await tap(page, retry.x, retry.y);
  await expect(page.locator('#game-status')).toContainText('Memory.');
  await expect(page.locator('#game-status')).not.toContainText('Rewards are unavailable.');
  expect(await medalRecord(page)).toContain('[medals]');
  expect(await page.locator('#selection-status').textContent()).toBe(selected);
  await page.screenshot({ path: testInfo.outputPath('rewards-recovered-memory.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('New adventure preserves unopened victory pieces across reload', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseTheme(page, 0);
  await chooseMode(page, 'match');
  await winMatch(page);
  expect(await pieceCount(page)).toBe(0);
  await resultTap(page, 'newAdventure');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  expect(await pieceCount(page)).toBe(1);
  await chooseMode(page, 'match');
  await winMatch(page);
  await resultTap(page, 'newAdventure');
  await expect(page.locator('#game-status')).toHaveText('Find 3 word–picture pairs. Two cards have no match.');
  expect(await pieceCount(page)).toBe(2);
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  expect(await pieceCount(page)).toBe(2);
  await page.screenshot({ path: testInfo.outputPath('unopened-pieces-restored.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a failed victory save stays retryable and cannot lose or duplicate its piece', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseTheme(page, 0);
  await chooseMode(page, 'match');
  await winMatch(page);
  const before = await medalRecord(page);
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.medalProgress') throw new DOMException('Save blocked for recovery test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreRewardSave = () => { Storage.prototype.setItem = save; };
  });
  await resultTap(page, 'newAdventure');
  await expect(page.locator('#game-status')).toContainText('Choose Retry saving.');
  expect(await medalRecord(page)).toBe(before);
  // A separate retry action replaces navigation until the reward is safe.
  await resultTap(page, 'retry');
  await expect(page.locator('#game-status')).toContainText('Keep your piece');
  expect(await medalRecord(page)).toBe(before);
  await page.screenshot({ path: testInfo.outputPath('victory-save-failed.png'), scale: 'css' });
  await page.evaluate(() => window.restoreRewardSave());
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('A new piece!');
  expect(await pieceCount(page)).toBe(1);
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  expect(await pieceCount(page)).toBe(1);
  await page.screenshot({ path: testInfo.outputPath('victory-save-recovered.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
