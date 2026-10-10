'use strict';

// Compose review stages from the shipped Pip artwork. No source art is redrawn.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../../..');
const { readSources, buildOutfits, buildExpressionSheet } = require(path.join(ROOT, 'tools/generate-pip-outfits.cjs'));
const sources = readSources(ROOT);
const PROFILE = { voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%' };
const STAGES = [
  [3, 'sprout', 'Sprout', null, 'summer',
    'A soft mint shirt and an open, curious face. The first little hello.',
    'wave', 'Hello wave', "Hello! I'm Pip.", '#3c8771', '#eaf3e7',
    { '#67C7D5': '#87BC9E', '#F6A98C': '#F3D49D' }],
  [4, 'little-helper', 'Little Helper', null, 'spring',
    'Leaf-green overalls, ready for small discoveries and helping hands.',
    'look', 'Curious look', "Let's grow together.", '#4d7954', '#ecf2db', {}],
  [5, 'curious-scout', 'Curious Scout', 'summer', 'spring',
    'A honey-yellow cap joins the familiar overalls: ready to venture out.',
    'high-five', 'High five', 'I wonder what we will find.', '#9c6c2d', '#fbefcb',
    { '#F58D76': '#D4A94F', '#FFC3A9': '#F5DA8D', '#FFB27E': '#E7C16E', '#CC7660': '#A37D38' }],
  [6, 'story-finder', 'Story Finder', 'autumn', 'spring',
    'A raspberry beret and deep teal overalls for an imaginative storyteller.',
    'peekaboo', 'Peekaboo', 'Every word can tell a story.', '#a55867', '#f9e6e5',
    { '#C28350': '#BE7183', '#8D6746': '#875061', '#E3AB42': '#E9C275', '#51977A': '#487F7B', '#37755F': '#35645F', '#A7D7AC': '#B8DCD0' }],
  [7, 'trail-buddy', 'Trail Buddy', 'jungle', 'jungle',
    'A sage field hat and pocketed vest make room for a growing collection of words.',
    'stretch', 'Wing stretch', 'A little practice goes a long way.', '#657e44', '#edf1dc',
    { '#C6B178': '#91AE7C', '#C9B27B': '#A6BC8B', '#A68D59': '#708E62', '#AB915D': '#79976B', '#F6DE94': '#F2E2AF', '#E1C990': '#D9D6A2', '#7E9364': '#577C59' }],
  [8, 'wayfinder', 'Wayfinder', 'spring', 'winter',
    'A flower-trimmed trail hat and a warm scarf: calm, cheerful, and prepared.',
    'hop', 'Happy hop', 'We can find a new way together.', '#36857e', '#e2f1ed',
    { '#78ABC6': '#70A9A0', '#467C9B': '#427C76', '#D86176': '#D9AB50', '#E77786': '#E6BB66', '#DDF2EE': '#F4E9C4' }],
  [9, 'word-maker', 'Word Maker', 'autumn', 'candy',
    'A cornflower beret and a maker\'s apron turn familiar words into new ideas.',
    'dance-sway', 'Gentle sway', "Let's make something with our words.", '#627d9b', '#e8edf6',
    { '#C28350': '#839EB8', '#8D6746': '#5B728D', '#E3AB42': '#EBC171', '#9ED3C4': '#D7E6DA', '#ED9BB5': '#79A4A0', '#FFE4E6': '#EFE5CD', '#E68DA9': '#8BB4AE', '#C58DB6': '#B9935C', '#976A76': '#786950' }],
  [10, 'sky-explorer', 'Sky Explorer', 'summer', 'space',
    'A bright explorer cap meets a pearl field suit, with an amber instrument panel.',
    'flutter', 'Wing flutter', 'There is a whole world to explore.', '#8e7946', '#f3ecd8',
    { '#F58D76': '#719C95', '#FFC3A9': '#AACFC2', '#FFB27E': '#91B7A7', '#CC7660': '#527F79', '#E4EEF0': '#F1EDD9', '#95B5C9': '#C9BA85', '#9EC9D4': '#B8CDAE', '#708DA7': '#9A895B', '#67778A': '#7D7258' }],
  [11, 'bright-navigator', 'Bright Navigator', 'ocean', 'space',
    'A cream navigator cap and blue field suit carry a more confident silhouette.',
    'dance-wave', 'Two-step wave', 'We are learning more, one word at a time.', '#4e7897', '#e6eff5',
    { '#E4EEF0': '#A0C0D0', '#95B5C9': '#5F8BA4', '#9EC9D4': '#DEE7DA', '#708DA7': '#557487', '#DF8576': '#D5A562' }],
  [12, 'kind-guide', 'Kind Guide', 'autumn', 'ocean',
    'An amber beret, deep teal jacket, and gold details. Still the same friendly Pip.',
    'dance-hop', 'Celebration dance', 'Look how far we have come. Keep being curious!', '#456f65', '#e5eee2',
    { '#C28350': '#D1A65E', '#8D6746': '#94733E', '#E3AB42': '#E9CF8A', '#4E809E': '#42756D', '#5D92B0': '#70968A', '#DF8576': '#D7AE59', '#F2F5E8': '#F5E9BF' }]
];

function sourceLayer(name) {
  if (!name) return '';
  const start = sources.wardrobe.indexOf(`<g id="${name}"`);
  if (start < 0) throw new Error(`Missing source wardrobe layer ${name}`);
  const tags = /<\/?g\b[^>]*>/g;
  tags.lastIndex = start;
  let depth = 0;
  for (let match; (match = tags.exec(sources.wardrobe));) {
    depth += match[0].startsWith('</') ? -1 : 1;
    if (!depth) return sources.wardrobe.slice(start, tags.lastIndex);
  }
  throw new Error(`Unbalanced source wardrobe layer ${name}`);
}

function recolor(layer, colors) {
  return layer.replace(/#[A-Fa-f0-9]{6}/g, color => colors[color.toUpperCase()] || color);
}

// Preserve the original illustration paths while changing the baby's proportions.
// Only grouping, existing colors and transforms change; every facial expression,
// speaking mouth and hand-drawn wing contour comes from the acquired Pip layers.
const BABY_PALETTE = { '#F6D36E': '#F7DB91', '#FFE68E': '#FFF0B9', '#FFDE7F': '#FFE4A1', '#F3AE65': '#F0BB81', '#F3B39B': '#F4B9AA' };
const BABY_TRANSFORMS = {
  body: 'translate(61 104) scale(.84 .76) translate(-61 -104)',
  head: 'translate(61 77) scale(1.025) translate(-61 -72)',
  wings: 'translate(61 87) scale(.78 .82) translate(-61 -80)',
  feet: 'translate(61 106) scale(.78 .78) translate(-61 -105)'
};
function svgTree(source) {
  const root = { tag: '#document', attributes: {}, children: [] };
  const stack = [root];
  for (const token of source.match(/<!--[\s\S]*?-->|<(?:[^>"']|"[^"]*"|'[^']*')*>|[^<]+/g) || []) {
    if (token.startsWith('<!--') || token.startsWith('<?')) continue;
    if (token.startsWith('</')) {
      if (stack.length < 2 || stack.pop().tag !== token.slice(2, -1).trim()) throw new Error('Unbalanced Pip source');
    } else if (token.startsWith('<')) {
      const match = /^<([\w:-]+)([\s\S]*?)(\/?)>$/.exec(token);
      if (!match) throw new Error('Unsupported Pip source element');
      const node = { tag: match[1], attributes: {}, children: [] };
      for (const [, key, value] of match[2].matchAll(/([\w:-]+)\s*=\s*("[^"]*"|'[^']*')/g)) node.attributes[key] = value.slice(1, -1);
      stack.at(-1).children.push(node);
      if (!match[3]) stack.push(node);
    } else if (token.trim()) stack.at(-1).children.push(token.trim());
  }
  if (stack.length !== 1 || root.children.length !== 1) throw new Error('Incomplete Pip source');
  return root.children[0];
}
function svgText(node) {
  if (typeof node === 'string') return node;
  const attributes = Object.entries(node.attributes).map(([key, value]) => ` ${key}="${value}"`).join('');
  return node.children.length ? `<${node.tag}${attributes}>${node.children.map(svgText).join('')}</${node.tag}>` : `<${node.tag}${attributes} />`;
}
function wrapBaby(children, kind) {
  return { tag: 'g', attributes: { transform: BABY_TRANSFORMS[kind] }, children };
}
function buildBaby() {
  const result = {};
  const babySources = { ...sources, expressions: buildExpressionSheet(sources) };
  for (const [kind, suffix] of [['regular', ''], ['idle', '-idle'], ['parts', '-parts'], ['expressions', '-expressions'], ['expressionHeads', '-expression-heads']]) {
    const sheet = svgTree(babySources[kind]);
    sheet.children = sheet.children.filter(child => child.tag !== 'title');
    sheet.children.unshift({ tag: 'title', attributes: {}, children: [`Pip Baby ${kind}; original Pip illustration layers with infant proportions and cream plumage`] });
    const frames = sheet.children.find(child => child.tag === 'g').children;
    frames.forEach((frame, index) => {
      if (kind === 'parts' || kind === 'expressionHeads') {
        const part = kind === 'expressionHeads' ? 'head' : ['body', 'head', 'wings', 'wings', 'feet', 'feet'][index];
        frame.children = [wrapBaby(frame.children, part)];
        return;
      }
      const head = [];
      const body = [];
      const wings = [];
      const feet = [];
      const shadow = [];
      for (const child of frame.children) {
        const attributes = child.attributes || {};
        if (attributes.fill === '#65708A') {
          if (attributes.rx) attributes.rx = '31';
          shadow.push(child);
        } else if (attributes.fill === '#F3AE65') feet.push(child);
        else if (attributes.fill === '#F6D36E' || attributes.stroke === '#FFEDA9') body.push(child);
        else if (attributes.fill === '#FFDE7F' || attributes.stroke === '#D4AE58') wings.push(child);
        else head.push(child);
      }
      frame.children = [...shadow, wrapBaby(feet, 'feet'), wrapBaby(body, 'body'), wrapBaby(wings, 'wings'), wrapBaby(head, 'head')];
    });
    result[`pip-spring${suffix}.svg`] = recolor(svgText(sheet), BABY_PALETTE) + '\n';
  }
  return result;
}

const art = path.join(__dirname, 'art');
const runtimeArt = path.join(ROOT, 'assets/images/mascots/growth');
const runtimeAudio = path.join(ROOT, 'assets/audio/pip-growth');
fs.mkdirSync(art, { recursive: true });
fs.mkdirSync(runtimeArt, { recursive: true });
fs.mkdirSync(runtimeAudio, { recursive: true });
fs.mkdirSync(path.join(__dirname, 'audio'), { recursive: true });
fs.mkdirSync(path.join(ROOT, 'data'), { recursive: true });
const actions = [];
const voiceIds = [];
const BABY_STAGE = [0, 'baby', 'Baby Pip', null, null, 'A downy little duckling with a round face, tiny wings, and a gentle first hello.', 'wave', 'Hello wave', "Hello! I'm Pip.", '#b7824e', '#fbefdc', BABY_PALETTE];
const stages = [BABY_STAGE, ...STAGES].map(([age, id, name, head, body, description, action, actionLabel, text, accent, background, palette]) => {
  if (!actions.includes(action)) actions.push(action);
  const voiceId = `pip-growth-${age === 0 ? 'sprout' : id}`;
  if (!voiceIds.includes(voiceId)) voiceIds.push(voiceId);
  const selectedBody = body ? recolor(sourceLayer(`${body}-body`), palette).replace(`id="${body}-body"`, 'id="spring-body"') : '<g id="spring-body" />';
  const selectedHead = head ? recolor(sourceLayer(`${head}-head`), palette).replace(`id="${head}-head"`, 'id="spring-head"') : '<g id="spring-head" />';
  const wardrobe = sources.wardrobe.replace(sourceLayer('spring-body'), selectedBody).replace(sourceLayer('spring-head'), selectedHead);
  const sheets = age === 0 ? buildBaby() : buildOutfits({ ...sources, wardrobe });
  // Retain the established file names for ages 3+; identity is age-only metadata.
  const stem = age === 0 ? 'pip-baby' : `pip-lv${age}`;
  const sheetPaths = {};
  const previewPaths = {};
  for (const [kind, suffix] of [['regular', ''], ['idle', '-idle'], ['parts', '-parts'], ['expressions', '-expressions'], ['expressionHeads', '-expression-heads']]) {
    const filename = `${stem}${suffix}.svg`;
    const svg = sheets[`pip-spring${suffix}.svg`].replace(/Pip spring wardrobe[^<]*;/, `Pip age ${age} ${name} ${kind};`);
    fs.writeFileSync(path.join(art, filename), svg);
    fs.writeFileSync(path.join(runtimeArt, filename), svg);
    const sourcePath = `res://assets/images/mascots/growth/${filename}`;
    const imported = `res://.godot/imported/${filename}-${crypto.createHash('md5').update(sourcePath).digest('hex')}.ctex`;
    const importFile = path.join(runtimeArt, filename + '.import');
    if (!fs.existsSync(importFile)) {
      const sourceImport = fs.readFileSync(path.join(ROOT, 'assets/images/mascots/outfits/pip-spring.svg.import'), 'utf8');
      const settings = sourceImport.replace(/^uid=.*\r?\n/m, '')
        .replaceAll('res://assets/images/mascots/outfits/pip-spring.svg', sourcePath)
        .replaceAll('res://.godot/imported/pip-spring.svg-636dd9e9ac4652158402e147298adcb3.ctex', imported);
      fs.writeFileSync(importFile, settings);
    }
    sheetPaths[kind] = `assets/images/mascots/growth/${filename}`;
    previewPaths[kind] = `art/${filename}`;
  }
  return {
    age, label: age === 0 ? 'Baby' : age === 12 ? 'Age 12+' : `Age ${age}`, id, name, description,
    accent, background, compositionStatus: 'proposed-stage-composition',
    source: { head: head ? `${head}-head` : null, body: body ? `${body}-body` : null, palette, ...(age === 0 ? { proportions: BABY_TRANSFORMS } : {}) },
    art: sheetPaths, previewArt: previewPaths,
    actions: [...actions], newAction: { id: action, label: actionLabel },
    voices: [...voiceIds], newVoice: { id: voiceId, text, path: `assets/audio/pip-growth/${age === 0 ? 'sprout' : id}.mp3`, previewPath: `audio/${age === 0 ? 'sprout' : id}.mp3` }
  };
});
const catalog = {
  schemaVersion: 2, title: 'Grow with Pip', status: 'Interactive age-stage design review',
  description: 'Baby Pip and ten age compositions derived from integrated production artwork. Pip appearance follows completed curriculum ages, independently of word-mastery levels. These stages are not a developmental diagnosis.',
  artSource: 'assets/images/mascots/pip-dance-parts.svg',
  wardrobeSource: 'assets/images/mascots/outfits/wardrobe.svg',
  expressionsSource: 'assets/images/mascots/pip-expression-heads.svg',
  expressions: ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink'],
  voice: { provider: 'Microsoft Edge TTS', clientVersion: '7.2.8', profile: PROFILE, postprocessing: 'none', autoplay: false, scope: 'Explicit preview playback or age-growth recognition; never gameplay guidance.' },
  stages
};
fs.writeFileSync(path.join(ROOT, 'data/pip-growth-stages.json'), JSON.stringify(catalog, null, 2) + '\n');
fs.writeFileSync(path.join(__dirname, 'stages.json'), JSON.stringify(catalog, null, 2) + '\n');
for (const weight of [600, 800]) fs.copyFileSync(path.join(ROOT, `assets/fonts/Nunito-${weight}.ttf`), path.join(__dirname, `Nunito-${weight}.ttf`));
if (fs.existsSync(path.join(__dirname, 'Nunito.ttf'))) fs.unlinkSync(path.join(__dirname, 'Nunito.ttf'));
fs.copyFileSync(path.join(ROOT, 'assets/fonts/OFL.txt'), path.join(__dirname, 'FONT-LICENSE.txt'));

// Cache is inside the owned preview tree; ignored temporary files are not shipped.
const cache = path.join(__dirname, '.voice-cache');
fs.mkdirSync(cache, { recursive: true });
const voicedStages = stages.filter((stage, index) => stages.findIndex(item => item.newVoice.id === stage.newVoice.id) === index);
const requests = voicedStages.map(stage => ({
  id: stage.newVoice.id,
  text: stage.newVoice.text,
  output: path.join(cache, crypto.createHash('sha256').update(JSON.stringify(PROFILE) + stage.newVoice.text).digest('hex') + '.mp3')
}));
const batch = { edgeTtsVersion: '7.2.8', profile: PROFILE, cacheDirectory: cache, requests };
fs.writeFileSync(path.join(cache, 'batch.json'), JSON.stringify(batch, null, 2) + '\n');
console.log(`Composed ${stages.length} Pip growth stages and ${stages.length * 5} production-format SVG sheets.`);

if (process.argv.includes('--install-voices')) {
  const files = requests.map((request, index) => {
    const bytes = fs.readFileSync(request.output);
    const target = path.join(__dirname, voicedStages[index].newVoice.previewPath);
    fs.writeFileSync(target, bytes);
    fs.writeFileSync(path.join(ROOT, voicedStages[index].newVoice.path), bytes);
    return { id: request.id, text: request.text, path: voicedStages[index].newVoice.path, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
  });
  fs.writeFileSync(path.join(__dirname, 'audio/manifest.json'), JSON.stringify({ provider: 'Microsoft Edge online TTS', client: 'edge-tts 7.2.8', profile: PROFILE, postprocessing: 'None; original response MP3 bytes.', files }, null, 2) + '\n');
  console.log(`Installed ${files.length} approved-profile preview voices without postprocessing.`);
}
