const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, openGame, memoryPoint, studyPoint, resultPoint, visibleColorCount } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';
const REVEAL = /^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/;
const READY = 'Find a pair.';

async function cardTap(page, index) {
  const point = memoryPoint(await metrics(page), index);
  await tap(page, point.x, point.y);
}

async function studyTap(page) {
  const point = studyPoint(await metrics(page));
  await tap(page, point.x, point.y);
}
async function reveal(page, index) {
  await cardTap(page, index);
  await expect(page.locator('#selection-status')).toHaveText(REVEAL);
  const [, position, kind, word] = (await page.locator('#selection-status').textContent()).match(REVEAL);
  expect(Number(position), 'The announced position is the card the player tapped.').toBe(index + 1);
  return { kind, word };
}

async function cancelCard(page, index) {
  await cardTap(page, index);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText(READY);
}

async function discoverBoard(page) {
  const board = [];
  // Learn positions through ordinary flips. No private Godot state or hidden-card DOM API.
  for (let index = 0; index < 10; index++) {
    board.push(await reveal(page, index));
    await cancelCard(page, index);
  }
  expect(board.filter(card => card.kind === 'Word')).toHaveLength(5);
  expect(board.filter(card => card.kind === 'Picture')).toHaveLength(5);
  expect(board.filter(card => card.kind === 'Word').map(card => card.word).sort())
    .toEqual(board.filter(card => card.kind === 'Picture').map(card => card.word).sort());
  expect(new Set(board.map(card => card.word)).size).toBe(5);
  return board;
}

function pairFor(board, word) {
  return ['Word', 'Picture'].map(kind => board.findIndex(card => card.word === word && card.kind === kind));
}

async function continueFeedback(page, correct) {
  await expect(page.locator('#game-status')).toContainText(correct ? 'A new flower!' : 'learn these words');
  // Feedback entry focuses its explicit Continue action, as it does in Match.
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toBeEmpty();
}

async function medalRecord(page) {
  return page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
}

async function screenshot(page, testInfo, name, { verifyRendering = false, afterResize = false } = {}) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const png = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  if (!verifyRendering) return;
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  const canvasPng = Buffer.from(raw, 'base64');
  fs.writeFileSync(testInfo.outputPath(`${name}-canvas.png`), canvasPng);
  const pageColors = await visibleColorCount(page, png);
  const canvasColors = await visibleColorCount(page, canvasPng);
  await testInfo.attach(`${name}-rendering`, {
    body: JSON.stringify({ pageColors, canvasColors }), contentType: 'application/json'
  });
  expect(canvasColors, `${name}: the game must still draw after resize.`).toBeGreaterThan(20);
  if (afterResize && pageColors === 1 && process.platform === 'win32' && testInfo.project.use.browserName === 'webkit') {
    // Old and current exports both draw a complete canvas while Windows WebKit's page
    // capture is blank after resize. Preserve both: this does not prove screen presentation.
    testInfo.annotations.push({ type: 'rendering-limitation',
      description: `${name}: existing Windows WebKit presentation/capture limitation; page PNG is blank while raw canvas renders. Both PNGs are retained.` });
  } else {
    expect(pageColors, `${name}: the page screenshot must show the rendered game.`).toBeGreaterThan(20);
  }
}

