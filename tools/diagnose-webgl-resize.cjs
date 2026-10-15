const fs = require('node:fs');
const path = require('node:path');
const { chromium, webkit, devices } = require('@playwright/test');

async function colorCount(page, png) {
  return page.evaluate(async base64 => {
    const image = new Image();
    image.src = `data:image/png;base64,${base64}`;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
    const colors = new Set();
    for (let y = 4; y < canvas.height; y += 8) for (let x = 4; x < canvas.width; x += 8) {
      const offset = (y * canvas.width + x) * 4;
      colors.add(`${data[offset] >> 4},${data[offset + 1] >> 4},${data[offset + 2] >> 4}`);
    }
    return colors.size;
  }, png.toString('base64'));
}

async function diagnose(browserName) {
  const output = path.resolve(__dirname, '../build/webgl-resize-diagnostics', browserName);
  fs.mkdirSync(output, { recursive: true });
  const browser = await ({ chromium, webkit })[browserName].launch();
  try {
    const context = await browser.newContext({ ...devices['iPhone 13'], viewport: { width: 390, height: 664 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.setContent('<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}canvas{width:100%;height:100%;display:block}</style>' +
      '<canvas id="canvas"></canvas>');
    await page.evaluate(() => {
      const canvas = document.getElementById('canvas');
      const gl = canvas.getContext('webgl2', { alpha: false, antialias: true, depth: true, stencil: false, preserveDrawingBuffer: true });
      if (!gl) throw new Error('WebGL 2 is unavailable.');
      function resize() {
        canvas.width = Math.round(innerWidth * devicePixelRatio);
        canvas.height = Math.round(innerHeight * devicePixelRatio);
      }
      resize();
      window.addEventListener('resize', resize);
      function draw() {
        gl.viewport(0, 0, canvas.width, canvas.height);
        gl.enable(gl.SCISSOR_TEST);
        for (let index = 0; index < 16; index++) {
          gl.scissor(index * canvas.width / 16, 0, canvas.width / 16 + 1, canvas.height);
          gl.clearColor(index / 16, 1 - index / 16, 0.5, 1);
          gl.clear(gl.COLOR_BUFFER_BIT);
        }
        requestAnimationFrame(draw);
      }
      draw();
    });
    const samples = [];
    async function capture(name) {
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const composed = await page.screenshot({ path: path.join(output, `${name}-page.png`), scale: 'css' });
      const raw = Buffer.from(await page.locator('#canvas').evaluate(canvas => canvas.toDataURL().split(',')[1]), 'base64');
      fs.writeFileSync(path.join(output, `${name}-canvas.png`), raw);
      samples.push({
        name, viewport: page.viewportSize(), pageColors: await colorCount(page, composed), canvasColors: await colorCount(page, raw),
        graphics: await page.locator('#canvas').evaluate(canvas => {
          const gl = canvas.getContext('webgl2');
          return { width: canvas.width, height: canvas.height, contextLost: gl.isContextLost(), error: gl.getError() };
        })
      });
    }
    await capture('initial');
    await page.setViewportSize({ width: 320, height: 568 });
    await capture('resized');
    await page.waitForTimeout(3100);
    await capture('resized-after-three-seconds');
    const passed = !errors.length && samples.every(sample => sample.pageColors >= 16 && sample.canvasColors >= 16 &&
      !sample.graphics.contextLost && sample.graphics.error === 0);
    const report = { browser: browserName, browserVersion: browser.version(), platform: process.platform,
      playwrightVersion: require('@playwright/test/package.json').version, passed, samples, errors };
    fs.writeFileSync(path.join(output, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
    console.log(JSON.stringify({ browser: browserName, passed, samples, errors, output }));
    return passed;
  } finally {
    await browser.close();
  }
}

const args = process.argv.slice(2);
if (args.length !== 2 || args[0] !== '--browser' || !['chromium', 'webkit'].includes(args[1])) {
  console.error('Usage: node tools/diagnose-webgl-resize.cjs --browser chromium|webkit');
  process.exitCode = 2;
} else {
  diagnose(args[1]).then(passed => { process.exitCode = passed ? 0 : 1; })
    .catch(error => { console.error(error); process.exitCode = 1; });
}
