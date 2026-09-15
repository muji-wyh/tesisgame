const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, swipeLearn,
  progressRegion, headerIconRect, openRewards, observeAudio, visibleColorCount } = require('./game-ui.cjs');

const learningStatus = /^Learn: ([a-z]+)\. Swipe to explore\. Tap the picture to hear\.$/;
const READY = 'Find 3 word';

async function learnWords(page, testInfo, prefix) {
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(learningStatus);
  const second = (await page.locator('#game-status').textContent()).match(learningStatus)[1];
  await swipeLearn(page, 'previous');
  await expect(page.locator('#game-status')).not.toHaveText(`Learn: ${second}. Swipe to explore. Tap the picture to hear.`);
  const words = [];
  for (let index = 0; index < 5; index++) {
    if (index) {
      const previous = await page.locator('#game-status').textContent();
      await swipeLearn(page, 'next');
      await expect(page.locator('#game-status')).not.toHaveText(previous);
    }
    await expect(page.locator('#game-status')).toHaveText(learningStatus);
    const word = (await page.locator('#game-status').textContent()).match(learningStatus)[1];
    words.push(word);
    if (prefix) await page.screenshot({ path: testInfo.outputPath(`${prefix}-${index + 1}-${word}.png`), scale: 'css' });
  }
  expect(words[1]).toBe(second);
  expect(new Set(words).size, 'A lesson teaches five distinct word-picture associations.').toBe(5);
  const last = await page.locator('#game-status').textContent();
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(last);
  return words;
}

async function cardTap(page, index) {
  const point = boardPoint(await metrics(page), index);
  await tap(page, point.x, point.y);
}

async function scanBoard(page) {
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    await cardTap(page, index);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await cardTap(page, index);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  expect(cards.size).toBe(5);
  expect([...cards.values()].filter(card => card.Word !== undefined && card.Picture !== undefined)).toHaveLength(3);
  return cards;
}

async function savedState(page) {
  return page.evaluate(() => ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward']
    .map(key => [key, localStorage.getItem(key)]));
}

async function patch(page, bounds, region) {
  await page.mouse.move(0, 0);
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    x: bounds.x + region.x * bounds.scale, y: bounds.y + region.y * bounds.scale,
    width: region.width * bounds.scale, height: region.height * bounds.scale
  } });
}

async function observeStatuses(page) {
  await page.locator('#game-status').evaluate(node => {
    window.matchStatuses = [];
    new MutationObserver(() => window.matchStatuses.push({ text: node.textContent, time: performance.now() }))
      .observe(node, { childList: true, characterData: true, subtree: true });
  });
}

async function answerPair(page, word, pair, picture = pair.Picture) {
  await cardTap(page, pair.Word);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
  await cardTap(page, picture);
}

test('Learn shows five associations and the lesson survives Match and Memory switches', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const words = await learnWords(page, testInfo, 'learn');
  await chooseMode(page, 'match');
  await expect(page.locator('#game-status')).toContainText(READY);
  expect([...(await scanBoard(page)).keys()].sort()).toEqual([...words].sort());
  await page.screenshot({ path: testInfo.outputPath('same-lesson-match.png'), scale: 'css' });
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText('Memory.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await chooseMode(page, 'learn');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  expect(await learnWords(page, testInfo)).toEqual(words);
  expect(errors).toEqual([]);
});

