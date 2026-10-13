const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, metrics, tap, rendered, enterGame, observeAudio, seedGrowth } = require('./game-ui.cjs');
const { recordingTiming, expectRecording } = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const normalize = text => text.trim().toLowerCase().replace(/\s+/g, ' ');

async function pressRect(page, rect) {
  expect(rect).toHaveLength(4);
  const [x, y, width, height] = rect;
  expect(width).toBeGreaterThan(0);
  expect(height).toBeGreaterThan(0);
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function startWordJelly(page, { age = 3, reducedMotion = 'no-preference', preseededGrowth = false } = {}) {
  const earnedAge = age === 3 ? 0 : age - 1;
  if (!preseededGrowth) await page.addInitScript(earnedAge => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=3\nlevel=0\nage=${earnedAge}\nstreaks={}\nmastered_words=[]\nreceipts=[]\n`);
  }, earnedAge);
  const errors = await openGame(page, { reducedMotion });
  await openModeMenu(page);
  const control = (await metrics(page)).library.controls.find(item => item.name === 'Mode_word_jelly');
  expect(control, 'Word Jelly appears in the ordinary game library').toBeTruthy();
  expect(control.disabled).toBe(false);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.tiles?.length >= 18 && state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Word Jelly board opens with three rows of settled roots' }).toBe(true);
  return errors;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

function rootsForWord(state, age, count, markedOnly = false, invalidReverse = false) {
  const words = new Map(vocabulary.filter(word => word.min_age === age).map(word => [normalize(word.text), word]));
  const roots = state.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1);
  for (const first of roots) for (const second of roots) {
    if (first.id === second.id) continue;
    const prefix = first.text + second.text;
    if (count === 2 && words.has(normalize(prefix)) && (!markedOnly || first.fragments + second.fragments > 0) &&
      (!invalidReverse || !words.has(normalize(second.text + first.text))))
      return { roots: [first, second], word: words.get(normalize(prefix)) };
  }
  return null;
}

async function availableWord(page, age, count, { markedOnly = false, invalidReverse = false } = {}) {
  for (let attempt = 0; attempt < 4; attempt++) {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page), found = rootsForWord(state, age, count, markedOnly, invalidReverse);
    if (found) return found;
    expect(state.preview.enabled, 'The ordinary preview can supply another complete word packet').toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  throw new Error(`The current age ${age} supply did not provide a ${count}-part word.`);
}

async function merge(page, sourceId, targetId) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === sourceId), target = before.tiles.find(tile => tile.id === targetId);
  expect(source?.settled, 'The held jelly is ready').toBe(true);
  expect(target?.settled, 'The destination jelly is ready').toBe(true);
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(sourceId);
    await page.mouse.move(to.x, to.y, { steps: 12 });
    await expect.poll(async () => (await jelly(page)).drag.target).toBe(targetId);
  } finally {
    await page.mouse.up();
  }
  let result;
  await expect.poll(async () => {
    const state = await jelly(page);
    result = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.text === source.text + target.text && tile.mass === source.mass + target.mass);
    return state.merged_count === before.merged_count + 1 && Boolean(result?.settled) &&
      before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId).every(original =>
        state.tiles.some(tile => tile.id === original.id && tile.settled));
  }, { message: 'The union settles into a persistent larger jelly in source-then-target order' }).toBe(true);
  const after = await jelly(page);
  expect(after.tiles.some(tile => tile.id === sourceId || tile.id === targetId)).toBe(false);
  expect(after.cleared_pairs, 'Merging does not automatically collect a word').toBe(before.cleared_pairs);
  expect(after.fragment_count, 'Carried fragments are collected only after a valid word is tapped').toBe(before.fragment_count);
  expect(result.fragments).toBe(source.fragments + target.fragments);
  expect(result.placement_locked, 'Automatic merging releases any previous manual placement').toBe(false);
  expectSupportedChild(after, result);
  for (const original of before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId && tile.settled)) {
    const unchanged = after.tiles.find(tile => tile.id === original.id);
    expect(unchanged, 'Merging preserves every unrelated jelly').toBeTruthy();
    if (original.placement_locked) {
      expect([unchanged.width, unchanged.height], 'Merging preserves an unrelated player-chosen footprint')
        .toEqual([original.width, original.height]);
    }
    const expanded = unchanged.width !== original.width || unchanged.height !== original.height;
    if (expanded) {
      const compressed = original.width < Math.min(before.columns, original.mass) ||
        original.height < Math.min(before.rows, Math.ceil(original.mass / before.columns));
      expect(compressed, 'Only an already compressed jelly can expand when a merge frees space').toBe(true);
      expect(unchanged.width).toBeGreaterThanOrEqual(original.width);
      expect(unchanged.height).toBeGreaterThanOrEqual(original.height);
      expectSupportedChild(after, unchanged);
      continue;
    }
    expect(unchanged.column, 'Automatic gravity preserves an unrelated jelly column').toBe(original.column);
    expect(unchanged.row, 'An unsupported neighbor can descend after merging removes its support').toBeGreaterThanOrEqual(original.row);
    expectSupportedChild(after, unchanged);
    for (const axis of [0, 2, 3])
      expect(unchanged.rect[axis], 'Automatic settlement preserves unrelated horizontal positions and sizes')
        .toBeCloseTo(original.rect[axis], 3);
  }
  return result;
}

async function rejectMerge(page, sourceId, targetId, { info, label, reducedMotion = 'no-preference', inspectContact } = {}) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === sourceId), target = before.tiles.find(tile => tile.id === targetId);
  const contents = tile => ({ id: tile.id, text: tile.text, mass: tile.mass, word: tile.word,
    fragments: tile.fragments, badges: tile.fragment_badges, picture: tile.picture_visible, coins: tile.coins });
  expect(source?.settled).toBe(true);
  expect(target?.settled).toBe(true);
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  to.y -= target.rect[3] * bounds.scale * 0.34;
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  let held;
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(sourceId);
    await page.mouse.move(to.x, to.y, { steps: 8 });
    await expect.poll(async () => (await jelly(page)).contact).toMatchObject({ kind: 'touch', source: sourceId, target: targetId });
    held = await jelly(page);
    expect(held.contact.strength, 'An incompatible pair still responds to physical contact').toBeGreaterThan(0);
    expect(held.tiles.find(tile => tile.id === targetId).completion_hint).toBe(false);
    if (inspectContact) await inspectContact(held);
    await page.evaluate(({ sourceId, targetId }) => {
      const status = document.getElementById('game-status');
      const evidence = window.wordJellyRejection = { releaseAt: null, timeline: [], frame: null };
      let capturing = false;
      window.wordJellyRejectionInput = () => { evidence.releaseAt = performance.now(); };
      document.addEventListener('pointerup', window.wordJellyRejectionInput, { capture: true, once: true });
      window.wordJellyRejectionObserver = new MutationObserver(() => {
        if (evidence.releaseAt === null) return;
        const state = JSON.parse(status.dataset.jelly || '{}');
        const tracked = state.tiles?.filter(tile => tile.id === sourceId || tile.id === targetId) || [];
        evidence.timeline.push({ at: performance.now(), contact: state.contact, tiles: tracked,
          merged: state.merged_count, fusions: state.fusions, cleared: state.cleared_pairs,
          coins: state.collected_coins, fragments: state.fragment_count });
        if (!capturing && state.contact?.kind === 'mismatch' && state.contact.strength > 0.15) {
          capturing = true;
          document.getElementById('canvas').toBlob(blob => {
            if (!blob) return;
            const reader = new FileReader();
            reader.onload = () => { evidence.frame = reader.result.split(',')[1]; };
            reader.readAsDataURL(blob);
          }, 'image/png');
        }
      });
      window.wordJellyRejectionObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    }, { sourceId, targetId });
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.drag.active && state.contact.kind === 'none' && [source, target].every(original => {
      const tile = state.tiles.find(item => item.id === original.id);
      return tile?.settled && tile.rect.every((value, axis) => Math.abs(value - original.rect[axis]) < 0.1);
    });
  }, { message: 'The rejected pair visibly separates and returns to its supported positions' }).toBe(true);
  const after = await jelly(page);
  const evidence = await page.evaluate(() => {
    window.wordJellyRejectionObserver.disconnect();
    document.removeEventListener('pointerup', window.wordJellyRejectionInput, { capture: true });
    return window.wordJellyRejection;
  });
  if (info) fs.writeFileSync(info.outputPath(`${label}-timeline.json`), JSON.stringify({ before, held, after,
    ...evidence, frame: Boolean(evidence.frame) }, null, 2));
  expect(evidence.releaseAt).not.toBeNull();
  expect(evidence.timeline.some(frame => frame.contact.kind === 'mismatch'),
    'The release produces a visible rejection cue').toBe(true);
  for (const frame of evidence.timeline) {
    expect(frame.tiles).toHaveLength(2);
    for (const original of [source, target]) expect(contents(frame.tiles.find(tile => tile.id === original.id))).toEqual(contents(original));
    expect(frame.merged).toBe(before.merged_count);
    expect(frame.cleared).toBe(before.cleared_pairs);
    expect(frame.coins).toBe(before.collected_coins);
    expect(frame.fragments).toBe(before.fragment_count);
    expect(frame.fusions, 'A rejected release never creates a merge or collection operation').toEqual([]);
  }
  for (const original of before.tiles) expect(after.tiles.some(tile => tile.id === original.id), 'Rejection never consumes an original body').toBe(true);
  for (const original of [source, target]) expectSupportedChild(after, after.tiles.find(tile => tile.id === original.id));
  const heldSource = held.tiles.find(tile => tile.id === sourceId);
  const separation = rect => Math.hypot(rect[0] + rect[2] / 2 - target.rect[0] - target.rect[2] / 2,
    rect[1] + rect[3] / 2 - target.rect[1] - target.rect[3] / 2);
  const poses = evidence.timeline.map(frame => frame.tiles.find(tile => tile.id === sourceId).rect);
  expect(separation(source.rect), 'The source finishes visibly separated from the rejected target').toBeGreaterThan(separation(heldSource.rect));
  if (reducedMotion !== 'reduce') expect(poses.some(rect =>
    Math.hypot(rect[0] - heldSource.rect[0], rect[1] - heldSource.rect[1]) > 0.5 &&
    Math.hypot(rect[0] - source.rect[0], rect[1] - source.rect[1]) > 0.5),
  'The rejected body has a visible separating pose before it returns').toBe(true);
  if (info) {
    await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyRejection.frame)),
      { message: 'The rejection cue retains a real rendered frame' }).toBe(true);
    const frame = await page.evaluate(() => window.wordJellyRejection.frame);
    fs.writeFileSync(info.outputPath(`${label}-separating.png`), Buffer.from(frame, 'base64'));
    await capture(page, info, `${label}-restored`);
  }
  return { before, held, after, ...evidence };
}

async function capture(page, info, name) {
  await rendered(page);
  await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
  const image = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), Buffer.from(image, 'base64'));
}

function expectInside(rect, bounds) {
  expect(rect.every(Number.isFinite)).toBe(true);
  expect(rect[0]).toBeGreaterThanOrEqual(-1);
  expect(rect[1]).toBeGreaterThanOrEqual(-1);
  expect(rect[2]).toBeGreaterThan(0);
  expect(rect[3]).toBeGreaterThan(0);
  expect(rect[0] + rect[2]).toBeLessThanOrEqual(bounds.width + 1);
  expect(rect[1] + rect[3]).toBeLessThanOrEqual(bounds.height + 1);
}

function expectWordRevealContent(entry, bounds, area) {
  for (const rect of [entry.rect, entry.resting_rect, entry.picture_rect, entry.spelling_rect]) expectInside(rect, bounds);
  expect(entry.rect[1] + entry.rect[3], 'Each independent word remains in the upper part of the playfield')
    .toBeLessThan(area[1] + area[3] * 0.42);
  const [x, y, width, height] = entry.rect;
  for (const rect of [entry.picture_rect, entry.spelling_rect]) {
    expect(rect[0], 'Word content remains inside its own card').toBeGreaterThanOrEqual(x - 1);
    expect(rect[1], 'Word content remains inside its own card').toBeGreaterThanOrEqual(y - 1);
    expect(rect[0] + rect[2], 'Word content remains inside its own card').toBeLessThanOrEqual(x + width + 1);
    expect(rect[1] + rect[3], 'Word content remains inside its own card').toBeLessThanOrEqual(y + height + 1);
  }
  expect(entry.picture_rect[0] + entry.picture_rect[2], 'Picture and spelling have distinct reading space')
    .toBeLessThan(entry.spelling_rect[0]);
  const contentWidth = entry.spelling_rect[0] + entry.spelling_rect[2] - entry.picture_rect[0];
  const contentHeight = Math.max(entry.picture_rect[1] + entry.picture_rect[3], entry.spelling_rect[1] + entry.spelling_rect[3]) -
    Math.min(entry.picture_rect[1], entry.spelling_rect[1]);
  expect(width, 'The card fits its picture and spelling without a wide empty fixed-size shell').toBeLessThan(contentWidth * 1.6);
  expect(height, 'The card height follows its content with modest padding').toBeLessThan(contentHeight * 1.7);
}

function expectSupplyLayout(state, bounds) {
  const board = state.board_rect, tray = state.preview.rect, area = state.playfield_rect;
  const scale = Math.max(2 / 3, bounds.scale), tolerance = 0.25 / bounds.scale;
  const inside = (rect, parent, label) => {
    expect(rect.every(Number.isFinite), `${label} has finite bounds`).toBe(true);
    expect(rect[2], `${label} has visible width`).toBeGreaterThan(0);
    expect(rect[3], `${label} has visible height`).toBeGreaterThan(0);
    expect(rect[0], `${label} is inside the left edge`).toBeGreaterThanOrEqual(parent[0] - tolerance);
    expect(rect[1], `${label} is inside the top edge`).toBeGreaterThanOrEqual(parent[1] - tolerance);
    expect(rect[0] + rect[2], `${label} is inside the right edge`).toBeLessThanOrEqual(parent[0] + parent[2] + tolerance);
    expect(rect[1] + rect[3], `${label} is inside the bottom edge`).toBeLessThanOrEqual(parent[1] + parent[3] + tolerance);
  };
  expect(Math.abs(tray[0] - board[0]), 'The supply tray starts at the well left edge').toBeLessThan(tolerance);
  expect(Math.abs(tray[2] - board[2]), 'The supply tray is exactly as wide as the six-column well').toBeLessThan(tolerance);
  expect(tray[1] + tray[3], 'The supply tray stays above the well').toBeLessThanOrEqual(board[1] + tolerance);
  for (const [axis, value] of state.preview.control.rect.entries())
    expect(Math.abs(value - tray[axis]), 'The whole tray remains the manual drop target').toBeLessThan(tolerance);
  expect(state.preview.slots).toHaveLength(6);
  for (const [index, slot] of state.preview.slots.entries()) {
    expect(slot.visible, `Preview ${index} stays visible`).toBe(true);
    inside(slot.rect, tray, `Preview ${index}`);
    expect(Math.abs(slot.rect[0] + slot.rect[2] / 2 - (board[0] + (index + 0.5) * board[2] / 6)),
      `Preview ${index} is centered over its well column`).toBeLessThan(tolerance);
  }
  const regions = [['well', board], ['supply tray', tray], ['Collect words', state.collect_button.rect],
    ...Object.entries(state.powerup_buttons).map(([kind, button]) => [kind, button.rect])];
  inside(area, [0, 0, bounds.width, bounds.height], 'Jelly Words playfield');
  for (const [index, [label, rect]] of regions.entries()) {
    inside(rect, area, label);
    for (const [otherLabel, other] of regions.slice(index + 1)) {
      const width = Math.min(rect[0] + rect[2], other[0] + other[2]) - Math.max(rect[0], other[0]);
      const height = Math.min(rect[1] + rect[3], other[1] + other[3]) - Math.max(rect[1], other[1]);
      expect(width <= tolerance || height <= tolerance, `${label} and ${otherLabel} do not overlap`).toBe(true);
    }
  }
  const chest = state.loot.progress.rect;
  inside(chest, [0, 0, bounds.width, bounds.height], 'Header chest');
  inside(state.loot.rect, chest, 'Chest artwork');
  expect(chest[1] + chest[3] + 4 / scale,
    'The chest uses the header without reserving playfield space').toBeLessThanOrEqual(area[1] + tolerance);
  expect(chest[2] * scale, 'The header chest keeps its full touch width').toBeGreaterThanOrEqual(43.75);
  expect(chest[3] * scale, 'The header chest keeps its full touch height').toBeGreaterThanOrEqual(43.75);
  for (const [label, rect] of [...regions, ['Finish', state.finish.rect]]) {
    const width = Math.min(chest[0] + chest[2], rect[0] + rect[2]) - Math.max(chest[0], rect[0]);
    const height = Math.min(chest[1] + chest[3], rect[1] + rect[3]) - Math.max(chest[1], rect[1]);
    expect(width <= tolerance || height <= tolerance, `Header chest and ${label} do not overlap`).toBe(true);
  }
  inside(state.finish.rect, [0, 0, bounds.width, bounds.height], 'Header Finish');
  expect(state.finish.visible, 'Finish is visible in the active round header').toBe(true);
  expect(state.finish.rect[1] + state.finish.rect[3] + 4 / scale,
    'Finish stays above the playfield with a separate header gap').toBeLessThanOrEqual(area[1] + tolerance);
  expect(state.collect_button.rect[1] - state.finish.rect[1] - state.finish.rect[3],
    'Collect words remains well below the header Finish target').toBeGreaterThanOrEqual(16 / scale - tolerance);
  expect(tray[3] * scale, 'The supply tray retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  expect(state.finish.rect[3] * scale, 'Finish retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  expect(state.collect_button.rect[3] * scale, 'Collect words retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  const bottom = Math.max(...regions.map(([, rect]) => rect[1] + rect[3]));
  expect(Math.abs(bottom - (area[1] + area[3] - 12 / scale)), 'The game retains twelve-pixel bottom padding').toBeLessThan(tolerance);
}

function expectSupportedChild(state, child) {
  const resting = state.tiles.filter(tile => !tile.lifted);
  const bottom = child.row + child.height;
  const supported = bottom === state.rows || resting.some(other => other.id !== child.id &&
    other.row === bottom && other.column < child.column + child.width && other.column + other.width > child.column);
  expect(supported, `Jelly ${child.text} touches the floor or an occupied footprint immediately below`).toBe(true);
  for (const other of resting.filter(tile => tile.id !== child.id)) {
    const overlaps = child.column < other.column + other.width && child.column + child.width > other.column &&
      child.row < other.row + other.height && child.row + child.height > other.row;
    expect(overlaps, `Jelly ${child.text} cannot overlap jelly ${other.id}`).toBe(false);
  }
}

function expectMixedRootPacket(roots, label) {
  expect(roots, `${label} contains six roots`).toHaveLength(6);
  expect(new Set(roots.map(root => root.supply_group)).size,
    `${label} contains parts from several words`).toBeGreaterThan(1);
  for (const [index, root] of roots.entries()) {
    expect(Number.isInteger(root.supply_group), `${label}: root provenance remains available`).toBe(true);
    expect(root.source_word_id, `${label}: every root retains its vocabulary identity`).toBeTruthy();
    if (index > 0) expect(root.supply_group,
      `${label}: parts from the same supplied word have another root between them`)
      .not.toBe(roots[index - 1].supply_group);
  }
}

function expectRootBreathingRoom(roots, pitch, label) {
  const ordered = [...roots].sort((a, b) => a.rect[0] - b.rect[0]);
  for (let index = 1; index < ordered.length; index++) {
    const previous = ordered[index - 1].rect, current = ordered[index].rect;
    expect(current[0] - previous[0] - previous[2],
      `${label}: neighboring root bodies retain visible breathing room`).toBeGreaterThanOrEqual(pitch * 0.08);
  }
}

async function observeArrival(page, before) {
  await page.evaluate(before => {
    window.wordJellyArrivalObserver?.disconnect();
    const status = document.getElementById('game-status');
    const wanted = new Set(before.upcoming.map(tile => tile.id));
    window.wordJellyArrivalTimeline = [];
    window.wordJellyArrivalFrame = null;
    window.wordJellyStaggerFrame = null;
    let capturePending = false;
    let staggerCapturePending = false;
    const source = before.preview.slots.find(slot => slot.id === before.upcoming[0].id);
    const capture = key => document.getElementById('canvas').toBlob(blob => {
      if (!blob) return;
      const reader = new FileReader();
      reader.onload = () => { window[key] = reader.result.split(',')[1]; };
      reader.readAsDataURL(blob);
    }, 'image/png');
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tracked = state.tiles?.filter(tile => wanted.has(tile.id)) || [];
      if (!tracked.length) return;
      window.wordJellyArrivalTimeline.push({ tiles: tracked, preview: state.preview.slots, time: performance.now() });
      const first = tracked.find(tile => tile.id === source.id);
      const boardPitch = state.board_rect[3] / state.rows;
      const targetY = state.board_rect[1] + (first?.row + 0.5) * boardPitch;
      const sourceY = source.rect[1] + source.rect[3] / 2;
      const progress = first && (first.rect[1] + first.rect[3] / 2 - sourceY) / (targetY - sourceY);
      if (!capturePending && first && !first.settled && progress > 0.20 && progress < 0.72) {
        capturePending = true;
        // Keep the simulation running while the real intermediate frame is encoded.
        capture('wordJellyArrivalFrame');
      }
      const travel = tracked.map(tile => {
        const preview = before.preview.slots.find(slot => slot.id === tile.id);
        return tile.rect[1] + tile.rect[3] / 2 - preview.rect[1] - preview.rect[3] / 2;
      });
      if (!staggerCapturePending && travel.some(value => Math.abs(value) < 1) &&
        travel.some(value => value > boardPitch * 0.25)) {
        staggerCapturePending = true;
        capture('wordJellyStaggerFrame');
      }
    };
    window.wordJellyArrivalObserver = new MutationObserver(record);
    window.wordJellyArrivalObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, before);
}

async function verifyArrival(page, info, before, label) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return before.upcoming.every(root => state.tiles.some(tile => tile.id === root.id && tile.settled));
  }, { timeout: Math.ceil(before.spawn_interval * 1000) + 12000,
    message: `${label} supply visibly descends and finishes its planted recovery` }).toBe(true);
  const after = await jelly(page);
  const timeline = await page.evaluate(() => window.wordJellyArrivalTimeline);
  await info.attach(`word-jelly-${label}-arrival-timeline.json`, {
    body: JSON.stringify({ before: before.preview, roots: before.upcoming, timeline }, null, 2), contentType: 'application/json'
  });
  for (const root of before.upcoming) {
    const source = before.preview.slots.find(slot => slot.id === root.id);
    const target = after.tiles.find(tile => tile.id === root.id);
    const frames = timeline.flatMap(frame => frame.tiles.filter(tile => tile.id === root.id));
    const sourceY = source.rect[1] + source.rect[3] / 2;
    const destinationY = target.rect[1] + target.rect[3] / 2;
    const descent = frames.filter(tile => !tile.settled && tile.rect[1] + tile.rect[3] / 2 < destinationY - 0.1);
    expect(descent.length, `${label}: ${root.text} is visible in several airborne frames`).toBeGreaterThanOrEqual(3);
    expect(descent[0].rect[1] + descent[0].rect[3] / 2,
      `${label}: ${root.text} begins at its source tray instead of appearing near its landing cell`)
      .toBeLessThan(sourceY + (destinationY - sourceY) * 0.12);
    let previousY = sourceY - 0.1;
    for (const tile of descent) {
      const centerY = tile.rect[1] + tile.rect[3] / 2;
      expect(centerY, `${label}: ${root.text} travels continuously downward`).toBeGreaterThanOrEqual(previousY - 0.1);
      expect(tile.text).toBe(root.text);
      expect(tile.fragments).toBe(root.fragments);
      expect(tile.palette_index, `${label}: the body retains its preview partner color`).toBe(source.palette_index);
      expect(tile.fragment_badges).toBe(root.fragments);
      previousY = centerY;
    }
    const moving = descent.filter(tile => tile.rect[1] + tile.rect[3] / 2 > sourceY + 0.5);
    const unique = moving.filter((tile, index) => index === 0 || tile.age > moving[index - 1].age + 0.001);
    if (unique.length >= 4) {
      const speed = (a, b) => ((b.rect[1] + b.rect[3] / 2) - (a.rect[1] + a.rect[3] / 2)) / (b.age - a.age);
      expect(speed(unique.at(-2), unique.at(-1)), `${label}: gravity accelerates the falling ${root.text}`)
        .toBeGreaterThan(speed(unique[0], unique[1]));
    }
    expect(target.text).toBe(root.text);
    expect(target.fragments).toBe(root.fragments);
    expectSupportedChild(after, target);
  }
  const arrivals = before.upcoming.map((root, slot) => ({
    ...after.tiles.find(tile => tile.id === root.id), slot, source: before.preview.slots[slot]
  }));
  const delay = root => root.arrival_delay;
  expect(new Set(arrivals.map(delay)).size, `${label}: all six roots have separate release beats`).toBe(6);
  expect(Math.max(...arrivals.map(delay)) - Math.min(...arrivals.map(delay)),
    `${label}: the packet spreads across a perceptible release sequence`).toBeGreaterThan(0.55);
  const crossLanePairs = arrivals.flatMap(early => arrivals
    .filter(late => early.slot > late.slot && delay(late) - delay(early) > 0.29)
    .map(late => ({ early, late })));
  expect(crossLanePairs.length, `${label}: release order crosses the row instead of sweeping left to right`).toBeGreaterThan(0);
  const pitch = after.board_rect[3] / after.rows;
  const travel = (frame, root) => {
    const tile = frame.tiles.find(tile => tile.id === root.id);
    return tile ? tile.rect[1] + tile.rect[3] / 2 - root.source.rect[1] - root.source.rect[3] / 2 : Number.NaN;
  };
  expect(timeline.some(frame => crossLanePairs.some(({ early, late }) =>
    travel(frame, early) > pitch * 0.15 && Math.abs(travel(frame, late)) < 1)),
  `${label}: a later column visibly falls while an earlier column still waits at the tray`).toBe(true);
  expect(timeline.some(frame => arrivals.some(early => travel(frame, early) > pitch * 0.25 &&
    frame.preview[early.slot].visible && frame.preview[early.slot].id !== early.id) &&
    arrivals.some(late => Math.abs(travel(frame, late)) < 1 && !frame.preview[late.slot].visible)),
  `${label}: cleared preview slots refill while other departing roots still wait`).toBe(true);
  expect(after.generated_tiles).toBe(before.generated_tiles + 6);
  expect(after.merged_count).toBe(before.merged_count);
  expect(after.cleared_pairs).toBe(before.cleared_pairs);
  expect(after.collected_coins).toBe(before.collected_coins);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyArrivalFrame)),
    { message: 'The actual browser captures the jellies between the tray and their support' }).toBe(true);
  const encoded = await page.evaluate(() => window.wordJellyArrivalFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-falling-midpoint.png`), Buffer.from(encoded, 'base64'));
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyStaggerFrame)),
    { message: 'The browser captures roots falling at visibly different heights' }).toBe(true);
  const stagger = await page.evaluate(() => window.wordJellyStaggerFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-staggered-release.png`), Buffer.from(stagger, 'base64'));
  await capture(page, info, `word-jelly-${label}-landed`);
  await page.evaluate(() => window.wordJellyArrivalObserver.disconnect());
}

test('manual and automatic preview packets naturally fall into the well', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await startWordJelly(page), manual = await jelly(page);
  expectSupplyLayout(manual, await metrics(page));
  for (let row = manual.rows - 3; row < manual.rows; row++) {
    const roots = manual.tiles.filter(tile => tile.row === row).sort((a, b) => a.column - b.column);
    expectMixedRootPacket(roots, `Starter row ${row}`);
    expectRootBreathingRoom(roots, manual.board_rect[2] / manual.columns, `Starter row ${row}`);
  }
  expectMixedRootPacket(manual.upcoming, 'Manual supply');
  expectRootBreathingRoom(manual.preview.slots, manual.board_rect[2] / manual.columns, 'Preview row');
  expect(manual.preview.slots.filter(slot => slot.visible)).toHaveLength(6);
  expect(manual.preview.rect[1] + manual.preview.rect[3], 'The supply tray is above the well on every layout')
    .toBeLessThanOrEqual(manual.board_rect[1]);
  expect(new Set(manual.preview.slots.map(slot => Math.round(slot.rect[1]))).size,
    'All six visible previews share one horizontal row').toBe(1);
  await capture(page, info, 'word-jelly-supply-before-release');
  await observeArrival(page, manual);
  await pressRect(page, manual.preview.rect);
  await verifyArrival(page, info, manual, 'manual-supply');
  const automatic = await jelly(page);
  expectMixedRootPacket(automatic.upcoming, 'Automatic supply');
  await observeArrival(page, automatic);
  await verifyArrival(page, info, automatic, 'automatic-supply');
  expect(errors).toEqual([]);
});

test('collecting a lower word makes the stack above it visibly fall onto support', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await startWordJelly(page), opening = await jelly(page), startingWallet = await wallet(page);
  const floor = opening.tiles.filter(tile => tile.row === opening.rows - 1 && tile.mass === 1)
    .sort((a, b) => a.column - b.column);
  const found = rootsForWord({ tiles: floor }, 3, 2);
  expect(found, 'The first ordinary supply packet contains a complete word among its dispersed floor roots').toBeTruthy();
  const { roots, word } = found;
  let completed = await merge(page, roots[0].id, roots[1].id);
  expect(completed.word.id).toBe(word.id);
  const supportedStack = state => {
    const support = state.tiles.find(tile => tile.id === completed.id);
    return state.tiles.filter(tile => tile.mass === 1 && tile.settled && !tile.placement_locked &&
      tile.row + tile.height === support.row && tile.column < support.column + support.width &&
      tile.column + tile.width > support.column);
  };
  let before = await jelly(page);
  // Merging now settles every unsupported body immediately. Use the ordinary
  // supply to form a real supported stack above the completed word if needed.
  for (let packet = 0; packet < 2 && !supportedStack(before).length; packet++) {
    await expect.poll(async () => (await jelly(page)).preview.enabled).toBe(true);
    await pressRect(page, before.preview.rect);
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    before = await jelly(page);
  }
  const stack = supportedStack(before);
  expect(stack.length, 'At least one ordinary upper root rests directly on the word being collected').toBeGreaterThan(0);
  for (const tile of stack) expectSupportedChild(before, tile);
  completed = before.tiles.find(tile => tile.id === completed.id);
  await page.evaluate(stack => {
    const status = document.getElementById('game-status');
    window.wordJellyGravityTimeline = [];
    window.wordJellyGravityFrame = null;
    let capturePending = false;
    const descentPositions = new Set();
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tracked = state.tiles?.filter(tile => stack.some(original => original.id === tile.id)) || [];
      window.wordJellyGravityTimeline.push(tracked.map(tile => ({ id: tile.id, row: tile.row,
        y: tile.rect[1], settled: tile.settled, falling: tile.falling, age: tile.age, time: performance.now() })));
      const first = tracked.find(tile => tile.id === stack[0].id);
      if (first?.falling && !first.settled && first.rect[1] > stack[0].rect[1] &&
        first.rect[1] < stack[0].rect[1] + (first.row - stack[0].row) * state.board_rect[3] / state.rows)
        descentPositions.add(first.rect[1]);
      // The 100 ms bridge may publish only one strictly intermediate pose in
      // this short fall; capture that pose instead of waiting past the landing.
      if (!capturePending && descentPositions.size > 0) {
        capturePending = true;
        // Encoding a full device-resolution PNG synchronously can stall the short fall on WebKit.
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { window.wordJellyGravityFrame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, stack);
  await capture(page, info, 'word-jelly-supported-stack-before-collection');
  await pressRect(page, completed.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.cleared_pairs === before.cleared_pairs + 1 && stack.every(original => {
      const tile = state.tiles.find(tile => tile.id === original.id);
      return tile?.settled && tile.row > original.row;
    });
  }, { message: 'Removing the lower word lets every supported upper jelly fall to its next support' }).toBe(true);
  const after = await jelly(page), bounds = await metrics(page);
  for (const original of stack) {
    const landed = after.tiles.find(tile => tile.id === original.id);
    expect(landed.column).toBe(original.column);
    expect(landed.row).toBeGreaterThanOrEqual(original.row + 1);
    expect({ text: landed.text, mass: landed.mass, fragments: landed.fragments })
      .toEqual({ text: original.text, mass: original.mass, fragments: original.fragments });
    expect(landed.fragment_badges).toBe(original.fragments);
    expect(landed.rect[1]).toBeGreaterThan(original.rect[1]);
    expectSupportedChild(after, landed);
    expectInside(landed.rect, bounds);
  }
  for (const grounded of before.tiles.filter(tile => tile.id !== completed.id && tile.row + tile.height === before.rows)) {
    const unchanged = after.tiles.find(tile => tile.id === grounded.id);
    expect([unchanged.column, unchanged.row], 'Gravity leaves an already grounded neighbor in place')
      .toEqual([grounded.column, grounded.row]);
  }
  const timeline = await page.evaluate(() => window.wordJellyGravityTimeline);
  await info.attach('word-jelly-gravity-timeline.json', { body: JSON.stringify(timeline, null, 2), contentType: 'application/json' });
  const original = stack[0], landed = after.tiles.find(tile => tile.id === original.id);
  const travel = timeline.flat().filter(tile => tile.id === original.id);
  const descent = travel.filter(tile => !tile.settled && tile.y > original.rect[1] && tile.y < landed.rect[1]);
  expect(descent.length, 'Collection gravity has an observed in-flight pose between its supported start and landing').toBeGreaterThan(0);
  expect(new Set(travel.map(tile => tile.y)).size, 'The browser observes distinct start, intermediate and landing positions').toBeGreaterThanOrEqual(3);
  let previousY = original.rect[1];
  for (const frame of travel) {
    expect(frame.y, 'The sampled fall moves downward without returning to its unsupported start').toBeGreaterThanOrEqual(previousY - 0.05);
    expect(frame.y).toBeLessThanOrEqual(landed.rect[1] + 0.05);
    previousY = frame.y;
  }
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyGravityFrame)),
    { message: 'The asynchronous intermediate-frame capture finishes without stalling the descent' }).toBe(true);
  const frame = await page.evaluate(() => window.wordJellyGravityFrame);
  fs.writeFileSync(info.outputPath('word-jelly-stack-falling-midpoint.png'), Buffer.from(frame, 'base64'));
  await capture(page, info, 'word-jelly-stack-landed-after-collection');
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + completed.mass * 50);
  expect(after.collected_coins).toBe(before.collected_coins + completed.mass * 50);
  expect(after.fragment_count).toBe(before.fragment_count + completed.fragments);
  expect(errors).toEqual([]);
});

test('lifting a lower jelly drops its stack while the pointer remains held', async ({ page }, info) => {
  const errors = await startWordJelly(page), bounds = await metrics(page);
  const before = await jelly(page), startingWallet = await wallet(page);
  const support = before.tiles.find(tile => tile.row === before.rows - 1 && tile.width === 1 &&
    before.tiles.some(upper => upper.column === tile.column && upper.row + upper.height === tile.row && upper.width === 1));
  expect(support, 'The opening board contains a removable lower support').toBeTruthy();
  const upper = before.tiles.find(tile => tile.column === support.column && tile.row + tile.height === support.row);
  const from = center(support.rect, bounds);
  const destination = center([before.board_rect[0] + before.board_rect[2] * 0.8,
    before.board_rect[1] + before.board_rect[3] * 0.15, 0, 0], bounds);
  await page.evaluate(id => {
    const status = document.getElementById('game-status');
    window.heldSupportFall = [];
    const observer = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tile = state.tiles?.find(item => item.id === id);
      if (tile) window.heldSupportFall.push({ time: performance.now(), tile, drag: state.drag });
    });
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  }, upper.id);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(support.id);
    expect((await jelly(page)).tiles.find(tile => tile.id === upper.id).row,
      'A press alone keeps the original support').toBe(upper.row);
    await page.mouse.move(destination.x, destination.y);
    await expect.poll(async () => {
      const state = await jelly(page), fallen = state.tiles.find(tile => tile.id === upper.id);
      return state.drag.active && state.drag.source === support.id && fallen?.settled && fallen.row > upper.row;
    }, { message: 'The upper jelly lands without waiting for pointer-up' }).toBe(true);
    const held = await jelly(page), landed = held.tiles.find(tile => tile.id === upper.id);
    expect(landed.rect[1]).toBeGreaterThan(upper.rect[1]);
    expectSupportedChild(held, landed);
    const timeline = await page.evaluate(() => window.heldSupportFall);
    expect(timeline.some(frame => frame.drag.source === support.id && frame.tile.falling && !frame.tile.settled &&
      frame.tile.rect[1] > upper.rect[1] && frame.tile.rect[1] < landed.rect[1]),
    'The browser renders an intermediate fall while the lower jelly is held').toBe(true);
    fs.writeFileSync(info.outputPath('word-jelly-held-support-fall.json'), JSON.stringify({ before, held, timeline }, null, 2));
    await capture(page, info, 'word-jelly-stack-landed-while-support-held');
    expect(held.collected_coins).toBe(before.collected_coins);
    expect(held.merged_count).toBe(before.merged_count);
    const outside = center([before.board_rect[0] - 20, before.board_rect[1] + before.board_rect[3] * 0.3, 0, 0], bounds);
    await page.mouse.move(outside.x, outside.y);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.drag.active && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  const after = await jelly(page);
  for (const tile of after.tiles) {
    expect(Boolean(tile.lifted), 'Cancellation returns every body to the board').toBe(false);
    expectSupportedChild(after, tile);
    for (const other of after.tiles.filter(item => item.id > tile.id)) {
      expect(tile.column < other.column + other.width && tile.column + tile.width > other.column &&
        tile.row < other.row + other.height && tile.row + tile.height > other.row,
      'Cancellation never overlaps the stack that occupied the old source position').toBe(false);
    }
  }
  for (const original of before.tiles) {
    const restored = after.tiles.find(tile => tile.id === original.id);
    expect(restored).toBeTruthy();
    for (const field of ['text', 'mass', 'fragments']) expect(restored[field]).toEqual(original[field]);
  }
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  expect(errors).toEqual([]);
});

test('released roots and merged words fall onto support and keep their contents through later moves and rejected merges', async ({ page }, info) => {
  test.setTimeout(240000);
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  const errors = await startWordJelly(page, { reducedMotion }), bounds = await metrics(page);
  const { roots, word } = await availableWord(page, 3, 2, { markedOnly: true });
  const opening = await jelly(page), startingWallet = await wallet(page);
  const read = () => page.evaluate(() => JSON.parse(document.getElementById('game-status').dataset.jelly));
  const content = tile => ({ id: tile.id, text: tile.text, mass: tile.mass, parts: tile.parts_count,
    word: tile.word, coins: tile.coins, fragments: tile.fragments,
    picture: tile.picture_visible, badges: tile.fragment_badges });
  const footprint = tile => [tile.column, tile.row, tile.width, tile.height];
  const vacant = (state, tile, { sameColumn = false, outside = null } = {}) => {
    const columns = Array.from({ length: state.columns - tile.width + 1 }, (_, column) => column)
      .filter(column => !outside || column + tile.width <= outside.column || column >= outside.column + outside.width)
      .sort((a, b) => Number(a === tile.column) * (sameColumn ? -1 : 1) - Number(b === tile.column) * (sameColumn ? -1 : 1));
    for (let row = 1; row < state.rows - tile.height; row++) for (const column of columns) {
      if (column === tile.column && row === tile.row) continue;
      // Leave air below the release footprint so a grounded outcome cannot be
      // confused with a body pinned to the pointer's last position.
      if (!state.tiles.some(other => other.id !== tile.id && other.column < column + tile.width &&
        other.column + other.width > column && other.row < row + tile.height + 1 && other.row + other.height > row))
        return { column, row };
    }
    throw new Error('The ordinary board needs an empty footprint with free space below for this placement check.');
  };
  const dropPoint = (state, tile, placement) => ({
    x: state.board_rect[0] + (placement.column + tile.width / 2) * state.board_rect[2] / state.columns,
    y: state.board_rect[1] + (placement.row + tile.height / 2) * state.board_rect[3] / state.rows
  });
  const observeFall = async (id, label, origin) => page.evaluate(({ id, label, origin }) => {
    const status = document.getElementById('game-status');
    window.wordJellyPlacementFalls ||= {};
    const evidence = window.wordJellyPlacementFalls[label] = { origin, timeline: [], frame: null };
    let capturing = false;
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tile = state.tiles?.find(item => item.id === id);
      if (!tile || state.drag.source === id) return;
      evidence.timeline.push({ time: performance.now(), tile });
      const pitch = state.board_rect[3] / state.rows;
      const gap = tile.height * pitch - tile.rect[3];
      const landingY = state.board_rect[1] + tile.row * pitch + gap / 2;
      const progress = (tile.rect[1] - origin.rect[1]) / (landingY - origin.rect[1]);
      if (!capturing && tile.falling && !tile.settled && progress > 0.12 && progress < 0.85) {
        capturing = true;
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { evidence.frame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    };
    const observer = new MutationObserver(record);
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, { id, label, origin });
  const verifyFall = async (label, original, landed, { release = false } = {}) => {
    const evidence = await page.evaluate(label => window.wordJellyPlacementFalls[label], label);
    const frames = evidence.timeline.map(frame => frame.tile);
    fs.writeFileSync(info.outputPath(`${label}-timeline.json`), JSON.stringify({ reducedMotion, bounds,
      original, landed, origin: evidence.origin, timeline: evidence.timeline }, null, 2));
    expect(content(landed), 'Falling keeps the word, picture, reward and carried fragments').toEqual(content(original));
    for (const tile of frames) expect(content(tile)).toEqual(content(original));
    if (reducedMotion !== 'reduce') {
      const falling = frames.filter(tile => tile.falling && !tile.settled);
      expect(falling.length, 'The real browser publishes an airborne pose before landing').toBeGreaterThan(0);
      const travel = landed.rect[1] - evidence.origin.rect[1];
      if (release) expect(Math.abs(falling[0].rect[1] - evidence.origin.rect[1]),
        'The released jelly starts near the hand instead of snapping to its old resting position')
        .toBeLessThan(travel * 0.18 + 1);
      if (release) expect(falling[0].rect[1], 'Final pointer-up rounding stays within one display pixel of the held pose')
        .toBeGreaterThanOrEqual(evidence.origin.rect[1] - 1 / bounds.scale);
      expect(falling.some(tile => tile.rect[1] > evidence.origin.rect[1] + 0.1 && tile.rect[1] < landed.rect[1] - 0.1),
        'At least one visible position lies between the release and supported landing').toBe(true);
      // The final pointer-up event can round differently from the last mousemove.
      // Check monotonic descent between published post-release frames.
      let previousY = frames[0].rect[1];
      for (const tile of frames) {
        expect(tile.rect[1], 'The falling body never rewinds upward').toBeGreaterThanOrEqual(previousY - 0.1);
        expect(tile.rect[1]).toBeLessThanOrEqual(landed.rect[1] + 0.1);
        previousY = tile.rect[1];
      }
      await expect.poll(() => page.evaluate(label => Boolean(window.wordJellyPlacementFalls[label].frame), label),
        { message: 'The browser retains an actual intermediate falling frame' }).toBe(true);
      const frame = await page.evaluate(label => window.wordJellyPlacementFalls[label].frame, label);
      fs.writeFileSync(info.outputPath(`${label}-midfall.png`), Buffer.from(frame, 'base64'));
    }
  };
  const drag = async (id, point, ready, screenshot, beforeRelease) => {
    const state = await read(), tile = state.tiles.find(item => item.id === id);
    expect(tile?.settled, 'The player grabs a settled body').toBe(true);
    const from = center(tile.rect, bounds), to = center([point.x, point.y, 0, 0], bounds);
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    try {
      await expect.poll(async () => (await read()).drag.source).toBe(id);
      await page.mouse.move(to.x, to.y, { steps: 3 });
      await expect.poll(async () => ready(await read()), { message: 'The ordinary drag presents the expected drop affordance' }).toBe(true);
      if (screenshot) await capture(page, info, screenshot);
      if (beforeRelease) await beforeRelease(await read());
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await read()).drag.active).toBe(false);
  };
  let relocation = 0;
  const dropAndLand = async (id, screenshot, options = {}) => {
    const state = await read(), tile = state.tiles.find(item => item.id === id), placement = vacant(state, tile, options);
    const point = dropPoint(state, tile, placement);
    if (screenshot) {
      point.x += state.board_rect[2] / state.columns * 0.2;
      point.y -= state.board_rect[3] / state.rows * 0.15;
    }
    await drag(id, point, current => current.placement.visible && current.placement.valid &&
      current.placement.tile_id === id && current.placement.column === placement.column && current.placement.row === placement.row,
    screenshot, current => observeFall(id, `word-jelly-release-${++relocation}`, current.tiles.find(item => item.id === id)));
    await expect.poll(async () => {
      const moved = (await read()).tiles.find(item => item.id === id);
      return moved?.settled && moved.column === placement.column && moved.row > placement.row;
    }).toBe(true);
    const current = await read(), moved = current.tiles.find(item => item.id === id);
    expect([moved.column, moved.width, moved.height], 'The release keeps the chosen column and body footprint')
      .toEqual([placement.column, tile.width, tile.height]);
    expectSupportedChild(current, moved);
    await verifyFall(`word-jelly-release-${relocation}`, tile, moved, { release: true });
    return moved;
  };
  const join = async (sourceId, targetId) => {
    const state = await read(), source = state.tiles.find(tile => tile.id === sourceId), target = state.tiles.find(tile => tile.id === targetId);
    const point = { x: target.rect[0] + target.rect[2] / 2, y: target.rect[1] + target.rect[3] / 2 };
    await drag(sourceId, point, current => current.drag.target === targetId && !current.placement.visible);
    await expect.poll(async () => {
      const current = await read();
      return current.merged_count === state.merged_count + 1 && current.tiles.some(tile =>
        !state.tiles.some(old => old.id === tile.id) && tile.text === source.text + target.text && tile.settled);
    }).toBe(true);
    const current = await read(), merged = current.tiles.find(tile =>
      !state.tiles.some(old => old.id === tile.id) && tile.text === source.text + target.text);
    expect(merged.mass).toBe(source.mass + target.mass);
    expect(merged.fragments).toBe(source.fragments + target.fragments);
    expect(merged.placement_locked, 'A new automatic merge resumes ordinary gravity').toBe(false);
    expectSupportedChild(current, merged);
    return merged;
  };

  await dropAndLand(roots[0].id);
  const merged = await join(roots[0].id, roots[1].id);
  expect(merged.word.id).toBe(word.id);
  expect(merged.width).toBeGreaterThan(1);
  expect(merged.picture_visible).toBe(true);
  let placed = await dropAndLand(merged.id, 'word-jelly-word-held-over-empty-space', { sameColumn: true });
  const firstLanding = placed;
  placed = await dropAndLand(placed.id, null, { sameColumn: true });
  expect(placed.column, 'Lifting a supported word straight upward keeps its lane').toBe(firstLanding.column);
  await capture(page, info, 'word-jelly-released-word-on-support');

  const beforeSupportMove = placed;
  await observeFall(placed.id, 'word-jelly-released-word-loses-support', beforeSupportMove);
  for (let attempt = 0; attempt < 3 && placed.row === beforeSupportMove.row; attempt++) {
    const state = await read();
    const support = state.tiles.find(tile => tile.id !== placed.id && tile.settled &&
      tile.row === placed.row + placed.height && tile.column < placed.column + placed.width && tile.column + tile.width > placed.column);
    expect(support, 'The released word has a real removable support body').toBeTruthy();
    await dropAndLand(support.id, null, { outside: placed });
    await expect.poll(async () => (await read()).tiles.find(tile => tile.id === placed.id)?.settled).toBe(true);
    placed = (await read()).tiles.find(tile => tile.id === placed.id);
  }
  expect(placed.row, 'Moving away the supports lets an already relocated word fall again').toBeGreaterThan(beforeSupportMove.row);
  expect(placed.column).toBe(beforeSupportMove.column);
  expectSupportedChild(await read(), placed);
  await verifyFall('word-jelly-released-word-loses-support', beforeSupportMove, placed);
  await capture(page, info, 'word-jelly-released-word-after-support-moves');

  const beforeInvalid = await read();
  const returnedToPlacement = async () => {
    const tile = (await read()).tiles.find(item => item.id === placed.id);
    return JSON.stringify(footprint(tile)) === JSON.stringify(footprint(placed)) &&
      tile.rect.every((value, axis) => Math.abs(value - placed.rect[axis]) < 0.05);
  };
  const overflow = { x: beforeInvalid.board_rect[0] + beforeInvalid.board_rect[2] * (1 - 0.3 / beforeInvalid.columns),
    y: beforeInvalid.board_rect[1] + beforeInvalid.board_rect[3] * 0.5 / beforeInvalid.rows };
  await drag(placed.id, overflow, current => current.drag.target === -1 && current.placement.visible && !current.placement.valid);
  await expect.poll(returnedToPlacement, { message: 'A footprint crossing the edge visibly returns to its supported position' }).toBe(true);
  const outside = { x: beforeInvalid.board_rect[0] - 12 / bounds.scale, y: overflow.y };
  await drag(placed.id, outside, current => current.drag.target === -1 && !current.placement.valid);
  await expect.poll(returnedToPlacement, { message: 'A pointer released outside the well visibly returns to its supported position' }).toBe(true);
  const returned = await read();
  expect(content(returned.tiles.find(tile => tile.id === placed.id))).toEqual(content(placed));
  expect(returned.merged_count, 'A rejected empty or outside drop never starts a merge').toBe(beforeInvalid.merged_count);
  expect(returned.collected_coins).toBe(opening.collected_coins);
  expect(returned.fragment_count).toBe(opening.fragment_count);

  const words = new Set(vocabulary.filter(item => item.min_age === 3).map(item => normalize(item.text)));
  const extra = returned.tiles.find(tile => tile.id !== placed.id && tile.mass === 1 && tile.settled &&
    !words.has(normalize(tile.text + placed.text)));
  expect(extra, 'An ordinary unfinished root can join the moved word').toBeTruthy();
  const rejected = await rejectMerge(page, extra.id, placed.id, {
    info, label: 'word-jelly-moved-word-rejects-invalid-append', reducedMotion
  });
  for (const original of [extra, placed]) {
    const retained = rejected.after.tiles.find(tile => tile.id === original.id);
    expect(content(retained), 'A rejected append preserves the relocated word and root').toEqual(content(original));
    expectSupportedChild(rejected.after, retained);
  }
  expect((await wallet(page)).balance, 'Dragging and a rejected merge do not collect word coins').toBe(startingWallet.balance);
  await pressRect(page, rejected.after.tiles.find(tile => tile.id === placed.id).rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + placed.coins);
  const final = await read();
  expect(final.cleared_pairs).toBe(opening.cleared_pairs + 1);
  expect(final.fragment_count).toBe(opening.fragment_count + placed.fragments);
  expect(errors).toEqual([]);
});

test('word pair colors distinguish exact completion targets and preserve source order', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page);
  const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => normalize(word.text)));
  const roots = opening.tiles.filter(tile => tile.mass === 1 && tile.settled && tile.visible);
  const pair = roots.flatMap(source => roots.map(target => ({ source, target }))).find(({ source, target }) =>
    source.id !== target.id && source.palette_index === target.palette_index &&
    words.has(normalize(source.text + target.text)) && !words.has(normalize(target.text + source.text)));
  expect(pair, 'The real board provides a shared-color word pair with an unambiguous spelling order').toBeTruthy();
  for (const tile of roots) {
    expect(tile.palette_index).toBeGreaterThanOrEqual(0);
    expect(tile.palette_hue).toBeGreaterThanOrEqual(0);
    for (const other of roots.filter(other => other.id > tile.id && other.palette_index === tile.palette_index))
      expect(words.has(normalize(tile.text + other.text)) || words.has(normalize(other.text + tile.text)),
        'An unrelated pair cannot share a resting hint color').toBe(true);
  }
  for (const slot of opening.preview.slots.filter(slot => slot.visible)) {
    expect(slot.palette_index, 'Upcoming roots render an assigned word-pair color').toBeGreaterThanOrEqual(0);
    expect(slot.palette_hue).toBeGreaterThanOrEqual(0);
  }
  await capture(page, info, 'word-jelly-distinct-word-pair-colors');
  const bounds = await metrics(page), point = center(pair.source.rect, bounds);
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.source.id);
    const selected = await jelly(page), source = selected.tiles.find(tile => tile.id === pair.source.id);
    const validTargets = selected.tiles.filter(tile => tile.id !== source.id && words.has(normalize(source.text + tile.text)));
    expect(validTargets.length).toBeGreaterThan(0);
    for (const target of validTargets) {
      expect(target.palette_index).toBe(source.palette_index);
      expect(target.palette_hue).toBeCloseTo(source.palette_hue, 5);
    }
    for (const target of selected.tiles.filter(tile => tile.id !== source.id && !words.has(normalize(source.text + tile.text))))
      expect(target.palette_index, 'Every invalid ordered target differs from the held source').not.toBe(source.palette_index);
    await capture(page, info, 'word-jelly-compatible-target-colors');
  } finally {
    await page.mouse.up();
  }
  const reverse = center(pair.target.rect, bounds);
  await page.mouse.move(reverse.x, reverse.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.target.id);
    const selected = await jelly(page);
    expect(selected.tiles.find(tile => tile.id === pair.source.id).palette_index,
      'Selecting the suffix does not falsely advertise the reversed word as a completion')
      .not.toBe(selected.tiles.find(tile => tile.id === pair.target.id).palette_index);
  } finally {
    await page.mouse.up();
  }
  const completed = await merge(page, pair.source.id, pair.target.id);
  expect(words.has(normalize(completed.text))).toBe(true);
  expect(completed.picture_visible).toBe(true);
  expect(completed.palette_index).toBeGreaterThanOrEqual(0);
  await capture(page, info, 'word-jelly-color-guided-completed-word');
  expect(errors).toEqual([]);
});

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`drag completion hints follow exact source order and clear with the gesture (${reducedMotion})`, async ({ page }, info) => {
    test.setTimeout(240000);
    await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5 });
    const errors = await startWordJelly(page, { reducedMotion });
    const pair = await availableWord(page, 3, 2, { invalidReverse: true });
    const opening = await jelly(page), bounds = await metrics(page);
    const audioAvailable = await page.evaluate(() => window.audioObservation.available);
    const playbackIndex = () => page.evaluate(() => window.audioObservation.playbacks.length);
    const contactSounds = (from, recording) => page.evaluate(({ from, fingerprint }) =>
      window.audioObservation.playbacks.slice(from).filter(sound => sound.fingerprint === fingerprint),
    { from, fingerprint: recording.fingerprint });
    const evidence = { reducedMotion, prefix: pair.roots[0].text, suffix: pair.roots[1].text,
      audioAvailable, opening };
    const evidencePath = info.outputPath('word-jelly-completion-samples.json');
    const retainEvidence = () => fs.writeFileSync(evidencePath, JSON.stringify(evidence, null, 2));
    const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => normalize(word.text)));
    const hintedIds = state => state.tiles.filter(tile => tile.completion_hint).map(tile => tile.id).sort((a, b) => a - b);
    const expectedIds = (state, source) => state.tiles.filter(tile => tile.id !== source.id && tile.settled &&
      words.has(normalize(source.text + tile.text))).map(tile => tile.id).sort((a, b) => a - b);
    const expectQuiet = state => {
      expect(hintedIds(state), 'Idle, canceled and paused jellies do not advertise a held prefix').toEqual([]);
      expect(state.contact.kind, 'Contact pressure clears when the gesture ends or pauses').toBe('none');
      for (const tile of state.tiles) expect(tile.completion_scale).toBe(1);
    };
    const safePoint = center([opening.board_rect[0] + opening.board_rect[2] * 0.25,
      opening.board_rect[1] + opening.board_rect[3] * 0.18, 0, 0], bounds);
    const beginDrag = async source => {
      await expect.poll(async () => (await jelly(page)).tiles.find(tile => tile.id === source.id)?.settled,
        { message: 'The next held root is settled after the previous cancellation' }).toBe(true);
      const point = center((await jelly(page)).tiles.find(tile => tile.id === source.id).rect, await metrics(page));
      await page.mouse.move(point.x, point.y);
      await page.mouse.down();
      await expect.poll(async () => (await jelly(page)).drag.source).toBe(source.id);
      await expect.poll(async () => {
        const held = await jelly(page);
        return JSON.stringify(hintedIds(held)) === JSON.stringify(expectedIds(held, source));
      }, { message: 'A held prefix publishes its forward completions before dragging' }).toBe(true);
      await capture(page, info, `word-jelly-completion-held-${source.id}`);
      await page.mouse.move(safePoint.x, safePoint.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).drag.active).toBe(true);
      await expect.poll(async () => {
        const state = await jelly(page);
        return JSON.stringify(hintedIds(state)) === JSON.stringify(expectedIds(state, source));
      }).toBe(true);
    };
    expectQuiet(opening);
    await capture(page, info, 'word-jelly-completion-idle');
    await beginDrag(pair.roots[0]);
    try {
      const samples = [];
      for (let frame = 0; frame < 8; frame++) {
        const state = await jelly(page);
        expect(hintedIds(state), 'Only exact current-age source-plus-target words receive a completion effect')
          .toEqual(expectedIds(state, pair.roots[0]));
        for (const tile of state.tiles.filter(tile => tile.id !== pair.roots[0].id)) {
          const original = opening.tiles.find(item => item.id === tile.id);
          if (original) expect(tile.rect, 'Breathing changes the jelly skin without moving its hit box or text layout').toEqual(original.rect);
          expect(tile.completion_scale).toBeGreaterThanOrEqual(1);
          expect(tile.completion_scale).toBeLessThanOrEqual(1.065);
          if (reducedMotion === 'reduce' || !tile.completion_hint) expect(tile.completion_scale).toBe(1);
        }
        samples.push(state.tiles.find(tile => tile.id === pair.roots[1].id).completion_scale);
        await page.waitForTimeout(120);
      }
      if (reducedMotion === 'no-preference') {
        expect(Math.max(...samples), 'A compatible target softly grows during an actual drag').toBeGreaterThan(1.01);
        expect(Math.max(...samples) - Math.min(...samples), 'The target breathes gently rather than snapping to one size')
          .toBeGreaterThan(0.003);
      }
      await capture(page, info, 'word-jelly-completion-active');
      evidence.active = await jelly(page);
      evidence.scales = samples;
      const forwardTarget = center((await jelly(page)).tiles.find(tile => tile.id === pair.roots[1].id).rect, bounds);
      forwardTarget.y -= pair.roots[1].rect[3] * bounds.scale * 0.34;
      await page.mouse.move(forwardTarget.x, forwardTarget.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).contact).toMatchObject({
        kind: 'match', source: pair.roots[0].id, target: pair.roots[1].id
      });
      evidence.forwardContact = await jelly(page);
      expect(evidence.forwardContact.contact.strength).toBeGreaterThan(0);
      expect(evidence.forwardContact.tiles.find(tile => tile.id === pair.roots[1].id).completion_hint).toBe(true);
      await capture(page, info, 'word-jelly-completion-forward-contact');
      await page.keyboard.press('Escape');
      await expect.poll(async () => (await jelly(page)).drag.active).toBe(false);
      expectQuiet(await jelly(page));
    } finally {
      await page.mouse.up();
    }
    await beginDrag(pair.roots[1]);
    try {
      const reversed = await jelly(page);
      expect(reversed.tiles.find(tile => tile.id === pair.roots[0].id).completion_hint,
        'Dragging a suffix never highlights the original prefix when their reversed spelling is invalid').toBe(false);
      const reverseTarget = center(reversed.tiles.find(tile => tile.id === pair.roots[0].id).rect, bounds);
      reverseTarget.y -= pair.roots[0].rect[3] * bounds.scale * 0.34;
      const beforeContact = await playbackIndex();
      await page.mouse.move(reverseTarget.x, reverseTarget.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).drag.target).toBe(pair.roots[0].id);
      const touching = await jelly(page);
      expect(touching.contact.kind, 'Every settled body gives neutral pressure without advertising a reversed word as a match').toBe('touch');
      expect(touching.contact.strength).toBeGreaterThan(0);
      expect(touching.contact).toMatchObject({ source: pair.roots[1].id, target: pair.roots[0].id });
      expect(touching.tiles.find(tile => tile.id === pair.roots[0].id).completion_hint).toBe(false);
      evidence.reverseContact = touching;
      await capture(page, info, 'word-jelly-completion-reverse-contact');
      if (audioAvailable) {
        evidence.contactAudio = await expectRecording(page, beforeContact, 'assets/imported-audio/jelly-interaction/contact.wav');
        expect(evidence.contactAudio.fingerprint).toBeTruthy();
        expect(evidence.contactAudio.peak).toBeGreaterThan(0.01);
        const heldSounds = await contactSounds(beforeContact, evidence.contactAudio);
        await page.waitForTimeout(250);
        expect(await contactSounds(beforeContact, evidence.contactAudio),
          'Holding a noncompleting contact does not repeat the bundled contact sound').toHaveLength(heldSounds.length);
        await page.mouse.move(safePoint.x, safePoint.y);
        await expect.poll(async () => (await jelly(page)).contact.kind).toBe('none');
        const beforeReturn = await playbackIndex();
        await page.mouse.move(reverseTarget.x, reverseTarget.y);
        await expect.poll(async () => (await jelly(page)).contact.kind).toBe('touch');
        await expectRecording(page, beforeReturn, 'assets/imported-audio/jelly-interaction/contact.wav');
        evidence.recontactAudio = await contactSounds(beforeReturn, evidence.contactAudio);
        expect(evidence.recontactAudio, 'Separating and touching the same jelly again produces one new cue').toHaveLength(1);
      }
      retainEvidence();
      const outside = center([opening.board_rect[0] - 20 / bounds.scale,
        opening.board_rect[1] + opening.board_rect[3] * 0.18, 0, 0], bounds);
      await page.mouse.move(outside.x, outside.y, { steps: 5 });
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await jelly(page)).drag.active).toBe(false);
    expectQuiet(await jelly(page));
    await beginDrag(pair.roots[0]);
    try {
      await openModeMenu(page);
      await expect.poll(async () => (await jelly(page)).paused).toBe(true);
      expectQuiet(await jelly(page));
    } finally {
      await page.mouse.up();
    }
    await chooseMode(page, 'word_jelly');
    await expect.poll(async () => (await jelly(page)).paused).toBe(false);
    expectQuiet(await jelly(page));
    await capture(page, info, 'word-jelly-completion-cleared');
    evidence.cleared = await jelly(page);
    expect(evidence.cleared.merged_count, 'Contact previews and cancellation do not commit a merge').toBe(opening.merged_count);
    expect(evidence.cleared.cleared_pairs).toBe(opening.cleared_pairs);
    expect(evidence.cleared.fragment_count).toBe(opening.fragment_count);
    retainEvidence();
    await info.attach('word-jelly-completion-samples.json', { path: evidencePath, contentType: 'application/json' });
    expect(errors).toEqual([]);
  });
}

test('six columns build a pictured word and a deliberate tap credits its coins once', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  expect(opening.tiles).toHaveLength(18);
  expect(opening.columns).toBe(6);
  const startingRows = [opening.rows - 3, opening.rows - 2, opening.rows - 1];
  expect([...new Set(opening.tiles.map(tile => tile.row))].sort((a, b) => a - b),
    'The opening occupies exactly the three bottom rows').toEqual(startingRows);
  for (const row of startingRows) {
    expect(opening.tiles.filter(tile => tile.row === row).map(tile => tile.column).sort((a, b) => a - b),
      'Every opening row fills all six columns').toEqual([0, 1, 2, 3, 4, 5]);
  }
  expect([...new Set(opening.tiles.map(tile => tile.column))].sort((a, b) => a - b)).toEqual([0, 1, 2, 3, 4, 5]);
  expect(new Set(opening.tiles.map(tile => Math.round(tile.rect[0]))).size,
    'All six columns occupy distinct rendered horizontal positions').toBe(6);
  expect(opening.upcoming).toHaveLength(6);
  for (const tile of opening.tiles) {
    expect(tile.mass).toBe(1);
    expect(tile.picture_visible, 'A standalone root does not pretend to be a completed word').toBe(false);
    expectInside(tile.rect, bounds);
  }
  await capture(page, info, 'word-jelly-six-column-opening');
  const originalViewport = page.viewportSize();
  for (const viewport of [{ width: 1473, height: 1175 }, { width: 768, height: 1024 },
    { width: 390, height: 844 }, { width: 393, height: 852 }, { width: 568, height: 320 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
      .toPass({ timeout: 5000 });
    if (viewport.width === 393) await capture(page, info, 'word-jelly-header-finish-393x852');
  }
  await page.setViewportSize(originalViewport);
  await rendered(page);
  await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
    .toPass({ timeout: 5000 });
  const { roots, word } = await availableWord(page, 3, 2), startingWallet = await wallet(page);
  await pressRect(page, roots[0].rect);
  await page.waitForTimeout(500);
  expect((await jelly(page)).tiles.some(tile => tile.id === roots[0].id), 'Tapping an unfinished root leaves it on the board').toBe(true);
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  const merged = await merge(page, roots[0].id, roots[1].id);
  expect(merged.word.id).toBe(word.id);
  expect(merged.word.min_age).toBe(3);
  expect(merged.picture_visible, 'The actual word art appears on the completed jelly').toBe(true);
  expect(merged.rect[2] * merged.rect[3]).toBeGreaterThan(roots[0].rect[2] * roots[0].rect[3] * 1.5);
  expect((await wallet(page)).balance, 'A word can remain on the board without spending its reward').toBe(startingWallet.balance);
  await capture(page, info, 'word-jelly-valid-pictured-word');
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  await page.waitForTimeout(500);
  const stillPaused = await jelly(page);
  expect(stillPaused.spawn_elapsed, 'The word supply clock pauses behind the menu').toBe(paused.spawn_elapsed);
  expect(stillPaused.tiles.map(tile => tile.id)).toEqual(paused.tiles.map(tile => tile.id));
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await expect.poll(async () => (await jelly(page)).visible).toBe(true);
  const before = await jelly(page);
  const resumed = before.tiles.find(tile => tile.id === merged.id);
  expect(resumed.picture_visible, 'The complete word survives opening and closing the menu').toBe(true);
  await pressRect(page, resumed.rect);
  await pressRect(page, resumed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 100);
  const collected = await jelly(page);
  expect(collected.tiles.some(tile => tile.id === merged.id)).toBe(false);
  expect(collected.collected_coins).toBe(before.collected_coins + 100);
  expect(collected.fragment_count).toBe(before.fragment_count + merged.fragments);
  await openModeMenu(page);
  const match = (await metrics(page)).library.controls.find(item => item.name === 'Mode_match');
  await pressRect(page, match.rect);
  await expect.poll(async () => (await metrics(page)).library.current).toBe('match');
  expect((await wallet(page)).balance, 'Leaving the mode never pays the collected word again').toBe(startingWallet.balance + 100);
  await page.reload();
  await enterGame(page);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 100);
  expect(errors).toEqual([]);
});

test('collect button grows with completed words and collects a rhythmic batch once', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = await startWordJelly(page), initial = await jelly(page), bounds = await metrics(page);
  expect(initial.collect_button.visible).toBe(true);
  expect(initial.collect_button.enabled).toBe(false);
  expect(initial.collect_button.count).toBe(0);
  expectSupplyLayout(initial, bounds);
  await capture(page, info, 'word-jelly-collect-count-0');
  const collectedIds = [];
  const stages = [initial.collect_button];
  for (let count = 1; count <= 3; count++) {
    const { roots } = await availableWord(page, 3, 2, { markedOnly: count === 1 });
    const merged = await merge(page, roots[0].id, roots[1].id);
    collectedIds.push(merged.id);
    await expect.poll(async () => (await jelly(page)).collect_button.count).toBe(count);
    await expect.poll(async () => (await jelly(page)).collect_button.charge).toBeGreaterThan(count - 0.1);
    const state = await jelly(page);
    expect(state.collect_button.enabled).toBe(true);
    expect(state.collect_button.rect, 'Accumulation grows artwork without moving its hit target').toEqual(initial.collect_button.rect);
    if (count === 1 || count === 3) {
      stages.push(state.collect_button);
      await capture(page, info, `word-jelly-collect-count-${count}`);
    }
  }
  expect(stages[1].visual_scale, 'One ready word charges the quiet empty control').toBeGreaterThan(stages[0].visual_scale);
  expect(stages[2].visual_scale, 'Three words visibly grow the charged control').toBeGreaterThan(stages[1].visual_scale);
  expect(stages[2].sparkle_count).toBeGreaterThanOrEqual(stages[1].sparkle_count);
  const before = await jelly(page), startingWallet = await wallet(page);
  const selected = before.tiles.filter(tile => collectedIds.includes(tile.id));
  const retained = before.tiles.filter(tile => !collectedIds.includes(tile.id)).map(tile => tile.id);
  const expectedCoins = selected.reduce((sum, tile) => sum + tile.coins, 0);
  const expectedFragments = selected.reduce((sum, tile) => sum + tile.fragments, 0);
  expect(expectedFragments, 'The ordinary-input batch includes a real carried treasure fragment').toBeGreaterThan(0);
  await page.exposeFunction('saveWordJellyBatchFrame', (index, encoded) =>
    fs.writeFileSync(info.outputPath(`word-jelly-batch-${index}.png`), Buffer.from(encoded, 'base64')));
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyBatchTimeline = [];
    window.wordJellyBatchCaptured = [];
    const pending = new Set();
    window.wordJellyBatchObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}'), batch = state.collection_batch;
      if (!batch?.total) return;
      window.wordJellyBatchTimeline.push({ ...batch, button: state.collect_button,
        effects: state.fusion_effects, revealed: state.word_reveal, cleared: state.cleared_pairs,
        collectedCoins: state.collected_coins, fragments: state.fragment_count, at: performance.now() });
      const reveal = state.word_reveal;
      // A 100 ms status publication can skip a whole 100 ms pickup. Capture
      // playback and the overlapping reading burst, without requiring every transient.
      const index = batch.active && batch.started && state.fusion_effects?.length ? 'active' :
        !batch.active && batch.completed === batch.total && reveal?.entries?.length === batch.total &&
        reveal.entries.every(entry => entry.content_alpha > 0.9) ? 'reveal' : '';
      if (!index || pending.has(index)) return;
      pending.add(index);
      // Let the status update reach the rendered canvas before capturing it.
      requestAnimationFrame(() => requestAnimationFrame(() => {
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = async () => {
            await window.saveWordJellyBatchFrame(index, reader.result.split(',')[1]);
            window.wordJellyBatchCaptured.push(index);
          };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }));
    });
    window.wordJellyBatchObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  // Consecutive trusted presses exercise the disabled state during playback.
  const point = center(before.collect_button.rect, bounds);
  await page.touchscreen.tap(point.x, point.y);
  await page.touchscreen.tap(point.x, point.y);
  await expect.poll(async () => (await jelly(page)).collection_batch.completed,
    { message: 'Every captured completed word is collected through the rhythmic queue' }).toBe(3);
  await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + expectedCoins);
  let timeline;
  try {
    await expect.poll(() => page.evaluate(() => window.wordJellyBatchCaptured.slice().sort()),
      { message: 'The real batch animation and overlapping readable words both produce rendered evidence' }).toEqual(['active', 'reveal']);
  } finally {
    timeline = await page.evaluate(() => {
      window.wordJellyBatchObserver.disconnect();
      return window.wordJellyBatchTimeline;
    });
    fs.writeFileSync(info.outputPath('word-jelly-batch-timeline.json'), JSON.stringify({ stages, timeline }, null, 2));
  }
  const final = await jelly(page);
  expect(timeline.some(frame => frame.active), 'The observer sees the disabled control during batch playback').toBe(true);
  expect(timeline.some(frame => !frame.active && frame.completed === 3), 'The browser observes the completed queue').toBe(true);
  const selectedById = new Map(selected.map(tile => [tile.id, tile]));
  let previousStarted = 0, previousCompleted = 0;
  const entryStates = new Map();
  for (const frame of timeline) {
    expect(frame.total).toBe(3);
    expect(frame.ids.slice().sort((a, b) => a - b)).toEqual(collectedIds.slice().sort((a, b) => a - b));
    expect(frame.skipped, 'Every captured word remains eligible throughout playback').toBe(0);
    expect(frame.started).toBeGreaterThanOrEqual(previousStarted);
    expect(frame.started).toBeLessThanOrEqual(3);
    expect(frame.completed).toBeGreaterThanOrEqual(previousCompleted);
    expect(frame.completed).toBeLessThanOrEqual(frame.started);
    expect(frame.started - frame.completed, 'The active disappearance never overlaps a second payout').toBeLessThanOrEqual(1);
    expect(frame.effects.length, 'Only one collection effect is active at each observed point').toBeLessThanOrEqual(1);
    const paid = frame.ids.slice(0, frame.completed).map(id => selectedById.get(id));
    expect(frame.cleared, 'Only the completed prefix has cleared from the board').toBe(before.cleared_pairs + paid.length);
    expect(frame.collectedCoins, 'Observed coin credit matches the completed prefix exactly')
      .toBe(before.collected_coins + paid.reduce((sum, tile) => sum + tile.coins, 0));
    expect(frame.fragments, 'Observed treasure credit matches the same completed prefix')
      .toBe(before.fragment_count + paid.reduce((sum, tile) => sum + tile.fragments, 0));
    for (const entry of frame.revealed.entries) {
      expect(entry.entry_id, 'Each word owns a stable independent reveal identity').toBeTruthy();
      const earlier = entryStates.get(entry.entry_id);
      if (earlier) {
        expect(entry.word_id, 'Later pickups cannot replace an active entry content').toBe(earlier.word_id);
        expect(entry.resting_rect, 'Each card keeps its chosen position throughout its lifetime').toEqual(earlier.resting_rect);
        expect(entry.variant_scale, 'Each card keeps its own chosen size throughout its lifetime').toBe(earlier.variant_scale);
        expect(entry.elapsed, 'Each card advances its own lifetime').toBeGreaterThanOrEqual(earlier.elapsed);
      }
      entryStates.set(entry.entry_id, entry);
    }
    if (frame.active) expect(frame.button.enabled).toBe(false);
    previousStarted = frame.started;
    previousCompleted = frame.completed;
  }
  expect(final.collection_batch.started).toBe(3);
  expect(final.collection_batch.completed).toBe(3);
  expect(final.collection_batch.elapsed, 'Three 100 ms collections finish in 300 ms of game time').toBeCloseTo(0.3, 6);
  const readable = timeline.find(frame => !frame.active && frame.revealed?.entries?.length === 3 &&
    frame.revealed.entries.every(entry => entry.content_alpha > 0.9));
  const lastWord = selectedById.get(final.collection_batch.ids.at(-1)).word;
  expect(readable, 'All three collected words coexist in an opaque reading burst after the fast batch').toBeTruthy();
  expect(readable.revealed.word_id).toBe(lastWord.id);
  expect(readable.revealed.spelling).toBe(lastWord.text);
  const burst = readable.revealed.entries;
  expect(new Set(burst.map(entry => entry.entry_id)).size, 'New words add independent cards').toBe(3);
  expect(burst.map(entry => entry.word_id).sort()).toEqual(selected.map(tile => tile.word.id).sort());
  expect(new Set(burst.map(entry => entry.resting_rect.slice(0, 2).join(','))).size,
    'The three words occupy different positions instead of covering a shared center').toBe(3);
  expect(new Set(burst.map(entry => entry.variant_scale)).size,
    'The burst varies its card sizes for a staggered rhythm').toBeGreaterThan(1);
  for (const entry of burst) expectWordRevealContent(entry, bounds, before.playfield_rect);
  expect(final.cleared_pairs).toBe(before.cleared_pairs + 3);
  expect(final.collected_coins).toBe(before.collected_coins + expectedCoins);
  expect(final.fragment_count).toBe(before.fragment_count + expectedFragments);
  expect(final.tiles.some(tile => collectedIds.includes(tile.id))).toBe(false);
  for (const id of retained) expect(final.tiles.some(tile => tile.id === id), 'Batch collection preserves unfinished roots').toBe(true);
  expect(final.collect_button.enabled).toBe(false);
  expect(final.collect_button.count).toBe(0);
  await capture(page, info, 'word-jelly-batch-completed');
  await page.waitForTimeout(800);
  expect((await wallet(page)).balance, 'Later presentation frames cannot repeat batch rewards').toBe(startingWallet.balance + expectedCoins);
  expect(errors).toEqual([]);
});

test('collected words reveal their picture and spelling above the bottom-anchored game with one pronunciation', async ({ page, browserName }, info) => {
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 4 });
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  const scale = Math.max(2 / 3, bounds.scale), area = opening.playfield_rect;
  const gameBottom = Math.max(...[opening.board_rect, opening.collect_button.rect, opening.loot.progress.rect]
    .map(rect => rect[1] + rect[3]));
  expect(Math.abs(gameBottom - (area[1] + area[3] - 12 / scale)) * bounds.scale,
    'The board and collection controls retain their bottom padding within a quarter rendered pixel')
    .toBeLessThan(0.25);
  expect(opening.preview.rect[1] + opening.preview.rect[3], 'The full supply tray remains above the board')
    .toBeLessThanOrEqual(opening.board_rect[1]);
  expect(opening.word_reveal.visible).toBe(false);
  await capture(page, info, 'word-jelly-bottom-anchored-opening');
  const supportedWords = state => rootsForWord({ ...state, tiles: state.tiles.filter(tile => tile.row + tile.height === state.rows) }, 3, 2);
  const first = supportedWords(await jelly(page));
  expect(first, 'A floor-supported word is available for the first collection').toBeTruthy();
  const firstMerged = await merge(page, first.roots[0].id, first.roots[1].id);
  const second = supportedWords(await jelly(page));
  expect(second, 'The initial board supplies another word for rapid successive collection').toBeTruthy();
  const secondMerged = await merge(page, second.roots[0].id, second.roots[1].id);
  expect(second.word.id).not.toBe(first.word.id);
  await page.exposeFunction('saveWordRevealFrame', (id, encoded) =>
    fs.writeFileSync(info.outputPath(`word-jelly-reveal-${id}.png`), Buffer.from(encoded, 'base64')));
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordRevealTimeline = [];
    window.wordRevealFrames = {};
    window.wordRevealInputs = [];
    window.wordRevealInputHandler = event => {
      if (event.isTrusted && event.target.id === 'canvas')
        window.wordRevealInputs.push({ at: performance.now(), sounds: window.audioObservation.playbacks.length });
    };
    document.addEventListener('pointerdown', window.wordRevealInputHandler, { capture: true });
    const pending = new Set();
    window.wordRevealObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}'), reveal = state.word_reveal;
      if (!reveal) return;
      window.wordRevealTimeline.push({ ...reveal, at: performance.now(), cleared: state.cleared_pairs });
      for (const entry of reveal.entries) {
        if (!entry.visible || entry.content_alpha < 0.95 || entry.elapsed < 0.20 || pending.has(entry.word_id)) continue;
        pending.add(entry.word_id);
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => {
            const encoded = reader.result.split(',')[1];
            window.wordRevealFrames[entry.word_id] = encoded;
            window.saveWordRevealFrame(entry.word_id, encoded);
          };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    });
    window.wordRevealObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  const before = await jelly(page), startingWallet = await wallet(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable).toBe(true);
  const candidates = [{ merged: firstMerged, word: first.word }, { merged: secondMerged, word: second.word }];
  const points = candidates.map(candidate => center(before.tiles.find(tile => tile.id === candidate.merged.id).rect, bounds));
  // Keep trusted gestures inside the reading beat. Helpers that wait for DOM
  // snapshots between each tap can consume the whole short effect under tracing.
  await page.touchscreen.tap(points[0].x, points[0].y);
  await page.touchscreen.tap(points[0].x, points[0].y);
  await page.waitForTimeout(240);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.touchscreen.tap(points[1].x, points[1].y);
  await page.touchscreen.tap(points[1].x, points[1].y);
  await expect.poll(() => page.evaluate(() => Object.keys(window.wordRevealFrames).length),
    { message: 'Both real reading beats produce a captured opaque picture and spelling' }).toBe(2);
  const evidence = await page.evaluate(() => ({ timeline: window.wordRevealTimeline, frames: window.wordRevealFrames,
    inputs: window.wordRevealInputs, sounds: window.audioObservation.playbacks }));
  fs.writeFileSync(info.outputPath('word-jelly-reveal-timeline.json'), JSON.stringify(evidence.timeline, null, 2));
  const together = evidence.timeline.find(reveal => reveal.entries.some(entry => entry.word_id === first.word.id) &&
    reveal.entries.some(entry => entry.word_id === second.word.id));
  expect(together, 'The next word appears while the earlier card continues its own reading beat').toBeTruthy();
  const firstEntry = together.entries.find(entry => entry.word_id === first.word.id);
  const secondEntry = together.entries.find(entry => entry.word_id === second.word.id);
  expect(firstEntry.entry_id).not.toBe(secondEntry.entry_id);
  expect(firstEntry.resting_rect.slice(0, 2), 'Successive taps use different reveal positions')
    .not.toEqual(secondEntry.resting_rect.slice(0, 2));
  expect(firstEntry.elapsed, 'Showing another word does not restart the earlier card').toBeGreaterThan(secondEntry.elapsed);
  if (audioAvailable) expect(evidence.inputs, 'The four real taps delimit separate word-audio windows').toHaveLength(4);
  const pronunciationObservations = [];
  for (const [index, candidate] of candidates.entries()) {
    const reveal = evidence.timeline.flatMap(frame => frame.entries)
      .find(entry => entry.word_id === candidate.word.id && entry.content_alpha > 0.95);
    expect(reveal, 'Each collected word owns a readable opaque hold within its actual lifetime').toBeTruthy();
    expect(reveal.spelling).toBe(candidate.word.text);
    expect(reveal.word.id).toBe(candidate.word.id);
    expect(reveal.picture.replace(/^res:\/\//, '')).toBe(candidate.merged.word.image);
    expectWordRevealContent(reveal, bounds, area);
    if (index === 1) expect(reveal.reduced_motion, 'The new word also supports a steady reduced-motion reading beat').toBe(true);
    if (audioAvailable) {
      const from = evidence.inputs[index * 2].sounds, end = evidence.inputs[(index + 1) * 2]?.sounds;
      const timing = recordingTiming(candidate.word.audio);
      const sounds = evidence.sounds.slice(from, end).filter(sound => sound.contextState === 'running' &&
        Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate);
      expect(sounds, 'Duplicate taps and the effect play one pronunciation per word, even when both recordings have equal length').toHaveLength(1);
      expect(sounds[0].peak, 'The bundled pronunciation contains audible samples').toBeGreaterThan(0.01);
      pronunciationObservations.push({ from, end, relative: candidate.word.audio, sound: sounds[0] });
    }
  }
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 2);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 200);
  await expect.poll(async () => (await jelly(page)).word_reveal.visible,
    { message: 'The picture and spelling leave on their own after the reading beat' }).toBe(false);
  const final = await jelly(page);
  expect(final.collected_coins).toBe(before.collected_coins + 200);
  expect(final.fragment_count).toBe(before.fragment_count + firstMerged.fragments + secondMerged.fragments);
  fs.writeFileSync(info.outputPath('word-jelly-reveal-timeline.json'), JSON.stringify({ timeline: evidence.timeline, pronunciationObservations }, null, 2));
  await page.evaluate(() => {
    window.wordRevealObserver.disconnect();
    document.removeEventListener('pointerdown', window.wordRevealInputHandler, { capture: true });
  });
  expect(errors).toEqual([]);
});

test('only forward dictionary words merge while rejected pairs separate without loss or duplicate feedback', async ({ page }, info) => {
  test.setTimeout(180000);
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  // Ordinary saved progress makes cat the next real word without a runtime test hook.
  await seedGrowth(page, 3, { unmastered: ['cat'] });
  const errors = await startWordJelly(page, { reducedMotion, preseededGrowth: true });
  const opening = await jelly(page), startingWallet = await wallet(page);
  const roots = opening.tiles.filter(tile => tile.source_word_id === 'cat').sort((a, b) => a.supply_part - b.supply_part);
  expect(roots.map(root => root.text)).toEqual(['ca', 't']);
  const negativePath = 'assets/imported-audio/pair-feedback/wrong.wav';
  const negativeTiming = recordingTiming(negativePath);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  const playbackIndex = () => page.evaluate(() => window.audioObservation.playbacks.length);
  const negativeSounds = from => page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from).filter(sound =>
    Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate), { from, timing: negativeTiming });
  const evidence = { reducedMotion, audioAvailable, negativePath, trials: [] };
  const retain = () => fs.writeFileSync(info.outputPath('word-jelly-rejection-audio.json'), JSON.stringify(evidence, null, 2));
  const attempt = async (sourceId, targetId, label) => {
    const audioFrom = await playbackIndex();
    const trial = { label, audioFrom };
    evidence.trials.push(trial);
    const rejection = await rejectMerge(page, sourceId, targetId, { info, label, reducedMotion,
      inspectContact: async held => {
        trial.heldContact = held.contact;
        if (audioAvailable) {
          trial.contactSound = await expectRecording(page, audioFrom, 'assets/imported-audio/jelly-interaction/contact.wav');
          expect(trial.contactSound.contextState).toBe('running');
          expect(trial.contactSound.peak).toBeGreaterThan(0.01);
          const count = await page.evaluate(({ from, fingerprint }) => window.audioObservation.playbacks.slice(from)
            .filter(sound => sound.fingerprint === fingerprint).length,
          { from: audioFrom, fingerprint: trial.contactSound.fingerprint });
          await page.waitForTimeout(400);
          expect(await page.evaluate(({ from, fingerprint }) => window.audioObservation.playbacks.slice(from)
            .filter(sound => sound.fingerprint === fingerprint).length,
          { from: audioFrom, fingerprint: trial.contactSound.fingerprint }), 'Held contact emits no repeated pressure cue').toBe(count);
          expect(await negativeSounds(audioFrom), 'Hovering an incompatible body never plays the negative cue').toEqual([]);
        }
        retain();
      }
    });
    trial.releaseAt = rejection.releaseAt;
    trial.rejectionFrames = rejection.timeline.filter(frame => frame.contact.kind === 'mismatch').map(frame => ({
      at: frame.at, strength: frame.contact.strength, tiles: frame.tiles.map(tile => ({ id: tile.id, rect: tile.rect }))
    }));
    if (audioAvailable) {
      trial.negativeSound = await expectRecording(page, audioFrom, negativePath);
      retain();
      expect(trial.negativeSound.at, 'The negative cue follows pointer-up, never hover').toBeGreaterThanOrEqual(trial.releaseAt - 2);
      expect(trial.negativeSound.at - trial.releaseAt, 'Rejection sound responds promptly to the actual release').toBeLessThan(250);
      expect(trial.negativeSound.peak).toBeGreaterThan(0.01);
      expect(trial.negativeSound.channels).toBe(2);
      expect(trial.negativeSound.channelFingerprints[0]).toBe(trial.negativeSound.channelFingerprints[1]);
      expect(trial.negativeSound.fingerprint).not.toBe(trial.contactSound.fingerprint);
      await page.waitForTimeout(950);
      trial.negativeSounds = await negativeSounds(audioFrom);
      expect(trial.negativeSounds, 'One rejected release plays the short negative recording exactly once').toHaveLength(1);
      expect(trial.negativeSounds[0].endedAt, 'The negative tail ends instead of looping').toBeGreaterThan(trial.negativeSound.at);
    }
    expect((await wallet(page)).balance, 'Rejecting a pair leaves the saved coin balance unchanged').toBe(startingWallet.balance);
    retain();
    return rejection;
  };

  await attempt(roots[1].id, roots[0].id, 'word-jelly-reversed-cat-rejection');
  const state = await jelly(page);
  const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => normalize(word.text)));
  const marked = state.tiles.filter(tile => tile.fragments > 0 && tile.mass === 1 && tile.settled);
  const unrelated = marked.flatMap(source => marked.map(target => ({ source, target }))).find(({ source, target }) =>
    source.id !== target.id && source.row === state.rows - 1 && target.row < source.row &&
    !words.has(normalize(source.text + target.text)) &&
    !words.has(normalize(target.text + source.text)));
  expect(unrelated, 'The real three-row supply offers unrelated marked bodies for a second rejected release').toBeTruthy();
  const nonword = await attempt(unrelated.source.id, unrelated.target.id, 'word-jelly-unrelated-marked-rejection');
  expect(nonword.after.tiles.filter(tile => [unrelated.source.id, unrelated.target.id].includes(tile.id))
    .reduce((sum, tile) => sum + tile.fragments, 0)).toBe(2);

  const beforeValid = await jelly(page), audioFrom = await playbackIndex();
  const completed = await merge(page, roots[0].id, roots[1].id);
  expect(completed.text).toBe('cat');
  expect(completed.word.id).toBe('cat');
  expect(completed.picture_visible).toBe(true);
  expect(completed.fragments).toBe(roots[0].fragments + roots[1].fragments);
  expect(completed.fragment_badges).toBe(completed.fragments);
  if (audioAvailable) {
    evidence.validMergeSound = await expectRecording(page, audioFrom, 'assets/imported-audio/jelly-interaction/merge-together-v3.wav');
    expect(await negativeSounds(audioFrom), 'A valid forward merge never plays the negative cue').toEqual([]);
  }
  await capture(page, info, 'word-jelly-forward-cat-after-rejections');
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  await pressRect(page, completed.rect);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + completed.coins);
  const final = await jelly(page);
  expect(final.merged_count).toBe(beforeValid.merged_count + 1);
  expect(final.cleared_pairs).toBe(opening.cleared_pairs + 1);
  expect(final.fragment_count).toBe(opening.fragment_count + completed.fragments);
  expect(final.tiles.some(tile => tile.id === completed.id || roots.some(root => root.id === tile.id))).toBe(false);
  evidence.final = final;
  retain();
  expect(errors).toEqual([]);
});

test('ordinary collected fragments synthesize a chest and then celebrate its upgrade', async ({ page }, info) => {
  test.skip(!['desktop-chromium', 'iphone-webkit'].includes(info.project.name), 'The complete milestone route covers desktop and phone renderers.');
  test.setTimeout(300000);
  const errors = await startWordJelly(page, { reducedMotion: 'no-preference' });
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyMilestones = [];
    window.wordJellyMilestoneFrames = {};
    window.wordJellyFlightFrames = {};
    window.wordJellyFlightCaptures = [];
    const captureFlight = key => {
      if (Object.hasOwn(window.wordJellyFlightFrames, key)) return;
      window.wordJellyFlightFrames[key] = null;
      window.wordJellyFlightCaptures.push(new Promise(resolve => {
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return resolve();
          const reader = new FileReader();
          reader.onload = () => {
            window.wordJellyFlightFrames[key] = reader.result.split(',')[1];
            resolve();
          };
          reader.onerror = resolve;
          reader.readAsDataURL(blob);
        }, 'image/png');
      }));
    };
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}'), presentation = state.reward_presentation;
      if (state.mode !== 'word_jelly' || !presentation?.active) return;
      window.wordJellyMilestones.push({ kind: presentation.kind, tier: presentation.tier,
        visible: presentation.visible, revealed: presentation.revealed, elapsed: presentation.elapsed,
        fragments: state.fragment_count, chests: state.chest_count, motion: presentation.motion,
        anchor: presentation.anchor, flightBounds: presentation.flight_bounds,
        wordRevealVisible: state.word_reveal.visible });
      if (presentation.visible && presentation.motion?.center) {
        const motion = presentation.motion, kind = presentation.kind;
        if (motion.phase === 'center') captureFlight(`${kind}-departure`);
        if (motion.phase === 'rise') captureFlight(`${kind}-screen-center`);
        if (motion.phase === 'celebrate' && !presentation.revealed) captureFlight(`${kind}-upper-arrival`);
        if (presentation.revealed && motion.phase === 'celebrate') captureFlight(`${kind}-enlarged-turn`);
        if (motion.phase === 'return') captureFlight(`${kind}-return`);
      }
      if (presentation.visible && presentation.revealed && !window.wordJellyMilestoneFrames[presentation.kind])
        window.wordJellyMilestoneFrames[presentation.kind] = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
  for (let attempt = 0; attempt < 40; attempt++) {
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.phase === 'playing' && !state.reward_presentation.active && state.tiles.every(tile => tile.settled);
    }, { message: 'The previous milestone finishes before the next deliberate word' }).toBe(true);
    const state = await jelly(page);
    if (state.fragment_count >= 9) break;
    const found = rootsForWord(state, 3, 2, true) || rootsForWord(state, 3, 2);
    if (!found) {
      expect(state.preview.enabled, 'Real supply remains available while building the chest').toBe(true);
      await pressRect(page, state.preview.rect);
      await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
      continue;
    }
    const completed = await merge(page, found.roots[0].id, found.roots[1].id);
    await pressRect(page, completed.rect);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + 1);
    const after = await jelly(page);
    if (after.chest_tier > state.chest_tier) {
      const kind = state.chest_tier === 0 ? 'synthesis' : 'upgrade';
      await expect.poll(async () => {
        const reward = (await jelly(page)).reward_presentation;
        return reward.kind === kind && reward.visible && reward.revealed;
      }, { intervals: [50], message: `The ${kind} visibly reaches its flash and confetti reveal` }).toBe(true);
      const peak = await page.evaluate(kind => window.wordJellyMilestoneFrames[kind], kind);
      expect(peak, `The first rendered ${kind} reveal is captured before its flash fades`).toBeTruthy();
      fs.writeFileSync(info.outputPath(`word-jelly-chest-${kind}-reveal.png`), Buffer.from(peak, 'base64'));
      await capture(page, info, `word-jelly-chest-${kind}`);
    }
  }
  const final = await jelly(page);
  expect(final.fragment_count).toBeGreaterThanOrEqual(9);
  expect(final.chest_count).toBe(1);
  expect(final.chest_tier).toBe(2);
  await expect.poll(async () => (await jelly(page)).reward_presentation.active,
    { timeout: 10000, message: 'The upgraded chest visibly finishes its return to the HUD anchor' }).toBe(false);
  await capture(page, info, 'word-jelly-chest-returned-to-anchor');
  const { milestones, keyframes } = await page.evaluate(async () => {
    await Promise.all(window.wordJellyFlightCaptures);
    return { milestones: window.wordJellyMilestones, keyframes: window.wordJellyFlightFrames };
  });
  await info.attach('word-jelly-chest-milestones.json', { body: JSON.stringify(milestones, null, 2), contentType: 'application/json' });
  for (const [name, encoded] of Object.entries(keyframes)) {
    if (encoded) fs.writeFileSync(info.outputPath(`word-jelly-chest-${name}.png`), Buffer.from(encoded, 'base64'));
  }
  for (const [kind, tier] of [['synthesis', 1], ['upgrade', 2]]) {
    const frames = milestones.filter(frame => frame.kind === kind && frame.tier === tier);
    expect(frames.some(frame => frame.visible && !frame.revealed), `${kind} has visible anticipation`).toBe(true);
    expect(frames.some(frame => frame.visible && frame.revealed), `${kind} has a visible reward reveal`).toBe(true);
    expect(new Set(frames.map(frame => frame.elapsed)).size, `${kind} advances through several rendered poses`).toBeGreaterThan(3);
    const visible = frames.filter(frame => frame.visible && frame.motion?.center);
    const first = visible[0], bounds = first.flightBounds, anchor = first.anchor;
    const screenCenter = [bounds[0] + bounds[2] / 2, bounds[1] + bounds[3] / 2];
    const anchorCenter = [anchor[0] + anchor[2] / 2, anchor[1] + anchor[3] / 2];
    const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
    const tolerance = Math.max(3, Math.hypot(bounds[2], bounds[3]) * 0.03);
    // Periodic status updates are at least 100 ms apart, so the first and last
    // endpoints can fall between samples. Check the observed journey here;
    // native route tests cover exact start/end poses and timing boundaries.
    const phases = visible.map(frame => frame.motion.phase).filter((phase, index, all) => index === 0 || phase !== all[index - 1]);
    expect(phases, `${kind} flies to screen center, rises, celebrates, and returns in order`).toEqual(['center', 'rise', 'celebrate', 'return']);
    const departure = visible.filter(frame => frame.motion.phase === 'center');
    expect(departure.length, `${kind} has several observed poses on its outbound journey`).toBeGreaterThan(1);
    const outboundDistance = distance(anchorCenter, screenCenter);
    let previousCenterDistance = Infinity;
    for (const frame of departure) {
      const currentDistance = distance(frame.motion.center, screenCenter);
      expect(distance(frame.motion.center, anchorCenter) + currentDistance,
        `${kind} departs along the route from its HUD chest to screen center`).toBeLessThanOrEqual(outboundDistance + 1);
      expect(currentDistance, `${kind} moves closer to screen center`).toBeLessThanOrEqual(previousCenterDistance + 0.1);
      previousCenterDistance = currentDistance;
    }
    expect(previousCenterDistance, `${kind} makes visible progress toward screen center`)
      .toBeLessThan(distance(departure[0].motion.center, screenCenter) - 1);
    const centered = visible.filter(frame => ['center', 'rise'].includes(frame.motion.phase));
    expect(Math.min(...centered.map(frame => distance(frame.motion.center, screenCenter))),
      `${kind} visibly travels through the actual screen center`).toBeLessThan(tolerance);
    const upper = visible.filter(frame => frame.motion.phase === 'celebrate');
    expect(upper.length, `${kind} has an upper-screen presentation beat`).toBeGreaterThan(2);
    let previousHeight = screenCenter[1];
    for (const frame of visible.filter(frame => frame.motion.phase === 'rise')) {
      expect(Math.abs(frame.motion.center[0] - screenCenter[0]), `${kind} rises from the horizontal screen center`).toBeLessThan(1);
      expect(frame.motion.center[1], `${kind} moves upward before celebrating`).toBeLessThanOrEqual(previousHeight + 0.1);
      previousHeight = frame.motion.center[1];
    }
    for (const frame of upper) {
      expect(Math.abs(frame.motion.center[0] - screenCenter[0]), `${kind} stays horizontally centered upstairs`).toBeLessThan(1);
      expect(frame.motion.center[1], `${kind} celebrates in the upper portion of the screen`).toBeLessThan(bounds[1] + bounds[3] * 0.4);
    }
    expect(centered.every(frame => frame.motion.scale <= 1.05 && Math.abs(frame.motion.yaw) < 0.01),
      `${kind} travels to its upper destination before enlarging and turning`).toBe(true);
    expect(Math.max(...upper.map(frame => frame.motion.scale)), `${kind} clearly enlarges at its destination`).toBeGreaterThan(1.3);
    expect(upper.some(frame => frame.motion.yaw > 0.1 && frame.motion.yaw < 6.1), `${kind} visibly turns while enlarged upstairs`).toBe(true);
    expect(Math.max(...visible.map(frame => frame.motion.yaw)), `${kind} completes its full closed-chest turn by the return journey`).toBeGreaterThan(6.2);
    const returning = visible.filter(frame => frame.motion.phase === 'return');
    expect(returning.length, `${kind} has a visible return journey`).toBeGreaterThan(2);
    let previousDistance = Infinity;
    let previousScale = Infinity;
    for (const frame of returning) {
      const currentDistance = distance(frame.motion.center, anchorCenter);
      expect(currentDistance, `${kind} returns continuously toward its original anchor`).toBeLessThanOrEqual(previousDistance + 0.1);
      expect(frame.motion.scale, `${kind} shrinks continuously on its return journey`).toBeLessThanOrEqual(previousScale);
      previousDistance = currentDistance;
      previousScale = frame.motion.scale;
    }
    expect(previousDistance, `${kind} visibly covers most of the return distance before the HUD icon takes over`)
      .toBeLessThan(Math.max(tolerance, distance(upper.at(-1).motion.center, anchorCenter) * 0.35));
    const peakScale = Math.max(...upper.map(frame => frame.motion.scale));
    expect(previousScale - 1, `${kind} visibly recovers most of its original size before the HUD icon takes over`)
      .toBeLessThan((peakScale - 1) * 0.35);
    const firstReveal = visible.find(frame => frame.revealed);
    expect(firstReveal.wordRevealVisible, 'The chest peak follows the completed word-picture reading beat').toBe(false);
    expect(['departure', 'screen-center', 'upper-arrival', 'enlarged-turn', 'return']
      .every(phase => Boolean(keyframes[`${kind}-${phase}`])), `${kind} records all five real rendered flight keyframes`).toBe(true);
  }
  expect(errors).toEqual([]);
});

test('older-age words remain completable from two blocks and pay their collected reward', async ({ page }, info) => {
  await seedGrowth(page, 12, { unmastered: ['quadrilateral'] });
  const errors = await startWordJelly(page, { age: 12, reducedMotion: 'reduce', preseededGrowth: true });
  const word = vocabulary.find(candidate => candidate.id === 'quadrilateral');
  const roots = (await jelly(page)).tiles.filter(tile => tile.source_word_id === word.id)
    .sort((a, b) => a.supply_part - b.supply_part);
  expect(roots, 'A long current-age word arrives as exactly two completable blocks').toHaveLength(2);
  expect(roots.map(root => root.text).join('')).toBe(word.text);
  const labelEvidence = { roots };
  const retainLabels = () => fs.writeFileSync(info.outputPath('word-jelly-current-age-two-block-labels.json'),
    JSON.stringify(labelEvidence, null, 2));
  const expectCompleteLabel = tile => {
    expect(tile.label_text, 'The rendered label contains the complete spelling').toBe(tile.text);
    expect(tile.label_line_count).toBeGreaterThan(0);
    expect(tile.label_visible_line_count, 'Every shaped spelling line is visible').toBeGreaterThanOrEqual(tile.label_line_count);
    expect(tile.label_line_height).toBeGreaterThan(0);
    expect(tile.label_line_count * tile.label_line_height, 'Actual shaped line heights fit the label')
      .toBeLessThanOrEqual(tile.label_height + 0.1);
  };
  retainLabels();
  roots.forEach(expectCompleteLabel);
  await capture(page, info, 'word-jelly-current-age-two-block-roots');
  const startingWallet = await wallet(page);
  const completed = await merge(page, roots[0].id, roots[1].id);
  labelEvidence.completed = completed;
  retainLabels();
  expectCompleteLabel(completed);
  expect(completed.mass).toBe(2);
  expect(completed.coins).toBe(completed.mass * 50);
  expect(completed.word.id).toBe(word.id);
  expect(completed.word.min_age).toBe(12);
  expect(completed.picture_visible).toBe(true);
  expectInside(completed.rect, await metrics(page));
  await capture(page, info, 'word-jelly-current-age-two-block-word');
  const before = await jelly(page);
  await pressRect(page, completed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + completed.coins);
  expect((await jelly(page)).collected_coins).toBe(before.collected_coins + completed.coins);
  expect(errors).toEqual([]);
});
