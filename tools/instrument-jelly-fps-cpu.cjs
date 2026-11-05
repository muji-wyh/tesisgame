const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const repository = path.resolve(__dirname, '..');
const marker = '# JELLY FPS CPU PROFILE DIAGNOSTIC';
const targets = [
  { file: 'scripts/game_ui.gd', method: '_process', parameters: 'delta: float', arguments: 'delta', returns: 'void', label: 'GameUI._process' },
  { file: 'scripts/word_jelly.gd', method: '_process', parameters: 'delta: float', arguments: 'delta', returns: 'void', label: 'WordJelly._process' },
  { file: 'scripts/word_jelly.gd', method: '_begin_view_update', parameters: '', arguments: '', returns: 'void', label: 'WordJelly._begin_view_update' },
  { file: 'scripts/word_jelly.gd', method: '_sync_tiles', parameters: '', arguments: '', returns: 'void', label: 'WordJelly._sync_tiles' },
  { file: 'scripts/word_jelly.gd', method: '_sync_positions', parameters: '', arguments: '', returns: 'void', label: 'WordJelly._sync_positions' },
  { file: 'scripts/word_jelly.gd', method: 'snapshot', parameters: '', arguments: '', returns: 'Dictionary', label: 'WordJelly.snapshot' },
  { file: 'scripts/jelly_match.gd', method: '_publish', parameters: '', arguments: '', returns: 'void', label: 'JellyMatch._publish' },
  { file: 'scripts/word_jelly.gd', method: '_publish', parameters: '', arguments: '', returns: 'void', label: 'WordJelly._publish', optional: true },
  { file: 'scripts/word_jelly_model.gd', method: 'step', parameters: 'delta: float', arguments: 'delta', returns: 'void', label: 'WordModel.step' },
  { file: 'scripts/word_jelly_model.gd', method: 'snapshot', parameters: '', arguments: '', returns: 'Dictionary', label: 'WordModel.snapshot' },
  { file: 'scripts/word_jelly_publication_cache.gd', method: 'encode_base', parameters: 'state: Dictionary', arguments: 'state', returns: 'Dictionary', label: 'PublicationCache.encode_base', optional: true },
  { file: 'scripts/word_jelly_publication_cache.gd', method: 'encode_host', parameters: 'state: Dictionary, encoded: Dictionary, overrides: Dictionary', arguments: 'state, encoded, overrides', returns: 'String', label: 'PublicationCache.encode_host', optional: true }
];

