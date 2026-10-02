const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { enterGame, chooseMode, rendered, visibleColorCount } = require('./game-ui.cjs');

async function installRecognition(page, prefixed) {
  await page.addInitScript(({ prefixed }) => {
    const fixture = { instances: [], starts: 0, aborts: 0, spoken: [], cancellations: 0, events: [] };
    const wordState = () => {
      const state = JSON.parse(document.getElementById('quest-status')?.dataset.snapshot || '{}');
      return { at: performance.now(), phase: state.phase, hp: state.hp, hits: state.hits,
        misses: state.misses, spawned: state.spawned, listening: state.listening, save_failed: state.save_failed,
        targets: state.targets?.map(target => ({ uid: target.uid, text: target.text, remaining_ms: target.remaining_ms })) };
    };
    class Recognition {
      constructor() {
        this.results = [];
        this.running = false;
        this.onaudiostart = null;
        fixture.instances.push(this);
      }
      start() {
        this.running = true;
        fixture.starts++;
        this.callbacks = { start: this.onstart, audio: this.onaudiostart, result: this.onresult,
          error: this.onerror, end: this.onend };
        queueMicrotask(() => { this.callbacks.start?.(); this.callbacks.audio?.(); });
      }
      abort() {
        this.running = false;
        fixture.aborts++;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks.error?.({ error: 'aborted' }); callbacks.end?.(); });
      }
      stop() { this.abort(); }
      revise(index, text, final = true) {
        this.results[index] = Object.assign([{ transcript: text, confidence: 0.95 }], { isFinal: final });
        const event = { index, text, final, before: wordState() };
        fixture.events.push(event);
        this.callbacks.result?.({ resultIndex: index, results: this.results });
        event.after = wordState();
        event.diagnostics = window.wordBuddiesHost?.speechDiagnostics();
      }
      emit(text, final = true) {
        const index = this.results.length && !this.results.at(-1).isFinal ? this.results.length - 1 : this.results.length;
        this.revise(index, text, final);
      }
    }
    window.__questSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: prefixed ? undefined : Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: prefixed ? Recognition : undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true,
      value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) { fixture.spoken.push(utterance); },
      cancel() { fixture.cancellations++; }
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      throw new Error('Talk Quest browser checks must not open a physical microphone');
    };
  }, { prefixed });
}

test.afterEach(async ({ page }, info) => {
  if (info.status === info.expectedStatus) return;
  const diagnostic = await page.evaluate(() => ({
    state: JSON.parse(document.getElementById('quest-status')?.dataset.snapshot || '{}'),
    fixture: window.__questSpeech ? { starts: window.__questSpeech.starts, aborts: window.__questSpeech.aborts,
      events: window.__questSpeech.events } : null,
    host: window.wordBuddiesHost?.speechDiagnostics()
  })).catch(error => ({ capture_error: error.message }));
  fs.writeFileSync(info.outputPath('quest-failure-diagnostics.json'), JSON.stringify(diagnostic, null, 2));
});

function recordErrors(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  return errors;
}

async function snapshot(page) {
  return page.evaluate(() => JSON.parse(document.getElementById('quest-status')?.dataset.snapshot || '{}'));
}

async function waitState(page, expected) {
  let current;
  try {
    await expect.poll(async () => {
      current = await snapshot(page);
      return Object.fromEntries(Object.keys(expected).map(key => [key, current[key]]));
    }, { intervals: [50, 100, 200], timeout: 10000 }).toEqual(expected);
    return current;
  } catch (error) {
    const current = await snapshot(page).catch(() => ({}));
    const observed = Object.fromEntries(Object.keys(expected).map(key => [key, current[key]]));
    throw new Error(`Quest state did not settle. Expected ${JSON.stringify(expected)}; observed ${JSON.stringify(observed)}`, { cause: error });
  }
}

async function waitAdventure(page, level, listening = true) {
  await rendered(page);
  return waitState(page, { active: true, view: 'stage', phase: 'playing', level, listening });
}

async function waitWord(page, level) {
  let current;
  await expect.poll(async () => {
    current = await snapshot(page);
    return current.level === level && current.phase === 'playing' && current.listening &&
      current.targets?.some(target => target.remaining_ms > 1200 && hasFiniteRect(target.rect));
  }, { intervals: [50, 100, 150], timeout: 10000 }).toBe(true);
  return { state: current, target: current.targets.filter(target => target.remaining_ms > 1200)
    .sort((a, b) => b.remaining_ms - a.remaining_ms)[0] };
}

async function emitVisibleWord(page, level, final = true) {
  let delivered;
  await expect.poll(async () => {
    delivered = await page.evaluate(({ level, final }) => {
      const state = JSON.parse(document.getElementById('quest-status')?.dataset.snapshot || '{}');
      const recognition = window.__questSpeech.instances.at(-1);
      if (state.level !== level || state.phase !== 'playing' || !state.listening || !recognition?.running) return null;
      const target = state.targets.filter(target => target.remaining_ms > 1200)
        .sort((a, b) => b.remaining_ms - a.remaining_ms)[0];
      if (!target) return null;
      // Select and speak in one browser task: transport time must not age an
      // already selected flight before the mocked recognition callback runs.
      recognition.emit(target.text, final);
      return { state, target };
    }, { level, final });
    return delivered !== null;
  }, { intervals: [50, 100, 150], timeout: 10000 }).toBe(true);
  return delivered;
}

