const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('the delivery preset exports a single-threaded Godot Web game with JSON data', () => {
  const filename = path.join(root, 'export_presets.cfg');
  assert.ok(fs.existsSync(filename), 'The Web export preset is missing');
  const preset = fs.readFileSync(filename, 'utf8');
  assert.match(preset, /platform="Web"/);
  assert.match(preset, /variant\/thread_support=false/);
  assert.match(preset, /variant\/extensions_support=false/);
  assert.match(preset, /include_filter="[^"]*words\.json[^"]*assets\/chests\/manifest\.json/);
  assert.match(preset, /html\/custom_html_shell="res:\/\/web\/shell\.html"/);
  assert.match(preset, /html\/canvas_resize_policy=0/);
  assert.match(preset, /html\/focus_canvas_on_start=false/);
  const project = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
  assert.match(project, /textures\/vram_compression\/import_s3tc_bptc=true/);
  assert.match(project, /textures\/vram_compression\/import_etc2_astc=true/);
});

test('the export shell hosts the engine and fits a safe-area container without disabling zoom', () => {
  const filename = path.join(root, 'web', 'shell.html');
  assert.ok(fs.existsSync(filename), 'The Godot Web shell is missing');
  const shell = fs.readFileSync(filename, 'utf8');
  assert.match(shell, /\$GODOT_URL/);
  assert.match(shell, /\$GODOT_CONFIG/);
  assert.match(shell, /<canvas\b/);
  assert.match(shell, /safe-area-inset/);
  assert.match(shell, /ResizeObserver/);
  assert.match(shell, /prefers-reduced-motion/);
  assert.match(shell, /visibilitychange/);
  assert.match(shell, /engineReady/);
  assert.match(shell, /id="game-status"/);
  assert.match(shell, /id="audio-status"/);
  assert.match(shell, /--audio-driver/);
  assert.match(shell, /Dummy/);
  assert.doesNotMatch(shell, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/);
  assert.doesNotMatch(shell, /GameCore|selectCard|createRound|speechSynthesis/);
});

test('the Godot command runner waits for the engine and propagates its real failure status', () => {
  const filename = path.join(root, 'tools', 'run-godot.cjs');
  assert.ok(fs.existsSync(filename), 'The Godot process runner is missing');
  const { runGodot } = require(filename);
  assert.match(runGodot(['--version']).stdout, /^4\.7\./);
  assert.throws(
    () => runGodot(['--headless', '--path', root, '--script', 'res://tests/godot/exit_code.gd']),
    /exit 7/
  );
});

test('Web delivery compresses and fingerprints assets without mixing cached game versions', (t) => {
  const filename = path.join(root, 'tools', 'package-web.cjs');
  assert.ok(fs.existsSync(filename), 'The mobile Web export packager is missing');
  const { packageWebExport } = require(filename);
  const { brotliDecompressSync } = require('node:zlib');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'word-buddies-web-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const files = {
    'index.js': Buffer.from('engine glue '.repeat(1024)),
    'index.wasm': Buffer.from('engine bytecode '.repeat(8192)),
    'index.audio.worklet.js': Buffer.from('audio worklet'),
    'index.audio.position.worklet.js': Buffer.from('position worklet'),
    'index.pck': Buffer.from('game data '.repeat(1024))
  };
  const audio = [{
    source: 'res://assets/audio/voice/welcome.wav',
    bytes: Buffer.from('RSRC optional audio '.repeat(1024))
  }];
  const writeExport = () => {
    for (const [name, bytes] of Object.entries(files)) fs.writeFileSync(path.join(directory, name), bytes);
    fs.writeFileSync(path.join(directory, 'index.html'),
      `<script src="index.js"></script><script>const config = ${JSON.stringify({
        executable: 'index', args: [], fileSizes: {
          'index.wasm': files['index.wasm'].length,
          'index.pck': files['index.pck'].length
        }
      })};</script>`);
  };
  const readConfig = () => JSON.parse(fs.readFileSync(path.join(directory, 'index.html'), 'utf8')
    .match(/const config = (\{[^\r\n]*\});/)[1]);
  writeExport();
  fs.writeFileSync(path.join(directory, 'keep.txt'), 'unrelated file');
  const initialBytes = packageWebExport(directory, audio);
  const first = readConfig();
  assert.match(first.executable, /^engine-[a-f0-9]{16}$/);
  assert.match(first.mainPack, /^game-[a-f0-9]{16}\.pck$/);
  for (const [name, bytes] of Object.entries(files)) {
    const target = name.endsWith('.pck') ? first.mainPack : name.replace('index', first.executable);
    assert.deepEqual(fs.readFileSync(path.join(directory, target)), bytes);
    assert.deepEqual(brotliDecompressSync(fs.readFileSync(path.join(directory, `${target}.br`))), bytes);
    assert.equal(fs.existsSync(path.join(directory, name)), false, 'Unversioned engine/data files must not be shipped');
  }
  assert.equal(first.fileSizes[`${first.executable}.wasm`], files['index.wasm'].length);
  assert.equal(first.fileSizes[first.mainPack], files['index.pck'].length);
  assert.ok(fs.readFileSync(path.join(directory, 'index.html'), 'utf8').includes(`src="${first.executable}.js"`));
  assert.ok(fs.statSync(path.join(directory, `${first.executable}.wasm.br`)).size < files['index.wasm'].length / 4);
  assert.ok(first.audioAssets, 'Optional audio needs an on-demand URL map');
  const firstAudio = first.audioAssets[audio[0].source];
  assert.match(firstAudio, /^audio-[a-f0-9]{16}\.sample$/);
  assert.deepEqual(fs.readFileSync(path.join(directory, firstAudio)), audio[0].bytes);
  assert.deepEqual(brotliDecompressSync(fs.readFileSync(path.join(directory, `${firstAudio}.br`))), audio[0].bytes);
  assert.equal(first.fileSizes[firstAudio], undefined, 'Optional audio must not participate in startup preloading');
  audio[0].bytes = Buffer.from('RSRC changed optional audio');
  writeExport();
  assert.equal(packageWebExport(directory, audio), initialBytes, 'Optional audio must not enlarge the startup payload');
  const audioUpdate = readConfig();
  assert.equal(audioUpdate.executable, first.executable);
  assert.equal(audioUpdate.mainPack, first.mainPack, 'Optional audio updates must not invalidate the game pack');
  assert.notEqual(audioUpdate.audioAssets[audio[0].source], firstAudio);
  assert.equal(fs.existsSync(path.join(directory, firstAudio)), false);

  files['index.pck'] = Buffer.from('updated game data');
  writeExport();
  packageWebExport(directory, audio);
  const second = readConfig();
  assert.equal(second.executable, first.executable, 'Game changes must reuse the cached engine');
  assert.notEqual(second.mainPack, first.mainPack, 'New game content must use a new cache key');
  assert.equal(fs.existsSync(path.join(directory, first.mainPack)), false, 'Obsolete generated packs must not accumulate');
  assert.equal(fs.readFileSync(path.join(directory, 'keep.txt'), 'utf8'), 'unrelated file');
  const config = JSON.parse(fs.readFileSync(path.join(root, 'web', 'staticwebapp.config.json'), 'utf8'));
  assert.equal(config.globalHeaders['Cache-Control'], 'no-cache', 'HTML must discover updated asset names');
  assert.equal(config.globalHeaders.Vary, 'Accept-Encoding', 'Caches must distinguish compressed and identity responses');
  for (const route of ['/engine-*', '/game-*', '/audio-*']) {
    assert.equal(config.routes.find(entry => entry.route === route).headers['Cache-Control'],
      'public, max-age=31536000, immutable');
  }
});
