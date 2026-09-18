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
  html = html.replaceAll('$PIP_MASCOT_URI', `data:image/svg+xml;base64,${svg.toString('base64')}`);
  if (!html.includes('$PIP_WARDROBE_JSON')) return html;
  const partNames = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot'];
  const outfits = Object.fromEntries(['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'].map(theme => {
    const directory = path.join(root, 'assets/images/mascots/outfits');
    const sprite = fs.readFileSync(path.join(directory, `pip-${theme}.svg`));
    const parts = danceFrames(fs.readFileSync(path.join(directory, `pip-${theme}-parts.svg`), 'utf8'));
    return [theme, { sprite: `data:image/svg+xml;base64,${sprite.toString('base64')}`,
      parts: Object.fromEntries(partNames.map((name, index) => [name, parts[index]])) }];
  }));
  return html.replaceAll('$PIP_WARDROBE_JSON', JSON.stringify(outfits).replaceAll('<', '\\u003c'));
}

function danceFrames(svg) {
  const frames = [];
  let depth = 0, start = 0;
  // Each atlas frame is a direct child of its shared stroke group. Preserve
  // the inner head/body transforms, but remove the atlas column translation.
  for (const match of svg.matchAll(/<g\b[^>]*>|<\/g>/g)) {
    if (match[0] === '</g>') {
      if (depth === 2) frames.push(svg.slice(start, match.index));
      depth--;
    } else {
      depth++;
      if (depth === 2) start = match.index + match[0].length;
    }
  }
  if (depth !== 0 || frames.length !== 6) throw new Error('Pip dance atlas needs six balanced limb groups.');
  return frames;
}

module.exports = { prepare, inlineMascot };

if (require.main === module) prepare();
