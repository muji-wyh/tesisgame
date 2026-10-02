const { test, expect } = require('@playwright/test');
const { enterGame, openRewards, rendered, metrics,
  leaderboardSnapshot: snapshot, leaderboardControl: control,
  activateLeaderboardControl: activate } = require('./game-ui.cjs');

const STORAGE_KEY = 'wordBuddies.leaderboards';
const PROFILES = [
  { id: 'player-a', name: 'Avery', avatar: 'fox' },
  { id: 'player-b', name: 'Blake', avatar: 'duck' }
];
const BESTS = {
  pop: { 'player-a': { hits: 9 }, 'player-b': { hits: 3 } },
  match: { 'player-a': { won: true, mistakes: 1, hints_used: 0 }, 'player-b': { won: true, mistakes: 4, hints_used: 2 } },
  memory: { 'player-a': { won: true, attempts: 6, peeks: 1 }, 'player-b': { won: true, attempts: 8, peeks: 2 } }
};
const RECEIPTS = [
  { id: 'round-a-pop', mode: 'pop', player_id: 'player-a' },
  { id: 'round-a-match', mode: 'match', player_id: 'player-a' },
  { id: 'round-a-memory', mode: 'memory', player_id: 'player-a' },
  { id: 'round-b-pop', mode: 'pop', player_id: 'player-b' }
];
const PLAYER_FIXTURE = `[leaderboard]\nversion=1\nprofiles=${JSON.stringify(PROFILES)}\n` +
  `bests=${JSON.stringify(BESTS)}\nreceipts=${JSON.stringify(RECEIPTS)}\n`;
const SHARED_KEYS = ['wordBuddies.medalProgress', 'wordBuddies.playroom',
  'wordBuddies.favoriteReward', 'wordBuddies.talkQuest'];

async function installFixtures(page) {
  await page.addInitScript(({ key, seed }) => {
    if (localStorage.getItem(key) === null) {
      localStorage.setItem(key, seed);
      localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1":3,"ocean-1":1}\n');
      localStorage.setItem('wordBuddies.talkQuest', JSON.stringify({
        version: 1, completion_counts: [1, ...Array(13).fill(0)], run: {}
      }));
    }
    window.__denyPlayerManagementSave = false;
    const setItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (name === key && window.__denyPlayerManagementSave) {
        throw new DOMException('Simulated full player storage', 'QuotaExceededError');
      }
      return setItem.call(this, name, value);
    };
  }, { key: STORAGE_KEY, seed: PLAYER_FIXTURE });
}

function observeErrors(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  return errors;
}

async function storedPlayers(page) {
  return page.evaluate(key => localStorage.getItem(key), STORAGE_KEY);
}

async function sharedProgress(page) {
  return page.evaluate(keys => keys.map(key => [key, localStorage.getItem(key)]), SHARED_KEYS);
}

function progressAfterNewLesson(records) {
  // Reload starts a fresh Match lesson and records its topic. That history can
  // grow independently of profile management; every other saved field must stay.
  return records.map(([key, value]) => [key, key === 'wordBuddies.playroom' && value !== null
    ? value.replace(/^recent_topic_ids=.*(?:\r?\n|$)/m, '') : value]);
}

async function openPlayers(page) {
  await openRewards(page);
  await activate(page, 'MenuPlayers');
  await expect.poll(async () => (await snapshot(page)).view).toBe('players');
}

async function replaceName(page, value, { expectNativeEditor = false } = {}) {
  const scaleBefore = await page.evaluate(() => window.visualViewport?.scale ?? 1);
  await activate(page, 'LeaderboardName');
  const editor = page.locator('input:focus, textarea:focus');
  if (expectNativeEditor) await expect(editor, 'A touch opens the native editor when modifying a player').toHaveCount(1);
  if (await editor.count()) {
    await expect(editor).toBeEditable();
    expect(await editor.evaluate(element => parseFloat(getComputedStyle(element).fontSize)),
      'Editing an existing player keeps the 16 CSS-pixel anti-zoom font').toBeGreaterThanOrEqual(16);
    await expect.poll(() => page.evaluate(() => window.visualViewport?.scale ?? 1),
      { message: 'Editing a player name preserves mobile page zoom' }).toBeCloseTo(scaleBefore, 3);
    await editor.fill(value);
  } else {
    await page.locator('#canvas').press('ControlOrMeta+A');
    await page.locator('#canvas').pressSequentially(value);
  }
  await rendered(page);
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(value);
}

