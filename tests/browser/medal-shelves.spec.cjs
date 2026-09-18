const { test, expect } = require('@playwright/test');
const { openGame, openRewards, chooseRewardSection, metrics, collectionBounds, firstMedalPoint, uiScale, tap, rendered } = require('./game-ui.cjs');

test.use({ viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1.5, hasTouch: true });

test('spacious medal shelves retain mixed progress and compact earlier rewards', async ({ page }, testInfo) => {
  await page.route('**/seed-medals.html', route => route.fulfill({ contentType: 'text/html', body: '<!doctype html><title>Medal fixture</title>' }));
  await page.goto('/seed-medals.html');
  await page.evaluate(async () => {
    localStorage.setItem('wordBuddies.medalProgress',
      '[medals]\nversion=1\ncounts={"spring-1":1,"spring-2":3,"spring-3":3,"spring-4":3,"summer-1":3,"summer-2":2}\n');
    localStorage.setItem('wordBuddies.playroom',
      '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite=""\n\n[journey]\npreferred_theme_id="ocean"\ngoal_item_id="toy-ocean"\nrecent_topic_ids=[]\n');
    await new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs', 21);
      request.onupgradeneeded = () => {
        const store = request.result.createObjectStore('FILE_DATA');
        store.createIndex('timestamp', 'timestamp', { unique: false });
      };
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result, transaction = db.transaction('FILE_DATA', 'readwrite');
        const store = transaction.objectStore('FILE_DATA'), timestamp = new Date();
        for (const path of ['/userfs/godot', '/userfs/godot/app_userdata', '/userfs/godot/app_userdata/Word Buddies']) {
          store.put({ timestamp, mode: 16877 }, path);
        }
        store.put({ timestamp, mode: 33206, contents: new TextEncoder().encode('[rewards]\nids=["spring-7"]\n') },
          '/userfs/godot/app_userdata/Word Buddies/rewards.cfg');
        transaction.oncomplete = () => { db.close(); resolve(); };
        transaction.onerror = () => { db.close(); reject(transaction.error); };
      };
    });
  });
  const errors = await openGame(page, { mode: 'match' });
  await openRewards(page);
  await chooseRewardSection(page, 'medals');
  await expect(page.locator('#game-status')).toContainText('4 of 48 medals complete.');
  await expect(page.locator('#game-status')).toContainText('1 earlier rewards.');
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await page.mouse.move(0, 0);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('spacious-medals.png'), scale: 'css' });
  const bounds = await metrics(page), collection = collectionBounds(bounds), scale = uiScale(bounds);
  const first = firstMedalPoint(bounds);
  await tap(page, first.x, first.y);
  await expect(page.locator('#game-status')).toContainText('Blossom #1');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Medals.');
  const guide = Math.ceil(64 / scale) + collection.gap * 2;
  const legacyY = collection.top + guide + Math.ceil(20 / scale) + Math.ceil(16 / scale)
    + Math.ceil(36 / scale) + Math.ceil(12 / scale) + 128 / scale
    + Math.ceil(12 / scale) + Math.ceil(20 / scale) + Math.ceil(12 / scale) + 28 / scale;
  await tap(page, collection.x + Math.ceil(16 / scale) + 64 / scale, legacyY);
  await expect(page.locator('#game-status')).toContainText('Sprout #7');
  await page.screenshot({ path: testInfo.outputPath('legacy-chip-preview.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Medals.');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
  await page.setViewportSize({ width: 320, height: 680 });
  await rendered(page);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Shift+Tab');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('spacious-medals-phone.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Sprout #7');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
  expect(errors).toEqual([]);
});
