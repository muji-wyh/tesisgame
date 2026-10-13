const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, chooseMode, metrics, headerPoint, visibleColorCount } = require('./game-ui.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const reward = state => ({ fragments: state.fragment_count, tier: state.chest_tier, count: state.chest_count });
const center = rect => [rect[0] + rect[2] / 2, rect[1] + rect[3] / 2];

// Per-frame evidence and canvas images retain the short response without
// tracing every large WebGL frame or relying on slow cross-process polling.
test.use({ trace: 'off', deviceScaleFactor: 1 });

async function ready(page, mode) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return (state.mode || 'jelly') === mode && state.visible && !state.paused && state.phase === 'playing' &&
      state.tiles?.length >= 2 && state.tiles.every(tile => tile.settled) &&
      state.loot?.tap?.visible && !state.loot.tap.disabled && !state.loot.tap.active;
  }, { timeout: 20000, message: `${mode} exposes the real idle chest hit target` }).toBe(true);
  return jelly(page);
}

function screenPoint(rect, bounds) {
  const [x, y] = center(rect);
  return { x: bounds.x + x * bounds.scale, y: bounds.y + y * bounds.scale };
}

async function press(page, point, mobile) {
  if (mobile) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
}

async function observe(page, label, reduced) {
  await page.evaluate(({ label, reduced }) => {
    window.jellyChestTapObservation?.stop();
    const status = document.getElementById('game-status');
    const evidence = { label, reduced, frames: [], image: null, inputs: [], running: true, capturePending: false };
    const input = event => {
      if (event.target.id === 'canvas') evidence.inputs.push({ at: performance.now(), pointerType: event.pointerType,
        x: event.clientX, y: event.clientY });
    };
    document.addEventListener('pointerdown', input, true);
    const record = () => {
      if (!evidence.running) return;
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tap = state.loot?.tap;
      if (tap) {
        evidence.frames.push({ at: performance.now(), ...tap, mode: state.mode,
          chest: state.loot.rect, fragments: state.fragment_count, tier: state.chest_tier,
          count: state.chest_count, paused: state.paused, gameVisible: state.visible });
        const inCaptureBeat = reduced ? tap.active && tap.light > 0.2 :
          tap.active && tap.elapsed >= 0.24 && tap.elapsed <= 0.48;
        if (inCaptureBeat && !evidence.capturePending) {
          evidence.capturePending = true;
          // The snapshot is published before Godot draws this frame. Let the
          // native scene render before reading its canvas pixels.
          requestAnimationFrame(() => requestAnimationFrame(() => {
            if (!evidence.running) return;
            evidence.image = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
          }));
        }
      }
      evidence.frameId = requestAnimationFrame(record);
    };
    evidence.stop = () => {
      evidence.running = false;
      cancelAnimationFrame(evidence.frameId);
      document.removeEventListener('pointerdown', input, true);
    };
    window.jellyChestTapObservation = evidence;
    record();
  }, { label, reduced });
}

