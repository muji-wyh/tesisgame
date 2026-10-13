const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);
const themeIds = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];

function themeButton(page, id) {
  return page.locator(`#loading-theme-options button[data-theme="${id}"]`);
}

async function maintainedShell(page) {
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8'))
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', `${config.executable}.js`)
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.route('**/loading-layout-test*', route => route.fulfill({ contentType: 'text/html', body: shell }));
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, route => route.fulfill({
    contentType: 'application/javascript',
    body: `window.Engine = class {
      static getMissingFeatures() { return []; }
      static load() { return Promise.resolve(); }
      startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
    };`
  }));
  await page.goto('/loading-layout-test');
}

async function expectUsableControls(page, { allVisible = true } = {}) {
  const controls = page.locator('#loading-toy, #loading-duck, #loading-theme-options button, #enter-game');
  const bounds = await controls.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    return { name: element.getAttribute('aria-label') || element.textContent.trim(),
      x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  }));
  for (const box of bounds) {
    expect(box.width, `${box.name} has a usable touch target`).toBeGreaterThanOrEqual(44);
    expect(box.height, `${box.name} has a usable touch target`).toBeGreaterThanOrEqual(44);
  }
  for (let first = 0; first < bounds.length; first++) {
    for (let second = first + 1; second < bounds.length; second++) {
      const a = bounds[first], b = bounds[second];
      const overlapX = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
      const overlapY = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
      expect(overlapX > 1 && overlapY > 1, `${a.name} must not overlap ${b.name}`).toBe(false);
    }
  }
  const overflow = await page.locator('#status').evaluate(element => ({
    horizontal: element.scrollWidth - element.clientWidth,
    vertical: element.scrollHeight - element.clientHeight
  }));
  expect(overflow.horizontal, 'The loading screen must not scroll sideways').toBeLessThanOrEqual(1);
  if (allVisible) {
    expect(overflow.vertical, 'The loading controls fit without vertical scrolling').toBeLessThanOrEqual(1);
    for (const control of await controls.all()) {
      await expect(control).toBeInViewport({ ratio: 1 });
      expect(await control.evaluate(element => {
        const rect = element.getBoundingClientRect();
        return element.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2));
      }), 'Every loading control receives pointer input at its center').toBe(true);
    }
  } else {
    for (const control of await controls.all()) {
      await control.scrollIntoViewIfNeeded();
      await expect(control).toBeInViewport({ ratio: 1 });
    }
  }
}

async function expectTransitionsStopped(page) {
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
  await expect(page.locator('#loading-duck > svg')).toHaveCSS('opacity', '1');
  const running = await page.locator('#status').evaluate(element => element.getAnimations({ subtree: true })
    .filter(animation => animation.playState === 'running' && (animation instanceof CSSTransition
      || animation.effect.getKeyframes().some(frame => Object.hasOwn(frame, 'opacity')))).length);
  expect(running, 'Palette transitions and costume fades stop when loading is interrupted').toBe(0);
}

for (const viewport of [{ width: 1473, height: 1175 }, { width: 768, height: 1024 },
  { width: 390, height: 844 }, { width: 320, height: 568 }, { width: 568, height: 320 }]) {
  test(`loading controls stay readable and reachable at ${viewport.width}x${viewport.height}`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: 'reduce', colorScheme: 'light' });
    await page.clock.install();
    await page.clock.pauseAt(new Date());
    await maintainedShell(page);
    await expect(page.locator('#loading-title')).toBeInViewport({ ratio: 1 });
    await expect(page.locator('#loading-theme-options button')).toHaveCount(8);
    await expectUsableControls(page, { allVisible: viewport.height > 320 });
    if (viewport.width === 1473) {
      const layout = await page.locator('.loader-layout').boundingBox();
      const scene = await page.locator('.toy-scene').boundingBox();
      const pip = await page.locator('#loading-duck').boundingBox();
      expect(layout.width, 'Wide screens use a substantial part of the available space').toBeGreaterThan(736);
      expect(scene.width, 'Pip and the chest grow with the available space').toBeGreaterThan(360);
      expect(pip.height, 'Pip remains prominent on a large loading screen').toBeGreaterThan(230);
    }
    for (const id of themeIds) {
      await themeButton(page, id).click();
      await expect(themeButton(page, id)).toHaveAttribute('aria-pressed', 'true');
    }
    await page.evaluate(() => wordBuddiesHost.ready());
    await page.clock.runFor(2000);
    await expect(page.locator('#enter-game')).toBeEnabled();
    await expectUsableControls(page, { allVisible: viewport.height > 320 });
    await page.screenshot({ path: testInfo.outputPath(`loading-layout-${viewport.width}x${viewport.height}.png`), scale: 'css' });
  });
}

