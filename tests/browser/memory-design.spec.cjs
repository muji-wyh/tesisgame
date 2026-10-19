const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, activateLibraryControl, metrics, memoryPoint, tap, rendered, withMemoryPeek,
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

test('illustrated Memory backs retain their identities through career browsing and Peek', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  const errors = await openGame(page, { mode: 'memory' });
  const original = await discover(page);
  for (const course of ['caregiving', 'retail', 'food_service']) {
    await openModeMenu(page);
    await activateLibraryControl(page, 'ChangeLearningPath');
    await activateLibraryControl(page, 'ProfessionalPath');
    await activateLibraryControl(page, `Career_${course}`);
    expect((await metrics(page)).library.learning).toMatchObject({ screen: 'modules', course_id: course });
    await activateLibraryControl(page, 'ContinueCurrentRound');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
    expect((await metrics(page)).library.current).toBe('memory');
    await page.mouse.move(0, 0);
    await rendered(page);
    const png = await page.screenshot({ path: testInfo.outputPath(`memory-deck-after-${course}.png`), scale: 'css' });
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
