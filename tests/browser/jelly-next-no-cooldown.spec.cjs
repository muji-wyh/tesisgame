const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, metrics } = require('./game-ui.cjs');

const snapshot = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));

test.use({ deviceScaleFactor: 1, viewport: { width: 393, height: 852 } });

for (const mode of ['jelly', 'word_jelly']) {
  for (const pointer of ['mouse', 'touch']) {
    test(`${mode} accepts consecutive Next ${pointer} clicks before the first batch lands`, async ({ page }, info) => {
      test.setTimeout(90000);
      const errors = await openGame(page, { reducedMotion: 'no-preference' });
      await openModeMenu(page);
      await chooseMode(page, mode);
      await expect.poll(async () => {
        const state = await snapshot(page);
        return state.visible && state.phase === 'playing' && state.preview?.enabled;
      }).toBe(true);
      const before = await snapshot(page), bounds = await metrics(page);
      const batchSize = mode === 'jelly' ? 4 : 5;
      const firstIds = before.upcoming.map(tile => tile.id);
      const [x, y, width, height] = before.preview.rect;
      const point = { x: bounds.x + (x + width / 2) * bounds.scale,
        y: bounds.y + (y + height / 2) * bounds.scale };
      await page.evaluate(({ firstIds, point, pointer }) => {
        const status = document.getElementById('game-status');
        window.nextClickEvidence = { events: [], frames: [] };
        const read = () => {
          const state = JSON.parse(status.dataset.jelly || '{}');
          return { at: performance.now(), generated: state.generated_tiles,
            enabled: state.preview?.enabled, disabled: state.preview?.control?.disabled,
            firstAirborne: firstIds.filter(id => state.tiles?.some(tile => tile.id === id && !tile.settled)),
            tiles: state.tiles?.map(tile => ({ id: tile.id, age: tile.age, settled: tile.settled, rect: tile.rect })) };
        };
        const record = event => {
          const contact = event.changedTouches?.[0] || event;
          if (Math.abs(contact.clientX - point.x) > 2 || Math.abs(contact.clientY - point.y) > 2) return;
          window.nextClickEvidence.events.push({ type: event.type, trusted: event.isTrusted, ...read() });
        };
        for (const type of pointer === 'touch' ? ['touchstart', 'touchend'] : ['pointerdown', 'pointerup']) {
          window.addEventListener(type, record, { capture: true, passive: true });
        }
        window.nextClickObserver = new MutationObserver(() => window.nextClickEvidence.frames.push(read()));
        window.nextClickObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
      }, { firstIds, point, pointer });
      const press = async () => {
        if (pointer === 'touch') await page.touchscreen.tap(point.x, point.y);
        else await page.mouse.click(point.x, point.y);
      };
      await press();
      await press();
      await expect.poll(async () => (await snapshot(page)).generated_tiles,
        { intervals: [30], message: 'Two actual preview gestures consume two committed packets without a cooldown' })
        .toBe(before.generated_tiles + batchSize * 2);
      const evidence = await page.evaluate(() => window.nextClickEvidence);
      await info.attach('next-click-evidence', {
        body: JSON.stringify({ mode, pointer, before: { generated: before.generated_tiles, firstIds }, evidence }, null, 2),
        contentType: 'application/json'
      });
      expect(evidence.events).toHaveLength(4);
      expect(evidence.events.every(event => event.trusted)).toBe(true);
      expect(evidence.events[2].firstAirborne.length,
        'The second press reaches the game while at least one earlier body is still falling').toBeGreaterThan(0);
      expect(evidence.events[2].enabled, 'Next stays enabled during the earlier fall').toBe(true);
      expect(evidence.frames.some(frame => frame.generated === before.generated_tiles + batchSize * 2 && frame.firstAirborne.length),
        'The second packet is committed before the previous one finishes landing').toBe(true);
      await expect.poll(async () => (await snapshot(page)).tiles.every(tile => tile.settled),
        { intervals: [50], message: 'Both accepted packets complete their natural fall' }).toBe(true);
      const after = await snapshot(page);
      expect(after.tiles).toHaveLength(before.tiles.length + batchSize * 2);
      expect(new Set(after.tiles.map(tile => tile.id)).size).toBe(after.tiles.length);
      expect(firstIds.every(id => after.tiles.some(tile => tile.id === id)),
        'A later packet never replaces or discards an earlier advertised root').toBe(true);
      expect(after.cleared_pairs).toBe(before.cleared_pairs);
      expect(after.fragment_count).toBe(before.fragment_count);
      expect(after.preview.enabled).toBe(true);
      expect(errors).toEqual([]);
      await page.screenshot({ path: info.outputPath(`${mode}-${pointer}-rapid-next.png`), scale: 'css' });
      await page.evaluate(() => window.nextClickObserver.disconnect());
    });
  }
}
