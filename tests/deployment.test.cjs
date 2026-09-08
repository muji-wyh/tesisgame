const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const script = path.join(root, 'tools', 'deploy-web.ps1');
const subscription = '2909b61b-7489-445e-9039-2fd51429745b';
const hostname = 'gentle-forest-02ff42900.3.azurestaticapps.net';

function runDeployment(mode = 'success', skipBuild = false) {
  assert.ok(fs.existsSync(script), 'The reusable deployment script is missing.');
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', `
    $calls = [System.Collections.Generic.List[object]]::new()
    $env:SWA_CLI_DEPLOYMENT_TOKEN = 'previous-test-token'
    $before = (Get-Location).Path
    function npm {
      $calls.Add(@{ command = 'npm'; arguments = @($args) })
      $global:LASTEXITCODE = ${mode === 'build-failure' ? 9 : 0}
    }
    function az {
      $calls.Add(@{ command = 'az'; arguments = @($args) })
      $global:LASTEXITCODE = 0
      if ($args -contains 'show') {
        return '{"defaultHostname":"${mode === 'wrong-target' ? 'wrong.azurestaticapps.net' : hostname}"}'
      }
      $global:LASTEXITCODE = ${mode === 'token-failure' ? 7 : 0}
      return '${mode === 'empty-token' ? '' : 'new-test-token'}'
    }
    function swa {
      if ($env:SWA_CLI_DEPLOYMENT_TOKEN -ne 'new-test-token') { throw 'Missing process token.' }
      $calls.Add(@{ command = 'swa'; arguments = @($args) })
      $global:LASTEXITCODE = ${mode === 'deploy-failure' ? 8 : 0}
    }
    $failure = $null
    try { & '${script.replaceAll("'", "''")}' -SkipBuild:$${skipBuild ? 'true' : 'false'} }
    catch { $failure = $_.Exception.Message }
    $result = @{
      calls = @($calls.ToArray()); failure = $failure
      tokenRestored = $env:SWA_CLI_DEPLOYMENT_TOKEN -eq 'previous-test-token'
      locationRestored = (Get-Location).Path -eq $before
    }
    Write-Output ('RESULT:' + ($result | ConvertTo-Json -Depth 5 -Compress))
  `], { cwd: require('node:os').tmpdir(), encoding: 'utf8', timeout: 20000 });
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stdout + result.stderr, /new-test-token|previous-test-token/);
  const line = result.stdout.split(/\r?\n/).find(value => value.startsWith('RESULT:'));
  assert.ok(line, result.stdout + result.stderr);
  const report = JSON.parse(line.slice(7));
  assert.equal(report.tokenRestored, true);
  assert.equal(report.locationRestored, true);
  return report;
}

test('the deployment command builds and publishes only to the explicitly scoped personal Azure app',
  { skip: process.platform !== 'win32' }, () => {
    const report = runDeployment();
    assert.equal(report.failure, null);
    assert.deepEqual(report.calls.map(call => call.command), ['npm', 'az', 'az', 'swa']);
    assert.deepEqual(report.calls[0].arguments, ['run', 'build:web']);
    for (const call of report.calls.filter(call => call.command === 'az')) {
      const args = call.arguments;
      assert.equal(args[args.indexOf('--subscription') + 1], subscription);
      assert.equal(args[args.indexOf('--name') + 1], 'tesisgame');
      assert.equal(args[args.indexOf('--resource-group') + 1], 'rg-footises');
    }
    assert.deepEqual(report.calls.at(-1).arguments, [
      'deploy', '.\\build\\web', '--swa-config-location', '.\\web', '--env', 'production'
    ]);
    const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
    assert.match(pkg.scripts.deploy, /powershell.*-File tools[\\/]deploy-web\.ps1/);
  });

test('an explicit SkipBuild deploy reuses the existing export without rebuilding',
  { skip: process.platform !== 'win32' }, () => {
    const report = runDeployment('success', true);
    assert.equal(report.failure, null);
    assert.deepEqual(report.calls.map(call => call.command), ['az', 'az', 'swa']);
  });

for (const mode of ['build-failure', 'wrong-target', 'token-failure', 'empty-token', 'deploy-failure']) {
  test(`deployment fails safely on ${mode} and restores the caller environment`,
    { skip: process.platform !== 'win32' }, () => {
      const report = runDeployment(mode);
      assert.ok(report.failure, `${mode} was incorrectly reported as successful.`);
      if (mode !== 'deploy-failure') assert.equal(report.calls.some(call => call.command === 'swa'), false);
      if (mode === 'build-failure') assert.deepEqual(report.calls.map(call => call.command), ['npm']);
      if (mode === 'wrong-target') assert.equal(report.calls.filter(call => call.command === 'az').length, 1);
    });
}
