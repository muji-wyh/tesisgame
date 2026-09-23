const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseTheme, chooseMode, rendered, enterGame, openGame, matchWords, discoverMatchCards,
  headerPoint, boardPoint, resultPoint, openRewards, collectionHeaderRect } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const INTRO = 'Find 3 word–picture pairs. Two cards have no match.';
const RETRY = 'Room choices could not be remembered. You can keep practising. Choose Retry saving.';

async function record(page, key = ROOM_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

function visits(saved) {
  return [...(saved.match(/^recent_topic_ids=(.*)$/m)?.[1] || '').matchAll(/"([^"]+)"/g)].map(match => match[1]);
}

function roomFields(saved) {
  return Object.fromEntries([...saved.matchAll(/^(toy|backdrop|favorite|goal_item_id|word_ids|display_word_id)=(.*)$/gm)]
    .map(match => [match[1], match[2]]));
}

async function pieceCount(page) {
  const counts = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return [...counts.matchAll(/:\s*(\d+)/g)].reduce((total, match) => total + Number(match[1]), 0);
}

async function finishMatch(page, won) {
  await chooseMode(page, 'match');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  const bounds = await metrics(page), cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = [...cards].filter(([, pair]) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (let index = 0; index < 3; index++) {
    const [word, pair] = won ? pairs[index] : pairs[0];
    const written = boardPoint(bounds, pair.Word);
    const pictured = boardPoint(bounds, won ? pair.Picture : pairs[1][1].Picture);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText(won ? 'Great match!' : 'Not quite.');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? (won ? 'You did it!' : 'Good try!') : 'Find 3 word');
  }
  return [...cards.keys()];
}

for (const input of ['mouse', 'touch']) {
test(`result review words support ${input} swiping without a scrollbar or accidental speech`, async ({ page, browserName }, testInfo) => {
  test.skip(input === 'touch' && browserName !== 'chromium', 'Trusted touch dragging uses Chromium CDP.');
  await page.setViewportSize({ width: 960, height: 720 });
  const errors = await openGame(page, { mode: 'match' });
  await finishMatch(page, false);
  const bounds = await metrics(page), review = resultPoint(bounds, 'review');
  const point = { x: bounds.x + (review.x + 80) * bounds.scale, y: bounds.y + review.y * bounds.scale };
  await page.touchscreen.tap(point.x, point.y);
  const status = page.locator('#game-status');
  await expect(status).toHaveText(/^[a-z]+\. Look at the picture and say the word\.$/);
  const spoken = await status.textContent(), saved = await record(page, MEDAL_KEY);
  const before = await page.screenshot({ scale: 'css' });
  const client = input === 'touch' ? await page.context().newCDPSession(page) : null;
  try {
    if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
    else { await page.mouse.move(point.x, point.y); await page.mouse.down(); }
    for (let step = 1; step <= 5; step++) {
      const x = point.x - 80 * bounds.scale * step / 5;
      if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, x, y: point.y }] });
      else await page.mouse.move(x, point.y);
      await rendered(page);
    }
    if (input === 'mouse') await page.waitForTimeout(1200);
    await expect(status).toHaveText(spoken);
    const moved = await page.screenshot({ path: testInfo.outputPath(`review-held-${input}.png`), scale: 'css' });
    expect(moved.equals(before)).toBe(false);
  } finally {
    if (client) {
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await client.detach();
    } else await page.mouse.up();
  }
  await expect(status).toHaveText(spoken);
  await page.touchscreen.tap(point.x, point.y);
  await expect(status).toHaveText(/^[a-z]+\. Look at the picture and say the word\.$/);
  await expect(status).not.toHaveText(spoken);
  expect(await record(page, MEDAL_KEY)).toBe(saved);
  await page.screenshot({ path: testInfo.outputPath(`review-after-${input}.png`), scale: 'css' });
  expect(errors).toEqual([]);
});
}

