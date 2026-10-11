# Pip growth models

Pip uses eleven authored Blender models: Baby and ages 3 through 12+. The design
keeps the original duck identity: golden down, a broad orange bill, cream eyes,
small friendly wings and an expressive feather crown. The October 11 sculpted
revision replaces the earlier wardrobe SVG variants, whose faces and silhouettes
were too similar at header size.

Age changes the head and cheek shape, eye proportions, feather crown, torso,
wing length, leg length and clothing silhouette together. Everyday childhood
clothing provides an additional recognition cue. These are playful learning
characters, not claims about a child's development or prescribed interests.

## Visual progression

| Age | Main silhouette and recognition cues |
| --- | --- |
| Baby | A round cream duckling seated in a broken eggshell, one downy curl and tiny feet |
| 3 | Top-heavy toddler, double curl, turquoise bib and soft play shorts |
| 4 | Short preschool proportions, broad open sun visor and blue overalls |
| 5 | Golden rain hood around the cheeks, roomy raincoat and tall green boots |
| 6 | First-school backpack outside both shoulders, coral cardigan and newly upright stance |
| 7 | Longer wings, green athletic shirt, white headband and canvas sneakers |
| 8 | Violet hood framing the face, roomy sweatshirt and large kangaroo pocket |
| 9 | Swept feather crest, round blue glasses and denim maker overalls |
| 10 | Side-projecting backward cap, blue open overshirt and longer legs |
| 11 | Tall varsity silhouette, neck headphones and a warm jacket with striped hem |
| 12+ | Smaller face, side-swept feathers, long teal jacket and crossbody messenger bag |

The gameplay header presents age through Pip's image. Age remains available in
accessibility descriptions and functional vocabulary-age selectors. Mastery
Lv0-Lv99 is separate: completing a curriculum cohort grants its age appearance;
a level change or world-theme switch cannot change it.

## Source, rights and acquisition status

| Material | Source and creator | License / acquisition | Integration and animation |
| --- | --- | --- | --- |
| Original Pip design reference | Existing `assets/images/mascots/pip.svg` and `pip-dance-parts.svg`; original project artwork, individual illustrator not recorded | Already integrated project material. Repository declares ISC; no separate illustrator license or additional third-party rights are claimed. | Inspected as the identity reference. Original vectors remain available for the existing non-growth uses. |
| Sculpted growth models | `tools/pip-growth/render.py`; authored locally by Codex for this project on October 11, 2026, at the user's request | Original project-authored mesh, curve, material and clothing work; repository ISC declaration. No purchased or generated-image assets. | Integrated as 55 PNG atlases. Custom cross-section meshes define head/body/bill forms; tapered meshes define wings/crowns; modeled clothing has bound edges, folds, seams and pockets. Six separable roots; ten expression heads plus a speaking head. |
| Kenney Cube Pets 2.0 | User-provided `Q:/uwok/Kenney Game Assets All-in-1 3.7.0/3D assets/Cube Pets/`; Kenney, www.kenney.nl | Local collection present. `License.txt` inspected: Creative Commons Zero (CC0), https://creativecommons.org/publicdomain/zero/1.0/ | Pack preview and chick OBJ structure inspected. Preview-only selection: the cube silhouette does not fit Pip's growth anatomy. No mesh, texture or animation from this pack is copied or shipped. |
| Kenney Mini Characters 1.0 | User-provided collection, `3D assets/Mini Characters/`; Kenney | Local collection present. `License.txt` inspected: CC0, same URL above | Pack preview inspected. Human silhouettes do not match Pip. No assets acquired into the repository or integrated; no animation claim. |
| Motion | `tools/pip-growth/motions.cjs`, `scripts/pip_age_motion.gd`, existing mascot and preview renderers | Original project choreography authored locally on October 12, 2026; repository ISC declaration | 22 integrated age-specific performances drive the six acquired project layers with model-specific pivots. No new mesh, audio or baked Blender animation clips. |
| Age-growth voice | Microsoft Edge online TTS, Microsoft Ava Neural; existing recordings and English scripts | Previously acquired with edge-tts 7.2.8. Microsoft service terms apply: https://www.microsoft.com/servicesagreement | Ten unchanged MP3 recordings. Baby shares the Sprout greeting. No new synthesis or processing in this revision. |
| Preview typography | Nunito Project Authors; existing Google Fonts acquisition | SIL Open Font License 1.1, `web/preview/pip-growth/FONT-LICENSE.txt` | Existing static 600/800 font instances reused. |

## Rendering and runtime contract

`tools/pip-growth/render.py` builds the source models and renders transparent
layers with Blender 5.2 Cycles. The front orthographic camera has a fixed 3.6-unit
frame, soft studio lights and a restrained coat response. All stages share the
same camera and ground plane. `--save-models` saves editable neutral `.blend`
files under `build/pip-models/<age>/`; these local review sources are excluded
from the game export and can be recreated from the checked-in authoring script.

`tools/pip-growth/assemble.py` composes the rendered layers into the existing
mascot atlas contract. Every cell is 360 x 360 pixels and retains the existing
120-unit pose coordinate system. A three-unit vertical inset places the webbed
feet on the existing ground shadow; the catalog applies the same inset to every
joint. Runtime imports are lossless with transparent
edge correction. Catalog paths are Texture2D inputs; no runtime 3D renderer,
Blender dependency or procedural character drawing is introduced.

