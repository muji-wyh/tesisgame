const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { runGodot } = require('./run-godot.cjs');

const root = path.resolve(__dirname, '..');
const resultsRoot = path.join(root, 'build', 'performance');
const scenarios = ['match', 'memory', 'voice-pop', 'growth', 'catalog', 'chest'];
const protocol = 'main-scene-rendered-v2';

function parse(args) {
  const result = {};
  while (args.length) {
    const arg = args.shift();
    if (!arg.startsWith('--')) throw new Error(`Unexpected argument: ${arg}`);
    const [key, inline] = arg.slice(2).split('=', 2);
    if (key === 'compare') {
      result.compare = [inline || args.shift(), args.shift()];
      continue;
    }
    if (key === 'help' || key === 'paired') { result[key] = true; continue; }
    const value = inline ?? args.shift();
    if (value == null || value.startsWith('--')) throw new Error(`Missing --${key} value`);
    result[key] = value;
  }
  return result;
}

function integer(value, fallback, min = 1) {
  const number = Number(value ?? fallback);
  if (!Number.isSafeInteger(number) || number < min) throw new Error(`Invalid integer: ${value}`);
  return number;
}

function hash(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }

function verifyProjectHarness(project, referenceProject = root) {
  const files = ['tests/performance/main_scene_benchmark.gd', 'tests/godot/player_flow_fixture.gd'].map(relative => {
    const sha256 = hash(path.join(project, relative));
    if (sha256 !== hash(path.join(referenceProject, relative))) {
      throw new Error(`Benchmark harness mismatch for ${relative}: ${project} differs from ${referenceProject}`);
    }
    return { path: relative, sha256 };
  });
  return { sha256: crypto.createHash('sha256').update(JSON.stringify(files)).digest('hex'), files };
}

function sourceIdentity(project) {
  const files = [];
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const filename = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(filename);
      else if (!entry.name.endsWith('.uid')) files.push([path.relative(project, filename).replaceAll('\\', '/'), hash(filename)]);
    }
  }
  for (const directory of ['scripts', 'scenes', 'data']) visit(path.join(project, directory));
  for (const file of ['project.godot', 'words.json', 'phrases.json', 'curriculum.json', 'voice-prompts.json']) {
    const filename = path.join(project, file);
    if (fs.existsSync(filename)) files.push([file, hash(filename)]);
  }
  let commit = null;
  try { commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: project, encoding: 'utf8', windowsHide: true }).trim(); } catch {}
  return { commit, sha256: crypto.createHash('sha256').update(JSON.stringify(files)).digest('hex'), files };
}

function stats(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return {
    count: sorted.length,
    mean: values.reduce((sum, value) => sum + value, 0) / values.length,
    p50: sorted[Math.ceil(sorted.length * 0.5) - 1],
    p95: sorted[Math.ceil(sorted.length * 0.95) - 1],
    min: sorted[0], max: sorted.at(-1)
  };
}

function bootstrapPairedRatios(ratios, iterations = 10000, seed = 0x51a7cafe) {
  if (!ratios.length || ratios.some(value => !Number.isFinite(value) || value <= 0)) throw new Error('Bootstrap requires positive independent-pair ratios');
  let state = seed >>> 0;
  function random() {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = Math.imul(state ^ (state >>> 15), state | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }
  const logs = ratios.map(Math.log);
  const sampled = [];
  for (let repeat = 0; repeat < iterations; repeat++) {
    let sum = 0;
    for (let index = 0; index < logs.length; index++) sum += logs[Math.floor(random() * logs.length)];
    sampled.push(Math.exp(sum / logs.length));
  }
  sampled.sort((a, b) => a - b);
  const low = sampled[Math.ceil(iterations * 0.025) - 1];
  const high = sampled[Math.ceil(iterations * 0.975) - 1];
  return {
    resampling_unit: 'baseline/candidate repeat pair; never individual frames',
    method: 'deterministic percentile bootstrap of the paired geometric mean',
    confidence: 0.95, iterations, seed, pairs: ratios.length,
    point_ratio: Math.exp(logs.reduce((sum, value) => sum + value, 0) / logs.length),
    ratio_ci95: [low, high], time_reduction_ci95_percent: [100 * (1 - high), 100 * (1 - low)]
  };
}

function save(filename, value) {
  const relative = path.relative(resultsRoot, filename);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('Benchmark results must stay inside build/performance');
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename, `${JSON.stringify(value, null, 2)}\n`);
}

