# Pip growth artwork

Pip has eleven appearances: Baby and ages 3 through 12+. The October 12
storybook revision adapts the original project Pip vectors into warm illustrated
characters with rounded cheeks, a short orange bill, cocoa eyes, soft feather
curves and a matte painted surface. It replaces the sculpted revision's shiny
surfaces, prominent eye whites and broad fixed smile while keeping the duck
identity and readable age differences.

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
| Original Pip vectors | Existing `assets/images/mascots/pip.svg` and `pip-dance-parts.svg`; original project artwork, individual illustrator not recorded | Previously integrated project material. Repository declares ISC; no separate illustrator license or additional third-party rights are claimed. | Inspected and adapted for the storybook revision. Retained as historical authoring sources and compatibility inputs; the current game, loading screen and speech companion use the new storybook artwork. |
| Storybook growth artwork | Original Pip vectors adapted locally by Codex for this project on October 12, 2026 in `tools/pip-growth/storybook.cjs`; each stage's `source.model` records this authoring script | Original project adaptation under the repository ISC declaration. No new external artwork was acquired, and no AI-generated raster images are used. | Vector-authored contours, faces and apparel are rasterized into the existing 55 PNG atlases. Six articulated layers, ten expression heads and a speaking head retain the existing motion and expression contract. |
| Storybook loading and speech wardrobes | Existing `assets/images/mascots/outfits/wardrobe.svg`, maintained as original project artwork; original individual illustrator not recorded. Adapted locally by Codex in `tools/pip-growth/storybook.cjs` on October 12, 2026 | Reused project artwork under its existing rights and the repository ISC declaration. No new third-party acquisition or separate artist license is claimed. | Original body and head accessories are resized, softened in color and outlined more lightly around the storybook duck. Integrated as a base character plus Spring, Summer, Autumn, Winter, Ocean, Space, Jungle and Candy variants under `assets/images/mascots/storybook/`: nine four-pose SVGs and nine six-part SVGs. Existing loading motion and speech reactions animate these assets. |
| Earlier sculpted growth models | `tools/pip-growth/render.py`; authored locally by Codex for this project on October 11, 2026, at the user's request | Original project-authored mesh, curve, material and clothing work; repository ISC declaration. No purchased or generated-image assets. | Historical source retained as a regeneration fallback. The storybook revision replaces its rendered production atlases; it does not reuse a Kenney mesh or introduce a runtime 3D character. |
| Kenney Cube Pets 2.0 | User-provided `Q:/uwok/Kenney Game Assets All-in-1 3.7.0/3D assets/Cube Pets/`; Kenney, www.kenney.nl | Local collection present. `License.txt` inspected: Creative Commons Zero (CC0), https://creativecommons.org/publicdomain/zero/1.0/ | Pack preview and chick OBJ structure inspected. Preview-only selection: the cube silhouette does not fit Pip's growth anatomy. No mesh, texture or animation from this pack is copied or shipped. |
| Kenney Mini Characters 1.0 | User-provided collection, `3D assets/Mini Characters/`; Kenney | Local collection present. `License.txt` inspected: CC0, same URL above | Pack preview inspected. Human silhouettes do not match Pip. No assets acquired into the repository or integrated; no animation claim. |
| Motion | `tools/pip-growth/motions.cjs`, `scripts/pip_age_motion.gd`, existing mascot and preview renderers | Original project choreography authored locally on October 12, 2026; repository ISC declaration | 22 integrated age-specific performances drive the six project artwork layers with age-specific pivots. The storybook revision preserves these clips, their timing and expression names. No new audio or baked Blender animation is introduced. |
| Age-growth voice | Microsoft Edge online TTS, Microsoft Ava Neural; existing recordings and English scripts | Previously acquired with edge-tts 7.2.8. Microsoft service terms apply: https://www.microsoft.com/servicesagreement | Ten unchanged MP3 recordings. Baby shares the Sprout greeting. No new synthesis or processing in this revision. |
| Preview typography | Nunito Project Authors; existing Google Fonts acquisition | SIL Open Font License 1.1, `web/preview/pip-growth/FONT-LICENSE.txt` | Existing static 600/800 font instances reused. |

## Rendering and runtime contract

`tools/pip-growth/storybook.cjs` adapts the existing Pip vector identity into
separate transparent body, head, wing and foot layers. All layers share the
same full frame, so a head turn or wing lift does not move its attachment point.
Headwear and glasses belong to every matching expression head. Source layers
and `model.json` are written under `build/pip-models/<age>/`; local review
sources are excluded from the game export and are reproducible from the
checked-in authoring script identified in the catalog.

`model.json` identifies storybook artwork with `style: "storybook"` and an
`artSource` path. Its optional `render` description records the rasterization
method. The catalog uses storybook provenance and status for these stages;
metadata without that style keeps the original Blender provenance. The retained
`tools/pip-growth/render.py` builds the earlier sculpted models with Blender
5.2 Cycles and can save editable neutral `.blend` files with `--save-models`.