| Sheet | Cells | Content |
| --- | --- | --- |
| Ordinary | 4 | Neutral, speaking, blink, wave |
| Idle | 4 | Curious look, small stretch, wink, tucked sleepy pose |
| Parts | 6 | Body, head, left/right wing, left/right foot |
| Expressions | 10 | Complete neutral, listening, thinking, delighted, proud, encourage, surprised, sleepy, wink, blink poses |
| Expression heads | 10 | Matching heads, including all headwear and face accessories |

`data/pip-growth-stages.json` (schema 3) is the runtime catalog. Its identical
preview copy is `web/preview/pip-growth/stages.json`. Each stage records model
form measurements, exact six-joint projected pivots, ground-shadow radius, five
runtime/preview atlas paths, and cumulative action/voice repertoires. Existing
stage IDs and `pip-lv3` through `pip-lv12` filename stems remain stable for voice
and catalog compatibility; appearance selection is exclusively age-based.

Native growth gestures, answer feedback and shared celebrations retarget their
existing motion around these projected joints. Paint order remains feet, body,
head, wings. Normal actions settle after one play; repeated input, speech
priority, hidden-page cancellation and reduced-motion behavior are unchanged.
The browser review embeds cropped raster cells into the same SVG articulation
wrappers, preserving the model's full 120-unit frame.

## Age-specific motion

Each age now has two signature performances. They alternate after six to nine
quiet seconds and on deliberate result-companion interactions. The gameplay
header still opens the mode menu. Older earned gestures remain available to
explicit callers and the review page, but no longer dilute the default age
repertoire. These choices describe Pip's personality, not developmental rules.

| Age | Signature performances | Physical emphasis |
| --- | --- | --- |
| Baby | Shell wiggle; sleepy nuzzle | Planted shell and feet, delayed heavy head, tiny wing cuddle |
| 3 | Wobbly steps; little claps | Tentative balance shifts, small lifted foot, eager wing contact |
| 4 | Curious peek; look what I found | Broad head turns, visor-led curiosity and open presentation |
| 5 | Rain-boot steps; boots together hop | Heavy boot lifts, feet-first contact and coat settling |
| 6 | Ready for school; I have an answer | Shoulder-strap tug and an eager raised wing |
| 7 | Side stretches; one-foot balance | Deliberate reach, planted sneakers and counterbalance |
| 8 | Hoodie two-step; why not? | Loose side rhythm and playful asymmetrical shrug |
| 9 | Think it through; an idea | Inspect, pause, try, then a clear recognition beat |
| 10 | Scout the horizon; ready to explore | Cap-side lookout, purposeful step and confident greeting |
| 11 | Find the rhythm; easy hello | Head-led groove, sneaker tap and relaxed wing salute |
| 12+ | A thoughtful nod; after you | Considered pause, reassuring nod and unhurried invitation |

`node tools/pip-growth/motions.cjs` regenerates `data/pip-age-motions.json` and
its identical local preview copy. Both renderers interpolate the same authored
beats. Only the boot hop needs extra headroom; grounded gestures keep their
normal size. Every action settles into the exact rest pose. Reduced motion uses
one selected still pose per action. Pronunciation, page hiding and pause cancel
the action; late input cannot stack it or take over the reward clock. Existing
answer reactions, shared chest timing, voice recordings and game state remain
unchanged. The new motion is silent and adds no instructional UI text.

## Regeneration

From the repository root:

```powershell
blender --background --python tools/pip-growth/render.py -- --preview --save-models
python tools/pip-growth/assemble.py --preview
blender --background --python tools/pip-growth/render.py -- --save-models
python tools/pip-growth/assemble.py
node web/preview/pip-growth/generate.cjs
node web/preview/pip-growth/verify.cjs
```

The first two commands provide the large and 44/56-pixel direction comparison.
The next commands render and assemble the actual articulated production layers.
Assembly rejects cells that touch atlas boundaries and writes the bounds report
to `build/pip-model-bounds.json`. `generate.cjs` catalogs the rendered models and
preserves the existing voice metadata. It does not request new voice synthesis.

The approved `ava-sweet` settings remain `en-US-AvaNeural`, rate `-15%`, pitch
`+8Hz`, volume `+0%`, no postprocessing. Exact scripts, byte lengths and SHA-256
hashes are in `web/preview/pip-growth/audio/manifest.json`; native and preview
recordings are byte-identical.

For interactive review, run `npm run preview:pip` and open
http://127.0.0.1:41774/. Review material stays local and is excluded from production.
The verifier checks eleven unique compositions, 55 matching PNG atlases with
360-pixel cells, all pivots, cumulative actions and unchanged recordings.
`tests/godot/pip_growth_tests.gd` covers actual textures, age/theme independence,
pose retargeting, speech, reactions, reduced motion and lifecycle interruption.
Rendered expression/motion sheets and real header captures provide separate
visual evidence; passing logic tests alone does not establish visual quality.

The sculpted revision passed 374 atlas-cell boundary checks, 846 native growth
assertions, 1,013 growth-flow checks and 2,401 expression checks. Native captures
cover all eleven ages at rest, speaking, waving, performing their new move,
answering correctly and celebrating. Header captures cover all five modes at
1280 x 720, 390 x 844, 320 x 568, 568 x 320 and 320 x 320, including Age 12/Lv99.
The browser review covers desktop Chromium, an iPhone 13 WebKit profile and a
short landscape viewport. A final pose review checks the inset wing roots after
removing the visible shoulder gap. This is emulated-device evidence, not a
physical-device test. No new audio was generated or subjectively approved.
