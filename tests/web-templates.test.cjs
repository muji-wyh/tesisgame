const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');
const { checkWebTemplates } = require('../tools/check-web-templates.cjs');

function fixture(t, overrides = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-template-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const info = { version: { major: 4, minor: 7, patch: 2, status: 'stable' },
    data_dir: path.join(root, 'portable-editor-data'), threads: false, extensions: false,
    debug: '', release: '', ...overrides };
  let probeDirectory;
  t.mock.method(childProcess, 'spawnSync', (binary, args, options) => {
    probeDirectory = options.cwd;
    assert.notEqual(probeDirectory, root);
    assert.deepEqual(args.slice(0, 3), ['--headless', '--editor', '--path']);
    assert.equal(args[3], probeDirectory);
    assert.equal(options.windowsHide, true);
    const request = JSON.parse(fs.readFileSync(path.join(probeDirectory, 'request.json'), 'utf8'));
    assert.equal(request.presets_path, path.join(root, 'export_presets.cfg'));
    const probe = fs.readFileSync(path.join(probeDirectory, 'addons/template-probe/plugin.gd'), 'utf8');
    assert.match(probe, /EditorInterface\.get_editor_paths\(\)\.get_data_dir\(\)/);
    return { status: 0, stdout: `Godot startup\nWEB_TEMPLATE_PREFLIGHT:${JSON.stringify(info)}\n`, stderr: '' };
  });
  const write = file => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, 'template fixture'); };
  const folder = path.join(info.data_dir, 'export_templates', '4.7.2.stable');
  return { root, info, folder, write, check: () => checkWebTemplates({ rootDir: root }),
    probeExists: () => fs.existsSync(probeDirectory) };
}

test('missing exact-version Web templates fail early with both files and an actionable repair', t => {
  const f = fixture(t);
  for (const kind of ['debug', 'release']) f.write(path.join(f.info.data_dir, 'export_templates', '4.7.stable', `web_nothreads_${kind}.zip`));
  assert.throws(f.check, error => error.message.includes('4.7.2.stable') &&
    error.message.includes('web_nothreads_debug.zip') && error.message.includes('web_nothreads_release.zip') &&
    error.message.includes('Manage Export Templates') && error.message.includes('npm run build:web'));
  assert.equal(f.probeExists(), false);
});

test('matching templates use Godot editor data paths, including portable installations', t => {
  const f = fixture(t);
  for (const kind of ['debug', 'release']) f.write(path.join(f.folder, `web_nothreads_${kind}.zip`));
  const result = f.check();
  assert.equal(result.version, '4.7.2.stable');
  assert.equal(result.templateDirectory, f.folder);
  assert.equal(result.templates.release, path.join(f.folder, 'web_nothreads_release.zip'));
  assert.equal(f.probeExists(), false);
});

test('empty templates and directories do not satisfy the preflight', t => {
  const f = fixture(t);
  fs.mkdirSync(path.join(f.folder, 'web_nothreads_debug.zip'), { recursive: true });
  fs.writeFileSync(path.join(f.folder, 'web_nothreads_release.zip'), '');
  assert.throws(f.check, /Missing or empty Web export templates/);
});

test('custom debug and release paths replace only their respective defaults', t => {
  const f = fixture(t, { debug: 'res://custom/debug.zip', release: 'custom/release.zip' });
  for (const kind of ['debug', 'release']) f.write(path.join(f.root, 'custom', `${kind}.zip`));
  assert.deepEqual(f.check().templates, { debug: path.join(f.root, 'custom/debug.zip'), release: path.join(f.root, 'custom/release.zip') });
  f.info.release = '';
  assert.throws(f.check, /web_nothreads_release\.zip/);
  f.info.release = path.join(f.root, 'custom/release.zip');
  assert.equal(f.check().templates.release, f.info.release);
});

test('the selected Web flags determine threaded and extension template names', t => {
  const f = fixture(t, { threads: true, extensions: true });
  for (const kind of ['debug', 'release']) f.write(path.join(f.folder, `web_dlink_${kind}.zip`));
  assert.equal(f.check().templates.debug, path.join(f.folder, 'web_dlink_debug.zip'));
  f.info.threads = false;
  assert.throws(f.check, /web_dlink_nothreads_debug\.zip/);
});

test('zero-patch Godot versions use their actual template directory name', t => {
  const f = fixture(t, { version: { major: 4, minor: 7, patch: 0, status: 'stable' } });
  const folder = path.join(f.info.data_dir, 'export_templates', '4.7.stable');
  for (const kind of ['debug', 'release']) f.write(path.join(folder, `web_nothreads_${kind}.zip`));
  assert.equal(f.check().version, '4.7.stable');
});

test('failed engine probes and malformed results fail closed and remove temporary projects', t => {
  const f = fixture(t);
  let directory;
  for (const result of [
    { error: new Error('synthetic engine unavailable') },
    { status: 1, stdout: 'WEB_TEMPLATE_PREFLIGHT:{"error":"A Web platform export preset named Web is required."}\n' },
    { status: 0, stdout: 'unexpected output' },
    { status: 0, stdout: 'WEB_TEMPLATE_PREFLIGHT:{"version":null}\n' },
    { status: 0, stdout: `WEB_TEMPLATE_PREFLIGHT:${JSON.stringify({ ...f.info, version: { major: 4, minor: 7, patch: 2 } })}\n` }
  ]) {
    t.mock.method(childProcess, 'spawnSync', (binary, args, options) => { directory = options.cwd; return result; });
    assert.throws(f.check, /Could not inspect|Web platform export preset|invalid Web template settings/);
    assert.equal(fs.existsSync(directory), false);
  }
});
