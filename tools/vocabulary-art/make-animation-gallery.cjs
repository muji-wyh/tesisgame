// Package and review local Blender studies. Nothing is copied into the Web export.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../build/word-art-review/animated');
const words = ['walk', 'run', 'jump', 'open', 'close', 'drink', 'eat', 'hello'];

async function packageFrames() {
  const sharp = require(process.env.SHARP_MODULE || 'sharp');
  const selected = process.argv.slice(2).filter(arg => words.includes(arg));
  const manifest = selected.length && fs.existsSync(path.join(root, 'manifest.json'))
    ? JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8')).filter(row => !selected.includes(row.id)) : [];
  for (const id of selected.length ? selected : words) {
    const dir = path.join(root, id);
    const metadata = JSON.parse(fs.readFileSync(path.join(dir, 'metadata.json'), 'utf8'));
    const tiles = [];
    const raw = [];
    for (let frame = 1; frame <= metadata.frames; frame++) {
      const source = path.join(dir, `frame-${String(frame).padStart(4, '0')}.png`);
      // One fixed camera and one fixed resize for the complete sequence, never per-frame trimming.
      const pixels = await sharp(source).resize(256, 256).ensureAlpha().raw().toBuffer();
      raw.push(pixels);
      tiles.push({ input: pixels, raw: { width: 256, height: 256, channels: 4 }, left: (frame - 1) % 8 * 256, top: Math.floor((frame - 1) / 8) * 256 });
    }
    await sharp({ create: { width: 2048, height: Math.ceil(metadata.frames / 8) * 256, channels: 4, background: '#00000000' } })
      .composite(tiles).webp({ quality: 88, alphaQuality: 100, effort: 5 }).toFile(path.join(root, `${id}.webp`));
    const posterFrame = Math.floor(metadata.frames * (['open', 'close'].includes(id) ? .78 : .48));
    await sharp(raw[posterFrame], { raw: { width: 256, height: 256, channels: 4 } }).png().toFile(path.join(root, `${id}.png`));
    const delay = raw.map((_, i) => Math.round((i + 1) * 1000 / metadata.fps) - Math.round(i * 1000 / metadata.fps));
    await sharp(Buffer.concat(raw), { raw: { width: 256, height: 256 * raw.length, channels: 4, pageHeight: 256 } })
      .webp({ quality: 86, alphaQuality: 100, effort: 4, loop: 0, delay }).toFile(path.join(root, `${id}-loop.webp`));
    manifest.push({ ...metadata, width: 256, height: 256, columns: 8, sheet: `${id}.webp`, poster: `${id}.png`, posterFrame });
    console.log(`Packaged ${id}: ${metadata.frames} frames at ${metadata.fps} fps`);
  }
  manifest.sort((a, b) => words.indexOf(a.id) - words.indexOf(b.id));
  fs.writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
}

