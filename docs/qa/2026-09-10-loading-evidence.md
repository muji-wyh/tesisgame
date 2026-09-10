# Loading and startup verification

## User-visible behavior

The loader reports received game-data bytes against a reliable total. Before a
total is available, and when received bytes exceed an unreliable total, the progress
bar is indeterminate. Elapsed time no longer advances a fabricated percentage.
At the user's request, the overall loading bar caps the download stage at 98%.
When all bytes arrive, it remains filled at 99%, with `Loading game...` and
`Getting ready to play...` visible throughout initialization. Only the game's
`ready()` callback reports 100% and hands input to the canvas. This supersedes
the empty, indeterminate startup bar recorded in the earlier measurements below.

After 16 seconds, a stalled startup offers `Try again` without moving focus away from
the loading toy. Synchronous engine failures, empty promise rejections and lost
graphics contexts show the existing retry screen. The first failure remains visible.
Graphics loss stops input and requests engine shutdown; retry reloads the game.

Lost pointer capture cancels chest dragging. Every direct tap on Pip produces a
visible text response, including with reduced motion, without awarding chest sparkles
or overwriting chest reactions when the chest itself animates Pip.

## Real Brotli transfer and progress measurement

A cold-cache Chromium run used the actual Godot export served from port 4181 with
Brotli enabled, 1,000,000 bytes/second download throughput (8 Mbps), and 40 ms latency.
Only the page's progress callback was instrumented; the real engine, Fetch responses,
WASM and game pack were used. Resource Timing supplied decoded body sizes, response
headers supplied encoded lengths, and the exported configuration supplied file sizes.

| Resource | Brotli content length | Browser decoded size | Configured file size |
| --- | ---: | ---: | ---: |
| `engine-2f56418648ba0140.wasm` | 7,094,628 | 39,513,091 | 39,513,091 |
| `game-b5b797de781821de.pck` | 3,744,455 | 4,535,920 | 4,535,920 |

Both responses were HTTP 200 with `Content-Encoding: br`. The 657 actual progress
callbacks consistently used a total of 44,049,011 decoded bytes; none exceeded it.
The last callback at 11,446.5 ms reported exactly 44,049,011 / 44,049,011 and the UI
showed `Starting game...` without a percentage. Host readiness arrived at 13,200.3 ms.
This verifies that Godot's received-byte count and the export's configured totals use
the same decoded units, even though the network transfer is compressed.

The measurement used the first unified export of this change. Later Pip feedback
and native UI fixes do not alter the progress code or binary byte accounting. The
final export regenerates its file-size configuration; its different pack hash is
recorded in the UI flow release report.

## Actual input and remaining initialization pause

The same run sent real Chromium mouse input to the chest approximately every 100 ms.
All 105 clicks received during download incremented the visible sparkle count, reaching
`105 sparkles`. Their maximum input-command round trip was 33 ms. The next input
straddled the transition into the game, after the loader relinquished its controls.

The PerformanceObserver long-task trace recorded a **1,746 ms synchronous main-thread
task** starting at 11,454.3 ms, immediately after download. The maximum mouse-command
round trip across that startup boundary was 1,924 ms. No uncaught page errors occurred.
These are measurements on this Windows test host, not guarantees for other devices.

The UI now distinguishes downloading from starting accurately. It does **not** make
Godot initialization free of pauses. The HTML toy cannot process input while the same
main thread is synchronously initializing the engine; this patch makes no claim of
continuous responsiveness during that interval and does not redesign the runtime.

## Regression checks

The loading suite covers pointer, keyboard and controller input; script and WASM delays;
download interruption; synchronous startup errors; unknown, known and cached progress;
reduced motion; focus; 320-pixel square layouts; and actual graphics loss followed by
retry and successful engine readiness.

New defect regressions failed before their fixes: eight startup/input cases, two byte
progress cases, and the repeated reduced-motion Pip response case. The initial focused
Chromium fixes passed 11/11 cases. The final Pip/slow-loading selection passed 9/9
across desktop Chromium, iPhone WebKit and iPad WebKit.

One initial WebKit test fixture held the deferred engine script indefinitely while
requesting a screenshot. Its behavioral assertions passed, but Playwright waited for
`document.fonts.ready` during capture and timed out. The stalled-download fixture now
loads the script and holds the engine-data promises instead. It preserves the 17-second,
retry, focus, interaction and layout assertions; all three device profiles passed.

The final loading matrix passed **78/78 cases in 2.1 minutes**: 26 each on desktop
Chromium, iPhone WebKit and iPad WebKit, with no retries and no skipped tests. All
three actual graphics-loss cases clicked `Try again`, reloaded successfully, hid the
loading overlay and restored canvas focus. Final screenshots of 60% download,
download-complete startup, the 320-pixel stalled layout and graphics recovery were
inspected without clipped controls or overlapping text.

## Commands and evidence

The shared server on port 4181 serves `build/web` with Brotli; the existing user preview
on port 4173 is preserved. The local `build/qa-ui.config.cjs` inherits the repository's
Playwright configuration, changes its base URL to 4181, and disables auto-starting a
second server.

```powershell
npx playwright test -c build/qa-ui.config.cjs tests/browser/loading.spec.cjs --output=build/qa-loader-matrix-final
node build/startup-progress-probe.cjs
```

Local diagnostic evidence (ignored build artifacts):

- `build/qa-real-startup/report.json`: all progress callbacks, encoded/decoded resource
  timings, input commands, handled clicks and long tasks.
