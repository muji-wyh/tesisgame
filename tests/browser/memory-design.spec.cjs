const { test, expect } = require('@playwright/test');
const { openGame, chooseTheme, metrics, memoryPoint, tap, rendered, withMemoryPeek,
  visibleColorCount } = require('./game-ui.cjs');

async function discover(page) {
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    cards.push(await page.locator('#selection-status').textContent());
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

test('illustrated Memory backs retain their identities through themes and Peek', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  const errors = await openGame(page, { mode: 'memory' });
  const original = await discover(page);
  for (const [index, theme] of ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].entries()) {
    await chooseTheme(page, index);
    await page.mouse.move(0, 0);
    await rendered(page);
    const png = await page.screenshot({ path: testInfo.outputPath(`memory-deck-${theme}.png`), scale: 'css' });
    expect(await visibleColorCount(page, png)).toBeGreaterThan(20);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  await withMemoryPeek(page, async () => {
    await page.screenshot({ path: testInfo.outputPath('memory-deck-revealed.png'), scale: 'css' });
  });
  await expect(page.locator('#game-status')).toContainText('Find a pair.');
  expect(await discover(page)).toEqual(original);
  expect(errors).toEqual([]);
});