function makeGallery() {
  const entries = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
  const cards = entries.map(row => `<article data-word="${row.id}"><header><h2>${row.id}</h2><span>${row.duration.toFixed(1)} s</span></header><div class="compare"><figure><div class="stage"><img src="../proposed-lv3/${row.id}.png" alt="Current static illustration for ${row.id}"></div><figcaption>Current picture</figcaption></figure><figure><div class="stage motion"><canvas width="256" height="256" role="img" aria-label="Animated ${row.id}"></canvas></div><figcaption>Motion study</figcaption></figure></div><p>${row.description}</p><div class="transport"><button class="toggle" aria-label="Pause ${row.id}">Pause</button><input class="scrub" type="range" min="0" max="${row.frames - 1}" value="0" aria-label="Frame for ${row.id}"><output>1 / ${row.frames}</output><button class="replay" aria-label="Replay ${row.id}">↺</button></div></article>`).join('');
  fs.writeFileSync(path.join(root, 'index.html'), `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Words in motion · Grow with Pip</title>
<style>
:root{--art-size:120px;font:15px/1.5 system-ui,sans-serif;color:#254c42;background:#f3f5ed}*{box-sizing:border-box}body{margin:0;padding:36px clamp(16px,5vw,80px)}a{color:inherit;text-underline-offset:4px}.intro{max-width:760px}h1{font-size:clamp(30px,4vw,44px);letter-spacing:-1.6px;line-height:1.15;margin:15px 0 12px}h2{margin:0;font-size:23px;letter-spacing:-.5px}.eyebrow{text-transform:uppercase;font-size:11px;letter-spacing:2px;font-weight:750;color:#648878}.intro p{color:#687a70;max-width:650px;margin:0 0 20px}.back{font-size:13px;display:inline-block;margin-bottom:24px}nav{position:sticky;top:0;z-index:2;display:flex;align-items:center;gap:8px;flex-wrap:wrap;background:#f3f5edf5;padding:16px 0;border-bottom:1px solid #d8e1d5;backdrop-filter:blur(12px)}button{border:1px solid #cedacf;border-radius:10px;background:#fff;color:#31594a;font:inherit;padding:9px 14px;cursor:pointer}button:hover{border-color:#6f9a87}button:focus-visible,input:focus-visible{outline:3px solid #efb23c;outline-offset:3px}button[aria-pressed=true],#all{background:#285d49;color:white;border-color:#285d49}.size-label{font-size:12px;margin-left:auto;color:#697d70}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,390px),1fr));gap:20px;margin-top:24px}article{border:1px solid #dce4d6;border-radius:22px;background:#fff;padding:22px;box-shadow:0 4px 14px #233c2410}header{display:flex;align-items:center;justify-content:space-between}header span{font-size:12px;color:#799183;background:#f2f6ed;padding:4px 10px;border-radius:12px}.compare{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:18px}figure{margin:0;min-width:0}.stage{height:210px;display:flex;align-items:center;justify-content:center;border-radius:16px;background:#f4f4ed;overflow:hidden}.motion{background:#eaf4ed}.stage img,.stage canvas{display:block;width:min(100%,var(--art-size));height:auto;object-fit:contain;aspect-ratio:1}figcaption{text-align:center;font-size:11px;color:#859185;margin-top:8px}.motion+figcaption{color:#48795d}article p{color:#748075;font-size:13px;margin:18px 0;min-height:40px}.transport{display:flex;align-items:center;gap:10px}.transport button{font-size:12px;padding:7px 10px}.scrub{width:100%;min-width:30px;accent-color:#347651;cursor:pointer}.transport output{font-size:10px;font-variant-numeric:tabular-nums;color:#829083;min-width:42px;text-align:center}.replay{font-size:20px!important;line-height:16px}.notice{font-size:12px;color:#7e8d7c;margin:12px 0 0}footer{font-size:12px;color:#81917f;margin-top:30px;max-width:780px} .large-art .gallery{grid-template-columns:repeat(auto-fit,minmax(min(100%,460px),1fr))}@media(max-width:520px){.large-art .compare{grid-template-columns:1fr}.large-art .stage{height:210px}body{padding-top:22px}nav{gap:6px}.size-label{width:100%;margin:4px 0 0}.stage{height:190px}article{padding:18px}.transport{gap:6px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
</style><body><a class="back" href="../">← All Lv3 pictures</a><section class="intro"><div class="eyebrow">Local asset review · Grow with Pip</div><h1>Words in motion.</h1><p>${entries.length} actions, brought to life with the same characters and props. Compare at card size, pause on a pose, or replay a complete movement.</p></section><nav aria-label="Preview controls"><button id="all">Pause all</button><button id="restart">Replay all</button><span class="size-label">Picture size</span>${[48,80,120,192].map(size=>`<button data-size="${size}" aria-pressed="${size===120}">${size} px</button>`).join('')}</nav><p class="notice" id="notice">Original speed · 24 frames per second · Local preview only</p><main class="gallery">${cards}</main><footer>Acquired Kenney CC0 characters, Furniture Kit and Food Kit; locally authored joint and prop animation rendered in Blender. The game continues to use the approved static pictures. Door studies hold their final state, then restart from the opposite state. Reduced-motion preferences start playback paused.</footer>
<script>
const entries=${JSON.stringify(entries)};
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let globalPaused=reduced.matches,last=0;
const all=document.querySelector('#all');
const states=entries.map(row=>{
 const el=document.querySelector('[data-word="'+row.id+'"]'),canvas=el.querySelector('canvas'),sheet=new Image();
 const state={...row,el,canvas,sheet,ctx:canvas.getContext('2d'),elapsed:0,frame:row.posterFrame,paused:false,visible:false,loaded:false};
 sheet.onload=()=>{state.loaded=true;draw(state,state.frame)};sheet.onerror=()=>{el.querySelector('p').textContent='The animation could not load. Reload this local preview.'};sheet.src=row.sheet;
 el.querySelector('.replay').onclick=()=>{if(globalPaused)for(const peer of states)peer.paused=true;globalPaused=false;state.paused=false;state.elapsed=0;draw(state,0);sync()};
 el.querySelector('.scrub').oninput=e=>{state.paused=true;state.elapsed=Number(e.target.value)*1000/row.fps;draw(state,Number(e.target.value));sync()};
 return state;
});
function draw(s,frame){if(!s.loaded)return;s.frame=frame;s.ctx.clearRect(0,0,256,256);s.ctx.drawImage(s.sheet,(frame%s.columns)*256,Math.floor(frame/s.columns)*256,256,256,0,0,256,256);s.canvas.dataset.frame=frame;s.el.querySelector('.scrub').value=frame;s.el.querySelector('output').value=(frame+1)+' / '+s.frames;}
function sync(){all.textContent=globalPaused?'Play all':'Pause all';for(const s of states){const paused=globalPaused||s.paused;s.el.querySelector('.toggle').textContent=paused?'Play':'Pause';s.el.querySelector('.toggle').setAttribute('aria-label',(paused?'Play ':'Pause ')+s.id);s.el.dataset.playing=String(!paused)}}
all.onclick=()=>{globalPaused=!globalPaused;if(!globalPaused)for(const s of states)s.paused=false;sync()};
document.querySelector('#restart').onclick=()=>{globalPaused=false;for(const s of states){s.elapsed=0;s.paused=false;draw(s,0)}sync()};
for(const s of states){s.el.querySelector('.toggle').onclick=()=>{if(globalPaused){globalPaused=false;for(const peer of states)peer.paused=true;s.paused=false}else s.paused=!s.paused;sync()}}
const observer=new IntersectionObserver(rows=>{for(const r of rows){const s=states.find(s=>s.el===r.target);s.visible=r.isIntersecting}},{threshold:.1});for(const s of states)observer.observe(s.el);
function tick(now){const dt=last?Math.min(now-last,100):0;last=now;if(!document.hidden&&!globalPaused)for(const s of states){if(s.visible&&!s.paused&&s.loaded){s.elapsed=(s.elapsed+dt)%(s.frames*1000/s.fps);const frame=Math.floor(s.elapsed*s.fps/1000);if(frame!==s.frame)draw(s,frame)}}requestAnimationFrame(tick)}
for(const button of document.querySelectorAll('[data-size]'))button.onclick=()=>{document.body.classList.toggle('large-art',button.dataset.size==='192');document.documentElement.style.setProperty('--art-size',button.dataset.size+'px');for(const peer of document.querySelectorAll('[data-size]'))peer.setAttribute('aria-pressed',String(peer===button))};
reduced.addEventListener('change',e=>{if(e.matches){globalPaused=true;sync()}});document.addEventListener('visibilitychange',()=>{last=0});sync();requestAnimationFrame(tick);
</script></body></html>`);
  console.log('Local animation gallery ready.');
}

(async () => {
  if (!process.argv.includes('--gallery-only')) await packageFrames();
  makeGallery();
})().catch(error => { console.error(error); process.exitCode = 1; });
