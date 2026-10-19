'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const mode = process.argv[2];
assert(['baseline', 'candidate'].includes(mode));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const json = value => JSON.stringify(value, null, 2) + '\n';
const prep = path.join(root, 'build/professional-english/foundation02-third10-delivery-preparation-r01/execution-r01');
const preparation = read(path.join(prep, 'preparation-receipt.json'));
assert.equal(preparation.status, 'frozen_preparation_pending_independent_technical_review');
assert.equal(read(path.join(prep, 'execution-end.json')).status, 'prepared_pending_independent_technical_review');
const sourcePins = preparation.measured_input_sha256;
function checkInputs() {
  for (const [file, expected] of Object.entries(sourcePins)) assert.equal(hash(fs.readFileSync(path.join(root, file))), expected, file);
  for (const row of [...preparation.source_files, ...preparation.artifacts]) assert.equal(hash(fs.readFileSync(path.join(root, row.path))), row.raw_sha256, row.path);
}
checkInputs();
const output = path.join(__dirname, mode);
assert(!fs.existsSync(output), 'Preserve the prior one-shot execution.');
fs.mkdirSync(output);
const started = new Date().toISOString(), commands = [], copies = [];
let ok = false, failure = null;
const write = (file, raw) => { fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, raw, {flag: 'wx'}); };
function run(args) {
  const began = new Date().toISOString();
  const result = spawnSync(process.execPath, args, {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 600000, maxBuffer: 32 * 1024 * 1024});
  const raw = Buffer.from((result.stdout || '') + (result.stderr || ''));
  const name = `command-${commands.length + 1}.log`;
  write(path.join(output, name), raw);
  const row = {command: [process.execPath, ...args], started_at: began, finished_at: new Date().toISOString(), exit_code: result.status, signal: result.signal, error: result.error?.message || null, log: name, log_sha256: hash(raw)};
  commands.push(row);
  assert.equal(result.error, undefined, row.error || 'command error');
  assert.equal(result.status, 0, raw.toString('utf8').slice(-6000));
  assert(!/(?:^|\n)(?:SCRIPT )?ERROR:/.test(raw.toString('utf8')));
}
try {
  if (mode === 'baseline') {
    run(['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs']);
    run(['tools/run-godot.cjs', '--headless', '--path', root, '--script', 'res://tests/godot/professional_retail_morphology_tests.gd']);
  } else {
    const project = path.join(output, 'project');
    fs.mkdirSync(project);
    function copy(file, bytes = fs.readFileSync(path.join(root, file)), source = file) {
      write(path.join(project, file), bytes);
      copies.push({path: file, source, bytes: bytes.length, sha256: hash(bytes)});
    }
    function walk(relative) {
      for (const item of fs.readdirSync(path.join(root, relative), {withFileTypes: true})) {
        const file = relative + '/' + item.name;
        assert(!item.isSymbolicLink(), file);
        if (item.isDirectory()) walk(file);
        else if (item.isFile()) copy(file);
      }
    }
    walk('data/professional');
    walk('data/vocabulary/morphology');
    for (const file of ['words.json', 'scripts/morphology_analysis.gd', 'scripts/morphology_resolver.gd', 'scripts/growth_morphology.gd']) copy(file);
    const overlays = [
      ['data/professional/lexemes/foundation-module02.json', 'foundation-module02.json.after'],
      ['data/professional/sources.json', 'sources.json.after'],
      ['data/professional/provenance/foundation-module02-language-third10-2026-10-17.json', 'accepted-language.json'],
      ['tests/godot/professional_retail_morphology_tests.gd', 'professional_retail_morphology_tests.gd.after']
    ];
    for (const [file, source] of overlays) {
      const bytes = fs.readFileSync(path.join(prep, source));
      if (fs.existsSync(path.join(project, file))) {
        const original = fs.readFileSync(path.join(project, file));
        write(path.join(output, 'preimages', file), original);
        fs.writeFileSync(path.join(project, file), bytes);
        copies.splice(copies.findIndex(row => row.path === file), 1);
        copies.push({path: file, source: path.relative(root, path.join(prep, source)).replaceAll('\\', '/'), bytes: bytes.length, sha256: hash(bytes)});
      } else copy(file, bytes, path.relative(root, path.join(prep, source)).replaceAll('\\', '/'));
    }
    copy('project.godot', Buffer.from('config_version=5\n\n[application]\nconfig/name="Professional Language Native Candidate"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'), 'root-authored isolated test configuration');
    write(path.join(output, 'copied-inputs.json'), json(copies));
    run(['tools/run-godot.cjs', '--headless', '--path', project, '--check-only', '--script', 'res://tests/godot/professional_retail_morphology_tests.gd']);
    run(['tools/run-godot.cjs', '--headless', '--path', project, '--script', 'res://tests/godot/professional_retail_morphology_tests.gd']);
    for (const row of copies) assert.equal(hash(fs.readFileSync(path.join(project, row.path))), row.sha256, row.path);
  }
  checkInputs();
  ok = true;
} catch (error) { failure = error.stack || String(error); }
const receipt = {schema: 1, ok, mode, started_at: started, finished_at: new Date().toISOString(), preparation: {path: path.relative(root, path.join(prep, 'preparation-receipt.json')).replaceAll('\\', '/'), sha256: hash(fs.readFileSync(path.join(prep, 'preparation-receipt.json')))}, current_inputs: sourcePins, current_input_count: Object.keys(sourcePins).length, commands, copied_input_count: copies.length, error: failure, scope: mode === 'baseline' ? 'Fresh current affected Node content/morphology and native morphology baseline. No whole-repository or browser validation.' : 'Exact native afterimage parsed and executed in an isolated copied content project. No production mutation or persisted integration acceptance.'};
const raw = Buffer.from(json(receipt));
write(path.join(output, 'receipt.json'), raw);
console.log(json({ok,mode,commands,error:failure,receipt_sha256:hash(raw)}));
process.exitCode = ok ? 0 : 1;