`tools/pip-growth/assemble.py` composes the rasterized layers into the existing
mascot atlas contract. Every cell is 360 x 360 pixels and retains the existing
120-unit pose coordinate system. A three-unit vertical inset places the webbed
feet on the existing ground shadow; the catalog applies the same inset to every
joint. The source metadata's `frameOffsetY` defaults to three units and must
match the assembly inset. Runtime imports are lossless with transparent edge
correction. Catalog paths remain Texture2D inputs; the gameplay mascot needs no
runtime drawing code or 3D renderer.

The same authoring script also writes the loading and speech SVG assets under
`assets/images/mascots/storybook/`. These use the age 3 proportions as a shared
storybook base, with the eight original wardrobe accessory sets adapted around
it. Each theme has neutral, speaking, blink and wave frames plus six separable
limbs. `tools/prepare-godot.cjs` embeds their SVG data directly in the web shell;
the initial loading frame, theme changes and speech companion all use the new
art. The directory's `.gdignore` keeps these web-only sources out of the Godot
resource import. Original Pip and wardrobe files remain editable historical
sources, rather than a second visual style for the loading or speech UI.

| Sheet | Cells | Content |
| --- | --- | --- |
| Ordinary | 4 | Neutral, speaking, blink, wave |
| Idle | 4 | Curious look, small stretch, wink, tucked sleepy pose |
| Parts | 6 | Body, head, left/right wing, left/right foot |
| Expressions | 10 | Complete neutral, listening, thinking, delighted, proud, encourage, surprised, sleepy, wink, blink poses |
| Expression heads | 10 | Matching heads, including all headwear and face accessories |

`data/pip-growth-stages.json` (schema 3) is the runtime catalog. Its identical
preview copy is `web/preview/pip-growth/stages.json`. Each stage records source
form measurements, exact six-joint pivots, ground-shadow radius, five
runtime/preview atlas paths, and cumulative action/voice repertoires. Existing
stage IDs and `pip-lv3` through `pip-lv12` filename stems remain stable for voice
and catalog compatibility; appearance selection is exclusively age-based.

Native growth gestures, answer feedback and shared celebrations retarget their
existing motion around these projected joints. Paint order remains feet, body,
head, wings. Normal actions settle after one play; repeated input, speech
priority, hidden-page cancellation and reduced-motion behavior are unchanged.
The browser review embeds cropped raster cells into the same SVG articulation
wrappers, preserving the artwork's full 120-unit frame.

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

From the repository root, render all eleven storybook ages and the base/eight
theme SVG sets, then assemble and catalog the production artwork:

```powershell
node tools/pip-growth/storybook.cjs
python tools/pip-growth/assemble.py
node web/preview/pip-growth/generate.cjs
node web/preview/pip-growth/verify.cjs
```

The first command requires Sharp; assembly requires Python with Pillow. When
Sharp comes from an external tool runtime rather than local Node dependencies,
set `$env:SHARP_MODULE` to its absolute package directory or entry-file path
before running Node. Leave it unset when `require('sharp')` resolves normally.
This environment variable affects the local authoring tool only; neither Sharp
nor an absolute machine path is shipped in the game.

`node tools/pip-growth/storybook.cjs --ages=0,6,12 --preview` produces local
direction previews for representative ages. Run the full four-command sequence
above before integrating a revision; preview rendering does not replace every
production layer or assemble atlases.

The source renderer and its options are recorded by the stage's `source.model`.
Review Baby, age 6 and age 12 at large size and 44/56-pixel header size before
expanding a visual revision to every age. Assemble and review the actual
articulated production layers, including extreme expression and gesture poses.
Assembly rejects cells that touch atlas boundaries and writes the bounds report
to `build/pip-model-bounds.json`. `generate.cjs` reads the source metadata,
catalogs the artwork and preserves the existing voice metadata. It does not
request new voice synthesis.

For a deliberate recreation of the earlier sculpted source, the retained
Blender path is:

```powershell
blender --background --python tools/pip-growth/render.py -- --preview --save-models
python tools/pip-growth/assemble.py --preview
blender --background --python tools/pip-growth/render.py -- --save-models
```

These commands overwrite local source layers and their metadata. Follow them
with the shared assembly/catalog steps only when intentionally replacing the
current artwork with that earlier version.

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

Visual verification must cover all eleven ages at rest, speaking, waving,
performing both age actions, answering correctly and celebrating. Inspect wing
roots, head-to-body overlap, the planted Baby shell and the boot hop's headroom.
Check the real header on desktop, phone and short landscape layouts, including
Age 12/Lv99. Prior sculpted-art captures and test counts are historical evidence;
they do not verify the storybook replacement. Emulated-device checks must not
be described as physical-device testing. No new audio is generated or
subjectively approved by this artwork revision.
