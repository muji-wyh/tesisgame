const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'build/chest-quality/game-review');
const items = [
  ['autumn', 'Harvest Keepsake', 'Amber wood, champagne trim, and a gently rounded lid.'],
  ['ocean', 'Lagoon Pearl', 'Teal panels, pale aqua details, and pearl framing.'],
  ['space', 'Moonstone Vault', 'Lilac enamel, pearl framing, and a gemstone cover that lifts open.'],
  ['jungle', 'Meadow Explorer', 'Warm wood and leafy green framing with softened edges.'],
  ['candy', 'Strawberry Bonbon', 'A strawberry rose barrel with vanilla bands and shallow fittings.']
];
for (const [id] of items) for (const pose of ['closed', 'opened']) {
  if (!fs.existsSync(path.join(output, `${id}-${pose}.png`))) throw new Error(`Missing real-game capture: ${id}/${pose}`);
}
fs.writeFileSync(path.join(output, 'index.html'), `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Chest review · Grow with Pip</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#142130;color:#f7f0e5;font:16px/1.6 system-ui,sans-serif}
main{max-width:1220px;margin:auto;padding:38px 28px 70px}header{display:flex;justify-content:space-between;align-items:center;gap:20px}
.eyebrow{color:#b5c9d3;font-size:12px;letter-spacing:.2em;text-transform:uppercase}h1{font-size:clamp(36px,6vw,64px);line-height:1.1;margin:12px 0 18px;letter-spacing:-.04em}
.intro{color:#b7c9d3;max-width:620px}a,button{color:inherit}a{text-underline-offset:4px}.pill{border:1px solid #71818b;border-radius:30px;padding:10px 18px;text-decoration:none;white-space:nowrap}
video{width:100%;max-height:70vh;object-fit:contain;display:block;border:1px solid #405460;border-radius:20px;background:#142130}.film{margin:34px 0 48px}
.film p{color:#9eb7c3;font-size:13px}h2{font-size:29px;line-height:1.3;letter-spacing:-.02em;margin:0}
.toolbar{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:22px;flex-wrap:wrap}
.switch{display:flex;gap:8px}button{font:inherit;background:transparent;border:1px solid #5e737e;border-radius:20px;padding:6px 18px;cursor:pointer}
button[aria-pressed=true]{background:#f2d397;color:#19232d;border-color:#f2d397}button:focus-visible,a:focus-visible{outline:3px solid #f2d397;outline-offset:4px}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:24px}.card{overflow:hidden;background:#1c2d3b;border:1px solid #344a59;border-radius:20px}
.card img{width:100%;display:block}.copy{padding:21px 24px 26px}.copy h3{font-size:24px;margin:0 0 5px}.copy p{color:#b1c5cf;margin:0;font-size:14px}
.index{float:right;color:#e7c88b;font-size:12px;letter-spacing:.12em}.details{border-top:1px solid #405460;padding-top:24px;margin-top:40px;color:#aebfc7;font-size:14px}.details p{max-width:900px}
@media(max-width:650px){main{padding:24px 16px 40px}header{align-items:flex-start}.pill{font-size:12px;padding:8px 12px}.grid{grid-template-columns:1fr}.film{margin:25px 0 34px}}
</style>
<main><header><div><div class="eyebrow">Grow with Pip · Asset review</div><h1>Treasure collection</h1></div><a class="pill" href="http://127.0.0.1:41773/" target="_blank" rel="noopener">Open game ↗</a></header>
<p class="intro">Five replacement designs with continuous lid movement, pressure feedback, and light that follows the actual chest.</p>
<section class="film" aria-label="Actual game animation"><video controls autoplay muted loop playsinline poster="collection-closed.png" src="opening.mp4"></video><p>Press Play to watch the opening. Captured from the shared in-game chest view; the preview is muted.</p></section>
<section aria-labelledby="designs"><div class="toolbar"><h2 id="designs">Inspect each design</h2><div class="switch" aria-label="Chest pose"><button aria-pressed="true" data-pose="closed">Closed</button><button aria-pressed="false" data-pose="opened">Opened</button></div></div>
<div class="grid">${items.map(([id, name, description], index) => `<article class="card"><img src="${id}-closed.png" data-chest="${id}" alt="${name}, closed, rendered inside the game" loading="lazy"><div class="copy"><span class="index">0${index + 1}</span><h3>${name}</h3><p>${description}</p></div></article>`).join('')}</div></section>
<section class="details"><h2>Source detail</h2><p>These are five distinct designs from acquired Unity Asset Store packages by Batata Studio, Bobardo, and Ekrem C. Moonstone remaps its original 1024px Epic atlas and retains source ambient occlusion; the other designs use source geometry and UVs with adapted pastel, wood, and pearl material colors. Four game-authored hinges and Moonstone's magnetic cover lift provide continuous opening motion. The game renders their geometry at an adaptive 512–1024px surface size.</p><p>Spring, Summer, and Winter keep their original chest designs. Hold timing, cancellation, rewards, and reduced motion remain shared with the existing game.</p></section></main>
<script>
for(const button of document.querySelectorAll('[data-pose]'))button.addEventListener('click',()=>{
for(const item of document.querySelectorAll('[data-pose]'))item.setAttribute('aria-pressed',String(item===button));
for(const image of document.querySelectorAll('[data-chest]')){image.src=image.dataset.chest+'-'+button.dataset.pose+'.png';image.alt=image.alt.replace(/, (?:closed|opened),/,', '+button.dataset.pose+',');}
});
if(matchMedia('(prefers-reduced-motion: reduce)').matches)document.querySelector('video').pause();
</script></html>`);
console.log(`Chest review written to ${output}`);
