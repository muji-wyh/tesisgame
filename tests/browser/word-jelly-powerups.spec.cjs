const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { expectCollectionReward } = require('./word-jelly-rewards.cjs');
const { openGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap, observeAudio, seedPipLevel } = require('./game-ui.cjs');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');
const morphology = Array.from({ length: 10 }, (_, index) =>
  require(`../../data/vocabulary/morphology/age-${String(index + 3).padStart(2, '0')}.json`).entries).flat();
const analyses = new Map(morphology.map(entry => [entry.analysis.id, entry.analysis]));

const WALLET_KEY = 'growWithPip.coinWallet.v1';
const GROWTH_KEY = 'growWithPip.growth.v1';
const WRONG = 'assets/imported-audio/pair-feedback/wrong.wav';
const RIGHT = 'assets/imported-audio/pair-feedback/right.wav';
const MERGE = 'assets/imported-audio/jelly-interaction/merge-together-v3.wav';
const prices = { auto_merge: 600 };
const AUTO_MERGE_BEAT = 0.10;
const AUTO_MERGE_DRAG = 0.32;
const AUTO_MERGE_FUSION = 0.11;
const AUTO_MERGE_SETTLE = 0.03;
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const soundsSince = (page, from) => page.evaluate(from => window.audioObservation.playbacks.slice(from), from);
const savedGrowth = page => page.evaluate(key => localStorage.getItem(key), GROWTH_KEY);
const fragmentTotal = state => state.tiles.reduce((total, tile) => total + tile.fragments, 0);
const progress = state => ({ collected_coins: state.collected_coins, cleared_pairs: state.cleared_pairs,
  fragment_count: state.fragment_count, chest_tier: state.chest_tier, chest_count: state.chest_count });
const forwardPairs = state => state.tiles.flatMap(source => state.tiles.filter(target =>
  validPair(source, target)).map(target => [source.id, target.id]));

function validPair(source, target) {
  if (!source || !target || source.id === target.id) return false;
  if (source.jelly_kind === 'merged' && target.jelly_kind === 'merged')
    return Boolean(source.word?.id && source.word.id === target.word?.id);
  const picture = source.jelly_kind === 'picture' ? source : target.jelly_kind === 'picture' ? target : null;
  if (picture) {
    const root = picture === source ? target : source;
    return root.jelly_kind === 'root' && Boolean(root.word_candidate?.id && root.word_candidate.id === picture.image_word?.id);
  }
  if (source.jelly_kind !== 'root' || target.jelly_kind !== 'root') return false;
  return (source.composition?.candidates || []).some(candidate => {
    const analysis = analyses.get(candidate.analysis_id);
    return analysis?.nodes.some(node => node.left === candidate.node_id &&
      target.composition?.candidates.some(other => other.analysis_id === analysis.id && other.node_id === node.right));
  });
}

function expectFragmentBadge(tile) {
  expect(tile.fragment_badges).toBe(Math.min(2, tile.fragments));
  const badge = tile.fragment_badge;
  expect(badge.icons).toBe(Math.min(2, tile.fragments));
  expect(badge.count_text).toBe(tile.fragments > 2 ? String(tile.fragments) : '');
  expect(badge.visible).toBe(tile.fragments > 0);
  if (!tile.fragments) return;
  const [x, y, width, height] = badge.rect;
  expect(badge.rect.every(Number.isFinite), 'A carried reward marker has real local geometry').toBe(true);
  expect(width).toBeGreaterThan(0);
  expect(height).toBeGreaterThan(0);
  expect(x, 'The chest stack stays inside its jelly').toBeGreaterThanOrEqual(-0.5);
  expect(y, 'The chest stack stays inside its jelly').toBeGreaterThanOrEqual(-0.5);
  expect(x + width, 'The exact count cannot overflow into the neighboring jelly').toBeLessThanOrEqual(tile.rect[2] + 0.5);
  expect(y + height, 'The chest stack stays inside its jelly').toBeLessThanOrEqual(tile.rect[3] + 0.5);
}

