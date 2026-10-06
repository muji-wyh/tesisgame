const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const INPUTS = [
  'assets', 'scenes', 'scripts', 'web', 'project.godot', 'export_presets.cfg',
  'package.json', 'package-lock.json', 'words.json', 'voice-prompts.json',
  'docs/assets/voice-pop-reference-audio.json', 'docs/assets/pair-feedback-audio.json',
  'docs/assets/ui-click-audio.json',
  'tests/godot/verify_web_pack.gd',
  ...['build-web', 'package-web', 'patch-web-engine', 'prepare-godot', 'run-godot', 'ui-click-audio', 'web-build-receipt']
    .map(name => `tools/${name}.cjs`)
];
const receiptPath = root => path.join(root, 'build', 'web-build.json');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

function inventory(root, entries) {
  const files = [];
  function visit(relative) {
    const filename = path.join(root, relative);
    if (!fs.existsSync(filename)) return;
    const stat = fs.lstatSync(filename);
    if (stat.isSymbolicLink()) throw new Error(`Web build inputs cannot be symbolic links: ${relative}`);
    if (stat.isDirectory()) {
      for (const name of fs.readdirSync(filename)) visit(`${relative}/${name}`);
    } else if (stat.isFile()) {
      const bytes = fs.readFileSync(filename);
      files.push({ path: relative.replaceAll('\\', '/'), bytes: bytes.length, sha256: digest(bytes) });
    }
  }
  for (const entry of entries) visit(entry);
  return files.sort((first, second) => first.path.localeCompare(second.path, 'en'));
}

function snapshotInputs(root) {
  return inventory(root, INPUTS);
}

function changedFiles(expected, actual) {
  const before = new Map(expected.map(file => [file.path, `${file.bytes}:${file.sha256}`]));
  const after = new Map(actual.map(file => [file.path, `${file.bytes}:${file.sha256}`]));
  return [...new Set([...before.keys(), ...after.keys()])]
    .filter(filename => before.get(filename) !== after.get(filename)).sort();
}

function invalidateBuildReceipt(root) {
  fs.rmSync(receiptPath(root), { force: true });
}

function exportInventory(root) {
  const directory = path.join(root, 'build', 'web');
  for (const name of ['index.html', 'staticwebapp.config.json']) {
    if (!fs.existsSync(path.join(directory, name))) throw new Error(`Missing Web export file: ${name}`);
  }
  const html = fs.readFileSync(path.join(directory, 'index.html'), 'utf8');
  const config = JSON.parse(html.match(/const config = (\{[^\r\n]*\});/)?.[1] || 'null');
  if (!config || !/^engine-[a-f0-9]{16}$/.test(config.executable) ||
      !/^game-[a-f0-9]{16}\.pck$/.test(config.mainPack)) {
    throw new Error('The Web export has not been packaged with versioned engine and game files.');
  }
  const required = [...['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']
    .map(suffix => `${config.executable}.${suffix}`), config.mainPack];
  for (const name of required) {
    for (const filename of [name, `${name}.br`]) {
      if (!fs.existsSync(path.join(directory, filename)) || !fs.statSync(path.join(directory, filename)).size) {
        throw new Error(`Missing Web export file: ${filename}`);
      }
    }
  }
  return inventory(directory, fs.readdirSync(directory));
}

function writeBuildReceipt(root, beforeExport) {
  const sources = snapshotInputs(root), changed = changedFiles(beforeExport, sources);
  if (changed.length) {
    throw new Error(`Web build inputs changed during export: ${changed.slice(0, 5).join(', ')}. Rebuild before deploying.`);
  }
  const receipt = { version: 1, createdAt: new Date().toISOString(), sources, output: exportInventory(root) };
  const filename = receiptPath(root), temporary = `${filename}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(receipt, null, 2)}\n`);
  fs.renameSync(temporary, filename);
  return receipt;
}

function verifyBuildReceipt(root) {
  const filename = receiptPath(root);
  if (!fs.existsSync(filename)) throw new Error('Missing successful Web build receipt. Run npm run build:web before deploying.');
  let receipt;
  try { receipt = JSON.parse(fs.readFileSync(filename, 'utf8')); }
  catch { throw new Error('Invalid Web build receipt. Run npm run build:web before deploying.'); }
  const validInventory = value => Array.isArray(value) && value.length > 0 && value.every(file =>
    file && typeof file.path === 'string' && Number.isSafeInteger(file.bytes) && file.bytes >= 0 && /^[a-f0-9]{64}$/.test(file.sha256));
  if (receipt?.version !== 1 || !validInventory(receipt.sources) || !validInventory(receipt.output)) {
    throw new Error('Invalid Web build receipt. Run npm run build:web before deploying.');
  }
  const sources = changedFiles(receipt.sources, snapshotInputs(root));
  if (sources.length) throw new Error(`Stale Web build: source files changed (${sources.slice(0, 5).join(', ')}). Run npm run build:web.`);
  const output = changedFiles(receipt.output, exportInventory(root));
  if (output.length) throw new Error(`Web export changed after its successful build (${output.slice(0, 5).join(', ')}). Run npm run build:web.`);
  return receipt;
}

module.exports = { snapshotInputs, invalidateBuildReceipt, writeBuildReceipt, verifyBuildReceipt };

if (require.main === module) {
  try {
    if (process.argv.slice(2).join(' ') !== '--verify') throw new Error('Usage: node tools/web-build-receipt.cjs --verify');
    const receipt = verifyBuildReceipt(path.resolve(__dirname, '..'));
    console.log(`Verified Web build: ${receipt.sources.length} source inputs and ${receipt.output.length} output files are unchanged.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
