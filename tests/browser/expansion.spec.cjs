const { test, expect } = require('@playwright/test');

async function openGame(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  return errors;
}

async function metrics(page) {
  return page.locator('#canvas').evaluate(canvas => {
    const rect = canvas.getBoundingClientRect();
    const scale = Math.min(rect.width, rect.height) / 480;
    return { x: rect.x, y: rect.y, width: rect.width / scale, height: rect.height / scale, scale };
  });
}

async function tap(page, x, y) {
  const bounds = await metrics(page);
  await page.touchscreen.tap(bounds.x + x * bounds.scale, bounds.y + y * bounds.scale);
}

async function chooseMode(page, index) {
  const bounds = await metrics(page);
  const width = (bounds.width - 40) / 3;
  await tap(page, 12 + index * (width + 8) + width / 2, 208);
}

async function rendered(page) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

test('Sky words and Listen use native choices and mode changes cancel old feedback', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await chooseMode(page, 1);
  await expect(page.locator('#game-status')).toContainText('Sky words. Choose the word');
  await page.screenshot({ path: testInfo.outputPath('sky-words.png'), scale: 'css' });
  let bounds = await metrics(page);
  await tap(page, bounds.width * 0.25, bounds.height - 48);
  await expect(page.locator('#game-status')).toHaveText(/^Yes! [a-z]+\. 1 of 5 found\.|^Try the other choice\./);
  const feedback = await page.locator('#game-status').textContent();
  await tap(page, bounds.width * 0.25, bounds.height - 48);
  await expect(page.locator('#game-status')).toHaveText(feedback);

  await chooseMode(page, 2);
  await expect(page.locator('#game-status')).toContainText('Listen. Press Hear');
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toContainText('Listen. Press Hear');
  bounds = await metrics(page);
  const height = bounds.height - 264;
  const answerHeight = Math.max(72, Math.min(140, (height - 36) * 0.38));
  const stageHeight = Math.max(72, height - 36 - answerHeight);
  await tap(page, bounds.width / 2, 252 + 28 + stageHeight / 2);
  await expect(page.locator('#game-status')).toHaveText('Listen, then choose a picture. Press Hear to listen again.');
  await page.screenshot({ path: testInfo.outputPath('listen-choices.png'), scale: 'css' });
  await tap(page, bounds.width * 0.75, bounds.height - 48);
  await expect(page.locator('#game-status')).toHaveText(/^Yes! [a-z]+\. 1 of 5 found\.|^Try the other choice\./);
  await chooseMode(page, 0);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await tap(page, 120, 340);
  await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
  expect(errors).toEqual([]);
});

test('Ocean and Space themes preserve a selected pair card', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await tap(page, 120, 340);
  await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
  const selected = await page.locator('#selection-status').textContent();
  for (const [index, color, name] of [[4, '#e4f6fb', 'ocean'], [5, '#eeeafa', 'space']]) {
    const bounds = await metrics(page);
    const width = (bounds.width - 44) / 6;
    await tap(page, 12 + index * (width + 4) + width / 2, 128);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', color);
    await expect(page.locator('#selection-status')).toHaveText(selected);
    await page.screenshot({ path: testInfo.outputPath(`${name}-board.png`), scale: 'css' });
  }
  expect(errors).toEqual([]);
});