function compare(baselineFile, candidateFile) {
  const baseline = JSON.parse(fs.readFileSync(path.resolve(baselineFile), 'utf8'));
  const candidate = JSON.parse(fs.readFileSync(path.resolve(candidateFile), 'utf8'));
  for (const key of ['protocol', 'configuration', 'harness_sha256', 'host']) {
    if (JSON.stringify(baseline[key]) !== JSON.stringify(candidate[key])) throw new Error(`Noncomparable ${key}`);
  }
  if (baseline.runs.length !== candidate.runs.length) throw new Error('Use the same number of repeats');
  const reference = baseline.runs[0];
  for (const run of [...baseline.runs, ...candidate.runs]) {
    if (JSON.stringify(run.configuration) !== JSON.stringify(reference.configuration) || JSON.stringify(run.engine) !== JSON.stringify(reference.engine)) {
      throw new Error('Engine, display, renderer, audio, or measured configuration differs between runs');
    }
  }
  const rows = baseline.scenarios.map(before => {
    const after = candidate.scenarios.find(item => item.scenario === before.scenario);
    if (!after) throw new Error(`Candidate is missing ${before.scenario}`);
    return {
      scenario: before.scenario,
      baseline_mean_us: before.rendered.mean,
      candidate_mean_us: after.rendered.mean,
      baseline_p95_us: before.rendered.p95,
      candidate_p95_us: after.rendered.p95,
      rendered_ratio: after.rendered.mean / before.rendered.mean,
      time_reduction_percent: 100 * (1 - after.rendered.mean / before.rendered.mean),
      process_ratio: after.process.mean / before.process.mean
    };
  });
  if (rows.length !== candidate.scenarios.length) throw new Error('Scenario sets differ');
  const geometricMeanRatio = Math.exp(rows.reduce((sum, row) => sum + Math.log(row.rendered_ratio), 0) / rows.length);
  const pairRatios = baseline.runs.map((before, index) => {
    const after = candidate.runs[index];
    return Math.exp(rows.reduce((sum, row) => sum + Math.log(
      after.scenarios.find(item => item.scenario === row.scenario).rendered.mean /
      before.scenarios.find(item => item.scenario === row.scenario).rendered.mean), 0) / rows.length);
  });
  const regressions = rows.filter(row => row.rendered_ratio > 1.05).map(row => row.scenario);
  const bootstrap = bootstrapPairedRatios(pairRatios);
  const everyPairImproves = pairRatios.every(ratio => ratio < 1);
  const config = baseline.configuration;
  const primaryProfile = config.width === 390 && config.height === 844 && config.warmup === 90 && config.samples === 240 && config.seed === 73021
    && scenarios.every(name => rows.some(row => row.scenario === name));
  const softwareRenderer = /basic render|software|swiftshader|llvmpipe|\bwarp\b/i.test(reference.configuration.adapter || '');
  return {
    protocol, primary_metric: 'active rendered-frame wall time',
    baseline: path.resolve(baselineFile), candidate: path.resolve(candidateFile),
    repeats: baseline.runs.length, scenarios: rows,
    geometric_mean_ratio: geometricMeanRatio,
    time_reduction_percent: 100 * (1 - geometricMeanRatio),
    throughput_equivalent_speedup_percent: 100 * (1 / geometricMeanRatio - 1),
    paired_repeat_ratios: pairRatios,
    every_pair_improves: everyPairImproves,
    paired_bootstrap: bootstrap,
    primary_profile: primaryProfile,
    software_renderer: softwareRenderer,
    renderer: reference.configuration,
    collection_order: baseline.collection_order || [],
    mean_regressions_over_five_percent: regressions,
    target_met: primaryProfile && baseline.runs.length >= 5 && geometricMeanRatio <= 0.90 && regressions.length === 0 && everyPairImproves && bootstrap.ratio_ci95[1] < 1,
    scope: `Native GL Compatibility with a 60 Hz cap${softwareRenderer ? ' using a software graphics adapter' : ''}. Main-scene updates, draw preparation, and render submission through frame_post_draw. Not GPU time, phone/Web FPS, or audio latency.`
  };
}

