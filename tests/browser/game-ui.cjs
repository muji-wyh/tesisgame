const { expect } = require('@playwright/test');
const THEME_IDS = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const THEME_COLORS = ['#effbef', '#fff4df', '#fff2e5', '#eef5ff', '#e7f8fa', '#f1edfb', '#f0f8e7', '#fff0f7'];
const MODES = ['match', 'memory', 'pop', 'quest'];

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

function modeRect(bounds, name) {
  const index = MODES.indexOf(name);
  if (index < 0) throw new Error(`Unknown mode: ${name}. Use match, memory, pop or quest.`);
  const scale = uiScale(bounds), edge = Math.ceil(8 / scale), padding = Math.ceil(10 / scale);
  const rowGap = Math.ceil(2 / scale), titleHeight = Math.ceil(28 / scale), titleGap = Math.ceil(4 / scale);
  const panelWidth = Math.min(Math.ceil(248 / scale), bounds.width - edge * 2);
  const panelHeight = padding * 2 + titleHeight + titleGap + MODES.length * modeHeight(bounds) + (MODES.length - 1) * rowGap;
  const pip = pipHeaderRect(bounds);
  const left = Math.max(edge, Math.min(pip.x, bounds.width - edge - panelWidth));
  const top = Math.max(edge, Math.min(pip.y + pip.height + Math.ceil(6 / scale), bounds.height - edge - panelHeight));
  return { x: left + padding, y: top + padding + titleHeight + titleGap + index * (modeHeight(bounds) + rowGap),
    width: panelWidth - padding * 2, height: modeHeight(bounds) };
}

async function openModeMenu(page) {
  const status = page.locator('#game-status');
  if (!/^Game mode\. .+ is selected\./.test(await status.textContent())) {
    const pip = headerPoint(await metrics(page), 'pip');
    await tap(page, pip.x, pip.y);
  }
  await expect(status).toHaveText(/^Game mode\. .+ is selected\. Choose a game, or press Back to return\.$/);
  await rendered(page);
}

async function chooseMode(page, name, options = {}) {
  await openModeMenu(page);
  const rect = modeRect(await metrics(page), name, options);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await rendered(page);
  if (name === 'pop' && options.choosePlayer !== false) await chooseRoundPlayer(page);
}

async function chooseTheme(page, index) {
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
  const more = headerPoint(await metrics(page));
  await tap(page, more.x, more.y);
  const world = await worldControl(page, index);
  await tap(page, world.x + world.width / 2, world.y + world.height / 2);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).not.toContainText("Pip's room opened.");
  await rendered(page);
}

function contentBounds(bounds) {
  const scale = uiScale(bounds), padding = Math.ceil(12 / scale), gap = Math.ceil(8 / scale), header = Math.ceil(56 / scale);
  const x = Math.max(padding, Math.round((bounds.width - 1040 / scale) / 2)), width = bounds.width - x * 2;
  const inlineModes = bounds.width * scale >= 680;
  const top = padding + header + gap;
  return { x, width, top, padding, gap, header, inlineModes };
}

function collectionBounds(bounds, { shelf = true } = {}) {
  const scale = uiScale(bounds), compact = bounds.height * bounds.scale < 500;
  const padding = Math.ceil((compact ? 8 : 12) / scale), gap = Math.ceil((compact ? 6 : 8) / scale);
  const x = Math.max(padding, Math.round((bounds.width - 960 / scale) / 2)), width = bounds.width - x * 2;
  const headerHeight = Math.ceil(48 / scale), ageHeight = headerHeight, ageTop = padding;
  const ageX = x + Math.ceil(40 / scale) + gap;
  const ageWidth = width - Math.ceil(40 / scale) - Math.ceil(44 / scale) - gap * 2;
  const themeHeight = Math.ceil((compact ? 44 : 52) / scale);
  const shelfHeight = shelf ? (compact ? 76 : 104) / scale : 0, shelfItemWidth = 216 / scale;
  const shelfTop = bounds.height - padding - shelfHeight, themeTop = shelfTop - (shelf ? gap : 0) - themeHeight;
  const playerMenuHeight = Math.ceil(40 / scale);
  const top = padding + headerHeight + gap + playerMenuHeight + gap, roomHeight = Math.max(0, themeTop - gap - top);
  return { x, width, top, padding, gap, compact, headerHeight, ageTop, ageHeight, ageX, ageWidth,
    themeTop, themeHeight, shelfTop, shelfHeight, shelfItemWidth, roomHeight,
    worldSide: themeHeight, worldGap: Math.round(6 / scale) };
}