test('Memory discoveries survive mistakes, Study, theme changes and My rewards', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 4);
  await expect(page.locator('#game-status')).toContainText(READY);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await screenshot(page, testInfo, 'memory-hidden-board');
  const saved = await medalRecord(page);
  const board = await discoverBoard(page);
  const wordIndex = board.findIndex(card => card.kind === 'Word');
  const wrongIndex = board.findIndex(card => card.kind === 'Picture' && card.word !== board[wordIndex].word);

  // Memory exploration must not inherit the other quiz modes' three-mistake loss.
  for (let attempt = 0; attempt < 4; attempt++) {
    expect(await reveal(page, wordIndex)).toEqual(board[wordIndex]);
    await cardTap(page, wrongIndex);
    await expect(page.locator('#game-status')).toContainText('learn these words');
    if (attempt === 0) {
      const feedback = await page.locator('#game-status').textContent();
      await screenshot(page, testInfo, 'memory-mismatch-associations');
      await page.waitForTimeout(1100);
      await expect(page.locator('#game-status')).toHaveText(feedback);
    }
    await continueFeedback(page, false);
    await expect(page.locator('#game-status')).toContainText(READY);
  }

  expect(await reveal(page, wordIndex)).toEqual(board[wordIndex]);
  await studyTap(page);
  await expect(page.locator('#game-status')).toContainText('Study the garden.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await screenshot(page, testInfo, 'memory-study-same-board');
  await cardTap(page, wrongIndex);
  await expect(page.locator('#game-status')).toContainText('Study the garden.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await discoverBoard(page), 'Study and four mistakes preserve every remembered position.').toEqual(board);

  expect(await reveal(page, wrongIndex)).toEqual(board[wrongIndex]);
  const selected = await page.locator('#selection-status').textContent();
  await chooseTheme(page, 4);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  const bounds = await metrics(page);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await page.keyboard.press('Escape');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await cancelCard(page, wrongIndex);
  expect(await reveal(page, wordIndex)).toEqual(board[wordIndex]);
  await cancelCard(page, wordIndex);
  await screenshot(page, testInfo, 'memory-after-study-and-modal');
  expect(await medalRecord(page), 'Exploring and studying never award a fragment.').toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory accepts cards and Study directly from feedback without moving the board', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
  });
  const errors = await openGame(page);
  await chooseMode(page, 4);
  const bounds = await metrics(page), saved = await medalRecord(page);
  const board = await discoverBoard(page);
  const pairs = board.filter(card => card.kind === 'Word').map(card => pairFor(board, card.word));
  const hit = async index => {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y);
  };
  const select = async index => {
    await hit(index);
    await expect(page.locator('#selection-status')).toHaveText(`Memory card ${index + 1}. ${board[index].kind}: ${board[index].word}.`);
  };
  const progress = (pairs, attempts) => expect(page.locator('#game-status')).toContainText(`Memory. ${pairs} of 5 pairs grown. ${attempts} attempts.`);
  const capture = name => screenshot(page, testInfo, name, { verifyRendering: true });
  const study = async (found, attempts, name) => {
    const point = studyPoint(bounds);
    await tap(page, point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Study the garden.');
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(found, attempts);
    await capture(name);
    await hit(pairs[0][0]);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await page.keyboard.press('Enter');
    await expect(page.locator('#game-status')).toContainText(READY);
    await progress(found, attempts);
  };

  await select(pairs[0][0]);
  await hit(pairs[1][1]);
  await expect(page.locator('#game-status')).toContainText('learn these words');
  await progress(0, 1);
  await capture('memory-wrong-feedback');
  // The first tap may reuse either comparison card, with focus following that card.
  await select(pairs[0][0]);
  await progress(0, 1);
  await page.keyboard.press('Space');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(`Memory card ${pairs[0][0] + 1}. Word: ${board[pairs[0][0]].word}.`);
  await progress(0, 1);
  await capture('memory-original-card-selected');
  await hit(pairs[1][1]);
  await progress(0, 2);
  await study(0, 2, 'memory-study-from-wrong');

  await select(pairs[0][0]);
  await hit(pairs[1][1]);
  await progress(0, 3);
  await select(pairs[2][0]);
  await progress(0, 3);
  await capture('memory-third-card-selected');
  await hit(pairs[2][1]);
  await expect(page.locator('#game-status')).toContainText('A new flower!');
  await progress(1, 4);
  const correctFeedback = await page.locator('#game-status').textContent();
  const correctSelection = await page.locator('#selection-status').textContent();
  await hit(pairs[2][0]);
  await expect(page.locator('#game-status')).toHaveText(correctFeedback);
  await expect(page.locator('#selection-status')).toHaveText(correctSelection);
  await study(1, 4, 'memory-study-from-correct');
  const remaining = pairs.filter((_, index) => index !== 2);
  // Return keeps every unmatched card at its original saved input coordinate.
  for (const index of remaining.flat()) {
    await select(index);
    await hit(index);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(1, 4);
  }
  for (const [index, pair] of remaining.entries()) {
    await select(pair[0]);
    await progress(index + 1, index + 4);
    if (index === 1) await capture('memory-next-card-from-correct');
    await hit(pair[1]);
    await expect(page.locator('#game-status')).toContainText('A new flower!');
    await progress(index + 2, index + 5);
  }
  const finalFeedback = await page.locator('#game-status').textContent();
  const finalSelection = await page.locator('#selection-status').textContent();
  await hit(remaining.at(-1)[0]);
  const studyButton = studyPoint(bounds);
  await tap(page, studyButton.x, studyButton.y);
  await expect(page.locator('#game-status')).toHaveText(finalFeedback);
  await expect(page.locator('#selection-status')).toHaveText(finalSelection);
  expect(await medalRecord(page), 'Card input cannot claim the final reward.').toBe(saved);
  await capture('memory-final-feedback');
  await continueFeedback(page, true);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to find a piece!');
  await capture('memory-final-continue');
  expect(await metrics(page)).toEqual(bounds);
  expect(errors).toEqual([]);
});

