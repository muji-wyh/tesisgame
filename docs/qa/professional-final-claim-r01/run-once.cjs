'use strict';

// Authoring this file does not dispatch it. The coordinating agent owns execution.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const proposal = __dirname;
const root = path.resolve(proposal, '../../..');
const attempt = path.join(proposal, 'attempt-001');
const sha256 = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const expectedInventory = process.argv[2] || '';
const inventoryPath = path.join(proposal, 'inventory.json');
if (!/^[a-f0-9]{64}$/.test(expectedInventory) || sha256(inventoryPath) !== expectedInventory) {
  throw new Error('Supply the independently reviewed inventory SHA-256 as the only argument.');
}
if (process.argv.length !== 3) throw new Error('Exactly one inventory SHA-256 argument is required.');
const executable = process.env.GODOT_BIN || '';
if (!path.isAbsolute(executable) || !fs.statSync(executable).isFile()) {
  throw new Error('GODOT_BIN must be the absolute path to the approved existing native Godot executable.');
}
const inventory = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
const inputs = JSON.parse(fs.readFileSync(path.join(proposal, 'inputs.json'), 'utf8'));
const receipt = {
  schema: 1,
  probe: 'final-claim-after-preflight-r01',
  started_at: new Date().toISOString(),
  status: 'started',
  root,
  attempt,
  inventory_sha256: expectedInventory,
  executable: { path: executable, sha256: sha256(executable) },
  steps: [],
  verification: []
};

function verify(label) {
  const checked = [];
  for (const [base, entries] of [[proposal, inventory.files], [root, inputs.inputs]]) {
    for (const entry of entries) {
      const file = path.resolve(base, entry.path);
      const relative = path.relative(base, file);
      if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
        throw new Error(`Invalid frozen input path: ${entry.path}`);
      }
      const actual = sha256(file);
      checked.push({ path: entry.path, sha256: actual });
      if (actual !== entry.sha256) throw new Error(`Frozen input changed: ${entry.path}`);
    }
  }
  receipt.verification.push({ label, at: new Date().toISOString(), count: checked.length });
}

function saveReceipt() {
  fs.writeFileSync(path.join(attempt, 'receipt.json'), JSON.stringify(receipt, null, 2) + '\n');
}

function dispatch(name, args) {
  verify(`before-${name}`);
  const step = { name, command: executable, args, cwd: root, started_at: new Date().toISOString() };
  receipt.steps.push(step);
  saveReceipt();
  const started = Date.now();
  const result = spawnSync(executable, args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    timeout: 180000,
    windowsHide: true
  });
  step.duration_ms = Date.now() - started;
  step.status = result.status;
  step.signal = result.signal;
  step.error = result.error ? { name: result.error.name, code: result.error.code, message: result.error.message } : null;
  step.stdout = `${name}.stdout.log`;
  step.stderr = `${name}.stderr.log`;
  fs.writeFileSync(path.join(attempt, step.stdout), result.stdout || '');
  fs.writeFileSync(path.join(attempt, step.stderr), result.stderr || '');
  step.stdout_sha256 = sha256(path.join(attempt, step.stdout));
  step.stderr_sha256 = sha256(path.join(attempt, step.stderr));
  saveReceipt();
  verify(`after-${name}`);
  if (result.error || result.status !== 0 || /(?:^|\n)(?:SCRIPT )?ERROR:/m.test(`${result.stdout || ''}\n${result.stderr || ''}`)) {
    throw new Error(`The ${name} process failed. Retain this attempt and review its logs; do not rerun r01.`);
  }
}

// Atomic creation consumes r01 once, even when later verification or a process fails.
fs.mkdirSync(attempt);
try {
  saveReceipt();
  verify('initial');
  const prefix = ['--headless', '--path', root];
  dispatch('check-ui', [...prefix, '--check-only', '--script', 'res://build/professional-english/final-claim-after-preflight-r01/probe_ui.gd']);
  dispatch('check-probe', [...prefix, '--check-only', '--script', 'res://build/professional-english/final-claim-after-preflight-r01/probe.gd']);
  dispatch('native-probe', [...prefix, '--script', 'res://build/professional-english/final-claim-after-preflight-r01/probe.gd', '--', attempt]);
  const resultPath = path.join(attempt, 'result.json');
  const result = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
  if (result.status !== 'passed' || result.failures !== 0 || result.checks < 80
      || !result.observations.final_gate || !result.observations.synchronous_rejection
      || !result.observations.restored) {
    throw new Error('The structured result does not establish all required witness stages.');
  }
  receipt.result = { path: 'result.json', sha256: sha256(resultPath), checks: result.checks, failures: result.failures };
  receipt.status = 'passed';
} catch (error) {
  receipt.status = 'failed';
  receipt.error = { name: error.name, message: error.message, stack: error.stack };
  process.exitCode = 1;
} finally {
  receipt.finished_at = new Date().toISOString();
  saveReceipt();
}
process.stdout.write(JSON.stringify({ status: receipt.status, receipt: path.join(attempt, 'receipt.json'), result: receipt.result || null }) + '\n');
