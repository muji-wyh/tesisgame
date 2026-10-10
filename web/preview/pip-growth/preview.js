'use strict';

const SVG = 'http://www.w3.org/2000/svg';
const byId = id => document.getElementById(id);
const EXPRESSIONS = ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink'];
const JOINTS = [[61, 98], [61, 72], [33, 78], [88, 78], [40, 103], [80, 103]];
const ORDER = [4, 5, 0, 1, 2, 3];
const ACTIONS = {
  wave: ['Hello wave', 1800], look: ['Curious look', 1900], 'high-five': ['High five', 1700],
  peekaboo: ['Peekaboo', 2100], stretch: ['Wing stretch', 2200], hop: ['Happy hop', 1700],
  'dance-sway': ['Gentle sway', 2800], flutter: ['Wing flutter', 1900],
  'dance-wave': ['Two-step wave', 2900], 'dance-hop': ['Celebration dance', 3200]
};
let catalog;
let selectedIndex = 0;
let rig;
let activeAction;
let frameHandle;
let reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let selectionToken = 0;
let audioToken = 0;
let player;
let playing = false;
let idleStart = performance.now();
const artCache = new Map();
const staticCards = new Map();

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(SVG, name);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
  return node;
}

function cleanClone(source) {
  const clone = source.cloneNode(true);
  clone.removeAttribute('transform');
  clone.removeAttribute('id');
  for (const child of clone.querySelectorAll('[id]')) child.removeAttribute('id');
  return clone;
}

