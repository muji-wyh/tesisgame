const { expect } = require('@playwright/test');
const THEME_COLORS = ['#effbef', '#fff4df', '#fff2e5', '#eef5ff', '#e7f8fa', '#f1edfb'];
const MODES = ['match', 'learn', 'memory'];

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

function learnCardRect(bounds) {
  const content = contentBounds(bounds);
  return { x: content.x, y: content.top, width: content.width, height: bounds.height - content.top - content.padding };
}

function learnArtRect(bounds) {
  const card = learnCardRect(bounds), scale = uiScale(bounds);
  const wide = card.width >= 420 && card.width >= card.height * 1.3;
  const edge = Math.min(360 / scale, wide ? card.width / 2 - 24 / scale : card.width - 24 / scale,
    card.height - (wide ? 48 : 100) / scale);
  const top = wide ? (card.height - edge) / 2
    : Math.max(12 / scale, Math.min(64 / scale, (card.height - edge - 64 / scale) * 0.25));
  return { x: card.x + (wide ? (card.width / 2 - edge) / 2 : (card.width - edge) / 2),
    y: card.y + top, width: edge, height: edge };
}

async function swipeLearn(page, direction, { input = 'mouse' } = {}) {
  if (!['next', 'previous'].includes(direction)) throw new Error(`Unknown Learn direction: ${direction}`);
  if (!['mouse', 'touch'].includes(input)) throw new Error(`Unknown Learn input: ${input}`);
  const bounds = await metrics(page), card = learnCardRect(bounds);
  const point = fraction => ({ x: bounds.x + (card.x + card.width * fraction) * bounds.scale,
    y: bounds.y + (card.y + card.height / 2) * bounds.scale });
  const start = point(direction === 'next' ? 0.75 : 0.25);
  const end = point(direction === 'next' ? 0.25 : 0.75);
  if (input === 'touch') {
    const client = await page.context().newCDPSession(page);
    let pressed = false;
    try {
      await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
      pressed = true;
      await rendered(page);
      for (let step = 1; step <= 6; step++) {
        await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{
          id: 1, x: start.x + (end.x - start.x) * step / 6, y: start.y
        }] });
        await rendered(page);
      }
    } finally {
      if (pressed) await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await client.detach();
    }
  } else {
    await page.mouse.move(start.x, start.y);
    await page.mouse.down();
    try {
      await rendered(page);
      await page.mouse.move(end.x, end.y, { steps: 6 });
      await rendered(page);
    } finally {
      await page.mouse.up();
    }
  }
  await rendered(page);
}

function uiScale(bounds) {
  if (!Number.isFinite(bounds.scale) || bounds.scale <= 0) throw new Error('Logical canvas bounds must include their CSS scale.');
  return Math.max(2 / 3, bounds.scale);
}

function modeHeight(bounds) {
  return Math.ceil(44 / uiScale(bounds));
}

function modeRect(bounds, name, currentMode = 'learn') {
  const index = MODES.indexOf(name);
  if (index < 0) throw new Error(`Unknown mode: ${name}. Use learn, match or memory.`);
  if (!MODES.includes(currentMode)) throw new Error(`Unknown current mode: ${currentMode}.`);
  const content = contentBounds(bounds);
  const scale = uiScale(bounds), width = Math.ceil(80 / scale), gap = Math.round(6 / scale);
  let rowX = content.x, rowWidth = content.width, y = content.padding + content.header + content.gap;
  if (content.inlineModes) {
    const pipWidth = Math.ceil((currentMode === 'learn' ? 52 : 132) / scale);
    const icons = { learn: 1, match: 3, memory: 2 }[currentMode];
    const toolbarWidth = icons * Math.ceil(44 / scale) + (icons - 1) * content.gap;
    rowX += pipWidth + content.gap;
    rowWidth -= pipWidth + toolbarWidth + content.gap * 2;
    y = content.padding + (content.header - modeHeight(bounds)) / 2;
  }
  const left = rowX + (rowWidth - MODES.length * width - (MODES.length - 1) * gap) / 2;
  return { x: left + index * (width + gap), y, width, height: modeHeight(bounds) };
}

