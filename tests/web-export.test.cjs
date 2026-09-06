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
