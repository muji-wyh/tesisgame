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
const rhythmVersion = 8;
const holdPulseTimes = [0.08, 0.40, 0.68, 0.91, 1.12];
const pulseTimes = [0.11, 0.30, 0.48, 0.65, 0.81, 0.96, 1.10, 1.23,
  1.35, 1.46, 1.56, 1.65, 1.73, 1.80, 1.86];
const cueTimes = { anticipation: 1.94, unlock: 2.08, release: 2.16, settle: 2.58 };

function visualStages(captured) {
  const press = captured.cues.filter(cue => cue.cue === 'press').at(-1).time;
  const accepted = captured.cues.filter(cue => cue.time >= press);
  const at = (name, step = 0) => accepted.find(cue => cue.cue === name && cue.step === step).time;
  // Sample each weighted impulse after its attack, using delivered cue times.
  // Separate the flash crest from the later lid gap so both remain reviewable.
  return [
    { id: 'rest', name: 'Rest', time: 0.2 },
    { id: 'first-hold', name: 'First holding recoil', time: at('hold_pulse', 1) + 2 / 60 },
    { id: 'late-hold', name: 'Last holding recoil', time: at('hold_pulse', 5) + 2 / 60 },
    { id: 'gathering', name: 'First opening recoil', time: at('tension_pulse', 1) + 2 / 60 },
    { id: 'building', name: 'Final opening recoil', time: at('tension_pulse', 15) + 2 / 60 },
    { id: 'anticipation', name: 'Continuous final rise', time: at('anticipation') + 0.10 },
    { id: 'release', name: 'Theme flash', time: at('release') + 0.06 },
    { id: 'lid-gap', name: 'Lid gap and light beam', time: at('release') + 0.20 },
    { id: 'lid-stop', name: 'Mechanical stop', time: at('settle') + 0.04 },
    { id: 'settled', name: 'Settled', time: captured.reward_time + 0.20 }
  ];
}

function fileVersion(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(path.join(output, file))).digest('hex').slice(0, 16);
}

