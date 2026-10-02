const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { enterGame, metrics, tap, openRewards, rendered, visibleColorCount,
  leaderboardSnapshot: snapshot, leaderboardControl: control,
  activateLeaderboardControl: activate } = require('./game-ui.cjs');

const STORAGE_KEY = 'wordBuddies.leaderboards';
const NAME = 'Zoë';

test.afterEach(async ({ page }, info) => {
  if (info.status === info.expectedStatus || page.isClosed()) return;
  const diagnostics = await page.evaluate(() => {
    const summarize = element => {
      const style = getComputedStyle(element), rect = element.getBoundingClientRect();
      return { tag: element.tagName, id: element.id, className: element.className,
        focused: document.activeElement === element, disabled: element.disabled,
        readOnly: element.readOnly, value: element.value, display: style.display,
        visibility: style.visibility, fontSize: style.fontSize,
        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
    };
    const canvas = document.getElementById('canvas');
    return { viewport: { width: innerWidth, height: innerHeight, deviceScaleFactor: devicePixelRatio,
      visual: window.visualViewport ? { width: visualViewport.width, height: visualViewport.height,
        scale: visualViewport.scale, offsetTop: visualViewport.offsetTop } : null },
      activeElement: document.activeElement ? summarize(document.activeElement) : null,
      editors: [...document.querySelectorAll('input, textarea')].map(summarize),
      canvas: canvas ? { ...summarize(canvas), backingWidth: canvas.width, backingHeight: canvas.height } : null,
      playerState: document.getElementById('leaderboard-status')?.dataset.snapshot || '' };
  }).catch(error => ({ captureError: error.message }));
  await info.attach('player-name-keyboard-state', {
    body: JSON.stringify(diagnostics, null, 2), contentType: 'application/json'
  });
});

async function touchName(page) {
  const item = await control(page, 'LeaderboardName');
  const bounds = await metrics(page);
  const [x, y, width, height] = item.rect;
  expect(y, 'The name field is visible without simulated keyboard navigation').toBeGreaterThanOrEqual(0);
  expect(y + height).toBeLessThanOrEqual(bounds.height + 1);
  const scaleBefore = await page.evaluate(() => window.visualViewport?.scale ?? 1);
  await tap(page, x + width / 2, y + height / 2);
  // Typing into the canvas can pass even with the exported mobile keyboard
  // disabled. A real editable DOM element must receive focus after the touch.
  const editor = page.locator('input:focus, textarea:focus');
  await expect(editor, 'A touch opens the engine native text-entry bridge').toHaveCount(1);
  await expect(editor).toBeEditable();
  await expect(editor).toBeVisible();
  expect(await editor.evaluate(element => element.disabled || element.readOnly)).toBe(false);
  expect(await editor.evaluate(element => parseFloat(getComputedStyle(element).fontSize)),
    'The real DOM editor meets the 16 CSS-pixel threshold that prevents iOS focus zoom').toBeGreaterThanOrEqual(16);
  await expect.poll(() => page.evaluate(() => window.visualViewport?.scale ?? 1),
    { message: 'Focusing the player name preserves the page zoom' }).toBeCloseTo(scaleBefore, 3);
  return editor;
}

async function commitComposedName(editor) {
  // Mobile IMEs update the DOM value through composition/input events rather
  // than canvas keydown events. The composed spelling must reach Godot intact.
  await editor.evaluate(element => {
    element.value = 'Zo';
    element.setSelectionRange(2, 2);
    element.dispatchEvent(new InputEvent('input', {
      bubbles: true, data: 'Zo', inputType: 'insertText'
    }));
    element.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true, data: '' }));
    element.dispatchEvent(new CompositionEvent('compositionupdate', { bubbles: true, data: 'ë' }));
    element.value = 'Zoë';
    element.setSelectionRange(3, 3);
    element.dispatchEvent(new InputEvent('input', {
      bubbles: true, data: 'ë', inputType: 'insertCompositionText', isComposing: true
    }));
    element.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true, data: 'ë' }));
    element.dispatchEvent(new InputEvent('input', {
      bubbles: true, data: 'ë', inputType: 'insertText', isComposing: false
    }));
  });
}

