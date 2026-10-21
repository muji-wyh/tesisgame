const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, enterGame, chooseMode, metrics, tap, openModeMenu, activateLibraryControl, rendered, celebrationState } = require('./game-ui.cjs');
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

async function hoverMemoryCard(page, index) {
  const bounds = await metrics(page), card = bounds.growth.memory.cards[index];
  const [x, y, width, height] = card.rect;
  await page.mouse.move(bounds.x + (x + width / 2) * bounds.scale, bounds.y + (y + height / 2) * bounds.scale);
}

async function expectHighlightedPair(page, indices) {
  await expect.poll(async () => (await memoryState(page)).cards.filter(card => card.pair_highlighted)
    .map(card => card.index).sort((a, b) => a - b),
  { message: 'Only the hovered visible pair has a rendered highlight' }).toEqual([...indices].sort((a, b) => a - b));
}

async function refreshMemory(page, previous, bounds) {
  expect(previous.refresh).toMatchObject({ visible: true, disabled: false });
  const [x, y, width, height] = previous.refresh.rect;
  await tap(page, x + width / 2, y + height / 2, bounds);
  await expect.poll(async () => (await memoryState(page)).round_id).not.toBe(previous.round_id);
  const fresh = await memoryState(page);
  expect(fresh).toMatchObject({ started: false, phase: 'waiting', attempts: 0, mistakes: 0, pairs: 0,
    start: { visible: true, disabled: false }, reward: { tier: 6, change_count: 0, animating: false },
    peek: { studying: false, count: 0, remaining: 0 } });
  expect(fresh.cards.every(card => !card.face_up && !card.selected && !card.selection_visible && !card.pair_highlighted)).toBe(true);
  return fresh;
}

async function observeReplay(page) {
  await page.evaluate(() => {
    const game = document.getElementById('game-status'), growth = document.getElementById('growth-status');
    window.memoryReplayFrames = [];
    const record = () => {
      const celebration = JSON.parse(game.dataset.celebration || '{}'), state = JSON.parse(growth.dataset.view || '{}');
      if (celebration.active && celebration.mode === 'memory') window.memoryReplayFrames.push({
        phase: celebration.stage, round_id: celebration.round_id, replay: celebration.replay });
      else if (state.result?.visible) window.memoryReplayFrames.push({ phase: 'chest',
        replay: state.result.controls.find(control => control.name === 'SettlementReplay') });
    };
    new MutationObserver(record).observe(game, { attributes: true, attributeFilter: ['data-celebration'] });
    new MutationObserver(record).observe(growth, { attributes: true, attributeFilter: ['data-view'] });
  });
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
    expect(state.cards[first.index]).toMatchObject({ selected: true, selection_visible: true, face_up: false, word_id: '' });
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
    expect(await celebrationState(page)).toMatchObject({ chest_count: 0, replay: { text: 'Play again', visible: true, disabled: false } });
    const flow = await saveObservation(page, info);
    expect([...new Set(flow.timeline.map(sample => sample.state.reward.tier))].sort()).toEqual([0, 1, 2, 3, 4, 5, 6]);
    const reactions = flow.timeline.map(sample => sample.state.reward).filter(reward => reward.animating);
    if (reducedMotion === 'no-preference') {
      expect(Math.min(...reactions.map(reward => reward.scale)), 'The chest visibly contracts during its downgrade').toBeLessThan(0.7);
      expect(Math.max(...reactions.map(reward => reward.scale)), 'A loss never enlarges into a celebration bounce').toBeLessThanOrEqual(1);
      expect(Math.min(...reactions.filter(reward => reward.tier === 0).map(reward => reward.scale)),
        'Losing the last chest contracts more deeply than an ordinary downgrade').toBeLessThan(0.3);
      expect(Math.min(...reactions.filter(reward => reward.tier === 0).map(reward => reward.shade)),
        'The final loss visibly dims before settling to grey').toBeLessThan(0.6);
      expect(Math.min(...reactions.map(reward => reward.rotation)), 'The chest spins in reverse during its downgrade').toBeLessThan(-0.5);
      expect(reactions.every(reward => reward.anchor.every((value, index) => Math.abs(value - observation.reward.anchor[index]) < 0.01)),
        'The stronger chest motion stays at the original badge anchor').toBe(true);
      await expect.poll(async () => (await memoryState(page)).reward.animating).toBe(false);
      expect((await memoryState(page)).reward).toMatchObject({ scale: 1, rotation: 0 });
    }
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

test('Memory replaces same-kind choices without revealing answers or charging a mistake', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const board = await startObservation(page);
  await startMatching(page);
  for (const kind of ['word', 'image']) {
    const [first, replacement] = board.filter(card => card.kind === kind);
    await memoryCardTap(page, first.index);
    expect((await memoryState(page)).cards[first.index]).toMatchObject({ selected: true, selection_visible: true, face_up: false });
    await memoryCardTap(page, replacement.index);
    const state = await memoryState(page);
    expect(state).toMatchObject({ phase: 'matching', attempts: 0, mistakes: 0, reward: { tier: 6, change_count: 0 } });
    expect(state.cards[first.index]).toMatchObject({ selected: false, selection_visible: false, face_up: false });
    expect(state.cards[replacement.index]).toMatchObject({ selected: true, selection_visible: true, face_up: false });
    expect(state.cards.every(card => !card.face_up && !card.word_id), 'A same-kind choice cannot expose either answer').toBe(true);
    expect(state.cards.filter(card => card.selection_visible)).toHaveLength(1);
    await screenshot(page, info, `memory-replaced-${kind}-selection`);
    await memoryCardTap(page, replacement.index);
    expect((await memoryState(page)).cards.some(card => card.selection_visible)).toBe(false);
  }
  const pair = memoryPairs(board)[0];
  await memoryCardTap(page, pair[0]);
  await memoryCardTap(page, pair[1]);
  await expect.poll(async () => (await memoryState(page)).pairs).toBe(1);
  expect(await memoryState(page)).toMatchObject({ attempts: 1, mistakes: 0, reward: { tier: 6 } });
  expect(errors).toEqual([]);
});

