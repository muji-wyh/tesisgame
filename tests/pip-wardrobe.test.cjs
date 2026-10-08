const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { THEMES, EXPRESSIONS, readSources, buildExpressionSheet, buildOutfits } = require('../tools/generate-pip-outfits.cjs');
const { inlineMascot } = require('../tools/prepare-godot.cjs');
const root = path.resolve(__dirname, '..');

test('all shipped Pip sheets reproduce exactly from their editable wardrobe designs', () => {
  const built = buildOutfits(readSources(root));
  assert.equal(Object.keys(built).length, 40);
  for (const [name, svg] of Object.entries(built)) {
    assert.equal(fs.readFileSync(path.join(root, 'assets/images/mascots/outfits', name), 'utf8').replaceAll('\r\n', '\n'), svg, name);
  }
});

test('full expression poses reproduce their original bodies and retain the head atlas frame order', () => {
  const sources = readSources(root);
  const full = buildExpressionSheet(sources);
  assert.equal(fs.readFileSync(path.join(root, 'assets/images/mascots/pip-expressions.svg'), 'utf8').replaceAll('\r\n', '\n'), full);
  assert.deepEqual(EXPRESSIONS, ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink']);
  assert.deepEqual([...sources.expressionHeads.matchAll(/id="pip-face-([^"]+)"/g)].map(match => match[1]), EXPRESSIONS);
  assert.deepEqual([...full.matchAll(/id="pip-expression-([^"]+)"/g)].map(match => match[1]), EXPRESSIONS);
  for (const svg of [sources.expressionHeads, full]) {
    assert.match(svg, /width="1200" height="120" viewBox="0 0 1200 120"/);
    assert.equal((svg.match(/d="M23 39Q21 12 54 13/g) || []).length, EXPRESSIONS.length, 'Every face keeps the original Pip head contour');
  }
  assert.equal((full.match(/fill="#F6D36E"/g) || []).length, EXPRESSIONS.length, 'Every pose keeps one resting body');
  assert.equal((full.match(/M86 74Q97 62 100 48/g) || []).length, 3, 'Delighted, proud and wink poses keep the original raised greeting wing');
  assert.equal((sources.expressionHeads.match(/fill="#F6D36E"/g) || []).length, 0, 'Articulated heads contain no duplicated bodies');
  assert.throws(() => buildExpressionSheet({ ...sources, expressionHeads: sources.expressionHeads.replace('id="pip-face-neutral"', 'id="pip-face-listening"') }), /frame order/);
});

test('every expression has both a clothed full pose and a matching clothed head in each world', () => {
  const built = buildOutfits(readSources(root));
  for (const theme of THEMES) {
    const full = built[`pip-${theme}-expressions.svg`];
    const heads = built[`pip-${theme}-expression-heads.svg`];
    for (const svg of [full, heads]) {
      assert.match(svg, /width="1200" height="120" viewBox="0 0 1200 120"/);
      for (const expression of EXPRESSIONS) assert.ok(svg.includes(`id="pip-${svg === heads ? 'face' : 'expression'}-${expression}"`));
      assert.equal((svg.match(/d="M23 39Q21 12 54 13/g) || []).length, EXPRESSIONS.length);
    }
    assert.equal((full.match(/fill="#F6D36E"/g) || []).length, EXPRESSIONS.length);
    assert.equal((heads.match(/fill="#F6D36E"/g) || []).length, 0);
  }
});

test('the loader embeds all eight costumes with complete articulated limbs and matching speech art', () => {
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web/shell.html'), 'utf8'));
  assert.doesNotMatch(shell, /\$PIP_(?:MASCOT_URI|WARDROBE_JSON)/);
  const wardrobe = JSON.parse(shell.match(/const pipWardrobe = (\{[^\r\n]+\});/)[1]);
  assert.deepEqual(Object.keys(wardrobe), THEMES);
  const heads = new Set(), bodies = new Set();
  for (const theme of THEMES) {
    const { sprite, parts } = wardrobe[theme];
    const expected = fs.readFileSync(path.join(root, 'assets/images/mascots/outfits', `pip-${theme}.svg`));
    assert.deepEqual(Buffer.from(sprite.split(',')[1], 'base64'), expected);
    assert.deepEqual(Object.keys(parts), ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot']);
    for (const markup of Object.values(parts)) {
      assert.ok(markup.length > 20);
      let depth = 0;
      for (const [tag] of markup.matchAll(/<g\b[^>]*>|<\/g>/g)) {
        depth += tag === '</g>' ? -1 : 1;
        assert.ok(depth >= 0, 'No limb may close its parent dance group');
      }
      assert.equal(depth, 0, 'Nested limb transforms must remain balanced');
      assert.doesNotMatch(markup, /translate\((?:120|240|360|480|600)\s/);
    }
    heads.add(parts.head); bodies.add(parts.body);
  }
  assert.equal(heads.size, 8);
  assert.equal(bodies.size, 8);
});