async function expectKeyboardDismissed(page) {
  await expect(page.locator('input:focus, textarea:focus'), 'Closed forms release the browser text-input focus').toHaveCount(0);
  await expect.poll(() => page.locator('input, textarea').evaluateAll(elements => elements.some(element =>
    !element.disabled && getComputedStyle(element).display !== 'none')),
  { message: 'No editable mobile keyboard bridge remains active behind the game' }).toBe(false);
}

async function expectGameFocus(page, name) {
  await expect.poll(async () => (await snapshot(page)).controls.find(item => item.focused)?.name || '',
    { message: `Keyboard navigation reaches ${name} inside the game` }).toBe(name);
}

test('touch opens the native player-name editor, accepts IME input and dismisses it on save or close', async ({ page }, info) => {
  // Software-rendered touch devices need time for repeated modal transitions.
  test.setTimeout(300000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const response = await page.goto('/');
  expect(await response.text(), 'The delivered engine configuration enables its mobile keyboard').toMatch(/"experimentalVK"\s*:\s*true/);
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  const editor = await touchName(page);
  await commitComposedName(editor);
  await expect.poll(async () => (await control(page, 'LeaderboardCreatePlayer')).disabled,
    { message: 'Native input events enable profile creation without a canvas key event' }).toBe(false);
  await page.screenshot({ path: info.outputPath('mobile-name-native-editor.png') });

  // Send keys to the actual focused element. locator.press() would first focus
  // its target and hide a regression where the native editor traps navigation.
  await page.keyboard.press('Tab');
  await expectGameFocus(page, 'LeaderboardCreatePlayer');
  await expectKeyboardDismissed(page);
  await page.keyboard.press('Shift+Tab');
  await expectGameFocus(page, 'LeaderboardName');
  await expectKeyboardDismissed(page);
  await touchName(page);
  await page.keyboard.press('Shift+Tab');
  await expectGameFocus(page, 'LeaderboardAvatar_rabbit');
  await expectKeyboardDismissed(page);
  await touchName(page);
  await page.keyboard.press('Escape');
  await expectKeyboardDismissed(page);
  expect((await snapshot(page)).view, 'Dismissing the keyboard does not bypass required player creation').toBe('onboarding');
  await expect(await touchName(page), 'Keyboard navigation preserves the composed player name').toHaveValue(NAME);

  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expectKeyboardDismissed(page);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toContain(NAME);

  await openRewards(page);
  await activate(page, 'MenuPlayers');
  expect((await snapshot(page)).profiles.map(profile => profile.name)).toEqual([NAME]);
  const nextEditor = await touchName(page);
  await expect(nextEditor).toHaveValue('');
  await nextEditor.evaluate(element => {
    element.value = 'Unsaved player';
    element.setSelectionRange(element.value.length, element.value.length);
    element.dispatchEvent(new InputEvent('input', { bubbles: true, data: element.value, inputType: 'insertText' }));
  });
  await expect.poll(async () => (await control(page, 'LeaderboardCreatePlayer')).disabled).toBe(false);
  await activate(page, 'LeaderboardClose');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expectKeyboardDismissed(page);
  await activate(page, 'MenuPlayers');
  const reopenedEditor = await touchName(page);
  await expect(reopenedEditor, 'Reopening a dismissed form cannot restore stale native input').toHaveValue('');
  expect((await snapshot(page)).profiles.map(profile => profile.name)).toEqual([NAME]);
  await activate(page, 'LeaderboardClose');
  await expectKeyboardDismissed(page);
  expect(errors).toEqual([]);
});

test('a dismissed player-name keyboard reopens on the next touch without losing the draft', async ({ page }, info) => {
  test.setTimeout(300000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  let editor = await touchName(page);
  await commitComposedName(editor);
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(NAME);

  async function dismissAndReopen(expectedName) {
    // Android may hide its keyboard while retaining native DOM focus. Exercise
    // another real field touch in that state before the separate blur path.
    // Browser automation can verify the live editor, not OS keyboard visibility.
    await expect(editor).toBeFocused();
    editor = await touchName(page);
    await expect(editor, 'Retapping the focused name field keeps its draft editable').toHaveValue(expectedName);
    // A phone can close its keyboard without sending Escape or moving Godot's
    // canvas focus. Blur only the native bridge so the next real field touch
    // must recover from that stale editing session itself.
    await editor.evaluate(element => element.blur());
    await expectKeyboardDismissed(page);
    expect((await control(page, 'LeaderboardName')).text,
      'Dismissing the native keyboard preserves the current name draft').toBe(expectedName);
    editor = await touchName(page);
    await expect(editor, 'The next touch reopens the native editor with the existing draft').toHaveValue(expectedName);
  }

  for (let cycle = 0; cycle < 3; cycle++) {
    await dismissAndReopen(NAME);
    expect((await snapshot(page)).view,
      'Keyboard dismissal and reopening keep the required creation form open').toBe('onboarding');
  }
  await page.screenshot({ path: info.outputPath('onboarding-keyboard-reopened.png') });
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expectKeyboardDismissed(page);

  await openRewards(page);
  await activate(page, 'MenuPlayers');
  const profiles = (await snapshot(page)).profiles;
  expect(profiles).toHaveLength(1);
  expect(profiles[0].name).toBe(NAME);
  await activate(page, `LeaderboardEdit_${profiles[0].id}`);
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe(profiles[0].id);
  editor = await touchName(page);
  await expect(editor).toHaveValue(NAME);
  await dismissAndReopen(NAME);

  // Verify that a recovered native editor still forwards composition and later
  // text input, rather than merely looking focused with a disconnected value.
  await commitComposedName(editor);
  await editor.evaluate(element => {
    element.value += ' Moon';
    element.setSelectionRange(element.value.length, element.value.length);
    element.dispatchEvent(new InputEvent('input', {
      bubbles: true, data: ' Moon', inputType: 'insertText'
    }));
  });
  const renamed = `${NAME} Moon`;
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(renamed);
  for (let cycle = 0; cycle < 2; cycle++) await dismissAndReopen(renamed);
  await page.screenshot({ path: info.outputPath('edit-keyboard-reopened.png') });
  await activate(page, 'LeaderboardSavePlayer');
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('');
  await expectKeyboardDismissed(page);
  expect((await snapshot(page)).profiles).toEqual([{ ...profiles[0], name: renamed }]);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toContain(renamed);
  expect(errors).toEqual([]);
});

test('player-name editing survives keyboard viewport changes and reopens after dismissal', async ({ page }, info) => {
  test.setTimeout(300000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  const fullViewport = { width: 390, height: 844 };
  const keyboardViewport = { width: 390, height: 350 };
  await page.setViewportSize(fullViewport);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  let editor = await touchName(page);
  await commitComposedName(editor);
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(NAME);

  async function resizeViewport(viewport) {
    await page.setViewportSize(viewport);
    await expect.poll(async () => {
      const bounds = await metrics(page);
      return { width: Math.round(bounds.width * bounds.scale), height: Math.round(bounds.height * bounds.scale) };
    }, { message: 'The game canvas follows the available phone viewport' }).toEqual(viewport);
    // Include deferred engine layout frames: merely checking the DOM viewport
    // can miss a form rebuild that drops native focus on the following frame.
    await rendered(page);
    await rendered(page);
  }

  async function shrinkDismissAndReopen(expectedName) {
    // Some mobile browsers resize the page when the keyboard opens. A smaller
    // viewport must not dismiss the editor that caused that resize.
    await resizeViewport(keyboardViewport);
    await expect(editor, 'The native editor keeps focus while its keyboard changes the viewport').toHaveCount(1);
    await expect(editor).toBeEditable();
    await expect(editor).toHaveValue(expectedName);
    expect((await control(page, 'LeaderboardName')).text).toBe(expectedName);

    // Model keyboard dismissal separately from viewport recovery. No Escape,
    // Tab, or canvas focus is sent before the user touches the name again.
    await editor.evaluate(element => element.blur());
    await expectKeyboardDismissed(page);
    await resizeViewport(fullViewport);
    await expectKeyboardDismissed(page);
    editor = await touchName(page);
    await expect(editor, 'The restored field reopens the native editor with its original name').toHaveValue(expectedName);
  }

  async function captureRestoredViewport(name) {
    await rendered(page);
    const png = await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
    const raw = await page.locator('#canvas').evaluate(canvas => new Promise(resolve =>
      requestAnimationFrame(() => resolve(canvas.toDataURL('image/png').split(',')[1]))));
    const canvasPng = Buffer.from(raw, 'base64');
    const canvasPath = info.outputPath(`${name}-canvas.png`);
    fs.writeFileSync(canvasPath, canvasPng);
    const pageColors = await visibleColorCount(page, png);
    const canvasColors = await visibleColorCount(page, canvasPng);
    let pageTopColors = null;
    await info.attach(`${name}-canvas`, { path: canvasPath, contentType: 'image/png' });
    const windowsWebKit = process.platform === 'win32' && info.project.use.browserName === 'webkit';
    if (canvasColors > 20 && pageColors <= 20 && windowsWebKit) {
      // A blank WebKit canvas layer can still show the native name editor over
      // its background. Require a uniform canvas region above that editor;
      // a merely low-color page is not enough to waive rendering verification.
      const viewport = page.viewportSize();
      const topPath = info.outputPath(`${name}-page-top.png`);
      const topPng = await page.screenshot({ path: topPath, scale: 'css',
        clip: { x: 0, y: 0, width: viewport.width, height: Math.floor(viewport.height / 4) } });
      pageTopColors = await visibleColorCount(page, topPng);
      await info.attach(`${name}-page-top`, { path: topPath, contentType: 'image/png' });
    }
    await info.attach(`${name}-rendering`, {
      body: JSON.stringify({ pageColors, canvasColors, pageTopColors }), contentType: 'application/json'
    });
    expect(canvasColors, `${name}: the player form still renders after viewport recovery`).toBeGreaterThan(20);
    if (windowsWebKit && pageColors <= 20 && pageTopColors === 1) {
      info.annotations.push({ type: 'rendering-limitation',
        description: `${name}: existing Windows WebKit presentation/capture limitation after resize; the composed canvas region is blank although its native editor may remain visible and the raw canvas renders. Page, uniform top crop, and raw canvas retained.` });
    } else {
      expect(pageColors, `${name}: the page shows the rendered player form`).toBeGreaterThan(20);
    }
  }

  await shrinkDismissAndReopen(NAME);
  await commitComposedName(editor);
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(NAME);
  await shrinkDismissAndReopen(NAME);
  await captureRestoredViewport('onboarding-keyboard-viewport-restored');
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expectKeyboardDismissed(page);

  await openRewards(page);
  await activate(page, 'MenuPlayers');
  const profiles = (await snapshot(page)).profiles;
  expect(profiles).toHaveLength(1);
  await activate(page, `LeaderboardEdit_${profiles[0].id}`);
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe(profiles[0].id);
  editor = await touchName(page);
  await expect(editor).toHaveValue(NAME);
  await shrinkDismissAndReopen(NAME);
  await editor.evaluate(element => {
    element.value += ' Star';
    element.setSelectionRange(element.value.length, element.value.length);
    element.dispatchEvent(new InputEvent('input', {
      bubbles: true, data: ' Star', inputType: 'insertText'
    }));
  });
  const renamed = `${NAME} Star`;
  await expect.poll(async () => (await control(page, 'LeaderboardName')).text).toBe(renamed);
  await shrinkDismissAndReopen(renamed);
  await captureRestoredViewport('edit-keyboard-viewport-restored');
  await activate(page, 'LeaderboardSavePlayer');
  await expect.poll(async () => (await snapshot(page)).editing_player).toBe('');
  await expectKeyboardDismissed(page);
  expect((await snapshot(page)).profiles).toEqual([{ ...profiles[0], name: renamed }]);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toContain(renamed);
  expect(errors).toEqual([]);
});
