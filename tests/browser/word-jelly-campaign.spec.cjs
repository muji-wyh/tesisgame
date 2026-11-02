const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, openModeMenu, activateLibraryControl, waitForCampaignMap, metrics, tap, seedPipLevel } = require('./game-ui.cjs');
const { seedCampaign } = require('./jelly-campaign-fixture.cjs');

test.use({ trace: 'off' });
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const rewards = page => page.locator('#jelly-reward-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const stage = (map, number) => map.stage_nodes.find(item => item.number === number);
const center = (rect, bounds) => ({
  x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
  y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale
});

async function pressRect(page, rect) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
}

async function pressMapControl(page, control) {
  const rect = control.rect;
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
}

async function pullToFinish(page) {
  const recordFailure = async error => {
    fs.writeFileSync(test.info().outputPath('finish-pausing-failure.json'),
      JSON.stringify({ state: await jelly(page), rewards: await rewards(page), bounds: await metrics(page) }, null, 2));
    throw error;
  };
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.finish.visible && !state.finish.disabled;
  }, { message: 'The current round must restore its actionable header control before a player can tap it' })
    .toBe(true).catch(recordFailure);
  const live = await jelly(page);
  if (!live.pause.active) await pressRect(page, live.finish.rect);
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(true).catch(recordFailure);
  const paused = await jelly(page), bounds = await metrics(page), from = center(paused.finish.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await page.mouse.move(from.x, from.y + paused.finish.pull.threshold * bounds.scale + 12, { steps: 12 });
    await expect.poll(async () => (await jelly(page)).finish.pull.armed).toBe(true);
  } finally {
    await page.mouse.up();
  }
}

async function openMap(page) {
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  return waitForCampaignMap(page);
}

async function startStage(page) {
  const map = await openMap(page);
  expect(map.stage_nodes).toHaveLength(99);
  expect(stage(map, 1).unlocked).toBe(true);
  await pressMapControl(page, stage(map, 1));
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.campaign?.kind === 'main' &&
      state.tiles.length === 15 && state.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true);
}

async function mergeWord(page, id) {
  let source, target, before;
  await expect.poll(async () => {
    before = await jelly(page);
    source = before.tiles.find(tile => tile.settled && tile.jelly_kind === 'root' &&
      tile.word_candidate?.id === id && before.tiles.some(other =>
        other.settled && other.jelly_kind === 'picture' && other.image_word?.id === id));
    target = source && before.tiles.find(tile => tile.settled && tile.jelly_kind === 'picture' &&
      tile.image_word?.id === id);
    return Boolean(source && target);
  }).toBe(true);
  const bounds = await metrics(page), from = center(source.rect, bounds), to = center(target.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await page.mouse.move(from.x, from.y - 16);
    await page.mouse.move(to.x, to.y, { steps: 5 });
    await expect.poll(async () => {
      const state = await jelly(page), live = state.tiles.find(tile => tile.id === target.id);
      if (state.drag.target === target.id) return true;
      if (live?.settled) {
        const point = center(live.rect, bounds);
        await page.mouse.move(point.x, point.y, { steps: 3 });
      }
      return false;
    }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  let merged;
  await expect.poll(async () => {
    const state = await jelly(page);
    merged = state.tiles.find(tile => tile.jelly_kind === 'merged' && tile.word.id === id &&
      !before.tiles.some(old => old.id === tile.id));
    return Boolean(merged?.settled);
  }).toBe(true);
  return merged;
}

async function collect(page, tile) {
  const state = await jelly(page), live = state.tiles.find(item => item.id === tile.id);
  await pressRect(page, live.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBeGreaterThan(state.cleared_pairs);
}

async function waitForMap(page) {
  await expect.poll(async () => (await jelly(page)).campaign_map?.visible,
    { timeout: 45000, message: 'Automatic sweep, saved settlement and coin arrivals return to the map' }).toBe(true);
  return (await jelly(page)).campaign_map;
}

async function capture(page, info, name) {
  await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
}

async function observeFinish(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    const reward = document.getElementById('jelly-reward-status');
    window.campaignFinishFrames = [];
    window.campaignFeedbackImages = {};
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const room = JSON.parse(reward.dataset.snapshot || '{}');
      const feedback = room.stage_feedback || {};
      if (room.visible && feedback.phase === 'stars' && feedback.star_elapsed >= 0.35 &&
          feedback.star_elapsed <= 0.7 && !window.campaignFeedbackImages.stars)
        window.campaignFeedbackImages.stars = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
      if (room.visible && feedback.phase === 'bonus' && feedback.bonus_elapsed >= 0.16 &&
          feedback.bonus_elapsed <= 0.5 && !window.campaignFeedbackImages.multiplier)
        window.campaignFeedbackImages.multiplier = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
      window.campaignFinishFrames.push({
        ending: state.game_over_sequence?.active || false,
        clear_phase: state.clear_phase || '',
        batch: state.collection_batch?.active || false,
        effects: state.collection_effects?.active_count || 0,
        reveals: state.word_reveal?.active_count || 0,
        collectable: state.collectable_ids?.length || 0,
        fusions: state.fusions?.length || 0,
        feedback: room.stage_feedback || {}
      });
    };
    window.campaignFinishObserver = new MutationObserver(record);
    window.campaignFinishObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    window.campaignFinishObserver.observe(reward, { attributes: true, attributeFilter: ['data-snapshot'] });
    record();
  });
}

