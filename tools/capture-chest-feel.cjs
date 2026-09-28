// Requires imported Godot resources, FFmpeg, and ffprobe on PATH (or their
// GODOT_BIN, FFMPEG_BIN, and FFPROBE_BIN overrides). Run without arguments for
// all eight themes; pass theme names for a subset or --convert-only to reuse
// existing Movie Maker recordings. Outputs are isolated under build/.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { runGodot } = require('./run-godot.cjs');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'build', 'chest-feel');
const themes = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const stages = [
  { id: 'rest', name: 'Rest', time: 0.2 },
  { id: 'pressure', name: 'Pressure', time: 1.2 },
  { id: 'unlock', name: 'Unlock', time: 2.23 },
  { id: 'release', name: 'Release', time: 2.48 },
  { id: 'opening', name: 'Opening', time: 2.72 },
  { id: 'settled', name: 'Settled', time: 3.5 }
];

function run(binary, args) {
  const result = spawnSync(binary, args, {
    cwd: root, encoding: 'utf8', windowsHide: true,
    timeout: 180000, maxBuffer: 16 * 1024 * 1024
  });
  if (result.error || result.status !== 0) {
    throw new Error(`${binary} failed: ${result.error || result.stderr || result.stdout}`);
  }
  return result;
}

function provenance() {
  const files = ['scripts/chest_view.gd', 'scripts/chest_feel.gd', 'scripts/game_audio.gd',
    'scripts/chest_sound_bank.gd', 'tools/capture-chest-feel.gd', 'assets/chests/rigs.json'];
  return Object.fromEntries(files.map(file => [file,
    crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex')]));
}

function render(theme) {
  const captured = runGodot(['--path', '.', '--resolution', '960x720', '--fixed-fps', '60',
    '--write-movie', `build/chest-feel/${theme}.avi`, '--script', 'res://tools/capture-chest-feel.gd',
    '--', `--theme=${theme}`]);
  fs.writeFileSync(path.join(output, `${theme}.log`), captured.stdout + captured.stderr);
  const line = captured.stdout.split(/\r?\n/).find(value => value.startsWith('{"cues":'));
  if (!line) throw new Error(`The ${theme} capture did not report its physical cue sequence.`);
  return JSON.parse(line);
}

function validateCapture(captured, theme) {
  const expected = ['press:0', 'cancel:0', 'press:0', 'charge_step:1', 'charge_step:2',
    'charge_step:3', 'opening:0', 'unlock:0', 'release:0', 'settle:0'];
  const actual = captured.cues.map(cue => `${cue.cue}:${cue.step}`);
  if (captured.theme !== theme || JSON.stringify(actual) !== JSON.stringify(expected) ||
      captured.cues.some(cue => cue.theme !== theme) || captured.state.opening_time !== 1.8) {
    throw new Error(`The ${theme} recording has an incomplete or duplicated physical cue sequence.`);
  }
  const opening = captured.cues.find(cue => cue.cue === 'opening').time;
  const press = captured.cues[2].time;
  const tolerance = 1 / 60 + 0.001;
  if (opening - press < 1.2 - 0.001 || opening - press > 1.2 + tolerance) {
    throw new Error(`The ${theme} recording did not preserve the complete 1.2-second hold.`);
  }
  for (const [name, seconds] of [['unlock', 0.12], ['release', 0.32], ['settle', 0.95]]) {
    const elapsed = captured.cues.find(cue => cue.cue === name).time - opening;
    if (elapsed < seconds - 0.001 || elapsed > seconds + tolerance) {
      throw new Error(`The ${theme} ${name} cue is early or outside the one-frame capture tolerance.`);
    }
  }
  for (const cue of captured.cues.filter(value => value.cue === 'charge_step')) {
    if (Math.abs(cue.time - press - cue.step * 0.4) > tolerance) {
      throw new Error(`The ${theme} charge milestone ${cue.step} is out of time.`);
    }
  }
}

function convert(theme, captured) {
  validateCapture(captured, theme);
  const avi = path.join(output, `${theme}.avi`);
  const mp4 = path.join(output, `${theme}.mp4`);
  // This maps Movie Maker's actual mixed game audio. Missing audio is a hard
  // error; no substitute soundtrack or normalization is introduced here.
  run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
    '-i', avi, '-map', '0:v:0', '-map', '0:a:0', '-vf', 'crop=640:640:160:40',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', mp4]);
  const probe = JSON.parse(run(process.env.FFPROBE_BIN || 'ffprobe', ['-v', 'error',
    '-show_streams', '-show_format', '-of', 'json', mp4]).stdout);
  const video = probe.streams.find(stream => stream.codec_type === 'video');
  const audio = probe.streams.find(stream => stream.codec_type === 'audio');
  if (!audio || video?.width !== 640 || video?.height !== 640 || Number(probe.format.duration) < 5) {
    throw new Error(`The ${theme} preview is missing audio, square video, or the complete five-second sequence.`);
  }
  const meter = run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-i', mp4,
    '-vn', '-af', 'volumedetect', '-f', 'null', '-']).stderr;
  const mean = Number(meter.match(/mean_volume:\s*(-?[\d.]+) dB/)?.[1]);
  const peak = Number(meter.match(/max_volume:\s*(-?[\d.]+) dB/)?.[1]);
  if (!Number.isFinite(mean) || !Number.isFinite(peak) || peak <= -90) {
    throw new Error(`The ${theme} preview audio is silent or cannot be measured.`);
  }
  for (const stage of stages) {
    run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      '-ss', String(stage.time), '-i', mp4, '-frames:v', '1',
      path.join(output, `${theme}-${stage.id}.png`)]);
  }
  const inputs = stages.flatMap(stage => ['-i', path.join(output, `${theme}-${stage.id}.png`)]);
  const scales = stages.map((stage, index) => `[${index}:v]scale=320:320[s${index}]`).join(';');
  const layout = stages.map((stage, index) => `${index % 3 * 320}_${Math.floor(index / 3) * 320}`).join('|');
  const stack = stages.map((stage, index) => `[s${index}]`).join('');
  run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
    ...inputs, '-filter_complex_threads', '1', '-filter_complex',
    `${scales};${stack}xstack=inputs=6:layout=${layout}[grid]`, '-map', '[grid]', '-frames:v', '1',
    path.join(output, `${theme}-grid.png`)]);
  const report = { theme, duration: Number(probe.format.duration), dimensions: [video.width, video.height],
    frames_per_second: video.r_frame_rate, audio: { codec: audio.codec_name, channels: audio.channels,
      sample_rate: Number(audio.sample_rate), mean_dbfs: mean, peak_dbfs: peak },
    capture: captured, source_sha256: provenance(), inspected_by_human: false,
    validation_scope: 'Engine recording, media structure, non-silent audio, and scripted cue timing. No human listening or real-device performance claim.' };
  fs.writeFileSync(path.join(output, `${theme}-report.json`), JSON.stringify(report, null, 2) + '\n');
  return report;
}

