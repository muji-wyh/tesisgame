const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, openGame, openRewards,
  memoryMetrics, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek,
  progressRegion, resultPoint, visibleColorCount } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';
const REVEAL = /^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/;
const READY = 'Find a pair.';
const PEEK = 'Release to hide.';
const progress = (page, pairs, attempts) => expect(page.locator('#game-status'))
  .toContainText(`Memory. ${pairs} of 5 pairs grown. ${attempts} attempts.`);

async function cardTap(page, index) {
  const point = memoryPoint(await memoryMetrics(page), index);
  await tap(page, point.x, point.y);
}

async function reveal(page, index) {
  await cardTap(page, index);
  await expect(page.locator('#selection-status')).toHaveText(REVEAL);
  const [, position, kind, word] = (await page.locator('#selection-status').textContent()).match(REVEAL);
  expect(Number(position)).toBe(index + 1);
  return { kind, word };
}

async function cancelCard(page, index) {
  await cardTap(page, index);
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText(READY);
}

async function discoverBoard(page) {
  const board = [];
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

async function medalRecord(page) {
  return page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
}

async function counterSnapshot(page, bounds) {
  const region = progressRegion(bounds, 'memory');
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    x: bounds.x + region.x * bounds.scale, y: bounds.y + region.y * bounds.scale,
    width: region.width * bounds.scale, height: region.height * bounds.scale
  } });
}

async function waitFeedback(page, correct, final = false) {
  await expect(page.locator('#game-status')).toContainText(correct ? 'A new flower!' : 'Try another pair.');
  await expect(page.locator('#game-status')).toContainText(final ? 'You did it!' : READY, { timeout: 2500 });
  await expect(page.locator('#selection-status')).toBeEmpty();
}

async function screenshot(page, testInfo, name, { verifyRendering = false, afterResize = false, held = false } = {}) {
  if (!held) await page.mouse.move(0, 0);
  await rendered(page);
  const png = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  if (!verifyRendering) return png;
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  const canvasPng = Buffer.from(raw, 'base64');
  fs.writeFileSync(testInfo.outputPath(`${name}-canvas.png`), canvasPng);
  const pageColors = await visibleColorCount(page, png), canvasColors = await visibleColorCount(page, canvasPng);
  await testInfo.attach(`${name}-rendering`, { body: JSON.stringify({ pageColors, canvasColors }), contentType: 'application/json' });
  expect(canvasColors, `${name}: the game still draws after resize.`).toBeGreaterThan(20);
  if (afterResize && pageColors === 1 && process.platform === 'win32' && testInfo.project.use.browserName === 'webkit') {
    testInfo.annotations.push({ type: 'rendering-limitation',
      description: `${name}: existing Windows WebKit presentation/capture limitation; the page PNG is blank while the raw canvas renders. Both retained.` });
  } else {
    expect(pageColors, `${name}: the page must show the game.`).toBeGreaterThan(20);
  }
  return png;
}

async function cardChanges(page, bounds, before, after) {
  const rects = Array.from({ length: 10 }, (_, index) => {
    const rect = memoryCardRect(bounds, index);
    // Exclude the rounded 20px focus corners; peek intentionally moves focus to the eye.
    return { x: Math.round(bounds.x + (rect.x + 12) * bounds.scale), y: Math.round(bounds.y + (rect.y + 12) * bounds.scale),
      width: Math.round((rect.width - 24) * bounds.scale), height: Math.round((rect.height - 24) * bounds.scale) };
  });
  return page.evaluate(async ({ sources, rects }) => {
    const images = await Promise.all(sources.map(async source => {
      const image = new Image(); image.src = 'data:image/png;base64,' + source; await image.decode();
      const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, canvas.width, canvas.height);
    }));
    const [a, b] = images;
    return rects.map(rect => {
      let changed = 0;
      for (let y = rect.y; y < rect.y + rect.height; y++) for (let x = rect.x; x < rect.x + rect.width; x++) {
        const ai = (y * a.width + x) * 4, bi = (y * b.width + x) * 4;
        if ([0, 1, 2].reduce((sum, channel) => sum + (a.data[ai + channel] - b.data[bi + channel]) ** 2, 0) > 60 ** 2) changed++;
      }
      return changed / (rect.width * rect.height);
    });
  }, { sources: [before, after].map(image => image.toString('base64')), rects });
}

