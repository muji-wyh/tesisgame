const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);

async function useMaintainedShell(page) {
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8')
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', `${config.executable}.js`)
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.route('**/loader-test*', route => route.fulfill({ contentType: 'text/html', body: shell }));
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
