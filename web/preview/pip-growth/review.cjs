'use strict';

// Serial, browser-only design review. Does not start Godot or modify game saves.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium, webkit, devices } = require('@playwright/test');
const directory = __dirname;
const output = process.env.PIP_REVIEW_OUTPUT || path.join(directory, 'review-output');
const posesOnly = process.argv.includes('--poses-only');
const actionsOnly = process.argv.includes('--actions-only');
fs.mkdirSync(output, { recursive: true });
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.mp3': 'audio/mpeg', '.ttf': 'font/ttf' };
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
  if (actionsOnly) {
    await reviewActions(url, profiles, errors);
    assert.deepEqual(errors, []);
    console.log('All-action browser review passed; no physical-device or sound-quality claim.');
    return;
  }
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
      for (const age of posesOnly ? [12] : [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]) {
        await page.locator(`.age-tab[data-age="${age}"]`).click();
        await page.waitForFunction(wanted => window.pipGrowthPreview.snapshot().age === wanted && document.querySelector('#character-art svg'), age);
        assert.equal(await page.locator('.action-button').count(), Math.max(1, age - 2) + 2);
        assert.equal(await page.locator('#voice-select option').count(), Math.max(1, age - 2));
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true, `${profile.name} Age${age}: horizontal overflow`);
        await page.locator('#stage-review').screenshot({ path: path.join(output, `${profile.name}-age${age}.png`) });
      }
      await page.locator('.whole-journey').screenshot({ path: path.join(output, `${profile.name}-all-stages.png`) });
      await page.locator('#play-new-move').click();
      assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().action), null);
      assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().expression), 'encourage');
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
        await page.locator('.age-tab[data-age="3"]').click();
        assert.equal(await page.evaluate(() => window.pipGrowthPreview.snapshot().playing), false, 'Switching stage must stop previous voice.');
        await page.locator('#motion-toggle').click();
        await page.screenshot({ path: path.join(output, 'desktop-full.png'), fullPage: true });
      }
      console.log(`${profile.name}: ${posesOnly ? 'final wing poses' : 'Baby and ten ages'}, cumulative controls, responsive layout and reduced-motion state passed.`);
    } finally { await browser.close(); }
  }
  assert.deepEqual(errors, []);
  console.log('Browser review passed; actual-device and subjective listening review remain separate.');
}