async function beginMemory(page, options) {
  const errors = await openGame(page, options);
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText(READY);
  return { errors, bounds: await memoryMetrics(page) };
}

test('Memory discoveries survive automatic mistakes, held peek, worlds and More', async ({ page }, testInfo) => {
  const { errors } = await beginMemory(page);
  const saved = await medalRecord(page), board = await discoverBoard(page);
  const word = board.findIndex(card => card.kind === 'Word');
  const wrong = board.findIndex(card => card.kind === 'Picture' && card.word !== board[word].word);
  for (let attempt = 0; attempt < 4; attempt++) {
    expect(await reveal(page, word)).toEqual(board[word]);
    await cardTap(page, wrong);
    await waitFeedback(page, false);
    await progress(page, 0, attempt + 1);
  }
  await reveal(page, word);
  await withMemoryPeek(page, async () => {
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(page, 0, 4);
    await screenshot(page, testInfo, 'memory-held-eye', { held: true });
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await discoverBoard(page), 'Holding the eye and four mistakes preserve every card identity and position.').toEqual(board);
  await reveal(page, wrong);
  const selected = await page.locator('#selection-status').textContent();
  await chooseTheme(page, 4);
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await openRewards(page);
  await page.keyboard.press('Escape');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await cancelCard(page, wrong);
  expect(await reveal(page, word)).toEqual(board[word]);
  await cancelCard(page, word);
  await screenshot(page, testInfo, 'memory-after-peek-and-modal');
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('held Memory eye reveals all ten faces and release hides matched faces without losing progress', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page);
  const saved = await medalRecord(page), board = await discoverBoard(page);
  const words = board.filter(card => card.kind === 'Word').map(card => card.word);
  const matched = words.slice(0, 2).flatMap(word => pairFor(board, word));
  const emptyCounters = await counterSnapshot(page, bounds);
  for (let index = 0; index < 2; index++) {
    const [word, picture] = pairFor(board, words[index]);
    await reveal(page, word);
    await cardTap(page, picture);
    await waitFeedback(page, true);
  }
  await progress(page, 2, 2);
  const grownCounters = await counterSnapshot(page, bounds);
  expect(grownCounters.equals(emptyCounters), 'The numeric progress beside Pip reflects earned Memory matches.').toBe(false);
  const backs = await screenshot(page, testInfo, 'memory-two-pairs-face-down');
  await withMemoryPeek(page, async () => {
    await progress(page, 2, 2);
    expect((await counterSnapshot(page, bounds)).equals(grownCounters), 'Holding the eye cannot reset the visible progress cluster.').toBe(true);
    await expect(page.locator('#selection-status')).toBeEmpty();
    const fronts = await screenshot(page, testInfo, 'memory-all-ten-held', { held: true });
    const changes = await cardChanges(page, bounds, backs, fronts);
    expect(changes.every(value => value > 0.005), 'Every face, including both matched pairs, is revealed only while held.').toBe(true);
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await progress(page, 2, 2);
  expect((await counterSnapshot(page, bounds)).equals(grownCounters)).toBe(true);
  const released = await screenshot(page, testInfo, 'memory-all-faces-hidden-after-release');
  expect(await cardChanges(page, bounds, backs, released), 'Matched green markers remain, but all ten faces return to their backs.').toEqual(Array(10).fill(0));
  for (const index of matched) {
    await cardTap(page, index);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(page, 2, 2);
  }
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory accepts the next card and held eye directly from automatic feedback', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page);
  const saved = await medalRecord(page), board = await discoverBoard(page);
  const pairs = board.filter(card => card.kind === 'Word').map(card => pairFor(board, card.word));
  await reveal(page, pairs[0][0]);
  await cardTap(page, pairs[1][1]);
  await expect(page.locator('#game-status')).toContainText('Try another pair.');
  await reveal(page, pairs[2][0]);
  await progress(page, 0, 1);
  await page.keyboard.press('Space');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await page.keyboard.press('Enter');
  await expect(page.locator('#selection-status')).toHaveText(`Memory card ${pairs[2][0] + 1}. Word: ${board[pairs[2][0]].word}.`);
  await cardTap(page, pairs[2][1]);
  await expect(page.locator('#game-status')).toContainText('A new flower!');
  await withMemoryPeek(page, async () => {
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(page, 1, 2);
    await screenshot(page, testInfo, 'memory-peek-from-correct-feedback', { held: true });
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await progress(page, 1, 2);
  const remaining = pairs.filter((_, index) => index !== 2);
  for (const [index, pair] of remaining.entries()) {
    await reveal(page, pair[0]);
    await cardTap(page, pair[1]);
    await waitFeedback(page, true, index === remaining.length - 1);
  }
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to find a piece!');
  expect(await medalRecord(page)).toBe(saved);
  await screenshot(page, testInfo, 'memory-no-footer-victory');
  expect(await metrics(page)).toEqual({ x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height, scale: bounds.scale });
  expect(errors).toEqual([]);
});

test('five Memory pairs earn one saved piece and New adventure refreshes the lesson', async ({ page }, testInfo) => {
  test.setTimeout(120000);
  const errors = await openGame(page);
  await chooseTheme(page, 0);
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText(READY);
  const before = await medalRecord(page), board = await discoverBoard(page);
  const words = board.filter(card => card.kind === 'Word').map(card => card.word);
  for (let index = 0; index < words.length; index++) {
    const [word, picture] = pairFor(board, words[index]);
    await reveal(page, word);
    await cardTap(page, picture);
    await waitFeedback(page, true, index === 4);
    expect(await medalRecord(page), 'Matching does not bypass the chest claim.').toBe(before);
  }
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try { await expect(page.locator('#game-status')).toContainText('Piece 1 of 3'); }
  finally { await page.mouse.up(); }
  await expect(page.locator('#game-status')).not.toContainText('Tap to place!');
  const claimed = await medalRecord(page);
  expect(claimed).not.toBe(before);
  expect(claimed).toMatch(/"spring-1"\s*:\s*1/);
  await tap(page, chest.x, chest.y);
  await tap(page, chest.x, chest.y);
  expect(await medalRecord(page)).toBe(claimed);
  await screenshot(page, testInfo, 'memory-saved-piece');
  const next = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText(READY);
  const refreshed = await discoverBoard(page);
  expect(refreshed.filter(card => card.kind === 'Word').map(card => card.word).sort()).not.toEqual([...words].sort());
  expect(await medalRecord(page)).toBe(claimed);
  await screenshot(page, testInfo, 'memory-next-adventure-board');
  expect(errors).toEqual([]);
});

test('Memory eye uses keyboard and Xbox down/up and cancels on B, disconnect and resize', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await installGamepad(page);
  const { errors } = await beginMemory(page);
  const board = await discoverBoard(page), saved = await medalRecord(page);
  const focusEye = async () => {
    const eye = peekPoint(await memoryMetrics(page));
    await tap(page, eye.x, eye.y);
    await expect(page.locator('#game-status')).toContainText(READY);
  };
  for (const key of ['Space', 'Enter']) {
    await focusEye();
    await page.keyboard.down(key);
    try {
      await expect(page.locator('#game-status')).toContainText(PEEK);
      await expect(page.locator('#selection-status')).toBeEmpty();
    } finally { await page.keyboard.up(key); }
    await expect(page.locator('#game-status')).toContainText(READY);
  }
  await page.evaluate(() => window.gamepadFixture.connect());
  await focusEye();
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await page.evaluate(() => window.gamepadFixture.button(0, false));
  await expect(page.locator('#game-status')).toContainText(READY);
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText(READY);
  await page.evaluate(async () => {
    window.gamepadFixture.button(0, false);
    await new Promise(resolve => setTimeout(resolve, 120));
  });
  await page.evaluate(() => window.gamepadFixture.button(0, true));
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await page.evaluate(() => window.gamepadFixture.disconnect());
  await expect(page.locator('#game-status')).toContainText(READY);
  await focusEye();
  await page.keyboard.down('Space');
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await page.setViewportSize({ width: 640, height: 320 });
  await rendered(page);
  await page.keyboard.up('Space');
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await reveal(page, 0)).toEqual(board[0]);
  await cancelCard(page, 0);
  expect(await reveal(page, 9)).toEqual(board[9]);
  await cancelCard(page, 9);
  await screenshot(page, testInfo, 'memory-eye-keyboard-controller-resized', { verifyRendering: true, afterResize: true });
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory held peek is cancelled by More and page lifecycle without changing the board', async ({ page }, testInfo) => {
  await installGamepad(page, { connected: true });
  const { errors, bounds } = await beginMemory(page);
  const saved = await medalRecord(page), backs = await screenshot(page, testInfo, 'memory-before-peek-cancel');
  await withMemoryPeek(page, async () => {
    await pressGamepad(page, 3);
    await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  });
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText(READY);
  for (const event of ['visibilitychange', 'pagehide']) {
    const eye = peekPoint(await memoryMetrics(page));
    await tap(page, eye.x, eye.y);
    await page.keyboard.down('Space');
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event(event));
    }, event);
    await page.keyboard.up('Space');
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        delete document.hidden;
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event('pageshow'));
    }, event);
    await expect(page.locator('#game-status')).toContainText(READY);
  }
  const returned = await screenshot(page, testInfo, 'memory-after-peek-cancel');
  expect(await cardChanges(page, bounds, backs, returned)).toEqual(Array(10).fill(0));
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory trusted touch holds the eye and touchcancel restores all backs', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Trusted touch hold/cancel uses Chromium CDP.');
  const { errors, bounds } = await beginMemory(page);
  const saved = await medalRecord(page), eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const backs = await screenshot(page, testInfo, 'memory-before-trusted-eye');
  const client = await page.context().newCDPSession(page);
  let held = false;
  try {
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
    held = true;
    await expect(page.locator('#game-status')).toContainText(PEEK);
    const fronts = await screenshot(page, testInfo, 'memory-trusted-eye-held', { held: true });
    expect((await cardChanges(page, bounds, backs, fronts)).every(value => value > 0.005)).toBe(true);
    const card = memoryPoint(bounds, 0);
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point },
      { id: 2, x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale }] });
    await rendered(page);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    held = false;
    await expect(page.locator('#game-status')).toContainText(READY);
    const returned = await screenshot(page, testInfo, 'memory-trusted-eye-cancelled');
    expect(await cardChanges(page, bounds, backs, returned)).toEqual(Array(10).fill(0));
    expect(await medalRecord(page)).toBe(saved);
    expect(errors).toEqual([]);
  } finally {
    if (held) await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    await client.detach();
  }
});

