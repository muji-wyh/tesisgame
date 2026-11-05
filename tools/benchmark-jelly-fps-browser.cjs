const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const { chromium } = require('@playwright/test');
const { createWebServer } = require('./serve-web.cjs');
const { seedPipLevel } = require('../tests/browser/game-ui.cjs');

const root = path.resolve(__dirname, '..');
const protocol = 'jelly-full-board-rendered-v2';
const scenarios = ['idle-ordinary', 'idle-merged', 'drag-ordinary', 'drag-merged', 'merge', 'collect'];
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function instrumentGL() {
  const counters = { draws: 0, program_switches: 0, use_program_calls: 0, draw_methods: {} };
  const programs = new WeakMap();
  window.jellyDrawAudit = counters;
  for (const prototype of new Set([window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype].filter(Boolean))) {
    for (const method of ['drawArrays', 'drawElements', 'drawRangeElements', 'drawArraysInstanced', 'drawElementsInstanced']) {
      // An inherited method is already wrapped on its owning prototype.
      if (!Object.prototype.hasOwnProperty.call(prototype, method)) continue;
      const original = prototype[method];
      if (typeof original !== 'function') continue;
      prototype[method] = function(...args) {
        counters.draws++;
        counters.draw_methods[method] = (counters.draw_methods[method] || 0) + 1;
        return original.apply(this, args);
      };
    }
    if (!Object.prototype.hasOwnProperty.call(prototype, 'useProgram')) continue;
    const original = prototype.useProgram;
    prototype.useProgram = function(program) {
      counters.use_program_calls++;
      const previous = programs.has(this) ? programs.get(this) : null;
      if (previous !== program) counters.program_switches++;
      programs.set(this, program);
      return original.call(this, program);
    };
  }
}

function sampleGLAtBoundaries() {
  const bench = window.jellyFpsBench;
  const originalBegin = bench.begin;
  const originalFinish = bench.finish;
  const copy = () => ({ ...window.jellyDrawAudit, draw_methods: { ...window.jellyDrawAudit.draw_methods } });
  let before;
  bench.begin = function(json) {
    before = copy();
    return originalBegin.call(this, json);
  };
  bench.finish = function(json) {
    const after = copy();
    originalFinish.call(this, json);
    const frames = this.report.frame_post_draw_frames;
    const draws = after.draws - before.draws;
    const switches = after.program_switches - before.program_switches;
    this.report.gl_work = { draws, program_switches: switches,
      use_program_calls: after.use_program_calls - before.use_program_calls,
      draws_per_engine_frame: draws / frames, program_switches_per_engine_frame: switches / frames,
      frame_post_draw_frames: frames,
      draw_methods: Object.fromEntries(Object.entries(after.draw_methods).map(([method, value]) => [method, value - (before.draw_methods[method] || 0)])),
      scope: 'Each GL draw API invocation counted once on its owning prototype; useProgram switches count changes of program identity. Sampled at benchmark begin/finish, divided by actual frame_post_draw count.' };
  };
}

async function startTrace(context, page, filename) {
  const session = await context.newCDPSession(page);
  await session.send('Tracing.start', { transferMode: 'ReturnAsStream',
    traceConfig: { recordMode: 'recordContinuously', includedCategories: [
      'devtools.timeline', 'v8.execute', 'blink', 'cc', 'gpu',
      'disabled-by-default-devtools.timeline', 'disabled-by-default-v8.cpu_profiler' ] } });
  return { session, filename };
}

