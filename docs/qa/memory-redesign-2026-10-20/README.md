# Memory interaction and header review — 2026-10-20

## Direction

The earlier 390 × 844 export revealed the answer on the first card and used a
manual free Peek to show the board. Its header did not explain a dedicated
observation phase. The revised flow has an explicit Start game gate, a ten-second
observation, and a visible Start matching action. The first choice keeps its
answer concealed; a second choice reveals both cards together. Tapping the first
choice again cancels it without a mistake. Completed pairs remain visible with
matching numbers.

The fixed header separates the current phase from the potential chest. Memory
starts at the highest available design in the shared reward sequence, currently
Level 6. Each mismatch lowers it by one level. At zero, a grey production chest
and No chest text remain visible. The badge makes one local 0.52-second response
to each decrement; its anchor and the card grid stay fixed. Reduced motion
updates the artwork and text without moving the marker. The badge does not own
sound, rewards, input, or settlement. Card selection does not pronounce hidden
answers; the revealed pair uses the existing outcome cue.

The accessible instructions in `web/shell.html` now describe the Start gate,
paired reveal, six-level reward, and paid observations. They also state the
professional-mode exception for the initial observation. The accessible-help
test passed before the final export refresh.

## Existing integrated artwork

No new artwork was acquired. All six designs already ship through ChestView;
this change reuses their closed artwork, not a product-page preview.

| Level | Runtime design | Original source and creator | Available source motion |
| --- | --- | --- | --- |
| 6 | Winter / Crystal | Modern 2D Animated Chests Pack_FREE Demo 1.0.2, Bobardo | Source package is animated; integration imports PNGs and reconstructed rest geometry only, not Unity animation clips |
| 5 | Spring / Royal | Same Bobardo 2D package | Closed/open PNGs; existing Godot hinge motion is authored by the game |
| 4 | Space / Moonstone Vault | Stylized 3D Animated Chests – FREE Demo, Bobardo, Epic Chest | Intro, Idle, Open and Pickup source clips; integrated cover lift is game-authored |
| 3 | Ocean / Lagoon Pearl | POLY STYLE Fantasy Treasure Chest, Batata Studio, Treasure_Chest_1a | Static separate parts; integrated lid hinge is game-authored |
| 2 | Autumn / Harvest Keepsake | Same Batata package, Treasure_Chest_4a | Static separate parts; integrated lid hinge is game-authored |
| 1 / 0 | Jungle / Meadow Explorer | Low Poly Chest Animated, Ekrem C., Chest_Animated | Chest_Open_Close (2.15 s), Rotation and Shake; integrated hinge is game-authored |

All use the Unity Asset Store Standard EULA. Acquisition and model hashes are
recorded in [the existing chest review](../../assets/chest-refresh.md) and the
[downloaded manifest](../../../assets/chests/downloaded/manifest.json). The
[original 2D source mapping](../../../assets/chests/SOURCE.txt) identifies the
imported Crystal parts and Royal PNGs. Original packages and acquisition evidence
remain in `C:/uworks/TalkQuest`. The zero-tier material affects only this badge
instance and leaves the shared acquired artwork intact.

The countdown reuses the acquired Bobardo `portal_glow.png` and Kenneth Foldal
Moe / Archanor VFX Toon FX `sparkle.png`; provenance and Standard EULA records are
linked in [chest feel](../../assets/chest-feel.md). The new local marker reaction
and countdown motion are authored UI animation, not claimed source clips.

## Evidence and scope

- Baseline: `build/memory-redesign-20261020/before/report.json`, with ready,
  observation, first-selection and second-selection raw-canvas PNGs at 390 × 844.
  The old observation is explicitly recorded as the existing free Peek.
- Completed final capture: `build/memory-redesign-20261020/capture-after.cjs`.
  It plays the real board, remembers answers only while visibly revealed, records
  normal elapsed time and actual mixed WebAudio, then captures desktop 1280 × 800,
  landscape 844 × 390 and narrow 320 × 640 layouts.
- Focused browser contracts cover the explicit gate, observation expiry/skip,
  concealed selection/cancellation, all six decrements, pair numbering, paid Peek,
  browsing, reduced motion, and one durable Level 6 settlement worth 300 coins.
  Other existing Memory branches were migrated away from first-click answer
  discovery and the retired random chest rule; Match discovery remains unchanged.

Seven focused Chromium cases passed in 7.8 minutes on the six-tier export,
including normal and reduced motion, observation expiry and paid Peek, browsing,
audio timing, and a perfect 300-coin settlement. The initial attempt stopped on a
test synchronization mistake: several queries outlasted the real 0.7-second
feedback. The tests now retain the actual feedback publication and rendered
frames through an observer. Gameplay timing was not lengthened for the tests.
That initial trace remains in `build/memory-redesign-20261020/browser-attempt-1/`.

