const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');

function runGodot(args) {
  // Waiting for the actual process is essential with the Windows GUI executable.
  const result = spawnSync(process.env.GODOT_BIN || 'godot', args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    timeout: 180000,
    windowsHide: true
  });
  if (result.error) {
    throw new Error(`Could not run Godot: ${result.error.message}`, { cause: result.error });
  }
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (result.status !== 0 || /(?:^|\n)(?:SCRIPT )?ERROR:/m.test(output)) {
    throw new Error(`Godot failed (exit ${result.status}):\n${output}`);
  }
  return { stdout: result.stdout, stderr: result.stderr };
}

module.exports = { runGodot };

if (require.main === module) {
  const args = process.argv.slice(2);
  const result = runGodot(args);
  if (args.includes('--import')) {
    console.log('Godot resources imported.');
  } else {
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
  }
}