function hasFiniteRect(rect) {
  return Boolean(rect && ['x', 'y', 'width', 'height'].every(key => Number.isFinite(rect[key])) &&
    rect.width > 0 && rect.height > 0);
}

function overlapArea(first, second) {
  return Math.max(0, Math.min(first.x + first.width, second.x + second.width) - Math.max(first.x, second.x)) *
    Math.max(0, Math.min(first.y + first.height, second.y + second.height) - Math.max(first.y, second.y));
}

async function rectCenter(page, rect, name) {
  expect(rect.visible, `${name} is visible in the actual native interface`).toBe(true);
  expect(rect.disabled, `${name} is enabled`).toBe(false);
  expect(hasFiniteRect(rect), `${name} has finite hit geometry`).toBe(true);
  const canvas = await page.locator('#canvas').boundingBox();
  expect(hasFiniteRect(canvas), 'The canvas has finite hit geometry').toBe(true);
  const x = rect.x + rect.width / 2, y = rect.y + rect.height / 2;
  expect(x, `${name} has an on-screen horizontal center`).toBeGreaterThan(0);
  expect(x).toBeLessThan(1);
  expect(y, `${name} has an on-screen vertical center`).toBeGreaterThan(0);
  expect(y).toBeLessThan(1);
  return { x: canvas.x + x * canvas.width, y: canvas.y + y * canvas.height };
}

async function tapRect(page, rect, name) {
  const point = await rectCenter(page, rect, name);
  await page.touchscreen.tap(point.x, point.y);
}

async function visibleQuestControl(page, name) {
  let rect;
  await expect.poll(async () => {
    rect = (await snapshot(page)).controls?.[name];
    return rect?.visible && hasFiniteRect(rect);
  }, { intervals: [50, 100, 200], timeout: 10000 }).toBe(true);
  expect(rect.x, `${name} stays inside the left edge`).toBeGreaterThanOrEqual(-0.002);
  expect(rect.x + rect.width, `${name} stays inside the right edge`).toBeLessThanOrEqual(1.002);
  expect(rect.y, `${name} stays above the bottom edge`).toBeGreaterThanOrEqual(-0.002);
  expect(rect.y + rect.height, `${name} stays inside the bottom edge`).toBeLessThanOrEqual(1.002);
  return rect;
}

async function readyQuestControl(page, name) {
  await expect.poll(async () => {
    const control = (await snapshot(page)).controls?.[name];
    return Boolean(control?.visible && !control.disabled && hasFiniteRect(control));
  }, { intervals: [50, 100, 200], timeout: 10000 }).toBe(true);
  return visibleQuestControl(page, name);
}

async function clickControl(page, name) {
  await tapRect(page, await readyQuestControl(page, name), name);
}

async function pressChest(page, milliseconds = null, { backgroundOnRelease = false } = {}) {
  const point = await rectCenter(page, await readyQuestControl(page, 'open'), 'Chest surface');
  // Observe native publications without advancing gameplay. A lifecycle case
  // can hide the page at release before browser transport consumes its tail.
  await page.evaluate(backgroundOnRelease => {
    window.__questChestObserver?.disconnect();
    window.__questChestHold = [];
    window.__questChestBackground = null;
    const status = document.getElementById('quest-status');
    const observe = () => {
      const value = JSON.parse(status.dataset.snapshot || '{}');
      const state = {
        at: performance.now(), phase: value.phase, busy: value.busy,
        chest_phase: value.chest_phase, chest_progress: value.chest_progress,
        chest_committed: value.chest_committed, holding_chest: value.holding_chest,
        completed: value.completed, total_clears: value.total_clears, chests: value.chests,
        saved: JSON.parse(window.wordBuddiesHost.questProgress())
      };
      window.__questChestHold.push(state);
      if (backgroundOnRelease && value.chest_committed && !window.__questChestBackground) {
        window.__questChestBackground = state;
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event('visibilitychange'));
      }
    };
    window.__questChestObserver = new MutationObserver(observe);
    window.__questChestObserver.observe(status, { attributes: true, attributeFilter: ['data-snapshot'] });
    observe();
  }, backgroundOnRelease);
  if (milliseconds !== null) {
    await page.mouse.click(point.x, point.y, { delay: milliseconds });
    return;
  }
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
}

async function waitChestRelease(page) {
  await page.waitForFunction(() => window.__questChestHold.some(state => state.chest_committed),
    null, { timeout: 10000 });
  return page.evaluate(() => window.__questChestHold.find(state => state.chest_committed));
}

async function holdChestUntilRelease(page) {
  await pressChest(page);
  try {
    return await waitChestRelease(page);
  } finally {
    await page.mouse.up();
    await page.evaluate(() => window.__questChestObserver.disconnect());
  }
}

async function setPageHidden(page, hidden) {
  await page.evaluate(hidden => {
    if (hidden) Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    else delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  }, hidden);
}