test('Memory flips face content while its card hitboxes stay fixed', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { reducedMotion: 'no-preference' });
  const board = await discoverBoard(page);
  const index = board.findIndex(card => card.kind === 'Picture');
  const rect = memoryCardRect(bounds, index);
  const clip = { x: Math.round(bounds.x + (rect.x + 8) * bounds.scale), y: Math.round(bounds.y + (rect.y + 8) * bounds.scale),
    width: Math.round((rect.width - 16) * bounds.scale), height: Math.round((rect.height - 16) * bounds.scale) };
  // The colored back starts 2 CSS pixels inside the button; sample only its fixed outer border.
  const edge = { x: Math.floor(bounds.x + rect.x * bounds.scale), y: bounds.y + (rect.y + rect.height / 2 - 12) * bounds.scale,
    width: 1, height: 24 * bounds.scale };
  await page.mouse.move(0, 0);
  await rendered(page);
  const fixedEdge = await page.screenshot({ clip: edge, scale: 'css' });
  const baselineFace = await page.screenshot({ clip, scale: 'css' });
  await page.evaluate(async ({ crop, baseline }) => {
    const source = document.getElementById('canvas'), sourceRect = source.getBoundingClientRect();
    const canvas = document.createElement('canvas'); canvas.width = crop.width; canvas.height = crop.height;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    const visibleWidth = () => {
      const { data } = context.getImageData(0, 0, crop.width, crop.height);
      let left = crop.width, right = -1, opaque = 0;
      for (let y = 0; y < crop.height; y++) for (let x = 0; x < crop.width; x++) {
        const pixel = (y * crop.width + x) * 4;
        opaque += Number(data[pixel + 3] > 245);
        if (data[pixel] + data[pixel + 1] + data[pixel + 2] < 600) {
          left = Math.min(left, x); right = Math.max(right, x);
        }
      }
      return { width: Math.max(0, right - left + 1), opaque };
    };
    const before = new Image();
    before.src = 'data:image/png;base64,' + baseline;
    await before.decode();
    context.drawImage(before, 0, 0);
    const result = window.memoryFlipFrames = { before: visibleWidth().width, widths: [], done: false };
    const until = performance.now() + 900;
    const sample = now => {
      if (document.getElementById('game-status').textContent.includes('Release to hide.')) {
        context.drawImage(source, (crop.x - sourceRect.x) * source.width / sourceRect.width,
          (crop.y - sourceRect.y) * source.height / sourceRect.height,
          crop.width * source.width / sourceRect.width, crop.height * source.height / sourceRect.height,
          0, 0, crop.width, crop.height);
        const frame = visibleWidth();
        if (frame.opaque > crop.width * crop.height * 0.95) result.widths.push(frame.width);
      }
      if (now < until) requestAnimationFrame(sample);
      else result.done = true;
    };
    requestAnimationFrame(sample);
  }, { crop: clip, baseline: baselineFace.toString('base64') });
  await withMemoryPeek(page, async () => {
    await page.waitForFunction(() => window.memoryFlipFrames.done);
    const { before, widths } = await page.evaluate(() => window.memoryFlipFrames);
    await testInfo.attach('visible-flip-widths', { body: JSON.stringify({ before, widths }), contentType: 'application/json' });
    expect(widths.length).toBeGreaterThan(3);
    expect(new Set(widths).size, 'A flip has intermediate content widths, not an instantaneous face swap.').toBeGreaterThan(2);
    const narrowest = Math.min(...widths);
    expect(narrowest, 'The colored back visibly compresses before changing faces.').toBeLessThan(before * 0.8);
    expect(widths.at(-1), 'The revealed artwork expands again after the narrowest frame.').toBeGreaterThan(narrowest);
    expect((await page.screenshot({ clip: edge, scale: 'css' })).equals(fixedEdge), 'Only CardFace transforms; the button edge does not move.').toBe(true);
    await screenshot(page, testInfo, 'memory-flipped-faces-held', { held: true, verifyRendering: true });
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await page.waitForTimeout(65);
  await tap(page, rect.x + 6, rect.y + rect.height / 2);
  await expect(page.locator('#selection-status'), 'The original outer hitbox remains usable during the return flip.').toHaveText(`Memory card ${index + 1}. Picture: ${board[index].word}.`);
  await cancelCard(page, index);
  expect(errors).toEqual([]);
});
