# Direct play with Pip in Rewards

Pip's room now accepts strokes, pokes, toy throws and floor destinations.
Stroking gives a closed-eye cuddle and hearts; a short tap gives a surprised
tickle response. Nearby destinations use a walk, distant ones a run, and a
new floor tap redirects Pip. Dragging the equipped toy shows the held object,
an aim marker and an arcing flight. Pip catches nearby throws or retrieves
misses, then returns the toy for another throw. Other earned toys retain
their noun, artwork and appropriate outcome text.

The larger scene owns gestures started inside it. Catalog dragging and
wheel scrolling remain available outside it. Pet, Poke, Toss and Call also
work through keyboard/controller focus. The original three-step toy actions
remain available by clicking the toy or its action button.

Movement, affection and flights are transient; no save version or reward
rules changed. Locked previews cannot be thrown. Touch cancellation, late
release, hiding, focus loss, equipment changes and resizing clear held input.
Reduced motion uses stable immediate outcomes. The shared header/preview
mascot retains its existing behavior.

## Verification

The initial scene regression failed both expected checks: a real floor tap
did not move Pip and the direct-interaction playground was absent. The
mascot API regression also failed before implementation. Logs are in
`build/pip-playground-native-red.log` and `build/pip-mascot-red.log`.

The final full `npm test` passed 28 native suites and 18,830 checks/assertions,
plus 100 Node tests. One pre-existing check skips when its external chest
source pack is unavailable. Log: `build/pip-final-native.log`.
After the last pointer-down adjustment, the 89-check playground suite passed
again (`build/pip-last-input-check.log`). It exercises real mouse and touch
input, canceled touches, single-action release, movement, catch/fetch,
zero-distance retrieval at a floor boundary, old toy stage progression,
relocated toy bounds, keyboard focus, save stability and interruption.

Review and screenshot feedback caught and resolved overlapping hit targets,
balls hidden behind Pip, reduced-motion overlap, resetting a toy sequence
on pointer-down, stale toy origins, and focus scrolling before room layout
had settled. Independent review found no remaining blocking issue in the
product changes or the updated regression assertions.

The final Web build passed, including 140 word pronunciations and 56 optional
path checks. Startup transfer is 12.13 MB, with 28 on-demand audio assets.
The tested export was copied to a separate local preview stage; all 71 files
were checked by SHA256 before activation.

- Pack: `game-8c26b6f494d4ef0f.pck`
- Pack SHA256: `8c26b6f494d4ef0f2dff6154a06261d5a6144ca6c5824694d88646524c92f9d5`
- HTML SHA256: `fdbb7c685d470b864020ccda6d928dc8a68b2412bf420aa44beafc94b5e586d2`

Browser checks use the exported canvas and actual pointer/keyboard input.
Chromium covers mouse gestures and CDP touch strokes; WebKit covers touch
taps and mouse drags in an iPhone viewport. These are browser emulation
checks, not a claim of physical iPhone touch-drag testing.

Inspected final-export screenshots show Pip's closed eyes and hearts after
a stroke, the caught ball in front of Pip, and separate Pip/ball resting
positions with all four shortcuts reachable at 320px. The new scene keeps
its title fixed during a gesture, and screenshot comparisons check visible
movement as well as the status text. Ball comparisons allow a one CSS-pixel
alignment shift while comparing the entire original patch at the same 8%
threshold; a missing ball differs by 47%, so absence still fails.

The final combined browser run passed **34/34**, with no failures, retries,
flaky cases or skips (460.0 seconds). Each browser passed four new playground
cases and thirteen affected room, gift, mascot and word-sticker regressions.
Command: `npx playwright test --config build/pip-playground/playwright.final.cjs`.
Report: `build/pip-playground/final-report.json`; screenshots and traces:
`build/pip-playground/final-results/`.

The old room helpers now focus and scroll the expanded controls before
real taps; they wait for rendering between Tab presses instead of using
stale geometry. The Medals focus path includes the existing Words tab.
Original storage, locked-preview, three-stage play and gesture assertions
remain in place. The final run verifies those behaviors on both browsers.

## Release

Implementation commit `913c619` was fast-forwarded to `main` and pushed to
`origin/main`. `npm run deploy -- -SkipBuild` completed successfully against
the configured Azure Static Web App using the exact tested export.

`node build/verify-ui-release.cjs` fetched both production and local preview
over HTTP and confirmed their HTML and pack SHA256 values match those above:

- Production: https://gentle-forest-02ff42900.3.azurestaticapps.net/
- Local preview: http://127.0.0.1:4173/

The previous local preview is preserved at
`D:/uwork/tesisgame/build/web-before-pip-8106acc9`.
All older preview backups and the unrelated untracked directory were retained.

The focused production browser run passed **8/8** in 69.1 seconds, with
four cases per browser and no failures, retries, flaky cases or skips.
It used `PLAYGROUND_BASE_URL` set to the production URL and
`npx playwright test --config build/pip-playground/playwright.live.cjs`.
Report: `build/pip-playground/live-report.json`; screenshots:
`build/pip-playground/live-results/`.

Production checks cover petting/poking, held and thrown balls, walking/running,
leaving during a gesture, catalog drag ownership, reduced-motion keyboard
shortcuts, unchanged saves and selection, visible canvas output, and no
page errors. Inspected live screenshots confirm the affection reaction,
held/caught ball, movement and separate resting positions at 320px.
