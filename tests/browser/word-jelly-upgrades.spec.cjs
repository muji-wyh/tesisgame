const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, openModeMenu, activateLibraryControl, waitForCampaignMap, tap } = require('./game-ui.cjs');
const { recipe } = require('./jelly-campaign-fixture.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const shop = async page => (await jelly(page)).campaign_map?.upgrades;
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const press = (page, rect) => tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);

test.use({ trace: 'off' });

test('a recovered first clear funds the Lv2 FRE and a paid final-save retry never charges twice', async ({ page }, info) => {
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
  expect(introduction.offer.caption).toContain('50 coins');
  await page.screenshot({ path: info.outputPath('first-clear-upgrade-introduction.png'), scale: 'css' });
  await press(page, introduction.offer.primary);
  await expect.poll(async () => (await shop(page))?.mode).toBe('page');
  expect(await shop(page)).toMatchObject({ selected_level: 2, level: 1, intro: 'guide',
    buy: { guided: true, enabled: true } });
  const before = (await wallet(page)).balance;
  const counts = [2, 4, 6, 8, 7, 13, 12, 22, 55];
  for (let level = 1; level <= 9; level++) {
    const choice = (await shop(page)).levels.find(item => item.level === level);
    await press(page, choice.rect);
    await expect.poll(async () => (await shop(page)).selected_level).toBe(level);
    const state = await shop(page);
    expect(state.preview).toMatchObject({ level, columns: 7, rows: 8, target_count: counts[level - 1] });
    expect(state.level).toBe(1);
    expect((await wallet(page)).balance, 'Viewing any locked ability is free').toBe(before);
    expect(state.buy.enabled).toBe(level === 2);
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
  await press(page, (await shop(page)).buy.rect);
  await expect.poll(async () => (await shop(page)).error).not.toBe('');
  const paid = await shop(page);
  expect(paid.level, 'A failed final save cannot pretend ownership increased').toBe(1);
  expect(paid.pending).toMatchObject({ level: 2, price: 50, id: 'jelly-level-v1:2' });
  expect((await wallet(page)).balance).toBe(before - 50);
  expect(paid.buy.enabled).toBe(true);
  await page.screenshot({ path: info.outputPath('paid-upgrade-safe-retry.png'), scale: 'css' });
  await press(page, paid.buy.rect);
  await expect.poll(async () => (await shop(page)).level).toBe(2);
  const saved = await shop(page);
  expect(saved).toMatchObject({ intro: 'complete', error: '', buy: { guided: false, enabled: false } });
  expect(saved.pending).toEqual({});
  expect((await wallet(page)).balance).toBe(before - 50);
  expect(await page.evaluate(() => window.jellyUpgradeWrites.wallet)).toBe(1);
  await page.screenshot({ path: info.outputPath('lv2-paid-and-owned.png'), scale: 'css' });
  fs.writeFileSync(info.outputPath('jelly-upgrade-journey.json'), JSON.stringify({ introduction, paid, saved, before }, null, 2));
  await page.reload();
  await enterGame(page, { home: true });
  await openModeMenu(page);
  await activateLibraryControl(page, 'Mode_word_jelly');
  const restored = await waitForCampaignMap(page);
  expect(restored.merged_level).toBe(2);
  expect(restored.upgrades.visible).toBe(false);
  expect((await wallet(page)).balance).toBe(before - 50);
  await tap(page, restored.upgrades_entry.rect.x + restored.upgrades_entry.rect.width / 2,
    restored.upgrades_entry.rect.y + restored.upgrades_entry.rect.height / 2);
  await expect.poll(async () => (await shop(page))?.visible).toBe(true);
  expect((await shop(page)).level).toBe(2);
  expect(errors).toEqual([]);
});

test('Auto merge upgrades migrate independently, recover one debit and persist the truthful gameplay capacity', async ({ page }, info) => {
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
  for (let level = 1; level <= 9; level++) {
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
  await press(page, (await shop(page)).buy.rect);
  await expect.poll(async () => (await shop(page)).error).not.toBe('');
  const pending = await shop(page);
  expect(pending).toMatchObject({ owned_level: 1, auto_merge_level: 1, level: 2,
    pending: { kind: 'auto_merge', level: 2, price: 50, id: 'auto-merge-level-v1:2' } });
  expect((await wallet(page)).balance).toBe(1950);
  await press(page, pending.categories.find(item => item.kind === 'jelly').rect);
  await press(page, (await shop(page)).levels.find(item => item.level === 9).rect);
  await press(page, (await shop(page)).buy.rect);
  await expect.poll(async () => (await shop(page)).auto_merge_level).toBe(2);
  expect((await shop(page)).level).toBe(2);
  expect((await shop(page)).pending).toEqual({});
  expect((await wallet(page)).balance).toBe(1950);
  expect(await page.evaluate(() => window.autoMergeUpgradeWrites.wallet)).toBe(1);
  await press(page, (await shop(page)).categories.find(item => item.kind === 'auto_merge').rect);
  await press(page, (await shop(page)).levels.find(item => item.level === 2).rect);
  const owned = await shop(page);
  expect(owned).toMatchObject({ owned_level: 2, auto_merge_level: 2, level: 2,
    preview: { capacity: 4 }, buy: { enabled: false } });
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
  fs.writeFileSync(info.outputPath('auto-merge-upgrade-journey.json'), JSON.stringify({ pending, owned, used }, null, 2));
  expect(errors).toEqual([]);
});