async function readSheet(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Unable to load artwork: ${url}`);
  const document = new DOMParser().parseFromString(await response.text(), 'image/svg+xml');
  if (document.querySelector('parsererror')) throw new Error(`Invalid artwork: ${url}`);
  const outer = [...document.documentElement.children].find(child => child.localName === 'g');
  if (!outer) throw new Error(`Missing layered artwork: ${url}`);
  return { outer, frames: [...outer.children] };
}

function stageArt(stage) {
  if (!artCache.has(stage.id)) artCache.set(stage.id, Promise.all([
    readSheet(stage.previewArt.parts), readSheet(stage.previewArt.expressionHeads),
    readSheet(stage.previewArt.expressions)
  ]).then(([parts, heads, expressions]) => ({ parts, heads, expressions })));
  return artCache.get(stage.id);
}

function renderMiniature(art, expression = 'proud') {
  const svg = svgNode('svg', { viewBox: '-9 -9 138 134', 'aria-hidden': 'true' });
  const outer = cleanClone(art.expressions.outer);
  outer.replaceChildren(cleanClone(art.expressions.frames[EXPRESSIONS.indexOf(expression)]));
  svg.append(outer);
  return svg;
}

function createRig(art) {
  const svg = svgNode('svg', { viewBox: '-18 -31 156 156', 'aria-hidden': 'true' });
  const shadow = svgNode('ellipse', { cx: 61, cy: 112, rx: 39, ry: 5, fill: '#65708A', opacity: '.14' });
  svg.append(shadow);
  const outer = cleanClone(art.parts.outer);
  outer.replaceChildren();
  const layers = art.parts.frames.map(part => {
    const layer = svgNode('g');
    layer.append(cleanClone(part));
    return layer;
  });
  for (const index of ORDER) outer.append(layers[index]);
  svg.append(outer);
  return { svg, layers, shadow, art, expression: '' };
}

function setExpression(expression) {
  if (!rig || rig.expression === expression) return;
  rig.expression = expression;
  rig.layers[1].replaceChildren(cleanClone(rig.art.heads.frames[EXPRESSIONS.indexOf(expression)]));
}

function smooth(start, end, value) {
  const t = Math.min(1, Math.max(0, (value - start) / (end - start)));
  return t * t * (3 - 2 * t);
}

function blankPose() { return Array.from({ length: 6 }, () => [0, 0, 0]); }

function actionPose(name, p) {
  const pose = blankPose();
  const e = smooth(0, .14, p) * (1 - smooth(.82, 1, p));
  const beat = Math.sin(p * Math.PI * 4);
  let face = 'proud';
  if (name === 'wave') {
    pose[2][2] = (79 + Math.sin(p * Math.PI * 6) * 15) * e;
    pose[1][2] = 4 * e;
    face = p > .45 && p < .58 ? 'wink' : 'encourage';
  } else if (name === 'look') {
    const direction = Math.sin(p * Math.PI * 2);
    pose[1] = [direction * 2.8 * e, -.7 * e, direction * 8 * e];
    pose[0][2] = direction * 2 * e;
    face = 'thinking';
  } else if (name === 'high-five') {
    pose[3] = [0, -1.2 * e, -82 * e];
    pose[1] = [2 * e, -1.2 * e, -4 * e];
    pose[0][2] = 2 * e;
    face = 'delighted';
  } else if (name === 'peekaboo') {
    const hiding = smooth(0, .16, p) * (1 - smooth(.43, .59, p));
    pose[2][2] = 126 * hiding + 58 * e * (1 - hiding);
    pose[3][2] = -126 * hiding - 58 * e * (1 - hiding);
    pose[1][1] = 2.5 * hiding;
    face = p < .48 ? 'blink' : p < .63 ? 'surprised' : 'delighted';
  } else if (name === 'stretch') {
    pose[2][2] = 66 * e;
    pose[3][2] = -66 * e;
    pose[0][1] = -2 * e;
    pose[1][1] = -3.5 * e;
    face = p < .5 ? 'blink' : 'proud';
  } else if (name === 'hop') {
    // Feet touch down before the body and head absorb the landing.
    const jump = Math.max(0, Math.sin((p - .18) / .47 * Math.PI)) * (p < .65 && p > .18 ? 1 : 0);
    const crouch = Math.sin(Math.min(1, p / .18) * Math.PI) * (p < .18 ? 4 : 0);
    const settle = Math.sin(Math.min(1, Math.max(0, (p - .65) / .2)) * Math.PI) * (p > .65 && p < .85 ? 3 : 0);
    pose.forEach(part => { part[1] = -17 * jump; });
    pose[0][1] += crouch + settle;
    pose[1][1] += crouch * 1.3 + settle * 1.5;
    pose[2][2] = 82 * e;
    pose[3][2] = -82 * e;
    pose[4][2] = -12 * jump;
    pose[5][2] = 12 * jump;
    face = p < .18 ? 'surprised' : 'delighted';
  } else if (name === 'flutter') {
    pose[2][2] = (76 + Math.sin(p * Math.PI * 15) * 18) * e;
    pose[3][2] = -(76 + Math.sin(p * Math.PI * 15) * 18) * e;
    pose[1][2] = 4 * e;
    face = 'delighted';
  } else if (name.startsWith('dance')) {
    const left = Math.max(0, beat) * e;
    const right = Math.max(0, -beat) * e;
    const sway = name === 'dance-sway';
    const hop = name === 'dance-hop';
    const lift = hop ? Math.abs(Math.sin(p * Math.PI * 3)) * 12 * e : Math.abs(beat) * 1.6 * e;
    const hips = sway ? beat * 6 * e : beat * 3 * e;
    pose[0] = [hips, -lift, (sway ? -5 : 3) * beat * e];
    pose[1] = [hips * .5, -lift, (sway ? 4 : -2) * beat * e];
    pose[2] = [hips, -lift, hop ? 85 * e : (sway ? 35 * e + 32 * left : 96 * left)];
    pose[3] = [hips, -lift, hop ? -85 * e : (sway ? -35 * e - 32 * right : -96 * right)];
    pose[4] = [hips * .2, hop ? -lift : -4 * right, -7 * left];
    pose[5] = [hips * .2, hop ? -lift : -4 * left, 7 * right];
    face = p > .45 && p < .5 ? 'blink' : p > .83 ? 'proud' : 'delighted';
  }
  return { pose, face };
}

function applyPose(pose) {
  if (!rig) return;
  pose.forEach(([x, y, angle], index) => {
    const [px, py] = JOINTS[index];
    rig.layers[index].setAttribute('transform', `translate(${x} ${y}) rotate(${angle} ${px} ${py})`);
  });
  const lift = Math.max(0, -pose[0][1]) / 23;
  rig.shadow.setAttribute('rx', String(39 - lift * 9));
  rig.shadow.setAttribute('opacity', String(.14 - lift * .05));
}

function updateActionButtons() {
  document.querySelectorAll('.action-button').forEach(button => button.setAttribute('aria-pressed', String(activeAction?.id === button.dataset.action)));
}

function stopAction() {
  activeAction = null;
  updateActionButtons();
  if (rig) {
    applyPose(blankPose());
    setExpression('proud');
  }
}

function runAction(id) {
  const stage = catalog.stages[selectedIndex];
  if (!stage.actions.includes(id) || !rig) return;
  stopAction();
  if (reducedMotion) {
    setExpression('delighted');
    byId('pose-caption').textContent = `${ACTIONS[id][0]} · a happy pose with reduced motion.`;
    return;
  }
  activeAction = { id, start: performance.now(), duration: ACTIONS[id][1] };
  byId('pose-caption').textContent = ACTIONS[id][0];
  updateActionButtons();
  requestFrame();
}

function requestFrame() {
  if (!frameHandle && !document.hidden && !reducedMotion && rig) frameHandle = requestAnimationFrame(animate);
}

function animate(now) {
  frameHandle = null;
  if (!rig || document.hidden || reducedMotion) return;
  const idle = (now - idleStart) / 1000;
  let pose = blankPose();
  let face = 'neutral';
  if (activeAction) {
    const p = Math.min(1, (now - activeAction.start) / activeAction.duration);
    ({ pose, face } = actionPose(activeAction.id, p));
    if (p >= 1) {
      activeAction = null;
      idleStart = now;
      byId('pose-caption').textContent = 'Ready for another little adventure.';
      updateActionButtons();
    }
  } else {
    const breath = Math.sin(idle * Math.PI * 2 / 3.8);
    pose[0][1] = breath * .32;
    pose[1][1] = breath * .25;
    pose[2][1] = pose[3][1] = breath * .25;
    face = idle % 4.6 > 4.42 ? 'blink' : 'neutral';
  }
  if (playing && !activeAction) face = idle % 4.6 > 4.42 ? 'blink' : 'encourage';
  applyPose(pose);
  setExpression(face);
  requestFrame();
}

function setAudioState(isPlaying) {
  playing = isPlaying;
  byId('play-voice').setAttribute('aria-pressed', String(playing));
  byId('play-voice').setAttribute('aria-label', playing ? 'Stop voice line' : 'Play voice line');
  byId('play-voice').querySelector('span').textContent = playing ? 'Stop' : 'Listen';
}

function stopVoice() {
  audioToken += 1;
  if (player) {
    player.pause();
    player.currentTime = 0;
    player.removeAttribute('src');
    player.load();
    player = null;
  }
  setAudioState(false);
}

function voiceSelection() {
  return catalog.stages.find(stage => stage.newVoice.id === byId('voice-select').value)?.newVoice;
}

function updateVoice() {
  stopVoice();
  byId('voice-text').textContent = `“${voiceSelection().text}”`;
  byId('voice-note').textContent = "Ava's gentle voice · plays only when you tap";
}

async function playVoice() {
  if (playing) { stopVoice(); return; }
  stopVoice();
  const voice = voiceSelection();
  const token = ++audioToken;
  player = new Audio(voice.previewPath);
  const current = player;
  current.preload = 'auto';
  current.addEventListener('ended', () => { if (token === audioToken) setAudioState(false); });
  current.addEventListener('error', () => {
    if (token !== audioToken) return;
    setAudioState(false);
    byId('voice-note').textContent = 'This voice could not load. Please try again.';
  });
  try {
    setAudioState(true);
    await current.play();
    if (token !== audioToken) current.pause();
  } catch {
    if (token !== audioToken) return;
    setAudioState(false);
    byId('voice-note').textContent = 'Tap Listen to allow audio playback.';
  }
}

async function selectStage(index, scroll = false) {
  index = Math.min(catalog.stages.length - 1, Math.max(0, index));
  const token = ++selectionToken;
  stopVoice();
  stopAction();
  selectedIndex = index;
  const stage = catalog.stages[index];
  document.documentElement.style.setProperty('--accent', stage.accent);
  document.documentElement.style.setProperty('--stage', stage.background);
  byId('stage-counter').textContent = `${String(index + 1).padStart(2, '0')} / ${catalog.stages.length}`;
  byId('age-label').textContent = stage.label;
  byId('stage-name').textContent = stage.name;
  byId('stage-name-small').textContent = `${stage.label} · ${stage.name}`;
  byId('stage-description').textContent = stage.description;
  byId('new-move-name').textContent = stage.newAction.label;
  byId('move-count').textContent = `${stage.actions.length} ${stage.actions.length === 1 ? 'move' : 'moves'}`;
  byId('voice-count').textContent = `${stage.voices.length} ${stage.voices.length === 1 ? 'hello' : 'hellos'}`;
  byId('pose-caption').textContent = 'Ready to say hello.';
  byId('character-art').setAttribute('aria-label', `${stage.label} ${stage.name}, ${stage.description}`);
  byId('previous-stage').disabled = index === 0;
  byId('next-stage').disabled = index === catalog.stages.length - 1;
  document.querySelectorAll('[data-age]').forEach(button => button.setAttribute('aria-current', String(Number(button.dataset.age) === stage.age)));
  const actions = stage.actions.map(id => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'action-button';
    button.dataset.action = id;
    button.dataset.new = String(id === stage.newAction.id);
    button.setAttribute('aria-pressed', 'false');
    button.textContent = ACTIONS[id][0];
    button.addEventListener('click', () => runAction(id));
    return button;
  });
  byId('action-list').replaceChildren(...actions);
  const options = catalog.stages.filter((item, index) => stage.voices.includes(item.newVoice.id) && catalog.stages.findIndex(previous => previous.newVoice.id === item.newVoice.id) === index).reverse().map(item => {
    const option = document.createElement('option');
    option.value = item.newVoice.id;
    option.textContent = `${item.label} · ${item.newVoice.text}`;
    return option;
  });
  byId('voice-select').replaceChildren(...options);
  byId('voice-select').value = stage.newVoice.id;
  updateVoice();
  history.replaceState(null, '', `#age${stage.age}`);
  const art = await stageArt(stage);
  if (token !== selectionToken) return;
  rig = createRig(art);
  byId('character-art').replaceChildren(rig.svg);
  setExpression('proud');
  idleStart = performance.now();
  requestFrame();
  if (scroll) byId('stage-review').scrollIntoView({ block: 'start', behavior: reducedMotion ? 'instant' : 'smooth' });
}

