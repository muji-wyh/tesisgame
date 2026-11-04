const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { enterGame, waitForCampaignMap, metrics, seedPipLevel } = require('./game-ui.cjs');
const { recipe } = require('./jelly-campaign-fixture.cjs');

const label = process.env.JELLY_IDLE_LABEL;
test.skip(!label, 'Set JELLY_IDLE_LABEL to collect the opt-in paired idle diagnostic.');
test.use({ trace: 'off' });
const state = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
async function click(page, rect) {
  const b = await metrics(page);
  await page.mouse.click(b.x + (rect[0] + rect[2] / 2) * b.scale, b.y + (rect[1] + rect[3] / 2) * b.scale);
}
function summarize(row) {
  const sorted = row.samples.slice().sort((a, b) => a - b);
  const percentile = q => sorted[Math.ceil(sorted.length * q) - 1];
  return { ...row, frames: sorted.length, p50_ms: percentile(.5), p95_ms: percentile(.95),
    mean_ms: sorted.reduce((sum, n) => sum + n, 0) / sorted.length,
    draws_per_frame: row.draws / sorted.length };
}
async function measure(page) {
  return page.evaluate(() => new Promise(resolve => {
    const samples = []; let previous = null, started, draws;
    const frame = now => {
      if (previous === null) { previous = now; started = now; draws = window.idleDrawCalls; }
      else { samples.push(now - previous); previous = now; }
      if (now - started < 2500) return requestAnimationFrame(frame);
      const gl = document.getElementById('canvas').getContext('webgl2');
      const debug = gl?.getExtension('WEBGL_debug_renderer_info');
      resolve({ samples, draws: window.idleDrawCalls - draws, elapsed: now - started,
        renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null,
        visibility: document.visibilityState, dpr: devicePixelRatio,
        end_state: JSON.parse(document.getElementById('game-status').dataset.jelly || '{}') });
    };
    requestAnimationFrame(frame);
  }));
}

for (const count of [21, 49]) test(`settled ${count}-body idle budget`, async ({ page }, info) => {
  test.setTimeout(300000);
  const errors = [], windows = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.addInitScript(() => {
    window.idleDrawCalls = 0;
    for (const prototype of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype].filter(Boolean))
      for (const name of ['drawArrays', 'drawElements', 'drawRangeElements', 'drawArraysInstanced', 'drawElementsInstanced']) {
        const original = prototype[name]; if (!original) continue;
        prototype[name] = function(...args) { window.idleDrawCalls++; return original.apply(this, args); };
      }
  });
  await seedPipLevel(page, 3);
  const plan = { ...recipe({ seconds: 900, quota: 99 }), spawn_interval: 60 };
  await page.addInitScript(plan => {
    const contexts = { growth: { highest_cleared: 1, recipes: { '1': plan }, ratings: { '1': 1 }, pending: {}, completed: [] } };
    localStorage.setItem('growWithPip.jellyCampaign.v1', `[campaign]\nversion=1\ncontexts=${JSON.stringify(contexts)}\n`);
    localStorage.setItem('growWithPip.coinWallet.v1', '[wallet]\nversion=2\nbalance=100000\nreceipts={"campaign-opening-coins":100000}\n');
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: true }));
  }, plan);
  await page.goto('/');
  await enterGame(page, { home: true });
  const mode = (await metrics(page)).library.controls.find(item => item.name === 'Mode_word_jelly' && item.visible);
  expect(mode).toBeTruthy(); await click(page, mode.rect);
  const map = await waitForCampaignMap(page), stage = map.stage_nodes.find(item => item.number === 1);
  await click(page, [stage.rect.x, stage.rect.y, stage.rect.width, stage.rect.height]);
  await expect.poll(async () => { const s = await state(page); return s.visible && s.phase === 'playing' && s.tiles.length === 21 && s.tiles.every(t => t.settled); }).toBe(true);
  while ((await state(page)).tiles.length < count) {
    const before = await state(page); await click(page, before.preview.rect);
    await expect.poll(async () => { const s = await state(page); return s.generated_tiles > before.generated_tiles && s.tiles.every(t => t.settled); }).toBe(true);
  }
  await page.mouse.move(1, 1);
  if (process.env.JELLY_IDLE_CANDIDATE) {
    await expect.poll(async () => (await state(page)).presentation_work?.cached_bodies || 0).toBe(count);
  }
  const before = await state(page);
  expect(before.tiles).toHaveLength(count); expect(before.spawn_interval).toBe(60);
  for (let repeat = 0; repeat < 3; repeat++) {
    const row = { repeat: repeat + 1, ...summarize(await measure(page)) }; windows.push(row);
    fs.writeFileSync(info.outputPath(`${label}-${count}.json`), JSON.stringify({
      protocol: 'word-jelly-idle-budget-browser-v1', label, count,
      browser: page.context().browser().version(), viewport: page.viewportSize(), before, windows, errors,
      scope: 'Authored campaign recipe with matched body count/type composition, normal motion, no deliberate throttle. '
        + 'The recipe seed does not seed GameUI.new_round; placement and word allocation vary, so this is not an exact same-board comparison. '
        + 'Three consecutive windows per process are not independent samples or physical PC FPS. Renderer, viewport and raw intervals retained.'
    }, null, 2));
    expect(row.end_state.tiles).toHaveLength(count);
    expect(row.end_state.generated_tiles).toBe(count);
    expect(row.end_state.phase).toBe('playing');
    expect(row.end_state.merged_count).toBe(0);
    expect(row.visibility).toBe('visible');
    if (process.env.JELLY_IDLE_CANDIDATE) {
      expect(row.end_state.presentation_work.animated_ids.length).toBeLessThanOrEqual(3);
      expect(row.end_state.presentation_work.cached_bodies).toBeGreaterThan(count / 2);
    }
    console.log(JSON.stringify({ label, count, repeat: repeat + 1, frames: row.frames,
      p95: row.p95_ms, mean: row.mean_ms, draws: row.draws_per_frame, renderer: row.renderer }));
  }
  expect(errors).toEqual([]);
  await page.screenshot({ path: info.outputPath(`${label}-${count}.png`), scale: 'css' });
});
