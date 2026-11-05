const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { instrument, wrapMethod, instrumentRunner, targets } = require('../tools/instrument-jelly-fps-cpu.cjs');

const repository = path.resolve(__dirname, '..');
const performanceRoot = path.join(repository, 'build/performance');
const marker = '# JELLY FPS CPU PROFILE DIAGNOSTIC';
const runnerSource = ['extends Node', 'func start() -> void:', '\t_before = _boundary_state()',
  '\t_process_samples.clear()', 'func tick() -> void:', '\t_frame_begin_usec = now',
  'func drawn() -> void:', '\t_process_samples.append(_process_usec)',
  'func finish() -> void:', '\t_view.cancel_input()', ''].join('\n');

function signature(target, newline = '\n') {
  return `func ${target.method}(${target.parameters}) -> ${target.returns}:`.replace(/\r?\n/g, newline);
}

function declaration(target) {
  const body = { void: '\tpass', Dictionary: '\treturn {}', String: '\treturn ""', bool: '\treturn false',
    Texture2D: '\treturn null', 'Array[int]': '\treturn []' }[target.returns];
  assert(body, `A fixture body is required for ${target.returns}`);
  return `${signature(target)}\n${body}\n`;
}

function copiedProject(t, omitted = []) {
  fs.mkdirSync(performanceRoot, { recursive: true });
  const directory = fs.mkdtempSync(path.join(performanceRoot, 'node-jelly-instrument-'));
  t.after(() => {
    // Resolve the exact owned fixture before recursive cleanup on Windows.
    const resolvedRoot = fs.realpathSync(performanceRoot), resolvedDirectory = fs.realpathSync(directory);
    const relative = path.relative(resolvedRoot, resolvedDirectory);
    assert(relative && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const project = path.join(directory, 'project');
  fs.mkdirSync(project);
  fs.writeFileSync(path.join(project, 'project.godot'), '[autoload]\nJellyFpsBenchmark="*res://tests/performance/jelly_fps_runner.gd"\n');
  const files = new Map();
  for (const target of targets) {
    if (omitted.includes(target.label)) continue;
    files.set(target.file, (files.get(target.file) || 'extends Node\n') + declaration(target));
  }
  files.set('tests/performance/jelly_fps_runner.gd', runnerSource);
  for (const [relative, text] of files) {
    const filename = path.join(project, relative);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, text, { flag: 'wx' });
  }
  return { project, directory, files };
}

function assertOriginalFiles(project, files) {
  for (const [relative, original] of files) assert.equal(fs.readFileSync(path.join(project, relative), 'utf8'), original, relative);
  assert.equal(fs.existsSync(path.join(project, 'cpu-profile-instrumentation.json')), false);
}

test('every current target matches its production declaration without changing the original body or call bindings', () => {
  const labels = new Set();
  for (const target of targets) {
    assert(!labels.has(target.label), `Duplicate profile label: ${target.label}`);
    labels.add(target.label);
    const source = fs.readFileSync(path.join(repository, target.file), 'utf8');
    const result = wrapMethod(source, target);
    const newline = source.includes('\r\n') ? '\r\n' : '\n';
    const scope = path.basename(target.file, '.gd');
    const original = `_jelly_fps_cpu_original_${scope}_${target.method}`;
    const preserved = source.replace(signature(target, newline), signature(target, newline).replace(`func ${target.method}(`, `func ${original}(`));
    assert(result.startsWith(preserved), `${target.label}: only the original declaration is renamed`);
    const wrapper = result.slice(preserved.length);
    assert(wrapper.includes(signature(target, newline)), `${target.label}: public defaults and types are retained`);
    assert(wrapper.includes(`${original}(${target.arguments})`), `${target.label}: arguments are forwarded without defaults`);
    assert(wrapper.includes(`profile_record", "${target.label}"`));
    if (target.returns === 'void') assert(!wrapper.includes('_jelly_fps_cpu_result'));
    else {
      assert(wrapper.includes(`var _jelly_fps_cpu_result: ${target.returns} = ${original}(${target.arguments})`));
      assert(wrapper.includes('\treturn _jelly_fps_cpu_result'));
    }
  }
  for (const required of ['WordModel._complete_operation', 'WordModel._complete_collection', 'GameUI._record_growth',
    'GameUI._refresh_growth', 'GameUI._refresh_jelly_stage_targets', 'GameUI._credit_word_jelly',
    'GameUI._credit_coins', 'GameUI._publish_coins', 'GameUI._present_word_jelly_credit',
    'WordJelly.set_stage_progress', 'WordJelly._collected', 'GameLibrary.configure_growth',
    'GameLibrary.configure_professional', 'GameLibrary._show_growth_hero', 'GameLibrary._layout_hero',
    'GrowthState.record_attempt', 'GrowthState._persist', 'CoinWallet._persist',
    'JellyMatch._chest_milestone', 'JellyMatch._chest_for_theme', 'JellyMatch._reward_texture',
    'ChestCelebration.enqueue', 'WordModel._queue_collection_blast', 'WordModel._blast_target_ids',
    'WordModel._restore_growth', 'WordJelly._refresh_controls', 'WordJelly._combo_changed', 'BossRun.collect_hit']) {
    assert(labels.has(required), `Required completion diagnostic is missing: ${required}`);
  }
});

test('resource and typed-array return wrappers preserve nullable resources and delegate the original array without reconstruction', () => {
  for (const label of ['JellyMatch._chest_for_theme', 'JellyMatch._reward_texture', 'WordModel._blast_target_ids']) {
    const target = targets.find(item => item.label === label);
    const original = `_jelly_fps_cpu_original_${path.basename(target.file, '.gd')}_${target.method}`;
    const body = target.returns === 'Texture2D' ? '\treturn null\n' : '\tvar selected: Array[int] = [1, 2]\n\treturn selected\n';
    const source = signature(target) + '\n' + body;
    const result = wrapMethod(source, target);
    const preserved = source.replace(signature(target), signature(target).replace(`func ${target.method}(`, `func ${original}(`));
    assert(result.startsWith(preserved));
    const wrapper = result.slice(preserved.length);
    assert(result.includes(body), `${label}: nullable or typed-array body is preserved`);
    assert(wrapper.includes(`var _jelly_fps_cpu_result: ${target.returns} = ${original}(${target.arguments})`));
    assert(wrapper.includes('\treturn _jelly_fps_cpu_result'));
    assert(!wrapper.includes('.duplicate(') && !wrapper.includes('.assign(') && !wrapper.includes('.append('),
      `${label}: the wrapper does not rebuild the original return value`);
  }
});

test('multiline persistence declarations retain LF or CRLF, default arguments, early returns and the bool result', () => {
  const target = targets.find(item => item.label === 'GrowthState._persist');
  for (const newline of ['\n', '\r\n']) {
    const source = ['extends RefCounted', signature(target, newline), '\tif next_receipts.is_empty():',
      '\t\treturn false', '\treturn expected_text == null', ''].join(newline);
    const result = wrapMethod(source, target);
    assert(result.includes(signature(target, newline)));
    assert(result.includes(`expected_text: Variant = null) -> bool:${newline}\tif next_receipts.is_empty():`));
    assert(result.includes(`\t\treturn false${newline}\treturn expected_text == null`));
    assert(result.includes('next_streaks, next_mastered, next_receipts, expected_text)'));
    assert.equal(result.replaceAll('\r\n', '').includes('\n'), newline === '\n');
  }
});

test('base and derived wrappers use distinct private names and preserve super and signal-bound public calls', () => {
  const base = { file: 'scripts/jelly_match.gd', method: '_publish', parameters: '', arguments: '', returns: 'void', label: 'Base._publish' };
  const derived = { ...base, file: 'scripts/word_jelly.gd', label: 'Derived._publish' };
  const body = 'func _publish() -> void:\n\tsuper._publish()\n\tchanged.connect(_publish)\n\t_publish()\n';
  const parent = wrapMethod('func _publish() -> void:\n\treturn\n', base);
  const child = wrapMethod(body, derived);
  assert(parent.includes('func _jelly_fps_cpu_original_jelly_match__publish()'));
  assert(child.includes('func _jelly_fps_cpu_original_word_jelly__publish()'));
  assert(child.includes('\tsuper._publish()\n\tchanged.connect(_publish)\n\t_publish()'));
  assert(!child.includes('_jelly_fps_cpu_original_jelly_match__publish'));
});

test('missing, duplicate, static, changed-return and changed-default signatures are rejected', () => {
  const target = targets.find(item => item.label === 'GameLibrary.configure_professional');
  const valid = declaration(target);
  for (const source of ['', valid + valid, valid.replace('func ', 'static func '),
    valid.replace('-> void:', '-> bool:'), valid.replace('profile: Dictionary = {}', 'profile: Dictionary')]) {
    assert.throws(() => wrapMethod(source, target), /Expected one nonstatic signature/);
  }
  assert.throws(() => wrapMethod(wrapMethod(valid, target), target), /already instrumented/);
});

test('runner sizing precedes sampling reset and every profile retains diagnostic overhead and overlapping-time scope', () => {
  const result = instrumentRunner(runnerSource);
  assert(result.indexOf('_before["base_snapshot_characters"]') < result.indexOf('_jelly_fps_cpu_profile_totals.clear()'));
  assert(result.includes('if not _sampling or not _pending:'));
  assert(result.includes('Nested method times overlap and must not be summed'));
  assert(result.includes('Wrapper clock reads, SceneTree/node lookup, dynamic call dispatch'));
  assert(result.includes('cannot establish 60 FPS acceptance'));
  assert.throws(() => instrumentRunner(runnerSource.replace('\t_frame_begin_usec = now', '\t_frame_begin_usec = later')), /frame-start boundary/);
});

test('a copied project records exact signatures, file hashes and diagnostic scope without modifying production', t => {
  const fixture = copiedProject(t);
  const productionBefore = fs.readFileSync(path.join(repository, 'project.godot'));
  const report = instrument(fixture.project);
  assert.equal(report.diagnostic_only, true);
  assert.equal(report.production_project_modified, false);
  assert.equal(report.methods.length, targets.length);
  for (const target of targets) {
    assert.deepEqual(report.methods.find(item => item.label === target.label), {
      file: target.file, method: target.method, label: target.label, parameters: target.parameters,
      arguments: target.arguments, returns: target.returns
    });
  }
  for (const file of report.files) {
    assert.match(file.original_sha256, /^[a-f0-9]{64}$/);
    assert.match(file.instrumented_sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(file.original_sha256, file.instrumented_sha256);
    assert(fs.readFileSync(path.join(fixture.project, file.file), 'utf8').includes(marker));
  }
  assert.deepEqual(fs.readFileSync(path.join(repository, 'project.godot')), productionBefore);
  const manifestBefore = fs.readFileSync(path.join(fixture.project, 'cpu-profile-instrumentation.json'));
  assert.throws(() => instrument(fixture.project), /instrument a project twice/);
  assert.deepEqual(fs.readFileSync(path.join(fixture.project, 'cpu-profile-instrumentation.json')), manifestBefore);
});

test('a late signature mismatch or runner boundary mismatch leaves every copied file untouched', t => {
  for (const breakRunner of [false, true]) {
    const fixture = copiedProject(t);
    const relative = breakRunner ? 'tests/performance/jelly_fps_runner.gd' : 'scripts/coin_wallet.gd';
    const original = fixture.files.get(relative);
    const changed = breakRunner ? original.replace('\t_view.cancel_input()', '\t_view.stop()')
      : original.replace('func _persist(next_balance: int', 'func _persist(renamed_balance: int');
    fs.writeFileSync(path.join(fixture.project, relative), changed);
    fixture.files.set(relative, changed);
    assert.throws(() => instrument(fixture.project), breakRunner ? /finish report boundary/ : /Expected one nonstatic signature/);
    assertOriginalFiles(fixture.project, fixture.files);
  }
});

test('missing optional cache and override methods are skipped explicitly in the active manifest', t => {
  const omitted = targets.filter(target => target.optional).map(target => target.label);
  const fixture = copiedProject(t, omitted);
  const report = instrument(fixture.project);
  assert.deepEqual(report.methods.map(item => item.label), targets.filter(target => !target.optional).map(item => item.label));
  assert(!report.files.some(item => item.file === 'scripts/word_jelly_publication_cache.gd'));
});

test('production, escaping directories and linked copied-project aliases are refused before writes', t => {
  const fixture = copiedProject(t);
  assert.throws(() => instrument(repository), /restricted to build\/performance copied projects/);
  assert.throws(() => instrument(path.join(fixture.project, '../../../../outside')), /restricted to build\/performance copied projects/);
  const linked = path.join(fixture.directory, 'linked-project');
  fs.symlinkSync(fixture.project, linked, process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => instrument(linked), /refuses links and junctions/);
  assertOriginalFiles(fixture.project, fixture.files);
});

test('a hard-linked source file is refused before any copied source is patched', t => {
  const fixture = copiedProject(t);
  const filename = path.join(fixture.project, 'scripts/game_library.gd');
  const shared = path.join(fixture.directory, 'shared-library.gd');
  fs.writeFileSync(shared, fixture.files.get('scripts/game_library.gd'));
  fs.unlinkSync(filename);
  fs.linkSync(shared, filename);
  assert.throws(() => instrument(fixture.project), /copied regular file with one link/);
  assertOriginalFiles(fixture.project, fixture.files);
  assert.equal(fs.readFileSync(shared, 'utf8'), fixture.files.get('scripts/game_library.gd'));
});
