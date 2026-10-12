const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { MODES, openGame, openModeMenu, chooseMode, metrics, tap, enterGame, rendered,
  visibleColorCount, libraryControl, activateLibraryControl, openRewards,
  activateGrowthControl, growthView, matchWords } = require('./game-ui.cjs');

async function openHome(page, { reducedMotion = 'reduce' } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.addInitScript(() => { window.SpeechRecognition = undefined; window.webkitSpeechRecognition = undefined; });
  await page.emulateMedia({ reducedMotion });
  await page.goto('/');
  await enterGame(page, { home: true });
  return errors;
}

async function captureHome(page, testInfo, name) {
  const png = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  const canvasPng = Buffer.from(raw, 'base64');
  fs.writeFileSync(testInfo.outputPath(`${name}-canvas.png`), canvasPng);
  expect(await visibleColorCount(page, canvasPng), 'The native home screen renders after resizing').toBeGreaterThan(20);
  const colors = await visibleColorCount(page, png);
  if (colors === 1 && process.platform === 'win32' && testInfo.project.use.browserName === 'webkit') {
    testInfo.annotations.push({ type: 'rendering-limitation', description: 'Windows WebKit presents a blank page after resize while its raw canvas renders; both captures retained.' });
  } else expect(colors).toBeGreaterThan(20);
}

const jellyState = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));

async function swipeHome(page, testInfo) {
  const bounds = await metrics(page), home = bounds.library;
  const [x, y, width, height] = home.viewport_rect;
  const start = { x: bounds.x + (x + width * 0.25) * bounds.scale,
    y: bounds.y + (y + height * 0.8) * bounds.scale };
  const distance = Math.min(180, height * bounds.scale * 0.6);
  const client = await page.context().newCDPSession(page);
  let pressedOffset;
  try {
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
    await page.waitForTimeout(100);
    pressedOffset = (await metrics(page)).library.scroll_offset;
    for (let step = 1; step <= 8; step++) {
      await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, x: start.x, y: start.y - distance * step / 8 }] });
      await rendered(page);
    }
  } finally {
    await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await client.detach();
  }
  await expect.poll(async () => (await metrics(page)).library.scroll_offset,
    { message: 'A real finger swipe scrolls beyond any initial card-focus adjustment' }).toBeGreaterThan(pressedOffset + 40 / bounds.scale);
  expect((await metrics(page)).library.visible, 'Swiping a game card does not launch it').toBe(true);
  expect((await metrics(page)).library.current).toBe(home.current);
  expect(await page.evaluate(() => [scrollX, scrollY]), 'Only the home content scrolls').toEqual([0, 0]);
  await captureHome(page, testInfo, 'home-compact-touch-scrolled');
}

