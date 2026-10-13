const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap, observeAudio } = require('./game-ui.cjs');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const WALLET_KEY = 'growWithPip.coinWallet.v1';
const GROWTH_KEY = 'growWithPip.growth.v1';
const WRONG = 'assets/imported-audio/pair-feedback/wrong.wav';
const RIGHT = 'assets/imported-audio/pair-feedback/right.wav';
const FRAGMENT = 'assets/imported-audio/chest-reference/step-detail.wav';
const MERGE = 'assets/imported-audio/jelly-interaction/merge-together-v3.wav';
const prices = { auto_merge: 1500, fragments: 500 };
const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => word.text.trim().toLowerCase()));
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const soundsSince = (page, from) => page.evaluate(from => window.audioObservation.playbacks.slice(from), from);
const savedGrowth = page => page.evaluate(key => localStorage.getItem(key), GROWTH_KEY);
const fragmentTotal = state => state.tiles.reduce((total, tile) => total + tile.fragments, 0);
const progress = state => ({ collected_coins: state.collected_coins, cleared_pairs: state.cleared_pairs,
  fragment_count: state.fragment_count, chest_tier: state.chest_tier, chest_count: state.chest_count });
const forwardPairs = state => state.tiles.flatMap(source => state.tiles.filter(target => source.id !== target.id &&
  words.has((source.text + target.text).trim().toLowerCase())).map(target => [source.id, target.id]));

