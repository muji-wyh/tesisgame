const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { runGodot } = require('./run-godot.cjs');
const { inlineMascot } = require('./prepare-godot.cjs');
const { packageWebExport } = require('./package-web.cjs');

const root = path.resolve(__dirname, '..');
const harnessFiles = ['tests/performance/jelly_fps_runner.gd', 'tests/performance/jelly_full_board_fixture.gd'];
const bridge = `<script>
window.jellyFpsBench = {
  ready: false, running: false, report: null, error: null, raf: [], callback: null,
  install(callback) { this.callback = callback; this.ready = true; },
  start(request) { this.report = null; this.error = null; this.callback(JSON.stringify(request)); },
  begin(json) {
    this.inputPlan = JSON.parse(json);
    this.running = true; this.raf = []; this.previous = null;
    const sample = timestamp => {
      if (!this.running) return;
      if (this.previous !== null) this.raf.push(timestamp - this.previous);
      this.previous = timestamp; requestAnimationFrame(sample);
    };
    requestAnimationFrame(sample);
  },
  finish(json) { this.running = false; this.report = JSON.parse(json); this.report.raf_interval_ms = this.raf; },
  fail(message) { this.running = false; this.error = message; }
};
</script>`;

function inside(parent, child) {
  const relative = path.relative(parent, child);
  return relative && !relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative);
}

function fingerprintProject(snapshot) {
  const files = [];
  function visit(filename) {
    const stat = fs.lstatSync(filename);
    // Licensed assets and engine imports remain shared references, not copied inputs.
    if (stat.isSymbolicLink()) return;
    if (stat.isDirectory()) {
      for (const entry of fs.readdirSync(filename).sort()) visit(path.join(filename, entry));
    } else if (stat.isFile() && !filename.endsWith('.uid')) {
      const bytes = fs.readFileSync(filename);
      files.push({ file: path.relative(snapshot, filename).split(path.sep).join('/'), bytes: bytes.length,
        sha256: crypto.createHash('sha256').update(bytes).digest('hex') });
    }
  }
  for (const name of ['scripts', 'scenes', 'data', 'tests', 'project.godot', 'export_presets.cfg', 'benchmark-shell.html',
    'words.json', 'phrases.json', 'curriculum.json', 'voice-prompts.json']) visit(path.join(snapshot, name));
  files.sort((a, b) => a.file.localeCompare(b.file));
  return { sha256: crypto.createHash('sha256').update(JSON.stringify(files)).digest('hex'), files,
    scope: 'Copied source, fixture, project/export configuration and shell; generated .uid files excluded. Shared assets and .godot imports are not frozen by this fingerprint.' };
}

function copyCompressionCandidates(output, cache = path.join(root, 'build', 'web')) {
  const copied = [];
  if (!fs.existsSync(cache)) return copied;
  for (const entry of fs.readdirSync(cache, { withFileTypes: true })) {
    if (!entry.isFile() || !/^(?:(?:engine|game)-[a-f0-9]{16}\..+|vocabulary-(?:shared-)?[0-9-]+-[a-f0-9]{16}\.pck)\.br$/.test(entry.name)) continue;
    const destination = path.join(output, entry.name);
    if (fs.existsSync(destination)) continue;
    fs.copyFileSync(path.join(cache, entry.name), destination, fs.constants.COPYFILE_EXCL);
    copied.push(entry.name);
  }
  // packageWebExport calls compressWebAsset, which decodes each candidate and
  // compares all bytes before reuse. A filename/hash alone never establishes reuse.
  return copied;
}

function writeBuildReport({ directory, source, packaged = false, cacheCandidates = [], compressionQuality = 4 }) {
  const snapshot = path.join(directory, 'project');
  const output = path.join(directory, 'web');
  const profileFile = path.join(snapshot, 'cpu-profile-instrumentation.json');
  const cpuProfile = fs.existsSync(profileFile) ? JSON.parse(fs.readFileSync(profileFile, 'utf8')) : null;
  const report = { protocol: 'jelly-full-board-rendered-v2', source: fs.realpathSync(source), snapshot, output,
    source_fingerprint: fingerprintProject(snapshot),
    harness_files: harnessFiles.map(filename => ({ file: filename,
      sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(snapshot, filename))).digest('hex') })),
    created_at: new Date().toISOString(), production_project_modified: false, packaged,
    cpu_profile: cpuProfile,
    diagnostic_only: Boolean(cpuProfile),
    measurement_role: cpuProfile ? 'CPU diagnosis; instrumentation overhead prevents FPS acceptance' : 'Uninstrumented runtime export',
    compression_quality: compressionQuality,
    compression_scope: 'Requested quality for newly compressed benchmark transfers; validated cached sidecars can retain their original encoding. All decoded engine, game and vocabulary bytes are unchanged, and measurement starts after loading.',
    compression_cache_candidates: cacheCandidates,
    compression_cache_validation: 'Every reused sidecar is fully decoded and compared to the current uncompressed input by compressWebAsset.',
    limitation: 'Assets and imported resources are shared. Keep them unchanged between paired benchmark exports.' };
  fs.writeFileSync(path.join(directory, 'benchmark-build.json'), `${JSON.stringify(report, null, 2)}\n`);
  return report;
}

