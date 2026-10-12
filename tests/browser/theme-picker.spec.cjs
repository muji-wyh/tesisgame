const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, openRewards, worldControl, openModeMenu, chooseMode,
  activateGrowthControl, growthView, enterGame, THEME_IDS, THEME_NAMES, THEME_COLORS } = require('./game-ui.cjs');
const KEY = 'pipAndWords.presentation.v1';

test('Home owns all eight themes and preserves the selected card when continuing', async ({ page }, info) => {
  const errors = await openGame(page);
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const growth = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
  await openRewards(page);
  expect((await growthView(page)).controls.filter(control => control.visible &&
    [...THEME_NAMES, 'NextWorld', 'WorldChoices'].includes(control.name))).toEqual([]);
  await activateGrowthControl(page, 'GrowthBack');
  await openModeMenu(page);
  for (const [index, id] of THEME_IDS.entries()) {
    const rect = await worldControl(page, index);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    expect((await metrics(page)).library.visible).toBe(true);
    expect((await metrics(page)).library.theme_id).toBe(id);
    expect((await growthView(page)).visible).toBe(false);
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe(id);
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
  }
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'))).toBe(growth);
  await page.screenshot({ path: info.outputPath('home-candy-theme.png'), scale: 'css' });
  await chooseMode(page, 'match');
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[7]);
  await page.reload(); await enterGame(page);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[7]);
  await page.screenshot({ path: info.outputPath('persisted-candy-world.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('compact Home themes remain reachable and retry a failed preference save', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { home: true });
  expect((await metrics(page)).library.current, 'Theme selection is available before choosing the first game').toBe('');
  await page.evaluate(key => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (name === key) throw new DOMException('Theme preference blocked for test', 'QuotaExceededError');
      return save.call(this, name, value);
    };
    window.restoreThemeSaving = () => { Storage.prototype.setItem = save; };
  }, KEY);
  let rect = await worldControl(page, 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText('not saved');
  await expect.poll(async () => (await metrics(page)).library.theme_save_failed).toBe(true);
  await page.evaluate(() => window.restoreThemeSaving());
  rect = await worldControl(page, 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe('space');
  await expect.poll(async () => (await metrics(page)).library.theme_save_failed).toBe(false);
  for (let index = 0; index < 8; index++) {
    rect = await worldControl(page, index);
    const bounds = await metrics(page);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(44);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(321);
  }
  await page.screenshot({ path: info.outputPath('home-theme-choices-320.png'), scale: 'css' });
  await chooseMode(page, 'memory');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[5]);
  expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe('space');
  expect(errors).toEqual([]);
});
