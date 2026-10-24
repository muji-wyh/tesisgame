# Jelly Finish pull

The Finish control reuses the game's soft jelly artwork. Its upper shoulder stays
in the header while the lower part stretches with a downward drag. Reaching the
release threshold adds a local glow and one short ready cue. Pulling back and
reaching the threshold again replays the cue; holding past it stays silent. Releasing commits
only while the threshold is reached. An early release returns the gel to its
resting shape. These poses are authored by the game, not source animations.

A pointer tap demonstrates the same action: the gel stretches down by 32 screen
pixels over 200 ms, then springs back with a small upward overshoot. The header
layout and hit target stay fixed. Only gestures that travel at most 8 screen
pixels receive this cue; an actual drag keeps its existing release behavior.
The demonstration never arms Finish, plays its ready sound, or pauses the board.
Repeated taps restart one cue, and a fresh pull takes control immediately.
Reduced motion keeps the existing focus highlight without the demonstration's
travel. Cancellation, hiding, resizing, disabling, and focus loss clear the cue.

## Sources and integration

| Material | Creator, source and license | Acquisition and animation |
| --- | --- | --- |
| Jelly surface | Zuhria Alfitra / pzUH, [Jelly Squash Free Sprites](https://www.gameart2d.com/jelly-squash-free-sprites.html), CC0 1.0 | Reuses the already acquired and integrated `gel-coral.png`, documented in [Jelly Match](jelly-match.md). The source is a static painted body; pull and rebound deformation are authored at runtime. |
| Finish flag | Pawel Kuna, [Tabler Icons v3.35.0](https://github.com/tabler/tabler-icons/blob/v3.35.0/icons/outline/flag-check.svg), MIT | Reuses the integrated static `assets/images/ui/finish-flag.svg`. Its [attribution](../../assets/images/ui/ATTRIBUTION.md) and license remain unchanged. |
| Local glow | Bobardo, [Modern 2D Animated Chests FREE Demo 1.0.2](https://assetstore.unity.com/packages/2d/modern-2d-animated-chests-free-demo-360538), Standard Unity Asset Store EULA | Reuses the acquired `assets/chests/particles/portal_glow.png`; source mapping is in `assets/chests/SOURCE.txt`. Static texture with runtime opacity and placement; no source animation is imported. |
| Ready glints | Kenneth Foldal Moe / Archanor VFX, Toon FX 1.52, Standard Unity Asset Store EULA | Reuses the acquired `assets/chests/milestone/sparkle.png`, documented in [Jelly fragments](jelly-fragments.md). Static four-point glint, animated at runtime. |
| Ready sound, `assets/audio/jelly-finish/ready.ogg` | Kenney, [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds), `Audio/confirmation_003.ogg`, CC0 1.0 | Acquired from the user's local Kenney Game Assets All-in-1 3.7.0 collection and copied byte-for-byte. It is a 322 ms mono one-shot, with no loop or animation. The original license is retained beside the asset. |

The ready sound is distinct from the earned-chest reward and plays at the actual
threshold transition. It has no added leading silence, pitch change, normalization,
or time stretching. The selected source and delivered hash are recorded in
[the manifest](jelly-finish.json). Source timing and waveform measurements were
inspected; they do not substitute for listening to the game mix.
