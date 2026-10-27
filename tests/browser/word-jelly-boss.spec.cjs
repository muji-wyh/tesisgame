const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, openModeMenu, activateLibraryControl, waitForCampaignMap, metrics, tap, seedPipLevel } = require('./game-ui.cjs');
const { recipe } = require('./jelly-campaign-fixture.cjs');

const bossStages = [3, 5, 7, 9, 18, 36, 63, 99];
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const room = page => page.locator('#jelly-reward-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
test.use({ trace: 'off' });

async function seed(page, number) {
  await seedPipLevel(page, 3);
  const recipes = {}, ratings = {};
  for (let stage = 1; stage <= number; stage++) {
    recipes[stage] = recipe({ number: stage, seconds: 360, quota: number === 1 ? 1 : 5 });
    if (stage < number) ratings[stage] = 3;
  }
  const victories = bossStages.map((stage, index) => stage < number ? index + 1 : null).filter(id => id !== null);
  await page.addInitScript(({ recipes, ratings, victories, number }) => {
    if (!localStorage.getItem('growWithPip.jellyCampaign.v1'))
      localStorage.setItem('growWithPip.jellyCampaign.v1', '[campaign]\nversion=2\ncontexts=' + JSON.stringify({
      growth: { highest_cleared: number - 1, recipes, ratings, boss_victories: victories, pending: {}, completed: [] }
    }) + '\n');
    if (!localStorage.getItem('growWithPip.coinWallet.v1')) localStorage.setItem('growWithPip.coinWallet.v1',
      '[wallet]\nversion=2\nbalance=20000\nreceipts={"boss-test-opening":20000}\n');
  }, { recipes, ratings, victories, number });
}

async function press(page, rect) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
}

async function start(page, number) {
  await seed(page, number);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  const map = await waitForCampaignMap(page);
  const node = map.stage_nodes.find(stage => stage.number === number);
  expect(node.boss).toBe(number !== 1);
  expect(map.boss_markers.filter(stage => stage > number)).toHaveLength(number === 1 ? 1 : 0);
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.bossActionFrames = {};
    window.bossActionObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const boss = state.boss || {}, view = state.boss_view || {};
      if (!boss.active || !view.visible) return;
      let key = '';
      const base = view.base_character_rect || [];
      if (view.clip === 'Kick' && view.character_rect[2] > base[2] * 1.35) key = 'giant-kick';
      if (view.clip === 'Snatch' && view.character_rect[0] < base[0] - 12) key = 'jump-snatch';
      if (boss.phase === 'ending' && boss.ending_elapsed > 1.7 && boss.ending_elapsed < 2.5)
        key = boss.outcome === 'ambushed' ? 'compass-theft' : 'victory-banter';
      if (boss.phase === 'ending' && boss.ending_elapsed > 5.2 && boss.ending_elapsed < 5.8) key = 'retreat';
      if (key && !window.bossActionFrames[key])
        window.bossActionFrames[key] = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
    });
    window.bossActionObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  await tap(page, node.rect.x + node.rect.width / 2, node.rect.y + node.rect.height / 2);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.boss.active && state.boss_view.visible === (number !== 1)
      && state.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true).catch(async error => {
    fs.writeFileSync(test.info().outputPath('boss-entry-state.json'), JSON.stringify({
      state: await jelly(page), errors
    }, null, 2));
    throw error;
  });
  expect((await jelly(page)).boss_view.error).toBe('');
  return errors;
}

async function retainAction(page, info, name) {
  await expect.poll(() => page.evaluate(name => Boolean(window.bossActionFrames[name]), name),
    { message: `The actual rendered ${name} phase is captured before browser-driver latency can skip it` }).toBe(true);
  const image = await page.evaluate(name => window.bossActionFrames[name], name);
  fs.writeFileSync(info.outputPath(`${name}.png`), Buffer.from(image, 'base64'));
}

async function shot(page) {
  await expect.poll(async () => (await jelly(page)).powerup_buttons.auto_merge.enabled).toBe(true);
  await press(page, (await jelly(page)).powerup_buttons.auto_merge.rect);
  await expect.poll(async () => !(await jelly(page)).powerup.active, { timeout: 30000 }).toBe(true);
  await expect.poll(async () => (await jelly(page)).collect_button.enabled).toBe(true);
  await press(page, (await jelly(page)).collect_button.rect);
  await expect.poll(async () => !(await jelly(page)).collection_batch.active, { timeout: 30000 }).toBe(true);
}

