const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');

test.beforeAll(() => {
  expect(fs.existsSync(path.join(__dirname, '..', '..', 'build', 'web', 'index.wasm')),
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
  const cellHeight = (height - 196 - (rows - 1) * 10) / rows;
  return {
    x: metrics.x + (12 + (index % columns) * (cellWidth + 10) + cellWidth / 2) * scale,
    y: metrics.y + (136 + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2) * scale
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
      pixelsWide: canvas.width, pixelsHigh: canvas.height, ratio: devicePixelRatio
    };
  });
  expect(sizes.scrollWidth).toBeLessThanOrEqual(sizes.windowWidth);
  expect(sizes.scrollHeight).toBeLessThanOrEqual(sizes.windowHeight);
  expect(sizes.x).toBeGreaterThanOrEqual(0);
  expect(sizes.y).toBeGreaterThanOrEqual(0);
  expect(sizes.x + sizes.width).toBeLessThanOrEqual(sizes.windowWidth + 1);
  expect(sizes.y + sizes.height).toBeLessThanOrEqual(sizes.windowHeight + 1);
  expect(Math.abs(sizes.pixelsWide - Math.round(sizes.width * sizes.ratio))).toBeLessThanOrEqual(1);
  expect(Math.abs(sizes.pixelsHigh - Math.round(sizes.height * sizes.ratio))).toBeLessThanOrEqual(1);
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

test('Listen uses real browser audio or reports genuine missing audio support', async ({ page }) => {
  const errors = watchErrors(page);
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
  await page.goto('/');
  await ready(page);
  const metrics = await canvasMetrics(page);
  const scale = Math.min(metrics.width, metrics.height) / 480;
  await page.touchscreen.tap(metrics.x + metrics.width - 57 * scale, metrics.y + 48 * scale);
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

test('completes matches and opens a one-shot reward using only real touch input', async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto('/');
  await ready(page);
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
  const stageHeight = landscape ? height - 148 : Math.max(72, height - 328);
  const chestPoint = {
    x: metrics.x + (12 + stageWidth * 0.5) * scale,
    y: metrics.y + (136 + stageHeight * 0.6) * scale
  };
  await page.touchscreen.tap(chestPoint.x, chestPoint.y);
  await expect(page.locator('#game-status')).toContainText('Wow!');
  const earned = await page.locator('#game-status').textContent();
  await page.touchscreen.tap(chestPoint.x, chestPoint.y);
  await expect(page.locator('#game-status')).toHaveText(earned);
  await assertFits(page);
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
  await page.route('**/index.js', (route) => route.abort());
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
