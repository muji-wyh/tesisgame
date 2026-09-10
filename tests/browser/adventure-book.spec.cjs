const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseTheme, rendered, openGame, lessonPoint } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const learningStatus = /^Learn: ([a-z]+)\. Look, read, and press Hear\.$/;
const ANIMALS = 'cat dog fish duck cow pig hen sheep horse goat rabbit mouse bear lion tiger monkey panda zebra fox owl frog turtle bee ant'.split(' ');
const PICNIC = 'apple banana orange pear grape cherry melon carrot tomato corn peas egg bread cake cookie cheese milk water juice rice'.split(' ');

async function roomRecord(page) {
  return page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
}

function visits(record) {
  const line = record.match(/^recent_topic_ids=(.*)$/m)?.[1] || '';
  return [...line.matchAll(/"([^"]+)"/g)].map(match => match[1]);
}

async function openBook(page) {
  const bounds = await metrics(page);
  await tap(page, bounds.width - 142, 48);
  await expect(page.locator('#game-status')).toContainText("Pip's adventures.");
  await rendered(page);
}

async function chooseFirstRowPlace(page, index, name) {
  const bounds = await metrics(page);
  const width = bounds.width - 32;
  const columns = width >= 840 ? 4 : width >= 560 ? 3 : 2;
  const cardWidth = (width - (columns - 1) * 8) / columns;
  // The first row starts below the introduction, count, and Surprise me.
  await tap(page, 16 + index * (cardWidth + 8) + cardWidth / 2, 345);
  await expect(page.locator('#game-status')).toContainText(`${name}. Learn five words.`);
}

async function lessonTap(page, control) {
  const point = lessonPoint(await metrics(page), control);
  await tap(page, point.x, point.y);
  await rendered(page);
}

async function learnWords(page) {
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(learningStatus);
  await lessonTap(page, 'previous');
  const words = [];
  for (let index = 0; index < 5; index++) {
    if (index) await lessonTap(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(learningStatus);
    words.push((await page.locator('#game-status').textContent()).match(learningStatus)[1]);
  }
  expect(new Set(words).size).toBe(5);
  return words;
}

test('pictured places start their five-word lesson and Back preserves the current word', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await openBook(page);
  await page.screenshot({ path: testInfo.outputPath('adventure-book-open.png'), scale: 'css' });
  await chooseFirstRowPlace(page, 0, 'Animal friends');
  const animals = await learnWords(page);
  expect(animals.every(word => ANIMALS.includes(word))).toBe(true);
  await lessonTap(page, 'previous');
  await expect(page.locator('#game-status')).toHaveText(`Learn: ${animals[3]}. Look, read, and press Hear.`);
  await openBook(page);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(`Learn: ${animals[4]}. Look, read, and press Hear.`);
  await openBook(page);
  await chooseFirstRowPlace(page, 1, 'Picnic time');
  const picnic = await learnWords(page);
  expect(picnic.every(word => PICNIC.includes(word))).toBe(true);
  expect(picnic.some(word => animals.includes(word))).toBe(false);
  expect(visits(await roomRecord(page)).slice(0, 2)).toEqual(['picnic-time', 'animal-friends']);
  await page.screenshot({ path: testInfo.outputPath('adventure-picnic-lesson.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('visit retry and reload preserve the preferred world and existing room choices', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    if (localStorage.getItem('wordBuddies.playroom') === null) {
      localStorage.setItem('wordBuddies.playroom', '[playroom]\nversion=1\ntoy="toy-spring"\nbackdrop="backdrop-spring"\nfavorite="spring-1"\n');
      localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1":3,"spring-2":3,"spring-3":3}\n');
    }
  });
  const errors = await openGame(page);
  const medals = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await chooseTheme(page, 5);
  await openBook(page);
  await chooseFirstRowPlace(page, 0, 'Animal friends');
  const saved = await roomRecord(page);
  expect(saved).toContain('preferred_theme_id="space"');
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Blocked for visit retry test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreJourneySave = () => { Storage.prototype.setItem = save; };
  });
  await openBook(page);
  await chooseFirstRowPlace(page, 1, 'Picnic time');
  expect(await roomRecord(page)).toBe(saved);
  await openBook(page);
  await expect(page.locator('#game-status')).toContainText('This visit could not be remembered. Choose Retry.');
  await page.screenshot({ path: testInfo.outputPath('adventure-visit-retry.png'), scale: 'css' });
  await page.evaluate(() => window.restoreJourneySave());
  // Back is focused when the book opens; Retry follows Surprise me.
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).not.toContainText('could not be remembered');
  const recovered = await roomRecord(page);
  expect(visits(recovered).slice(0, 2)).toEqual(['picnic-time', 'animal-friends']);
  for (const field of ['toy="toy-spring"', 'backdrop="backdrop-spring"', 'favorite="spring-1"', 'preferred_theme_id="space"']) {
    expect(recovered).toContain(field);
  }
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  const restored = await roomRecord(page);
  expect(visits(restored)).toEqual(expect.arrayContaining(['animal-friends', 'picnic-time']));
  for (const field of ['toy="toy-spring"', 'backdrop="backdrop-spring"', 'favorite="spring-1"', 'preferred_theme_id="space"']) {
    expect(restored).toContain(field);
  }
  await page.screenshot({ path: testInfo.outputPath('adventure-restored-space-world.png'), scale: 'css' });
  await openBook(page);
  await expect(page.locator('#game-status')).toContainText(`${visits(restored).length} of 12 places visited.`);
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(medals);
  expect(errors).toEqual([]);
});

test('a phone card swipe cannot select a place and keyboard focus reaches the last card', async ({ page, browserName }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  const errors = await openGame(page);
  await openBook(page);
  const saved = await roomRecord(page);
  const bounds = await metrics(page);
  const x = bounds.x + 126 * bounds.scale;
  const start = bounds.y + 350 * bounds.scale;
  const end = bounds.y + 220 * bounds.scale;
  if (browserName === 'chromium') {
    const client = await page.context().newCDPSession(page);
    try {
      await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, x, y: start }] });
      for (let step = 1; step <= 8; step++) {
        await client.send('Input.dispatchTouchEvent', {
          type: 'touchMove', touchPoints: [{ id: 1, x, y: start + (end - start) * step / 8 }]
        });
        await rendered(page);
      }
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } finally {
      await client.detach();
    }
  } else {
    await page.mouse.move(x, start);
    await page.mouse.down();
    await page.mouse.move(x, end, { steps: 8 });
    await page.mouse.up();
  }
  await rendered(page);
  await expect(page.locator('#game-status')).toContainText("Pip's adventures.");
  expect(await roomRecord(page)).toBe(saved);
  await page.screenshot({ path: testInfo.outputPath('adventure-card-swipe.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText("Pip's adventures.");
  // Back wraps to Music makers; the host must scroll its focused card into view.
  await page.keyboard.press('Shift+Tab');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('adventure-last-card-focus.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Music makers. Learn five words.');
  expect(visits(await roomRecord(page))[0]).toBe('music-makers');
  expect(errors).toEqual([]);
});
