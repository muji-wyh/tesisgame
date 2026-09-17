# Broader, rounder Voice Pop glow

Follow-up to `5f820e4`: increase the visible glow area and soften its shape.
Diffusion increases from 58–104px to 78–140px, about one third wider. A separate
corner radius of 1.5 times the diffusion width leaves a rounded inner opening
instead of fading into a sharp inner corner. The outer rim feathers out, with
its brightest point slightly inward. Smooth upper-corner attenuation keeps Pip
and the menu readable without the previous diagonal dark crease.

The change is confined to the existing CSS overlay. Listening lifecycle,
pointer-through and static reduced-motion behavior remain intact. No engine,
gameplay, speech, asset or JavaScript changes are required.

## Verification

- [x] All 52 existing host checks pass.
- [x] Eight isolated Chromium/WebKit cases pass at 390x844 and 1366x768 on
  dark/light backgrounds: center transparency, visible inward diffusion, edge
  input, actual animation, immediate hiding and static reduced motion.
- [x] Quick integrated CSS previews at 320x568, 834x1194 and 844x390 confirm
  the wider rounded contour and readable Pip/menu before the full export.
- [x] All nine exported-game browser cases pass across desktop Chromium,
  iPhone WebKit and iPad WebKit. Coverage includes live interim captions,
  320x568 and 844x390 layouts, input, reduced motion and hiding on mode exit.
- [x] Desktop exported screenshots confirm rounder corners, a wider glow and
  readable controls, cards and captions, including compact portrait/landscape.
- [ ] Commit, main integration, deployment and production verification.

Evidence: ignored `build/voice-pop-qa/rounder-glow/` contains the probe, previous
release comparison and new screenshots. `rounder-glow-host.log` contains host
results. Browser speech events are fixtures; no physical microphone is used.

Exported-game evidence: `build/voice-pop-qa/rounder-glow-integrated.log`,
`rounder-glow-integrated-tests.json` and `rounder-glow-integrated/` screenshots.

## Artifact

The export remains 13.24 MB compressed at startup, with 28 optional audio assets.
Pack verification found all 200 pronunciations and all 56 optional resource paths
without failures. PCK, engine JavaScript and WebAssembly are byte-identical to
the previous release. Only the HTML changes.

| File | SHA256 |
| --- | --- |
| `index.html` | `17615c069d5a5562a6906deee815a2b46324cc59d89fa9f09ebc6f468d04a31d` |
| `game-9651e6515167d63f.pck` | `9651e6515167d63fce4ca9e7b5d85ec432c6ca08d1c54fa70e7ecb55d49a456d` |
| `engine-c8ca3724771088b0.js` | `13ce7253b63b49b659e9eee7fbdcec1d9b4e3d5c8bd1b5460c4065bd0ea68b31` |
| `engine-c8ca3724771088b0.wasm` | `35116f68540ac41acf7d71ea457added91b5e960a9cca3e2acc72918eaf01277` |
