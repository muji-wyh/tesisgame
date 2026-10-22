# Jelly Words interaction and cadence verification — 2026-10-22

This iteration completes the queued Jelly Words work on the existing
`users/yoki/jelly-auto-cadence` branch:

- Five columns and eight rows, with square jellies and a five-slot supply tray.
- Auto merge starts independent flights every 200 ms, with 250 ms travel;
  automatic collection starts one pickup every 200 ms.
- Chest acquisition and upgrade flights follow straight paths with vertical
  Y-axis rotation.
- Higher-level word reveals use expanding firework blossoms, with additional
  blooms, sparks and trails at higher levels.
- Selected-word guidance uses stronger violet contours, an acquired glow and
  gold sparkles. Merged words highlight the same word across levels, including
  Lv9; actual upgrades still require equal levels below Lv9.
- Valid matches become actionable within a small margin beyond the painted
  contour. Nonmatches retain the original overlap threshold.
- A manual merging pair follows the pointer. Its result inherits that pointer
  when the merge completes; early release resolves the accepted pair once and
  applies ordinary drop rules. Cancellation and pauses release ownership.

All visual material reuses acquired production assets. Source, creator, license
and animation records remain in the Jelly Words and level-feedback asset docs.

## Native and rendered evidence

The dedicated interaction suite passes 937 checks across desktop and phone
dimensions with normal and reduced motion. It covers cross-level guidance,
early match distance, natural and early fusion handoff, chained upgrades,
cancellation, pauses, stopping, reconfiguration and taps without collection.
The full view suite passes 19,482 assertions, authored drag passes 988,093,
and the model passes 111,961. Reveal checks pass 9,712; chest flight and
celebration checks pass 8,313 in total. The Web packaging, deployment, receipt
and template suites pass 80 Node tests.

Two settlement fixtures still selected word pairs by concatenating display
strings. They now use the production merge resolver and collect only complete
words. Their reruns pass 688 and 633 checks, respectively.

Native phone and landscape highlight captures were visually inspected.
The phone capture shows matching Lv2, Lv4 and Lv9 words together. A 48-frame
phone fusion-drag capture and its contact sheet were inspected for continuity
between the joining artwork and the held result. Firework captures include
Lv4 and Lv9 and a phone layout. These are native renders, not physical-device
or audio-audition evidence.

Evidence is retained in the ignored `build/qa/iter4/` directory, including
native logs, before/after highlights, `merge-drag.mp4` and its contact sheet.
Final firework captures are under `build/jelly-reveal-feedback/`.

## Browser and release build

Six distinct scenarios passed: Auto merge cadence, five-column layout and
collection persistence, and overlapping word reveals with one pronunciation,
each in desktop Chromium and Pixel 7 Chromium emulation. The first run passed
four scenarios; the two Android failures passed their focused rerun.

The Android layout scenario exhausted its original 180-second total budget
while beginning collection checks. Its budget is now 300 seconds, and its
viewport matrix covers phone portrait and landscape while desktop retains the
large-screen and tablet sizes. The successful Android run took 4.1 minutes.
The first reveal run started its second card 3.1 seconds after the first,
outside the first reading window. Mobile duplicate taps now use Chromium's
native gesture queue, and evidence images are encoded at their CSS display
size. All overlap, duplicate-input, reward and pronunciation assertions remain.
The reveal rerun passed in 2.2 minutes. These are software browser runs, not
physical Android-device timings.

The Web build completed with zero pack-verification failures. Its core startup
download is 50.04 MB, with ten on-demand age packs. The immutable receipt copy
is `build/qa/iter4/web-build.json`; browser logs and artifacts are in that same
evidence directory. Production verification uses `verify-production.cjs` there
to compare the deployed entry point, engine, core pack and all vocabulary
bundles against this receipt, including byte lengths, SHA-256 and response
headers. Deployment uses the existing receipt-validated `-SkipBuild` path.

## Existing failures outside this interaction change

- `growth_morphology_tests.gd`: nine image-eligibility expectations fail for
  compare, investigate, suggest, explore, estimate, connect, include, reflect
  and adapt. The test's eight-script dependency closure and vocabulary inputs
  are unchanged from HEAD; evidence is in `baseline-morphology.txt`.
- `jelly_finish_confirmation_tests.gd`: two controller Back expectations fail,
  once in each Jelly mode. The confirmation input handler, input mappings and
  regression test are unchanged from HEAD. The raw Back button is consumed
  by the confirmation guard. Evidence is in `baseline-finish.txt` and the
  native test log.

These failures are reported separately and are not counted as passing checks.
