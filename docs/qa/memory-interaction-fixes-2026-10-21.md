# Memory interaction fixes — 2026-10-21

## Behavior

- A concealed first choice keeps its answer hidden and silent. A persistent
  contrasting back and light inner outline acknowledge selection.
- Choosing another card of the same kind replaces that choice without revealing
  either card, counting an attempt, recording a wrong answer, or lowering a chest.
  Selecting the same card again still cancels it.
- Hovering a matched card illuminates both members of its pair. During observation,
  every visible word-picture pair supports the same treatment. Concealed unmatched
  cards cannot disclose their partners through hover. Observation and matched cards
  remain disabled for matching input.
- The header refresh action creates a fresh round at the Start game gate. It clears
  pending observation, selection, feedback, and highlight state. Refreshing during
  the fifth successful pair finishes the outcome and saves its reward first.
- Memory shows Play again from the start of Pip's celebration, through the chest
  entrance and final result. It uses the existing reward receipts to collect an
  unopened earned chest before starting again. Save failures retain the retry path.
  A held Replay or Home action delays the automatic handoff until release, so a
  click cannot disappear between the celebration and the final result.
- Chest loss now uses a stationary 0.78-second counterclockwise full turn. The
  existing artwork immediately compresses and dims, contracts to 40% for the tier
  swap, and recovers without a celebratory bounce. Losing the last chest contracts
  to 18% with a darker, longer pause before becoming grey. The artwork stays at
  its original center. Reduced motion updates immediately.
- Loss uses a dedicated descending sound instead of stacking ordinary wrong
  feedback. The last chest adds a lower pitch and a soft wooden stop at the
  340 ms artwork swap. After the chest is already gone, wrong pairs use the
  ordinary wrong cue. All loss audio shares the existing bounded feedback voice
  and its mute, pause, refresh, and navigation cancellation.

## Existing material and new icon

The card treatment is interface styling. All six production chest designs and
their rights remain as recorded in [the prior review](memory-redesign-2026-10-20/README.md).
The new refresh control uses Paweł Kuna's Tabler Icons 3.35.0 `refresh.svg` under
MIT, acquired from the pinned upstream source and integrated with the existing
theme tint transformation. Its source URL, hashes, license, acquisition date, and
static-animation status are recorded in
[`sources.json`](../../assets/images/ui/controls/sources.json).
The actual acquired vector was inspected at control size in
`build/memory-fixes-20261021/refresh-source-review.png` before integration.

The two loss sounds adapt acquired Kenney Interface Sounds and Impact Sounds
under CC0. Source paths, creator, license copies, delivery hashes, timing and
processing are in [the audio record](../assets/memory-chest-audio.json).
The actual rendered waves have descending frequency contours and unclipped
headroom. Direct auditory input was unavailable; these measurements and browser
playback checks do not establish subjective listening quality.

## Evidence

The previous first-choice phone rendering is retained at
`build/memory-redesign-20261020/after/phone-memory-first-selection.png`.
It shows why the old border did not clearly distinguish the selected card.
Current test logs and browser output are stored beneath
`build/memory-fixes-20261021/`.

Native checks cover model neutrality, real pointer hover on disabled cards,
selection appearance, observation/payment behavior, chest lifecycle, refresh
cancellation, immediate replay, exact reward receipts, and small-screen targets.
The Memory scene checks include 320 × 568, 390 × 844, 844 × 390 and 1280 × 800.
Browser regressions use actual card input and remember word identities only from
the visible observation. They cover concealed selection, same-kind replacement,
pair highlight isolation, refresh, all six chest losses, and replay persistence.

The first browser run exposed a real input race: a Replay press at 2.71 seconds
spanned the celebration handoff, removing the button before release. The final
implementation keeps that control alive until the press finishes. Native pointer
tests cover both a valid release and cancellation across the deadline. The browser
regression deliberately holds Replay through the same deadline before releasing.

Native suites passed with zero failures: Memory model (812), garden (75,998),
card polish (57), back design (6,469), reward UI (559), observation (290),
observation payment (98), scene (231), celebration (116), celebration flow (429),
and UI audio flow (308). Card polish, celebration, and celebration flow were
rerun after the final edge-ring rendering and handoff fixes. Node's Memory input
and UI click asset checks also passed (14 tests).
The delivery preset, required audio inventory, and accessible-help checks passed
(3 tests). Reward UI and audio flow were rerun after the final loss treatment.

The final controls export passed all three focused Chromium regressions:
observation/matched hover, refresh during feedback, and Replay held across the
settlement handoff. Both final pair-highlight screenshots were visually reviewed;
the open edge rings preserve the word and picture instead of obscuring them.

The final loss export built successfully with 389 required audio resources and
a 37.15 MB core. Its Chromium audio regression passed offline with eight actual
pair inputs: five downgrade cues, one final loss, one ordinary wrong cue after
zero, and one correct cue. Each input played exactly one feedback recording;
the hidden first choice and cancellation stayed silent. Measured cue starts were
13–25 ms after the trusted second-card release.

The iPhone WebKit profile passed the complete normal-motion flow, including all
six downgrades, a deeper/darker final collapse, no scale overshoot, a fixed badge
anchor, matched pair badges, and zero-reward completion. The final phone selection
and grey-chest screenshots were visually reviewed. These are simulated browser
device profiles, not physical-device evidence.

The final preview server capture also passed at 390 × 844, with additional
1280 × 800, 844 × 390, and 320 × 640 views. Captured contraction frames show
the ordinary loss at 40% scale and final loss at 18%; both retain the original
anchor. A 27.31-second canvas/WebAudio recording and a 6.83-second excerpt of
ordinary downgrade plus final loss are saved under
`build/memory-fixes-20261021/capture/` as
`memory-observe-select-reward-phone.webm` and `memory-chest-loss-preview.mp4`.
The excerpt keeps the original elapsed speed and audio. Frames, stream structure,
and browser playback events were checked; no subjective normal-speed viewing or
listening claim is made.

The build regenerated the existing professional release's supporting-inventory
fingerprints for the required audio inventory change. Course content is unchanged.

No production deployment or physical-device test is implied by this local review.
