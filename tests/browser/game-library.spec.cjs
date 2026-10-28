const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { MODES, THEME_NAMES, openGame, openModeMenu, chooseMode, metrics, tap, enterGame, rendered,
  visibleColorCount, libraryControl, activateLibraryControl, openRewards,
  activateGrowthControl, growthView, growthState, seedPipLevel, matchWords, discoverMatchCards, boardPoint } = require('./game-ui.cjs');
const learningThemes = require('../../data/professional/themes.json').profiles;

async function expectAutomaticPalette(page, themeId) {
  const palette = learningThemes.find(profile => profile.id === themeId).palette;
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(palette.accent.toLowerCase());
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', palette.background.toLowerCase());
}

async function browseDraftRetailModule(page) {
  await activateLibraryControl(page, 'ChangeLearningPath');
  await expect.poll(async () => (await metrics(page)).library.learning.screen).toBe('paths');
  await activateLibraryControl(page, 'ProfessionalPath');
  await expect.poll(async () => (await metrics(page)).library.learning.screen).toBe('courses');
  await activateLibraryControl(page, 'Career_retail');
  await expect.poll(async () => (await metrics(page)).library.learning.screen).toBe('modules');
  expect((await metrics(page)).library.learning.course_id).toBe('retail');
  await expectAutomaticPalette(page, 'professional_retail');
  await activateLibraryControl(page, 'Module_module03');
  await expect.poll(async () => (await metrics(page)).library.learning.screen).toBe('summary');
  expect((await metrics(page)).library.learning.selection).toMatchObject({
    track: 'professional', course_id: 'retail', module_id: 'module03'
  });
  expect((await metrics(page)).library.learning.continue_enabled, 'A draft module cannot start a lesson').toBe(false);
}

async function openHome(page, { reducedMotion = 'reduce' } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.addInitScript(() => { window.SpeechRecognition = undefined; window.webkitSpeechRecognition = undefined; });
  await page.emulateMedia({ reducedMotion });
  await page.goto('/');
  await expect(page).toHaveTitle("Pip's world");
  await expect(page.locator('#loading-title')).toHaveText("Pip's world");
  await expect(page.locator('#canvas')).toHaveAttribute('aria-label', "Pip's world word game");
  await enterGame(page, { home: true });
  // Home opens with everyday games; vocabulary selection lives in Word Library.
  await expect.poll(async () => {
    const home = (await metrics(page)).library;
    return home.visible && home.vocabulary?.kind === 'everyday';
  }, { message: 'A new learner reaches Home with everyday vocabulary' }).toBe(true);
  const initial = (await metrics(page)).library;
  expect(initial.brand).toBe("Pip's world");
  expect(initial.controls.filter(item => item.name.startsWith('Mode_')).map(item => item.name),
    'All six games are available directly from Home').toEqual(MODES.map(mode => `Mode_${mode}`));
  expect(initial.controls.some(item => item.name.startsWith('Mode_') && item.visible),
    'The first games are visible without choosing a learning path').toBe(true);
  expect(initial.controls.find(item => item.name === 'HomeVocabulary')?.visible,
    'Home exposes its current vocabulary and the Word Library entry').toBe(true);
  expect(initial.controls.filter(item => ['GrowthPath', 'ProfessionalPath'].includes(item.name) && item.visible),
    'Home has no separate learning-path gate').toEqual([]);
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

test("Pip's world brands loading, Home and credits while restoring existing progress", async ({ page }, info) => {
  test.setTimeout(240000);
  await seedPipLevel(page, 3);
  await page.addInitScript(() => {
    const key = 'growWithPip.coinWallet.v1';
    // v3 supports exact coin amounts; earlier receipts require multiples of 50.
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      '[wallet]\nversion=3\nbalance=275\nreceipts={"branding-opening-coins":275}\n');
  });
  const errors = await openHome(page);
  expect((await growthState(page)).level, 'The old growth key restores the earned Pip level').toBe(3);
  await expect.poll(() => page.locator('#coin-status').evaluate(node =>
    JSON.parse(node.dataset.snapshot || '{}').balance)).toBe(275);
  const saved = await page.evaluate(() => ({
    growth: localStorage.getItem('growWithPip.growth.v1'),
    wallet: localStorage.getItem('growWithPip.coinWallet.v1')
  }));
  expect(saved.growth).toBeTruthy();
  expect(saved.wallet).toContain('branding-opening-coins');
  await captureHome(page, info, 'pip-world-home');
  await page.goto('/map-credits.html');
  await expect(page).toHaveTitle("Pip's world art credits");
  await expect(page.getByRole('heading', { level: 1 })).toHaveText("The art of Pip's world");
  await expect(page.getByRole('link', { name: "Pip's world", exact: true })).toHaveAttribute('href', './');
  expect(errors).toEqual([]);
});

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
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.authored_morphology && state.tiles?.length > 0 && state.tiles.every(tile => tile.settled);
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
  await expect.poll(async () => (await metrics(page)).library.learning.selection.track).toBe('growth');
  const restored = (await metrics(page)).library;
  expect(restored.hero.mastered).toBe(1);
  expect(restored.hero.progress).toBeCloseTo(earned.hero.progress, 5);
  expect(restored.hero.next_age).toBe(3);
  expect(errors).toEqual([]);
});

