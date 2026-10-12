const { test, expect } = require('@playwright/test');
const { openGame, openRewards, metrics, tap, boardPoint, worldControl, growthView,
  activateGrowthControl, openModeMenu, chooseMode, THEME_NAMES } = require('./game-ui.cjs');

test('the growth notebook preserves the game while theme choices belong to Home', async ({ page }, info) => {
  const errors = await openGame(page);
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const status = await page.locator('#game-status').textContent();
  const keys = ['wordBuddies.medalProgress', 'growWithPip.growth.v1'];
  const saved = await page.evaluate(keys => keys.map(key => localStorage.getItem(key)), keys);
  await openRewards(page);
  expect((await growthView(page)).controls.filter(control => control.visible &&
    [...THEME_NAMES, 'NextWorld'].includes(control.name))).toEqual([]);
  await page.screenshot({ path: info.outputPath('growth-notebook.png'), scale: 'css' });
  await activateGrowthControl(page, 'GrowthBack');
  await expect(page.locator('#game-status')).toHaveText(status);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await openModeMenu(page);
  const world = await worldControl(page, 5);
  await tap(page, world.x + world.width / 2, world.y + world.height / 2);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#f1edfb');
  expect((await metrics(page)).library.visible).toBe(true);
  await chooseMode(page, 'match');
  expect(await page.evaluate(keys => keys.map(key => localStorage.getItem(key)), keys)).toEqual(saved);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  expect(errors).toEqual([]);
});
