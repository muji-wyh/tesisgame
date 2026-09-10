const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);

async function useMaintainedShell(page) {
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8'))
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', `${config.executable}.js`)
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.route('**/loader-test*', route => route.fulfill({ contentType: 'text/html', body: shell }));
}

async function whileEngineScriptIsPending(page, action) {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => {
    await held;
    await route.abort();
  });
  try {
    await page.goto('/loader-test', { waitUntil: 'commit' });
    await expect(page.locator('#loading-toy')).toBeVisible();
    await action(page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }));
  } finally {
    release();
    await page.unrouteAll({ behavior: 'wait' });
  }
}

async function progressShell(page, engineScript = `window.Engine = class {
  static getMissingFeatures() { return []; }
  static load() { return Promise.resolve(); }
  startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
};`) {
  await useMaintainedShell(page);
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, route => route.fulfill({
    contentType: 'application/javascript',
    body: engineScript
  }));
  await page.goto('/loader-test');
}

for (const stage of ['features', 'constructor', 'load', 'start']) {
  test(`synchronous engine ${stage} failure leaves an actionable retry`, async ({ page }, testInfo) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await progressShell(page, `window.Engine = class {
      static getMissingFeatures() { ${stage === 'features' ? "throw new Error('Feature check failed.');" : 'return [];'} }
      constructor() { ${stage === 'constructor' ? "throw new Error('Engine setup failed.');" : ''} }
      static load() { ${stage === 'load' ? "throw new Error('Download setup failed.');" : 'return Promise.resolve();'} }
      startGame() { ${stage === 'start' ? "throw new Error('Game setup failed.');" : 'return Promise.resolve();'} }
    };`);
    await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 3000 });
    await expect(page.locator('#retry')).toBeFocused();
    await expect(page.locator('#loading-play')).toBeHidden();
    await expect(page.locator('#canvas')).toHaveAttribute('inert');
    expect(errors).toEqual([]);
    if (stage === 'constructor') await page.screenshot({ path: testInfo.outputPath('startup-failure-retry.png'), scale: 'css' });
  });
}

test('an empty startup rejection still gives a clear failure and preserves its first cause', async ({ page }) => {
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return Promise.reject(null); }
    startGame() { return Promise.resolve(); }
  };`);
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 3000 });
  await expect(page.locator('#retry')).toBeFocused();
  const first = await page.locator('#message').textContent();
  await page.evaluate(() => window.wordBuddiesHost.fail('A later shutdown message.'));
  await expect(page.locator('#message')).toHaveText(first);
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#status')).toBeVisible();
});

test('a stalled download offers retry without stealing focus or stopping the loading toy', async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return new Promise(() => {}); }
    startGame() { return new Promise(() => {}); }
  };`);
  await page.setViewportSize({ width: 320, height: 320 });
  const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
  await toy.focus();
  await page.clock.runFor(17000);
  await expect(page.locator('#retry')).toBeVisible({ timeout: 3000 });
  await expect(page.locator('#loading-note')).toContainText('retry');
  await expect(toy).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('stalled-download-320.png'), scale: 'css' });
});

test('losing pointer capture cancels the loading chest drag', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    const bounds = await toy.boundingBox();
    const x = bounds.x + bounds.width / 2;
    const y = bounds.y + bounds.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x + 32, y);
    expect(await page.locator('#chest-art').evaluate(el => el.style.transform)).not.toBe('');
    await toy.evaluate(el => el.releasePointerCapture(1));
    await page.mouse.move(x + 48, y);
    await expect.poll(() => page.locator('#chest-art').evaluate(el => el.style.transform)).toBe('');
    await page.mouse.up();
  });
});

test('graphics context loss gives a visible recovery action and stops game input', async ({ page }, testInfo) => {
  const dialogs = [];
  page.on('dialog', async dialog => { dialogs.push(dialog.message()); await dialog.dismiss(); });
  await useMaintainedShell(page);
  await page.goto('/loader-test');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await page.evaluate(() => document.getElementById('canvas').getContext('webgl2')
    .getExtension('WEBGL_lose_context').loseContext());
  await expect(page.locator('#message')).toContainText('graphics', { timeout: 3000 });
  await expect(page.locator('#retry')).toBeFocused();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'false');
  expect(dialogs).toEqual([]);
  await page.screenshot({ path: testInfo.outputPath('graphics-lost-retry.png'), scale: 'css' });
  await page.getByRole('button', { name: 'Try again', exact: true }).click();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
});

