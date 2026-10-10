# Lv3 motion studies

Eight vocabulary animations replace their static pictures in the live game:
walk, run, jump, open, close, drink, eat and hello. Match, Memory, Phrase Builder,
Voice Pop, Jelly Match and the age-word catalogue share the same playback.
The comparison gallery and editable Blender sources remain local only.

## Acquired source and authorship

The character is the acquired **Kenney Animated Characters Protagonists 1.1**
`characterMedium.fbx`, with the retained child skin adaptation. The door is from
**Kenney Furniture Kit 2.0**, and the glass and loaf are from **Kenney Food Kit 2.0**.
These production models are CC0. Source URLs, acquired archive hashes, individual
model hashes and retained license files are recorded in
[the existing artwork manifest](lv3-vocabulary.json).

The character package includes idle, run and jump animation files. These studies
use locally authored and baked joint/prop motion on that acquired rig, rather
than claiming the package supplied the eight teaching actions. No new image
generation service, paid asset or external API is used.

## Motion and review

- Walk uses a slow alternating gait; run has a faster cadence, bent elbows,
  higher knees and short unsupported phases.
- Jump contains anticipation, flight, a two-foot landing and settling.
- Open and close rotate the actual door leaf around its hinge, with the hand
  following the handle. They hold the final state before the next replay.
- Drink raises and tips a held glass; eat raises a held loaf and adds a chewing
  nod. Hello raises a hand, waves three times and returns to a relaxed stance.
- Cameras are fitted to the full motion envelope and remain fixed. No frame is
  individually trimmed. The contact shadow comes from the rendered scene.

The local page compares each animation with its current static picture at 48,
80, 120 and 192 pixels. It provides global and individual playback, replay and
frame scrubbing. Offscreen and background playback stops; reduced-motion
preferences start the preview paused. The door animations restart after their
hold instead of reversing and demonstrating the opposite word.

## Local output and reproduction

The acquired source packs remain in `build/word-art-review/model-source/`.
Run Blender 5.2.2 LTS with:

```text
blender --background --factory-startup --python-exit-code 1 --python tools/vocabulary-art/render-animations.py -- walk run jump open close drink eat hello
```

Add `--poses` to render five key poses per word before the full sequence. Full
renders contain 24 frames per second and write the baked editable `.blend`,
per-frame transparent PNGs and metadata into `build/word-art-review/animated/`.

Package the full sequences with `node tools/vocabulary-art/make-animation-gallery.cjs`.
It requires Sharp; `SHARP_MODULE` can point to an installed module when it is not
on the normal Node module path. The packager writes 256-pixel sprite atlases,
standalone animated WebP files, posters, a manifest and the review page. Use
`--gallery-only` to rebuild the page without recompressing the rendered frames.

Serve `build/word-art-review/` on loopback port 41775. The review route is
`http://127.0.0.1:41775/animated/`. Generated source scenes, full-resolution
atlases, animated WebP loops and pages remain in the ignored build directory.
`tools/vocabulary-art/.gdignore` excludes authoring tools from Godot import.

`node tools/vocabulary-art/package-runtime-motion.cjs` packages only the eight
card-sized atlases into `assets/images/word-motion/`. Each frame is 128 pixels,
with eight columns and no per-frame cropping. The 516 frames total 1,548,734
source bytes and approximately 33 MiB decoded, shared across repeated cards.
The runtime delivery hashes are in [lv3-word-motion.json](lv3-word-motion.json).

`scripts/word_art.gd` advances shared AtlasTextures at 24 fps while visible.
Offscreen and hidden art, menus and background pages pause playback. Reduced
motion selects the reviewed teaching pose. Hidden Memory faces remain hidden;
Phrase candidates, dragged cards and answers retain the same illustration.
Voice Pop freezes the impact pose for its two sliced halves. Existing static
pictures remain available as fallbacks. Curriculum IDs, pronunciation and
mastery rules are unchanged. Preview routes and source scenes are excluded
from the production export.

## Review checks

All eight studies were rendered and packaged: 516 frames in total, each 256 by
256 pixels at 24 fps. Frame validation found no missing files or clipped opaque
subjects; minimum subject margins range from 20 to 27 pixels. The baked door
handle/hand contact error stays below 0.000001 scene units. Sprite atlases total
approximately 2.93 MB. Individual animated WebP loops are also retained locally.

The browser review loaded all eight canvases without failed images or console
errors. Playback, pause, individual replay, frame scrubbing, reduced-motion
initial pause and a 390-pixel phone viewport were checked. Key poses and full
frame bounds were inspected; the local page is the normal-speed visual review
deliverable. This is not a physical-device gameplay integration test. The local
`verification.json` and `delivery.json` retain frame checks and output hashes.

Runtime verification adds 604 focused assertions for all atlas frames, playback,
shared ownership, recycled controls, hidden Memory cards, Phrase editing, Jelly
fusion pictures and frozen Voice Pop slices. Existing Phrase, catalogue, Memory,
Jelly view, Voice Pop scene and slice suites also pass. The export verifier checks
all eight runtime atlases and excludes local galleries and authoring files.

Browser pixel comparisons confirm motion for all eight words on desktop Chromium
and an emulated iPhone in WebKit. Reduced motion stays on its teaching pose in
both engines. The combined desktop navigation run reached its timeout after all
eight motion comparisons; the remaining static-pose check passed as a separate
focused run. These are browser emulations, not physical-device measurements.