async function stopTrace(trace) {
  const { session, filename } = trace;
  const completed = new Promise(resolve => session.once('Tracing.tracingComplete', resolve));
  await session.send('Tracing.end');
  const { stream } = await completed;
  if (!stream) throw new Error('Chrome returned no trace stream.');
  const chunks = [];
  let eof = false;
  while (!eof) {
    const item = await session.send('IO.read', { handle: stream });
    chunks.push(Buffer.from(item.data, item.base64Encoded ? 'base64' : 'utf8'));
    eof = item.eof;
  }
  await session.send('IO.close', { handle: stream });
  fs.writeFileSync(filename, Buffer.concat(chunks));
  await session.detach();
}
function stats(values, cadence = false) {
  if (!values.length) return { count: 0 };
  const sorted = [...values].sort((a, b) => a - b);
  const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
  const percentile = p => sorted[Math.ceil(sorted.length * p) - 1];
  return { count: values.length, mean_ms: mean, ...(cadence ? { fps: 1000 / mean } : {}),
    p50_ms: percentile(.5), p95_ms: percentile(.95), p99_ms: percentile(.99), max_ms: sorted.at(-1),
    over_25ms: values.filter(value => value > 25).length,
    over_33ms: values.filter(value => value > 33.4).length,
    over_50ms: values.filter(value => value > 50).length };
}
async function emptyBaseline(page) {
  return page.evaluate(() => new Promise(resolve => {
    let first, previous;
    const intervals = [];
    function frame(now) {
      first ??= now;
      if (previous !== undefined) intervals.push(now - previous);
      previous = now;
      if (now - first < 3000) return requestAnimationFrame(frame);
      const canvas = document.createElement('canvas'), gl = canvas.getContext('webgl2');
      const debug = gl?.getExtension('WEBGL_debug_renderer_info');
      resolve({ intervals, renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null,
        user_agent: navigator.userAgent, hardware_threads: navigator.hardwareConcurrency,
        device_memory_gb: navigator.deviceMemory, viewport: [innerWidth, innerHeight],
        dpr: devicePixelRatio, visibility: document.visibilityState });
    }
    requestAnimationFrame(frame);
  }));
}
async function cdpDrag(session, seconds, before, geometry, evidence = {}) {
  const scale = Math.min(geometry.width, geometry.height) / 480;
  const [x, y, width, height] = before.source_rect;
  const origin = before.logical_view_origin;
  const board = before.logical_board;
  const source = { x: geometry.x + (x + width / 2) * scale, y: geometry.y + (y + height / 2) * scale };
  Object.assign(evidence, { kind: 'Chrome DevTools Protocol mouse', source, canvas: geometry, logical_to_css_scale: scale,
    motion_events: 0, duration_ms: 0 });
  await session.send('Input.dispatchMouseEvent', { type: 'mouseMoved', ...source });
  await session.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...source, button: 'left', buttons: 1, clickCount: 1 });
  const started = performance.now();
  let events = 0;
  while (performance.now() - started < seconds * 1000 - 250) {
    const elapsed = (performance.now() - started) / 1000;
    await session.send('Input.dispatchMouseEvent', { type: 'mouseMoved', button: 'left', buttons: 1,
      x: geometry.x + (origin[0] + board[0] + before.pitch * (3 + 2 * Math.sin(elapsed * 2))) * scale,
      y: geometry.y + (origin[1] + board[1] + before.pitch * .35) * scale });
    evidence.motion_events = ++events;
    evidence.duration_ms = performance.now() - started;
    await delay(16);
  }
  evidence.duration_ms = performance.now() - started;
  return evidence;
}

async function inputState(page) {
  return page.evaluate(() => {
    const state = JSON.parse(document.getElementById('game-status')?.dataset.jelly || '{}');
    const rect = document.getElementById('canvas').getBoundingClientRect();
    return { browser_seconds: performance.now() / 1000, drag: state.drag, contact: state.contact,
      placement: state.placement, board_rect: state.board_rect,
      canvas: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
      top_row: (state.tiles || []).filter(tile => tile.row === 0).map(tile => ({ id: tile.id,
        column: tile.column, jelly_kind: tile.jelly_kind, rect: tile.rect, settled: tile.settled,
        lifted: tile.lifted, word_id: tile.word?.id, root_word_id: tile.word_candidate?.id,
        picture_word_id: tile.image_word?.id })) };
  });
}