async function expectKeyboardDismissed(page) {
  await expect(page.locator('input:focus, textarea:focus'), 'Leaving the editor releases native keyboard focus').toHaveCount(0);
}

async function expectProfiles(page, profiles) {
  await expect.poll(async () => (await snapshot(page)).profiles).toEqual(profiles);
}

async function expectBoards(page, profiles) {
  await activate(page, 'LeaderboardClose');
  await activate(page, 'MenuLeaderboards');
  for (const mode of ['pop', 'match', 'memory']) {
    await activate(page, `LeaderboardMode_${mode}`);
    await expect.poll(async () => (await snapshot(page)).mode).toBe(mode);
    const rows = (await snapshot(page)).rows;
    expect(rows.map(row => row.player_id)).toEqual(profiles.map(profile => profile.id));
    for (const profile of profiles) {
      expect(rows.find(row => row.player_id === profile.id)).toMatchObject({
        player_id: profile.id, name: profile.name, avatar: profile.avatar, result: BESTS[mode][profile.id]
      });
    }
  }
}

async function expectNarrowControls(page) {
  const bounds = await metrics(page);
  for (const item of (await snapshot(page)).controls) {
    const [x, , width, height] = item.rect;
    expect([x, width, height].every(Number.isFinite), `${item.name} has finite geometry`).toBe(true);
    expect(x, `${item.name} fits the left edge`).toBeGreaterThanOrEqual(-1);
    expect(x + width, `${item.name} fits the right edge`).toBeLessThanOrEqual(bounds.width + 1);
  }
}

test('editing a local player preserves identity and scores, cancels drafts and survives a save retry and reload', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = observeErrors(page);
  await installFixtures(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page);
  await openPlayers(page);
  await expectProfiles(page, PROFILES);
  const shared = await sharedProgress(page);
  const original = await storedPlayers(page);

  await activate(page, 'LeaderboardEdit_player-a');
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('player-a');
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe('Avery');
  await activate(page, 'LeaderboardAvatar_unicorn');
  await replaceName(page, 'Unsaved name', { expectNativeEditor: info.project.name.includes('iphone') });
  await activate(page, 'LeaderboardCancelEdit');
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('');
  await expectKeyboardDismissed(page);
  await expectProfiles(page, PROFILES);
  expect(await storedPlayers(page), 'Cancel discards the draft name and avatar without rewriting storage').toBe(original);

  await activate(page, 'LeaderboardEdit_player-a');
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('player-a');
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe('Avery');
  await activate(page, 'LeaderboardAvatar_frog');
  await replaceName(page, 'Avery Moon', { expectNativeEditor: info.project.name.includes('iphone') });
  await page.screenshot({ path: info.outputPath('edit-player-name-and-avatar.png') });
  await page.evaluate(() => { window.__denyPlayerManagementSave = true; });
  await activate(page, 'LeaderboardSavePlayer');
  await expect.poll(async () => (await snapshot(page)).error || '').not.toBe('');
  await expectProfiles(page, PROFILES);
  expect((await snapshot(page)).editing_player, 'A save failure keeps the existing identity selected for retry').toBe('player-a');
  expect(await storedPlayers(page), 'A failed edit preserves the original durable profile and scores').toBe(original);
  expect((await control(page, 'LeaderboardName')).text, 'A failed save keeps the edited draft for retry').toBe('Avery Moon');
  await page.evaluate(() => { window.__denyPlayerManagementSave = false; });
  await activate(page, 'LeaderboardSavePlayer');
  const updated = [{ ...PROFILES[0], name: 'Avery Moon', avatar: 'frog' }, PROFILES[1]];
  await expectProfiles(page, updated);
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('');
  await expectKeyboardDismissed(page);
  await expectNarrowControls(page);
  await page.screenshot({ path: info.outputPath('modified-local-player.png') });
  expect(await sharedProgress(page), 'Profile editing preserves shared medals, toys and Talk Quest progress').toEqual(shared);

  await page.reload();
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await openPlayers(page);
  await expectProfiles(page, updated);
  await expectBoards(page, updated);
  for (const receipt of RECEIPTS) expect(await storedPlayers(page)).toContain(receipt.id);
  expect(progressAfterNewLesson(await sharedProgress(page))).toEqual(progressAfterNewLesson(shared));
  expect(errors).toEqual([]);
});

