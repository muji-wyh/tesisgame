const { expect } = require('@playwright/test');

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
  const width = (bounds.width - 56) / 5;
  await tap(page, 12 + index * (width + 8) + width / 2, 208);
}

async function chooseTheme(page, index) {
  const bounds = await metrics(page);
  const width = (bounds.width - 44) / 6;
  await tap(page, 12 + index * (width + 4) + width / 2, 128);
}

async function rendered(page) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function visibleColorCount(page, png) {
  return page.evaluate(async base64 => {
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
}

async function openGame(page, { reducedMotion = 'reduce' } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  return errors;
}

function boardPoint(bounds, index) {
  const top = bounds.height >= 520 ? 319 : 288;
  const areaWidth = bounds.width - 24, areaHeight = bounds.height - top - 12;
  const side = areaWidth >= 420 && areaHeight < 360;
  const tight = side && areaWidth < 500, gap = tight ? 8 : 12, spacing = tight ? 0 : 10;
  const gridWidth = side ? areaWidth - Math.max(160, Math.min(areaWidth * 0.28, 240)) - gap : areaWidth;
  const height = side ? areaHeight : areaHeight - (areaWidth >= 392 ? 104 : 176) - 12;
  const columns = side || height < 318 ? 4 : 2;
  const rows = 8 / columns;
  const width = (gridWidth - (columns - 1) * spacing) / columns;
  const cellHeight = (height - (rows - 1) * 10) / rows;
  return { x: 12 + (index % columns) * (width + spacing) + width / 2,
    y: top + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2 };
}

function lessonPoint(bounds, key, { match = false, multiple = true } = {}) {
  if (match || !multiple) return feedbackPoint(bounds, key, match ? 'match' : 'choice');
  const top = 252 + (bounds.height >= 520 ? 28 : 0) + (match ? 36 : 0);
  const width = bounds.width - 24;
  const height = bounds.height - top - 12;
  const buttonHeight = multiple ? 152 : 72;
  let x, y, buttonWidth;
  if (width >= 420 && width >= height * 1.3) {
    const contentWidth = Math.min(width, 900);
    const pictureWidth = Math.floor((contentWidth - 12) * 0.48);
    buttonWidth = (contentWidth - pictureWidth - 20) / 2;
    x = (width - contentWidth) / 2 + pictureWidth + 12;
    y = 32 + Math.max(0, (height - 32 - buttonHeight) / 2);
  } else {
    const contentWidth = Math.min(width, 480);
    const cardHeight = Math.max(88, Math.min(height - 40 - buttonHeight, 420));
    buttonWidth = (contentWidth - 8) / 2;
    x = (width - contentWidth) / 2;
    y = 32 + Math.max(0, (height - 32 - cardHeight - 8 - buttonHeight) / 2) + cardHeight + 8;
  }
  return { x: 12 + x + (['next', 'action'].includes(key) ? buttonWidth + 8 : 0) + buttonWidth / 2,
    y: top + y + (['previous', 'next'].includes(key) ? 80 : 0) + 36 };
}

function memoryLayout(bounds) {
  const top = 252 + (bounds.height >= 520 ? 28 : 0);
  const areaWidth = bounds.width - 24, areaHeight = bounds.height - top - 12;
  const reviewHeight = areaWidth >= 392 ? 104 : 176;
  const side = areaWidth >= 368 && areaHeight < reviewHeight + 208;
  const width = side ? areaWidth - 168 : areaWidth;
  const height = side ? areaHeight : areaHeight - reviewHeight - 8;
  const wide = side || (width >= 420 && width >= height * 1.3) || (width >= 392 && height < 460);
  const columns = wide ? Math.min(side && width < 368 ? 4 : 5, Math.floor((width + 8) / 52)) : 2;
  const rows = Math.ceil(10 / columns), header = wide ? 44 : 64;
  return { top, width, height, columns, header,
    studyWidth: width < 300 && wide ? 108 : wide ? 132 : Math.max(132, Math.min(width * 0.4, 176)),
    cardWidth: (width - (columns - 1) * 8) / columns,
    cardHeight: (height - header - 4 - (rows - 1) * 8) / rows,
    review: side ? { x: 12 + width + 8, y: top, width: 160 } : { x: 12, y: top + height + 8, width }
  };
}

function memoryPoint(bounds, index) {
  const g = memoryLayout(bounds);
  return { x: 12 + index % g.columns * (g.cardWidth + 8) + g.cardWidth / 2,
    y: g.top + g.header + 4 + Math.floor(index / g.columns) * (g.cardHeight + 8) + g.cardHeight / 2 };
}

function studyPoint(bounds) {
  const g = memoryLayout(bounds);
  return { x: 12 + g.width - g.studyWidth / 2, y: g.top + g.header / 2 };
}

function choiceLayout(bounds) {
  const top = 252 + (bounds.height >= 520 ? 28 : 0);
  const areaWidth = bounds.width - 24, areaHeight = bounds.height - top - 12;
  const side = areaWidth >= 392 && areaHeight < 312;
  const reviewWidth = Math.max(160, Math.min(areaWidth * 0.36, 240));
  const reviewHeight = areaWidth >= 392 ? 104 : 176;
  const width = side ? areaWidth - reviewWidth - 8 : areaWidth;
  const height = side ? areaHeight : areaHeight - reviewHeight - 8;
  const answerHeight = Math.max(72, Math.min((height - 36) * 0.38, 140));
  return { top, width, height, answerHeight,
    stageHeight: Math.max(72, height - 36 - answerHeight),
    review: side ? { x: 12 + width + 8, y: top + (areaHeight - 176) / 2, width: reviewWidth }
      : { x: 12, y: top + height + 8, width }
  };
}

function choicePoint(bounds, index) {
  const g = choiceLayout(bounds), width = (g.width - 10) / 2;
  return { x: 12 + index * (width + 10) + width / 2, y: g.top + g.height - g.answerHeight / 2 };
}

function choiceTargetPoint(bounds) {
  const g = choiceLayout(bounds);
  return { x: 12 + g.width / 2, y: g.top + 28 + g.stageHeight / 2 };
}

function feedbackPoint(bounds, key, mode = 'choice') {
  let review;
  if (mode === 'memory') review = memoryLayout(bounds).review;
  else if (mode === 'match') {
    const top = bounds.height >= 520 ? 319 : 288;
    const width = bounds.width - 24, height = bounds.height - top - 12;
    const side = width >= 420 && height < 360;
    const reviewWidth = Math.max(160, Math.min(width * 0.28, 240));
    review = side ? { x: bounds.width - 12 - reviewWidth, y: top, width: reviewWidth }
      : { x: 12, y: bounds.height - 12 - (width >= 392 ? 104 : 176), width };
  } else {
    review = choiceLayout(bounds).review;
  }
  const wide = review.width >= 392, gap = review.width >= 176 ? 8 : 0;
  const actionWidth = wide ? 88 : review.width - 88 - gap * 2;
  const controlsWidth = 88 + actionWidth + gap * 2;
  const origin = wide ? review.width - controlsWidth : 0;
  if (key === 'hear') return { x: review.x + 32, y: review.y + (wide ? 68 : 60) };
  const x = key === 'previous' ? 22 : key === 'next' ? 44 + actionWidth + gap * 2 + 22 : 44 + gap + actionWidth / 2;
  return { x: review.x + origin + x, y: review.y + (wide ? 68 : 140) };
}

function resultPoint(bounds, key) {
  const landscape = bounds.width >= bounds.height || bounds.height < 560;
  const textWidth = landscape ? Math.max(232, (bounds.width - 40) * 0.39) : bounds.width - 24;
  const left = bounds.width - 12 - textWidth;
  if (key === 'chest') return { x: 48, y: 208 };
  if (key === 'review') return { x: left + 36, y: bounds.height - (bounds.height < 524 ? 132 : 138) };
  return { x: left + textWidth * (key === 'newAdventure' ? 0.75 : 0.25), y: bounds.height - 48 };
}

module.exports = { metrics, tap, chooseMode, chooseTheme, rendered, openGame, boardPoint, lessonPoint,
  memoryPoint, studyPoint, choicePoint, choiceTargetPoint, feedbackPoint, resultPoint, visibleColorCount };
