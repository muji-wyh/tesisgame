# Chest rhythm revision - 2026-09-29

The full standard opening now takes 10.5 seconds: a 1.2-second confirmation
hold, followed by 9.3 seconds of automatic buildup and release. Letting go before
confirmation cancels; letting go afterward does not interrupt the performance.
Reduced motion keeps the short confirmation and shows the saved result directly.

Progress and three stars span the elapsed time from the initial press to the
lid-release beat. The lid stays closed while fourteen material pulses accelerate
from 1.10-second spacing to 160 ms. Local pressure, light and material-loop
intensity rise with the rhythm. Background music recedes, then the strained pose
and physical sounds stop for 400 ms before unlocking. The original theme-specific
lid motion follows, retaining its quick release, rebound and settling.

| Event | From the initial press |
| --- | --- |
| Automatic buildup begins | 1.20 s |
| Quiet breath begins | 8.42 s |
| Lock releases | 8.82 s |
| Lid and light release | 9.02 s |
| Material settles | 9.65 s |
| Opening completes and reward save is attempted | 10.50 s |

These are animation-clock targets. A stalled renderer or failed persistence can
delay the visible saved reward. Progress reaches 100% at the actual lid release;
it does not sit at 100% throughout the buildup. The success accent still waits
for a successful save. No assets, reward rules or save formats were changed.

## Verification

- Native chest coverage passed 2,364 assertions: reveal 866, feel 435, audio 944
  and real-scene flow 119. Coverage includes confirmation cancellation, automatic
  completion, accelerating beat intervals, the complete still/quiet breath,
  monotonic progress, sealed cavity before release and all eight motion profiles.
- Boundary regressions cover silent physical completion when saving fails in
  reduced motion, enabling reduced motion during buildup, retained reward retry,
  hidden progress in Pip's room, duplicate completion and skipped old sounds.
  A 230 ms stall crossing two fast pulses plays only the most recent one.
- The focused Node asset/audio/web-export contracts passed 37 tests. Existing
  72 theme samples are reused; the longer rhythm adds no sound downloads.
- The affected core suite passed 1,501 assertions and the reward-scene suite
  passed 47. The Web export is `game-7fb0af2c4f4f4858.pck`, with a 13.87 MB startup
  download and the existing 141 optional audio assets. The pack verifier found
  all 200 bundled words and confirmed 282 optional source/import paths absent.
- All eight native recordings passed the capture checks: 640 x 640, 60 fps,
  13 seconds each, with the engine's stereo audio. Every theme measured
  10.517 seconds from the confirmed press to the reward, within one frame of
  the target. Fourteen pulses, three milestones and release deadlines passed.
  The isolated chest soundtrack's quiet-breath slice measured -91 dBFS in every
  theme, more than 6 dB below both the preceding tension and release slices.
- Visual inspection of the eight stage grids found no clipping, abrupt art-fit
  changes or exposed source fragments. The lid stays shut during buildup;
  progress continues through 23%, 74%, 94% and then 100% at release.
- Five focused browser cases passed: standard opening on desktop Chromium,
  iPhone WebKit and iPad WebKit, plus desktop reduced motion and invalid optional
  samples. They verify release-after-confirmation, cancellation, all fourteen
  pulse ordinals, faster late cadence, the quiet gap, continuous progress and
  one saved reward. Chromium also records cue/audio scheduling for inspection.
- Production deployment of the same pack passed startup availability checks and
  all 72 theme-sample hash/resource checks. One complete production opening
  passed: press-to-reward audio was 10.668 seconds and quiet-cue-to-unlock was
  421.3 ms. Cue-to-WebAudio scheduling offsets were 4.5 ms for unlock, 50.9 ms
  for release and 2.9 ms for settle. The release observation slightly exceeds
  the 50 ms target; this check does not assert that latency target or establish
  physical audio/display synchronization.

Logs and generated previews are kept under ignored `build/` paths. Relevant logs
include `chest-rhythm-tests.log`, `chest-rhythm-feel-final.log`,
`chest-rhythm-audio.log`, `chest-rhythm-flow-final.log`, `chest-rhythm-node.log`,
`chest-rhythm-browser-desktop.log`, `chest-rhythm-browser-mobile.log` and
`chest-rhythm-build.log`. Native recordings, timing/audio reports and the
preview gallery are in `build/chest-feel/`; capture output is in
`chest-rhythm-capture.log`. Production evidence is in
`chest-rhythm-production.log`, `chest-rhythm-production-smoke.log` and
`chest-production-smoke/report.json`.

## Validation limits

Native Movie Maker audio and browser scheduling observations can verify timing
and a quiet gap, but do not establish human-perceived suspense, speaker latency
or mobile frame rate. Physical macOS Safari, Android Chrome and iPhone/iPad
Safari listening and performance checks remain outstanding. Windows Playwright
WebKit covers visual/input/reward behavior; it has no WebAudio in this environment.