async function chooseMode(page, name) {
  const bounds = await metrics(page), modes = MODES.map(current => modeRect(bounds, name, current));
  // The shared interior stays clickable as the Pip and toolbar widths recenter the row.
  const left = Math.max(...modes.map(mode => mode.x));
  const right = Math.min(...modes.map(mode => mode.x + mode.width));
  if (right <= left) throw new Error(`No shared hit area for mode ${name}.`);
  await tap(page, (left + right) / 2, modes[0].y + modes[0].height / 2);
  await rendered(page);
}

async function chooseTheme(page, index) {
  if (!Number.isInteger(index) || index < 0 || index > 5) throw new Error(`Unknown world index: ${index}`);
  const more = headerPoint(await metrics(page));
  await tap(page, more.x, more.y);
  const world = worldIconRect(await metrics(page), index);
  await tap(page, world.x + world.width / 2, world.y + world.height / 2);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).not.toContainText('My rewards opened.');
  await rendered(page);
}

function contentBounds(bounds) {
  const scale = uiScale(bounds), padding = Math.ceil(12 / scale), gap = Math.ceil(8 / scale), header = Math.ceil(56 / scale);
  const x = Math.max(padding, Math.round((bounds.width - 1040 / scale) / 2)), width = bounds.width - x * 2;
  const inlineModes = bounds.width * scale >= 600;
  const top = padding + header + gap + (inlineModes ? 0 : gap + modeHeight(bounds));
  return { x, width, top, padding, gap, header, inlineModes };
}

function collectionBounds(bounds) {
  const scale = uiScale(bounds), padding = Math.ceil(12 / scale), gap = Math.ceil(8 / scale);
  const usableWidth = Math.min(bounds.width - padding * 2, 960 / scale);
  const x = Math.max(padding, Math.round((bounds.width - 960 / scale) / 2)), width = bounds.width - x * 2;
  const worldSide = Math.ceil(52 / scale), worldGap = Math.round(6 / scale);
  const inlineWorlds = usableWidth * scale >= 640;
  const worldColumns = usableWidth >= worldSide * 6 + worldGap * 5 ? 6 : 3;
  const worldRowGap = Math.round(4 / scale);
  const rows = 6 / worldColumns, worldHeight = rows * worldSide + (rows - 1) * worldRowGap;
  const headerHeight = Math.ceil((inlineWorlds ? 52 : 44) / scale);
  const ageTop = padding + headerHeight + gap + (inlineWorlds ? 0 : worldHeight + gap);
  const ageHeight = Math.ceil(48 / scale) + Math.round(4 / scale) + Math.ceil(20 / scale);
  const pinAge = bounds.height - padding - ageTop - ageHeight - gap >= Math.ceil(128 / scale);
  const top = ageTop + ageHeight + (pinAge ? gap : Math.ceil(20 / scale));
  return { x, width, top, padding, gap, inlineWorlds, headerHeight, worldSide, worldGap, worldRowGap, worldColumns, worldHeight, ageTop, ageHeight, pinAge };
}

function ageButtonRect(bounds, id) {
  const index = ['all', '4-6', '7-9', '10-plus'].indexOf(id);
  if (index < 0) throw new Error(`Unknown age level: ${id}`);
  const { x, width, ageTop } = collectionBounds(bounds), scale = uiScale(bounds);
  const labelWidth = Math.ceil(30 / scale), buttonWidth = Math.ceil(52 / scale), gap = Math.round(6 / scale);
  const rowWidth = labelWidth + 4 * (buttonWidth + gap);
  return { x: x + (width - rowWidth) / 2 + labelWidth + gap + index * (buttonWidth + gap),
    y: ageTop, width: buttonWidth, height: Math.ceil(48 / scale) };
}