async function start(page, info, balance, pipLevel = 0,
  { pauseOnReady = false, autoMergeLevel = 1, challenge = true } = {}) {
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  await page.setViewportSize(/iphone|android|mobile/.test(info.project.name)
    ? { width: 393, height: 852 } : { width: 1473, height: 1175 });
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  await seedPipLevel(page, pipLevel);
  await page.addInitScript(({ balance, walletKey, autoMergeLevel }) => {
    if (localStorage.getItem(walletKey) === null) localStorage.setItem(walletKey,
      `[wallet]\nversion=3\nbalance=${balance}\nreceipts=${JSON.stringify(balance ? { 'browser-opening-coins': balance } : {})}\n`);
    if (autoMergeLevel > 1 && localStorage.getItem('growWithPip.jellyCampaign.v1') === null)
      localStorage.setItem('growWithPip.jellyCampaign.v1',
        '[campaign]\nversion=5\ncontexts={}\nupgrades=' + JSON.stringify({
          level: 1, auto_merge_level: autoMergeLevel, intro: 'unseen', pending: {}
        }) + '\n');
  }, { balance, walletKey: WALLET_KEY, autoMergeLevel });
  const errors = await openGame(page, { reducedMotion });
  await chooseMode(page, 'word_jelly', { challenge });
  let opening;
  await expect.poll(async () => {
    const state = opening = await jelly(page);
    return state.visible && !state.paused && state.phase === 'playing' && state.tiles.length === (challenge ? 56 : 21) &&
      state.tiles.every(tile => tile.settled) &&
      Object.values(state.powerup_buttons || {}).filter(button => button.visible).length === 1;
  }, { timeout: 30000 }).toBe(true).catch(async error => {
    fs.writeFileSync(info.outputPath('powerup-startup-state.json'),
      JSON.stringify({ state: await jelly(page), bounds: await metrics(page) }, null, 2));
    throw error;
  });
  if (pauseOnReady) {
    await page.keyboard.press('p');
    await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  }
  await expect.poll(async () => (await wallet(page)).balance).toBe(balance);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (!audioAvailable) info.annotations.push({ type: 'audio-limitation',
    description: 'This renderer has no WebAudio. Chromium verifies the recordings; this case still verifies all visible and saved outcomes.' });
  return { errors, reducedMotion, audioAvailable, opening };
}

async function pressRect(page, rect, bounds) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2, bounds);
}

async function readyPowerup(page, kind) {
  let state;
  await expect.poll(async () => {
    state = await jelly(page);
    // Leave time for the browser-driver tap before the next supply temporarily disables purchases.
    return state.powerup_buttons[kind].enabled && state.spawn_interval - state.spawn_elapsed > 4;
  }, { message: `${kind} is ready with enough time before the next supply drop` }).toBe(true);
  return state;
}

async function capture(page, info, name) {
  await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
  const image = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), Buffer.from(image, 'base64'));
}

async function storedWallet(page) {
  return page.evaluate(key => {
    const text = localStorage.getItem(key);
    return { text, balance: Number(text.match(/^balance\s*=\s*(\d+)/m)[1]),
      receipts: JSON.parse(text.match(/^receipts\s*=\s*(\{[^}]*\})/m)[1]) };
  }, WALLET_KEY);
}

function expectLayout(state, bounds, affordable) {
  const inside = (rect, outer, label) => {
    expect(rect.every(Number.isFinite), `${label} has real bounds`).toBe(true);
    expect(rect[2]).toBeGreaterThan(0);
    expect(rect[3]).toBeGreaterThan(0);
    expect(rect[0], label).toBeGreaterThanOrEqual(outer[0] - 0.5);
    expect(rect[1], label).toBeGreaterThanOrEqual(outer[1] - 0.5);
    expect(rect[0] + rect[2], label).toBeLessThanOrEqual(outer[0] + outer[2] + 0.5);
    expect(rect[1] + rect[3], label).toBeLessThanOrEqual(outer[1] + outer[3] + 0.5);
  };
  const regions = [['well', state.board_rect], ['supply', state.preview.rect],
    ['Collect', state.collect_button.rect], ['chest', state.loot.progress.rect], ['Finish', state.finish.rect]];
  for (const [kind, price] of Object.entries(prices)) {
    const button = state.powerup_buttons[kind];
    expect(button.visible).toBe(true);
    expect(button.enabled, 'An unaffordable powerup remains tappable for negative feedback').toBe(true);
    expect(button.price).toBe(price);
    expect(button.price_text).toBe(String(price));
    expect(button.title.replace(/\s+/g, ' ')).toBe('Auto merge');
    expect(button.affordable).toBe(affordable);
    inside(button.rect, [0, 0, bounds.width, bounds.height], kind);
    inside(button.price_rect, [0, 0, button.rect[2], button.rect[3]], `${kind} price`);
    inside(button.title_rect, [0, 0, button.rect[2], button.rect[3]], `${kind} title`);
    expect(button.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43.5);
    expect(button.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43.5);
    regions.push([kind, button.rect]);
  }
  for (const [index, [name, a]] of regions.entries()) for (const [otherName, b] of regions.slice(index + 1)) {
    const overlapX = Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0]);
    const overlapY = Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]);
    expect(overlapX <= 0.5 || overlapY <= 0.5, `${name} and ${otherName} keep distinct interaction areas`).toBe(true);
  }
}

