const { test, expect } = require('@playwright/test');
const { openGame, activateLibraryControl, chooseMode, seedPipLevel, rendered } = require('./game-ui.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));

test('normal Web Jelly play publishes lean status and retains native map, pause and touch behavior', async ({ page }) => {
  test.setTimeout(180000);
  await seedPipLevel(page, 3);
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference', jellyDiagnostics: false });
  expect(await page.evaluate(() => wordBuddiesHost.jellyDiagnosticsEnabled())).toBe(false);
  await activateLibraryControl(page, 'Mode_word_jelly');
  await expect.poll(async () => (await jelly(page)).campaign_map?.visible).toBe(true);
  await rendered(page);
  // The native map focuses its first available stage after it opens.
  await page.keyboard.press('Enter');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && !state.paused && !state.campaign_map.visible;
  }, { timeout: 60000 }).toBe(true);
  const state = await jelly(page);
  expect(state).toMatchObject({ schema: 1, diagnostics: false, mode: 'word_jelly', pause: { active: false }, error: '' });
  for (const field of ['cells', 'tiles', 'presentation_work', 'practice', 'powerup'])
    expect(state).not.toHaveProperty(field);
  expect(JSON.stringify(state).length).toBeLessThan(2048);
  expect(await page.locator('#canvas').evaluate(canvas => canvas.style.touchAction)).toBe('pinch-zoom');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(true);
  await expect(page.locator('#game-status')).toContainText('Paused');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(false);
  expect((await jelly(page)).error).toBe('');
  expect(errors).toEqual([]);
});

test('explicit Web Jelly diagnostics preserve complete model and presentation snapshots', async ({ page }) => {
  test.setTimeout(180000);
  await seedPipLevel(page, 3);
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference' });
  expect(await page.evaluate(() => wordBuddiesHost.jellyDiagnosticsEnabled())).toBe(true);
  await chooseMode(page, 'word_jelly', { stage: 1 });
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && !state.paused && state.tiles?.length > 0;
  }, { timeout: 60000 }).toBe(true);
  const state = await jelly(page);
  expect(state.cells.length).toBeGreaterThan(0);
  expect(state.tiles.length).toBeGreaterThan(0);
  expect(state).toHaveProperty('presentation_work');
  expect(state).toHaveProperty('practice');
  expect(state.tiles[0]).toHaveProperty('presentation');
  expect(errors).toEqual([]);
});