for (const reducedMotion of ['reduce', 'no-preference']) {
  test(`the home screen is the entry point with reachable illustrated games (${reducedMotion})`, async ({ page, browserName }, testInfo) => {
    test.setTimeout(180000);
    const errors = await openHome(page, { reducedMotion });
    expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryClose'),
      'The home screen has no dismissal that bypasses choosing a game').toBe(false);
    await page.keyboard.press('Escape');
    await rendered(page);
    expect((await metrics(page)).library.visible, 'Escape keeps the player at home').toBe(true);
    await tap(page, 1, 1);
    expect((await metrics(page)).library.visible, 'The page edge cannot dismiss home').toBe(true);
    const sizes = reducedMotion === 'reduce' ? [{ width: 390, height: 420 }, { width: 390, height: 844 },
      { width: 390, height: 600 }, { width: 320, height: 320 }, { width: 844, height: 390 }, { width: 1280, height: 800 }] :
      [{ width: 390, height: 844 }, { width: 1280, height: 800 }];
    for (const size of sizes) {
      await page.setViewportSize(size);
      await rendered(page);
      await expect.poll(async () => {
        const bounds = await metrics(page), rect = bounds.library.rect;
        return rect && Math.abs(rect[0]) <= 1 && Math.abs(rect[1]) <= 1 &&
          Math.abs(rect[2] - bounds.width) <= 1 && Math.abs(rect[3] - bounds.height) <= 1;
      }, { message: 'Home finishes laying out across the entire viewport' }).toBe(true);
      const names = (await metrics(page)).library.controls.filter(item => item.name.startsWith('Mode_')).map(item => item.name);
      expect(names, 'Home offers every supported game').toEqual(MODES.map(mode => `Mode_${mode}`));
      const bounds = await metrics(page), [x, y, width, height] = bounds.library.viewport_rect;
      if (browserName === 'webkit' && testInfo.project.use.isMobile) {
        // Mobile WebKit has no wheel API. Tab through the real controls until
        // the companion at the beginning of the content brings its top back.
        for (let step = 0; step < 18 && (await metrics(page)).library.scroll_offset > 0; step++) {
          await page.locator('#canvas').press('Tab');
          await rendered(page);
        }
      } else {
        await page.mouse.move(bounds.x + (x + width / 2) * bounds.scale, bounds.y + (y + height / 2) * bounds.scale);
        await page.mouse.wheel(0, -5000);
      }
      await expect.poll(async () => (await metrics(page)).library.scroll_offset).toBe(0);
      await captureHome(page, testInfo, `home-${reducedMotion}-${size.width}x${size.height}`);
      if (browserName === 'chromium' && reducedMotion === 'reduce' && size.width === 390 && size.height === 420) {
        await swipeHome(page, testInfo);
      }
      for (const name of [...names, 'HomeCollection', 'LibrarySound', 'LibraryMotion']) {
        const control = await libraryControl(page, name), bounds = await metrics(page);
        const [x, y, w, h] = control.rect;
        expect(control.disabled, `${name} is enabled`).toBe(false);
        expect(x, `${name} fits horizontally`).toBeGreaterThanOrEqual(-1);
        expect(y, `${name} can be brought into view`).toBeGreaterThanOrEqual(-1);
        expect(x + w).toBeLessThanOrEqual(bounds.width + 1);
        expect(y + h).toBeLessThanOrEqual(bounds.height + 1);
        expect(w * bounds.scale, `${name} has a touchable width`).toBeGreaterThanOrEqual(43);
        expect(h * bounds.scale, `${name} has a touchable height`).toBeGreaterThanOrEqual(43);
      }
    }
    expect(errors).toEqual([]);
  });
}