async function beginTrace(page, label, { pauseOnOverlap = false } = {}) {
  await page.evaluate(({ label, pauseOnOverlap }) => {
    window.wordJellyPowerupObserver?.disconnect();
    const status = document.getElementById('game-status');
    const evidence = window.wordJellyPowerupEvidence = { label, timeline: [], frames: {}, pending: [], pausedOnOverlap: false };
    const capture = name => {
      if (evidence.frames[name] || evidence.pending.includes(name)) return;
      evidence.pending.push(name);
      document.getElementById('canvas').toBlob(blob => {
        if (!blob) return;
        const reader = new FileReader();
        reader.onload = () => { evidence.frames[name] = reader.result.split(',')[1]; };
        reader.readAsDataURL(blob);
      }, 'image/png');
    };
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      if (state.mode !== 'word_jelly') return;
      const powerup = state.powerup || {};
      evidence.timeline.push({ at: performance.now(), powerup, buttons: state.powerup_buttons,
        goals: state.practice?.words || [], goal_hover: state.goal_hover,
        effects: state.powerup_effect_count, paused: state.paused, spawn_elapsed: state.spawn_elapsed,
        generated: state.generated_tiles, merged: state.merged_count, cleared: state.cleared_pairs,
        coins: state.collected_coins, fragments: state.fragment_count, chest_tier: state.chest_tier,
        tiles: state.tiles.map(tile => ({ id: tile.id, text: tile.text, mass: tile.mass, fragments: tile.fragments,
          fragment_badges: tile.fragment_badges, fragment_badge: tile.fragment_badge,
          rect: tile.rect, visible: tile.visible, settled: tile.settled, settling: tile.settling,
          settle_seconds: tile.settle_seconds,
          word: tile.word, picture_visible: tile.picture_visible, coins: tile.coins })),
        fusions: (state.fusions || []).map(fusion => ({ operation: fusion.operation, automatic: fusion.automatic, a_id: fusion.a_id,
          b_id: fusion.b_id, result: fusion.result, elapsed: fusion.elapsed, duration: fusion.duration })) });
      for (const [kind, button] of Object.entries(state.powerup_buttons || {})) {
        if (button.feedback_active && !button.feedback_success && button.light > 0.05) capture(`negative-${kind}`);
      }
      if (state.goal_hover?.word_id && state.goal_hover.elapsed > 0.12) capture('goal-hover');
      for (const goal of state.practice?.words || []) {
        const button = goal.purchase || {};
        if (button.feedback_active && !button.feedback_success && button.light > 0.05) capture('negative-goal');
        if (button.spent_coins > 0 && button.feedback_elapsed > 0.04) capture('goal-paid');
      }
      const drags = powerup.drags || [];
      const inFlight = powerup.active && powerup.kind === 'auto_merge' &&
        drags.some(drag => drag.elapsed / drag.duration > 0.2 && drag.elapsed / drag.duration < 0.8);
      if (inFlight)
        capture('auto-midpoint');
      const overlapping = powerup.active && powerup.kind === 'auto_merge' && drags.length > 1;
      if (overlapping)
        capture('auto-overlap');
      if (powerup.active && powerup.kind === 'auto_merge' && drags.length && state.fusions?.length)
        capture('auto-fusion');
      const overlappingOperations = drags.some(drag => drag.elapsed > 0) &&
        (overlapping || state.fusions?.some(fusion => fusion.automatic));
      if (pauseOnOverlap && !evidence.pausedOnOverlap && overlappingOperations) {
        // A renderer can skip the 20 ms two-flight window; a simultaneous union is also real overlap.
        evidence.pausedOnOverlap = true;
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event('visibilitychange'));
      }
    };
    window.wordJellyPowerupObserver = new MutationObserver(record);
    window.wordJellyPowerupObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, { label, pauseOnOverlap });
}

async function retainTrace(page, info, label, expectedFrames) {
  const snapshot = await page.evaluate(() => ({ ...window.wordJellyPowerupEvidence, frames: Object.keys(window.wordJellyPowerupEvidence.frames) }));
  fs.writeFileSync(info.outputPath(`${label}-timeline.json`), JSON.stringify(snapshot, null, 2));
  for (const name of expectedFrames) {
    await expect.poll(() => page.evaluate(name => Boolean(window.wordJellyPowerupEvidence.frames[name]), name),
      { message: `Retain the actual ${name} canvas frame` }).toBe(true);
    const encoded = await page.evaluate(name => window.wordJellyPowerupEvidence.frames[name], name);
    fs.writeFileSync(info.outputPath(`${label}-${name}.png`), Buffer.from(encoded, 'base64'));
  }
  await page.evaluate(() => window.wordJellyPowerupObserver.disconnect());
  return snapshot;
}

