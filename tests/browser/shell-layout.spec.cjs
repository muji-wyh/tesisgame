const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');

const root = path.resolve(__dirname, '../..');

async function openShell(page) {
  const config = { executable: 'shell-review-engine', fileSizes: { 'shell-review-engine.wasm': 1 } };
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web/shell.html'), 'utf8'))
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', 'shell-review-engine.js')
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.addInitScript(() => {
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: true }));
    window.SpeechRecognition = class {
      constructor() { window.shellSpeech = this; }
      start() { setTimeout(() => this.onstart?.(), 0); }
      abort() { setTimeout(() => this.onend?.(), 0); }
    };
  });
  await page.route('**/shell-layout-test', route => route.fulfill({ contentType: 'text/html', body: shell }));
  await page.route('**/shell-review-engine.js', route => route.fulfill({ contentType: 'application/javascript', body: `
    window.Engine = class {
      static getMissingFeatures() { return []; }
      static load() { return Promise.resolve(); }
      startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
    };` }));
  await page.goto('/shell-layout-test');
  await page.evaluate(() => document.fonts.ready);
}

async function expectNoOverflow(page) {
  const overflow = await page.locator('#status').evaluate(element => ({
    horizontal: element.scrollWidth - element.clientWidth,
    vertical: element.scrollHeight - element.clientHeight
  }));
  expect(overflow.horizontal).toBeLessThanOrEqual(1);
  expect(overflow.vertical).toBeLessThanOrEqual(1);
}

for (const viewport of [{ width: 1473, height: 1175 }, { width: 390, height: 844 },
  { width: 320, height: 568 }, { width: 568, height: 320 }, { width: 320, height: 320 }]) {
  test(`maintained loading, recovery and speech remain readable at ${viewport.width}x${viewport.height}`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: 'reduce', colorScheme: 'light' });
    await page.clock.install({ time: new Date('2026-10-20T00:00:00Z') });
    await page.clock.pauseAt(new Date('2026-10-20T00:00:01Z'));
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await openShell(page);
    await expect(page.locator('#loading-themes')).toBeHidden();
    await expect(page.locator('#retry')).toBeHidden();
    await expectNoOverflow(page);
    for (const id of ['loading-toy', 'loading-duck', 'enter-game']) {
      const rect = await page.locator('#' + id).boundingBox();
      expect(rect.width).toBeGreaterThanOrEqual(44);
      expect(rect.height).toBeGreaterThanOrEqual(44);
    }
    await page.clock.runFor(17000);
    await expect(page.locator('#retry')).toBeHidden();
    await expectNoOverflow(page);
    await page.evaluate(() => window.wordBuddiesHost.ready());
    await page.clock.runFor(2200);
    await expect(page.locator('#enter-game')).toBeEnabled();
    await expectNoOverflow(page);
    await page.screenshot({ path: testInfo.outputPath('ready.png'), scale: 'css' });
    await page.locator('#enter-game').click();
    await expect(page.locator('#status')).toBeHidden();
    await page.evaluate(({ width, height }) => {
      const panelWidth = Math.min(width - 32, 760);
      window.wordBuddiesHost.speechBounds((width - panelWidth) / 2 / width, 24 / height, panelWidth / width, 112 / height);
      window.wordBuddiesHost.speechMode(true);
    }, viewport);
    await page.clock.runFor(20);
    await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
    await page.evaluate(() => {
      document.getElementById('speech-transcript').textContent = 'I see a friendly little duck beside a bright red rocket and a cheerful turtle';
    });
    const privacy = await page.locator('#speech-notice').evaluate(element => ({
      font: parseFloat(getComputedStyle(element).fontSize),
      fits: element.scrollHeight <= element.clientHeight + 1,
      bottom: element.getBoundingClientRect().bottom,
      panelBottom: document.getElementById('speech-panel').getBoundingClientRect().bottom
    }));
    expect(privacy.font).toBeGreaterThanOrEqual(12);
    expect(privacy.fits).toBe(true);
    expect(privacy.bottom).toBeLessThanOrEqual(privacy.panelBottom);
    await page.evaluate(() => window.shellSpeech.onerror?.({ error: 'not-allowed' }));
    await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'error');
    const recovery = await page.locator('#speech-status').evaluate(element => ({
      bottom: element.getBoundingClientRect().bottom,
      bubbleBottom: element.closest('.speech-bubble').getBoundingClientRect().bottom,
      privacyTop: document.getElementById('speech-notice').getBoundingClientRect().top
    }));
    expect(recovery.bottom, 'The complete microphone recovery instruction is visible.').toBeLessThanOrEqual(recovery.bubbleBottom + 1);
    expect(recovery.bottom).toBeLessThanOrEqual(recovery.privacyTop);
    await page.screenshot({ path: testInfo.outputPath('speech-recovery.png'), scale: 'css' });
    await page.evaluate(() => window.wordBuddiesHost.fail('The game could not start. Check your connection and try again.'));
    await expect(page.locator('#retry')).toBeVisible();
    await expect(page.locator('#retry')).toBeFocused();
    await expectNoOverflow(page);
    await page.screenshot({ path: testInfo.outputPath('startup-recovery.png'), scale: 'css' });
    expect(errors).toEqual([]);
  });
}