function collectionHeaderRect(bounds, section) {
  const { x, width, padding, gap, headerHeight } = collectionBounds(bounds), scale = uiScale(bounds);
  const height = Math.ceil(44 / scale);
  const y = padding + (headerHeight - height) / 2;
  if (section === 'back') return { x: x + width - height, y, width: height, height };
  const tab = ['room', 'medals'].indexOf(section);
  if (tab < 0) throw new Error(`Unknown reward section: ${section}`);
  const tabWidth = Math.min(80 / scale, (width - 44 / scale - gap * 3) / 2);
  return { x: x + tab * (tabWidth + gap), y, width: tabWidth, height };
}

function worldIconRect(bounds, index) {
  if (!Number.isInteger(index) || index < 0 || index > 5) throw new Error(`Unknown world index: ${index}`);
  const { x, width, padding, gap, inlineWorlds, headerHeight, worldSide: side,
    worldGap: spacing, worldRowGap, worldColumns: columns, worldHeight } = collectionBounds(bounds);
  let rowX = x, rowWidth = width, y = padding + headerHeight + gap;
  if (inlineWorlds) {
    const tab = collectionHeaderRect(bounds, 'room'), back = collectionHeaderRect(bounds, 'back');
    rowX += 2 * (tab.width + gap);
    rowWidth -= tab.width * 2 + back.width + gap * 3;
    y = padding + (headerHeight - worldHeight) / 2;
  }
  const left = rowX + (rowWidth - side * columns - spacing * (columns - 1)) / 2;
  return { x: left + index % columns * (side + spacing),
    y: y + Math.floor(index / columns) * (side + worldRowGap), width: side, height: side };
}

function firstMedalPoint(bounds) {
  const { x, width, top, gap } = collectionBounds(bounds), scale = uiScale(bounds);
  const shelfPadding = Math.ceil(16 / scale), shelfGap = Math.ceil(12 / scale);
  const columns = (width - shelfPadding * 2) * scale >= 780 ? 6 : 3;
  const cell = (width - shelfPadding * 2 - shelfGap * (columns - 1)) / columns;
  const spacing = Math.ceil(20 / scale);
  const guideHeight = Math.ceil(64 / scale) + gap * 2;
  return { x: x + shelfPadding + cell / 2, y: top + guideHeight + spacing + shelfPadding + 36 / scale + shelfGap + 64 / scale };
}

function headerIconRect(bounds, key = 'rewards') {
  const { x, width, padding, header, gap } = contentBounds(bounds);
  const index = { rewards: 0, hint: 1, voice: 2, eye: 1 }[key];
  if (index === undefined) throw new Error(`Unknown header icon: ${key}`);
  const side = Math.ceil(44 / uiScale(bounds));
  return { x: x + width - side - index * (side + gap), y: padding + (header - side) / 2, width: side, height: side };
}

