# Loading-page moves in Pip's Home

Pip's Home now starts the loading page's 5.28-second dance automatically,
raising each wing before swaying with planted toes. A tap immediately replaces
the dance with a jump, shy head scratch, or playful bonk. Every shuffled group
of three contains all three responses, with no adjacent repeat between groups.
Rapid taps replace the current response rather than queueing more animations.

Stroking, walking, dragging and throwing toys interrupt the dance, which resumes
after a short quiet beat. Grabbing a resting toy also clears a previous Pip tap
response immediately. The original touch target, outfits, saves and non-Home
idle schedule remain intact. Reduced motion uses three distinct static poses
and disables the automatic dance. Explicit tap gestures remain visible while a
previous word finishes playing.

Keyboard focus reveals 16 logical pixels above Pip's input slot for the jump.
Bonk stars are inset so they stay on the floor when Pip stands at either edge.

## Native verification

Final targeted suites passed **1,066 assertions/checks**, with zero failures:

| Suite | Checks |
| --- | ---: |
| Mascot | 90 |
| Proactive Pip | 227 |
| Pip engagement UI | 61 |
| Pip outfits | 235 |
| Direct playground input | 199 |
| UI audio flow | 106 |
| Home Pip moves | 148 |

The focused Home suite checks complete dance loops and midpoint movement,
fixed toes, distinct articulated/reduced poses, interruption and resume,
lifecycle gates, and twelve real mouse/touch taps. It also covers eight toy
takeover combinations: mouse/touch, normal/reduced motion, and tap/drag.
Scene checks scroll Home to the bottom and refocus Pip at phone and desktop
sizes, verifying that the jump keeps its headroom without moving the hit area.

The first loop test compared a countdown directly across its wrap point.
It now checks circular phase distance and matching artwork, with a midpoint
assertion to reject a stopped timer. Old deterministic poke expectations were
updated to require the shuffled reaction set and immediate visible feedback.

`node --test tests/pip-wardrobe.test.cjs` passed both wardrobe source and
eight-costume embedded-art checks. `git diff --check` passed.

## Web acceptance

`npm run build:web` passed. The startup pack verifies 200 word pronunciations,
eight random slice sounds and 174 optional paths. The compressed startup is
14.96 MB with 87 on-demand audio assets; these moves reuse the existing artwork.

Browser acceptance passed **18 cases** across desktop Chromium and emulated
iPhone/iPad WebKit: twelve existing playground regressions, three new Home
animation cases, and three board/chest/collection/preview/loss navigation cases.
The Home cases use each project's actual viewport (1366x768, 390x664 and
834x1194), while the narrow keyboard case retains its 320x568 viewport.

```powershell
$env:POP_BASE_URL = 'http://127.0.0.1:4173'
$env:POP_QA_LABEL = 'home-pip-loading-moves'
npx playwright test tests/browser/pip-playground.spec.cjs --config build/voice-pop.config.cjs
$env:POP_QA_LABEL = 'home-pip-loading-moves-acceptance'
npx playwright test tests/browser/pip-playground.spec.cjs tests/browser/godot.spec.cjs --config build/voice-pop.config.cjs --grep 'Home dances promptly|Pip follows the board'
```

The initial desktop rapid-replacement check incorrectly included screenshot
encoding/transfer time and compared moving poses sampled at different times.
The final checks measure trusted input and caption changes inside the page,
then compare distinct static reduced-motion poses for visible replacement.
Normal animation screenshots remain review artifacts. All six final acceptance
cases passed; the earlier twelve playground regressions were already passing.
The legacy navigation test also now uses the real Home layout helper for Pip.

Reviewed actual canvas screenshots of automatic dancing and all three responses
on desktop and iPhone, plus the jump/head scratch on iPad. The jump lifts both
feet, the shy wing reaches the hat, and outfits remain attached. The artwork
and input target stay inside the room; captions, toys and progress are preserved.
Native pose checks verify planted toes through the full sway, and browser pixel
changes verify sustained movement. These are emulated mobile browser profiles,
not physical-device tests.

Evidence is under `build/voice-pop-qa/home-pip-loading-moves/` and
`build/voice-pop-qa/home-pip-loading-moves-acceptance/`.

## Production acceptance

Runtime commit `feaec9c` was merged into `main`, pushed to GitHub, and deployed
to https://gentle-forest-02ff42900.3.azurestaticapps.net/.

All four production startup files match the tested export by SHA-256. The
verification manifest is `2026-09-20-home-pip-loading-moves-production-manifest.json`.

Production acceptance passed **9 cases** across the same three browser profiles:
automatic dancing, the three tap responses and rapid replacement; leaving and
returning during gestures; and first-tap/keyboard play with earned floor toys.
All cases preserve saved progress and report no browser errors.

The first iPad dance check sampled similar points of the repeating sway at
equal intervals. It now requires four distinct rendered poses over a complete
routine while checking the initial start separately. The six toy/navigation
cases passed in the first production run, and the final three Home cases all
passed with that stronger cycle-aware visual check. This was a test-only
adjustment; the verified deployed game files did not change.

Reviewed production screenshots of the desktop jump, phone head scratch and
tablet bonk. Evidence is under
`build/voice-pop-qa/home-pip-loading-moves-production/` and
`build/voice-pop-qa/home-pip-loading-moves-production-final/`.
