# Interface icons

## Jelly journey controls

The stage medallions and nine-slice challenge frame in `jelly-map/` are unmodified
128px PNGs from Kenney's acquired **UI Pack - Adventure 1.1**, under CC0 1.0.
The actual source preview and selected originals were inspected before integration.
Original paths, hashes and the byte-identical license are in
`jelly-map/sources.json` and `jelly-map/LICENSE-CC0.txt`.
These assets are static; map placement, focus and rating feedback are game-authored.
The challenge reuses the existing acquired Toon FX gold coin, with source and
rights unchanged in `assets/coins/manifest.json`. No private source package is copied.

## Shared controls

The SVGs in `controls/` are acquired Tabler Icons v3.35.0 artwork by
Paweł Kuna under the MIT License. The initial set was downloaded on October 20, 2026,
inspected at their 28px display size inside 44px light and dark controls, and
integrated into the shared icon button. The Home icon also replaces the earlier
Fluent illustration in game navigation. Vocabulary and game-preview illustrations
retain their existing artwork.

The icons use the source 24px view box and rounded 2px outline. The filled
microphone marks active listening without changing the microphone's upright
orientation; the eye switches between the source closed and open variants.
Only `currentColor` is replaced with white for runtime theme tinting. Vector
paths are unchanged. These are static source SVGs, with no animation clips;
button feedback and the existing price/count badges remain game-authored.

Exact original URLs, source SHA-256 values and integrated SHA-256 values are
recorded in [controls/sources.json](controls/sources.json). The full
[MIT license](LICENSE-Tabler.txt) is retained. Godot runtime review follows
the shared control and page-layout checks; the acquisition record distinguishes
it from the source-scale inspection.

`controls/lock.svg` was acquired from the same v3.35.0 release on October 25,
2026 for the Jelly Words Auto Collect unlock state. The original closed-lock
source was inspected at 20 and 24 pixels before integration; it retains the
source paths and uses the same white/theme-tint conversion. Its source and
integrated hashes are recorded in `controls/sources.json`. It has no animation.
The locked control pairs the static icon with "Lv3"; its ready artwork and
effects are reserved for the unlocked state.

`controls/player-pause.svg` was acquired from the same v3.35.0 release on October
25, 2026 and rendered for source inspection before integration into the Jelly
header. It keeps the original pause paths and existing white/theme-tint
conversion; original and integrated hashes are in `controls/sources.json`.
It is static MIT-licensed artwork, with no animation clips.

Jelly Words' current-stage goal cards reuse the exact vocabulary artwork through
`WordArt`; creator, source, per-word license and motion availability remain in
[the word-library record](../../../docs/assets/word-library.md). Image-free
terms retain text, with no substitute picture. Their goal header reuses
`mastery-medal.webp` below, while the three mastery accents reuse the acquired
static Toon FX sparkle documented in
[Jelly level feedback](../../../docs/assets/jelly-level-feedback.md). No new
illustration or effect asset was acquired for these cards.

## Finish and mastery

`jelly-goals/completed.svg` and the inline Resume control's
`controls/player-play.svg` are acquired Tabler Icons 3.35.0 by Paweł Kuna (MIT).
The original SVGs were rendered and inspected before adapting only `currentColor`
to white. Original/output hashes and source URLs are recorded in the respective
`sources.json` files. They contain no source animation clips.

Campaign rating stars and the extra-time clock reuse the exact acquired Microsoft
Fluent Emoji 3D illustrations from the reviewed word library (Microsoft Corporation,
MIT). Their unchanged copies live in `jelly-goals/` so they are available before
any age media pack. Source/output hashes, rights and acquisition/integration state
are recorded in `jelly-goals/sources.json`. Goal achievement reuses the existing
licensed Toon FX static light/sparkle textures and Kenney CC0
`confirmation_002.ogg`-derived receipt cue, not a new generated illustration or
audio recording. Its card-local animation and the paused gel tug are game-authored.

`finish-flag.svg` is the `flag-check` icon from Tabler Icons v3.35.0 by
Paweł Kuna, licensed under the MIT License. The source SVG was downloaded on
October 9, 2026, inspected, and integrated into Jelly Match's Finish button.
Its vector paths are unchanged; `currentColor` is replaced with white so Godot
can tint the icon for normal, focus, pressed, and disabled states. It is static
artwork and contains no animation.

- Original: https://github.com/tabler/tabler-icons/blob/v3.35.0/icons/outline/flag-check.svg
- Creator/project: https://tabler.io/icons
- License: [LICENSE-Tabler.txt](LICENSE-Tabler.txt)

The button surface is an intentional interface container, using the game's
existing typography and click cue. State styling provides a raised cream face,
pressed depth, and a separate keyboard focus outline without changing its hit area.

`mastery-medal.webp` reuses the acquired Microsoft Fluent Emoji Sports medal 3D
illustration by Microsoft Corporation under the MIT License. It is a byte-identical
copy of the integrated word-library artwork. The source, hash, license, acquisition
status, and static-animation record are in
[the vocabulary mastery record](../../../docs/assets/vocabulary-mastery.md).
