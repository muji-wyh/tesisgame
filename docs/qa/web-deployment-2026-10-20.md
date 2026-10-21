# Web deployment verification — 2026-10-20

The current workspace was built and published to
[the production site](https://gentle-forest-02ff42900.3.azurestaticapps.net/)
with the unmodified command `npm run deploy`. The second run exited with code 0.

## Reproduced failure and repair

The first run completed vocabulary packing but failed during Godot Web export.
The selected engine was `4.7.2.stable`, while the local template installation
contained only `4.7.stable`. Godot reported missing
`web_nothreads_debug.zip` and `web_nothreads_release.zip` for its exact version.
The deployment script stopped before contacting Azure.

The matching Web templates were installed from the
[official 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
The downloaded template archive matched the release's SHA-512 manifest. The
existing template installation was preserved. All maintained Web startup
patches also matched the official 4.7.2 JavaScript template.

`tools/check-web-templates.cjs` now asks the selected Godot editor for its actual
data directory and checks the Web preset's exact-version templates before
content preparation or game import. It handles custom templates and the
thread/extension variants, reports missing paths with repair instructions, and
does not download files automatically. The preflight is included in the build
receipt inputs. A failed preflight cannot leave an earlier build deployable.

## Build and production evidence

- Seven focused template checks passed, followed by a successful actual-engine
  preflight. The deployment/receipt/compression checks passed 35 tests, and the
  Web export/test-runner checks passed 45 tests.
- Native pack verification reported zero failures. It verified the Professional
  domain descriptor pin, all 101 deferred vocabulary bundles, required artwork
  and audio, and the excluded startup content.
- The successful receipt contains 13,341 source inputs and 117 output files,
  totaling 227,571,240 bytes. The deployment command verified that both source
  inputs and output files remained unchanged before uploading.
- Production engine: `engine-50b4911a4a706fb7`.
- Production game pack: `game-7ea05fe5dec5212c.pck.br`.
- An independent HTTPS check matched 107 production files to the local build by
  exact SHA-256 and byte length: HTML, all four engine resources, the core pack,
  and every vocabulary bundle. It also checked cache headers, WASM MIME type,
  and Brotli encoding for the packs.

The 200 incomplete Professional modules remain unavailable. No loose
Professional media was published because no module meets the existing release
gates. The source-level morphology and art work remains available for continued
review; deployment does not grant curriculum or specialist approval.

## Browser verification and limits

The targeted Playwright run completed with 18 passing scenarios, zero retries
and exit code 0, using one worker. Nine scenarios ran in desktop Chromium and
nine in Windows WebKit with an iPhone 13 device profile:

- Eight real-engine production scenarios covered both learning paths, all 20
  searchable careers, clearing unmatched queries, automatic career palettes,
  unavailable-module gates and the browser text-input bridge. Browsing
  Professional metadata did not request deferred media.
- Ten maintained-shell scenarios used controlled engine stubs to verify slow
  loading and four startup failure stages. Slow loading hides Retry, preserves
  focus and keeps the loading toy usable. Actual startup failures expose Retry.
  These are shell regression checks, not live network-failure observations.
- Production Chromium screenshots were visually inspected at 320 x 568 and
  1280 x 800. The fixed-size initial WebKit page at 390 x 664 also rendered
  correctly and was visually inspected.

The WebKit learning-path screenshots captured after live viewport resizing are
blank. A fresh paired page/raw-canvas diagnostic reproduced the existing
[Windows WebKit presentation limitation](2026-10-15-webkit-resize.md) on the
current production export and on an independent WebGL 2 canvas:

| Sample | Initial page / raw canvas colors | After 320 x 568 resize | After 390 x 844 resize |
| --- | --- | --- | --- |
| Production, WebKit 26.6 | 82 / 254 | 1 / 241 | 1 / 253 |
| Independent WebGL 2, WebKit 26.6 | 16 / 16 | 1 / 16 | 1 / 16 |
| Independent WebGL 2, Chromium 153.0.8010.12 | 16 / 16 | 16 / 16 | 16 / 16 |

All samples used Playwright 1.63.0 on Windows. Drawing buffers and viewports
matched the resized canvas, with no context loss, WebGL error or page error.
An additional 3.1 seconds did not restore WebKit presentation. The production
page and raw captures were visually compared. The independent canvas uses no
game code, Godot, assets or network requests.

The separate pixel diagnostic deliberately exited with code 1 for blank
composed output; it is not counted among the 18 passing functional scenarios.
Those functional assertions do not establish visual acceptance after resizing.
Physical iPhone/iPad Safari was not tested. No production workaround was added
for this Windows browser-runtime limitation.

Local command logs, browser results and captures, canvas diagnostic reports,
the official checksum manifest, an immutable copy of the build receipt, and
the production verification JSON are retained under
`build/deployment-20261020-dfce08a66b744d48af492dbfcaa0f13b/`. That directory is
ignored build evidence. This deployment did not create a Git commit or push.
