const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, openGame, openRewards,
  memoryMetrics, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek,
  resultPoint, visibleColorCount } = require('./game-ui.cjs');
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

async function dispatchMemoryTouches(page, type, active, changed) {
  return page.evaluate(({ type, active, changed }) => {
    const canvas = document.getElementById('canvas');
    const contacts = new Map();
    for (const { id, x, y } of [...active, ...changed]) {
      const touch = typeof document.createTouch === 'function'
        ? document.createTouch(window, canvas, id, x + scrollX, y + scrollY, x, y)
        : new Touch({ identifier: id, target: canvas, clientX: x, clientY: y,
          pageX: x + scrollX, pageY: y + scrollY, screenX: x, screenY: y,
          radiusX: 1, radiusY: 1, rotationAngle: 0, force: type === 'touchend' || type === 'touchcancel' ? 0 : 1 });
      contacts.set(id, touch);
    }
    // Older WebKit requires TouchList values. Both paths reach Godot's canvas handler.
    const list = items => typeof document.createTouchList === 'function' ? document.createTouchList(...items) : items;
    const touches = list(active.map(({ id }) => contacts.get(id)));
    const event = new TouchEvent(type, { bubbles: true, cancelable: true, composed: true,
      touches, targetTouches: touches, changedTouches: list(changed.map(({ id }) => contacts.get(id))) });
    canvas.dispatchEvent(event);
    return Array.from(event.changedTouches, touch => touch.identifier);
  }, { type, active, changed });
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

for (const reducedMotion of ['reduce', 'no-preference']) {
test(`Memory matched faces stay visible after feedback, Peek and More (${reducedMotion})`, async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { reducedMotion });
  const saved = await medalRecord(page), board = await discoverBoard(page);
  const words = board.filter(card => card.kind === 'Word').map(card => card.word);
  const matched = words.slice(0, 2).flatMap(word => pairFor(board, word));
  for (let index = 0; index < 2; index++) {
    const [word, picture] = pairFor(board, words[index]);
    await reveal(page, word);
    await cardTap(page, picture);
    await waitFeedback(page, true);
  }
  await progress(page, 2, 2);
  const matchedFaces = await screenshot(page, testInfo, 'memory-two-pairs-face-up', { verifyRendering: true });
  await withMemoryPeek(page, async () => {
    await progress(page, 2, 2);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await page.waitForTimeout(300);
    const fronts = await screenshot(page, testInfo, 'memory-all-ten-held', { held: true });
    const changes = await cardChanges(page, bounds, matchedFaces, fronts);
    for (let index = 0; index < 10; index++) {
      if (matched.includes(index)) {
        expect(changes[index], `Matched card ${index + 1} already shows its face before Peek.`).toBe(0);
      } else {
        expect(changes[index], `Unmatched card ${index + 1} reveals its face during Peek.`).toBeGreaterThan(0.005);
      }
    }
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await progress(page, 2, 2);
  await page.waitForTimeout(300);
  const released = await screenshot(page, testInfo, 'memory-matched-faces-after-release');
  expect(await cardChanges(page, bounds, matchedFaces, released), 'Releasing Peek hides only unmatched faces.').toEqual(Array(10).fill(0));
  for (const index of matched) {
    await cardTap(page, index);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await progress(page, 2, 2);
  }
  const remaining = words.slice(2).map(word => pairFor(board, word));
  await reveal(page, remaining[0][0]);
  await cardTap(page, remaining[1][1]);
  await waitFeedback(page, false);
  await page.waitForTimeout(300);
  const afterMistake = await screenshot(page, testInfo, 'memory-matched-faces-after-mistake');
  expect(await cardChanges(page, bounds, matchedFaces, afterMistake), 'A later mistake hides only the incorrect pair.').toEqual(Array(10).fill(0));
  await openRewards(page);
  await page.keyboard.press('Escape');
  await progress(page, 2, 3);
  await page.waitForTimeout(300);
  const afterMore = await screenshot(page, testInfo, 'memory-matched-faces-after-more', { verifyRendering: true });
  expect(await cardChanges(page, bounds, matchedFaces, afterMore), 'Returning from More preserves the matched faces and all other backs.').toEqual(Array(10).fill(0));
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});
}

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
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
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
  await screenshot(page, testInfo, 'memory-chest-closed');
  const beforeNext = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, beforeNext.x, beforeNext.y);
  await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
  expect(await medalRecord(page), 'A hidden next-adventure action cannot claim or leave the chest.').toBe(before);
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try { await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 }); }
  finally { await page.mouse.up(); }
  await expect(page.locator('#game-status')).not.toContainText(/A new piece!|Medal complete!|Piece \d of 3|Tap to place!/);
  const claimed = await medalRecord(page);
  expect(claimed).not.toBe(before);
  expect(claimed).toMatch(/"spring-1"\s*:\s*1/);
  await tap(page, chest.x, chest.y);
  await tap(page, chest.x, chest.y);
  expect(await medalRecord(page)).toBe(claimed);
  await screenshot(page, testInfo, 'memory-saved-piece');
  const next = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, next.x, next.y);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
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
    await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
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

test('Memory mouse release closes the eye while the pointer stays over it', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page);
  const eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  await page.mouse.move(point.x, point.y);
  for (let index = 0; index < 2; index++) {
    await page.mouse.down();
    await expect(page.locator('#game-status')).toContainText(PEEK);
    if (index === 1) await page.evaluate(() => document.getElementById('canvas').addEventListener('mouseup',
      event => event.stopImmediatePropagation(), { capture: true, once: true }));
    await page.mouse.up();
    await expect(page.locator('#game-status'), 'Mouse-up closes the eye without moving the pointer or blurring it.').toContainText(READY);
  }
  await screenshot(page, testInfo, 'memory-eye-mouse-released', { held: true });
  expect(errors).toEqual([]);
});

