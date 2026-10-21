const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, openModeMenu, activateLibraryControl, rendered, celebrationState } = require('./game-ui.cjs');
const { memoryState, pressMemoryRect, startObservation, startMatching, memoryCardTap,
  waitForMemoryInput, memoryPairs, completeRememberedBoard } = require('./memory-flow.cjs');

const WALLET_KEY = 'growWithPip.coinWallet.v1';

async function fundPeeks(page, balance) {
  await page.addInitScript(({ key, balance }) => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify({ 'memory-browser-opening-coins': balance })}\n`);
  }, { key: WALLET_KEY, balance });
}

async function wallet(page) {
  return page.evaluate(key => {
    const text = localStorage.getItem(key) || '';
    return { balance: Number(text.match(/^balance\s*=\s*(\d+)/m)?.[1] || 0),
      receipts: JSON.parse(text.match(/^receipts\s*=\s*(\{[\s\S]*\})\s*$/m)?.[1] || '{}') };
  }, WALLET_KEY);
}

async function screenshot(page, info, name) {
  await rendered(page);
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  fs.writeFileSync(info.outputPath(`${name}.png`), Buffer.from(raw, 'base64'));
  fs.writeFileSync(info.outputPath(`${name}.json`), JSON.stringify(await memoryState(page), null, 2));
}

async function observeMemory(page) {
  await page.evaluate(() => {
    const element = document.getElementById('growth-status'), start = performance.now();
    window.memoryFlow = { timeline: [], reactions: [] };
    let previousTier = null;
    const observer = new MutationObserver(() => {
      const state = JSON.parse(element.dataset.view || '{}').memory;
      if (!state) return;
      const at = performance.now() - start;
      window.memoryFlow.timeline.push({ at, state });
      if (previousTier !== null && state.reward.tier < previousTier) {
        const tier = state.reward.tier;
        for (const delay of [0, 120, 360, 650]) setTimeout(() => requestAnimationFrame(() => {
          window.memoryFlow.reactions.push({ at: performance.now() - start, tier,
            state: JSON.parse(element.dataset.view || '{}').memory,
            raw: document.getElementById('canvas').toDataURL('image/png').split(',')[1] });
        }), delay);
      }
      previousTier = state.reward.tier;
    });
    observer.observe(element, { attributes: true, attributeFilter: ['data-view'] });
    window.memoryFlow.stop = () => observer.disconnect();
  });
}

async function saveObservation(page, info) {
  const flow = await page.evaluate(() => { window.memoryFlow.stop(); return window.memoryFlow; });
  for (const [index, frame] of flow.reactions.entries()) {
    const file = `memory-tier-${frame.tier}-${String(index).padStart(2, '0')}-${Math.round(frame.at)}ms.png`;
    fs.writeFileSync(info.outputPath(file), Buffer.from(frame.raw, 'base64'));
    frame.file = file; delete frame.raw;
  }
  delete flow.stop;
  fs.writeFileSync(info.outputPath('memory-flow-timeline.json'), JSON.stringify(flow, null, 2));
  return flow;
}

function expectStableBoard(before, after) {
  expect(after.map(card => card.rect), 'The reserved header never moves the cards').toEqual(before.map(card => card.rect));
}

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`Memory observation, concealed first choice, numbered pairs and anchored tier loss (${reducedMotion})`, async ({ page }, info) => {
    test.setTimeout(180000);
    await page.setViewportSize({ width: 390, height: 844 });
    const errors = await openGame(page, { mode: 'memory', reducedMotion });
    await observeMemory(page);
    const initial = await memoryState(page), initialWallet = await wallet(page);
    expect(initial).toMatchObject({ started: false, mistakes: 0, pairs: 0, reward: { tier: 6, visible: true, animating: false } });
    expect(initial.cards.every(card => !card.face_up && !card.word_id)).toBe(true);
    await screenshot(page, info, 'memory-phone-ready-to-start');
    const board = await startObservation(page), observation = await memoryState(page);
    const first = board.find(card => card.kind === 'word');
    const wrong = board.find(card => card.kind === 'image' && card.word !== first.word);
    await memoryCardTap(page, first.index);
    expect((await memoryState(page)).cards.every(card => !card.selected), 'Observation ignores card clicks').toBe(true);
    expect((await memoryState(page)).attempts).toBe(0);
    await screenshot(page, info, 'memory-phone-observation');
    await startMatching(page);
    await memoryCardTap(page, first.index);
    let state = await memoryState(page);
    expect(state.cards[first.index]).toMatchObject({ selected: true, face_up: false, word_id: '' });
    expect(state.cards.filter(card => card.face_up)).toHaveLength(0);
    await screenshot(page, info, 'memory-phone-first-selection');
    await memoryCardTap(page, first.index);
    expect((await memoryState(page)).cards.every(card => !card.selected)).toBe(true);
    expect((await memoryState(page)).mistakes).toBe(0);
    for (const tier of [5, 4, 3, 2, 1, 0]) {
      await waitForMemoryInput(page);
      await memoryCardTap(page, first.index);
      const bounds = await metrics(page);
      const hit = index => { const [x, y, width, height] = bounds.growth.memory.cards[index].rect;
        return tap(page, x + width / 2, y + height / 2, bounds); };
      await hit(wrong.index);
      // Dispatch the repeat without intervening DOM/audio queries, within the
      // actual feedback window. Inspect the retained publication afterward.
      await hit(first.index);
      await expect.poll(async () => (await memoryState(page)).reward.tier).toBe(tier);
      state = await page.evaluate(tier => window.memoryFlow.timeline.findLast(sample =>
        sample.state.phase === 'feedback' && sample.state.reward.tier === tier)?.state, tier);
      expect(state, 'The real feedback publication retains both faces').toBeTruthy();
      expect(state.mistakes).toBe(6 - tier);
      expect(state.cards[first.index].face_up).toBe(true);
      expect(state.cards[wrong.index].face_up).toBe(true);
      expect(state.cards.filter(card => card.face_up)).toHaveLength(2);
      expect(state.reward.rect).toEqual(observation.reward.rect);
      expectStableBoard(observation.cards, state.cards);
      if (reducedMotion === 'reduce') expect(state.reward).toMatchObject({ animating: false, scale: 1, rotation: 0 });
      expect((await memoryState(page)).mistakes, 'Feedback ignores repeated card input').toBe(6 - tier);
      if (tier === 5) await screenshot(page, info, 'memory-phone-second-selection');
      await waitForMemoryInput(page);
    }
    state = await memoryState(page);
    expect(state.reward).toMatchObject({ tier: 0, grey: true, text: 'No chest', change_count: 6 });
    expect(state.cards.every(card => !card.face_up && !card.word_id)).toBe(true);
    await screenshot(page, info, 'memory-phone-no-chest');
    const pair = memoryPairs(board)[0];
    await memoryCardTap(page, pair[0]); await memoryCardTap(page, pair[1]);
    await expect.poll(async () => (await memoryState(page)).pairs).toBe(1);
    await waitForMemoryInput(page);
    state = await memoryState(page);
    for (const index of pair) expect(state.cards[index]).toMatchObject({ face_up: true, pair: 1, selected: false });
    await screenshot(page, info, 'memory-phone-numbered-pair');
    await completeRememberedBoard(page, board);
    await expect.poll(async () => (await celebrationState(page)).ready, { timeout: 15000 }).toBe(true);
    expect(await celebrationState(page)).toMatchObject({ chest_count: 0, action: { text: 'Play again', visible: true, disabled: false } });
    const flow = await saveObservation(page, info);
    expect([...new Set(flow.timeline.map(sample => sample.state.reward.tier))].sort()).toEqual([0, 1, 2, 3, 4, 5, 6]);
    if (reducedMotion === 'no-preference') expect(flow.timeline.some(sample => sample.state.reward.animating &&
      (sample.state.reward.scale !== 1 || sample.state.reward.rotation !== 0)), 'The actual fixed badge performs its local reaction').toBe(true);
    await openModeMenu(page);
    expect(await wallet(page), 'A zero-tier completion awards no coins').toEqual(initialWallet);
    expect(errors).toEqual([]);
  });
}

test('Memory automatic observation and paid Peek keep real timing, one charge and explicit skip', async ({ page }, info) => {
  test.setTimeout(120000);
  await fundPeeks(page, 100);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const board = await startObservation(page), initial = await memoryState(page);
  expect(initial.peek.countdown).toMatchObject({ phase: 'observation', action: { visible: true, disabled: false } });
  await expect.poll(async () => (await memoryState(page)).peek.remaining, { timeout: 14000 }).toBe(0);
  expect((await memoryState(page)).cards.every(card => !card.face_up && !card.word_id)).toBe(true);
  expect((await wallet(page)).balance).toBe(100);
  const eye = (await metrics(page)).growth.controls.find(control => control.name === 'StudyGarden' && control.visible);
  await pressMemoryRect(page, eye.rect);
  await expect.poll(async () => (await memoryState(page)).peek.count).toBe(2);
  expect((await memoryState(page)).peek).toMatchObject({ duration: 5, next_price: 200, studying: true });
  const paid = await wallet(page);
  expect(paid.balance).toBe(0);
  expect(Object.values(paid.receipts).filter(value => value < 0)).toEqual([-100]);
  await pressMemoryRect(page, eye.rect);
  expect(await wallet(page), 'Repeating the active reveal never debits twice').toEqual(paid);
  const returned = (await memoryState(page)).cards.map(card => ({ index: card.index, kind: card.kind, word: card.word_id }));
  expect(returned).toEqual(board);
  await screenshot(page, info, 'memory-paid-observation');
  await startMatching(page);
  expect((await memoryState(page)).peek.countdown.action.visible).toBe(false);
  await pressMemoryRect(page, eye.rect);
  expect((await memoryState(page)).peek.studying).toBe(false);
  expect(await wallet(page), 'An unaffordable Peek leaves the ledger unchanged').toEqual(paid);
  expect((await memoryState(page)).reward).toMatchObject({ tier: 6, change_count: 0 });
  expect(errors).toEqual([]);
});

test('Memory fixed header fits desktop and short landscape and preserves a pending choice through browsing', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const board = await startObservation(page);
  await startMatching(page);
  await memoryCardTap(page, board[0].index);
  for (const viewport of [{ width: 1280, height: 800 }, { width: 844, height: 390 }, { width: 320, height: 640 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    await expect.poll(async () => Math.round((await metrics(page)).width * (await metrics(page)).scale)).toBe(viewport.width);
    const bounds = await metrics(page), state = await memoryState(page);
    expect(state.reward.tier).toBe(6);
    for (const card of state.cards) {
      const [x, y, width, height] = card.rect;
      expect(width * bounds.scale).toBeGreaterThanOrEqual(43.5);
      expect(height * bounds.scale).toBeGreaterThanOrEqual(43.5);
      expect(x).toBeGreaterThanOrEqual(-0.5);
      expect(y + height).toBeLessThanOrEqual(bounds.height + 0.5);
    }
    expect(state.reward.rect[1] + state.reward.rect[3]).toBeLessThanOrEqual(state.cards[0].rect[1] + 0.5);
    await screenshot(page, info, `memory-layout-${viewport.width}x${viewport.height}`);
  }
  await openModeMenu(page);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'ProfessionalPath');
  await activateLibraryControl(page, 'Career_retail');
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  const resumed = await memoryState(page);
  expect(resumed.cards[board[0].index]).toMatchObject({ selected: true, face_up: false, word_id: '' });
  expect(resumed.reward).toMatchObject({ tier: 6, change_count: 0 });
  expect(errors).toEqual([]);
});