function makeContext(project, label, configuration, repeats, harness) {
  if (verifyProjectHarness(project).sha256 !== harness.sha256) throw new Error('Benchmark protocol changed before collection');
  const directory = path.join(resultsRoot, label);
  fs.mkdirSync(directory, { recursive: true });
  return { project, label, configuration, repeats, harness, directory, source: sourceIdentity(project), runs: [] };
}

function assertUnchanged(context) {
  if (sourceIdentity(context.project).sha256 !== context.source.sha256) throw new Error(`Runtime source changed during collection: ${context.label}`);
  if (verifyProjectHarness(context.project).sha256 !== context.harness.sha256) throw new Error('Benchmark protocol changed during collection');
}

function capture(context, index, order) {
  assertUnchanged(context);
  const { project, label, configuration, repeats, source, directory } = context;
  const selected = configuration.scenarios;
  const filename = path.join(directory, `repeat-${String(index + 1).padStart(2, '0')}.json`);
  const args = ['--path', project, '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--disable-vsync', '--max-fps', '60',
    '--resolution', `${configuration.width}x${configuration.height}`, '--script', 'res://tests/performance/main_scene_benchmark.gd', '--',
    `--output=${filename}`, `--label=${label}`, `--source=${source.sha256}`, `--scenarios=${selected.join(',')}`,
    `--width=${configuration.width}`, `--height=${configuration.height}`, `--warmup=${configuration.warmup}`,
    `--samples=${configuration.samples}`, `--seed=${configuration.seed}`];
  console.log(`Running ${label} ${index + 1}/${repeats}: ${selected.join(', ')} at ${configuration.width}x${configuration.height}`);
  const startedAt = new Date().toISOString();
  const result = runGodot(args, { timeout: Math.max(180000, selected.length * 45000) });
  fs.writeFileSync(path.join(directory, `repeat-${String(index + 1).padStart(2, '0')}.log`), `${result.stdout}${result.stderr}`);
  const report = JSON.parse(fs.readFileSync(filename, 'utf8'));
  if (report.protocol !== protocol || report.source !== source.sha256 || JSON.stringify(report.scenarios.map(item => item.scenario)) !== JSON.stringify(selected)) throw new Error('Incomplete or mismatched benchmark report');
  if (report.configuration.display_server === 'headless' || report.configuration.rendering_method !== 'gl_compatibility'
    || report.configuration.vsync !== 0 || report.configuration.max_fps !== 60
    || JSON.stringify(report.configuration.window_size) !== JSON.stringify([configuration.width, configuration.height])) throw new Error('Invalid renderer, resolution, or frame pacing');
  for (const item of report.scenarios) {
    if (item.rendered_us.length !== configuration.samples || item.process_us.length !== configuration.samples
      || item.frame_interval_us.length !== configuration.samples - 1
      || item.rendered_us.some(value => !Number.isFinite(value) || value <= 0)
      || item.process_us.some((value, position) => !Number.isFinite(value) || value <= 0 || value > item.rendered_us[position])) {
      throw new Error(`Invalid raw samples: ${item.scenario}`);
    }
    if (item.scenario === 'voice-pop') {
      for (const [countsKey, framesKey, peakKey] of [['target_counts', 'target_frame_count', 'target_peak'], ['drawn_target_counts', 'drawn_target_frame_count', 'drawn_target_peak']]) {
        const counts = item[countsKey];
        if (!Array.isArray(counts) || counts.length !== configuration.samples || counts.some(value => !Number.isSafeInteger(value) || value < 0)
          || counts.filter(value => value > 0).length !== item[framesKey] || Math.max(...counts) !== item[peakKey]
          || item[framesKey] < Math.ceil(configuration.samples * 0.25)) throw new Error(`Invalid target workload evidence: ${item.scenario}`);
      }
    }
  }
  assertUnchanged(context);
  context.runs.push(report);
  order.push({ ordinal: order.length + 1, pair: index + 1, label, file: filename, started_at: startedAt, completed_at: new Date().toISOString() });
  process.stdout.write(result.stdout.split('\n').filter(line => line.startsWith('BENCHMARK ')).join('\n') + '\n');
}

