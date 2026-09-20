const { expect } = require('@playwright/test');
const THEME_IDS = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const THEME_COLORS = ['#effbef', '#fff4df', '#fff2e5', '#eef5ff', '#e7f8fa', '#f1edfb', '#f0f8e7', '#fff0f7'];
const MODES = ['match', 'memory', 'pop'];

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

function uiScale(bounds) {
  if (!Number.isFinite(bounds.scale) || bounds.scale <= 0) throw new Error('Logical canvas bounds must include their CSS scale.');
  return Math.max(2 / 3, bounds.scale);
}

function modeHeight(bounds) {
  return Math.ceil(44 / uiScale(bounds));
}

function modeRect(bounds, name, currentMode = 'match') {
  const index = MODES.indexOf(name);
  if (index < 0) throw new Error(`Unknown mode: ${name}. Use match, memory or pop.`);
  if (!MODES.includes(currentMode)) throw new Error(`Unknown current mode: ${currentMode}.`);
  const content = contentBounds(bounds);
  const scale = uiScale(bounds), gap = Math.round(4 / scale);
  const width = Math.min(Math.ceil(80 / scale), Math.floor((bounds.width - 2 * Math.ceil(12 / scale) - (MODES.length - 1) * gap) / MODES.length));
  let rowX = content.x, rowWidth = content.width, y = content.padding + content.header + content.gap;
  if (content.inlineModes) {
    const pipWidth = Math.ceil(132 / scale);
    const toolbarWidth = 3 * Math.ceil(44 / scale) + 2 * content.gap;
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
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
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
  const inlineModes = bounds.width * scale >= 680;
  const top = padding + header + gap + (inlineModes ? 0 : gap + modeHeight(bounds));
  return { x, width, top, padding, gap, header, inlineModes };
}

function collectionBounds(bounds) {
  const scale = uiScale(bounds), padding = Math.ceil(12 / scale), gap = Math.ceil(8 / scale);
  const usableWidth = Math.min(bounds.width - padding * 2, 960 / scale);
  const x = Math.max(padding, Math.round((bounds.width - 960 / scale) / 2)), width = bounds.width - x * 2;
  const worldSide = Math.ceil(52 / scale), worldGap = Math.round(6 / scale);
  const worldWidth = worldSide * THEME_IDS.length + worldGap * (THEME_IDS.length - 1);
  const tabWidth = Math.min(80 / scale, (usableWidth - 44 / scale - gap * 3) / 2);
  const inlineWorlds = usableWidth >= worldWidth + tabWidth * 2 + Math.ceil(44 / scale) + gap * 3;
  const worldColumns = usableWidth >= worldWidth ? THEME_IDS.length : Math.max(1, Math.min(4, Math.floor((usableWidth + worldGap) / (worldSide + worldGap))));
  const worldRowGap = Math.round(4 / scale);
  const rows = Math.ceil(THEME_IDS.length / worldColumns), worldHeight = rows * worldSide + (rows - 1) * worldRowGap;
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
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
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
  const columns = width * scale >= 720 ? 3 : 2;
  const index = ['ball', ...THEME_IDS].indexOf(name);
  const cell = (width - (columns - 1) * gap) / columns;
  if (name === 'goal') {
    if (!item) throw new Error('The inline goal control needs its toy card name.');
    const card = roomPoint(bounds, item);
    return { x: card.x + cell / 2 - 30 / scale, y: card.y - 34 / scale };
  }
  if (index < 0) throw new Error(`Unknown room control: ${name}`);
  const firstItem = top + 304 + gap + 64 / scale;
  const center = firstItem + Math.floor(index / columns) * (128 / scale + gap);
  return {
    x: x + index % columns * (cell + gap) + cell / 2,
    y: Math.min(center, bounds.height - padding - 64 / scale)
  };
}

async function roomControl(page, name, { locked = false, item = '' } = {}) {
  const bounds = await metrics(page);
  const saved = await page.evaluate(() => {
    // Storage-recovery fixtures use the game's default room until reading succeeds.
    try { return localStorage.getItem('wordBuddies.playroom') || ''; }
    catch (error) {
      if (error.name !== 'SecurityError') throw error;
      return '';
    }
  });
  const selected = saved.match(/^goal_item_id="toy-([^"]+)"/m)?.[1] || '';
  const active = locked ? item : selected;
  await chooseRewardSection(page, 'room');
  const controls = ['pip', ...(locked ? [] : ['toy'])];
  for (const toy of ['ball', ...THEME_IDS]) {
    controls.push(toy);
    if (toy === active) controls.push('goal');
  }
  if (!controls.includes(name)) throw new Error(`Unavailable room control: ${name}`);
  // Two tabs lead to Back, the world icons, four age choices, then the room controls.
  for (let index = 0; index < 7 + THEME_IDS.length + controls.indexOf(name); index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  return roomPoint(bounds, name, { item: active });
}

async function leaveRoomPreview(page, { item = '' } = {}) {
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom') || '');
  const equipped = saved.match(/^toy="toy-([^"]+)"/m)?.[1] || 'ball';
  await roomControl(page, equipped, { locked: true, item });
  await page.keyboard.press('Enter');
  await rendered(page);
  const bounds = await metrics(page), collection = collectionBounds(bounds);
  const x = bounds.x + (collection.x + collection.width / 2) * bounds.scale;
  const top = bounds.y + Math.min(collection.top + 20, bounds.height - collection.padding - 80) * bounds.scale;
  await page.mouse.move(x, top);
  if (page.context().browser().browserType().name() !== 'webkit') {
    await page.mouse.wheel(0, -2600);
  } else {
    // Mobile WebKit has no wheel API; dragging the list keeps the toy feedback intact.
    for (let swipe = 0; swipe < 4; swipe++) {
      await page.mouse.move(x, top);
      await page.mouse.down();
      await page.mouse.move(x, bounds.y + (bounds.height - collection.padding - 20) * bounds.scale, { steps: 8 });
      await page.mouse.up();
      await rendered(page);
    }
  }
  await rendered(page);
}

