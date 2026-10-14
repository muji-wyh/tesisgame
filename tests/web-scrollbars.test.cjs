const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'web', name), 'utf8');

for (const filename of ['shell.html', 'map-credits.html']) {
  test(`${filename} hides scrollbar chrome globally, including dynamic controls`, () => {
    const source = read(filename);
    const globalRule = source.match(/(?:^|\n)\s*\*\s*\{([^}]+)\}/)?.[1];
    const webkitRule = source.match(/\*::-webkit-scrollbar\s*\{([^}]+)\}/)?.[1];
    assert.ok(globalRule, 'All elements, including later-created diagnostics, receive the policy');
    assert.match(globalRule, /scrollbar-width:\s*none\s*;/);
    assert.match(globalRule, /-ms-overflow-style:\s*none\s*;/);
    assert.doesNotMatch(globalRule, /(?:overflow|touch-action)\s*:/,
      'The scrollbar policy must not disable scrolling or touch navigation');
    assert.ok(webkitRule, 'WebKit needs its native scrollbar pseudo-element rule');
    assert.match(webkitRule, /display:\s*none\s*;/);
    assert.match(webkitRule, /width:\s*0\s*;/);
    assert.match(webkitRule, /height:\s*0\s*;/);
  });
}

test('loading and speech diagnostics retain their scroll navigation', () => {
  const source = read('shell.html');
  for (const selector of ['status', 'speech-transcript', 'speech-notice', 'speech-debug']) {
    const declaration = source.match(new RegExp(`#${selector}\\s*\\{([^}]+)\\}`))?.[1];
    assert.ok(declaration, `Missing ${selector} styling`);
    assert.match(declaration, /overflow:\s*auto\s*;/, `${selector} remains scrollable`);
  }
});

test('theme choices use a four-column grid and retain scroll navigation in compact windows', () => {
  const source = read('shell.html');
  const grid = source.match(/#loading-theme-options\s*\{([^}]+)\}/)?.[1];
  assert.ok(grid, 'The default theme layout is defined');
  assert.match(grid, /display:\s*grid\s*;/);
  assert.match(grid, /grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)\s*;/);
  assert.doesNotMatch(grid, /overflow(?:-[xy])?:\s*(?:hidden|clip)\b/,
    'The default grid must not clip theme choices');
  const compact = source.match(/@media\s*\(max-height:\s*420px\)\s*and\s*\(max-width:\s*500px\)\s*\{([\s\S]*?)\n\s{4}\}/)?.[1];
  assert.ok(compact, 'Very short narrow windows have a separate theme layout');
  const rail = compact.match(/#loading-theme-options\s*\{([^}]+)\}/)?.[1];
  assert.ok(rail, 'Compact windows expose the theme row');
  assert.match(rail, /display:\s*flex\s*;/);
  assert.match(rail, /overflow-x:\s*auto\s*;/);
  assert.match(rail, /touch-action:\s*pan-x pinch-zoom\s*;/);
  assert.match(compact, /\.loading-theme\s*\{[^}]*flex:\s*0\s+0\s+auto\s*;[^}]*min-height:\s*44px\s*;/,
    'Compact choices retain usable touch targets instead of shrinking to fit');
  assert.match(source, /ArrowLeft:[\s\S]*?ArrowRight:[\s\S]*?ArrowUp:[\s\S]*?ArrowDown:[\s\S]*?Home:\s*0,\s*End:/,
    'The grid and compact row retain keyboard access to every choice');
  assert.match(source, /if\s*\(focus\)\s*button\.focus\(\{\s*preventScroll:\s*true\s*\}\);\s*revealThemeChoice\(button\);/,
    'Keyboard selection reveals offscreen choices without moving the surrounding page');
});

test('art credits retain document scrolling and visible keyboard focus', () => {
  const source = read('map-credits.html');
  assert.doesNotMatch(source, /overflow(?:-[xy])?:\s*(?:hidden|clip)\b/);
  assert.match(source, /a:focus-visible\s*\{[^}]*outline:/);
});