async function initialize() {
  const response = await fetch('stages.json');
  if (!response.ok) throw new Error('The growth-stage catalog could not load.');
  catalog = await response.json();
  catalog.stages.forEach((stage, index) => {
    const tab = document.createElement('button');
    tab.type = 'button';
    tab.className = 'age-tab';
    tab.dataset.age = stage.age;
    tab.textContent = stage.label;
    tab.addEventListener('click', () => selectStage(index).catch(showError));
    byId('age-picker').append(tab);
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'journey-card';
    card.dataset.age = stage.age;
    card.setAttribute('aria-label', `Meet ${stage.label} ${stage.name}`);
    const miniature = document.createElement('span');
    miniature.className = 'miniature';
    const age = document.createElement('span');
    age.className = 'mini-age';
    age.textContent = stage.label;
    const name = document.createElement('strong');
    name.textContent = stage.name;
    const moves = document.createElement('span');
    moves.className = 'mini-moves';
    moves.textContent = `${stage.actions.length} ${stage.actions.length === 1 ? 'move' : 'moves'} · ${stage.voices.length} ${stage.voices.length === 1 ? 'hello' : 'hellos'}`;
    card.append(miniature, age, name, moves);
    card.addEventListener('click', () => selectStage(index, true).catch(showError));
    byId('journey-grid').append(card);
    staticCards.set(stage.id, miniature);
  });
  byId('play-new-move').addEventListener('click', () => runAction(catalog.stages[selectedIndex].newAction.id));
  byId('previous-stage').addEventListener('click', () => selectStage(selectedIndex - 1).catch(showError));
  byId('next-stage').addEventListener('click', () => selectStage(selectedIndex + 1).catch(showError));
  byId('play-voice').addEventListener('click', playVoice);
  byId('voice-select').addEventListener('change', updateVoice);
  byId('motion-toggle').setAttribute('aria-pressed', String(reducedMotion));
  byId('motion-toggle').addEventListener('click', () => {
    reducedMotion = !reducedMotion;
    byId('motion-toggle').setAttribute('aria-pressed', String(reducedMotion));
    stopAction();
    cancelAnimationFrame(frameHandle);
    frameHandle = null;
    byId('pose-caption').textContent = reducedMotion ? 'Reduced motion · still full of curiosity.' : 'Ready to say hello.';
    requestFrame();
  });
  const requested = Number(location.hash.replace('#age', ''));
  const index = catalog.stages.findIndex(stage => stage.age === requested);
  await selectStage(index < 0 ? 0 : index);
  await Promise.all(catalog.stages.map(async stage => {
    const art = await stageArt(stage);
    staticCards.get(stage.id).replaceChildren(renderMiniature(art));
  }));
  document.body.dataset.ready = 'true';
}

function showError(error) {
  byId('load-error').hidden = false;
  byId('load-error').textContent = error.message || 'The preview could not load. Please refresh to try again.';
}

document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    stopVoice();
    stopAction();
    cancelAnimationFrame(frameHandle);
    frameHandle = null;
  } else {
    idleStart = performance.now();
    requestFrame();
  }
});
window.addEventListener('pagehide', stopVoice);
window.pipGrowthPreview = Object.freeze({
  snapshot: () => ({ age: catalog?.stages[selectedIndex].age, action: activeAction?.id || null, playing, reducedMotion, expression: rig?.expression, ready: document.body.dataset.ready === 'true' })
});
initialize().catch(showError);
