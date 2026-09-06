const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const { prepare } = require('./prepare-godot.cjs');

const root = path.resolve(__dirname, '..');
prepare();
runGodot(['--headless', '--path', root, '--import']);
runGodot(['--headless', '--path', root, '--export-release', 'Web', path.join(root, 'build', 'web', 'index.html')]);
for (const filename of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
  const output = path.join(root, 'build', 'web', filename);
  if (!fs.existsSync(output) || fs.statSync(output).size === 0) {
    throw new Error(`The Godot Web export did not produce ${filename}`);
  }
}
console.log('Godot Web game exported to build\\web.');
