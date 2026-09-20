const { test, expect } = require('@playwright/test');
const {
  THEME_IDS, THEME_COLORS, metrics, tap, rendered, openGame, enterGame,
  chooseTheme, openRewards, chooseRewardSection, collectionHeaderRect,
  contentBounds, discoverMatchCards, boardPoint, resultPoint, visibleColorCount
} = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const OLD_COUNTS = { 'spring-1': 3, 'summer-2': 1, 'autumn-6': 2 };

async function record(page, key = ROOM_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

async function counts(page) {
  const dictionary = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return Object.fromEntries([...dictionary.matchAll(/"([^"]+)":\s*(\d+)/g)]
    .map(([, id, amount]) => [id, Number(amount)]));
}

async function seedPriorSave(page) {
  const medals = `[medals]\nversion=1\ncounts=${JSON.stringify(OLD_COUNTS)}\n`;
  const room = '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite="spring-1"\n\n' +
    '[journey]\nrecent_topic_ids=[]\npreferred_theme_id="spring"\ngoal_item_id=""\n\n' +
    '[stickers]\nword_ids=["cat","apple"]\ndisplay_word_id=""\n\n[learning]\nage_band="4-6"\n';
  await page.addInitScript(({ medals, room, medalKey, roomKey }) => {
    // Existing progress is the fixture. The new piece must come from a real win
    // and hold gesture; reloading never overwrites the player's current save.
    if (localStorage.getItem(medalKey) === null) localStorage.setItem(medalKey, medals);
    if (localStorage.getItem(roomKey) === null) localStorage.setItem(roomKey, room);
  }, { medals, room, medalKey: MEDAL_KEY, roomKey: ROOM_KEY });
}

async function winMatch(page) {
  const bounds = await metrics(page), cards = await discoverMatchCards(page);
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]
  ).filter(([, picture]) => picture);
  expect(pairs).toHaveLength(3);
  for (const [index, [word, picture]] of pairs.entries()) {
    const written = boardPoint(bounds, word.index), pictured = boardPoint(bounds, picture.index);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word.word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
}

function sceneryClip(bounds) {
  const content = contentBounds(bounds);
  // Results omit the mode row. This left-edge patch fits all three configured
  // devices, below the theme badge and outside the central chest artwork. Keep
  // the crop independent of title wrapping and the result's changing height.
  return {
    x: Math.round(bounds.x + (content.x + 8) * bounds.scale),
    y: Math.round(bounds.y + (content.padding + content.header + content.gap + 56) * bounds.scale),
    width: Math.round(42 * bounds.scale),
    height: Math.round(60 * bounds.scale)
  };
}

async function captureStage(page, testInfo, theme, phase) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const clip = sceneryClip(await metrics(page));
  const edge = await page.screenshot({ path: testInfo.outputPath(`treasure-${phase}-${theme}-scenery.png`), clip, scale: 'css' });
  await page.waitForTimeout(180);
  expect((await page.screenshot({ clip, scale: 'css' })).equals(edge),
    `${phase}/${theme}: reduced-motion scenery is settled before comparison.`).toBe(true);
  const full = await page.screenshot({ path: testInfo.outputPath(`treasure-${phase}-${theme}.png`), fullPage: true, scale: 'css' });
  expect(await visibleColorCount(page, full), `${phase}/${theme}: evidence contains the rendered game.`).toBeGreaterThan(20);
  // The full screenshots retain the theme badge, distinctive scenery, chest,
  // medal and review controls for visual inspection at each real device size.
  return { theme, png: edge.toString('base64') };
}

async function compareScenery(page, testInfo, phase, samples) {
  const comparisons = await page.evaluate(async sources => {
    const images = await Promise.all(sources.map(async ({ theme, png }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${png}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return { theme, width: image.width, height: image.height,
        pixels: context.getImageData(0, 0, image.width, image.height).data };
    }));
    const results = [];
    for (let first = 0; first < images.length; first++) for (let second = first + 1; second < images.length; second++) {
      const a = images[first], b = images[second];
      if (a.width !== b.width || a.height !== b.height) throw new Error('Scenery crops must have matching dimensions.');
      let changed = 0, difference = 0;
      for (let offset = 0; offset < a.pixels.length; offset += 4) {
        const delta = [0, 1, 2].map(channel => Math.abs(a.pixels[offset + channel] - b.pixels[offset + channel]));
        if (Math.max(...delta) > 8) changed++;
        difference += delta.reduce((total, value) => total + value, 0) / 3;
      }
      const pixels = a.width * a.height;
      results.push({ pair: `${a.theme} / ${b.theme}`, changedFraction: changed / pixels, meanDifference: difference / pixels });
    }
    return results;
  }, samples);
  await testInfo.attach(`treasure-${phase}-visible-scenery-comparisons`, {
    body: JSON.stringify(comparisons, null, 2), contentType: 'application/json'
  });
  expect(comparisons).toHaveLength(28);
  for (const comparison of comparisons) {
    // These are actual pixels inside the stage, excluding the browser tint,
    // header mascot and changing label. Full screenshots cover motif quality;
    // this broad check catches a stale or identical scene after a world switch.
    expect(comparison.changedFraction, `${phase}/${comparison.pair}: the visible scenery changes.`).toBeGreaterThan(0.1);
    expect(comparison.meanDifference, `${phase}/${comparison.pair}: the change is larger than raster noise.`).toBeGreaterThan(2);
  }
}

