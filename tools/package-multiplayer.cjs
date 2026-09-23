const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function packageMultiplayer(root, output) {
  for (const name of ['multiplayer-host.js', 'multiplayer-capture.js', 'multiplayer-audio.js', 'multiplayer-worker.js',
    'voice-profiles.js', 'voice-profiles-ui.js', 'voice-profiles.css']) {
    fs.copyFileSync(path.join(root, 'web', name), path.join(output, name));
  }
  const source = path.join(root, 'build', 'multiplayer');
  const manifestPath = path.join(source, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error('Local multiplayer assets are missing. Run npm run prepare:multiplayer before building the Web export.');
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!Array.isArray(manifest.assets) || !manifest.assets.length) throw new Error('Multiplayer asset manifest is empty.');
  const destination = path.join(output, 'multiplayer');
  fs.mkdirSync(destination, { recursive: true });
  let total = 0;
  const names = new Set();
  for (const asset of manifest.assets) {
    if (typeof asset.id !== 'string' || !/^[a-z0-9-]+$/.test(asset.id)) throw new Error('Multiplayer asset IDs must be safe filenames.');
    if (typeof asset.url !== 'string' || /(^[\/\\]|\.\.|:)/.test(asset.url)) throw new Error('Multiplayer assets must use relative paths.');
    const input = path.join(source, asset.url);
    const bytes = fs.readFileSync(input);
    const hash = createHash('sha256').update(bytes).digest('hex');
    if (hash !== asset.sha256 || bytes.length !== asset.bytes) throw new Error(`Multiplayer asset failed verification: ${asset.id}`);
    // Content-address every model and runtime so cached versions cannot mix.
    const name = `${asset.id}-${hash.slice(0, 16)}${path.extname(asset.url)}`;
    names.add(name);
    fs.writeFileSync(path.join(destination, name), bytes);
    asset.url = name;
    total += bytes.length;
  }
  fs.writeFileSync(path.join(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  // This generated directory is deployed in full. Keep its size bounded across
  // repeated local builds by removing only our obsolete content-addressed files.
  for (const entry of fs.readdirSync(destination, { withFileTypes: true })) {
    if (entry.isFile() && /^[a-z0-9-]+-[a-f0-9]{16}\.(?:onnx|txt|js|wasm)$/.test(entry.name) && !names.has(entry.name)) {
      fs.unlinkSync(path.join(destination, entry.name));
    }
  }
  const notices = path.join(source, 'THIRD_PARTY_NOTICES.txt');
  if (fs.existsSync(notices)) fs.copyFileSync(notices, path.join(destination, 'THIRD_PARTY_NOTICES.txt'));
  return total;
}

module.exports = { packageMultiplayer };
