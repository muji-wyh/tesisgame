'use strict';

// Authored poses for Pip's six articulated artwork layers, in 120-unit atlas space.
// Each beat has a physical purpose; holds repeat a pose instead of oscillating forever.
const fs = require('node:fs');
const path = require('node:path');
const clips = {};
const stages = {};
const pose = (body = [0, 0, 0], head = [0, 0, 0], left = [0, 0, 0], right = [0, 0, 0], feet = [[0, 0, 0], [0, 0, 0]]) =>
  [body, head, left, right, ...feet];
const rest = pose();
const beat = (time, parts, face = 'encourage') => ({ time, parts, face });
function clip(age, id, label, description, seconds, beats, still = .5, inset = 0) {
  clips[id] = { label, description, seconds, still, inset,
    beats: [beat(0, rest, 'neutral'), ...beats, beat(1, rest, 'neutral')] };
  (stages[age] ||= []).push(id);
}

clip(0, 'shell-rock', 'Shell wiggle', 'A seated duckling tests its balance inside the shell; its heavy head follows a beat late.', 2.6, [
  beat(.16, pose([0, 0, -4], [1, 0, 5], [0, 0, 24], [0, 0, -12]), 'surprised'),
  beat(.36, pose([0, 0, 5], [-1, 1, -6], [0, 0, 12], [0, 0, -33])),
  beat(.56, pose([0, 0, -3], [1, 0, 4], [0, 0, 35], [0, 0, -15])),
  beat(.77, pose([0, 0, 1], [0, 1, -2], [0, 0, 12], [0, 0, -12]), 'encourage')
], .56);
clip(0, 'sleepy-nuzzle', 'Sleepy nuzzle', 'A slow sleepy head tuck, tiny wing cuddle and bright-eyed recovery; shell and feet stay planted.', 3.0, [
  beat(.23, pose([0, 1, 0], [-2, 3, -9], [0, 1, 45], [0, 1, -18]), 'sleepy'),
  beat(.49, pose([0, 1, 0], [-2, 4, -11], [0, 1, 48], [0, 1, -18]), 'blink'),
  beat(.7, pose([0, 0, 0], [0, -1, 3], [0, 0, 20], [0, 0, -20]), 'surprised'),
  beat(.84, pose([0, 0, 0], [0, 0, 2], [0, 0, 10], [0, 0, -10]), 'encourage')
], .3);
clip(3, 'toddler-wobble', 'Wobbly steps', 'Two tentative weight shifts with a small lifted foot and wings spread for balance.', 2.5, [
  beat(.18, pose([-2, 1, -4], [-1, 0, 5], [-2, 1, 47], [-2, 1, -35], [[0, 0, 0], [0, -3, 9]]), 'surprised'),
  beat(.37, pose([0, 2, 0], [1, 3, -3], [0, 2, 30], [0, 2, -30])),
  beat(.57, pose([2, 1, 4], [1, 0, -5], [2, 1, 35], [2, 1, -47], [[0, -3, -9], [0, 0, 0]])),
  beat(.79, pose([0, 1, 0], [0, 2, 2], [0, 1, 20], [0, 1, -20]), 'proud')
], .57);
clip(3, 'tiny-clap', 'Little claps', 'An eager two-beat wing clap with a delayed delighted head bob.', 2.3, [
  beat(.17, pose([0, 1, 0], [0, 0, 0], [0, 1, 62], [0, 1, -62]), 'surprised'),
  beat(.32, pose([0, 0, 0], [0, -1, 0], [2, 0, -55], [-2, 0, 55])),
  beat(.45, pose([0, 1, 0], [0, 2, 3], [0, 1, 62], [0, 1, -62])),
  beat(.6, pose([0, 0, 0], [0, -1, -2], [2, 0, -55], [-2, 0, 55])),
  beat(.79, pose([0, 1, 0], [0, 2, 0], [0, 1, 30], [0, 1, -30]), 'proud')
], .45);
clip(4, 'curious-peek', 'Curious peek', 'A preschooler leans out, checks the other side and peeks above its visor.', 2.7, [
  beat(.2, pose([-2, 1, -3], [-4, 1, -10], [-2, 1, 18], [-2, 1, -12]), 'thinking'),
  beat(.4, pose([2, 0, 3], [4, -1, 11], [2, 0, 12], [2, 0, -25]), 'surprised'),
  beat(.61, pose([0, -1, 0], [0, -3, 0], [0, -1, 40], [0, -1, -40])),
  beat(.8, pose([0, 0, 0], [0, 0, 4], [0, 0, 20], [0, 0, -20]), 'wink')
], .4);
clip(4, 'show-and-tell', 'Look what I found', 'An eager open-wing presentation, then a proud nod toward the player.', 2.5, [
  beat(.2, pose([0, 1, 0], [0, 2, 0], [3, 1, 18], [-3, 1, -18]), 'thinking'),
  beat(.44, pose([0, -1, 0], [0, -2, 0], [0, -1, 85], [0, -1, -85]), 'surprised'),
  beat(.63, pose([0, 0, 0], [0, 2, 4], [0, 0, 72], [0, 0, -72]), 'proud'),
  beat(.8, pose([0, 0, 0], [0, 0, 0], [0, 0, 38], [0, 0, -38]), 'encourage')
], .44);
clip(5, 'rain-boot-stomp', 'Rain-boot steps', 'Lifts each heavy boot, plants it, and lets the coat and head absorb the landing.', 2.8, [
  beat(.16, pose([-2, -1, -2], [-1, -2, 3], [-2, -1, 40], [-2, -1, -25], [[0, 0, 0], [0, -7, 10]])),
  beat(.3, pose([0, 3, 0], [0, 4, 0], [0, 3, 28], [0, 3, -28])),
  beat(.5, pose([2, -1, 2], [1, -2, -3], [2, -1, 25], [2, -1, -40], [[0, -7, -10], [0, 0, 0]])),
  beat(.64, pose([0, 3, 0], [0, 4, 0], [0, 3, 28], [0, 3, -28])),
  beat(.82, pose([0, 0, 0], [0, 0, 4], [0, 0, 18], [0, 0, -18]), 'proud')
], .5);
clip(5, 'puddle-hop', 'Boots together hop', 'Crouches inside the raincoat, hops with both boots, then lands feet first.', 2.4, [
  beat(.2, pose([0, 4, 0], [0, 5, 0], [0, 4, -8], [0, 4, 8]), 'thinking'),
  beat(.4, pose([0, -13, -2], [0, -15, 3], [0, -13, 85], [0, -13, -85], [[0, -13, -10], [0, -13, 10]])),
  beat(.59, pose([0, -1, 0], [0, -3, 0], [0, -1, 60], [0, -1, -60])),
  beat(.68, pose([0, 3, 0], [0, 5, 0], [0, 3, 42], [0, 3, -42])),
  beat(.83, pose([0, 0, 0], [0, 0, 0], [0, 0, 25], [0, 0, -25]), 'proud')
], .4, .08);
clip(6, 'backpack-ready', 'Ready for school', 'Tugs both shoulder straps, lifts the backpack with a shoulder shrug, then stands ready.', 2.7, [
  beat(.19, pose([0, 1, 0], [0, 2, 0], [2, -3, 22], [-2, -3, -22]), 'thinking'),
  beat(.39, pose([0, -2, 0], [0, -3, 0], [2, -5, 30], [-2, -5, -30]), 'surprised'),
  beat(.57, pose([0, 1, 0], [0, 2, 0], [2, -1, 25], [-2, -1, -25])),
  beat(.77, pose([0, -1, 0], [0, -2, 0], [0, -1, 15], [0, -1, -15]), 'proud')
], .39);
clip(6, 'eager-hand', 'I have an answer', 'Sits into a small anticipation, raises one wing eagerly and leans forward to join in.', 2.4, [
  beat(.17, pose([0, 2, 0], [0, 3, 0], [0, 2, 15], [0, 2, -15]), 'thinking'),
  beat(.39, pose([1, -1, 2], [1, -2, -3], [1, -1, 18], [1, -2, -119]), 'surprised'),
  beat(.56, pose([1, -1, 2], [1, 0, -3], [1, -1, 18], [1, -2, -108])),
  beat(.72, pose([1, 0, 1], [1, 1, 0], [1, 0, 15], [1, 0, -88]), 'proud')
], .39);
clip(7, 'warm-up', 'Side stretches', 'A controlled athletic reach to each side, counterbalanced by the head and planted sneakers.', 3.0, [
  beat(.23, pose([-2, 0, -5], [-1, -1, 4], [-2, 0, 105], [-2, 0, -22]), 'proud'),
  beat(.36, pose([-2, 0, -5], [-1, -1, 4], [-2, 0, 105], [-2, 0, -22]), 'blink'),
  beat(.5, pose(), 'proud'),
  beat(.68, pose([2, 0, 5], [1, -1, -4], [2, 0, 22], [2, 0, -105]), 'proud'),
  beat(.79, pose([2, 0, 5], [1, -1, -4], [2, 0, 22], [2, 0, -105]), 'proud')
], .68);
clip(7, 'balance-challenge', 'One-foot balance', 'Balances on one sneaker with outstretched wings, corrects a tiny wobble, then deliberately plants the foot.', 2.9, [
  beat(.22, pose([-2, 0, -2], [-1, -1, 2], [-2, 0, 75], [-2, 0, -75], [[0, 0, 0], [0, -8, 15]]), 'thinking'),
  beat(.43, pose([-3, 0, -4], [-1, -1, 5], [-3, 0, 89], [-3, 0, -61], [[0, 0, 0], [0, -8, 12]]), 'surprised'),
  beat(.61, pose([-2, 0, -1], [-1, -1, 1], [-2, 0, 72], [-2, 0, -72], [[0, 0, 0], [0, -8, 15]]), 'proud'),
  beat(.81, pose([0, 1, 0], [0, 2, 0], [0, 1, 32], [0, 1, -32]), 'proud')
], .61);
clip(8, 'hoodie-groove', 'Hoodie two-step', 'Loose alternating side steps with an independent head counter-beat and low, relaxed wings.', 3.0, [
  beat(.17, pose([-3, 1, -3], [-1, -1, 4], [-3, 1, 35], [-3, 1, -15], [[0, 0, 0], [0, -3, 7]])),
  beat(.34, pose([0, 0, 0], [0, 2, 0], [0, 0, 20], [0, 0, -20])),
  beat(.52, pose([3, 1, 3], [1, -1, -4], [3, 1, 15], [3, 1, -35], [[0, -3, -7], [0, 0, 0]])),
  beat(.7, pose([0, 0, 0], [0, 2, 0], [0, 0, 30], [0, 0, -30]), 'wink'),
  beat(.83, pose([-1, 0, -1], [0, 0, 2], [-1, 0, 18], [-1, 0, -18]), 'proud')
], .52);
clip(8, 'playful-shrug', 'Why not?', 'Raises both shoulders, tilts the hooded head, then opens one wing in a playful invitation.', 2.5, [
  beat(.23, pose([0, -1, 0], [0, 1, -9], [0, -3, 46], [0, -3, -46]), 'thinking'),
  beat(.44, pose([0, -1, 0], [0, 1, -9], [0, -3, 46], [0, -3, -46]), 'wink'),
  beat(.65, pose([1, 0, 2], [1, -1, 5], [1, 0, 18], [1, 0, -75]), 'encourage'),
  beat(.82, pose([0, 0, 0], [0, 0, 3], [0, 0, 12], [0, 0, -35]), 'encourage')
], .65);
clip(9, 'think-and-try', 'Think it through', 'Leans in for a closer look through the glasses, pauses to think, then tests an idea with a measured wing reach.', 3.0, [
  beat(.2, pose([0, 1, 0], [-2, 3, -6], [3, -1, 25], [0, 1, -12]), 'thinking'),
  beat(.41, pose([0, 1, 0], [-2, 3, -6], [3, -1, 25], [0, 1, -12]), 'thinking'),
  beat(.62, pose([1, 0, 1], [2, 0, 4], [1, 0, 15], [1, -1, -60]), 'listening'),
  beat(.81, pose([0, 0, 0], [0, 1, 0], [0, 0, 16], [0, 0, -32]), 'proud')
], .3);
clip(9, 'idea-spark', 'An idea!', 'A thoughtful downward glance resolves into a lifted head, one clear raised wing and a satisfied nod.', 2.6, [
  beat(.23, pose([0, 1, 0], [0, 3, -4], [2, 0, 22], [0, 1, -10]), 'thinking'),
  beat(.4, pose([0, -1, 0], [0, -3, 0], [0, -1, 20], [0, -1, -94]), 'surprised'),
  beat(.56, pose([0, 0, 0], [0, 1, 2], [0, 0, 18], [0, 0, -82]), 'proud'),
  beat(.76, pose([0, 0, 0], [0, -1, 0], [0, 0, 10], [0, 0, -40]), 'proud')
], .4);
clip(10, 'scout-lookout', 'Scout the horizon', 'Raises a wing toward the cap, scans deliberately, and points out a direction with an open wing.', 3.1, [
  beat(.23, pose([-1, 0, -2], [-3, -1, -7], [-1, 0, 110], [-1, 0, -15]), 'listening'),
  beat(.46, pose([1, 0, 2], [3, -1, 7], [1, 0, 110], [1, 0, -15]), 'listening'),
  beat(.65, pose([1, 0, 1], [2, -1, 3], [1, 0, 30], [1, 0, -80]), 'proud'),
  beat(.82, pose([0, 0, 0], [0, 0, 2], [0, 0, 15], [0, 0, -40]), 'encourage')
], .46);
clip(10, 'confident-step', 'Ready to explore', 'A purposeful sneaker step, steady shoulder turn, then a small confident greeting.', 2.6, [
  beat(.2, pose([2, 0, 3], [1, -1, -2], [2, 0, 22], [2, 0, -10], [[0, -5, -10], [0, 0, 0]]), 'proud'),
  beat(.38, pose([1, 2, 1], [1, 3, 0], [1, 2, 20], [1, 2, -20]), 'proud'),
  beat(.58, pose([0, 0, -2], [0, -1, 3], [0, 0, 72], [0, 0, -12]), 'wink'),
  beat(.75, pose([0, 0, -1], [0, 0, 2], [0, 0, 58], [0, 0, -12]), 'encourage')
], .58);
clip(11, 'rhythm-groove', 'Find the rhythm', 'A headphone-inspired restrained groove: head nods lead, shoulders answer, and one sneaker taps.', 3.2, [
  beat(.15, pose([0, 1, -2], [0, 3, 3], [0, 1, 15], [0, 1, -15], [[0, 0, 0], [0, -2, 5]]), 'proud'),
  beat(.3, pose([0, 0, 2], [0, -1, -3], [0, 0, 22], [0, 0, -12]), 'blink'),
  beat(.46, pose([0, 1, -2], [0, 3, 3], [0, 1, 15], [0, 1, -22], [[0, 0, 0], [0, -2, 5]]), 'proud'),
  beat(.62, pose([0, 0, 2], [0, -1, -3], [0, 0, 22], [0, 0, -12]), 'wink'),
  beat(.79, pose([0, 1, 0], [0, 2, 0], [0, 1, 14], [0, 1, -14]), 'proud')
], .46);
clip(11, 'casual-greeting', 'Easy hello', 'A relaxed asymmetrical lean, brief wing salute and small nod, with no bouncy whole-body hop.', 2.5, [
  beat(.24, pose([1, 0, 2], [1, -1, -4], [1, 0, 12], [1, 0, -88]), 'encourage'),
  beat(.41, pose([1, 0, 2], [1, -1, -4], [1, 0, 12], [1, 0, -72]), 'wink'),
  beat(.6, pose([1, 0, 1], [0, 2, 0], [1, 0, 12], [1, 0, -45]), 'encourage'),
  beat(.78, pose([0, 0, 0], [0, 0, 0], [0, 0, 8], [0, 0, -15]), 'proud')
], .24);
clip(12, 'thoughtful-nod', 'A thoughtful nod', 'Attentive head tilt, a considered pause, then one deliberate reassuring nod; feet and bag stay settled.', 3.1, [
  beat(.23, pose([0, 0, 0], [-1, 1, -6], [0, 0, 8], [0, 0, -12]), 'listening'),
  beat(.44, pose([0, 0, 0], [-1, 1, -6], [0, 0, 8], [0, 0, -12]), 'thinking'),
  beat(.63, pose([0, 1, 0], [0, 3, 0], [0, 1, 12], [0, 1, -20]), 'encourage'),
  beat(.8, pose([0, 0, 0], [0, -1, 0], [0, 0, 12], [0, 0, -20]), 'proud')
], .63);
clip(12, 'welcoming-guide', 'After you', 'A composed open-wing invitation, gentle inclination toward the player and unhurried recovery.', 3.0, [
  beat(.24, pose([-1, 0, -2], [0, -1, 3], [-1, 0, 18], [-1, 0, -66]), 'encourage'),
  beat(.43, pose([-1, 1, -3], [0, 2, 4], [-1, 1, 20], [-1, 1, -76]), 'encourage'),
  beat(.62, pose([-1, 0, -2], [0, 0, 3], [-1, 0, 18], [-1, 0, -70]), 'proud'),
  beat(.8, pose([0, 0, 0], [0, 0, 1], [0, 0, 12], [0, 0, -35]), 'encourage')
], .43);

function generate(root = path.resolve(__dirname, '../..')) {
  const catalog = { version: 1, source: 'tools/pip-growth/motions.cjs',
    description: 'Age-specific performances of the existing six rendered Pip layers. Original project choreography; no additional artwork or audio.', stages, clips };
  const bytes = JSON.stringify(catalog, null, 2) + '\n';
  for (const file of ['data/pip-age-motions.json', 'web/preview/pip-growth/age-motions.json'])
    fs.writeFileSync(path.join(root, file), bytes);
  return catalog;
}
module.exports = { generate };
if (require.main === module) { generate(); console.log('Generated 22 age-specific Pip performances.'); }
