const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint, swipeLearn,
  openRewards, chooseTheme, chooseRewardSection: section } = require('./game-ui.cjs');

const KEY = 'wordBuddies.playroom';

async function record(page) {
  const text = await page.evaluate(key => localStorage.getItem(key), KEY);
  return {
    ids: [...(text?.match(/^word_ids=(.*)$/m)?.[1] || '').matchAll(/"([a-z-]+)"/g)].map(match => match[1]),
    displayed: text?.match(/^display_word_id="([a-z-]*)"$/m)?.[1] || '',
  };
}

async function pictureTap(page) {
  const point = lessonPoint(await metrics(page), 'picture');
  await tap(page, point.x, point.y);
}

test('picture taps pronounce and Match no longer creates runtime word stickers', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\./);
  const before = await page.locator('#game-status').textContent();
  const word = before.match(/^Learn: ([a-z]+)/)[1];
  await pictureTap(page);
  const canHear = await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext));
  await expect(page.locator('#game-status')).toHaveText(canHear ? `${word}. Look at the picture and say the word.` : before);
  expect((await record(page)).ids).toEqual([]);
  await chooseMode(page, 'match');
  const b = await metrics(page);
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    const p = boardPoint(b, index);
    await tap(page, p.x, p.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, id] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(id)) cards.set(id, {});
    cards.get(id)[kind] = index;
    await tap(page, p.x, p.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  expect((await record(page)).ids).toEqual([]);
  const [id, pair] = [...cards.entries()].find(([, item]) => item.Word !== undefined && item.Picture !== undefined);
  const written = boardPoint(b, pair.Word), pictured = boardPoint(b, pair.Picture);
  await tap(page, written.x, written.y);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${id}`);
  await tap(page, pictured.x, pictured.y);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  expect((await record(page)).ids, 'Matching must not recreate the removed Words collection.').toEqual([]);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('picture-audio-without-sticker-writes.png'), scale: 'css' });
  await openRewards(page);
  await section(page, 'medals');
  expect((await record(page)).ids).toEqual([]);
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect((await record(page)).ids).toEqual([]);
  expect(errors).toEqual([]);
});

test('saved word sticker records survive More, world choices and reload', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.addInitScript(({ key }) => {
    if (!localStorage.getItem(key)) localStorage.setItem(key, '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite=""\n\n[stickers]\nword_ids=["cat", "apple", "rocket", "bell"]\ndisplay_word_id="cat"\n');
  }, { key: KEY });
  const errors = await openGame(page);
  const saved = await record(page);
  expect(saved).toEqual({ ids: ['cat', 'apple', 'rocket', 'bell'], displayed: 'cat' });
  await openRewards(page);
  await section(page, 'medals');
  await expect(page.locator('#game-status')).toContainText('Choose a world from the icons above');
  await page.screenshot({ path: testInfo.outputPath('saved-stickers-worlds-320.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await chooseTheme(page, 5);
  expect(await record(page)).toEqual(saved);
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect((await record(page)).displayed).toBe('cat');
  await openRewards(page);
  await page.screenshot({ path: testInfo.outputPath('saved-stickers-restored-320.png'), scale: 'css' });
  expect((await record(page)).ids).toEqual(['cat', 'apple', 'rocket', 'bell']);
  expect(errors).toEqual([]);
});
