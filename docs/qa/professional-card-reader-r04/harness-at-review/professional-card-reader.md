# Card-reader caller capture

`tools/capture-professional-card-reader.gd` captures the current app's real Match
and Memory callers with an in-memory synthetic module. It does not install the
candidate image, change a production review flag, or unblock Retail module03.
The source contract explicitly checks that all six real practice modes still
reject that module with `content_pending`.

The exact acquired artwork is FreeSVG 206301, published by
publicdomainvectors.org as Public Domain with a CC0 1.0 link. No individual
artwork creator is confirmed. It is a static SVG with no animation. The fixture
uses its unchanged 512 by 433 PNG derivative; source, license, acquisition and
earlier scoped AI review records remain in the preserved local build inputs.
Those inputs are required and are not recreated by this tool.

Run from the primary checkout with a private APPDATA directory, preserving the
inherited LOCALAPPDATA. For example, set APPDATA to the absolute path of
`build/professional-english/card-reader-review-20261020/user-data`. Import and
check the script in that environment before the non-headless capture:

```powershell
node tools/run-godot.cjs --headless --path . --import --audio-driver Dummy
node tools/run-godot.cjs --headless --path . --check-only --script res://tools/capture-professional-card-reader.gd
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --script res://tools/capture-professional-card-reader.gd -- --results-dir=res://build/professional-english/card-reader-review-20261020/captures-r01 --private-user-root=res://build/professional-english/card-reader-review-20261020/user-data
```

The tool verifies the actual Godot user-data directory is inside the supplied
private build root before instantiating the app. It refuses an existing results
directory; use a new run suffix for a retry and preserve failed logs and output.
Current runtime and content hashes are recorded before capture and rechecked
after every mode and viewport. Historical source snapshots and completed
transaction wrappers are neither changed nor executed.

The expected output is 32 full-board PNGs and `report.json`, covering 320 by 568,
390 by 844, 844 by 390, and 1280 by 800. At each size, Match captures unmatched,
selected reader, reader-focused matches, and register-focused matches. Memory
captures backs, the real first peek, selected reader, and three matched pairs.
The Match deal is not reordered. The images remain fully opaque through the
actual callers, with the real pair fills, badges, labels and focus behavior.

The report checks actual layout bounds, contain-fit, media identity, cache
leases, and teardown. Pixel checks require an independently decoded source
texture to preserve exact RGBA bytes before rendering, then compare the real
loaded texture's post-render pixels to that source texture after the same
renderer path. Both comparisons are exact, with no tolerance or alpha
normalization. The source and post-render hashes are recorded separately:
ANGLE's software driver reproducibly changes some reference PNG channels by
one level during post-render readback. Temporary reference views are removed
before any board capture. Muted sessions and Dummy audio
preserve the five existing recordings without providing listening acceptance.
Successful technical checks still require inspection of the actual PNGs. This
matrix does not claim exhaustive pair-lane coverage, human recognition, final
exercise suitability, physical-device acceptance, or course readiness.
