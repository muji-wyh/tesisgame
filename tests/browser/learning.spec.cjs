const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint } = require('./game-ui.cjs');

const learningStatus = /^Learn: ([a-z]+)\. Look, read, and press Hear\.$/;
const choiceFeedback = /^(?:Yes! ([a-z]+)\. Press Continue\.|This picture is ([a-z]+)\. Look, listen, then Continue\.)$/;
const initialWrittenPrompt = /^Listen\. No sound\. Choose the picture for ([a-z]+)\.$/;

async function lessonTap(page, control, options) {
  const point = lessonPoint(await metrics(page), control, options);
  await tap(page, point.x, point.y);
  await rendered(page);
}

async function expectFeedbackHear(page, word, options) {
  const canHear = await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext));
  const previous = await page.locator('#game-status').textContent();
  await lessonTap(page, 'hear', options);
  await expect(page.locator('#game-status')).toHaveText(
    canHear ? `${word}. Look at the picture and say the word.` : previous
  );
}

async function learnWords(page, testInfo, prefix) {
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(learningStatus);
  const second = (await page.locator('#game-status').textContent()).match(learningStatus)[1];
  await lessonTap(page, 'previous');
  await expect(page.locator('#game-status')).not.toHaveText(`Learn: ${second}. Look, read, and press Hear.`);
  await expect(page.locator('#game-status')).toHaveText(learningStatus);
  const words = [];
  for (let index = 0; index < 5; index++) {
    if (index) {
      const previous = await page.locator('#game-status').textContent();
      await lessonTap(page, 'next');
      await expect(page.locator('#game-status')).not.toHaveText(previous);
      await expect(page.locator('#game-status')).toHaveText(learningStatus);
    }
    const word = (await page.locator('#game-status').textContent()).match(learningStatus)[1];
    words.push(word);
    if (prefix) {
      await rendered(page);
      await page.screenshot({ path: testInfo.outputPath(`${prefix}-${index + 1}-${word}.png`), scale: 'css' });
    }
  }
  expect(words[1]).toBe(second);
  expect(new Set(words).size, 'A lesson teaches five distinct word–picture associations.').toBe(5);
  const lastStatus = await page.locator('#game-status').textContent();
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(lastStatus);
  return words;
}

async function cardPoint(page, index) {
  const point = boardPoint(await metrics(page), index);
  return [point.x, point.y];
}

async function scanBoard(page) {
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = await cardPoint(page, index);
    await tap(page, ...point);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, ...point);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  expect(cards.size, 'The Match board uses the same five-word lesson.').toBe(5);
  expect([...cards.values()].filter(card => card.Word !== undefined && card.Picture !== undefined)).toHaveLength(3);
  return cards;
}

async function answerChoice(page, index = 0) {
  const bounds = await metrics(page);
  await tap(page, bounds.width * (index ? 0.75 : 0.25), bounds.height - 48);
  await rendered(page);
  await expect(page.locator('#game-status')).toHaveText(choiceFeedback);
  const result = (await page.locator('#game-status').textContent()).match(choiceFeedback);
  return result[1] || result[2];
}

async function feedbackImage(page, path) {
  const bounds = await metrics(page);
  const top = 248 * bounds.scale;
  return page.screenshot({ path, scale: 'css', clip: {
    x: bounds.x, y: bounds.y + top, width: bounds.width * bounds.scale,
    height: bounds.height * bounds.scale - top
  } });
}

async function expectSelfPaced(page, testInfo, name) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const before = await feedbackImage(page, testInfo.outputPath(`${name}.png`));
  // Exceeds the previous automatic 0.7 s feedback interval.
  await page.waitForTimeout(1200);
  const after = await feedbackImage(page);
  expect(after.equals(before), 'The word and picture remain visible until the learner presses Continue.').toBe(true);
  return before;
}

