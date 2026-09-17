# Voice Pop soft listening glow

The user supplied a Siri screen reference after the first Voice Pop feedback
release. The previous falloff became almost transparent within 18px and looked
like a thin colored border. This follow-up widens the inward diffusion and joins
the edges around rounded corners, with peach/pink across the top and right and
blue/violet along the left and bottom. The supplied reference is not a game asset.

The diffusion spans 58–104px depending on the viewport. Four static gradient
strips meet four radial corner sections with matching colors and falloff. Small
light blooms drift slowly inside the strips; no full-screen rotation, blur,
additional downloaded images or JavaScript animation loop is introduced.
The two upper corner masks reduce light along their diagonal while preserving
full strength at the straight-edge joins. This keeps the broad shape without
washing out Pip or the menu where the arc crosses the iPad portrait header.

The light remains decorative and tied to actual listening. Game input passes
through it, stopping listening hides it immediately, and reduced motion retains
static illumination. The central playfield stays clear. The existing game engine,
speech behavior, Pip reports and result scrolling are unchanged.

## Acceptance

- [x] All 52 host tests passed against the new shell (0 failed or skipped).
  The source contract now checks lifecycle, input and accessibility rather than
  requiring the previous four-strip rendering algorithm.
- [x] Eight isolated cases passed: Chromium and WebKit, 390x844 and 1366x768,
  each on dark and light backgrounds. Every edge visibly illuminates at 24px
  inward, while the sampled central playfield pixels remain unchanged. Edge
  clicks pass through. Stopping removes all light immediately; reduced motion
  removes every animation and produces identical successive screenshots.
- [x] Reviewed all ten new isolated screenshots, including later animation
  frames in both engines. Rounded corners have no visible seams, the center
  stays clear, and shallow color pools move without changing the rounded shape.
  The two old Chromium screenshots retain the comparison before this change.
- [x] Initial exported-game checks: all 12 cases passed in 1.7 minutes across
  desktop Chromium, iPhone WebKit and iPad WebKit. Covers live captions,
  permission denial/recovery, listening activation, pointer-through, 320x568
  portrait and 844x390 landscape layouts, visible static reduced-motion light,
  and actual hidden styles after mode exit.
- [x] All 12 exported-game cases passed again after the final corner correction
  (1.7 minutes, no failures or skips). The native iPad portrait screenshot
  confirms Pip's face and the menu lines remain clear under the softened arc.
- [ ] Production deployment, byte verification and focused smoke checks.

Isolated reference comparisons are retained under the ignored
`build/voice-pop-qa/soft-glow/` directory: `baseline-report.json`,
`aura-report.json`, `aura-preview.log`, the repeatable `aura-preview.cjs` probe
and before/after screenshots. The final 52 passing host tests are recorded in
`build/voice-pop-qa/soft-glow-final-host.log`. Integrated tests use recognition fixtures, not a physical
microphone; this change does not alter recognition or scoring.

The exported-game evidence is `build/voice-pop-qa/soft-glow-integrated.log`,
`soft-glow-integrated-tests.json` and `soft-glow-integrated/` screenshots.
The final corrected export uses `soft-glow-final-build.log`,
`soft-glow-final-integrated.log`, `soft-glow-final-integrated-tests.json` and
`soft-glow-final-integrated/` screenshots.

## Artifact

The export remains 13.24 MB compressed at startup, with 28 optional audio assets.
Pack verification found all 200 pronunciations and all 56 optional resource paths
without failures. The PCK, engine JavaScript and WebAssembly are byte-identical to
the previous release; the HTML contains the new CSS and decorative elements.

| File | SHA256 |
| --- | --- |
| `index.html` | `92df82aefca6db4f3a49fb88661d7cc86df5e6d6a505fd8e80fc6910819ebe2f` |
| `game-9651e6515167d63f.pck` | `9651e6515167d63fce4ca9e7b5d85ec432c6ca08d1c54fa70e7ecb55d49a456d` |
| `engine-c8ca3724771088b0.js` | `13ce7253b63b49b659e9eee7fbdcec1d9b4e3d5c8bd1b5460c4065bd0ea68b31` |
| `engine-c8ca3724771088b0.wasm` | `35116f68540ac41acf7d71ea457added91b5e960a9cca3e2acc72918eaf01277` |
