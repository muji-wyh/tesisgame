# Startup stuck after download

The user reported a permanent stop at `Starting game...`, with the download
complete and the loading screen still displayed. This report is separate from
the previously measured short initialization pause.

## Reproduced defects

The unmodified Godot 4.7.1 Web wrapper loses promise rejections in two places:
the custom WebAssembly instantiation callback and the nested `Engine.init`
load/module/filesystem chain. Injecting an ordinary `Error` or `RangeError`
at streaming or fallback instantiation leaves the actual `startGame` promise
pending. A rejected `initFS` promise has the same result. The existing global
handler recognizes some WebAssembly errors, but misses these failures.

Separately, another tab holding a version 20 `/userfs` connection prevents the
engine's version 21 upgrade. IndexedDB emits `blocked`; the generated runtime
has no handler. A real two-tab reproduction remained unready after 16 seconds
and started as soon as the older connection closed. Main-thread heartbeats and
treasure clicks continued during this wait.

The five initial browser regressions all failed against the prior export,
showing `Starting game...` instead of recovery. The ordinary IndexedDB
`SecurityError` control still starts successfully: this is an existing supported
in-memory filesystem fallback, distinct from an upgrade blocked by another tab.

## Repair

The export packaging step repairs the pinned engine's promise propagation before
fingerprinting and compression. Template mismatches stop packaging so an engine
upgrade cannot silently omit the repair. Blocked storage upgrades stop startup
with an explanation and Retry; they do not run against an empty replacement
filesystem. Pending upgrades and late database connections are cleaned up.

The existing Godot engine, game content and save migration remain in place.
The browser regression seeds an actual old filesystem medal record, verifies
that failed startup does not replace it with a new browser save, then closes
the blocking tab and retries. Its two earned pieces must migrate successfully.

## Scope and remaining uncertainty

The user confirmed that the freeze was in a local preview. Its exact browser
tab could not be inspected: the in-app browser tool reports
`Codex auth token is unavailable`. That tool failure does not explain the game
freeze. The defects above are reproduced failure paths, not proof of which
condition occurred in that tab. In particular, the reproduced waits leave the
browser event loop responsive; they do not reproduce a permanently blocked
renderer thread.

Seventeen browser save variants reached game readiness, including corrupt,
legacy and unavailable local storage. Eight native startup signal combinations
passed forty checks. An independent desktop browser opened the current production
game successfully using NVIDIA T1000 / ANGLE D3D11.

Port 4173 had no listener when checked; port 4181 served the working checkout.
The main checkout's old export contained `game-71522da7333b637e.pck`, while the
current game pack is `game-b419d5752e4de9b2.pck`. The old export also started
successfully in a separate Chrome profile (3.858 seconds), so the stale local
artifact is not established as the cause of the freeze.

## Evidence

- `tests/browser/startup.spec.cjs`: actual exported engine failures, two-tab
  storage recovery with reward migration, and the unavailable IndexedDB control.
- `build/qa-startup-red`: five failing pre-fix browser regressions and screenshots.
- `build/qa-startup-rejections`: instrumented real-engine fault injection,
  promise outcomes, main-thread heartbeats and screenshots.

## Verification results

- `npm run build:web` passed, including the packed resources check: all 140 word
  pronunciations and 56 optional paths present, zero failures.
- `node --test tests/web-export.test.cjs tests/deployment.test.cjs`: 17 passed.
- Loading regressions: 78 passed across Chromium and iPhone/iPad WebKit profiles.
- Final startup suite: 18 passed across those same profiles in 28.4 seconds.
  The initial migration fixture used `/userfs/medals.cfg`; a real runtime probe
  established the correct path, `/userfs/godot/app_userdata/Word Buddies/medals.cfg`.
  Correcting the fixture required no product or artifact change. Blocked startup
  and subsequent retry preserve and migrate both saved medal pieces.
- Chrome 152.0.7977.83, launched with a temporary profile and native defaults:
  NVIDIA T1000 / ANGLE D3D11, readiness at 3.796 seconds, still rendering at
  15 seconds. Actual Next, Rewards and Back clicks preserve the second card.
  No console or page errors. Screenshots of desktop play, phone recovery and
  the recovered phone game were inspected.
- Independent source review found no blockers; template drift, success-path
  callbacks, LF/CRLF handling and late IndexedDB events were checked.

The final startup screenshots are in `build/qa-startup-final`; the hardware
browser evidence is in `build/headed-patched-export-audit/chrome-direct`.
WebKit profiles run on Windows, not physical Apple devices. Cleanup of a test
profile directory was denied by automatic review; ignored diagnostic files
were retained and the test browser processes were closed.

Release artifact:

- Engine: `engine-27986f74840ebada` (new cache key for the repaired wrapper).
- Game: `game-b419d5752e4de9b2.pck` (unchanged game content).
- HTML SHA256: `266cef3ea2f73512bd605b030d147c4459c27ffced124bbf33a37f2666686005`.
- Pack SHA256: `b419d5752e4de9b2e652adefb859a38877252066f813426cd6b623bb3343d7b1`.
