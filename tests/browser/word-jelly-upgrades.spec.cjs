const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, openModeMenu, activateLibraryControl, waitForCampaignMap, metrics, tap } = require('./game-ui.cjs');
const { recipe } = require('./jelly-campaign-fixture.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const shop = async page => (await jelly(page)).campaign_map?.upgrades;
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const press = (page, rect) => tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);

async function holdUntil(page, condition) {
  const state = await shop(page), bounds = await metrics(page), rect = state.buy.rect;
  await page.mouse.move(bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    bounds.y + (rect[1] + rect[3] / 2) * bounds.scale);
  await page.mouse.down();
  try {
    await expect.poll(async () => condition(await shop(page)),
      { timeout: 10000, intervals: [16, 16, 25, 25, 50] }).toBe(true);
    // Saving errors resize the footer. Releasing inside its current button
    // must still finish this gesture without activating the new Retry action.
    const releaseRect = (await shop(page)).buy.rect, releaseBounds = await metrics(page);
    await page.mouse.move(releaseBounds.x + (releaseRect[0] + releaseRect[2] / 2) * releaseBounds.scale,
      releaseBounds.y + (releaseRect[1] + releaseRect[3] / 2) * releaseBounds.scale);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => (await shop(page)).charging).toBe(false);
}

async function openUpgrades(page) {
  const map = await waitForCampaignMap(page);
  await tap(page, map.upgrades_entry.rect.x + map.upgrades_entry.rect.width / 2,
    map.upgrades_entry.rect.y + map.upgrades_entry.rect.height / 2);
  await expect.poll(async () => (await shop(page))?.visible).toBe(true);
  return shop(page);
}

test.use({ trace: 'off' });

test('a recovered first clear charges Lv2 with retained progress and a fresh paid-save retry', async ({ page }, info) => {
  test.setTimeout(240000);
  const first = recipe({ number: 1 });
  await page.addInitScript(first => {
    const campaign = 'growWithPip.jellyCampaign.v1';
    if (localStorage.getItem(campaign) === null) {
      localStorage.setItem(campaign, '[campaign]\nversion=3\ncontexts=' + JSON.stringify({
        growth: { highest_cleared: 0, recipes: { 1: first }, ratings: {}, completed: [],
          boss_victories: [], challenge_best_stage: 0,
          pending: { round_id: 'upgrade-first-clear-browser',
            result: { kind: 'main', number: 1, outcome: 'cleared', stars: 1, bonus: 75,
              chest_count: 0, chest_coins: 0, completed_word_ids: [] } } }
      }) + '\n');
    }
    if (localStorage.getItem('growWithPip.coinWallet.v1') === null)
      localStorage.setItem('growWithPip.coinWallet.v1', '[wallet]\nversion=3\nbalance=0\nreceipts={}\n');
  }, first);
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference' });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  await expect.poll(async () => (await shop(page))?.mode).toBe('offer');
  const introduction = await shop(page);
  expect(introduction.visible).toBe(true);
  expect(introduction.level).toBe(1);
  expect((await wallet(page)).balance, 'The chest-free first clear has already saved at least fifty coins').toBeGreaterThanOrEqual(50);
  expect(introduction.offer.caption).toContain(`${(await wallet(page)).balance} coins saved`);
  await page.screenshot({ path: info.outputPath('first-clear-upgrade-introduction.png'), scale: 'css' });
  await press(page, introduction.offer.primary);
  await expect.poll(async () => (await shop(page))?.mode).toBe('page');
  expect(await shop(page)).toMatchObject({ selected_level: 2, level: 1, intro: 'guide',
    buy: { guided: true, enabled: true } });
  const before = (await wallet(page)).balance;
  const counts = [2, 4, 6];
  for (let level = 1; level <= 3; level++) {
    const choice = (await shop(page)).levels.find(item => item.level === level);
    await press(page, choice.rect);
    await expect.poll(async () => (await shop(page)).selected_level).toBe(level);
    const state = await shop(page);
    expect(state.preview).toMatchObject({ level, columns: 7, rows: 8, target_count: counts[level - 1] });
    expect(state.level).toBe(1);
    expect((await wallet(page)).balance, 'Viewing any locked ability is free').toBe(before);
    expect(state.buy.enabled, 'Inspecting a future milestone keeps the next-level charge available').toBe(true);
  }
  await press(page, (await shop(page)).levels.find(item => item.level === 2).rect);
  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    window.jellyUpgradeWrites = { campaign: 0, wallet: 0 };
    Storage.prototype.setItem = function(key, value) {
      if (key === 'growWithPip.jellyCampaign.v1') {
        window.jellyUpgradeWrites.campaign++;
        if (window.jellyUpgradeWrites.campaign === 2)
          throw new DOMException('Expected one final-upgrade save failure', 'QuotaExceededError');
      }
      if (key === 'growWithPip.coinWallet.v1') window.jellyUpgradeWrites.wallet++;
      return original.call(this, key, value);
    };
  });
  await holdUntil(page, state => Boolean(state.error));
  await page.waitForTimeout(500);
  const paid = await shop(page);
  expect(paid.error, 'Releasing the failed charge cannot also activate the newly shown Retry action').not.toBe('');
  expect(paid.level, 'A failed final save cannot pretend ownership increased').toBe(1);
  expect(paid.pending).toMatchObject({ kind: 'jelly', level: 2, price: 50, mode: 'contribution',
    amount: 25, id: 'jelly-charge-v1:jelly:2:0:25' });
  expect(paid.funded).toBe(0);
  expect((await wallet(page)).balance).toBe(before - 25);
  expect(paid.buy.enabled).toBe(true);
  await page.screenshot({ path: info.outputPath('paid-upgrade-safe-retry.png'), scale: 'css' });
  await press(page, paid.buy.rect);
  await expect.poll(async () => (await shop(page)).funded).toBe(25);
  const partial = await shop(page);
  expect(partial).toMatchObject({ level: 1, funded: 25, remaining: 25, progress: 0.5,
    intro: 'guide', error: '', pending: {}, level_up_count: 0 });
  expect((await wallet(page)).balance).toBe(before - 25);
  expect(await page.evaluate(() => window.jellyUpgradeWrites.wallet)).toBe(1);

  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  expect(await openUpgrades(page)).toMatchObject({ level: 1, funded: 25, remaining: 25, progress: 0.5 });
  expect((await wallet(page)).balance, 'Saved partial progress survives reload without another debit').toBe(before - 25);
  await holdUntil(page, state => state.level === 2);
  await page.waitForTimeout(700);
  const saved = await shop(page);
  expect(saved).toMatchObject({ level: 2, funded: 0, intro: 'complete', error: '', pending: {},
    level_up_count: 1, buy: { guided: false, enabled: before - 50 >= 25 } });
  expect((await wallet(page)).balance, 'Release prevents any charge toward Lv3').toBe(before - 50);
  await page.screenshot({ path: info.outputPath('lv2-paid-and-owned.png'), scale: 'css' });
  fs.writeFileSync(info.outputPath('jelly-upgrade-journey.json'), JSON.stringify({ introduction, paid, partial, saved, before }, null, 2));
  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  const restored = await waitForCampaignMap(page);
  expect(restored.merged_level).toBe(2);
  expect(restored.upgrades.visible).toBe(false);
  expect((await wallet(page)).balance).toBe(before - 50);
  expect(await openUpgrades(page)).toMatchObject({ level: 2, funded: 0, level_up_count: 0 });
  expect(errors).toEqual([]);
});

