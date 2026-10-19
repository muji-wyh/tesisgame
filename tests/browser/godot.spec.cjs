const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording, recordingTiming } = require('./bundled-audio.cjs');
const catalog = require('../../words.json');
const { metrics: logicalMetrics, tap, chooseMode, openRewards, enterGame, openModeMenu, activateLibraryControl,
  contentBounds, headerPoint, rendered, observeAudio, boardPoint, resultPoint, growthView, activateGrowthControl, rewardState, acceptCelebration } = require('./game-ui.cjs');
const learningThemes = require('../../data/professional/themes.json').profiles;
const growthTheme = learningThemes.find(profile => profile.id === 'growth_garden');

test.beforeEach(async ({ page }) => {
  // The chest interaction cases start after two saved dry rounds. The runtime
  // still reserves, earns and claims the guaranteed first chest normally.
  await page.addInitScript(() => {
    if (localStorage.getItem('wordBuddies.medalProgress') === null) localStorage.setItem('wordBuddies.medalProgress',
      '[medals]\nversion=1\ncounts={}\n[pair_chests]\nversion=1\nstate={"match":{"dry_rounds":2,"round":{}},"memory":{"dry_rounds":0,"round":{}}}\n');
  });
});

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
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height,
      library: JSON.parse(document.getElementById('game-status').dataset.library || '{}'),
      growth: JSON.parse(document.getElementById('growth-status').dataset.view || '{}') };
  });
}

function cardPoint(metrics, index) {
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const point = boardPoint({ width: metrics.width / scale, height: metrics.height / scale, scale,
    library: metrics.library, growth: metrics.growth }, index);
  return { x: metrics.x + point.x * scale, y: metrics.y + point.y * scale };
}

function resultScreenPoint(metrics, key = 'chest') {
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const point = resultPoint({ width: metrics.width / scale, height: metrics.height / scale, scale,
    library: metrics.library, growth: metrics.growth }, key);
  return { x: metrics.x + point.x * scale, y: metrics.y + point.y * scale };
}

const firstCard = (metrics) => cardPoint(metrics, 0);

const HINT_WALLET_KEY = 'growWithPip.coinWallet.v1';
const MATCH_HINT_STATUS = /^(?:(?:You found a hidden treasure chest!|No chest this pair\.) )?Hint: match the ([a-z]+) cards\.$/;

