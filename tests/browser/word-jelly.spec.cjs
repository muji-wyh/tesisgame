const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, metrics, tap, rendered, enterGame } = require('./game-ui.cjs');
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

async function startWordJelly(page, { age = 3, reducedMotion = 'no-preference' } = {}) {
  const earnedAge = age === 3 ? 0 : age - 1;
  await page.addInitScript(earnedAge => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=3\nlevel=0\nage=${earnedAge}\nstreaks={}\nmastered_words=[]\nreceipts=[]\n`);
  }, earnedAge);
  const errors = await openGame(page, { reducedMotion });
  await openModeMenu(page);
  const control = (await metrics(page)).library.controls.find(item => item.name === 'Mode_word_jelly');
  expect(control, 'Word Jelly appears in the ordinary game library').toBeTruthy();
  expect(control.disabled).toBe(false);
  await pressRect(page, control.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.tiles?.length >= 12 && state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Word Jelly board opens with twelve settled roots' }).toBe(true);
  return errors;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

function rootsForWord(state, age, count, markedOnly = false) {
  const words = new Map(vocabulary.filter(word => word.min_age === age).map(word => [normalize(word.text), word]));
  const roots = state.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1);
  for (const first of roots) for (const second of roots) {
    if (first.id === second.id) continue;
    const prefix = first.text + second.text;
    if (count === 2 && words.has(normalize(prefix)) && (!markedOnly || first.fragments + second.fragments > 0))
      return { roots: [first, second], word: words.get(normalize(prefix)) };
    if (count !== 3) continue;
    for (const third of roots) {
      if (third.id === first.id || third.id === second.id) continue;
      const text = normalize(prefix + third.text);
      if (words.has(text)) return { roots: [first, second, third], word: words.get(text) };
    }
  }
  return null;
}

async function availableWord(page, age, count) {
  for (let attempt = 0; attempt < 4; attempt++) {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page), found = rootsForWord(state, age, count);
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
    return state.merged_count === before.merged_count + 1 && Boolean(result?.settled);
  }, { message: 'The union settles into a persistent larger jelly in source-then-target order' }).toBe(true);
  const after = await jelly(page);
  expect(after.tiles.some(tile => tile.id === sourceId || tile.id === targetId)).toBe(false);
  expect(after.cleared_pairs, 'Merging does not automatically collect a word').toBe(before.cleared_pairs);
  expect(after.fragment_count, 'Carried fragments are collected only after a valid word is tapped').toBe(before.fragment_count);
  expect(result.fragments).toBe(source.fragments + target.fragments);
  expect(result.row, 'A merged jelly stays at the target row or grows upward without sinking').toBeLessThanOrEqual(target.row);
  for (const original of before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId && tile.settled)) {
    const unchanged = after.tiles.find(tile => tile.id === original.id);
    expect(unchanged, 'Merging preserves every unrelated jelly').toBeTruthy();
    const expanded = unchanged.width !== original.width || unchanged.height !== original.height;
    if (expanded) {
      const compressed = original.width < Math.min(before.columns, original.mass) ||
        original.height < Math.min(before.rows, Math.ceil(original.mass / before.columns));
      expect(compressed, 'Only an already compressed jelly can expand when a merge frees space').toBe(true);
      expect(unchanged.width).toBeGreaterThanOrEqual(original.width);
      expect(unchanged.height).toBeGreaterThanOrEqual(original.height);
      expect(unchanged.row, 'Restored growth cannot make an unrelated jelly sink').toBeLessThanOrEqual(original.row);
      continue;
    }
    expect([unchanged.column, unchanged.row], 'A merge leaves unrelated occupied cells in place')
      .toEqual([original.column, original.row]);
    for (let axis = 0; axis < original.rect.length; axis++)
      expect(unchanged.rect[axis], 'Unrelated settled jelly positions and sizes remain visually stable')
        .toBeCloseTo(original.rect[axis], 3);
  }
  return result;
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

test('six columns build a pictured word and a deliberate tap credits its coins once', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  expect(opening.tiles).toHaveLength(12);
  expect(opening.columns).toBe(6);
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
  await page.keyboard.press('Escape');
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

test('ordinary collected fragments synthesize a chest and then celebrate its upgrade', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop-chromium', 'The complete milestone path supplements the phone and desktop core interactions.');
  test.setTimeout(180000);
  const errors = await startWordJelly(page, { reducedMotion: 'no-preference' });
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyMilestones = [];
    window.wordJellyMilestoneFrames = {};
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}'), presentation = state.reward_presentation;
      if (state.mode !== 'word_jelly' || !presentation?.active) return;
      window.wordJellyMilestones.push({ kind: presentation.kind, tier: presentation.tier,
        visible: presentation.visible, revealed: presentation.revealed, elapsed: presentation.elapsed,
        fragments: state.fragment_count, chests: state.chest_count });
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
  const milestones = await page.evaluate(() => window.wordJellyMilestones);
  for (const [kind, tier] of [['synthesis', 1], ['upgrade', 2]]) {
    const frames = milestones.filter(frame => frame.kind === kind && frame.tier === tier);
    expect(frames.some(frame => frame.visible && !frame.revealed), `${kind} has visible anticipation`).toBe(true);
    expect(frames.some(frame => frame.visible && frame.revealed), `${kind} has a visible reward reveal`).toBe(true);
    expect(new Set(frames.map(frame => frame.elapsed)).size, `${kind} advances through several rendered poses`).toBeGreaterThan(3);
  }
  await info.attach('word-jelly-chest-milestones.json', { body: JSON.stringify(milestones, null, 2), contentType: 'application/json' });
  expect(errors).toEqual([]);
});

test('carried fragments stack and a merged jelly stays draggable as it wraps beyond six parts', async ({ page }, info) => {
  const errors = await startWordJelly(page, { reducedMotion: 'reduce' });
  const opening = await jelly(page), marked = opening.tiles.filter(tile => tile.fragments > 0);
  expect(marked.length, 'The opening supply contains several independently marked roots').toBeGreaterThanOrEqual(2);
  let merged = await merge(page, marked[0].id, marked[1].id);
  expect(merged.fragments).toBe(2);
  expect(merged.fragment_badges, 'Both inherited fragments are presented on the merged jelly').toBe(2);
  await capture(page, info, 'word-jelly-two-carried-fragments');
  while (merged.mass < 7) {
    const state = await jelly(page);
    const next = state.tiles.find(tile => tile.id !== merged.id && tile.visible && tile.settled && tile.mass === 1 && tile.fragments === 0);
    expect(next, 'The starter packet has enough unmarked roots to grow this jelly').toBeTruthy();
    merged = await merge(page, merged.id, next.id);
  }
  expect(merged.mass).toBe(7);
  expect(merged.width).toBe(6);
  expect(merged.height).toBeGreaterThan(1);
  expect(merged.fragments).toBe(2);
  expect(merged.fragment_badges).toBe(2);
  expectInside(merged.rect, await metrics(page));
  expect((await jelly(page)).fragment_count, 'Merging never consumes the visible fragments').toBe(opening.fragment_count);
  await capture(page, info, 'word-jelly-wrapped-seven-part-body');
  expect(errors).toEqual([]);
});

test('three-part words use only the active age and pay more when the larger jelly is collected', async ({ page }, info) => {
  const errors = await startWordJelly(page, { age: 12, reducedMotion: 'reduce' });
  const { roots, word } = await availableWord(page, 12, 3), startingWallet = await wallet(page);
  const partial = await merge(page, roots[0].id, roots[1].id);
  const completed = await merge(page, partial.id, roots[2].id);
  expect(completed.mass).toBe(3);
  expect(completed.word.id).toBe(word.id);
  expect(completed.word.min_age).toBe(12);
  expect(completed.picture_visible).toBe(true);
  expectInside(completed.rect, await metrics(page));
  await capture(page, info, 'word-jelly-current-age-three-part-word');
  const before = await jelly(page);
  await pressRect(page, completed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 150);
  expect((await jelly(page)).collected_coins).toBe(before.collected_coins + 150);
  expect(errors).toEqual([]);
});
