const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, openRewards, openModeMenu,
  activateGrowthControl, activateLibraryControl, libraryControl, growthView, enterGame, THEME_NAMES } = require('./game-ui.cjs');
const themes = require('../../data/professional/themes.json').profiles;
const KEY = 'pipAndWords.presentation.v1';

async function expectPalette(page, id) {
  const profile = themes.find(item => item.id === id);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', profile.palette.background.toLowerCase());
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(profile.palette.accent.toLowerCase());
}

test('Home previews automatic career themes and Continue preserves the selected Growth card', async ({ page }, info) => {
  test.setTimeout(150000);
  await page.addInitScript(key => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key, JSON.stringify({ muted: false, preferred_theme: 'candy' }));
    document.addEventListener('DOMContentLoaded', () => {
      window.initialHomeTheme = { theme: wordBuddiesHost.loadingTheme(),
        saved: JSON.parse(localStorage.getItem(key) || '{}').preferred_theme };
    });
  }, KEY);
  const errors = await openGame(page);
  await expectPalette(page, 'growth_garden');
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const growth = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
  await openRewards(page);
  expect((await growthView(page)).controls.filter(control => control.visible &&
    [...THEME_NAMES, 'NextWorld', 'WorldChoices'].includes(control.name))).toEqual([]);
  await activateGrowthControl(page, 'GrowthBack');
  await openModeMenu(page);
  expect((await metrics(page)).library.controls.filter(control => control.visible && THEME_NAMES.includes(control.name))).toEqual([]);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'ProfessionalPath');
  for (const id of ['caregiving', 'retail', 'food_service']) {
    await activateLibraryControl(page, `Career_${id}`);
    await expectPalette(page, `professional_${id}`);
    expect((await metrics(page)).library.learning).toMatchObject({ screen: 'modules', course_id: id });
    expect((await metrics(page)).library.visible).toBe(true);
    expect((await growthView(page)).visible).toBe(false);
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe('candy');
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
    await page.screenshot({ path: info.outputPath(`home-${id}-automatic-theme.png`), scale: 'css' });
    await activateLibraryControl(page, 'ChangeCareer');
  }
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'))).toBe(growth);
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await expectPalette(page, 'growth_garden');
  await page.reload();
  expect(await page.evaluate(() => initialHomeTheme)).toEqual({ theme: 'spring', saved: 'candy' });
  expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)).preferred_theme, KEY)).toBe('candy');
  await expect(page.locator('#loading-themes')).toBeHidden();
  await enterGame(page);
  await expectPalette(page, 'growth_garden');
  await page.screenshot({ path: info.outputPath('automatic-growth-after-reload.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('compact Home exposes storage recovery and remembers Growth after a successful retry', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.addInitScript(() => {
    if (sessionStorage.getItem('learningStorageRecovered')) return;
    const open = IDBFactory.prototype.open;
    IDBFactory.prototype.open = function (name, ...arguments_) {
      if (name === 'growWithPip.professional.v1') throw new DOMException('Professional storage is blocked for recovery test', 'SecurityError');
      return open.call(this, name, ...arguments_);
    };
    window.restoreLearningStorage = () => {
      IDBFactory.prototype.open = open;
      sessionStorage.setItem('learningStorageRecovered', 'true');
    };
  });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.learning.retry).toBe(true);
  expect((await metrics(page)).library.learning.status).toContain('storage');
  expect((await metrics(page)).library.current, 'Recovery is available before choosing the first game').toBe('');
  const retry = await libraryControl(page, 'RetryLearningPath'), bounds = await metrics(page);
  expect(retry.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43);
  expect(retry.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43);
  await page.screenshot({ path: info.outputPath('learning-storage-retry-320.png'), scale: 'css' });
  await page.evaluate(() => window.restoreLearningStorage());
  await activateLibraryControl(page, 'RetryLearningPath');
  await expect.poll(async () => {
    const learning = (await metrics(page)).library.learning;
    return !learning.busy && !learning.retry && learning.status === '';
  }).toBe(true);
  for (const name of ['GrowthPath', 'ProfessionalPath']) {
    const control = await libraryControl(page, name), current = await metrics(page);
    expect(control.rect[2] * current.scale).toBeGreaterThanOrEqual(43);
    expect(control.rect[3] * current.scale).toBeGreaterThanOrEqual(43);
    expect((control.rect[0] + control.rect[2]) * current.scale).toBeLessThanOrEqual(321);
  }
  await activateLibraryControl(page, 'GrowthPath');
  await expectPalette(page, 'growth_garden');
  expect((await metrics(page)).library.learning.selection.track).toBe('growth');
  await expect.poll(() => page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('growWithPip.professional.v1');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result, transaction = database.transaction('context', 'readonly');
      const read = transaction.objectStore('context').get('current');
      read.onsuccess = () => resolve(read.result?.track);
      read.onerror = () => reject(read.error);
      transaction.oncomplete = () => database.close();
    };
  })), { message: 'The successful retry permits the Growth context to become durable' }).toBe('growth');
  await page.screenshot({ path: info.outputPath('learning-storage-recovered-320.png'), scale: 'css' });
  await page.reload();
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.learning.selection.track).toBe('growth');
  await expectPalette(page, 'growth_garden');
  expect(errors).toEqual([]);
});
