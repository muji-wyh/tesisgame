# Unity food artwork release QA — September 11, 2026

Food Icons Pack 1.0 was acquired through the signed-in Unity Asset Store and
downloaded with Editor Package Manager. Nineteen reviewed illustrations now
replace their corresponding game pictures. Word IDs, text, voice recordings,
lesson rules, rewards and saves are unchanged.

## Acquisition and actual import

- Original package: 43,257,555 bytes; 100 transparent 256 × 256 PNGs.
- Original SHA256: `ba54f508dc982fec10d64adbdd980dcc2f5b767cda77cb50440215e110d76bc5`.
- Mapping: [19 selected word/source/hash records](../assets/unity-food-icons.mapping.json).
- Unity CLI: 1.0.0-beta.6; Editor: 6000.6.0f1.
- Successful import: `build/unity-art-import/20260911-122407-933036cc/`.
- `unity-command.json`: exit 0; Editor log: successful batch exit, no texture version warnings.
- `sprite-validation.json`: 19/19 loadable Sprite objects, Single mode, transparency enabled, 256 × 256; zero failures.
- Imported PNG bytes match every selected source SHA256. Source packages,
  staging projects and licensed PNGs remain ignored by Git; textures are shipped
  inside the compiled game.

The real package exposed three compatibility assumptions: Windows PowerShell
could not compute `$PSScriptRoot` in a parameter default, legacy pathnames contain
an extra GUID line, and the CLI manages `-batchmode`/`-quit` itself. The wrapper
now handles those cases and writes BOM-free staging configuration. Generated
texture metadata uses the Editor's observed serialized version 13. Regression
checks retain traversal, duplicate, link, hash and vocabulary protections.

## Learning review

All 100 source PNGs were inspected. The selected 19 were compared with the
original illustrations at 64px, then viewed in the actual game on 390 × 844 and
1366 × 768 viewports. The selection covers apple, banana, orange, pear, grape,
cherry, melon, carrot, tomato, corn, peas, egg, bread, cake, cookie, cheese, acorn,
fish and squid. No clipping, wrong labels, unreadable controls or conflicting
referents were found in the final local views.

Original milk, water, root, berry and shell drawings were retained for clearer
teaching cues. All 140 original SVG hashes and all 140 actual WAV hashes still
match the [catalog audit](2026-09-11-catalog-semantic-audit.json). This establishes
unchanged recordings; it is not a new claim of human listening.

## Validation

- `npm test`: 25 native suites, **12,564 checks/assertions**, zero failures;
  Node **100 passes**, zero failures, one pre-existing external chest-source skip.
- `npm run build:web`: success with Godot 4.7.1; **12.09 MB** startup download
  (previously 10.98 MB); all 140 word pronunciations remain in the startup pack.
- Actual PCK check: **19 mapped textures**, **140 loadable original fallbacks**,
  matching compiled texture bytes and current source hashes, zero failures.
- Browser learning suite: **12/12** across desktop Chromium and iPhone/iPad
  WebKit profiles; Learn, Match, Sky, Listen, explicit feedback and silent-browser
  fallback exercised.
- Local targeted run: **38/38** imported-word Learn/Hear observations, plus
  phone/desktop Match and imported-word quiz feedback. No browser errors.
- Two reviewers checked source art and final game screenshots. Evidence is under
  `build/unity-food-review/`; the import and sprite logs are under the run above.

Final tested pack: `game-c02cf44c9c64440f.pck`.
SHA256: `c02cf44c9c64440f47abf40b5a069988d0d1a40d97fb0113d94850ab467fe2f9`.
HTML SHA256: `7ffd8356473ac999f9eab8bb378add14c8df421b15978f24842bc9bf6c934c24`.

## Release status and limits

The tested build is ready for the authorized main merge and deployment.
Production artifact hashes and actual imported-art flows remain to be checked.

A clean checkout without the ignored licensed overrides uses the original art;
building this art release requires the verified local import. Browser device
profiles do not replace physical-device validation. The previously observed
Canary first-compilation stall is not claimed fixed by this art release.
