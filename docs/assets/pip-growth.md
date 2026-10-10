# Pip growth stages

The growth journey keeps the original Pip silhouette, cream eyes, orange bill,
warm outlines, and expressive six-part body. Every age remains friendly and
recognizable. The stages describe a learning journey, not a developmental
diagnosis. Baby has softer infant proportions; later stages use familiar outfits.

These are **new stage compositions for review**, assembled from already
integrated production illustration. They are not newly acquired stock character
designs, generated concept-art placeholders, or a one-to-one assignment of the
eight world outfits to ages. The interactive review is a localhost-only asset
tool, served directly from `web/preview/pip-growth/`. Run `npm run preview:pip`
and open `http://127.0.0.1:41774/`. It is excluded from the production export
and has no in-game entry.

## Visual progression

Age is separate from Lv0–Lv99 mastery progression. Pip begins as Baby (`age: 0`).
Completing an entire curriculum cohort grants its age appearance. A mastery-level
change alone never changes Pip's artwork or available actions.

Baby recomposes the original uncovered duck illustration with a large head,
shorter cream-colored body, small wings and close-set feet. Original contours,
speaking mouth and all ten expression heads remain intact. The exact proportional
transforms and palette changes are recorded in the Baby catalog entry. No new
stock character, placeholder outline, or unlicensed image is introduced.

| Age | Companion | Composition | Newly available action |
| --- | --- | --- | --- |
| Baby | Baby Pip | Cream plumage, round face, small wings and feet; no clothing | Hello wave |
| Age 3 | Sprout | Mint striped shirt; original uncovered tuft | Hello wave |
| Age 4 | Little Helper | Leaf-green overalls; original uncovered tuft | Curious look |
| Age 5 | Curious Scout | Honey cap and leaf-green overalls | High five |
| Age 6 | Story Finder | Raspberry beret and deep teal overalls | Peekaboo |
| Age 7 | Trail Buddy | Sage field hat and pocketed vest | Wing stretch |
| Age 8 | Wayfinder | Flower-trimmed trail hat, teal jacket, and amber scarf | Happy hop |
| Age 9 | Word Maker | Cornflower beret and teal maker's apron | Gentle sway |
| Age 10 | Sky Explorer | Green explorer cap and pearl field suit | Wing flutter |
| Age 11 | Bright Navigator | Cream navigator cap and blue field suit | Two-step wave |
| Age 12+ | Kind Guide | Amber beret, deep teal collared jacket, and gold details | Celebration dance |

All earlier moves and voice lines remain in the preview repertoire. Breathing,
blinking, and ten emotional expressions are available at every age; basic
emotional support is never withheld as an unlock. More experience adds variety,
not continuous activity or louder feedback. Preview actions play once, settle,
and return to quiet breathing. Switching stages or hiding the page stops current
action and speech. Reduced motion shows an authored happy expression without
jumps, sway, or idle movement. Preview speech requires an explicit click.

## Source, rights, and status