function recordingCount(sounds, relative) {
  const timing = recordingTiming(relative);
  return sounds.filter(sound => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate);
}

function expectAutoMergeTimeline(evidence, completed) {
  const frames = evidence.timeline.filter(frame => !frame.paused && frame.powerup.kind === 'auto_merge' && frame.powerup.active);
  const dragFrames = frames.filter(frame => frame.powerup.drags?.length);
  expect(dragFrames.length, 'The browser renders the automatic transfers').toBeGreaterThan(1);
  const resultIds = new Set(frames.flatMap(frame => frame.fusions.map(fusion => fusion.result.id)));
  const launches = new Map();
  for (const frame of frames) {
    expect(frame.powerup.drags.length, 'A 320 ms flight overlaps at most three following 100 ms launches').toBeLessThanOrEqual(4);
    const reserved = new Set();
    for (const drag of frame.powerup.drags) {
      expect(drag.duration, 'Every automatic transfer takes 320 ms').toBeCloseTo(AUTO_MERGE_DRAG, 6);
      expect(drag.elapsed).toBeGreaterThanOrEqual(0);
      expect(drag.elapsed).toBeLessThanOrEqual(AUTO_MERGE_DRAG + 0.00001);
      expect(drag.started_at).toBeGreaterThanOrEqual(0);
      expect(drag.source_id).not.toBe(drag.target_id);
      expect(validPair(drag.source, drag.target),
        'Every transfer follows a reviewed root join, matching picture, or same-word level sum up to nine').toBe(true);
      for (const id of [drag.source_id, drag.target_id]) {
        expect(reserved.has(id), 'Overlapping transfers reserve distinct sources and targets').toBe(false);
        reserved.add(id);
        expect(frame.tiles.some(tile => tile.id === id), 'Both reserved endpoints remain on the board until fusion').toBe(true);
      }
      for (const tile of [drag.source, drag.target].filter(tile => resultIds.has(tile.id))) {
        expect(tile.settling, 'A dependent source or target has completed its landing').toBe(false);
        expect(tile.age, 'A dependent source or target is stable before its next flight')
          .toBeGreaterThanOrEqual((tile.settle_seconds ?? 0.36) - 0.00001);
      }
      launches.set(`${drag.started_at}:${drag.source_id}:${drag.target_id}`, drag);
    }
    for (const fusion of frame.fusions) {
      expect(fusion.operation).toBe('merge');
      expect(fusion.automatic).toBe(true);
      expect(fusion.duration, 'The transfer is followed by a 110 ms liquid union').toBeCloseTo(AUTO_MERGE_FUSION, 6);
      expect(fusion.elapsed).toBeGreaterThanOrEqual(0);
      expect(fusion.elapsed).toBeLessThanOrEqual(AUTO_MERGE_FUSION + 0.00001);
      for (const id of [fusion.a_id, fusion.b_id]) {
        expect(reserved.has(id), 'Fusion endpoints cannot be reused by another operation').toBe(false);
        reserved.add(id);
      }
      expect(reserved.has(fusion.result.id), 'An unfinished fusion result cannot be used by an overlapping flight').toBe(false);
    }
    for (const tile of frame.tiles.filter(tile => resultIds.has(tile.id) && tile.settling)) {
      expect(tile.settled, 'A new union remains unavailable during its landing').toBe(false);
      expect(tile.settle_seconds, 'Each new union uses a 30 ms landing before becoming stable').toBeCloseTo(AUTO_MERGE_SETTLE, 6);
    }
  }
  const ordered = [...launches.values()].sort((a, b) => a.started_at - b.started_at);
  expect(ordered.length, 'Every completed pair was shown in transit').toBe(completed);
  expect(ordered.length).toBeGreaterThan(1);
  expect(ordered[0].started_at, 'The first eligible pair launches after the accepted 100 ms hit-stop').toBeCloseTo(0.1, 5);
  expect(ordered[1].started_at - ordered[0].started_at,
    'The next independent pair launches on the 100 ms beat while the first still flies').toBeCloseTo(AUTO_MERGE_BEAT, 5);
  for (const launch of ordered) {
    const beat = launch.started_at / AUTO_MERGE_BEAT;
    expect(beat, 'Every launch remains aligned to the 100 ms grid after dependency waits').toBeCloseTo(Math.round(beat), 5);
  }
  let overlappingLaunches = 0;
  for (let index = 1; index < ordered.length; index++) {
    expect(ordered[index].started_at - ordered[index - 1].started_at,
      'A skipped dependency beat never becomes a burst of catch-up launches').toBeGreaterThanOrEqual(AUTO_MERGE_BEAT - 0.00001);
    const previous = ordered[index - 1], current = ordered[index];
    if (current.started_at < previous.started_at + previous.duration - 0.00001) {
      overlappingLaunches++;
      expect(new Set([previous.source_id, previous.target_id, current.source_id, current.target_id]).size,
        'Overlapping launch windows reserve four distinct endpoints, even between rendered frames').toBe(4);
    }
  }
  expect(overlappingLaunches, 'The actual 320 ms flights overlap on the 100 ms launch rhythm').toBeGreaterThan(0);
  expect(frames.some(frame => frame.powerup.drags.length && frame.fusions.length),
    'A liquid union remains visible while the next pair flies').toBe(true);
  return { frames: dragFrames, launches: ordered };
}

