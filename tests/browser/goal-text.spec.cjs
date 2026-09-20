const { test, expect } = require('@playwright/test');
const { openGame, openRewards, roomControl, roomPoint, roomState, metrics, collectionBounds,
  uiScale, tap, rendered } = require('./game-ui.cjs');

test.use({
  viewport: { width: 1024, height: 768 },
  deviceScaleFactor: 1.5,
  hasTouch: true,
  reducedMotion: 'reduce'
});

async function checkBelowBell(page, testInfo, name, fromGoal = false) {
  // Reveal the next locked row without refreshing away an in-place retry message.
  for (let index = 0; index < (fromGoal ? 2 : 3); index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  const bounds = await metrics(page), collection = collectionBounds(bounds), scale = uiScale(bounds);
  const cell = (collection.width - collection.gap * 2) / 3;
  const lastRow = roomPoint(bounds, 'space', { owned: (await roomState(page)).owned });
  const bottom = bounds.y + (lastRow.y - 64 / scale - collection.gap) * bounds.scale;
  const left = bounds.x + (collection.x + cell + collection.gap) * bounds.scale;
  const clip = { x: left + 20, y: bottom + 2, width: cell * bounds.scale - 40, height: 13 };
  const png = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  const ink = await page.evaluate(async ({ data, clip }) => {
    const image = new Image();
    image.src = 'data:image/png;base64,' + data;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(Math.round(clip.x), Math.round(clip.y), Math.floor(clip.width), clip.height).data;
    let count = 0;
    for (let index = 0; index < pixels.length; index += 4) {
      if (pixels[index] < 160 && pixels[index + 1] < 160 && pixels[index + 2] < 180) count++;
    }
    return count;
  }, { data: png.toString('base64'), clip });
  expect(ink, `${name}: no card text may render below the Winter bell border`).toBe(0);
}

test('inline goal and retry text stay inside the bell card at desktop scaling', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    localStorage.setItem('wordBuddies.medalProgress',
      '[medals]\nversion=1\ncounts={"spring-1":1,"spring-3":3,"summer-1":3,"autumn-1":3,"winter-1":1,"space-1":2}\n');
    localStorage.setItem('wordBuddies.playroom',
      '[playroom]\nversion=1\ntoy="toy-autumn"\nbackdrop="backdrop-spring"\nfavorite=""\n\n[journey]\npreferred_theme_id="summer"\ngoal_item_id=""\nrecent_topic_ids=[]\n');
  });
  const errors = await openGame(page, { mode: 'match' });
  await openRewards(page);
  const point = await roomControl(page, 'winter');
  await tap(page, point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('Winter bell. Complete Snowflake: 1/3. 2 more pieces');
  await checkBelowBell(page, testInfo, 'bell-goal-contained');
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Goal text retry fixture', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreGoalTextSave = () => { Storage.prototype.setItem = save; };
  });
  await roomControl(page, 'goal', { locked: true, item: 'winter' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('could not be saved');
  await checkBelowBell(page, testInfo, 'bell-retry-contained', true);
  await page.evaluate(() => window.restoreGoalTextSave());
  expect(errors).toEqual([]);
});
