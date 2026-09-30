const { test, expect } = require('@playwright/test');
const { enterGame, metrics, tap, openRewards,
  leaderboardSnapshot: snapshot, leaderboardControl: control,
  activateLeaderboardControl: activate } = require('./game-ui.cjs');

const STORAGE_KEY = 'wordBuddies.leaderboards';
const NAME = 'Zoë';

async function touchName(page) {
  const item = await control(page, 'LeaderboardName');
  const bounds = await metrics(page);
  const [x, y, width, height] = item.rect;
  expect(y, 'The name field is visible without simulated keyboard navigation').toBeGreaterThanOrEqual(0);
  expect(y + height).toBeLessThanOrEqual(bounds.height + 1);
  await tap(page, x + width / 2, y + height / 2);
  // Typing into the canvas can pass even with the exported mobile keyboard
  // disabled. A real editable DOM element must receive focus after the touch.
  const editor = page.locator('input:focus, textarea:focus');
  await expect(editor, 'A touch opens the engine native text-entry bridge').toHaveCount(1);
  await expect(editor).toBeEditable();
  await expect(editor).toBeVisible();
  expect(await editor.evaluate(element => element.disabled || element.readOnly)).toBe(false);
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
  test.setTimeout(210000);
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