async function cdpMerge(session, before, geometry, evidence = {}, diagnosticPage = null) {
  const scale = Math.min(geometry.width, geometry.height) / 480;
  const center = rect => ({ x: geometry.x + (rect[0] + rect[2] / 2) * scale,
    y: geometry.y + (rect[1] + rect[3] / 2) * scale });
  const source = center(before.source_rect), target = center(before.target_rect);
  const started = performance.now();
  Object.assign(evidence, { kind: 'Chrome DevTools Protocol mouse merge', source, target,
    canvas: geometry, logical_to_css_scale: scale, logical_source_rect: before.source_rect,
    logical_target_rect: before.target_rect, motion_events: 0, dispatched: [], duration_ms: 0 });
  const dispatch = async event => {
    evidence.dispatched.push({ seconds: (performance.now() - started) / 1000, ...event });
    await session.send('Input.dispatchMouseEvent', event);
    evidence.duration_ms = performance.now() - started;
    if (event.type === 'mouseMoved') evidence.motion_events++;
  };
  await delay(350);
  await dispatch({ type: 'mouseMoved', ...source });
  await dispatch({ type: 'mousePressed', ...source, button: 'left', buttons: 1, clickCount: 1 });
  await delay(80);
  if (diagnosticPage) evidence.after_press = await inputState(diagnosticPage);
  await dispatch({ type: 'mouseMoved', x: source.x, y: source.y - 16, button: 'left', buttons: 1 });
  await delay(80);
  for (let step = 1; step <= 4; step++) {
    const fraction = step / 4;
    await dispatch({ type: 'mouseMoved', button: 'left', buttons: 1,
      x: source.x + (target.x - source.x) * fraction,
      y: source.y - 16 + (target.y - source.y + 16) * fraction });
    await delay(35);
  }
  await delay(160);
  if (diagnosticPage) evidence.before_release = await inputState(diagnosticPage);
  await dispatch({ type: 'mouseReleased', ...target, button: 'left', buttons: 0, clickCount: 1 });
  return evidence;
}

function collectionPhases(report) {
  if (report.scenario !== 'collect') return null;
  const count = report.process_frames;
  const batch = report.batch_progress;
  const resident = report.collection_effect_entries;
  const visible = report.visible_collection_effect_entries;
  for (const values of [report.tile_counts, report.sample_elapsed_seconds, resident, visible, ...Object.values(batch)]) {
    if (!Array.isArray(values) || values.length !== count) throw new Error('Collection telemetry must cover every engine frame.');
  }
  const visiblePeak = Math.max(...visible), residentPeak = Math.max(...resident);
  const peakThreshold = Math.max(1, Math.ceil(visiblePeak * .8));
  const masks = {
    high_density_collecting: report.tile_counts.map((tiles, index) => tiles >= 40 && batch.active[index]),
    collecting: batch.active,
    peak_effects: visible.map(entries => entries >= peakThreshold),
    effects_tail: report.tile_counts.map((tiles, index) => tiles === 0 && resident[index] > 0),
    empty_tail: report.tile_counts.map((tiles, index) => tiles === 0 && resident[index] === 0 && !batch.active[index])
  };
  const phases = Object.fromEntries(Object.entries(masks).map(([name, mask]) => {
    const indices = mask.flatMap((active, index) => active ? [index] : []);
    // An interval belongs to a phase only when both adjacent rendered frames
    // satisfy its mask, avoiding a boundary-crossing interval in the dense phase.
    const intervals = report.frame_interval_us.filter((_value, index) => mask[index] && mask[index + 1]);
    return [name, { frames: indices.length,
      first_seconds: indices.length ? report.sample_elapsed_seconds[indices[0]] : null,
      last_seconds: indices.length ? report.sample_elapsed_seconds[indices.at(-1)] : null,
      tile_range: indices.length ? [Math.min(...indices.map(index => report.tile_counts[index])), Math.max(...indices.map(index => report.tile_counts[index]))] : null,
      engine_intervals: stats(intervals.map(value => value / 1000), true),
      process: stats(indices.map(index => report.process_us[index] / 1000)),
      submission: stats(indices.map(index => report.submission_us[index] / 1000)) }];
  }));
  return { visible_effect_entry_peak: visiblePeak, resident_effect_entry_peak: residentPeak,
    peak_phase_threshold: peakThreshold, phases,
    queue_peak_started: Math.max(...batch.started), queue_peak_completed: Math.max(...batch.completed),
    queue_peak_remaining: Math.max(...batch.remaining),
    gl_work_scope: report.gl_work
      ? 'GL draw and program-switch totals cover the entire sampled window. Per-phase GL rates are unavailable because the current exported runner has no synchronous per-frame GL counter bridge.'
      : 'GL auditing is disabled for this capture; no draw/program-switch totals or per-phase GL rates are available.',
    scope: 'Per-frame scalar telemetry collected after the timing endpoint. Dense, active queue, peak effect, effect tail and idle empty-tail durations are reported separately. Phase FPS uses actual engine intervals, not aggregate GL draw totals or host publication counts.' };
}

