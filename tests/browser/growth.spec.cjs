const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const { openGame, enterGame, metrics, tap, rendered, chooseMode, discoverMatchCards,
  boardPoint, memoryPoint, peekPoint, pipHeaderRect } = require('./game-ui.cjs');

const KEY = 'growWithPip.growth.v1';
const cohort = words.filter(word => word.min_age === 3);
const growth = page => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const view = page => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.view || '{}'));
const phrase = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.phrase || '{}'));

async function seed(page, level, streaks) {
  const record = `[growth]\nversion=1\nlevel=${level}\nstreaks=${JSON.stringify(streaks)}\nreceipts=[]\n`;
  await page.addInitScript(({ key, record }) => {
    if (!sessionStorage.getItem('growth-test-seeded')) {
      localStorage.setItem(key, record);
      sessionStorage.setItem('growth-test-seeded', 'true');
    }
  }, { key: KEY, record });
}

async function press(page, control) {
  expect(control?.visible).toBe(true);
  if (control.word_id) control = await revealOption(page, control.word_id);
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function revealOption(page, id) {
  for (let attempt = 0; attempt < 24; attempt++) {
    const state = await phrase(page), option = state.options.find(item => item.word_id === id);
    const [x, , width] = option.rect, [left, top, bankWidth, bankHeight] = state.bank.rect;
    if (x >= left - 0.5 && x + width <= left + bankWidth + 0.5) return option;
    const direction = x < left ? -1 : 1, bounds = await metrics(page);
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
  throw new Error(`Could not reveal phrase option ${id}`);
}

async function pressNamed(page, name) {
  await expect.poll(async () => (await view(page)).controls?.some(control => control.name === name)).toBe(true);
  await press(page, (await view(page)).controls.find(control => control.name === name));
}

async function matchTap(page, card) {
  const point = boardPoint(await metrics(page), card.index);
  await tap(page, point.x, point.y);
}

async function expectHeaderBadge(page) {
  const state = await growth(page);
  await expect.poll(async () => {
    const bar = (await view(page)).controls?.find(control => control.name === 'GrowthProgressBar');
    return bar ? bar.value / bar.max_value : -1;
  }, { message: 'The visible growth bar follows current mastered-word progress' }).toBeCloseTo(state.progress, 6);
  const layout = await view(page), bounds = await metrics(page);
  const badge = layout.controls.find(control => control.name === 'GrowthProgressButton');
  const bar = layout.controls.find(control => control.name === 'GrowthProgressBar');
  expect(badge.visible).toBe(true);
  expect(badge.disabled).toBe(false);
  expect(badge.description).toContain(state.label);
  expect(badge.description).toContain(`${state.mastered} of ${state.total} words mastered`);
  expect(bar.visible).toBe(true);
  const [x, y, width, height] = badge.rect;
  const [barX, barY, barWidth, barHeight] = bar.rect;
  expect(x).toBeGreaterThanOrEqual(0);
  expect(y).toBeGreaterThanOrEqual(0);
  expect(x + width).toBeLessThanOrEqual(bounds.width + 0.5);
  expect(y + height).toBeLessThanOrEqual(bounds.height + 0.5);
  expect(width * bounds.scale, 'Growth has a compact header footprint').toBeLessThanOrEqual(180);
  expect(width * bounds.scale).toBeGreaterThanOrEqual(43.5);
  expect(height * bounds.scale).toBeGreaterThanOrEqual(43.5);
  expect(height * bounds.scale).toBeLessThanOrEqual(56.5);
  expect(barWidth).toBeGreaterThan(0);
  expect(barHeight).toBeGreaterThan(0);
  expect(barX).toBeGreaterThanOrEqual(x - 0.5);
  expect(barY).toBeGreaterThanOrEqual(y - 0.5);
  expect(barX + barWidth, 'The progress track stays inside its entry button').toBeLessThanOrEqual(x + width + 0.5);
  expect(barY + barHeight).toBeLessThanOrEqual(y + height + 0.5);
  const pip = pipHeaderRect(bounds);
  expect(Math.abs(y + height / 2 - pip.y - pip.height / 2) * bounds.scale,
    'Pip and the growth badge share the same header row').toBeLessThanOrEqual(2);
  expect(pip.x + pip.width).toBeLessThan(x);
  return { state, layout, badge, bar, bounds };
}

test('new device starts directly at Lv3 with a compact header badge and complete notebook', async ({ page }, info) => {
  const errors = await openGame(page);
  await expect(page).toHaveTitle(/Grow with Pip/);
  await expect.poll(async () => (await growth(page)).level).toBe(3);
  expect((await growth(page)).total).toBe(80);
  expect(await page.evaluate(() => ['leaderboardState', 'playroomState'].some(name => name in window.wordBuddiesHost))).toBe(false);
  await expect.poll(async () => Boolean((await view(page)).board)).toBe(true);
  const { layout, badge, bounds } = await expectHeaderBadge(page);
  expect(badge.rect[1] + badge.rect[3]).toBeLessThanOrEqual(layout.board.rect[1] - 2);
  expect((layout.board.rect[1] - badge.rect[1] - badge.rect[3]) * bounds.scale,
    'The board begins below the single header without a separate growth row').toBeLessThanOrEqual(18);
  await page.screenshot({ path: info.outputPath('growth-board.png'), scale: 'css' });
  await pressNamed(page, 'GrowthProgressButton');
  await expect.poll(async () => (await view(page)).catalog?.word_count).toBe(80);
  expect((await view(page)).catalog.visible_word_ids).toContain('a');
  await pressNamed(page, 'GrowthAge4');
  await expect.poll(async () => (await view(page)).catalog?.age_band).toBe('4');
  expect((await view(page)).notice).toContain('Preview only');
  expect((await growth(page)).level).toBe(3);
  await page.screenshot({ path: info.outputPath('growth-notebook.png'), scale: 'css' });
  await pressNamed(page, 'GrowthBack');
  await expect.poll(async () => (await view(page)).visible).toBe(false);
  expect(errors).toEqual([]);
});

test('partial growth remains accessible in every mode on desktop, narrow, and short screens', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop-chromium', 'The responsive matrix runs once; device projects retain the real growth-flow coverage.');
  test.setTimeout(240000);
  const mastered = cohort.slice(0, 20);
  await seed(page, 3, Object.fromEntries(mastered.map(word => [word.id, 6])));
  const errors = await openGame(page);
  const cases = [
    { mode: 'match', width: 1366, height: 768 },
    { mode: 'memory', width: 390, height: 844 },
    { mode: 'phrase', width: 320, height: 640 },
    { mode: 'pop', width: 844, height: 390 },
    { mode: 'jelly', width: 1366, height: 768 },
    { mode: 'jelly', width: 390, height: 844 },
    { mode: 'jelly', width: 844, height: 390 },
    { mode: 'match', width: 320, height: 568 }
  ];
  for (const item of cases) {
    await page.setViewportSize({ width: item.width, height: item.height });
    await rendered(page);
    await chooseMode(page, item.mode);
    await expect.poll(async () => (await metrics(page)).library.current).toBe(item.mode);
    const badge = await expectHeaderBadge(page);
    expect(badge.state.level).toBe(3);
    expect(badge.state.mastered).toBe(mastered.length);
    expect(badge.state.progress).toBeCloseTo(mastered.length / cohort.length, 6);
    await page.screenshot({ path: info.outputPath(`growth-header-${item.mode}-${item.width}x${item.height}.png`), scale: 'css' });
    await pressNamed(page, 'GrowthProgressButton');
    await expect.poll(async () => (await view(page)).catalog?.age_band).toBe('3');
    expect((await view(page)).catalog.word_count).toBe(cohort.length);
    await pressNamed(page, 'GrowthBack');
    await expect.poll(async () => (await view(page)).visible).toBe(false);
    expect((await metrics(page)).library.current).toBe(item.mode);
  }
  expect(errors).toEqual([]);
});

test('real Match and Memory answers persist shared streaks while peek is neutral', async ({ page }) => {
  test.setTimeout(150000);
  await seed(page, 3, Object.fromEntries(cohort.map(word => [word.id, 2])));
  const errors = await openGame(page);
  const cards = await discoverMatchCards(page);
  const picture = cards.find(card => card.kind === 'Picture');
  const wrong = cards.find(card => card.kind === 'Word' && card.word !== picture.word);
  await matchTap(page, picture);
  await matchTap(page, wrong);
  await expect.poll(async () => (await growth(page)).streaks[picture.word] || 0).toBe(0);
  expect((await growth(page)).streaks[wrong.word] || 0).toBe(0);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await matchTap(page, picture);
  await matchTap(page, cards.find(card => card.word === picture.word && card.kind === 'Word'));
  await expect.poll(async () => (await growth(page)).streaks[picture.word]).toBe(1);
  await chooseMode(page, 'memory');
  const before = (await growth(page)).streaks;
  const peek = peekPoint(await metrics(page)), bounds = await metrics(page);
  await page.mouse.move(bounds.x + peek.x * bounds.scale, bounds.y + peek.y * bounds.scale);
  await page.mouse.down();
  await expect(page.locator('#game-status')).toContainText('Release to hide.');
  await page.mouse.up();
  await expect(page.locator('#game-status')).toContainText('Find a pair.');
  expect((await growth(page)).streaks).toEqual(before);
  const memory = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(await metrics(page), index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    const [, kind, word] = (await page.locator('#selection-status').textContent()).match(/\. (Word|Picture): ([a-z]+)\.$/);
    memory.push({ index, kind, word });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const target = memory[0].word;
  for (const card of memory.filter(card => card.word === target)) {
    const point = memoryPoint(await metrics(page), card.index);
    await tap(page, point.x, point.y);
  }
  await expect.poll(async () => (await growth(page)).streaks[target]).toBe((before[target] || 0) + 1);
  const saved = (await growth(page)).streaks;
  await page.reload();
  await enterGame(page);
  await expect.poll(async () => (await growth(page)).streaks).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Phrase Builder credits all target words after correction and keeps unused distractors neutral', async ({ page }) => {
  await seed(page, 3, Object.fromEntries(cohort.map(word => [word.id, 2])));
  const errors = await openGame(page, { mode: 'phrase' });
  await expect.poll(async () => (await phrase(page)).phase).toBe('building');
  const initial = await phrase(page);
  const target = initial.target_ids;
  const distractor = initial.options.find(option => !target.includes(option.word_id));
  expect(distractor).toBeTruthy();
  for (const id of [...target.slice(0, -1), distractor.word_id]) {
    await press(page, (await phrase(page)).options.find(option => option.word_id === id));
  }
  await press(page, (await phrase(page)).action);
  await expect.poll(async () => {
    const state = await growth(page);
    return target.map(id => state.streaks[id] || 0);
  }).toEqual(target.map(() => 0));
  await expect.poll(async () => (await phrase(page)).phase).toBe('building');
  while ((await phrase(page)).answer.length) await press(page, (await phrase(page)).answers[0]);
  for (const id of target) await press(page, (await phrase(page)).options.find(option => option.word_id === id));
  await press(page, (await phrase(page)).action);
  await expect.poll(async () => {
    const state = await growth(page);
    return target.map(id => state.streaks[id] || 0);
  }).toEqual(target.map(() => 1));
  expect((await growth(page)).streaks[distractor.word_id] || 0).toBe(0);
  const unused = initial.options.find(option => !target.includes(option.word_id) && option.word_id !== distractor.word_id);
  if (unused) expect((await growth(page)).streaks[unused.word_id]).toBe(2);
  expect(errors).toEqual([]);
});

test('sixth real success promotes Pip and the new level survives a reload', async ({ page }, info) => {
  const streaks = Object.fromEntries(cohort.map(word => [word.id, word.id === 'apple' ? 5 : 6]));
  await seed(page, 3, streaks);
  const errors = await openGame(page);
  const before = await expectHeaderBadge(page);
  expect(before.state.mastered).toBe(cohort.length - 1);
  expect(before.bar.value / before.bar.max_value).toBeCloseTo((cohort.length - 1) / cohort.length, 6);
  const cards = await discoverMatchCards(page);
  expect(cards.filter(card => card.word === 'apple')).toHaveLength(2);
  for (const card of cards.filter(card => card.word === 'apple')) await matchTap(page, card);
  await expect.poll(async () => (await growth(page)).level).toBe(4);
  expect((await growth(page)).streaks.apple).toBe(6);
  const promoted = await expectHeaderBadge(page);
  expect(promoted.state.level).toBe(4);
  expect(promoted.state.total).toBe(words.filter(word => word.min_age === 4).length);
  expect(promoted.state.mastered).toBe(0);
  expect(promoted.bar.value).toBe(0);
  await pressNamed(page, 'GrowthProgressButton');
  await expect.poll(async () => (await view(page)).catalog?.age_band).toBe('4');
  await page.screenshot({ path: info.outputPath('level-four.png'), scale: 'css' });
  await page.reload();
  await enterGame(page);
  await expect.poll(async () => (await growth(page)).level).toBe(4);
  expect(errors).toEqual([]);
});

test('two open game tabs preserve each other\'s completed word practice', async ({ page, context }, info) => {
  test.setTimeout(150000);
  test.skip(info.project.name !== 'desktop-chromium', 'Cross-tab storage is covered once on desktop.');
  await seed(page, 3, Object.fromEntries(cohort.map(word => [word.id, 2])));
  const errors = await openGame(page);
  const other = await context.newPage();
  try {
    const otherErrors = await openGame(other);
    await page.bringToFront();
    const firstCards = await discoverMatchCards(page);
    await other.bringToFront();
    const secondCards = await discoverMatchCards(other);
    const firstWord = firstCards[0].word;
    const secondWord = secondCards.find(card => card.word !== firstWord).word;
    await page.bringToFront();
    for (const card of firstCards.filter(card => card.word === firstWord)) await matchTap(page, card);
    await expect.poll(async () => (await growth(page)).streaks[firstWord]).toBe(3);
    await other.bringToFront();
    for (const card of secondCards.filter(card => card.word === secondWord)) await matchTap(other, card);
    await expect.poll(async () => (await growth(other)).streaks[secondWord]).toBe(3);
    expect((await growth(other)).streaks[firstWord]).toBe(3);
    await page.bringToFront();
    await page.reload();
    await enterGame(page);
    await expect.poll(async () => (await growth(page)).streaks[firstWord]).toBe(3);
    expect((await growth(page)).streaks[secondWord]).toBe(3);
    expect([...errors, ...otherErrors]).toEqual([]);
  } finally {
    await other.close();
  }
});
