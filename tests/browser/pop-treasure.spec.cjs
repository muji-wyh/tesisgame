const { test, expect } = require('@playwright/test');
const { enterGame, chooseMode, rendered, metrics, tap, contentBounds, uiScale } = require('./game-ui.cjs');
const { roomState, scrollChestIntoView } = require('./pop-treasure-ui.cjs');

const STORAGE_KEY = 'wordBuddies.popRewards';
const PIXEL_TOLERANCE = 0.1;

async function installRecognition(page) {
  await page.addInitScript(() => {
    const fixture = { instances: [], starts: 0 };
    class Recognition {
      constructor() {
        this.results = [];
        this.running = false;
        this.onaudiostart = null;
        fixture.instances.push(this);
      }
      start() {
        fixture.starts++;
        this.running = true;
        this.callbacks = { start: this.onstart, audio: this.onaudiostart,
          result: this.onresult, error: this.onerror, end: this.onend };
        queueMicrotask(() => { this.callbacks.start?.(); this.callbacks.audio?.(); });
      }
      abort() {
        this.running = false;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      stop() {
        this.running = false;
        const callbacks = this.callbacks;
        queueMicrotask(() => callbacks?.end?.());
      }
      emit(text) {
        const resultIndex = this.results.length;
        this.results.push(Object.assign([{ transcript: text, confidence: 0.95 }], { isFinal: true }));
        this.callbacks.result?.({ resultIndex, results: this.results });
      }
    }
    window.__popTreasureSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true,
      value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) { queueMicrotask(() => utterance.onstart?.()); }, cancel() {}
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      throw new Error('Voice Pop reward checks must not capture a physical microphone');
    };
  });
}

async function popState(page) {
  return page.locator('#pop-status').evaluate(element => ({
    phase: element.dataset.phase, score: Number(element.dataset.score), hits: Number(element.dataset.hits),
    chestCount: Number(element.dataset.chestCount), chestNextScore: Number(element.dataset.chestNextScore),
    chestProgress: Number(element.dataset.chestProgress), chestFx: JSON.parse(element.dataset.chestFx || '{}'),
    resultsRewards: JSON.parse(element.dataset.resultsRewards || '{}'),
    hud: JSON.parse(element.dataset.hud || '{}'), controls: JSON.parse(element.dataset.controls || '[]')
  }));
}

async function visibleResultState(page) {
  // The round finishes before its shared Pip celebration reveals the results.
  // Wait for the visible reward ladder and actions rather than elapsed time.
  let current;
  await expect.poll(async () => {
    current = await popState(page);
    const actions = current.controls.filter(control =>
      /^(OpenChests|Replay)$/.test(control.name) && !control.disabled && control.width > 1 && control.height > 1);
    return { phase: current.phase, visible: current.resultsRewards.visible === true,
      actions: actions.map(control => control.name).sort() };
  }, { timeout: 45000, intervals: [50, 100, 200],
    message: 'The completed Pip celebration reveals the earned result ladder and its actions' })
    .toEqual({ phase: 'finished', visible: true, actions: ['OpenChests', 'Replay'] });
  await rendered(page);
  return popState(page);
}