async function emit(page, text, final = true) {
  return page.evaluate(({ text, final }) => {
    const fixture = window.__questSpeech, recognition = fixture.instances.at(-1);
    if (!recognition?.running) throw new Error('A real level or retry gesture must start capture before delivering browser results');
    recognition.emit(text, final);
    return fixture.instances.length - 1;
  }, { text, final });
}

async function progress(page) {
  return page.evaluate(() => JSON.parse(window.wordBuddiesHost.questProgress()));
}

function expectPrivateProgress(saved) {
  expect(Object.keys(saved).sort()).toEqual(['completion_counts', 'run', 'version']);
  expect(saved.version).toBe(2);
  expect(saved.completion_counts).toHaveLength(14);
  const allowed = ['clear_number', 'level_number', 'hits', 'misses', 'spawned', 'elapsed',
    'next_spawn_in', 'targets', 'phase', 'run_id'];
  expect(Object.keys(saved.run).every(key => allowed.includes(key))).toBe(true);
  const flightFields = ['uid', 'word_id', 'age', 'lifetime', 'lane', 'x_start', 'x_end', 'peak', 'spin'];
  for (const target of saved.run.targets || []) {
    expect(Object.keys(target).every(key => flightFields.includes(key))).toBe(true);
  }
  expect(JSON.stringify(saved)).not.toMatch(/transcript|event_id|recording|audio|feedback|forms/);
}

function expectWordInterface(current) {
  for (const removed of ['speak', 'hear', 'type', 'input', 'submit', 'prompt']) {
    expect(current.controls[removed], `${removed} is absent from the word-only interface`).toBeUndefined();
  }
  expect(current.scroll_max).toBe(0);
  expect(current.scroll_offset).toBe(0);
}

async function openQuest(page, browserName) {
  await installRecognition(page, browserName === 'webkit');
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'quest');
  await page.evaluate(() => window.wordBuddiesHost.setSpeechDiagnostics(true));
  return waitState(page, { active: true, view: 'map' });
}

async function openPendingChest(page, browserName, reducedMotion) {
  await page.emulateMedia({ reducedMotion });
  // Seed the current earned-chest checkpoint. Actual input and the normal
  // Continue action still own the complete chest interaction.
  await page.addInitScript(() => {
    const key = 'wordBuddies.talkQuest';
    if (localStorage.getItem(key) === null) localStorage.setItem(key, JSON.stringify({
      version: 2, completion_counts: Array(14).fill(0),
      run: { level_number: 1, hits: 5, misses: 0, spawned: 5, elapsed: 8.6,
        next_spawn_in: 2.15, targets: [], phase: 'chest', clear_number: 1, run_id: 'tq-run-1-1-1' }
    }));
  });
  const map = await openQuest(page, browserName);
  expect(map.controls.continue.visible).toBe(true);
  await clickControl(page, 'continue');
  await rendered(page);
  return waitState(page, { active: true, view: 'stage', level: 1, phase: 'chest',
    busy: false, holding_chest: false, chest_committed: false, chest_progress: 0 });
}

test('Talk Quest first adventure launches word attacks and restores its earned chest exactly once', async ({ page, browserName }, info) => {
  test.setTimeout(180000);
  const errors = recordErrors(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  const map = await openQuest(page, browserName);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  await tapRect(page, map.levels[0], 'First adventure');
  let current = await waitAdventure(page, 1);
  expectWordInterface(current);
  expect(current.total_words).toBe(current.max_hp + 3);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);
  await page.evaluate(() => {
    window.__questWordEvidence = [];
    const status = document.getElementById('quest-status');
    window.__questWordObserver = new MutationObserver(() => {
      const value = JSON.parse(status.dataset.snapshot || '{}');
      window.__questWordEvidence.push({ hp: value.hp, displayed_hp: value.displayed_hp,
        hits: value.hits, projectiles: value.projectiles, phase: value.phase });
    });
    window.__questWordObserver.observe(status, { attributes: true, attributeFilter: ['data-snapshot'] });
  });
  const first = await emitVisibleWord(page, 1, false);
  current = await waitState(page, { hp: first.state.hp - 1, hits: 1 });
  await emit(page, first.target.text, true);
  await page.waitForTimeout(250);
  expect(await snapshot(page)).toMatchObject({ hp: first.state.hp - 1, hits: 1 });
  await page.screenshot({ path: info.outputPath('talk-quest-first-word-flight.png') });
  while (current.phase === 'playing') {
    const { state } = await emitVisibleWord(page, 1);
    current = await waitState(page, { hp: state.hp - 1, hits: state.hits + 1 });
  }
  const evidence = await page.evaluate(() => {
    window.__questWordObserver.disconnect();
    return window.__questWordEvidence;
  });
  expect(evidence.some(value => value.hp < value.displayed_hp && value.projectiles.length > 0)).toBe(true);
  expect(current).toMatchObject({ hp: 0, phase: 'victory' });
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);
  await waitState(page, { phase: 'chest', busy: false });
  const earned = await progress(page);
  expectPrivateProgress(earned);
  expect(earned.run).toMatchObject({ phase: 'chest', hits: first.state.max_hp });
  expect(earned.run.targets).toEqual([]);
  const speechEvidence = await page.evaluate(() => ({ events: window.__questSpeech.events,
    host: window.wordBuddiesHost.speechDiagnostics() }));
  fs.writeFileSync(info.outputPath('quest-speech-evidence.json'), JSON.stringify(speechEvidence, null, 2));
  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'quest');
  await waitState(page, { active: true, view: 'map' });
  await clickControl(page, 'continue');
  await waitState(page, { view: 'stage', phase: 'chest', hp: 0, busy: false });
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  await holdChestUntilRelease(page);
  await waitState(page, { phase: 'complete', busy: false, total_clears: 1 });
  const awarded = await progress(page);
  expectPrivateProgress(awarded);
  expect(awarded.completion_counts).toEqual([1, ...Array(13).fill(0)]);
  expect(awarded.run).toEqual({});
  await page.screenshot({ path: info.outputPath('talk-quest-first-word-reward.png') });
  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'quest');
  const reloaded = await waitState(page, { active: true, view: 'map', total_clears: 1 });
  expect(reloaded).toMatchObject({ completed: [1], chests: ['chest-01'] });
  expect(reloaded.controls.continue.visible).toBe(false);
  expect(await progress(page)).toEqual(awarded);
  expect(errors).toEqual([]);
  await info.attach('talk-quest-first-word-evidence', {
    body: JSON.stringify({ evidence, earned, awarded }, null, 2), contentType: 'application/json'
  });
});

