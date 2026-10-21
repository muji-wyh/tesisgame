const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, rendered, chooseMode, openModeMenu, headerPoint,
  discoverMatchCards, boardPoint, resultPoint, celebrationState, acceptCelebration
} = require('./game-ui.cjs');
const { startMemory, completeRememberedBoard } = require('./memory-flow.cjs');

// Keep real phone geometry without multiplying the software renderer's fill cost.
test.use({ deviceScaleFactor: 1, video: 'on' });

const MEDAL_KEY = 'wordBuddies.medalProgress';
const phraseState = page => page.locator('#game-status').evaluate(element => JSON.parse(element.dataset.phrase || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));

test.beforeEach(async ({ page }) => {
  // Match's existing dry rounds invoke its pity rule. Memory earns its highest
  // chest by completing the observed board without mistakes.
  await page.addInitScript(key => {
    localStorage.setItem(key, '[medals]\nversion=1\ncounts={}\n[pair_chests]\nversion=1\n' +
      'state={"match":{"dry_rounds":2,"round":{}},"memory":{"dry_rounds":0,"round":{}}}\n');
  }, MEDAL_KEY);
});

async function pieceCount(page) {
  const saved = await page.evaluate(key => localStorage.getItem(key) || '', MEDAL_KEY);
  return [...saved.matchAll(/"[a-z]+-\d+"\s*:\s*(\d+)/g)].reduce((sum, match) => sum + Number(match[1]), 0);
}

async function pressRect(page, control) {
  expect(control?.visible, 'The requested game control is visible.').toBe(true);
  expect(control.disabled, 'The requested game control is enabled.').toBe(false);
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
}