test('automatic theme previews blend colors and Pip costumes while controls stay in place', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1473, height: 1175 });
  await page.emulateMedia({ reducedMotion: 'no-preference', colorScheme: 'light' });
  await maintainedShell(page);
  const result = await page.evaluate(() => new Promise(resolve => {
    const status = document.getElementById('status');
    const duck = document.getElementById('loading-duck');
    const name = document.getElementById('loading-theme-name');
    const chest = document.querySelector('#chest-art rect');
    const started = performance.now(), frames = [];
    let changedAt = null;
    function snapshot() {
      const incoming = duck.querySelector('svg:not(.loading-pip-outgoing)');
      const outgoing = duck.querySelector('.loading-pip-outgoing');
      const bounds = ['loading-theme-options', 'enter-game'].map(id => {
        const rect = document.getElementById(id).getBoundingClientRect();
        return [rect.x, rect.y, rect.width, rect.height];
      });
      return { background: getComputedStyle(status).backgroundColor,
        accent: getComputedStyle(name).color, chest: getComputedStyle(chest).fill,
        incoming: Number(getComputedStyle(incoming).opacity),
        outgoing: outgoing ? Number(getComputedStyle(outgoing).opacity) : 0,
        layers: duck.querySelectorAll(':scope > svg').length, bounds };
    }
    const before = snapshot();
    function sample() {
      if (status.dataset.theme === 'summer') {
        changedAt ??= performance.now();
        frames.push(snapshot());
      }
      if ((changedAt !== null && performance.now() - changedAt >= 900) || performance.now() - started > 8000) {
        resolve({ before, frames, theme: status.dataset.theme, final: snapshot() });
      } else requestAnimationFrame(sample);
    }
    requestAnimationFrame(sample);
  }));
  const evidence = testInfo.outputPath('automatic-theme-transition.json');
  fs.writeFileSync(evidence, JSON.stringify(result));
  await testInfo.attach('automatic-theme-transition.json', { path: evidence, contentType: 'application/json' });
  expect(result.theme).toBe('summer');
  expect(result.frames.length).toBeGreaterThan(3);
  for (const property of ['background', 'accent', 'chest']) {
    expect(result.before[property], `${property} changes with the theme`).not.toBe(result.final[property]);
    expect(result.frames.some(frame => frame[property] !== result.before[property]
      && frame[property] !== result.final[property]), `${property} visibly interpolates between palettes`).toBe(true);
  }
  expect(result.frames.some(frame => frame.incoming > 0 && frame.incoming < 1
    && frame.outgoing > 0 && frame.outgoing < 1), 'The old and new costumes overlap during the fade').toBe(true);
  for (const frame of result.frames) {
    expect(frame.layers, 'A transition retains at most one outgoing costume').toBeLessThanOrEqual(2);
    expect(frame.incoming + frame.outgoing, 'Pip must never disappear between costumes').toBeGreaterThan(0.8);
    for (let control = 0; control < frame.bounds.length; control++) {
      frame.bounds[control].forEach((value, component) => {
        expect(Math.abs(value - result.before.bounds[control][component]),
          'A theme preview must not move or resize its controls').toBeLessThan(1);
      });
    }
  }
  expect(result.final.incoming).toBe(1);
  expect(result.final.layers).toBe(1);
  await expect(page.locator('#loading-theme-options button[aria-pressed="true"]')).toHaveCount(1);
  await expect(themeButton(page, 'summer')).toHaveAttribute('aria-pressed', 'true');
  await themeButton(page, 'ocean').click();
  await page.locator('#status').evaluate(element => {
    for (const animation of element.getAnimations({ subtree: true })) {
      animation.pause();
      const timing = animation.effect.getTiming();
      if (timing.iterations !== Infinity) animation.currentTime = Number(timing.duration) / 2;
    }
  });
  await page.screenshot({ path: testInfo.outputPath('loading-theme-mid-transition.png'), scale: 'css' });
});

test('rapid theme choices settle on the latest costume without stale artwork or duplicate controls', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference', colorScheme: 'light' });
  await maintainedShell(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await themeButton(page, 'candy').click();
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
  const expectedCostume = await page.locator('#loading-duck [id^="loading-pip-"]').evaluateAll(
    parts => parts.map(part => ({ id: part.id, art: part.innerHTML })));
  await themeButton(page, 'spring').click();
  await page.evaluate(ids => {
    for (const id of ids) document.querySelector(`#loading-theme-options button[data-theme="${id}"]`).click();
  }, ['ocean', 'autumn', 'space', 'winter', 'candy']);
  await expect(themeButton(page, 'candy')).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-theme', 'candy');
  await expect(page.locator('#status')).toHaveAttribute('data-theme', 'candy');
  expect(await page.evaluate(() => wordBuddiesHost.loadingTheme())).toBe('candy');
  expect(await page.locator('.loading-pip-outgoing').count()).toBeLessThanOrEqual(1);
  const artwork = await page.locator('.loading-pip-outgoing').evaluate(outgoing => {
    const ids = new Set([...outgoing.querySelectorAll('[id]')].map(element => element.id));
    const references = [...outgoing.querySelectorAll('*')].flatMap(element => [...element.attributes]
      .flatMap(attribute => {
        const urls = [...attribute.value.matchAll(/url\(["']?#([^\s)"']+)["']?\)/g)].map(match => match[1]);
        return attribute.localName === 'href' && attribute.value.startsWith('#')
          ? [...urls, attribute.value.slice(1)] : urls;
      }));
    const documentIds = [...document.querySelectorAll('[id]')].map(element => element.id);
    return { unresolved: references.filter(id => !ids.has(id)), references: references.length,
      livePartIds: [...ids].filter(id => /^loading-pip-(body|head|left-wing|right-wing|left-foot|right-foot)$/.test(id)),
      duplicates: documentIds.filter((id, index) => documentIds.indexOf(id) !== index) };
  });
  expect(artwork.references, 'The outgoing costume retains its gradients and filters').toBeGreaterThan(0);
  expect(artwork.unresolved, 'Every outgoing SVG paint reference resolves within that artwork').toEqual([]);
  expect(artwork.livePartIds, 'Only the current Pip costume owns the live dance-part IDs').toEqual([]);
  expect(artwork.duplicates, 'The outgoing costume must not duplicate document IDs').toEqual([]);
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
  expect(await page.locator('#loading-duck [id^="loading-pip-"]').evaluateAll(
    parts => parts.map(part => ({ id: part.id, art: part.innerHTML })))).toEqual(expectedCostume);
  await expect(page.locator('#loading-duck > svg')).toHaveCSS('opacity', '1');
  await expect(page.locator('#loading-theme-options button')).toHaveCount(8);
  await expect(page.locator('#loading-theme-options button[aria-pressed="true"]')).toHaveCount(1);
  expect(errors).toEqual([]);
});