test('Memory highlights both cards of a visible pair during observation and after matching', async ({ page }, info) => {
  test.skip(Boolean(info.project.use.isMobile), 'Pair hover is a desktop pointer interaction.');
  test.setTimeout(120000);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const board = await startObservation(page), [first, second] = memoryPairs(board);
  for (const index of first) {
    await hoverMemoryCard(page, index);
    await expectHighlightedPair(page, first);
  }
  await hoverMemoryCard(page, second[0]);
  await expectHighlightedPair(page, second);
  expect((await memoryState(page)).peek.studying, 'Pair hover remains available while observing').toBe(true);
  await screenshot(page, info, 'memory-observation-pair-highlight');
  await startMatching(page);
  await hoverMemoryCard(page, first[0]);
  await expectHighlightedPair(page, []);
  expect((await memoryState(page)).cards.every(card => !card.face_up), 'Hovering a concealed card does not disclose its pair').toBe(true);
  for (const pair of [first, second]) {
    await memoryCardTap(page, pair[0]);
    await memoryCardTap(page, pair[1]);
    await waitForMemoryInput(page);
  }
  for (const index of first) {
    await hoverMemoryCard(page, index);
    await expectHighlightedPair(page, first);
  }
  await hoverMemoryCard(page, second[1]);
  await expectHighlightedPair(page, second);
  expect((await memoryState(page)).cards.filter(card => card.pair > 0)).toHaveLength(4);
  await screenshot(page, info, 'memory-matched-pair-highlight');
  await page.mouse.move(1, 1);
  await expectHighlightedPair(page, []);
  expect(errors).toEqual([]);
});

test('Memory refresh starts a clean round from observation, pending selection and match feedback', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const openingWallet = await wallet(page);
  for (const stage of ['observation', 'selection', 'feedback']) {
    const board = await startObservation(page);
    if (stage !== 'observation') {
      await startMatching(page);
      const first = board.find(card => card.kind === 'word');
      await memoryCardTap(page, first.index);
    }
    const bounds = await metrics(page), previous = bounds.growth.memory;
    if (stage === 'observation') expect(previous.peek.studying).toBe(true);
    if (stage === 'selection') expect(previous.cards.filter(card => card.selection_visible)).toHaveLength(1);
    if (stage === 'feedback') {
      const first = board.find(card => card.kind === 'word');
      const wrong = board.find(card => card.kind === 'image' && card.word !== first.word);
      const [rx, ry, rw, rh] = previous.refresh.rect;
      await page.evaluate(rect => {
        const record = event => {
          if (!event.isTrusted || event.target.id !== 'canvas' || event.clientX < rect[0] || event.clientX > rect[2] ||
              event.clientY < rect[1] || event.clientY > rect[3]) return;
          window.memoryRefreshInput = JSON.parse(document.getElementById('growth-status').dataset.view).memory;
          document.removeEventListener('pointerdown', record, true);
        };
        document.addEventListener('pointerdown', record, true);
      }, [bounds.x + rx * bounds.scale, bounds.y + ry * bounds.scale,
        bounds.x + (rx + rw) * bounds.scale, bounds.y + (ry + rh) * bounds.scale]);
      const [x, y, width, height] = previous.cards[wrong.index].rect;
      // Reuse the actual control coordinates. Canvas screenshots and repeated
      // metrics queries can consume the whole 0.7-second feedback window.
      await tap(page, x + width / 2, y + height / 2, bounds);
      await page.waitForFunction(() => JSON.parse(document.getElementById('growth-status').dataset.view).memory.phase === 'feedback');
    }
    const fresh = await refreshMemory(page, previous, bounds);
    if (stage === 'feedback') expect(await page.evaluate(() => window.memoryRefreshInput),
      'The trusted refresh gesture arrives while the mismatch is still showing')
      .toMatchObject({ round_id: previous.round_id, phase: 'feedback', mistakes: 1, reward: { tier: 5 } });
    // Allow the abandoned feedback timer to expire before proving it cannot
    // reveal a card, resolve an attempt, or change the replacement round.
    if (stage === 'feedback') await page.waitForTimeout(850);
    expect(await memoryState(page)).toMatchObject({ round_id: fresh.round_id, started: false, phase: 'waiting',
      attempts: 0, mistakes: 0, pairs: 0, reward: { tier: 6, change_count: 0 } });
  }
  await screenshot(page, info, 'memory-refreshed-round');
  expect(await wallet(page), 'Refreshing unfinished rounds never awards or spends coins').toEqual(openingWallet);
  expect(errors).toEqual([]);
});