test('upgraded Auto merge caps completed outputs while keeping its overlapping 100 ms launch rhythm', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening } = await start(page, info, 5000, 0,
    { pauseOnReady: true, autoMergeLevel: 4, challenge: false });
  let before = opening;
  expect(before.columns).toBe(7);
  expect(before.rows).toBe(8);
  expect(before.practice.compact).toBe(false);
  expect(before.practice.rect[0] + before.practice.rect[2]).toBeLessThanOrEqual(before.board_rect[0] + 0.5);
  expect(before.powerup_buttons.auto_merge).toMatchObject({ auto_merge_level: 4, capacity: 6,
    capacity_badge: { visible: true, text: '6' } });
  const saved = await savedGrowth(page), bounds = await metrics(page);
  await beginTrace(page, 'auto-merge-100ms');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  const rect = before.powerup_buttons.auto_merge.rect;
  const hover = async () => {
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.powerup_buttons.auto_merge.enabled && state.tiles.every(tile => tile.settled) &&
        state.spawn_interval - state.spawn_elapsed > 6;
    }, { message: 'Observe settled inputs with a complete driver-interaction window before the next supply' }).toBe(true);
    await page.mouse.move(bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
      bounds.y + (rect[1] + rect[3] / 2) * bounds.scale);
    await expect.poll(async () => (await jelly(page)).auto_merge_hover?.active,
      { message: 'A real pointer hover forecasts the exported native Auto merge inputs' }).toBe(true);
    const state = await jelly(page);
    expect(state.auto_merge_hover.capacity).toBe(6);
    expect(state.auto_merge_hover.result_count).toBeGreaterThan(0);
    expect(state.auto_merge_hover.result_count).toBeLessThanOrEqual(6);
    const planned = [...state.auto_merge_hover.input_ids].sort((a, b) => a - b);
    expect(state.tiles.filter(tile => tile.completion_hint).map(tile => tile.id).sort((a, b) => a - b))
      .toEqual(planned);
    expect(state.tiles.every(tile => tile.match_dimmed === !planned.includes(tile.id))).toBe(true);
    expect((await wallet(page)).balance).toBe(5000);
    expect(state.paused).toBe(false);
    expect(state.powerup.active).toBe(false);
    return state;
  };
  await hover();
  await capture(page, info, 'auto-merge-hover-inputs');
  await page.mouse.move(bounds.x + 4, bounds.y + 4);
  await expect.poll(async () => (await jelly(page)).auto_merge_hover.active).toBe(false);
  expect((await jelly(page)).tiles.every(tile => !tile.completion_hint && !tile.match_dimmed)).toBe(true);
  before = await hover();
  const forecast = before.auto_merge_hover;
  await pressRect(page, before.powerup_buttons.auto_merge.rect, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4400);
  expect((await jelly(page)).auto_merge_hover.active).toBe(false);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active && state.powerup.stage === 'complete' &&
      state.tiles.every(tile => tile.settled);
  }, { timeout: 60000 }).toBe(true).catch(async error => {
    fs.writeFileSync(info.outputPath('auto-merge-completion-state.json'),
      JSON.stringify(await jelly(page), null, 2));
    fs.writeFileSync(info.outputPath('auto-merge-completion-trace.json'),
      JSON.stringify(await page.evaluate(() => window.wordJellyPowerupEvidence), null, 2));
    throw error;
  });
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const after = await jelly(page);
  const evidence = await retainTrace(page, info, 'auto-merge-100ms', ['auto-midpoint', 'auto-fusion']);
  expectAutoMergeTimeline(evidence, after.powerup.completed);
  expect(after.powerup.completed).toBeGreaterThan(1);
  expect(after.powerup.total).toBe(after.powerup.completed);
  expect(after.merged_count - before.merged_count).toBe(after.powerup.completed);
  expect(after.powerup.capacity).toBe(6);
  expect(after.powerup.completed_results).toBeGreaterThan(0);
  expect(after.powerup.completed_results).toBeLessThanOrEqual(6);
  expect(after.powerup.result_ids).toHaveLength(after.powerup.completed_results);
  const originalIds = new Set(before.tiles.map(tile => tile.id));
  const survivingIds = new Set(after.tiles.map(tile => tile.id));
  expect(before.tiles.filter(tile => !survivingIds.has(tile.id)).map(tile => tile.id).sort((a, b) => a - b))
    .toEqual([...forecast.input_ids].sort((a, b) => a - b));
  expect(after.powerup.completed_results).toBe(forecast.result_count);
  expect(after.auto_merge_hover.active, 'Finishing under the pointer cannot latch the consumed preview').toBe(false);
  expect(after.powerup.result_ids.every(id => after.tiles.some(tile =>
    tile.id === id && tile.jelly_kind === 'merged')),
    'Every counted output survives instead of being reused by another path').toBe(true);
  expect(progress(after), 'Auto merge leaves the resulting words for manual collection').toEqual(progress(before));
  // A short union can fall between rendered frames; later drag endpoints and
  // the final merged words still distinguish its results from fresh supply.
  const resultIds = new Set(evidence.timeline.flatMap(frame => [
    ...frame.fusions.map(fusion => fusion.result.id),
    ...(frame.powerup.drags || []).flatMap(drag => [drag.source_id, drag.target_id])
      .filter(id => !originalIds.has(id))
  ]).concat(after.tiles.filter(tile => tile.jelly_kind === 'merged' && !originalIds.has(tile.id))
    .map(tile => tile.id)));
  expect(resultIds.size, 'Every automatic result is accounted for').toBe(after.powerup.completed);
  const supplied = after.tiles.filter(tile => !originalIds.has(tile.id) && !resultIds.has(tile.id));
  expect(supplied.length, 'Only genuinely generated Fill bodies add carried markers')
    .toBe(after.generated_tiles - before.generated_tiles);
  expect(fragmentTotal(after)).toBe(fragmentTotal(before) + fragmentTotal({ tiles: supplied }));
  expect(await savedGrowth(page)).toBe(saved);
  const persisted = await storedWallet(page);
  expect(persisted.balance).toBe(4400);
  const debits = Object.entries(persisted.receipts).filter(([, amount]) => amount < 0);
  expect(debits).toHaveLength(1);
  expect(debits[0][0].endsWith(`:${after.powerup.receipt_id}`)).toBe(true);
  expect(debits[0][1]).toBe(-600);
  await capture(page, info, 'auto-merge-100ms-complete');
  expect(errors).toEqual([]);
});