test('loading caps downloads at 98 percent and holds 99 percent until the game is ready', async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#message')).toContainText('Loading');
  await page.evaluate(() => window.reportDownload(2 * 1048576, 10 * 1048576));
  await expect(page.locator('#loading-percent')).toHaveText('20%');
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toHaveText('20%');
  await expect(page.locator('#download-status')).toContainText('2.0 / 10.0 MB');
  await page.evaluate(() => window.reportDownload(6 * 1048576, 10 * 1048576));
  await expect(page.locator('#loading-percent')).toHaveText('60%');
  await page.screenshot({ path: testInfo.outputPath('real-download-60-percent.png'), scale: 'css' });
  await page.evaluate(() => window.reportDownload(99, 100));
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.98');
  await page.evaluate(() => window.reportDownload(10 * 1048576, 10 * 1048576));
  await expect(page.locator('#message')).toHaveText('Loading game...');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.99');
  await expect(page.locator('#progress')).toHaveAttribute('aria-label', 'Game loading progress');
  await expect(page.locator('#loading-percent')).toHaveText('99%');
  await expect(page.locator('#download-status')).toHaveText('Getting ready to play...');
  await page.clock.runFor(30000);
  await expect(page.locator('#loading-percent')).toHaveText('99%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.99');
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }).click();
  await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  await page.screenshot({ path: testInfo.outputPath('preparing-game-99-percent.png'), scale: 'css' });
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#status')).toBeHidden();
});

test('a real engine waiting to initialize keeps 99 percent visible and can finish loading', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    const instantiate = WebAssembly.instantiate;
    const held = new Promise(resolve => { window.finishInitialization = resolve; });
    WebAssembly.instantiateStreaming = async (response, imports) => {
      const bytes = await (await response).arrayBuffer();
      await held;
      return instantiate(bytes, imports);
    };
  });
  await page.goto('/');
  await expect(page.locator('#loading-percent')).toHaveText('99%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.99');
  await expect(page.locator('#message')).toHaveText('Loading game...');
  await page.screenshot({ path: testInfo.outputPath('real-engine-preparing-99-percent.png'), scale: 'css' });
  await page.evaluate(() => window.finishInitialization());
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#loading-percent')).toHaveText('100%');
});

test('cached startup can become ready immediately and failed startup never finishes progress', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#status')).toBeHidden();
  await page.reload();
  await page.evaluate(() => window.reportDownload(25, 100));
  await expect(page.locator('#loading-percent')).toHaveText('25%');
  await page.evaluate(() => window.wordBuddiesHost.fail('The game could not start.'));
  await page.clock.runFor(5000);
  await page.evaluate(() => window.reportDownload(100, 100));
  await expect(page.locator('#loading-percent')).toHaveText('25%');
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('#download-status')).toBeHidden();
});

test('unknown totals stay indeterminate and time or visibility never invents progress', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await progressShell(page);
  await page.evaluate(() => window.reportDownload(1048576, 0));
  await page.clock.runFor(2000);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#download-status')).toContainText('1.0 MB');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(1300);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await page.evaluate(() => window.reportDownload(2, 10));
  await expect(page.locator('#loading-percent')).toHaveText('20%');
  await page.evaluate(() => window.reportDownload(1, 10));
  await expect(page.locator('#loading-percent')).toHaveText('10%');
  await page.evaluate(() => window.reportDownload(11, 10));
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#loading-percent')).toBeEmpty();
});

test('loading chest taps have no browser highlight but keyboard focus stays visible', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    // Desktop WebKit builds do not implement the mobile tap-highlight property.
    if (await page.evaluate(() => CSS.supports('-webkit-tap-highlight-color', 'transparent'))) {
      await expect(toy).toHaveCSS('-webkit-tap-highlight-color', 'rgba(0, 0, 0, 0)');
    }
    await expect(toy).toHaveCSS('appearance', 'none');
    for (let i = 0; i < 7; i++) await toy.tap();
    await expect(page.locator('#loading-score')).toHaveText('7 sparkles');
    expect(await page.evaluate(() => String(window.getSelection()))).toBe('');
    await expect(toy).toHaveCSS('outline-style', 'none');
    await toy.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('#loading-score')).toHaveText('8 sparkles');
    await expect(toy).toHaveCSS('outline-style', 'solid');
    await expect(toy).toHaveCSS('outline-width', '3px');
    await expect(toy).toHaveCSS('touch-action', 'pinch-zoom');
  });
});

