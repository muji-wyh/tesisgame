const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const review = path.join(root, 'build/word-art-review/library');
const mulberryRoot = process.env.MULBERRY_SOURCE || path.join(root, 'build/mulberry-source/EN');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const read = filename => JSON.parse(fs.readFileSync(path.join(root, filename), 'utf8'));
const optional = filename => fs.existsSync(path.join(root, filename)) ? read(filename) : null;
const index = entries => new Map(entries.map(entry => [entry.id, entry]));
const esc = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function selectSource(word, { approved, extra, emoji, symbol }, directories = { root, mulberryRoot }) {
  let input, source, vector = false, crop;
  if (approved) {
    input = path.join(directories.root, approved.path);
    source = { ...approved.source,
      creator: approved.source.provider === 'fluent-emoji' ? 'Microsoft Corporation' : 'Kenney; Grow with Pip (studio adaptation)',
      license: approved.source.provider === 'fluent-emoji' ? 'MIT' : 'CC0-1.0',
      record: 'docs/assets/lv3-vocabulary.json', transformation: 'Preserved reviewed Lv3 composition; normalized transparent margin and encoded at high quality.' };
    const poster = path.join(directories.root, `build/word-art-review/animated/${word.id}.png`);
    if (['walk', 'run', 'jump', 'open', 'close', 'drink', 'eat', 'hello'].includes(word.id) && fs.existsSync(poster)) {
      input = poster;
      source.transformation = 'Happy character pose from the newly rendered joint animation; static fallback for the shared action atlas.';
    }
  } else if (extra) {
    input = path.join(directories.root, extra.local);
    vector = path.extname(input) === '.svg'; source = extra.source; crop = extra.crop;
  } else if (emoji) {
    if (!/^[a-f0-9]{64}$/.test(emoji.sha256 || '')) throw new Error(`Missing reviewed Fluent source hash: ${word.id}`);
    input = path.join(directories.root, emoji.local);
    source = { provider: 'fluent-emoji', creator: 'Microsoft Corporation', license: 'MIT', path: emoji.path,
      url: emoji.url, sha256: emoji.sha256, meaning: emoji.meaning, selection: emoji.selection,
      transformation: 'Source 3D illustration, transparent margins normalized; aspect ratio and authored lighting preserved.' };
  } else if (symbol) {
    input = path.join(directories.mulberryRoot, symbol.source); vector = true;
    source = { provider: 'mulberry', creator: 'Steve Lee; original symbol design project by Garry Paxton', license: 'CC-BY-SA-4.0',
      path: symbol.source, url: symbol.url || `https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/9cbab9f400c5de44e2bc58839cca07294aadb086/EN/${encodeURIComponent(symbol.source)}`,
      sha256: symbol.sourceSha256, meaning: symbol.intendedSense || word.meaning || word.text,
      transformation: 'Original educational geometry retained; softened outline, moderated source palette, individual shape shading, normalized composition and 256-pixel rendering.' };
  } else return null;
  if (!fs.existsSync(input)) {
    throw new Error(`Missing reviewed ${source.provider} source for ${word.id}: ${input}. Acquire or regenerate the mapped source before preparing the library.`);
  }
  return { input, source, vector, crop };
}

function readCachedPicture(output, previous, { inputSha256, compositionKey, rendererHash, previousRendererHash }) {
  if (!previous || previous.inputSha256 !== inputSha256 || previous.compositionKey !== compositionKey ||
      previousRendererHash !== rendererHash || !fs.existsSync(output)) return null;
  const bytes = fs.readFileSync(output);
  // A staging file is reusable only while it still matches its reviewed receipt.
  // Otherwise rerender from the verified source instead of approving new bytes.
  return bytes.length === previous.bytes && digest(bytes) === previous.sha256 ? bytes : null;
}

