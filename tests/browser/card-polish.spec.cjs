const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { openGame, openRewards, metrics, rendered, roomControl, collectionBounds,
  uiScale, worldIconRect, tap, visibleColorCount, chooseRewardSection } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';

test('an equipped starter keeps its Using badge clear of failed-load retry text', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.addInitScript(() => {
    const read = Storage.prototype.getItem;
    window.blockRoomRead = true;
    Storage.prototype.getItem = function (key) {
      if (key === 'wordBuddies.playroom' && window.blockRoomRead) throw new DOMException('Fixture room read failure', 'SecurityError');
      return read.call(this, key);
    };
  });
  const errors = await openGame(page, { mode: 'match' });
  await openRewards(page);
  await chooseRewardSection(page, 'room');
  // Known fresh fixture: 13 header choices, then seven room controls before Ball.
  // Do not read the deliberately blocked store just to navigate this fixture.
  for (let index = 0; index < 20; index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Your room could not be saved.');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('using-ball-retry-320.png'), scale: 'css' });
  await page.evaluate(() => { window.blockRoomRead = false; });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Roll the ball');
  expect(await page.evaluate(key => localStorage.getItem(key), ROOM_KEY)).toContain('toy="toy-ball"');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('using-ball-recovered-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

async function recordPressFrames(page, clip) {
  await page.evaluate(async clip => {
    const source = document.querySelector('#canvas'), rect = source.getBoundingClientRect();
    const sample = document.createElement('canvas');
    sample.width = Math.ceil(clip.width); sample.height = Math.ceil(clip.height);
    const context = sample.getContext('2d', { willReadFrequently: true });
    const frame = () => new Promise(resolve => requestAnimationFrame(() => {
      context.clearRect(0, 0, sample.width, sample.height);
      context.drawImage(source, (clip.x - rect.x) * source.width / rect.width,
        (clip.y - rect.y) * source.height / rect.height, clip.width * source.width / rect.width,
        clip.height * source.height / rect.height, 0, 0, sample.width, sample.height);
      const pixels = context.getImageData(0, 0, sample.width, sample.height).data;
      let hash = 2166136261, visible = 0;
      for (let index = 0; index < pixels.length; index++) {
        hash = Math.imul(hash ^ pixels[index], 16777619) >>> 0;
        if (index % 4 === 3 && pixels[index]) visible++;
      }
      resolve({ hash, visible });
    }));
    const first = await frame();
    window.pipPressFrames = (async () => {
      const frames = [first];
      let image = '';
      for (let index = 0; index < 36; index++) {
        const next = await frame();
        frames.push(next);
        if (!image && next.visible && next.hash !== first.hash) image = sample.toDataURL('image/png');
      }
      return { frames, image };
    })();
  }, clip);
}

test('Pip and Words distinguishes the equipped toy from a preview and animates without moving cards', async ({ page }, testInfo) => {
  const room = '[playroom]\nversion=1\ntoy="toy-spring"\nbackdrop="backdrop-home"\nfavorite=""\n'
    + '\n[journey]\nrecent_topic_ids=[]\npreferred_theme_id="ocean"\ngoal_item_id="toy-ocean"\n'
    + '\n[learning]\nage_band="all"\n';
  await page.addInitScript(({ room, key }) => {
    if (!localStorage.getItem(key)) localStorage.setItem(key, room);
    if (!localStorage.getItem('wordBuddies.medalProgress')) {
      localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1":3, "ocean-1":1}\n');
    }
  }, { room, key: ROOM_KEY });
  const errors = await openGame(page, { mode: 'match', reducedMotion: 'no-preference' });
  await expect(page).toHaveTitle('Pip and Words');
  await expect(page.locator('#canvas')).toHaveAttribute('aria-label', 'Pip and Words word game');
  await openRewards(page);
  const before = await page.evaluate(key => localStorage.getItem(key), ROOM_KEY);
  const rewards = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  const target = await roomControl(page, 'ocean');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Preview only. Ocean shell.');
  expect(await page.evaluate(key => localStorage.getItem(key), ROOM_KEY)).toBe(before);
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(rewards);
  await rendered(page);
  const png = await page.screenshot({ path: testInfo.outputPath('using-flower-preview-shell.png'), scale: 'css' });
  expect(await visibleColorCount(page, png)).toBeGreaterThan(20);
  const bounds = await metrics(page), scale = uiScale(bounds), collection = collectionBounds(bounds);
  const columns = collection.width * scale >= 720 ? 3 : 2;
  const cardWidth = (collection.width - (columns - 1) * collection.gap) / columns;
  const wide = cardWidth * scale >= 240, artSide = (wide ? 72 : 56) / scale;
  const artX = target.x - cardWidth / 2 + (wide ? 16 / scale
    : 12 / scale + (cardWidth - 72 / scale - artSide) / 2);
  const artY = target.y - 64 / scale + (wide ? 28 : 8) / scale;
  const artClip = { x: bounds.x + artX * bounds.scale, y: bounds.y + artY * bounds.scale,
    width: artSide * bounds.scale, height: artSide * bounds.scale };
  const width = Math.min(collection.width, bounds.width - 24), height = 120 / scale;
  const strip = { x: bounds.x + collection.x * bounds.scale,
    y: bounds.y + (bounds.height - collection.padding - height) * bounds.scale,
    width: width * bounds.scale, height: height * bounds.scale };
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  await recordPressFrames(page, artClip);
  await page.keyboard.press('Enter');
  const capture = await page.evaluate(async () => {
    const result = await window.pipPressFrames;
    delete window.pipPressFrames;
    return result;
  });
  expect(capture.frames.every(frame => frame.visible > 0), 'Each animation sample contains a rendered canvas.').toBe(true);
  expect(new Set(capture.frames.map(frame => frame.hash)).size,
    'An accepted card click visibly animates its illustration.').toBeGreaterThan(1);
  expect(capture.frames.slice(-3).map(frame => frame.hash),
    'The illustration returns to its unchanged resting position.').toEqual(Array(3).fill(capture.frames[0].hash));
  if (capture.image) fs.writeFileSync(testInfo.outputPath('toy-card-press.png'), Buffer.from(capture.image.split(',')[1], 'base64'));
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  const still = await page.screenshot({ clip: strip, scale: 'css' });
  await page.keyboard.press('Enter');
  await rendered(page);
  expect((await page.screenshot({ clip: strip, scale: 'css' })).equals(still),
    'Reduced motion keeps a repeatedly previewed card visually still.').toBe(true);
  for (const [index, name] of ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].entries()) {
    const rect = worldIconRect(await metrics(page), index);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await rendered(page);
    await page.screenshot({ path: testInfo.outputPath(`toy-cards-${name}.png`), scale: 'css' });
  }
  expect(await page.evaluate(key => localStorage.getItem(key), ROOM_KEY)).toContain('toy="toy-spring"');
  expect(errors).toEqual([]);
});
