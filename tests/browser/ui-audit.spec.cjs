const { test, expect } = require('@playwright/test');
const { openGame, openRewards, metrics, tap, boardPoint, growthView,
  activateGrowthControl, activateLibraryControl, openModeMenu, THEME_NAMES } = require('./game-ui.cjs');
const learningThemes = require('../../data/professional/themes.json').profiles;

test('the growth notebook and automatic career previews preserve the current game', async ({ page }, info) => {
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
  expect((await metrics(page)).library.controls.filter(control => control.visible && THEME_NAMES.includes(control.name))).toEqual([]);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'ProfessionalPath');
  await activateLibraryControl(page, 'Career_retail');
  expect((await metrics(page)).library.learning).toMatchObject({ screen: 'modules', course_id: 'retail' });
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(learningThemes.find(profile => profile.id === 'professional_retail').palette.accent.toLowerCase());
  expect((await metrics(page)).library.visible).toBe(true);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  expect((await metrics(page)).library.current).toBe('match');
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(learningThemes.find(profile => profile.id === 'growth_garden').palette.accent.toLowerCase());
  expect(await page.evaluate(keys => keys.map(key => localStorage.getItem(key)), keys)).toEqual(saved);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  expect(errors).toEqual([]);
});
