const { test, expect } = require('@playwright/test');
const { openGame, chooseMode, metrics, rendered, celebrationState } = require('./game-ui.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const room = page => page.locator('#jelly-reward-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

function inside(rect, bounds) {
  expect(rect[0]).toBeGreaterThanOrEqual(-0.1);
  expect(rect[1]).toBeGreaterThanOrEqual(-0.1);
  expect(rect[0] + rect[2]).toBeLessThanOrEqual(bounds.width + 0.1);
  expect(rect[1] + rect[3]).toBeLessThanOrEqual(bounds.height + 0.1);
}

test.use({ deviceScaleFactor: 1 });

for (const mode of ['jelly', 'word_jelly']) {
  for (const pointer of ['mouse', 'touch']) {
    test(`${mode} Finish ${pointer} settles in a dialog over its frozen board`, async ({ page }, info) => {
      test.skip(info.project.name !== 'desktop-chromium', 'Private Chromium covers explicit mouse and native touch gestures once.');
      test.setTimeout(90000);
      const viewport = pointer === 'touch' ? { width: 393, height: 852 } : { width: 1366, height: 768 };
      await page.setViewportSize(viewport);
      const errors = await openGame(page, { mode, reducedMotion: 'no-preference' });
      await expect.poll(async () => {
        const state = await jelly(page);
        return state.mode === mode && state.phase === 'playing' && state.tiles?.every(tile => tile.settled);
      }).toBe(true);
      const startingCoins = (await wallet(page)).balance;
      await page.evaluate(() => {
        const status = document.getElementById('game-status');
        window.finishSettlementFrames = [];
        const record = () => {
          const state = JSON.parse(status.dataset.jelly || '{}');
          const celebration = JSON.parse(status.dataset.celebration || '{}');
          window.finishSettlementFrames.push({ phase: state.phase, result: state.result,
            modal: state.game_over?.visible, celebration: celebration.active });
        };
        window.finishSettlementObserver = new MutationObserver(record);
        window.finishSettlementObserver.observe(status, { attributes: true });
        record();
      });
      const before = await jelly(page), bounds = await metrics(page);
      const from = center(before.finish.rect, bounds);
      const to = { x: from.x, y: from.y + before.finish.pull.threshold * bounds.scale * 1.15 };
      const session = pointer === 'touch' ? await page.context().newCDPSession(page) : null;
      const touches = point => [{ x: point.x, y: point.y, id: 0, radiusX: 6, radiusY: 6, force: 1 }];
      try {
        if (session) {
          await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: touches(from) });
          await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: touches(to) });
        } else {
          await page.mouse.move(from.x, from.y);
          await page.mouse.down();
          await page.mouse.move(to.x, to.y, { steps: 4 });
        }
        await expect.poll(async () => (await jelly(page)).finish.pull.armed).toBe(true);
        expect((await jelly(page)).phase, 'An armed pull waits for release').toBe('playing');
      } finally {
        if (session) {
          await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await session.detach();
        } else await page.mouse.up();
      }
      await expect.poll(async () => (await room(page)).visible,
        { message: 'Releasing Finish immediately presents the settlement dialog' }).toBe(true);
      const ended = await jelly(page), settlement = await room(page);
      expect(ended.phase).toBe('finished');
      expect(ended.round_id).toBe(before.round_id);
      expect(ended.result, 'The standalone result page is retired').toEqual({ visible: false, retired: true });
      expect(ended.game_over).toMatchObject({ visible: true, title: 'Round complete' });
      expect(ended.finish_confirmation.visible, 'A deliberate pull needs no second confirmation').toBe(false);
      expect(ended.preview.enabled, 'The frozen board cannot release more jelly').toBe(false);
      expect(ended.danger.active).toBe(false);
      expect((await celebrationState(page)).active, 'No celebration postpones settlement').toBe(false);
      expect(settlement).toMatchObject({ heading: 'Round complete', visible: true, chest_count: 0,
        scroll_max: 0, score_text: '0', empty_result: true, save_failed: false });
      expect(settlement.result_context).toMatchObject({ reason: 'finished', score: 0, fragment_count: 0, chest_count: 0 });
      expect((await wallet(page)).balance).toBe(startingCoins);
      inside(ended.game_over.panel_rect, bounds);
      const actions = settlement.actions.filter(action => action.visible);
      expect(actions.map(action => action.text).sort()).toEqual(['Home', 'Play again']);
      for (const action of actions) {
        inside(action.rect, bounds);
        expect(action.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43.75);
      }
      const click = async point => {
        if (pointer === 'touch') await page.touchscreen.tap(point.x, point.y);
        else await page.mouse.click(point.x, point.y);
      };
      await click({ x: bounds.x + 3, y: bounds.y + 3 });
      await rendered(page);
      const frozen = await jelly(page);
      expect(frozen.game_over.visible, 'The shade cannot dismiss an ended round').toBe(true);
      expect(frozen.tiles.map(tile => tile.id)).toEqual(ended.tiles.map(tile => tile.id));
      expect(frozen.score).toBe(ended.score);
      expect(frozen.generated_tiles).toBe(ended.generated_tiles);
      const frames = await page.evaluate(() => {
        window.finishSettlementObserver.disconnect();
        return window.finishSettlementFrames;
      });
      expect(frames.every(frame => !frame.result?.visible && !frame.celebration),
        'Neither a standalone result page nor a celebration flashes during the transition').toBe(true);
      await info.attach('finish-settlement-state.json', {
        body: JSON.stringify({ mode, pointer, viewport, ended, settlement, frames }, null, 2), contentType: 'application/json'
      });
      await page.screenshot({ path: info.outputPath(`${mode}-${pointer}-finish-settlement.png`), scale: 'css' });
      const action = actions.find(item => item.text === (pointer === 'touch' ? 'Home' : 'Play again'));
      await click(center(action.rect, await metrics(page)));
      if (pointer === 'touch') {
        await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
        expect((await room(page)).visible).toBe(false);
        await chooseMode(page, mode);
        await expect.poll(async () => (await room(page)).visible).toBe(true);
        expect((await jelly(page)).round_id, 'Returning from Home preserves the settled round').toBe(ended.round_id);
        const replay = (await room(page)).actions.find(item => item.text === 'Play again');
        await click(center(replay.rect, await metrics(page)));
      }
      await expect.poll(async () => {
        const state = await jelly(page);
        return state.phase === 'playing' && state.round_id !== ended.round_id && !state.game_over.visible;
      }, { message: 'The modal action leads to a fresh playable round without the retired result page' }).toBe(true);
      expect((await wallet(page)).balance, 'Empty settlement never creates coins').toBe(startingCoins);
      expect(errors).toEqual([]);
    });
  }
}
