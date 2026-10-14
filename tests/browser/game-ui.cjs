const { expect } = require('@playwright/test');
const THEME_IDS = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const THEME_COLORS = ['#effbef', '#fff4df', '#fff2e5', '#eef5ff', '#e7f8fa', '#f1edfb', '#f0f8e7', '#fff0f7'];
const THEME_NAMES = THEME_IDS.map(id => id[0].toUpperCase() + id.slice(1));
const MODES = ['word_jelly', 'match', 'memory', 'pop', 'phrase', 'jelly'];

async function metrics(page) {
  return page.locator('#canvas').evaluate(canvas => {
    const rect = canvas.getBoundingClientRect();
    const scale = Math.min(rect.width, rect.height) / 480;
    return { x: rect.x, y: rect.y, width: rect.width / scale, height: rect.height / scale, scale,
      library: JSON.parse(document.getElementById("game-status").dataset.library || "{}"),
      growth: JSON.parse(document.getElementById("growth-status").dataset.view || "{}") };
  });
}

async function tap(page, x, y, bounds) {
  bounds ||= await metrics(page);
  if (page.touchscreen) await page.touchscreen.tap(bounds.x + x * bounds.scale, bounds.y + y * bounds.scale);
  else await page.locator('#canvas').tap({ position: { x: x * bounds.scale, y: y * bounds.scale } });
}

function uiScale(bounds) {
  if (!Number.isFinite(bounds.scale) || bounds.scale <= 0) throw new Error('Logical canvas bounds must include their CSS scale.');
  return Math.max(2 / 3, bounds.scale);
}

function modeRect(bounds, name) {
  const index = MODES.indexOf(name);
  if (index < 0) throw new Error(`Unknown mode: ${name}. Use match, memory, pop, phrase, jelly or word_jelly.`);
  const control = bounds.library?.controls?.find(item => item.name === `Mode_${name}`);
  if (!control) throw new Error(`Open the home screen before locating ${name}.`);
  const [x, y, width, height] = control.rect;
  return { x, y, width, height };
}

async function openModeMenu(page) {
  const bounds = await metrics(page);
  if (!bounds.library?.visible) {
    let home = headerPoint(bounds, 'mode');
    if (bounds.growth?.settlement?.visible) {
      if (bounds.growth.result?.visible) home = resultPoint(bounds, 'home');
      else {
        const celebration = await celebrationState(page);
        let action = celebration.active ? celebration.home : null;
        if (!action) {
          const selector = bounds.library?.current === 'pop' ? '#pop-reward-status' : '#jelly-reward-status';
          action = await page.locator(selector).evaluate(element =>
            JSON.parse(element.dataset.snapshot || '{}').actions?.find(item => item.text === 'Home'));
        }
        expect(action?.visible && !action.disabled, 'The settlement exposes its own available Home action.').toBe(true);
        const [x, y, width, height] = action.rect;
        home = { x: x + width / 2, y: y + height / 2 };
      }
    }
    await tap(page, home.x, home.y);
  }
  await expect.poll(async () => (await metrics(page)).library?.visible).toBe(true);
  await rendered(page);
}

async function libraryControl(page, name) {
  await expect.poll(async () => (await metrics(page)).library?.controls?.some(item => item.name === name),
    { message: `${name} is available on the home screen` }).toBe(true);
  const target = bounds => {
    const state = bounds.library, item = state.controls.find(control => control.name === name);
    if (!item || item.visible === false) return null;
    const [left, top, width, height] = item.rect;
    const [x, y, w, h] = state.viewport_rect || [0, 0, bounds.width, bounds.height];
    const tolerance = 1 / bounds.scale;
    return left >= x - tolerance && top >= y - tolerance && left + width <= x + w + tolerance && top + height <= y + h + tolerance ? item : null;
  };
  let item = target(await metrics(page));
  if (item) return item;
  for (let step = 0; step < 24; step++) {
    await page.locator('#canvas').press('Tab');
    await rendered(page);
    item = target(await metrics(page));
    if (item) return item;
  }
  throw new Error(`Could not reveal home control: ${name}`);
}

