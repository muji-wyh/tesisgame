const { test, expect } = require('@playwright/test');
const { writeFile } = require('node:fs/promises');
const { openGame, metrics, tap, boardPoint, openRewards,
  worldIconRect, collectionBounds, rendered, enterGame, roomLayout,
  THEME_IDS, THEME_COLORS } = require('./game-ui.cjs');

async function expectRoomFloor(page, testInfo, index, suffix = '') {
  const bounds = await metrics(page), room = roomLayout(bounds);
  // This clear floor patch is below the wall and above the first row of toys.
  const point = { x: Math.round(bounds.x + (room.x + room.width - 12) * bounds.scale),
    y: Math.round(bounds.y + (room.top + 186) * bounds.scale) };
  const expected = THEME_COLORS[index].slice(1).match(/../g).map(value => parseInt(value, 16));
  let screenshot;
  await expect.poll(async () => {
    screenshot = await page.screenshot({ scale: 'css' });
    const actual = await page.evaluate(async ({ png, point }) => {
      const image = new Image();
      image.src = 'data:image/png;base64,' + png;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return [...context.getImageData(point.x, point.y, 1, 1).data].slice(0, 3);
    }, { png: screenshot.toString('base64'), point });
    return Math.max(...actual.map((value, channel) => Math.abs(value - expected[channel])));
  }, { message: `Pip's actual room floor must use ${THEME_IDS[index]}, even with an earned legacy Spring backdrop.` }).toBeLessThanOrEqual(2);
  await writeFile(testInfo.outputPath(`legacy-room-${THEME_IDS[index]}${suffix}.png`), screenshot);
}

test('the room follows every selected world despite an earned legacy backdrop', async ({ page }, testInfo) => {
  const counts = { 'spring-1': 3, 'summer-1': 3, 'autumn-1': 3, 'spring-3': 3 };
  await page.addInitScript(counts => {
    if (localStorage.getItem('wordBuddies.playroom') !== null) return;
    localStorage.setItem('wordBuddies.medalProgress', `[medals]\nversion=1\ncounts=${JSON.stringify(counts)}\n`);
    localStorage.setItem('wordBuddies.playroom', '[playroom]\nversion=1\ntoy="toy-autumn"\nbackdrop="backdrop-spring"\nfavorite="spring-1"\n\n[journey]\npreferred_theme_id="autumn"\ngoal_item_id=""\nrecent_topic_ids=[]\n');
  }, counts);
  const errors = await openGame(page);
  await openRewards(page);
  const original = await page.evaluate(() => ({
    room: localStorage.getItem('wordBuddies.playroom').split('[journey]')[0],
    medals: localStorage.getItem('wordBuddies.medalProgress')
  }));
  await expectRoomFloor(page, testInfo, 2, '-startup');
  for (const [index, id] of THEME_IDS.entries()) {
    const rect = worldIconRect(await metrics(page), index);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    await expectRoomFloor(page, testInfo, index);
    const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'));
    expect(saved).toContain(`preferred_theme_id="${id}"`);
    expect(saved.split('[journey]')[0]).toBe(original.room);
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(original.medals);
  }
  await page.reload();
  await enterGame(page);
  await openRewards(page);
  await expectRoomFloor(page, testInfo, 7, '-reload');
  expect(errors).toEqual([]);
});

test('larger themes stay on the current page and retry saving in place', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  await openRewards(page);
  for (const [index, color] of [[4, '#e7f8fa'], [1, '#fff4df']]) {
    const bounds = await metrics(page), rect = worldIconRect(bounds, index);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(52);
    if (collectionBounds(bounds).inlineWorlds) {
      expect((rect.y + rect.height / 2) * bounds.scale).toBeLessThan(44);
    }
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', color);
    await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
    await page.screenshot({ path: testInfo.outputPath(`larger-themes-${index}.png`), scale: 'css' });
  }
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Theme preference blocked for test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreThemeSaving = () => { Storage.prototype.setItem = save; };
  });
  let rect = worldIconRect(await metrics(page), 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText('Changes not saved.');
  await page.screenshot({ path: testInfo.outputPath('theme-save-notice.png'), scale: 'css' });
  await page.evaluate(() => window.restoreThemeSaving());
  rect = worldIconRect(await metrics(page), 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  await expect(page.locator('#game-status')).not.toContainText('Changes not saved.');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'))).toContain('preferred_theme_id="space"');
  await page.setViewportSize({ width: 320, height: 568 });
  await rendered(page);
  const bounds = await metrics(page);
  for (let index = 0; index < 8; index++) {
    rect = worldIconRect(bounds, index);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(52);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(320);
  }
  await page.screenshot({ path: testInfo.outputPath('larger-themes-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
