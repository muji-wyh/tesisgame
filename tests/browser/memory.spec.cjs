const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, openGame, resultPoint } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';
const REVEAL = /^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/;
const READY = 'Find a pair.';

function gardenLayout(bounds) {
  const top = 252 + (bounds.height >= 520 ? 28 : 0);
  const width = bounds.width - 24;
  const height = bounds.height - top - 12;
  const wide = (width >= 420 && width >= height * 1.3) || (width >= 392 && height < 460);
  const columns = wide ? 5 : 2;
  const rows = 10 / columns;
  const gap = 8;
  const header = wide ? 44 : 64;
  const gridTop = header + 4;
  return { top, width, height, columns, gap, gridTop, header,
    studyWidth: wide ? 132 : Math.max(132, Math.min(width * 0.4, 176)),
    cardWidth: (width - (columns - 1) * gap) / columns,
    cardHeight: (height - gridTop - (rows - 1) * gap) / rows };
}

async function cardTap(page, index) {
  const layout = gardenLayout(await metrics(page));
  await tap(page,
    12 + index % layout.columns * (layout.cardWidth + layout.gap) + layout.cardWidth / 2,
    layout.top + layout.gridTop + Math.floor(index / layout.columns) * (layout.cardHeight + layout.gap) + layout.cardHeight / 2);
}

async function studyTap(page) {
  const layout = gardenLayout(await metrics(page));
  await tap(page, 12 + layout.width - layout.studyWidth / 2, layout.top + layout.header / 2);
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

async function screenshot(page, testInfo, name) {
  await page.mouse.move(0, 0);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
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

test('five Memory pairs earn one saved piece and Repeat retains the lesson', async ({ page }, testInfo) => {
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
  await screenshot(page, testInfo, 'memory-320-portrait-keyboard');

  await studyTap(page);
  await expect(page.locator('#game-status')).toContainText('Study the garden.');
  await screenshot(page, testInfo, 'memory-320-portrait-study');
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
    await screenshot(page, testInfo, `memory-${size.width}-${size.height}-all-cards`);
  }
  await page.evaluate(() => window.gamepadFixture.connect());
  await pressGamepad(page, 0);
  await expect(page.locator('#selection-status')).toHaveText(`Memory card 10. ${last.kind}: ${last.word}.`);
  await pressGamepad(page, 1);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText(READY);
  await screenshot(page, testInfo, 'memory-xbox-cancelled-card');
  expect(errors).toEqual([]);
});