test('a real first Boss victory celebrates, escapes, saves Lv2 and never duplicates its unlock on reload', async ({ page }, info) => {
  test.setTimeout(300000);
  const errors = await start(page, 3);
  const opening = await jelly(page);
  expect(opening.max_merge_level).toBe(1);
  expect(opening.boss_view.animations).toEqual(expect.arrayContaining(['Idle', 'Throw', 'Kick', 'Snatch', 'Hit', 'Taunt', 'Escape']));
  await page.screenshot({ path: info.outputPath('boss-first-battle.png'), scale: 'css' });
  for (let round = 0; round < 3; round++) {
    const state = await jelly(page);
    if (state.boss.health === 0 || state.campaign_map.visible) break;
    if (round) {
      await press(page, state.preview.rect);
      await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    }
    await shot(page);
  }
  await expect.poll(async () => (await room(page)).skill_unlock?.visible, { timeout: 60000 }).toBe(true);
  const skill = (await room(page)).skill_unlock;
  expect(skill.level).toBe(2);
  expect(skill.description).toContain('4 nearby');
  expect(skill.preview_targets).toBe(4);
  await expect.poll(async () => (await room(page)).skill_unlock.continue.enabled).toBe(true);
  await page.screenshot({ path: info.outputPath('new-jelly-skill.png'), scale: 'css' });
  await press(page, (await room(page)).skill_unlock.continue.rect);
  await expect.poll(async () => (await jelly(page)).campaign_map.visible, { timeout: 30000 }).toBe(true);
  const finished = await jelly(page);
  expect(finished.boss.outcome).toBe('defeated');
  expect(finished.campaign.outcome).toBe('cleared');
  expect(finished.campaign_map.merged_level).toBe(2);
  expect(finished.campaign_map.boss_victories).toEqual([1]);
  expect(finished.campaign_map.boss_markers).toEqual([3, 5]);
  expect(finished.campaign_map.stage_nodes.find(stage => stage.number === 4).unlocked).toBe(true);
  await retainAction(page, info, 'victory-banter');
  await retainAction(page, info, 'retreat');
  await page.screenshot({ path: info.outputPath('boss-lv2-map.png'), scale: 'css' });
  const balance = (await wallet(page)).balance;
  fs.writeFileSync(info.outputPath('boss-clear.json'), JSON.stringify({ opening, finished, balance }, null, 2));
  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  const restored = await waitForCampaignMap(page);
  expect(restored.merged_level).toBe(2);
  expect(restored.boss_victories).toEqual([1]);
  expect((await wallet(page)).balance).toBe(balance);
  expect(errors).toEqual([]);
});

test('stage one ends in the compass theft without losing learning rewards or inventing a Boss unlock', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = await start(page, 1);
  expect((await jelly(page)).boss.definition.intro).toBe(true);
  expect((await jelly(page)).boss_view.visible).toBe(false);
  expect((await jelly(page)).max_merge_level).toBe(1);
  await shot(page);
  await expect.poll(async () => (await jelly(page)).campaign_map.visible, { timeout: 60000 }).toBe(true);
  const state = await jelly(page);
  expect(state.boss.outcome).toBe('ambushed');
  expect(state.campaign.outcome).toBe('cleared');
  expect(state.campaign_map.merged_level).toBe(1);
  expect(state.campaign_map.boss_victories).toEqual([]);
  expect(state.campaign_map.boss_markers).toEqual([3]);
  expect(state.campaign_map.stage_nodes.find(stage => stage.number === 2).unlocked).toBe(true);
  expect(state.cleared_pairs).toBeGreaterThanOrEqual(3);
  await retainAction(page, info, 'compass-theft');
  await page.screenshot({ path: info.outputPath('boss-chase-begins-map.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('the giant kick limits actual preview releases to two and repairs after eight active seconds', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await start(page, 18);
  await expect.poll(async () => (await jelly(page)).boss.broken_remaining).toBeGreaterThan(0);
  const before = await jelly(page);
  expect(before.boss.drop_limit).toBe(2);
  await page.screenshot({ path: info.outputPath('boss-damaged-sky.png'), scale: 'css' });
  await press(page, before.preview.rect);
  await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(before.generated_tiles);
  const after = await jelly(page);
  expect(after.generated_tiles - before.generated_tiles).toBeLessThanOrEqual(2);
  await expect.poll(async () => (await jelly(page)).boss.broken_remaining, {
    timeout: 60000, message: 'Repair follows eight active-play seconds, even under software-rendered WebKit'
  }).toBe(0);
  const repaired = await jelly(page);
  expect(repaired.boss.drop_limit).toBe(5);
  const kick = repaired.boss.events.find(event => event.kind === 'kick');
  const repair = repaired.boss.events.find(event => event.kind === 'sky_repaired');
  expect(repair.at - kick.at).toBeCloseTo(8, 4);
  await retainAction(page, info, 'giant-kick');
  expect(errors).toEqual([]);
});

test('the recurring rival jumps into the well and returns a snatched body with its original identity', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await start(page, 36);
  await expect.poll(async () => (await jelly(page)).boss.events.some(event => event.kind === 'snatch'),
    { timeout: 20000 }).toBe(true);
  const state = await jelly(page);
  const taken = state.boss.events.find(event => event.kind === 'snatch');
  expect(taken.tile.jelly_kind).not.toBe('merged');
  expect(state.boss_view.animations).toContain('Snatch');
  await page.screenshot({ path: info.outputPath('boss-snatch.png'), scale: 'css' });
  await expect.poll(async () => {
    const live = await jelly(page);
    return live.boss.events.some(event => event.kind === 'jelly_returned' && event.target === taken.target);
  }).toBe(true);
  await retainAction(page, info, 'jump-snatch');
  expect(errors).toEqual([]);
});

test('the fourth encounter creates two real shadow doubles that collected words disperse', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await start(page, 9);
  await expect.poll(async () => (await jelly(page)).boss.clones).toBe(2);
  await page.screenshot({ path: info.outputPath('boss-shadow-doubles.png'), scale: 'css' });
  await shot(page);
  await expect.poll(async () => (await jelly(page)).boss.clones).toBe(0);
  expect((await jelly(page)).boss.events.filter(event => event.kind === 'clone_hit')).toHaveLength(2);
  expect(errors).toEqual([]);
});

