# Startup responsiveness

The reported symptom was an online pause around 50% with an unresponsive loading
chest; the user confirmed local and online were compared on the same device and
browser. Earlier progress-animation fixes did not remove synchronous startup work.

The user subsequently corrected that comparison: Canary stalls while ordinary
Chrome does not. The installed-channel investigation and compiled-cache repair
are recorded in [the Canary startup report](2026-09-10-canary-startup.md).

## Reproduction and diagnosis

- A real Chromium engine run reproduced a 5,083 ms main-thread task with 4x CPU
  throttling. A separate empty-save run froze at 50% for 4,767 ms and delayed a
  real mouse click by 4,711 ms.
- Fresh local and production contexts had approximately 912/945 ms maximum
  tasks without CPU throttling. Actual GET responses had matching engine bytes,
  correct WASM MIME and Brotli encoding. An old already-open tab was not treated
  as evidence of a stale deployment.
- Empty and full-medal save timing ranges overlapped. Saved medals add work, but
  are not an established explanation for the user's local/online difference.
- Web phase markers put about 2.23 seconds before game UI `_ready()` at 4x CPU.
  Splitting `_ready()` alone left a 2.9-second task. Godot compiles the transitive
  GDScript preloads synchronously; imported game pictures are already raster
  textures, so this was not runtime SVG parsing.

## Change

The Web entry scene loads and retains scripts in dependency order across frames,
then enters the existing main scene. UI initialization yields between complete
batches. Processing remains disabled while the UI is incomplete, then the
existing paused-tree reveal callback restores input. Native startup and save
locations are unchanged.

Hidden adventure previews and medal thumbnails load when opened. Controls,
navigation and saved counts still exist immediately. Runtime setup starts only
after 20/50/80/98% have been painted, and late download callbacks cannot reset this
final stage. Completion still requires the real game-ready callback.

The core Godot initialization remains synchronous: the bootstrap experiment
reduced the longest task to about 417 ms normally and 1.65 seconds at 4x CPU.
The regression explicitly bounds this remaining cost and keeps it at 98%; it
does not claim an interruptible engine or zero input latency.

## Regression evidence

Before fixes, the real-engine responsiveness test failed at 5,083 ms, the runtime
gate test started at 0%, the late-total test remained stuck, and hidden-art tests
loaded pictures prematurely. Each behavior has a runnable regression in the
browser loading tests or native adventure/collection tests.

Raw timing probes and traces are under ignored `build/qa-online-stall`,
`build/profile-save-startup-reports`, `build/qa-startup-red`, and
`build/qa-gate-late-red`.

Full `npm test` exited 0: 23 Godot suites / 11,921 checks passed, plus 94 Node
checks. One Node check was skipped because its external source asset package is
not available; imported-file and parser coverage passed. The Web build verified
140 word pronunciations and 56 optional paths with no failures.

Release HTML SHA256:
`1c2e96122e5b379968453be5fef7d2012ebb530fa7e667376b541cd613fea141`.
Game pack: `game-06d1f7bfbcd93d2d.pck`.

Browser verification against the completed export passed 135 cases across
desktop Chromium, iPhone WebKit and iPad WebKit; 12 Chromium-only CDP/input cases
were skipped on WebKit. Loading, actual engine failures, storage recovery,
adventure pictures and reward scrolling were included. Both 1x and 4x CPU
responsiveness budgets passed. Screenshots were inspected for the game,
adventure cards and Medals. Evidence: `build/qa-startup-final` and
`build/startup-browser-suite.log`.
