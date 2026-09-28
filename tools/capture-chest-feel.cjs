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
const pulseTimes = [0.10, 0.48, 0.81, 1.09, 1.32, 1.50, 1.64];
const stages = [
  { id: 'rest', name: 'Rest', time: 0.2 },
  { id: 'gathering', name: 'Gathering', time: 2.35 },
  { id: 'building', name: 'Building tension', time: 3.55 },
  { id: 'anticipation', name: 'Final breath', time: 3.90 },
  { id: 'release', name: 'Release', time: 4.52 },
  { id: 'settled', name: 'Settled', time: 6.05 }
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
  const expected = ['press:0', 'cancel:0', 'press:0', 'opening:0', 'anticipation:0',
    'unlock:0', 'release:0', 'settle:0'];
  const actual = captured.cues.filter(cue => !['charge_step', 'tension_pulse'].includes(cue.cue))
    .map(cue => `${cue.cue}:${cue.step}`);
  if (captured.theme !== theme || JSON.stringify(actual) !== JSON.stringify(expected) ||
      captured.cues.some(cue => cue.theme !== theme) || captured.state.opening_time !== 3.8) {
    throw new Error(`The ${theme} recording has an incomplete or duplicated physical cue sequence.`);
  }
  const opening = captured.cues.find(cue => cue.cue === 'opening').time;
  const press = captured.cues[2].time;
  const tolerance = 1 / 60 + 0.001;
  if (opening - press < 1.2 - 0.001 || opening - press > 1.2 + tolerance) {
    throw new Error(`The ${theme} recording did not preserve the complete 1.2-second hold.`);
  }
  if (captured.reward_time - press < 5.0 - 0.001 || captured.reward_time - press > 5.0 + tolerance * 2) {
    throw new Error(`The ${theme} recording did not preserve the complete five-second reward sequence.`);
  }
  for (const [name, seconds] of [['anticipation', 1.72], ['unlock', 2.12], ['release', 2.32], ['settle', 2.95]]) {
    const elapsed = captured.cues.find(cue => cue.cue === name).time - opening;
    if (elapsed < seconds - 0.001 || elapsed > seconds + tolerance) {
      throw new Error(`The ${theme} ${name} cue is early or outside the one-frame capture tolerance.`);
    }
  }
  const milestones = captured.cues.filter(value => value.cue === 'charge_step');
  if (JSON.stringify(milestones.map(cue => cue.step)) !== '[1,2,3]') {
    throw new Error(`The ${theme} recording must light each of its three progress stars exactly once.`);
  }
  if (milestones[0].time >= opening) {
    throw new Error(`The ${theme} recording must retain its first progress star from the confirmation hold.`);
  }
  for (const cue of milestones) {
    if (Math.abs(cue.time - press - cue.step * (3.52 / 3)) > tolerance * 2) {
      throw new Error(`The ${theme} charge milestone ${cue.step} is out of time.`);
    }
  }
  const pulses = captured.cues.filter(value => value.cue === 'tension_pulse');
  if (pulses.length !== pulseTimes.length || pulses.some((cue, index) =>
    cue.step !== index + 1 || Math.abs(cue.time - opening - pulseTimes[index]) > tolerance)) {
    throw new Error(`The ${theme} recording missed or duplicated an accelerating tension beat.`);
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
  if (!audio || video?.width !== 640 || video?.height !== 640 || Number(probe.format.duration) < 7.5) {
    throw new Error(`The ${theme} preview is missing audio, square video, or the complete 7.5-second recording.`);
  }
  const meter = run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-i', mp4,
    '-vn', '-af', 'volumedetect', '-f', 'null', '-']).stderr;
  const mean = Number(meter.match(/mean_volume:\s*(-?[\d.]+) dB/)?.[1]);
  const peak = Number(meter.match(/max_volume:\s*(-?[\d.]+) dB/)?.[1]);
  if (!Number.isFinite(mean) || !Number.isFinite(peak) || peak <= -90) {
    throw new Error(`The ${theme} preview audio is silent or cannot be measured.`);
  }
  const openingAt = captured.cues.find(cue => cue.cue === 'opening').time;
  const audioEnvelope = Object.fromEntries([
    ['late_tension', 1.40, 0.2], ['quiet_breath', 1.82, 0.2], ['release', 2.37, 0.25]
  ].map(([name, relativeStart, seconds]) => {
    const measurement = run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner',
      '-ss', String(openingAt + relativeStart), '-t', String(seconds), '-i', mp4,
      '-vn', '-af', 'volumedetect', '-f', 'null', '-']).stderr;
    return [name, {
      start_seconds: openingAt + relativeStart, duration_seconds: seconds,
      mean_dbfs: Number(measurement.match(/mean_volume:\s*(-?[\d.]+) dB/)?.[1]),
      peak_dbfs: Number(measurement.match(/max_volume:\s*(-?[\d.]+) dB/)?.[1])
    }];
  }));
  if (Object.values(audioEnvelope).some(slice => !Number.isFinite(slice.mean_dbfs)) ||
      audioEnvelope.quiet_breath.mean_dbfs > audioEnvelope.late_tension.mean_dbfs - 6) {
    throw new Error(`The ${theme} mixed audio does not preserve the quiet breath before release.`);
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
  const report = { rhythm_version: 3, theme, duration: Number(probe.format.duration), dimensions: [video.width, video.height],
    frames_per_second: video.r_frame_rate, audio: { codec: audio.codec_name, channels: audio.channels,
      sample_rate: Number(audio.sample_rate), mean_dbfs: mean, peak_dbfs: peak },
    audio_envelope: audioEnvelope,
    capture: captured, source_sha256: provenance(), inspected_by_human: false,
    validation_scope: 'Engine recording, media structure, non-silent audio, and scripted cue timing. No human listening or real-device performance claim.' };
  fs.writeFileSync(path.join(output, `${theme}-report.json`), JSON.stringify(report, null, 2) + '\n');
  return report;
}

function writeGallery() {
  const reports = themes.filter(theme => fs.existsSync(path.join(output, `${theme}-report.json`)))
    .map(theme => JSON.parse(fs.readFileSync(path.join(output, `${theme}-report.json`), 'utf8')))
    .filter(report => report.rhythm_version === 3);
  const available = reports.map(report => report.theme);
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
<p>${reports.length} ${reports.length === 1 ? 'representative theme' : reports.length === themes.length ? 'themes' : 'representative themes'} at the same size. Each recording includes a short cancelled press followed by the complete five-second reward sequence: hold for 1.2 seconds, let go, then watch tension build automatically toward a final breath and release.</p>
<p>Progress advances throughout the buildup. Seven increasingly close beats lead into a brief hush; the lid stays closed until the final release. Play with sound to compare each theme's rhythm.</p>
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
