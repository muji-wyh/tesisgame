const fs = require('node:fs');
const path = require('node:path');
const { runGodot } = require('./run-godot.cjs');
const output = path.resolve(__dirname, '../build/professional-english/theme-review');
fs.mkdirSync(output, { recursive: true });
const result = runGodot(['--path', '.', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle',
  '--audio-driver', 'Dummy', '--disable-vsync', '--max-fps', '30', '--resolution', '1280x800',
  '--script', 'res://tools/render-professional-theme-review.gd']);
fs.writeFileSync(path.join(output, 'render.log'), result.stdout + result.stderr);
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