test('a real blue hit has a frozen countdown that pauses and then visibly thaws', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await start(page, 3);
  let target;
  await expect.poll(async () => {
    const state = await jelly(page);
    target = Object.entries(state.boss.statuses).find(([, status]) => status.freeze > 1.2)?.[0];
    return Boolean(target);
  }, { timeout: 20000, intervals: [25] }).toBe(true);
  await press(page, (await jelly(page)).finish.rect);
  await expect.poll(async () => (await jelly(page)).pause.active).toBe(true);
  const frozen = (await jelly(page)).boss.statuses[target].freeze;
  await page.screenshot({ path: info.outputPath('boss-frozen-countdown.png'), scale: 'css' });
  expect((await jelly(page)).boss.statuses[target].freeze).toBe(frozen);
  await press(page, (await jelly(page)).finish.rect);
  await expect.poll(async () => (await jelly(page)).boss.events.some(event =>
    event.kind === 'thaw' && event.target === Number(target)), { timeout: 10000 }).toBe(true);
  expect((await jelly(page)).boss.statuses[target].freeze).toBe(0);
  expect(errors).toEqual([]);
});

test('a real golden lock is removed by a matching drag without consuming either jelly', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await start(page, 7);
  let state, locked, partner;
  await expect.poll(async () => {
    state = await jelly(page);
    const entry = Object.entries(state.boss.statuses).find(([, status]) => status.locks > 0);
    locked = entry && state.tiles.find(tile => tile.id === Number(entry[0]) && tile.settled);
    if (!locked) return false;
    const id = locked.jelly_kind === 'picture' ? locked.image_word?.id : locked.word_candidate?.id;
    partner = state.tiles.find(tile => tile.id !== locked.id && tile.settled &&
      (locked.jelly_kind === 'picture' ? tile.word_candidate?.id === id : tile.image_word?.id === id));
    return Boolean(partner);
  }, { timeout: 20000, intervals: [25] }).toBe(true);
  await page.screenshot({ path: info.outputPath('boss-golden-lock.png'), scale: 'css' });
  state = await jelly(page);
  const before = state.boss.statuses[locked.id].locks;
  const count = state.merged_count;
  const bounds = await metrics(page);
  const center = rect => ({ x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale });
  const from = center(partner.rect), to = center(locked.rect);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move(from.x, from.y - 16);
  await page.mouse.move(to.x, to.y, { steps: 6 });
  await page.mouse.up();
  await expect.poll(async () => (await jelly(page)).boss.statuses[locked.id].locks).toBe(before - 1);
  const after = await jelly(page);
  expect(after.merged_count).toBe(count);
  expect(after.tiles.some(tile => tile.id === locked.id)).toBe(true);
  expect(after.tiles.some(tile => tile.id === partner.id)).toBe(true);
  expect(errors).toEqual([]);
});