function ageButtonRect(bounds, id, scroll = 0) {
  const index = ['all', '4-6', '7-9', '10-plus'].indexOf(id);
  if (index < 0) throw new Error(`Unknown age level: ${id}`);
  const { ageX, ageWidth, ageTop } = collectionBounds(bounds), scale = uiScale(bounds);
  const labelWidth = Math.ceil(30 / scale), buttonWidth = Math.ceil(52 / scale), gap = Math.round(6 / scale);
  const rowWidth = labelWidth + 4 * (buttonWidth + gap);
  return { x: ageX + Math.max(0, (ageWidth - rowWidth) / 2) + labelWidth + gap + index * (buttonWidth + gap) - scroll,
    y: ageTop, width: buttonWidth, height: Math.ceil(48 / scale) };
}

function collectionHeaderRect(bounds, section) {
  const { x, width, padding, headerHeight } = collectionBounds(bounds), scale = uiScale(bounds);
  const height = Math.ceil(44 / scale);
  const y = padding + (headerHeight - height) / 2;
  if (section === 'back') return { x: x + width - height, y, width: height, height };
  if (section !== 'room') throw new Error(`Unknown room header item: ${section}`);
  return { x, y, width: Math.ceil(40 / scale), height };
}

function worldIconRect(bounds, index, scroll = 0, options = {}) {
  if (!Number.isInteger(index) || index < 0 || index >= THEME_IDS.length) throw new Error(`Unknown world index: ${index}`);
  const { x, width, themeTop, worldSide: side, worldGap: spacing } = collectionBounds(bounds, options);
  const left = x + Math.max(0, (width - side * THEME_IDS.length - spacing * (THEME_IDS.length - 1)) / 2);
  return { x: left + index * (side + spacing) - scroll, y: themeTop, width: side, height: side };
}

async function focusRoomBack(page, bounds = null) {
  bounds ||= await metrics(page);
  const back = collectionHeaderRect(bounds, 'back'), title = collectionHeaderRect(bounds, 'room');
  await page.mouse.move(bounds.x + (back.x + back.width / 2) * bounds.scale,
    bounds.y + (back.y + back.height / 2) * bounds.scale);
  await page.mouse.down();
  await page.mouse.move(bounds.x + (title.x + title.width / 2) * bounds.scale,
    bounds.y + (title.y + title.height / 2) * bounds.scale);
  await page.mouse.up();
}

async function ageControl(page, id) {
  const index = ['all', '4-6', '7-9', '10-plus'].indexOf(id);
  if (index < 0) throw new Error(`Unknown age level: ${id}`);
  const bounds = await metrics(page), collection = collectionBounds(bounds);
  await focusRoomBack(page, bounds);
  // Visit the last and first choices so their focus visibility resets any prior swipe.
  for (let step = 0; step < 4; step++) { await page.keyboard.press('Shift+Tab'); await rendered(page); }
  const first = ageButtonRect(bounds, 'all'), last = ageButtonRect(bounds, '10-plus');
  const maximum = Math.max(0, last.x + last.width - collection.ageX - collection.ageWidth);
  let scroll = Math.min(maximum, first.x - collection.ageX);
  for (let step = 0; step < index; step++) { await page.keyboard.press('Tab'); await rendered(page); }
  const target = ageButtonRect(bounds, id);
  scroll = Math.max(scroll, target.x + target.width - collection.ageX - collection.ageWidth);
  return ageButtonRect(bounds, id, scroll);
}

