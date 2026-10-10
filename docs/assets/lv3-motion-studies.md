# Lv3 motion studies

This guide covers the eight articulated Blender clips in the
[complete animated vocabulary library](word-library.md): walk, run, jump, open,
close, drink, eat and hello. The full release animates all 1,285 pictured words;
the other 1,277 use illustration motion, and 265 context-only words retain text.
Match, Memory, Phrase Builder, Voice Pop, Jelly Match and the age-word catalogue
share the same picture playback. The comparison gallery and editable Blender
sources remain local only.

## Acquired source and authorship

The character is the acquired **Kenney Animated Characters Protagonists 1.1**
`characterMedium.fbx`, with locally adapted bright, delighted, pleased and blink
expression textures, keyed to the action's contact and recovery beats.
The door is from
**Kenney Furniture Kit 2.0**, and the glass and loaf are from **Kenney Food Kit 2.0**.
These production models are CC0. Source URLs, acquired archive hashes, individual
model hashes and retained license files are recorded in
[the existing artwork manifest](lv3-vocabulary.json).

The character package includes idle, run and jump animation files. These studies
use locally authored and baked joint/prop motion on that acquired rig, rather
than claiming the package supplied the eight teaching actions. No new image
generation service, paid asset or external API is used.

## Motion and review

- Walk uses a jaunty planted gait, heel-to-toe steps, generous arm swings and a
  bright grin; run has a faster cadence, strong opposing elbows, higher knees
  and short unsupported phases.
- Jump contains an eager crouch, joyful open-arm leap, a soft two-foot landing
  and a proud happy finish.
- Open and close rotate the actual door leaf around its hinge, with the hand
  following the handle. A delighted turn and free-hand presentation follow the
  completed door movement. They hold the final state before the next replay.
- Drink raises and tips a held glass; eat raises a held loaf and adds a chewing
  nod and a closed-eye pleased reaction. Hello leads three broad waves with its
  palm, with delayed head and shoulder follow-through before the relaxed hold.
  The complete cycle remains readable.
- Cameras are fitted to the full motion envelope and remain fixed. No frame is
  individually trimmed. The contact shadow comes from the rendered scene.

The original local page compares each animation with its previous character pose at 48,
80, 120 and 192 pixels. It provides global and individual playback, replay and
frame scrubbing. Offscreen and background playback stops; reduced-motion
preferences start the preview paused. The door animations restart after their
hold instead of reversing and demonstrating the opposite word.

The `/cheerful/` local comparison additionally plays the previous shipped and
revised animations side by side at 48, 80 and 128 pixels. Its snapshot atlases
and generated page stay under `build/word-art-review/`, outside production.

## Local output and reproduction

The acquired source packs remain in `build/word-art-review/model-source/`.
The cheerful skin textures are tracked in `tools/vocabulary-art/skins/`. To
regenerate them, run `python tools/vocabulary-art/make-cheerful-skin.py` with
Pillow installed. Run Blender 5.2.2 LTS from the repository root with:

```text
blender --background --factory-startup --python-exit-code 1 --python tools/vocabulary-art/render-animations.py -- walk run jump open close drink eat hello
```

Add `--poses` to render action-specific review poses before the full sequence,
and `--output-dir` to keep experimental output separate. Full
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

`node tools/vocabulary-art/package-runtime-motion.cjs` packages this eight-clip
subset into `assets/images/word-motion/`. Each frame is 128 pixels,
with eight columns and no per-frame cropping. The 516 frames occupy approximately
33 MiB decoded, shared across repeated cards; encoded sizes are in the manifest.
The subset's delivery hashes are in [lv3-word-motion.json](lv3-word-motion.json).
This step does not regenerate the full runtime descriptor. Complete the
[full-library workflow](word-library.md#reproduction-and-local-review), ending
with `python tools/vocabulary-art/render-library-motion.py --integrate`, to
publish all 1,285 animation records and their combined provenance manifest.

`scripts/word_art.gd` advances these shared AtlasTextures at 24 fps while visible;
the other illustration loops retain their own 12 fps timing.
Offscreen and hidden art, menus and background pages pause playback. Reduced
motion selects the reviewed teaching pose. Hidden Memory faces remain hidden;
Phrase candidates, dragged cards and answers retain the same illustration.
Voice Pop freezes the impact pose for its two sliced halves. Existing static
pictures in the complete word library remain available as fallbacks. Curriculum IDs, pronunciation and
mastery rules are unchanged. Preview routes and source scenes are excluded
from the production export.

## Review checks

The cheerful revision contains 516 full frames at 256 by 256 pixels and 24 fps.
`verify-motion-frames.py` checks every frame for a visible subject, a safe opaque
margin and distinct movement, and exports a five-pose contact sheet for each
word. Door hand/handle contact is measured while authoring the joint motion.
The local `animated/verification.json` records the current frame measurements;
encoded runtime sizes and hashes are recorded in `lv3-word-motion.json`.

The full vocabulary runtime now uses visibility-driven sheet loading and idle
release. Its focused tests cover both frame rates, bounded memory, recycled
controls, hidden Memory cards, Phrase editing, Jelly pictures and frozen Voice
Pop slices. The production pack verifier checks all motion descriptors and
atlas dimensions while excluding preview pages and authoring files.

Normal-speed preview and browser frame comparisons supplement pose review.
Browser emulation does not establish physical-device performance. The complete
local page remains available for the user's motion and expression review.
