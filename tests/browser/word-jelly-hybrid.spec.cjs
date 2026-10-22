const { test, expect } = require('@playwright/test');
const { openGame, chooseMode, metrics, tap, rendered } = require('./game-ui.cjs');
const { expectCollectionReward } = require('./word-jelly-rewards.cjs');

const state = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const point = (tile, bounds) => ({
  x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
  y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale,
});

async function join(page, first, second, projectName) {
  const before = await state(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === first);
  const destination = before.tiles.find(tile => tile.id === second);
  const from = point(source, bounds), to = point(destination, bounds);
  const touch = projectName === 'android-chromium' ? await page.context().newCDPSession(page) : null;
  let cursor = from;
  const move = async (next, steps = 1) => {
    if (touch) {
      const start = cursor;
      for (let step = 1; step <= steps; step++) {
        await touch.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1,
          x: start.x + (next.x - start.x) * step / steps,
          y: start.y + (next.y - start.y) * step / steps }] });
      }
      cursor = next;
    } else {
      await page.mouse.move(next.x, next.y, { steps });
    }
  };
  try {
    if (touch) {
      await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...from }] });
    } else {
      await page.mouse.move(from.x, from.y);
      await page.mouse.down();
    }
    await move({ x: from.x, y: from.y - 16 });
    await move(to, 8);
    await expect.poll(async () => (await state(page)).drag.source).toBe(first);
    if (touch) await expect.poll(async () => (await state(page)).drag.pointer,
      { message: 'Android dragging is owned by a real touch pointer' }).toBeGreaterThanOrEqual(0);
    await expect.poll(async () => {
      const current = await state(page), target = current.tiles.find(tile => tile.id === second);
      if (!target?.settled) return false;
      if (current.drag.target === second) return true;
      const next = point(target, bounds);
      await move(next, 4);
      return false;
    }).toBe(true);
  } finally {
    if (touch) {
      try {
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } finally {
        await touch.detach();
      }
    } else {
      await page.mouse.up();
    }
  }
  let merged;
  await expect.poll(async () => {
    const current = await state(page);
    merged = current.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.mass === source.mass + destination.mass && tile.jelly_kind === 'merged');
    return current.merged_count === before.merged_count + 1 && Boolean(merged?.settled);
  }).toBe(true);
  expect((await state(page)).cleared_pairs).toBe(before.cleared_pairs);
  expect([merged.width, merged.height]).toEqual([1, 1]);
  expectCollectionReward(merged);
  return merged;
}

test('whole-word roots match pictures and merged words remain compact and collectable', async ({ page }, info) => {
  test.setTimeout(600000);
  const errors = await openGame(page);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const current = await state(page);
    return current.visible && current.phase === 'playing' && current.tiles?.length > 0 &&
      current.tiles.every(tile => tile.settled);
  }, { timeout: 30000 }).toBe(true);
  const before = await state(page);
  expect(before.stage.number).toBe(1);
  expect(before.stage.total).toBe(10);
  expect(before.stage.remaining_ids).toHaveLength(10);
  expect(before.stage.label).toBe('Stage 1  ·  0 / 10 mastered');
  expect(before.tiles.every(tile => before.stage.word_ids.includes(tile.source_word_id))).toBe(true);
  const root = before.tiles.find(tile => tile.jelly_kind === 'root' && tile.word_candidate?.id &&
    before.tiles.some(picture => picture.jelly_kind === 'picture' && picture.image_word?.id === tile.word_candidate.id));
  expect(root, 'The real opening contains an atomic word and its matching picture').toBeTruthy();
  const picture = before.tiles.find(tile => tile.jelly_kind === 'picture' && tile.image_word?.id === root.word_candidate.id);
  expect(root.label_visible).toBe(true);
  expect(root.picture_visible).toBe(false);
  expect(root.word).toEqual({});
  expect(picture.label_visible).toBe(false);
  expect(picture.label_text).toBe('');
  expect(picture.picture_visible).toBe(true);
  expect(picture.requires_read).toBe(false);
  const merged = await join(page, root.id, picture.id, info.project.name);
  expect(merged.word.id).toBe(root.word_candidate.id);
  expect(merged.merge_level).toBe(1);
  expect(merged.mastery_eligible).toBe(true);
  expect(merged.label_visible && merged.picture_visible).toBe(true);
  expect(merged.presentation.merged_light).toBe(true);
  expect(merged.rect[2]).toBeCloseTo(root.rect[2], 3);
  await page.screenshot({ path: info.outputPath('hybrid-word-and-picture.png') });
  await page.setViewportSize({ width: 390, height: 844 });
  await rendered(page);
  await expect.poll(async () => {
    const current = await state(page), live = current.tiles.find(tile => tile.id === merged.id);
    return !current.layout_paused && live?.picture_visible && live?.label_visible;
  }).toBe(true);
  const phone = await state(page), live = phone.tiles.find(tile => tile.id === merged.id);
  expect(phone.stage.visible).toBe(true);
  expect(phone.stage.rect[1] + phone.stage.rect[3]).toBeLessThanOrEqual(phone.preview.rect[1]);
  expect([live.width, live.height]).toEqual([1, 1]);
  expect(live.rect[2]).toBeCloseTo(live.rect[3], 3);
  expect(live.label_font_pixels).toBeGreaterThanOrEqual(13);
  expect(phone.tiles.find(tile => tile.jelly_kind === 'picture').label_visible).toBe(false);
  await page.screenshot({ path: info.outputPath('hybrid-phone.png') });
  const holdPoint = point(live, await metrics(page));
  await page.mouse.move(holdPoint.x, holdPoint.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await state(page)).drag.source).toBe(merged.id);
    await page.waitForTimeout(650);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => (await state(page)).drag.source).toBe(-1);
  const afterHold = await state(page), retained = afterHold.tiles.find(tile => tile.id === merged.id);
  expect(afterHold.cleared_pairs).toBe(phone.cleared_pairs);
  expect(afterHold.tiles.map(tile => tile.id)).toEqual(expect.arrayContaining(phone.tiles.map(tile => tile.id)));
  expect(retained?.jelly_kind).toBe('merged');
  expect(afterHold.fusions.some(fusion => fusion.operation === 'collect')).toBe(false);
  expect(afterHold.read_detail.visible, 'Holding a clipped phone label opens its Read dialog').toBe(retained.requires_read);
  if (afterHold.read_detail.visible) {
    expect(afterHold.read_detail.text).toBe(merged.word.text);
    expect(afterHold.paused).toBe(true);
    await page.screenshot({ path: info.outputPath('hybrid-read-dialog.png') });
    await page.keyboard.press('Escape');
    await expect.poll(async () => {
      const current = await state(page);
      return !current.read_detail.visible && !current.paused;
    }).toBe(true);
  }
  const collectable = (await state(page)).tiles.find(tile => tile.id === merged.id);
  await tap(page, collectable.rect[0] + collectable.rect[2] / 2, collectable.rect[1] + collectable.rect[3] / 2);
  await expect.poll(async () => (await state(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await state(page)).tiles.some(tile => tile.id === merged.id)).toBe(false);
  expect((await state(page)).collected_coins, 'Collecting Lv1 never awards bonus coins').toBe(before.collected_coins);
  expect(errors).toEqual([]);
});