test('reduced motion cancels a costume fade and subsequent themes appear immediately', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference', colorScheme: 'light' });
  await maintainedShell(page);
  await themeButton(page, 'ocean').click();
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(1);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
  await themeButton(page, 'space').click();
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-theme', 'space');
  await expect(page.locator('#loading-duck > svg')).toHaveCSS('opacity', '1');
  await expect(page.locator('#status')).toHaveCSS('background-color', 'rgb(241, 237, 251)');
  await expect(page.locator('#loading-theme-name')).toHaveCSS('color', 'rgb(105, 74, 153)');
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
  expect(await page.locator('#status').evaluate(element => element.getAnimations({ subtree: true })
    .filter(animation => animation.playState === 'running').length)).toBe(0);
  await page.locator('#loading-duck').click();
  await expect(page.locator('#loading-hint')).toContainText('Pip');
  await themeButton(page, 'jungle').click();
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-theme', 'jungle');
  await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
});

for (const suspension of ['hidden page', 'page suspension']) {
  test(`an active theme fade clears during ${suspension} and resumes with a full carousel interval`, async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference', colorScheme: 'light' });
    await page.clock.install();
    await page.clock.pauseAt(new Date());
    await maintainedShell(page);
    await page.clock.fastForward(4500);
    await expect(page.locator('#status')).toHaveAttribute('data-theme', 'summer');
    await expect(page.locator('.loading-pip-outgoing')).toHaveCount(1);
    await page.evaluate(suspension => {
      if (suspension === 'hidden page') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event('visibilitychange'));
      } else window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }));
    }, suspension);
    await expectTransitionsStopped(page);
    await page.clock.fastForward(9000);
    await expect(page.locator('#status')).toHaveAttribute('data-theme', 'summer');
    await page.evaluate(suspension => {
      if (suspension === 'hidden page') {
        delete document.hidden;
        document.dispatchEvent(new Event('visibilitychange'));
      } else window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
    }, suspension);
    await page.clock.fastForward(4499);
    await expect(page.locator('#status')).toHaveAttribute('data-theme', 'summer');
    await expect(page.locator('.loading-pip-outgoing')).toHaveCount(0);
    await page.clock.fastForward(1);
    await expect(page.locator('#status')).toHaveAttribute('data-theme', 'autumn');
    await expect(page.locator('.loading-pip-outgoing')).toHaveCount(1);
  });
}

for (const endState of ['entry', 'engine failure']) {
  test(`an active theme fade leaves no artwork or transition behind after ${endState}`, async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference', colorScheme: 'light' });
    await page.clock.install();
    await page.clock.pauseAt(new Date());
    await maintainedShell(page);
    if (endState === 'entry') {
      await page.evaluate(() => {
        window.revealedThemes = [];
        wordBuddiesHost.ready(theme => revealedThemes.push(theme));
      });
      await page.clock.runFor(2000);
      await expect(page.locator('#enter-game')).toBeEnabled();
    }
    await themeButton(page, 'ocean').click();
    await expect(page.locator('.loading-pip-outgoing')).toHaveCount(1);
    if (endState === 'entry') {
      await page.locator('#enter-game').click();
      await expect(page.locator('#status')).toBeHidden();
      expect(await page.evaluate(() => revealedThemes)).toEqual(['ocean']);
    } else {
      await page.evaluate(() => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', {
        reason: new WebAssembly.RuntimeError('Theme transition test failure'), promise: Promise.resolve()
      })));
      await expect(page.locator('#status')).toHaveAttribute('data-state', 'error');
      await expect(page.locator('#retry')).toBeFocused();
    }
    await expectTransitionsStopped(page);
    await page.clock.fastForward(9000);
    await expectTransitionsStopped(page);
    expect(await page.evaluate(() => wordBuddiesHost.loadingTheme())).toBe('ocean');
  });
}