test('chapter segments browse only nine stages and preserve saved unlocks and ratings', async ({ page }, info) => {
  test.setTimeout(300000);
  await seedCampaign(page, { highestCleared: 12, balance: 3200 });
  const errors = await openGame(page, { home: true, reducedMotion: 'reduce' });
  await expect.poll(async () => (await wallet(page)).balance).toBe(3200);
  let map = await openMap(page);
  expect(map.segment).toMatchObject({ index: 2, count: 11, title: 'Grove', first_stage: 10, last_stage: 18 });
  expect(map.stage_nodes).toHaveLength(99);
  expect(map.stage_nodes.filter(item => item.in_segment).map(item => item.number)).toEqual([10, 11, 12, 13, 14, 15, 16, 17, 18]);
  const saved = await page.evaluate(() => ({
    campaign: localStorage.getItem('growWithPip.jellyCampaign.v1'),
    wallet: localStorage.getItem('growWithPip.coinWallet.v1')
  }));
  await capture(page, info, 'chapter-two-frontier');
  await pressMapControl(page, map.chapter_previous);
  await expect.poll(async () => (await jelly(page)).campaign_map.segment.index).toBe(1);
  map = (await jelly(page)).campaign_map;
  expect(map.chapter_previous.enabled).toBe(false);
  expect(stage(map, 1)).toMatchObject({ unlocked: true, best_stars: 1, in_segment: true });
  expect(stage(map, 13).visible).toBe(false);
  await pressMapControl(page, map.chapter_next);
  await expect.poll(async () => (await jelly(page)).campaign_map.segment.index).toBe(2);
  map = (await jelly(page)).campaign_map;
  await pressMapControl(page, map.chapter_next);
  await expect.poll(async () => (await jelly(page)).campaign_map.segment.index).toBe(3);
  await expect.poll(async () => {
    map = (await jelly(page)).campaign_map;
    const target = stage(map, 19), area = map.scroll_rect, rect = target.rect;
    return target.visible && rect.y >= area.y - 0.5 && rect.y + rect.height <= area.y + area.height + 0.5;
  }).toBe(true);
  map = (await jelly(page)).campaign_map;
  expect(map.segment).toMatchObject({ title: 'Pine Trail', first_stage: 19, last_stage: 27 });
  expect(map.stage_nodes.filter(item => item.in_segment).every(item => !item.unlocked)).toBe(true);
  await pressMapControl(page, stage(map, 19));
  expect((await jelly(page)).campaign_map.visible).toBe(true);
  expect((await wallet(page)).balance).toBe(3200);
  expect(await page.evaluate(() => ({
    campaign: localStorage.getItem('growWithPip.jellyCampaign.v1'),
    wallet: localStorage.getItem('growWithPip.coinWallet.v1')
  }))).toEqual(saved);
  await capture(page, info, 'future-chapter-stays-locked');
  map = await waitForCampaignMap(page, { stage: 13 });
  expect(map.segment.index).toBe(2);
  expect(stage(map, 13)).toMatchObject({ unlocked: true, visible: true, in_segment: true });
  await pressMapControl(page, stage(map, 13));
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.campaign?.number === 13 && !state.campaign_map.visible;
  }, { timeout: 30000 }).toBe(true);
  expect(errors).toEqual([]);
});

