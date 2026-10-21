# Professional Pip wardrobes

Professional vocabulary uses the same Pip companion as everyday words. The
selected career changes Pip's apparel while the selected career's mastery level
remains a separate progress value. Switching vocabulary never changes the saved
everyday age or makes one career inherit another career's mastery.

## Source and rights

| Material | Original source and creator | License and acquisition | Integration and animation |
| --- | --- | --- | --- |
| Storybook Pip character | Existing project Pip vectors, adapted locally by Codex in `tools/pip-growth/storybook.cjs`; original individual illustrator not recorded | Previously integrated original project material. Repository ISC declaration; no additional illustrator license or third-party rights are claimed. | The same approved face, matte volume, feather contours, feet and attached shoulder layers are reused. |
| Twenty career wardrobes | `tools/pip-growth/professional.cjs`, original apparel illustration authored locally by Codex for this project on October 21, 2026 | Original project adaptation under the repository ISC declaration. No purchase, stock character acquisition or generated raster artwork. | Five transparent PNG atlases per career: four ordinary poses, four idle poses, six articulated parts, ten complete expressions and ten matching expression heads. Existing explicit companion gestures and reward feedback animate the layers. |

The new apparel is part of the character artwork: collars, lapels, pockets,
stitching, folds, matching moving sleeves, fitted headwear and attached
accessories. It does not replace Pip with a workplace preview or a generic icon.
All twenty careers have independent silhouettes or apparel combinations, using
the approved older storybook anatomy. Career level does not imply a human age,
professional qualification or clinical authority.

`data/pip-professional.json` lists each career, its apparel description, all five
asset paths and SHA-256 hashes. The assets live in
`assets/images/mascots/professional/`. The original acquired workplace images
remain separately recorded in `professional-themes.json`; none were used as
character clothing or represented as new portrait assets.

## Rig and lifecycle

The artwork preserves the 120-unit pose frame, 360-pixel cells, six body joints
and three-unit grounding inset. Sleeves remain on their matching wing layers.
The existing body-following shoulder transform keeps the wings attached during
gestures and celebrations. Headwear and glasses are included in every matching
expression head. Reduced motion, speech, interruption and celebration clocks
continue through the existing mascot implementation. No automatic looping dance
is introduced.

`DuckMascot.set_professional_profile` accepts the selected `course_id`, `title`
and `level`. An empty profile restores the latest earned everyday appearance.
Level-only updates preserve the current animation and loaded textures.
`ProfessionalPip.portrait` exposes the same first-frame atlas crop to libraries.

## Reproduction and review

```powershell
node tools/pip-growth/professional.cjs
node tools/pip-growth/professional.cjs --check
node --test tests/professional-pip-art.test.cjs
```

The generator requires Sharp; use `SHARP_MODULE` when it is available through an
external authoring runtime. It writes the production atlases and catalog and a
local review sheet, `build/professional-pip/all-careers.png`, including actual
44-pixel and 56-pixel header views. Review sources remain under
`build/professional-pip/` and are not shipped as runtime art. The native
`professional_pip_tests.gd` suite checks the real textures, career switching,
everyday-age restoration, level-only updates and attached celebration joints.

The October 21 source review inspected all twenty completed portraits at the
151-pixel Home size and the actual 44-pixel and 56-pixel header sizes. The review
checked consistent faces and light, readable career apparel and attached wing
roots. All 680 transparent frame bounds were checked, and the native career
suite passed 484 assertions. Production PNG imports use lossless compression
and transparent-edge correction, matching the existing growth artwork. This
source and rig review is separate from the enclosing Home/browser layout review.
