const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const { openGame, enterGame, metrics, tap, rendered, chooseMode, discoverMatchCards,
  boardPoint, memoryPoint, peekPoint } = require('./game-ui.cjs');

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

test('new device starts directly at Lv3 with a complete notebook and separated progress bar', async ({ page }, info) => {
  const errors = await openGame(page);
  await expect(page).toHaveTitle(/Grow with Pip/);
  await expect.poll(async () => (await growth(page)).level).toBe(3);
  expect((await growth(page)).total).toBe(80);
  expect(await page.evaluate(() => ['leaderboardState', 'playroomState'].some(name => name in window.wordBuddiesHost))).toBe(false);
  await expect.poll(async () => Boolean((await view(page)).board)).toBe(true);
  const layout = await view(page);
  const progress = layout.controls.find(control => control.name === 'GrowthProgressButton');
  expect(progress.rect[1] + progress.rect[3]).toBeLessThanOrEqual(layout.board.rect[1] - 2);
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
  const cards = await discoverMatchCards(page);
  expect(cards.filter(card => card.word === 'apple')).toHaveLength(2);
  for (const card of cards.filter(card => card.word === 'apple')) await matchTap(page, card);
  await expect.poll(async () => (await growth(page)).level).toBe(4);
  expect((await growth(page)).streaks.apple).toBe(6);
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