test('Pip guides the actual frontier and tactile map feedback never changes stage hit areas or progress', async ({ page }, info) => {
  test.setTimeout(300000);
  await seedCampaign(page, { highestCleared: 24, balance: 3200 });
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference' });
  let map = await openMap(page);
  map = await waitForCampaignMap(page, { stage: 25 });
  expect(map.guide).toMatchObject({ visible: true, stage: 25, age: 0, course_id: '' });
  expect(map.presentation).toMatchObject({ completed_edges: 5, reduced_motion: false });
  const saved = await page.evaluate(() => ({
    campaign: localStorage.getItem('growWithPip.jellyCampaign.v1'),
    wallet: localStorage.getItem('growWithPip.coinWallet.v1')
  }));
  const geometry = map.stage_nodes.map(item => item.rect);
  const bounds = await metrics(page), replay = stage(map, 24).rect;
  const point = {
    x: bounds.x + (replay.x + replay.width / 2) * bounds.scale,
    y: bounds.y + (replay.y + replay.height / 2) * bounds.scale
  };
  await page.mouse.move(point.x, point.y);
  await expect.poll(async () => (await jelly(page)).campaign_map.presentation.hovered_stage).toBe(24);
  await expect.poll(async () => (await jelly(page)).campaign_map.presentation.hover_scale).toBeGreaterThan(1.02);
  map = (await jelly(page)).campaign_map;
  expect(map.stage_nodes.map(item => item.rect)).toEqual(geometry);
  await capture(page, info, 'map-feel-hover');
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).campaign_map.presentation.pressed_stage).toBe(24);
    await expect.poll(async () => (await jelly(page)).campaign_map.presentation.pressed_scale).toBeLessThan(1);
    await capture(page, info, 'map-feel-pressed');
    await page.mouse.move(point.x, point.y - 64 * bounds.scale, { steps: 8 });
    await expect.poll(async () => (await jelly(page)).campaign_map.presentation.pressed_stage).toBe(0);
  } finally {
    await page.mouse.up();
  }
  map = await waitForCampaignMap(page, { stage: 25 });
  expect(map.visible).toBe(true);
  await pressMapControl(page, map.chapter_next);
  await expect.poll(async () => (await jelly(page)).campaign_map.segment.index).toBe(4);
  map = (await jelly(page)).campaign_map;
  expect(map.guide.visible).toBe(false);
  expect(map.presentation).toMatchObject({ completed_edges: 0, hovered_stage: 0, pressed_stage: 0 });
  await capture(page, info, 'map-feel-future-chapter');
  await pressMapControl(page, map.chapter_previous);
  await expect.poll(async () => (await jelly(page)).campaign_map.guide.visible).toBe(true);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect.poll(async () => (await jelly(page)).campaign_map.presentation.reduced_motion).toBe(true);
  map = await waitForCampaignMap(page, { stage: 25 });
  expect(map.guide).toMatchObject({ visible: true, stage: 25 });
  await capture(page, info, 'map-feel-frontier-reduced');
  expect((await wallet(page)).balance).toBe(3200);
  expect(await page.evaluate(() => ({
    campaign: localStorage.getItem('growWithPip.jellyCampaign.v1'),
    wallet: localStorage.getItem('growWithPip.coinWallet.v1')
  }))).toEqual(saved);
  await pressMapControl(page, stage(map, 25));
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.campaign?.number === 25 &&
      state.campaign_map.visible === false;
  }, { timeout: 30000 }).toBe(true);
  expect((await jelly(page)).campaign_map).not.toHaveProperty('guide');
  expect(errors).toEqual([]);
});

