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

test('loading, theme selection and speech diagnostics retain their scroll navigation', () => {
  const source = read('shell.html');
  for (const selector of ['status', 'speech-transcript', 'speech-notice', 'speech-debug']) {
    const declaration = source.match(new RegExp(`#${selector}\\s*\\{([^}]+)\\}`))?.[1];
    assert.ok(declaration, `Missing ${selector} styling`);
    assert.match(declaration, /overflow:\s*auto\s*;/, `${selector} remains scrollable`);
  }
  const rail = source.match(/#loading-theme-options\s*\{([^}]+)\}/)?.[1];
  assert.match(rail, /overflow-x:\s*auto\s*;/);
  assert.match(rail, /touch-action:\s*pan-x pinch-zoom\s*;/);
  assert.match(source, /ArrowLeft:[\s\S]*?ArrowRight:[\s\S]*?Home:\s*0,\s*End:/,
    'The theme rail retains keyboard access to offscreen choices');
});

test('art credits retain document scrolling and visible keyboard focus', () => {
  const source = read('map-credits.html');
  assert.doesNotMatch(source, /overflow(?:-[xy])?:\s*(?:hidden|clip)\b/);
  assert.match(source, /a:focus-visible\s*\{[^}]*outline:/);
});