test('Memory eye touch taps never leave the cards revealed', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { reducedMotion: 'no-preference' });
  const eye = peekPoint(bounds);
  for (let index = 0; index < 3; index++) {
    await page.touchscreen.tap(bounds.x + eye.x * bounds.scale, bounds.y + eye.y * bounds.scale);
    await expect(page.locator('#game-status')).toContainText(READY);
  }
  await screenshot(page, testInfo, 'memory-eye-touch-released', { held: true });
  expect(errors).toEqual([]);
});

test('Memory eye releases opaque signed and high-bit touch identifiers without another input', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page);
  const saved = await medalRecord(page), eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const backs = await screenshot(page, testInfo, 'memory-before-opaque-touch', { held: true });
  // These synthetic events cover each browser's Touch conversion and the real engine handler.
  // Trusted browser release fallback is covered separately by the CDP hold test below.
  let capturedFronts = false;
  for (const id of [-1, -2, -2147483648, 0x80000001, 0xffffffff, 0]) {
    const contact = { id, ...point };
    for (let repeat = 0; repeat < 2; repeat++) {
      const identifiers = await dispatchMemoryTouches(page, 'touchstart', [contact], [contact]);
      expect(identifiers.map(value => value | 0), 'The browser preserves the requested signed 32-bit touch identity.').toEqual([id | 0]);
      await expect(page.locator('#game-status'), `Identifier ${id}, hold ${repeat + 1} opens the eye.`).toContainText(PEEK);
      if (!capturedFronts) {
        const fronts = await screenshot(page, testInfo, 'memory-opaque-touch-held', { held: true });
        expect((await cardChanges(page, bounds, backs, fronts)).every(value => value > 0.005)).toBe(true);
        capturedFronts = true;
      }
      await dispatchMemoryTouches(page, 'touchend', [], [contact]);
      await expect(page.locator('#game-status'), `Identifier ${id} closes at the same position without a tap, mouse move or blur.`)
        .toContainText(READY);
      await page.waitForTimeout(160);
      await expect(page.locator('#game-status'), 'The released eye stays closed while no input is sent.').toContainText(READY);
    }
  }
  const released = await screenshot(page, testInfo, 'memory-opaque-touch-released', { held: true });
  expect((await cardChanges(page, bounds, backs, released)).every(value => value < 0.005)).toBe(true);
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory signed touch ownership survives another finger and ends on cancel or leaving the eye', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page);
  const eye = peekPoint(bounds), card = memoryPoint(bounds, 0);
  const owner = { id: -1, x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const second = { ...owner, id: -2 };
  const outside = { ...owner, x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale };
  await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await dispatchMemoryTouches(page, 'touchstart', [owner, second], [second]);
  await dispatchMemoryTouches(page, 'touchend', [owner], [second]);
  await expect(page.locator('#game-status'), 'Lifting another signed touch cannot release the owning finger.').toContainText(PEEK);
  await dispatchMemoryTouches(page, 'touchend', [], [owner]);
  await expect(page.locator('#game-status'), 'The original signed owner still closes on release.').toContainText(READY);
  for (const type of ['touchcancel', 'touchmove']) {
    await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await dispatchMemoryTouches(page, type, type === 'touchmove' ? [outside] : [], [type === 'touchmove' ? outside : owner]);
    await expect(page.locator('#game-status'), `${type} closes the signed owning finger's eye.`).toContainText(READY);
    await page.waitForTimeout(160);
    await expect(page.locator('#game-status')).toContainText(READY);
    if (type === 'touchmove') await dispatchMemoryTouches(page, 'touchend', [], [outside]);
  }
  await screenshot(page, testInfo, 'memory-signed-touch-cancelled', { held: true });
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(errors).toEqual([]);
});

test('Memory trusted touch holds the eye and release or cancellation restores all backs', async ({ page, browserName }, testInfo) => {
  test.setTimeout(180000);
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
    await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    held = false;
    await expect(page.locator('#game-status'), 'Lifting the owning finger closes the eye without another screen interaction.').toContainText(READY);
    await rendered(page);
    const released = await screenshot(page, testInfo, 'memory-trusted-eye-released', { held: true });
    // Fractional mobile display scales can rerasterize a few text-edge pixels.
    expect((await cardChanges(page, bounds, backs, released)).every(value => value < 0.005)).toBe(true);
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
    held = true;
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await page.evaluate(() => document.getElementById('canvas').addEventListener('touchend',
      event => event.stopImmediatePropagation(), { capture: true, once: true }));
    await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    held = false;
    await expect(page.locator('#game-status'), 'The page-level release still closes the eye when canvas delivery is interrupted.').toContainText(READY);
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
    held = true;
    await expect(page.locator('#game-status')).toContainText(PEEK);
    const card = memoryPoint(bounds, 0);
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point },
      { id: 2, x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale }] });
    await rendered(page);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await expect(page.locator('#selection-status')).toBeEmpty();
    // CDP touchEnd lifts every point; update the active set to lift only finger 2.
    await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...point }] });
    await expect(page.locator('#game-status'), 'Lifting the second finger cannot release the first finger\'s eye.').toContainText(PEEK);
    await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    held = false;
    await expect(page.locator('#game-status')).toContainText(READY);
    const returned = await screenshot(page, testInfo, 'memory-trusted-eye-cancelled');
    expect((await cardChanges(page, bounds, backs, returned)).every(value => value < 0.005)).toBe(true);
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