async function reviewActions(url, profiles, errors) {
  const catalog = JSON.parse(fs.readFileSync(path.join(directory, 'action-catalog.json'), 'utf8'));
  for (const profile of profiles) {
    const browser = await profile.engine.launch({ headless: true });
    try {
      const context = await browser.newContext(profile.options);
      const page = await context.newPage();
      const audio = [];
      page.on('pageerror', cause => errors.push(`${profile.name}: ${cause.message}`));
      page.on('request', request => { if (/\.(mp3|wav|ogg)(?:\?|$)/.test(request.url())) audio.push(request.url()); });
      await page.goto(`${url}/actions.html`);
      await page.waitForFunction(() => window.pipActionsReview?.snapshot().ready);
      await page.evaluate(() => document.fonts.ready);
      const snapshot = () => page.evaluate(() => window.pipActionsReview.snapshot());
      const nonempty = () => page.locator('#pip-player').evaluate(canvas => {
        const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let colored = 0;
        for (let index = 3; index < pixels.length; index += 16) if (pixels[index]) colored++;
        return colored;
      });
      assert.equal((await snapshot()).total, catalog.actions.length);
      assert.equal(await page.locator('.motion-card').count(), catalog.actions.length);
      assert.equal((await snapshot()).playing, false, 'The grid must not autoplay on entry.');
      await page.locator('#reduced-motion').check();
      for (const action of catalog.actions) {
        await page.locator(`.motion-card[data-action="${action.id}"]`).click();
        await page.waitForFunction(id => window.pipActionsReview.snapshot().action === id &&
          document.getElementById('motion-player').getAttribute('aria-busy') === 'false', action.id);
        assert.ok(await nonempty() > 40, `${profile.name}: ${action.id} has actual visible artwork`);
        assert.equal((await snapshot()).playing, false, 'Reduced motion uses the native held pose.');
      }
      await page.locator('#category').selectOption('signature');
      await page.locator('#age').selectOption('0');
      assert.deepEqual((await snapshot()).visible, ['shell-rock', 'sleepy-nuzzle']);
      await page.locator('#category').selectOption('inherited');
      assert.deepEqual((await snapshot()).visible, ['inherited:wave']);
      await page.locator('#age').selectOption('12');
      await page.locator('#search').fill('high-five');
      assert.deepEqual((await snapshot()).visible, ['inherited:high-five']);
      await page.locator('#search').fill('not-an-existing-Pip-action');
      assert.equal((await snapshot()).visible.length, 0);
      assert.equal(await page.locator('#empty').isVisible(), true);
      await page.locator('#search').fill('');
      await page.locator('#category').selectOption('loading');
      await page.locator('#age').selectOption('loading');
      assert.deepEqual((await snapshot()).visible, ['loading:jump', 'loading:shy', 'loading:bonk']);
      await page.locator('.motion-card[data-action="loading:shy"]').click();
      await page.waitForFunction(() => window.pipActionsReview.snapshot().age === 'loading' &&
        document.getElementById('motion-player').getAttribute('aria-busy') === 'false');
      await page.locator('#motion-player').screenshot({ path: path.join(output, `${profile.name}-loading-pip.png`), scale: 'css' });
      await page.locator('#age').selectOption('all');
      await page.locator('#category').selectOption('celebration');
      await page.locator('.motion-card').click();
      await page.locator('#variant-age').selectOption('0');
      await page.waitForFunction(() => window.pipActionsReview.snapshot().age === 0 &&
        document.getElementById('motion-player').getAttribute('aria-busy') === 'false');
      await page.locator('#display-size').selectOption('52');
      assert.equal(Math.round((await page.locator('#pip-player').boundingBox()).width), 52);
      await page.locator('#motion-player').screenshot({ path: path.join(output, `${profile.name}-header-size.png`), scale: 'css' });
      await page.locator('#display-size').selectOption('256');
      await page.locator('#reduced-motion').uncheck();
      await page.locator('#replay').click();
      await page.waitForFunction(() => window.pipActionsReview.snapshot().playing &&
        window.pipActionsReview.snapshot().progress > .04);
      await page.locator('#play').click();
      const paused = (await snapshot()).progress;
      await page.waitForTimeout(100);
      assert.equal((await snapshot()).progress, paused);
      await page.locator('#timeline').focus();
      await page.keyboard.press('End');
      assert.equal((await snapshot()).progress, 1, 'The real range keyboard controls the last native frame.');
      await page.locator('#replay').click();
      await page.keyboard.press('Escape');
      assert.equal((await snapshot()).playing, false);
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.waitForFunction(() => window.pipActionsReview.snapshot().reducedMotion);
      assert.equal((await snapshot()).reducedMotion, true);
      await page.locator('#replay').click();
      assert.equal((await snapshot()).playing, false);
      assert.equal(await page.locator('#timeline').isDisabled(), true);
      assert.equal(await page.locator('#time').textContent(), 'Reduced-motion still');
      await page.locator('#category').selectOption('all');
      if (profile.name === 'desktop') {
        for (const width of [320, 390, 700, 844, 1366]) {
          await page.setViewportSize({ width, height: 900 });
          assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true,
            `All-actions review fits ${width}px without horizontal scrolling.`);
        }
      }
      await page.locator('#motion-player').screenshot({ path: path.join(output, `${profile.name}-all-actions-player.png`), scale: 'css' });
      await page.locator('.introduction').scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(output, `${profile.name}-all-actions.png`), scale: 'css' });
      if (profile.name === 'desktop') {
        await page.locator('#action-grid').screenshot({ path: path.join(output, 'all-pip-runtime-poses.png'), scale: 'css' });
      }
      await page.getByRole('link', { name: 'Growth journey', exact: true }).click();
      await page.waitForFunction(() => window.pipGrowthPreview?.snapshot().ready);
      assert.equal(await page.title(), "Pip's growth journey · Pip's world");
      assert.equal(await page.locator('.action-button').count(), 3);
      await page.getByRole('link', { name: 'All actions', exact: true }).click();
      await page.waitForFunction(() => window.pipActionsReview?.snapshot().ready);
      assert.equal(await page.locator('.motion-card').count(), catalog.actions.length);
      assert.deepEqual(audio, [], 'Reviewing actions and navigating never autoplays audio.');
      if (profile.name === 'desktop') {
        await page.emulateMedia({ reducedMotion: 'no-preference' });
        let release;
        const gate = new Promise(resolve => { release = resolve; });
        await page.route('**/art/pip-lv12*.png', async route => { await gate; await route.continue(); });
        try {
          await page.reload({ waitUntil: 'domcontentloaded' });
          await page.waitForFunction(() => window.pipActionsReview?.snapshot().ready);
          await page.locator('.motion-card[data-action="welcoming-guide"]').click();
          await page.locator('.motion-card[data-action="shell-rock"]').click();
          await page.waitForFunction(() => window.pipActionsReview.snapshot().action === 'shell-rock' &&
            window.pipActionsReview.snapshot().playing && window.pipActionsReview.snapshot().progress > .08);
          const beforeLateArt = (await snapshot()).progress;
          release();
          await page.waitForFunction(() => [...document.querySelectorAll('.motion-card canvas')].every(canvas => canvas.width === 120));
          assert.equal((await snapshot()).action, 'shell-rock');
          assert.ok((await snapshot()).progress >= beforeLateArt, 'An older image completion cannot restart the newer action.');
        } finally {
          release();
          await page.unrouteAll({ behavior: 'wait' });
        }
      }
      console.log(`${profile.name}: all${catalog.actions.length} poses, legal age filters, playback/pause/replay, keyboard timeline, 52px, reduced motion and review navigation passed.`);
      await context.close();
    } finally { await browser.close(); }
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => server.close());