function expectEarnedResultLadder(current, bounds) {
  const rewards = current.resultsRewards;
  expect(current.phase).toBe('finished');
  expect(current.score).toBeGreaterThanOrEqual(300);
  expect(rewards).toMatchObject({ visible: true, score: current.score, earned: current.chestCount,
    title: 'All 3 chests earned' });
  expect(rewards.earned).toBe(3);
  expect(rewards.rows.map(row => row.threshold)).toEqual([100, 200, 300]);
  const expectRect = (rect, parent, message) => {
    expect(rect, message).toHaveLength(4);
    expect(rect.every(Number.isFinite), message).toBe(true);
    expect(rect[2], message).toBeGreaterThan(0);
    expect(rect[3], message).toBeGreaterThan(0);
    if (!parent) return;
    expect(rect[0], message).toBeGreaterThanOrEqual(parent[0] - 1);
    expect(rect[1], message).toBeGreaterThanOrEqual(parent[1] - 1);
    expect(rect[0] + rect[2], message).toBeLessThanOrEqual(parent[0] + parent[2] + 1);
    expect(rect[1] + rect[3], message).toBeLessThanOrEqual(parent[1] + parent[3] + 1);
  };
  const separate = (a, b) => a[0] + a[2] <= b[0] + 1 || b[0] + b[2] <= a[0] + 1 ||
    a[1] + a[3] <= b[1] + 1 || b[1] + b[3] <= a[1] + 1;
  expectRect(rewards.rect, null, 'The completed reward ladder has finite, nonempty bounds');
  expect(rewards.rect[0], 'Reward rows fit the canvas horizontally').toBeGreaterThanOrEqual(-1);
  expect(rewards.rect[0] + rewards.rect[2], 'Reward rows fit the canvas horizontally').toBeLessThanOrEqual(bounds.width + 1);
  for (const [index, row] of rewards.rows.entries()) {
    expect(row, 'A score above 300 fills each cumulative goal without overflow').toMatchObject({
      value: row.threshold, progress: 1, earned: true,
      label: `${row.threshold} points`, progress_text: `${row.threshold} / ${row.threshold}`
    });
    expectRect(row.rect, rewards.rect, 'Each earned threshold stays inside the ladder');
    expectRect(row.bar_rect, row.rect, 'Each full bar stays inside its row');
    expectRect(row.chest_rect, row.rect, 'Each earned chest stays inside its row');
    expect(separate(row.bar_rect, row.chest_rect), 'Full bars do not overlap chest artwork').toBe(true);
    if (index) expect(rewards.rows[index - 1].rect[1] + rewards.rows[index - 1].rect[3],
      'Earned rows remain in order without overlap').toBeLessThanOrEqual(row.rect[1] + 1);
  }
  // Short screens may scroll some rows below the fold; the actions retain their
  // own space and must be visible before the existing open-chests gesture.
  const actions = current.controls.filter(control => /^(OpenChests|Replay)$/.test(control.name));
  expect(actions.map(action => action.name).sort()).toEqual(['OpenChests', 'Replay']);
  for (const action of actions) {
    const rect = [action.x, action.y, action.width, action.height];
    expectRect(rect, [0, 0, bounds.width, bounds.height], 'Earned-chest result actions are immediately reachable');
    expect(separate(rewards.rect, rect), 'Result actions do not overlap the reward ladder').toBe(true);
  }
}

async function storedRewards(page) {
  return page.evaluate(key => localStorage.getItem(key), STORAGE_KEY);
}

async function beginScoring(page) {
  await page.evaluate(() => {
    const status = document.querySelector('#pop-status');
    window.__popChestMilestones = [];
    const observed = new Set(), spoken = new Set();
    const record = () => {
      const effect = JSON.parse(status.dataset.chestFx || '{}');
      if (!effect.active || observed.has(effect.serial)) return;
      observed.add(effect.serial);
      window.__popChestMilestones.push({ at: performance.now(), score: Number(status.dataset.score),
        count: Number(status.dataset.chestCount), next: Number(status.dataset.chestNextScore), ...effect });
    };
    window.__popChestObserver = new MutationObserver(record);
    window.__popChestObserver.observe(status, { attributes: true,
      attributeFilter: ['data-chest-fx', 'data-chest-count'] });
    // Read a currently visible target and deliver a browser recognition event
    // in the same task; scoring and the real game clock remain unmodified.
    window.__popDriveToScore = goal => {
      clearInterval(window.__popTreasureDriver);
      window.__popTreasureDriver = setInterval(() => {
        if (Number(status.dataset.score) >= goal || status.dataset.phase === 'finished') {
          clearInterval(window.__popTreasureDriver);
          return;
        }
        if (status.dataset.phase !== 'running') return;
        const recognition = window.__popTreasureSpeech.instances.at(-1);
        if (!recognition?.running) return;
        const targets = JSON.parse(status.dataset.targets || '[]');
        const target = targets.find(item => !spoken.has(item.uid));
        if (!target) return;
        spoken.add(target.uid);
        recognition.emit(target.text);
      }, 80);
    };
    window.__popDriveToScore(300);
  });
}

