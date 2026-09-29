const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');
const { THEME_IDS, THEME_COLORS, enterGame } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);
const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const roomSave = '[playroom]\nversion=1\ntoy="toy-autumn"\nbackdrop="backdrop-spring"\nfavorite="spring-1"\n\n'
  + '[journey]\nrecent_topic_ids=[]\npreferred_theme_id="autumn"\ngoal_item_id="toy-space"\n\n'
  + '[stickers]\nword_ids=["apple"]\ndisplay_word_id="apple"\n\n[learning]\nage_band="7-9"\n';
const medalSave = '[medals]\nversion=1\ncounts={"spring-1":3,"autumn-1":3,"autumn-2":1}\n';

function themeButton(page, id) {
  return page.locator(`#loading-theme-options button[data-theme="${id}"]`);
}

async function expectPreview(page, id) {
  await expect(themeButton(page, id)).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('#loading-theme-options button[aria-pressed="true"]')).toHaveCount(1);
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-theme', id);
  await expect(page.locator('#status')).toHaveAttribute('data-theme', id);
  await expect(page.locator('html')).toHaveAttribute('data-pip-theme', id);
  expect(await page.evaluate(() => wordBuddiesHost.loadingTheme())).toBe(id);
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

async function seedProgress(page) {
  await page.addInitScript(({ roomSave, medalSave }) => {
    if (localStorage.getItem('wordBuddies.playroom') !== null) return;
    localStorage.setItem('wordBuddies.playroom', roomSave);
    localStorage.setItem('wordBuddies.medalProgress', medalSave);
  }, { roomSave, medalSave });
}

test('all themes are selectable before the engine is available and late startup colors preserve the preview', async ({ page }) => {
  await seedProgress(page);
  // Keep a valid pending engine script so the loader remains interactive without
  // reporting readiness or touching any native save state.
  await maintainedShell(page);
  await expect(page.locator('#enter-game')).toBeDisabled();
  await expectPreview(page, 'autumn');
  await expect(page.locator('#loading-theme-options button')).toHaveCount(8);
  const outfits = new Set();
  for (const id of THEME_IDS) {
    const choice = themeButton(page, id);
    await expect(choice).toHaveAccessibleName(id[0].toUpperCase() + id.slice(1));
    await choice.click();
    await expectPreview(page, id);
    outfits.add(await page.locator('#loading-pip-head').innerHTML());
  }
  expect(outfits.size, 'Theme changes update Pip artwork while downloads continue.').toBeGreaterThan(1);
  await page.evaluate(() => wordBuddiesHost.background('#effbef', '#438363', '#d7efc7', 'spring'));
  await expectPreview(page, 'candy');
  await expect(page.locator('#enter-game')).toBeDisabled();
  expect(await page.evaluate(key => localStorage.getItem(key), ROOM_KEY)).toBe(roomSave);
  expect(await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY)).toBe(medalSave);
});

test('Enter game passes the latest ready-screen choice to the engine exactly once', async ({ page }) => {
  await maintainedShell(page);
  await themeButton(page, 'ocean').click();
  await page.evaluate(() => {
    window.loadingReveals = [];
    wordBuddiesHost.ready(theme => loadingReveals.push(theme));
  });
  await expect(page.locator('#enter-game')).toBeEnabled();
  await themeButton(page, 'jungle').click();
  await themeButton(page, 'space').click();
  await expectPreview(page, 'space');
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await page.evaluate(() => wordBuddiesHost.ready(() => loadingReveals.push('duplicate')));
  await page.locator('#enter-game').click();
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).not.toHaveAttribute('inert');
  await page.evaluate(() => document.getElementById('enter-game').dispatchEvent(new Event('click')));
  expect(await page.evaluate(() => loadingReveals)).toEqual(['space']);
});

test('theme choices support arrow, Home and End keys without entering the game', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await maintainedShell(page);
  await themeButton(page, 'spring').focus();
  for (const [key, id] of [['ArrowRight', 'summer'], ['End', 'candy'], ['ArrowRight', 'spring'],
    ['ArrowLeft', 'candy'], ['Home', 'spring']]) {
    await page.keyboard.press(key);
    await expectPreview(page, id);
    await expect(themeButton(page, id)).toBeFocused();
    await expect(themeButton(page, id)).toBeInViewport({ ratio: 1 });
    await expect(page.locator('#loading-theme-options button[tabindex="0"]')).toHaveCount(1);
  }
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#enter-game')).toBeDisabled();
});

test('controller shoulder buttons change theme once per press before Start enters the chosen world', async ({ page }) => {
  await installGamepad(page, { connected: true });
  await maintainedShell(page);
  await expectPreview(page, 'spring');
  await pressGamepad(page, 4);
  await expectPreview(page, 'candy');
  await pressGamepad(page, 5);
  await expectPreview(page, 'spring');
  await page.evaluate(async () => {
    gamepadFixture.button(5, true);
    await new Promise(resolve => setTimeout(resolve, 400));
    gamepadFixture.button(5, false);
  });
  await expectPreview(page, 'summer');
  await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
  await page.evaluate(() => {
    window.controllerTheme = '';
    wordBuddiesHost.ready(theme => { controllerTheme = theme; });
  });
  await expect(page.locator('#enter-game')).toBeEnabled();
  await pressGamepad(page, 9);
  await expect(page.locator('#status')).toBeHidden();
  expect(await page.evaluate(() => controllerTheme)).toBe('summer');
});

