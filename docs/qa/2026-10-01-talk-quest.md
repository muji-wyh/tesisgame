# Talk Quest

Talk Quest adds a fourth game mode alongside Match, Memory, and Voice Pop.
This report records local implementation and verification on October 1-2,
2026. Initial validation used the combined working tree; a separately isolated
release snapshot then passed the focused checks recorded below. Both selected
WebKit cases passed functionally during initial validation, while composed-page
captures after viewport rotation remained blank despite valid raw canvas
rendering. The initial local verification phase involved no public deployment.

## Scope

- Fourteen levels contain 170 complete sentences spoken by Adam and Yoki.
  Twelve everyday conversations lead to an eighteen-line birthday boss and a
  twenty-line cooperative workshop. The levels have 6, 6, 8, 8, 10, 10, 12, 12,
  14, 14, 16, 16, 18, and 20 lines respectively.
- Each level has a distinct scene composition and one of fourteen source
  creatures. The first thirteen adventures progress through word effects,
  creature reactions and health, friendly defeat, victory, and treasure.
  Reduced-motion presentation is supported.
- The workshop has no health, damage, attacks, or defeat. Five repairs each
  require choosing the correct illustrated part from three options before
  completing four lines. The required parts are a wheel, wing, ribbon, screw,
  and key. Incorrect choices are harmless; speech and typing cannot bypass a
  closed part gate.
- Final recognition must match the whole prompted sentence after conservative
  case, punctuation, whitespace, and contraction normalization. Interim text is
  visible without scoring. Original event, round, and prompt bindings prevent
  duplicate, stale, malformed, and paused events from advancing the adventure.
  Incorrect speech has helpful feedback without a penalty.
- **Type** practice uses the same sentence validator. **Hear line** stops
  recognition before browser text-to-speech reads the prompt. Resuming an
  adventure requires a new **Speak** gesture.
- Device-wide progress saves clear counters and a validated pending adventure,
  including canonical workshop part selections. It contains no transcripts,
  recordings, or recognition event IDs. Resume restores the exact sentence,
  part choice, victory, or pending chest. Reward commits reject duplicate
  callbacks and stale pending saves.
- Twenty chest designs are reachable: fourteen through the campaign and six
  more through replay, followed by deterministic cycling. Talk Quest uses
  shared campaign progress rather than player leaderboard scores.

The maintained [mode specification](../talk-quest.md) describes the current
interfaces and save contract.

## Initial validation of the combined working tree

These aggregate results include unrelated speech work that was already present
in the working tree. The 70-suite and 259-test totals, initial browser runs, and
the `fd189476ab65ac5d` and `3d5c2e978d48c02f` exports are historical evidence for
that combined tree. They are distinct from the isolated release preparation
recorded later in this report.

| Check | Recorded result |
| --- | --- |
| Native regression suites | All 70 Godot suites completed with zero failures |
| Talk Quest model | 1,490 assertions, zero failures |
| Talk Quest monster integration | 148 assertions, zero failures |
| Talk Quest scene integration | 117 checks, zero failures; repeated after compact-layout and ASCII label corrections |
| Node regression rerun | 259 tests passed, zero failures, skips, or cancellations |
| Native art capture harness | 129 captures, zero capture failures |
| Source model validation | 14 complete rigged GLBs and 22 exported clips with measured moving mesh vertices |
| Campaign-tested Web export | `npm run build:web` passed; 19.94 MB startup and 224 required audio paths checked with zero failures; predates the ASCII label correction |
| Later combined-worktree Web export | Two-label follow-up build passed with the same 19.94 MB startup and 224 required audio paths checked with zero failures |
| Desktop Chromium | All three cases passed against the campaign-tested baseline in 8.0 minutes |
| WebKit functional cases | Hear line/mode exit and typing/backgrounded chest passed in separate runs |
| Combined-worktree export focused cases | Desktop Chromium and iPhone WebKit typing/backgrounded chest passed in 1.8 minutes, including initial-page and raw-canvas color checks; WebKit composed-page rotation captures remain blank |

The native suites cover content, full-sentence matching, speech binding and
replay protection, pause/resume, workshop gates and saved choices, campaign
transitions, all twenty rewards, guarded commits, private checkpoints, and
malformed saves. Local native evidence is in
`build/talk-quest-native-tests.log`.

The combined native/Node runner did not pass as one command: after all seventy
native suites passed, an obsolete Web-export assertion rejected every use of
browser text-to-speech. Talk Quest intentionally uses it for **Hear line**.
The assertion was corrected, and the separate complete Node rerun passed all
259 tests in `build/talk-quest-node-tests.log`. The invalid-creature warning in
the native log is an intentional negative-input fixture.