test('every game is selected from home and choosing the current game continues its round', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  const errors = await openHome(page);
  for (const mode of MODES) {
    await chooseMode(page, mode);
    const playing = await metrics(page);
    expect(playing.library.visible).toBe(false);
    expect(playing.library.current).toBe(mode);
    const home = playing.growth.controls.find(item => item.name === 'Home');
    expect(home?.visible, 'The gameplay header provides a Home action').toBe(true);
    expect(home.disabled).toBe(false);
    expect(playing.growth.controls.some(item => item.visible && item.name.startsWith('Mode_')),
      'The gameplay header has no direct mode choices').toBe(false);
    if (mode === 'match') await page.screenshot({ path: testInfo.outputPath('match-gameplay-home-header.png'), scale: 'css' });
    await openModeMenu(page);
    expect((await metrics(page)).library.current, 'Returning home does not silently switch modes').toBe(mode);
    await page.keyboard.press('Escape');
    await rendered(page);
    expect((await metrics(page)).library.visible).toBe(true);
    await chooseMode(page, mode);
    expect((await metrics(page)).library.current).toBe(mode);
  }
  await chooseMode(page, 'match');
  const words = await matchWords(page);
  await openModeMenu(page);
  await chooseMode(page, 'match');
  expect(await matchWords(page), 'The same Match cards survive a visit home').toEqual(words);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const state = await jellyState(page);
    return state.mode === 'word_jelly' && state.tiles?.length >= 18 && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  await openModeMenu(page);
  await expect.poll(async () => (await jellyState(page)).paused).toBe(true);
  const paused = await jellyState(page);
  await page.waitForTimeout(1100);
  expect((await jellyState(page)).spawn_elapsed, 'Falling word supply pauses on home').toBe(paused.spawn_elapsed);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => (await jellyState(page)).paused).toBe(false);
  expect((await jellyState(page)).tiles.map(tile => tile.id), 'Returning from home keeps the current Jelly Words board')
    .toEqual(paused.tiles.map(tile => tile.id));
  await page.screenshot({ path: testInfo.outputPath('jelly-words-resumed-from-home.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('collection and background visits return to home without resuming its paused game', async ({ page }) => {
  test.setTimeout(180000);
  const errors = await openGame(page, { mode: 'word_jelly' });
  await openModeMenu(page);
  await expect.poll(async () => (await jellyState(page)).paused).toBe(true);
  const before = await jellyState(page);
  await openRewards(page);
  expect((await metrics(page)).library.visible).toBe(false);
  await activateGrowthControl(page, 'GrowthBack');
  await expect.poll(async () => (await growthView(page)).visible).toBe(false);
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
  expect((await jellyState(page)).paused).toBe(true);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await rendered(page);
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await rendered(page);
  expect((await metrics(page)).library.visible, 'Returning to the tab keeps home open').toBe(true);
  expect((await jellyState(page)).paused, 'The covered game remains paused after tab visibility changes').toBe(true);
  expect((await jellyState(page)).generated_tiles).toBe(before.generated_tiles);
  await page.reload();
  await enterGame(page, { home: true });
  expect((await metrics(page)).library.visible, 'Reload also lands on home').toBe(true);
  expect(errors).toEqual([]);
});

test('returning home releases the microphone until Voice Pop is selected again', async ({ page }) => {
  await page.addInitScript(() => {
    const speech = { starts: 0, stops: 0, active: false };
    class Recognition {
      start() {
        speech.starts++;
        speech.active = true;
        this.callbacks = { start: this.onstart, error: this.onerror, end: this.onend };
        queueMicrotask(() => this.callbacks.start?.());
      }
      abort() {
        speech.stops++;
        speech.active = false;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      stop() { this.abort(); }
    }
    window.__homeSpeech = speech;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('The home test must not capture a physical microphone'); };
  });
  const errors = await openGame(page, { mode: 'pop' });
  await expect.poll(() => page.evaluate(() => window.__homeSpeech.active)).toBe(true);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await openModeMenu(page);
  await expect.poll(() => page.evaluate(() => window.__homeSpeech.active)).toBe(false);
  const paused = await page.evaluate(() => ({ ...window.__homeSpeech }));
  expect(paused.stops).toBeGreaterThan(0);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await chooseMode(page, 'pop');
  await expect.poll(() => page.evaluate(() => window.__homeSpeech.starts)).toBe(paused.starts + 1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await openModeMenu(page);
  await expect.poll(() => page.evaluate(() => window.__homeSpeech.active)).toBe(false);
  const beforeCollection = await page.evaluate(() => window.__homeSpeech.starts);
  await openRewards(page);
  await activateGrowthControl(page, 'GrowthBack');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
  expect(await page.evaluate(() => window.__homeSpeech.starts), 'Collection return does not restart the microphone').toBe(beforeCollection);
  expect(await page.evaluate(() => window.__homeSpeech.active)).toBe(false);
  expect(errors).toEqual([]);
});

test('home sound and explicit motion choices persist while system motion remains the default', async ({ page }) => {
  test.setTimeout(180000);
  const errors = await openHome(page);
  const preferredTheme = await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).preferred_theme);
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true, preferred_theme: preferredTheme });
  await activateLibraryControl(page, 'LibraryMotion');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true, reduced_motion: false, preferred_theme: preferredTheme });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await page.reload();
  await enterGame(page, { home: true });
  const reloadedTheme = await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).preferred_theme);
  await activateLibraryControl(page, 'LibraryMotion');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true, reduced_motion: true, preferred_theme: reloadedTheme });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: false, reduced_motion: true, preferred_theme: reloadedTheme });
  expect(errors).toEqual([]);
});