async function worldControl(page, index) {
  const bounds = await metrics(page), state = await roomState(page);
  const controls = roomFocusOrder(bounds, state);
  await focusRoomBack(page, bounds);
  for (let step = 0; step <= controls.indexOf(`world-${index}`); step++) {
    await page.keyboard.press('Tab'); await rendered(page);
  }
  const options = { shelf: roomLayout(bounds, state.owned).locked.length > 0 };
  const rect = worldIconRect(bounds, index, 0, options), collection = collectionBounds(bounds, options);
  const visible = worldIconRect(bounds, index, Math.max(0, rect.x + rect.width - collection.x - collection.width), options);
  if ((await page.locator('#game-status').textContent()).includes('Changes not saved.')) {
    // The retry notice lifts the bottom strip. Aim within the overlap with its usual row,
    // avoiding dependence on the platform's exact font height for the notice.
    visible.y -= visible.height / 2;
  }
  return visible;
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
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  await rendered(page);
}

function roomLayout(bounds, owned = ['ball']) {
  const toys = ['ball', ...THEME_IDS];
  owned = toys.filter(toy => toy === 'ball' || owned.includes(toy));
  const locked = toys.filter(toy => !owned.includes(toy));
  const { x, width, top, padding, gap, roomHeight: homeHeight } = collectionBounds(bounds, { shelf: locked.length > 0 });
  const scale = uiScale(bounds), homes = {}, count = owned.length;
  const left = Math.min(120, width * 0.32), areaWidth = Math.max(1, width - left - 12), areaHeight = Math.max(1, homeHeight - 24);
  let columns = 1, tileSize = 0;
  for (let candidate = 1; candidate <= count; candidate++) {
    const rows = Math.ceil(count / candidate);
    const size = Math.min(64, (areaWidth - (candidate - 1) * 10) / candidate, (areaHeight - (rows - 1) * 10) / rows - 24);
    if (size >= tileSize) { columns = candidate; tileSize = size; }
  }
  tileSize = Math.max(16, tileSize);
  const rows = Math.ceil(count / columns), cellWidth = areaWidth / columns;
  const gridTop = Math.max(12, homeHeight - 12 - rows * (tileSize + 24) - (rows - 1) * 10);
  for (const [index, toy] of owned.entries()) {
    homes[toy] = count === 1 ? { x: width - Math.min(66, width * 0.23), y: homeHeight - tileSize / 2 - 36 }
      : { x: left + cellWidth * (index % columns + 0.5), y: gridTop + Math.floor(index / columns) * (tileSize + 34) + tileSize / 2 };
  }
  const duckScale = Math.min(1, Math.max(0.25, homeHeight / 160));
  const halfDuck = Math.min(48 * duckScale + 4, width / 2), bottom = Math.max(0, homeHeight - 12);
  const pipX = Math.max(halfDuck, Math.min(Math.min(88, width * 0.16), width - halfDuck));
  const duckEdge = 96 * duckScale, feetInset = (112 * duckScale - duckEdge) / 2 + duckEdge * 8 / 120;
  const floorYAt = x => homeHeight * (0.70 - 0.13 * Math.max(0, Math.min(1, Math.min(x, width - x) / Math.max(1, Math.min(width * 0.13, 92)))));
  const floorTop = Math.min(bottom, Math.max(112 * duckScale + 4,
    Math.max(floorYAt(pipX - duckEdge * 0.33), floorYAt(pipX + duckEdge * 0.33)) + feetInset + 4));
  const pipFoot = { x: pipX,
    y: Math.max(floorTop, Math.min(homeHeight - 32, bottom)) };
  return { x, width, top, padding, gap, scale, owned, locked, homes, homeHeight, tileSize, duckScale, pipFoot };
}

async function roomState(page) {
  const records = await page.evaluate(() => {
    const read = key => {
      try { return localStorage.getItem(key) || ''; }
      catch (error) {
        if (error.name !== 'SecurityError') throw error;
        return '';
      }
    };
    return { saved: read('wordBuddies.playroom'), medals: read('wordBuddies.medalProgress') };
  });
  const counts = Object.fromEntries([...records.medals.matchAll(/"([a-z]+-\d+)"\s*:\s*(\d+)/g)]
    .map(([, id, count]) => [id, Number(count)]));
  return { ...records,
    owned: ['ball', ...THEME_IDS.filter(theme => counts[`${theme}-1`] >= 3)],
    selected: records.saved.match(/^goal_item_id="toy-([^"]+)"/m)?.[1] || '',
    equipped: records.saved.match(/^toy="toy-([^"]+)"/m)?.[1] || 'ball'
  };
}

