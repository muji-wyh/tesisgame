# Game mode illustrations

## Home mechanics previews

The Home cards reuse three acquired Microsoft Fluent Emoji 3D illustrations by
Microsoft Corporation under the MIT License. The WebP files below are
byte-identical copies of the already integrated vocabulary stills, not new
downloads or source-page previews. Their original source revision, hashes,
reviewed transformations, and acquisition status remain in the corresponding
`cat`, `apple`, and `microphone` entries of the
[word-library manifest](../../../../docs/assets/word-library.json).

| UI copy | Integrated original | Exact upstream source |
| --- | --- | --- |
| `cat.webp` | `assets/images/word-library/cat.webp` | [Cat/3D/cat_3d.png](https://raw.githubusercontent.com/microsoft/fluentui-emoji/1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/assets/Cat/3D/cat_3d.png) |
| `apple.webp` | `assets/images/word-library/apple.webp` | [Red apple/3D/red_apple_3d.png](https://raw.githubusercontent.com/microsoft/fluentui-emoji/1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/assets/Red%20apple/3D/red_apple_3d.png) |
| `microphone.webp` | `assets/images/word-library/microphone.webp` | [Microphone/3D/microphone_3d.png](https://raw.githubusercontent.com/microsoft/fluentui-emoji/1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/assets/Microphone/3D/microphone_3d.png) |

The upstream project is [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji),
pinned to revision `1ffb34c752ecf5d402f04cfb4b392c77f57c54bc`. The full
[MIT license](../../../../docs/assets/licenses/fluent-emoji.txt) is retained.
These sources are static illustrations, with no supplied animation clips.

The copies ship with the core interface so Home can explain each game's
mechanics without loading another age's vocabulary pack. The example pictures,
word labels, card surfaces, and gestures form decorative miniature game scenes;
they neither choose curriculum words nor award learning progress or rewards.
The existing painted gel skins retain their acquired CC0 provenance in the
[Jelly Match asset record](../../../../docs/assets/jelly-match.md).

Each scene automatically loops a silent 5.8-second gameplay demonstration on
Home, with staggered phases, a readable outcome hold and a soft reset. Match
selects its pair, Memory flips two cards, Voice Pop shows speech and a sliced
card, Phrase Builder slides a word into place, and both jelly modes join and
collect their pieces. Jelly Words also sends a chest fragment from its completed
word into a Royal chest, opens the lid, and fans out gold coins. Hidden Home and
background browser tabs pause the loops;
the system reduced-motion setting uses static compositions. This movement is
authored by the game's interface renderer, not a claim that the source pictures
contain character animation. The reused gold coin retains its existing
[treasure asset provenance](../../../../docs/assets/coins.md).

### Jelly Words treasure demonstration

The preview retains `ca` + `t` becoming `cat` and adds the chest reward to that
same decorative sequence. Its fragment flight, hinged lid, local glow, glints,
and coin fan are silent interface animation. Reduced motion keeps a static word
and open chest composition. The preview does not open a saved chest, select
loot, write progress, or issue coins.

The following assets were already acquired and integrated into the game. They
are reused here; no listing screenshots, new downloads, or new source animation
clips are introduced.

| Runtime material | Source, creator, and license | Acquisition and animation status |
| --- | --- | --- |
| Royal chest layers in `assets/chests/rigs/royal/`: `body.png`, `interior.png`, `lid_outer.png`, `lid_inner.png`, and `latch.png` | Bobardo, [Modern 2D Animated Chests FREE Demo 1.0.2](https://assetstore.unity.com/packages/2d/modern-2d-animated-chests-free-demo-360538), under the recorded [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms). Derived from `SPR_Royal_Close.png` and `SPR_Royal_Open.png`; see [original source mapping](../../../chests/SOURCE.txt) and [derived layer record](../../../chests/rigs/SOURCE.md). | Previously acquired source PNGs and integrated deterministic derivatives. The static source poses supply the visible material; the game animates the separate layers around their recorded hinge. No Unity animation clip or controller is imported. |
| Chest-fragment marker from `assets/chests/royal/closed.png` | Reuses the existing Royal closed chest artwork and its source rights above, following the game's existing fragment presentation. | Existing acquired and integrated static PNG, cropped at runtime to exclude transparent margins; only the decorative marker's placement and flight are authored for Home. |
| `assets/chests/particles/portal_glow.png` | Bobardo, the same Modern 2D Animated Chests package, `Particles/Textures/portal_glow.png`, under the recorded Standard Unity Asset Store EULA; see [source mapping](../../../chests/SOURCE.txt). | Already acquired and integrated static texture; Home controls its local size and opacity. |
| `assets/chests/milestone/sparkle.png` | Kenneth Foldal Moe / Archanor VFX, [Toon FX 1.52](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601), source `Textures/sparkle.png`, under the recorded Standard Unity Asset Store EULA. Source hashes and acquisition evidence remain in [Jelly fragments](../../../../docs/assets/jelly-fragments.md). | Already acquired and integrated static glint; timing and movement are game-authored. |
| `assets/coins/gold-coin.png` | Kenneth Foldal Moe / Archanor VFX, Toon FX 1.52, derived from `Textures/coins.png`, under the recorded Standard Unity Asset Store EULA; see [coin artwork](../../../../docs/assets/coins.md). | Previously acquired, recolored, and integrated coin texture. Home animates its flight without invoking the reward or wallet systems. |

## Retained Twemoji illustrations

The three SVG illustrations are unmodified Twemoji 14.0.2 artwork by Twitter,
Inc. and other contributors, licensed under Creative Commons Attribution 4.0
International (CC BY 4.0). They were acquired for the original standalone mode
icons. The rocket remains integrated into the Voice Pop microphone welcome
screen; the Home mechanics previews use the artwork described above. These SVG
sources have no animations.

- Project: https://github.com/twitter/twemoji/tree/v14.0.2
- Source: https://github.com/twitter/twemoji/tree/v14.0.2/assets/svg
- License: https://creativecommons.org/licenses/by/4.0/
- Full license: [LICENSE-CC-BY-4.0.txt](LICENSE-CC-BY-4.0.txt)

| Local filename | Original filename |
| --- | --- |
| cat.svg | 1f431.svg |
| rainbow.svg | 1f308.svg |
| rocket.svg | 1f680.svg |