test('Talk Quest completes all fourteen adventures with floating-word speech and restores finite progress', async ({ page, browserName }, info) => {
  test.setTimeout(900000);
  const errors = recordErrors(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  const map = await openQuest(page, browserName);
  expect(map.completed).toEqual([]);
  expect(map.unlocked).toBe(1);
  expect(map.levels).toHaveLength(14);
  expect(map.levels.map(level => level.disabled)).toEqual([false, ...Array(13).fill(true)]);
  expect(map.map_scroll_max).toBe(0);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  await tapRect(page, map.levels[0], 'First adventure');
  let current = await waitAdventure(page, 1);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);
  expectWordInterface(current);
  await page.evaluate(() => {
    window.__questWordEvidence = [];
    const status = document.getElementById('quest-status');
    window.__questWordObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.snapshot || '{}');
      window.__questWordEvidence.push({ hp: state.hp, displayed_hp: state.displayed_hp,
        hits: state.hits, projectiles: state.projectiles, phase: state.phase });
    });
    window.__questWordObserver.observe(status, { attributes: true, attributeFilter: ['data-snapshot'] });
  });
  const first = await emitVisibleWord(page, 1, false);
  current = await waitState(page, { level: 1, hits: 1, hp: first.state.hp - 1 });
  await emit(page, first.target.text, true);
  await page.waitForTimeout(250);
  expect(await snapshot(page), 'The accepted interim and final revision cause only one hit').toMatchObject({ hits: 1, hp: first.state.hp - 1 });
  await expect.poll(async () => (await snapshot(page)).displayed_hp, { intervals: [50] }).toBe(first.state.hp - 1);
  const projectileEvidence = await page.evaluate(() => {
    window.__questWordObserver.disconnect();
    return window.__questWordEvidence;
  });
  expect(projectileEvidence.some(state => state.hp < state.displayed_hp && state.projectiles.length > 0),
    'The word visibly travels before the health meter receives the impact').toBe(true);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);

  const completedEvidence = [];
  let restoredFiniteFlight = false;
  for (let level = 1; level <= 14; level++) {
    if (level > 1) current = await waitAdventure(page, level);
    expectWordInterface(current);
    expect(current.max_hp).toBeGreaterThan(0);
    expect(current.total_words).toBe(current.max_hp + Math.max(3, Math.ceil(current.max_hp / 4)));
    const maxHp = current.max_hp, totalWords = current.total_words;
    if ([1, 8, 13, 14].includes(level)) {
      await page.screenshot({ path: info.outputPath(`talk-quest-words-level-${level}.png`) });
    }
    while (current.phase === 'playing') {
      if (level === 2 && current.hits === 2 && !restoredFiniteFlight) {
        await clickControl(page, 'map');
        await waitState(page, { view: 'map', phase: 'paused', listening: false });
        const saved = await progress(page);
        expectPrivateProgress(saved);
        expect(saved.run).toMatchObject({ level_number: 2, hits: 2, phase: 'playing' });
        await page.reload();
        await enterGame(page);
        await chooseMode(page, 'quest');
        const restoredMap = await waitState(page, { active: true, view: 'map' });
        expect(restoredMap.controls.continue.visible).toBe(true);
        expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
        await clickControl(page, 'continue');
        current = await waitAdventure(page, 2);
        expect(current).toMatchObject({ hits: saved.run.hits, hp: maxHp - saved.run.hits,
          spawned: saved.run.spawned, misses: saved.run.misses });
        expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);
        restoredFiniteFlight = true;
      }
      const starts = await page.evaluate(() => window.__questSpeech.starts);
      const { state: before } = await emitVisibleWord(page, level);
      current = await waitState(page, { level, hits: before.hits + 1, hp: before.hp - 1 });
      expect(current.save_failed).toBe(false);
      expect(current.spawned).toBeLessThanOrEqual(totalWords);
      expect(await page.evaluate(() => window.__questSpeech.starts),
        'Publishing the remaining words never restarts capture').toBe(starts);
    }
    expect(current.phase).toBe('victory');
    expect(current.hp).toBe(0);
    expect(current.completed).toHaveLength(level - 1);
    current = await waitState(page, { level, phase: 'chest', busy: false });
    expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
    const released = await holdChestUntilRelease(page);
    expect(released).toMatchObject({ phase: 'chest', busy: true, chest_committed: true, total_clears: level - 1 });
    expect(released.saved.completion_counts.reduce((total, count) => total + count, 0)).toBe(level - 1);
    current = await waitState(page, { level, phase: 'complete', busy: false });
    expect(current.completed).toEqual(Array.from({ length: level }, (_, index) => index + 1));
    expect(current.unlocked).toBe(Math.min(14, level + 1));
    expect(current.total_clears).toBe(level);
    expect(current.chests).toHaveLength(level);
    expect(current.controls.next.disabled).toBe(false);
    expectPrivateProgress(await progress(page));
    completedEvidence.push({ level, maxHp, totalWords, hits: current.hits, spawned: current.spawned,
      misses: current.misses, completed: current.completed, chests: current.chests });
    await clickControl(page, 'next');
  }
  expect(restoredFiniteFlight).toBe(true);
  const finished = await waitState(page, { active: true, view: 'map', total_clears: 14 });
  expect(finished.chests).toEqual(Array.from({ length: 14 }, (_, index) => `chest-${String(index + 1).padStart(2, '0')}`));
  expect(finished.levels.every(level => !level.disabled)).toBe(true);
  const saved = await progress(page);
  expectPrivateProgress(saved);
  expect(saved.completion_counts).toEqual(Array(14).fill(1));
  expect(saved.run).toEqual({});
  await clickControl(page, 'album');
  await waitState(page, { view: 'album' });
  await page.screenshot({ path: info.outputPath('talk-quest-treasure-shelf.png') });
  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'quest');
  const reloaded = await waitState(page, { active: true, view: 'map', total_clears: 14 });
  expect(reloaded.completed).toEqual(finished.completed);
  expect(reloaded.chests).toEqual(finished.chests);
  expect(reloaded.controls.continue.visible).toBe(false);
  expect(await progress(page)).toEqual(saved);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  expect(errors).toEqual([]);
  await info.attach('talk-quest-word-completion-evidence', {
    body: JSON.stringify({ completedEvidence, projectileEvidence, saved }, null, 2), contentType: 'application/json'
  });
});

