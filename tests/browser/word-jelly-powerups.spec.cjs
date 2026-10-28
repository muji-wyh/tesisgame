const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { collectionCoins, expectCollectionReward } = require('./word-jelly-rewards.cjs');
const { openGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap, observeAudio, seedPipLevel } = require('./game-ui.cjs');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');
const morphology = Array.from({ length: 10 }, (_, index) =>
  require(`../../data/vocabulary/morphology/age-${String(index + 3).padStart(2, '0')}.json`).entries).flat();
const analyses = new Map(morphology.map(entry => [entry.analysis.id, entry.analysis]));

const WALLET_KEY = 'growWithPip.coinWallet.v1';
const GROWTH_KEY = 'growWithPip.growth.v1';
const WRONG = 'assets/imported-audio/pair-feedback/wrong.wav';
const RIGHT = 'assets/imported-audio/pair-feedback/right.wav';
const FRAGMENT_APPEAR = 'assets/audio/fragments/appear.wav';
const FRAGMENT = 'assets/audio/fragments/arrive.wav';
const MERGE = 'assets/imported-audio/jelly-interaction/merge-together-v3.wav';
const prices = { auto_merge: 600, fragments: 200 };
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

async function start(page, info, balance, pipLevel = 0, { pauseOnReady = false } = {}) {
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  await page.setViewportSize(/iphone|android|mobile/.test(info.project.name)
    ? { width: 393, height: 852 } : { width: 1473, height: 1175 });
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  await seedPipLevel(page, pipLevel);
  await page.addInitScript(({ balance, walletKey }) => {
    if (localStorage.getItem(walletKey) === null) localStorage.setItem(walletKey,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify(balance ? { 'browser-opening-coins': balance } : {})}\n`);
  }, { balance, walletKey: WALLET_KEY });
  const errors = await openGame(page, { reducedMotion });
  await chooseMode(page, 'word_jelly', { challenge: true });
  let opening;
  await expect.poll(async () => {
    const state = opening = await jelly(page);
    return state.visible && !state.paused && state.phase === 'playing' && state.tiles.length === 40 &&
      state.tiles.every(tile => tile.settled) &&
      Object.values(state.powerup_buttons || {}).filter(button => button.visible).length === 3;
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
    expect(button.title.replace(/\s+/g, ' ')).toBe(kind === 'auto_merge' ? 'Auto merge' : 'Treasure');
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
      if (powerup.active && powerup.kind === 'fragments' && powerup.elapsed > 0.08 && powerup.elapsed < 0.35 && state.powerup_effect_count > 0)
        capture('fragment-flight');
      if (powerup.kind === 'fragments' && powerup.completed > 0 && state.powerup_effect_count >= 5) capture('fragment-arrival');
      if (powerup.kind === 'fragments' && state.tiles.some(tile => tile.fragments > 2 && tile.fragment_badge?.scale > 1.04))
        capture('fragment-stack-arrival');
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
  expect(ordered[0].started_at, 'The first eligible pair launches immediately').toBeCloseTo(0, 5);
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

test('Auto merge launches eligible pairs every 100 ms with overlapping 320 ms flights', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening: before } = await start(page, info, 5000, 0, { pauseOnReady: true });
  const saved = await savedGrowth(page), bounds = await metrics(page);
  await beginTrace(page, 'auto-merge-100ms');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, before.powerup_buttons.auto_merge.rect, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4400);
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
  const originalIds = new Set(before.tiles.map(tile => tile.id));
  expect(forwardPairs(after).some(pair => pair.every(id => originalIds.has(id))),
    'The captured board has no remaining original pair; required Fill may supply new paths').toBe(false);
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

test('Magnet charges only for the player-selected family and Challenge keeps Fill on', async ({ page }, info) => {
  test.setTimeout(300000);
  const { errors, opening } = await start(page, info, 2000, 3, { pauseOnReady: true });
  const bounds = await metrics(page);
  expect(opening.powerup_buttons.family_merge.enabled).toBe(true);
  expect(opening.fill_control).toMatchObject({ on: true, locked: true, enabled: false });
  expect(opening.fill_control.presentation).toMatchObject({ icon_only: true, on: true, locked: true, glow: true });
  const pairs = forwardPairs(opening).map(pair => pair.map(id => opening.tiles.find(tile => tile.id === id)))
    .filter(pair => pair.some(tile => tile.jelly_kind === 'picture'));
  expect(pairs.length).toBeGreaterThan(0);
  const selected = pairs[0].find(tile => tile.jelly_kind === 'picture');
  const id = selected.image_word.id;
  const family = tile => tile.word?.id || tile.image_word?.id || tile.word_candidate?.id || tile.source_word_id;
  const unrelated = opening.tiles.filter(tile => family(tile) !== id).map(tile => tile.id);
  expect(unrelated.length, 'The test has a genuine second family, not a single-family proxy').toBeGreaterThan(0);
  const beforeProgress = progress(opening), beforeGrowth = await savedGrowth(page);
  await page.evaluate(walletKey => {
    const status = document.getElementById('game-status');
    window.magnetChoiceFrames = [];
    window.magnetChoiceObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      window.magnetChoiceFrames.push({ selection: state.family_selection, powerup: state.powerup,
        preview: state.preview?.enabled, title: state.powerup_buttons?.family_merge?.title,
        wallet: localStorage.getItem(walletKey) });
    });
    window.magnetChoiceObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  }, WALLET_KEY);
  // Keep the genuine ten-second full-board clock for player gestures, not
  // browser-driver assertions; pausing itself deliberately cancels a selector.
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, opening.powerup_buttons.family_merge.rect, bounds);
  await pressRect(page, opening.powerup_buttons.family_merge.rect, bounds);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const choice = await page.evaluate(() => window.magnetChoiceFrames.filter(frame => frame.selection?.active));
  expect(choice.length, 'The real player gesture visibly arms the selector before its next press cancels it').toBeGreaterThan(0);
  expect(choice.every(frame => frame.title === 'Pick Jelly' && !frame.powerup.active && !frame.preview)).toBe(true);
  expect(choice.every(frame => /^balance=2000$/m.test(frame.wallet))).toBe(true);
  expect((await jelly(page)).family_selection.active).toBe(false);
  expect((await wallet(page)).balance).toBe(2000);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, opening.powerup_buttons.family_merge.rect, bounds);
  await pressRect(page, selected.rect, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(1800);
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.powerup.active && state.powerup.kind === 'family_merge';
  }, { timeout: 20000 }).toBe(true);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const after = await jelly(page);
  expect(after.powerup.family_word_id).toBe(id);
  expect(after.powerup.selected_id).toBe(selected.id);
  expect(after.tiles.some(tile => tile.jelly_kind === 'merged' && tile.word.id === id)).toBe(true);
  expect(unrelated.every(old => after.tiles.some(tile => tile.id === old))).toBe(true);
  expect(progress(after)).toEqual(beforeProgress);
  expect(after.combo.coins).toBe(0);
  expect(await savedGrowth(page)).toBe(beforeGrowth);
  expect(after.powerup_buttons.family_merge.price).toBe(300);
  const persisted = await storedWallet(page);
  expect(persisted.balance).toBe(1800);
  expect(Object.values(persisted.receipts).filter(amount => amount < 0)).toEqual([-200]);
  await page.evaluate(() => window.magnetChoiceObserver.disconnect());
  await capture(page, info, 'selected-family-magnet');
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
    return state.phase === 'playing' && !state.paused && state.tiles.length === 40 &&
      state.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true);
  const beforeMuted = await readyPowerup(page, 'fragments');
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const mutedFrom = await playbackIndex(page);
  await page.keyboard.press('p');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await pressRect(page, beforeMuted.powerup_buttons.fragments.rect, bounds);
  await expect.poll(async () => (await jelly(page)).powerup_buttons.fragments.feedback_serial)
    .toBe(beforeMuted.powerup_buttons.fragments.feedback_serial + 1).catch(async error => {
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

test('rapid Treasure purchases overlap their flights without a cooldown and preserve each paid delivery', async ({ page }, info) => {
  test.setTimeout(180000);
  const { errors, audioAvailable } = await start(page, info, 900);
  const opening = await readyPowerup(page, 'fragments'), growth = await savedGrowth(page);
  const bounds = await metrics(page), rect = opening.powerup_buttons.fragments.rect;
  const from = await playbackIndex(page);
  await beginTrace(page, 'treasure-repeat');
  // Trusted consecutive taps reuse the stable target so no polling wait becomes a cooldown.
  for (let click = 0; click < 4; click++) await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(0);
  await expect.poll(async () => (await jelly(page)).powerup_buttons.fragments.feedback_serial)
    .toBe(opening.powerup_buttons.fragments.feedback_serial + 4);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'fragments' && !state.powerup.active && state.powerup.stage === 'complete';
  }).toBe(true);
  const final = await jelly(page), saved = await storedWallet(page);
  const evidence = await retainTrace(page, info, 'word-jelly-treasure-repeat', ['fragment-arrival', 'negative-fragments']);
  const batches = new Map();
  for (const arrival of final.powerup.arrivals) {
    if (!batches.has(arrival.receipt_id)) batches.set(arrival.receipt_id, []);
    batches.get(arrival.receipt_id).push(arrival);
  }
  expect(batches.size, 'Every funded click keeps its independent receipt in the same live timeline').toBe(3);
  expect(final.powerup.receipt_id).toBe([...batches.keys()][0]);
  const first = [...batches.values()][0], firstEnd = first.at(-1).at + 0.35;
  for (const [receipt, arrivals] of batches) {
    expect(arrivals.length).toBeGreaterThanOrEqual(2);
    expect(arrivals.length).toBeLessThanOrEqual(8);
    expect(arrivals[0].at - 0.42, 'Each repeat begins before the original animation finishes').toBeLessThan(firstEnd);
    for (const [index, arrival] of arrivals.entries()) {
      expect(arrival.receipt_id).toBe(receipt);
      expect(arrival.total).toBe(arrivals.length);
      expect(arrival.at).toBeCloseTo(arrivals[0].at + index * 0.18, 5);
      expect(arrival.arrived).toBe(true);
    }
  }
  expect(final.powerup.completed).toBe(final.powerup.total);
  expect(fragmentTotal(final) - fragmentTotal(opening)).toBe(final.powerup.total);
  for (const tile of final.tiles) expectFragmentBadge(tile);
  expect(progress(final)).toEqual(progress(opening));
  expect(await savedGrowth(page)).toBe(growth);
  expect(saved.balance).toBe(0);
  expect(Object.values(saved.receipts).filter(amount => amount < 0)).toEqual([-200, -300, -400]);
  expect(final.powerup_buttons.fragments.price).toBe(400);
  expect(final.powerup_buttons.fragments.enabled).toBe(true);
  const overlap = evidence.timeline.filter(frame => frame.powerup.active && frame.powerup.kind === 'fragments' &&
    new Set((frame.powerup.arrivals || []).map(arrival => arrival.receipt_id)).size === 3);
  expect(overlap.length, 'All three payments share continuing animation instead of replacing or draining earlier flights').toBeGreaterThan(0);
  expect(overlap.some(frame => frame.effects > 0)).toBe(true);
  expect(overlap.some(frame => frame.buttons.fragments.enabled && !frame.buttons.fragments.busy)).toBe(true);
  for (const frame of overlap) {
    expect(frame.buttons.auto_merge.enabled, 'Auto merge keeps its separate operation lock').toBe(false);
    for (const original of opening.tiles) {
      const tile = frame.tiles.find(item => item.id === original.id);
      const arrived = frame.powerup.arrivals.filter(arrival => arrival.tile_id === original.id && arrival.arrived).length;
      expect(tile.fragments, 'A marker is granted only on its own preserved arrival deadline').toBe(original.fragments + arrived);
      expectFragmentBadge(tile);
    }
  }
  if (audioAvailable) {
    const sounds = await soundsSince(page, from);
    expect(recordingCount(sounds, RIGHT)).toHaveLength(3);
    expect(recordingCount(sounds, WRONG)).toHaveLength(1);
    expect(recordingCount(sounds, FRAGMENT)).toHaveLength(final.powerup.total);
    fs.writeFileSync(info.outputPath('word-jelly-treasure-repeat-audio.json'), JSON.stringify(sounds, null, 2));
  }
  expect(errors).toEqual([]);
});

test('Treasure fragment stacks stay compact after many purchases', async ({ page }, info) => {
  test.setTimeout(180000);
  const { errors, reducedMotion } = await start(page, info, 10000);
  const opening = await readyPowerup(page, 'fragments');
  const bounds = await metrics(page), rect = opening.powerup_buttons.fragments.rect;
  await beginTrace(page, 'treasure-fragment-stacks');
  for (let purchase = 0; purchase < 20; purchase++)
    await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2, bounds);
  await expect.poll(async () => (await wallet(page)).balance).toBe(2300);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'fragments' && !state.powerup.active && state.powerup.stage === 'complete' &&
      state.powerup_effect_count === 0;
  }, { timeout: 20000 }).toBe(true);
  const final = await jelly(page), saved = await storedWallet(page);
  expect(final.powerup_buttons.fragments.feedback_serial).toBe(opening.powerup_buttons.fragments.feedback_serial + 20);
  expect(Object.values(saved.receipts).filter(amount => amount < 0)).toHaveLength(20);
  expect(final.tiles.some(tile => tile.fragments > 2), 'Repeated legitimate purchases produce a compact counted stack').toBe(true);
  expect(fragmentTotal(final) - fragmentTotal(opening)).toBeGreaterThanOrEqual(40);
  expect(progress(final), 'Adding fragments never collects them or changes the chest progress').toEqual(progress(opening));
  for (const tile of final.tiles) expectFragmentBadge(tile);
  await capture(page, info, 'word-jelly-fragment-stacks-idle');
  const evidence = await retainTrace(page, info, 'word-jelly-fragment-stacks',
    reducedMotion === 'reduce' ? ['fragment-arrival'] : ['fragment-stack-arrival']);
  const stackedFrames = evidence.timeline.filter(frame => frame.tiles.some(tile => tile.fragments > 2));
  expect(stackedFrames.length, 'The browser observes counted stacks during the delivery sequence').toBeGreaterThan(0);
  for (const frame of stackedFrames) for (const tile of frame.tiles) expectFragmentBadge(tile);
  expect(errors).toEqual([]);
});

test('paid Treasure arrives on the jellies and Auto merge moves every valid pair before a separate manual collection', async ({ page }, info) => {
  test.setTimeout(240000);
  const { errors, reducedMotion, audioAvailable } = await start(page, info, 5000, 3);
  const opening = await jelly(page), growth = await savedGrowth(page);
  expectLayout(opening, await metrics(page), true);
  await capture(page, info, 'word-jelly-powerups-idle-funded');
  const audioEvidence = { reducedMotion, audioAvailable };
  const beforeFragments = await jelly(page), fragmentAudioFrom = await playbackIndex(page);
  await beginTrace(page, 'fragments');
  await pressRect(page, beforeFragments.powerup_buttons.fragments.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4800);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'fragments' && !state.powerup.active && state.powerup.stage === 'complete';
  }).toBe(true);
  const afterFragments = await jelly(page);
  const fragmentEvidence = await retainTrace(page, info, 'word-jelly-treasure', ['fragment-flight', 'fragment-arrival']);
  const total = afterFragments.powerup.total, arrivals = afterFragments.powerup.arrivals;
  expect(total).toBeGreaterThanOrEqual(2);
  expect(total).toBeLessThanOrEqual(8);
  expect(afterFragments.powerup.completed).toBe(total);
  expect(arrivals).toHaveLength(total);
  expect(fragmentTotal(afterFragments) - fragmentTotal(beforeFragments)).toBe(total);
  expect(arrivals.every(arrival => arrival.arrived)).toBe(true);
  expect(progress(afterFragments), 'Buying markers does not collect fragments or unlock a chest').toEqual(progress(opening));
  expect(await savedGrowth(page)).toBe(growth);
  for (const original of beforeFragments.tiles) {
    const tile = afterFragments.tiles.find(item => item.id === original.id);
    const added = arrivals.filter(arrival => arrival.tile_id === original.id).length;
    expect(tile.fragments).toBe(original.fragments + added);
    expectFragmentBadge(tile);
  }
  const flightFrames = fragmentEvidence.timeline.filter(frame => frame.powerup.kind === 'fragments');
  expect(flightFrames.some(frame => frame.powerup.elapsed > 0.08 && frame.powerup.elapsed < 0.35 && frame.effects > 0)).toBe(true);
  for (const frame of flightFrames) for (const original of beforeFragments.tiles) {
    const tile = frame.tiles.find(item => item.id === original.id);
    const arrived = (frame.powerup.arrivals || []).filter(arrival => arrival.tile_id === original.id && arrival.arrived).length;
    expect(tile.fragments, 'A marker appears only when its own flight arrives').toBe(original.fragments + arrived);
    expectFragmentBadge(tile);
    for (const arrival of frame.powerup.arrivals || []) if (arrival.arrived)
      expect(frame.powerup.elapsed + 0.00001).toBeGreaterThanOrEqual(arrival.at);
  }
  for (const [index, arrival] of arrivals.entries()) expect(arrival.at).toBeCloseTo(0.42 + index * 0.18, 5);
  if (audioAvailable) {
    audioEvidence.fragments = { success: await expectRecording(page, fragmentAudioFrom, RIGHT),
      appearance: await expectRecording(page, fragmentAudioFrom, FRAGMENT_APPEAR),
      arrival: await expectRecording(page, fragmentAudioFrom, FRAGMENT), sounds: await soundsSince(page, fragmentAudioFrom) };
    fs.writeFileSync(info.outputPath('word-jelly-powerups-paid-audio.json'), JSON.stringify(audioEvidence, null, 2));
    expect(recordingCount(audioEvidence.fragments.sounds, RIGHT)).toHaveLength(1);
    const appearances = recordingCount(audioEvidence.fragments.sounds, FRAGMENT_APPEAR);
    const arrivals = recordingCount(audioEvidence.fragments.sounds, FRAGMENT);
    expect(appearances).toHaveLength(total);
    expect(arrivals).toHaveLength(total);
    expect(audioEvidence.fragments.appearance.fingerprint).not.toBe(audioEvidence.fragments.arrival.fingerprint);
    for (let index = 0; index < total; index++) {
      expect(arrivals[index].at - appearances[index].at,
        'Each arrival recording follows its visible 420 ms flight').toBeGreaterThan(300);
      expect(arrivals[index].at - appearances[index].at).toBeLessThan(620);
      // Video capture can quantize the 180 ms model beat to adjacent rendered frames.
      // The exact schedule is checked above; audible launches must remain distinct.
      if (index) expect(appearances[index].at - appearances[index - 1].at,
        'Fragment appearances retain separate audible delivery beats').toBeGreaterThanOrEqual(60);
    }
  }
  const savedFragments = await storedWallet(page);
  expect(savedFragments.balance).toBe(4800);
  expect(Object.values(savedFragments.receipts).filter(amount => amount < 0)).toEqual([-200]);
  expect(afterFragments.powerup_buttons.fragments.price).toBe(300);
  expect(afterFragments.powerup_buttons.fragments.price_text).toBe('300');
  expect(afterFragments.powerup_buttons.auto_merge.price).toBe(600);

  const beforeAuto = await readyPowerup(page, 'auto_merge'), autoAudioFrom = await playbackIndex(page);
  expect(forwardPairs(beforeAuto).length).toBeGreaterThan(0);
  await beginTrace(page, 'auto-merge', { pauseOnOverlap: true });
  await pressRect(page, beforeAuto.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4200);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page), pausedWallet = await storedWallet(page);
  try {
    expect(paused.powerup.active, 'A paid multi-pair operation remains pending while the tab is hidden').toBe(true);
    expect(paused.powerup.drags.length, 'The visibility change interrupts a real automatic flight').toBeGreaterThan(0);
    expect(paused.powerup.drags.length + paused.fusions.length,
      'Another automatic flight or liquid union is pending at the same time').toBeGreaterThan(1);
    expect(paused.powerup.drags.some(drag => drag.elapsed > 0)).toBe(true);
    for (const drag of paused.powerup.drags) {
      expect(drag.elapsed).toBeGreaterThanOrEqual(0);
      expect(drag.elapsed).toBeLessThan(drag.duration);
    }
    expect(new Set([...paused.powerup.drags.flatMap(drag => [drag.source_id, drag.target_id]),
      ...paused.fusions.flatMap(fusion => [fusion.a_id, fusion.b_id])]).size,
    'Every paused transfer and union retains its distinct reservations')
      .toBe(2 * (paused.powerup.drags.length + paused.fusions.length));
    await page.waitForTimeout(350);
    const stillPaused = await jelly(page);
    expect(stillPaused.powerup, 'Each transfer and the next-launch clock remain frozen').toEqual(paused.powerup);
    expect(stillPaused.fusions).toEqual(paused.fusions);
    expect(stillPaused.spawn_elapsed).toBe(paused.spawn_elapsed);
    expect(stillPaused.generated_tiles).toBe(paused.generated_tiles);
    expect(await storedWallet(page), 'Pausing never repeats the purchase').toEqual(pausedWallet);
  } finally {
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
  }
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.paused && state.powerup.kind === 'auto_merge' && !state.powerup.active &&
      state.powerup.stage === 'complete' && state.tiles.every(tile => tile.settled);
  }, { timeout: 45000 }).toBe(true);
  const afterAuto = await jelly(page);
  const autoEvidence = await retainTrace(page, info, 'word-jelly-auto-merge', ['auto-midpoint', 'auto-fusion']);
  expect(autoEvidence.pausedOnOverlap).toBe(true);
  const { frames: dragFrames, launches } = expectAutoMergeTimeline(autoEvidence, afterAuto.powerup.completed);
  const firstSource = launches[0].source_id;
  const firstTarget = launches[0].target_id;
  const original = beforeAuto.tiles.find(tile => tile.id === firstSource);
  const target = beforeAuto.tiles.find(tile => tile.id === firstTarget);
  const distance = (a, b) => Math.hypot(a[0] + a[2] / 2 - b[0] - b[2] / 2, a[1] + a[3] / 2 - b[1] - b[3] / 2);
  const travel = dragFrames.filter(frame => frame.powerup.drags.some(drag => drag.source_id === firstSource &&
    drag.elapsed / drag.duration > 0.2 && drag.elapsed / drag.duration < 0.8));
  expect(travel.some(frame => {
    const moving = frame.tiles.find(tile => tile.id === firstSource);
    return moving?.visible && distance(moving.rect, original.rect) > 0.5 && distance(moving.rect, target.rect) > 0.5 &&
      distance(moving.rect, target.rect) < distance(original.rect, target.rect);
  }), 'The actual source jelly moves between its original slot and the target, rather than only drawing a trail').toBe(true);
  expect(afterAuto.powerup_buttons.auto_merge.enabled,
    'The captured supply has no remaining complete authored path or valid same-word level sum').toBe(false);
  expect(afterAuto.merged_count - beforeAuto.merged_count).toBe(afterAuto.powerup.completed);
  expect(afterAuto.powerup.completed).toBeGreaterThan(0);
  expect(fragmentTotal(afterAuto)).toBe(fragmentTotal(beforeAuto));
  expect(progress(afterAuto), 'Automatic merging does not collect coins, fragments, or chest progress').toEqual(progress(opening));
  expect(await savedGrowth(page), 'Automatic merging does not count as a learned answer').toBe(growth);
  for (const frame of autoEvidence.timeline) {
    expect(frame.cleared).toBe(opening.cleared_pairs);
    expect(frame.coins).toBe(opening.collected_coins);
    expect(frame.fragments).toBe(opening.fragment_count);
    expect(frame.chest_tier).toBe(opening.chest_tier);
  }
  const savedAuto = await storedWallet(page);
  expect(savedAuto.balance).toBe(4200);
  expect(afterAuto.powerup_buttons.auto_merge.price).toBe(900);
  expect(afterAuto.powerup_buttons.auto_merge.price_text).toBe('900');
  expect(afterAuto.powerup_buttons.fragments.price).toBe(300);
  expect(savedAuto, 'Resuming completes the existing purchase without another debit').toEqual(pausedWallet);
  const autoDebits = Object.entries(savedAuto.receipts).filter(([id]) => !Object.hasOwn(savedFragments.receipts, id));
  expect(autoDebits).toHaveLength(1);
  expect(autoDebits[0][0].endsWith(`:${afterAuto.powerup.receipt_id}`)).toBe(true);
  expect(autoDebits[0][1]).toBe(-600);
  expect(Object.values(savedAuto.receipts).filter(amount => amount < 0).sort((a, b) => a - b)).toEqual([-600, -200]);
  const completed = afterAuto.tiles.filter(tile => tile.mass > 1 && tile.word?.id);
  expect(completed.length).toBeGreaterThan(0);
  expect(completed.every(tile => tile.assisted && !tile.mastery_eligible),
    'Automatically completed words retain their assisted learning status').toBe(true);
  for (const tile of completed) {
    expect(tile.picture_visible).toBe(true);
    expectCollectionReward(tile);
    expectFragmentBadge(tile);
  }
  if (audioAvailable) {
    audioEvidence.auto = { success: await expectRecording(page, autoAudioFrom, RIGHT),
      merge: await expectRecording(page, autoAudioFrom, MERGE), sounds: await soundsSince(page, autoAudioFrom) };
    expect(recordingCount(audioEvidence.auto.sounds, RIGHT)).toHaveLength(1);
    expect(recordingCount(audioEvidence.auto.sounds, MERGE).length).toBeGreaterThan(0);
  }
  await capture(page, info, 'word-jelly-auto-merge-awaits-collection');
  const earnedFragments = completed.reduce((sum, tile) => sum + tile.fragments, 0);
  const collectAudioFrom = await playbackIndex(page);
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    const timeline = window.fragmentCollectionTimeline = [];
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      timeline.push({ at: performance.now(), flights: state.loot?.flights || 0 });
    };
    window.fragmentCollectionObserver = new MutationObserver(record);
    window.fragmentCollectionObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
  await pressRect(page, (await jelly(page)).collect_button.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(opening.cleared_pairs + completed.length);
  const earnedCoins = collectionCoins(await jelly(page), opening, completed);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4200 + earnedCoins);
  expect((await jelly(page)).fragment_count).toBe(opening.fragment_count + earnedFragments);
  if (audioAvailable && earnedFragments > 0) {
    await expect.poll(async () => (await jelly(page)).loot.flights, { timeout: 15000 }).toBe(0);
    await expectRecording(page, collectAudioFrom, FRAGMENT);
    const sounds = await soundsSince(page, collectAudioFrom);
    const timeline = await page.evaluate(() => window.fragmentCollectionTimeline);
    const arrival = recordingCount(sounds, FRAGMENT).at(-1);
    audioEvidence.collection = { arrival, sounds, timeline };
    fs.writeFileSync(info.outputPath('word-jelly-powerups-paid-audio.json'), JSON.stringify(audioEvidence, null, 2));
    if (reducedMotion !== 'reduce') {
      const appearance = recordingCount(sounds, FRAGMENT_APPEAR).at(-1);
      expect(appearance, 'Collect plays a distinct fragment appearance recording').toBeTruthy();
      expect(arrival.at).toBeGreaterThan(appearance.at);
      // Engine animation time can lag wall time during software WebGL capture.
      // Check the visible arrival boundary; native tests verify the 650 ms flight.
      const finalFrame = timeline.findLastIndex((frame, index) => index > 0 && frame.flights === 0 && timeline[index - 1].flights > 0);
      expect(finalFrame, 'Collected fragments visibly travel before reaching the chest').toBeGreaterThan(0);
      expect(arrival.at, 'The final arrival cue belongs to the frame completing the visible flight')
        .toBeGreaterThanOrEqual(timeline[finalFrame - 1].at - 150);
      expect(arrival.at).toBeLessThanOrEqual(timeline[finalFrame].at + 250);
      audioEvidence.collection.appearance = appearance;
    }
  }
  await page.evaluate(() => window.fragmentCollectionObserver.disconnect());
  expect(await savedGrowth(page), 'Collecting automatically merged words durably records learning').not.toBe(growth);
  const learned = await page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
  for (const id of new Set(completed.map(tile => tile.word.id))) {
    expect(learned.streaks[id], 'Each committed automatic pickup counts once toward its word')
      .toBe(Math.min(3, completed.filter(tile => tile.word.id === id).length));
  }
  const finalSave = await storedWallet(page);
  expect(finalSave.balance).toBe(4200 + earnedCoins);
  expect(Object.values(finalSave.receipts).filter(amount => amount < 0).sort((a, b) => a - b)).toEqual([-600, -200]);
  fs.writeFileSync(info.outputPath('word-jelly-powerups-paid-audio.json'), JSON.stringify(audioEvidence, null, 2));
  fs.writeFileSync(info.outputPath('word-jelly-powerups-wallet.json'), JSON.stringify({ savedFragments, savedAuto, finalSave }, null, 2));
  expect(errors).toEqual([]);
});
