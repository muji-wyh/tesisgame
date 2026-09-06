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

module.exports = { prepare };

if (require.main === module) prepare();