async function tapPopAction(page, name) {
  let action;
  await expect.poll(async () => {
    action = (await popState(page)).controls.find(control => control.name === name);
    return Boolean(action && !action.disabled && action.width > 1 && action.height > 1);
  }, { intervals: [50, 100, 200], message: `${name} is available in the finished game` }).toBe(true);
  await rendered(page);
  action = (await popState(page)).controls.find(control => control.name === name);
  await tap(page, action.x + action.width / 2, action.y + action.height / 2);
}

async function expectChestRoom(page, opened, expectedTypes) {
  // Windows WebKit can block while warming the three live chest models.
  // Keep the saved-batch checks intact while allowing that first render to finish.
  await expect.poll(async () => {
    const current = await roomState(page);
    return { visible: current.visible, count: current.chest_count,
      opened: current.opened_count, paused: current.paused, failed: current.save_failed };
  }, { timeout: 45000, intervals: [50, 100, 200],
    message: 'The rendered treasure room exposes the complete saved chest batch' })
    .toEqual({ visible: true, count: 3, opened, paused: false, failed: false });
  await rendered(page);
  const current = await roomState(page), bounds = await metrics(page), field = contentBounds(bounds);
  await test.info().attach('treasure-room-layout.json', {
    body: JSON.stringify({ room: current, viewport: bounds, field }, null, 2),
    contentType: 'application/json'
  });
  expect(current.chests).toHaveLength(3);
  expect(current.heading).toBe('Your treasure');
  expect(current.progress_text, 'The room reports opened rewards across the entire saved batch').toBe(`${opened} / 3 opened`);
  const types = current.chests.map(chest => chest.type);
  expect(new Set(types).size, 'All three displayed chests have different actual styles').toBe(3);
  expect(types.every(type => typeof type === 'string' && type.length > 0)).toBe(true);
  if (expectedTypes) expect(types, 'Returning preserves the same three chest types').toEqual(expectedTypes);
  const viewport = current.scroll_rect;
  expect([viewport.x, viewport.y, viewport.width, viewport.height,
    current.scroll_offset, current.scroll_max].every(Number.isFinite)).toBe(true);
  expect(viewport.width).toBeGreaterThan(0);
  expect(viewport.height).toBeGreaterThan(0);
  expect(viewport.x).toBeGreaterThanOrEqual(field.x - 1);
  expect(viewport.x + viewport.width).toBeLessThanOrEqual(field.x + field.width + 1);
  expect(viewport.y).toBeGreaterThanOrEqual(field.top - 1);
  expect(viewport.y + viewport.height).toBeLessThanOrEqual(bounds.height - field.padding + 1);
  expect(current.scroll_max).toBeGreaterThanOrEqual(0);
  expect(current.scroll_offset).toBeGreaterThanOrEqual(0);
  expect(current.scroll_offset).toBeLessThanOrEqual(current.scroll_max + 1);
  for (const chest of current.chests) {
    const rect = chest.rect;
    expect([rect.x, rect.y, rect.width, rect.height].every(Number.isFinite)).toBe(true);
    expect(rect.width).toBeGreaterThan(0);
    expect(rect.height * uiScale(bounds), 'Every chest keeps a usable hold target').toBeGreaterThanOrEqual(44 - PIXEL_TOLERANCE);
    expect(chest.art_rect.width * uiScale(bounds), 'Chest art stays bounded within the reward layout').toBeLessThanOrEqual(361);
    expect(chest.art_rect.height * uiScale(bounds), 'The artwork remains readable even in short landscape').toBeGreaterThanOrEqual(128 - PIXEL_TOLERANCE);
    expect(chest.art_rect.height * uiScale(bounds), 'A batch no longer uses oversized chest panels').toBeLessThanOrEqual(301);
    expect(chest.caption, 'The visible instruction follows the durable opened state').toBe(chest.opened ? 'Opened!' : 'Hold to open');
    expect(rect.x).toBeGreaterThanOrEqual(viewport.x - 1);
    expect(rect.x + rect.width).toBeLessThanOrEqual(viewport.x + viewport.width + 1);
    expect(rect.y + current.scroll_offset).toBeGreaterThanOrEqual(viewport.y - 1);
    expect(rect.y + current.scroll_offset + rect.height,
      'Each chest stays inside the reachable scroll content').toBeLessThanOrEqual(viewport.y + viewport.height + current.scroll_max + 1);
    expect(chest.disabled, 'Only already opened chests are disabled between holds').toBe(chest.opened);
  }
  for (let first = 0; first < 3; first++) for (let second = first + 1; second < 3; second++) {
    const a = current.chests[first].rect, b = current.chests[second].rect;
    expect(a.x + a.width <= b.x + 1 || b.x + b.width <= a.x + 1 ||
      a.y + a.height <= b.y + 1 || b.y + b.height <= a.y + 1,
    'Chest controls never overlap inside the shared list').toBe(true);
  }
  const roomWidth = field.width * uiScale(bounds);
  if (roomWidth < 620) {
    expect(current.scroll_max, 'Phone rewards remain scrollable without shrinking every chest').toBeGreaterThan(0);
    expect(current.chests.every(chest => Math.abs(chest.rect.x - current.chests[0].rect.x) <= 1),
      'Phone treasure uses one chest per row').toBe(true);
  } else {
    expect(Math.abs(current.chests[0].rect.y - current.chests[1].rect.y), 'Wide treasure layouts place rewards alongside one another').toBeLessThanOrEqual(1);
    expect(current.chests[1].rect.x).toBeGreaterThan(current.chests[0].rect.x);
    if (roomWidth >= 960) {
      expect(Math.abs(current.chests[0].rect.y - current.chests[2].rect.y), 'A desktop row can present the complete three-chest batch').toBeLessThanOrEqual(1);
      expect(current.chests[2].rect.x).toBeGreaterThan(current.chests[1].rect.x);
    }
  }
  return current;
}