function mergePhase(report) {
  if (report.scenario !== 'merge') return null;
  const mask = Array.isArray(report.fusion_active) ? report.fusion_active
    : Array.isArray(report.fusion_counts) ? report.fusion_counts.map(count => count > 0) : null;
  if (!mask) return { observed_fusion_frames: report.fusion_frames, remaining_tiles: report.after.tiles,
    timing_available: false,
    timing_scope: 'This exported runner records aggregate fusion_frames without a per-frame fusion mask. Exact fusion-only timings cannot be reconstructed; the whole-window average includes idle frames.' };
  if (mask.length !== report.process_frames) throw new Error('Fusion telemetry must cover every engine frame.');
  const indices = mask.flatMap((active, index) => active ? [index] : []);
  if (indices.length !== report.fusion_frames) throw new Error('Fusion mask disagrees with the observed fusion frame count.');
  const intervals = report.frame_interval_us.filter((_value, index) => mask[index] && mask[index + 1]);
  const transition = entering => report.frame_interval_us.flatMap((value, index) =>
    (entering ? !mask[index] && mask[index + 1] : mask[index] && !mask[index + 1])
      ? [{ from_frame: index, to_frame: index + 1, interval_ms: value / 1000 }] : []);
  const entry = transition(true), exit = transition(false);
  const activeAndTransitions = report.frame_interval_us.filter((_value, index) => mask[index] || mask[index + 1]);
  return { observed_fusion_frames: report.fusion_frames, remaining_tiles: report.after.tiles,
    timing_available: true, frames: indices.length,
    engine_intervals: stats(intervals.map(value => value / 1000), true),
    transitions: { entry: { intervals: entry, engine_intervals: stats(entry.map(item => item.interval_ms), true) },
      exit: { intervals: exit, engine_intervals: stats(exit.map(item => item.interval_ms), true) } },
    active_and_transition_engine_intervals: stats(activeAndTransitions.map(value => value / 1000), true),
    process: stats(indices.map(index => report.process_us[index] / 1000)),
    submission: stats(indices.map(index => report.submission_us[index] / 1000)),
    timing_scope: 'Fusion-only intervals require two adjacent active frames. Entry and exit intervals cross the fusion mask and are retained separately; active-and-transition intervals include either adjacent active frame. Transitions outside the sampled window are unavailable.' };
}

