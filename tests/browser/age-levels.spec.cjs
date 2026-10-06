const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const { enterGame, openGame, openRewards, metrics, tap, rendered, ageControl, collectionHeaderRect,
  boardPoint, chooseMode, matchWords, memoryPoint, roomControl, withMemoryPeek,
  collectionBounds, uiScale, observeAudio } = require('./game-ui.cjs');
const { watchAudioRequests, expectRecording } = require('./bundled-audio.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const NAMES = { all: 'All words', '4-6': 'Ages 4-6', '7-9': 'Ages 7-9', '10-plus': 'Ages 10+' };
const COUNTS = { all: 1250, '4-6': 448, '7-9': 412, '10-plus': 390 };
const vocabulary = new Map(words.map(word => [word.id, word]));

async function saved(page) {
  return page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
}

async function age(page, id, input = 'touch') {
  const bounds = await metrics(page), rect = await ageControl(page, id);
  if (input === 'mouse') {
    await page.mouse.click(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
      bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  } else {
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  }
  await rendered(page);
}

async function backFromMore(page) {
  const rect = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await rendered(page);
}

async function expectCatalog(page, id) {
  await expect(page.locator('#game-status')).toContainText(`${NAMES[id]}. ${COUNTS[id]} words.`);
  await expect(page.locator('#game-status')).toContainText("Back returns to Pip's room.");
}

async function returnToRoom(page) {
  await backFromMore(page);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
}

async function matchCards(page) {
  // Board scans do not resize the canvas; reuse its measured geometry.
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y, bounds);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    cards.push(await page.locator('#selection-status').textContent());
    await tap(page, point.x, point.y, bounds);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

async function memoryWords(page) {
  const bounds = await metrics(page), result = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y, bounds);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    result.push((await page.locator('#selection-status').textContent()).match(/: ([a-z]+)\.$/)[1]);
    await tap(page, point.x, point.y, bounds);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return result;
}

test('all age catalogues preserve the current lesson in Match and Memory and apply after reload', async ({ page }, testInfo) => {
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
    await expectCatalog(page, id);
    expect(await saved(page)).toBe(originalSave.replace(/^age_band="all"$/m, `age_band="${id}"`));
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
    await returnToRoom(page);
  }
  const confirmed = await saved(page);
  await age(page, '4-6');
  await expectCatalog(page, '4-6');
  expect(await saved(page)).toBe(confirmed);
  await page.screenshot({ path: testInfo.outputPath('age-word-catalogue.png'), scale: 'css' });
  await returnToRoom(page);
  await backFromMore(page);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await tap(page, first.x, first.y);
  expect(await matchCards(page)).toEqual(before);
  await chooseMode(page, 'memory');
  const remembered = await memoryWords(page);
  expect([...new Set(remembered)].sort()).toEqual(originalWords);
  for (const word of originalWords) expect(remembered.filter(value => value === word)).toHaveLength(2);
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(rewards);
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word');
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
  await expectCatalog(page, '7-9');
  const confirmed = await saved(page);
  await returnToRoom(page);
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
  await expectCatalog(page, '10-plus');
  expect(await saved(page)).toContain('age_band="10-plus"');
  await returnToRoom(page);
  await age(page, 'all', 'mouse');
  await expectCatalog(page, 'all');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Enter');
  await expectCatalog(page, '4-6');
  expect(await saved(page)).toContain('age_band="4-6"');
  await returnToRoom(page);
  await page.setViewportSize({ width: 320, height: 568 });
  await rendered(page);
  for (const id of Object.keys(NAMES)) {
    const bounds = await metrics(page), rect = await ageControl(page, id);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(48);
    expect(rect.height * bounds.scale).toBeGreaterThanOrEqual(48);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(320);
    await age(page, id);
    await expectCatalog(page, id);
    expect(await saved(page)).toContain(`age_band="${id}"`);
    if (id === '10-plus') await page.screenshot({ path: testInfo.outputPath('age-catalogue-320.png'), scale: 'css' });
    await returnToRoom(page);
  }
  await page.screenshot({ path: testInfo.outputPath('age-choices-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a new gift lesson uses advanced vocabulary across Match and Memory', async ({ page }, testInfo) => {
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
  await expectCatalog(page, '10-plus');
  expect(await saved(page)).toContain('age_band="10-plus"');
  await returnToRoom(page);
  await roomControl(page, 'winter');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Winter bell.');
  await roomControl(page, 'goal', { locked: true, item: 'winter' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Music makers. Find 5 word–picture pairs.');
  const lesson = await matchWords(page);
  expect(lesson).toContain('bell');
  expect(lesson.filter(word => word !== 'bell').every(word => vocabulary.get(word).level === 'advanced')).toBe(true);
  expect(lesson.some(word => word.length >= 9)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('advanced-match.png'), scale: 'css' });
  await chooseMode(page, 'memory');
  expect([...new Set(await memoryWords(page))].sort()).toEqual([...lesson].sort());
  await withMemoryPeek(page, async () => {
    await page.screenshot({ path: testInfo.outputPath('advanced-memory.png'), scale: 'css' });
  });
  expect(await saved(page)).toContain('age_band="10-plus"');
  expect(errors).toEqual([]);
});

test('expanded vocabulary pages show new artwork, meanings and bundled pronunciations', async ({ page, browserName }, testInfo) => {
  test.setTimeout(120000);
  await page.setViewportSize({ width: 480, height: 480 });
  const requests = watchAudioRequests(page);
  await observeAudio(page);
  const errors = await openGame(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable, 'Chromium exercises the real word recording').toBe(true);
  await openRewards(page);
  await age(page, '4-6');
  await expectCatalog(page, '4-6');
  const ageSave = await saved(page);
  const ordered = words.filter(word => word.level === 'basic').sort((a, b) => a.text.localeCompare(b.text));
  const first = ordered[0], secondPage = ordered[60];
  expect([first.id, secondPage.id]).toEqual(['above', 'bring']);
  expect([first.part_of_speech, secondPage.part_of_speech]).toEqual(['preposition', 'verb']);
  for (const word of [first, secondPage]) {
    expect(word.image).toMatch(/\.png$/);
    expect(word.meaning.length).toBeGreaterThan(10);
  }

  // These are normal visible canvas controls. Their positions follow the
  // public collection layout, without invoking native methods or test hooks.
  const bounds = await metrics(page), layout = collectionBounds(bounds), scale = uiScale(bounds);
  const inset = Math.ceil(3 / scale), gap = Math.ceil(8 / scale), sectionGap = Math.ceil(6 / scale);
  const columns = Math.floor((layout.width - inset * 2 + gap) / (124 / scale + gap));
  const cardWidth = (layout.width - inset * 2 - (columns - 1) * gap) / columns;
  const firstPoint = {
    x: layout.x + inset + cardWidth / 2,
    y: layout.padding + layout.headerHeight + layout.gap + Math.ceil(30 / scale)
      + sectionGap + Math.ceil(34 / scale) + sectionGap + inset + Math.ceil(126 / scale) / 2
  };
  const nextPoint = { x: layout.x + layout.width - 40 / scale,
    y: bounds.height - layout.padding - 24 / scale };
  async function pronounce(word) {
    const from = await page.evaluate(() => window.audioObservation.playbacks.length);
    await tap(page, firstPoint.x, firstPoint.y);
    await expect(page.locator('#game-status')).toHaveText(`${word.text}. ${word.meaning}`);
    await rendered(page);
    return audioAvailable ? expectRecording(page, from, word.audio) : null;
  }

  const firstSound = await pronounce(first);
  await tap(page, nextPoint.x, nextPoint.y);
  await rendered(page);
  const secondSound = await pronounce(secondPage);
  const screenshot = testInfo.outputPath('expanded-vocabulary-page-two-480.png');
  await page.screenshot({ path: screenshot, scale: 'css' });
  await testInfo.attach('New verb and adjective artwork with a visible meaning', { path: screenshot, contentType: 'image/png' });

  // Focus Next with a cancelled mouse press, then reach Previous by keyboard.
  await page.mouse.move(bounds.x + nextPoint.x * bounds.scale, bounds.y + nextPoint.y * bounds.scale);
  await page.mouse.down();
  await page.mouse.move(bounds.x + bounds.width * bounds.scale / 2,
    bounds.y + nextPoint.y * bounds.scale);
  await page.mouse.up();
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Enter');
  await rendered(page);
  await pronounce(first);
  expect(await saved(page), 'Browsing pages and pronunciations does not alter saved progress').toBe(ageSave);
  expect(requests, 'New pronunciation recordings remain inside the game pack').toEqual([]);
  expect(errors).toEqual([]);
  await testInfo.attach('expanded-vocabulary-playback.json', {
    body: JSON.stringify({ viewport: [480, 480], words: [first.id, secondPage.id], firstSound, secondSound }),
    contentType: 'application/json'
  });
});