async function pressChest(page, index) {
  const current = await scrollChestIntoView(page, index), chest = current.chests[index];
  expect(current.visible).toBe(true);
  expect(chest.opened).toBe(false);
  expect(chest.disabled).toBe(false);
  const bounds = await metrics(page), rect = chest.rect;
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  const pressedAt = Date.now();
  await page.mouse.down();
  await expect.poll(async () => {
    const value = await roomState(page);
    return { active: value.active, holding: value.holding };
  }, { intervals: [20, 50, 100] }).toEqual({ active: index, holding: true });
  expect((await roomState(page)).chests[index].caption).toBe('Keep holding...');
  return pressedAt;
}

async function openChest(page, index, expectedOpened) {
  const started = await pressChest(page, index);
  try {
    await expect.poll(async () => (await roomState(page)).chests[index].opened,
      { timeout: 12000, intervals: [50, 100, 200], message: 'The held chest reaches its real release and saves once' }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  expect(Date.now() - started, 'Even reduced motion requires an intentional hold').toBeGreaterThanOrEqual(1000);
  await expect.poll(async () => {
    const current = await roomState(page);
    return { active: current.active, opening: current.opening, count: current.opened_count };
  }, { timeout: 12000, intervals: [50, 100, 200] }).toEqual({ active: -1, opening: false, count: expectedOpened });
}

async function setHidden(page, hidden) {
  await page.evaluate(hidden => {
    if (hidden) Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    else delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  }, hidden);
}

test('earned Voice Pop chests stay distinct, cancel safely, and survive return and reload', async ({ page }, info) => {
  // Include the real round, live-model warmup, three openings, and two reloads.
  test.setTimeout(360000);
  const reduced = info.project.name.includes('iphone');
  await page.emulateMedia({ reducedMotion: reduced ? 'reduce' : 'no-preference' });
  await installRecognition(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await popState(page)).toMatchObject({ chestCount: 0, chestNextScore: 100, chestProgress: 0 });
  await beginScoring(page);
  await expect.poll(async () => (await popState(page)).chestCount,
    { timeout: 45000, intervals: [50, 100, 200], message: 'Accepted spoken targets earn all three score milestones' }).toBe(3);
  const earned = await popState(page);
  expect(earned.score).toBeGreaterThanOrEqual(300);
  expect(earned).toMatchObject({ chestNextScore: 0, chestProgress: 1 });
  expect(earned.hud.chests.text).toBe('CHESTS 3 / 3');
  await page.screenshot({ path: info.outputPath('third-chest-earned.png') });
  await page.evaluate(() => window.__popDriveToScore(350));
  await expect.poll(async () => (await popState(page)).score,
    { timeout: 10000, intervals: [50, 100, 200] }).toBeGreaterThanOrEqual(350);
  expect((await popState(page)).chestCount, 'Additional scoring cannot create a fourth chest').toBe(3);
  const milestones = await page.evaluate(() => window.__popChestMilestones);
  expect(milestones.map(value => value.count)).toEqual([1, 2, 3]);
  expect(milestones.map(value => value.next)).toEqual([200, 300, 0]);
  expect(milestones.every(value => value.active && value.text === '+1 CHEST' &&
    value.above_targets && value.reduced_motion === reduced)).toBe(true);
  for (const milestone of milestones) expect(milestone.score).toBeGreaterThanOrEqual(milestone.count * 100);
  await info.attach('earned-chest-milestones.json', { body: JSON.stringify(milestones, null, 2), contentType: 'application/json' });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 65000 });
  const finishedRound = await visibleResultState(page);
  expect(finishedRound.chestCount).toBe(3);
  expectEarnedResultLadder(finishedRound, await metrics(page));
  await info.attach('earned-chest-result-ladder.json', { body: JSON.stringify(finishedRound.resultsRewards, null, 2), contentType: 'application/json' });
  await page.screenshot({ path: info.outputPath('earned-chest-results.png') });
  await tapPopAction(page, 'OpenChests');
  let room = await expectChestRoom(page, 0);
  const types = room.chests.map(chest => chest.type), round = room.round_id;
  const unopened = await storedRewards(page);
  expect(unopened).toBeTruthy();
  await page.screenshot({ path: info.outputPath('treasure-room.png') });

  await pressChest(page, 0);
  await page.waitForTimeout(150);
  await page.mouse.up();
  await expect.poll(async () => (await roomState(page)).active).toBe(-1);
  await expectChestRoom(page, 0, types);
  expect(await storedRewards(page), 'A short hold leaves the durable reward batch unchanged').toBe(unopened);

  await pressChest(page, 0);
  try {
    await setHidden(page, true);
    await expect.poll(async () => (await roomState(page)).paused).toBe(true);
    await page.mouse.up();
  } finally {
    await page.mouse.up();
    await setHidden(page, false);
  }
  await expectChestRoom(page, 0, types);
  expect(await storedRewards(page), 'Backgrounding before release cannot claim a chest').toBe(unopened);

  await openChest(page, 0, 1);
  await expectChestRoom(page, 1, types);
  const partiallyOpened = await storedRewards(page);
  expect(partiallyOpened).not.toBe(unopened);
  await page.locator('#canvas').press('Escape');
  await expect.poll(async () => (await roomState(page)).visible).toBe(false);
  const returnedResult = await visibleResultState(page);
  expect(returnedResult.score, 'Returning from a partially opened batch preserves the scored round').toBe(finishedRound.score);
  expectEarnedResultLadder(returnedResult, await metrics(page));
  await tapPopAction(page, 'OpenChests');
  room = await expectChestRoom(page, 1, types);
  expect(room.round_id).toBe(round);
  expect(room.chests.map(chest => chest.opened)).toEqual([true, false, false]);
  expect(await storedRewards(page), 'Returning to the same room never rerolls or reopens treasure').toBe(partiallyOpened);

  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'pop');
  room = await expectChestRoom(page, 1, types);
  expect(room.round_id).toBe(round);
  expect(room.chests.map(chest => chest.opened)).toEqual([true, false, false]);
  expect((await roomState(page)).visible, 'Pending treasure is restored before a fresh round').toBe(true);
  expect(await storedRewards(page), 'Reload preserves the exact partial batch').toBe(partiallyOpened);
  await page.screenshot({ path: info.outputPath('saved-chests-restored.png') });
  await openChest(page, 1, 2);
  await openChest(page, 2, 3);
  room = await expectChestRoom(page, 3, types);
  expect(room.pending).toBe(false);
  expect(room.chests.every(chest => chest.opened && chest.mode === 'opened')).toBe(true);
  const completed = await storedRewards(page);
  await page.screenshot({ path: info.outputPath('completed-treasure-list.png') });
  await page.reload();
  await enterGame(page);
  expect(await storedRewards(page), 'Every opened flag and the completed-round receipt survive reload').toBe(completed);
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await storedRewards(page), 'Starting a fresh round cannot duplicate the completed reward batch').toBe(completed);
  expect(errors).toEqual([]);
});