async function capture(options) {
  const directory = path.resolve(options.directory);
  const warmup = Number(options.warmup || 2);
  if (options['gl-audit'] !== undefined && !['true', 'false'].includes(options['gl-audit']))
    throw new Error('--gl-audit must be true or false.');
  const glAudit = options['gl-audit'] !== 'false';
  if (!Number.isFinite(warmup) || warmup < 1 || warmup > 10) throw new Error('--warmup must be between 1 and 10 seconds.');
  if (options.label && !/^[a-z0-9][a-z0-9_-]*$/i.test(options.label)) throw new Error('Invalid result label.');
  const results = path.join(root, 'build', 'performance', options.label || 'jelly-browser-results');
  if (fs.existsSync(results)) throw new Error(`Refusing to replace existing results: ${results}`);
  fs.mkdirSync(results, { recursive: true });
  const server = createWebServer(directory);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}/`;
  let browser;
  try {
    browser = await chromium.launch({ channel: options.channel || 'chrome', headless: options.headed !== 'true' });
  } catch (error) {
    fs.writeFileSync(path.join(results, 'failure.json'), `${JSON.stringify({ failed_at: new Date().toISOString(),
      phase: 'Chrome launch', error: error.message, stack: error.stack, source_export: directory }, null, 2)}\n`);
    await new Promise(resolve => server.close(resolve));
    throw error;
  }
  const rows = [];
  let activeTrace = null;
  let current = null;
  try {
    for (let repeat = 0; repeat < Number(options.repeats || 3); repeat++) {
      for (const scenario of (options.scenarios || scenarios.join(',')).split(',')) {
        if (!scenarios.includes(scenario)) throw new Error(`Unknown scenario: ${scenario}`);
        const context = await browser.newContext({ viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1,
          reducedMotion: 'no-preference', hasTouch: false });
        const page = await context.newPage();
        const errors = [];
        const errorFile = path.join(results, `${scenario}-${repeat + 1}-errors.json`);
        current = { scenario, repeat: repeat + 1, page, errors, empty: null, report: null };
        function recordError(message) {
          errors.push({ at: new Date().toISOString(), message });
          fs.writeFileSync(errorFile, `${JSON.stringify({ scenario, repeat: repeat + 1, errors }, null, 2)}\n`);
          console.error(`Browser error (${scenario} ${repeat + 1}): ${message}`);
        }
        page.on('pageerror', error => recordError(error.message));
        page.on('console', message => { if (message.type() === 'error') recordError(message.text()); });
        const empty = await emptyBaseline(page);
        current.empty = { ...empty, intervals_summary: stats(empty.intervals, true) };
        if (glAudit) await page.addInitScript(instrumentGL);
        await seedPipLevel(page, 3);
        await page.addInitScript(() => {
          localStorage.setItem('growWithPip.coinWallet.v1', '[wallet]\nversion=5\nbalance=1000000\nreceipts={"benchmark-coins":1000000}\nchest_rewards={}\n');
          localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: false, reduced_motion: false }));
        });
        await page.goto(url);
        await page.locator('#enter-game:not([disabled])').waitFor({ timeout: 180000 });
        await page.locator('#enter-game').click();
        await page.waitForFunction(() => window.jellyFpsBench?.ready && document.getElementById('status').dataset.state === 'ready');
        if (glAudit) await page.evaluate(sampleGLAtBoundaries);
        if (options.trace === 'true') {
          activeTrace = await startTrace(context, page, path.join(results, `${scenario}-${repeat + 1}-trace.json`));
        }
        const seconds = Math.max(scenario === 'collect' ? 12 : 2, Number(options.seconds || 8));
        const input = scenario.startsWith('drag-') || scenario === 'merge' ? 'cdp' : 'scene';
        const geometry = await page.locator('#canvas').boundingBox();
        await page.evaluate(request => window.jellyFpsBench.start(request), { scenario, seconds, warmup_seconds: warmup, seed: 73021, input });
        await page.waitForFunction(() => window.jellyFpsBench.running || window.jellyFpsBench.error, undefined, { timeout: 90000 });
        let inputEvidence = { kind: 'Benchmark scheduled scene handlers' };
        current.inputEvidence = inputEvidence;
        if (input === 'cdp' && !(await page.evaluate(() => window.jellyFpsBench.error))) {
          const session = await context.newCDPSession(page);
          const plan = await page.evaluate(() => window.jellyFpsBench.inputPlan);
          inputEvidence = scenario === 'merge' ? await cdpMerge(session, plan.before, geometry, inputEvidence,
            options['input-diagnostics'] === 'true' ? page : null)
            : await cdpDrag(session, seconds, plan.before, geometry, inputEvidence);
          await session.detach();
        }
        await page.waitForFunction(() => window.jellyFpsBench.report || window.jellyFpsBench.error, undefined, { timeout: (seconds + 30) * 1000 });
        const result = await page.evaluate(() => ({ report: window.jellyFpsBench.report, error: window.jellyFpsBench.error,
          browser_state: {
            jelly: JSON.parse(document.getElementById('game-status')?.dataset.jelly || '{}'),
            growth: JSON.parse(document.getElementById('growth-status')?.dataset.snapshot || '{}'),
            wallet_storage: localStorage.getItem('growWithPip.coinWallet.v1'),
            growth_storage: localStorage.getItem('growWithPip.growth.v1'),
            campaign_storage: localStorage.getItem('growWithPip.jellyCampaign.v1')
          } }));
        current.report = result.report;
        current.browser_state = result.browser_state;
        if (result.error) throw new Error(result.error);
        const report = result.report;
        if (activeTrace) {
          await stopTrace(activeTrace);
          activeTrace = null;
        }
        if (errors.length) throw new Error(`Browser errors: ${errors.map(item => item.message).join('; ')}`);
        if (report.protocol !== protocol || report.before.tiles !== 56 || report.before.paused || report.process_frames !== report.frame_post_draw_frames)
          throw new Error('Incomplete full-board rendered workload evidence.');
        const expectedCohort = scenario === 'collect'
          ? ['cat', 'dog', 'sun', 'ball', 'car', 'apple', 'fish', 'duck', 'cow'] : ['cat'];
        if (!report.before.authored_morphology || report.before.learning?.age !== 3 ||
            JSON.stringify([...(report.before.cohort_word_ids || [])].sort()) !== JSON.stringify(expectedCohort.sort()))
          throw new Error('The rendered fixture must use its exact reviewed production Age 3 word cohort.');
        if (glAudit && (!report.gl_work || report.gl_work.draws <= 0 ||
            Object.values(report.gl_work.draw_methods).reduce((sum, count) => sum + count, 0) !== report.gl_work.draws ||
            report.gl_work.program_switches > report.gl_work.use_program_calls))
          throw new Error('Invalid GL draw/program-switch counters.');
        if (scenario.startsWith('drag-') && report.drag_frames < report.process_frames * .6)
          throw new Error('Drag did not remain active for most sampled rendered frames.');
        if (scenario === 'merge' && (report.after.merged <= report.before.merged || report.fusion_frames <= 0 || report.after.tiles !== 55))
          throw new Error('Merge workload must render a fusion and leave exactly 55 Jellies after the accepted pair.');
        if (scenario === 'collect') {
          const batch = report.after.collection_batch;
          if (report.after.cleared_pairs - report.before.cleared_pairs !== 56 || report.after.tiles !== 0 ||
              batch.total !== 56 || batch.started !== 56 || batch.completed !== 56 || batch.skipped !== 0 || batch.active)
            throw new Error('Collection workload must clear and commit all 56 captured mixed-level Jellies with no skips. '
              + (report.after.error || result.browser_state.jelly.error || report.after.wallet?.error || ''));
          if (Object.keys(report.before.word_counts).length !== 9 || Object.keys(report.before.level_counts).length !== 9)
            throw new Error('Collection board must contain nine production words and all nine merged levels.');
        }
        const row = { repeat: repeat + 1, browser: browser.version(), headed: options.headed === 'true',
          traced: options.trace === 'true', input_diagnostics: options['input-diagnostics'] === 'true', gl_audit: glAudit,
          measurement_role: report.cpu_profile?.diagnostic_only ? 'CPU diagnosis; instrumentation adds overhead'
            : options['input-diagnostics'] === 'true' ? 'input diagnosis; boundary host snapshots add overhead'
            : options.trace === 'true' ? 'diagnosis; tracing adds overhead'
            : glAudit ? 'unprofiled untraced GL-audited comparison' : 'untraced acceptance candidate',
          empty: { ...empty, intervals_summary: stats(empty.intervals, true) }, input_evidence: inputEvidence,
          ...report, raf: stats(report.raf_interval_ms, true), engine_intervals: stats(report.frame_interval_us.map(value => value / 1000), true),
          process: stats(report.process_us.map(value => value / 1000)), submission: stats(report.submission_us.map(value => value / 1000)),
          collection_phases: collectionPhases(report), merge_phase: mergePhase(report),
          instrumentation_scope: glAudit
            ? 'GL API wrappers increment JavaScript counters on every draw/useProgram call. This adds overhead and is enabled consistently only for paired audited comparisons. Disable with --gl-audit false for bare FPS acceptance.'
            : 'GL auditing is disabled: no GL API wrappers, counters, boundary hooks or GL assertions. Engine scalar timing telemetry remains; optional CPU profiles, Chrome traces or input snapshots are diagnostic overhead when enabled.',
          warmup_scope: 'Warmup is excluded from the sampled window. Its requested duration and the post-warmup presentation/cache state are retained; use separate short-warmup diagnostic runs to assess cold and warming behavior.' };
        rows.push(row);
        fs.writeFileSync(path.join(results, `${scenario}-${repeat + 1}.json`), `${JSON.stringify(row, null, 2)}\n`);
        console.log(`${scenario} repeat ${repeat + 1}: engine ${row.engine_intervals.fps.toFixed(2)} FPS, P95 ${row.engine_intervals.p95_ms.toFixed(2)} ms; empty ${row.empty.intervals_summary.fps.toFixed(2)} FPS; ${empty.renderer}`);
        await context.close();
        current = null;
      }
    }
    const output = { protocol, viewport: [1366, 768], source_export: directory, gl_audit: glAudit, rows,
      scope: 'Real local Chrome at DPR1, no deliberate CPU or network throttle, normal audio and motion. Record empty-page cadence and GPU adapter before interpreting 60 FPS. Godot frame_post_draw is submission completion, not GPU presentation. Headed/headless and driver must match for paired comparisons.' };
    fs.writeFileSync(path.join(results, 'summary.json'), `${JSON.stringify(output, null, 2)}\n`);
  } catch (error) {
    const failure = { protocol, failed_at: new Date().toISOString(),
      error: error.message, stack: error.stack, source_export: directory, browser: browser.version(),
      scenario: current?.scenario, repeat: current?.repeat, errors: current?.errors || [],
      input_evidence: current?.inputEvidence,
      empty: current?.empty, report: current?.report, browser_state: current?.browser_state, completed_rows: rows,
      traced: options.trace === 'true', input_diagnostics: options['input-diagnostics'] === 'true', gl_audit: glAudit };
    fs.writeFileSync(path.join(results, 'failure.json'), `${JSON.stringify(failure, null, 2)}\n`);
    throw error;
  } finally {
    if (activeTrace) {
      try { await stopTrace(activeTrace); }
      catch (error) { fs.writeFileSync(path.join(results, 'trace-failure.json'), `${JSON.stringify({ error: error.message }, null, 2)}\n`); }
    }
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
  return rows;
}
if (require.main === module) {
  const options = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i].replace(/^--/, '');
    if (!['directory', 'label', 'channel', 'headed', 'repeats', 'seconds', 'warmup', 'scenarios', 'trace', 'input-diagnostics', 'gl-audit'].includes(key) || !process.argv[i + 1])
      throw new Error('Usage: node tools/benchmark-jelly-fps-browser.cjs --directory PATH [--label NAME] [--channel chrome] [--headed true] [--repeats 3] [--seconds 8] [--warmup 8] [--scenarios idle-ordinary,...] [--trace true] [--input-diagnostics true] [--gl-audit false]');
    options[key] = process.argv[i + 1];
  }
  if (!options.directory) throw new Error('--directory is required.');
  capture(options).catch(error => { console.error(error); process.exitCode = 1; });
}
module.exports = { stats, emptyBaseline, capture, instrumentGL, sampleGLAtBoundaries, collectionPhases, mergePhase };