async function fundMatchHints(page, balance) {
  await page.addInitScript(({ key, balance }) => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify({ 'match-hint-browser-opening-coins': balance })}\n`);
  }, { key: HINT_WALLET_KEY, balance });
}

async function matchHintWallet(page) {
  return page.evaluate(key => {
    const text = localStorage.getItem(key);
    return { text, balance: Number(text.match(/^balance\s*=\s*(\d+)/m)[1]),
      receipts: JSON.parse(text.match(/^receipts\s*=\s*(\{[\s\S]*\})\s*$/m)[1]) };
  }, HINT_WALLET_KEY);
}

async function matchHintState(page) {
  return (await logicalMetrics(page)).growth.match.hint;
}

async function expectMatchHintPrice(page) {
  await expect.poll(async () => Boolean((await logicalMetrics(page)).growth.match?.hint)).toBe(true);
  const bounds = await logicalMetrics(page), state = bounds.growth.match.hint;
  const button = bounds.growth.controls.find(control => control.name === 'Hint' && control.visible);
  expect(button, 'The priced hint stays visible in the Match header').toBeTruthy();
  const expectedPrice = [100, 150, 200][Math.min(state.uses, 2)];
  expect(state).toMatchObject({ price: expectedPrice, price_text: String(expectedPrice) });
  const [x, y, width, height] = button.rect;
  const [px, py, pw, ph] = state.price_rect;
  expect([x, y, width, height, px, py, pw, ph].every(Number.isFinite)).toBe(true);
  expect(x).toBeGreaterThanOrEqual(-0.5);
  expect(y).toBeGreaterThanOrEqual(-0.5);
  expect(x + width).toBeLessThanOrEqual(bounds.width + 0.5);
  expect(y + height).toBeLessThanOrEqual(bounds.height + 0.5);
  expect(px).toBeGreaterThanOrEqual(x - 0.5);
  expect(py).toBeGreaterThanOrEqual(y - 0.5);
  expect(px + pw).toBeLessThanOrEqual(x + width + 0.5);
  expect(py + ph).toBeLessThanOrEqual(y + height + 0.5);
  expect(Math.min(width, height) * bounds.scale, 'The priced hint retains a usable touch target').toBeGreaterThanOrEqual(43.5);
  expect(pw).toBeGreaterThan(0);
  expect(ph * bounds.scale, 'The next hint price fits at a readable display height').toBeGreaterThanOrEqual(11.5);
  return state;
}

async function buyMatchHint(page, activate) {
  const previousHint = await expectMatchHintPrice(page);
  const before = await matchHintWallet(page);
  await activate();
  await expect(page.locator('#game-status')).toHaveText(MATCH_HINT_STATUS);
  await expect.poll(async () => (await matchHintWallet(page)).balance,
    { message: 'Each accepted Match hint deducts its displayed price' }).toBe(before.balance - previousHint.price);
  const after = await matchHintWallet(page);
  const receipts = Object.entries(after.receipts).filter(([id]) => !Object.hasOwn(before.receipts, id));
  expect(receipts.map(([, amount]) => amount), 'One accepted hint saves one debit at its quoted price').toEqual([-previousHint.price]);
  expect(Object.entries(before.receipts).every(([id, amount]) => after.receipts[id] === amount),
    'Hint purchases preserve earlier wallet receipts').toBe(true);
  expect(receipts[0][0]).toBe(`${previousHint.round_id}:match-hint:${previousHint.uses + 1}`);
  await expect.poll(async () => (await matchHintState(page)).uses).toBe(previousHint.uses + 1);
  const nextPrice = [100, 150, 200][Math.min(previousHint.uses + 1, 2)];
  expect(await matchHintState(page)).toMatchObject({ price: nextPrice, price_text: String(nextPrice),
    active: true, round_id: previousHint.round_id });
  await expect.poll(async () => page.locator('#coin-status').evaluate(node =>
    JSON.parse(node.dataset.snapshot || '{}').balance)).toBe(after.balance);
  return after;
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

test('Xbox navigation and collection controls preserve the current round and automatic palette', async ({ page }) => {
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
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', background);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await pressGamepad(page, 5);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', background);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('Lv0');
  await pressGamepad(page, 9);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('Lv0');
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

async function previewCareer(page, career) {
  await openModeMenu(page);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'ProfessionalPath');
  await activateLibraryControl(page, `Career_${career}`);
  await expect.poll(async () => (await logicalMetrics(page)).library.learning.course_id).toBe(career);
  const theme = learningThemes.find(profile => profile.course_id === career);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', theme.palette.background.toLowerCase());
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(theme.palette.accent.toLowerCase());
}

async function continueGrowthRound(page) {
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await logicalMetrics(page)).library.visible).toBe(false);
  expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', growthTheme.palette.background.toLowerCase());
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

test('automatic career colors and bundled music preserve selection while offline', async ({ page, context, browserName }) => {
  test.setTimeout(240000);
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
    for (const career of ['caregiving', 'retail', 'food_service']) {
      await previewCareer(page, career);
      if (available) {
        // A career preview preserves the paused round's existing music source.
        await expectRecording(page, 0, growthTheme.audio.music.replace('res://', ''), { active: true });
        await expectOutputEnergy(page);
      }
      await continueGrowthRound(page);
      await expect(page.locator('#game-status')).toHaveText('Now find its match!');
      await expect(page.locator('#selection-status')).toHaveText(selected);
      if (available) {
        await expectRecording(page, 0, growthTheme.audio.music.replace('res://', ''), { active: true });
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

test('missing browser audio support leaves card input and career browsing usable', async ({ page }) => {
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
  await previewCareer(page, 'retail');
  await continueGrowthRound(page);
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
    await expect(page.locator('#game-status')).toHaveText(/^Round complete Treasure collected!$/, { timeout: 15000 });
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
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? /You did it!|Round complete/ : 'Find 5 word–picture pairs.');
  }
  await acceptCelebration(page);
  return await canvasMetrics(page);
}

async function holdControllerChest(page) {
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  try {
    await expect(page.locator('#game-status')).toHaveText(/^Round complete Treasure collected!$/, { timeout: 15000 });
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

function rewardCounts(saved) {
  return JSON.parse(saved.match(/^counts=(\{.*\})$/m)?.[1] || '{}');
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
  expect((await growthView(page)).visible, 'The settlement blocks the underlying catalog shortcut.').toBe(false);
  expect((await logicalMetrics(page)).growth.settlement.visible).toBe(true);
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(unopened);
  await holdChestUntilOpen(page, resultScreenPoint(await canvasMetrics(page)));
  await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!');
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
  await greet(boardPip);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.screenshot({ path: testInfo.outputPath('pip-board.png'), scale: 'css' });
  expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
  await winWithTouch(page);
  const coveredPip = headerPoint(await logicalMetrics(page), 'pip');
  await tap(page, coveredPip.x, coveredPip.y);
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  await page.screenshot({ path: testInfo.outputPath('pip-chest.png'), scale: 'css' });
  await holdChestUntilOpen(page, resultScreenPoint(await canvasMetrics(page)));
  const earnedProgress = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await openRewards(page);
  await expect(page.locator('#game-status')).toContainText('Lv0');
  await page.screenshot({ path: testInfo.outputPath('pip-growth.png'), scale: 'css' });
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(earnedProgress);
  await page.keyboard.press('Escape');
  expect(errors).toEqual([]);
});

test('career previews keep bundled music audible offline without Pip welcome narration', async ({ page, context }) => {
  test.setTimeout(240000);
  const errors = watchErrors(page), requests = watchAudioRequests(page);
  await installGamepad(page);
  await observeOutputAudio(page, { trackSourceLifecycle: true, fingerprintBuffers: true });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  test.skip(!await page.evaluate(() => window.audioObservation.available), 'This WebKit runtime has no audio output.');
  await context.setOffline(true);
  try {
    await page.evaluate(() => window.gamepadFixture.connect());
    for (const career of ['caregiving', 'retail', 'food_service']) {
      const previousTheme = await page.locator('html').getAttribute('data-pip-theme');
      const before = await page.evaluate(() => window.audioObservation.playbacks.length);
      await previewCareer(page, career);
      await continueGrowthRound(page);
      await expect(page.locator('html')).toHaveAttribute('data-pip-theme', previousTheme);
      await expectRecording(page, 0, growthTheme.audio.music.replace('res://', ''), { active: true });
      const click = await expectRecording(page, before, 'assets/imported-audio/ui-click/select.wav');
      expect(click.fingerprint).toBeTruthy();
      expect(click.peak, 'Interface feedback contains real audible PCM').toBeGreaterThan(0.01);
      await expectOutputEnergy(page);
      const allowed = [growthTheme.audio.music.replace('res://', ''), 'assets/imported-audio/ui-click/select.wav'].map(recordingTiming);
      const played = await page.evaluate(from => window.audioObservation.playbacks.slice(from), before);
      expect(played.every(sound => allowed.some(timing =>
        Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate)),
      'Career browsing plays only bundled music and interface clicks, without a Pip welcome or other narration.').toBe(true);
    }
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('paid hints have no round limit across touch and Xbox', async ({ page }, testInfo) => {
  // Buy a hint for all five pairs, preserve purchases across career previews, then reset the next round's price.
  test.setTimeout(240000);
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await fundMatchHints(page, 1200);
  await page.addInitScript(() => localStorage.setItem('wordBuddies.medalProgress',
    '[medals]\nversion=1\ncounts={}\n[pair_chests]\nversion=1\nstate={"match":{"dry_rounds":2,"round":{}},"memory":{"dry_rounds":0,"round":{}}}\n'));
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const hint = headerPoint(await logicalMetrics(page), 'hint');
  const hintPoint = { x: metrics.x + hint.x * scale, y: metrics.y + hint.y * scale };
  const firstPurchase = await buyMatchHint(page, () => page.touchscreen.tap(hintPoint.x, hintPoint.y));
  const used = new Set();
  const firstHint = await page.locator('#game-status').textContent();
  const firstWord = firstHint.match(MATCH_HINT_STATUS)[1];
  const firstPair = discovered.get(firstWord);
  used.add(firstWord);
  expect(firstPair.Word).toBeDefined();
  expect(firstPair.Picture).toBeDefined();
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(firstHint);
  expect(await matchHintWallet(page), 'Tapping an active hint cannot charge again').toEqual(firstPurchase);
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
  const initialSelection = await page.locator('#selection-status').textContent();
  const paidHint = await matchHintState(page);
  for (const career of ['caregiving', 'retail', 'food_service']) {
    await previewCareer(page, career);
    await continueGrowthRound(page);
    await expect(page.locator('#game-status')).toHaveText(firstHint);
    await expect(page.locator('#selection-status')).toHaveText(initialSelection);
    expect(await matchHintState(page), `${career} browsing preserves the paid hint and its next price.`)
      .toMatchObject({ uses: paidHint.uses, price: paidHint.price, active: true, round_id: paidHint.round_id });
    const resumed = await page.screenshot({ path: testInfo.outputPath(`hint-after-${career}-bolt.png`), clip: linkClip, scale: 'css' });
    expect((await boltColors(page, resumed)).saturated, 'The resumed hint still visibly connects the same cards.').toBeGreaterThan(4);
    await page.screenshot({ path: testInfo.outputPath(`hint-after-${career}.png`), scale: 'css' });
  }
  await expect(page.locator('#game-status')).toHaveText(firstHint);
  expect(await matchHintWallet(page), 'Browsing careers preserves the purchased hint and its receipt').toEqual(firstPurchase);
  for (const index of [firstPair.Word, firstPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await page.evaluate(() => window.gamepadFixture.connect());
  const secondPurchase = await buyMatchHint(page, () => pressGamepad(page, 2));
  const secondHint = await page.locator('#game-status').textContent();
  const secondWord = secondHint.match(MATCH_HINT_STATUS)[1];
  const secondPair = discovered.get(secondWord);
  used.add(secondWord);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(secondHint);
  expect(await matchHintWallet(page), 'Repeating Xbox X on an active hint cannot charge again').toEqual(secondPurchase);
  await page.screenshot({ path: testInfo.outputPath('hint-direct-second.png'), scale: 'css' });
  await page.waitForTimeout(160);
  await page.screenshot({ path: testInfo.outputPath('hint-direct-second-next.png'), scale: 'css' });
  for (const index of [secondPair.Word, secondPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await previewCareer(page, 'retail');
  await continueGrowthRound(page);
  const thirdPurchase = await buyMatchHint(page, () => page.touchscreen.tap(hintPoint.x, hintPoint.y));
  const thirdHint = await page.locator('#game-status').textContent();
  const thirdWord = thirdHint.match(MATCH_HINT_STATUS)[1];
  const thirdPair = discovered.get(thirdWord);
  used.add(thirdWord);
  expect(used.size).toBe(3);
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(thirdHint);
  expect(await matchHintWallet(page), 'Repeating an active third hint cannot save another debit').toEqual(thirdPurchase);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.screenshot({ path: testInfo.outputPath('hint-third.png'), scale: 'css' });
  for (const index of [thirdPair.Word, thirdPair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await continueMatch(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  for (const ordinal of [4, 5]) {
    const activate = ordinal === 4 ? () => pressGamepad(page, 2)
      : () => page.touchscreen.tap(hintPoint.x, hintPoint.y);
    const purchase = await buyMatchHint(page, activate);
    const status = await page.locator('#game-status').textContent();
    const word = status.match(MATCH_HINT_STATUS)[1];
    expect(used.has(word), `Purchase ${ordinal} hints an unmatched pair`).toBe(false);
    used.add(word);
    expect(await matchHintState(page)).toMatchObject({ uses: ordinal, price: 200, active: true });
    await activate();
    await expect(page.locator('#game-status')).toHaveText(status);
    expect(await matchHintWallet(page), `Repeated input on hint ${ordinal} cannot debit again`).toEqual(purchase);
    await page.screenshot({ path: testInfo.outputPath(`hint-${ordinal}.png`), scale: 'css' });
    const pair = discovered.get(word);
    for (const card of [pair.Word, pair.Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await continueMatch(page);
    await expect(page.locator('#game-status')).toContainText(ordinal === 5 ? /You did it!|Round complete/ : 'Find 5 word–picture pairs.');
  }
  expect(used.size).toBe(5);
  await acceptCelebration(page);
  await holdControllerChest(page);
  await pressGamepad(page, 0);
  await ready(page);
  const newRoundPurchase = await buyMatchHint(page, () => pressGamepad(page, 2));
  expect(Object.values(newRoundPurchase.receipts).filter(amount => amount < 0).sort((a, b) => a - b))
    .toEqual([-200, -200, -200, -150, -100, -100]);
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
  expect(await matchHintWallet(page), 'An active hint remains paid once even with a card selected').toEqual(newRoundPurchase);
  await assertFits(page);
  expect(errors).toEqual([]);
});

for (const correct of [true, false]) {
test(`Hint remains available after ${correct ? 'correct' : 'wrong'} feedback`, async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await fundMatchHints(page, 400);
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const hint = headerPoint(await logicalMetrics(page), 'hint');
  const hintPoint = { x: metrics.x + hint.x * scale, y: metrics.y + hint.y * scale };
  await buyMatchHint(page, () => page.touchscreen.tap(hintPoint.x, hintPoint.y));
  const word = (await page.locator('#game-status').textContent()).match(MATCH_HINT_STATUS)[1];
  const pair = discovered.get(word);
  const picture = correct ? pair.Picture : [...discovered].find(([id, card]) => id !== word && card.Picture !== undefined)[1].Picture;
  for (const index of [pair.Word, picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText(correct ? 'Great match!' : 'Not quite.');
  const saved = await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('growWithPip.growth.v1')]);
  if (!correct) await page.evaluate(() => window.gamepadFixture.connect());
  const feedbackPurchase = await buyMatchHint(page, () => correct
    ? page.touchscreen.tap(hintPoint.x, hintPoint.y) : pressGamepad(page, 2));
  await expect(page.locator('#game-status'), 'Hint must work directly from feedback without Escape or an extra card tap')
    .toHaveText(MATCH_HINT_STATUS);
  const hinted = await page.locator('#game-status').textContent();
  if (correct) expect(hinted.match(MATCH_HINT_STATUS)[1]).not.toBe(word);
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(hinted);
  expect(await matchHintWallet(page), 'A repeated hint from feedback cannot charge twice').toEqual(feedbackPurchase);
  expect(await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('growWithPip.growth.v1')])).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('next-hint-1.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  const nextWord = hinted.match(MATCH_HINT_STATUS)[1];
  await expect(page.locator('#selection-status')).toHaveText(new RegExp(`^(Word|Picture): ${nextWord}$`));
  expect(errors).toEqual([]);
});
}

test('keyboard hints focus a suggested card ready for Enter', async ({ page }) => {
  const errors = watchErrors(page);
  await fundMatchHints(page, 200);
  await page.goto('/');
  await ready(page);
  expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
  await page.keyboard.press('Shift+Tab');
  await buyMatchHint(page, () => page.keyboard.press('Enter'));
  const word = (await page.locator('#game-status').textContent()).match(MATCH_HINT_STATUS)[1];
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
  await fundMatchHints(page, 200);
  await page.addInitScript(() => localStorage.setItem('wordBuddies.medalProgress',
    '[medals]\nversion=1\ncounts={}\n[pair_chests]\nversion=1\nstate={"match":{"dry_rounds":2,"round":{}},"memory":{"dry_rounds":0,"round":{}}}\n'));
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
    await buyMatchHint(page, () => pressGamepad(page, 2));
    await page.screenshot({ path: testInfo.outputPath('match-unlimited-retries.png'), scale: 'css' });
    await winWithTouch(page, board);
    await expect(page.locator('#game-status')).toContainText(/You did it!|Round complete/);
    await assertFits(page);
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await context.setOffline(false);
  }
});

test('fresh adventures save at most one chest per round, honor pity and preserve earned progress', async ({ page }, testInfo) => {
  test.setTimeout(480000);
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  await page.evaluate(() => window.gamepadFixture.connect());
  expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
  const background = await page.locator('meta[name="theme-color"]').getAttribute('content');
  let previousWords = [];
  let earned = 0, dryRounds = 2, savedProgress;
  for (let round = 0; round < 4; round++) {
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', background);
    const board = await discoverCards(page);
    const words = [...board.discovered.keys()];
    if (previousWords.length) expect([...words].sort()).not.toEqual([...previousWords].sort());
    previousWords = words;
    await winWithTouch(page, board);
    const hasChest = (await logicalMetrics(page)).growth.result.controls
      .some(control => control.name === 'OpenSettlementChest' && control.visible && !control.disabled);
    if (dryRounds === 2) expect(hasChest, 'Two completed dry rounds guarantee the next chest').toBe(true);
    if (hasChest) {
      await holdControllerChest(page);
      await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!');
      earned++;
      dryRounds = 0;
    } else dryRounds++;
    await pressGamepad(page, 3);
    expect((await growthView(page)).visible, 'Settlement blocks the covered growth shortcut.').toBe(false);
    expect((await logicalMetrics(page)).growth.settlement.visible).toBe(true);
    await openRewards(page);
    expect((await growthView(page)).visible).toBe(true);
    const progress = await rewardState(page);
    expect(rewardPieceTotal(progress.medals), 'Every round saves exactly its earned chest, without duplication').toBe(earned);
    savedProgress = rewardCounts(progress.medals);
    await page.screenshot({ path: testInfo.outputPath(`growth-rewards-${round + 1}.png`), scale: 'css' });
    await pressGamepad(page, 1);
    expect((await logicalMetrics(page)).library.visible).toBe(true);
    await chooseMode(page, 'match');
    await expect(page.locator('#game-status')).toHaveText('Find 5 word–picture pairs.');
    expect(rewardCounts((await rewardState(page)).medals)).toEqual(savedProgress);
  }
  expect(earned, 'Four rounds with the initial pity guarantee include an earned chest').toBeGreaterThan(0);
  await page.reload();
  await ready(page);
  expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 3);
  expect((await growthView(page)).visible).toBe(true);
  const restored = await rewardState(page);
  expect(rewardCounts(restored.medals)).toEqual(savedProgress);
  expect(rewardPieceTotal(restored.medals)).toBe(earned);
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
    await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
    expect((await rewardState(page)).medals).toBe(before);
    // Cross the original completion deadline before starting another attempt.
    await page.waitForTimeout(4100);
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
    expect((await rewardState(page)).medals).toBe(before);

    await hold();
    try {
      await expect(progress).toHaveAttribute('data-phase', 'release', { timeout: 7000 });
    } finally {
      await release();
    }
    expect((await rewardState(page)).medals, 'Releasing at the flash precedes the final reward save').toBe(before);
    await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!', { timeout: 15000 });
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
    await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
    expect((await rewardState(page)).medals).toBe(before);
    await page.waitForTimeout(4100);
    await expect(progress).toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuenow', '0');
    await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
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
    await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!', { timeout: 15000 });
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
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await expect(progress).toHaveAttribute('data-phase', 'building', { timeout: 5000 });
  await page.evaluate(() => window.gamepadFixture.disconnect());
  await expect(progress).toHaveAttribute('hidden', '');
  await expect(progress).toHaveAttribute('aria-valuenow', '0');
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  expect((await rewardState(page)).medals).toBe(before);
  await page.waitForTimeout(4100);
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
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
      await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? /You did it!|Round complete/ : 'Find 5 word–picture pairs.');
    }
    await acceptCelebration(page);
    const chestPoint = resultScreenPoint(await canvasMetrics(page));
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
      const reward = await expectRecording(page, beforeChest, 'assets/audio/chest-kenney/reward.wav');
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
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? /You did it!|Round complete/ : 'Find 5 word–picture pairs.');
  }
  await acceptCelebration(page);
  const chestPoint = resultScreenPoint(await canvasMetrics(page));
  await page.mouse.move(chestPoint.x, chestPoint.y);
  await page.mouse.down();
  await page.mouse.move(chestPoint.x + 28, chestPoint.y + 12, { steps: 4 });
  await page.waitForTimeout(1300);
  await page.mouse.up();
  await expect(page.locator('#game-status')).toContainText(/You did it!|Round complete/);
  await holdChestUntilOpen(page, chestPoint);
  expect(errors).toEqual([]);
});

test('completed Match keeps its board behind a bounded settlement dialog with a visible Play again action on a phone', async ({ page }, testInfo) => {
    const errors = watchErrors(page);
    await page.setViewportSize({ width: 390, height: 650 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await ready(page);
    expect((await logicalMetrics(page)).library.learning.selection.track).toBe('growth');
    await winWithTouch(page);
    await page.screenshot({ path: testInfo.outputPath('result-match-closed-phone.png'), scale: 'css' });
    await holdChestUntilOpen(page, resultScreenPoint(await canvasMetrics(page)));
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const metrics = await canvasMetrics(page);
    const scale = Math.min(metrics.width, metrics.height) / 480;
    const logical = await logicalMetrics(page);
    const action = resultPoint(logical, 'newAdventure');
    const dialog = logical.growth.settlement;
    const replay = logical.growth.result.controls.find(control => control.name === 'SettlementReplay');
    expect(dialog.visible).toBe(true);
    expect(logical.growth.board.visible).toBe(true);
    expect(replay.visible && !replay.disabled).toBe(true);
    const [left, top, width, height] = dialog.panel_rect;
    expect(left).toBeGreaterThan(0);
    expect(top).toBeGreaterThan(0);
    expect(left + width).toBeLessThan(logical.width);
    expect(top + height).toBeLessThan(logical.height);
    expect(action.x).toBeGreaterThan(left);
    expect(action.x).toBeLessThan(left + width);
    expect(action.y).toBeGreaterThan(top);
    expect(action.y).toBeLessThan(top + height);
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
    expect(Math.max(...pixel) - Math.min(...pixel), 'Play again renders a colored button surface.').toBeGreaterThan(30);
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
