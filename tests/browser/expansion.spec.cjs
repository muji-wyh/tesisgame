const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, openGame } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';

async function roomRecord(page) {
  return page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
}

async function openRoom(page) {
  const bounds = await metrics(page);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await rendered(page);
}

async function leavePreview(page) {
  // The gift goal starts focused; Pip and Back follow it while the toy is locked.
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
}

async function seedGifts(page, { favorite = '' } = {}) {
  const counts = {};
  for (const theme of ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space']) {
    for (let number = 1; number <= 3; number++) counts[`${theme}-${number}`] = 3;
  }
  const progress = `[medals]\nversion=1\ncounts=${JSON.stringify(counts)}\n`;
  await page.addInitScript(({ key, progress, favorite }) => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key, progress);
    if (favorite) localStorage.setItem('wordBuddies.favoriteReward', favorite);
  }, { key: MEDAL_KEY, progress, favorite });
}

test('the starter toy remains still with reduced motion and locked gifts cannot be equipped', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  const errors = await openGame(page);
  await openRoom(page);
  const saved = await roomRecord(page);
  expect(saved).toContain('toy="toy-ball"');
  await tap(page, 240, 502);
  await expect(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!');
  // Pip's speech marker clears when the pronunciation finishes.
  await page.waitForTimeout(1600);
  await rendered(page);
  const still = await page.screenshot({ path: testInfo.outputPath('room-starter-phone.png'), scale: 'css' });
  await page.waitForTimeout(300);
  expect((await page.screenshot({ scale: 'css' })).equals(still)).toBe(true);
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Complete Blossom');
  await rendered(page);
  const locked = await page.screenshot({ path: testInfo.outputPath('room-locked-toy-phone.png'), scale: 'css' });
  expect(locked.equals(still), 'A locked gift shows its artwork and exact requirement.').toBe(false);
  await leavePreview(page);
  await expect(page.locator('#game-status')).toContainText('ball');
  expect(await roomRecord(page)).toBe(saved);
  await tap(page, 240, 502);
  expect(await roomRecord(page)).toBe(saved);
  await expect(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!');
  await tap(page, 360, 588);
  await tap(page, 360, 660);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('room-locked-backdrop-phone.png'), scale: 'css' });
  await expect(page.locator('#game-status')).toContainText('Complete Bee');
  await leavePreview(page);
  await expect(page.locator('#game-status')).toContainText('ball');
  expect(await roomRecord(page)).toBe(saved);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  expect(errors).toEqual([]);
});

test('earned toy, backdrop, and migrated favorite persist through immediate reload', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await seedGifts(page, { favorite: 'spring-1' });
  const errors = await openGame(page);
  const medals = await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
  await openRoom(page);
  await expect(page.locator('#game-status')).toContainText('18 of 36 medals complete.');
  expect(await roomRecord(page)).toContain('favorite="spring-1"');
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Water the flower');
  expect(await roomRecord(page)).toContain('toy="toy-spring"');
  await tap(page, 360, 588);
  await tap(page, 360, 660);
  const saved = await roomRecord(page);
  expect(saved).toContain('backdrop="backdrop-spring"');
  expect(saved).toContain('favorite="spring-1"');
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await openRoom(page);
  // A new startup lesson can add a visit; the selected room must stay identical.
  expect((await roomRecord(page)).split('[journey]')[0]).toBe(saved.split('[journey]')[0]);
  await tap(page, 240, 502);
  await expect(page.locator('#game-status')).toHaveText('1/3 · A drink for the flower!');
  await tap(page, 240, 502);
  await expect(page.locator('#game-status')).toHaveText('2/3 · The flower grows taller!');
  await tap(page, 240, 502);
  await expect(page.locator('#game-status')).toHaveText('3/3 · The flower blooms for Pip!');
  await page.waitForTimeout(1600);
  await page.screenshot({ path: testInfo.outputPath('room-saved-flower-phone.png'), scale: 'css' });
  expect(await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});

