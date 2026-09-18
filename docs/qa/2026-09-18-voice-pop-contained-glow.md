# Contained Voice Pop listening glow

The previous `c38010d` glow extended too far into the game: its large corner
radius produced an oversized bottom arc, while the broad fade tinted the header
and playfield. User screenshot feedback supersedes the earlier visual acceptance.

Keep the existing soft color falloff and listening behavior, but constrain its
geometry to the viewport rim. Diffusion changes from 78–140px to 20–36px;
corner radius changes from 117–210px to 30–54px. The maxima keep large screens
from developing a broad color cloud. This is a CSS-only adjustment.

## Verification

- [x] All 52 existing host checks pass.
- [x] Chromium game previews at 320x568, 768x1024, 834x1194 and 1366x768.
  The 768x1024 view matches the user screenshot's proportions. The header and
  playfield remain clear; the bottom arc is now a compact rounded border.
- [x] Independent visual review of the 320px, 768px and 834px previews confirms
  the light reads as a narrow perimeter, without the former broad color cloud
  or oversized bottom arc. Retain 36px/54px as the diffusion/radius ceilings.
- [x] Production export succeeds: 13.24 MB compressed startup, 28 optional
  audio assets, all 200 pronunciations and 56 optional resource paths verified.
- [x] All nine final exported-game browser cases pass across desktop Chromium,
  iPhone WebKit and iPad WebKit: live captions, compact portrait/landscape,
  input, reduced motion and hiding on exit. Final compact screenshots confirm
  the contained appearance from the preview.
- [x] Independent review of final iPhone portrait/landscape and native iPad
  screenshots confirms a narrow rim, clear original game colors, no broad
  top cloud or intrusive bottom arc, and no hard seams.
- [x] Committed as `bd117b1`, fast-forward merged into main and pushed.
- [x] Promoted 71 hash-verified files, preserving the previous local export.
- [x] Deployed the tested output with `npm run deploy -- -SkipBuild`.
  Production HTML, PCK, engine JavaScript and WebAssembly match local SHA256
  values. Verification completed at 2026-09-18T04:12:13Z.
- [x] All three focused production Chromium cases pass in 26.1 seconds:
  live captions, compact portrait/landscape input, reduced motion and hiding
  on exit. The production portrait screenshot retains the accepted narrow rim.

Before/after previews are in ignored `build/voice-pop-qa/contained-glow/`.
Host results are in `contained-glow-host.log`. Recognition in browser checks
uses fixtures, not a physical microphone. No speech or gameplay behavior changes.
Exported-game results and screenshots are in `contained-glow-integrated.log`,
`contained-glow-integrated-tests.json` and `contained-glow-integrated/`.

The PCK, engine JavaScript and WebAssembly match the preceding release byte for
byte. The new `index.html` SHA256 is
`34a3dbf1d7c7453f1923e7bbb5a381a5b2c7e50303242a58d8b1639d03ee8206`.

Production: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=bd117b1

Deployment evidence is retained in `build/voice-pop-qa/`:
`contained-glow-tested-manifest.json`, `contained-glow-deploy.log`,
`contained-glow-production-manifest.json`, `contained-glow-production-hashes.log`,
`contained-glow-production.log`, `contained-glow-production-tests.json` and
`contained-glow-production/` screenshots.