function writeGallery() {
  const available = themes.filter(theme => fs.existsSync(path.join(output, `${theme}-report.json`)));
  const reports = available.map(theme => JSON.parse(fs.readFileSync(path.join(output, `${theme}-report.json`), 'utf8')));
  reports.forEach(report => validateCapture(report.capture, report.theme));
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(reports, null, 2) + '\n');
  if (available.length === themes.length) {
    const inputs = themes.flatMap(theme => ['-i', path.join(output, `${theme}-settled.png`)]);
    const scales = themes.map((theme, index) => `[${index}:v]scale=320:320[s${index}]`).join(';');
    const layout = themes.map((theme, index) => `${index % 4 * 320}_${Math.floor(index / 4) * 320}`).join('|');
    const stack = themes.map((theme, index) => `[s${index}]`).join('');
    run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      ...inputs, '-filter_complex_threads', '1', '-filter_complex',
      `${scales};${stack}xstack=inputs=8:layout=${layout}[grid]`, '-map', '[grid]', '-frames:v', '1',
      path.join(output, 'themes-grid.png')]);
  }
  const cards = reports.map((report, index) => `<article>
    <h2>Sample ${index + 1} <span class="theme-name">${report.theme[0].toUpperCase() + report.theme.slice(1)}</span></h2>
    <video controls playsinline preload="auto" poster="${report.theme}-rest.png" src="${report.theme}.mp4"></video>
    <p class="measure">640 × 640 · 60 fps · ${report.duration.toFixed(2)} s · recorded audio ${report.audio.mean_dbfs} dBFS mean</p>
    <details><summary>Inspect the six physical stages</summary>
      <div class="stages">${stages.map(stage => `<figure><img loading="lazy" src="${report.theme}-${stage.id}.png" alt="${stage.name} at ${stage.time} seconds"><figcaption>${stage.name} · ${stage.time.toFixed(2)} s</figcaption></figure>`).join('')}</div>
    </details></article>`).join('\n');
  fs.writeFileSync(path.join(output, 'index.html'), `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Chest motion and sound review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f6f4ee;color:#263448;font:16px/1.5 system-ui,sans-serif}
main{max-width:1440px;margin:auto;padding:32px 24px}h1{margin:0 0 8px;font-size:32px}header p{max-width:880px;margin:8px 0;color:#536170}
.toolbar{display:flex;gap:24px;flex-wrap:wrap;padding:18px 0 24px}label{cursor:pointer}input{margin-right:8px;accent-color:#236c76}
.gallery{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}article{background:white;border:1px solid #dbe0de;border-radius:18px;padding:18px;overflow:hidden}
h2{font-size:18px;margin:0 0 12px}.theme-name{font-weight:400;color:#69727a;margin-left:12px}.hide-names .theme-name{visibility:hidden}
video{display:block;width:100%;aspect-ratio:1;background:#f6f4ee;border-radius:10px}.measure{font-size:12px;color:#66737a}
summary{cursor:pointer;font-size:14px}.stages{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:12px}
figure{margin:0}img{display:block;width:100%;background:#f6f4ee;border-radius:6px}figcaption{font-size:11px;color:#536170;margin-top:4px}
footer{margin:28px 0;color:#68757e;font-size:13px}a{color:#236c76}@media(max-width:760px){main{padding:20px 12px}.gallery{grid-template-columns:1fr}h1{font-size:26px}}
</style><main><header><h1>Chest motion and sound review</h1>
<p>Eight themes at the same size. Each recording includes a short cancelled press, a complete 1.2-second hold, and the 1.8-second opening. Play with sound to review contact, charge, unlock, release, settle, and reward cues.</p>
<p>The soundtrack is the engine's recorded game audio, with its original mix preserved. Hide names to compare the motion without theme labels.</p></header>
<div class="toolbar"><label><input id="hide" type="checkbox">Hide theme names</label><label><input id="mute" type="checkbox">Mute all previews</label></div>
<section class="gallery">${cards}</section>
<footer>Automated checks verify video dimensions, duration, non-silent audio, and cue timing. They do not establish human listening quality or real-device performance. <a href="report.json">Media and cue report</a>.</footer></main>
<script>document.querySelector('#hide').addEventListener('change',event=>document.body.classList.toggle('hide-names',event.target.checked));document.querySelector('#mute').addEventListener('change',event=>document.querySelectorAll('video').forEach(video=>video.muted=event.target.checked));document.querySelectorAll('video').forEach(video=>video.addEventListener('play',()=>document.querySelectorAll('video').forEach(other=>{if(other!==video)other.pause()})));</script></html>\n`);
}