test('Pip is an inline loading companion with bounded, motion-safe reactions', async ({ page }) => {
  const imageRequests = [];
  page.on('request', request => {
    if (/pip\.svg|PIP_MASCOT_URI/.test(request.url())) imageRequests.push(request.url());
  });
  await whileEngineScriptIsPending(page, async () => {
    const duck = page.getByRole('button', { name: 'Play with Pip the duck' });
    await expect(duck).toBeVisible();
    expect(await duck.locator('.duck-sprite').evaluate(element =>
      getComputedStyle(element).backgroundImage.startsWith('url("data:image/svg+xml;base64,')
    )).toBe(true);
    for (let tap = 0; tap < 8; tap++) await duck.click();
    await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
    expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBeLessThanOrEqual(1);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await duck.click();
    expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
    expect(imageRequests).toEqual([]);
  });
});

test('every Pip tap gives visible feedback with reduced motion without awarding chest sparkles', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await whileEngineScriptIsPending(page, async toy => {
    const duck = page.getByRole('button', { name: 'Play with Pip the duck' });
    const hint = page.locator('#loading-hint');
    let previous = await hint.textContent();
    for (let tap = 0; tap < 4; tap++) {
      await duck.click();
      await expect(hint).not.toHaveText(previous, { timeout: 1000 });
      previous = await hint.textContent();
      await expect(hint).toContainText('Pip');
      await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
      expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
    }
    await toy.click();
    await expect(hint).toContainText('Boing!');
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  });
});

test('repeated clicks around the loading chest do not select its caption', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    await toy.dblclick();
    await page.locator('#loading-score').dblclick();
    expect(await page.evaluate(() => String(window.getSelection()))).toBe('');
    await expect(page.locator('#loading-play')).toHaveCSS('-webkit-user-select', 'none');
  });
});

test('loading taps vary the chest reaction and celebrate every five sparkles', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    await toy.click();
    await expect(page.locator('#loading-hint')).toContainText('Boing!');
    await toy.click();
    await expect(page.locator('#loading-hint')).toContainText('Peekaboo!');
    expect(await page.locator('#chest-lid').evaluate(el => el.getAnimations().length)).toBeGreaterThan(0);
    for (let i = 0; i < 3; i++) await toy.dispatchEvent('click');
    await expect(page.locator('#loading-score')).toHaveText('5 sparkles');
    await expect(page.locator('#loading-hint')).toContainText('Star party!');
    expect(await page.locator('#loading-surprise').evaluate(el => el.getAnimations().length)).toBeGreaterThan(0);
    expect(await page.locator('#loading-sparks > *').count()).toBeLessThanOrEqual(12);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    for (let i = 0; i < 5; i++) await toy.dispatchEvent('click');
    await expect(page.locator('#loading-score')).toHaveText('10 sparkles');
    await expect(page.locator('#loading-hint')).toContainText('Star party!');
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
  });
});

test('Xbox A plays with the HTML chest once per press before the engine arrives', async ({ page }) => {
  await installGamepad(page);
  await whileEngineScriptIsPending(page, async () => {
    await page.evaluate(() => window.gamepadFixture.connect());
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.waitForTimeout(300);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await page.waitForTimeout(120);
    await pressGamepad(page, 0);
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await page.evaluate(() => window.gamepadFixture.disconnect());
  });
});

test('quick Xbox taps are caught within two rendered frames', async ({ page }) => {
  await installGamepad(page, { connected: true });
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await whileEngineScriptIsPending(page, async () => {
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await page.clock.runFor(34);
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  });
});

test('loading controller polling stops when hidden or disconnected and ignores a held resume', async ({ page }) => {
  await installGamepad(page);
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await whileEngineScriptIsPending(page, async () => {
    const polls = () => page.evaluate(() => window.gamepadFixture.polls);
    const initial = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(initial);
    await page.evaluate(() => {
      window.gamepadFixture.connect();
      window.gamepadFixture.button(0, true);
    });
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    const hidden = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(hidden);
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await page.clock.runFor(120);
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await page.evaluate(() => window.gamepadFixture.disconnect());
    const disconnected = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(disconnected);
  });
});

for (const support of ['unavailable', 'blocked']) {
  test(`the loading toy still works when the Gamepad API is ${support}`, async ({ page }) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(support => {
      Object.defineProperty(navigator, 'getGamepads', {
        value: support === 'unavailable' ? undefined : () => {
          throw new DOMException('Disabled by the embedding permissions policy.', 'SecurityError');
        }
      });
    }, support);
    await whileEngineScriptIsPending(page, async toy => {
      await toy.tap();
      await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
      await expect(page.locator('#retry')).toBeHidden();
      expect(errors).toEqual([]);
    });
  });
}

