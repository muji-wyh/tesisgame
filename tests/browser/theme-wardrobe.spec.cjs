const { test, expect } = require('@playwright/test');
const {
  THEME_IDS, THEME_COLORS, metrics, tap, rendered, openGame, chooseTheme,
  openRewards, chooseRewardSection, collectionHeaderRect, worldIconRect,
  contentBounds, pipHeaderRect, roomControl, matchWords, boardPoint, resultPoint
} = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const OLD_COUNTS = { 'spring-1': 3, 'summer-2': 1, 'autumn-6': 2 };
const VOCABULARY = new Map(require('../../words.json').map(word => [word.id, word]));

async function record(page, key = ROOM_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

async function counts(page) {
  const dictionary = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return Object.fromEntries([...dictionary.matchAll(/"([^"]+)":\s*(\d+)/g)]
    .map(([, id, amount]) => [id, Number(amount)]));
}

function cssClip(bounds, rect, padding = 0) {
  return {
    x: bounds.x + rect.x * bounds.scale - padding,
    y: bounds.y + rect.y * bounds.scale - padding,
    width: rect.width * bounds.scale + padding * 2,
    height: rect.height * bounds.scale + padding * 2
  };
}

async function closeRewards(page) {
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).not.toContainText('My rewards opened.');
  await rendered(page);
}

async function settled(page) {
  // The happy selection reaction and any short pronunciation finish before a
  // wardrobe comparison. Reduced motion then leaves the same resting pose.
  await page.mouse.move(0, 0);
  await page.waitForTimeout(1800);
  await rendered(page);
}

