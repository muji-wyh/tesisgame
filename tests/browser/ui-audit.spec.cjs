const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint } = require('./game-ui.cjs');

// Exploratory release audit: interact through the rendered game and its public announcements.
const SIZES = [{ width: 390, height: 844 }, { width: 320, height: 568 }, { width: 844, height: 390 }];

function memoryGeometry(b) {
  const top = 252 + (b.height >= 520 ? 28 : 0);
  const width = b.width - 24, height = b.height - top - 12;
  const wide = (width >= 420 && width >= height * 1.3) || (width >= 392 && height < 460);
  const columns = wide ? 5 : 2, rows = 10 / columns, header = wide ? 44 : 64;
  return { top, width, height, columns, header, study: wide ? 132 : Math.max(132, Math.min(width * 0.4, 176)),
    cellWidth: (width - (columns - 1) * 8) / columns,
    cellHeight: (height - header - 4 - (rows - 1) * 8) / rows };
}

async function memoryCard(page, index) {
  const g = memoryGeometry(await metrics(page));
  await tap(page, 12 + index % g.columns * (g.cellWidth + 8) + g.cellWidth / 2,
    g.top + g.header + 4 + Math.floor(index / g.columns) * (g.cellHeight + 8) + g.cellHeight / 2);
}

async function study(page) {
  const g = memoryGeometry(await metrics(page));
  await tap(page, 12 + g.width - g.study / 2, g.top + g.header / 2);
}

async function lesson(page, control, options) {
  const point = lessonPoint(await metrics(page), control, options);
  await tap(page, point.x, point.y);
}

async function rewards(page) {
  const b = await metrics(page);
  await tap(page, b.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
}

async function rewardSection(page, section) {
  const b = await metrics(page);
  await tap(page, 16 + (b.width - 104) * (section === 'medals' ? 0.75 : 0.25), 52);
  await expect(page.locator('#game-status')).toContainText(section === 'medals' ? /Medals[.:]/ : 'Choose toys and places for Pip.');
  await rendered(page);
}

async function scrollToEnd(page, browserName, size) {
  if (browserName === 'chromium') {
    await page.mouse.move(size.width / 2, size.height / 2);
    await page.mouse.wheel(0, 2600);
  } else {
    // Mobile WebKit has no wheel API; use the game's supported pointer drag.
    for (let swipe = 0; swipe < 6; swipe++) {
      await page.mouse.move(size.width / 2, size.height - 30);
      await page.mouse.down();
      await page.mouse.move(size.width / 2, 100, { steps: 8 });
      await page.mouse.up();
      await rendered(page);
    }
  }
  await rendered(page);
}

async function capture(page, testInfo, name, evidence) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const path = testInfo.outputPath(`${name}.png`);
  const png = await page.screenshot({ path, scale: 'css' });
  const visibleColors = await page.evaluate(async base64 => {
    const image = new Image();
    image.src = 'data:image/png;base64,' + base64;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
    const colors = new Set();
    for (let y = 4; y < canvas.height; y += 8) for (let x = 4; x < canvas.width; x += 8) {
      const i = (y * canvas.width + x) * 4;
      colors.add(`${data[i] >> 4},${data[i + 1] >> 4},${data[i + 2] >> 4}`);
    }
    return colors.size;
  }, png.toString('base64'));
  const entry = { name, path, visibleColors, status: await page.locator('#game-status').textContent(),
    selection: await page.locator('#selection-status').textContent(), metrics: await metrics(page) };
  evidence.push(entry);
  fs.writeFileSync(testInfo.outputPath('audit-evidence.json'), JSON.stringify(evidence, null, 2));
  expect.soft(visibleColors, `${name}: the screenshot must show the game, not a solid loading/background frame`).toBeGreaterThan(20);
}

