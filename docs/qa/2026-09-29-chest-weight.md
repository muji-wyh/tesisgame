# Chest weight and synchronized release

## Rhythm 6 baseline

The performance still lasts five seconds: a 1.2-second confirmation hold and a
3.8-second automatic opening. Five hold beats lead into fifteen opening beats,
with a short quiet breath before the lock, lid, release sound and themed flash.
The body rocks around its feet, the contact shadow resists lateral motion, and
the lid retains a dark thickness edge while rotating.

## Automated and recorded evidence

- Four native Godot suites passed 3,793 assertions, including interruption,
  stale-beat coalescing, rigid-body motion, flash timing, reduced motion and
  once-only reward persistence. Twenty-four theme/viewport cases measured
  growing body recoil without requiring a large flat translation.
- The audio assets and Web export checks passed 34 Node tests. The final Web
  export validated all 282 optional resource paths and its 13.90 MB startup.
- Eight final 640 x 640 engine recordings contain the actual mixed audio. The
  early-to-late buildup rises by 10.4-12.0 dB; release rises another 5.6-6.6 dB.
  Recorded peaks remain between -6.9 and -5.2 dBFS. Visual inspection found no
  clipping or art-fit jumps in the reviewed grids.
- Focused browser scenarios cover earned opening/cancellation, background
  completion, missing-sample fallback and once-only saving in Chromium, plus
  earned opening/cancellation and fallback in the iPhone WebKit layout.

The browser timing environment needs an explicit distinction from device tests.
This Windows host exposes virtual display adapters without a physical GPU.
Periodic trace screenshots caused Chromium to miss a dense late beat; removing
that recording overhead passed the unchanged strict assertions. The completed
sequence measured 5.158 seconds, with WebAudio scheduling 6.2, 5.8 and 3.9 ms
after the unlock, release and settle cues respectively.

At DPR 3, screenshot-free WebKit still rendered 1170 x 1992 pixels with long
frame gaps, coalescing late beats and sometimes delivering unlock and release
on the same frame. The same phone layout at DPR 1 passed every timing assertion.
The chest timing spec therefore uses DPR 1 and disables passive trace screenshots;
it retains explicit screenshots, trace snapshots and strict beat counts. This is
a functional timing check, not evidence of Retina-device performance. Product
code still coalesces stale beats after a genuine stall instead of replaying a
backlog. Fallback coverage also passed at the original DPR 3.

## Remaining device checks

Actual macOS Safari, Android Chrome and iPhone/iPad Safari frame rate and audible
latency remain unverified. Windows WebKit does not provide WebAudio in this
environment. JavaScript scheduling offsets do not measure display scanout,
speakers or Bluetooth latency. Fixed-rate recordings do not establish mobile
performance, and waveform measurements do not replace a human listening review.

Generated evidence remains under ignored `build/` paths: `chest-weight-native.log`,
`chest-weight-node.log`, `chest-weight-build.log`, `chest-feel/`,
`chest-sync-browser/`, `chest-weight-no-screencast/` and
`chest-weight-webkit-dpr1/`.

## Rhythm 7: continuous rise and wider release

The five-second sequence now carries its final roll into a continuous 220 ms
rise. Body and lid pressure remain engaged until release. Three material strike
textures add detail and brightness as the cadence accelerates, while the body
pitch stays grounded. The release combines a broader theme-colored bloom, seven
upper rays and one expanding wave; the small white core preserves the chest
silhouette. Progress stars fade within 160 ms of release.

Eight fresh 640 x 640 engine recordings retain the actual game mix. Their
early-to-late buildup rises by 11.5-12.7 dB. The final rise stays within 0.6-2.0 dB
of the late roll, followed by a 6.7-7.7 dB release increase. Mixed peaks range from
-7.8 to -6.8 dBFS. All recordings complete the accepted hold and opening in
5.033 seconds, including two frames of capture quantization. These measurements
check continuity and headroom; they do not establish subjective sound quality.

Visual review of the spring, autumn, space and candy stage grids found a wider
theme bloom with readable chest surfaces, held strain through the final rise,
and no clipping or fit-scale jumps. The existing real-device and listening
limitations above still apply.

The updated assets, generator and Web packaging passed 40 Node checks. The
native feel and audio suites passed 1,241 and 1,966 assertions respectively.
The flow suite passed 314 assertions, including a long frame that suppresses
the stale release accent: physical release still stops the pressure bed without
replaying sound or saving the reward early. The unchanged reveal suite passed
602 assertions, for 4,123 native assertions across the four suites.
The final Web export validated all 314 optional resource paths and a 13.89 MB
compressed startup. The complete chest bank has 88 cues loaded on demand.
All five focused browser cases passed on that export: earned opening and
cancellation, background completion and missing-sample fallback in Chromium,
plus earned opening/cancellation and fallback in the iPhone WebKit layout.
These used the same DPR 1 and screenshot-free passive trace settings described
above. Finalized desktop and phone screenshots were reviewed for clipping and
stable chest scale; physical-device sound and frame pacing remain unverified.
Fresh evidence is in `build/chest-flow-*.log`, `build/chest-flow-browser/` and
`build/chest-feel/`.
