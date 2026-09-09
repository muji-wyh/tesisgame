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

async function progressShell(page) {
  await useMaintainedShell(page);
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, route => route.fulfill({
    contentType: 'application/javascript',
    body: `window.Engine = class {
      static getMissingFeatures() { return []; }
      static load() { return Promise.resolve(); }
      startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
    };`
  }));
  await page.goto('/loader-test');
}

test('startup estimate pauses at 35 and 75 before 95, then follows real remaining data', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await expect(page.locator('#message')).toContainText('estimate');
  await page.evaluate(() => window.reportDownload(2 * 1048576, 10 * 1048576));
  for (const [milliseconds, percentage] of [[350, '35%'], [200, '35%'], [450, '75%'], [200, '75%'], [400, '95%']]) {
    await page.clock.runFor(milliseconds);
    await expect(page.locator('#loading-percent')).toHaveText(percentage);
  }
  await expect(page.locator('#download-status')).toContainText('2.0 / 10.0 MB');
  await page.evaluate(() => window.reportDownload(6 * 1048576, 10 * 1048576));
  await expect(page.locator('#loading-percent')).toHaveText('97%');
  await page.evaluate(() => window.reportDownload(10 * 1048576, 10 * 1048576));
  await expect(page.locator('#loading-percent')).toHaveText('99%');
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toHaveText('99%');
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#status')).toBeHidden();
});

test('fast readiness bypasses staged delays and failed startup never finishes the estimate', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#status')).toBeHidden();
  await page.reload();
  await page.clock.runFor(1700);
  await expect(page.locator('#loading-percent')).toHaveText('95%');
  await page.evaluate(() => window.wordBuddiesHost.fail('The game could not start.'));
  await page.clock.runFor(5000);
  await page.evaluate(() => window.reportDownload(100, 100));
  await expect(page.locator('#loading-percent')).toHaveText('95%');
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('#download-status')).toBeHidden();
});

test('hidden startup pauses pacing and reduced motion uses milestone steps', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await progressShell(page);
  await page.clock.runFor(200);
  await expect(page.locator('#loading-percent')).toHaveText('0%');
  await page.clock.runFor(150);
  await expect(page.locator('#loading-percent')).toHaveText('35%');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toHaveText('35%');
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(1300);
  await expect(page.locator('#loading-percent')).toHaveText('95%');
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
    await expect(page.locator('#progress')).toHaveAttribute('value');
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
