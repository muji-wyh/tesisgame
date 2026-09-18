# Visible rhythm in the Voice Pop listening glow

The narrow glow from `bd117b1` barely appeared animated: its faint highlight
moved only 18% of an edge over an 8–11 second leg, then reversed. User feedback
requires visible rhythm, while retaining the contained geometry.

All eight edge/corner pieces now share a 2.6-second smooth breath. Stronger
colored highlights sweep along each edge every 3.2 seconds, with staggered
phases and clockwise directions. Each highlight fades out before wrapping.
An inner flow layer supplies a stationary fade at each strip's ends, keeping
moving highlights from cutting sharply against the corners. Supported browsers
round the shared corner radius to whole CSS pixels, preventing WebKit's thin
gaps where separately masked pieces meet at fractional coordinates.
Only opacity and the highlight transforms animate; the 20–36px diffusion and
30–54px corner radius remain fixed. Reduced motion removes both animations,
and stopping listening hides the whole overlay immediately.

## Verification

- [x] All 52 existing host checks pass.
- [x] All eight temporal pixel cases pass across Chromium/WebKit, mobile/desktop
  and light/dark backgrounds. In 0.473–0.808 seconds, 24.18%–54.79% of each
  edge's sampled pixels change by at least 10 RGB levels. Pixels beyond 60px
  remain unchanged; reduced motion is static; hiding the overlay leaves zero
  residual pixels. All eight edge/corner click-through targets work.
- [x] Five native game sequences pass: Chromium at 320x568, 768x1024 and
  1366x768; WebKit at 768x1024 and 834x1194. All 45 frames follow the real
  animation clock, with no CSS injection, seeking or playback acceleration.
  Exported CSS matches source exactly after image inlining; no browser or
  Godot errors occur. Visual review confirms visible breathing and travelling
  highlights, smooth corner joins and the same narrow inward fade.
- [x] All nine checks on the export with the flow mask pass across desktop Chromium,
  iPhone WebKit and iPad WebKit. Coverage includes live captions, compact
  portrait/landscape, input, reduced motion and immediate hiding on exit.
- [x] After pixel alignment, the three focused iPad WebKit cases pass again
  in 28.6 seconds, including reduced motion and hiding on mode exit.
- [x] Production export succeeds: 13.24 MB compressed startup, 28 optional
  audio assets; 200 pronunciations and 56 optional resource paths verified.
- [x] Runtime commit `78ffde8` fast-forwarded to `main`, pushed and deployed.
  The exact tested candidate was promoted with all 71 files hash-verified.
  Production HTML, PCK, engine JavaScript and WebAssembly match the local
  release byte for byte. All three production Chromium cases pass in 27.0
  seconds: live captions, compact portrait and compact landscape, including
  reduced motion and hiding on mode exit. Production screenshot review passes.

Evidence is retained under ignored `build/voice-pop-qa/rhythmic-glow/`
and the `rhythmic-glow-*` logs. Speech recognition uses fixtures in browser
checks; this is a CSS listening animation, not a microphone amplitude meter.

Final temporal evidence under `runs/`:

- `20260918T043042218Z-isolated`: eight pixel and input cases.
- `20260918T043125943Z-game`: three native Chromium sequences.
- `20260918T043233716Z-game`: two native WebKit sequences.

Production acceptance logs and manifests under `build/voice-pop-qa/`:

- `rhythmic-glow-deploy.log`
- `rhythmic-glow-tested-manifest.json`
- `rhythmic-glow-production-manifest.json`
- `rhythmic-glow-production-tests.json`

Live release: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=78ffde8

The PCK, engine JavaScript and WebAssembly match the previous release byte for
byte. The final CSS-only pixel alignment was applied to a fresh copy of the
verified Godot export; the entire generated style block matches the source
after Pip image inlining. Final `index.html` SHA256:
`d6444f0a2b5f1915a7b010652461ef28897011adf1ea036442a8c74460c7e2e2`.