function summarize(context, order) {
  assertUnchanged(context);
  const { label, configuration, source, harness, runs, directory } = context;
  const summary = {
    protocol, label, configuration, source, harness_sha256: harness.sha256, harness_files: harness.files,
    host: { platform: os.platform(), release: os.release(), cpu: os.cpus()[0]?.model, logical_cpus: os.cpus().length },
    collection_order: order, runs,
    scenarios: configuration.scenarios.map(scenario => {
      const samples = runs.map(run => run.scenarios.find(item => item.scenario === scenario));
      return { scenario, rendered: stats(samples.flatMap(item => item.rendered_us)), process: stats(samples.flatMap(item => item.process_us)),
        frame_interval: stats(samples.flatMap(item => item.frame_interval_us)), repeat_means_us: samples.map(item => item.rendered.mean) };
    })
  };
  const filename = path.join(directory, 'summary.json');
  save(filename, summary);
  console.log(`Saved ${filename}`);
  return filename;
}

function showComparison(comparison, filename) {
  save(filename, comparison);
  console.table(comparison.scenarios.map(row => ({ scenario: row.scenario, baseline_us: row.baseline_mean_us.toFixed(2), candidate_us: row.candidate_mean_us.toFixed(2), reduction: `${row.time_reduction_percent.toFixed(2)}%`, p95_us: row.candidate_p95_us.toFixed(2) })));
  console.log(`Equal-weight geometric mean time reduction: ${comparison.time_reduction_percent.toFixed(2)}%; target met: ${comparison.target_met}`);
  console.log(`Every pair improves: ${comparison.every_pair_improves}; paired bootstrap 95% time-reduction interval: ${comparison.paired_bootstrap.time_reduction_ci95_percent.map(value => value.toFixed(2)).join(' to ')}%`);
  console.log(`Renderer: ${comparison.renderer.adapter}; software renderer: ${comparison.software_renderer}`);
  console.log(`Saved ${filename}`);
}

function main() {
  const options = parse(process.argv.slice(2));
  if (options.help) {
    console.log('node tools/benchmark-performance.cjs --paired --baseline-project PATH --label native-paired --repeats 5\nnode tools/benchmark-performance.cjs --label baseline --project PATH --repeats 5\nnode tools/benchmark-performance.cjs --label candidate --repeats 5\nnode tools/benchmark-performance.cjs --compare build/performance/baseline/summary.json build/performance/candidate/summary.json\nOptional: --scenarios match,memory,... --width 390 --height 844 --warmup 90 --samples 240 --seed 73021');
    return;
  }
  if (options.compare) {
    showComparison(compare(...options.compare), path.join(resultsRoot, 'comparison.json'));
    return;
  }
  const label = options.label || 'diagnostic';
  if (!/^[a-z0-9][a-z0-9_-]*$/i.test(label)) throw new Error('Label must contain only letters, digits, underscores, and hyphens');
  const project = path.resolve(options.project || root);
  const selected = options.scenarios ? options.scenarios.split(',') : scenarios;
  if (new Set(selected).size !== selected.length || selected.some(name => !scenarios.includes(name))) throw new Error('Invalid scenario list');
  const configuration = {
    scenarios: selected, width: integer(options.width, 390), height: integer(options.height, 844),
    warmup: integer(options.warmup, 90, 2), samples: integer(options.samples, 240), seed: integer(options.seed, 73021, 0),
    fps: 60, vsync: false, renderer: 'gl_compatibility', audio: 'Dummy', reduced_motion: false
  };
  const repeats = integer(options.repeats, 5);
  const harness = verifyProjectHarness(root);
  const order = [];
  if (options.paired) {
    if (!options['baseline-project']) throw new Error('--paired requires --baseline-project');
    const baseline = makeContext(path.resolve(options['baseline-project']), `${label}-baseline`, configuration, repeats, harness);
    const candidate = makeContext(project, `${label}-candidate`, configuration, repeats, harness);
    for (let index = 0; index < repeats; index++) {
      const pair = index % 2 === 0 ? [baseline, candidate] : [candidate, baseline];
      for (const context of pair) capture(context, index, order);
      save(path.join(resultsRoot, label, 'collection-order.json'), order);
    }
    const baselineFile = summarize(baseline, order);
    const candidateFile = summarize(candidate, order);
    showComparison(compare(baselineFile, candidateFile), path.join(resultsRoot, label, 'comparison.json'));
  } else {
    const context = makeContext(project, label, configuration, repeats, harness);
    for (let index = 0; index < repeats; index++) capture(context, index, order);
    summarize(context, order);
  }
}

if (require.main === module) main();
module.exports = { compare, stats, bootstrapPairedRatios, verifyProjectHarness };
