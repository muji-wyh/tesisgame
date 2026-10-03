const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const { prepare, inlineMascot } = require('./prepare-godot.cjs');
const { packageWebExport, collectRequiredAudio } = require('./package-web.cjs');
const { snapshotInputs, invalidateBuildReceipt, writeBuildReceipt } = require('./web-build-receipt.cjs');

const root = path.resolve(__dirname, '..');
invalidateBuildReceipt(root);
prepare();
runGodot(['--headless', '--path', root, '--import']);
const audio = collectRequiredAudio(root);
const inputs = snapshotInputs(root);
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
  ...(fs.existsSync(path.join(root, 'assets/imported-audio/pop-slice.wav')) ? ['--require-pop-slice'] : []),
  ...(fs.existsSync(path.join(root, 'assets/imported-audio/pop-slices')) ? ['--require-pop-slices'] : []),
  ...(audio.some(file => file.source.startsWith('res://assets/imported-audio/pop-reference/')) ? ['--require-pop-reference'] : []),
  ...audio.flatMap(file => [file.source, file.imported])
]);
process.stdout.write(verification.stdout);
const downloadBytes = packageWebExport(output);
fs.copyFileSync(path.join(root, 'web', 'staticwebapp.config.json'), path.join(output, 'staticwebapp.config.json'));
fs.copyFileSync(path.join(root, 'web', 'map-credits.html'), path.join(output, 'map-credits.html'));
fs.copyFileSync(path.join(root, 'assets', 'fonts', 'OFL.txt'), path.join(output, 'nunito-license.txt'));
writeBuildReceipt(root, inputs);
console.log(`Godot Web game exported to build\\web (${(downloadBytes / 1000000).toFixed(2)} MB startup; ${audio.length} music, prompt, chest and optional slice assets verified inside the game pack).`);