for (const size of SIZES) {
  test(`exploratory UI tour ${size.width}x${size.height}`, async ({ page, browserName }, testInfo) => {
    test.setTimeout(180000);
    await page.setViewportSize(size);
    const errors = await openGame(page);
    const evidence = [];
    const shot = name => capture(page, testInfo, name, evidence);
    await shot('01-learn-entry');
    await lesson(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\. Look, read, and press Hear\.$/);
    await shot('02-learn-next');
    const learned = await page.locator('#game-status').textContent();
    const bounds = await metrics(page);
    await tap(page, bounds.width - 142, 48);
    await expect(page.locator('#game-status')).toContainText("Pip's adventures.");
    await shot('03-adventure-menu');
    await page.keyboard.press('Shift+Tab');
    await shot('04-adventure-last-focus');
    await page.keyboard.press('Escape');
    await lesson(page, 'hear');
    await shot('05-learn-return-hear');
    expect.soft(await page.locator('#game-status').textContent(), 'Return should leave the displayed lesson usable').not.toContain('adventures.');

    await chooseMode(page, 1);
    await expect(page.locator('#game-status')).toContainText('Find 3 word');
    const first = boardPoint(await metrics(page), 0);
    await tap(page, first.x, first.y);
    await expect(page.locator('#selection-status')).not.toBeEmpty();
    const selected = await page.locator('#selection-status').textContent();
    await shot('06-match-selected');
    await rewards(page);
    await shot('07-rewards-room-top');
    await page.keyboard.press('Escape');
    expect.soft(await page.locator('#selection-status').textContent(), 'Rewards return must preserve the Match selection').toBe(selected);
    await tap(page, first.x, first.y);
    await expect(page.locator('#selection-status')).toBeEmpty();

    for (const [mode, name] of [[2, 'sky'], [3, 'listen']]) {
      await chooseMode(page, mode);
      await expect(page.locator('#game-status')).toContainText(mode === 2 ? 'Sky words.' : 'Listen.');
      await shot(`08-${name}-entry`);
      const b = await metrics(page);
      await tap(page, b.width / 4, b.height - 48);
      await expect(page.locator('#game-status')).toContainText('Continue');
      await shot(`09-${name}-feedback`);
      await rewards(page);
      await page.keyboard.press('Escape');
      await shot(`10a-${name}-feedback-restored`);
      expect.soft(await page.locator('#game-status').textContent(), 'Returning from Rewards must announce the visible feedback and its Continue action').toContain('Continue');
      await lesson(page, 'action', { multiple: false });
      await expect(page.locator('#game-status')).not.toContainText('Continue');
      await shot(`10-${name}-after-modal-continue`);
    }

    await chooseMode(page, 4);
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await memoryCard(page, 0);
    await expect(page.locator('#selection-status')).toContainText('Memory card 1.');
    await study(page);
    await expect(page.locator('#game-status')).toContainText('Study the garden.');
    await shot('11-memory-study');
    await memoryCard(page, 9);
    await page.keyboard.press('Enter');
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await memoryCard(page, 9);
    const memorySelection = await page.locator('#selection-status').textContent();
    await rewards(page);
    await page.keyboard.press('Escape');
    expect.soft(await page.locator('#selection-status').textContent()).toBe(memorySelection);
    await memoryCard(page, 9);
    await shot('12-memory-after-room');

    await rewards(page);
    const b = await metrics(page);
    if (b.height > 550) {
      await tap(page, b.width / 2, 502);
      await shot('13-room-toy-action');
      await tap(page, b.width * 0.75, 588);
      await shot('14-room-category');
    } else {
      await tap(page, b.width - 84, 322);
      await expect(page.locator('#game-status')).toHaveText('The ball rolls to Pip!');
      await shot('13-room-toy-action');
      await scrollToEnd(page, browserName, size);
      await shot('14-room-controls-scrolled');
      await tap(page, b.width / 6, b.height - 90);
      await expect(page.locator('#game-status')).toContainText('Complete Rocket');
      await shot('14b-room-locked-from-bottom');
      await tap(page, b.width / 2, b.height - 52);
      await expect(page.locator('#game-status')).toContainText('ball');
      await shot('14c-room-locked-return');
    }
    await rewardSection(page, 'medals');
    await shot('15-medals-section');
    await scrollToEnd(page, browserName, size);
    await rendered(page);
    await shot('16-medals-scrolled');
    await rewardSection(page, 'room');
    await rendered(page);
    await shot('16b-room-section-return');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await shot('17-final-return');
    expect.soft(errors).toEqual([]);
    expect.soft(learned).toContain('Learn:');
  });
}

test('locked room previews provide a usable return and Medals has its own entry', async ({ page }, testInfo) => {
  test.setTimeout(90000);
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  const evidence = [];
  const shot = name => capture(page, testInfo, name, evidence);
  await rewards(page);
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'));
  await tap(page, 360, 660);
  await shot('locked-toy-before-return');
  await expect.soft(page.locator('#game-status')).toContainText('Complete Blossom', { timeout: 1500 });
  await page.keyboard.press('Enter');
  await shot('locked-toy-after-return');
  await expect.soft(page.locator('#game-status')).toContainText('ball', { timeout: 1500 });
  await tap(page, 240, 502);
  await expect.soft(page.locator('#game-status')).toHaveText('The ball rolls to Pip!', { timeout: 1500 });
  await tap(page, 360, 588);
  await tap(page, 360, 660);
  await shot('locked-backdrop-before-return');
  await expect.soft(page.locator('#game-status')).toContainText('Complete Bee', { timeout: 1500 });
  await tap(page, 240, 502);
  await shot('locked-backdrop-after-return');
  await expect.soft(page.locator('#game-status')).toContainText('ball', { timeout: 1500 });
  expect.soft(await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'))).toBe(saved);
  await rewardSection(page, 'medals');
  await shot('medals-direct-entry');
  await rewardSection(page, 'room');
  await shot('room-direct-return');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  expect.soft(errors).toEqual([]);
});
