# Five-second chest opening - 2026-09-29

The complete opening now takes 5 seconds: a 1.2-second confirmation hold,
2 seconds of automatic buildup and the existing 1.8-second physical opening.
Seven increasingly close material beats replace the former fourteen beats.
The final quiet breath remains 400 ms; the release occurs 3.52 seconds after
the press. Cancellation, reduced motion, saved rewards and toy unlocks retain
their existing behavior. Retired collectible presentation remains removed.

The first progress star now crosses its threshold just before confirmation.
The handoff to automatic opening preserves that star and consumes its cue so
it cannot sound twice. A programmatic opening without a hold still consumes
the first milestone at the start of its timeline.

## Verification

- Editor parsing passed. Four native suites passed 2,217 assertions: reveal
  866, feel 397, audio 832 and charge flow 122. Coverage includes all eight
  themes, motion bounds, timing, accelerating pulses, the quiet breath,
  hold-to-opening star continuity, cancellation, background settlement,
  reduced motion and save retry.
- Autumn, Space and Candy were rendered at 60 fps with engine audio. All
  three measured 5.033 seconds from the accepted press to reward, including
  frame rounding at both transitions. Each emitted seven pulses and three
  distinct stars. The isolated 200 ms quiet slice measured -91 dBFS.
- Visual inspection of their six-stage grids found stable fitting and
  contained lids, crystal parts and progress labels. The current gallery
  includes only these three recordings with `rhythm_version: 3`; older
  recordings are historical evidence.
- The Web build passed startup verification: 200 bundled pronunciations,
  282 optional paths checked, 13.87 MB startup. The exported pack is
  `game-b24ebf591e26d555.pck`.
- Two focused browser cases passed: desktop Chromium measured 5.110 seconds
  from accepted press to saved result; iPhone WebKit measured 5.172 seconds.
  Both verified progress, unique stars, accelerating beats and persistence.
  Desktop audio started 3.7 ms after the unlock cue, 44.1 ms after release and
  2.8 ms after settle. The simulated iPhone runtime did not expose WebAudio;
  its result verifies visual/input/save behavior, not physical Safari audio.

Generated logs, recordings and browser evidence remain in ignored `build/`
paths. Native and capture logs use `chest-five-second-*.log`; parse and build
logs use `chest-five-seconds-*.log`. Physical Safari/mobile performance,
speaker latency and human listening impressions have not been revalidated
for this timing adjustment.
