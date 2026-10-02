const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { compare, stats, bootstrapPairedRatios, verifyProjectHarness } = require('../tools/benchmark-performance.cjs');
const { freezeBaseline } = require('../tools/freeze-performance-baseline.cjs');

const resultsRoot = path.resolve(__dirname, '../build/performance');
fs.mkdirSync(resultsRoot, { recursive: true });
const fixtureDirectory = fs.mkdtempSync(path.join(resultsRoot, 'node-acceptance-'));
const names = ['match', 'memory', 'voice-pop', 'talk-quest', 'room', 'catalog', 'chest'];
const baseMeans = [1000, 2000, 50000, 12000, 500, 800, 10000];
let serial = 0;

function report(factors = Array(7).fill(1), repeatFactors = Array(5).fill(1)) {
  const configuration = {
    scenarios: names, width: 390, height: 844, warmup: 90, samples: 240, seed: 73021,
    fps: 60, vsync: false, renderer: 'gl_compatibility', audio: 'Dummy', reduced_motion: false
  };
  const runs = repeatFactors.map(repeatFactor => ({
    engine: { string: '4.7-stable (official)', hash: 'fixture-engine' },
    configuration: {
      adapter: 'ANGLE Microsoft Basic Render Driver', rendering_method: 'gl_compatibility',
      rendering_driver: 'opengl3_angle', window_size: [390, 844], vsync: 0, max_fps: 60,
      audio_driver: 'Dummy', stretch_mode: 'canvas_items', stretch_aspect: 'expand',
      warmup_frames: 90, sample_frames: 240, reduced_motion: false
    },
    scenarios: names.map((scenario, index) => ({
      scenario, rendered: { mean: baseMeans[index] * factors[index] * repeatFactor, p95: baseMeans[index] * factors[index] * repeatFactor * 1.4 },
      process: { mean: baseMeans[index] * factors[index] * repeatFactor * 0.1 }
    }))
  }));
  return {
    protocol: 'main-scene-rendered-v1', configuration, harness_sha256: 'fixture-harness',
    host: { platform: 'win32', release: 'fixture-os', cpu: 'fixture-cpu', logical_cpus: 8 }, runs,
    scenarios: names.map((scenario, index) => ({
      scenario,
      rendered: { mean: runs.reduce((sum, run) => sum + run.scenarios[index].rendered.mean, 0) / runs.length, p95: baseMeans[index] * factors[index] * 1.4 },
      process: { mean: runs.reduce((sum, run) => sum + run.scenarios[index].process.mean, 0) / runs.length }
    }))
  };
}

function evaluate(baseline = report(), candidate = report(Array(7).fill(0.8))) {
  const id = ++serial;
  const baselineFile = path.join(fixtureDirectory, `baseline-${id}.json`);
  const candidateFile = path.join(fixtureDirectory, `candidate-${id}.json`);
  fs.writeFileSync(baselineFile, JSON.stringify(baseline), { flag: 'wx' });
  fs.writeFileSync(candidateFile, JSON.stringify(candidate), { flag: 'wx' });
  return compare(baselineFile, candidateFile);
}

function near(actual, expected) {
  assert(Math.abs(actual - expected) < 1e-10, `Expected ${actual} to equal ${expected}`);
}

