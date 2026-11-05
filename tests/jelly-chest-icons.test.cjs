const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { checkJellyChestIcons, manifestPath } = require('../tools/jelly-chest-icons.cjs');

const root = path.resolve(__dirname, '..');
const original = () => JSON.parse(fs.readFileSync(path.join(root, manifestPath)));
const withManifest = manifest => ({ readFile: filename =>
  filename === path.join(root, manifestPath) ? Buffer.from(JSON.stringify(manifest)) : fs.readFileSync(filename) });

test('all 28 acquired chest portraits retain their source hashes and native crop dimensions', () => {
  const report = checkJellyChestIcons(root);
  assert.equal(report.icons, 28);
  assert(report.bytes > 0);
});

test('missing tiers, repeated identities and changed source hashes cannot pass release verification', () => {
  for (const mutate of [m => m.icons.pop(), m => { m.dependencies = m.dependencies.slice(0, 1); },
    m => { delete m.settle_frames; }, m => { m.icons[1].asset_id = m.icons[0].asset_id; },
    m => { m.icons[0].source_model.sha256 = '0'.repeat(64); }]) {
    const manifest = original();
    mutate(manifest);
    assert.throws(() => checkJellyChestIcons(root, withManifest(manifest)), /Jelly chest icon/);
  }
});

test('missing or altered portrait bytes fail without replacing source artwork', () => {
  const iconPath = path.join(root, original().icons[0].path);
  assert.throws(() => checkJellyChestIcons(root, { readFile: filename => {
    if (filename === iconPath) return Buffer.from('altered artwork');
    return fs.readFileSync(filename);
  } }), /Stale Jelly chest icon input/);
});

test('out-of-frame crops and escaping input paths fail the bake contract', () => {
  for (const mutate of [m => { m.icons[0].crop[0] = 769; },
    m => { m.dependencies[0].path = '../outside'; }]) {
    const manifest = original();
    mutate(manifest);
    assert.throws(() => checkJellyChestIcons(root, withManifest(manifest)), /Jelly chest icon/);
  }
});

test('checkout line endings preserve a bake while changed drawing code invalidates it', () => {
  const drawingPath = path.join(root, 'scripts/chest_view.gd');
  const normalized = fs.readFileSync(drawingPath, 'utf8').replace(/\r\n?/g, '\n');
  const readFile = text => filename => filename === drawingPath ? Buffer.from(text) : fs.readFileSync(filename);
  assert.equal(checkJellyChestIcons(root, { readFile: readFile(normalized) }).icons, 28);
  assert.equal(checkJellyChestIcons(root, { readFile: readFile(normalized.replace(/\n/g, '\r\n')) }).icons, 28);
  assert.throws(() => checkJellyChestIcons(root, { readFile: readFile(`${normalized}\n# Changed drawing code\n`) }),
    /Stale Jelly chest icon input/);
});
