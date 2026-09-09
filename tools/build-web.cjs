const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const { prepare, inlineMascot } = require('./prepare-godot.cjs');
const { packageWebExport, collectOptionalAudio } = require('./package-web.cjs');

const root = path.resolve(__dirname, '..');
prepare();
runGodot(['--headless', '--path', root, '--import']);
const audio = collectOptionalAudio(root);
runGodot(['--headless', '--path', root, '--export-release', 'Web', path.join(root, 'build', 'web', 'index.html')]);
for (const filename of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
  const output = path.join(root, 'build', 'web', filename);
  if (!fs.existsSync(output) || fs.statSync(output).size === 0) {
    throw new Error(`The Godot Web export did not produce ${filename}`);
  }
}
const output = path.join(root, 'build', 'web');
const htmlPath = path.join(output, 'index.html');
fs.writeFileSync(htmlPath, inlineMascot(fs.readFileSync(htmlPath, 'utf8')));
const verification = runGodot([
  '--headless', '--path', output, '--main-pack', path.join(output, 'index.pck'),
  '--script', path.join(root, 'tests', 'godot', 'verify_web_pack.gd'), '--',
  ...audio.flatMap(file => [file.source, file.imported])
]);
process.stdout.write(verification.stdout);
const downloadBytes = packageWebExport(output, audio);
fs.copyFileSync(path.join(root, 'web', 'staticwebapp.config.json'), path.join(output, 'staticwebapp.config.json'));
console.log(`Godot Web game exported to build\\web (${(downloadBytes / 1000000).toFixed(2)} MB startup, ${audio.length} on-demand audio assets).`);