async function closeRewards(page) {
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).not.toContainText('My rewards opened.');
  await rendered(page);
}

function persistentFields(saved) {
  return Object.fromEntries(['toy', 'backdrop', 'favorite', 'preferred_theme_id', 'goal_item_id',
    'word_ids', 'display_word_id', 'age_band'].map(field => [field, saved.match(new RegExp(`^${field}=(.*)$`, 'm'))?.[1]]));
}

test('all eight treasure stages follow the selected world while a real chest claim keeps its earned medal after navigation and reload', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  // Preserve each project's desktop, iPhone and iPad dimensions.
  await seedPriorSave(page);
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  expect(await counts(page)).toEqual(OLD_COUNTS);
  await winMatch(page);
  const beforeClaim = await record(page, MEDAL_KEY);
  expect(await counts(page), 'Winning alone does not claim the chest.').toEqual(OLD_COUNTS);

  const closed = [];
  for (const [index, theme] of THEME_IDS.entries()) {
    await chooseTheme(page, index);
    await expect(page.locator('#game-status')).toContainText('You did it!');
    expect(await record(page)).toContain(`preferred_theme_id="${theme}"`);
    expect(await record(page, MEDAL_KEY), `${theme}: browsing closed stages never awards a piece.`).toBe(beforeClaim);
    closed.push(await captureStage(page, testInfo, theme, 'closed'));
  }
  await compareScenery(page, testInfo, 'closed', closed);

  // Candy is selected when opening begins. reward_theme belongs to this claim,
  // not to the earlier winning world or a later decorative world selection.
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toContainText('Here comes your surprise!');
    await page.waitForTimeout(450);
    await page.screenshot({ path: testInfo.outputPath('treasure-opening-candy.png'), scale: 'css' });
    await expect(page.locator('#game-status')).toContainText('A new piece!');
    await expect(page.locator('#game-status')).toContainText('Party Cake');
    await expect(page.locator('#game-status')).toContainText('Piece 1 of 3');
  } finally {
    await page.mouse.up();
  }
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  const earnedCounts = { ...OLD_COUNTS, 'candy-1': 1 };
  expect(await counts(page), 'The real hold awards exactly one Candy piece and preserves previous medals.').toEqual(earnedCounts);
  const earnedSave = await record(page, MEDAL_KEY);
  const opened = [];
  // End on Jungle so the saved current world differs from the Candy reward.
  for (const index of [7, 0, 1, 2, 3, 4, 5, 6]) {
    const theme = THEME_IDS[index];
    await chooseTheme(page, index);
    await expect(page.locator('#game-status')).toContainText('A new piece!');
    await expect(page.locator('#game-status')).toContainText('Party Cake');
    await expect(page.locator('#game-status')).toContainText('Piece 1 of 3');
    expect(await record(page)).toContain(`preferred_theme_id="${theme}"`);
    expect(await record(page, MEDAL_KEY), `${theme}: changing the open stage never moves or duplicates its Candy piece.`).toBe(earnedSave);
    opened.push(await captureStage(page, testInfo, theme, 'opened'));
  }
  await compareScenery(page, testInfo, 'opened', opened);

  await openRewards(page);
  await chooseRewardSection(page, 'medals');
  await closeRewards(page);
  await expect(page.locator('#game-status')).toContainText('Party Cake');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[6]);
  expect(await record(page, MEDAL_KEY)).toBe(earnedSave);
  const savedRoom = persistentFields(await record(page));
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[6]);
  expect(await counts(page), 'Reload keeps the earned Candy piece while the chosen world remains Jungle.').toEqual(earnedCounts);
  expect(persistentFields(await record(page)), 'Reload preserves owned items, chosen world, stickers and learning settings.').toEqual(savedRoom);
  await openRewards(page);
  await chooseRewardSection(page, 'medals');
  await page.screenshot({ path: testInfo.outputPath('treasure-jungle-reloaded-medals.png'), fullPage: true, scale: 'css' });
  expect(await record(page, MEDAL_KEY)).toBe(earnedSave);
  expect(errors).toEqual([]);
});
