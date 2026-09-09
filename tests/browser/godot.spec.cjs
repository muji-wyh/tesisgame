const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

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

async function ready(scope) {
  await expect(scope.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(scope.locator('#status')).toBeHidden();
  await expect(scope.locator('#game-status')).toContainText('Find three pairs.');
}

async function canvasMetrics(scope) {
  return scope.locator('#canvas').evaluate((canvas) => {
    const rect = canvas.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  });
}

function cardPoint(metrics, index) {
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const width = metrics.width / scale;
  const height = metrics.height / scale;
  const columns = metrics.width >= metrics.height ? 4 : 2;
  const rows = 8 / columns;
  const cellWidth = (width - 24 - (columns - 1) * 10) / columns;
  const cellHeight = (height - 184 - (rows - 1) * 10) / rows;
  return {
    x: metrics.x + (12 + (index % columns) * (cellWidth + 10) + cellWidth / 2) * scale,
    y: metrics.y + (172 + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2) * scale
  };
}

const firstCard = (metrics) => cardPoint(metrics, 0);

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
  expect(loaded.some((response) => response.url().includes('.pck') && response.ok())).toBe(true);
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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
  await expect(page.locator('#game-status')).toContainText('My rewards');
  await pressGamepad(page, 9);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('My rewards');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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

async function observeAudio(page) {
  await page.addInitScript(() => {
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.audioObservation = { available: Boolean(NativeContext), contexts: [], starts: 0 };
    if (!NativeContext) return;
    const WrappedContext = new Proxy(NativeContext, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args);
        window.audioObservation.contexts.push(context);
        const createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const source = createSource();
          const start = source.start.bind(source);
          source.start = (...values) => {
            window.audioObservation.starts += 1;
            return start(...values);
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = WrappedContext;
    else window.webkitAudioContext = WrappedContext;
  });
}

async function holdOptionalAudio(page) {
  const requests = [];
  let release;
  const pending = new Promise(resolve => { release = resolve; });
  await page.route('**/audio-*.sample', async route => {
    requests.push(route.request());
    await pending;
    await route.continue();
  });
  return {
    requests, release,
    async finish() {
      release();
      await Promise.all(requests.map(async request => {
        const response = await request.response();
        expect(response?.ok()).toBe(true);
        await response.finished();
      }));
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    }
  };
}

async function chooseSeason(page, index) {
  const metrics = await canvasMetrics(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const buttonWidth = (metrics.width / scale - 48) / 4;
  await page.touchscreen.tap(
    metrics.x + (12 + index * (buttonWidth + 8) + buttonWidth / 2) * scale,
    metrics.y + 128 * scale
  );
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

test('optional audio downloads never delay bundled words or card input', async ({ page }) => {
  const errors = watchErrors(page);
  const held = await holdOptionalAudio(page);
  await observeAudio(page);
  try {
    await page.goto('/');
    await ready(page);
    expect(held.requests).toEqual([]);
    test.skip(!await page.evaluate(() => window.audioObservation.available), 'This WebKit runtime has no WebAudio.');
    const metrics = await canvasMetrics(page);
    const point = firstCard(metrics);
    const beforeWord = await page.evaluate(() => window.audioObservation.starts);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThanOrEqual(beforeWord + 2);
    await expect.poll(() => new Set(held.requests.map(request => request.url())).size).toBe(1);
    expect(held.requests).toHaveLength(1);
    await expect(page.locator('#audio-status')).toBeEmpty();
    const beforeRelease = await page.evaluate(() => window.audioObservation.starts);
    await held.finish();
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBe(beforeRelease + 1);
    expect(await page.evaluate(() => window.audioObservation.starts)).toBe(beforeRelease + 1);
    await expect(page.locator('#audio-status')).toBeEmpty();
    expect(errors).toEqual([]);
  } finally {
    held.release();
    await page.unrouteAll({ behavior: 'wait' });
  }
});

test('hiding prevents pending audio from restarting until another gesture', async ({ page }) => {
    const errors = watchErrors(page);
    const held = await holdOptionalAudio(page);
    await observeAudio(page);
    try {
      await page.goto('/');
      await ready(page);
      test.skip(!await page.evaluate(() => window.audioObservation.available), 'This WebKit runtime has no WebAudio.');
      const metrics = await canvasMetrics(page);
      const point = firstCard(metrics);
      await page.touchscreen.tap(point.x, point.y);
      await expect.poll(() => held.requests.length).toBe(1);
      const before = await page.evaluate(() => window.audioObservation.starts);
      await page.evaluate(() => {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event('visibilitychange'));
      });
      await held.finish();
      expect(await page.evaluate(() => window.audioObservation.starts)).toBe(before);
      await page.evaluate(() => {
        delete document.hidden;
        document.dispatchEvent(new Event('visibilitychange'));
      });
      expect(await page.evaluate(() => window.audioObservation.starts)).toBe(before);
      await page.touchscreen.tap(point.x, point.y);
      await expect(page.locator('#game-status')).toContainText('Find three pairs.');
      await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBe(before + 1);
      expect(held.requests).toHaveLength(1);
      expect(errors).toEqual([]);
    } finally {
      held.release();
      await page.unrouteAll({ behavior: 'wait' });
    }
});

test('season colors preserve selection and discard obsolete pending music and prompts', async ({ page }) => {
  const errors = watchErrors(page);
  const held = await holdOptionalAudio(page);
  await observeAudio(page);
  try {
    await page.goto('/');
    await ready(page);
    const point = firstCard(await canvasMetrics(page));
    await page.touchscreen.tap(point.x, point.y);
    const selected = await page.locator('#selection-status').textContent();
    for (const [index, color] of ['#edf8ec', '#ffe6e6', '#fff8cf', '#ffffff'].entries()) {
      await chooseSeason(page, index);
      await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', color);
      await expect(page.locator('#game-status')).toHaveText('Now find its match!');
      await expect(page.locator('#selection-status')).toHaveText(selected);
    }
    const before = await page.evaluate(() => window.audioObservation.starts);
    await held.finish();
    if (await page.evaluate(() => window.audioObservation.available)) {
      await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBe(before + 2);
      expect(new Set(held.requests.map(request => request.url())).size).toBe(8);
      expect(held.requests).toHaveLength(8);
    }
    await assertFits(page);
    expect(errors).toEqual([]);
  } finally {
    held.release();
    await page.unrouteAll({ behavior: 'wait' });
  }
});

for (const failure of ['unavailable', 'corrupt']) {
  test(`${failure} optional audio leaves the round playable and can be retried`, async ({ page }) => {
    let failing = true;
    const requests = [];
    await page.route('**/audio-*.sample', async route => {
      requests.push(route.request());
      if (failing) await route.fulfill({
        status: failure === 'unavailable' ? 503 : 200,
        body: failure === 'unavailable' ? 'Temporarily unavailable' : 'RSRC damaged audio',
        headers: { 'Cache-Control': 'no-store' }
      });
      else await route.continue();
    });
    await observeAudio(page);
    await page.goto('/');
    await ready(page);
    test.skip(!await page.evaluate(() => window.audioObservation.available), 'This WebKit runtime has no WebAudio.');
    const metrics = await canvasMetrics(page);
    const point = firstCard(metrics);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#audio-status')).toContainText('You can keep playing.');
    await expect(page.locator('#audio-status')).not.toContainText('Listen');
    const before = await page.evaluate(() => window.audioObservation.starts);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Find three pairs.');
    expect(await page.evaluate(() => window.audioObservation.starts)).toBe(before);
    await Promise.all(requests.map(async request => (await request.response()).finished()));
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    failing = false;
    const retryStarts = await page.evaluate(() => window.audioObservation.starts);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThanOrEqual(retryStarts + 2);
    await expect(page.locator('#audio-status')).toBeEmpty();
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  });
}

test('motion preference changes do not restart the native round', async ({ page }) => {
  const errors = watchErrors(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
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
      '</head><body><iframe title="Word Buddies" src="/" allow="autoplay; fullscreen"></iframe></body></html>'
  }));
  await page.goto('/embed-test.html');
  const frame = page.frameLocator('iframe');
  await ready(frame);
  await assertFits(frame);
  await page.locator('iframe').evaluate((element) => { element.style.height = '80%'; });
  await expect.poll(async () => (await canvasMetrics(frame)).height).toBeLessThan(page.viewportSize().height);
  await assertFits(frame);
  await expect(frame.locator('#game-status')).toContainText('Find three pairs.');
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
      '</head><body><section>Content above the game</section><iframe title="Word Buddies" src="/" allow="autoplay"></iframe></body></html>'
  }));
  await page.goto('/below-fold.html');
  const frame = page.frameLocator('iframe');
  await ready(frame);
  const focusRequests = await frame.locator('#canvas').evaluate(() => window.canvasFocusRequests);
  expect(focusRequests.length).toBeGreaterThan(0);
  expect(focusRequests.every(Boolean)).toBe(true);
  expect(await page.evaluate(() => window.scrollY)).toBe(0);
  expect(errors).toEqual([]);
});

