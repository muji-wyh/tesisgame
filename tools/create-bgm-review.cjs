const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const manifestPath = path.join(root, 'docs', 'assets', 'casual-bgm.json');
const outputDirectory = path.join(root, 'build', 'bgm-review');
const audioDirectory = path.join(outputDirectory, 'audio');

const themes = {
  spring: { label: 'Spring', color: '#267f64', background: '#e9f4e8', symbol: '✿' },
  summer: { label: 'Summer', color: '#aa6520', background: '#fff0ce', symbol: '☀' },
  autumn: { label: 'Autumn', color: '#ad533a', background: '#ffe8db', symbol: '❧' },
  winter: { label: 'Winter', color: '#507ba0', background: '#e8f2fb', symbol: '❄' },
  ocean: { label: 'Ocean', color: '#208997', background: '#def4f5', symbol: '≈' },
  space: { label: 'Space', color: '#7762ad', background: '#efeafb', symbol: '✦' },
  jungle: { label: 'Jungle', color: '#4e773c', background: '#ecf2db', symbol: '♧' },
  candy: { label: 'Candy', color: '#a8507f', background: '#fbe5ef', symbol: '♡' },
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

function externalUrl(value, field) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error(`Invalid ${field}: ${value}`);
  return escapeHtml(url.href);
}

