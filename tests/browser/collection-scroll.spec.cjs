const { test, expect } = require('@playwright/test');
const { metrics, worldControl, enterGame, rendered } = require('./game-ui.cjs');

async function savedState(page) {
  return page.evaluate(() => ({ status: document.getElementById('game-status').textContent,
    growth: localStorage.getItem('growWithPip.growth.v1'), medals: localStorage.getItem('wordBuddies.medalProgress'),
    presentation: localStorage.getItem('pipAndWords.presentation.v1'),
    theme: document.querySelector('meta[name="theme-color"]').content }));
}

async function themeDragOrigin(page) {
  const rect = await worldControl(page, 5), bounds = await metrics(page);
  return { bounds, point: { x: bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    y: bounds.y + (rect.y + rect.height / 2) * bounds.scale } };
}

for (const ratio of [1, 2, 3]) test.describe(`Home theme scrolling at DPR ${ratio}`, () => {
  test.use({ viewport: { width: 390, height: 650 }, deviceScaleFactor: ratio, hasTouch: true, reducedMotion: 'reduce' });
  test('dragging a theme follows the finger without choosing it or moving the page', async ({ page, browserName }, testInfo) => {
    test.skip(browserName !== 'chromium', 'Trusted touch motion uses Chromium CDP.');
    await page.goto('/'); await enterGame(page, { home: true });
    const { bounds, point } = await themeDragOrigin(page);
    const saved = await savedState(page), client = await page.context().newCDPSession(page), measurements = [];
    try {
      await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
      await rendered(page);
      const initial = (await metrics(page)).library.scroll_offset;
      for (const displacement of [20, 40, 60, 30]) {
        await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, x: point.x, y: point.y - displacement }] });
        await rendered(page);
        const measured = ((await metrics(page)).library.scroll_offset - initial) * bounds.scale;
        measurements.push({ finger: displacement, content: measured });
        expect(Math.abs(measured - displacement), JSON.stringify(measurements)).toBeLessThanOrEqual(2);
      }
    } finally {
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await client.detach();
    }
    expect(await savedState(page)).toEqual(saved);
    expect((await metrics(page)).library.visible).toBe(true);
    expect(await page.evaluate(() => [scrollX, scrollY])).toEqual([0, 0]);
    await testInfo.attach('home-theme-touch-displacement', { body: JSON.stringify({ ratio, measurements }, null, 2), contentType: 'application/json' });
    await page.screenshot({ path: testInfo.outputPath('home-after-theme-swipe.png'), scale: 'css' });
  });
});

for (const input of ['mouse', 'touch']) {
  test(`${input} swiping a Home theme leaves the header fixed without activation`, async ({ page, browserName }, testInfo) => {
    test.skip(input === 'touch' && browserName !== 'chromium', 'Trusted touch motion uses Chromium CDP.');
    await page.setViewportSize({ width: 390, height: 650 }); await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/'); await enterGame(page, { home: true });
    const { bounds, point } = await themeDragOrigin(page), saved = await savedState(page);
    const [, top] = bounds.library.viewport_rect;
    const headerClip = { x: bounds.x, y: bounds.y, width: bounds.width * bounds.scale, height: top * bounds.scale };
    const client = input === 'touch' ? await page.context().newCDPSession(page) : null;
    try {
      if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
      else { await page.mouse.move(point.x, point.y); await page.mouse.down(); }
      await rendered(page);
      const initial = (await metrics(page)).library.scroll_offset;
      const header = await page.screenshot({ clip: headerClip, scale: 'css' });
      for (let step = 1; step <= 5; step++) {
        const moved = { x: point.x, y: point.y - step * 12 };
        if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...moved }] });
        else await page.mouse.move(moved.x, moved.y);
        await rendered(page);
      }
      expect(((await metrics(page)).library.scroll_offset - initial) * bounds.scale).toBeGreaterThanOrEqual(58);
      expect((await page.screenshot({ clip: headerClip, scale: 'css' })).equals(header), 'The Home header stays fixed.').toBe(true);
    } finally {
      if (client) { await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await client.detach(); }
      else await page.mouse.up();
    }
    expect(await savedState(page)).toEqual(saved);
    expect((await metrics(page)).library.visible).toBe(true);
    await page.screenshot({ path: testInfo.outputPath(`home-theme-${input}-swipe.png`), scale: 'css' });
  });
}