test('the actual project must use the reference harness and fixture, and either input changes its fingerprint', () => {
  const reference = path.join(fixtureDirectory, 'harness-reference');
  const project = path.join(fixtureDirectory, 'harness-project');
  const inputs = {
    'tests/performance/main_scene_benchmark.gd': 'extends SceneTree\n',
    'tests/godot/player_flow_fixture.gd': 'extends RefCounted\n'
  };
  for (const directory of [reference, project]) {
    for (const [relative, content] of Object.entries(inputs)) {
      const filename = path.join(directory, relative);
      fs.mkdirSync(path.dirname(filename), { recursive: true });
      fs.writeFileSync(filename, content, { flag: 'wx' });
    }
  }
  const original = verifyProjectHarness(project, reference);
  assert.match(original.sha256, /^[a-f0-9]{64}$/);
  assert.deepEqual(original.files, Object.entries(inputs).map(([relative, content]) => ({
    path: relative, sha256: crypto.createHash('sha256').update(content).digest('hex')
  })));
  assert.deepEqual(original, verifyProjectHarness(reference, reference));

  for (const [relative, content] of Object.entries(inputs)) {
    fs.writeFileSync(path.join(project, relative), `${content}# Different protocol input\n`);
    assert.throws(() => verifyProjectHarness(project, reference), error =>
      error.message.includes('Benchmark harness mismatch') && error.message.includes(relative));
    fs.writeFileSync(path.join(reference, relative), `${content}# Different protocol input\n`);
    assert.notEqual(verifyProjectHarness(project, reference).sha256, original.sha256,
      'Simultaneous mutation of shared inputs must change the frozen fingerprint');
    fs.writeFileSync(path.join(project, relative), content);
    fs.writeFileSync(path.join(reference, relative), content);
    assert.deepEqual(verifyProjectHarness(project, reference), original);
  }
  fs.unlinkSync(path.join(project, 'tests/godot/player_flow_fixture.gd'));
  assert.throws(() => verifyProjectHarness(project, reference), /ENOENT.*player_flow_fixture/);
});

test('frame statistics use arithmetic means and nearest-rank percentiles without mutating samples', () => {
  const samples = [40, 10, 30, 20];
  assert.deepEqual(stats(samples), { count: 4, mean: 25, p50: 20, p95: 40, min: 10, max: 40 });
  assert.deepEqual(samples, [40, 10, 30, 20]);
  assert.equal(stats(Array.from({ length: 100 }, (_, index) => index + 1)).p95, 95);
});

test('acceptance reports time reduction separately from throughput-equivalent speedup', () => {
  const result = evaluate();
  near(result.geometric_mean_ratio, 0.8);
  near(result.time_reduction_percent, 20);
  near(result.throughput_equivalent_speedup_percent, 25);
  assert.equal(result.target_met, true);
  assert.equal(result.every_pair_improves, true);
  assert.equal(result.repeats, 5);
  assert.equal(result.software_renderer, true);
  assert.match(result.scope, /software graphics adapter/);
  assert.equal(result.scenarios.length, 7);
  assert.equal(result.scenarios[2].baseline_p95_us, 70000);
  assert.equal(result.scenarios[2].candidate_p95_us, 56000);
});

test('all seven scenarios have equal geometric weight even when one subsystem dominates wall time', () => {
  const result = evaluate(report(), report([1, 1, 0.5, 1, 1, 1, 1]));
  near(result.geometric_mean_ratio, Math.pow(0.5, 1 / 7));
  assert(result.time_reduction_percent < 10);
  assert.equal(result.target_met, false, 'A large isolated hotspot win cannot substitute for the full target');
});

test('the ten-percent time-reduction boundary is inclusive and smaller reductions fail', () => {
  const boundary = evaluate(report(), report(Array(7).fill(0.9)));
  near(boundary.time_reduction_percent, 10);
  assert.equal(boundary.target_met, true);
  const below = evaluate(report(), report(Array(7).fill(0.90001)));
  assert(below.time_reduction_percent < 10);
  assert.equal(below.target_met, false);
});

test('a mean regression above five percent rejects an otherwise large aggregate improvement', () => {
  const result = evaluate(report(), report([1.0501, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6]));
  assert(result.time_reduction_percent > 10);
  assert.deepEqual(result.mean_regressions_over_five_percent, ['match']);
  assert.equal(result.target_met, false);
});

test('a five-percent mean regression is the documented inclusive boundary', () => {
  const result = evaluate(report(), report([1.05, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6]));
  assert.deepEqual(result.mean_regressions_over_five_percent, []);
  assert.equal(result.target_met, true);
});

test('every independent paired repeat must improve despite a favorable pooled average', () => {
  const result = evaluate(report(), report(Array(7).fill(1), [0.7, 0.7, 0.7, 0.7, 1.02]));
  assert(result.time_reduction_percent > 10);
  assert(result.paired_repeat_ratios[4] > 1);
  assert.equal(result.every_pair_improves, false);
  assert.equal(result.target_met, false);
});