async function prepare() {
  const { normalizePicture } = require('./library-material.cjs');
  const sharp = require(process.env.SHARP_MODULE || 'sharp');
  fs.mkdirSync(path.join(review, 'pictures'), { recursive: true });
  fs.mkdirSync(path.join(review, 'before'), { recursive: true });
  const words = read('words.json').filter(word => word.image);
  const lv3 = index(read('docs/assets/lv3-vocabulary.json').files);
  const fluent = index(optional('tools/vocabulary-art/fluent-library-map.json')?.files || []);
  const mulberry = index([...read('docs/assets/mulberry-vocabulary.json').files, ...read('docs/assets/growth-vocabulary.json').files,
    ...(optional('tools/vocabulary-art/mulberry-library-map.json')?.entries || [])]);
  const supplemental = index([...(optional('tools/vocabulary-art/supplemental-library-map.json')?.files || []),
    ...(optional('tools/vocabulary-art/curated-library-map.json')?.files || []),
    ...(optional('tools/vocabulary-art/kenney-library-map.json')?.files || [])]);
  const oldManifest = optional('build/word-art-review/library/manifest.json');
  const previous = index(oldManifest?.files || []);
  const adjustments = read('tools/vocabulary-art/library-adjustments.json');
  const rendererHash = digest(fs.readFileSync(path.join(__dirname, 'library-material.cjs')));
  const files = [], missing = [];
  for (const word of words) {
    const approved = lv3.get(word.id), emoji = fluent.get(word.id), symbol = mulberry.get(word.id), extra = supplemental.get(word.id);
    const selected = selectSource(word, { approved, extra, emoji, symbol });
    if (!selected) { missing.push(word.id); continue; }
    let { input, source, vector, crop } = selected;
    const inputBytes = fs.readFileSync(input);
    const inputSha256 = digest(inputBytes);
    const adjustment = adjustments[word.id];
    const compositionKey = JSON.stringify({ crop: crop || null, palette: adjustment?.palette || null });
    if (crop) source = { ...source, crop };
    if (adjustment) source = { ...source, palette: adjustment.palette, transformation: source.transformation + ' ' + adjustment.reason };
    if (!approved && source.sha256 && inputSha256 !== source.sha256) throw new Error(`Source hash mismatch: ${word.id}`);
    const output = path.join(review, 'pictures', `${word.id}.webp`);
    let bytes = readCachedPicture(output, previous.get(word.id), {
      inputSha256, compositionKey, rendererHash, previousRendererHash: oldManifest?.rendererHash
    });
    if (!bytes) {
      const cropped = crop ? await sharp(inputBytes).extract(crop).png().toBuffer() : inputBytes;
      bytes = await normalizePicture(cropped, vector, adjustment?.palette); fs.writeFileSync(output, bytes);
    }
    const original = path.join(root, approved?.path || word.image);
    const before = path.join(review, 'before', `${word.id}.png`);
    if (!fs.existsSync(before)) await sharp(original).resize(256, 256).png().toFile(before);
    files.push({ id: word.id, age: word.min_age, meaning: word.meaning || word.text, partOfSpeech: word.part_of_speech,
      path: `assets/images/word-library/${word.id}.webp`, sha256: digest(bytes), bytes: bytes.length,
      width: 256, height: 256, inputSha256, compositionKey, source, status: 'Prepared for visual review; not yet integrated' });
    if (files.length % 100 === 0) console.log(`Prepared ${files.length} / ${words.length}`);
  }
  const manifest = { schema: 1, pictures: words.length, count: files.length, contextOnly: read('words.json').filter(word => !word.image).length,
    rendererHash, status: 'Local artwork review', missing, files };
  fs.writeFileSync(path.join(review, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(JSON.stringify({ prepared: files.length, missing, bytes: files.reduce((sum, row) => sum + row.bytes, 0) }));
  makeGallery(manifest);
  if (process.argv.includes('--integrate')) {
    if (missing.length || files.length !== words.length) throw new Error('Every pictured word needs a reviewed source before integration.');
    fs.mkdirSync(path.join(root, 'assets/images/word-library'), { recursive: true });
    for (const file of files) {
      fs.copyFileSync(path.join(review, 'pictures', `${file.id}.webp`), path.join(root, file.path));
      file.status = 'Integrated; source and output hashes verified';
      delete file.compositionKey;
    }
    manifest.status = 'Integrated'; delete manifest.rendererHash; delete manifest.missing;
    fs.writeFileSync(path.join(root, 'docs/assets/word-library.json'), JSON.stringify(manifest, null, 2) + '\n');
  }
}

function makeGallery(manifest) {
  const cards = manifest.files.map(file => `<article data-age="${file.age}" data-name="${esc(file.id)}"><header><b>${esc(file.id)}</b><small>Age ${file.age}${file.age === 12 ? '+' : ''}</small></header><div class="pair"><figure><img loading="lazy" src="before/${file.id}.png" alt="Previous ${esc(file.id)} picture"><figcaption>Previous</figcaption></figure><figure><img loading="lazy" src="pictures/${file.id}.webp" alt="Updated ${esc(file.id)} picture"><figcaption>Updated</figcaption></figure></div><p>${esc(file.meaning)}</p><small>${esc(file.source.provider)}</small></article>`).join('');
  fs.writeFileSync(path.join(review, 'index.html'), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Vocabulary artwork review · Grow with Pip</title><style>
  *{box-sizing:border-box}body{font:15px/1.5 system-ui;margin:0;padding:28px clamp(16px,4vw,64px);color:#27473d;background:#f4f5ed}h1{font-size:36px;line-height:1.2;letter-spacing:-1px}a{color:inherit}nav{display:flex;gap:12px;flex-wrap:wrap;position:sticky;top:0;padding:16px 0;background:#f4f5edf5;z-index:2}select,input,button{font:inherit;padding:10px 14px;border:1px solid #cad8cc;background:white;border-radius:10px;color:inherit}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(310px,1fr));gap:16px}article{background:white;border:1px solid #dce4da;border-radius:20px;padding:18px}header{display:flex;justify-content:space-between;align-items:center}header b{font-size:21px}small,p{color:#6d8173}.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:14px}figure{margin:0;text-align:center;background:#f3f3ed;border-radius:12px;padding:14px 0 8px}figure+figure{background:#edf4ec}img{width:var(--size,120px);height:var(--size,120px);max-width:100%;object-fit:contain}figcaption{font-size:11px;color:#6d8173}p{font-size:13px;min-height:20px;margin-bottom:4px}[hidden]{display:none!important}</style><body><a href="../animated/">View the eight cheerful actions</a><h1>Every word, clearly pictured.</h1><p>Local asset review · ${manifest.count} / ${manifest.pictures} pictures prepared. Preview pages remain local.</p><nav><select aria-label="Age" id="age"><option value="">All ages</option>${Array.from({length:10},(_,i)=>`<option>${i+3}</option>`).join('')}</select><input type="search" placeholder="Find a word" aria-label="Find a word" id="search"><select aria-label="Picture size" id="size">${[48,80,120,192].map(n=>`<option value="${n}" ${n===120?'selected':''}>${n} px</option>`).join('')}</select><span id="count"></span></nav><main>${cards}</main><script>const cards=[...document.querySelectorAll('article')];function filter(){let n=0;for(const card of cards){card.hidden=Boolean((age.value&&card.dataset.age!==age.value)||!card.dataset.name.includes(search.value.trim().toLowerCase()));if(!card.hidden)n++}count.textContent=n+' words'}age.onchange=search.oninput=filter;size.onchange=()=>document.body.style.setProperty('--size',size.value+'px');filter();</script></body></html>`);
}

if (require.main === module) prepare().catch(error => { console.error(error); process.exitCode = 1; });
module.exports = { prepare, makeGallery, selectSource, readCachedPicture };
