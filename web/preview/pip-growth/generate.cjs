'use strict';

// Compose review stages from the shipped Pip artwork. No source art is redrawn.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../../..');
const { readSources, buildOutfits } = require(path.join(ROOT, 'tools/generate-pip-outfits.cjs'));
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
const stages = STAGES.map(([level, id, name, head, body, description, action, actionLabel, text, accent, background, palette]) => {
  actions.push(action);
  voiceIds.push(`pip-growth-${id}`);
  const selectedBody = recolor(sourceLayer(`${body}-body`), palette).replace(`id="${body}-body"`, 'id="spring-body"');
  const selectedHead = head ? recolor(sourceLayer(`${head}-head`), palette).replace(`id="${head}-head"`, 'id="spring-head"') : '<g id="spring-head" />';
  const wardrobe = sources.wardrobe.replace(sourceLayer('spring-body'), selectedBody).replace(sourceLayer('spring-head'), selectedHead);
  const sheets = buildOutfits({ ...sources, wardrobe });
  const stem = `pip-lv${level}`;
  const sheetPaths = {};
  const previewPaths = {};
  for (const [kind, suffix] of [['regular', ''], ['idle', '-idle'], ['parts', '-parts'], ['expressions', '-expressions'], ['expressionHeads', '-expression-heads']]) {
    const filename = `${stem}${suffix}.svg`;
    const svg = sheets[`pip-spring${suffix}.svg`].replace(/Pip spring wardrobe[^<]*;/, `Pip level ${level} ${name} ${kind};`);
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
    level, label: level === 12 ? 'Lv 12+' : `Lv ${level}`, id, name, description,
    accent, background, compositionStatus: 'proposed-stage-composition',
    source: { head: head ? `${head}-head` : null, body: `${body}-body`, palette },
    art: sheetPaths, previewArt: previewPaths,
    actions: [...actions], newAction: { id: action, label: actionLabel },
    voices: [...voiceIds], newVoice: { id: `pip-growth-${id}`, text, path: `assets/audio/pip-growth/${id}.mp3`, previewPath: `audio/${id}.mp3` }
  };
});
const catalog = {
  schemaVersion: 1, title: 'Grow with Pip', status: 'Interactive growth-stage design review',
  description: 'Ten proposed stage compositions derived from integrated Pip production artwork. Age labels describe the learning journey, not a physical transformation or a developmental diagnosis.',
  artSource: 'assets/images/mascots/pip-dance-parts.svg',
  wardrobeSource: 'assets/images/mascots/outfits/wardrobe.svg',
  expressionsSource: 'assets/images/mascots/pip-expression-heads.svg',
  expressions: ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink'],
  voice: { provider: 'Microsoft Edge TTS', clientVersion: '7.2.8', profile: PROFILE, postprocessing: 'none', autoplay: false, scope: 'Explicit preview playback or level-up recognition; never gameplay guidance.' },
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
const requests = stages.map(stage => ({
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
    const target = path.join(__dirname, 'audio', `${stages[index].id}.mp3`);
    fs.writeFileSync(target, bytes);
    fs.writeFileSync(path.join(runtimeAudio, `${stages[index].id}.mp3`), bytes);
    return { id: request.id, text: request.text, path: stages[index].newVoice.path, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
  });
  fs.writeFileSync(path.join(__dirname, 'audio/manifest.json'), JSON.stringify({ provider: 'Microsoft Edge online TTS', client: 'edge-tts 7.2.8', profile: PROFILE, postprocessing: 'None; original response MP3 bytes.', files }, null, 2) + '\n');
  console.log(`Installed ${files.length} approved-profile preview voices without postprocessing.`);
}
