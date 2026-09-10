const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint } = require('./game-ui.cjs');

const KEY = 'wordBuddies.playroom';

async function record(page) {
  const text = await page.evaluate(key => localStorage.getItem(key), KEY);
  return {
    ids: [...(text?.match(/^word_ids=(.*)$/m)?.[1] || '').matchAll(/"([a-z-]+)"/g)].map(match => match[1]),
    displayed: text?.match(/^display_word_id="([a-z-]*)"$/m)?.[1] || '',
  };
}

async function openWords(page) {
  const b = await metrics(page);
  await tap(page, b.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await section(page, 'words');
}

async function section(page, id) {
  const b = await metrics(page);
  const fraction = { room: 0.16, words: 0.5, medals: 0.83 }[id];
  await tap(page, 16 + (b.width - 104) * fraction, 52);
  await expect(page.locator('#game-status')).toContainText(id === 'words' ? 'Words.' : id === 'medals' ? 'Medals.' : 'Choose toys and places for Pip.');
  await rendered(page);
}

async function pictureTap(page) {
  const b = await metrics(page);
  const top = 252 + (b.height >= 520 ? 28 : 0);
  const width = b.width - 24, height = b.height - top - 12;
  const wide = width >= 420 && width >= height * 1.3;
  let x, y;
  if (wide) {
    const content = Math.min(width, 900);
    const cardWidth = Math.floor((content - 12) * 0.48);
    x = 12 + (width - content) / 2 + cardWidth / 2;
    y = top + 32 + (height - 32) / 2;
  } else {
    const cardHeight = Math.max(88, Math.min(height - 192, 420));
    x = b.width / 2;
    y = top + 32 + Math.max(0, (height - 32 - cardHeight - 160) / 2) + cardHeight / 2;
  }
  await tap(page, x, y);
}

test('real picture taps pronounce and correct Match targets persist once', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const next = lessonPoint(await metrics(page), 'next');
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\./);
  const before = await page.locator('#game-status').textContent();
  const word = before.match(/^Learn: ([a-z]+)/)[1];
  await pictureTap(page);
  const canHear = await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext));
  await expect(page.locator('#game-status')).toHaveText(canHear ? `${word}. Look at the picture and say the word.` : before);
  expect((await record(page)).ids).toEqual([]);
  await chooseMode(page, 1);
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
  for (const index of [pair.Word, pair.Picture]) {
    const p = boardPoint(b, index);
    await tap(page, p.x, p.y);
  }
  await expect(page.locator('#game-status')).toContainText('Great match!');
  expect((await record(page)).ids).toEqual([id]);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('new-word-sticker.png'), scale: 'css' });
  await openWords(page);
  await expect(page.locator('#game-status')).toContainText('1 of 140 stickers collected.');
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect((await record(page)).ids).toEqual([id]);
  expect(errors).toEqual([]);
});

test('word album displays a saved sticker with Pip and keeps topic navigation usable', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.addInitScript(({ key }) => {
    if (!localStorage.getItem(key)) localStorage.setItem(key, '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite=""\n\n[stickers]\nword_ids=["cat", "apple", "rocket", "bell"]\ndisplay_word_id=""\n');
  }, { key: KEY });
  const errors = await openGame(page);
  await openWords(page);
  await expect(page.locator('#game-status')).toContainText('4 of 140 stickers collected.');
  await page.screenshot({ path: testInfo.outputPath('words-320.png'), scale: 'css' });
  const canHear = await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext));
  // Starting at the Words tab, traverse the visible native controls to Display.
  for (let i = 0; i < (canHear ? 6 : 5); i++) await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect.poll(async () => (await record(page)).displayed).toBe('cat');
  await section(page, 'room');
  await page.screenshot({ path: testInfo.outputPath('pip-word-sticker-320.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect((await record(page)).displayed).toBe('cat');
  await openWords(page);
  // Header->Medals->Back->Previous->Next. Enter turns the actual topic.
  for (let i = 0; i < 4; i++) await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Picnic time. Topic 2 of 12.');
  await page.screenshot({ path: testInfo.outputPath('picnic-word-stickers.png'), scale: 'css' });
  expect((await record(page)).ids).toEqual(['cat', 'apple', 'rocket', 'bell']);
  expect(errors).toEqual([]);
});
