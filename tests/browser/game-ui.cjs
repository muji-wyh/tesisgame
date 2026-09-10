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
  const width = (bounds.width - 48) / 4;
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

async function openGame(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  return errors;
}

function boardPoint(bounds, index) {
  const top = bounds.height >= 520 ? 319 : 288;
  const height = bounds.height - top - 43;
  const columns = bounds.width >= bounds.height || height < 318 ? 4 : 2;
  const rows = 8 / columns;
  const width = (bounds.width - 24 - (columns - 1) * 10) / columns;
  const cellHeight = (height - (rows - 1) * 10) / rows;
  return { x: 12 + (index % columns) * (width + 10) + width / 2,
    y: top + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2 };
}

function lessonPoint(bounds, key, { match = false, multiple = true } = {}) {
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

function resultPoint(bounds, key) {
  const landscape = bounds.width >= bounds.height || bounds.height < 560;
  const textWidth = landscape ? Math.max(232, (bounds.width - 40) * 0.39) : bounds.width - 24;
  const left = bounds.width - 12 - textWidth;
  if (key === 'chest') return { x: 48, y: 208 };
  if (key === 'review') return { x: left + 36, y: bounds.height - (bounds.height < 524 ? 132 : 138) };
  return { x: left + textWidth * (key === 'newAdventure' ? 0.75 : 0.25), y: bounds.height - 48 };
}

module.exports = { metrics, tap, chooseMode, chooseTheme, rendered, openGame, boardPoint, lessonPoint, resultPoint };
