const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { enterGame, activateLibraryControl, waitForCampaignMap,
  metrics, tap, seedPipLevel } = require('./game-ui.cjs');
const { seedCampaign } = require('./jelly-campaign-fixture.cjs');

const label = process.env.JELLY_PERF_LABEL;
const repeats = Number(process.env.JELLY_PERF_REPEATS || 3);
test.skip(!label, 'Set JELLY_PERF_LABEL for the opt-in crowded-board runtime measurement.');
test.use({ trace: 'off' });
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const center = (rect, bounds) => ({
  x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
  y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale
});

async function press(page, rect, mouse = false) {
  if (mouse) {
    const point = center(rect, await metrics(page));
    await page.mouse.click(point.x, point.y);
  } else await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
}

async function fillBoard(page, first, mouse) {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  if (first) await page.goto('/');
  else await page.reload();
  await expect(page.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 180000 });
  await enterGame(page, { home: true });
  if (mouse) {
    const controls = (await metrics(page)).library.controls;
    const control = controls.find(item => item.name === 'Mode_word_jelly' && item.visible);
    expect(control).toBeTruthy();
    await press(page, control.rect, true);
  } else await activateLibraryControl(page, 'Mode_word_jelly');
  const map = await waitForCampaignMap(page), stage = map.stage_nodes.find(item => item.number === 1);
  await press(page, [stage.rect.x, stage.rect.y, stage.rect.width, stage.rect.height], mouse);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.tiles.length === 15 &&
      state.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true);
  for (let count = 0; count < 8 && (await jelly(page)).tiles.length < 35; count++) {
    const state = await jelly(page);
    expect(state.preview.enabled).toBe(true);
    await press(page, state.preview.rect, mouse);
    await expect.poll(async () => {
      const current = await jelly(page);
      return current.generated_tiles > state.generated_tiles && current.tiles.every(tile => tile.settled);
    }).toBe(true);
  }
  expect((await jelly(page)).tiles).toHaveLength(35);
}

async function prepareCollect(page) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.filter(tile => tile.jelly_kind === 'root' && tile.word_candidate?.id)
    .sort((a, b) => a.rect[1] - b.rect[1]).find(tile =>
      before.tiles.some(other => other.jelly_kind === 'picture' && other.image_word?.id === tile.word_candidate.id));
  const target = before.tiles.find(tile => tile.jelly_kind === 'picture' && tile.image_word?.id === source?.word_candidate.id);
  expect(source && target).toBeTruthy();
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(from.x, from.y - 16);
  await page.mouse.move(to.x, to.y, { steps: 4 });
  await page.mouse.up();
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.merged_count > before.merged_count && state.tiles.every(tile => tile.settled) &&
      state.collect_button.enabled;
  }).toBe(true);
  expect((await jelly(page)).tiles).toHaveLength(34);
}

async function startFrames(page, duration) {
  await page.evaluate(duration => {
    const samples = [], longTasks = [];
    let observer;
    const supported = typeof PerformanceObserver !== 'undefined' &&
      PerformanceObserver.supportedEntryTypes?.includes('longtask');
    if (supported) {
      observer = new PerformanceObserver(list => longTasks.push(...list.getEntries().map(entry =>
        ({ start: entry.startTime, duration: entry.duration }))));
      observer.observe({ entryTypes: ['longtask'] });
    }
    const started = performance.now();
    let previous = null;
    window.jellyRuntimeFrames = { done: false };
    const frame = now => {
      if (previous !== null) samples.push(now - previous);
      previous = now;
      if (now - started < duration) return requestAnimationFrame(frame);
      observer?.disconnect();
      const canvas = document.getElementById('canvas'), gl = canvas.getContext('webgl2');
      const debug = gl?.getExtension('WEBGL_debug_renderer_info');
      window.jellyRuntimeFrames = { done: true, samples, longTasks, longTasksSupported: Boolean(supported),
        elapsed: now - started, visibility: document.visibilityState,
        renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null };
    };
    requestAnimationFrame(frame);
  }, duration);
}

function summarize(measurement) {
  const sorted = measurement.samples.slice().sort((a, b) => a - b);
  const percentile = fraction => sorted[Math.ceil(sorted.length * fraction) - 1];
  return { ...measurement, frames: sorted.length, p50_ms: percentile(.5), p95_ms: percentile(.95),
    p99_ms: percentile(.99), over_33ms: sorted.filter(value => value > 33.4).length,
    over_50ms: sorted.filter(value => value > 50).length };
}

async function finishTrace(session, info, name) {
  const completed = new Promise(resolve => session.once('Tracing.tracingComplete', resolve));
  await session.send('Tracing.end');
  const { stream } = await completed;
  const chunks = [];
  let eof = false;
  while (!eof) {
    const result = await session.send('IO.read', { handle: stream });
    chunks.push(Buffer.from(result.data, result.base64Encoded ? 'base64' : 'utf8'));
    eof = result.eof;
  }
  await session.send('IO.close', { handle: stream });
  fs.writeFileSync(info.outputPath(`${name}-trace.json`), Buffer.concat(chunks));
}