test('Talk Quest level gestures own capture, stale callbacks cannot score, and microphone errors have a real retry', async ({ page, browserName }, info) => {
  const errors = recordErrors(page);
  const map = await openQuest(page, browserName);
  await tapRect(page, map.levels[0], 'First adventure');
  await waitAdventure(page, 1);
  const first = await waitWord(page, 1);
  expectWordInterface(first.state);
  const oldSession = await emit(page, 'xylophonically');
  await page.evaluate(({ index, word }) => window.__questSpeech.instances[index].revise(0, word),
    { index: oldSession, word: first.target.text });
  await rendered(page);
  expect(await snapshot(page), 'A finalized wrong occurrence cannot be rewritten into a hit').toMatchObject({ hp: first.state.hp, hits: 0 });
  await clickControl(page, 'map');
  await waitState(page, { view: 'map', phase: 'paused', listening: false });
  await page.evaluate(({ index, word }) => window.__questSpeech.instances[index].emit(word),
    { index: oldSession, word: first.target.text });
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hp: first.state.hp, hits: 0 });
  expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
  await clickControl(page, 'continue');
  await waitAdventure(page, 1);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(2);
  try {
    await setPageHidden(page, true);
    await waitState(page, { phase: 'paused', listening: false });
  } finally {
    await setPageHidden(page, false);
  }
  await rendered(page);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(2);
  await clickControl(page, 'resume');
  await waitAdventure(page, 1);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(3);
  await page.evaluate(() => window.__questSpeech.instances.at(-1).callbacks.error({ error: 'network' }));
  await waitState(page, { listening: false });
  await readyQuestControl(page, 'mic_retry');
  await clickControl(page, 'mic_retry');
  await waitAdventure(page, 1);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(4);
  const target = await waitWord(page, 1);
  await emit(page, target.target.text);
  await waitState(page, { hp: first.state.hp - 1, hits: 1 });
  await page.screenshot({ path: info.outputPath('talk-quest-word-microphone-retry.png') });
  await chooseMode(page, 'match');
  await waitState(page, { active: false, listening: false });
  await page.evaluate(word => window.__questSpeech.instances.at(-1).emit(word), target.target.text);
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hits: 1, total_clears: 0 });
  expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
  expectPrivateProgress(await progress(page));
  expect(errors).toEqual([]);
});