test('removing players requires confirmation, retries a failed save and returns the last deletion to onboarding', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = observeErrors(page);
  await installFixtures(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page);
  await openPlayers(page);
  const shared = await sharedProgress(page);
  const original = await storedPlayers(page);

  await activate(page, 'LeaderboardRemove_player-a');
  await expect.poll(async () => (await snapshot(page)).removing_player).toBe('player-a');
  await control(page, 'LeaderboardConfirmRemove');
  await expectProfiles(page, PROFILES);
  expect(await storedPlayers(page), 'Opening confirmation cannot remove the profile').toBe(original);
  await expectNarrowControls(page);
  await page.screenshot({ path: info.outputPath('remove-player-confirmation.png') });
  await activate(page, 'LeaderboardCancelRemove');
  await expect.poll(async () => (await snapshot(page)).removing_player).toBe('');
  await expectProfiles(page, PROFILES);
  expect(await storedPlayers(page), 'Cancel keeps both players and their scores').toBe(original);

  await activate(page, 'LeaderboardRemove_player-a');
  await expect.poll(async () => (await snapshot(page)).removing_player).toBe('player-a');
  await page.evaluate(() => { window.__denyPlayerManagementSave = true; });
  await activate(page, 'LeaderboardConfirmRemove');
  await expect.poll(async () => (await snapshot(page)).error || '').not.toBe('');
  await expectProfiles(page, PROFILES);
  expect((await snapshot(page)).removing_player, 'A save failure keeps the removal confirmation available for retry').toBe('player-a');
  expect(await storedPlayers(page), 'A failed removal leaves the saved players and records intact').toBe(original);
  await page.evaluate(() => { window.__denyPlayerManagementSave = false; });
  await activate(page, 'LeaderboardConfirmRemove');
  await expectProfiles(page, [PROFILES[1]]);
  await expect.poll(async () => (await snapshot(page)).removing_player).toBe('');
  expect(await storedPlayers(page), 'Deleted profile IDs cannot remain in scores or round receipts').not.toContain('player-a');
  expect(await storedPlayers(page)).toContain('round-b-pop');
  await expectBoards(page, [PROFILES[1]]);
  await activate(page, 'LeaderboardClose');
  await activate(page, 'MenuPlayers');
  expect(await sharedProgress(page), 'Removing one player preserves shared game progression').toEqual(shared);

  await activate(page, 'LeaderboardRemove_player-b');
  await activate(page, 'LeaderboardConfirmRemove');
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  await expectProfiles(page, []);
  expect((await snapshot(page)).controls.some(item => item.name === 'LeaderboardClose'),
    'Deleting the last player reopens the required onboarding gate').toBe(false);
  await page.keyboard.press('Escape');
  await rendered(page);
  expect((await snapshot(page)).view, 'The final deletion cannot leave the game without a player').toBe('onboarding');
  expect(await storedPlayers(page)).not.toContain('player-b');
  expect(await sharedProgress(page), 'Even the last profile removal retains medals, toys and Talk Quest progress').toEqual(shared);
  await page.screenshot({ path: info.outputPath('last-player-removed-onboarding.png') });

  await page.reload();
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  await expectProfiles(page, []);
  await replaceName(page, 'New explorer', { expectNativeEditor: info.project.name.includes('iphone') });
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expectKeyboardDismissed(page);
  await openPlayers(page);
  const recreated = (await snapshot(page)).profiles;
  expect(recreated).toHaveLength(1);
  expect(recreated[0].name).toBe('New explorer');
  expect(PROFILES.some(profile => profile.id === recreated[0].id), 'A new player receives a fresh stable identity').toBe(false);
  await activate(page, 'LeaderboardClose');
  await activate(page, 'MenuLeaderboards');
  for (const mode of ['pop', 'match', 'memory']) {
    await activate(page, `LeaderboardMode_${mode}`);
    await expect.poll(async () => (await snapshot(page)).mode).toBe(mode);
    expect((await snapshot(page)).rows, 'A replacement player cannot inherit removed scores').toEqual([]);
  }
  expect(progressAfterNewLesson(await sharedProgress(page))).toEqual(progressAfterNewLesson(shared));
  expect(errors).toEqual([]);
});