test('the theme rail keeps its controls and entry visible on compact and wide loading screens', async ({ page }, testInfo) => {
  await maintainedShell(page);
  await page.evaluate(() => wordBuddiesHost.ready());
  await expect(page.locator('#enter-game')).toBeEnabled();
  for (const viewport of [{ width: 320, height: 320 }, { width: 320, height: 568 },
    { width: 844, height: 390 }, { width: 1366, height: 768 }]) {
    await page.setViewportSize(viewport);
    await themeButton(page, 'candy').click();
    await expectPreview(page, 'candy');
    await expect(themeButton(page, 'candy')).toBeInViewport({ ratio: 1 });
    const layout = await page.locator('#loading-theme-options').evaluate(rail => {
      const rect = rail.getBoundingClientRect(), first = rail.querySelector('button').getBoundingClientRect();
      const status = document.getElementById('status');
      const enter = document.getElementById('enter-game').getBoundingClientRect();
      return { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom,
        scrollWidth: rail.scrollWidth, clientWidth: rail.clientWidth, buttonHeight: first.height,
        scrollTop: status.scrollTop, scrollHeight: status.scrollHeight, clientHeight: status.clientHeight,
        overflowX: getComputedStyle(rail).overflowX,
        scrollbarHidden: getComputedStyle(rail).scrollbarWidth === 'none'
          || getComputedStyle(rail, '::-webkit-scrollbar').display === 'none',
        enterTop: enter.top, enterBottom: enter.bottom };
    });
    expect(layout.left).toBeGreaterThanOrEqual(0);
    expect(layout.right).toBeLessThanOrEqual(viewport.width);
    expect(layout.top).toBeGreaterThanOrEqual(0);
    expect(layout.bottom).toBeLessThanOrEqual(layout.enterTop);
    expect(layout.enterBottom).toBeLessThanOrEqual(viewport.height);
    expect(layout.buttonHeight).toBeGreaterThanOrEqual(44);
    expect(layout.scrollHeight).toBeLessThanOrEqual(layout.clientHeight);
    expect(layout.scrollTop).toBe(0);
    expect(layout.scrollbarHidden).toBe(true);
    if (viewport.width === 320) {
      expect(layout.scrollWidth).toBeGreaterThan(layout.clientWidth);
      expect(['auto', 'scroll']).toContain(layout.overflowX);
    }
    await page.screenshot({ path: testInfo.outputPath(`loading-themes-${viewport.width}x${viewport.height}.png`), scale: 'css' });
  }
});

async function observeNativeThemes(page) {
  await page.addInitScript(() => {
    window.nativeThemes = [];
    document.addEventListener('DOMContentLoaded', () => {
      const host = wordBuddiesHost;
      window.wordBuddiesHost = { ...host, background(color, accent, light, theme) {
        nativeThemes.push(theme);
        return host.background(color, accent, light, theme);
      } };
    });
  });
}

test('the real game adopts the final loading theme and remembers it without losing progress', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  await seedProgress(page);
  await observeNativeThemes(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => { await held; await route.continue(); });
  try {
    await page.goto('/', { waitUntil: 'commit' });
    await expectPreview(page, 'autumn');
    await themeButton(page, 'ocean').click();
    await expectPreview(page, 'ocean');
    release();
    await expect(page.locator('#enter-game')).toBeEnabled({ timeout: 60000 });
    await themeButton(page, 'candy').click();
    await themeButton(page, 'summer').click();
    await page.evaluate(() => { nativeThemes.length = 0; });
    await enterGame(page);
    await expect.poll(() => page.evaluate(() => nativeThemes.at(-1))).toBe('summer');
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[1]);
    const saved = await page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
    for (const field of ['preferred_theme_id="summer"', 'toy="toy-autumn"', 'backdrop="backdrop-spring"',
      'favorite="spring-1"', 'goal_item_id="toy-space"', 'age_band="7-9"', 'display_word_id="apple"']) {
      expect(saved).toContain(field);
    }
    const savedWords = saved.match(/^word_ids=(.*)$/m)?.[1] || '';
    expect([...savedWords.matchAll(/"([^"]+)"/g)].map(([, word]) => word)).toEqual(['apple']);
    expect(await page.evaluate(key => localStorage.getItem(key), MEDAL_KEY)).toBe(medalSave);
    await page.screenshot({ path: testInfo.outputPath('entered-selected-summer.png'), scale: 'css' });
    await page.reload();
    await expectPreview(page, 'summer');
    await enterGame(page);
    await expect.poll(() => page.evaluate(() => nativeThemes.at(-1))).toBe('summer');
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[1]);
    expect(errors).toEqual([]);
  } finally {
    release();
    await page.unrouteAll({ behavior: 'wait' });
  }
});

test('blocked preference storage still allows theme selection and the real game uses that choice', async ({ page }) => {
  await page.addInitScript(() => {
    const read = Storage.prototype.getItem, write = Storage.prototype.setItem;
    Storage.prototype.getItem = function (key) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Preference storage is blocked', 'SecurityError');
      return read.call(this, key);
    };
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Preference storage is blocked', 'SecurityError');
      return write.call(this, key, value);
    };
  });
  await observeNativeThemes(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.locator('#enter-game')).toBeEnabled({ timeout: 60000 });
  await themeButton(page, 'winter').click();
  await expectPreview(page, 'winter');
  await page.evaluate(() => { nativeThemes.length = 0; });
  await enterGame(page);
  await expect.poll(() => page.evaluate(() => nativeThemes.at(-1))).toBe('winter');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[3]);
  await expect(page.locator('#canvas')).not.toHaveAttribute('inert');
  await expect(page.locator('#game-status')).toContainText('could not be remembered');
  expect(errors).toEqual([]);
});
