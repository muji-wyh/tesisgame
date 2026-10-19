'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const output = path.join(__dirname, 'scene-disposal-r01');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
if (fs.existsSync(output)) throw Error('One-shot witness already exists; preserve it and use an affected supplement.');
const probe = 'tests/godot/professional_scene_disposal_tests.gd';
if (digest(fs.readFileSync(path.join(root, probe))) !== 'eaf0c87b4f928a2b81c01ed80b7dcf822d5b3e19abbf8a5c5aa73e53631eb8ab') throw Error('Frozen probe changed.');
const files = ['project.godot', 'tools/run-godot.cjs', 'tools/run-tests.cjs',
  'assets/images/words/absent.png', 'assets/audio/jelly-match/collect-do.wav'];
for (const directory of ['scripts', 'tests/godot', 'scenes']) {
  for (const name of fs.readdirSync(path.join(root, directory))) {
    if (/\.(gd|tscn)$/.test(name)) files.push(directory + '/' + name);
  }
}
files.sort();
const snapshot = () => files.map(file => {
  const raw = fs.readFileSync(path.join(root, file));
  return {path: file, bytes: raw.length, sha256: digest(raw)};
});
fs.mkdirSync(output);
const before = snapshot(), started = new Date().toISOString(), results = [];
fs.writeFileSync(path.join(output, 'inputs-before.json'), JSON.stringify(before, null, 2) + '\n', {flag: 'wx'});
for (const syntax of [true, false]) {
  const args = ['tools/run-godot.cjs', '--headless', '--path', '.', ...(syntax ? ['--check-only'] : []), '--script', 'res://' + probe];
  const label = syntax ? 'syntax' : 'runtime';
  const began = new Date().toISOString();
  const run = spawnSync(process.execPath, args, {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 200000, maxBuffer: 32 * 1024 * 1024});
  const log = (run.stdout || '') + (run.stderr || '');
  fs.writeFileSync(path.join(output, label + '.log'), log, {flag: 'wx'});
  const ok = run.status === 0 && !run.error && !/(?:^|\n)(?:SCRIPT )?ERROR:|^FAIL:/m.test(log);
  const result = {label, command: [process.execPath, ...args], started_at: began, finished_at: new Date().toISOString(),
    exit_code: run.status, signal: run.signal, error: run.error?.message || null, log_sha256: digest(Buffer.from(log)), ok};
  results.push(result);
  fs.writeFileSync(path.join(output, label + '.json'), JSON.stringify(result, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({...result, summary: log.split(/\r?\n/).filter(line => /checks|failures|ERROR|FAIL:|Scene disposal observation/.test(line)).slice(-24)}));
  if (!ok) break;
}
const after = snapshot();
fs.writeFileSync(path.join(output, 'inputs-after.json'), JSON.stringify(after, null, 2) + '\n', {flag: 'wx'});
const report = {schema_version: 1, started_at: started, finished_at: new Date().toISOString(), results,
  planned_executions: 2, inputs_unchanged: JSON.stringify(before) === JSON.stringify(after), input_count: before.length,
  ok: results.length === 2 && results.every(row => row.ok) && JSON.stringify(before) === JSON.stringify(after),
  scope: 'Actual scene disposal with synthetic owner/media and held host response; no compiled Web, human media, curriculum or device acceptance.'};
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({ok: report.ok, executions: results.length, inputs_unchanged: report.inputs_unchanged, receipt_sha256: digest(fs.readFileSync(path.join(output, 'receipt.json')))}));
process.exitCode = report.ok ? 0 : 1;
