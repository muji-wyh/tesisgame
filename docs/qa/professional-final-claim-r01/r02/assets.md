# Existing fixture resources

These are acquired, integrated repository assets reused only as synthetic test resources. They are not source previews, new curriculum artwork, or replacements for production presentation. The probe assigns the existing fixture's synthetic hash IDs to these resources; those IDs are intentionally not their real file hashes. `inputs.json` records their actual bytes.

| Resource | Original source and creator | License | Acquisition and motion |
| --- | --- | --- | --- |
| `assets/images/words/absent.png` | [Mulberry Symbols absent.svg](https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/9cbab9f400c5de44e2bc58839cca07294aadb086/EN/absent.svg); Steve Lee, original symbol design project by Garry Paxton | [CC-BY-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/) | Already downloaded and integrated; original SVG rasterized to transparent 192 by 192 PNG with original design preserved. Static illustration; no animations. |
| `assets/audio/jelly-match/collect-do.wav` | rubberduck's [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) and Aeva's [BOING!](https://opengameart.org/content/boing) | [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Original recordings acquired and adapted into the existing collection sound. Current derivative is 0.24 seconds, mono PCM16 at 44100 Hz; one-shot audio, no animation. |

The original source hashes, acquisition records, and conversion details are in `docs/assets/mulberry-vocabulary.json` and `docs/assets/jelly-collection-audio.json`; the latter links to `docs/assets/jelly-match.json` for its source master. No media download, generation, conversion, or integration is performed by this proposal.
