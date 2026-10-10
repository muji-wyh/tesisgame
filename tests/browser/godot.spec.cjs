const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording } = require('./bundled-audio.cjs');
const catalog = require('../../words.json');
const { THEME_COLORS, metrics: logicalMetrics, tap, chooseTheme, openRewards, enterGame,
  contentBounds, headerPoint, headerIconRect, pipHeaderRect, rendered, observeAudio, boardPoint, resultPoint, growthView, activateGrowthControl, rewardState, acceptCelebration } = require('./game-ui.cjs');

test.beforeAll(() => {
  const directory = path.join(__dirname, '..', '..', 'build', 'web');
  const config = JSON.parse(fs.readFileSync(path.join(directory, 'index.html'), 'utf8')
    .match(/const config = (\{[^\r\n]*\});/)[1]);
  expect(fs.existsSync(path.join(directory, `${config.executable}.wasm`)),
    'Build the actual Godot Web export before running browser tests.').toBe(true);
});

function watchErrors(page) {
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  return errors;
}

async function ready(scope, renderFrames = true) {
  // This helper also checks new rounds after entry; only a fresh page needs the gate.
  if (await scope.locator('body').getAttribute('data-engine-ready') !== 'true') await enterGame(scope);
  await expect(scope.locator('#status')).toBeHidden();
  await expect(scope.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  if (renderFrames) await rendered(scope);
}

async function canvasMetrics(scope) {
  return scope.locator('#canvas').evaluate((canvas) => {
    const rect = canvas.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  });
}

function cardPoint(metrics, index) {
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const point = boardPoint({ width: metrics.width / scale, height: metrics.height / scale, scale }, index);
  return { x: metrics.x + point.x * scale, y: metrics.y + point.y * scale };
}

function resultScreenPoint(metrics, key = 'chest') {
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const point = resultPoint({ width: metrics.width / scale, height: metrics.height / scale, scale }, key);
  return { x: metrics.x + point.x * scale, y: metrics.y + point.y * scale };
}

const firstCard = (metrics) => cardPoint(metrics, 0);

async function hintImage(page, countOnly = false) {
  const bounds = await logicalMetrics(page), icon = headerIconRect(bounds, 'hint');
  const clip = countOnly ? { x: icon.x + icon.width * 0.67, y: icon.y + icon.height * 0.66,
    width: icon.width * 0.22, height: icon.height * 0.24 } : icon;
  await page.mouse.move(0, 0);
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    x: bounds.x + clip.x * bounds.scale, y: bounds.y + clip.y * bounds.scale,
    width: clip.width * bounds.scale, height: clip.height * bounds.scale
  } });
}

async function boltColors(page, screenshot) {
  return page.evaluate(async encoded => {
    const image = new Image(); image.src = 'data:image/png;base64,' + encoded; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const counts = { saturated: 0, warm: 0, cool: 0, purple: 0, pink: 0 };
    for (let index = 0; index < pixels.length; index += 4) {
      const [red, green, blue] = pixels.subarray(index, index + 3);
      if (Math.max(red, green, blue) < 100 || Math.max(red, green, blue) - Math.min(red, green, blue) < 55) continue;
      counts.saturated++;
      if (red > blue + 45 && red > green + 5) counts.warm++;
      if (green > red + 25 && blue > red + 25) counts.cool++;
      if (blue > green + 30 && red > green + 15) counts.purple++;
      if (red > green + 35 && blue > green + 15 && red > blue + 5) counts.pink++;
    }
    return counts;
  }, screenshot.toString('base64'));
}

async function assertFits(scope) {
  const sizes = await scope.locator('#canvas').evaluate((canvas) => {
    const rect = canvas.getBoundingClientRect();
    return {
      width: rect.width, height: rect.height, x: rect.x, y: rect.y,
      windowWidth: innerWidth, windowHeight: innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
      ratio: devicePixelRatio
    };
  });
  expect(sizes.scrollWidth).toBeLessThanOrEqual(sizes.windowWidth);
  expect(sizes.scrollHeight).toBeLessThanOrEqual(sizes.windowHeight);
  expect(sizes.x).toBeGreaterThanOrEqual(0);
  expect(sizes.y).toBeGreaterThanOrEqual(0);
  expect(sizes.x + sizes.width).toBeLessThanOrEqual(sizes.windowWidth + 1);
  expect(sizes.y + sizes.height).toBeLessThanOrEqual(sizes.windowHeight + 1);
  await expect.poll(async () => {
    const pixels = await scope.locator('#canvas').evaluate(canvas => ({ width: canvas.width, height: canvas.height }));
    return Math.max(
      Math.abs(pixels.width - Math.round(sizes.width * sizes.ratio)),
      Math.abs(pixels.height - Math.round(sizes.height * sizes.ratio))
    );
  }).toBeLessThanOrEqual(1);
}

