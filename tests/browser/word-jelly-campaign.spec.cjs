const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, openModeMenu, activateLibraryControl, metrics, tap, seedPipLevel } = require('./game-ui.cjs');
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

async function openMap(page) {
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  await expect.poll(async () => (await jelly(page)).campaign_map?.visible).toBe(true);
  return (await jelly(page)).campaign_map;
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
  await page.screenshot({ path: info.outputPath(`${name}.png`) });
}

test('campaign quotas clear, sweep leftovers, save stars and unlock the next stage', async ({ page }, info) => {
  test.setTimeout(240000);
  await seedCampaign(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await startStage(page);
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

test('extra time escalates without restoring stars and a paused pull finishes its sweep', async ({ page }, info) => {
  test.setTimeout(180000);
  await seedCampaign(page, { seconds: 12, quota: 2, balance: 750 });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await startStage(page);
  await expect.poll(async () => (await jelly(page)).campaign.stars_now).toBe(2);
  for (const [index, price] of [100, 150].entries()) {
    const state = await jelly(page);
    expect(state.powerup_buttons.extra_time.price).toBe(price);
    await pressRect(page, state.powerup_buttons.extra_time.rect);
    await expect.poll(async () => (await jelly(page)).campaign.seconds_added).toBe((index + 1) * 30);
    expect((await jelly(page)).campaign.stars_now).toBeLessThanOrEqual(2);
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

test('a timeout cannot turn its cleanup pickup into goal credit or an unlock', async ({ page }) => {
  test.setTimeout(150000);
  await seedCampaign(page, { seconds: 20, quota: 2 });
  const errors = await openGame(page);
  await startStage(page);
  await mergeWord(page, 'cat');
  const map = await waitForMap(page), finished = await jelly(page);
  expect(finished.campaign.outcome).toBe('timeout');
  expect(finished.cleared_pairs).toBe(1);
  expect(finished.campaign.stars).toBe(0);
  expect(finished.campaign.current).toEqual({ cat: 0, dog: 0, duck: 0 });
  expect(stage(map, 2).unlocked).toBe(false);
  expect((await rewards(page)).result_context.stage_bonus.bonus).toBe(0);
  expect(errors).toEqual([]);
});

test('untimed challenge credits real Auto Collect and increases variety and incoming speed', async ({ page }, info) => {
  test.setTimeout(360000);
  await seedPipLevel(page, 3);
  await seedCampaign(page, { balance: 12000 });
  const errors = await openGame(page);
  const map = await openMap(page);
  await pressMapControl(page, map.challenge);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.campaign?.kind === 'challenge' && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  const opening = await jelly(page);
  expect(opening.campaign.seconds_total).toBe(0);
  expect(opening.campaign.pressure.word_limit).toBe(3);
  expect(opening.practice.words).toHaveLength(3);
  expect(opening.powerup_buttons.extra_time.visible).toBe(false);
  for (let batch = 0; batch < 10 && (await jelly(page)).cleared_pairs < 10; batch++) {
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
    await expect.poll(async () => (await jelly(page)).powerup.active, { timeout: 20000 }).toBe(false);
    await expect.poll(async () => (await jelly(page)).collectable_ids.length).toBeGreaterThan(0);
    const ready = await jelly(page), before = ready.cleared_pairs;
    await pressRect(page, ready.collect_button.rect);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBeGreaterThan(before);
    await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
  }
  const after = await jelly(page);
  expect(after.cleared_pairs).toBeGreaterThanOrEqual(10);
  expect(after.campaign.pressure.level).toBeGreaterThanOrEqual(2);
  expect(after.campaign.pressure.word_limit).toBeGreaterThan(3);
  expect(after.fall_speed_scale).toBeGreaterThan(opening.fall_speed_scale);
  expect(after.spawn_interval).toBeLessThan(opening.spawn_interval);
  expect(after.combo.count).toBeGreaterThan(0);
  expect(after.practice.words.length).toBeGreaterThan(3);
  const saved = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
  expect(saved).toMatch(/word_jelly:/);
  await capture(page, info, 'challenge-growing-pressure');
  fs.writeFileSync(info.outputPath('challenge-pressure.json'), JSON.stringify({ opening, after }, null, 2));
  expect(errors).toEqual([]);
});