test('Pip playroom tricks stay still with reduced motion and preserve the board', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    const Source = window.AudioBufferSourceNode;
    const playback = window.shortAudioPlayback = { available: Boolean(Source), started: 0, ended: 0 };
    if (!Source) return;
    const start = Source.prototype.start;
    Source.prototype.start = function (...args) {
      if (!this.loop) {
        playback.started += 1;
        this.addEventListener('ended', () => { playback.ended += 1; }, { once: true });
      }
      return start.apply(this, args);
    };
  });
  const errors = await openGame(page);
  let releaseMusic;
  const musicPending = new Promise(resolve => { releaseMusic = resolve; });
  await page.route('**/audio-*.sample', async route => { await musicPending; await route.continue(); });
  let selected;
  try {
    await tap(page, 120, 340);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    selected = await page.locator('#selection-status').textContent();
    // Let the bundled cue and word finish before releasing optional background music.
    // Speech markers change when pronunciation ends, even with reduced motion.
    if (await page.evaluate(() => window.shortAudioPlayback.available)) {
      await expect.poll(() => page.evaluate(() => {
        const playback = window.shortAudioPlayback;
        return playback.started >= 2 && playback.ended === playback.started;
      })).toBe(true);
    }
  } finally {
    releaseMusic();
    await page.unrouteAll({ behavior: 'wait' });
  }
  const bounds = await metrics(page);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 36 medals complete.');
  const captions = ["Pip's happy dance!", 'Crunch! A carrot for Pip!', 'Pop! Bubble party!'];
  for (const [index, caption] of captions.entries()) {
    const width = (bounds.width - 68) / 3;
    await tap(page, 26 + index * (width + 8) + width / 2, 378);
    await expect(page.locator('#game-status')).toHaveText(caption);
    await rendered(page);
    const still = await page.screenshot({ path: testInfo.outputPath(`pip-trick-${index + 1}.png`), scale: 'css' });
    await page.waitForTimeout(300);
    expect((await page.screenshot({ scale: 'css' })).equals(still), 'Reduced-motion tricks keep a stable illustration.').toBe(true);
  }
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(selected);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 36 medals complete.');
  expect(errors).toEqual([]);
});

test('an earned medal can be displayed with Pip and survives a page reload', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  const bounds = await metrics(page);
  await tap(page, 48, 128);
  const cards = new Map();
  const cellWidth = (bounds.width - 34) / 2;
  const cellHeight = (bounds.height - 330) / 4;
  const cardPoint = index => [12 + (index % 2) * (cellWidth + 10) + cellWidth / 2,
    288 + Math.floor(index / 2) * (cellHeight + 10) + cellHeight / 2];
  for (let index = 0; index < 8; index++) {
    await tap(page, ...cardPoint(index));
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, ...cardPoint(index));
    await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  }
  const pairs = [...cards.values()].filter(card => card.Word !== undefined && card.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (const [index, pair] of pairs.entries()) {
    await tap(page, ...cardPoint(pair.Word));
    await tap(page, ...cardPoint(pair.Picture));
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find three pairs.');
  }
  await page.mouse.move(bounds.x + 48 * bounds.scale, bounds.y + 208 * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toContainText('A new piece!');
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).toContainText('Piece 1 of 3');
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 36 medals complete.');
  const favoriteClip = { x: bounds.x + 364 * bounds.scale, y: bounds.y + 182 * bounds.scale,
    width: 72 * bounds.scale, height: 72 * bounds.scale };
  const empty = await page.screenshot({ clip: favoriteClip, scale: 'css' });
  await tap(page, 90, 518);
  await expect(page.locator('#game-status')).toContainText('Blossom #1 reward preview opened');
  await tap(page, bounds.width / 2, bounds.height - 58);
  await expect(page.locator('#game-status')).toHaveText('Pip loves your Blossom!');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 36 medals complete.');
  await rendered(page);
  const displayed = await page.screenshot({ clip: favoriteClip, scale: 'css' });
  expect(displayed.equals(empty), 'Displaying an earned medal changes the actual playroom artwork.').toBe(false);
  await page.screenshot({ path: testInfo.outputPath('pip-favorite-medal.png'), scale: 'css' });
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened. 0 of 36 medals complete.');
  await rendered(page);
  expect((await page.screenshot({ clip: favoriteClip, scale: 'css' })).equals(displayed),
    'The saved favorite remains visibly displayed after reloading the engine.').toBe(true);
  expect(errors).toEqual([]);
});
