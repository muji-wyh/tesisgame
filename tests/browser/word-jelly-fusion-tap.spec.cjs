const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { enterGame, chooseMode, metrics } = require('./game-ui.cjs');

const snapshot = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const center = (rect, bounds) => ({ x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
  y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale });

test.use({ deviceScaleFactor: 1 });

async function pointerFor(page, touch) {
  const session = touch ? await page.context().newCDPSession(page) : null;
  let held = false;
  const points = point => [{ id: 0, ...point, radiusX: 6, radiusY: 6, force: 1 }];
  return {
    async down(point, move = true) {
      if (session) await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: points(point) });
      else { if (move) await page.mouse.move(point.x, point.y); await page.mouse.down(); }
      held = true;
    },
    async move(point) {
      if (session) await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: points(point) });
      else await page.mouse.move(point.x, point.y);
    },
    async up() {
      if (session) await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      else await page.mouse.up();
      held = false;
    },
    async close() {
      if (held) await this.up();
      if (session) await session.detach();
    }
  };
}

async function beginMerge(page, pointer) {
  const before = await snapshot(page), bounds = await metrics(page);
  const pairs = before.tiles.filter(tile => tile.visible && tile.settled && tile.jelly_kind === 'root' &&
    tile.word_candidate?.id && !tile.requires_read).flatMap(root => before.tiles.filter(tile => tile.visible &&
      tile.settled && tile.jelly_kind === 'picture' && tile.image_word?.id === root.word_candidate.id)
    .map(picture => ({ root, picture })));
  pairs.sort((a, b) => Number(a.root.column === a.picture.column) - Number(b.root.column === b.picture.column) ||
    a.root.word_candidate.text.length - b.root.word_candidate.text.length || b.picture.row - a.picture.row);
  expect(pairs.length, 'The real opening supplies an atomic word and its matching picture').toBeGreaterThan(0);
  const { root, picture } = pairs[0], from = center(root.rect, bounds);
  let to = center(picture.rect, bounds);
  await pointer.down(from);
  await pointer.move({ x: from.x, y: from.y - 16 });
  await pointer.move(to);
  await expect.poll(async () => {
    const current = await snapshot(page), target = current.tiles.find(tile => tile.id === picture.id);
    if (!target?.settled) return false;
    if (current.drag.target === picture.id) return true;
    to = center(target.rect, bounds);
    await pointer.move(to);
    return false;
  }, { intervals: [30], message: 'The real held root contacts its matching picture' }).toBe(true);
  await pointer.up();
  return { before, root, picture, bounds, point: to };
}

async function observe(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    const trace = window.fusionTapTrace = { phase: 'merge', events: [], timeline: [], frames: [] };
    const read = () => {
      const value = JSON.parse(status.dataset.jelly || '{}');
      if (!trace.merge) trace.merge = value.fusions?.find(fusion => fusion.operation === 'merge');
      return { at: performance.now(), phase: trace.phase, cleared: value.cleared_pairs, merged: value.merged_count,
        drag: value.drag, effects: value.fusion_effects, tiles: value.tiles?.map(tile => ({ id: tile.id,
          settled: tile.settled, word: tile.word?.id, kind: tile.jelly_kind })),
        fusions: value.fusions?.map(fusion => ({ id: fusion.attempt_id, operation: fusion.operation,
          elapsed: fusion.elapsed, duration: fusion.duration, a: fusion.a_id, b: fusion.b_id,
          result: fusion.result?.id, word: fusion.word?.id, held: Boolean(fusion.held_for_drag) })) };
    };
    const record = () => {
      const value = read();
      trace.timeline.push(value);
    };
    const input = event => {
      trace.events.push({ type: event.type, trusted: event.isTrusted,
        pointerType: event.pointerType, x: event.clientX, y: event.clientY, ...read() });
      if (trace.phase === 'merge' && event.type === 'pointerup') trace.phase = 'probe';
    };
    window.addEventListener('pointerdown', input, true);
    window.addEventListener('pointerup', input, true);
    const observer = new MutationObserver(record);
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    window.stopFusionTapTrace = () => {
      observer.disconnect();
      window.removeEventListener('pointerdown', input, true);
      window.removeEventListener('pointerup', input, true);
    };
    record();
  });
}