The art harness is `tests/godot/talk_quest_art_review.gd`; local captures are
under `build/talk-quest-art-review/`. A companion-face overlap in chest 14 was
corrected and the captures regenerated. A final compact-layout correction hides
the duplicate lower creature name when the art area is less than 180 pixels
high, preventing an overlap. The scene suite passed all 117 checks again in
`build/talk-quest-final-scene-tests.log`. Capture completion establishes that
the native scenes rendered; it does not measure mobile performance.

## Asset evidence

The fourteen rigged creatures come from Unity Asset Store product 380750 under
the Standard Unity Asset Store EULA. Their source metadata, hashes, conversion,
preview cropping, and listing/archive version discrepancy are recorded in
[monster provenance](../assets/talk-quest-monsters.md) and its
[machine-readable record](../assets/talk-quest-monsters.json).

All fourteen creatures have a verified source `Idle` clip; eight also have
source `Celebrate`. There were no usable source `Hit` or `Defeat` clips in the
selected characters. Recoil, friendly retreat, and cooperative wake/stretch
reactions are authored gameplay motion. Runtime creatures use the rigged GLBs;
the alpha-cropped and padded portraits are reviewed source previews.

The [scene art](../../assets/talk_quest/scenes/README.md) and all twenty
[chest mechanisms](../../assets/talk_quest/chests/README.md) are original
procedural vector art. Their manifests record the distinct compositions and
mechanisms used by the runtime.

## Campaign-tested Web export and desktop Chromium

The baseline release build, including the art and compact-layout corrections,
completed successfully. The actual startup pack check verified 350 word
pronunciations, 12 game effects, and 224 required audio paths with zero failures.
The export reports a 19.94 MB startup
and 112 music, prompt, chest, and optional slice assets verified inside the
game pack.

The campaign-tested game pack is `game-fd189476ab65ac5d.pck`, with SHA-256
`FD189476AB65AC5D54E6C40B6161A0ADE0159849118D974F3A9E99B9074AC2C5`.
The exported `index.html` SHA-256 is
`CE6656589AF5353F308E69332717DA4569B8B03B6595EDF0290E20B4E2F39044`.
These identify the local baseline used for the complete Chromium campaign run.
They predate the later ASCII label correction and do not identify a final
release or a public deployment.

All three desktop Chromium cases passed against that baseline export in 8.0
minutes, recorded in `build/talk-quest-browser-final-desktop.log`:

- Completed all fourteen campaign adventures with simulated browser speech,
  checked restoration after a mid-adventure reload, and verified the final
  campaign and collection state.
- Verified that **Hear line** and leaving an adventure stop capture without
  scoring or reopening the microphone.
- Verified typing without browser speech at 320 by 568 and 568 by 320 viewport
  sizes, and exactly one reward from a chest backgrounded during its animation.

An initial campaign fixture exceeded its
420-second timeout while repeated selector-backed snapshots added substantial
overhead; it had reached the workshop. The fixture helper was optimized without
changing the assertions, and the complete baseline run passed. Baseline browser
screenshots are in `build/talk-quest-browser-review/desktop/`.

## Combined-worktree label rebuild and focused verification

Visual review found missing checkmark glyphs in completion labels. Those labels
were replaced with ASCII **Cleared** and **Collected** text after the baseline
Chromium run. This two-label-only follow-up build passed in
`build/talk-quest-release-build.log`, again reporting 19.94 MB startup and 224
required audio paths checked with zero failures.

This combined-worktree game pack is `game-3d5c2e978d48c02f.pck`, with SHA-256
`3D5C2E978D48C02FCBACD46DBF9EC53C72CD8B319F462926D80A67C15C892BAA`.
Its exported `index.html` SHA-256 is
`C5446DAA8098710DC7251531F721E5D8CA54F1E66ABDC6EC8D09A757C2AB8D75`.
The complete campaign evidence above applies to the earlier baseline and must
not be described as a full campaign test of this later output.

The focused desktop Chromium and iPhone WebKit typing/backgrounded-chest cases
passed against that export in 45.3 and 58.6 seconds respectively, with two
passes in 1.8 minutes overall. Initial-page and all raw-canvas color assertions
passed. The log is `build/talk-quest-browser-delivery-typing.log`, with captures
in `build/talk-quest-browser-review/final-typing/`.

At this stage the sidebar preview was refreshed to that tested pack at level 1,
line 0. The captures `build/talk-quest-final-preview.png` and
`build/talk-quest-map-preview.png` recorded the combined-worktree output; they
are separate from the isolated release verification below.

## WebKit functional results and presentation limitation