test('Learn shows five associations and the lesson survives Match, Sky and Listen switches', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const words = await learnWords(page, testInfo, 'learn');
  await lessonTap(page, 'action');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  const cards = await scanBoard(page);
  expect([...cards.keys()].sort()).toEqual([...words].sort());
  await page.screenshot({ path: testInfo.outputPath('same-lesson-match.png'), scale: 'css' });
  for (const [mode, name] of [[2, 'sky'], [3, 'listen']]) {
    await chooseMode(page, mode);
    await expect(page.locator('#game-status')).toContainText(mode === 2 ? 'Sky words.' : 'Listen.');
    if (mode === 3 && !await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext))) {
      await expect(page.locator('#game-status')).toHaveText(initialWrittenPrompt);
      expect(words).toContain((await page.locator('#game-status').textContent()).match(initialWrittenPrompt)[1]);
    }
    expect(words).toContain(await answerChoice(page));
    await page.screenshot({ path: testInfo.outputPath(`same-lesson-${name}-feedback.png`), scale: 'css' });
  }
  await chooseMode(page, 0);
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  expect(await learnWords(page, testInfo)).toEqual(words);
  expect(errors).toEqual([]);
});

test('Match keeps wrong and correct word–picture feedback open until Continue', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 1);
  const cards = await scanBoard(page);
  const pairs = [...cards.entries()].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  await tap(page, ...await cardPoint(page, pairs[0][1].Word));
  await tap(page, ...await cardPoint(page, pairs[1][1].Picture));
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  await expectSelfPaced(page, testInfo, 'match-wrong-associations');
  await expectFeedbackHear(page, pairs[0][0], { multiple: true, match: true });
  await lessonTap(page, 'next', { multiple: true, match: true });
  await expectFeedbackHear(page, pairs[1][0], { multiple: true, match: true });
  await page.screenshot({ path: testInfo.outputPath('match-second-association.png'), scale: 'css' });
  await lessonTap(page, 'action', { multiple: true, match: true });
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await tap(page, ...await cardPoint(page, pairs[0][1].Word));
  await tap(page, ...await cardPoint(page, pairs[0][1].Picture));
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expectSelfPaced(page, testInfo, 'match-correct-association');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  expect(errors).toEqual([]);
});

test('Sky feedback waits for Continue and then returns to the picture question', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 2);
  const target = await answerChoice(page);
  const feedback = await expectSelfPaced(page, testInfo, 'sky-self-paced');
  await expectFeedbackHear(page, target, { multiple: false });
  await lessonTap(page, 'action', { multiple: false });
  await expect(page.locator('#game-status')).toHaveText('Choose the matching word.');
  await rendered(page);
  expect((await feedbackImage(page, testInfo.outputPath('sky-after-continue.png'))).equals(feedback)).toBe(false);
  const nextTarget = await answerChoice(page, 1);
  expect(nextTarget).toMatch(/^[a-z]+$/);
  expect(target).toMatch(/^[a-z]+$/);
  expect(errors).toEqual([]);
});

test('Listen remains answerable with a written target when browser sound is unavailable', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
  });
  const errors = await openGame(page);
  const words = await learnWords(page, testInfo);
  await chooseMode(page, 3);
  await expect(page.locator('#game-status')).toHaveText(initialWrittenPrompt);
  expect(words).toContain((await page.locator('#game-status').textContent()).match(initialWrittenPrompt)[1]);
  expect(await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext))).toBe(false);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('listen-written-target-no-sound.png'), scale: 'css' });
  const target = await answerChoice(page);
  await expect(page.locator('#audio-status')).toHaveText('Sound is not available in this browser.');
  expect(words).toContain(target);
  await expectSelfPaced(page, testInfo, `listen-no-sound-feedback-${target}`);
  await lessonTap(page, 'action', { multiple: false });
  const writtenPrompt = /^No sound\. Choose the picture\. ([a-z]+)\.$/;
  await expect(page.locator('#game-status')).toHaveText(writtenPrompt);
  expect(words).toContain((await page.locator('#game-status').textContent()).match(writtenPrompt)[1]);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('listen-no-sound-next-question.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