const args = process.argv.slice(2);
const selected = args.filter(arg => !arg.startsWith('--'));
if (selected.some(theme => !themes.includes(theme)) || args.some(arg => arg.startsWith('--') && !['--convert-only', '--gallery-only'].includes(arg))) {
  throw new Error('Usage: node tools/capture-chest-feel.cjs [spring summer autumn winter ocean space jungle candy] [--convert-only|--gallery-only]');
}
fs.mkdirSync(output, { recursive: true });
if (!args.includes('--gallery-only')) {
  for (const theme of selected.length ? selected : themes) {
    console.log(`${args.includes('--convert-only') ? 'Encoding' : 'Capturing'} ${theme}...`);
    let captured;
    if (args.includes('--convert-only')) {
      const log = fs.readFileSync(path.join(output, `${theme}.log`), 'utf8');
      captured = JSON.parse(log.split(/\r?\n/).find(line => line.startsWith('{"cues":')));
    } else {
      captured = render(theme);
    }
    const report = convert(theme, captured);
    console.log(`${theme}: ${report.duration.toFixed(2)} s, 640 x 640, audio mean ${report.audio.mean_dbfs} dBFS, peak ${report.audio.peak_dbfs} dBFS`);
    writeGallery();
  }
} else {
  writeGallery();
}
console.log(`Preview gallery: ${path.join(output, 'index.html')}`);