test('Memory Play again stays available through settlement and accepts a press across the chest handoff', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'no-preference' });
  await observeReplay(page);
  const openingWallet = await wallet(page);
  const completedIds = [];
  for (const immediate of [false, true]) {
    const board = await startObservation(page), id = (await memoryState(page)).round_id;
    completedIds.push(id);
    await startMatching(page);
    const bounds = await metrics(page);
    await completeRememberedBoard(page, board);
    await expect.poll(() => page.evaluate(() => JSON.parse(document.getElementById('game-status').dataset.celebration).active)).toBe(true);
    if (immediate) {
      const entrance = await page.evaluate(() => JSON.parse(document.getElementById('game-status').dataset.celebration));
      expect(entrance).toMatchObject({ ready: false, round_id: id, chest_count: 1,
        replay: { text: 'Play again', visible: true, disabled: false } });
      const [x, y, width, height] = entrance.replay.rect;
      await page.mouse.move(bounds.x + (x + width / 2) * bounds.scale, bounds.y + (y + height / 2) * bounds.scale);
      await page.mouse.down();
      try {
        // The same control must own this press until release, even after the
        // performance and narration would normally hand off to the real chest.
        await expect.poll(async () => {
          const state = await celebrationState(page);
          return { active: state.active, ready: state.ready, elapsed: state.elapsed,
            narration: state.narration_playing, finished: state.performance_emitted };
        }, { timeout: 15000, message: 'The held replay press survives the automatic chest handoff deadline' })
          .toEqual({ active: true, ready: false, elapsed: entrance.duration, narration: false, finished: false });
        expect((await wallet(page)).receipts[`pair:memory:${id}`], 'Holding Replay has not claimed the chest before release').toBeUndefined();
        await screenshot(page, info, 'memory-play-again-held-through-handoff');
      } finally {
        await page.mouse.up();
      }
    } else {
      await expect.poll(async () => (await metrics(page)).growth.result.visible, { timeout: 15000 }).toBe(true);
      const replay = (await metrics(page)).growth.result.controls.find(control => control.name === 'SettlementReplay');
      expect(replay).toMatchObject({ text: 'Play again', visible: true, disabled: false });
      const frames = await page.evaluate(() => window.memoryReplayFrames);
      expect(frames.filter(frame => frame.round_id === id).length, 'The full performance publishes several replay states').toBeGreaterThan(2);
      expect(frames.some(frame => frame.phase === 'chest')).toBe(true);
      for (const frame of frames) expect(frame.replay, `Play again remains available during ${frame.phase}`)
        .toMatchObject({ text: 'Play again', visible: true, disabled: false });
      await screenshot(page, info, 'memory-chest-with-play-again');
      expect((await wallet(page)).receipts[`pair:memory:${id}`], 'The unopened chest has not been awarded early').toBeUndefined();
      await pressMemoryRect(page, replay.rect);
    }
    await expect.poll(async () => (await memoryState(page)).round_id).not.toBe(id);
    await expect.poll(async () => (await wallet(page)).receipts[`pair:memory:${id}`]).toBe(300);
    expect(await memoryState(page)).toMatchObject({ started: false, mistakes: 0, pairs: 0, reward: { tier: 6 } });
    expect((await metrics(page)).growth.settlement.visible).toBe(false);
  }
  const savedWallet = await wallet(page);
  expect(savedWallet.balance).toBe(openingWallet.balance + 600);
  expect(Object.keys(savedWallet.receipts).filter(id => completedIds.some(round => id === `pair:memory:${round}`))).toHaveLength(2);
  fs.writeFileSync(info.outputPath('memory-replay-timeline.json'), JSON.stringify({ completedIds,
    frames: await page.evaluate(() => window.memoryReplayFrames) }, null, 2));
  await page.reload();
  await enterGame(page, { home: true });
  await chooseMode(page, 'memory');
  expect(await wallet(page), 'Reloading and entering Memory retain both rewards without duplicating them').toEqual(savedWallet);
  expect((await memoryState(page)).start.visible).toBe(true);
  expect((await metrics(page)).growth.settlement.visible).toBe(false);
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