| Material | Original source and creator | License / acquisition | Integration and available animation |
| --- | --- | --- | --- |
| Pip body, head, wings, and feet | `assets/images/mascots/pip-dance-parts.svg`, `pip.svg`, and `pip-idle-actions.svg`; existing original game art. No individual illustrator is identified in the existing repository record. | Already integrated project material. Repository package declares ISC; no separate artist license is recorded. No additional third-party license is claimed. | Original shapes retained. Six separate articulated parts, four ordinary poses, and four idle poses. These are illustration layers, not baked animation clips. |
| Clothing | `assets/images/mascots/outfits/wardrobe.svg`; existing original project wardrobe art. | Already integrated under the same recorded project rights. | Head and body layers are recombined and deliberately recolored. Original silhouette/detail is preserved; no new character outline is substituted. Source combinations and exact palette mappings are recorded in the stage catalog. Baby adds no wardrobe layer and adapts only existing Pip proportions and colors. |
| Faces | `assets/images/mascots/pip-expression-heads.svg`; authored project adaptations described in `docs/assets/pip-expressions.md`. | Already integrated derivative art under the existing source rights. | Ten expressions retained, including complete headwear. Full-body and head-only atlases share the existing source coordinates. |
| Motion | `scripts/duck_mascot.gd` articulated joint conventions and existing gestures. Growth timing is authored in `preview.js` and the corresponding native growth-pose function. | Original project code and animation composition. | Head, body, wings, and feet move independently around existing joints. The browser and native growth gestures use the same beat curves. These are authored animations, not a claim that source illustration includes baked clips. |
| Preview and age-growth voice | Microsoft Edge online TTS, `speech.platform.bing.com/consumer/speech/synthesize/readaloud`; Microsoft Ava Neural. English scripts authored for this game. | Generated and acquired locally with `edge-tts` 7.2.8. Microsoft service terms apply; see the [Microsoft Services Agreement](https://www.microsoft.com/servicesagreement). The LGPLv3 client license does not grant extra rights to the voice service. | Ten original response MP3 recordings acquired and integrated. Click-only in the review page; available for explicit age-growth recognition in the game. No gameplay guide narration or duck calls are added by this asset set. |
| Typography | Nunito Project Authors; acquired Google Fonts material already in `assets/fonts/`. | SIL Open Font License 1.1; copied unchanged to `FONT-LICENSE.txt`. | Existing static 600/800 font instances are reused to avoid the variable-font weight issue previously observed in Windows WebKit. |

## Voice profile and exact recordings

The approved `ava-sweet` profile is used without substitution:

| Setting | Value |
| --- | --- |
| Voice | `en-US-AvaNeural` |
| Rate | `-15%` |
| Pitch | `+8Hz` |
| Volume | `+0%` |
| Postprocessing | None; original MP3 response bytes |
| Generation client | `edge-tts` 7.2.8 |

`web/preview/pip-growth/audio/manifest.json` records each exact script, runtime
path, byte length, and SHA-256. The recordings also exist at
`assets/audio/pip-growth/` for native use. The preview copies have identical
bytes. Baby shares the existing Sprout greeting. Ages 4–12+ each add one line, progressing from a short greeting to a
longer, encouraging sentence. Earlier lines remain available in the preview's
voice selector. These are authored character lines, not vocabulary assessments.

## Runtime and preview contract

`data/pip-growth-stages.json` is the runtime source catalog;
`web/preview/pip-growth/stages.json` is its exact preview copy. Each stage has:

- `age`, `label`, `id`, `name`, and a short visual `description`.
- `source` with the original wardrobe layer IDs and exact palette substitutions.
- `art` with repository-relative runtime sheet paths, and `previewArt` with
  corresponding paths relative to the review page.
- `actions` and `voices` as cumulative ordered repertoires.
- `newAction` and `newVoice` with the new or retained item at that age.
- `newVoice.path` for runtime and `newVoice.previewPath` for the review page.

The 55 runtime SVG atlases are in `assets/images/mascots/growth/`. Their preview
copies live under `web/preview/pip-growth/art/` and have identical bytes. No
preview rendering code needs to be bundled into Godot.

| Sheet | Source size | Cells |
| --- | --- | --- |
| Ordinary | 480 × 120 | idle, speaking, blink, wave |
| Idle | 480 × 120 | existing four idle-action poses |
| Parts | 720 × 120 | body, head, left wing, right wing, left foot, right foot |
| Expressions | 1200 × 120 | the documented ten complete expression poses |
| Expression heads | 1200 × 120 | the same ten faces and their headwear |

The public mascot API is `growth_age` and `set_growth_age(age)`. Age 0 selects
Baby, ages 3–12 select the earned curriculum appearance, and invalid low ages
normalize to Baby. The original `pip-lv3` through `pip-lv12` filenames are retained
for compatibility with existing imports; their catalog identity is age-only.

All cells retain their 120-unit coordinate system and transparent margins.
Runtime SVG imports use the existing 3× scale. The six articulation pivots are
`(61,98)`, `(61,72)`, `(33,78)`, `(88,78)`, `(40,103)`, and `(80,103)`.
Paint order remains feet, body, head, then wings. The preview uses a larger
view box for motion headroom; it does not stretch the artwork to fit a screen.

## Regeneration and checks

```powershell
node web/preview/pip-growth/generate.cjs
python tools/edge-voice-batch.py --manifest web/preview/pip-growth/.voice-cache/batch.json
node web/preview/pip-growth/generate.cjs --install-voices
node web/preview/pip-growth/verify.cjs
```

The generator uses the existing wardrobe generator and original source layers;
it does not modify those sources or the general vocabulary voice pipeline.
Its local voice cache is ignored and is not part of the shipped preview.
Rebuilding the art does not require a voice request; the final install step uses
already acquired cache bytes. Re-synthesis can change output bytes when the
service changes, so update and inspect the resulting recording manifest.

The asset check verifies the Baby and ten ages, cumulative repertoires, distinct
compositions, atlas sizes, 3× imports, runtime/preview byte parity, copied fonts,
and every recording hash. Browser layout, motion extremes, actual playback, and
native integration need separate visual and functional verification; these
checks alone do not establish listening quality or physical-device behavior.

The October 9 browser review passed all ten stages on desktop Chromium, an
iPhone 13 WebKit profile, and a short 844 × 390 Chromium viewport. Captures show
the complete ten-stage comparison and each selected stage. The review exercises
all ten gestures, their return to rest, reduced-motion acknowledgement,
click-triggered audio, and cancellation when changing stages. A second capture
checked the final high-five and stretch wing angles after moving the hands away
from the face. Actual source captures are kept locally under
`web/preview/pip-growth/review-output/` and are excluded from shipped content.
This is browser-emulated device coverage, not testing on physical phones.

FFprobe decoded all ten voice files as 24 kHz mono MP3, with durations from
1.87 to 3.84 seconds. Browser playback starts and stage switching stops it.
These checks establish file/playback integrity; subjective listening approval
remains part of the interactive user review.

`tests/godot/pip_growth_tests.gd` covers age artwork, theme independence,
cumulative action access, manual timing without proactive movement, repeated
input, lifecycle interruptions, reduced motion, word-speech priority, contact
timing, stable input bounds, and retained basic feedback/shared celebration.

## Age separation review

The new Baby composition and Age 3 comparison were rasterized directly from the
production expression atlases at phone-readable size. The Baby retains the
original expressive face and contours with a visibly smaller body and wings.
The asset verifier checks 11 distinct compositions, 55 identical runtime/preview
atlases, age-only metadata, cumulative action access, and unchanged recording
hashes. Native lifecycle, rendered motion and local preview interaction are
covered separately by their focused suites. No new voice audio was generated.