test('campaign quotas clear, sweep leftovers, save stars and unlock the next stage', async ({ page }, info) => {
  test.setTimeout(240000);
  await seedCampaign(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await startStage(page);
  await observeFinish(page);
  const opening = await jelly(page);
  expect(opening.campaign.goals).toEqual({ cat: 1, dog: 1, duck: 1 });
  expect(opening.campaign.stars_now).toBe(3);
  expect(opening.powerup_buttons.extra_time.visible).toBe(true);
  await capture(page, info, 'campaign-stage-one');
  await pressRect(page, opening.finish.rect);
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(true);
  const paused = await jelly(page);
  expect(paused.pause_menu.visible).toBe(false);
  expect(paused.pause.shade_visible).toBe(true);
  expect(paused.finish.pull.label_text).toBe('Resume');
  await expect.poll(async () => (await jelly(page)).finish.pull.visual_pull,
    { message: 'The paused gel continues its gentle downward teaching tug' }).not.toBe(paused.finish.pull.visual_pull);
  const still = await jelly(page);
  expect(still.finish.rect).toEqual(paused.finish.rect);
  expect(still.campaign.seconds_remaining).toBe(paused.campaign.seconds_remaining);
  await capture(page, info, 'campaign-inline-pause');
  await pressRect(page, still.finish.rect);
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  const cat = await mergeWord(page, 'cat');
  const leftover = await mergeWord(page, 'cat');
  await collect(page, cat);
  await expect.poll(async () => (await jelly(page)).practice.words.find(word => word.id === 'cat')
    ?.completed_marker_visible).toBe(true);
  await capture(page, info, 'campaign-goal-done');
  await collect(page, await mergeWord(page, 'dog'));
  await collect(page, await mergeWord(page, 'duck'));
  await expect.poll(() => page.evaluate(() => Boolean(window.campaignFeedbackImages.stars &&
    window.campaignFeedbackImages.multiplier)), {
    timeout: 45000, intervals: [25],
    message: 'Capture both visible award phases in-page without screenshot latency skipping the short multiplier'
  }).toBe(true);
  const map = await waitForMap(page), finished = await jelly(page), room = await rewards(page);
  expect(finished.campaign.outcome).toBe('cleared');
  expect(finished.cleared_pairs).toBe(4);
  expect(finished.tiles.some(tile => tile.id === leftover.id)).toBe(false);
  expect(finished.campaign.current).toEqual({ cat: 1, dog: 1, duck: 1 });
  expect(stage(map, 1).best_stars).toBe(3);
  expect(stage(map, 2).unlocked).toBe(true);
  expect(stage(map, 3).unlocked).toBe(false);
  const quote = room.result_context.stage_bonus;
  expect(quote.factor).toBe(2);
  expect(quote.bonus).toBe((quote.chest_coins + 75) * 2 - quote.chest_coins);
  const coins = (await wallet(page)).balance;
  expect(coins).toBe(quote.total + finished.collected_coins + finished.combo.coins);
  const { frames, images } = await page.evaluate(() => {
    window.campaignFinishObserver.disconnect();
    return { frames: window.campaignFinishFrames, images: window.campaignFeedbackImages };
  });
  expect(images.stars, 'The earned-star effect has real rendered evidence during its visible phase').toBeTruthy();
  expect(images.multiplier, 'The multiplier glow and coin count-up have real rendered evidence before wallet flight').toBeTruthy();
  for (const [name, image] of Object.entries(images))
    fs.writeFileSync(info.outputPath(`settlement-${name}-effect.png`), Buffer.from(image, 'base64'));
  expect(frames.some(frame => frame.feedback.phase === 'stars')).toBe(true);
  expect(frames.some(frame => frame.feedback.phase === 'bonus')).toBe(true);
  expect(frames.some(frame => frame.feedback.formula?.includes('×2'))).toBe(true);
  const phases = frames.map(frame => frame.clear_phase);
  expect(phases).toEqual(expect.arrayContaining(['slowdown', 'announcement', 'collecting', 'done']));
  expect(phases.indexOf('slowdown')).toBeLessThan(phases.indexOf('announcement'));
  expect(phases.indexOf('announcement')).toBeLessThan(phases.indexOf('collecting'));
  expect(frames.filter(frame => frame.clear_phase === 'announcement').every(frame => !frame.batch)).toBe(true);
  expect(frames.some(frame => frame.ending), 'Clear is announced before the sweep, without a second late end overlay').toBe(false);
  for (const frame of frames.filter(frame => frame.ending)) {
    expect(frame.effects, 'Round complete cannot cover a remaining board effect').toBe(0);
    expect(frame.reveals, 'Round complete cannot cut off a reading-pop firework').toBe(0);
    expect(frame.collectable, 'Every merged word is collected before the end overlay').toBe(0);
    expect(frame.fusions, 'No accepted collection is still waiting to commit').toBe(0);
  }
  await capture(page, info, 'campaign-earned-stars-map');
  fs.writeFileSync(info.outputPath('campaign-clear.json'), JSON.stringify({ opening, finished, map, room, coins }, null, 2));
  await page.reload();
  await enterGame(page, { home: true });
  const restored = await openMap(page);
  expect(stage(restored, 1).best_stars).toBe(3);
  expect(stage(restored, 2).unlocked).toBe(true);
  expect((await wallet(page)).balance).toBe(coins);
  expect(errors).toEqual([]);
});

test('the map climbs upwards and Home confirms before collecting, settling and returning to the library', async ({ page }, info) => {
  test.setTimeout(240000);
  await seedCampaign(page, { quota: 2 });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  const map = await openMap(page);
  fs.writeFileSync(info.outputPath('map-entry-state.json'), JSON.stringify({ map, bounds: await metrics(page) }, null, 2));
  for (let number = 2; number <= 99; number++) {
    expect(stage(map, number).rect.y, 'Later stages are above earlier stages, including chapter boundaries')
      .toBeLessThan(stage(map, number - 1).rect.y);
  }
  expect(map.heading_rect.x, 'The real Home icon leaves room for the complete title')
    .toBeGreaterThanOrEqual(map.home.rect.x + map.home.rect.width);
  await capture(page, info, 'ascending-map-new-controls');
  await pressMapControl(page, stage(map, 1));
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.tiles.length === 15 && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  await mergeWord(page, 'cat');
  await mergeWord(page, 'dog');
  const before = await jelly(page);
  expect(before.collectable_ids.length).toBeGreaterThanOrEqual(2);
  const home = (await metrics(page)).growth.controls.find(control => control.name === 'Home' && control.visible);
  expect(home).toBeTruthy();
  await pressRect(page, home.rect);
  await expect.poll(async () => (await jelly(page)).finish_confirmation.visible).toBe(true);
  const paused = await jelly(page);
  expect(paused.campaign.outcome).toBe('');
  expect((await metrics(page)).library.visible).toBe(false);
  await capture(page, info, 'jelly-exit-confirmation');
  await pressRect(page, paused.finish_confirmation.keep_playing.rect);
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  expect((await jelly(page)).round_id).toBe(before.round_id);
  await observeFinish(page);
  await pressRect(page, home.rect);
  await expect.poll(async () => (await jelly(page)).finish_confirmation.visible).toBe(true);
  await pressRect(page, (await jelly(page)).finish_confirmation.confirm.rect);
  await expect.poll(async () => (await metrics(page)).library.visible, { timeout: 90000 }).toBe(true);
  const finished = await jelly(page);
  expect(finished.phase).toBe('finished');
  expect(finished.campaign.outcome).toBe('exit');
  expect(finished.cleared_pairs).toBeGreaterThanOrEqual(before.collectable_ids.length);
  const frames = await page.evaluate(() => {
    window.campaignFinishObserver.disconnect();
    return window.campaignFinishFrames;
  });
  expect(frames.some(frame => frame.effects > 0 || frame.reveals > 0)).toBe(true);
  expect(frames.some(frame => frame.ending)).toBe(true);
  for (const frame of frames.filter(frame => frame.ending)) {
    expect(frame.effects).toBe(0);
    expect(frame.reveals).toBe(0);
    expect(frame.collectable).toBe(0);
    expect(frame.fusions).toBe(0);
  }
  await activateLibraryControl(page, 'Mode_word_jelly');
  await expect.poll(async () => (await jelly(page)).campaign_map.visible).toBe(true);
  expect((await jelly(page)).visible).toBe(false);
  await capture(page, info, 'jelly-reentry-stage-map');
  expect(errors).toEqual([]);
});

test('extra time escalates without restoring stars and a paused pull finishes its sweep', async ({ page }, info) => {
  test.setTimeout(180000);
  await seedCampaign(page, { seconds: 12, quota: 2, balance: 750 });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await startStage(page);
  await expect.poll(async () => (await jelly(page)).campaign.stars_now).toBe(2);
  await capture(page, info, 'extra-time-before-purchase');
  for (const [index, price] of [100, 150].entries()) {
    const state = await jelly(page);
    expect(state.powerup_buttons.extra_time.price).toBe(price);
    await pressRect(page, state.powerup_buttons.extra_time.rect);
    await expect.poll(async () => (await jelly(page)).campaign.seconds_added).toBe((index + 1) * 30);
    if (state.stage.timer_ratio < 0.999) {
      await expect.poll(async () => (await jelly(page)).stage.timer_ratio,
        { message: 'Saved extra time visibly refills the remaining-time bar' }).toBeGreaterThan(state.stage.timer_ratio);
    } else {
      await expect.poll(async () => (await jelly(page)).stage.timer_ratio).toBe(1);
    }
    expect((await jelly(page)).campaign.stars_now).toBeLessThanOrEqual(state.campaign.stars_now);
    await capture(page, info, `extra-time-refilled-${index + 1}`);
  }
  expect((await wallet(page)).balance).toBe(500);
  const merged = await mergeWord(page, 'cat');
  await pressRect(page, (await jelly(page)).finish.rect);
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(true);
  const paused = await jelly(page), bounds = await metrics(page), from = center(paused.finish.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await page.mouse.move(from.x, from.y + paused.finish.pull.threshold * bounds.scale + 12, { steps: 12 });
    await expect.poll(async () => (await jelly(page)).finish.pull.armed).toBe(true);
  } finally {
    await page.mouse.up();
  }
  const map = await waitForMap(page), finished = await jelly(page);
  expect(finished.campaign.outcome).toBe('exit');
  expect(finished.cleared_pairs).toBe(1);
  expect(finished.tiles.some(tile => tile.id === merged.id)).toBe(false);
  expect(finished.campaign.current).toEqual({ cat: 0, dog: 0, duck: 0 });
  expect(stage(map, 1).best_stars).toBe(0);
  expect(stage(map, 2).unlocked).toBe(false);
  expect((await wallet(page)).balance).toBe(500);
  await capture(page, info, 'campaign-failed-stage-map');
  expect(errors).toEqual([]);
});

test('a timeout warns with the board border and cannot turn cleanup into goal credit or an unlock', async ({ page }, info) => {
  test.setTimeout(150000);
  await seedCampaign(page, { seconds: 20, quota: 2 });
  const errors = await openGame(page);
  await startStage(page);
  await mergeWord(page, 'cat');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.campaign.seconds_remaining <= 10 && state.danger.active && state.danger.source === 'stage';
  }, { timeout: 30000 }).toBe(true);
  await capture(page, info, 'stage-final-ten-second-border');
  const map = await waitForMap(page), finished = await jelly(page);
  expect(finished.campaign.outcome).toBe('timeout');
  expect(finished.cleared_pairs).toBe(1);
  expect(finished.campaign.stars).toBe(0);
  expect(finished.campaign.current).toEqual({ cat: 0, dog: 0, duck: 0 });
  expect(stage(map, 2).unlocked).toBe(false);
  expect((await rewards(page)).result_context.stage_bonus.bonus).toBe(0);
  expect(errors).toEqual([]);
});