for (const won of [true, false]) {
test(`New adventure starts Match directly after a ${won ? 'win' : 'loss'}`, async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseTheme(page, 5);
  const world = await page.locator('meta[name="theme-color"]').getAttribute('content');
  const originalWords = await matchWords(page), pieces = await pieceCount(page);
  expect((await finishMatch(page, won)).sort()).toEqual([...originalWords].sort());
  const saved = await record(page), previousTopic = visits(saved)[0];
  await page.screenshot({ path: testInfo.outputPath(`result-actions-${won ? 'win' : 'loss'}.png`), scale: 'css' });
  const next = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', world);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath(`direct-next-lesson-${won ? 'win' : 'loss'}.png`), scale: 'css' });
  const nextWords = await matchWords(page);
  expect(nextWords.filter(word => originalWords.includes(word)), 'A direct New adventure rotates the five-word topic without a picker.').toEqual([]);
  const changed = await record(page);
  expect(visits(changed)[0]).not.toBe(previousTopic);
  expect(roomFields(changed), 'Starting a lesson preserves existing room, sticker and gift choices.').toEqual(roomFields(saved));
  expect(await pieceCount(page), 'A win keeps its protected unopened piece; a loss awards nothing.').toBe(pieces + Number(won));
  expect(errors).toEqual([]);
});
}

test('Pip room and Back preserve the Match board and selected card', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const cards = await discoverMatchCards(page), selected = cards[3];
  const point = boardPoint(await metrics(page), selected.index);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  const saved = await record(page), medals = await record(page, MEDAL_KEY);
  await openRewards(page);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  await expect(page.locator('#game-status')).toContainText('Choose a world or age level above');
  await page.screenshot({ path: testInfo.outputPath('more-worlds-preserves-lesson.png'), scale: 'css' });
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  await tap(page, point.x, point.y);
  expect(await discoverMatchCards(page)).toEqual(cards);
  expect(await record(page)).toBe(saved);
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});

test('main-header Retry saving preserves Match selection, world and existing collections', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    if (localStorage.getItem('wordBuddies.playroom') === null) {
      localStorage.setItem('wordBuddies.playroom', '[playroom]\nversion=1\ntoy="toy-spring"\nbackdrop="backdrop-spring"\nfavorite="spring-1"\n\n[stickers]\nword_ids=["cat", "apple"]\ndisplay_word_id="cat"\n');
      localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1":3,"spring-2":3,"spring-3":3}\n');
    }
  });
  const errors = await openGame(page);
  await chooseTheme(page, 0);
  const cards = await discoverMatchCards(page), selected = cards[2];
  const point = boardPoint(await metrics(page), selected.index);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  const saved = await record(page), medals = await record(page, MEDAL_KEY);
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Blocked for journey retry test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreJourneySave = () => { Storage.prototype.setItem = save; };
  });
  await chooseTheme(page, 5);
  await expect(page.locator('#game-status')).toHaveText(RETRY);
  const world = await page.locator('meta[name="theme-color"]').getAttribute('content');
  expect(await record(page)).toBe(saved);
  await page.screenshot({ path: testInfo.outputPath('main-header-journey-retry.png'), scale: 'css' });
  await page.evaluate(() => window.restoreJourneySave());
  const retry = headerPoint(await metrics(page), 'retry');
  await tap(page, retry.x, retry.y);
  await expect(page.locator('#game-status')).not.toContainText('could not be remembered');
  const recovered = await record(page);
  expect(recovered).toContain('preferred_theme_id="space"');
  expect(visits(recovered)).toEqual(visits(saved));
  expect(roomFields(recovered)).toEqual(roomFields(saved));
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  await tap(page, point.x, point.y);
  expect(await discoverMatchCards(page)).toEqual(cards);
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', world);
  const restored = await record(page);
  expect(restored).toContain('preferred_theme_id="space"');
  expect(roomFields(restored)).toEqual(roomFields(saved));
  expect(visits(restored)).toEqual(expect.arrayContaining(visits(saved)));
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  await page.screenshot({ path: testInfo.outputPath('restored-world-without-picker.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