function build({ source = root, label = 'jelly-fps', profile = false } = {}) {
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(label)) throw new Error('Invalid benchmark label.');
  if (![true, false, 'true', 'false'].includes(profile)) throw new Error('--profile must be true or false.');
  const useProfile = profile === true || profile === 'true';
  source = fs.realpathSync(source);
  const directory = path.join(root, 'build', 'performance', label);
  const snapshot = path.join(directory, 'project');
  const output = path.join(directory, 'web');
  if (!inside(path.join(root, 'build', 'performance'), directory)) throw new Error('Invalid output directory.');
  if (fs.existsSync(directory)) throw new Error(`Refusing to replace an existing benchmark: ${directory}`);
  fs.mkdirSync(snapshot, { recursive: true });
  fs.mkdirSync(output);
  for (const name of ['scripts', 'scenes', 'data', 'words.json', 'phrases.json', 'curriculum.json', 'voice-prompts.json']) {
    fs.cpSync(path.join(source, name), path.join(snapshot, name), { recursive: true });
  }
  for (const name of ['assets', '.godot']) {
    fs.symlinkSync(path.join(root, name), path.join(snapshot, name), process.platform === 'win32' ? 'junction' : 'dir');
  }
  for (const filename of harnessFiles) {
    const bytes = fs.readFileSync(path.join(root, filename));
    const destination = path.join(snapshot, filename);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, bytes);
  }
  let project = fs.readFileSync(path.join(source, 'project.godot'), 'utf8');
  if (/^\[autoload\]/m.test(project)) throw new Error('Merge the benchmark autoload explicitly before using this builder.');
  project += '\n[autoload]\nJellyFpsBenchmark="*res://tests/performance/jelly_fps_runner.gd"\n';
  fs.writeFileSync(path.join(snapshot, 'project.godot'), project);
  let preset = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
  preset = preset.replace('tests/*,', '').replace('html/custom_html_shell="res://web/shell.html"', 'html/custom_html_shell="res://benchmark-shell.html"');
  fs.writeFileSync(path.join(snapshot, 'export_presets.cfg'), preset);
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8').replace('</head>', `${bridge}\n</head>`);
  fs.writeFileSync(path.join(snapshot, 'benchmark-shell.html'), shell);
  if (useProfile) require('./instrument-jelly-fps-cpu.cjs').instrument(snapshot);
  // Existing imported art and complete vocabulary packs must be built by the
  // standard Web build first. This builder never modifies the production export.
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'build', 'vocabulary-packs', 'build-manifest.json'), 'utf8'));
  writeBuildReport({ directory, source });
  runGodot(['--headless', '--path', snapshot, '--export-release', 'Web', path.join(output, 'index.html')], { timeout: 1800000 });
  const html = path.join(output, 'index.html');
  fs.writeFileSync(html, inlineMascot(fs.readFileSync(html, 'utf8')));
  const cacheCandidates = copyCompressionCandidates(output);
  console.log(`Copied ${cacheCandidates.length} compression-cache candidates; packaging verifies decoded bytes before reuse.`);
  packageWebExport(output, manifest.packs, { compressionQuality: 4 });
  const report = writeBuildReport({ directory, source, packaged: true, cacheCandidates });
  console.log(`Jelly FPS benchmark export: ${output}`);
  return report;
}

if (require.main === module) {
  const options = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i].replace(/^--/, '');
    if (!['source', 'label', 'profile'].includes(key) || !process.argv[i + 1]) throw new Error('Usage: node tools/build-jelly-fps-web.cjs [--source PATH] [--label NAME] [--profile true]');
    options[key] = process.argv[i + 1];
  }
  build(options);
}
module.exports = { build, bridge, fingerprintProject, copyCompressionCandidates, writeBuildReport };