async function retain(page, info, scenario) {
  const trace = await page.evaluate(() => {
    window.stopFusionTapTrace?.();
    return window.fusionTapTrace;
  });
  if (!trace) return;
  for (const frame of trace.frames) {
    const filename = info.outputPath(`${scenario}-${frame.name}.png`);
    fs.writeFileSync(filename, Buffer.from(frame.raw, 'base64'));
    await info.attach(`${scenario}-${frame.name}`, { path: filename, contentType: 'image/png' });
  }
  const filename = info.outputPath(`${scenario}-timeline.json`);
  fs.writeFileSync(filename, JSON.stringify({ viewport: page.viewportSize(),
    ...trace, frames: trace.frames.map(({ raw, ...frame }) => frame) }, null, 2));
  await info.attach(`${scenario}-timeline`, { path: filename, contentType: 'application/json' });
}

for (const scenario of ['early repeated taps', 'short tap crossing natural completion', 'long hold']) {
  test(`Word Jelly ${scenario} on a merging result`, async ({ page }, info) => {
    test.skip(!['desktop-chromium', 'android-chromium'].includes(info.project.name),
      'This timing regression covers desktop mouse and native Android touch injection.');
    test.setTimeout(90000);
    const touch = info.project.name === 'android-chromium';
    // Keep desktop geometry while allowing several real software-rendered frames
    // within the unchanged 760 ms union. Android keeps its phone viewport.
    if (!touch) await page.setViewportSize({ width: 960, height: 600 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/');
    await enterGame(page, { home: true });
    await chooseMode(page, 'word_jelly');
    await expect.poll(async () => {
      const current = await snapshot(page);
      return current.mode === 'word_jelly' && current.visible && current.phase === 'playing' &&
        current.tiles?.length > 0 && current.tiles.every(tile => tile.settled);
    }, { timeout: 20000 }).toBe(true);
    const pointer = await pointerFor(page, touch);
    try {
      // Warm the actual union material before measuring a short overlapping input.
      const warmup = await beginMerge(page, pointer);
      await expect.poll(async () => {
        const current = await snapshot(page);
        return current.merged_count === warmup.before.merged_count + 1 && !current.fusions.length &&
          current.tiles.every(tile => tile.settled);
      }, { intervals: [30] }).toBe(true);
      await observe(page);
      const joined = await beginMerge(page, pointer);
      // The cursor is already at the real drop point. Avoid status round trips
      // and redundant mouse movement inside the unchanged short union window.
      if (scenario.startsWith('short')) await page.waitForTimeout(touch ? 350 : 250);
      await pointer.down(joined.point, false);
      if (scenario === 'long hold') {
        await page.screenshot({ path: info.outputPath('long-hold-merging.png'), scale: 'css' });
        await page.waitForTimeout(650);
      }
      else if (scenario.startsWith('short')) {
        await page.waitForFunction(() => {
          const current = JSON.parse(document.getElementById('game-status').dataset.jelly || '{}');
          const id = window.fusionTapTrace.merge?.attempt_id;
          return id && !current.fusions.some(item => item.attempt_id === id);
        }, undefined, { polling: 20, timeout: 1500 });
      }
      await pointer.up();
      if (scenario === 'early repeated taps') {
        await pointer.down(joined.point, false);
        await pointer.up();
      }
      const fusion = await page.evaluate(() => window.fusionTapTrace.merge);
      expect(fusion, 'The real drag starts a collectable manual union').toBeTruthy();
      expect(fusion.duration, 'A collect tap does not shorten the existing union').toBeCloseTo(.76, 5);
      expect(fusion.result.word.id).toBe(joined.root.word_candidate.id);
      const events = await page.evaluate(() => window.fusionTapTrace.events.filter(event => event.phase === 'probe'));
      expect(events).toHaveLength(scenario === 'early repeated taps' ? 4 : 2);
      expect(events.every(event => event.trusted && event.pointerType === (touch ? 'touch' : 'mouse'))).toBe(true);
      expect(events.filter(event => event.type === 'pointerdown').every(event =>
        event.fusions.some(item => item.id === fusion.attempt_id)),
      'Every regression press reaches the same genuinely unfinished union').toBe(true);
      for (let index = 0; index < events.length; index += 2) {
        const heldMs = events[index + 1].at - events[index].at;
        if (scenario === 'long hold') expect(heldMs).toBeGreaterThanOrEqual(500);
        else expect(heldMs, 'Every regression gesture remains a short collection tap').toBeLessThan(500);
      }
      if (scenario.startsWith('short')) {
        expect(events[1].fusions.some(item => item.id === fusion.attempt_id), 'Release crosses the natural union boundary').toBe(false);
      } else if (scenario === 'early repeated taps') {
        expect(events[1].fusions.some(item => item.id === fusion.attempt_id), 'The early tap releases before the merge ends').toBe(true);
      }
      if (scenario === 'long hold') {
        await expect.poll(async () => {
          const current = await snapshot(page);
          return !current.fusions.length && current.tiles.some(tile => tile.id === fusion.result.id && tile.settled);
        }, { intervals: [30] }).toBe(true);
        expect((await snapshot(page)).cleared_pairs, 'A long press never queues collection').toBe(joined.before.cleared_pairs);
        const heldTrace = await page.evaluate(() => window.fusionTapTrace);
        expect(heldTrace.timeline.some(frame => frame.fusions.some(item => item.operation === 'collect'))).toBe(false);
        await page.screenshot({ path: info.outputPath('long-hold-result-retained.png'), scale: 'css' });
        await page.evaluate(() => { window.fusionTapTrace.phase = 'settled-retry'; });
        const retained = (await snapshot(page)).tiles.find(tile => tile.id === fusion.result.id);
        await pointer.down(center(retained.rect, await metrics(page)));
        await pointer.up();
      }
      await expect.poll(async () => (await snapshot(page)).cleared_pairs,
        { intervals: [30], message: 'One accepted short tap collects the exact completed word once' })
        .toBe(joined.before.cleared_pairs + 1);
      await expect.poll(async () => (await snapshot(page)).fusions.length, { intervals: [30] }).toBe(0);
      const after = await snapshot(page), trace = await page.evaluate(() => window.fusionTapTrace);
      for (let index = 0; index < events.length; index += 2) {
        expect(trace.timeline.some(frame => frame.at > events[index].at && frame.at < events[index + 1].at &&
          frame.fusions.some(item => item.id === fusion.attempt_id && item.held)),
        'The game owns each press during the original fusion, beyond the browser event snapshot').toBe(true);
      }
      expect(after.merged_count).toBe(joined.before.merged_count + 1);
      expect(after.tiles.some(tile => [joined.root.id, joined.picture.id, fusion.result.id].includes(tile.id))).toBe(false);
      expect(after.tiles.map(tile => tile.id)).toEqual(expect.arrayContaining(joined.before.tiles
        .filter(tile => ![joined.root.id, joined.picture.id].includes(tile.id)).map(tile => tile.id)));
      const collections = new Map(trace.timeline.flatMap(frame => frame.fusions)
        .filter(item => item.operation === 'collect').map(item => [item.id, item]));
      expect(collections.size, 'Repeated taps cannot duplicate the collection operation').toBe(1);
      expect([...collections.values()][0]).toMatchObject({ a: fusion.result.id, word: fusion.word.id });
      if (scenario === 'early repeated taps') {
        const released = events[1].fusions.find(item => item.id === fusion.attempt_id);
        expect(trace.timeline.some(frame => frame.at > events[1].at && frame.fusions.some(item =>
          item.id === fusion.attempt_id && item.elapsed > released.elapsed + .08)),
        'The accepted tap leaves the original union running instead of forcing it to finish').toBe(true);
      }
      expect(errors).toEqual([]);
      await page.screenshot({ path: info.outputPath(`${scenario.replaceAll(' ', '-')}-collected-once.png`), scale: 'css' });
    } finally {
      await pointer.close();
      await retain(page, info, scenario.replaceAll(' ', '-'));
    }
  });
}
