const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');
const { enterGame, metrics, activateLibraryControl } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');
const growthTheme = require('../../data/professional/themes.json').profiles.find(profile => profile.id === 'growth_garden');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);
const roomSave = '[playroom]\nversion=1\ntoy="toy-autumn"\nbackdrop="backdrop-spring"\nfavorite="spring-1"\n\n'
  + '[journey]\nrecent_topic_ids=[]\npreferred_theme_id="autumn"\ngoal_item_id="toy-space"\n\n'
  + '[stickers]\nword_ids=["apple"]\ndisplay_word_id="apple"\n\n[learning]\nage_band="7-9"\n';
const medalSave = '[medals]\nversion=1\ncounts={"spring-1":3,"autumn-1":3,"autumn-2":1}\n';
const presentationSave = JSON.stringify({ muted: false, preferred_theme: 'ocean' });
const savedRecords = {
  'wordBuddies.playroom': roomSave,
  'wordBuddies.medalProgress': medalSave,
  'pipAndWords.presentation.v1': presentationSave
};
async function seedProgress(page) {
  await page.addInitScript(records => {
    for (const [key, value] of Object.entries(records)) {
      if (localStorage.getItem(key) === null) localStorage.setItem(key, value);
    }
  }, savedRecords);
}
async function maintainedShell(page) {
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8'))
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', `${config.executable}.js`)
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.route('**/loading-theme-test*', route => route.fulfill({ contentType: 'text/html', body: shell }));
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, route => route.fulfill({
    contentType: 'application/javascript',
    body: `window.Engine = class {
      static getMissingFeatures() { return []; }
      static load() { return Promise.resolve(); }
      startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
    };`
  }));
  await page.goto('/loading-theme-test');
}
async function expectAutomaticTheme(page) {
  await expect(page.locator('#loading-themes')).toBeHidden();
  await expect(page.locator('#loading-themes')).toHaveAttribute('inert');
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-theme', 'spring');
  expect(await page.evaluate(() => wordBuddiesHost.loadingTheme())).toBe('spring');
}
for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`loader uses Growth preview without rotation or saved preference changes with motion ${reducedMotion}`, async ({ page }) => {
    await page.emulateMedia({ reducedMotion });
    await page.clock.install();
    await page.clock.pauseAt(new Date());
    await seedProgress(page);
    await maintainedShell(page);
    await expectAutomaticTheme(page);
    await page.clock.fastForward(45000);
    await expectAutomaticTheme(page);
    await page.evaluate(() => {
      window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }));
      window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
    });
    await page.clock.fastForward(45000);
    await expectAutomaticTheme(page);
    expect(await page.evaluate(keys => Object.fromEntries(keys.map(key => [key, localStorage.getItem(key)])),
      Object.keys(savedRecords))).toEqual(savedRecords);
    await expect(page.locator('#enter-game')).toBeDisabled();
    if (reducedMotion === 'reduce') expect(await page.locator('#status').evaluate(el => getComputedStyle(el).transitionDuration)).toBe('0s');
  });
}
test('hidden historical choices cannot receive keyboard focus', async ({ page }) => {
  await maintainedShell(page);
  await page.locator('#loading-duck').focus();
  for (let index = 0; index < 12; index++) {
    await page.keyboard.press('Tab');
    expect(await page.evaluate(() => Boolean(document.activeElement?.closest('#loading-themes')))).toBe(false);
  }
  await expectAutomaticTheme(page);
});
test('controller shoulders leave theme automatic and Start enters exactly once', async ({ page }) => {
  await installGamepad(page, { connected: true });
  await maintainedShell(page);
  await pressGamepad(page, 4);
  await pressGamepad(page, 5);
  await expectAutomaticTheme(page);
  await page.evaluate(() => {
    window.loadingReveals = [];
    wordBuddiesHost.ready(theme => loadingReveals.push(theme));
  });
  await expect(page.locator('#enter-game')).toBeEnabled();
  await pressGamepad(page, 9);
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).not.toHaveAttribute('inert');
  await page.evaluate(() => document.getElementById('enter-game').dispatchEvent(new Event('click')));
  expect(await page.evaluate(() => loadingReveals)).toEqual(['spring']);
});
test('engine failure exposes Retry without restoring historical theme controls', async ({ page }) => {
  await maintainedShell(page);
  await page.evaluate(() => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', {
    reason: new WebAssembly.RuntimeError('Loading test failure'), promise: Promise.resolve()
  })));
  await expect(page.locator('#status')).toHaveAttribute('data-state', 'error');
  await expect(page.locator('#retry')).toBeFocused();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
  await expectAutomaticTheme(page);
});
test('loader entry stays visible at compact and wide sizes without a second theme picker', async ({ page }, testInfo) => {
  await maintainedShell(page);
  await page.evaluate(() => wordBuddiesHost.ready());
  await expect(page.locator('#enter-game')).toBeEnabled();
  for (const viewport of [{ width: 320, height: 320 }, { width: 320, height: 568 },
    { width: 390, height: 844 }, { width: 844, height: 390 }, { width: 1280, height: 800 }]) {
    await page.setViewportSize(viewport);
    await expectAutomaticTheme(page);
    await expect(page.locator('#enter-game')).toBeInViewport({ ratio: 1 });
    expect((await page.locator('#enter-game').boundingBox()).height).toBeGreaterThanOrEqual(44);
    await page.screenshot({ path: testInfo.outputPath(`automatic-loading-${viewport.width}x${viewport.height}.png`), scale: 'css' });
  }
});
test('real Home preserves historical themes and rewards while Growth selects Garden automatically', async ({ page }) => {
  test.setTimeout(150000);
  await seedProgress(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expectAutomaticTheme(page);
  await enterGame(page, { home: true });
  expect((await metrics(page)).library.controls.filter(item => item.name.startsWith('Theme_') && item.visible)).toEqual([]);
  expect(await page.evaluate(() => localStorage.getItem('pipAndWords.presentation.v1'))).toBe(presentationSave);
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'))).toBe(roomSave);
  expect(JSON.parse((await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress')))
    .match(/^counts=(\{[\s\S]*?\})/m)[1])).toEqual({ 'spring-1': 3, 'autumn-1': 3, 'autumn-2': 1 });
  await activateLibraryControl(page, 'GrowthPath');
  expect((await metrics(page)).library.learning.selection.track).toBe('growth');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', growthTheme.palette.background.toLowerCase());
  await activateLibraryControl(page, 'LibrarySound');
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'))))
    .toEqual({ muted: true, preferred_theme: 'ocean' });
  await page.reload();
  await enterGame(page, { home: true });
  await expectAutomaticTheme(page);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).preferred_theme)).toBe('ocean');
  expect(errors).toEqual([]);
});
test('blocked optional preferences do not block entry or learning-path selection', async ({ page }) => {
  await page.addInitScript(() => {
    const read = Storage.prototype.getItem, write = Storage.prototype.setItem;
    Storage.prototype.getItem = function (key) {
      if (['wordBuddies.playroom', 'pipAndWords.presentation.v1'].includes(key)) throw new DOMException('Preference storage is blocked', 'SecurityError');
      return read.call(this, key);
    };
    Storage.prototype.setItem = function (key, value) {
      if (['wordBuddies.playroom', 'pipAndWords.presentation.v1'].includes(key)) throw new DOMException('Preference storage is blocked', 'SecurityError');
      return write.call(this, key, value);
    };
  });
  await page.goto('/');
  await enterGame(page, { home: true });
  await activateLibraryControl(page, 'GrowthPath');
  expect((await metrics(page)).library.learning.selection.track).toBe('growth');
  await expect(page.locator('#canvas')).not.toHaveAttribute('inert');
  await expectAutomaticTheme(page);
});