function durationLabel(seconds) {
  const rounded = Math.round(seconds);
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, '0')}`;
}

function prepareTrack(track) {
  if (!themes[track.theme]) throw new Error(`Unknown music theme: ${track.theme}`);
  if (!track.title || !Number.isFinite(track.durationSeconds) || track.durationSeconds <= 0) {
    throw new Error(`Missing title or duration for ${track.theme}`);
  }
  const relativePath = String(track.path).replace(/^res:\/\//, '');
  const sourcePath = path.resolve(root, relativePath);
  const sourceDirectory = path.join(root, 'assets', 'audio', 'bgm');
  if (path.dirname(sourcePath) !== sourceDirectory || path.extname(sourcePath).toLowerCase() !== '.wav') {
    throw new Error(`Expected an active BGM WAV file, received: ${track.path}`);
  }
  if (!fs.statSync(sourcePath).isFile()) throw new Error(`Missing BGM file: ${sourcePath}`);
  const outputPath = path.join(audioDirectory, `${track.theme}.mp3`);
  const conversion = spawnSync('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', '-i', sourcePath,
    '-map_metadata', '-1', '-vn', '-codec:a', 'libmp3lame', '-b:a', '128k', outputPath,
  ], { encoding: 'utf8', windowsHide: true });
  if (conversion.error) throw conversion.error;
  if (conversion.status !== 0) throw new Error(`Could not preview ${track.theme}: ${conversion.stderr}`);
  const theme = themes[track.theme];
  return `<article class="track-card" style="--accent:${theme.color};--tint:${theme.background}">
    <div class="card-art" aria-hidden="true"><span>${theme.symbol}</span><i></i><i></i><i></i></div>
    <div class="card-content">
      <div class="track-meta"><span>${theme.label}</span><span>${durationLabel(track.durationSeconds)} loop</span></div>
      <h2>${escapeHtml(track.title)}</h2>
      <p class="track-author">${escapeHtml(manifest.author)}</p>
      <audio controls loop preload="none" aria-label="Listen to ${escapeHtml(track.title)}" data-title="${escapeHtml(track.title)}">
        <source src="audio/${track.theme}.mp3" type="audio/mpeg">
        Your browser does not support audio playback.
      </audio>
      <div class="card-footer"><span class="play-status">Ready to listen</span><a href="${externalUrl(track.sourceUrl, 'source URL')}" target="_blank" rel="noopener noreferrer">Original track <span aria-hidden="true">↗</span></a></div>
    </div>
  </article>`;
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (!Array.isArray(manifest.files) || manifest.files.length !== Object.keys(themes).length) {
  throw new Error('The review requires all eight BGM themes.');
}
if (new Set(manifest.files.map((track) => track.theme)).size !== manifest.files.length) {
  throw new Error('The BGM manifest contains duplicate themes.');
}
fs.mkdirSync(audioDirectory, { recursive: true });
const cards = Object.keys(themes).map((theme) => prepareTrack(manifest.files.find((track) => track.theme === theme))).join('\n');

const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>Music Room · Tesisgame</title>
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; background: #f6f6ef; color: #263d39; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    button, input { font: inherit; }
    a { color: inherit; text-underline-offset: 3px; }
    :focus-visible { outline: 3px solid #277b66; outline-offset: 4px; }
    main { max-width: 1240px; margin: 0 auto; padding: 46px 32px 28px; }
    .brand { display: flex; align-items: center; gap: 10px; font-size: 13px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
    .brand-icon { display: grid; place-items: center; width: 34px; height: 34px; border-radius: 12px; background: #d8eade; font-size: 21px; }
    .hero { display: grid; grid-template-columns: 1.3fr 1fr; gap: 60px; align-items: end; margin: 36px 0 32px; }
    h1 { margin: 0 0 16px; font-size: clamp(38px, 5.5vw, 66px); letter-spacing: -.06em; line-height: 1.06; font-weight: 750; }
    h1 span { color: #42886c; }
    .intro { max-width: 500px; margin: 0; color: #61716a; line-height: 1.7; font-size: 16px; }
    .player-panel { padding: 24px; background: #fffdf7; border: 1px solid #e0e6db; border-radius: 24px; box-shadow: 0 8px 26px #27473505; }
    .eyebrow { margin: 0 0 7px; font-size: 11px; font-weight: 800; letter-spacing: .12em; text-transform: uppercase; color: #697c71; }
    #now-playing { margin: 0 0 20px; font-size: 19px; font-weight: 650; min-height: 26px; }
    .volume-row { display: flex; gap: 13px; align-items: center; }
    .volume-row label { font-size: 13px; font-weight: 600; }
    .volume-row input { flex: 1; min-width: 50px; accent-color: #42886c; cursor: pointer; }
    .volume-row output { width: 36px; text-align: right; font-size: 12px; font-variant-numeric: tabular-nums; }
    .player-note { margin: 16px 0 0; color: #718176; font-size: 12px; line-height: 1.6; }
    .collection-bar { display: flex; align-items: center; justify-content: space-between; gap: 14px; padding: 8px 0 18px; font-size: 13px; }
    .collection-bar strong { font-weight: 650; }
    .collection-bar span { margin-left: 8px; color: #7a897c; }
    button { border: 1px solid #d3dfd3; border-radius: 999px; padding: 9px 17px; background: #fffdf8; color: #3c6050; font-size: 12px; font-weight: 650; cursor: pointer; }
    button:hover { background: #e8f0e3; }
    .track-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 20px; }
    .track-card { overflow: hidden; border: 1px solid #e0e5da; border-radius: 22px; background: #fffefb; transition: box-shadow .2s, border-color .2s; }
    .track-card.is-playing { border-color: var(--accent); box-shadow: 0 0 0 2px var(--tint), 0 8px 22px #324b3b12; }
    .card-art { height: 104px; position: relative; overflow: hidden; display: grid; place-items: center; color: var(--accent); background: var(--tint); }
    .card-art span { position: relative; z-index: 1; font-family: Georgia, serif; font-size: 62px; font-weight: normal; line-height: 1; }
    .card-art i { position: absolute; display: block; width: 115px; height: 115px; border: 1px solid currentColor; opacity: .12; border-radius: 50%; }
    .card-art i:nth-of-type(1) { left: -34px; bottom: -75px; }
    .card-art i:nth-of-type(2) { right: -32px; top: -62px; }
    .card-art i:nth-of-type(3) { right: -48px; top: -47px; }
    .card-content { padding: 18px 16px 15px; }
    .track-meta { display: flex; justify-content: space-between; gap: 8px; font-size: 10px; text-transform: uppercase; letter-spacing: .08em; font-weight: 750; color: var(--accent); }
    .track-meta span:last-child { color: #809085; letter-spacing: .02em; text-transform: none; font-weight: 500; }
    h2 { min-height: 46px; margin: 11px 0 3px; font-size: 18px; line-height: 1.3; letter-spacing: -.025em; font-weight: 650; }
    .track-author { margin: 0 0 17px; font-size: 11px; color: #7a877b; }
    audio { display: block; width: 100%; height: 37px; margin: 0; }
    .card-footer { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; margin-top: 14px; font-size: 10px; }
    .card-footer a { text-decoration: none; color: #607766; }
    .card-footer a:hover { text-decoration: underline; }
    .play-status { color: #7d8c80; }
    .is-playing .play-status { color: var(--accent); font-weight: 700; }
    footer { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 10px; margin: 26px 0 0; padding: 18px 0 0; border-top: 1px solid #dfe5d9; color: #758274; font-size: 11px; line-height: 1.8; }
    footer p { margin: 0; }
    @media (max-width: 1050px) { .track-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } .card-art { height: 100px; } h2 { min-height: 0; } .hero { gap: 30px; } }
    @media (max-width: 660px) { main { padding: 28px 18px 22px; } .hero { grid-template-columns: 1fr; gap: 24px; margin-top: 28px; } .player-panel { padding: 20px; } .track-grid { gap: 14px; } .card-content { padding: 15px 12px; } h2 { min-height: 44px; font-size: 17px; } .collection-bar span { display: none; } }
    @media (max-width: 440px) { .track-grid { grid-template-columns: 1fr; } .card-art { height: 95px; } h2 { min-height: 0; } .card-content { padding: 18px; } }
    @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
  </style>
</head>
<body>
  <main>
    <div class="brand"><span class="brand-icon" aria-hidden="true">♫</span>Tesisgame · Music Room</div>
    <section class="hero" aria-labelledby="page-title">
      <div><h1 id="page-title">A little music.<br><span>A whole new mood.</span></h1><p class="intro">Eight melodies for eight colorful worlds. Explore the new soundtrack and find your favorite.</p></div>
      <div class="player-panel">
        <p class="eyebrow">Now playing</p><p id="now-playing" aria-live="polite">Pick a world to begin</p>
        <div class="volume-row"><label for="volume">Volume</label><input id="volume" type="range" min="0" max="100" value="50"><output id="volume-value" for="volume">50%</output></div>
        <p class="player-note">Normalized previews. Music plays more quietly in the game to leave room for speech. Tracks loop automatically.</p>
      </div>
    </section>
    <div class="collection-bar"><div><strong>Choose your soundtrack</strong><span>8 worlds · 8 original tracks</span></div><button id="pause-all" type="button">Pause music</button></div>
    <section class="track-grid" aria-label="Theme music previews">${cards}</section>
    <footer><p>Music by ${escapeHtml(manifest.author)} · <a href="${externalUrl(manifest.licenseUrl, 'license URL')}" target="_blank" rel="noopener noreferrer">${escapeHtml(manifest.license)}</a></p><p>Previewing the soundtrack included in the game.</p></footer>
  </main>
  <script>
    const tracks = Array.from(document.querySelectorAll('audio'));
    const volume = document.getElementById('volume');
    const volumeValue = document.getElementById('volume-value');
    const nowPlaying = document.getElementById('now-playing');
    function applyVolume() {
      const value = Number(volume.value) / 100;
      tracks.forEach((track) => { track.volume = value; });
      volumeValue.value = volume.value + '%';
    }
    tracks.forEach((track) => {
      const card = track.closest('.track-card');
      const status = card.querySelector('.play-status');
      track.addEventListener('play', () => {
        tracks.forEach((other) => { if (other !== track) other.pause(); });
        card.classList.add('is-playing');
        status.textContent = 'Playing';
        nowPlaying.textContent = track.dataset.title;
      });
      track.addEventListener('pause', () => {
        card.classList.remove('is-playing');
        status.textContent = track.currentTime > 0 ? 'Paused' : 'Ready to listen';
        if (tracks.every((other) => other.paused)) nowPlaying.textContent = 'Music paused';
      });
      track.addEventListener('error', () => { status.textContent = 'Preview unavailable'; });
    });
    volume.addEventListener('input', applyVolume);
    document.getElementById('pause-all').addEventListener('click', () => {
      tracks.forEach((track) => track.pause());
    });
    applyVolume();
  </script>
</body>
</html>`;

fs.writeFileSync(path.join(outputDirectory, 'index.html'), html);
console.log(`Created ${manifest.files.length} music previews: ${path.join(outputDirectory, 'index.html')}`);