The **Hear line** and mode-exit case passed in
`build/talk-quest-browser-webkit-recheck.log`. The typing and backgrounded-chest
case subsequently passed in 47.2 seconds, with a total run time of 49.4 seconds,
in `build/talk-quest-browser-webkit-typing-recheck.log`. These are separate
passing functional runs.

The first typing recheck failed because its helper called `mouse.wheel`, which
mobile WebKit does not support. A replacement drag initially missed the narrow
scrollbar; correcting the drag position allowed the existing assertions to
pass. The test uses the actual scrollbar rather than setting scroll state
through a game hook.

Screenshot review reproduced a Windows WebKit presentation/capture limitation:
the initial portrait page rendered, but composed-page captures at landscape,
portrait after rotation, and subsequent states were solid pale green while the
functional state continued to advance. The final focused tests passed strict
initial-page and raw-canvas color checks. Visual review of the WebKit landscape
raw canvas showed the full rendered UI, including the **Who's that?** prompt,
creature, and actual scroll thumb. Raw-canvas validation does not establish that
the resized WebKit window is displayed correctly. The composed-page limitation
remains unresolved; this is not a complete WebKit visual pass.

The same composed-page symptom is documented in the prior
[Windows WebKit resize investigation](2026-09-11-steady-gameplay.md#windows-webkit-resize-investigation)
and the [September 26 cleanup](2026-09-26-repository-cleanup.md). Those earlier
runs found valid raw canvas rendering despite blank composed-page captures,
including on an untouched baseline. Current Talk Quest raw-canvas results
substantiate the same distinction for this mode. No product fix for that
existing presentation limitation is claimed.

An earlier `waitForFunction` timed out even though the reported expected and
observed states were identical. The test-side wait was replaced with
`expect.poll`, retaining the ten-second assertion deadlines. The fixture
failures were corrected independently of the presentation limitation.

## Measurement limits

Speech fixtures simulate recognition callbacks; they do not measure acoustic
recognition accuracy or children's pronunciation. Browser emulation does not
establish physical mobile microphone, speaker, keyboard, or performance
behavior. Native captures and Blender source validation do not establish
browser rendering or playback. The recorded checks were completed before
publication and do not claim a deployment result.

## Isolated release preparation

The release was built from a separate snapshot of the staged files under
`build/talk-quest-commit/release/`. It excludes the unrelated uncommitted speech
diagnostics, compound matching, and Pop callback receipt changes. A narrow
capture-readiness/watchdog prerequisite required by the Talk Quest browser host
is included. Tests and export ran from this snapshot, so the other working-tree
speech changes were not part of the verified release artifact.

The public source snapshot retains character manifests, provenance, and
conversion tools. Licensed character GLBs, portrait PNGs, and their import
sidecars are ignored local build inputs restored for the isolated build. They
are bundled into the compiled game pack; the staged index contains no raw
licensed character payloads.

| Isolated check | Result |
| --- | --- |
| Talk Quest native suites | Model: 1,490 assertions; monsters: 148 assertions; scene: 117 checks; all passed |
| Modified native regression suites | Collection polish, layout, Memory scene, core scene/model, and mode-order suites passed; five suites, zero failures |
| Complete configured Node plan | 237 tests passed, zero failures, skips, or cancellations |
| Web export | Passed; 19.94 MB startup, 350 pronunciations, 12 effects, and 224 required audio paths verified with zero failures; 112 music, prompt, chest, and optional slice assets verified inside the pack |
| Focused desktop Chromium | Both cases passed against the isolated export in 1.4 minutes: Hear line/mode exit in 33.0 seconds, and phone-size typing/backgrounded chest in 42.8 seconds |

The focused browser cases verify capture shutdown without scoring or reopening
the microphone, typing without browser speech at phone sizes, and exactly one
reward from a backgrounded chest. The complete fourteen-level browser campaign
was not repeated on this isolated artifact; that campaign result belongs to
the earlier combined-worktree baseline.

Local logs are `build/talk-quest-commit/isolated-quest-tests.log`,
`build/talk-quest-commit/isolated-regression.log`,
`build/talk-quest-commit/isolated-build.log`, and
`build/talk-quest-commit/isolated-browser.log`. The isolated release hashes are
recorded in `build/talk-quest-commit/release-hashes.json`:

- `game-bcdba8666d791d3f.pck` SHA-256:
  `BCDBA8666D791D3FF340E4E59483636A1EDD83F896C05E08BA92F13A9BCDF815`.
- `index.html` SHA-256:
  `12090E4ECDCF92D344EC0A2BB57C4AD7BAA5BEC0812D09B7885D6CE661E785A8`.