async function start(page, info, balance) {
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  await page.setViewportSize(/iphone|android|mobile/.test(info.project.name)
    ? { width: 393, height: 852 } : { width: 1473, height: 1175 });
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  await page.addInitScript(({ balance, walletKey, growthKey }) => {
    if (localStorage.getItem(walletKey) === null) localStorage.setItem(walletKey,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify(balance ? { 'browser-opening-coins': balance } : {})}\n`);
    if (localStorage.getItem(growthKey) === null) localStorage.setItem(growthKey,
      '[growth]\nversion=3\nlevel=0\nage=0\nstreaks={}\nmastered_words=[]\nreceipts=[]\n');
  }, { balance, walletKey: WALLET_KEY, growthKey: GROWTH_KEY });
  const errors = await openGame(page, { reducedMotion, mode: 'word_jelly' });
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.tiles.length >= 18 &&
      state.tiles.every(tile => tile.settled) && Object.keys(state.powerup_buttons || {}).length === 2;
  }, { timeout: 20000 }).toBe(true);
  await expect.poll(async () => (await wallet(page)).balance).toBe(balance);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (!audioAvailable) info.annotations.push({ type: 'audio-limitation',
    description: 'This renderer has no WebAudio. Chromium verifies the recordings; this case still verifies all visible and saved outcomes.' });
  return { errors, reducedMotion, audioAvailable };
}

async function pressRect(page, rect) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
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
      receipts: JSON.parse(text.match(/^receipts\s*=\s*(\{[\s\S]*\})\s*$/m)[1]) };
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

async function beginTrace(page, label) {
  await page.evaluate(label => {
    window.wordJellyPowerupObserver?.disconnect();
    const status = document.getElementById('game-status');
    const evidence = window.wordJellyPowerupEvidence = { label, timeline: [], frames: {}, pending: [] };
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
          fragment_badges: tile.fragment_badges, rect: tile.rect, visible: tile.visible, settled: tile.settled,
          word: tile.word, picture_visible: tile.picture_visible, coins: tile.coins })),
        fusions: (state.fusions || []).map(fusion => ({ operation: fusion.operation, a_id: fusion.a_id,
          b_id: fusion.b_id, result: fusion.result, elapsed: fusion.elapsed, duration: fusion.duration })) });
      for (const [kind, button] of Object.entries(state.powerup_buttons || {})) {
        if (button.feedback_active && !button.feedback_success && button.light > 0.05) capture(`negative-${kind}`);
      }
      if (powerup.active && powerup.kind === 'fragments' && powerup.elapsed > 0.08 && powerup.elapsed < 0.35 && state.powerup_effect_count > 0)
        capture('fragment-flight');
      if (powerup.kind === 'fragments' && powerup.completed > 0 && state.powerup_effect_count >= 5) capture('fragment-arrival');
      if (powerup.active && powerup.stage === 'drag' && powerup.elapsed / powerup.duration > 0.2 && powerup.elapsed / powerup.duration < 0.8)
        capture('auto-midpoint');
      if (powerup.active && powerup.kind === 'auto_merge' && state.fusions?.length > 1)
        capture('auto-overlap');
    };
    window.wordJellyPowerupObserver = new MutationObserver(record);
    window.wordJellyPowerupObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, label);
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

test('Auto merge transfers pairs on the 80 ms beat while earlier fusions remain visible', async ({ page }, info) => {
  const { errors } = await start(page, info, 5000);
  const before = await jelly(page), saved = await savedGrowth(page);
  await beginTrace(page, 'auto-merge-80ms');
  await pressRect(page, before.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(3500);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active && state.powerup.stage === 'complete';
  }, { timeout: 20000 }).toBe(true);
  const after = await jelly(page);
  const evidence = await retainTrace(page, info, 'auto-merge-80ms', ['auto-midpoint', 'auto-overlap']);
  const moving = evidence.timeline.filter(frame => frame.powerup.stage === 'drag');
  expect(moving.length, 'The browser renders the automatic transfer').toBeGreaterThan(0);
  for (const frame of moving) expect(frame.powerup.duration).toBeCloseTo(0.08, 6);
  expect(evidence.timeline.some(frame => frame.fusions.length > 1),
    'Earlier liquid unions remain visible as subsequent pairs arrive').toBe(true);
  expect(after.powerup.completed).toBeGreaterThan(1);
  expect(after.powerup.total).toBe(after.powerup.completed);
  expect(after.merged_count - before.merged_count).toBe(after.powerup.completed);
  expect(forwardPairs(after)).toEqual([]);
  expect(progress(after), 'Auto merge leaves the resulting words for manual collection').toEqual(progress(before));
  expect(fragmentTotal(after)).toBe(fragmentTotal(before));
  expect(await savedGrowth(page)).toBe(saved);
  const persisted = await storedWallet(page);
  expect(Object.values(persisted.receipts).filter(amount => amount < 0)).toEqual([-1500]);
  await capture(page, info, 'auto-merge-80ms-complete');
  expect(errors).toEqual([]);
});

test('powerup prices stay visible and unaffordable purchases give feedback without changing the board or wallet', async ({ page }, info) => {
  test.setTimeout(180000);
  const { errors, reducedMotion, audioAvailable } = await start(page, info, 0);
  const opening = await jelly(page), initialSave = await storedWallet(page), growth = await savedGrowth(page);
  expectLayout(opening, await metrics(page), false);
  await capture(page, info, 'word-jelly-powerups-idle-zero-coins');
  const audioEvidence = { reducedMotion, audioAvailable, trials: [] };
  for (const kind of Object.keys(prices)) {
    const before = await jelly(page), from = await playbackIndex(page);
    await beginTrace(page, `negative-${kind}`);
    await pressRect(page, before.powerup_buttons[kind].rect);
    await expect.poll(async () => (await jelly(page)).powerup_buttons[kind].feedback_serial).toBe(before.powerup_buttons[kind].feedback_serial + 1);
    await expect.poll(async () => (await jelly(page)).powerup_buttons[kind].feedback_active).toBe(false);
    const evidence = await retainTrace(page, info, `word-jelly-${kind}-unaffordable`, [`negative-${kind}`]);
    const feedback = evidence.timeline.map(frame => frame.buttons[kind]).filter(button => button.feedback_active);
    expect(feedback.some(button => !button.feedback_success && button.light > 0)).toBe(true);
    if (reducedMotion === 'reduce') for (const button of feedback) {
      expect(button.icon_scale).toBe(1);
      expect(button.icon_rotation).toBe(0);
      expect(button.icon_offset).toEqual([0, 0]);
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
  await openModeMenu(page);
  await activateLibraryControl(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).muted)).toBe(true);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => (await jelly(page)).powerup_buttons.fragments.enabled).toBe(true);
  const beforeMuted = await jelly(page), mutedFrom = await playbackIndex(page);
  await pressRect(page, beforeMuted.powerup_buttons.fragments.rect);
  await expect.poll(async () => (await jelly(page)).powerup_buttons.fragments.feedback_serial)
    .toBe(beforeMuted.powerup_buttons.fragments.feedback_serial + 1);
  await page.waitForTimeout(450);
  audioEvidence.muted = await soundsSince(page, mutedFrom);
  expect(audioEvidence.muted, 'Mute also silences rejected purchases').toEqual([]);
  expect((await wallet(page)).balance).toBe(0);
  expect(await storedWallet(page)).toEqual(initialSave);
  fs.writeFileSync(info.outputPath('word-jelly-powerups-negative-audio.json'), JSON.stringify(audioEvidence, null, 2));
  expect(errors).toEqual([]);
});

test('paid Treasure arrives on the jellies and Auto merge moves every valid pair before a separate manual collection', async ({ page }, info) => {
  test.setTimeout(240000);
  const { errors, reducedMotion, audioAvailable } = await start(page, info, 5000);
  const opening = await jelly(page), growth = await savedGrowth(page);
  expectLayout(opening, await metrics(page), true);
  await capture(page, info, 'word-jelly-powerups-idle-funded');
  const audioEvidence = { reducedMotion, audioAvailable };
  const beforeFragments = await jelly(page), fragmentAudioFrom = await playbackIndex(page);
  await beginTrace(page, 'fragments');
  await pressRect(page, beforeFragments.powerup_buttons.fragments.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(4500);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'fragments' && !state.powerup.active && state.powerup.stage === 'complete';
  }).toBe(true);
  const afterFragments = await jelly(page);
  const fragmentEvidence = await retainTrace(page, info, 'word-jelly-treasure', ['fragment-flight', 'fragment-arrival']);
  const total = afterFragments.powerup.total, arrivals = afterFragments.powerup.arrivals;
  expect(total).toBeGreaterThanOrEqual(1);
  expect(total).toBeLessThanOrEqual(5);
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
    expect(tile.fragment_badges).toBe(Math.min(6, tile.fragments));
  }
  const flightFrames = fragmentEvidence.timeline.filter(frame => frame.powerup.kind === 'fragments');
  expect(flightFrames.some(frame => frame.powerup.elapsed > 0.08 && frame.powerup.elapsed < 0.35 && frame.effects > 0)).toBe(true);
  for (const frame of flightFrames) for (const original of beforeFragments.tiles) {
    const tile = frame.tiles.find(item => item.id === original.id);
    const arrived = (frame.powerup.arrivals || []).filter(arrival => arrival.tile_id === original.id && arrival.arrived).length;
    expect(tile.fragments, 'A marker appears only when its own flight arrives').toBe(original.fragments + arrived);
    expect(tile.fragment_badges).toBe(Math.min(6, tile.fragments));
    for (const arrival of frame.powerup.arrivals || []) if (arrival.arrived)
      expect(frame.powerup.elapsed + 0.00001).toBeGreaterThanOrEqual(arrival.at);
  }
  for (const [index, arrival] of arrivals.entries()) expect(arrival.at).toBeCloseTo(0.42 + index * 0.18, 5);
  if (audioAvailable) {
    audioEvidence.fragments = { success: await expectRecording(page, fragmentAudioFrom, RIGHT),
      arrival: await expectRecording(page, fragmentAudioFrom, FRAGMENT), sounds: await soundsSince(page, fragmentAudioFrom) };
    expect(recordingCount(audioEvidence.fragments.sounds, RIGHT)).toHaveLength(1);
    expect(recordingCount(audioEvidence.fragments.sounds, FRAGMENT)).toHaveLength(total);
  }
  const savedFragments = await storedWallet(page);
  expect(savedFragments.balance).toBe(4500);
  expect(Object.values(savedFragments.receipts).filter(amount => amount < 0)).toEqual([-500]);

  await expect.poll(async () => (await jelly(page)).powerup_buttons.auto_merge.enabled).toBe(true);
  const beforeAuto = await jelly(page), autoAudioFrom = await playbackIndex(page);
  expect(forwardPairs(beforeAuto).length).toBeGreaterThan(0);
  await beginTrace(page, 'auto-merge');
  await pressRect(page, beforeAuto.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(3000);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyPowerupEvidence.frames['auto-midpoint']))).toBe(true);
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  expect(paused.powerup.active, 'A paid multi-pair operation remains pending while Home is open').toBe(true);
  await page.waitForTimeout(350);
  expect((await jelly(page)).powerup).toEqual(paused.powerup);
  expect((await wallet(page)).balance).toBe(3000);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.paused && state.powerup.kind === 'auto_merge' && !state.powerup.active &&
      state.powerup.stage === 'complete' && state.tiles.every(tile => tile.settled);
  }, { timeout: 45000 }).toBe(true);
  const afterAuto = await jelly(page);
  const autoEvidence = await retainTrace(page, info, 'word-jelly-auto-merge', ['auto-midpoint']);
  const dragFrames = autoEvidence.timeline.filter(frame => frame.powerup.stage === 'drag' && !frame.paused);
  expect(dragFrames.length).toBeGreaterThan(1);
  const firstSource = dragFrames[0].powerup.source_id;
  const firstTarget = dragFrames[0].powerup.target_id;
  const original = beforeAuto.tiles.find(tile => tile.id === firstSource);
  const target = beforeAuto.tiles.find(tile => tile.id === firstTarget);
  const distance = (a, b) => Math.hypot(a[0] + a[2] / 2 - b[0] - b[2] / 2, a[1] + a[3] / 2 - b[1] - b[3] / 2);
  const travel = dragFrames.filter(frame => frame.powerup.source_id === firstSource &&
    frame.powerup.elapsed / frame.powerup.duration > 0.2 && frame.powerup.elapsed / frame.powerup.duration < 0.8);
  expect(travel.some(frame => {
    const moving = frame.tiles.find(tile => tile.id === firstSource);
    return moving?.visible && distance(moving.rect, original.rect) > 0.5 && distance(moving.rect, target.rect) > 0.5 &&
      distance(moving.rect, target.rect) < distance(original.rect, target.rect);
  }), 'The actual source jelly moves between its original slot and the target, rather than only drawing a trail').toBe(true);
  for (const frame of dragFrames) expect(words.has((frame.powerup.source.text + frame.powerup.target.text).trim().toLowerCase())).toBe(true);
  expect(forwardPairs(afterAuto), 'Auto merge leaves no available forward dictionary pair').toEqual([]);
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
  expect(savedAuto.balance).toBe(3000);
  expect(Object.values(savedAuto.receipts).filter(amount => amount < 0).sort((a, b) => a - b)).toEqual([-1500, -500]);
  const completed = afterAuto.tiles.filter(tile => tile.mass > 1 && tile.word?.id);
  expect(completed.length).toBeGreaterThan(0);
  for (const tile of completed) {
    expect(tile.picture_visible).toBe(true);
    expect(tile.coins).toBe(tile.mass * 50);
    expect(tile.fragment_badges).toBe(Math.min(6, tile.fragments));
  }
  if (audioAvailable) {
    audioEvidence.auto = { success: await expectRecording(page, autoAudioFrom, RIGHT),
      merge: await expectRecording(page, autoAudioFrom, MERGE), sounds: await soundsSince(page, autoAudioFrom) };
    expect(recordingCount(audioEvidence.auto.sounds, RIGHT)).toHaveLength(1);
    expect(recordingCount(audioEvidence.auto.sounds, MERGE).length).toBeGreaterThan(0);
  }
  await capture(page, info, 'word-jelly-auto-merge-awaits-collection');
  const earnedCoins = completed.reduce((sum, tile) => sum + tile.mass * 50, 0);
  const earnedFragments = completed.reduce((sum, tile) => sum + tile.fragments, 0);
  await pressRect(page, (await jelly(page)).collect_button.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(opening.cleared_pairs + completed.length);
  await expect.poll(async () => (await wallet(page)).balance).toBe(3000 + earnedCoins);
  expect((await jelly(page)).fragment_count).toBe(opening.fragment_count + earnedFragments);
  await expect.poll(() => savedGrowth(page)).not.toBe(growth);
  const finalSave = await storedWallet(page);
  expect(finalSave.balance).toBe(3000 + earnedCoins);
  expect(Object.values(finalSave.receipts).filter(amount => amount < 0).sort((a, b) => a - b)).toEqual([-1500, -500]);
  fs.writeFileSync(info.outputPath('word-jelly-powerups-paid-audio.json'), JSON.stringify(audioEvidence, null, 2));
  fs.writeFileSync(info.outputPath('word-jelly-powerups-wallet.json'), JSON.stringify({ savedFragments, savedAuto, finalSave }, null, 2));
  expect(errors).toEqual([]);
});