test('word goals hover their matching Jellies and buy only that family while Challenge keeps Fill on', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening } = await start(page, info, 2000, 3, { pauseOnReady: true });
  const bounds = await metrics(page);
  expect(opening.powerup_buttons.family_merge).toBeUndefined();
  expect(opening.fill_control).toMatchObject({ on: true, locked: true, enabled: false });
  expect(opening.fill_control.presentation).toMatchObject({ icon_only: true, on: true, locked: true,
    glow: true, unified_switch: true, stationary_icon: true });
  expect(opening.fill_control.presentation).not.toHaveProperty('thumb_x');
  const goal = opening.practice.words.find(item => !item.mastered && item.enabled);
  expect(goal).toBeTruthy();
  const id = goal.word_id || goal.id;
  const family = tile => tile.word?.id || tile.image_word?.id || tile.word_candidate?.id || tile.source_word_id;
  const unrelated = opening.tiles.filter(tile => family(tile) !== id).map(tile => tile.id);
  expect(unrelated.length, 'The test has a genuine second family, not a single-family proxy').toBeGreaterThan(0);
  expect(goal.purchase).toMatchObject({ price: 50, price_text: '50', title: goal.text, goal: true });
  const beforeProgress = progress(opening), beforeGrowth = await savedGrowth(page);
  await beginTrace(page, 'paid-goal');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await page.mouse.move(bounds.x + (goal.rect[0] + goal.rect[2] / 2) * bounds.scale,
    bounds.y + (goal.rect[1] + goal.rect[3] / 2) * bounds.scale);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.goal_hover?.word_id === id && state.goal_hover.elapsed >= 0.2 &&
      state.tiles.every(tile => tile.completion_hint === (family(tile) === id) &&
        tile.match_dimmed === (family(tile) !== id));
  }).toBe(true);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  expect((await jelly(page)).goal_hover.word_id).toBe('');
  expect((await wallet(page)).balance).toBe(2000);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, goal.rect, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(1950);
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.powerup.active && state.powerup.kind === 'family_merge';
  }, { timeout: 20000 }).toBe(true);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const after = await jelly(page);
  expect(after.powerup.family_word_id).toBe(id);
  expect(after.tiles.some(tile => tile.jelly_kind === 'merged' && tile.word.id === id)).toBe(true);
  expect(unrelated.every(old => after.tiles.some(tile => tile.id === old))).toBe(true);
  expect(progress(after)).toEqual(beforeProgress);
  expect(after.combo.coins).toBe(0);
  expect(await savedGrowth(page)).toBe(beforeGrowth);
  expect(after.practice.words.every(item => item.price === 75)).toBe(true);
  const persisted = await storedWallet(page);
  expect(persisted.balance).toBe(1950);
  expect(Object.values(persisted.receipts).filter(amount => amount < 0)).toEqual([-50]);
  const evidence = await retainTrace(page, info, 'paid-goal', ['goal-hover', 'goal-paid']);
  expect(evidence.timeline.some(frame => frame.goals.some(item => item.id === goal.id &&
    item.purchase.spent_coins === 50 && item.purchase.price === 75)),
  'The clicked goal shows its real debit without replacing the next quote').toBe(true);
  await capture(page, info, 'paid-goal-complete');
  expect(errors).toEqual([]);
});