for (const scenario of ['drag', 'auto-merge', 'auto-collect']) {
  test(`crowded-board ${scenario} rendered browser intervals`, async ({ page }, info) => {
    test.setTimeout(900000);
    page.on('pageerror', error => console.log('Runtime page error: ' + error.message));
    page.on('console', message => {
      if (message.type() === 'error') console.log('Runtime console error: ' + message.text());
    });
    test.skip(scenario === 'drag' && !info.project.name.includes('desktop'),
      'The iPad profile verifies automatic actions; a Windows mouse is not an iPad touch-latency measurement.');
    await seedPipLevel(page, 3);
    await seedCampaign(page, { seconds: 900, quota: 99, balance: 100000 });
    const mouse = info.project.name.includes('desktop');
    const results = [];
    for (let repeat = 0; repeat < repeats; repeat++) {
      await fillBoard(page, repeat === 0, mouse);
      if (scenario === 'auto-collect') await prepareCollect(page);
      const before = await jelly(page);
      const bounds = await metrics(page);
      let trace;
      if (process.env.JELLY_PERF_TRACE && mouse && repeat === 0) {
        trace = await page.context().newCDPSession(page);
        await trace.send('Profiler.enable');
        await trace.send('Profiler.start');
        await trace.send('Tracing.start', { categories: 'devtools.timeline,v8,toplevel,blink,disabled-by-default-gpu.service',
          transferMode: 'ReturnAsStream' });
      }
      if (scenario === 'drag') {
        const source = before.tiles.filter(tile => tile.jelly_kind === 'root').sort((a, b) => a.rect[1] - b.rect[1])[0];
        const from = center(source.rect, bounds);
        await page.mouse.move(from.x, from.y);
        await page.mouse.down();
        await page.mouse.move(from.x, from.y - 20);
        await startFrames(page, 4000);
        const started = Date.now();
        while (Date.now() - started < 4100) {
          const phase = (Date.now() - started) / 420;
          const rect = before.board_rect, pitch = rect[2] / 5;
          const x = bounds.x + (rect[0] + rect[2] * (.50 + Math.sin(phase) * .18)) * bounds.scale;
          const y = bounds.y + (rect[1] + pitch * .30) * bounds.scale;
          await page.mouse.move(x, y);
          await page.waitForTimeout(16);
        }
      } else {
        await startFrames(page, 9000);
        const action = scenario === 'auto-merge' ? before.powerup_buttons.auto_merge : before.collect_button;
        expect(action.enabled).toBe(true);
        await press(page, action.rect, mouse);
      }
      await expect.poll(() => page.evaluate(() => window.jellyRuntimeFrames.done), { timeout: 20000 }).toBe(true);
      const measurement = summarize(await page.evaluate(() => window.jellyRuntimeFrames));
      if (trace) {
        const { profile } = await trace.send('Profiler.stop');
        fs.writeFileSync(info.outputPath(`${label}-${scenario}-cpu.json`), JSON.stringify(profile));
        await finishTrace(trace, info, `${label}-${scenario}`);
        await trace.detach();
      }
      const after = await jelly(page);
      expect(measurement.visibility).toBe('visible');
      expect(measurement.frames).toBeGreaterThan(10);
      expect(after.phase).toBe('playing');
      if (scenario === 'drag') {
        expect(after.drag.source).toBeGreaterThanOrEqual(0);
        await page.mouse.up();
      } else if (scenario === 'auto-merge') expect(after.merged_count).toBeGreaterThan(before.merged_count);
      else expect(after.cleared_pairs).toBeGreaterThan(before.cleared_pairs);
      results.push({ repeat: repeat + 1, before_bodies: before.tiles.length, after_bodies: after.tiles.length,
        before_merged: before.merged_count, after_merged: after.merged_count,
        collected: after.cleared_pairs - before.cleared_pairs, ...measurement });
      if (repeat === 0) await page.screenshot({ path: info.outputPath(`${label}-${scenario}.png`), scale: 'css' });
    }
    const report = { protocol: 'word-jelly-browser-intervals-v1', label, scenario, project: info.project.name,
      browser: page.context().browser().version(), viewport: page.viewportSize(), repeats: results,
      scope: 'Windows-hosted browser lab; normal motion, no CPU/network throttle. rAF intervals include drawing and driver work. Auto Collect uses 34 live bodies and one manually completed word; the separate native fixture covers 35 Lv1-9 batch targets. Not physical Chrome/iPad device FPS or field RUM.' };
    fs.writeFileSync(info.outputPath(`${label}-${scenario}.json`), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({ label, scenario, project: info.project.name,
      p95_ms: results.map(row => row.p95_ms), over_50ms: results.map(row => row.over_50ms) }));
  });
}