test('loads the real engine, WebAssembly and game pack without scrolling', async ({ page }) => {
  const errors = watchErrors(page);
  const loaded = [];
  page.on('response', (response) => {
    if (/\.(wasm|pck)(?:$|\?)/.test(response.url())) loaded.push(response);
  });
  await page.goto('/');
  await ready(page);
  expect(loaded.some((response) => response.url().includes('.wasm') && response.ok())).toBe(true);
  expect(loaded.some((response) => response.url().endsWith('.pck.br') && response.ok())).toBe(true);
  await expect(page.locator('.card')).toHaveCount(0);
  await assertFits(page);
  expect(errors).toEqual([]);
});

test('real touch input selects and cancels a native Godot card', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  expect(errors).toEqual([]);
});

test('Xbox navigation, seasons and collection controls preserve the current round', async ({ page }) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.goto('/');
  await ready(page);
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  const selected = await page.locator('#selection-status').textContent();
  const background = await page.locator('meta[name="theme-color"]').getAttribute('content');
  await pressGamepad(page, 4);
  await expect(page.locator('meta[name="theme-color"]')).not.toHaveAttribute('content', background);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await pressGamepad(page, 5);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', background);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('Lv3');
  await pressGamepad(page, 9);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('Lv3');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await pressGamepad(page, 15);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).not.toHaveText(selected);
  await pressGamepad(page, 1);
  await page.evaluate(() => window.gamepadFixture.disconnect());
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  expect(errors).toEqual([]);
});

test('holding Xbox A across startup does not select an unseen native card', async ({ page }) => {
  const errors = watchErrors(page);
  await installGamepad(page, { connected: true, heldButtons: [0] });
  await page.goto('/');
  await ready(page);
  await page.waitForTimeout(200);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.evaluate(() => window.gamepadFixture.button(0, false));
  await page.waitForTimeout(120);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  expect(errors).toEqual([]);
});