for (const extension of ['wasm', 'pck']) {
  test(`an interrupted ${extension} response body does not strand the loading screen`, async ({ page }) => {
    await useMaintainedShell(page);
    await page.addInitScript(extension => {
      const originalFetch = window.fetch;
      window.fetch = (resource, options) => {
        if (String(resource).endsWith('.' + extension)) {
          return Promise.resolve(new Response(new ReadableStream({
            start(controller) {
              controller.enqueue(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]));
              setTimeout(() => controller.error(new TypeError('Network connection lost while reading the download.')), 100);
            }
          }), { headers: { 'Content-Type': extension === 'wasm' ? 'application/wasm' : 'application/octet-stream' } }));
        }
        return originalFetch(resource, options);
      };
    }, extension);
    await page.goto('/loader-test');
    await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 4000 });
    await expect(page.locator('#retry')).toBeVisible();
    await expect(page.locator('#loading-play')).toBeHidden();
  });
}

test('the loading toy works before the engine script arrives and fits small screens', async ({ page }) => {
  await useMaintainedShell(page);
  await page.clock.install();
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => {
    await held;
    await route.continue();
  });
  try {
    await page.goto('/loader-test', { waitUntil: 'commit' });
    const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
    await expect(toy).toBeVisible({ timeout: 3000 });
    await toy.tap();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await toy.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await expect(page.locator('#progress')).not.toHaveAttribute('value');
    for (const viewport of [{ width: 390, height: 844 }, { width: 844, height: 390 }, { width: 320, height: 320 }]) {
      await page.setViewportSize(viewport);
      const bounds = await toy.boundingBox();
      expect(bounds.y).toBeGreaterThanOrEqual(0);
      expect(bounds.y + bounds.height).toBeLessThanOrEqual(viewport.height);
      expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
    }
    await page.clock.fastForward(17000);
    await expect(page.locator('#loading-note')).toBeVisible();
    expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
  } finally {
    release();
  }
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#loading-toy')).toBeDisabled();
  await expect(page.locator('#loading-sparks > *')).toHaveCount(0);
  await expect(page.locator('#canvas')).toBeFocused();
});

test('the game pack starts while the first WASM response is still pending', async ({ page }) => {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  let packs = 0;
  let wasm = 0;
  page.on('request', request => {
    if (request.url().endsWith('.pck')) packs++;
  });
  await page.route('**/*.wasm', async route => {
    wasm++;
    await held;
    await route.continue();
  });
  try {
    await page.goto('/loader-test');
    await expect.poll(() => wasm).toBe(1);
    await expect.poll(() => packs, { timeout: 3000 }).toBe(1);
    await page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }).click();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  } finally {
    release();
  }
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect(wasm).toBe(1);
  expect(packs).toBe(1);
});

test('wiggling the loading toy stays bounded and reduced motion stops all effects', async ({ page }) => {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route('**/*.pck', async route => {
    await held;
    await route.abort();
  });
  try {
    await page.goto('/loader-test?scoutTheme=dark');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    for (const selector of ['.loading-heading p', '#loading-hint', '#message', '#loading-note']) {
      const contrast = await page.locator(selector).evaluate(element => {
        function luminance(color) {
          const channels = color.match(/[\d.]+/g).slice(0, 3).map(value => {
            const channel = Number(value) / 255;
            return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
          });
          return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
        }
        const text = luminance(getComputedStyle(element).color);
        const background = luminance(getComputedStyle(document.getElementById('status')).backgroundColor);
        return (Math.max(text, background) + 0.05) / (Math.min(text, background) + 0.05);
      });
      expect(contrast, selector).toBeGreaterThanOrEqual(4.5);
    }
    const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
    await expect(toy).toBeVisible();
    const bounds = await toy.boundingBox();
    await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
    await page.mouse.down();
    await page.mouse.move(bounds.x + bounds.width / 2 + 45, bounds.y + bounds.height / 2, { steps: 4 });
    await page.mouse.up();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    for (let i = 0; i < 15; i++) await toy.dispatchEvent('click');
    expect(await page.locator('#loading-sparks > *').count()).toBeLessThanOrEqual(12);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect.poll(() => page.locator('#loading-play').evaluate(el =>
      el.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length)).toBe(0);
    await toy.click();
    await expect(page.locator('#loading-score')).toHaveText('17 sparkles');
    await expect(page.locator('#loading-sparks > *')).toHaveCount(0);
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
  } finally {
    release();
  }
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('#loading-play')).toBeHidden();
});
