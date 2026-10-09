'use strict';

// Serial, browser-only design review. Does not start Godot or modify game saves.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium, webkit, devices } = require('@playwright/test');
const directory = __dirname;
const output = path.join(directory, 'review-output');
const posesOnly = process.argv.includes('--poses-only');
fs.mkdirSync(output, { recursive: true });
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.mp3': 'audio/mpeg', '.ttf': 'font/ttf' };
const server = http.createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const filename = path.resolve(directory, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!filename.startsWith(directory + path.sep) || !fs.existsSync(filename) || fs.statSync(filename).isDirectory()) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(filename).pipe(response);
});

async function run() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const errors = [];
  const profiles = [
    { name: 'desktop', engine: chromium, options: { viewport: { width: 1440, height: 1040 }, deviceScaleFactor: 1 } },
    { name: 'phone-portrait', engine: webkit, options: { ...devices['iPhone 13'] } },
    { name: 'short-landscape', engine: chromium, options: { viewport: { width: 844, height: 390 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 } }
  ];
  for (const profile of posesOnly ? profiles.slice(0, 1) : profiles) {
    const browser = await profile.engine.launch({ headless: true });
    try {
      const context = await browser.newContext(profile.options);
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(`${profile.name}: ${error.message}`));
      await page.goto(url);
      await page.waitForFunction(() => window.pipGrowthPreview?.snapshot().ready);
      await page.evaluate(() => document.fonts.ready);
      await page.locator('#motion-toggle').click();
      for (let level = posesOnly ? 12 : 3; level <= 12; level++) {
        await page.locator(`.level-tab[data-level="${level}"]`).click();
        await page.waitForFunction(wanted => window.pipGrowthPreview.snapshot().level === wanted && document.querySelector('#character-art svg'), level);
        assert.equal(await page.locator('.action-button').count(), level - 2);
        assert.equal(await page.locator('#voice-select option').count(), level - 2);
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true, `${profile.name} Lv${level}: horizontal overflow`);
        await page.locator('#stage-review').screenshot({ path: path.join(output, `${profile.name}-lv${level}.png`) });
      }
      await page.locator('.whole-journey').screenshot({ path: path.join(output, `${profile.name}-all-stages.png`) });
      await page.locator('#play-new-move').click();
      assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().action), null);
      assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().expression), 'delighted');
      await page.locator('#motion-toggle').click();
      if (profile.name === 'desktop') {
        const actions = posesOnly ? ['high-five', 'stretch'] : ['wave', 'look', 'high-five', 'peekaboo', 'stretch', 'hop', 'dance-sway', 'flutter', 'dance-wave', 'dance-hop'];
        for (const id of actions) {
          await page.locator(`[data-action="${id}"]`).click();
          await page.waitForTimeout(id === 'hop' ? 650 : 700);
          await page.locator('#character-art').screenshot({ path: path.join(output, `action-${id}.png`) });
          assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().action), id);
        }
        await page.waitForTimeout(3400);
        assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().action), null);
        await page.locator('#play-voice').click();
        await page.waitForFunction(() => window.pipGrowthPreview.snapshot().playing);
        await page.waitForTimeout(700);
        assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().playing), true);
        await page.locator('.level-tab[data-level="3"]').click();
        assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().playing), false, 'Switching stage must stop previous voice.');
        await page.locator('#motion-toggle').click();
        await page.screenshot({ path: path.join(output, 'desktop-full.png'), fullPage: true });
      }
      console.log(`${profile.name}: ${posesOnly ? 'final wing poses' : 'ten stages'}, cumulative controls, responsive layout and reduced-motion state passed.`);
    } finally { await browser.close(); }
  }
  assert.deepEqual(errors, []);
  console.log('Browser review passed; actual-device and subjective listening review remain separate.');
}
run().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => server.close());