function assetUrl(file) {
  return `${file}?v=${fileVersion(file)}`;
}

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
  const files = ['scripts/chest_view.gd', 'scripts/chest_surface.gdshader', 'scripts/chest_feel.gd', 'scripts/game_audio.gd',
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
  const actual = captured.cues.filter(cue => !['charge_step', 'hold_pulse', 'tension_pulse'].includes(cue.cue))
    .map(cue => `${cue.cue}:${cue.step}`);
  if (captured.theme !== theme || JSON.stringify(actual) !== JSON.stringify(expected) ||
      captured.cues.some(cue => cue.theme !== theme) || captured.state.opening_time !== 3.8) {
    throw new Error(`The ${theme} recording has an incomplete or duplicated physical cue sequence.`);
  }
  const opening = captured.cues.find(cue => cue.cue === 'opening').time;
  const press = captured.cues.filter(cue => cue.cue === 'press').at(-1).time;
  const tolerance = 1 / 60 + 0.001;
  if (opening - press < 1.2 - 0.001 || opening - press > 1.2 + tolerance) {
    throw new Error(`The ${theme} recording did not preserve the complete 1.2-second hold.`);
  }
  if (captured.reward_time - press < 5.0 - 0.001 || captured.reward_time - press > 5.0 + tolerance * 2) {
    throw new Error(`The ${theme} recording did not preserve the complete five-second reward sequence.`);
  }
  for (const [name, seconds] of Object.entries(cueTimes)) {
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
    if (Math.abs(cue.time - press - cue.step * ((1.2 + cueTimes.release) / 3)) > tolerance * 2) {
      throw new Error(`The ${theme} charge milestone ${cue.step} is out of time.`);
    }
  }
  const holdPulses = captured.cues.filter(value => value.cue === 'hold_pulse' && value.time >= press);
  if (holdPulses.length !== holdPulseTimes.length || holdPulses.some((cue, index) =>
    cue.step !== index + 1 || Math.abs(cue.time - press - holdPulseTimes[index]) > tolerance)) {
    throw new Error(`The ${theme} recording must deliver all five holding kicks, beginning at 80 milliseconds.`);
  }
  const pulses = captured.cues.filter(value => value.cue === 'tension_pulse');
  if (pulses.length !== pulseTimes.length || pulses.some((cue, index) =>
    cue.step !== index + 1 || Math.abs(cue.time - opening - pulseTimes[index]) > tolerance)) {
    throw new Error(`The ${theme} recording missed or duplicated an accelerating tension beat.`);
  }
  const rhythm = captured.cues.filter(cue => cue.time >= press && ['hold_pulse', 'tension_pulse'].includes(cue.cue));
  const ordered = [...holdPulseTimes.map((_, index) => `hold_pulse:${index + 1}`),
    ...pulseTimes.map((_, index) => `tension_pulse:${index + 1}`)];
  if (JSON.stringify(rhythm.map(cue => `${cue.cue}:${cue.step}`)) !== JSON.stringify(ordered)) {
    throw new Error(`The ${theme} recording must join five holding beats to fifteen opening beats without restarting.`);
  }
  const intervals = rhythm.slice(1).map((cue, index) => cue.time - rhythm[index].time);
  const early = intervals.slice(0, 3).reduce((total, value) => total + value, 0) / 3;
  const late = intervals.slice(-3).reduce((total, value) => total + value, 0) / 3;
  if (intervals.some(interval => interval <= 0) || late >= early * 0.60) {
    throw new Error(`The ${theme} captured rhythm does not accelerate from the first hold into the final roll.`);
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
  const pressAt = captured.cues.filter(cue => cue.cue === 'press').at(-1).time;
  const audioEnvelope = Object.fromEntries([
    ['early_tension', pressAt + 0.08, 0.25], ['middle_tension', openingAt + 0.70, 0.25],
    ['late_tension', openingAt + 1.66, 0.25], ['final_rise', openingAt + 1.97, 0.15],
    ['release', openingAt + cueTimes.release, 0.25]
  ].map(([name, start, seconds]) => {
    const measurement = run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner',
      '-ss', String(start), '-t', String(seconds), '-i', mp4,
      '-vn', '-af', 'volumedetect', '-f', 'null', '-']).stderr;
    return [name, {
      start_seconds: start, duration_seconds: seconds,
      mean_dbfs: Number(measurement.match(/mean_volume:\s*(-?[\d.]+) dB/)?.[1]),
      peak_dbfs: Number(measurement.match(/max_volume:\s*(-?[\d.]+) dB/)?.[1])
    }];
  }));
  if (Object.values(audioEnvelope).some(slice => !Number.isFinite(slice.mean_dbfs))) {
    throw new Error(`The ${theme} mixed audio envelope could not be measured.`);
  }
  if (audioEnvelope.middle_tension.mean_dbfs < audioEnvelope.early_tension.mean_dbfs + 0.5 ||
      audioEnvelope.late_tension.mean_dbfs < audioEnvelope.middle_tension.mean_dbfs + 0.5 ||
      audioEnvelope.late_tension.mean_dbfs < audioEnvelope.early_tension.mean_dbfs + 3) {
    throw new Error(`The ${theme} actual mixed audio does not build from its first hold beat through the opening to the final roll.`);
  }
  if (audioEnvelope.final_rise.mean_dbfs < audioEnvelope.late_tension.mean_dbfs - 3) {
    throw new Error(`The ${theme} mixed audio loses its continuous final rise before release.`);
  }
  if (audioEnvelope.release.mean_dbfs < audioEnvelope.final_rise.mean_dbfs + 2 || peak > -1) {
    throw new Error(`The ${theme} release needs a clear dynamic lift without clipping.`);
  }
  const stages = visualStages(captured);
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
    `${scales};${stack}xstack=inputs=${stages.length}:layout=${layout}:fill=0xf6f4ee[grid]`, '-map', '[grid]', '-frames:v', '1',
    path.join(output, `${theme}-grid.png`)]);
  const report = { rhythm_version: rhythmVersion, theme, duration: Number(probe.format.duration), dimensions: [video.width, video.height],
    frames_per_second: video.r_frame_rate, audio: { codec: audio.codec_name, channels: audio.channels,
      sample_rate: Number(audio.sample_rate), mean_dbfs: mean, peak_dbfs: peak },
    audio_envelope: audioEnvelope, hold_pulse_seconds: holdPulseTimes, tension_pulse_seconds: pulseTimes,
    continuous_rise_seconds: Number((cueTimes.release - cueTimes.anticipation).toFixed(3)), visual_stages: stages,
    capture: captured, source_sha256: provenance(), inspected_by_human: false,
    validation_scope: 'Engine recording, media structure, actual mixed crescendo and continuous rise measurements, and scripted cue timing. No human listening or real-device performance claim.' };
  fs.writeFileSync(path.join(output, `${theme}-report.json`), JSON.stringify(report, null, 2) + '\n');
  return report;
}