test('Auto merge charging migrates independently and recovers its own paid progress and gameplay capacity', async ({ page }, info) => {
  test.setTimeout(300000);
  const first = recipe({ number: 1 });
  await page.addInitScript(first => {
    const campaign = 'growWithPip.jellyCampaign.v1';
    if (localStorage.getItem(campaign) === null)
      localStorage.setItem(campaign, '[campaign]\nversion=4\ncontexts=' + JSON.stringify({
        growth: { highest_cleared: 1, recipes: { 1: first }, ratings: { 1: 1 }, completed: [],
          boss_victories: [], challenge_best_stage: 0, pending: {} }
      }) + '\nupgrades=' + JSON.stringify({ level: 2, intro: 'complete', pending: {} }) + '\n');
    if (localStorage.getItem('growWithPip.coinWallet.v1') === null)
      localStorage.setItem('growWithPip.coinWallet.v1',
        '[wallet]\nversion=3\nbalance=2000\nreceipts={"browser-opening-coins":2000}\n');
  }, first);
  const errors = await openGame(page, { home: true, reducedMotion: 'no-preference' });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  let map = await waitForCampaignMap(page);
  expect(map).toMatchObject({ merged_level: 2, auto_merge_level: 1 });
  await tap(page, map.upgrades_entry.rect.x + map.upgrades_entry.rect.width / 2,
    map.upgrades_entry.rect.y + map.upgrades_entry.rect.height / 2);
  await expect.poll(async () => (await shop(page))?.visible).toBe(true);
  await press(page, (await shop(page)).categories.find(item => item.kind === 'auto_merge').rect);
  await expect.poll(async () => (await shop(page)).kind).toBe('auto_merge');
  expect(await shop(page)).toMatchObject({ owned_level: 1, level: 2, auto_merge_level: 1 });
  for (let level = 1; level <= 3; level++) {
    await press(page, (await shop(page)).levels.find(item => item.level === level).rect);
    await expect.poll(async () => (await shop(page)).selected_level).toBe(level);
    expect((await shop(page)).preview).toMatchObject({ kind: 'auto_merge', level, capacity: level + 2 });
    expect((await wallet(page)).balance).toBe(2000);
  }
  await press(page, (await shop(page)).levels.find(item => item.level === 2).rect);
  await page.screenshot({ path: info.outputPath('auto-merge-lv2-preview.png'), scale: 'css' });
  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    window.autoMergeUpgradeWrites = { campaign: 0, wallet: 0 };
    Storage.prototype.setItem = function(key, value) {
      if (key === 'growWithPip.jellyCampaign.v1' && ++window.autoMergeUpgradeWrites.campaign === 2)
        throw new DOMException('Expected one Auto merge final-save failure', 'QuotaExceededError');
      if (key === 'growWithPip.coinWallet.v1') window.autoMergeUpgradeWrites.wallet++;
      return original.call(this, key, value);
    };
  });
  await holdUntil(page, state => Boolean(state.error));
  await page.waitForTimeout(500);
  const pending = await shop(page);
  expect(pending.error, 'The failed held gesture must finish before Retry can be activated').not.toBe('');
  expect(pending).toMatchObject({ owned_level: 1, auto_merge_level: 1, level: 2,
    pending: { kind: 'auto_merge', level: 2, price: 50, mode: 'contribution', amount: 25,
      id: 'jelly-charge-v1:auto_merge:2:0:25' } });
  expect((await wallet(page)).balance).toBe(1975);
  await press(page, pending.categories.find(item => item.kind === 'jelly').rect);
  await press(page, (await shop(page)).levels.find(item => item.level === 3).rect);
  await press(page, (await shop(page)).buy.rect);
  await expect.poll(async () => (await shop(page)).funding.auto_merge).toBe(25);
  const partial = await shop(page);
  expect(partial).toMatchObject({ kind: 'auto_merge', level: 2, auto_merge_level: 1,
    funded: 25, remaining: 25, funding: { jelly: 0, auto_merge: 25 }, error: '', pending: {} });
  expect((await wallet(page)).balance).toBe(1975);
  expect(await page.evaluate(() => window.autoMergeUpgradeWrites.wallet)).toBe(1);

  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  await openUpgrades(page);
  await press(page, (await shop(page)).categories.find(item => item.kind === 'auto_merge').rect);
  expect(await shop(page)).toMatchObject({ level: 2, auto_merge_level: 1, funded: 25,
    funding: { jelly: 0, auto_merge: 25 } });
  expect((await wallet(page)).balance).toBe(1975);
  await holdUntil(page, state => state.auto_merge_level === 2);
  await page.waitForTimeout(700);
  const owned = await shop(page);
  expect(owned).toMatchObject({ owned_level: 2, auto_merge_level: 2, level: 2,
    funded: 0, preview: { capacity: 4 }, level_up_count: 1, buy: { enabled: true } });
  expect((await wallet(page)).balance, 'Release prevents the next capacity level from consuming any coins').toBe(1950);
  await page.screenshot({ path: info.outputPath('auto-merge-lv2-owned.png'), scale: 'css' });
  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  map = await waitForCampaignMap(page, { stage: 2 });
  expect(map).toMatchObject({ merged_level: 2, auto_merge_level: 2 });
  const stage = map.stage_nodes.find(item => item.number === 2);
  await tap(page, stage.rect.x + stage.rect.width / 2, stage.rect.y + stage.rect.height / 2);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.auto_merge_level === 2 &&
      state.powerup_buttons.auto_merge.enabled;
  }, { timeout: 45000 }).toBe(true);
  const before = await jelly(page);
  expect(before.powerup_buttons.auto_merge).toMatchObject({ auto_merge_level: 2, capacity: 4,
    capacity_badge: { visible: true, text: '4' } });
  await press(page, before.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(1350);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active;
  }, { timeout: 30000 }).toBe(true);
  const used = await jelly(page);
  expect(used.powerup.capacity).toBe(4);
  expect(used.powerup.completed_results).toBe(4);
  expect(used.powerup.result_ids).toHaveLength(4);
  expect(used.powerup.affected_jellies).toBe(8);
  expect(used.powerup_buttons.auto_merge.capacity_badge.text).toBe('4');
  await page.screenshot({ path: info.outputPath('auto-merge-lv2-gameplay.png'), scale: 'css' });
  fs.writeFileSync(info.outputPath('auto-merge-upgrade-journey.json'), JSON.stringify({ pending, partial, owned, used }, null, 2));
  expect(errors).toEqual([]);
});