test('finite Talk Quest words finish a missed round and the visible retry creates a fresh encounter', async ({ page, browserName }) => {
  const errors = recordErrors(page);
  const map = await openQuest(page, browserName);
  await tapRect(page, map.levels[0], 'First adventure');
  const first = await waitAdventure(page, 1);
  const oldSession = await page.evaluate(() => window.__questSpeech.instances.length - 1);
  await expect.poll(async () => (await snapshot(page)).phase, { intervals: [250, 500], timeout: 40000 }).toBe('lost');
  const lost = await snapshot(page);
  expect(lost).toMatchObject({ hits: 0, hp: first.max_hp, spawned: first.total_words,
    misses: first.total_words, targets: [], listening: false });
  await readyQuestControl(page, 'retry');
  await clickControl(page, 'retry');
  const retry = await waitAdventure(page, 1);
  expect(retry).toMatchObject({ hits: 0, misses: 0, spawned: 1, hp: first.max_hp });
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(2);
  const live = await waitWord(page, 1);
  await page.evaluate(({ index, word }) => window.__questSpeech.instances[index].emit(word),
    { index: oldSession, word: live.target.text });
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hits: 0, hp: first.max_hp });
  await emit(page, live.target.text);
  await waitState(page, { hits: 1, hp: first.max_hp - 1 });
  expect(errors).toEqual([]);
});

test('Talk Quest phone layouts need no scrolling and unavailable speech exposes no typing controls', async ({ page }, info) => {
  const errors = recordErrors(page);
  await page.setViewportSize({ width: 320, height: 568 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.__questNoSpeech = { microphoneRequests: 0 };
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      window.__questNoSpeech.microphoneRequests++;
      throw new Error('Unavailable browser speech must not request a physical microphone');
    };
  });
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'quest');
  const layouts = [];
  for (const [label, width, height] of [['portrait', 320, 568], ['landscape', 568, 320], ['portrait-return', 320, 568]]) {
    await page.setViewportSize({ width, height });
    await rendered(page);
    await page.waitForTimeout(250);
    let map = await waitState(page, { active: true, view: 'map', map_scroll_max: 0 });
    await visibleQuestControl(page, 'album');
    await visibleQuestControl(page, 'map_previous');
    await visibleQuestControl(page, 'map_next');
    while (!map.controls.map_previous.disabled) {
      const previous = map.map_chapter;
      await clickControl(page, 'map_previous');
      map = await waitState(page, { map_chapter: previous - 1 });
    }
    const chapters = [];
    for (;;) {
      const visible = map.levels.filter(level => level.visible);
      const canvasBounds = await page.locator('#canvas').boundingBox();
      expect(hasFiniteRect(canvasBounds)).toBe(true);
      expect(visible.length).toBeGreaterThan(0);
      for (const rect of visible) {
        expect(hasFiniteRect(rect)).toBe(true);
        expect(typeof rect.compact, 'Adventure geometry reports its artwork layout').toBe('boolean');
        expect(rect.width * canvasBounds.width, 'Every adventure keeps a usable touch width').toBeGreaterThanOrEqual(44);
        expect(rect.height * canvasBounds.height, 'Every adventure keeps a usable touch height').toBeGreaterThanOrEqual(44);
        expect(rect.x).toBeGreaterThanOrEqual(-0.002);
        expect(rect.y).toBeGreaterThanOrEqual(-0.002);
        expect(rect.x + rect.width).toBeLessThanOrEqual(1.002);
        expect(rect.y + rect.height).toBeLessThanOrEqual(1.002);
        if (rect.compact) {
          for (const key of ['caption', 'badge']) {
            const paint = rect[key];
            expect(hasFiniteRect(paint), `The compact adventure ${key} has visible painted bounds`).toBe(true);
            expect(paint.x, `The compact adventure ${key} fits its left edge`).toBeGreaterThanOrEqual(rect.x - 0.002);
            expect(paint.y, `The compact adventure ${key} fits its top edge`).toBeGreaterThanOrEqual(rect.y - 0.002);
            expect(paint.x + paint.width, `The compact adventure ${key} fits its right edge`).toBeLessThanOrEqual(rect.x + rect.width + 0.002);
            expect(paint.y + paint.height, `The compact adventure ${key} fits its bottom edge`).toBeLessThanOrEqual(rect.y + rect.height + 0.002);
          }
        }
      }
      chapters.push({ chapter: map.map_chapter, levels: visible });
      await page.screenshot({ path: info.outputPath(`talk-quest-map-${label}-${map.map_chapter}.png`) });
      const mapCanvas = await page.locator('#canvas').evaluate(canvas => new Promise(resolve =>
        requestAnimationFrame(() => resolve(canvas.toDataURL('image/png').split(',')[1]))));
      fs.writeFileSync(info.outputPath(`talk-quest-map-${label}-${map.map_chapter}-canvas.png`), Buffer.from(mapCanvas, 'base64'));
      if (map.controls.map_next.disabled) break;
      const previous = map.map_chapter;
      await clickControl(page, 'map_next');
      map = await waitState(page, { map_chapter: previous + 1 });
    }
    expect(chapters.flatMap(chapter => chapter.levels)).toHaveLength(14);
    while (!map.controls.map_previous.disabled) {
      const previous = map.map_chapter;
      await clickControl(page, 'map_previous');
      map = await waitState(page, { map_chapter: previous - 1 });
    }
    await tapRect(page, map.levels[0], 'First adventure');
    const stage = await waitAdventure(page, 1, false);
    expectWordInterface(stage);
    expect(stage.reduced_motion).toBe(true);
    expect(stage.feedback).toMatch(/unavailable/i);
    await visibleQuestControl(page, 'map');
    const arena = await visibleQuestControl(page, 'word_arena');
    const retry = await visibleQuestControl(page, 'mic_retry');
    const bounds = await page.locator('#canvas').boundingBox();
    for (const target of (await snapshot(page)).targets) {
      const rect = target.rect;
      expect(rect.width * bounds.width, 'Word artwork and text keep readable space').toBeGreaterThanOrEqual(44);
      expect(rect.height * bounds.height).toBeGreaterThanOrEqual(44);
      expect(rect.x).toBeGreaterThanOrEqual(arena.x - 0.002);
      expect(rect.y).toBeGreaterThanOrEqual(arena.y - 0.002);
      expect(rect.x + rect.width).toBeLessThanOrEqual(arena.x + arena.width + 0.002);
      expect(rect.y + rect.height).toBeLessThanOrEqual(arena.y + arena.height + 0.002);
      expect(overlapArea(rect, retry), 'Retry microphone cannot cover a displayed word').toBe(0);
    }
    const png = await page.screenshot({ path: info.outputPath(`talk-quest-words-${label}.png`) });
    const raw = await page.locator('#canvas').evaluate(canvas => new Promise(resolve =>
      requestAnimationFrame(() => resolve(canvas.toDataURL('image/png').split(',')[1]))));
    const pageColors = await visibleColorCount(page, png);
    const canvasPng = Buffer.from(raw, 'base64'), canvasColors = await visibleColorCount(page, canvasPng);
    fs.writeFileSync(info.outputPath(`talk-quest-words-${label}-canvas.png`), canvasPng);
    expect(canvasColors).toBeGreaterThan(20);
    await info.attach(`talk-quest-words-${label}-canvas`, { body: canvasPng, contentType: 'image/png' });
    if (label !== 'portrait' && pageColors === 1 && process.platform === 'win32' && info.project.use.browserName === 'webkit') {
      info.annotations.push({ type: 'rendering-limitation',
        description: `${label}: Windows WebKit page capture is blank after resize while the native canvas continues rendering.` });
    } else expect(pageColors).toBeGreaterThan(20);
    layouts.push({ label, viewport: page.viewportSize(), chapters, stage, pageColors, canvasColors });
    await clickControl(page, 'map');
    await waitState(page, { view: 'map', listening: false });
  }
  expect(await page.evaluate(() => window.__questNoSpeech.microphoneRequests)).toBe(0);
  expect(errors).toEqual([]);
  await info.attach('talk-quest-fixed-phone-layouts', { body: JSON.stringify(layouts, null, 2), contentType: 'application/json' });
});

