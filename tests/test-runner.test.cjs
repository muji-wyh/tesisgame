const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { groups, allGroups, createPlan } = require('../tools/run-tests.cjs');

const root = path.resolve(__dirname, '..');
const runner = path.join(root, 'tools', 'run-tests.cjs');

test('the default plan runs every Godot and Node test file exactly once', () => {
  const plan = createPlan();
  const godot = fs.readdirSync(path.join(root, 'tests', 'godot'))
    .filter(file => file.endsWith('_tests.gd')).map(file => `tests/godot/${file}`);
  const node = fs.readdirSync(path.join(root, 'tests'))
    .filter(file => file.endsWith('.test.cjs')).map(file => `tests/${file}`);
  assert.deepEqual(plan.godot.map(suite => suite.file).sort(), godot.sort());
  assert.deepEqual([...plan.node].sort(), node.sort());
  assert.deepEqual([...allGroups].sort(), Object.keys(groups).sort());
  for (const name of allGroups) {
    const group = createPlan([name]);
    assert.ok(group.godot.length + group.node.length > 0, `Empty test group: ${name}`);
  }
});

test('overlapping selections do not repeat suites and vocabulary keeps its fixed frame rate', () => {
  assert.deepEqual(createPlan(['all', 'chest-charge', 'voice-pop', 'pip-audio', 'all']), createPlan());
  const plan = createPlan(['ages']);
  assert.deepEqual(plan.godot.find(suite => suite.file.endsWith('/vocabulary_layout_tests.gd')).options,
    ['--fixed-fps', '60']);
  assert.ok(plan.godot.filter(suite => !suite.file.endsWith('/vocabulary_layout_tests.gd'))
    .every(suite => suite.options.length === 0));
});

test('npm keeps import preparation and every focused suite alias in the explicit runner', () => {
  const { scripts } = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  assert.equal(scripts.pretest, 'npm run import');
  assert.equal(scripts.test, 'node tools/run-tests.cjs all');
  assert.equal(scripts.posttest, undefined);
  for (const name of allGroups.filter(name => name !== 'core')) {
    assert.equal(scripts[`test:${name}`], `node tools/run-tests.cjs ${name}`);
  }
});

test('the CLI lists the plan, rejects unknown groups and propagates engine startup failures', () => {
  const options = {
    cwd: root, encoding: 'utf8', windowsHide: true,
    env: { ...process.env, GODOT_BIN: path.join(root, 'missing-test-godot') }
  };
  const listed = spawnSync(process.execPath, [runner, 'all', '--list'], options);
  assert.equal(listed.error, undefined);
  assert.equal(listed.status, 0, listed.stderr);
  const plan = createPlan();
  const lines = listed.stdout.trim().split(/\r?\n/);
  assert.equal(lines.length, plan.godot.length + plan.node.length);
  assert.equal(new Set(lines).size, lines.length);
  for (const suite of plan.godot) assert.ok(lines.some(line => line.startsWith(`Godot: ${suite.file}`)));
  for (const file of plan.node) assert.ok(lines.includes(`Node: ${file}`));

  const invalid = spawnSync(process.execPath, [runner, 'missing-group', '--list'], options);
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /Unknown test group: missing-group/);
  assert.equal(invalid.stdout, '');

  const failed = spawnSync(process.execPath, [runner, 'cards'], options);
  assert.equal(failed.status, 1);
  assert.match(failed.stderr, /Could not run Godot/);
  assert.doesNotMatch(failed.stdout, /Passed \d+ Godot suites/);
});
