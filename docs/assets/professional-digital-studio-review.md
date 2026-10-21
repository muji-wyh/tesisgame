# Digital Studio candidate review

The full Software & Data theme remains pending. Its accepted Home preview is
separate from the candidate full scene and must retain its existing bytes.

The acquired scene uses thirteen Kenney Furniture Kit 2.1 GLBs under CC0 1.0:
`floorFull`, `wall`, `wallWindow`, `desk`, `computerScreen`, `computerKeyboard`,
`computerMouse`, `chairDesk`, `pottedPlant`, `lampRoundFloor`, `laptop`,
`televisionModern`, and `cabinetTelevision`. The fourteenth asset is the original
Innerscene Mobile Whiteboard under CC0 1.0 Universal. The assets were acquired in
`build/professional-english/software-data-theme-proposal-r01/sources/` and now
have durable exact copies under
`docs/assets/sources/kenney-innerscene-software-data-theme/sources/`. Source URLs,
original licenses, acquisition records and exact hashes are in the accompanying
`source-inventory.json` and `file-destinations.json`. All fourteen retained
files match that inventory. They have no baked animations or skins. The
proposed plant movement is authored rotation of the acquired leaf mesh, not a
source animation.

The immutable placement-r02 proposal moves only the plant from
`[1.82, 0.05, -0.38]` to `[1.50, 0.05, 0.35]`. It retains the existing source
geometry, materials, camera, lighting, scale, yaw and sixteen +/-0.6-degree
poses. Its source crop calculation fits the four target viewports, but that
calculation does not establish visibility behind the actual lesson controls.

## Current Main inspection

`tools/capture-digital-studio-review.gd` captures a completed source rest render
through current Main in Match and Word Jelly at 320x568, 390x844, 844x390 and
1280x800. It verifies the complete rest and two extreme PNGs against their
native renderer report, then records all three poses at each viewport. The
24 screenshots and JSON report include the current card and action-control
bounds in viewport pixels. Word Jelly's existing snapshot also retains the
well, supply row, Collect control and paid tools.

The tool uses the existing internal test owner and media fixtures to exercise
Main routing. Its synthetic words, repeated fixture picture and fixture audio
are not Software & Data curriculum delivery. Only the candidate scene texture
is replaced, and only in that process. It makes no production loader-budget,
atlas, animation-playback, listening or physical-device claim. The theme catalog
must remain pending and byte-identical; saves stay under the fresh review output.

Run a script check first, then capture using an actual renderer and Dummy audio:

```text
node tools/run-godot.cjs --headless --path . --script res://tools/capture-digital-studio-review.gd --check-only
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --disable-vsync --max-fps 30 --resolution 320x568 --script res://tools/capture-digital-studio-review.gd -- --source-dir=res://build/professional-english/software-data-theme-render-r02/rest-r01 --output=res://build/professional-english/software-data-theme-review-r02/main-r04
```

The source directory must contain the completed rest renderer's original
`render-report.json`, `composition-rest.png`, `extreme-00.png` and
`extreme-01.png`. The output directory must be new. Choose a new attempt name
after a failure; retain previous attempts. Root coordinates native execution
with other project work and provides a private user directory to the process.

The tool resumes Main through its actual `on_page_visible()` lifecycle when
desktop focus leaves the inspection process; it records the resume count.
Before every screenshot it requires foreground state, visible backdrop and
environment nodes, full current-layer alpha, the exact scoped source texture
identity, and matching decoded pixels. Loading a texture alone is insufficient.

## Inspection on 2026-10-20

The first attempt, `software-data-theme-review-r02/main-r01`, retained its
startup-routing failure without captures. `main-r02` retained 12 Match captures
and a Word Jelly routing failure. Its flat cream background was caused by native
focus loss: Main correctly hid the background and refused a new Home selection
while the page was hidden. Those screenshots do not establish scene visibility.

The corrected `main-r03` passed **131 checks with no failures** and saved all
**24** views. It used one recorded foreground-lifecycle restoration. All eight
viewport/mode combinations and all three complete poses were visually inspected.
The actual acquired scene is present, and source identity, visibility and scope
release checks passed. No production data or runtime was changed.

The r02 plant is visible with an attached pot in Word Jelly at 390x844 and
1280x800. At 844x390 the opaque action stack conceals most of it. The 320x568 view
shows Word Jelly's existing minimum-window pause overlay, so it does not
establish active gameplay readability. Opaque Match cards hide substantial
parts of the background; that incidental occlusion does not require drawing
art above the cards. The still images do not establish normal-speed motion
perceptibility, lifecycle, media-loader budgets or full-theme acceptance.

