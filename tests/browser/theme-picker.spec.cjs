const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, openRewards, worldControl,
  growthView, rendered, enterGame, THEME_IDS, THEME_COLORS } = require('./game-ui.cjs');
const KEY = 'pipAndWords.presentation.v1';

test('all eight worlds persist independently of growth and preserve the selected card', async ({ page }, info) => {
  const errors = await openGame(page);
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const growth = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
  await openRewards(page);
  for (const [index, id] of THEME_IDS.entries()) {
    const rect = await worldControl(page, index);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    expect((await growthView(page)).visible).toBe(true);
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe(id);
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
  }
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'))).toBe(growth);
  await page.reload(); await enterGame(page);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[7]);
  await page.screenshot({ path: info.outputPath('persisted-candy-world.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('compact world choices remain reachable and retry a failed preference save', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  await openRewards(page);
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
  await page.evaluate(() => window.restoreThemeSaving());
  rect = await worldControl(page, 5);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe('space');
  for (let index = 0; index < 8; index++) {
    rect = await worldControl(page, index);
    const bounds = await metrics(page);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(44);
    expect((rect.x + rect.width) * bounds.scale).toBeLessThanOrEqual(321);
  }
  await page.screenshot({ path: info.outputPath('growth-world-choices-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
