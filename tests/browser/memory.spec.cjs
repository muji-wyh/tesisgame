const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, rendered, openGame, openRewards,
  memoryMetrics, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek,
  resultPoint, visibleColorCount, acceptCelebration } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';
const WALLET_KEY = 'growWithPip.coinWallet.v1';
const REVEAL = /^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/;
const READY = 'Find a pair.';
const PEEK = /Cards hide in \d+ seconds\./;
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
  await expect(page.locator('#game-status')).toContainText(final ? /You did it!|Round complete/ : READY, { timeout: 2500 });
  await expect(page.locator('#selection-status')).toBeEmpty();
  if (final) await acceptCelebration(page);
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

async function beginMemory(page, { coinBalance, ...options } = {}) {
  if (coinBalance !== undefined) await page.addInitScript(({ key, balance }) => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify(balance ? { 'memory-browser-opening-coins': balance } : {})}\n`);
  }, { key: WALLET_KEY, balance: coinBalance });
  const errors = await openGame(page, options);
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText(READY);
  return { errors, bounds: await memoryMetrics(page) };
}

async function memoryPeek(page) {
  return (await metrics(page)).growth.memory.peek;
}

async function memoryWallet(page) {
  return page.evaluate(key => {
    const text = localStorage.getItem(key);
    return { text, balance: Number(text.match(/^balance\s*=\s*(\d+)/m)[1]),
      receipts: JSON.parse(text.match(/^receipts\s*=\s*(\{[\s\S]*\})\s*$/m)[1]) };
  }, WALLET_KEY);
}

async function displayedCoins(page) {
  return page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
}

function expectPeekPriceLayout(bounds, price) {
  const peek = bounds.growth.memory.peek;
  const eye = bounds.growth.controls.find(control => control.name === 'StudyGarden' && control.visible);
  expect(eye, 'The eye control is visible in the game header').toBeTruthy();
  expect(eye.disabled, 'Even an unaffordable eye accepts a press for feedback').toBe(false);
  expect(peek.next_price).toBe(price);
  if (price === 0) expect(peek.price_text).toMatch(/^(?:0|free)$/i);
  else expect(peek.price_text).toBe(String(price));
  const inside = (rect, outer, label) => {
    expect(rect.every(Number.isFinite), label).toBe(true);
    expect(rect[2], label).toBeGreaterThan(0);
    expect(rect[3], label).toBeGreaterThan(0);
    expect(rect[0], label).toBeGreaterThanOrEqual(outer[0] - 0.5);
    expect(rect[1], label).toBeGreaterThanOrEqual(outer[1] - 0.5);
    expect(rect[0] + rect[2], label).toBeLessThanOrEqual(outer[0] + outer[2] + 0.5);
    expect(rect[1] + rect[3], label).toBeLessThanOrEqual(outer[1] + outer[3] + 0.5);
  };
  inside(eye.rect, [0, 0, bounds.width, bounds.height], 'The eye remains inside the viewport');
  inside(peek.price_rect, eye.rect, 'The whole price fits within the eye control');
  expect(eye.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43.5);
  expect(eye.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43.5);
  expect(peek.price_rect[3] * bounds.scale, 'The price retains readable height at this display scale').toBeGreaterThanOrEqual(11.5);
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

test('Memory eye charges 0, 100, 200, 300, 300 once per timed reveal and resets only for a fresh round', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  const { errors } = await beginMemory(page, { coinBalance: 900, reducedMotion: 'reduce' });
  await expect.poll(async () => Boolean((await metrics(page)).growth.memory?.peek)).toBe(true);
  const opening = await memoryPeek(page), openingWallet = await memoryWallet(page);
  expect(opening).toMatchObject({ count: 0, next_price: 0, studying: false });
  expect(opening.round_id).toBeTruthy();
  expect(openingWallet.balance).toBe(900);
  const ledger = [];
  let balance = 900;
  for (const [index, price] of [0, 100, 200, 300, 300].entries()) {
    const bounds = await memoryMetrics(page), eye = peekPoint(bounds);
    expectPeekPriceLayout(bounds, price);
    const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
    const before = await memoryWallet(page);
    await page.mouse.click(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await expect.poll(async () => (await memoryPeek(page)).count).toBe(index + 1);
    balance -= price;
    await expect.poll(async () => (await memoryWallet(page)).balance).toBe(balance);
    await expect.poll(async () => (await displayedCoins(page)).balance).toBe(balance);
    const paid = await memoryWallet(page), state = await memoryPeek(page);
    const receipts = Object.entries(paid.receipts).filter(([id]) => !Object.hasOwn(before.receipts, id));
    expect(receipts.map(([, amount]) => amount), 'Each successful paid reveal saves exactly its advertised debit')
      .toEqual(price ? [-price] : []);
    expect(Object.entries(before.receipts).every(([id, amount]) => paid.receipts[id] === amount),
      'Peeking preserves every earlier wallet receipt').toBe(true);
    expect(state).toMatchObject({ count: index + 1, next_price: Math.min((index + 1) * 100, 300),
      studying: true, round_id: opening.round_id, duration: index === 0 ? 10 : 5 });
    await page.mouse.click(point.x, point.y);
    await page.mouse.click(point.x, point.y);
    await page.mouse.move(point.x + 1, point.y + 1);
    await rendered(page);
    expect(await memoryWallet(page), 'Repeated clicks during one countdown cannot charge twice').toEqual(paid);
    const repeated = await memoryPeek(page);
    expect(repeated, 'Repeated clicks cannot increase the counter or change the price')
      .toMatchObject({ count: state.count, next_price: state.next_price, duration: state.duration });
    expect(repeated.remaining, 'Repeated clicks cannot extend the reveal').toBeLessThanOrEqual(state.remaining);
    await progress(page, 0, 0);
    if (index === 3) await screenshot(page, testInfo, 'memory-priced-eye-300-countdown', { verifyRendering: true });
    ledger.push({ ordinal: index + 1, price, balance, peek: state, receipts });
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(READY);
    await expect.poll(async () => (await memoryPeek(page)).studying).toBe(false);
  }
  const emptyWallet = await memoryWallet(page);
  expect(emptyWallet.balance).toBe(0);
  expect(Object.values(emptyWallet.receipts).filter(amount => amount < 0).sort((a, b) => a - b)).toEqual([-300, -300, -200, -100]);
  const card = await reveal(page, 0), selection = await page.locator('#selection-status').textContent();
  const bounds = await memoryMetrics(page), eye = peekPoint(bounds);
  expectPeekPriceLayout(bounds, 300);
  await page.mouse.move(bounds.x + eye.x * bounds.scale, bounds.y + eye.y * bounds.scale);
  const beforeDenied = await screenshot(page, testInfo, 'memory-before-unaffordable-eye', { held: true });
  const beforePeek = await memoryPeek(page);
  const eyePosition = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  await page.mouse.click(eyePosition.x, eyePosition.y);
  await page.mouse.click(eyePosition.x, eyePosition.y);
  await rendered(page);
  await expect(page.locator('#selection-status'), 'A declined reveal preserves the already selected card').toHaveText(selection);
  expect(await memoryPeek(page)).toMatchObject({ count: beforePeek.count, next_price: 300,
    studying: false, round_id: opening.round_id });
  expect(await memoryWallet(page), 'Insufficient coins cannot alter balance or receipts').toEqual(emptyWallet);
  expect((await displayedCoins(page)).balance, 'The visible coin counter also stays at zero').toBe(0);
  await expect(page.locator('#game-status')).toContainText('Not enough coins. This reveal costs 300 coins.');
  const refused = await screenshot(page, testInfo, 'memory-unaffordable-eye-keeps-cards', { held: true, verifyRendering: true });
  expect((await cardChanges(page, bounds, beforeDenied, refused)).every(value => value < 0.005),
    'The declined reveal never exposes another card face').toBe(true);
  await expect(page.locator('#selection-status')).toHaveText(selection);
  await cancelCard(page, 0);
  await progress(page, 0, 0);
  expect(await reveal(page, 0), 'The declined purchase does not replace the board').toEqual(card);
  await cancelCard(page, 0);
  await chooseMode(page, 'match');
  await chooseMode(page, 'memory');
  await expect(page.locator('#game-status')).toContainText(READY);
  await expect.poll(async () => (await memoryPeek(page)).round_id).not.toBe(opening.round_id);
  expect(await memoryPeek(page)).toMatchObject({ count: 0, next_price: 0, studying: false });
  expectPeekPriceLayout(await memoryMetrics(page), 0);
  await withMemoryPeek(page, async () => {
    expect(await memoryPeek(page)).toMatchObject({ count: 1, next_price: 100, studying: true });
    expect(await memoryWallet(page), 'A new round grants its first reveal even with an empty wallet').toEqual(emptyWallet);
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await screenshot(page, testInfo, 'memory-new-round-eye-free-used', { verifyRendering: true });
  await testInfo.attach('memory-eye-price-ledger.json', { body: JSON.stringify(ledger, null, 2), contentType: 'application/json' });
  expect(errors).toEqual([]);
});

for (const reducedMotion of ['no-preference', 'reduce']) {
test(`Memory timed eye counts down 10s then 5s with animated text and progress (${reducedMotion})`, async ({ page }, testInfo) => {
  test.setTimeout(120000);
  const { errors, bounds } = await beginMemory(page, { reducedMotion, coinBalance: 100 });
  const saved = await medalRecord(page), backs = await screenshot(page, testInfo, 'memory-countdown-before');
  const eye = peekPoint(bounds);
  const activate = async () => page.touchscreen.tap(bounds.x + eye.x * bounds.scale, bounds.y + eye.y * bounds.scale);
  const captured = [];
  const captureStage = async name => {
    const state = await memoryPeek(page);
    expect(state.studying, `${name} is captured before real timer expiry`).toBe(true);
    // Keep the live countdown path light on phones. Canvas readback, image
    // decoding and pixel comparisons happen only after both timers expire.
    const png = await page.screenshot({ path: testInfo.outputPath(`memory-countdown-${name}.png`), scale: 'css' });
    captured.push({ name, state, png });
    return png;
  };
  await activate();
  await expect(page.locator('#game-status')).toContainText(PEEK);
  const first = await memoryPeek(page);
  expect(first).toMatchObject({ count: 1, duration: 10, next_price: 100, studying: true });
  expect(first.remaining).toBeGreaterThan(8);
  const firstWallet = await memoryWallet(page);
  expect(firstWallet.balance).toBe(100);
  await page.waitForTimeout(300);
  const fronts = await captureStage('first-start');
  await activate();
  await activate();
  await page.keyboard.press('Tab');
  await page.mouse.move(0, 0);
  const repeated = await memoryPeek(page);
  expect(repeated).toMatchObject({ count: 1, duration: 10, next_price: 100, studying: true });
  expect(repeated.remaining, 'Repeated taps and focus changes never restart the timer').toBeLessThan(first.remaining);
  expect(await memoryWallet(page), 'The active countdown cannot buy another reveal').toEqual(firstWallet);
  await expect.poll(async () => (await memoryPeek(page)).remaining, { intervals: [100], timeout: 8000 }).toBeLessThanOrEqual(5.5);
  await captureStage('first-middle');
  await expect.poll(async () => (await memoryPeek(page)).remaining, { intervals: [100], timeout: 6000 }).toBeLessThanOrEqual(2.7);
  await captureStage('first-final-seconds');
  await expect.poll(async () => (await memoryPeek(page)).studying, { intervals: [100], timeout: 5000 }).toBe(false);
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await memoryPeek(page)).toMatchObject({ remaining: 0, progress: 0, seconds: 0, countdown: { visible: false } });
  await page.waitForTimeout(300);
  const hidden = await screenshot(page, testInfo, 'memory-countdown-first-expired', { verifyRendering: true });
  await activate();
  await expect(page.locator('#game-status')).toContainText(PEEK);
  const second = await memoryPeek(page);
  expect(second).toMatchObject({ count: 2, duration: 5, next_price: 200, studying: true });
  expect(second.remaining).toBeGreaterThan(3.5);
  const paid = await memoryWallet(page);
  expect(paid.balance).toBe(0);
  expect(Object.entries(paid.receipts).filter(([id]) => !Object.hasOwn(firstWallet.receipts, id)).map(([, amount]) => amount)).toEqual([-100]);
  await captureStage('second-start');
  await activate();
  expect(await memoryWallet(page)).toEqual(paid);
  expect((await memoryPeek(page)).remaining).toBeLessThan(second.remaining);
  await expect.poll(async () => (await memoryPeek(page)).remaining, { intervals: [100], timeout: 5000 }).toBeLessThanOrEqual(2.7);
  await captureStage('second-final-seconds');
  await expect.poll(async () => (await memoryPeek(page)).studying, { intervals: [100], timeout: 5000 }).toBe(false);
  await expect(page.locator('#game-status')).toContainText(READY);
  expect((await memoryPeek(page)).count).toBe(2);
  expect(await memoryWallet(page)).toEqual(paid);
  expect(await medalRecord(page), 'Timed peeking does not award mastery or rewards').toBe(saved);
  await progress(page, 0, 0);
  expect((await cardChanges(page, bounds, backs, fronts)).every(value => value > 0.005),
    'A completed touch tap leaves all ten cards revealed').toBe(true);
  expect((await cardChanges(page, bounds, backs, hidden)).every(value => value < 0.005),
    'The timer hides every unmatched card without another input').toBe(true);
  for (const { name, state, png } of captured) {
    expect(state.countdown.visible, `${name}: the timed reveal displays its own countdown`).toBe(true);
    expect(state.seconds).toBe(Math.ceil(state.remaining));
    expect(state.progress).toBeCloseTo(state.remaining / state.duration, 3);
    expect(state.countdown.seconds).toBe(state.seconds);
    expect(state.countdown.progress).toBeCloseTo(state.progress, 3);
    const [x, y, width, height] = state.countdown.rect;
    expect([x, y, width, height].every(Number.isFinite)).toBe(true);
    expect(width * bounds.scale, `${name}: the bar remains legible on phones`).toBeGreaterThan(45);
    expect(height * bounds.scale, `${name}: the timer and effects have actual drawing space`).toBeGreaterThan(16);
    expect(x).toBeGreaterThanOrEqual(0);
    expect(y).toBeGreaterThanOrEqual(0);
    expect(x + width).toBeLessThanOrEqual(bounds.width + 1);
    expect(y + height).toBeLessThanOrEqual(bounds.height + 1);
    expect(await visibleColorCount(page, png), `${name}: the captured page shows the rendered game`).toBeGreaterThan(20);
  }
  await testInfo.attach('memory-countdown-stages.json', {
    body: JSON.stringify(captured.map(({ name, state }) => ({ name, state })), null, 2), contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});
}

test('Memory discoveries survive automatic mistakes, timed peek, worlds and More', async ({ page }, testInfo) => {
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
    await screenshot(page, testInfo, 'memory-timed-eye', { held: true });
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await discoverBoard(page), 'Opening the eye and four mistakes preserve every card identity and position.').toEqual(board);
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
    const fronts = await screenshot(page, testInfo, 'memory-all-ten-revealed', { held: true });
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
  const released = await screenshot(page, testInfo, 'memory-matched-faces-after-peek');
  expect(await cardChanges(page, bounds, matchedFaces, released), 'Ending Peek hides only unmatched faces.').toEqual(Array(10).fill(0));
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

test('Memory accepts the next card and timed eye directly from automatic feedback', async ({ page }, testInfo) => {
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
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  expect(await medalRecord(page)).toBe(saved);
  await screenshot(page, testInfo, 'memory-no-footer-victory');
  expect(await metrics(page)).toMatchObject({ x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height, scale: bounds.scale });
  expect(errors).toEqual([]);
});

test('five Memory pairs earn one saved piece and Play again refreshes Memory', async ({ page }, testInfo) => {
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
  await expect(page.locator('#game-status')).toHaveText('Round complete Hold the chest to open');
  expect(await medalRecord(page), 'Disabled Play again cannot claim or leave the chest.').toBe(before);
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try { await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!', { timeout: 15000 }); }
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
  await expect(page.locator('#game-status')).toContainText(READY);
  expect((await metrics(page)).library.current).toBe('memory');
  expect((await metrics(page)).growth.settlement.visible).toBe(false);
  const refreshed = await discoverBoard(page);
  expect(refreshed.filter(card => card.kind === 'Word').map(card => card.word).sort()).not.toEqual([...words].sort());
  expect(await medalRecord(page)).toBe(claimed);
  await screenshot(page, testInfo, 'memory-next-adventure-board');
  expect(errors).toEqual([]);
});

test('Memory timed eye survives keyboard and Xbox release but cancels on B, disconnect and resize', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await installGamepad(page);
  const { errors } = await beginMemory(page, { coinBalance: 5000 });
  const board = await discoverBoard(page), saved = await medalRecord(page);
  const focusEye = async () => {
    const eye = peekPoint(await memoryMetrics(page));
    await tap(page, eye.x, eye.y);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(READY);
  };
  for (const key of ['Space', 'Enter']) {
    await focusEye();
    const beforeKey = await memoryPeek(page), beforeWallet = await memoryWallet(page);
    await page.keyboard.down(key);
    await rendered(page);
    expect(await memoryPeek(page), 'A key press starts no countdown before its release')
      .toMatchObject({ studying: false, count: beforeKey.count });
    expect(await memoryWallet(page), 'Key-down alone does not charge').toEqual(beforeWallet);
    await page.keyboard.up(key);
    await expect(page.locator('#game-status'), 'A completed key activation opens the paid reveal').toContainText(PEEK);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await page.keyboard.press('Tab');
    await expect(page.locator('#game-status'), 'Moving keyboard focus preserves the countdown').toContainText(PEEK);
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(READY);
  }
  await page.evaluate(() => window.gamepadFixture.connect());
  await focusEye();
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status'), 'Xbox A release preserves the reveal').toContainText(PEEK);
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText(READY);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await page.evaluate(() => window.gamepadFixture.disconnect());
  await expect(page.locator('#game-status')).toContainText(READY);
  await focusEye();
  await page.keyboard.press('Space');
  await expect(page.locator('#game-status')).toContainText(PEEK);
  await page.setViewportSize({ width: 640, height: 320 });
  await rendered(page);
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(await reveal(page, 0)).toEqual(board[0]);
  await cancelCard(page, 0);
  expect(await reveal(page, 9)).toEqual(board[9]);
  await cancelCard(page, 9);
  await screenshot(page, testInfo, 'memory-eye-keyboard-controller-resized', { verifyRendering: true, afterResize: true });
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory timed peek is cancelled by More and page lifecycle without changing the board', async ({ page }, testInfo) => {
  await installGamepad(page, { connected: true });
  const { errors, bounds } = await beginMemory(page, { coinBalance: 5000 });
  const saved = await medalRecord(page), backs = await screenshot(page, testInfo, 'memory-before-peek-cancel');
  await withMemoryPeek(page, async () => {
    await pressGamepad(page, 3);
    await expect(page.locator('#game-status')).toContainText('Lv0');
  });
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toContainText(READY);
  for (const event of ['visibilitychange', 'pagehide']) {
    const eye = peekPoint(await memoryMetrics(page));
    await tap(page, eye.x, eye.y);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event(event));
    }, event);
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

test('Memory mouse release keeps the timed eye open until automatic expiry', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { coinBalance: 100 });
  const eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  await page.mouse.move(point.x, point.y);
  for (let index = 0; index < 2; index++) {
    const before = await memoryWallet(page);
    await page.mouse.down();
    await rendered(page);
    expect(await memoryPeek(page), 'Mouse-down alone does not begin a reveal')
      .toMatchObject({ count: index, studying: false });
    expect(await memoryWallet(page), 'A pending click does not charge').toEqual(before);
    await page.mouse.up();
    await expect(page.locator('#game-status'), 'Completing the click starts the countdown').toContainText(PEEK);
    await page.mouse.move(0, 0);
    await expect(page.locator('#game-status'), 'Leaving the eye cannot consume the remaining reveal time').toContainText(PEEK);
    await expect.poll(async () => (await memoryPeek(page)).studying, { timeout: 12000, intervals: [100] }).toBe(false);
    await expect(page.locator('#game-status')).toContainText(READY);
    await page.mouse.move(point.x, point.y);
  }
  await screenshot(page, testInfo, 'memory-eye-mouse-expired');
  expect(errors).toEqual([]);
});

test('Memory eye touch taps preserve one countdown without extra charges', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { reducedMotion: 'no-preference', coinBalance: 300 });
  const eye = peekPoint(bounds), initialWallet = await memoryWallet(page);
  for (let index = 0; index < 3; index++) {
    await page.touchscreen.tap(bounds.x + eye.x * bounds.scale, bounds.y + eye.y * bounds.scale);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    expect(await memoryPeek(page)).toMatchObject({ count: 1, duration: 10, next_price: 100 });
    expect(await memoryWallet(page)).toEqual(initialWallet);
  }
  await screenshot(page, testInfo, 'memory-eye-repeated-touch-countdown');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText(READY);
  expect(errors).toEqual([]);
});

test('Memory eye preserves timed reveals after opaque signed and high-bit touch releases', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { coinBalance: 5000 });
  const saved = await medalRecord(page), eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const backs = await screenshot(page, testInfo, 'memory-before-opaque-touch', { held: true });
  // These synthetic events cover each browser's Touch conversion and the real engine handler.
  // Trusted browser release delivery is covered separately by the CDP timer test below.
  let capturedFronts = false;
  for (const id of [-1, -2, -2147483648, 0x80000001, 0xffffffff, 0]) {
    const contact = { id, ...point };
    for (let repeat = 0; repeat < 2; repeat++) {
      const identifiers = await dispatchMemoryTouches(page, 'touchstart', [contact], [contact]);
      expect(identifiers.map(value => value | 0), 'The browser preserves the requested signed 32-bit touch identity.').toEqual([id | 0]);
      await rendered(page);
      expect((await memoryPeek(page)).studying, `Identifier ${id} waits for a completed tap.`).toBe(false);
      await dispatchMemoryTouches(page, 'touchend', [], [contact]);
      await expect(page.locator('#game-status'), `Identifier ${id}, completed tap ${repeat + 1} opens the eye.`).toContainText(PEEK);
      if (!capturedFronts) {
        const fronts = await screenshot(page, testInfo, 'memory-opaque-touch-revealed', { held: true });
        expect((await cardChanges(page, bounds, backs, fronts)).every(value => value > 0.005)).toBe(true);
        capturedFronts = true;
      }
      await expect(page.locator('#game-status'), `Identifier ${id} keeps its timed reveal after release.`).toContainText(PEEK);
      await page.waitForTimeout(160);
      await expect(page.locator('#game-status'), 'The released eye remains open without any held input.').toContainText(PEEK);
      await page.keyboard.press('Escape');
      await expect(page.locator('#game-status')).toContainText(READY);
    }
  }
  const released = await screenshot(page, testInfo, 'memory-opaque-touch-released', { held: true });
  expect((await cardChanges(page, bounds, backs, released)).every(value => value < 0.005)).toBe(true);
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(await medalRecord(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('Memory timed eye survives additional touches and leaving the eye but cancels on interruption', async ({ page }, testInfo) => {
  const { errors, bounds } = await beginMemory(page, { coinBalance: 300 });
  const eye = peekPoint(bounds), card = memoryPoint(bounds, 0);
  const owner = { id: -1, x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const second = { ...owner, id: -2 };
  const outside = { ...owner, x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale };
  await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
  await dispatchMemoryTouches(page, 'touchend', [], [owner]);
  await expect(page.locator('#game-status')).toContainText(PEEK);
  const activeWallet = await memoryWallet(page);
  await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
  await dispatchMemoryTouches(page, 'touchstart', [owner, second], [second]);
  await dispatchMemoryTouches(page, 'touchend', [owner], [second]);
  await expect(page.locator('#game-status'), 'Lifting another signed touch cannot cancel the countdown.').toContainText(PEEK);
  await dispatchMemoryTouches(page, 'touchend', [], [owner]);
  await expect(page.locator('#game-status'), 'The original touch release preserves the reveal.').toContainText(PEEK);
  expect((await memoryPeek(page)).count).toBe(1);
  expect(await memoryWallet(page), 'Additional touches cannot buy a second active reveal').toEqual(activeWallet);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText(READY);
  for (const type of ['touchcancel', 'touchmove']) {
    await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
    await dispatchMemoryTouches(page, 'touchend', [], [owner]);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await dispatchMemoryTouches(page, 'touchstart', [owner], [owner]);
    await dispatchMemoryTouches(page, type, type === 'touchmove' ? [outside] : [], [type === 'touchmove' ? outside : owner]);
    if (type === 'touchmove') {
      await expect(page.locator('#game-status'), 'Moving away from the eye preserves its timer.').toContainText(PEEK);
      await dispatchMemoryTouches(page, 'touchend', [], [outside]);
      await expect(page.locator('#game-status')).toContainText(PEEK);
      await page.keyboard.press('Escape');
    }
    await expect(page.locator('#game-status'), 'Explicit cancellation restores ordinary play.').toContainText(READY);
    await page.waitForTimeout(160);
    await expect(page.locator('#game-status')).toContainText(READY);
  }
  await screenshot(page, testInfo, 'memory-signed-touch-cancelled', { held: true });
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(errors).toEqual([]);
});

test('Memory trusted touch release starts the timer and explicit cancellation restores all backs', async ({ page, browserName }, testInfo) => {
  test.setTimeout(180000);
  test.skip(browserName !== 'chromium', 'Trusted touch activation/cancel uses Chromium CDP.');
  const { errors, bounds } = await beginMemory(page, { coinBalance: 300 });
  const saved = await medalRecord(page), eye = peekPoint(bounds);
  const point = { x: bounds.x + eye.x * bounds.scale, y: bounds.y + eye.y * bounds.scale };
  const backs = await screenshot(page, testInfo, 'memory-before-trusted-eye');
  const client = await page.context().newCDPSession(page);
  let held = false;
  const touchStart = async () => {
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point }] });
    held = true;
  };
  const touchEnd = async () => {
    await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    held = false;
  };
  try {
    const openingWallet = await memoryWallet(page);
    await touchStart();
    await rendered(page);
    expect(await memoryPeek(page), 'Touch-down alone does not begin a reveal').toMatchObject({ count: 0, studying: false });
    expect(await memoryWallet(page)).toEqual(openingWallet);
    await touchEnd();
    await expect(page.locator('#game-status'), 'A completed trusted tap starts the countdown').toContainText(PEEK);
    const fronts = await screenshot(page, testInfo, 'memory-trusted-eye-revealed');
    expect((await cardChanges(page, bounds, backs, fronts)).every(value => value > 0.005)).toBe(true);
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(READY);
    await rendered(page);
    const released = await screenshot(page, testInfo, 'memory-trusted-eye-escape');
    // Fractional mobile display scales can rerasterize a few text-edge pixels.
    expect((await cardChanges(page, bounds, backs, released)).every(value => value < 0.005)).toBe(true);

    const beforeLostRelease = await memoryWallet(page);
    await touchStart();
    await page.evaluate(() => document.getElementById('canvas').addEventListener('touchend',
      event => event.stopImmediatePropagation(), { capture: true, once: true }));
    await touchEnd();
    await rendered(page);
    expect(await memoryPeek(page), 'A tap whose release never reaches the canvas does not activate')
      .toMatchObject({ count: 1, studying: false });
    expect(await memoryWallet(page), 'An incomplete paid tap leaves the wallet unchanged').toEqual(beforeLostRelease);
    // Explicitly cancel the pending finger before a new, complete tap.
    await page.locator('#canvas').dispatchEvent('pointercancel');
    await touchStart();
    await touchEnd();
    await expect(page.locator('#game-status')).toContainText(PEEK);
    expect(await memoryPeek(page)).toMatchObject({ count: 2, duration: 5 });
    const activeWallet = await memoryWallet(page);
    expect(activeWallet.balance).toBe(200);

    await touchStart();
    const card = memoryPoint(bounds, 0);
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...point },
      { id: 2, x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale }] });
    await rendered(page);
    await expect(page.locator('#game-status')).toContainText(PEEK);
    await expect(page.locator('#selection-status')).toBeEmpty();
    // CDP touchEnd lifts every point; update the active set to lift only finger 2.
    await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...point }] });
    await expect(page.locator('#game-status'), 'Lifting the second finger cannot cancel the countdown').toContainText(PEEK);
    expect(await memoryWallet(page), 'Additional touches cannot charge an active countdown').toEqual(activeWallet);
    expect((await memoryPeek(page)).count).toBe(2);
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
      if (document.getElementById('game-status').textContent.match(/Cards hide in \d+ seconds\./)) {
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
    await screenshot(page, testInfo, 'memory-flipped-faces-revealed', { held: true, verifyRendering: true });
  });
  await expect(page.locator('#game-status')).toContainText(READY);
  await page.waitForTimeout(65);
  await tap(page, rect.x + 6, rect.y + rect.height / 2);
  await expect(page.locator('#selection-status'), 'The original outer hitbox remains usable during the return flip.').toHaveText(`Memory card ${index + 1}. Picture: ${board[index].word}.`);
  await cancelCard(page, index);
  expect(errors).toEqual([]);
});