function headerPoint(bounds, key = 'rewards') {
  const content = contentBounds(bounds), scale = uiScale(bounds);
  if (['pip', 'retry'].includes(key)) return { x: content.x + (key === 'pip' ? 26 : 48) / scale, y: content.padding + content.header / 2 };
  const rect = headerIconRect(bounds, key);
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function pipHeaderRect(bounds) {
  const content = contentBounds(bounds), scale = uiScale(bounds);
  return { x: content.x, y: content.padding + 2 / scale, width: 52 / scale, height: 52 / scale };
}

function progressRegion(bounds, mode = 'match') {
  if (!['match', 'memory'].includes(mode)) throw new Error('Only Match and Memory have header score badges.');
  const { x, padding } = contentBounds(bounds), scale = uiScale(bounds);
  return { x: x + 60 / scale, y: padding + 5 / scale, width: 70 / scale, height: 46 / scale };
}

async function openRewards(page) {
  const point = headerPoint(await metrics(page));
  await tap(page, point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await rendered(page);
}

async function chooseRewardSection(page, section) {
  const tab = collectionHeaderRect(await metrics(page), section);
  if (section === 'back') throw new Error('Back closes the collection; it is not a reward section.');
  await tap(page, tab.x + tab.width / 2, tab.y + tab.height / 2);
  await expect(page.locator('#game-status')).toContainText({
    room: 'Choose toys for Pip.', medals: 'Medals.'
  }[section]);
  await rendered(page);
}

function roomPoint(bounds, name, { item = '' } = {}) {
  const { x, width, top, padding, gap } = collectionBounds(bounds), scale = uiScale(bounds);
  if (name === 'pip') return { x: x + 88, y: top + 216 };
  if (name === 'toy') return { x: x + width - 66, y: top + 230 };
  const shortcut = ['pet', 'poke', 'toss', 'call'].indexOf(name);
  if (shortcut >= 0) return { x: x + width * (shortcut + 0.5) / 4, y: top + 304 + gap + 22 / scale };
  const columns = width * scale >= 720 ? 3 : 2;
  const index = ['ball', 'spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].indexOf(name);
  const cell = (width - (columns - 1) * gap) / columns;
  if (name === 'goal') {
    if (!item) throw new Error('The inline goal control needs its toy card name.');
    const card = roomPoint(bounds, item);
    return { x: card.x + cell / 2 - 30 / scale, y: card.y - 34 / scale };
  }
  const action = top + 304 + gap * 3 + 102 / scale;
  const firstItem = action + gap + 86 / scale;
  const center = index >= 0 ? firstItem + Math.floor(index / columns) * (128 / scale + gap) : { action }[name];
  if (!Number.isFinite(center)) throw new Error(`Unknown room control: ${name}`);
  return {
    x: index >= 0 ? x + index % columns * (cell + gap) + cell / 2 : x + width / 2,
    y: Math.min(center, bounds.height - padding - (index >= 0 ? 64 : 22) / scale)
  };
}

async function roomControl(page, name, { locked = false, item = '' } = {}) {
  const bounds = await metrics(page);
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom') || '');
  const selected = saved.match(/^goal_item_id="toy-([^"]+)"/m)?.[1] || '';
  const active = locked ? item : selected;
  await chooseRewardSection(page, 'room');
  const controls = ['pip', ...(locked ? [] : ['toy']), 'pet', 'poke', ...(locked ? [] : ['toss']), 'call',
    'action'];
  for (const toy of ['ball', 'spring', 'summer', 'autumn', 'winter', 'ocean', 'space']) {
    controls.push(toy);
    if (toy === active) controls.push('goal');
  }
  if (!controls.includes(name)) throw new Error(`Unavailable room control: ${name}`);
  // Two tabs lead to Back, six world icons, four age choices, then the room controls.
  for (let index = 0; index < 13 + controls.indexOf(name); index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  return roomPoint(bounds, name, { item: active });
}

async function leaveRoomPreview(page) {
  await roomControl(page, 'action', { locked: true });
  await page.keyboard.press('Enter');
  await rendered(page);
}

async function rendered(page) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function observeAudio(page) {
  await page.addInitScript(() => {
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.audioObservation = { available: Boolean(NativeContext), contexts: [], starts: 0 };
    if (!NativeContext) return;
    const WrappedContext = new Proxy(NativeContext, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args);
        window.audioObservation.contexts.push(context);
        const createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const source = createSource(), start = source.start.bind(source);
          source.start = (...values) => {
            window.audioObservation.starts++;
            return start(...values);
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = WrappedContext;
    else window.webkitAudioContext = WrappedContext;
  });
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

async function openGame(page, { reducedMotion = 'reduce', mode = 'learn' } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect(page.locator('#status')).toBeHidden();
  await rendered(page);
  // Shared word-discovery fixtures explicitly enter Learn after checking the real startup mode.
  if (mode !== 'match') await chooseMode(page, mode);
  return errors;
}

function boardPoint(bounds, index, { top: overrideTop } = {}) {
  const { top: normalTop, x, width: areaWidth } = contentBounds(bounds);
  const top = overrideTop === undefined ? normalTop : overrideTop;
  if (!Number.isFinite(top) || top < 0 || top >= bounds.height) throw new Error('Invalid Match playfield top.');
  const areaHeight = bounds.height - top - contentBounds(bounds).padding;
  const columns = areaWidth >= areaHeight || areaHeight < 318 ? 4 : 2;
  const rows = 8 / columns;
  const width = (areaWidth - (columns - 1) * 10) / columns;
  const cellHeight = (areaHeight - (rows - 1) * 10) / rows;
  return { x: x + (index % columns) * (width + 10) + width / 2,
    y: top + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2 };
}

function lessonPoint(bounds, key, options) {
  if (options !== undefined) throw new Error('WordLesson is Learn-only; feedback has no footer controls.');
  if (key !== 'picture') throw new Error(`Learn has no ${key} button. Use swipeLearn or the top mode tabs.`);
  const card = learnCardRect(bounds);
  return { x: card.x + card.width / 2, y: card.y + card.height / 2 };
}

async function memoryMetrics(page) {
  return metrics(page);
}

function memoryLayout(bounds) {
  const { top, x, width, padding } = contentBounds(bounds), scale = uiScale(bounds);
  const gap = Math.ceil(8 / scale), height = bounds.height - top - padding;
  const columns = width < height ? 2 : 5, rows = 10 / columns;
  return { top, x, width, height, boardTop: top, gap, columns,
    cardWidth: (width - gap * (columns - 1)) / columns,
    cardHeight: (height - gap * (rows - 1)) / rows, eye: headerIconRect(bounds, 'eye') };
}

function memoryCardRect(bounds, index) {
  const layout = memoryLayout(bounds), row = Math.floor(index / layout.columns);
  const count = Math.min(layout.columns, 10 - row * layout.columns);
  const inset = (layout.width - count * layout.cardWidth - (count - 1) * layout.gap) / 2;
  return { x: layout.x + inset + index % layout.columns * (layout.cardWidth + layout.gap),
    y: layout.boardTop + row * (layout.cardHeight + layout.gap), width: layout.cardWidth, height: layout.cardHeight };
}

function memoryPoint(bounds, index) {
  const rect = memoryCardRect(bounds, index);
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function peekPoint(bounds) {
  const rect = memoryLayout(bounds).eye;
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

async function withMemoryPeek(page, held) {
  const bounds = await memoryMetrics(page), point = peekPoint(bounds);
  await page.mouse.move(bounds.x + point.x * bounds.scale, bounds.y + point.y * bounds.scale);
  await page.mouse.down();
  try {
    await rendered(page);
    await expect(page.locator('#game-status')).toContainText('Release to hide.');
    await held(bounds);
  } finally {
    await page.mouse.up();
  }
  await rendered(page);
}

function resultPoint(bounds, key, { gift = false } = {}) {
  if (!['chest', 'review', 'gift', 'newAdventure', 'retry'].includes(key)) throw new Error(`Unknown result action: ${key}`);
  const content = contentBounds(bounds);
  const scale = uiScale(bounds), actionHeight = Math.ceil(48 / scale), actionGap = Math.ceil(8 / scale);
  const landscape = bounds.width >= bounds.height || bounds.height < 560;
  const textWidth = landscape ? Math.max(232, (content.width - 16) * 0.39) : content.width;
  const left = content.x + content.width - textWidth;
  const top = content.padding + content.header + content.gap;
  const extra = gift ? actionHeight + actionGap : 0;
  if (key === 'chest') return { x: content.x + 36, y: top + 116 };
  if (key === 'gift') return { x: content.x + content.width / 2, y: bounds.height - content.padding - actionHeight / 2 };
  if (key === 'review') return { x: left + 36, y: bounds.height - content.padding - actionHeight - 44 - actionGap - extra };
  return { x: content.x + content.width / 2,
    y: bounds.height - content.padding - actionHeight / 2 - extra };
}

module.exports = { metrics, tap, learnCardRect, learnArtRect, swipeLearn, uiScale, modeHeight, modeRect, chooseMode, chooseTheme, chooseRewardSection, contentBounds, collectionBounds, collectionHeaderRect, worldIconRect, ageButtonRect, firstMedalPoint, headerPoint, headerIconRect, pipHeaderRect,
  progressRegion, openRewards, roomPoint, roomControl, leaveRoomPreview, rendered, observeAudio, openGame, boardPoint, lessonPoint,
  memoryMetrics, memoryLayout, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek, resultPoint, visibleColorCount };
