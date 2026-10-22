const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { runGodot } = require('./run-godot.cjs');

const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(`--${name}`);
  return index < 0 ? fallback : args[index + 1];
};
const baselineOption = option('baseline');
if (!baselineOption) throw new Error('Pass --baseline with the path to a frozen source snapshot.');
const baseline = path.resolve(root, baselineOption);
const label = option('label', 'jelly-drag-cpu');
if (!/^[a-z0-9-]+$/.test(label)) throw new Error('Use a lowercase output label.');
const output = path.join(root, 'build', 'performance', label);
if (fs.existsSync(output)) throw new Error(`Refusing to overwrite ${output}`);
const repeats = Number(option('repeats', 5));
const samples = Number(option('samples', 120));
if (!Number.isInteger(repeats) || repeats < 1 || !Number.isInteger(samples) || samples < 1) {
  throw new Error('Repeats and samples must be positive integers.');
}
if (!fs.existsSync(path.join(baseline, 'baseline-source.json'))) throw new Error('Create a frozen baseline first.');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const fingerprint = project => {
  const files = [];
  const collect = relative => {
    const filename = path.join(project, relative);
    if (fs.statSync(filename).isDirectory()) {
      for (const child of fs.readdirSync(filename).sort()) collect(path.join(relative, child));
    } else files.push([relative.replaceAll('\\', '/'), hash(filename)]);
  };
  for (const scope of ['scripts', 'scenes', 'data', 'project.godot', 'words.json', 'phrases.json', 'curriculum.json', 'voice-prompts.json']) collect(scope);
  return crypto.createHash('sha256').update(JSON.stringify(files)).digest('hex');
};
const harness = ['tests/performance/word_jelly_drag_benchmark.gd', 'tests/performance/jelly_drag_fixture.gd'];
const harnessHashes = harness.map(file => [file, hash(path.join(root, file))]);
const projects = { baseline, candidate: root };
const fingerprints = Object.fromEntries(Object.entries(projects).map(([name, project]) => [name, fingerprint(project)]));
const verify = () => {
  for (const [name, project] of Object.entries(projects)) {
    if (fingerprint(project) !== fingerprints[name]) throw new Error(`${name} runtime changed during collection`);
    for (const [file, expected] of harnessHashes) if (hash(path.join(project, file)) !== expected) throw new Error('Harness changed during collection');
  }
};
const stats = values => {
  const sorted = [...values].sort((a, b) => a - b);
  return { mean_us: values.reduce((sum, n) => sum + n, 0) / values.length,
    p95_us: sorted[Math.ceil(sorted.length * .95) - 1], p99_us: sorted[Math.ceil(sorted.length * .99) - 1] };
};
fs.mkdirSync(output, { recursive: true });
const reports = { baseline: [], candidate: [] };
const order = [];
for (let repeat = 0; repeat < repeats; repeat++) {
  for (const name of repeat % 2 ? ['candidate', 'baseline'] : ['baseline', 'candidate']) {
    verify();
    const file = path.join(output, `${name}-${repeat + 1}.json`);
    const result = runGodot(['--headless', '--path', projects[name], '--script', 'res://tests/performance/word_jelly_drag_benchmark.gd',
      '--', `--samples=${samples}`, `--output=${file.replaceAll('\\', '/')}`], { timeout: 300000 });
    fs.writeFileSync(path.join(output, `${name}-${repeat + 1}.log`), result.stdout + result.stderr);
    const report = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (report.protocol !== 'word-jelly-drag-cpu-v1' || report.rows.length !== 8 || report.rows.some(row => row.samples_us.length !== samples)) {
      throw new Error('Incomplete diagnostic report');
    }
    reports[name].push(report);
    if (reports.baseline[repeat] && reports.candidate[repeat]) {
      for (let scenario = 0; scenario < 8; scenario++) {
        const before = reports.baseline[repeat].rows[scenario], after = reports.candidate[repeat].rows[scenario];
        if (JSON.stringify(before.interaction_trace) !== JSON.stringify(after.interaction_trace) ||
            before.contact_frames !== after.contact_frames) {
          throw new Error(`Interaction mismatch in repeat ${repeat + 1}, scenario ${scenario + 1}`);
        }
      }
    }
    order.push({ repeat: repeat + 1, name });
    verify();
    console.log(`Completed ${name} ${repeat + 1}/${repeats}`);
  }
}
const comparisons = reports.baseline[0].rows.map((row, index) => {
  const summarize = name => {
    const rows = reports[name].map(report => report.rows[index]);
    return { ...stats(rows.flatMap(item => item.samples_us)), repeat_mean_us: rows.map(item => stats(item.samples_us).mean_us),
      position_passes_per_frame: rows.reduce((sum, item) => sum + item.position_passes, 0) / (samples * repeats),
      snapshots_per_frame: rows.reduce((sum, item) => sum + item.snapshots, 0) / (samples * repeats),
      serialized_characters_per_frame: rows.reduce((sum, item) => sum + item.serialized_characters, 0) / (samples * repeats),
      contact_frames: rows.map(item => item.contact_frames) };
  };
  const before = summarize('baseline'), after = summarize('candidate');
  return { tiles: row.tiles, contact: row.contact, motion_events_per_frame: row.motion_events_per_frame,
    baseline: before, candidate: after, mean_reduction_percent: (1 - after.mean_us / before.mean_us) * 100 };
});
const summary = { protocol: 'word-jelly-drag-cpu-v1', scope: reports.candidate[0].scope, repeats, samples,
  engine: reports.candidate[0].engine, baseline, fingerprints, harness: harnessHashes, order, comparisons };
fs.writeFileSync(path.join(output, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
console.table(comparisons.map(row => ({ tiles: row.tiles, contact: row.contact, events: row.motion_events_per_frame,
  baseline_ms: +(row.baseline.mean_us / 1000).toFixed(3), candidate_ms: +(row.candidate.mean_us / 1000).toFixed(3),
  reduction: `${row.mean_reduction_percent.toFixed(1)}%` })));
console.log(`Saved ${path.join(output, 'summary.json')}. CPU diagnostic only; no Web FPS claim.`);