async function rendered(page) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function observeAudio(page, { fingerprintBuffers = false, phaseSelector = '' } = {}) {
  await page.addInitScript(({ fingerprintBuffers, phaseSelector }) => {
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.audioObservation = { available: Boolean(NativeContext), contexts: [], starts: 0, playbacks: [] };
    if (!NativeContext) return;
    const fingerprints = new WeakMap();
    function fingerprint(buffer) {
      if (!fingerprintBuffers || buffer.duration > 1) return undefined;
      if (fingerprints.has(buffer)) return fingerprints.get(buffer);
      // Equal-length clips still need content identity: six fruit slices last 270 ms.
      let hash = 2166136261, peak = 0;
      for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
        const samples = buffer.getChannelData(channel);
        const bits = new Uint32Array(samples.buffer, samples.byteOffset, samples.length);
        for (let index = 0; index < samples.length; index++) {
          hash = Math.imul(hash ^ bits[index], 16777619) >>> 0;
          peak = Math.max(peak, Math.abs(samples[index]));
        }
      }
      const result = { fingerprint: `${buffer.sampleRate}:${buffer.numberOfChannels}:${buffer.length}:${hash.toString(16)}`, peak };
      fingerprints.set(buffer, result);
      return result;
    }
    const WrappedContext = new Proxy(NativeContext, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args);
        window.audioObservation.contexts.push(context);
        const createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const source = createSource(), start = source.start.bind(source);
          source.start = (...values) => {
            const result = start(...values);
            window.audioObservation.starts++;
            if (source.buffer) window.audioObservation.playbacks.push({ duration: source.buffer.duration,
              sampleRate: source.buffer.sampleRate, channels: source.buffer.numberOfChannels,
              loop: source.loop, contextState: context.state, playbackRate: source.playbackRate.value,
              phase: phaseSelector ? document.querySelector(phaseSelector)?.dataset.phase || '' : '',
              ...fingerprint(source.buffer) });
            return result;
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = WrappedContext;
    else window.webkitAudioContext = WrappedContext;
  }, { fingerprintBuffers, phaseSelector });
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

async function enterGame(scope) {
  await expect(scope.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  const enter = scope.locator('#enter-game');
  await expect(enter).toBeVisible();
  await expect(enter).toBeEnabled();
  await expect(scope.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await enter.click();
  await expect(scope.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  await expect(scope.locator('#status')).toBeHidden();
}

async function openGame(page, { reducedMotion = 'reduce', mode = 'match', expectedStatus = 'Find 3 word–picture pairs.' } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion });
  await page.goto('/');
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText(expectedStatus);
  await rendered(page);
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

async function discoverMatchCards(page) {
  await expect(page.locator('#selection-status')).toBeEmpty();
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    cards.push({ index, kind, word });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  expect(new Set(cards.map(card => card.word)).size).toBe(5);
  return cards;
}

async function matchWords(page) {
  return [...new Set((await discoverMatchCards(page)).map(card => card.word))];
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

module.exports = { THEME_IDS, THEME_COLORS, MODES, metrics, tap, uiScale, modeHeight, modeRect, chooseMode, chooseTheme, chooseRewardSection, contentBounds, collectionBounds, collectionHeaderRect, worldIconRect, ageButtonRect, firstMedalPoint, headerPoint, headerIconRect, pipHeaderRect,
  progressRegion, openRewards, roomPoint, roomControl, leaveRoomPreview, rendered, observeAudio, enterGame, openGame, boardPoint, discoverMatchCards, matchWords,
  memoryMetrics, memoryLayout, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek, resultPoint, visibleColorCount };
