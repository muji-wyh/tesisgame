const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const { prepare, inlineMascot } = require('./prepare-godot.cjs');
const { packageWebExport, collectRequiredAudio } = require('./package-web.cjs');
const { snapshotInputs, invalidateBuildReceipt, writeBuildReceipt } = require('./web-build-receipt.cjs');
const { writeVocabularyPlan } = require('./vocabulary-packs.cjs');

const root = path.resolve(__dirname, '..');
const professionalAudit = require('./validate-professional-content.cjs').auditProfessionalContent({ rootDir: root });
if (!professionalAudit.ok) throw new Error('Professional content audit failed: ' + professionalAudit.errors.map(issue => issue.message).join('; '));
const growthMorphologyAudit = require('./validate-growth-morphology.cjs').auditGrowthMorphology({ rootDir: root });
if (!growthMorphologyAudit.ok) throw new Error('Growth morphology audit failed: ' + growthMorphologyAudit.errors.map(issue => issue.message).join('; '));
invalidateBuildReceipt(root);
prepare();
require('./lv3-vocabulary-art.cjs').checkLv3Art(root);
require('./lv3-vocabulary-art.cjs').checkWordMotion(root);
require('./word-library-art.cjs').checkWordLibrary(root);
require('./word-library-motion.cjs').checkWordLibraryMotion(root);
require('./prepare-jelly-reward-art.cjs').checkJellyRewardArt(root);
require('./prepare-chest-milestone-art.cjs').checkChestMilestoneArt(root);
require('./prepare-coin-art.cjs').checkCoinArt(root);
runGodot(['--headless', '--path', root, '--import']);
const vocabulary = writeVocabularyPlan(root);
process.stdout.write(runGodot(['--headless', '--path', root, '--script',
  'res://tools/pack-vocabulary.gd', '--', vocabulary.manifest]).stdout);
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
// The expanded phrase bank exceeds Windows' command-line limit as path pairs.
const audioManifest = path.join(root, 'build', 'required-web-audio.json');
fs.writeFileSync(audioManifest, JSON.stringify(audio.flatMap(file => [file.source, file.imported])));
// Native pack verification must finish before packaging removes the raw PCK.
const verification = runGodot([
  '--headless', '--path', output, '--main-pack', path.join(output, 'index.pck'),
  '--script', path.join(root, 'tests', 'godot', 'verify_web_pack.gd'), '--',
  ...(fs.existsSync(path.join(root, 'assets/imported-audio/pop-slice.wav')) ? ['--require-pop-slice'] : []),
  ...(fs.existsSync(path.join(root, 'assets/imported-audio/pop-slices')) ? ['--require-pop-slices'] : []),
  ...(audio.some(file => file.source.startsWith('res://assets/imported-audio/pop-reference/')) ? ['--require-pop-reference'] : []),
  '--audio-manifest', audioManifest,
  '--vocabulary-manifest', vocabulary.manifest
]);
process.stdout.write(verification.stdout);
const downloadBytes = packageWebExport(output, vocabulary.packs);
require('./package-professional-media.cjs').packageProfessionalMedia(root, output);
fs.copyFileSync(path.join(root, 'web', 'staticwebapp.config.json'), path.join(output, 'staticwebapp.config.json'));
fs.copyFileSync(path.join(root, 'web', 'map-credits.html'), path.join(output, 'map-credits.html'));
fs.copyFileSync(path.join(root, 'assets', 'fonts', 'OFL.txt'), path.join(output, 'nunito-license.txt'));
writeBuildReceipt(root, inputs);
console.log(`Godot Web game exported to build\\web (${(downloadBytes / 1000000).toFixed(2)} MB core startup plus the selected age pack; ten on-demand vocabulary packs and ${audio.length} audio resources verified).`);
