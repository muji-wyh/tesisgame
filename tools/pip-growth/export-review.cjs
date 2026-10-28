const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createHash } = require('node:crypto');
const { chromium } = require('@playwright/test');
const { runGodot } = require('../run-godot.cjs');

const root = path.resolve(__dirname, '..', '..');
const destination = path.join(root, 'web', 'preview', 'pip-growth');
const parts = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot'];

async function main() {
  process.stdout.write(runGodot(['--headless', '--audio-driver', 'Dummy', '--path', '.',
    '--script', 'res://tools/pip-growth/export-review.gd']).stdout);
  const filename = path.join(destination, 'action-catalog.json');
  const catalog = JSON.parse(fs.readFileSync(filename, 'utf8'));
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8');
  const source = shell.slice(shell.indexOf('      function pipReaction(name) {'),
    shell.indexOf('      function playWithDuck('));
  const labels = shell.slice(shell.indexOf('      const pipReactionLabels = {'),
    shell.indexOf('      function clearLoadingPipReaction()'));
  const anchor = shell.slice(shell.indexOf('      function anchorLoadingWings(pose) {'),
    shell.indexOf('      function canPlayLoadingInteraction()'));
  if (!source || !labels || !anchor) throw new Error('The maintained loading Pip functions are unavailable.');
  const definitions = vm.runInNewContext(`${labels}\n${source}\nObject.fromEntries(Object.keys(pipReactionLabels).map(id => [id, { ...pipReaction(id), label: pipReactionLabels[id] }]))`);
  const origins = Object.fromEntries(parts.map(part => {
    const match = shell.match(new RegExp(`#loading-pip-${part}\\s*\\{\\s*transform-origin:\\s*([^;]+);`));
    if (!match) throw new Error(`Missing loading joint: ${part}`);
    return [part, match[1].trim().split(/\s+/).map(parseFloat)];
  }));
  const viewBox = shell.match(/<button id="loading-duck"[\s\S]*?<svg viewBox="([^"]+)"/)?.[1].split(' ').map(Number);
  if (viewBox?.length !== 4) throw new Error('Missing loading Pip viewBox.');
  const browser = await chromium.launch({ headless: true });
  let loading;
  try {
    const page = await browser.newPage();
    await page.setContent(parts.map(part => `<div id="${part}" style="width:120px;height:120px;transform-origin:${origins[part].map(value => value + 'px').join(' ')}"></div>`).join(''));
    loading = await page.evaluate(({ anchor, definitions, origins, parts, viewBox, fps }) => {
      const anchorPose = new Function('loadingPipJoints', `${anchor}\nreturn anchorLoadingWings;`)(origins);
      const scale = 120 / Math.max(viewBox[2], viewBox[3]);
      const base = new DOMMatrix([scale, 0, 0, scale,
        (120 - viewBox[2] * scale) / 2 - viewBox[0] * scale,
        (120 - viewBox[3] * scale) / 2 - viewBox[1] * scale]);
      const frame = () => ({
        mode: 'parts', face: '',
        shadow: [base.a * 60 + base.e, base.d * 114 + base.f, scale * 28, scale * 4, .14],
        parts: parts.map(name => {
          const [x, y] = origins[name];
          const transform = new DOMMatrix(getComputedStyle(document.getElementById(name)).transform);
          const matrix = base.translate(x, y).multiply(transform).translate(-x, -y);
          return [matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f].map(value => Math.round(value * 100000) / 100000);
        })
      });
      return Object.entries(definitions).map(([id, definition]) => {
        const beats = definition.beats.map(([offset, pose]) => [offset, anchorPose(pose)]);
        const animations = parts.map(name => {
          const element = document.getElementById(name);
          element.style.transform = '';
          const animation = element.animate(beats.map(([offset, pose]) => ({
            offset, transform: pose[name] || 'translate(0, 0) rotate(0deg)', easing: 'ease-in-out'
          })), { duration: definition.duration, fill: 'both' });
          animation.pause();
          return animation;
        });
        const count = Math.ceil(definition.duration / 1000 * fps) + 1;
        const frames = Array.from({ length: count }, (_, index) => {
          animations.forEach(animation => { animation.currentTime = index / (count - 1) * definition.duration; });
          return frame();
        });
        animations.forEach(animation => animation.cancel());
        const still = anchorPose(definition.still);
        parts.forEach(name => { document.getElementById(name).style.transform = still[name] || 'none'; });
        return { id: `loading:${id}`, label: definition.label, category: 'loading', kind: 'loading',
          seconds: definition.duration / 1000, source: 'web/shell.html: pipReaction',
          description: 'Existing loading-screen tap response, sampled from its real Web Animations timing. Uses the original Spring wardrobe; no loading sounds are played.',
          performances: { loading: { frames, reduced: frame() } } };
      });
    }, { anchor, definitions: JSON.parse(JSON.stringify(definitions)), origins, parts, viewBox, fps: catalog.fps });
  } finally { await browser.close(); }
  const artwork = 'assets/images/mascots/storybook/pip-spring-parts.svg';
  fs.copyFileSync(path.join(root, ...artwork.split('/')), path.join(destination, 'art', 'pip-loading-parts.svg'));
  catalog.contexts = { loading: { age: 'loading', label: 'Loading screen', name: 'Spring Pip',
    accent: '#3c8771', background: '#eaf3e7', cellSize: 120,
    previewArt: { parts: 'art/pip-loading-parts.svg' }, originalArt: artwork } };
  catalog.native_performances = catalog.performances;
  catalog.actions.push(...loading);
  catalog.performances += loading.length;
  catalog.scope = 'Existing native and loading-screen character poses, expressions and shadows. Audio, particles and rewards are not replayed.';
  for (const file of ['web/shell.html', 'tools/prepare-godot.cjs', 'tools/pip-growth/export-review.cjs', artwork]) {
    catalog.sources[file] = createHash('sha256').update(fs.readFileSync(path.join(root, ...file.split('/')))).digest('hex');
  }
  fs.writeFileSync(filename, JSON.stringify(catalog) + '\n');
  console.log(`Complete Pip review: ${catalog.actions.length} actions/states, ${catalog.performances} performances, including all ${loading.length} loading tap responses.`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
