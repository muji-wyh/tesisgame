const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { MODES, THEME_NAMES, openGame, openModeMenu, chooseMode, chooseTheme, metrics, tap, enterGame, rendered,
  visibleColorCount, libraryControl, activateLibraryControl, openRewards,
  activateGrowthControl, growthView, matchWords, discoverMatchCards, boardPoint } = require('./game-ui.cjs');

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

async function previewPixels(page, mode) {
  return page.locator('#canvas').evaluate(async (canvas, id) => {
    const state = JSON.parse(document.getElementById('game-status').dataset.library);
    const [x, y, width, height] = state.previews.find(item => item.mode === id).rect;
    const image = new Image();
    image.src = canvas.toDataURL('image/png');
    await image.decode();
    const sample = document.createElement('canvas');
    sample.width = 96;
    sample.height = 48;
    const context = sample.getContext('2d');
    const scale = canvas.width / state.rect[2];
    context.drawImage(image, x * scale, y * scale, width * scale, height * scale, 0, 0, 96, 48);
    return { png: sample.toDataURL('image/png').split(',')[1], pixels: Array.from(context.getImageData(0, 0, 96, 48).data) };
  }, mode);
}

function changedPreviewPixels(before, after) {
  let changed = 0;
  for (let index = 0; index < before.length; index += 4) {
    if (Math.abs(before[index] - after[index]) + Math.abs(before[index + 1] - after[index + 1]) +
      Math.abs(before[index + 2] - after[index + 2]) > 30) changed++;
  }
  return changed;
}

test('Home previews loop through all six games automatically without changing gameplay or taking card input', async ({ page }, testInfo) => {
  test.setTimeout(240000);
  const errors = await openHome(page, { reducedMotion: 'no-preference' });
  // Do not hover or focus any game: the illustrations should already be alive.
  await page.mouse.move(1, 1);
  await rendered(page);
  expect((await metrics(page)).library.previews.map(item => item.mode)).toEqual(MODES);
  await expect.poll(async () => (await metrics(page)).library.previews.every(item => item.animating && !item.reduced_motion),
    { message: 'All six gameplay illustrations run without hover or keyboard focus' }).toBe(true);
  const before = await metrics(page);
  const growthBefore = await page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot));
  await page.waitForTimeout(6200);
  const looping = (await metrics(page)).library;
  expect(looping.previews.every(item => item.animating), 'Every illustration continues beyond one complete demonstration').toBe(true);
  expect(looping.visible).toBe(true);
  expect(looping.current).toBe(before.library.current);
  const clocks = looping.previews.map(item => item.elapsed);
  expect(looping.previews.every(item => Number.isFinite(item.elapsed) && item.duration > 0)).toBe(true);
  await expect.poll(async () => (await metrics(page)).library.previews.every((item, index) => Math.abs(item.elapsed - clocks[index]) > 0.05),
    { message: 'All six animation clocks continue advancing after a full loop' }).toBe(true);

  for (const mode of MODES) {
    await libraryControl(page, `Mode_${mode}`);
    await rendered(page);
    const first = await previewPixels(page, mode);
    fs.writeFileSync(testInfo.outputPath(`preview-${mode}-before.png`), Buffer.from(first.png, 'base64'));
    let later;
    await expect.poll(async () => {
      later = await previewPixels(page, mode);
      return changedPreviewPixels(first.pixels, later.pixels);
    }, { timeout: 8000, intervals: [300, 600, 800], message: `${mode} visibly changes inside its illustration, beyond the card decoration` }).toBeGreaterThan(30);
    fs.writeFileSync(testInfo.outputPath(`preview-${mode}-after.png`), Buffer.from(later.png, 'base64'));
    expect((await metrics(page)).library.visible, 'Watching a game does not enter it').toBe(true);
  }
  expect((await metrics(page)).library.coins, 'The miniature collection demonstrations do not award coins').toBe(before.library.coins);
  expect(await page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot)),
    'The demonstrations do not answer real words or change learning progress').toEqual(growthBefore);
  await captureHome(page, testInfo, 'home-animated-gameplay-previews');

  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const state = await jellyState(page);
    return state.tiles?.length >= 18 && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  await openModeMenu(page);
  await expect.poll(async () => (await metrics(page)).library.previews.every(item => item.animating),
    { message: 'Returning Home restarts the automatic illustrations' }).toBe(true);
  await expect.poll(async () => (await jellyState(page)).paused).toBe(true);
  const pausedGame = await jellyState(page);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(async () => (await metrics(page)).library.previews.every(item => !item.animating),
    { message: 'Backgrounding the browser pauses every preview' }).toBe(true);
  const hiddenClocks = (await metrics(page)).library.previews.map(item => item.elapsed);
  await page.waitForTimeout(350);
  expect((await metrics(page)).library.previews.map(item => item.elapsed), 'Backgrounded illustrations do no animation work').toEqual(hiddenClocks);
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(async () => (await metrics(page)).library.previews.every(item => item.animating),
    { message: 'Returning to the browser resumes the automatic illustrations' }).toBe(true);
  expect((await jellyState(page)).tiles, 'Home animations and browser visibility changes preserve the paused board').toEqual(pausedGame.tiles);
  expect((await jellyState(page)).generated_tiles).toBe(pausedGame.generated_tiles);
  expect((await jellyState(page)).spawn_elapsed).toBe(pausedGame.spawn_elapsed);

  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect.poll(async () => (await metrics(page)).library.previews.every(item => item.reduced_motion && !item.animating),
    { message: 'The device motion setting keeps every illustration static' }).toBe(true);
  const card = await libraryControl(page, 'Mode_match');
  await rendered(page);
  const still = await previewPixels(page, 'match');
  await page.waitForTimeout(400);
  expect(changedPreviewPixels(still.pixels, (await previewPixels(page, 'match')).pixels), 'Reduced-motion artwork stays still').toBe(0);
  const preview = (await metrics(page)).library.previews.find(item => item.mode === 'match');
  const [x, y, w, h] = preview.rect;
  expect(card.fully_visible).toBe(true);
  await tap(page, x + w / 2, y + h / 2);
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  expect((await metrics(page)).library.current).toBe('match');
  expect((await metrics(page)).library.previews.every(item => !item.animating), 'Hidden demonstrations stop').toBe(true);
  expect(errors).toEqual([]);
});

