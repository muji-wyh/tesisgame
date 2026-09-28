const { test, expect } = require('@playwright/test');
const { metrics, collectionBounds, openRewards, enterGame, rendered } = require('./game-ui.cjs');

function railClip(bounds, name) {
  const c = collectionBounds(bounds);
  return { x: bounds.x + c.x * bounds.scale, y: bounds.y + c[`${name}Top`] * bounds.scale,
    width: c.width * bounds.scale, height: c[`${name}Height`] * bounds.scale };
}

async function savedState(page) {
  return page.evaluate(() => ({ status: document.getElementById('game-status').textContent,
    room: localStorage.getItem('wordBuddies.playroom'), medals: localStorage.getItem('wordBuddies.medalProgress'),
    theme: document.querySelector('meta[name="theme-color"]').content }));
}

async function horizontalShift(page, before, after) {
  return page.evaluate(async sources => {
    const images = await Promise.all(sources.map(async source => {
      const image = new Image(); image.src = 'data:image/png;base64,' + source; await image.decode();
      const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, canvas.width, canvas.height);
    }));
    const [original, moved] = images;
    let best = { pixels: 0, error: Infinity };
    for (let shift = 0; shift <= 80; shift++) {
      let error = 0;
      for (let y = 6; y < original.height - 6; y += 2) for (let x = 6; x < original.width - 90; x += 2) {
        const a = (y * original.width + x + shift) * 4, b = (y * moved.width + x) * 4;
        for (let c = 0; c < 3; c++) error += Math.abs(original.data[a + c] - moved.data[b + c]);
      }
      if (error < best.error) best = { pixels: shift, error };
    }
    return best;
  }, [before, after].map(png => png.toString('base64')));
}

for (const ratio of [1, 2, 3]) test.describe(`horizontal room rails at DPR ${ratio}`, () => {
  test.use({ viewport: { width: 390, height: 650 }, deviceScaleFactor: ratio, hasTouch: true, reducedMotion: 'reduce' });
  test('theme rail tracks finger pixels without changing the world or moving the page', async ({ page, browserName }, testInfo) => {
    test.skip(browserName !== 'chromium', 'Trusted touch motion uses Chromium CDP.');
    await page.goto('/'); await enterGame(page); await openRewards(page);
    const bounds = await metrics(page), clip = railClip(bounds, 'theme');
    const start = { x: clip.x + 240, y: clip.y + clip.height / 2 };
    const saved = await savedState(page), client = await page.context().newCDPSession(page), measurements = [];
    try {
      await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
      await rendered(page);
      const before = await page.screenshot({ clip, scale: 'css' });
      for (const displacement of [20, 40, 60, 30]) {
        await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, x: start.x - displacement, y: start.y }] });
        await rendered(page);
        const measured = await horizontalShift(page, before, await page.screenshot({ clip, scale: 'css' }));
        measurements.push({ finger: displacement, content: measured.pixels });
        expect(Math.abs(measured.pixels - displacement), JSON.stringify(measurements)).toBeLessThanOrEqual(2);
      }
    } finally {
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await client.detach();
    }
    expect(await savedState(page)).toEqual(saved);
    expect(await page.evaluate(() => [scrollX, scrollY])).toEqual([0, 0]);
    await testInfo.attach('horizontal-touch-displacement', { body: JSON.stringify({ ratio, measurements }, null, 2), contentType: 'application/json' });
    await page.screenshot({ path: testInfo.outputPath('fixed-room-after-theme-swipe.png'), scale: 'css' });
  });
});

for (const input of ['mouse', 'touch']) for (const name of ['theme', 'shelf']) {
  test(`${input} ${name} rail swipe leaves the playground and other controls fixed without activation`, async ({ page, browserName }, testInfo) => {
    test.skip(input === 'touch' && browserName !== 'chromium', 'Trusted touch motion uses Chromium CDP.');
    await page.setViewportSize({ width: 390, height: 650 }); await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/'); await enterGame(page); await openRewards(page);
    const bounds = await metrics(page), c = collectionBounds(bounds), clip = railClip(bounds, name);
    const stationaryClip = { x: bounds.x + c.x * bounds.scale, y: bounds.y + c.padding * bounds.scale,
      width: c.width * bounds.scale, height: (c.top + 36 - c.padding) * bounds.scale };
    const otherClip = railClip(bounds, name === 'theme' ? 'shelf' : 'theme');
    // A neighboring theme tooltip can cast its shadow over the strip's outer edge.
    // Compare the card content to measure movement independently of that hover overlay.
    otherClip.y += 8;
    otherClip.height -= 16;
    const start = { x: clip.x + 240, y: clip.y + clip.height / 2 }, saved = await savedState(page);
    const client = input === 'touch' ? await page.context().newCDPSession(page) : null;
    try {
      if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
      else { await page.mouse.move(start.x, start.y); await page.mouse.down(); }
      await rendered(page);
      const before = await page.screenshot({ clip, scale: 'css' });
      const stationary = await page.screenshot({ clip: stationaryClip, scale: 'css' });
      const other = await page.screenshot({ clip: otherClip, scale: 'css' });
      for (let step = 1; step <= 5; step++) {
        const point = { x: start.x - step * 12, y: start.y };
        if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...point }] });
        else await page.mouse.move(point.x, point.y);
        await rendered(page);
      }
      expect((await horizontalShift(page, before, await page.screenshot({ clip, scale: 'css' }))).pixels).toBeGreaterThanOrEqual(58);
      expect((await page.screenshot({ clip: stationaryClip, scale: 'css' })).equals(stationary), 'The header and room title stay fixed.').toBe(true);
      const otherAfter = await page.screenshot({ clip: otherClip, scale: 'css' });
      if (!otherAfter.equals(other)) {
        await testInfo.attach('stationary-rail-before', { body: other, contentType: 'image/png' });
        await testInfo.attach('stationary-rail-after', { body: otherAfter, contentType: 'image/png' });
      }
      expect(otherAfter.equals(other), 'Only the dragged rail moves.').toBe(true);
    } finally {
      if (client) { await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await client.detach(); }
      else await page.mouse.up();
    }
    expect(await savedState(page)).toEqual(saved);
    await page.screenshot({ path: testInfo.outputPath(`${name}-${input}-swipe.png`), scale: 'css' });
  });
}

test('vertical dragging cannot scroll the fixed room page', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 }); await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/'); await enterGame(page); await openRewards(page);
  const bounds = await metrics(page), c = collectionBounds(bounds);
  const start = { x: bounds.x + (c.x + c.width / 2) * bounds.scale, y: bounds.y + (c.top + 80) * bounds.scale };
  const saved = await savedState(page);
  await page.mouse.move(start.x, start.y);
  const before = await page.screenshot({ scale: 'css' });
  await page.mouse.down(); await page.mouse.move(start.x, start.y - 60, { steps: 6 }); await page.mouse.up(); await rendered(page);
  expect((await page.screenshot({ scale: 'css' })).equals(before), 'A vertical drag leaves the fixed room layout unchanged.').toBe(true);
  expect(await savedState(page)).toEqual(saved);
  expect(await page.evaluate(() => ({ x: scrollX, y: scrollY,
    fits: document.documentElement.scrollHeight <= innerHeight && document.documentElement.scrollWidth <= innerWidth })))
    .toEqual({ x: 0, y: 0, fits: true });
  await page.screenshot({ path: testInfo.outputPath('fixed-room-320.png'), scale: 'css' });
});