function inside(parent, child) {
  const relative = path.relative(parent, child);
  return relative !== '' && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function assertUnlinkedPath(parent, filename, requireFile = true) {
  if (!inside(parent, filename)) throw new Error(`Instrumentation path escapes its copied project: ${filename}`);
  let current = parent;
  for (const component of path.relative(parent, filename).split(path.sep)) {
    current = path.join(current, component);
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error(`CPU instrumentation refuses links and junctions: ${current}`);
  }
  const stat = fs.statSync(filename);
  if (requireFile && (!stat.isFile() || stat.nlink !== 1)) {
    throw new Error(`CPU instrumentation requires a copied regular file with one link: ${filename}`);
  }
}

function digest(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function replaceOnce(source, needle, replacement, description) {
  const first = source.indexOf(needle);
  if (first < 0 || source.indexOf(needle, first + needle.length) >= 0) {
    throw new Error(`Expected one ${description}; the copied harness changed.`);
  }
  return source.slice(0, first) + replacement + source.slice(first + needle.length);
}

function wrapMethod(source, target) {
  const signature = `func ${target.method}(${target.parameters}) -> ${target.returns}:`;
  const lines = source.split(/\r?\n/);
  if (lines.filter(line => line === signature).length !== 1) {
    throw new Error(`Expected one nonstatic signature in ${target.file}: ${signature}`);
  }
  const newline = source.includes('\r\n') ? '\r\n' : '\n';
  // A derived override and its base implementation can both be instrumented.
  // Scope private declarations by script so super calls cannot redispatch to
  // an identically named derived "original" and recurse into the wrapper.
  const scope = path.basename(target.file, '.gd').replace(/[^a-zA-Z0-9_]/g, '_');
  const original = `_jelly_fps_cpu_original_${scope}_${target.method}`;
  if (source.includes(`func ${original}(`)) throw new Error(`Method is already instrumented: ${target.label}`);
  // Rename only the declaration. Its original body, explicit super calls,
  // public self calls and signal-bound public method names remain intact.
  source = replaceOnce(source, signature, `func ${original}(${target.parameters}) -> ${target.returns}:`, target.label);
  const call = `${original}(${target.arguments})`;
  const wrapper = [
    marker,
    signature,
    '\tvar _jelly_fps_cpu_started: int = Time.get_ticks_usec()',
    target.returns === 'void' ? `\t${call}` : `\tvar _jelly_fps_cpu_result: ${target.returns} = ${call}`,
    '\tvar _jelly_fps_cpu_elapsed: int = Time.get_ticks_usec() - _jelly_fps_cpu_started',
    '\tvar _jelly_fps_cpu_tree: SceneTree = Engine.get_main_loop() as SceneTree',
    '\tif _jelly_fps_cpu_tree != null:',
    '\t\tvar _jelly_fps_cpu_bench: Node = _jelly_fps_cpu_tree.root.get_node_or_null("JellyFpsBenchmark")',
    '\t\tif _jelly_fps_cpu_bench != null:',
    `\t\t\t_jelly_fps_cpu_bench.call("profile_record", "${target.label}", _jelly_fps_cpu_elapsed)`
  ];
  if (target.returns !== 'void') wrapper.push('\treturn _jelly_fps_cpu_result');
  return `${source}${source.endsWith(newline) ? '' : newline}${newline}${wrapper.join(newline)}${newline}`;
}

function instrumentRunner(source) {
  const newline = source.includes('\r\n') ? '\r\n' : '\n';
  const block = lines => lines.join(newline);
  source = replaceOnce(source, '\t_before = _boundary_state()', block([
    '\t_before = _boundary_state()',
    '\t# Diagnostic payload sizing runs before sampling reset and timing begin.',
    '\t_before["base_snapshot_characters"] = JSON.stringify(_view.snapshot()).length()'
  ]), 'pre-sampling snapshot-size boundary');
  source = replaceOnce(source, '\t_process_samples.clear()', block([
    '\t_process_samples.clear()',
    '\t_jelly_fps_cpu_profile_totals.clear()',
    '\t_jelly_fps_cpu_profile_frame.clear()',
    '\t_jelly_fps_cpu_profile_frames.clear()',
    '\t_jelly_fps_cpu_record_us = 0',
    '\t_jelly_fps_cpu_frame_record_us = 0'
  ]), 'sampling reset');
  source = replaceOnce(source, '\t_frame_begin_usec = now', block([
    '\t_jelly_fps_cpu_profile_frame.clear()',
    '\t_jelly_fps_cpu_frame_record_us = 0',
    '\t_frame_begin_usec = now'
  ]), 'frame-start boundary');
  source = replaceOnce(source, '\t_process_samples.append(_process_usec)', block([
    '\t_jelly_fps_cpu_profile_frames.append({"methods": _jelly_fps_cpu_profile_frame.duplicate(true),',
    '\t\t"record_bookkeeping_us": _jelly_fps_cpu_frame_record_us})',
    '\t_process_samples.append(_process_usec)'
  ]), 'frame-post-draw boundary');
  source = replaceOnce(source, '\t_view.cancel_input()', block([
    '\treport["cpu_profile"] = {"protocol": "jelly-gdscript-inclusive-cpu-v1", "diagnostic_only": true,',
    '\t\t"clock": "Time.get_ticks_usec", "totals": _jelly_fps_cpu_profile_totals.duplicate(true),',
    '\t\t"frames": _jelly_fps_cpu_profile_frames, "frame_post_draw_frames": _jelly_fps_cpu_profile_frames.size(),',
    '\t\t"record_bookkeeping_us": _jelly_fps_cpu_record_us,',
    '\t\t"timing_scope": "Inclusive CPU duration of the preserved original methods. Nested method times overlap and must not be summed as exclusive costs.",',
    '\t\t"instrumentation_overhead": "Recording bookkeeping is measured separately. Wrapper clock reads, SceneTree/node lookup, dynamic call dispatch and per-frame sample copying add further unmeasured overhead. Enclosing method/frame times include nested instrumentation; no overhead is subtracted. This instrumented export cannot establish 60 FPS acceptance."}',
    '\t_view.cancel_input()'
  ]), 'finish report boundary');
  const recorder = block([
    marker,
    'var _jelly_fps_cpu_profile_totals: Dictionary = {}',
    'var _jelly_fps_cpu_profile_frame: Dictionary = {}',
    'var _jelly_fps_cpu_profile_frames: Array[Dictionary] = []',
    'var _jelly_fps_cpu_record_us: int = 0',
    'var _jelly_fps_cpu_frame_record_us: int = 0',
    '',
    'func profile_record(method_name: String, elapsed_us: int) -> void:',
    '\tif not _sampling or not _pending:',
    '\t\treturn',
    '\tvar record_started: int = Time.get_ticks_usec()',
    '\tif not _jelly_fps_cpu_profile_totals.has(method_name):',
    '\t\t_jelly_fps_cpu_profile_totals[method_name] = {"calls": 0, "inclusive_us": 0}',
    '\tif not _jelly_fps_cpu_profile_frame.has(method_name):',
    '\t\t_jelly_fps_cpu_profile_frame[method_name] = {"calls": 0, "inclusive_us": 0}',
    '\t_jelly_fps_cpu_profile_totals[method_name].calls += 1',
    '\t_jelly_fps_cpu_profile_totals[method_name].inclusive_us += elapsed_us',
    '\t_jelly_fps_cpu_profile_frame[method_name].calls += 1',
    '\t_jelly_fps_cpu_profile_frame[method_name].inclusive_us += elapsed_us',
    '\tvar recording_us: int = Time.get_ticks_usec() - record_started',
    '\t_jelly_fps_cpu_record_us += recording_us',
    '\t_jelly_fps_cpu_frame_record_us += recording_us',
    ''
  ]);
  return `${source}${source.endsWith(newline) ? '' : newline}${newline}${recorder}`;
}

function instrument(project) {
  if (typeof project !== 'string' || project.length === 0) throw new Error('Pass the copied benchmark project directory.');
  const performanceRoot = fs.realpathSync(path.join(repository, 'build', 'performance'));
  const requested = path.resolve(project);
  if (!inside(performanceRoot, requested)) throw new Error('CPU instrumentation is restricted to build/performance copied projects.');
  assertUnlinkedPath(performanceRoot, requested, false);
  project = fs.realpathSync(requested);
  if (!inside(performanceRoot, project) || project === fs.realpathSync(repository)) {
    throw new Error('CPU instrumentation cannot modify the production project.');
  }
  const projectFile = path.join(project, 'project.godot');
  assertUnlinkedPath(project, projectFile);
  const configuration = fs.readFileSync(projectFile, 'utf8');
  if (!configuration.includes('JellyFpsBenchmark="*res://tests/performance/jelly_fps_runner.gd"')) {
    throw new Error('The copied project must explicitly install the isolated JellyFpsBenchmark autoload.');
  }
  const files = [...new Set(targets.map(target => target.file)), 'tests/performance/jelly_fps_runner.gd'];
  const patches = new Map();
  for (const relative of files) {
    const filename = path.join(project, relative);
    if (!fs.existsSync(filename)) {
      if (targets.filter(target => target.file === relative).every(target => target.optional) && relative !== 'tests/performance/jelly_fps_runner.gd') continue;
      throw new Error(`Required CPU instrumentation source is missing: ${relative}`);
    }
    assertUnlinkedPath(project, filename);
    const before = fs.readFileSync(filename, 'utf8');
    if (before.includes(marker)) throw new Error(`Refusing to instrument a project twice: ${relative}`);
    patches.set(relative, { filename, before, after: before });
  }
  const manifestFile = path.join(project, 'cpu-profile-instrumentation.json');
  if (fs.existsSync(manifestFile)) throw new Error('The copied project already has a CPU instrumentation manifest.');
  const activeTargets = targets.filter(target => {
    if (!patches.has(target.file)) return false;
    if (!target.optional) return true;
    const source = patches.get(target.file).before;
    const declarations = source.split(/\r?\n/).filter(line => line.startsWith(`func ${target.method}(`));
    if (!declarations.length) return false;
    const signature = `func ${target.method}(${target.parameters}) -> ${target.returns}:`;
    if (declarations.length !== 1 || declarations[0] !== signature) {
      throw new Error(`Expected one supported optional declaration in ${target.file}: ${signature}`);
    }
    return true;
  });
  // Validate and generate every patch before writing any copied source file.
  for (const target of activeTargets) {
    const patch = patches.get(target.file);
    patch.after = wrapMethod(patch.after, target);
  }
  const runner = patches.get('tests/performance/jelly_fps_runner.gd');
  runner.after = instrumentRunner(runner.after);
  const report = {
    protocol: 'jelly-gdscript-inclusive-cpu-v1', diagnostic_only: true, project,
    created_at: new Date().toISOString(), production_project_modified: false,
    methods: activeTargets.map(({ file, method, label, returns }) => ({ file, method, label, returns })),
    boundary_probes: [{ field: 'before.base_snapshot_characters',
      scope: 'Fresh complete base snapshot JSON character count after the warmup boundary and before sampling reset/start. This diagnostic sizing call is outside all sampled timings; host overrides are excluded.' }],
    files: [...patches].map(([file, patch]) => ({ file, original_sha256: digest(patch.before), instrumented_sha256: digest(patch.after) })),
    timing_scope: 'Inclusive durations; original bodies are preserved under private names and public signatures delegate to them. Nested timings overlap.',
    overhead: 'Recording bookkeeping is measured by the runner. Additional wrapper clocks, root lookup, dispatch and frame-copy overhead remain unmeasured; no overhead is subtracted. Use this export for diagnosis only, never 60 FPS acceptance.'
  };
  for (const patch of patches.values()) fs.writeFileSync(patch.filename, patch.after);
  fs.writeFileSync(manifestFile, `${JSON.stringify(report, null, 2)}\n`, { flag: 'wx' });
  return report;
}

if (require.main === module) {
  if (process.argv.length !== 4 || process.argv[2] !== '--project') {
    throw new Error('Usage: node tools/instrument-jelly-fps-cpu.cjs --project PATH_TO_COPIED_BENCHMARK_PROJECT');
  }
  console.log(JSON.stringify(instrument(process.argv[3]), null, 2));
}

module.exports = { instrument, wrapMethod, instrumentRunner, targets };
