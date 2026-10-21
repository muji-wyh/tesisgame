'use strict';

// Catalog the authored age artwork while preserving the approved voice repertoire.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../../..');
const PROFILE = { voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%' };
const STAGES = [
  [
    3,
    "sprout",
    "Sprout",
    "wave",
    "Hello wave",
    "Hello! I'm Pip.",
    "#3c8771",
    "#eaf3e7"
  ],
  [
    4,
    "little-helper",
    "Little Helper",
    "look",
    "Curious look",
    "Let's grow together.",
    "#4d7954",
    "#ecf2db"
  ],
  [
    5,
    "curious-scout",
    "Curious Scout",
    "high-five",
    "High five",
    "I wonder what we will find.",
    "#9c6c2d",
    "#fbefcb"
  ],
  [
    6,
    "story-finder",
    "Story Finder",
    "peekaboo",
    "Peekaboo",
    "Every word can tell a story.",
    "#a55867",
    "#f9e6e5"
  ],
  [
    7,
    "trail-buddy",
    "Trail Buddy",
    "stretch",
    "Wing stretch",
    "A little practice goes a long way.",
    "#657e44",
    "#edf1dc"
  ],
  [
    8,
    "wayfinder",
    "Wayfinder",
    "hop",
    "Happy hop",
    "We can find a new way together.",
    "#36857e",
    "#e2f1ed"
  ],
  [
    9,
    "word-maker",
    "Word Maker",
    "dance-sway",
    "Gentle sway",
    "Let's make something with our words.",
    "#627d9b",
    "#e8edf6"
  ],
  [
    10,
    "sky-explorer",
    "Sky Explorer",
    "flutter",
    "Wing flutter",
    "There is a whole world to explore.",
    "#8e7946",
    "#f3ecd8"
  ],
  [
    11,
    "bright-navigator",
    "Bright Navigator",
    "dance-wave",
    "Two-step wave",
    "We are learning more, one word at a time.",
    "#4e7897",
    "#e6eff5"
  ],
  [
    12,
    "kind-guide",
    "Kind Guide",
    "dance-hop",
    "Celebration dance",
    "Look how far we have come. Keep being curious!",
    "#456f65",
    "#e5eee2"
  ]
];

const DESIGNS = {
  0: 'A cream duckling sitting in a broken eggshell, with a huge round face, downy curl and tiny feet.',
  3: 'A wobbly toddler with a turquoise bib, soft play shorts, a double curl and close-set feet.',
  4: 'A preschool helper in blue overalls and a broad sun visor, with short helping wings.',
  5: 'A playful kindergartener in a golden rain hood, roomy coat and tall green rain boots.',
  6: 'A first-school companion with an oversized turquoise backpack and coral cardigan, standing newly upright.',
  7: 'An active schoolchild in a green sports shirt, white headband and sneakers, with longer wings.',
  8: 'An independent schoolchild in a roomy violet hoodie, with a broad hood and kangaroo pocket.',
  9: 'A curious maker with round blue glasses, denim overalls and a swept feather crest.',
  10: 'An adventurous older child in a backward blue cap, an open overshirt and canvas sneakers.',
  11: 'A confident preteen in a warm varsity jacket, headphones around the neck and a taller stance.',
  12: 'A composed young guide with a small swept-feather head, long teal jacket, messenger bag and longer legs.'
};
const art = path.join(__dirname, 'art');
const runtimeArt = path.join(ROOT, 'assets/images/mascots/growth');
const runtimeAudio = path.join(ROOT, 'assets/audio/pip-growth');
const actions = [], voiceIds = [];
const BABY_STAGE = [0, 'baby', 'Baby Pip', 'wave', 'Hello wave', "Hello! I'm Pip.", '#b7824e', '#fbefdc'];
const stages = [BABY_STAGE, ...STAGES].map(([age, id, name, action, actionLabel, text, accent, background]) => {
  if (!actions.includes(action)) actions.push(action);
  const voiceId = `pip-growth-${age === 0 ? 'sprout' : id}`;
  if (!voiceIds.includes(voiceId)) voiceIds.push(voiceId);
  const model = JSON.parse(fs.readFileSync(path.join(ROOT, `build/pip-models/${age}/model.json`), 'utf8'));
  const storybook = model.style === 'storybook';
  if (storybook && (typeof model.artSource !== 'string' || !model.artSource.trim())) {
    throw new Error(`Age ${age}: storybook artwork must identify its authoring source.`);
  }
  const artSource = storybook ? model.artSource : 'tools/pip-growth/render.py';
  const frameOffsetY = Number.isFinite(model.frameOffsetY) ? model.frameOffsetY : 3;
  const stem = age === 0 ? 'pip-baby' : `pip-lv${age}`;
  const sheetPaths = {}, previewPaths = {};
  for (const [kind, suffix] of [['regular', ''], ['idle', '-idle'], ['parts', '-parts'], ['expressions', '-expressions'], ['expressionHeads', '-expression-heads']]) {
    const filename = `${stem}${suffix}.png`;
    const bytes = fs.readFileSync(path.join(runtimeArt, filename));
    const previewPath = path.join(art, filename);
    // Assembly already writes these files. Avoid reopening identical atlases
    // while a local preview or image inspector may still be reading them.
    if (!fs.existsSync(previewPath) || !fs.readFileSync(previewPath).equals(bytes)) {
      fs.copyFileSync(path.join(runtimeArt, filename), previewPath);
    }
    const sourcePath = `res://assets/images/mascots/growth/${filename}`;
    const imported = `res://.godot/imported/${filename}-${crypto.createHash('md5').update(sourcePath).digest('hex')}.ctex`;
    if (!fs.existsSync(path.join(runtimeArt, filename + '.import'))) fs.writeFileSync(path.join(runtimeArt, filename + '.import'), `[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="${imported}"\nmetadata={\n"vram_texture": false\n}\n\n[deps]\n\nsource_file="${sourcePath}"\ndest_files=["${imported}"]\n\n[params]\n\ncompress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\ncompress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\nprocess/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\n`);
    sheetPaths[kind] = `assets/images/mascots/growth/${filename}`;
    previewPaths[kind] = `art/${filename}`;
  }
  return {
    age, label: age === 0 ? 'Baby' : age === 12 ? 'Age 12+' : `Age ${age}`, id, name, description: DESIGNS[age],
    accent, background, compositionStatus: storybook ? 'integrated-storybook-age-artwork' : 'integrated-sculpted-age-model',
    source: {
      model: artSource, assembly: 'tools/pip-growth/assemble.py', form: model.form, frameOffsetY,
      render: storybook ? model.render || 'Project-authored storybook vectors; transparent articulated layers; 360 px cells' : 'Blender 5.2 Cycles; transparent orthographic layers; 360 px cells'
    },
    art: sheetPaths, previewArt: previewPaths,
    motionPivots: model.motionPivots.map(([x, y]) => [x, y + frameOffsetY]), shadowRadius: model.shadowRadius,
    actions: [...actions], newAction: { id: action, label: actionLabel },
    voices: [...voiceIds], newVoice: { id: voiceId, text, path: `assets/audio/pip-growth/${age === 0 ? 'sprout' : id}.mp3`, previewPath: `audio/${age === 0 ? 'sprout' : id}.mp3` }
  };
});
const storybookStages = stages.filter(stage => stage.compositionStatus === 'integrated-storybook-age-artwork');
const allStorybook = storybookStages.length === stages.length;
const mixedArtwork = storybookStages.length > 0 && !allStorybook;
const catalog = {
  schemaVersion: 3, title: 'Grow with Pip',
  status: allStorybook ? 'Integrated storybook age artwork with a local interactive review' : mixedArtwork ? 'Integrated age artwork with a local interactive review' : 'Integrated sculpted age models with a local interactive review',
  description: `${allStorybook ? 'Eleven storybook duck illustrations adapted from the original project Pip vectors' : mixedArtwork ? 'Eleven authored duck characters' : 'Eleven authored Blender duck models'} express growth through face, crown, body, wings, legs and everyday clothing. Appearance follows completed curriculum ages independently of word mastery. These playful stages are not a developmental diagnosis.`,
  artSource: allStorybook ? stages[0].source.model : 'tools/pip-growth/render.py',
  designReference: 'assets/images/mascots/pip-dance-parts.svg',
  expressions: ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink'],
  voice: { provider: 'Microsoft Edge TTS', clientVersion: '7.2.8', profile: PROFILE, postprocessing: 'none', autoplay: false, scope: 'Explicit preview playback or age-growth recognition; never gameplay guidance.' },
  stages
};
fs.writeFileSync(path.join(ROOT, 'data/pip-growth-stages.json'), JSON.stringify(catalog, null, 2) + '\n');
fs.writeFileSync(path.join(__dirname, 'stages.json'), JSON.stringify(catalog, null, 2) + '\n');
require('../../../tools/pip-growth/motions.cjs').generate(ROOT);

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
console.log(`Composed ${stages.length} Pip growth stages and ${stages.length * 5} production-format PNG sheets.`);

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