test('matched word and picture taps pronounce without changing scores, hints or selection', async ({ page }, testInfo) => {
  await observeAudio(page);
  const errors = await openGame(page);
  await chooseMode(page, 'match');
  const bounds = await metrics(page), cards = await scanBoard(page);
  const pairs = [...cards].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  const [word, pair] = pairs[0];
  await answerPair(page, word, pair);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText(READY);
  const saved = await savedState(page);
  const score = await patch(page, bounds, progressRegion(bounds));
  const hints = await patch(page, bounds, headerIconRect(bounds, 'hint'));
  for (const index of [pair.Word, pair.Picture, pair.Word]) {
    const starts = await page.evaluate(() => window.audioObservation.starts);
    await cardTap(page, index);
    await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
    if (await page.evaluate(() => window.audioObservation.available)) {
      await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(starts);
    }
    await expect(page.locator('#selection-status')).toBeEmpty();
    expect((await patch(page, bounds, progressRegion(bounds))).equals(score), 'Replaying an earned pair cannot add another success or mistake.').toBe(true);
    expect((await patch(page, bounds, headerIconRect(bounds, 'hint'))).equals(hints), 'Replaying cannot spend or replenish the hint badge.').toBe(true);
    expect(await savedState(page)).toEqual(saved);
  }
  const [nextWord, nextPair] = pairs[1];
  await cardTap(page, nextPair.Word);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${nextWord}`);
  await cardTap(page, pair.Picture);
  await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
  await expect(page.locator('#selection-status'), 'A replay does not replace an already selected unmatched card.').toHaveText(`Word: ${nextWord}`);
  expect((await patch(page, bounds, progressRegion(bounds))).equals(score)).toBe(true);
  expect(await savedState(page)).toEqual(saved);
  const png = await page.screenshot({ path: testInfo.outputPath('matched-card-replay-full-board.png'), scale: 'css' });
  expect(await visibleColorCount(page, png)).toBeGreaterThan(20);
  expect(await metrics(page)).toEqual(bounds);
  expect(errors).toEqual([]);
});

for (const correct of [true, false]) {
test(`Match ${correct ? 'correct' : 'wrong'} feedback resolves automatically without a footer`, async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 'match');
  const bounds = await metrics(page), cards = await scanBoard(page);
  const pairs = [...cards].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  const [word, pair] = pairs[0];
  await observeStatuses(page);
  await answerPair(page, word, pair, correct ? pair.Picture : pairs[1][1].Picture);
  await expect(page.locator('#game-status')).toContainText(correct ? 'Great match!' : 'Not quite.');
  await expect(page.locator('#game-status')).toContainText(READY, { timeout: 2500 });
  await expect(page.locator('#selection-status')).toBeEmpty();
  const timing = await page.evaluate(() => {
    const feedback = window.matchStatuses.find(entry => /^(Great match!|Not quite\.)/.test(entry.text));
    const ready = window.matchStatuses.find(entry => entry.time >= feedback?.time && entry.text.startsWith('Find 3 word'));
    return feedback && ready ? ready.time - feedback.time : null;
  });
  expect(timing, 'Public announcements must include both feedback and its automatic resolution.').not.toBeNull();
  expect(timing).toBeGreaterThanOrEqual(500);
  expect(timing).toBeLessThan(1800);
  await testInfo.attach('auto-feedback-ms', { body: String(timing), contentType: 'text/plain' });
  await page.screenshot({ path: testInfo.outputPath(`match-${correct ? 'correct' : 'wrong'}-auto-resolved.png`), scale: 'css' });
  expect(await metrics(page)).toEqual(bounds);
  expect(errors).toEqual([]);
});
}

for (const pause of ['More', 'visibilitychange', 'pagehide']) {
test(`Match feedback pauses for ${pause} and resumes on return`, async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 'match');
  const cards = await scanBoard(page), pairs = [...cards].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  await answerPair(page, pairs[0][0], pairs[0][1], pairs[1][1].Picture);
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  if (pause === 'More') {
    await openRewards(page);
  } else {
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event(event));
    }, pause);
  }
  await page.waitForTimeout(950);
  if (pause === 'More') {
    await page.keyboard.press('Escape');
  } else {
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        delete document.hidden;
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event('pageshow'));
    }, pause);
  }
  await expect(page.locator('#game-status'), 'Feedback cannot expire while its view or page is hidden.').toContainText('Not quite.');
  await expect(page.locator('#game-status')).toContainText(READY, { timeout: 2500 });
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.screenshot({ path: testInfo.outputPath(`match-resumed-${pause}.png`), scale: 'css' });
  expect(errors).toEqual([]);
});
}