test('orientation changes preserve selection and fit the resized canvas', async ({ page }) => {
  const errors = watchErrors(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await ready(page);
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  for (const viewport of [{ width: 844, height: 390 }, { width: 320, height: 320 }, { width: 834, height: 1194 }]) {
    await page.setViewportSize(viewport);
    await expect.poll(async () => (await canvasMetrics(page)).width).toBe(viewport.width);
    await assertFits(page);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  }
  expect(errors).toEqual([]);
});

async function chooseSeason(page, index) {
  await chooseTheme(page, index);
}

test('the first card interaction uses real browser audio or reports genuine missing audio support', async ({ page }) => {
  const errors = watchErrors(page);
  await observeAudio(page);
  await page.goto('/');
  await ready(page);
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (available) {
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(0);
    await expect.poll(() => page.evaluate(() =>
      window.audioObservation.contexts.some((context) => context.state === 'running'))).toBe(true);
    await expect(page.locator('#audio-status')).toBeEmpty();
  } else {
    await expect(page.locator('#audio-status')).toHaveText('Sound is not available in this browser.');
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  }
  expect(errors).toEqual([]);
});

test('bundled words and card input work offline immediately after readiness', async ({ page, context, browserName }) => {
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true });
  await page.goto('/');
  await ready(page);
  await context.setOffline(true);
  try {
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    const point = firstCard(await canvasMetrics(page));
    const before = await page.evaluate(() => window.audioObservation.playbacks.length);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
    const selected = await page.locator('#selection-status').textContent();
    const word = catalog.find(entry => entry.text === selected.split(': ')[1]);
    expect(word).toBeTruthy();
    if (available) {
      await expectRecording(page, before, word.audio);
      const select = await expectRecording(page, before, 'assets/audio/sfx/select.wav');
      expect(select.peak, 'The selected card has real PCM feedback').toBeGreaterThan(0.01);
      await expectOutputEnergy(page);
      await expect(page.locator('#audio-status')).toBeEmpty();
    }
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    await expect(page.locator('#selection-status')).toBeEmpty();
    expect(requests, 'All game audio is available from the loaded pack').toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('season colors and bundled music preserve selection while offline', async ({ page, context, browserName }) => {
  // Eight complete room/focus/back traversals can exceed the general 90-second
  // budget with Chromium's traced software renderer. Each audio assertion
  // retains its usual timeout while the full UI tour gets time to finish.
  test.setTimeout(150000);
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await observeOutputAudio(page, { trackSourceLifecycle: true });
  await page.goto('/');
  await ready(page);
  await context.setOffline(true);
  try {
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    const point = firstCard(await canvasMetrics(page));
    await page.touchscreen.tap(point.x, point.y);
    const selected = await page.locator('#selection-status').textContent();
    const themes = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
    for (const [index, theme] of themes.entries()) {
      const before = await page.evaluate(() => window.audioObservation.playbacks.length);
      await chooseSeason(page, index);
      await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
      await expect(page.locator('#game-status')).toHaveText('Now find its match!');
      await expect(page.locator('#selection-status')).toHaveText(selected);
      if (available) {
        // The first choice can already be the current world; inspect the live
        // source in that case instead of requiring an unnecessary restart.
        await expectRecording(page, index === 0 ? 0 : before, 'assets/audio/bgm/' + theme + '.wav', { active: true });
        await expectOutputEnergy(page);
      }
    }
    await assertFits(page);
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('missing browser audio support leaves card input and world selection usable', async ({ page }) => {
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
  });
  await page.goto('/');
  await ready(page);
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  const selected = await page.locator('#selection-status').textContent();
  await expect(page.locator('#audio-status')).toHaveText('Sound is not available in this browser.');
  await chooseSeason(page, 5);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  expect(requests).toEqual([]);
  expect(errors).toEqual([]);
});

test('motion preference changes do not restart the native round', async ({ page }) => {
  const errors = watchErrors(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const point = firstCard(await canvasMetrics(page));
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await assertFits(page);
  expect(errors).toEqual([]);
});

test('the exported game runs inside a normal website iframe', async ({ page }) => {
  const errors = watchErrors(page);
  await page.route('**/embed-test.html', (route) => route.fulfill({
    contentType: 'text/html',
    body: '<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}iframe{display:block;width:100%;height:100%;border:0}</style>' +
      '</head><body><iframe title="Grow with Pip" src="/" allow="autoplay; fullscreen"></iframe></body></html>'
  }));
  await page.goto('/embed-test.html');
  const frame = page.frameLocator('iframe');
  await ready(frame, false);
  await assertFits(frame);
  await page.locator('iframe').evaluate((element) => { element.style.height = '80%'; });
  await expect.poll(async () => (await canvasMetrics(frame)).height).toBeLessThan(page.viewportSize().height);
  await assertFits(frame);
  await expect(frame.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  expect(errors).toEqual([]);
});

test('a below-the-fold game does not steal the hosting page scroll position', async ({ page }) => {
  const errors = watchErrors(page);
  await page.addInitScript(() => {
    window.canvasFocusRequests = [];
    const focus = HTMLCanvasElement.prototype.focus;
    HTMLCanvasElement.prototype.focus = function (...args) {
      window.canvasFocusRequests.push(args[0]?.preventScroll === true);
      return focus.apply(this, args);
    };
  });
  await page.route('**/below-fold.html', (route) => route.fulfill({
    contentType: 'text/html',
    body: '<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<style>body{margin:0}section{height:150vh}iframe{display:block;width:100%;height:700px;border:0}</style>' +
      '</head><body><section>Content above the game</section><iframe title="Grow with Pip" src="/" allow="autoplay"></iframe></body></html>'
  }));
  await page.goto('/below-fold.html');
  const frame = page.frameLocator('iframe');
  await expect(frame.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  await expect(frame.locator('#enter-game')).toBeEnabled();
  await expect(frame.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  expect(await page.evaluate(() => window.scrollY)).toBe(0);
  // Scroll the host's iframe explicitly; a fixed child button cannot scroll its parent page.
  await page.locator('iframe').scrollIntoViewIfNeeded();
  const scrollBeforeEntry = await page.evaluate(() => window.scrollY);
  expect(scrollBeforeEntry).toBeGreaterThan(0);
  await ready(frame, false);
  const focusRequests = await frame.locator('#canvas').evaluate(() => window.canvasFocusRequests);
  expect(focusRequests.length).toBeGreaterThan(0);
  expect(focusRequests.every(Boolean)).toBe(true);
  expect(await page.evaluate(() => window.scrollY)).toBe(scrollBeforeEntry);
  expect(errors).toEqual([]);
});

async function discoverCards(page) {
  const metrics = await canvasMetrics(page);
  const discovered = new Map();
  for (let index = 0; index < 10; index++) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!discovered.has(word)) discovered.set(word, {});
    discovered.get(word)[kind] = index;
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  }
  return { metrics, discovered };
}

async function continueMatch(page, correct = true) {
  await expect(page.locator('#game-status')).toContainText(correct ? 'Great match!' : 'Not quite.');
  await page.mouse.move(0, 0);
  await page.keyboard.press('Escape');
}

async function holdChestUntilOpen(page, point) {
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    // Keep holding through slow rendered frames instead of releasing on the runner's clock.
    await expect(page.locator('#game-status')).toHaveText(/^(Chest opened! Ready for another adventure\?|A gift for Pip! .+ unlocked!)$/, { timeout: 15000 });
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).not.toContainText(/A new piece!|Medal complete!|All six collected!|Piece \d of 3|Tap to place!/);
}

async function winWithTouch(page, board) {
  const { metrics, discovered } = board ?? await discoverCards(page);
  const pairs = [...discovered.values()].filter(pair => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(5);
  for (let index = 0; index < pairs.length; index++) {
    for (const card of [pairs[index].Word, pairs[index].Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await continueMatch(page);
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word–picture pairs.');
  }
  await acceptCelebration(page);
  return metrics;
}

async function holdControllerChest(page) {
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  try {
    await expect(page.locator('#game-status')).toHaveText(/^(Chest opened! Ready for another adventure\?|A gift for Pip! .+ unlocked!)$/, { timeout: 15000 });
  } finally {
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    // Let the engine sample the release before another simulated A press.
    await page.waitForTimeout(120);
  }
  await expect(page.locator('#game-status')).not.toContainText(/A new piece!|Medal complete!|All six collected!|Piece \d of 3|Tap to place!/);
}

function rewardPieceTotal(saved) {
  return [...(saved || '').matchAll(/"([a-z]+-\d+)"\s*:\s*(\d+)/g)]
    .reduce((total, [, , count]) => total + Number(count), 0);
}

test('new adventures rotate after the chest is opened and growth navigation preserves its claim', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  const board = await discoverCards(page);
  const words = [...board.discovered.keys()];
  expect(words).toHaveLength(5);
  expect(words.every(text => catalog.find(word => word.text === text)?.min_age === 3)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('word-adventure.png'), scale: 'css' });
  await winWithTouch(page, board);
  await page.screenshot({ path: testInfo.outputPath('chest-before-opening.png'), scale: 'css' });

  const { metrics } = board;
  const unopened = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('Lv3');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(unopened);
  await holdChestUntilOpen(page, resultScreenPoint(metrics));
  await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?');
  await page.screenshot({ path: testInfo.outputPath('chest-after-opening.png'), scale: 'css' });
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('Find 5 word–picture pairs.');
  await ready(page);
  const nextBoard = await discoverCards(page);
  const nextWords = [...nextBoard.discovered.keys()];
  expect([...nextBoard.discovered.keys()].filter(word => words.includes(word))).toEqual([]);
  await assertFits(page);
  expect(errors).toEqual([]);
});

test('Pip follows the board and chest while growth preserves rewards without extra rewards', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  const bounds = await canvasMetrics(page);
  const greet = async point => {
    await rendered(page);
    await tap(page, point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Pip says hello!');
  };
  const boardPip = headerPoint(await logicalMetrics(page), 'pip');
  await tap(page, boardPip.x, boardPip.y);
  await expect(page.locator('#game-status')).toContainText('Game mode. Match is selected.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.screenshot({ path: testInfo.outputPath('pip-board.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Game mode menu closed.');
  await chooseSeason(page, 0);
  await winWithTouch(page);
  await greet(headerPoint(await logicalMetrics(page), 'pip'));
  await page.screenshot({ path: testInfo.outputPath('pip-chest.png'), scale: 'css' });
  await holdChestUntilOpen(page, resultScreenPoint(bounds));
  const earnedProgress = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await openRewards(page);
  await expect(page.locator('#game-status')).toContainText('Lv3');
  await page.screenshot({ path: testInfo.outputPath('pip-growth.png'), scale: 'css' });
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(earnedProgress);
  await page.keyboard.press('Escape');
  expect(errors).toEqual([]);
});

test('Pip speaks with bundled prompt playback while offline', async ({ page, context }) => {
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await installGamepad(page);
  await observeOutputAudio(page, { trackSourceLifecycle: true });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  test.skip(!await page.evaluate(() => window.audioObservation.available), 'This WebKit runtime has no audio output.');
  const bounds = await canvasMetrics(page);
  const scale = Math.min(bounds.width, bounds.height) / 480;
  const pip = pipHeaderRect(await logicalMetrics(page)), unit = pip.width / 54;
  const beak = { x: bounds.x + (pip.x + 16 * unit) * scale, y: bounds.y + (pip.y + 26 * unit) * scale,
    width: 32 * unit * scale, height: 15 * unit * scale };
  const resting = await page.screenshot({ clip: beak, scale: 'css' });
  await context.setOffline(true);
  try {
    await page.evaluate(() => window.gamepadFixture.connect());
    for (let index = 0; index < 8; index++) await pressGamepad(page, 5);
    const theme = await page.locator('html').getAttribute('data-pip-theme');
    await expectRecording(page, 0, 'assets/audio/voice/' + theme + '-theme.wav');
    await expectOutputEnergy(page);
    await expect.poll(async () => (await page.screenshot({ clip: beak, scale: 'css' })).equals(resting)).toBe(false);
    await expect.poll(async () => (await page.screenshot({ clip: beak, scale: 'css' })).equals(resting)).toBe(true);
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('three hints per round are shared by touch and Xbox', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const hint = headerPoint(await logicalMetrics(page), 'hint');
  const hintPoint = { x: metrics.x + hint.x * scale, y: metrics.y + hint.y * scale };
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const used = new Set();
  const firstHint = await page.locator('#game-status').textContent();
  const firstWord = firstHint.match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  const firstPair = discovered.get(firstWord);
  used.add(firstWord);
  expect(firstPair.Word).toBeDefined();
  expect(firstPair.Picture).toBeDefined();
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(firstHint);
  const twoLeft = await hintImage(page);
  await page.screenshot({ path: testInfo.outputPath('hint-direct.png'), scale: 'css' });
  await page.waitForTimeout(160);
  await page.screenshot({ path: testInfo.outputPath('hint-direct-next.png'), scale: 'css' });
  const pictureCenter = cardPoint(metrics, firstPair.Picture), wordCenter = cardPoint(metrics, firstPair.Word);
  // Sample the direct connection's midpoint, independently of board gutters or Pip's animation.
  const linkClip = { x: Math.round((pictureCenter.x + wordCenter.x) / 2 - 16),
    y: Math.round((pictureCenter.y + wordCenter.y) / 2 - 16), width: 32, height: 32 };
  const current = await page.screenshot({ path: testInfo.outputPath('hint-direct-before.png'), clip: linkClip, scale: 'css' });
  expect((await boltColors(page, current)).saturated, 'A saturated electric bolt visibly connects the hinted cards.').toBeGreaterThan(4);
  await expect.poll(async () => (await page.screenshot({
    path: testInfo.outputPath('hint-direct-after.png'), clip: linkClip, scale: 'css'
  })).equals(current), { timeout: 3000, intervals: [200], message: 'The direct electric bolt flickers between the hinted cards.' }).toBe(false);
  const initialTheme = THEME_COLORS.indexOf(await page.locator('meta[name="theme-color"]').getAttribute('content'));
  const initialSelection = await page.locator('#selection-status').textContent();
  const remainingHints = await hintImage(page, true);
  for (const [theme, index, color] of [['autumn', 2, 'warm'], ['ocean', 4, 'cool'], ['space', 5, 'purple'], ['candy', 7, 'pink']]) {
    await chooseSeason(page, index);
    await expect(page.locator('#game-status')).toHaveText(firstHint);
    await expect(page.locator('#selection-status')).toHaveText(initialSelection);
    expect((await hintImage(page, true)).equals(remainingHints), `${theme} preserves the remaining hint count.`).toBe(true);
    const themed = await page.screenshot({ path: testInfo.outputPath(`hint-theme-${theme}-bolt.png`), clip: linkClip, scale: 'css' });
    expect((await boltColors(page, themed))[color], `${theme} recolors the active bolt to its ${color} palette.`).toBeGreaterThan(4);
    await page.screenshot({ path: testInfo.outputPath(`hint-theme-${theme}.png`), scale: 'css' });
  }
  await chooseSeason(page, initialTheme);
  await expect(page.locator('#game-status')).toHaveText(firstHint);
  for (const index of [firstPair.Word, firstPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const secondHint = await page.locator('#game-status').textContent();
  const secondWord = secondHint.match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  const secondPair = discovered.get(secondWord);
  used.add(secondWord);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(secondHint);
  const oneLeft = await hintImage(page);
  expect(oneLeft.equals(twoLeft), 'The native digit badge changes from two remaining hints to one.').toBe(false);
  await page.screenshot({ path: testInfo.outputPath('hint-direct-second.png'), scale: 'css' });
  await page.waitForTimeout(160);
  await page.screenshot({ path: testInfo.outputPath('hint-direct-second-next.png'), scale: 'css' });
  for (const index of [secondPair.Word, secondPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await chooseSeason(page, 1);
  const beforeLastHint = await hintImage(page);
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const thirdHint = await page.locator('#game-status').textContent();
  const thirdWord = thirdHint.match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  const thirdPair = discovered.get(thirdWord);
  used.add(thirdWord);
  expect(used.size).toBe(3);
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(thirdHint);
  expect((await hintImage(page)).equals(beforeLastHint), 'The last hint visibly changes the native badge to zero.').toBe(false);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.screenshot({ path: testInfo.outputPath('hint-used.png'), scale: 'css' });
  for (const index of [thirdPair.Word, thirdPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  const exhausted = await page.locator('#game-status').textContent();
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status'), 'Three hints do not cover all five pairs, and exhausted hints cannot change the board.').toHaveText(exhausted);
  const remaining = [...discovered].filter(([word]) => !used.has(word));
  expect(remaining).toHaveLength(2);
  for (const [index, [, pair]] of remaining.entries()) {
    for (const card of [pair.Word, pair.Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await continueMatch(page);
    await expect(page.locator('#game-status')).toContainText(index === remaining.length - 1 ? 'You did it!' : 'Find 5 word–picture pairs.');
  }
  await holdControllerChest(page);
  await pressGamepad(page, 0);
  await ready(page);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  // Pip's static speech indicator can change when the hint recording ends.
  const top = contentBounds(await logicalMetrics(page)).top * scale;
  const boardClip = { x: metrics.x, y: metrics.y + top, width: metrics.width, height: metrics.height - top };
  const still = await page.screenshot({ clip: boardClip, scale: 'css' });
  await page.waitForTimeout(250);
  expect((await page.screenshot({ clip: boardClip, scale: 'css' })).equals(still), 'Reduced-motion hints stay visually still.').toBe(true);
  await pressGamepad(page, 0);
  const selected = await page.locator('#selection-status').textContent();
  await pressGamepad(page, 2);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await assertFits(page);
  expect(errors).toEqual([]);
});

for (const correct of [true, false]) {
test(`Hint remains available after ${correct ? 'correct' : 'wrong'} feedback`, async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const hint = headerPoint(await logicalMetrics(page), 'hint');
  const hintPoint = { x: metrics.x + hint.x * scale, y: metrics.y + hint.y * scale };
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const word = (await page.locator('#game-status').textContent()).match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  const pair = discovered.get(word);
  const picture = correct ? pair.Picture : [...discovered].find(([id, card]) => id !== word && card.Picture !== undefined)[1].Picture;
  for (const index of [pair.Word, picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText(correct ? 'Great match!' : 'Not quite.');
  const saved = await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('growWithPip.growth.v1')]);
  if (correct) {
    await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  } else {
    await page.evaluate(() => window.gamepadFixture.connect());
    await pressGamepad(page, 2);
  }
  await expect(page.locator('#game-status'), 'Hint must work directly from feedback without Escape or an extra card tap')
    .toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const hinted = await page.locator('#game-status').textContent();
  if (correct) expect(hinted).not.toBe(`Hint: match the ${word} cards.`);
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(hinted);
  expect(await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('growWithPip.growth.v1')])).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('next-hint-1.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  const nextWord = hinted.match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  await expect(page.locator('#selection-status')).toHaveText(new RegExp(`^(Word|Picture): ${nextWord}$`));
  expect(errors).toEqual([]);
});
}

test('keyboard hints focus a suggested card ready for Enter', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
  await chooseSeason(page, 0);
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const word = (await page.locator('#game-status').textContent()).match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(new RegExp(`^(Word|Picture): ${word}$`));
  await expect(page.locator('#canvas')).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  expect(errors).toEqual([]);
});

test('Match keeps the same board after repeated mistakes and finishes only when every pair is matched', async ({ page, context }, testInfo) => {
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  const board = await discoverCards(page);
  const { metrics, discovered } = board;
  await context.setOffline(true);
  try {
    const [word, card] = [...discovered].find(([, value]) => value.Word !== undefined);
    const [, other] = [...discovered].find(([text, value]) => text !== word && value.Picture !== undefined);
    for (let attempt = 0; attempt < 6; attempt++) {
      for (const index of [card.Word, other.Picture]) {
        const point = cardPoint(metrics, index);
        await page.touchscreen.tap(point.x, point.y);
      }
      await continueMatch(page, false);
      await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    }
    expect([...(await discoverCards(page)).discovered]).toEqual([...discovered]);
    await page.evaluate(() => window.gamepadFixture.connect());
    await pressGamepad(page, 2);
    await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
    await page.screenshot({ path: testInfo.outputPath('match-unlimited-retries.png'), scale: 'css' });
    await winWithTouch(page, board);
    await expect(page.locator('#game-status')).toContainText('You did it!');
    await assertFits(page);
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('fresh adventures save exactly one chest reward per round and preserve progress', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  await page.evaluate(() => window.gamepadFixture.connect());
  await chooseSeason(page, 0);
  const background = await page.locator('meta[name="theme-color"]').getAttribute('content');
  let previousWords = [];
  for (let round = 0; round < 4; round++) {
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', background);
    const board = await discoverCards(page);
    const words = [...board.discovered.keys()];
    if (previousWords.length) expect([...words].sort()).not.toEqual([...previousWords].sort());
    previousWords = words;
    await winWithTouch(page, board);
    await holdControllerChest(page);
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?');
    await pressGamepad(page, 3);
    expect((await growthView(page)).visible).toBe(true);
    const progress = await rewardState(page);
    expect(progress.medals).toMatch(new RegExp(`"spring-1"\\s*:\\s*${Math.min(round + 1, 3)}`));
    if (round === 3) expect(progress.medals).toMatch(/"spring-2"\s*:\s*1/);
    await page.screenshot({ path: testInfo.outputPath(`season-goal-${round + 1}.png`), scale: 'css' });
    await pressGamepad(page, 1);
    if (round < 3) {
      await pressGamepad(page, 0);
      await ready(page);
    }
  }
  await page.reload();
  await ready(page);
  await chooseSeason(page, 0);
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 3);
  expect((await growthView(page)).visible).toBe(true);
  const restored = await rewardState(page);
  expect(restored.medals).toMatch(/"spring-1"\s*:\s*3/);
  expect(restored.medals).toMatch(/"spring-2"\s*:\s*1/);
  await activateGrowthControl(page, 'GrowthAge4');
  expect((await rewardState(page)).medals).toBe(restored.medals);
  expect(errors).toEqual([]);
});

for (const input of ['Space', 'Enter', 'Xbox A']) {
  test(`${input} chest hold cancels during opening and a fresh hold saves one piece`, async ({ page }) => {
    const errors = watchErrors(page), controller = input === 'Xbox A';
    if (controller) await installGamepad(page);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/');
    await ready(page);
    await winWithTouch(page);
    if (controller) await page.evaluate(() => window.gamepadFixture.connect());
    const before = (await rewardState(page)).medals, progress = page.locator('#chest-progress');
    const hold = () => controller
      ? page.evaluate(() => window.gamepadFixture.button(0, true)) : page.keyboard.down(input);
    const release = () => controller
      ? page.evaluate(() => window.gamepadFixture.button(0, false)) : page.keyboard.up(input);

    await hold();
    try {
      // Release after the initial hold has entered the moving opening sequence.
      await expect(progress).toHaveAttribute('data-phase', 'building', { timeout: 5000 });
    } finally {
      await release();
    }
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
    expect((await rewardState(page)).medals).toBe(before);
    // Cross the original completion deadline before starting another attempt.
    await page.waitForTimeout(4100);
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
    expect((await rewardState(page)).medals).toBe(before);

    await hold();
    try {
      await expect(progress).toHaveAttribute('data-phase', 'release', { timeout: 7000 });
    } finally {
      await release();
    }
    expect((await rewardState(page)).medals, 'Releasing at the flash precedes the final reward save').toBe(before);
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
    const saved = (await rewardState(page)).medals;
    expect(rewardPieceTotal(saved)).toBe(rewardPieceTotal(before) + 1);
    await expect(progress).toHaveAttribute('hidden', '');
    await page.waitForTimeout(300);
    expect((await rewardState(page)).medals).toBe(saved);
    expect(errors).toEqual([]);
  });
}

test('held touch cancels before the flash and releasing at the flash saves one piece', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'Trusted held touch uses Chromium CDP.');
  const errors = watchErrors(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await ready(page);
  const chest = resultScreenPoint(await winWithTouch(page));
  const before = (await rewardState(page)).medals, progress = page.locator('#chest-progress');
  await page.evaluate(() => {
    window.chestTouchReleases = [];
    window.addEventListener('touchend', event => {
      window.chestTouchReleases.push({
        trusted: event.isTrusted,
        phase: document.getElementById('chest-progress').getAttribute('data-phase'),
        saved: localStorage.getItem('wordBuddies.medalProgress') || ''
      });
    }, true);
  });
  const client = await page.context().newCDPSession(page);
  const hold = () => client.send('Input.dispatchTouchEvent', {
    type: 'touchStart', touchPoints: [{ id: 1, ...chest }]
  });
  const release = () => client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  try {
    await hold();
    try {
      await expect(progress).toHaveAttribute('data-phase', 'building', { timeout: 5000 });
    } finally {
      await release();
    }
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
    expect((await rewardState(page)).medals).toBe(before);
    await page.waitForTimeout(4100);
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
    expect((await rewardState(page)).medals).toBe(before);

    await hold();
    try {
      await expect(progress).toHaveAttribute('data-phase', 'release', { timeout: 7000 });
    } finally {
      await release();
    }
    const releases = await page.evaluate(() => window.chestTouchReleases);
    expect(releases).toHaveLength(2);
    expect(releases[1], 'The real touch ends at the flash before the reward is saved').toEqual({
      trusted: true, phase: 'release', saved: before
    });
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
    const saved = (await rewardState(page)).medals;
    expect(rewardPieceTotal(saved)).toBe(rewardPieceTotal(before) + 1);
    await expect(progress).toHaveAttribute('hidden', '');
    await page.waitForTimeout(300);
    expect((await rewardState(page)).medals).toBe(saved);
    expect(errors).toEqual([]);
  } finally {
    await client.detach();
  }
});

test('Xbox chest opening cancels on disconnect and works again after reconnect', async ({ page }) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await ready(page);
  await winWithTouch(page);
  const before = (await rewardState(page)).medals, progress = page.locator('#chest-progress');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await expect(progress).toHaveAttribute('data-phase', 'building', { timeout: 5000 });
  await page.evaluate(() => window.gamepadFixture.disconnect());
  await expect(progress).toHaveAttribute('hidden', '');
  await expect(progress).toHaveAttribute('aria-valuenow', '0');
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  expect((await rewardState(page)).medals).toBe(before);
  await page.waitForTimeout(4100);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  expect((await rewardState(page)).medals).toBe(before);
  await page.evaluate(() => window.gamepadFixture.connect());
  await holdControllerChest(page);
  const saved = (await rewardState(page)).medals;
  expect(rewardPieceTotal(saved)).toBe(rewardPieceTotal(before) + 1);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  expect((await rewardState(page)).medals).toBe(saved);
  expect(errors).toEqual([]);
});

test('completes matches and opens a one-shot reward with bundled audio offline', async ({ page, context }) => {
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 2 });
  await page.goto('/');
  await ready(page);
  await context.setOffline(true);
  try {
    const beforeReward = rewardPieceTotal((await rewardState(page)).medals);
    const { metrics, discovered } = await discoverCards(page);
    const pairs = [...discovered.values()].filter((pair) => pair.Word !== undefined && pair.Picture !== undefined);
    expect(pairs).toHaveLength(5);
    for (let index = 0; index < pairs.length; index++) {
      for (const card of [pairs[index].Word, pairs[index].Picture]) {
        const point = cardPoint(metrics, card);
        await page.touchscreen.tap(point.x, point.y);
      }
      await continueMatch(page);
      await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word–picture pairs.');
    }
    const chestPoint = resultScreenPoint(metrics);
    const beforeChest = await page.evaluate(() => window.audioObservation.playbacks.length);
    await holdChestUntilOpen(page, chestPoint);
    const earned = await page.locator('#game-status').textContent();
    const saved = (await rewardState(page)).medals;
    expect(rewardPieceTotal(saved)).toBe(beforeReward + 1);
    await page.mouse.down();
    await page.waitForTimeout(1300);
    await page.mouse.up();
    await expect(page.locator('#game-status')).toHaveText(earned);
    expect((await rewardState(page)).medals).toBe(saved);
    if (await page.evaluate(() => window.audioObservation.available)) {
      const reward = await expectRecording(page, beforeChest, 'assets/imported-audio/chest-reference/reward.wav');
      expect(reward.peak).toBeGreaterThan(0.01);
      await expect(page.locator('#audio-status')).toBeEmpty();
    }
    await assertFits(page);
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('dragging the reward chest cancels hold-open without losing pointer control', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const pairs = [...discovered.values()].filter((pair) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(5);
  for (let index = 0; index < pairs.length; index++) {
    for (const card of [pairs[index].Word, pairs[index].Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await continueMatch(page);
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word–picture pairs.');
  }
  const chestPoint = resultScreenPoint(metrics);
  await page.mouse.move(chestPoint.x, chestPoint.y);
  await page.mouse.down();
  await page.mouse.move(chestPoint.x + 28, chestPoint.y + 12, { steps: 4 });
  await page.waitForTimeout(1300);
  await page.mouse.up();
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await holdChestUntilOpen(page, chestPoint);
  expect(errors).toEqual([]);
});

test('completed Match visibly reveals a bottom-right New adventure after opening the chest on a phone', async ({ page }, testInfo) => {
    const errors = watchErrors(page);
    await page.setViewportSize({ width: 390, height: 650 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await ready(page);
    await chooseSeason(page, 1);
    await winWithTouch(page);
    await page.screenshot({ path: testInfo.outputPath('result-match-closed-phone.png'), scale: 'css' });
    await holdChestUntilOpen(page, resultScreenPoint(await canvasMetrics(page)));
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const metrics = await canvasMetrics(page);
    const scale = Math.min(metrics.width, metrics.height) / 480;
    const action = resultPoint(await logicalMetrics(page), 'newAdventure');
    const next = { x: metrics.x + action.x * scale, y: metrics.y + action.y * scale };
    const screenshot = await page.screenshot({ path: testInfo.outputPath('result-match-complete.png'), scale: 'css' });
    const pixel = await page.evaluate(async ({ encoded, point }) => {
      const image = new Image();
      image.src = 'data:image/png;base64,' + encoded;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return [...context.getImageData(Math.round(point.x), Math.round(point.y), 1, 1).data].slice(0, 3);
    }, { encoded: screenshot.toString('base64'), point: { x: next.x, y: next.y - 20 } });
    expect(pixel, 'The filled New adventure button must render, not just accept invisible input.').toEqual([185, 69, 69]);
    await page.touchscreen.tap(next.x, next.y);
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    expect(errors).toEqual([]);
});

test('a failed WebAssembly download shows an English error and retry control', async ({ page }) => {
  await page.route('**/*.wasm', (route) => route.abort());
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
});

test('a missing engine script shows an English startup error', async ({ page }) => {
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, (route) => route.abort());
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
});

test('a corrupt WebAssembly response does not leave the loader pending', async ({ page }) => {
  await page.route('**/*.wasm', (route) => route.fulfill({
    contentType: 'application/wasm', body: 'not a WebAssembly module'
  }));
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
});

test('a failed game pack download shows an English startup error', async ({ page }) => {
  await page.route('**/*.pck.br', (route) => route.abort());
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
});

test('invalid game pack contents report the native startup exit', async ({ page }) => {
  await page.route('**/*.pck.br', (route) => route.fulfill({
    contentType: 'application/octet-stream', body: 'not a Godot game pack'
  }));
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
});
