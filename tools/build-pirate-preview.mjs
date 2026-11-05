import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { readFile, writeFile, mkdir } from 'node:fs/promises';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(process.argv[2] || 'Q:/uwok/boss');
const output = path.resolve(process.argv[3] || path.join(source, 'game-ready/index.html'));
const { build } = await import(pathToFileURL(path.join(source, 'node_modules/esbuild/lib/main.js')));
const viewerSource = (await readFile(path.join(source, 'viewer-source.js'), 'utf8'))
  .replace('object.receiveShadow = true;', 'object.receiveShadow = false;').replace(
  'const bounds = new THREE.Box3().setFromObject(model);',
  `const bounds = new THREE.Box3();
  const restPoint = new THREE.Vector3();
  model.traverse(mesh => {
    if (!mesh.isMesh) return;
    for (let index = 0; index < mesh.geometry.attributes.position.count; index++) {
      mesh.getVertexPosition(index, restPoint).applyMatrix4(mesh.matrixWorld);
      bounds.expandByPoint(restPoint);
    }
  });`
);
const result = await build({
  stdin: { contents: viewerSource, resolveDir: source, sourcefile: 'pirate-game-viewer.js' },
  bundle: true, minify: true, format: 'iife', target: ['es2020'],
  write: false, legalComments: 'none'
});
const [template, model, license] = await Promise.all([
  readFile(path.join(source, 'index.template.html'), 'utf8'),
  readFile(path.join(root, 'assets/pirate/pirate-game.glb')),
  readFile(path.join(source, 'node_modules/three/LICENSE'), 'utf8')
]);
const html = template
  .replace('__MODEL_BASE64__', () => model.toString('base64'))
  .replace('__VIEWER_SCRIPT__', () => result.outputFiles[0].text.replace(/<\/script/gi, '<\\/script'))
  .replace('<title>', '<title>Game-ready / ')
  .replace('</head>', () => `<!-- Three.js 0.170.0 license\n${license}\n-->\n</head>`);
if (/__MODEL_BASE64__|__VIEWER_SCRIPT__/.test(html)) throw new Error('Unresolved preview placeholder.');
await mkdir(path.dirname(output), { recursive: true });
await writeFile(output, html);
console.log(`Built optimized offline preview: ${output} (${Buffer.byteLength(html)} bytes)`);