test('fewer than five repeats cannot establish acceptance', () => {
  const result = evaluate(report(Array(7).fill(1), [1, 1, 1, 1]), report(Array(7).fill(0.8), [1, 1, 1, 1]));
  assert.equal(result.repeats, 4);
  assert.equal(result.target_met, false);
});

test('diagnostic dimensions, warmup, sample count, and seed cannot be accepted as the primary profile', () => {
  for (const [key, value] of [['width', 960], ['height', 720], ['warmup', 30], ['samples', 60], ['seed', 5]]) {
    const baseline = report();
    const candidate = report(Array(7).fill(0.8));
    baseline.configuration[key] = value;
    candidate.configuration[key] = value;
    const result = evaluate(baseline, candidate);
    assert.equal(result.primary_profile, false, key);
    assert.equal(result.target_met, false, key);
  }
});

test('removing a default scenario invalidates primary acceptance even if both reports omit it', () => {
  const baseline = report();
  const candidate = report(Array(7).fill(0.8));
  for (const value of [baseline, candidate]) {
    value.scenarios = value.scenarios.filter(item => item.scenario !== 'chest');
    for (const run of value.runs) run.scenarios = run.scenarios.filter(item => item.scenario !== 'chest');
  }
  const result = evaluate(baseline, candidate);
  assert.equal(result.primary_profile, false);
  assert.equal(result.target_met, false);
});

test('comparison refuses mismatched requested configurations, harnesses, hosts, and protocols', () => {
  for (const key of ['configuration', 'harness_sha256', 'host', 'protocol']) {
    const candidate = report(Array(7).fill(0.8));
    candidate[key] = key === 'configuration' ? { ...candidate.configuration, width: 480 } : 'different';
    assert.throws(() => evaluate(report(), candidate), /Noncomparable/, key);
  }
  const candidate = report(Array(7).fill(0.8));
  candidate.runs.pop();
  assert.throws(() => evaluate(report(), candidate), /same number of repeats/);
});

test('actual engine, graphics adapter, renderer, audio and window settings are checked on every repeat', () => {
  for (const key of ['adapter', 'rendering_driver', 'audio_driver', 'window_size', 'vsync', 'reduced_motion']) {
    const candidate = report(Array(7).fill(0.8));
    candidate.runs[3].configuration[key] = 'different';
    assert.throws(() => evaluate(report(), candidate), /Engine, display, renderer, audio/, key);
  }
  const candidate = report(Array(7).fill(0.8));
  candidate.runs[4].engine.hash = 'different-engine';
  assert.throws(() => evaluate(report(), candidate), /Engine, display, renderer, audio/);
});

test('bootstrap is deterministic and resamples complete paired repeats rather than frame samples', () => {
  const ratios = [0.79, 0.82, 0.85, 0.83, 0.81];
  const result = bootstrapPairedRatios(ratios);
  assert.deepEqual(result, bootstrapPairedRatios(ratios));
  assert.equal(result.pairs, 5);
  assert.equal(result.iterations, 10000);
  assert.match(result.resampling_unit, /repeat pair; never individual frames/);
  assert(result.ratio_ci95[0] <= result.point_ratio && result.point_ratio <= result.ratio_ci95[1]);
  assert(result.ratio_ci95[1] < 1);
  near(result.time_reduction_ci95_percent[0], 100 * (1 - result.ratio_ci95[1]));
  near(result.time_reduction_ci95_percent[1], 100 * (1 - result.ratio_ci95[0]));
  assert.deepEqual(bootstrapPairedRatios([1, 1, 1, 1, 1]).ratio_ci95, [1, 1]);
  for (const invalid of [[], [0], [-1], [NaN], [Infinity]]) assert.throws(() => bootstrapPairedRatios(invalid), /positive independent-pair ratios/);
});

