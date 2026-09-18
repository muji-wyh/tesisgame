const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { THEMES, readSources, buildOutfits } = require('../tools/generate-pip-outfits.cjs');
const { inlineMascot } = require('../tools/prepare-godot.cjs');
const root = path.resolve(__dirname, '..');

test('all shipped Pip sheets reproduce exactly from their editable wardrobe designs', () => {
  const built = buildOutfits(readSources(root));
  assert.equal(Object.keys(built).length, 24);
  for (const [name, svg] of Object.entries(built)) {
    assert.equal(fs.readFileSync(path.join(root, 'assets/images/mascots/outfits', name), 'utf8').replaceAll('\r\n', '\n'), svg, name);
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