function roomPoint(bounds, name, { item = '', owned = ['ball'], equipped = 'ball' } = {}) {
  const layout = roomLayout(bounds, owned);
  const { x, width, top, scale, gap } = layout;
  if (name === 'pip') return { x: x + layout.pipFoot.x, y: top + layout.pipFoot.y - 56 * layout.duckScale };
  if (name === 'toy') name = layout.owned.includes(equipped) ? equipped : 'ball';
  if (name === 'goal') {
    if (!item) throw new Error('The inline goal control needs its toy card name.');
    if (layout.owned.includes(item)) throw new Error('Earned toys are selected directly in Pip\'s home.');
    const card = roomPoint(bounds, item, { owned });
    return { x: card.x + card.width / 2 - 30 / scale, y: card.y };
  }
  const inHome = layout.owned.includes(name);
  if (inHome) return { x: x + layout.homes[name].x,
    y: top + layout.homes[name].y, width: layout.tileSize, height: layout.tileSize, inHome: true };
  const index = layout.locked.indexOf(name);
  if (index < 0) throw new Error(`Unknown room control: ${name}`);
  const { shelfTop, shelfHeight: height, shelfItemWidth: cell } = collectionBounds(bounds);
  const left = index * (cell + gap), scroll = Math.max(0, left + cell - width);
  return {
    x: x + left - scroll + cell / 2, y: shelfTop + height / 2,
    width: cell, height, inHome
  };
}