test('Home grows alongside Pip when a word is mastered and after reloading', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  const cohort = require('../../words.json').filter(word => word.min_age === 3);
  await page.addInitScript(streaks => {
    if (sessionStorage.getItem('home-growth-seeded')) return;
    localStorage.setItem('growWithPip.growth.v1', `[growth]\nversion=3\nlevel=0\nage=0\nstreaks=${JSON.stringify(streaks)}\nmastered_words=[]\nreceipts=[]\n`);
    sessionStorage.setItem('home-growth-seeded', 'true');
  }, Object.fromEntries(cohort.map(word => [word.id, 2])));
  const errors = await openHome(page);
  const initial = (await metrics(page)).library;
  expect(initial.hero.ready).toBe(true);
  expect(initial.hero.mastered).toBe(0);
  expect(initial.hero.total).toBe(cohort.length);
  expect(initial.hero.progress).toBe(0);
  expect(initial.hero.next_age).toBe(3);
  expect(initial.pip_age).toBe(0);
  await captureHome(page, testInfo, 'home-grow-together');

  await chooseMode(page, 'match');
  const cards = await discoverMatchCards(page);
  for (const card of cards.filter(card => card.word === cards[0].word)) {
    const point = boardPoint(await metrics(page), card.index);
    await tap(page, point.x, point.y);
  }
  await expect.poll(() => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot).mastered)).toBe(1);
  await openModeMenu(page);
  const earned = (await metrics(page)).library;
  expect(earned.hero.mastered).toBe(1);
  expect(earned.hero.progress).toBeCloseTo(1 / cohort.length, 5);
  expect(earned.pip_age, 'One mastered word advances the journey without prematurely changing Pip').toBe(0);
  expect(earned.hero.next_age).toBe(3);

  await page.reload();
  await enterGame(page, { home: true });
  const restored = (await metrics(page)).library;
  expect(restored.hero.mastered).toBe(1);
  expect(restored.hero.progress).toBeCloseTo(earned.hero.progress, 5);
  expect(restored.hero.next_age).toBe(3);
  expect(errors).toEqual([]);
});

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
    test.setTimeout(240000);
    const errors = await openHome(page, { reducedMotion });
    expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryClose'),
      'The home screen has no dismissal that bypasses choosing a game').toBe(false);
    expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryMotion'),
      'Home has no manual motion control').toBe(false);
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
        for (let step = 0; step < 28 && (await metrics(page)).library.scroll_offset > 0; step++) {
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
      const footer = (await metrics(page)).library.controls.filter(item => !THEME_NAMES.includes(item.name) && !item.name.startsWith('Mode_'));
      expect(footer.map(item => item.name), 'The Home footer contains only the word library and sound controls')
        .toEqual(['HomeCollection', 'LibrarySound']);
      expect(Math.abs(footer[0].rect[2] - footer[1].rect[2]), 'The two footer controls share the width equally').toBeLessThanOrEqual(1);
      for (const name of [...THEME_NAMES, ...names, 'HomeCollection', 'LibrarySound']) {
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
  test.setTimeout(240000);
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
    await expect.poll(async () => (await metrics(page)).library.controls
      .filter(item => item.name.startsWith('Mode_') && item.selected).map(item => item.name),
    { message: 'The current game stays selected independently of the card display order' }).toEqual([`Mode_${mode}`]);
    await expect.poll(async () => (await metrics(page)).library.controls.find(item => item.focused)?.name,
      { message: 'Home returns keyboard focus to the current game by identity' }).toBe(`Mode_${mode}`);
    await page.keyboard.press('Escape');
    await rendered(page);
    expect((await metrics(page)).library.visible).toBe(true);
    await page.keyboard.press('Enter');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
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
  await chooseTheme(page, 5);
  expect((await metrics(page)).library.visible, 'Choosing a Home theme keeps the game paused').toBe(true);
  expect((await jellyState(page)).paused).toBe(true);
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
  await chooseTheme(page, 4);
  expect(await page.evaluate(() => window.__homeSpeech.starts), 'Choosing a Home theme keeps the microphone stopped').toBe(paused.starts);
  expect(await page.evaluate(() => window.__homeSpeech.active)).toBe(false);
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

test('home keeps sound and theme choices while motion follows the system and ignores old saved overrides', async ({ page }) => {
  test.setTimeout(180000);
  await page.addInitScript(() => {
    if (sessionStorage.getItem('legacyMotionSeeded')) return;
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: false, reduced_motion: false, preferred_theme: 'spring' }));
    sessionStorage.setItem('legacyMotionSeeded', 'true');
  });
  const errors = await openHome(page);
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryMotion')).toBe(false);
  await chooseTheme(page, 4);
  await activateLibraryControl(page, 'LibrarySound');
  const savedPreferences = { muted: true, preferred_theme: 'ocean' };
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual(savedPreferences);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'))),
    'System motion changes do not become saved manual overrides').toEqual(savedPreferences);
  await page.evaluate(() => {
    const saved = JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'));
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ ...saved, reduced_motion: true }));
  });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#loading-theme-options button[data-theme="ocean"]')).toHaveAttribute('aria-pressed', 'true');
  await page.locator('#loading-theme-options button[data-theme="ocean"]').focus();
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await enterGame(page, { home: true });
  expect((await metrics(page)).library.theme_id, 'The selected Home theme survives reload').toBe('ocean');
  expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryMotion')).toBe(false);
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: false, preferred_theme: 'ocean' });
  expect(errors).toEqual([]);
});
