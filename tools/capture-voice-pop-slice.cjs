// Requires imported Godot resources, FFmpeg and ffprobe, or their environment
// overrides. Captures run serially with the real game scene. Desktop keeps the
// actual mixed-audio movie; portrait review uses native 390 x 844 PNG stages
// because Movie Maker fixes its video header to the project size before resize.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { runGodot } = require('./run-godot.cjs');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'build', 'voice-pop-slice');
const layouts = { desktop: [960, 720], portrait: [390, 844] };
const prefix = 'VOICE_POP_CAPTURE ';
const sourceFiles = ['scripts/voice_pop.gd', 'scripts/voice_pop_slice.gd', 'scripts/game_audio.gd',
  'tools/capture-voice-pop-slice.gd', 'tools/capture-voice-pop-slice.cjs'];

function run(binary, args) {
  const result = spawnSync(binary, args, { cwd: root, encoding: 'utf8', windowsHide: true,
    timeout: 180000, maxBuffer: 16 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`${binary}: ${result.error || result.stderr || result.stdout}`);
  return result;
}

function readCapture(log) {
  const line = log.split(/\r?\n/).find(value => value.startsWith(prefix));
  if (!line) throw new Error('The game did not report its slice capture.');
  return JSON.parse(line.slice(prefix.length));
}

function render(layout) {
  const result = runGodot(['--path', '.', '--resolution', layouts[layout].join('x'), '--fixed-fps', '60',
    '--write-movie', `build/voice-pop-slice/${layout}.avi`,
    '--script', 'res://tools/capture-voice-pop-slice.gd', '--', `--layout=${layout}`]);
  const log = result.stdout + result.stderr;
  fs.writeFileSync(path.join(output, `${layout}.log`), log);
  return readCapture(log);
}

function convert(layout, capture) {
  const expectedStages = ['before', 'impact', 'rupture', 'blade', 'separated', 'falling', 'faded', 'multi-hit'];
  if (capture.capture !== 'voice-pop-slice' || capture.layout !== layout || capture.final_hits < 3 ||
      JSON.stringify(capture.stages.map(stage => stage.id)) !== JSON.stringify(expectedStages)) {
    throw new Error(`${layout}: incomplete gameplay, simultaneous hits or deterministic stages.`);
  }
  const firstStages = capture.stages.filter(stage => stage.requested_age >= 0 && stage.id !== 'multi-hit');
  if (firstStages.some(stage => stage.effects.length !== 1 ||
      Math.abs(stage.effects[0].age - stage.requested_age) > 1 / 60 + 0.002)) {
    throw new Error(`${layout}: an effect stage deviated by more than one capture frame.`);
  }
  const multi = capture.stages.find(stage => stage.id === 'multi-hit');
  if (multi.effects.length < 2) throw new Error(`${layout}: missing independently retained simultaneous cuts.`);
  const [width, height] = layouts[layout];
  for (const stage of capture.stages) {
    const png = fs.readFileSync(path.join(output, stage.file));
    if (png.toString('hex', 0, 8) !== '89504e470d0a1a0a' || png.readUInt32BE(16) !== width || png.readUInt32BE(20) !== height) {
      throw new Error(`${layout}: ${stage.file} is not a native ${width} x ${height} stage.`);
    }
  }
  let videoReport = null, audioReport = null;
  if (layout === 'desktop') {
    const mp4 = path.join(output, `${layout}.mp4`);
    run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      '-i', path.join(output, `${layout}.avi`), '-map', '0:v:0', '-map', '0:a:0',
      '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', mp4]);
    const probe = JSON.parse(run(process.env.FFPROBE_BIN || 'ffprobe', ['-v', 'error',
      '-show_streams', '-show_format', '-of', 'json', mp4]).stdout);
    const video = probe.streams.find(stream => stream.codec_type === 'video');
    const audio = probe.streams.find(stream => stream.codec_type === 'audio');
    if (video?.width !== width || video?.height !== height || !audio || Number(probe.format.duration) < 4.5) {
      throw new Error(`${layout}: video dimensions, mixed audio or complete duration are missing.`);
    }
    const meter = run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-i', mp4,
      '-vn', '-af', 'volumedetect', '-f', 'null', '-']).stderr;
    const mean = Number(meter.match(/mean_volume:\s*(-?[\d.]+) dB/)?.[1]);
    const peak = Number(meter.match(/max_volume:\s*(-?[\d.]+) dB/)?.[1]);
    if (!Number.isFinite(mean) || !Number.isFinite(peak) || peak < -60 || peak > -0.5) {
      throw new Error(`${layout}: recorded game audio is silent, clipped or unmeasurable.`);
    }
    videoReport = { file: `${layout}.mp4`, width, height,
      duration: Number(probe.format.duration), frames_per_second: video.r_frame_rate };
    audioReport = { codec: audio.codec_name, channels: audio.channels, mean_dbfs: mean, peak_dbfs: peak };
  }
  const inputs = capture.stages.flatMap(stage => ['-i', path.join(output, stage.file)]);
  const thumbWidth = layout === 'portrait' ? 195 : 320;
  const thumbHeight = layout === 'portrait' ? 422 : 240;
  const scales = capture.stages.map((_, index) => `[${index}:v]scale=${thumbWidth}:${thumbHeight}[s${index}]`).join(';');
  const stack = capture.stages.map((_, index) => `[s${index}]`).join('');
  const grid = capture.stages.map((_, index) => `${index % 4 * thumbWidth}_${Math.floor(index / 4) * thumbHeight}`).join('|');
  run(process.env.FFMPEG_BIN || 'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...inputs,
    '-filter_complex_threads', '1', '-filter_complex',
    `${scales};${stack}xstack=inputs=${capture.stages.length}:layout=${grid}:fill=0x080e23[grid]`,
    '-map', '[grid]', '-frames:v', '1', path.join(output, `${layout}-grid.png`)]);
  const report = { capture, video: videoReport, audio: audioReport,
    still_dimensions: [width, height],
    video_omitted_reason: layout === 'portrait'
      ? 'Movie Maker fixes its AVI header to 960 x 720 before the runtime portrait resize. Review native 390 x 844 PNG stages; no portrait video or audio validation is claimed.' : null,
    source_sha256: Object.fromEntries(sourceFiles.map(file => [file,
      crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex')])),
    validation_scope: `Real game scene, deterministic speech fixture, native stage dimensions, clipped artwork and one-frame stage tolerance.${videoReport ? ' Desktop video includes the recorded game mix.' : ' Portrait is still-image review only.'} Not physical microphone or mobile-device validation.` };
  fs.writeFileSync(path.join(output, `${layout}-report.json`), JSON.stringify(report, null, 2) + '\n');
  return report;
}

function writeGallery(reports) {
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(reports, null, 2) + '\n');
  const hash = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(output, file))).digest('hex').slice(0, 12);
  const url = file => `${file}?v=${hash(file)}`;
  const cards = reports.map(report => {
    const layout = report.capture.layout;
    const media = report.video
      ? `<video controls playsinline preload="metadata" src="${url(report.video.file)}"></video><p>${report.capture.final_hits} scored hits · ${report.audio.peak_dbfs} dBFS peak · real mixed game audio</p>`
      : `<p>${report.capture.final_hits} scored hits · native ${report.still_dimensions.join(' x ')} stills. ${report.video_omitted_reason}</p>`;
    return `<article><h2>${layout}</h2>${media}
      <div class="stages">${report.capture.stages.map(stage => `<figure><img src="${url(stage.file)}" alt="${layout} ${stage.id}"><figcaption>${stage.id}${stage.requested_age < 0 ? '' : ` · ${Math.round(stage.effects[0].age * 1000)} ms`}</figcaption></figure>`).join('')}</div></article>`;
  }).join('');
  const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Voice Pop slice review</title><style>*{box-sizing:border-box}body{margin:0;background:#0c1428;color:#f5f7ff;font:16px/1.5 system-ui}main{max-width:1440px;margin:auto;padding:24px}h1{margin:0}p{color:#a8b9dc}article{margin:24px 0;padding:20px;background:#16203c;border-radius:16px}video{display:block;max-width:100%;max-height:720px;margin:auto}.stages{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}figure{margin:0}img{width:100%;display:block}figcaption{font-size:12px;color:#a8b9dc}a{color:#57edff}@media(max-width:700px){.stages{grid-template-columns:repeat(2,minmax(0,1fr))}main{padding:12px}}</style><main>
    <h1>Voice Pop slice review</h1><p>The real game scene with deterministic spoken hits. First hit: blade, retained artwork, opposing fragments and falling droplets. The second recognition cuts two targets together. Stage ages are actual captured effect times, within one 60 Hz frame of the requested age.</p>
    ${cards}<p>The desktop movie uses the engine's game audio with no replacement soundtrack. Portrait review uses native still images. These captures do not establish real microphone recognition, physical-device latency or human listening quality. <a href="${url('report.json')}">Capture report</a>.</p></main></html>\n`;
  fs.writeFileSync(path.join(output, 'index.html'), html);
  const named = path.join(output, `index-${crypto.createHash('sha256').update(html).digest('hex').slice(0, 16)}.html`);
  fs.writeFileSync(named, html);
  return named;
}

const args = process.argv.slice(2);
const selected = args.filter(arg => !arg.startsWith('--'));
if (selected.some(layout => !layouts[layout]) || args.some(arg => arg.startsWith('--') && arg !== '--convert-only')) {
  throw new Error('Usage: node tools/capture-voice-pop-slice.cjs [desktop portrait] [--convert-only]');
}
fs.mkdirSync(output, { recursive: true });
const reports = [];
for (const layout of selected.length ? selected : Object.keys(layouts)) {
  console.log(`${args.includes('--convert-only') ? 'Encoding' : 'Capturing'} Voice Pop ${layout}...`);
  const capture = args.includes('--convert-only')
    ? readCapture(fs.readFileSync(path.join(output, `${layout}.log`), 'utf8')) : render(layout);
  reports.push(convert(layout, capture));
}
console.log(`Preview gallery: ${writeGallery(reports)}`);
