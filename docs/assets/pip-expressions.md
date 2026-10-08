# Pip expression artwork

The expression system extends the game's existing Pip illustration. It keeps
the original head contour, feather tuft, asymmetric cream eyes, orange bill,
warm brown outlines, blush colours, body proportions, and all eight wardrobes.
It does not introduce a replacement character or an external art pack.

## Source and status

| Material | Source and creator | Rights and acquisition | Status |
| --- | --- | --- | --- |
| Pip's head, bill, cheeks, resting and waving bodies | Existing original game art in `assets/images/mascots/pip.svg` and `pip-dance-parts.svg`; the repository does not identify an individual illustrator. | Already integrated project artwork. No new third-party acquisition or license is introduced. The repository package declares ISC; no separate artist license is recorded for Pip. | Reused directly, with authored edits to eye contours, pupil direction, brow lines, and bill expression. |
| Seasonal and world clothing | Existing editable `assets/images/mascots/outfits/wardrobe.svg`, maintained as original project art. | Already integrated project artwork under its existing rights. | The original head and body costume layers are applied by the generator, including the Space helmet over every face. |
| Expression head source | `assets/images/mascots/pip-expression-heads.svg`; expression adaptations authored for this project from the material above. | Local derivative artwork, not a downloaded source preview. | Editable source for ten expressions. |
| Complete expression poses and wardrobe variants | `tools/generate-pip-outfits.cjs`, using the expression head source and original body. | Generated derivatives of the same integrated sources. | Runtime SVG atlases; the face is identical between the full-body and articulated-head versions. |

## Atlas contract

Both expression atlases have ten **120 × 120** cells in a single **1200 × 120**
row. Preserve each cell's transparent margins: the head-only sheet uses the
same head pivot as the existing dance atlas, and the complete sheet retains the
original body and shadow. The `delighted`, `proud`, and `wink` complete poses
reuse Pip's original raised greeting wing; all other complete poses use the
resting body. The head-only faces have no body or wing baked into them.

| Index | Name | Visual purpose |
| ---: | --- | --- |
| 0 | `neutral` | Original open-eyed, closed-bill resting face. |
| 1 | `listening` | Raised attention, larger pupils looking toward a sound. |
| 2 | `thinking` | Upward glance, asymmetric brow and a small thoughtful bill. |
| 3 | `delighted` | Smiling closed eyes and an open, laughing bill. |
| 4 | `proud` | A quieter closed-bill smile and relaxed smiling eyes. |
| 5 | `encourage` | Warm direct eye contact and a supportive smile; no tears. |
| 6 | `surprised` | Bright wide eyes and a rounded open bill, without fear. |
| 7 | `sleepy` | Soft horizontal lids, lowered gaze, and a relaxed bill. |
| 8 | `wink` | One smiling closed eye and a playful closed-bill smile. |
| 9 | `blink` | The original blink face, retained for brief eyelid transitions. |

`pip-expression-heads.svg` is the editable head source. The generator produces
the base full-body `pip-expressions.svg` and both corresponding
`outfits/pip-<theme>-expression-heads.svg` and
`outfits/pip-<theme>-expressions.svg` for each world. The original four-pose,
idle-action, and articulated-part sheets stay unchanged.

```powershell
node tools/generate-pip-outfits.cjs
node tools/generate-pip-outfits.cjs --check
```

The atlases provide expression poses, not baked animation. Runtime timing and
head motion select the same face index in ordinary and articulated rendering.
The existing speaking poses remain available separately. Import expression
SVGs at the same **3×** scale as the existing mascot sheets; sample regions by
the imported texture height, not a hard-coded source pixel count.

## Art review

Rendered source previews were inspected at **156 px** and at the actual
**52 px** header size across all eight outfits. Eyelid, pupil and bill changes
carry the expression because hats cover much of Pip's brows. Headwear remains
on top of the complete face, including the transparent Space helmet. The
preview contacts are local review evidence under
`build/pip-expressions-156.png` and `build/pip-expressions-52.png`; they are not
additional shipped textures. Runtime motion and integration require their
own native and browser checks.