async function activateLibraryControl(page, name) {
  const item = await libraryControl(page, name);
  expect(item.disabled, `${name} is enabled`).toBe(false);
  const [x, y, width, height] = item.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function chooseMode(page, name, options = {}) {
  await openModeMenu(page);
  modeRect(await metrics(page), name, options);
  await activateLibraryControl(page, `Mode_${name}`);
  await expect.poll(async () => (await metrics(page)).library?.visible).toBe(false);
  await expect.poll(async () => (await metrics(page)).library?.current).toBe(name);
}

async function chooseTheme(page, index) {
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
  const previous = (await metrics(page)).library;
  if ((await growthView(page)).visible) {
    await activateGrowthControl(page, 'GrowthBack');
    await expect.poll(async () => (await growthView(page)).visible).toBe(false);
  }
  await openModeMenu(page);
  const world = await worldControl(page, index);
  await tap(page, world.x + world.width / 2, world.y + world.height / 2);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
  await expect.poll(async () => (await metrics(page)).library?.theme_id).toBe(THEME_IDS[index]);
  if (!previous?.visible && previous?.current) await chooseMode(page, previous.current);
}

function contentBounds(bounds) {
  const scale = uiScale(bounds), mode = bounds.library?.current, height = bounds.height * scale;
  const shortHeader = (['jelly', 'word_jelly'].includes(mode) && height <= 440) || (['match', 'memory'].includes(mode) && height <= 360);
  const padding = Math.ceil((shortHeader ? 4 : 12) / scale);
  const gap = Math.ceil((shortHeader || bounds.width * scale < 360 ? 4 : 8) / scale);
  const stackedHeader = bounds.width * scale < 520 || (bounds.width * scale < 600 && !shortHeader);
  const header = Math.ceil((stackedHeader ? 88 : shortHeader ? 44 : 56) / scale), board = bounds.growth?.board;
  const inset = Math.max(Math.ceil(12 / scale), Math.round((bounds.width - 1040 / scale) / 2));
  const frame = bounds.growth?.game_area?.rect;
  const x = board?.visible ? board.rect[0] : frame ? frame[0] + Math.ceil(12 / scale) : inset;
  const width = board?.visible ? board.rect[2] : frame ? frame[2] - Math.ceil(12 / scale) * 2 : bounds.width - inset * 2;
  const top = board?.visible ? board.rect[1] : (frame?.[1] || 0) + padding + header + gap;
  const bottom = frame ? frame[1] + frame[3] - padding : bounds.height - padding;
  const areaHeight = board?.visible ? board.rect[3] : bottom - top;
  return { x, width, top, height: areaHeight, padding, gap, header };
}

function growthRect(bounds, name) {
  const item = bounds.growth?.controls?.find(control => control.name === name && control.visible);
  if (!item) throw new Error(`Growth control is not visible: ${name}`);
  const [x, y, width, height] = item.rect;
  return { x, y, width, height };
}

async function growthView(page) {
  return page.locator('#growth-status').evaluate(element => JSON.parse(element.dataset.view || '{}'));
}

async function seedGrowth(page, level, { unmastered = null } = {}) {
  // Keep this old six-answer record to exercise saved-learner migration on real browser flows.
  const words = require('../../words.json');
  const streaks = Object.fromEntries(words.filter(word => word.min_age <= level &&
    (unmastered ? !unmastered.includes(word.id) : word.min_age < level)).map(word => [word.id, 6]));
  await page.addInitScript(({ level, streaks }) => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=1\nlevel=${level}\nstreaks=${JSON.stringify(streaks)}\nreceipts=[]\n`);
  }, { level, streaks });
}

async function growthState(page) {
  return page.locator('#growth-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));
}

async function growthControl(page, name) {
  await expect.poll(async () => (await growthView(page)).controls?.some(item => item.name === name && item.visible),
    { message: `${name} is exposed by the growth interface` }).toBe(true);
  const visibleTarget = (item, state, bounds) => {
    if (!item) return null;
    const [left, top, width, height] = item.rect;
    const clip = name.startsWith('AgeWord_') && state.catalog?.viewport_rect || [0, 0, bounds.width, bounds.height];
    const [x, y, w, h] = clip;
    if (left < x - 1 || left + width > x + w + 1) return null;
    if (top >= y - 1 && top + height <= y + h + 1) return item;
    if (height > h && item.focused) {
      const upper = Math.max(top, y), bottom = Math.min(top + height, y + h);
      if (bottom - upper >= Math.min(44 / bounds.scale, h)) return { ...item, rect: [left, upper, width, bottom - upper] };
    }
    return null;
  };
  let state = await growthView(page), item = state.controls.find(entry => entry.name === name);
  let target = visibleTarget(item, state, await metrics(page));
  if (target) return target;
  for (let step = 0; step < 100; step++) {
    await page.locator('#canvas').press('Tab');
    await rendered(page);
    state = await growthView(page);
    item = state.controls.find(entry => entry.name === name);
    target = visibleTarget(item, state, await metrics(page));
    if (item?.focused && target) return target;
  }
  throw new Error(`Could not reveal growth control: ${name}`);
}

async function activateGrowthControl(page, name) {
  const item = await growthControl(page, name), bounds = await metrics(page);
  expect(item.disabled, `${name} is enabled`).toBe(false);
  const [x, y, width, height] = item.rect;
  if (page.touchscreen) await tap(page, x + width / 2, y + height / 2, bounds);
  else await page.locator('#canvas').click({ position: { x: (x + width / 2) * bounds.scale, y: (y + height / 2) * bounds.scale } });
  await rendered(page);
}

function collectionBounds(bounds) {
  const back = growthRect(bounds, 'GrowthBack');
  const controls = bounds.growth.controls.filter(item => item.visible && THEME_NAMES.includes(item.name));
  const scale = uiScale(bounds), padding = Math.ceil(12 / scale), gap = Math.ceil(8 / scale);
  const x = Math.max(padding, Math.round((bounds.width - 960 / scale) / 2));
  const world = controls[0]?.rect;
  return { x, width: bounds.width - x * 2, padding, gap, headerHeight: back.height,
    top: back.y + back.height + gap, themeTop: world?.[1] || 0, themeHeight: world?.[3] || 0,
    worldSide: world?.[3] || 0, worldGap: Math.round(6 / scale) };
}

function ageButtonRect(bounds, id) {
  if (!/^([3-9]|1[0-2])$/.test(String(id))) throw new Error(`Unknown age stage: ${id}`);
  return growthRect(bounds, `GrowthAge${id}`);
}

function collectionHeaderRect(bounds, section) {
  if (section !== 'back') throw new Error(`Unknown growth header item: ${section}`);
  return growthRect(bounds, 'GrowthBack');
}

function worldIconRect(bounds, index) {
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
  const item = bounds.library?.controls?.find(control => control.name === THEME_NAMES[index] && control.visible);
  if (!bounds.library?.visible || !item) throw new Error(`Open the home screen before locating ${THEME_NAMES[index]}.`);
  const [x, y, width, height] = item.rect;
  return { x, y, width, height };
}

async function ageControl(page, id) {
  const item = await growthControl(page, `GrowthAge${id}`);
  const [x, y, width, height] = item.rect;
  return { x, y, width, height };
}

async function worldControl(page, index) {
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
  const item = await libraryControl(page, THEME_NAMES[index]);
  const [x, y, width, height] = item.rect;
  return { x, y, width, height };
}

function headerIconRect(bounds, key = 'rewards') {
  const name = { rewards: 'GrowthProgressButton', hint: 'Hint', voice: 'Voice', eye: 'StudyGarden', mode: 'Home' }[key];
  if (!name) throw new Error(`Unknown header icon: ${key}`);
  return growthRect(bounds, name);
}

function headerPoint(bounds, key = 'rewards') {
  if (key === 'pip') {
    const pip = pipHeaderRect(bounds);
    return { x: pip.x + pip.width / 2, y: pip.y + pip.height / 2 };
  }
  if (key === 'retry') {
    const item = bounds.growth.controls.find(control => control.visible && control.text.startsWith('Retry'));
    if (!item) throw new Error('The storage retry control is not visible.');
    const [x, y, width, height] = item.rect;
    return { x: x + width / 2, y: y + height / 2 };
  }
  const rect = headerIconRect(bounds, key);
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function pipHeaderRect(bounds) {
  const pip = bounds.growth?.pip;
  if (!pip?.visible || !Array.isArray(pip.rect)) throw new Error('Pip is not visible in the gameplay header.');
  const [x, y, width, height] = pip.rect;
  return { x, y, width, height };
}

async function openRewards(page) {
  if (!(await growthView(page)).visible) {
    const bounds = await metrics(page);
    if (bounds.growth?.settlement?.visible) await openModeMenu(page);
    if ((await metrics(page)).library?.visible) await activateLibraryControl(page, 'HomeCollection');
    else await activateGrowthControl(page, 'GrowthProgressButton');
  }
  await expect.poll(async () => (await growthView(page)).visible).toBe(true);
  await rendered(page);
}

async function rewardState(page) {
  const medals = await page.evaluate(() => {
    try { return localStorage.getItem('wordBuddies.medalProgress') || ''; }
    catch (error) { if (error.name !== 'SecurityError') throw error; return ''; }
  });
  return { medals };
}

async function rendered(page) {
  await page.locator('#canvas').evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function observeAudio(page, { fingerprintBuffers = false, fingerprintMaxDuration = 1, phaseSelector = '', trackSourceLifecycle = false } = {}) {
  await page.addInitScript(({ fingerprintBuffers, fingerprintMaxDuration, phaseSelector, trackSourceLifecycle }) => {
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.audioObservation = { available: Boolean(NativeContext), contexts: [], starts: 0, playbacks: [] };
    if (!NativeContext) return;
    const fingerprints = new WeakMap();
    function fingerprint(buffer) {
      if (!fingerprintBuffers || buffer.duration > fingerprintMaxDuration) return undefined;
      if (fingerprints.has(buffer)) return fingerprints.get(buffer);
      // Equal-length clips still need content identity: six fruit slices last 270 ms.
      let hash = 2166136261, peak = 0;
      const channelFingerprints = [];
      for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
        const samples = buffer.getChannelData(channel);
        const bits = new Uint32Array(samples.buffer, samples.byteOffset, samples.length);
        let channelHash = 2166136261;
        for (let index = 0; index < samples.length; index++) {
          hash = Math.imul(hash ^ bits[index], 16777619) >>> 0;
          channelHash = Math.imul(channelHash ^ bits[index], 16777619) >>> 0;
          peak = Math.max(peak, Math.abs(samples[index]));
        }
        channelFingerprints.push(channelHash.toString(16));
      }
      const result = { fingerprint: `${buffer.sampleRate}:${buffer.numberOfChannels}:${buffer.length}:${hash.toString(16)}`, channelFingerprints, peak };
      fingerprints.set(buffer, result);
      return result;
    }
    const WrappedContext = new Proxy(NativeContext, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args);
        window.audioObservation.contexts.push(context);
        const createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const createdAt = performance.now();
          const source = createSource(), start = source.start.bind(source);
          let playback;
          if (trackSourceLifecycle) {
            const stop = source.stop.bind(source);
            source.stop = (...values) => {
              const at = performance.now(), contextTime = context.currentTime;
              const result = stop(...values);
              if (playback) {
                playback.stoppedAt = at;
                playback.stopContextTime = contextTime;
                playback.stopScheduledAt = values[0] || contextTime;
              }
              return result;
            };
            source.addEventListener('ended', () => {
              if (playback) playback.endedAt = performance.now();
            });
          }
          source.start = (...values) => {
            const at = performance.now(), contextTime = context.currentTime;
            const result = start(...values);
            window.audioObservation.starts++;
            if (source.buffer) {
              playback = { duration: source.buffer.duration,
                at, createdAt, contextTime, scheduledAt: values[0] || contextTime,
                sampleRate: source.buffer.sampleRate, channels: source.buffer.numberOfChannels,
                loop: source.loop, contextState: context.state, playbackRate: source.playbackRate.value,
                phase: phaseSelector ? document.querySelector(phaseSelector)?.dataset.phase || '' : '',
                ...fingerprint(source.buffer) };
              window.audioObservation.playbacks.push(playback);
            }
            return result;
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = WrappedContext;
    else window.webkitAudioContext = WrappedContext;
  }, { fingerprintBuffers, fingerprintMaxDuration, phaseSelector, trackSourceLifecycle });
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

async function enterGame(scope, { home = false } = {}) {
  await expect(scope.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  const enter = scope.locator('#enter-game');
  await expect(enter).toBeVisible();
  await expect(enter).toBeEnabled();
  await expect(scope.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await enter.click();
  await expect(scope.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  await expect(scope.locator('#status')).toBeHidden();
  await expect.poll(async () => (await metrics(scope)).library?.visible,
    { message: 'Entering the game opens the home screen before a mode is selected' }).toBe(true);
  if (!home) await chooseMode(scope, 'match');
}

async function openGame(page, { reducedMotion = 'reduce', mode = 'match', expectedStatus = 'Find 5 word–picture pairs.' } = {}) {
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
  const { top: normalTop, x, width: areaWidth, height } = contentBounds(bounds);
  const top = overrideTop === undefined ? normalTop : overrideTop;
  if (!Number.isFinite(top) || top < 0 || top >= bounds.height) throw new Error('Invalid Match playfield top.');
  const areaHeight = height - (top - normalTop);
  const scale = uiScale(bounds);
  const columns = wordBoardColumns(areaWidth, areaHeight, scale, 10, 10);
  const rows = 10 / columns;
  const gutter = Math.ceil(44 / scale), horizontalGap = columns === 2 ? gutter : 10;
  const verticalGap = columns === 2 ? 10 : Math.min(gutter, Math.max(10, Math.floor(areaHeight - 88 / scale)));
  const width = (areaWidth - (columns - 1) * horizontalGap) / columns;
  const cellHeight = (areaHeight - (rows - 1) * verticalGap) / rows;
  return { x: x + (index % columns) * (width + horizontalGap) + width / 2,
    y: top + Math.floor(index / columns) * (cellHeight + verticalGap) + cellHeight / 2 };
}

async function discoverMatchCards(page) {
  await expect(page.locator('#selection-status')).toBeEmpty();
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    cards.push({ index, kind, word });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  expect(new Set(cards.map(card => card.word)).size).toBe(5);
  for (const word of new Set(cards.map(card => card.word))) {
    expect(cards.filter(card => card.word === word).map(card => card.kind).sort()).toEqual(['Picture', 'Word']);
  }
  return cards;
}

async function matchWords(page) {
  return [...new Set((await discoverMatchCards(page)).map(card => card.word))];
}

async function celebrationState(page) {
  return page.locator('#game-status').evaluate(element => JSON.parse(element.dataset.celebration || '{}'));
}

async function acceptCelebration(page) {
  // Keep the established helper name while callers migrate: the completed
  // performance now reveals the real chest without an intermediary click.
  await expect.poll(async () => {
    const current = await celebrationState(page), result = (await metrics(page)).growth?.result;
    const chest = result?.controls?.find(control => control.name === 'OpenSettlementChest');
    return Boolean(!current.active && result?.visible && chest?.visible && !chest.disabled);
  }, { timeout: 15000, message: 'The celebration reveals the chest directly inside settlement' }).toBe(true);
  expect((await celebrationState(page)).action?.visible,
    'The completed performance has no separate Open chest action.').not.toBe(true);
  await expect(page.locator('#game-status')).toContainText('Hold the chest to open');
}

async function memoryMetrics(page) {
  return metrics(page);
}

function wordBoardColumns(width, height, scale, columnGap, rowGap) {
  const tallCardHeight = (height - rowGap * 4) / 5;
  const wideCardWidth = (width - columnGap * 4) / 5;
  return tallCardHeight * scale >= 44 && (width < height || wideCardWidth * scale < 112) ? 2 : 5;
}

function memoryLayout(bounds) {
  const { top, x, width, height } = contentBounds(bounds), scale = uiScale(bounds);
  const gap = Math.ceil(8 / scale);
  const columns = wordBoardColumns(width, height, scale, gap, gap), rows = 10 / columns;
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

async function withMemoryPeek(page, revealed) {
  const bounds = await memoryMetrics(page), point = peekPoint(bounds);
  await tap(page, point.x, point.y);
  await expect(page.locator('#game-status')).toContainText(/Cards hide in \d+ seconds\./);
  try {
    await revealed(bounds);
  } finally {
    // Keep shared visual/gameplay fixtures short; timer expiry is exercised by
    // the dedicated countdown tests. Do not dismiss a modal opened by the callback.
    if ((await metrics(page)).growth?.memory?.peek?.studying) {
      await page.keyboard.press('Escape');
      await expect.poll(async () => (await metrics(page)).growth.memory.peek.studying).toBe(false);
    }
  }
  await rendered(page);
}

function resultPoint(bounds, key) {
  const names = { chest: 'OpenSettlementChest', newAdventure: 'SettlementReplay', retry: 'RetrySettlementSave', home: 'SettlementHome' };
  if (!names[key]) throw new Error(`Unknown result action: ${key}`);
  const result = bounds.growth?.result;
  const control = result?.controls?.find(item => item.name === names[key]);
  if (!control?.rect) throw new Error(`Settlement control has no measured bounds: ${names[key]}`);
  const [x, y, width, height] = control.rect;
  return { x: x + width / 2, y: y + height / 2 };
}

module.exports = { THEME_NAMES, THEME_IDS, THEME_COLORS, MODES, metrics, tap, uiScale, modeRect, openModeMenu, libraryControl, activateLibraryControl, chooseMode, chooseTheme, contentBounds, collectionBounds, collectionHeaderRect, worldIconRect, worldControl, ageButtonRect, ageControl, headerPoint, headerIconRect, pipHeaderRect,
  openRewards, rewardState, growthView, growthState, seedGrowth, growthControl, activateGrowthControl, rendered, observeAudio, enterGame, openGame, boardPoint, discoverMatchCards, matchWords,
  memoryMetrics, memoryLayout, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek, resultPoint, visibleColorCount,
  celebrationState, acceptCelebration };
