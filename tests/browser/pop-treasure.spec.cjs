const { test, expect } = require('@playwright/test');
const { enterGame, chooseMode, rendered, metrics, tap, contentBounds,
  leaderboardSnapshot } = require('./game-ui.cjs');

const STORAGE_KEY = 'wordBuddies.popRewards';

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
    hud: JSON.parse(element.dataset.hud || '{}'), controls: JSON.parse(element.dataset.controls || '[]')
  }));
}

async function roomState(page) {
  return page.locator('#pop-reward-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));
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
  await expect.poll(async () => {
    const current = await roomState(page);
    return { visible: current.visible, count: current.chest_count,
      opened: current.opened_count, paused: current.paused, failed: current.save_failed };
  }, { intervals: [50, 100, 200] }).toEqual({ visible: true, count: 3, opened, paused: false, failed: false });
  await rendered(page);
  const current = await roomState(page), bounds = await metrics(page), field = contentBounds(bounds);
  await test.info().attach('treasure-room-layout.json', {
    body: JSON.stringify({ room: current, viewport: bounds, field }, null, 2),
    contentType: 'application/json'
  });
  expect(current.chests).toHaveLength(3);
  const types = current.chests.map(chest => chest.type);
  expect(new Set(types).size, 'All three displayed chests have different actual styles').toBe(3);
  expect(types.every(type => typeof type === 'string' && type.length > 0)).toBe(true);
  if (expectedTypes) expect(types, 'Returning preserves the same three chest types').toEqual(expectedTypes);
  for (const chest of current.chests) {
    const rect = chest.rect;
    expect([rect.x, rect.y, rect.width, rect.height].every(Number.isFinite)).toBe(true);
    expect(rect.width).toBeGreaterThan(0);
    expect(rect.height).toBeGreaterThan(0);
    expect(rect.x, 'Every chest is simultaneously visible at the left edge').toBeGreaterThanOrEqual(field.x - 1);
    expect(rect.x + rect.width).toBeLessThanOrEqual(field.x + field.width + 1);
    expect(rect.y).toBeGreaterThanOrEqual(field.top - 1);
    expect(rect.y + rect.height, 'Every chest fits without scrolling').toBeLessThanOrEqual(bounds.height - field.padding + 1);
    expect(chest.disabled, 'Only already opened chests are disabled between holds').toBe(chest.opened);
  }
  for (let first = 0; first < 3; first++) for (let second = first + 1; second < 3; second++) {
    const a = current.chests[first].rect, b = current.chests[second].rect;
    expect(a.x + a.width <= b.x + 1 || b.x + b.width <= a.x + 1 ||
      a.y + a.height <= b.y + 1 || b.y + b.height <= a.y + 1,
    'Simultaneous chest controls never overlap').toBe(true);
  }
  return current;
}

async function pressChest(page, index) {
  const current = await roomState(page), chest = current.chests[index];
  expect(current.visible).toBe(true);
  expect(chest.opened).toBe(false);
  expect(chest.disabled).toBe(false);
  const bounds = await metrics(page), rect = chest.rect;
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  await page.mouse.down();
  await expect.poll(async () => {
    const value = await roomState(page);
    return { active: value.active, holding: value.holding };
  }, { intervals: [20, 50, 100] }).toEqual({ active: index, holding: true });
}

async function openChest(page, index, expectedOpened) {
  const started = Date.now();
  await pressChest(page, index);
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
  test.setTimeout(240000);
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
  expect((await popState(page)).chestCount).toBe(3);
  await tapPopAction(page, 'OpenChests');
  let room = await expectChestRoom(page, 0);
  const types = room.chests.map(chest => chest.type), round = room.round_id;
  const unopened = await storedRewards(page);
  expect(unopened).toBeTruthy();
  await page.screenshot({ path: info.outputPath('three-distinct-chests.png') });

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
  await tapPopAction(page, 'OpenChests');
  room = await expectChestRoom(page, 1, types);
  expect(room.round_id).toBe(round);
  expect(room.chests.map(chest => chest.opened)).toEqual([true, false, false]);
  expect(await storedRewards(page), 'Returning to the same room never rerolls or reopens treasure').toBe(partiallyOpened);

  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'pop', { choosePlayer: false });
  room = await expectChestRoom(page, 1, types);
  expect(room.round_id).toBe(round);
  expect(room.chests.map(chest => chest.opened)).toEqual([true, false, false]);
  expect((await leaderboardSnapshot(page)).view, 'Pending treasure is restored before a fresh player selection').not.toBe('picker');
  expect(await storedRewards(page), 'Reload preserves the exact partial batch').toBe(partiallyOpened);
  await page.screenshot({ path: info.outputPath('saved-chests-restored.png') });
  await openChest(page, 1, 2);
  await openChest(page, 2, 3);
  room = await expectChestRoom(page, 3, types);
  expect(room.pending).toBe(false);
  expect(room.chests.every(chest => chest.opened && chest.mode === 'opened')).toBe(true);
  const completed = await storedRewards(page);
  await page.screenshot({ path: info.outputPath('all-three-chests-opened.png') });
  await page.reload();
  await enterGame(page);
  expect(await storedRewards(page), 'Every opened flag and the completed-round receipt survive reload').toBe(completed);
  await chooseMode(page, 'pop', { choosePlayer: false });
  await expect.poll(async () => (await leaderboardSnapshot(page)).view,
    { message: 'Opening the last pending chest allows the next round player selection' }).toBe('picker');
  expect(await storedRewards(page), 'Starting player selection cannot duplicate the completed reward batch').toBe(completed);
  expect(errors).toEqual([]);
});