async function discoverCards(page) {
  const metrics = await canvasMetrics(page);
  const discovered = new Map();
  for (let index = 0; index < 8; index++) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!discovered.has(word)) discovered.set(word, {});
    discovered.get(word)[kind] = index;
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  }
  return { metrics, discovered };
}

async function holdChestUntilOpen(page, point) {
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    // Keep holding through slow rendered frames instead of releasing on the runner's clock.
    await expect(page.locator('#game-status')).toContainText(/A new piece!|Medal complete!|All six collected!/);
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).not.toContainText('Tap to place!');
}

async function winWithTouch(page, board) {
  const { metrics, discovered } = board ?? await discoverCards(page);
  const pairs = [...discovered.values()].filter(pair => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (let index = 0; index < pairs.length; index++) {
    for (const card of [pairs[index].Word, pairs[index].Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find three pairs.');
  }
  return metrics;
}

async function holdControllerChest(page) {
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  try {
    await expect(page.locator('#game-status')).toContainText(/A new piece!|Medal complete!|All six collected!/);
  } finally {
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    // Let the engine sample the release before another simulated A press.
    await page.waitForTimeout(120);
  }
  await expect(page.locator('#game-status')).not.toContainText('Tap to place!');
}

test('one hint per round is shared by touch and Xbox', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const hintPoint = { x: metrics.x + metrics.width - 128 * scale, y: metrics.y + 48 * scale };
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const firstHint = await page.locator('#game-status').textContent();
  const word = firstHint.match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  const pair = discovered.get(word);
  expect(pair.Word).toBeDefined();
  expect(pair.Picture).toBeDefined();
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toHaveText(firstHint);
  await page.screenshot({ path: testInfo.outputPath('hint-stars.png'), scale: 'css' });
  for (const index of [pair.Word, pair.Picture]) {
    const point = cardPoint(metrics, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await page.touchscreen.tap(hintPoint.x, hintPoint.y);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await chooseSeason(page, 1);
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('My rewards opened');
  await pressGamepad(page, 1);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await page.screenshot({ path: testInfo.outputPath('hint-used.png'), scale: 'css' });
  const remaining = [...discovered.values()].filter(value => value !== pair && value.Word !== undefined && value.Picture !== undefined);
  for (const [index, cards] of remaining.entries()) {
    for (const card of [cards.Word, cards.Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    if (index === 0) await expect(page.locator('#game-status')).toHaveText('Great match! 2 in a row!');
    await expect(page.locator('#game-status')).toContainText(index === 0 ? 'Find three pairs.' : 'You did it!');
  }
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await holdControllerChest(page);
  await pressGamepad(page, 0);
  await ready(page);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const still = await page.screenshot({ scale: 'css' });
  await page.waitForTimeout(250);
  expect((await page.screenshot({ scale: 'css' })).equals(still), 'Reduced-motion hints stay visually still.').toBe(true);
  await pressGamepad(page, 0);
  const selected = await page.locator('#selection-status').textContent();
  await pressGamepad(page, 2);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await assertFits(page);
  expect(errors).toEqual([]);
});

test('keyboard hints focus a suggested card ready for Enter', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
  await page.keyboard.press('Tab');
  if (await page.evaluate(() => window.wordBuddiesHost.speechAvailable())) await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const word = (await page.locator('#game-status').textContent()).match(/^Hint: match the ([a-z]+) cards\.$/)[1];
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(new RegExp(`^(Word|Picture): ${word}$`));
  await page.keyboard.press('Escape');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  expect(errors).toEqual([]);
});

test('three mistakes end a round and the counter cannot reset the limits', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  const board = await discoverCards(page);
  const { metrics, discovered } = board;
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  const [word, card] = [...discovered].find(([, value]) => value.Word !== undefined);
  const [, other] = [...discovered].find(([text, value]) => text !== word && value.Picture !== undefined);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const counterPoint = { x: metrics.x + metrics.width * 0.75 - 184 * scale, y: metrics.y + 48 * scale };
  for (let attempt = 0; attempt < 3; attempt++) {
    await page.touchscreen.tap(counterPoint.x, counterPoint.y);
    for (const index of [card.Word, other.Picture]) {
      const point = cardPoint(metrics, index);
      await page.touchscreen.tap(point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText(attempt === 2 ? 'Good try!' : 'Find three pairs.');
  }
  await page.touchscreen.tap(counterPoint.x, counterPoint.y);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toContainText('Good try!');
  await page.screenshot({ path: testInfo.outputPath('three-mistake-limit.png'), scale: 'css' });
  await pressGamepad(page, 0);
  await ready(page);
  await pressGamepad(page, 2);
  await expect(page.locator('#game-status')).toHaveText(/^Hint: match the [a-z]+ cards\.$/);
  await expect(page.locator('#help')).not.toContainText('Practice');
  await assertFits(page);
  expect(errors).toEqual([]);
});

test('fresh replays assemble three fragments into a medal and preserve progress', async ({ page }, testInfo) => {
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
    expect(words.filter(word => previousWords.includes(word))).toEqual([]);
    previousWords = words;
    await winWithTouch(page, board);
    await holdControllerChest(page);
    if (round === 2) {
      await expect(page.locator('#game-status')).toContainText('Medal complete!');
    } else {
      await expect(page.locator('#game-status')).toContainText(`Piece ${round % 3 + 1} of 3`);
    }
    await pressGamepad(page, 3);
    const completed = Math.floor((round + 1) / 3);
    await expect(page.locator('#game-status')).toContainText(`My rewards opened. ${completed} of 24 medals complete.`);
    await expect(page.locator('#game-status')).toContainText(`Spring ${completed}/6`);
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
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 1 of 24 medals complete. Spring 1/6');
  const bounds = await canvasMetrics(page);
  const scale = Math.min(bounds.width, bounds.height) / 480;
  const width = bounds.width / scale;
  const columns = width - 32 >= 500 ? 6 : 3;
  const cellWidth = (width - 32 - (columns - 1) * 4) / columns;
  await page.touchscreen.tap(bounds.x + (20 + cellWidth * 1.5) * scale, bounds.y + 162 * scale);
  await expect(page.locator('#game-status')).toContainText('Ladybug #2 reward preview opened');
  await expect(page.locator('#game-status')).toContainText('Piece 1 of 3');
  expect(errors).toEqual([]);
});

test('Xbox chest charging cancels on disconnect and works again after reconnect', async ({ page }) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.goto('/');
  await ready(page);
  await winWithTouch(page);
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to find a piece!');
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await page.waitForTimeout(120);
  await page.evaluate(() => window.gamepadFixture.disconnect());
  await page.waitForTimeout(1700);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to find a piece!');
  await page.evaluate(() => window.gamepadFixture.connect());
  await holdControllerChest(page);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  expect(errors).toEqual([]);
});

test('earned rewards respond to deliberate touch and stay closed after a swipe', async ({ page, browserName }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await ready(page);
  await chooseSeason(page, 0);
  await winWithTouch(page);
  await page.evaluate(() => window.gamepadFixture.connect());
  await holdControllerChest(page);
  const earned = (await page.locator('#game-status').textContent()).split('\n')[0].replace(/^A new piece!\s*/, '');
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
  await page.screenshot({ path: testInfo.outputPath('reward-collection.png'), scale: 'css' });
  let rewardPoint;
  for (let index = 0; index < 6; index++) {
    const point = {
      x: (16 + (index % 3) * (452 / 3) + 440 / 6) * 390 / 480,
      y: (162 + Math.floor(index / 3) * 120) * 390 / 480
    };
    await page.touchscreen.tap(point.x, point.y);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    if ((await page.locator('#game-status').textContent()).includes('reward preview opened')) {
      rewardPoint = point;
      break;
    }
  }
  expect(rewardPoint, 'The earned Spring reward opens from an actual tap; locked slots stay closed.').toBeDefined();
  await expect(page.locator('#game-status')).toContainText(earned);
  await page.screenshot({ path: testInfo.outputPath('reward-preview.png'), scale: 'css' });
  await page.touchscreen.tap(195, 340);
  await expect(page.locator('#game-status')).toContainText('Boing! Tap 1');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
  if (browserName === 'chromium') {
    const client = await page.context().newCDPSession(page);
    try {
      await client.send('Input.dispatchTouchEvent', {
        type: 'touchStart', touchPoints: [{ id: 1, x: rewardPoint.x, y: rewardPoint.y }]
      });
      await client.send('Input.dispatchTouchEvent', {
        type: 'touchMove', touchPoints: [{ id: 1, x: rewardPoint.x, y: rewardPoint.y - 32 }]
      });
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
      rewardPoint.y -= 32;
    } finally {
      await client.detach();
    }
  }
  await page.touchscreen.tap(rewardPoint.x, rewardPoint.y);
  await expect(page.locator('#game-status')).toContainText('reward preview opened');
  await pressGamepad(page, 12);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText('A new piece!');
  expect(errors).toEqual([]);
});

for (const [season, name] of ['Spring', 'Summer', 'Autumn', 'Winter'].entries()) {
  test(`${name} preview play varies reactions and celebrates five taps without extra rewards`, async ({ page }, testInfo) => {
    const errors = watchErrors(page);
    await installGamepad(page);
    await page.setViewportSize({ width: 390, height: 650 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await ready(page);
    await chooseSeason(page, season);
    await winWithTouch(page);
    await page.evaluate(() => window.gamepadFixture.connect());
    await holdControllerChest(page);
    await pressGamepad(page, 3);
    await pressGamepad(page, 13);
    await pressGamepad(page, 0);
    await expect(page.locator('#game-status')).toContainText('reward preview opened');
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    const reactions = ['Boing! Tap 1', 'Wheee! Tap 2', 'Big hug! Tap 3', 'Boing! Tap 4', `High five! ${name} party!`];
    for (const [index, reaction] of reactions.entries()) {
      if (index === 2) await pressGamepad(page, 0);
      else await page.touchscreen.tap(195, 340);
      await expect(page.locator('#game-status')).toContainText(reaction);
    }
    await page.waitForTimeout(220);
    await page.screenshot({ path: testInfo.outputPath(`reward-party-${name.toLowerCase()}.png`), scale: 'css' });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await pressGamepad(page, 0);
    await expect(page.locator('#game-status')).toContainText('Big hug! Tap 6');
    const still = await page.screenshot({ scale: 'css' });
    await page.waitForTimeout(250);
    expect((await page.screenshot({ scale: 'css' })).equals(still), 'Reduced-motion play stays visually still.').toBe(true);
    await pressGamepad(page, 1);
    await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
    expect(errors).toEqual([]);
  });
}

test('completes matches and opens a one-shot reward while optional audio is still downloading', async ({ page }) => {
  const errors = watchErrors(page);
  const held = await holdOptionalAudio(page);
  await observeAudio(page);
  try {
    await page.goto('/');
    await ready(page);
    const { metrics, discovered } = await discoverCards(page);
    const pairs = [...discovered.values()].filter((pair) => pair.Word !== undefined && pair.Picture !== undefined);
    expect(pairs).toHaveLength(3);
    for (let index = 0; index < pairs.length; index++) {
      for (const card of [pairs[index].Word, pairs[index].Picture]) {
        const point = cardPoint(metrics, card);
        await page.touchscreen.tap(point.x, point.y);
      }
      await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find three pairs.');
    }
    const scale = Math.min(metrics.width, metrics.height) / 480;
    const width = metrics.width / scale;
    const height = metrics.height / scale;
    const landscape = metrics.width >= metrics.height;
    const stageWidth = landscape ? (width - 40) * 0.61 : width - 24;
    const stageHeight = landscape ? height - 184 : Math.max(72, height - 364);
    const chestPoint = {
      x: metrics.x + (12 + stageWidth * 0.5) * scale,
      y: metrics.y + (172 + stageHeight * 0.6) * scale
    };
    await holdChestUntilOpen(page, chestPoint);
    const earned = await page.locator('#game-status').textContent();
    await page.mouse.down();
    await page.waitForTimeout(1300);
    await page.mouse.up();
    await expect(page.locator('#game-status')).toHaveText(earned);
    const before = await page.evaluate(() => window.audioObservation.starts);
    await held.finish();
    if (await page.evaluate(() => window.audioObservation.available)) {
      await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBe(before + 2);
    }
    await assertFits(page);
    expect(errors).toEqual([]);
  } finally {
    held.release();
    await page.unrouteAll({ behavior: 'wait' });
  }
});

test('dragging the reward chest cancels hold-open without losing pointer control', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
  const { metrics, discovered } = await discoverCards(page);
  const pairs = [...discovered.values()].filter((pair) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (let index = 0; index < pairs.length; index++) {
    for (const card of [pairs[index].Word, pairs[index].Picture]) {
      const point = cardPoint(metrics, card);
      await page.touchscreen.tap(point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find three pairs.');
  }
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const width = metrics.width / scale;
  const height = metrics.height / scale;
  const landscape = metrics.width >= metrics.height;
  const stageWidth = landscape ? (width - 40) * 0.61 : width - 24;
  const stageHeight = landscape ? height - 184 : Math.max(72, height - 364);
  const chestPoint = {
    x: metrics.x + (12 + stageWidth * 0.5) * scale,
    y: metrics.y + (172 + stageHeight * 0.6) * scale
  };
  await page.mouse.move(chestPoint.x, chestPoint.y);
  await page.mouse.down();
  await page.mouse.move(chestPoint.x + 28, chestPoint.y + 12, { steps: 4 });
  await page.waitForTimeout(1300);
  await page.mouse.up();
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await holdChestUntilOpen(page, chestPoint);
  expect(errors).toEqual([]);
});

async function loseWithTouch(page) {
  const { metrics, discovered } = await discoverCards(page);
  const [word, card] = [...discovered].find(([, value]) => value.Word !== undefined);
  const [, other] = [...discovered].find(([text, value]) => text !== word && value.Picture !== undefined);
  for (let attempt = 0; attempt < 3; attempt++) {
    for (const index of [card.Word, other.Picture]) {
      const point = cardPoint(metrics, index);
      await page.touchscreen.tap(point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText(attempt === 2 ? 'Good try!' : 'Find three pairs.');
  }
  return metrics;
}

for (const outcome of ['win', 'loss']) {
  test(`${outcome} screen visibly renders Play again below the artwork on a phone`, async ({ page }, testInfo) => {
    const errors = watchErrors(page);
    await page.setViewportSize({ width: 390, height: 650 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await ready(page);
    await chooseSeason(page, 1);
    if (outcome === 'win') await winWithTouch(page);
    else await loseWithTouch(page);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const metrics = await canvasMetrics(page);
    const scale = Math.min(metrics.width, metrics.height) / 480;
    const replay = { x: metrics.x + metrics.width * 0.23, y: metrics.y + metrics.height - 48 * scale };
    const screenshot = await page.screenshot({ path: testInfo.outputPath(`result-${outcome}.png`), scale: 'css' });
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
    }, { encoded: screenshot.toString('base64'), point: replay });
    expect(pixel, 'The actual white replay button must render, not just accept invisible input.').toEqual([255, 255, 255]);
    await page.touchscreen.tap(replay.x, replay.y);
    await expect(page.locator('#game-status')).toContainText('Find three pairs.');
    expect(errors).toEqual([]);
  });
}

test('the loss-screen bear responds to touch and Xbox without restarting the round', async ({ page }, testInfo) => {
  const errors = watchErrors(page);
  await installGamepad(page);
  await page.setViewportSize({ width: 390, height: 650 });
  await page.goto('/');
  await ready(page);
  const metrics = await loseWithTouch(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  const stageHeight = metrics.height / scale - 364;
  const bear = { x: metrics.x + metrics.width / 2, y: metrics.y + (172 + stageHeight * 0.5) * scale };
  await page.touchscreen.tap(bear.x, bear.y);
  await expect(page.locator('#game-status')).toContainText('Good try! High five!');
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('Good try! A big bear hug');
  await page.screenshot({ path: testInfo.outputPath('loss-screen-play.png'), scale: 'css' });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('Good try! You kept trying');
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 24 medals complete.');
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText('Good try!');
  await pressGamepad(page, 13);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  expect(errors).toEqual([]);
});

test('losing stops pending music and only plays the current loss prompt', async ({ page }) => {
  const errors = watchErrors(page);
  const held = await holdOptionalAudio(page);
  await observeAudio(page);
  try {
    await page.goto('/');
    await ready(page);
    await loseWithTouch(page);
    const before = await page.evaluate(() => window.audioObservation.starts);
    await held.finish();
    if (await page.evaluate(() => window.audioObservation.available)) {
      await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBe(before + 1);
    }
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true');
    expect(errors).toEqual([]);
  } finally {
    held.release();
    await page.unrouteAll({ behavior: 'wait' });
  }
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
  await page.route('**/*.pck', (route) => route.abort());
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
});

test('invalid game pack contents report the native startup exit', async ({ page }) => {
  await page.route('**/*.pck', (route) => route.fulfill({
    contentType: 'application/octet-stream', body: 'not a Godot game pack'
  }));
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
});