test('baseline snapshots preserve committed bytes and refuse existing or escaping destinations', () => {
  const repository = path.join(fixtureDirectory, 'snapshot-fixture');
  fs.mkdirSync(repository);
  const git = args => execFileSync('git', args, { cwd: repository, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  git(['init', '--quiet']);
  for (const directory of ['scripts', 'scenes', 'assets', '.godot', 'tests/performance', 'tests/godot']) fs.mkdirSync(path.join(repository, directory), { recursive: true });
  const bytes = Buffer.from([0, 13, 10, 0xff, 0x80, 0x41]);
  fs.writeFileSync(path.join(repository, 'scripts/code.gd'), 'extends Node\n');
  fs.writeFileSync(path.join(repository, 'scenes/raw.bin'), bytes);
  fs.writeFileSync(path.join(repository, 'project.godot'), 'config_version=5\n');
  fs.writeFileSync(path.join(repository, 'words.json'), '[]\n');
  fs.writeFileSync(path.join(repository, 'voice-prompts.json'), '{}\n');
  fs.writeFileSync(path.join(repository, 'tests/performance/main_scene_benchmark.gd'), 'extends SceneTree\n');
  fs.writeFileSync(path.join(repository, 'tests/godot/player_flow_fixture.gd'), 'extends RefCounted\n');
  git(['add', 'scripts', 'scenes', 'project.godot', 'words.json', 'voice-prompts.json']);
  const commitOptions = ['-c', 'user.name=Benchmark Fixture', '-c', 'user.email=benchmark-fixture@example.invalid',
    '-c', 'commit.gpgsign=false', '-c', `core.hooksPath=${path.join(repository, 'no-test-hooks')}`];
  git([...commitOptions, 'commit', '--quiet', '-m', 'Create snapshot fixture']);
  const commit = git(['rev-parse', 'HEAD']).toString('utf8').trim();
  fs.writeFileSync(path.join(repository, 'scripts/code.gd'), 'Uncommitted content must not enter the baseline.\n');
  const manifest = freezeBaseline({ repository });
  assert.equal(manifest.commit, commit);
  assert.deepEqual(fs.readFileSync(path.join(manifest.snapshot_directory, 'scenes/raw.bin')), bytes);
  assert.equal(fs.readFileSync(path.join(manifest.snapshot_directory, 'scripts/code.gd'), 'utf8'), 'extends Node\n');
  assert.equal(manifest.files.find(file => file.path === 'scenes/raw.bin').sha256, crypto.createHash('sha256').update(bytes).digest('hex'));
  for (const name of ['assets', '.godot', 'tests']) {
    assert.equal(fs.realpathSync(path.join(manifest.snapshot_directory, name)), fs.realpathSync(path.join(repository, name)));
    assert.equal(manifest.shared_directories.find(item => item.name === name).mutable, true);
  }
  const originalManifest = fs.readFileSync(path.join(manifest.snapshot_directory, 'baseline-source.json'));
  assert.throws(() => freezeBaseline({ repository }), /Refusing to replace existing/);
  assert.deepEqual(fs.readFileSync(path.join(manifest.snapshot_directory, 'baseline-source.json')), originalManifest);
  assert.throws(() => freezeBaseline({ repository, output: '../outside' }), /inside build\/performance/);
  const linkedParent = path.join(repository, 'build/performance/linked-parent');
  fs.symlinkSync(path.join(repository, 'assets'), linkedParent, process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => freezeBaseline({ repository, output: 'build/performance/linked-parent/new-baseline' }), /parents cannot be links or junctions/);
  assert.equal(fs.existsSync(path.join(repository, 'assets/new-baseline')), false);
  git(['add', 'scripts/code.gd']);
  git([...commitOptions, 'commit', '--quiet', '-m', 'Advance fixture HEAD']);
  const explicit = freezeBaseline({ repository, ref: commit, output: 'build/performance/explicit-old-commit' });
  assert.equal(explicit.commit, commit);
  assert.notEqual(git(['rev-parse', 'HEAD']).toString('utf8').trim(), commit);
  assert.equal(fs.readFileSync(path.join(explicit.snapshot_directory, 'scripts/code.gd'), 'utf8'), 'extends Node\n');
});
