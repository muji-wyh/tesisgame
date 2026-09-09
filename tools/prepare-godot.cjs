const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function prepare() {
  const modules = path.join(root, 'node_modules');
  if (fs.existsSync(modules)) {
    fs.writeFileSync(path.join(modules, '.gdignore'), '');
  }
  fs.mkdirSync(path.join(root, 'build', 'web'), { recursive: true });
  fs.writeFileSync(path.join(root, 'build', '.gdignore'), '');
}

function inlineMascot(html) {
  if (!html.includes('$PIP_MASCOT_URI')) throw new Error('The web shell is missing the Pip mascot placeholder.');
  const svg = fs.readFileSync(path.join(root, 'assets', 'images', 'mascots', 'pip.svg'));
  return html.replaceAll('$PIP_MASCOT_URI', `data:image/svg+xml;base64,${svg.toString('base64')}`);
}

module.exports = { prepare, inlineMascot };

if (require.main === module) prepare();