test('five Memory pairs earn one saved piece and Repeat retains the lesson', async ({ page }, testInfo) => {
  // This victory/claim/replay tour flips both ten-card boards through real input.
  // Windows WebKit traces kept responding but exceeded 90s in multi-project runs.
  test.setTimeout(120000);
  const errors = await openGame(page);
  await chooseTheme(page, 0);
  await chooseMode(page, 4);
  await expect(page.locator('#game-status')).toContainText(READY);
  const before = await medalRecord(page);
  const board = await discoverBoard(page);
  const words = board.filter(card => card.kind === 'Word').map(card => card.word);

  for (let index = 0; index < words.length; index++) {
    const [word, picture] = pairFor(board, words[index]);
    await reveal(page, word);
    await cardTap(page, picture);
    await expect(page.locator('#game-status')).toContainText('A new flower!');
    expect(await medalRecord(page), 'Discovering pairs does not bypass the chest claim.').toBe(before);
    if (index === 0) await screenshot(page, testInfo, 'memory-first-pair-feedback');
    await continueFeedback(page, true);
    if (index < 4) {
      await expect(page.locator('#game-status')).toContainText(READY);
      const status = await page.locator('#game-status').textContent();
      await cardTap(page, word);
      await expect(page.locator('#game-status')).toHaveText(status);
      await expect(page.locator('#selection-status')).toBeEmpty();
      if (index === 1) {
        await studyTap(page);
        await expect(page.locator('#game-status')).toContainText('Study the garden.');
        await screenshot(page, testInfo, 'memory-two-pairs-studied');
        await page.keyboard.press('Enter');
        await expect(page.locator('#game-status')).toContainText(READY);
        await cardTap(page, word);
        await expect(page.locator('#selection-status')).toBeEmpty();
      }
    }
  }
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to find a piece!');
  await screenshot(page, testInfo, 'memory-five-pairs-victory');
  const bounds = await metrics(page);
  const chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toContainText('Piece 1 of 3');
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).not.toContainText('Tap to place!');
  const claimed = await medalRecord(page);
  expect(claimed).not.toBe(before);
  expect(claimed).toMatch(/"spring-1"\s*:\s*1/);
  await tap(page, chest.x, chest.y);
  await tap(page, chest.x, chest.y);
  expect(await medalRecord(page), 'Repeated result input cannot award another piece.').toBe(claimed);
  await screenshot(page, testInfo, 'memory-saved-piece');

  const repeat = resultPoint(await metrics(page), 'repeat');
  await tap(page, repeat.x, repeat.y);
  await expect(page.locator('#game-status')).toContainText(READY);
  const replayed = await discoverBoard(page);
  expect(replayed.filter(card => card.kind === 'Word').map(card => card.word).sort()).toEqual([...words].sort());
  expect(await medalRecord(page)).toBe(claimed);
  await screenshot(page, testInfo, 'memory-repeat-hidden-board');
  expect(errors).toEqual([]);
});

test('Memory cards and Study work by keyboard and remain usable on small layouts', async ({ page }, testInfo) => {
  const capture = (name, afterResize = false) => screenshot(page, testInfo, name, { verifyRendering: true, afterResize });
  await page.setViewportSize({ width: 320, height: 640 });
  await installGamepad(page);
  const errors = await openGame(page);
  await chooseMode(page, 4);
  await expect(page.locator('#game-status')).toContainText(READY);
  const first = await reveal(page, 0);
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Space');
  await expect(page.locator('#selection-status')).toHaveText(`Memory card 1. ${first.kind}: ${first.word}.`);
  await page.keyboard.press('Space');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(/^Memory card 2\. (Word|Picture): [a-z]+\.$/);
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await capture('memory-320-portrait-keyboard');

  await studyTap(page);
  await expect(page.locator('#game-status')).toContainText('Study the garden.');
  await capture('memory-320-portrait-study');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText(READY);
  let last;
  for (const size of [{ width: 320, height: 320 }, { width: 640, height: 320 }]) {
    await page.setViewportSize(size);
    await rendered(page);
    expect(await reveal(page, 0), 'Resizing changes the grid shape without moving its logical cards.').toEqual(first);
    await cancelCard(page, 0);
    last = await reveal(page, 9);
    await cancelCard(page, 9);
    await capture(`memory-${size.width}-${size.height}-all-cards`, true);
  }
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#selection-status')).toHaveText(`Memory card 10. ${last.kind}: ${last.word}.`);
  await pressGamepad(page, 1);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText(READY);
  await capture('memory-xbox-cancelled-card', true);
  expect(errors).toEqual([]);
});
