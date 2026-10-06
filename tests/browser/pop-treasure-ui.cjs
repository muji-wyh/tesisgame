const { test, expect } = require('@playwright/test');
const { metrics, rendered } = require('./game-ui.cjs');

async function roomState(page) {
  return page.locator('#pop-reward-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));
}

async function settleScroll(page) {
  const started = Date.now();
  let previous, stableSince = started;
  await expect.poll(async () => {
    const offset = (await roomState(page)).scroll_offset;
    if (offset !== previous) {
      previous = offset;
      stableSince = Date.now();
    }
    // Integer offsets can repeat briefly while the final fractional momentum
    // is still active. Wait through that tail before pressing a chest.
    return Number.isFinite(offset) && Date.now() - started >= 1200 && Date.now() - stableSince >= 500;
  }, { timeout: 15000, intervals: [100, 150, 200], message: 'Treasure scrolling settles before the next gesture' }).toBe(true);
}

function insideViewport(rect, viewport, tolerance = 1) {
  return rect.x >= viewport.x - tolerance && rect.x + rect.width <= viewport.x + viewport.width + tolerance &&
    rect.y >= viewport.y - tolerance && rect.y + rect.height <= viewport.y + viewport.height + tolerance;
}

async function scrollChestIntoView(page, index) {
  await rendered(page);
  let room = await roomState(page);
  expect(room.visible, 'The treasure list is open before scrolling').toBe(true);
  expect(room.chests[index], `Chest ${index + 1} exists in the earned list`).toBeTruthy();
  for (let attempt = 0; attempt < 32; attempt++) {
    const rect = room.chests[index].rect, viewport = room.scroll_rect;
    if (insideViewport(rect, viewport)) return room;
    const bounds = await metrics(page);
    const desired = Math.max(0, Math.min(room.scroll_max,
      room.scroll_offset + rect.y + rect.height / 2 - viewport.y - viewport.height / 2));
    const distance = desired - room.scroll_offset;
    if (distance === 0) {
      await test.info().attach('unreachable-chest.png', {
        body: await page.screenshot({ scale: 'css' }), contentType: 'image/png'
      });
    }
    expect(Math.abs(distance), `An offscreen chest can be reached through the shared scroll area: ${JSON.stringify({
      index, rect, viewport, offset: room.scroll_offset, max: room.scroll_max, desired, bounds
    })}`).toBeGreaterThan(0);
    const x = bounds.x + (viewport.x + viewport.width / 2) * bounds.scale;
    const centerY = bounds.y + (viewport.y + viewport.height / 2) * bounds.scale;
    const mobileWebKit = page.context().browser().browserType().name() === 'webkit' &&
      Boolean(test.info().project.use.isMobile);
    if (mobileWebKit) {
      // Mobile WebKit has no wheel API. The shared scroller also accepts a
      // physical pointer drag, which cancels any chest hold as travel begins.
      const travel = Math.sign(distance) * Math.min(Math.abs(distance) * bounds.scale, viewport.height * bounds.scale * 0.6);
      await page.mouse.move(x, centerY + travel / 2);
      await page.mouse.down();
      try {
        await page.mouse.move(x, centerY - travel / 2, { steps: 8 });
        // Park the pointer before release so reaching a middle row does not
        // repeatedly fling past it on fast automation hardware.
        await rendered(page);
        await page.waitForTimeout(160);
      } finally {
        await page.mouse.up();
      }
    } else {
      await page.mouse.move(x, centerY);
      await page.mouse.wheel(0, Math.sign(distance) * Math.max(60, Math.min(1600, Math.abs(distance) * bounds.scale * 100 / 48)));
    }
    await settleScroll(page);
    const next = await roomState(page);
    expect(next.scroll_offset, 'A real scroll gesture moves the treasure list').not.toBe(room.scroll_offset);
    expect(next.opened_count, 'Scrolling never opens a chest').toBe(room.opened_count);
    room = next;
  }
  expect(insideViewport(room.chests[index].rect, room.scroll_rect), `Chest ${index + 1} is fully visible before interaction`).toBe(true);
  return room;
}

module.exports = { roomState, scrollChestIntoView, insideViewport };