function writeGallery() {
  const currentSources = provenance();
  const reports = themes.filter(theme => fs.existsSync(path.join(output, `${theme}-report.json`)))
    .map(theme => JSON.parse(fs.readFileSync(path.join(output, `${theme}-report.json`), 'utf8')))
    .filter(report => report.rhythm_version === rhythmVersion &&
      Object.entries(currentSources).every(([file, hash]) => report.source_sha256?.[file] === hash));
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
    <video controls playsinline preload="auto" poster="${assetUrl(`${report.theme}-rest.png`)}" src="${assetUrl(`${report.theme}.mp4`)}"></video>
    <p class="measure">640 × 640 · 60 fps · ${report.duration.toFixed(2)} s · recorded audio ${report.audio.mean_dbfs} dBFS mean</p>
    <details><summary>Inspect the ${report.visual_stages.length} physical stages</summary>
      <div class="stages">${report.visual_stages.map(stage => `<figure><img loading="lazy" src="${assetUrl(`${report.theme}-${stage.id}.png`)}" alt="${stage.name} at ${stage.time.toFixed(3)} seconds"><figcaption>${stage.name} · ${stage.time.toFixed(2)} s</figcaption></figure>`).join('')}</div>
    </details></article>`).join('\n');
  const gallery = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Chest motion and sound review · Rhythm ${rhythmVersion}</title>
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
<p class="measure">Rhythm ${rhythmVersion} · 5 holding beats + 15 opening beats · 5-second reward sequence</p>
<p>${reports.length} ${reports.length === 1 ? 'representative theme' : reports.length === themes.length ? 'themes' : 'representative themes'} at the same size. Each recording includes a short cancelled press followed by the complete five-second reward sequence: keep holding as five grounded recoils grow into fifteen increasingly strong opening beats. Let go when the lid releases; the remaining animation completes automatically.</p>
<p>The first holding beat begins at 80 milliseconds. Grounded impacts gain detail and brightness as the rhythm tightens. The final roll flows into a rising rush while the body keeps straining; there is no silent stop before release. A dry crack and weighty impact drive the base into its contact shadow as the lid accelerates upward. The lid meets its mechanical stop 420 milliseconds after release, then quickly damps its return. Progress stars fade into a broad theme-colored bloom and outward light wave.</p>
<p>A theme-colored flash peaks 45 milliseconds after release, then opens into a broad beam and afterglow. The lid, light and release sound share the same cue.</p>
<p>The soundtrack is the engine's recorded game audio, with its original mix preserved. Hide names to compare the motion without theme labels.</p></header>
<div class="toolbar"><label><input id="hide" type="checkbox">Hide theme names</label><label><input id="mute" type="checkbox">Mute all previews</label></div>
<section class="gallery">${cards}</section>
<footer>Automated checks verify video dimensions, duration, mixed audio crescendo, continuity into the final rise, release headroom and cue timing. The stills use delivered cues to show weighted recoil, the flash crest and the opening lid. This isolated large preview does not establish motion visibility in the real game stage, human listening quality, or real-device performance. <a href="${assetUrl('report.json')}">Media and cue report</a>.</footer></main>
<script>document.querySelector('#hide').addEventListener('change',event=>document.body.classList.toggle('hide-names',event.target.checked));document.querySelector('#mute').addEventListener('change',event=>document.querySelectorAll('video').forEach(video=>video.muted=event.target.checked));document.querySelectorAll('video').forEach(video=>video.addEventListener('play',()=>document.querySelectorAll('video').forEach(other=>{if(other!==video)other.pause()})));</script></html>\n`;
  fs.writeFileSync(path.join(output, 'index.html'), gallery);
  // The printed entry point is immutable by content, just like every embedded
  // media URL. Rebuilding cannot silently reuse an older browser gallery.
  const galleryPath = path.join(output, `index-${fileVersion('index.html')}.html`);
  fs.writeFileSync(galleryPath, gallery);
  return galleryPath;
}

const args = process.argv.slice(2);
const selected = args.filter(arg => !arg.startsWith('--'));
if (selected.some(theme => !themes.includes(theme)) || args.some(arg => arg.startsWith('--') && !['--convert-only', '--gallery-only'].includes(arg))) {
  throw new Error('Usage: node tools/capture-chest-feel.cjs [spring summer autumn winter ocean space jungle candy] [--convert-only|--gallery-only]');
}
fs.mkdirSync(output, { recursive: true });
let galleryPath;
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
    galleryPath = writeGallery();
  }
} else {
  galleryPath = writeGallery();
}
console.log(`Preview gallery: ${galleryPath}`);