async function foregroundDifference(page, first, second, firstColor, secondColor) {
  return page.evaluate(async ({ sources, colors }) => {
    const pictures = await Promise.all(sources.map(async source => {
      const image = new Image();
      image.src = `data:image/png;base64,${source}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return { width: image.width, height: image.height,
        data: context.getImageData(0, 0, image.width, image.height).data };
    }));
    if (pictures[0].width !== pictures[1].width || pictures[0].height !== pictures[1].height) {
      throw new Error('Wardrobe comparison requires identically sized Pip crops.');
    }
    const backgrounds = colors.map(color => [1, 3, 5].map(start => parseInt(color.slice(start, start + 2), 16)));
    const distance = (data, offset, other) => Math.sqrt([0, 1, 2]
      .reduce((sum, channel) => sum + (data[offset + channel] - other[channel]) ** 2, 0));
    let commonForeground = 0, changed = 0;
    for (let index = 0; index < pictures[0].data.length; index += 4) {
      const a = pictures[0].data, b = pictures[1].data;
      // A different page tint must never count as a different costume. Compare
      // only pixels that belong to Pip in both images, excluding each backdrop.
      if (distance(a, index, backgrounds[0]) <= 60 || distance(b, index, backgrounds[1]) <= 60) continue;
      commonForeground++;
      if (distance(a, index, [b[index], b[index + 1], b[index + 2]]) > 55) changed++;
    }
    return { commonForeground, changed, fraction: changed / Math.max(1, commonForeground) };
  }, { sources: [first, second].map(buffer => buffer.toString('base64')), colors: [firstColor, secondColor] });
}

test('all eight theme choices give Pip different visible outfits in the header and room', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  // This tall phone frame keeps the complete room and its nine toy cards in one
  // visual artifact, without replacing the game's internal scrolling behavior.
  await page.setViewportSize({ width: 390, height: 1560 });
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  expect(THEME_IDS).toEqual(['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy']);
  expect(THEME_COLORS).toHaveLength(8);
  const originalMedals = await record(page, MEDAL_KEY);
  const originalSelection = await page.locator('#selection-status').textContent();
  const outfits = [];
  for (const [index, theme] of THEME_IDS.entries()) {
    await chooseTheme(page, index);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    expect(await record(page)).toContain(`preferred_theme_id="${theme}"`);
    await settled(page);
    const bounds = await metrics(page), content = contentBounds(bounds);
    const clip = cssClip(bounds, pipHeaderRect(bounds), 2);
    const pip = await page.screenshot({ path: testInfo.outputPath(`wardrobe-pip-${theme}.png`), clip, scale: 'css' });
    await page.waitForTimeout(180);
    expect((await page.screenshot({ clip, scale: 'css' })).equals(pip), `${theme}: the compared Pip has settled.`).toBe(true);
    outfits.push(pip);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-header-${theme}.png`), scale: 'css',
      clip: cssClip(bounds, { x: content.x, y: content.padding, width: content.width, height: content.header }) });
    await openRewards(page);
    await chooseRewardSection(page, 'room');
    await settled(page);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-room-${theme}.png`), fullPage: true, scale: 'css' });
    await closeRewards(page);
    expect(await record(page, MEDAL_KEY), 'Changing outfits never awards or removes medal pieces.').toBe(originalMedals);
    expect(await page.locator('#selection-status').textContent()).toBe(originalSelection);
  }
  const comparisons = [];
  for (let first = 0; first < outfits.length; first++) {
    for (let second = first + 1; second < outfits.length; second++) {
      const difference = await foregroundDifference(page, outfits[first], outfits[second], THEME_COLORS[first], THEME_COLORS[second]);
      const pair = `${THEME_IDS[first]} / ${THEME_IDS[second]}`;
      comparisons.push({ pair, ...difference });
      expect(difference.commonForeground, `${pair}: the crop contains the actual mascot.`).toBeGreaterThan(100);
      expect(difference.changed, `${pair}: clothing changes pixels on Pip, independent of page tint.`).toBeGreaterThan(8);
      expect(difference.fraction, `${pair}: the outfits remain visibly distinct at their real header size.`).toBeGreaterThan(0.02);
    }
  }
  await testInfo.attach('wardrobe-foreground-comparisons', {
    body: JSON.stringify(comparisons, null, 2), contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});

test('all eight theme targets fit 320 by 568 and the new choices survive touch and reload', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await openRewards(page);
  const originalMedals = await record(page, MEDAL_KEY);
  const bounds = await metrics(page), viewport = page.viewportSize();
  const targets = THEME_IDS.map((theme, index) => ({ theme, rect: cssClip(bounds, worldIconRect(bounds, index)) }));
  for (const [index, { theme, rect }] of targets.entries()) {
    expect(rect.width, `${theme}: minimum touch width`).toBeGreaterThanOrEqual(52 - 0.01);
    expect(rect.height, `${theme}: minimum touch height`).toBeGreaterThanOrEqual(52 - 0.01);
    expect(rect.x, `${theme}: left edge`).toBeGreaterThanOrEqual(0);
    expect(rect.y, `${theme}: top edge`).toBeGreaterThanOrEqual(0);
    expect(rect.x + rect.width, `${theme}: right edge`).toBeLessThanOrEqual(viewport.width + 0.01);
    expect(rect.y + rect.height, `${theme}: bottom edge`).toBeLessThanOrEqual(viewport.height + 0.01);
    for (const previous of targets.slice(0, index)) {
      const other = previous.rect;
      expect(rect.x + rect.width <= other.x + 0.01 || other.x + other.width <= rect.x + 0.01 ||
        rect.y + rect.height <= other.y + 0.01 || other.y + other.height <= rect.y + 0.01,
      `${theme} and ${previous.theme} have separate touch targets.`).toBe(true);
    }
  }
  for (const index of [6, 7, 6, 7]) {
    const world = worldIconRect(await metrics(page), index);
    await tap(page, world.x + world.width / 2, world.y + world.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    await expect(page.locator('#game-status')).toContainText('My rewards opened.');
    expect(await record(page)).toContain(`preferred_theme_id="${THEME_IDS[index]}"`);
    await rendered(page);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-${THEME_IDS[index]}-320.png`), scale: 'css' });
  }
  expect(await record(page, MEDAL_KEY)).toBe(originalMedals);
  const saved = await record(page);
  // openGame navigates to a new exported engine and selects its default Match
  // mode. It must read the saved world rather than overwrite Candy with Spring.
  const reloadErrors = await openGame(page, { reducedMotion: 'reduce' });
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[7]);
  const reloaded = await record(page);
  for (const field of ['toy', 'backdrop', 'favorite', 'preferred_theme_id', 'goal_item_id']) {
    const pattern = new RegExp(`^${field}=(.*)$`, 'm');
    expect(reloaded.match(pattern)?.[1], `Reload preserves ${field} while the fresh lesson may record a new topic visit.`)
      .toBe(saved.match(pattern)?.[1]);
  }
  expect(await record(page, MEDAL_KEY)).toBe(originalMedals);
  await settled(page);
  await page.screenshot({ path: testInfo.outputPath('wardrobe-candy-reloaded-320.png'), scale: 'css' });
  expect([...errors, ...reloadErrors]).toEqual([]);
});

async function seedGiftSaveFixture(page, world) {
  const medals = `[medals]\nversion=1\ncounts=${JSON.stringify({ ...OLD_COUNTS, [`${world}-1`]: 2 })}\n`;
  const room = '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite="spring-7"\n\n' +
    '[journey]\nrecent_topic_ids=[]\npreferred_theme_id="spring"\ngoal_item_id=""\n\n' +
    '[stickers]\nword_ids=["cat","apple"]\ndisplay_word_id=""\n\n[learning]\nage_band="4-6"\n';
  await page.addInitScript(({ medals, room, medalKey, roomKey }) => {
    // This is an explicit prior-save fixture, never an in-game reward grant.
    // A reload preserves the current saved result instead of reseeding it.
    if (localStorage.getItem(medalKey) === null) localStorage.setItem(medalKey, medals);
    if (localStorage.getItem(roomKey) === null) localStorage.setItem(roomKey, room);
  }, { medals, room, medalKey: MEDAL_KEY, roomKey: ROOM_KEY });
}