test('a pending word goal reports its exact shortfall without spending or merging', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening } = await start(page, info, 25, 0, { pauseOnReady: true });
  const goal = opening.practice.words.find(item => !item.mastered && item.enabled);
  expect(goal).toBeTruthy();
  const bounds = await metrics(page), saved = await storedWallet(page), growth = await savedGrowth(page);
  await beginTrace(page, 'unaffordable-goal');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, goal.rect, bounds);
  await expect.poll(async () => (await jelly(page)).practice.words.find(item => item.id === goal.id)
    ?.purchase.feedback_serial).toBe(goal.purchase.feedback_serial + 1);
  await expect.poll(async () => (await jelly(page)).practice.words.find(item => item.id === goal.id)
    ?.purchase.feedback_active).toBe(false);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const evidence = await retainTrace(page, info, 'unaffordable-goal', ['negative-goal']);
  const funds = evidence.timeline.flatMap(frame => frame.goals).filter(item =>
    item.id === goal.id && item.purchase.funds_warning);
  expect(funds.length).toBeGreaterThan(0);
  expect(funds.every(item => item.purchase.title === 'Need coins' && item.purchase.missing_coins === 25 &&
    item.purchase.price_text === '50' && item.purchase.spent_coins === 0 &&
    item.purchase.accessibility_name.includes('Need 25 more coins'))).toBe(true);
  expect(await storedWallet(page)).toEqual(saved);
  expect(await savedGrowth(page)).toBe(growth);
  expect(progress(await jelly(page))).toEqual(progress(opening));
  expect((await jelly(page)).merged_count).toBe(opening.merged_count);
  expect((await jelly(page)).powerup.active).toBe(false);
  expect(errors).toEqual([]);
});

