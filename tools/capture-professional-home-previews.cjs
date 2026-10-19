const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const output = path.resolve(__dirname, '../build/professional-english');
fs.mkdirSync(output, { recursive: true });
const result = runGodot(['--path', '.', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle',
  '--audio-driver', 'Dummy', '--disable-vsync', '--max-fps', '30', '--resolution', '1280x800',
  '--script', 'res://tools/capture-professional-home-previews.gd']);
fs.writeFileSync(path.join(output, 'home-preview-render.log'), result.stdout + result.stderr);
const report = JSON.parse(fs.readFileSync(path.join(output, 'home-preview-render-report.json'), 'utf8'));
if (report.failures.length || report.captures.length !== 40) throw new Error('Home preview renderer checks did not complete.');
const cards = report.captures.map(capture => `<figure><a href="${capture.file}"><img src="${capture.file}" alt="${capture.stage} at ${capture.viewport.join(' by ')}"></a><figcaption>${capture.viewport.join(' × ')} · ${capture.stage}</figcaption></figure>`).join('\n');
fs.writeFileSync(path.join(output, 'home-preview-render-gallery.html'), `<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Professional Home preview renderer review</title>
<style>body{font:16px system-ui;max-width:1500px;margin:32px auto;padding:0 20px;background:#eef5f1;color:#183c35}.gallery{display:flex;flex-wrap:wrap;gap:20px;align-items:flex-start}figure{margin:0;max-width:440px}img{max-width:100%;max-height:650px;border-radius:12px}figcaption{padding:8px 0}p{max-width:900px}</style>
<h1>Professional Home preview renderer review</h1><p>${report.notice}</p><p>${report.checks} checks passed. Actual ${report.renderer} rendering. <a href="home-preview-render-report.json">Capture and geometry report</a></p><div class="gallery">${cards}</div></html>\n`);
process.stdout.write(result.stdout);
console.log(`Gallery: ${path.join(output, 'home-preview-render-gallery.html')}`);