Rendered inspection found a narrow-layout defect after the seven tests passed:
the 320-pixel badge clipped both the final digit in Level 6 and the end of No
chest. `build/memory-redesign-20261020/narrow-before/` preserves the actual ready,
observation and empty-chest screens. The responsive label now uses `Chest / Lv 6`
or `No / chest` on two lines only when the complete form cannot fit at 11 CSS
pixels. Wider layouts keep their full labels. Chest artwork, header allocation,
card positions and accessible wording are unchanged. The focused widget test
measures every displayed line at the actual 320-pixel allocation.

The coordinated six-tier native batch passed Memory scene (166 checks), reward
widgets (65), coin rewards (373), card (57), and hover (63,126). After the
narrow-label correction, the focused native rerun passed all 77 reward-widget
checks and 166 Memory scene assertions. All 63 browser JavaScript files parse.
The seven Chromium passes precede the narrow-label correction. After that
correction and the successful 37.10 MB export, the iPhone 13 WebKit profile passed
the complete normal-motion core case in 1.3 minutes. That case covers the gate,
observation, skip, concealed selection/cancellation, all six losses, grey chest,
numbered pair and zero-chest completion. The final WebKit zero-chest image was
also inspected; it retains the complete label and card layout.

## Final rendered and media evidence

`build/memory-redesign-20261020/after/report.json` records the final run with no
browser errors or capture failure. Sixteen raw-canvas PNGs cover the 390 × 844
ready, observation, first choice, simultaneous mismatch reveal, every reward
decrement, grey chest and numbered pair; 320 × 640 ready/observation/zero;
844 × 390 landscape; and 1280 × 800 desktop. These views were inspected. The
compact 320-pixel labels now fit completely, the skip control stays separate
from the clock, and larger layouts keep their complete labels. Both selected
faces are visible during mismatch feedback; the successful pair keeps equal
numbers. Root also independently inspected the key phone and layout images.

The run retains 459 state/output samples and 24 timed reaction snapshots. The
badge's header rectangle stays constant through all six decrements, and its
local transform changes only during the response. The recording captures a real
observation, concealed first choice, six mismatches and one numbered success at
normal elapsed time. Answers were remembered only from the visible observation;
outcomes and reward state were not injected.

The original WebM is 1,989,645 bytes with a 390 × 844 VP8 video stream and a stereo
48 kHz Opus audio stream. The recorder ran for 26.579 seconds and captured the
actual WebAudio mix; maximum sampled output RMS was 0.1052. The shareable MP4 is
1,082,471 bytes, 26.441 seconds, H.264 at 30 fps with stereo 48 kHz AAC. Conversion
explicitly maps the WebM's full color range to limited range. Both containers
were probed and fully decoded with FFmpeg's error-abort check, without errors.
An extracted MP4 observation frame was inspected. Probe records are saved beside
the clips as `webm-probe.json` and `mp4-probe.json`.

The dedicated audio test observed bundled wrong/right cues starting 13.5/15.0 ms
after the trusted second-card gesture and 4.4/8.4 ms before publishing its
revealed-pair status. It verified silence for the first selection and its cancel,
with no external media requests. These are measured output/timing checks, not a
claim of subjective listening or normal-speed audiovisual review.

Useful outputs:

- [390-pixel observation](../../../build/memory-redesign-20261020/after/phone-memory-observation.png)
- [Concealed first choice](../../../build/memory-redesign-20261020/after/phone-memory-first-selection.png)
- [Simultaneous mismatch reveal](../../../build/memory-redesign-20261020/after/phone-memory-second-selection.png)
- [Narrow observation](../../../build/memory-redesign-20261020/after/memory-320-observation.png)
- [Narrow zero reward](../../../build/memory-redesign-20261020/after/memory-layout-320x640.png)
- [Normal-time MP4 with recorded audio](../../../build/memory-redesign-20261020/after/memory-observe-select-reward-phone.mp4)
- [Original WebM](../../../build/memory-redesign-20261020/after/memory-observe-select-reward-phone.webm)

The first final-capture harness attempt let the real ten-second observation
expire while resizing between viewports; it is preserved in
`build/memory-redesign-20261020/capture-attempt-1/`. The completed capture uses a
stable 390-pixel viewport for the recorded interaction and a separate narrow
observation pass. Gameplay timing was not changed.

This is not a claim that the full repository suite passes. The broader audit
reported four existing Match-result expectations in the expansion scene, 15
Home/UI failures, and one growth startup-recovery failure. Memory assertions in
the expansion scene passed. Wider browser branches migrated in this change have
only received syntax/static checks unless explicitly listed as executed later.

Logic checks alone do not establish visual or acoustic quality. Browser geometry
is simulated device coverage; no physical-device or subjective audio-listening
claim is made.