test.describe('Talk Quest chest hold lifecycle', () => {
  // Preserve phone geometry while reducing software-renderer fill cost around
  // the short interval between visible release and completion.
  test.use({ deviceScaleFactor: 1 });

  test('release before confirmation or opening cancels, retry works, and backgrounding commits only after release',
    async ({ page, browserName }, info) => {
      test.setTimeout(150000);
      const errors = recordErrors(page);
      const initial = await openPendingChest(page, browserName, 'no-preference');
      expect(initial).toMatchObject({ reduced_motion: false, completed: [], total_clears: 0, chests: [] });
      const unopened = await progress(page);
      expectPrivateProgress(unopened);
      expect(unopened.run).toMatchObject({ level_number: 1, hits: 5, phase: 'chest' });

      await pressChest(page, 250);
      await waitState(page, { phase: 'chest', busy: false, holding_chest: false,
        chest_phase: 'idle', chest_progress: 0, chest_committed: false });
      const shortHold = await page.evaluate(() => window.__questChestHold);
      expect(shortHold.some(state => state.holding_chest), 'A real pointer press starts the hold').toBe(true);
      expect(shortHold.every(state => !state.chest_committed)).toBe(true);
      await page.waitForTimeout(1350);
      expect(await progress(page), 'Releasing before the 1.2-second confirmation cannot award treasure').toEqual(unopened);

      await pressChest(page);
      try {
        await waitState(page, { phase: 'chest', busy: true, holding_chest: true,
          chest_phase: 'gathering', chest_committed: false });
      } finally {
        await page.mouse.up();
      }
      await waitState(page, { phase: 'chest', busy: false, holding_chest: false,
        chest_phase: 'idle', chest_progress: 0, chest_committed: false });
      expect(await progress(page), 'Releasing after confirmation but before visible release still cancels').toEqual(unopened);

      await pressChest(page);
      try {
        await waitState(page, { phase: 'chest', busy: true, chest_phase: 'gathering', chest_committed: false });
        await setPageHidden(page, true);
        const paused = await waitState(page, { phase: 'paused', paused: true, busy: false,
          holding_chest: false, chest_committed: false, chest_progress: 0 });
        expect(paused.controls.resume.visible).toBe(true);
        await page.waitForTimeout(4100);
        expect(await snapshot(page)).toMatchObject({ phase: 'paused', total_clears: 0, completed: [], chests: [] });
        expect(await progress(page), 'Backgrounding before release cancels all pending reward work').toEqual(unopened);
      } finally {
        await page.mouse.up();
        await setPageHidden(page, false);
      }
      await clickControl(page, 'resume');
      await waitState(page, { phase: 'chest', paused: false, busy: false,
        holding_chest: false, chest_committed: false, chest_progress: 0 });

      let awarded;
      await pressChest(page, null, { backgroundOnRelease: true });
      try {
        const released = await waitChestRelease(page);
        expect(released).toMatchObject({ phase: 'chest', busy: true, holding_chest: false,
          chest_committed: true, completed: [], total_clears: 0, chests: [] });
        expect(released.saved, 'Visible release commits the opening before the normal completion saves its reward')
          .toEqual(unopened);
        expect(await page.evaluate(() => window.__questChestBackground),
          'The page hides during the committed opening, before normal completion').toEqual(released);
        const paused = await waitState(page, { phase: 'complete', paused: true, busy: false,
          holding_chest: false, chest_committed: true, total_clears: 1 });
        expect(paused).toMatchObject({ completed: [1], chests: ['chest-01'] });
        expect(paused.controls.resume.visible).toBe(true);
        expect(paused.controls.next.visible).toBe(false);
        awarded = await progress(page);
        expectPrivateProgress(awarded);
        expect(awarded.completion_counts).toEqual([1, ...Array(13).fill(0)]);
        expect(awarded.run).toEqual({});
        await page.waitForTimeout(1900);
        expect(await progress(page), 'Backgrounding after release settles the reward exactly once').toEqual(awarded);
      } finally {
        await page.mouse.up();
        await setPageHidden(page, false);
      }
      await clickControl(page, 'resume');
      const completed = await waitState(page, { phase: 'complete', paused: false, busy: false, total_clears: 1 });
      expect(completed).toMatchObject({ completed: [1], chests: ['chest-01'] });
      expect(completed.controls.next.disabled).toBe(false);
      expect(await progress(page)).toEqual(awarded);
      await rendered(page);
      await page.screenshot({ path: info.outputPath('talk-quest-opened-chest.png'), scale: 'css' });
      const acceptedHold = await page.evaluate(() => {
        window.__questChestObserver.disconnect();
        return window.__questChestHold;
      });
      expect(acceptedHold.some(state => state.chest_phase === 'holding' && state.chest_progress > 0 &&
        state.chest_progress < 0.36), 'The retry visibly charges before opening').toBe(true);
      expect(acceptedHold.some(state => state.chest_phase === 'gathering')).toBe(true);
      await info.attach('talk-quest-chest-lifecycle', { body: JSON.stringify({ shortHold, acceptedHold, awarded }, null, 2),
        contentType: 'application/json' });

      await page.reload();
      await enterGame(page);
      await chooseMode(page, 'quest');
      const reloaded = await waitState(page, { active: true, view: 'map', total_clears: 1 });
      expect(reloaded).toMatchObject({ completed: [1], chests: ['chest-01'] });
      expect(reloaded.controls.continue.visible).toBe(false);
      expect(await progress(page), 'Reloading a settled chest cannot duplicate its reward').toEqual(awarded);
      expect(errors).toEqual([]);
    });

  test('reduced motion still requires a hold and completes once at confirmation', async ({ page, browserName }, info) => {
    test.setTimeout(90000);
    const errors = recordErrors(page);
    const initial = await openPendingChest(page, browserName, 'reduce');
    expect(initial.reduced_motion).toBe(true);
    const unopened = await progress(page);
    await pressChest(page, 250);
    await waitState(page, { phase: 'chest', busy: false, holding_chest: false,
      chest_committed: false, chest_progress: 0 });
    await page.waitForTimeout(1350);
    expect(await progress(page), 'Reduced motion retains the intentional hold gate').toEqual(unopened);

    const released = await holdChestUntilRelease(page);
    expect(released, 'Reduced motion completes immediately at confirmation without an opening tail')
      .toMatchObject({ phase: 'complete', busy: false, holding_chest: false,
        chest_committed: true, total_clears: 1, completed: [1], chests: ['chest-01'] });
    const held = await page.evaluate(() => window.__questChestHold.find(state => state.holding_chest));
    expect(held).toBeTruthy();
    expect(released.at - held.at, 'The reduced-motion reward still waits for the 1.2-second hold')
      .toBeGreaterThanOrEqual(1100);
    const completed = await waitState(page, { phase: 'complete', busy: false, total_clears: 1 });
    expect(completed.controls.next.disabled).toBe(false);
    const awarded = await progress(page);
    expectPrivateProgress(awarded);
    expect(awarded.completion_counts).toEqual([1, ...Array(13).fill(0)]);
    expect(awarded.run).toEqual({});
    await page.waitForTimeout(1900);
    expect(await progress(page), 'Releasing after completion cannot replay a reduced-motion reward').toEqual(awarded);
    await info.attach('talk-quest-reduced-chest-hold', {
      body: JSON.stringify({ held, released, awarded }, null, 2), contentType: 'application/json'
    });
    expect(errors).toEqual([]);
  });
});