async function swipeHome(page, testInfo) {
  const card = await libraryControl(page, 'Mode_word_jelly');
  const bounds = await metrics(page), home = bounds.library;
  const [x, y, width, height] = card.rect;
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
      const controls = (await metrics(page)).library.controls;
      expect(controls.filter(item => THEME_NAMES.includes(item.name) && item.visible),
        'Learning paths choose their presentation automatically without a separate theme picker').toEqual([]);
      const footer = controls.filter(item => ['HomeCollection', 'LibrarySound'].includes(item.name));
      expect(footer.map(item => item.name), 'The Home footer contains only the word library and sound controls')
        .toEqual(['HomeCollection', 'LibrarySound']);
      expect(Math.abs(footer[0].rect[2] - footer[1].rect[2]), 'The two footer controls share the width equally').toBeLessThanOrEqual(1);
      for (const name of ['HomeVocabulary', ...names, 'HomeCollection', 'LibrarySound']) {
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
  test.setTimeout(420000);
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
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.authored_morphology && state.tiles?.length > 0 && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  await openModeMenu(page);
  await expect.poll(async () => (await jellyState(page)).paused).toBe(true);
  const paused = await jellyState(page);
  await browseDraftRetailModule(page);
  expect((await metrics(page)).library.visible, 'Browsing another learning path keeps the current game paused').toBe(true);
  expect((await jellyState(page)).paused).toBe(true);
  await page.waitForTimeout(1100);
  expect((await jellyState(page)).spawn_elapsed, 'Falling word supply pauses on home').toBe(paused.spawn_elapsed);
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  expect((await metrics(page)).library.current).toBe('word_jelly');
  await expect.poll(async () => (await jellyState(page)).paused).toBe(false);
  await expectAutomaticPalette(page, 'growth_garden');
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
  test.setTimeout(240000);
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
  await browseDraftRetailModule(page);
  expect(await page.evaluate(() => window.__homeSpeech.starts), 'Browsing careers and draft modules keeps the microphone stopped').toBe(paused.starts);
  expect(await page.evaluate(() => window.__homeSpeech.active)).toBe(false);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  expect((await metrics(page)).library.current).toBe('pop');
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

test('automatic learning themes preserve historical preferences while sound persists and motion follows the system', async ({ page }) => {
  // Two engine starts, course changes and keyboard scrolling must all finish on
  // the software renderer; retain the normal per-step assertion timeouts.
  test.setTimeout(300000);
  await page.addInitScript(() => {
    if (sessionStorage.getItem('legacyMotionSeeded')) return;
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: false, reduced_motion: false, preferred_theme: 'ocean' }));
    sessionStorage.setItem('legacyMotionSeeded', 'true');
  });
  const errors = await openHome(page);
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryMotion')).toBe(false);
  await expectAutomaticPalette(page, 'growth_garden');
  expect((await metrics(page)).library.controls.filter(item => THEME_NAMES.includes(item.name) && item.visible)).toEqual([]);
  await activateLibraryControl(page, 'LibrarySound');
  const savedPreferences = { muted: true, preferred_theme: 'ocean' };
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual(savedPreferences);
  await browseDraftRetailModule(page);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'))),
    'Automatic course previews preserve the historical theme preference').toEqual(savedPreferences);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'GrowthPath');
  await expectAutomaticPalette(page, 'growth_garden');
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
  await expect(page.locator('#loading-themes')).toBeHidden();
  await expect(page.locator('#loading-themes')).toHaveAttribute('inert');
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.learning.selection.track).toBe('growth');
  await expectAutomaticPalette(page, 'growth_garden');
  expect((await metrics(page)).library.controls.filter(item => THEME_NAMES.includes(item.name) && item.visible)).toEqual([]);
  expect((await metrics(page)).library.controls.some(item => item.name === 'LibraryMotion')).toBe(false);
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: false, preferred_theme: 'ocean' });
  expect(errors).toEqual([]);
});

test('saved Sound reload restores the actual toggle state with the automatic Growth theme', async ({ page }, info) => {
  test.setTimeout(180000);
  await page.addInitScript(() => {
    if (sessionStorage.getItem('soundReloadSeeded')) return;
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: false, reduced_motion: true, preferred_theme: 'ocean' }));
    sessionStorage.setItem('soundReloadSeeded', 'true');
  });
  const errors = await openHome(page, { reducedMotion: 'no-preference' });
  // Exercise the real reverse keyboard route to the footer. This focused reload
  // check does not repeat the separate full forward-navigation acceptance case.
  async function revealSound() {
    for (let step = 0; step < 12; step++) {
      const sound = (await metrics(page)).library.controls.find(item => item.name === 'LibrarySound');
      if (sound?.focused && sound.visible) return libraryControl(page, 'LibrarySound');
      await page.locator('#canvas').press('Shift+Tab');
      await rendered(page);
    }
    throw new Error('The reverse keyboard route did not reveal Sound.');
  }
  await revealSound();
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'))))
    .toEqual({ muted: true, preferred_theme: 'ocean' });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.learning.selection.track).toBe('growth');
  await expectAutomaticPalette(page, 'growth_garden');
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  expect((await metrics(page)).library.controls.filter(item => THEME_NAMES.includes(item.name) && item.visible)).toEqual([]);
  await revealSound();
  await page.screenshot({ path: info.outputPath('sound-after-reload.png'), scale: 'css' });
  await activateLibraryControl(page, 'LibrarySound');
  // Defaulting to unmuted on reload would toggle to true and fail this check.
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1'))))
    .toEqual({ muted: false, preferred_theme: 'ocean' });
  expect(errors).toEqual([]);
});