- `build/startup-progress-probe.cjs`: the actual-engine measurement harness.
- `build/qa-loader-matrix-final`: progress, startup failure, stalled layout and graphics
  recovery screenshots from the final browser matrix.
- `build/qa-loader-red`, `build/qa-loader-progress-red`, `build/qa-pip-repeat-red`:
  failure evidence before implementation.

The iPhone and iPad entries are Playwright WebKit device profiles running on Windows,
not tests on physical Apple hardware. These startup checks do not supersede the
separate WebKit resize/compositor limitations documented in the Memory Garden report.

## Requested 98% / 99% loading hold

The user requested a filled progress bar while the engine prepares the game. The
download stage now stops at 98%; received-all-bytes changes the value to 99% and
keeps the loading label visible. This is overall startup progress, not a claim
that byte reception alone completes the game. Only the ready callback reaches
100%. Unknown totals and error recovery retain their existing behavior.

Two browser regressions failed before the change: the 98% cap was missing, and
real-engine initialization cleared the progress value. The updated loading
matrix passed 81 checks across Chromium and iPhone/iPad WebKit profiles; it
includes a 30-second hold, clickable treasure, visible retry and readiness.
Ten Node export checks passed. Phone screenshots were inspected. Evidence is in
`build/qa-progress-hold-red` and `build/qa-progress-hold-final`.

A fresh local profile measured download completion at 235.7 ms, a browser paint
at 236.34 ms, then synchronous engine startup from 245.3 to 1128.4 ms. The loading
state was already painted before initialization. No extra frame delay or engine
change was needed to keep 99% visible in that run. This does not establish the
cause of the user's longer wait or reduce the engine's initialization time.
Timing evidence is in `build/qa-startup-phase/report.json`.

`npm run build:web` passed. The exported-page initialization hold also passed
on all three browser profiles (`build/qa-progress-hold-export`), followed by
normal game readiness. HTML SHA256 is
`061a9f1ccbba7a56a4ccca160c6c7b3f7830d29066bea4edcbf145ccb0bfaabb`;
the game pack remains `game-b419d5752e4de9b2.pck` and the engine remains
`engine-27986f74840ebada`.

## Smooth progress after a fast or cached download

The displayed value now follows the received-byte target at up to 45 percentage
points per second, instead of jumping directly to 98% / 99%. The numeric label
and native progress bar use the same value. Each animation frame accounts for at
most 50 ms, so returning from a suspended or busy page cannot produce one large
catch-up jump. Reduced motion applies the target directly. Unknown totals cancel
the animation and stay indeterminate; errors also cancel it. The ready callback
still enters the game immediately, even halfway through the transition.

The cached-download regression failed against the previous shell: the first
displayed value was 0.99. Its replacement checks intermediate values, bounded
resume, the 99% hold and readiness. Existing cases now also exercise readiness,
failure and unknown-total cancellation during a pending animation. No engine
initialization or gameplay behavior changed.

The initial focused checks passed 12/12. One subsequent test invocation overlapped
export packaging and read its temporary `index` executable before fingerprinting;
the engine stub did not install. Final verification runs against the completed
export. The exported startup controller was compared with the maintained shell.
Evidence lives in `build/qa-smooth-progress-red`, `build/qa-smooth-progress-focused`
and `build/qa-smooth-progress-matrix`.

Final validation passed **84/84 browser cases** across desktop Chromium and the
iPhone/iPad WebKit profiles, including actual exported-engine readiness, plus
**17/17 Node export/deployment checks**. The Web export passed with 140 word
pronunciations and 56 optional paths checked. The intermediate phone screenshot
shows the bar and label together at 44%. Final HTML SHA256:
`353512c1ee199f832a2ce57b8cc63988cb8b51b8aea96408ad9dea58a6934493`.

## Requested 20 / 50 / 80 / 98 percent rhythm

This follow-up supersedes the constant-speed presentation above. Progress now
moves quickly between 20%, 50%, 80% and 98%, with a 140 ms rest at each milestone.
It still follows received data and holds at 98% until the real ready callback.
Early readiness finishes the remaining milestones, shows 100% briefly, then
reveals the game. Reduced motion uses discrete steps. Unknown totals, failures
and repeated ready callbacks preserve the appropriate loading state.

The Godot scene tree stays paused during the final presentation. Its retained
JavaScript callback resets controller state and resumes the tree at reveal.
Before this fix, the real-browser regression showed that pressing Y while the
loader covered the initialized game opened My rewards behind it. The corrected
case verifies that Y is ignored during loading and works after reveal. A throwing
reveal callback now shows retry instead of stranding the 100% screen; that
regression also failed before the catch was added.

Evidence: `build/qa-milestones-red`, `build/qa-milestones-reveal-red` and
`build/qa-milestones-final`. Screenshots cover 50%, 98% and the visible 100% state.
The exported progress and reveal controllers match the maintained shell. HTML
SHA256 is `93d90c049fbf6c2d0b2d8da322e1c66614332fa7bbaaddc6024c8da7fe867ad1`;
the game pack is `game-1d03eb0a735f61aa.pck`.

Final verification passed **96/96 browser cases** across Chromium and iPhone/iPad
WebKit profiles, **105 native Godot UI assertions**, and **17 Node export/deploy
checks**. The Web build verified 140 pronunciations and 56 optional paths without
failures. Both native browser input suppression during loading and restored
controller input after reveal passed on all three browser profiles.
