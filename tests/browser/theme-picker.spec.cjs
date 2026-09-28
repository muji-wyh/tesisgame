const { test, expect } = require('@playwright/test');
const { writeFile } = require('node:fs/promises');
const { openGame, metrics, tap, boardPoint, openRewards,
  worldControl, collectionBounds, rendered, enterGame, roomLayout,
  THEME_IDS, THEME_COLORS } = require('./game-ui.cjs');

function pixelDifference(left, right) {
  return left.reduce((total, channel, index) => total + Math.abs(channel - right[index]), 0) / left.length;
}

async function expectRoomInterior(page, testInfo, index, references, suffix = '') {
  const bounds = await metrics(page), room = roomLayout(bounds);
  // The wall and window contain real theme artwork without moving actors or labels.
  // Compare rendered images so shading, floorboards and daylight need not be flat RGB.
  const patch = { x: bounds.x + (room.x + room.width * 0.28) * bounds.scale,
    y: bounds.y + (room.top + room.homeHeight * 0.16) * bounds.scale,
    width: room.width * 0.54 * bounds.scale, height: room.homeHeight * 0.27 * bounds.scale };
  let screenshot, pixels;
  const capture = async () => {
    screenshot = await page.screenshot({ scale: 'css' });
    pixels = await page.evaluate(async ({ png, patch }) => {
      const image = new Image();
      image.src = 'data:image/png;base64,' + png;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = 64; canvas.height = 32;
      const context = canvas.getContext('2d');
      context.drawImage(image, patch.x, patch.y, patch.width, patch.height, 0, 0, 64, 32);
      return [...context.getImageData(0, 0, 64, 32).data].filter((_, channel) => channel % 4 !== 3);
    }, { png: screenshot.toString('base64'), patch });
  };
  await rendered(page);
  const reference = references.get(index);
  if (reference) {
    await expect.poll(async () => {
      await capture();
      return pixelDifference(pixels, reference);
    }, { message: `The ${THEME_IDS[index]} room artwork must survive a theme round-trip and reload.` }).toBeLessThanOrEqual(1);
  } else if (references.size) {
    await expect.poll(async () => {
      await capture();
      return Math.min(...[...references.values()].map(other => pixelDifference(pixels, other)));
    }, { message: `The actual ${THEME_IDS[index]} room artwork must differ from every other world, despite the legacy Spring backdrop.` }).toBeGreaterThan(2);
  } else {
    await capture();
  }
  references.set(index, pixels);
  await writeFile(testInfo.outputPath(`legacy-room-${THEME_IDS[index]}${suffix}.png`), screenshot);
}

test('the room follows every selected world despite an earned legacy backdrop', async ({ page }, testInfo) => {
  test.setTimeout(120000);
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
  const interiors = new Map();
  await expectRoomInterior(page, testInfo, 2, interiors, '-startup');
  for (const [index, id] of THEME_IDS.entries()) {
    const rect = await worldControl(page, index);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    await expectRoomInterior(page, testInfo, index, interiors);
    const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'));
    expect(saved).toContain(`preferred_theme_id="${id}"`);
    expect(saved.split('[journey]')[0]).toBe(original.room);
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(original.medals);
  }
  await page.reload();
  await enterGame(page);
  await openRewards(page);
  await expectRoomInterior(page, testInfo, 7, interiors, '-reload');
  expect(errors).toEqual([]);
});

test('larger themes stay on the current page and retry saving in place', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  await openRewards(page);
  for (const [index, color] of [[4, '#e7f8fa'], [1, '#fff4df']]) {
    const bounds = await metrics(page), rect = await worldControl(page, index);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(52);
    expect(rect.y).toBe(collectionBounds(bounds).themeTop);
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
  let rect = await worldControl(page, 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText('Changes not saved.');
  await page.screenshot({ path: testInfo.outputPath('theme-save-notice.png'), scale: 'css' });
  await page.evaluate(() => window.restoreThemeSaving());
  rect = await worldControl(page, 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  await expect(page.locator('#game-status')).not.toContainText('Changes not saved.');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'))).toContain('preferred_theme_id="space"');
  await page.setViewportSize({ width: 320, height: 568 });
  await rendered(page);
  const bounds = await metrics(page);
  for (let index = 0; index < 8; index++) {
    rect = await worldControl(page, index);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(52);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(320);
  }
  await page.screenshot({ path: testInfo.outputPath('larger-themes-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
