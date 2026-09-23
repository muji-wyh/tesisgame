const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { createHash } = require('node:crypto');
const { packageMultiplayer } = require('../tools/package-multiplayer.cjs');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'voice-pop-package-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.mkdirSync(path.join(directory, 'web'));
  for (const name of ['host', 'capture', 'audio', 'worker']) fs.writeFileSync(path.join(directory, 'web', `multiplayer-${name}.js`), `// ${name}`);
  const source = path.join(directory, 'build', 'multiplayer');
  const output = path.join(directory, 'output');
  fs.mkdirSync(source, { recursive: true }); fs.mkdirSync(output);
  const data = Buffer.from('verified local model');
  fs.writeFileSync(path.join(source, 'model.onnx'), data);
  const manifest = { version: 'v1', runtime: {}, assets: [{ id: 'speaker', url: 'model.onnx', bytes: data.length,
    sha256: createHash('sha256').update(data).digest('hex') }] };
  const write = () => fs.writeFileSync(path.join(source, 'manifest.json'), JSON.stringify(manifest));
  write();
  return { directory, source, output, data, manifest, write };
}

test('models are verified, content-addressed and packaged separately from Godot startup', t => {
  const f = fixture(t);
  assert.equal(packageMultiplayer(f.directory, f.output), f.data.length);
  const published = JSON.parse(fs.readFileSync(path.join(f.output, 'multiplayer', 'manifest.json')));
  assert.match(published.assets[0].url, /^speaker-[a-f0-9]{16}\.onnx$/);
  assert.deepEqual(fs.readFileSync(path.join(f.output, 'multiplayer', published.assets[0].url)), f.data);
  assert.equal(fs.existsSync(path.join(f.output, 'multiplayer-worker.js')), true);
  assert.equal(fs.existsSync(path.join(f.output, 'model.onnx')), false);
});

test('missing or corrupted multiplayer assets fail the export explicitly', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.source, 'model.onnx'), 'corrupt');
  assert.throws(() => packageMultiplayer(f.directory, f.output), /failed verification/);
  fs.unlinkSync(path.join(f.source, 'manifest.json'));
  assert.throws(() => packageMultiplayer(f.directory, f.output), /prepare:multiplayer/);
});

test('manifest asset paths cannot escape the prepared asset directory', t => {
  const f = fixture(t);
  for (const url of ['../model.onnx', '/model.onnx', 'C:\\model.onnx', 'https://example.com/model.onnx']) {
    f.manifest.assets[0].url = url; f.write();
    assert.throws(() => packageMultiplayer(f.directory, f.output), /relative paths/);
  }
});

test('successive exports remove obsolete generated assets without removing unrelated files', t => {
  const f = fixture(t);
  packageMultiplayer(f.directory, f.output);
  const destination = path.join(f.output, 'multiplayer');
  const previous = JSON.parse(fs.readFileSync(path.join(destination, 'manifest.json'))).assets[0].url;
  fs.writeFileSync(path.join(destination, 'notes.txt'), 'Keep non-generated files');
  const next = Buffer.from('a new model version');
  fs.writeFileSync(path.join(f.source, 'model.onnx'), next);
  Object.assign(f.manifest.assets[0], { bytes: next.length, sha256: createHash('sha256').update(next).digest('hex') });
  f.write();
  packageMultiplayer(f.directory, f.output);
  const current = JSON.parse(fs.readFileSync(path.join(destination, 'manifest.json'))).assets[0].url;
  assert.notEqual(current, previous);
  assert.equal(fs.existsSync(path.join(destination, previous)), false);
  assert.equal(fs.existsSync(path.join(destination, 'notes.txt')), true);
  assert.deepEqual(fs.readFileSync(path.join(destination, current)), next);
});