A separate r03 placement proposal moved only the plant into the floor strip
between the analysis desk and left workstation. Its completed native rest
render was rejected: the workstation hid the floor pot and suggested a plant
at desktop height. The r03 proposal and all twenty render outputs remain
intact; the projection calculation alone was insufficient.

The r04 proposal moves the plant to `[-1.42, 0.05, 0.05]`, retaining the camera,
source geometry and materials, scale 1.4, yaw 0, grounded Y and sixteen original
motion poses. Its fresh source rest and both extremes were inspected, followed
by all **24** current Main screenshots in
`software-data-theme-review-r04/main-r01`. That actual Main run passed **131
checks with no failures**. In Word Jelly the leaves, pot rim and pot's left side
read as a floor plant behind the chair, including the 844x390 landscape view.
The action stack no longer conceals the whole plant. The existing 320x568
minimum-window pause overlay remains, and is not active-gameplay acceptance.
Opaque Match card occlusion is natural; background art is never drawn above
the cards to defeat that occlusion. This accepts the bounded static placement,
not the complete theme or all six games.

The fresh `software-data-theme-render-r04/motion-r01` rest PNG is byte-identical
to the accepted r04 source rest. Every one of its sixteen complete frames was
inspected in a contact sheet and a separately labelled enlarged crop; these
are still-image observations. `tools/prepare-professional-theme-layers.py`
derived a 768x768 environment, a 768x768 transparent props layer and a 264x536
4x4 candidate atlas. The actual motion crop is `[193, 280, 66, 134]` with the
specified eight-pixel padding. Source reconstruction is exact for the static
composition and all sixteen motion frames; the repeated loop endpoint is
byte-identical. The props layer has 523,318 fully transparent pixels and 66,506
opaque pixels; it retains changed shadows and foreground occlusion.

The 390x844 cover crops 14.9 viewport pixels from the left edge of the padded
motion rectangle; the accepted Main images establish the remaining plant and
pot readability. Other source-cover rectangles fit their viewports. No source
crop metric establishes animation perceptibility at normal speed. The
two-frames-per-second review GIF is a derivative for later continuous review,
not evidence that such review took place.

Inspect the actual plant, attached pot, desk contact, shadows and control
occlusion in every screenshot. A nonzero pixel difference alone does not prove
that subtle motion reads at normal speed. If the action column obscures the
plant, revise the scene placement and rerender the complete source scene; do
not paste an old crop above controls or alter lesson interaction for the art.

Actual raw-media loading, scoped cache ownership, scaled rendering, animation
timing and reduced-motion/hidden-view/disposal checks are recorded separately
from visual observations. The original Retail layer script is a reference,
not an entrypoint to replay. Full-theme delivery still needs the other four
games, actual complete lesson-media budgets, normal-speed perceptual review
and the remaining acceptance scenarios from the development plan.

## Bounded static component check

`tools/check-digital-studio-components.gd` passed **133 checks with no failures**
in `software-data-theme-review-r04/components-r01`. It uses the actual native
raw loader, decoder, cache, scoped Access lease and `LearningThemeArt`, with no
fetch override or fixture cache. Its private manifest contains the exact two
static images, candidate atlas and unchanged accepted Home bytes: four images,
287,409 encoded bytes and 11,879,936 conservative decoded CPU-plus-GPU bytes.
The atlas and Home image are loaded for resource identity and disposal checks;
only environment and props are bound to the displayed internal profile.

The actual cache has one lease. Deactivation and trimming retain all four
images while that lease exists; closing the view and releasing the scope return
resource count, active IDs, resident/pinned/reserved bytes and lease count to
zero. All four weak references clear. Decoded pixels match the exact private
delivery bytes. The production Software03 resolver returns `content_pending`
in all six modes, and every pinned production/source file stays byte-identical
during the run.

Five standalone component screenshots at 768x768, 320x568, 390x844, 844x390 and
1280x800 were visually inspected. The actual layered rendering shows no visible
mask seams, detached pot or shifted foreground shadows. These are **standalone
component views**, not post-integration Main captures. Their source identity
and exact unscaled reconstruction connect them to the earlier accepted Main
placement evidence. Normal interpolation can differ from scaling a precomposed
PNG; no scaled pixel-equality claim is made.

The native check deliberately does not play the candidate animation. Normal-
speed perceptual review and motion timing/lifecycle acceptance remain pending.
The complete evidence copies and their exact hashes are retained under
`docs/qa/software-data-static-r04/`.

The two static components are integrated through content-addressed PNGs and
reviewed `art.environment` / `art.props` descriptors. The full profile remains
pending; `art.home`, ambient motion and the accepted Home preview remain
unchanged. The scoped receipt and before/after profile are retained in
`docs/assets/sources/kenney-innerscene-software-data-theme/`. The source audit
passes with no errors and zero ready modules. Source catalog packaging is
regenerated separately after the combined continuation changes are frozen.