test('a failed room write preserves the selected toy and succeeds on retry', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await seedGifts(page);
  const errors = await openGame(page);
  await openRoom(page);
  const original = await roomRecord(page);
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Blocked for retry test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restorePlayroomSave = () => { Storage.prototype.setItem = save; };
  });
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Your room could not be saved.');
  expect(await roomRecord(page)).toBe(original);
  await page.screenshot({ path: testInfo.outputPath('room-save-retry.png'), scale: 'css' });
  await page.evaluate(() => window.restorePlayroomSave());
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Water the flower');
  expect(await roomRecord(page)).toContain('toy="toy-spring"');
  expect(errors).toEqual([]);
});

test('a failed initial room read recovers after storage becomes available', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await seedGifts(page);
  await page.addInitScript(() => {
    const read = Storage.prototype.getItem;
    window.blockRoomRead = true;
    Storage.prototype.getItem = function (key) {
      if (key === 'wordBuddies.playroom' && window.blockRoomRead) throw new DOMException('Storage unavailable', 'SecurityError');
      return read.call(this, key);
    };
  });
  const errors = await openGame(page);
  await openRoom(page);
  await page.screenshot({ path: testInfo.outputPath('room-load-retry.png'), scale: 'css' });
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Your room could not be saved.');
  await page.evaluate(() => { window.blockRoomRead = false; });
  await tap(page, 360, 660);
  await expect(page.locator('#game-status')).toContainText('Water the flower');
  expect(await roomRecord(page)).toContain('toy="toy-spring"');
  expect(errors).toEqual([]);
});

test('dragging an owned gift scrolls without equipping it on release', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await seedGifts(page);
  const errors = await openGame(page);
  await openRoom(page);
  const saved = await roomRecord(page);
  const bounds = await metrics(page);
  await page.mouse.move(bounds.x + 360 * bounds.scale, bounds.y + 660 * bounds.scale);
  await page.mouse.down();
  await page.mouse.move(bounds.x + 360 * bounds.scale, bounds.y + 550 * bounds.scale, { steps: 8 });
  await page.mouse.up();
  expect(await roomRecord(page)).toBe(saved);
  await page.screenshot({ path: testInfo.outputPath('room-gift-drag.png'), scale: 'css' });
  await tap(page, 360, 550);
  await expect(page.locator('#game-status')).toContainText('Water the flower');
  expect(await roomRecord(page)).toContain('toy="toy-spring"');
  expect(errors).toEqual([]);
});

test('earned seasonal toys keep their visible noun and distinct outcome', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await seedGifts(page);
  const errors = await openGame(page);
  const medals = await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
  for (const [theme, stages] of [
    ['summer', ['The ball rolls to Pip!', 'Pip rolls the ball back!', 'Pip catches the ball. Hooray!']],
    ['autumn', ['An apple for Pip!', 'Pip nibbles the apple. Crunch!', 'Pip finishes the apple. Just the core!']],
    ['ocean', ['Pip lifts the shell!', 'Pip listens to the shell. Shh!', 'The shell sounds like ocean waves. Whoosh!']],
    ['space', ['The rocket is ready on its launch pad!', 'The rocket glows. Ready to go!', 'The rocket takes off. Whoosh!']]
  ]) {
    await page.evaluate(({ key, theme }) => {
      localStorage.setItem(key, `[playroom]\nversion=1\ntoy="toy-${theme}"\nbackdrop="backdrop-${theme}"\nfavorite=""\n`);
    }, { key: ROOM_KEY, theme });
    await page.reload();
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
    await openRoom(page);
    for (const [index, caption] of stages.entries()) {
      await tap(page, 240, 502);
      await expect(page.locator('#game-status')).toHaveText(`${index + 1}/3 · ${caption}`);
      await page.screenshot({ path: testInfo.outputPath(`room-${theme}-stage-${index + 1}.png`), scale: 'css' });
    }
    await page.waitForTimeout(1600);
    await page.screenshot({ path: testInfo.outputPath(`room-${theme}-outcome.png`), scale: 'css' });
  }
  expect(await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});

test('the room keeps readable gift previews and usable controls on a tablet', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 834, height: 1194 });
  const errors = await openGame(page);
  await openRoom(page);
  await tap(page, 240, 502);
  await expect(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!');
  await tap(page, 360, 660);
  await page.waitForTimeout(1600);
  await page.screenshot({ path: testInfo.outputPath('room-locked-toy-tablet.png'), scale: 'css' });
  expect(await roomRecord(page)).toContain('toy="toy-ball"');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  expect(errors).toEqual([]);
});