async function winGiftMatch(page) {
  const bounds = await metrics(page), cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = [...cards].filter(([, pair]) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (const [index, [word, pair]] of pairs.entries()) {
    const written = boardPoint(bounds, pair.Word), pictured = boardPoint(bounds, pair.Picture);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
}

for (const gift of [
  { world: 'jungle', word: 'monkey', name: 'Jungle monkey', medal: 'Monkey', topic: 'Animal friends', firstAction: 'Swing the monkey',
    outcomes: ['1/3 · The monkey swings through the jungle!', '2/3 · The monkey waves to Pip!', '3/3 · Pip and the monkey share a high five!'] },
  { world: 'candy', word: 'cake', name: 'Candy cake', medal: 'Party Cake', topic: 'Picnic time', firstAction: 'Set the cake',
    outcomes: ["1/3 · A cake for Pip's party!", '2/3 · A swirl of frosting on the cake!', '3/3 · Sprinkles on the cake. Ready to celebrate!'] }
]) {
  test(`${gift.world} ages 4-6 prior-save fixture earns its last toy piece through the real lesson and preserves old medals`, async ({ page }, testInfo) => {
    test.setTimeout(150000);
    await page.setViewportSize({ width: 390, height: 844 });
    await seedGiftSaveFixture(page, gift.world);
    const errors = await openGame(page, { reducedMotion: 'reduce' });
    const originalCounts = { ...OLD_COUNTS, [`${gift.world}-1`]: 2 };
    expect(await counts(page)).toEqual(originalCounts);
    await openRewards(page);
    const toy = await roomControl(page, gift.world);
    await tap(page, toy.x, toy.y);
    await expect(page.locator('#game-status')).toContainText(`${gift.name}. Complete ${gift.medal}`);
    await expect(page.locator('#game-status')).toContainText('1 more piece');
    expect(await record(page)).toContain('toy="toy-ball"');
    await page.screenshot({ path: testInfo.outputPath(`${gift.world}-locked-save-fixture.png`), scale: 'css' });
    const goal = await roomControl(page, 'goal', { locked: true, item: gift.world });
    await tap(page, goal.x, goal.y);
    await expect(page.locator('#game-status')).toContainText(`${gift.topic}. Find 3 word–picture pairs. Help Pip get ${gift.name}.`);
    expect(await record(page)).toContain(`goal_item_id="toy-${gift.world}"`);
    expect(await record(page)).toContain(`preferred_theme_id="${gift.world}"`);
    const lesson = await matchWords(page);
    expect(lesson).toContain(gift.word);
    for (const word of lesson.filter(word => word !== gift.word)) {
      expect(VOCABULARY.get(word)?.level, 'Only the explicitly chosen gift noun may exceed the selected age level.').toBe('basic');
    }
    expect(await record(page)).toContain('age_band="4-6"');
    expect(await counts(page)).toEqual(originalCounts);
    await page.screenshot({ path: testInfo.outputPath(`${gift.world}-gift-lesson.png`), scale: 'css' });
    await winGiftMatch(page);
    expect(await counts(page)).toEqual(originalCounts);
    const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
    await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
    await page.mouse.down();
    try {
      await expect(page.locator('#game-status')).toContainText('A gift for Pip!');
    } finally {
      await page.mouse.up();
    }
    const earnedCounts = { ...OLD_COUNTS, [`${gift.world}-1`]: 3 };
    expect(await counts(page), 'Only the earned new-world fragment changes; every old medal count remains intact.').toEqual(earnedCounts);
    await page.screenshot({ path: testInfo.outputPath(`${gift.world}-earned-toy.png`), scale: 'css' });
    const useGift = resultPoint(await metrics(page), 'gift');
    await tap(page, useGift.x, useGift.y);
    await expect(page.locator('#game-status')).toContainText(gift.firstAction);
    expect(await record(page)).toContain(`toy="toy-${gift.world}"`);
    await roomControl(page, 'action');
    for (const [index, outcome] of gift.outcomes.entries()) {
      await page.keyboard.press('Enter');
      await expect(page.locator('#game-status')).toHaveText(outcome);
      await rendered(page);
      await page.screenshot({ path: testInfo.outputPath(`${gift.world}-toy-stage-${index + 1}.png`), scale: 'css' });
    }
    expect(await counts(page)).toEqual(earnedCounts);
    expect(await record(page)).toContain('favorite="spring-7"');
    const reloadErrors = await openGame(page, { reducedMotion: 'reduce' });
    expect(await counts(page)).toEqual(earnedCounts);
    for (const field of [`toy="toy-${gift.world}"`, `goal_item_id="toy-${gift.world}"`, 'favorite="spring-7"', 'age_band="4-6"']) {
      expect(await record(page)).toContain(field);
    }
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[THEME_IDS.indexOf(gift.world)]);
    expect([...errors, ...reloadErrors]).toEqual([]);
  });
}
