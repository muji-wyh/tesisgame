# Interface icons

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

## Finish and mastery

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