async function finishObservation(page, info, label, { capture = true } = {}) {
  const evidence = await page.evaluate(() => {
    const value = window.jellyChestTapObservation;
    value.stop();
    return { label: value.label, reduced: value.reduced, frames: value.frames, inputs: value.inputs, image: value.image };
  });
  const { image, ...timeline } = evidence;
  const path = info.outputPath(`${label}.json`);
  fs.writeFileSync(path, JSON.stringify(timeline, null, 2));
  await info.attach(label, { path, contentType: 'application/json' });
  if (capture) {
    expect(image, 'A real rendered frame captures the chest response near its highlight beat').toBeTruthy();
    const png = Buffer.from(image, 'base64');
    const imagePath = info.outputPath(`${label}.png`);
    fs.writeFileSync(imagePath, png);
    await info.attach(`${label}-canvas`, { path: imagePath, contentType: 'image/png' });
    expect(await visibleColorCount(page, png), 'The captured native canvas contains rendered game artwork').toBeGreaterThan(20);
  }
  return timeline;
}

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`Jelly chests answer a tap in place with ${reducedMotion} motion`, async ({ page }, info) => {
    test.setTimeout(150000);
    const reduced = reducedMotion === 'reduce', mobile = Boolean(info.project.use.isMobile);
    const errors = await openGame(page, { reducedMotion, mode: 'word_jelly' });
    for (const mode of ['word_jelly', 'jelly']) {
      if (mode === 'jelly') await chooseMode(page, mode);
      const opening = await ready(page, mode), bounds = await metrics(page);
      const point = screenPoint(opening.loot.tap.rect, bounds);
      const label = `${mode}-${reducedMotion}-tap`;
      expect(opening.loot.tap.rect[2] * bounds.scale, 'The chest retains a comfortable pointer/touch target').toBeGreaterThanOrEqual(43);
      expect(opening.loot.tap.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43);
      await observe(page, label, reduced);
      if (mobile) {
        await press(page, point, true);
        await press(page, point, true);
      } else {
        await page.mouse.dblclick(point.x, point.y, { delay: 40 });
      }
      await expect.poll(() => page.evaluate(() => window.jellyChestTapObservation.frames.some(frame => frame.active)),
        { message: 'The actual chest receives the trusted pointer gesture' }).toBe(true);
      await expect.poll(async () => (await jelly(page)).loot.tap.active,
        { message: 'The finite chest response returns to rest on its own' }).toBe(false);
      const evidence = await finishObservation(page, info, label);
      const active = evidence.frames.filter(frame => frame.active);
      expect(active.length).toBeGreaterThan(1);
      expect(evidence.inputs).toHaveLength(2);
      expect(new Set(evidence.inputs.map(input => input.pointerType))).toEqual(new Set([mobile ? 'touch' : 'mouse']));
      const starts = evidence.frames.filter((frame, index, frames) => frame.active && (!index || !frames[index - 1].active));
      expect(starts, 'A second press during the response cannot restart or stack the animation').toHaveLength(1);
      for (const [index, frame] of active.entries()) {
        expect(frame.rect, 'The input target does not grow, move, or rotate with the chest artwork').toEqual(opening.loot.tap.rect);
        expect(center(frame.chest), 'The chest stays at its original center').toEqual(center(opening.loot.rect));
        expect({ fragments: frame.fragments, tier: frame.tier, count: frame.count },
          'The playful response does not grant fragments or change chest tier').toEqual(reward(opening));
        if (index) expect(frame.elapsed, 'A repeated press never rewinds an active response').toBeGreaterThanOrEqual(active[index - 1].elapsed);
      }
      expect(Math.max(...active.map(frame => frame.light)), 'The response includes a visible light accent').toBeGreaterThan(0.2);
      if (reduced) {
        expect(active.every(frame => frame.scale === 1 && frame.rotation === 0),
          'Reduced motion keeps the chest steady and responds through light alone').toBe(true);
      } else {
        expect(Math.max(...active.map(frame => frame.scale)), 'The chest visibly grows above its resting size').toBeGreaterThan(1.5);
        expect(Math.min(...active.map(frame => frame.rotation)), 'The opening tilt moves in one direction').toBeLessThan(-0.05);
        expect(Math.max(...active.map(frame => frame.rotation)), 'The accent turns back through the other direction').toBeGreaterThan(0.1);
      }
      const after = await jelly(page);
      expect(after.loot.tap).toMatchObject({ active: false, scale: 1, rotation: 0, light: 0 });
      expect(reward(after)).toEqual(reward(opening));

      // Precompute both real control centers. Avoid querying snapshots between
      // gestures, which could consume the entire short effect on a slow runner.
      const currentBounds = await metrics(page), home = headerPoint(currentBounds, 'mode');
      const homePoint = { x: currentBounds.x + home.x * currentBounds.scale,
        y: currentBounds.y + home.y * currentBounds.scale };
      const chestPoint = screenPoint(after.loot.tap.rect, currentBounds);
      await observe(page, `${label}-home`, reduced);
      await press(page, chestPoint, mobile);
      await press(page, homePoint, mobile);
      await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
      await expect.poll(async () => (await jelly(page)).loot.tap.active).toBe(false);
      await chooseMode(page, mode);
      await ready(page, mode);
      await page.waitForTimeout(500);
      const returned = await jelly(page);
      expect(returned.loot.tap, 'Returning from Home cannot replay the interrupted tap response')
        .toMatchObject({ active: false, scale: 1, rotation: 0, light: 0 });
      expect(reward(returned)).toEqual(reward(opening));
      const lifecycle = await finishObservation(page, info, `${label}-home`, { capture: false });
      const pause = lifecycle.frames.findIndex(frame => frame.paused || !frame.gameVisible);
      expect(pause, 'The ordinary Home action pauses or hides the current Jelly game').toBeGreaterThanOrEqual(0);
      expect(lifecycle.frames.slice(pause).some(frame => frame.active),
        'No tap response remains active behind Home or resumes later').toBe(false);
    }
    expect(errors).toEqual([]);
  });
}