test('powerup prices stay visible and unaffordable purchases give feedback without changing the board or wallet', async ({ page }, info) => {
  test.setTimeout(600000);
  const { errors, reducedMotion, audioAvailable, opening } = await start(page, info, 0, 0, { pauseOnReady: true });
  const initialSave = await storedWallet(page), growth = await savedGrowth(page), bounds = await metrics(page);
  expectLayout(opening, bounds, false);
  await capture(page, info, 'word-jelly-powerups-idle-zero-coins');
  const audioEvidence = { reducedMotion, audioAvailable, trials: [] };
  for (const kind of Object.keys(prices)) {
    const from = await playbackIndex(page);
    await beginTrace(page, `negative-${kind}`);
    const before = await jelly(page);
    await page.keyboard.press('p');
    await expect.poll(async () => (await jelly(page)).paused).toBe(false);
    await pressRect(page, before.powerup_buttons[kind].rect, bounds);
    await expect.poll(async () => (await jelly(page)).powerup_buttons[kind].feedback_serial).toBe(before.powerup_buttons[kind].feedback_serial + 1);
    await expect.poll(async () => (await jelly(page)).powerup_buttons[kind].feedback_active).toBe(false);
    await page.keyboard.press('p');
    await expect.poll(async () => (await jelly(page)).paused).toBe(true);
    const evidence = await retainTrace(page, info, `word-jelly-${kind}-unaffordable`, [`negative-${kind}`]);
    const feedback = evidence.timeline.map(frame => frame.buttons[kind]).filter(button => button.feedback_active);
    expect(feedback.some(button => !button.feedback_success && button.light > 0)).toBe(true);
    const funds = feedback.filter(button => button.funds_warning);
    expect(funds.length, 'The exported game identifies the actual insufficient-funds cause').toBeGreaterThan(0);
    expect(funds.every(button => button.title === 'Need coins' && button.missing_coins === prices[kind] &&
      button.price_text === String(prices[kind])), 'The warning preserves the real price and shortfall').toBe(true);
    if (reducedMotion !== 'reduce')
      expect(funds.some(button => button.price_offset.some(value => Math.abs(value) > 0.01)),
        'The actual coin-price row, not just the tool art, recoils').toBe(true);
    if (reducedMotion === 'reduce') for (const button of feedback) {
      expect(button.icon_scale).toBe(1);
      expect(button.icon_rotation).toBe(0);
      expect(button.icon_offset).toEqual([0, 0]);
      expect(button.price_offset).toEqual([0, 0]);
      expect(button.coin_scale).toBe(1);
    }
    const after = await jelly(page);
    expect(after.powerup.active).toBe(false);
    expect(after.merged_count).toBe(before.merged_count);
    expect(progress(after)).toEqual(progress(before));
    for (const original of before.tiles) {
      const retained = after.tiles.find(tile => tile.id === original.id);
      expect({ text: retained.text, mass: retained.mass, fragments: retained.fragments })
        .toEqual({ text: original.text, mass: original.mass, fragments: original.fragments });
    }
    if (audioAvailable) {
      const recording = await expectRecording(page, from, WRONG);
      expect(recording.peak).toBeGreaterThan(0.01);
      const sounds = await soundsSince(page, from);
      expect(recordingCount(sounds, WRONG)).toHaveLength(1);
      expect(recordingCount(sounds, RIGHT)).toHaveLength(0);
      audioEvidence.trials.push({ kind, recording, sounds });
    }
    expect(await storedWallet(page)).toEqual(initialSave);
    expect(await savedGrowth(page)).toBe(growth);
  }
  // Reload the same persisted wallet for the independent muted trial.
  await openGame(page, { reducedMotion, home: true });
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).muted)).toBe(true);
  await chooseMode(page, 'word_jelly', { challenge: true });
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.phase === 'playing' && !state.paused && state.tiles.length === 56 &&
      state.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true);
  const beforeMuted = await readyPowerup(page, 'auto_merge');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const mutedFrom = await playbackIndex(page);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, beforeMuted.powerup_buttons.auto_merge.rect, bounds);
  await expect.poll(async () => (await jelly(page)).powerup_buttons.auto_merge.feedback_serial)
    .toBe(beforeMuted.powerup_buttons.auto_merge.feedback_serial + 1).catch(async error => {
      fs.writeFileSync(info.outputPath('muted-purchase-state.json'),
        JSON.stringify({ before: beforeMuted, after: await jelly(page), bounds: await metrics(page) }, null, 2));
      throw error;
    });
  await page.waitForTimeout(450);
  audioEvidence.muted = await soundsSince(page, mutedFrom);
  expect(audioEvidence.muted, 'Mute also silences rejected purchases').toEqual([]);
  expect((await wallet(page)).balance).toBe(0);
  expect(await storedWallet(page)).toEqual(initialSave);
  fs.writeFileSync(info.outputPath('word-jelly-powerups-negative-audio.json'), JSON.stringify(audioEvidence, null, 2));
  expect(errors).toEqual([]);
});

test('only Auto merge remains purchasable while naturally earned chest fragments still collect', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening } = await start(page, info, 5000, 3, { pauseOnReady: true });
  expect(Object.keys(opening.powerup_buttons)).toEqual(['auto_merge']);
  expect(Object.keys(opening.powerup_prices).sort()).toEqual(['auto_merge', 'family_merge']);
  const carried = fragmentTotal(opening), before = await wallet(page);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, (await jelly(page)).powerup_buttons.auto_merge.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(before.balance - 600);
  await expect.poll(async () => (await jelly(page)).powerup.active, { timeout: 30000 }).toBe(false);
  const merged = await jelly(page);
  expect(fragmentTotal(merged), 'Removing the paid Treasure card preserves all naturally carried fragments').toBe(carried);
  expect((await wallet(page)).balance).toBe(before.balance - 600);
  const ready = merged.tiles.filter(tile => tile.jelly_kind === 'merged' && tile.settled);
  expect(ready.length).toBeGreaterThan(0);
  for (const tile of ready) {
    expectFragmentBadge(tile);
    expectCollectionReward(tile);
  }
  const fragments = ready.reduce((total, tile) => total + tile.fragments, 0);
  await pressRect(page, merged.collect_button.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(merged.cleared_pairs + ready.length);
  expect((await jelly(page)).fragment_count).toBe(merged.fragment_count + fragments);
  expect(Object.keys((await jelly(page)).powerup_buttons)).toEqual(['auto_merge']);
  await capture(page, info, 'natural-chest-rewards-without-retired-tools');
  expect(errors).toEqual([]);
});
