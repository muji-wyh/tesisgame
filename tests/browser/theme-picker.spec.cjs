const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, openRewards, chooseRewardSection,
  worldIconRect, collectionBounds, rendered } = require('./game-ui.cjs');

test('larger themes stay on the current page and retry saving in place', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  await openRewards(page);
  for (const [section, index, color] of [['room', 4, '#e7f8fa'], ['medals', 1, '#fff4df']]) {
    await chooseRewardSection(page, section);
    const bounds = await metrics(page), rect = worldIconRect(bounds, index);
    expect(rect.width * bounds.scale).toBeGreaterThanOrEqual(52);
    if (collectionBounds(bounds).inlineWorlds) {
      expect((rect.y + rect.height / 2) * bounds.scale).toBeLessThan(44);
    }
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', color);
    await expect(page.locator('#game-status')).toContainText(section === 'room' ? 'Choose toys for Pip.' : 'Medals.');
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
    await page.screenshot({ path: testInfo.outputPath(`larger-themes-${section}.png`), scale: 'css' });
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
  await expect(page.locator('#game-status')).toContainText('Medals.');
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