async function completeMatch(page) {
  const cards = await discoverMatchCards(page);
  const words = cards.filter(card => card.kind === 'Word');
  for (const [index, word] of words.entries()) {
    const picture = cards.find(card => card.word === word.word && card.kind === 'Picture');
    for (const card of [word, picture]) {
      const point = boardPoint(await metrics(page), card.index);
      await tap(page, point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    if (index < words.length - 1) await expect(page.locator('#game-status')).toContainText('Find 5 word');
  }
}

async function completeMemory(page) {
  await completeRememberedBoard(page, await startMemory(page));
}

async function visiblePhraseOption(page, id) {
  for (let attempt = 0; attempt < 20; attempt++) {
    const state = await phraseState(page), option = state.options.find(item => item.word_id === id && item.visible);
    expect(option, `The candidate for ${id} is available.`).toBeTruthy();
    const [x, , width] = option.rect, [left, top, bankWidth, bankHeight] = state.bank.rect;
    if (x >= left - 0.5 && x + width <= left + bankWidth + 0.5) return option;
    const bounds = await metrics(page), direction = x < left ? -1 : 1;
    const centerX = bounds.x + (left + bankWidth / 2) * bounds.scale;
    const centerY = bounds.y + (top + bankHeight / 2) * bounds.scale;
    await page.mouse.move(centerX, centerY);
    if (page.context().browser().browserType().name() === 'webkit') {
      await page.mouse.down();
      try { await page.mouse.move(centerX - direction * 80, centerY, { steps: 6 }); }
      finally { await page.mouse.up(); }
    } else await page.mouse.wheel(0, direction * 80);
    await rendered(page);
  }
  throw new Error(`Could not reveal phrase candidate: ${id}`);
}

async function phraseAction(page) {
  await expect.poll(async () => {
    const action = (await phraseState(page)).action;
    return Boolean(action?.visible && !action.disabled);
  }, { message: 'The phrase finishes its feedback before the next action.' }).toBe(true);
  await pressRect(page, (await phraseState(page)).action);
}

async function completePhrase(page) {
  for (let question = 0; question < 3; question++) {
    const state = await phraseState(page);
    expect(state.question_index).toBe(question);
    for (const id of state.target_ids) {
      const before = (await phraseState(page)).answer.length;
      await pressRect(page, await visiblePhraseOption(page, id));
      await expect.poll(async () => (await phraseState(page)).answer.length).toBe(before + 1);
    }
    await phraseAction(page);
    await expect.poll(async () => (await phraseState(page)).completed).toBe(question + 1);
    if (question < 2) {
      await phraseAction(page);
      await expect.poll(async () => (await phraseState(page)).question_index).toBe(question + 1);
    }
  }
}

async function observeSettlement(page) {
  await page.locator('#growth-status').evaluate(element => {
    window.settlementFrames = [];
    const record = () => {
      const state = JSON.parse(element.dataset.view || '{}');
      window.settlementFrames.push({
        dialog: Boolean(state.settlement?.visible), result: Boolean(state.result?.visible),
        background: Boolean(state.background_game?.visible)
      });
    };
    new MutationObserver(record).observe(element, { attributes: true, attributeFilter: ['data-view'] });
    record();
  });
}

async function checkModal(page, info, label) {
  await expect.poll(async () => (await metrics(page)).growth.settlement.visible).toBe(true);
  const bounds = await metrics(page), state = bounds.growth;
  expect(state.background_game.visible, 'The completed game remains rendered behind settlement.').toBe(true);
  expect(bounds.library.visible, 'Settlement does not navigate to another page.').toBe(false);
  const [x, y, width, height] = state.settlement.panel_rect;
  expect(x).toBeGreaterThan(0);
  expect(y).toBeGreaterThan(0);
  expect(x + width).toBeLessThan(bounds.width);
  expect(y + height).toBeLessThan(bounds.height);
  const screenshot = await page.screenshot({ path: info.outputPath(`${label}.png`), scale: 'css' });
  await info.attach(label, { body: screenshot, contentType: 'image/png' });
  return state;
}

for (const mode of ['match', 'memory', 'phrase']) {
  for (const geometry of [
    { name: 'desktop', width: 1366, height: 768 },
    { name: 'phone', width: 393, height: 852 }
  ]) {
    test(`${mode} settles its unopened chest on ${geometry.name} before ${geometry.name === 'desktop' ? 'Play again' : 'Home'}`, async ({ page }, info) => {
      // Complete a real round, cancel an early hold, then leave through a footer action.
      // Software WebGL rendering needs room for the full flow; action waits stay bounded.
      test.setTimeout(180000);
      await page.setViewportSize({ width: geometry.width, height: geometry.height });
      const errors = await openGame(page, { mode });
      await observeSettlement(page);
      const beforePieces = await pieceCount(page), beforeCoins = (await wallet(page)).balance;
      const complete = { match: completeMatch, memory: completeMemory, phrase: completePhrase }[mode];
      await complete(page);
      await acceptCelebration(page);
      let state = await checkModal(page, info, `${mode}-closed-chest-dialog`);
      expect(state.result.visible).toBe(true);
      expect((await celebrationState(page)).active, 'The performance hands off directly to the real chest.').toBe(false);
      expect((await celebrationState(page)).action.visible, 'No intermediary Open chest button is shown.').toBe(false);
      expect(state.result.controls.filter(control => control.visible && control.text === 'Open chest')).toEqual([]);
      expect(state.result.controls.find(control => control.name === 'OpenSettlementChest'))
        .toMatchObject({ visible: true, disabled: false });
      expect(state.result.controls.find(control => control.name === 'SettlementReplay').disabled).toBe(false);
      expect(await pieceCount(page), 'Completing the game never claims the chest early.').toBe(beforePieces);
      expect((await wallet(page)).balance).toBe(beforeCoins);

      const bounds = await metrics(page), coveredHome = headerPoint(bounds, 'mode');
      await tap(page, 4 / bounds.scale, bounds.height / 2);
      await tap(page, coveredHome.x, coveredHome.y);
      await page.keyboard.press('Escape');
      state = (await metrics(page)).growth;
      expect(state.settlement.visible, 'Shade, covered header and Escape cannot leave the settlement.').toBe(true);
      expect((await metrics(page)).library.visible).toBe(false);
      expect(state.visible, 'The underlying word catalog remains closed.').toBe(false);
      for (let step = 0; step < 5; step++) {
        await page.keyboard.press('Tab');
        await expect.poll(async () => (await metrics(page)).growth.result.controls.some(control =>
          control.focused && control.visible && !control.disabled), { message: 'Tab focus stays inside settlement.' }).toBe(true);
      }
      // The chest itself is the interaction target. An incomplete hold must
      // return to rest without claiming either the treasure or its coins.
      await page.emulateMedia({ reducedMotion: 'no-preference' });
      await rendered(page);
      const initialBounds = await metrics(page), initialChest = resultPoint(initialBounds, 'chest');
      await page.mouse.click(initialBounds.x + initialChest.x * initialBounds.scale,
        initialBounds.y + initialChest.y * initialBounds.scale, { delay: 140 });
      await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
      expect(await pieceCount(page), 'Releasing a short hold leaves the chest unclaimed.').toBe(beforePieces);
      expect((await wallet(page)).balance).toBe(beforeCoins);
      if (geometry.name === 'phone') {
        await openModeMenu(page);
        expect((await metrics(page)).library.current, 'An ended round is never labelled Continue.').toBe('');
        expect((await metrics(page)).library.keyboard_focus_visible, 'Pointer Home does not leave a dark keyboard outline.').toBe(false);
      } else {
        const replay = resultPoint(await metrics(page), 'newAdventure');
        await tap(page, replay.x, replay.y);
      }
      await expect.poll(async () => pieceCount(page)).toBe(beforePieces + 1);
      await expect.poll(async () => (await wallet(page)).balance).toBe(beforeCoins + (mode === 'memory' ? 300 : 50));
      const earnedCoins = (await wallet(page)).balance;
      await page.emulateMedia({ reducedMotion: 'reduce' });
      expect((await metrics(page)).growth.settlement.visible).toBe(false);
      if (geometry.name === 'phone') await chooseMode(page, mode);
      await expect.poll(async () => (await metrics(page)).growth.settlement.visible).toBe(false);
      expect((await metrics(page)).library.current).toBe(mode);
      expect((await metrics(page)).growth.background_game.visible).toBe(true);
      if (mode === 'phrase') await expect.poll(async () => (await phraseState(page)).completed).toBe(0);
      else await expect(page.locator('#game-status')).toContainText(mode === 'match' ? 'Find 5 word' : 'Start game');
      expect(await pieceCount(page), 'Departure and reentry cannot claim the previous chest twice.').toBe(beforePieces + 1);
      expect((await wallet(page)).balance).toBe(earnedCoins);

      const frames = await page.evaluate(() => window.settlementFrames);
      expect(frames.some(frame => frame.result), 'The real settlement path was observed.').toBe(true);
      expect(frames.filter(frame => frame.result && (!frame.dialog || !frame.background)),
        'No standalone results page or missing-game transition is rendered.').toEqual([]);
      await info.attach(`${mode}-settlement-transitions`, { body: JSON.stringify(frames, null, 2), contentType: 'application/json' });
      expect(errors).toEqual([]);
    });
  }
}