async function roomControl(page, name, { locked = false, item = '' } = {}) {
  const bounds = await metrics(page);
  const state = await roomState(page), layout = roomLayout(bounds, state.owned);
  const active = locked ? item : state.selected;
  const equipped = layout.owned.includes(state.equipped) ? state.equipped : 'ball';
  const target = name === 'toy' ? equipped : name;
  if (name === 'toy' && locked) throw new Error('A locked preview has no active playable toy; select an owned object.');
  await focusRoomBack(page, bounds);
  const beforeFocus = target === 'pip' ? await page.screenshot({ scale: 'css' }) : null;
  const controls = roomFocusOrder(bounds, state, { locked, item });
  if (!controls.includes(target)) throw new Error(`Unavailable room control: ${name}`);
  for (let index = 0; index <= controls.indexOf(target); index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  if (beforeFocus) {
    // Pip can retain a position after a resize. Find its visible focus response
    // instead of treating the nominal home coordinate as the current actor position.
    const afterFocus = await page.screenshot({ scale: 'css' });
    const center = await page.evaluate(async ({ before, after, bounds, layout }) => {
      const images = await Promise.all([before, after].map(async png => {
        const image = new Image();
        image.src = 'data:image/png;base64,' + png;
        await image.decode();
        return image;
      }));
      const canvas = document.createElement('canvas');
      canvas.width = images[0].width; canvas.height = images[0].height;
      const context = canvas.getContext('2d');
      const frames = images.map(image => {
        context.clearRect(0, 0, canvas.width, canvas.height);
        context.drawImage(image, 0, 0);
        return context.getImageData(0, 0, canvas.width, canvas.height).data;
      });
      let left = canvas.width, top = canvas.height, right = -1, bottom = -1;
      const startX = Math.max(0, Math.ceil(bounds.x + layout.x * bounds.scale));
      const startY = Math.max(0, Math.ceil(bounds.y + layout.top * bounds.scale));
      const endX = Math.min(canvas.width, Math.floor(bounds.x + (layout.x + layout.width) * bounds.scale));
      const endY = Math.min(canvas.height, Math.floor(bounds.y + (layout.top + layout.homeHeight) * bounds.scale));
      for (let y = startY; y < endY; y++) {
        for (let x = startX; x < endX; x++) {
          const offset = (y * canvas.width + x) * 4;
          if ([0, 1, 2].every(channel => Math.abs(frames[0][offset + channel] - frames[1][offset + channel]) < 24)) continue;
          left = Math.min(left, x); right = Math.max(right, x);
          top = Math.min(top, y); bottom = Math.max(bottom, y);
        }
      }
      return right > left && bottom > top ? {
        x: ((left + right) / 2 - bounds.x) / bounds.scale,
        y: ((top + bottom) / 2 - bounds.y) / bounds.scale
      } : null;
    }, { before: beforeFocus.toString('base64'), after: afterFocus.toString('base64'), bounds, layout });
    expect(center, 'The real room must visibly focus Pip before a pointer interaction.').not.toBeNull();
    return center;
  }
  return roomPoint(bounds, target, { item: active, owned: layout.owned, equipped });
}

function roomFocusOrder(bounds, state, { locked = false, item = '' } = {}) {
  const layout = roomLayout(bounds, state.owned), active = locked ? item : state.selected;
  const equipped = layout.owned.includes(state.equipped) ? state.equipped : 'ball';
  const controls = ['players', 'leaderboards', 'pip', ...(locked ? [] : [equipped]), ...layout.owned.filter(toy => locked || toy !== equipped),
    ...THEME_IDS.map((_, index) => `world-${index}`)];
  for (const toy of layout.locked) {
    controls.push(toy);
    if (toy === active) controls.push('goal');
  }
  return controls;
}

async function leaveRoomPreview(page, { item = '' } = {}) {
  const { equipped } = await roomState(page);
  await roomControl(page, equipped, { locked: true, item });
  await page.keyboard.press('Enter');
  await rendered(page);
}

async function dragRoomToy(page, name, input = 'mouse') {
  if (!['mouse', 'touch'].includes(input)) throw new Error(`Unknown toy drag input: ${input}`);
  const toy = await roomControl(page, name), bounds = await metrics(page);
  const points = [0, 20, 44].map(offset => ({
    x: bounds.x + (toy.x - offset) * bounds.scale,
    y: bounds.y + (toy.y - offset) * bounds.scale
  }));
  if (input === 'mouse') {
    await page.mouse.move(points[0].x, points[0].y);
    await page.mouse.down();
    try {
      for (const point of points.slice(1)) {
        await page.mouse.move(point.x, point.y, { steps: 3 });
        await rendered(page);
      }
    } finally {
      await page.mouse.up();
    }
  } else {
    const client = await page.context().newCDPSession(page);
    let pressed = false;
    try {
      for (const [index, point] of points.entries()) {
        await client.send('Input.dispatchTouchEvent', {
          type: index === 0 ? 'touchStart' : 'touchMove', touchPoints: [{ id: 1, ...point }]
        });
        pressed = true;
        await rendered(page);
      }
    } finally {
      if (pressed) await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await client.detach();
    }
  }
  await rendered(page);
  return points;
}

async function rendered(page) {
  await page.locator('#canvas').evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function leaderboardSnapshot(scope) {
  return scope.locator('#leaderboard-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));
}

async function leaderboardControl(scope, name) {
  await expect.poll(async () => (await leaderboardSnapshot(scope)).controls?.some(item => item.name === name),
    { message: `${name} is exposed by the visible interface` }).toBe(true);
  return (await leaderboardSnapshot(scope)).controls.find(item => item.name === name);
}

async function focusLeaderboardControl(scope, name) {
  for (let attempt = 0; attempt < 55; attempt++) {
    const current = await leaderboardSnapshot(scope);
    const target = current.controls?.find(item => item.name === name);
    if (target?.focused) return target;
    await scope.locator('#canvas').press('Tab');
    // Focus diagnostics are sampled every 100 ms, including within an iframe.
    await scope.locator('#canvas').evaluate(() => new Promise(resolve => setTimeout(resolve, 130)));
  }
  throw new Error(`Keyboard navigation did not reach ${name}: ${JSON.stringify(await leaderboardSnapshot(scope))}`);
}

async function activateLeaderboardControl(scope, name) {
  let item = await leaderboardControl(scope, name);
  await expect.poll(async () => (await leaderboardSnapshot(scope)).controls.find(entry => entry.name === name)?.disabled,
    { message: `${name} is available` }).toBe(false);
  const bounds = await metrics(scope), current = await leaderboardSnapshot(scope);
  item = current.controls.find(entry => entry.name === name);
  const back = current.controls.find(entry => entry.name === 'LeaderboardClose');
  const content = contentBounds(bounds), inset = 16 / uiScale(bounds);
  const insidePanel = current.visible && name !== 'LeaderboardClose';
  const top = insidePanel ? current.modal ? back ? back.rect[1] + back.rect[3] : content.padding : content.top + inset : 0;
  const bottom = insidePanel ? bounds.height - content.padding - (current.modal ? 0 : inset) : bounds.height;
  const fitsViewport = ([left, upper, width, height]) => left >= 0 && upper >= top &&
    left + width <= bounds.width + 1 && upper + height <= bottom + 1;
  if (!fitsViewport(item.rect)) {
    // Refocusing also reveals a button displaced by a newly inserted save error.
    if (item.focused) {
      await scope.locator('#canvas').press('Shift+Tab');
      await scope.locator('#canvas').evaluate(() => new Promise(resolve => setTimeout(resolve, 130)));
    }
    item = await focusLeaderboardControl(scope, name);
    await expect.poll(async () => {
      item = (await leaderboardSnapshot(scope)).controls.find(entry => entry.name === name);
      return fitsViewport(item.rect);
    }, { message: `${name} is fully inside its scroll viewport` }).toBe(true);
  }
  const [x, y, width, height] = item.rect;
  expect(width, `${name} has a nonempty target`).toBeGreaterThan(0);
  expect(height, `${name} has a nonempty target`).toBeGreaterThan(0);
  if (scope.touchscreen) {
    await tap(scope, x + width / 2, y + height / 2);
  } else {
    // A locator-relative pointer gesture also works in embedded game frames.
    await scope.locator('#canvas').click({ position: { x: (x + width / 2) * bounds.scale, y: (y + height / 2) * bounds.scale } });
  }
  await rendered(scope);
}

async function typeLeaderboardName(scope, name) {
  await activateLeaderboardControl(scope, 'LeaderboardName');
  const nativeEditor = scope.locator('input:focus, textarea:focus');
  if (await nativeEditor.count()) {
    // Keep focus on the mobile DOM bridge so software-keyboard input reaches
    // Godot. Focusing the canvas here would bypass the path real phones use.
    await nativeEditor.fill(name);
  } else {
    await scope.locator('#canvas').pressSequentially(name);
  }
  await rendered(scope);
}

async function finishOnboarding(scope, { name = 'Test player', avatar = 'fox' } = {}) {
  await expect.poll(async () => typeof (await leaderboardSnapshot(scope)).visible,
    { message: 'The first-entry player gate is initialized' }).toBe('boolean');
  if ((await leaderboardSnapshot(scope)).view !== 'onboarding') return;
  await activateLeaderboardControl(scope, `LeaderboardAvatar_${avatar}`);
  await typeLeaderboardName(scope, name);
  await activateLeaderboardControl(scope, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await leaderboardSnapshot(scope)).view || '',
    { message: 'A durable first player unlocks entry to the game' }).not.toBe('onboarding');
}

async function chooseRoundPlayer(scope, { playerId } = {}) {
  await expect.poll(async () => (await leaderboardSnapshot(scope)).view,
    { message: 'Every fresh Voice Pop round requires a player before it starts' }).toBe('picker');
  const current = await leaderboardSnapshot(scope);
  const chosen = playerId || current.profiles[0]?.id;
  expect(chosen, 'A registered player is available before starting Voice Pop').toBeTruthy();
  await activateLeaderboardControl(scope, `LeaderboardPlayer_${chosen}`);
  await expect.poll(async () => (await leaderboardSnapshot(scope)).view || '',
    { message: 'One player gesture starts the round without another confirmation' }).not.toBe('picker');
}

async function observeAudio(page, { fingerprintBuffers = false, phaseSelector = '', trackSourceLifecycle = false } = {}) {
  await page.addInitScript(({ fingerprintBuffers, phaseSelector, trackSourceLifecycle }) => {
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.audioObservation = { available: Boolean(NativeContext), contexts: [], starts: 0, playbacks: [] };
    if (!NativeContext) return;
    const fingerprints = new WeakMap();
    function fingerprint(buffer) {
      if (!fingerprintBuffers || buffer.duration > 1) return undefined;
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
  }, { fingerprintBuffers, phaseSelector, trackSourceLifecycle });
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

async function enterGame(scope, { onboarding = true } = {}) {
  await expect(scope.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  const enter = scope.locator('#enter-game');
  await expect(enter).toBeVisible();
  await expect(enter).toBeEnabled();
  await expect(scope.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await enter.click();
  await expect(scope.locator('body')).toHaveAttribute('data-engine-ready', 'true');
  await expect(scope.locator('#status')).toBeHidden();
  if (onboarding) await finishOnboarding(scope);
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
  const { top: normalTop, x, width: areaWidth } = contentBounds(bounds);
  const top = overrideTop === undefined ? normalTop : overrideTop;
  if (!Number.isFinite(top) || top < 0 || top >= bounds.height) throw new Error('Invalid Match playfield top.');
  const areaHeight = bounds.height - top - contentBounds(bounds).padding;
  const columns = areaWidth >= areaHeight || areaHeight < 318 ? 5 : 2;
  const rows = 10 / columns;
  const width = (areaWidth - (columns - 1) * 10) / columns;
  const cellHeight = (areaHeight - (rows - 1) * 10) / rows;
  return { x: x + (index % columns) * (width + 10) + width / 2,
    y: top + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2 };
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

function resultPoint(bounds, key, { gift = false, message = false } = {}) {
  if (!['chest', 'review', 'gift', 'newAdventure', 'retry'].includes(key)) throw new Error(`Unknown result action: ${key}`);
  gift ||= key === 'gift';
  message ||= gift || key === 'retry';
  const content = contentBounds(bounds);
  const scale = uiScale(bounds), actionHeight = Math.ceil((key === 'retry' ? 48 : 64) / scale);
  const secondaryHeight = Math.ceil(48 / scale), actionGap = Math.ceil(8 / scale);
  const top = content.padding + content.header + content.gap;
  const extra = gift ? secondaryHeight + actionGap : 0;
  const availableHeight = bounds.height - content.padding - top;
  const textGap = Math.ceil((availableHeight < 340 ? 8 : 14) / scale);
  const minimumTextHeight = actionHeight + extra + 88 + textGap + (message ? 72 + textGap * 2 : 0);
  const landscape = (message && bounds.width >= bounds.height) || availableHeight < minimumTextHeight + 82;
  const actionWidth = Math.min((key === 'retry' ? 176 : 320) / scale, content.width);
  const textWidth = landscape ? Math.max(actionWidth, 232, (content.width - 16) * 0.39) : content.width;
  const left = content.x + content.width - textWidth;
  if (key === 'chest') return { x: content.x + 36, y: top + 116 };
  if (key === 'gift') return { x: left + textWidth / 2, y: bounds.height - content.padding - 88 - textGap - secondaryHeight / 2 };
  if (key === 'review') return { x: left + 36, y: bounds.height - content.padding - 44 };
  return { x: left + textWidth / 2,
    y: bounds.height - content.padding - 88 - textGap - actionHeight / 2 - extra };
}

module.exports = { THEME_IDS, THEME_COLORS, MODES, metrics, tap, uiScale, modeHeight, modeRect, openModeMenu, chooseMode, chooseTheme, contentBounds, collectionBounds, collectionHeaderRect, worldIconRect, worldControl, ageButtonRect, ageControl, headerPoint, headerIconRect, pipHeaderRect,
  progressRegion, openRewards, roomLayout, roomState, roomPoint, roomControl, leaveRoomPreview, dragRoomToy, rendered, observeAudio, enterGame, openGame, boardPoint, discoverMatchCards, matchWords,
  leaderboardSnapshot, leaderboardControl, focusLeaderboardControl, activateLeaderboardControl, typeLeaderboardName, finishOnboarding, chooseRoundPlayer,
  memoryMetrics, memoryLayout, memoryCardRect, memoryPoint, peekPoint, withMemoryPeek, resultPoint, visibleColorCount };