test('Challenge completes a full goal stage, increases difficulty and restores its persisted best stage', async ({ page }, info) => {
  test.setTimeout(600000);
  await seedPipLevel(page, 3);
  await seedCampaign(page, { balance: 12000 });
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference' });
  const map = await openMap(page);
  await pressMapControl(page, map.challenge);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.campaign?.kind === 'challenge' && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  const opening = await jelly(page);
  expect(opening.campaign.seconds_total).toBe(90);
  expect(opening.campaign.challenge_stage).toBe(1);
  expect(opening.stage.challenge_best_stage).toBeGreaterThanOrEqual(1);
  expect(opening.campaign.pressure.word_limit).toBe(3);
  expect(opening.practice.words).toHaveLength(3);
  expect(opening.powerup_buttons.extra_time.visible).toBe(false);
  for (let batch = 0; batch < 10 && (await jelly(page)).campaign.challenge_stage < 2; batch++) {
    if (batch > 0) {
      for (let supply = 0; supply < 2; supply++) {
        const state = await jelly(page);
        await pressRect(page, state.preview.rect);
        await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
        await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
      }
    }
    await expect.poll(async () => (await jelly(page)).powerup_buttons.auto_merge.enabled).toBe(true);
    await pressRect(page, (await jelly(page)).powerup_buttons.auto_merge.rect);
    await expect.poll(async () => (await jelly(page)).powerup.active,
      { timeout: info.project.name.includes('webkit') ? 60000 : 20000 }).toBe(false).catch(async error => {
      fs.writeFileSync(info.outputPath('challenge-auto-failure.json'),
        JSON.stringify({ state: await jelly(page), errors }, null, 2));
      throw error;
    });
    await expect.poll(async () => (await jelly(page)).collectable_ids.length).toBeGreaterThan(0);
    const ready = await jelly(page), before = ready.cleared_pairs;
    await pressRect(page, ready.collect_button.rect);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBeGreaterThan(before);
    await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
    if (batch === 0) {
      const gained = await jelly(page);
      expect(gained.stage.time_bonus.visible).toBe(true);
      expect(gained.stage.time_bonus.seconds).toBeGreaterThan(0);
      expect(gained.stage.time_bonus.seconds).toBeLessThanOrEqual(gained.campaign.seconds_added);
      expect(gained.stage.time_bonus.text).toMatch(/^\+(?:\d+(?:\.\d)?|<0\.1)s$/);
      await capture(page, info, 'challenge-actual-time-gain');
    }
  }
  const after = await jelly(page);
  expect(after.campaign.challenge_stage).toBeGreaterThanOrEqual(2);
  expect(after.campaign.seconds_remaining).toBeGreaterThan(0);
  expect(after.campaign.seconds_remaining).toBeLessThanOrEqual(90);
  expect(after.campaign.seconds_added).toBeGreaterThan(0);
  expect(after.stage.challenge_best_stage).toBeGreaterThanOrEqual(2);
  expect(after.practice.record.value).toBe(after.stage.challenge_best_stage);
  expect(after.campaign.pressure.level).toBeGreaterThanOrEqual(2);
  expect(after.campaign.pressure.word_limit).toBeGreaterThan(3);
  expect(after.fall_speed_scale).toBeGreaterThan(opening.fall_speed_scale);
  expect(after.spawn_interval).toBeLessThan(opening.spawn_interval);
  expect(after.combo.count).toBeGreaterThan(0);
  expect(after.practice.words.length).toBeGreaterThan(3);
  const best = after.stage.challenge_best_stage;
  const saved = await page.evaluate(() => localStorage.getItem('growWithPip.jellyCampaign.v1'));
  expect(saved).toMatch(/version=3/);
  expect(saved).toMatch(new RegExp(`"challenge_best_stage":\\s*${best}\\b`));
  await capture(page, info, 'challenge-growing-pressure');
  fs.writeFileSync(info.outputPath('challenge-pressure.json'), JSON.stringify({ opening, after }, null, 2));
  await pullToFinish(page);
  await expect.poll(async () => (await rewards(page)).challenge_return_ready, { timeout: 60000 }).toBe(true);
  const result = await rewards(page);
  expect(result.result_context.challenge_result).toMatchObject({
    stage: after.campaign.challenge_stage, previous_best: 0, best, new_best: true, confirmed: true
  });
  expect(result.challenge_record.value).toBe(best);
  expect(result.summary_text).toContain(`Reached Stage ${after.campaign.challenge_stage}`);
  await page.waitForTimeout(3000);
  expect((await jelly(page)).campaign_map.visible).toBe(false);
  expect((await rewards(page)).visible).toBe(true);
  await capture(page, info, 'challenge-saved-record-summary');
  const back = (await rewards(page)).actions.find(action => action.text === 'Back to map' && action.visible);
  expect(back?.disabled).toBe(false);
  const retry = (await rewards(page)).actions.find(action => action.text === 'Try again' && action.visible);
  expect(retry?.disabled).toBe(false);
  expect(retry.rect[3] * (await metrics(page)).scale).toBeGreaterThanOrEqual(44);
  const settledBalance = (await wallet(page)).balance;
  await pressRect(page, retry.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.campaign?.kind === 'challenge' &&
      state.campaign.challenge_stage === 1 && state.campaign.collection_count === 0 &&
      state.tiles.length === 15 && state.tiles.every(tile => tile.settled);
  }, { timeout: 60000 }).toBe(true);
  expect((await jelly(page)).stage.challenge_best_stage).toBe(best);
  expect((await wallet(page)).balance).toBe(settledBalance);
  await capture(page, info, 'challenge-try-again-retains-best');
  await pullToFinish(page);
  await expect.poll(async () => (await rewards(page)).challenge_return_ready, { timeout: 60000 }).toBe(true);
  expect((await rewards(page)).result_context.challenge_result.new_best).toBe(false);
  const returnToMap = (await rewards(page)).actions.find(action => action.text === 'Back to map' && action.visible);
  await pressRect(page, returnToMap.rect);
  const settledMap = await waitForMap(page);
  expect(stage(settledMap, 2).unlocked).toBe(false);
  await page.reload();
  await enterGame(page, { home: true });
  const restoredMap = await openMap(page);
  await pressMapControl(page, restoredMap.challenge);
  await expect.poll(async () => (await jelly(page)).campaign?.kind).toBe('challenge');
  expect((await jelly(page)).campaign.challenge_stage).toBe(1);
  expect((await jelly(page)).stage.challenge_best_stage).toBe(best);
  expect(errors).toEqual([]);
});
