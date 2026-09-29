# Chest anticipation pause

The final roll now brakes over 60 ms and holds the loaded chest for 160 ms
before the opening impact. The body, lid/lock, surface light, flowing progress
effects and decorations share the same slowed pose clock. Release starts from
that exact pose and blends back to the live presentation clock over 75 ms.

The real input and cue clocks continue throughout the pause. Release stays at
3.36 seconds after pressing, and completion stays at five seconds. Releasing
during the pause still cancels; releasing when the opening flash begins commits
the gesture and lets the remaining performance finish. Saving remains tied to
completion, and reduced motion keeps its shorter existing flow.

## Sound and skipped frames

Anticipation clears remaining rolling strikes and quiets the live pressure bed
to gain 0.025, without restarting it. The 240 ms opening clip gathers over its
first 60 ms into a quiet tail. Music ducks to 0.06 and the small latch uses gain
0.055. The existing release and saved-reward sounds are unchanged.

The steady held mix also follows saturated real progress independently of the
skippable breath cue. A frame from opening +1.90 to +2.04 seconds therefore
quiets the bed without replaying a missed one-shot. Unlock provides the same
idempotent fallback. Late progress or cues cannot restart sound after release.

Only the eight opening WAVs changed. The other 80 cue hashes match the prior
version. Authored opening RMS is 0.055; the 60-210 ms held tail measures
28.7-29.8 dB below the early gathered breath. The bank remains 1,549,152 bytes
and requires no additional audio download.

## Automated validation

- All 21 Node chest asset checks passed, including deterministic audio
  generation and the quiet-tail envelope.
- Native feel: 1,477 assertions passed across all eight themes, including
  held body and part transforms, light/color/crown stability, advancing real
  progress, and less than 0.05 screen pixels of discontinuity at release.
- Native audio: 2,648 assertions passed, including authored/fallback envelopes,
  missed anticipation, event/update ordering, cancellation and release cleanup.
- Native charge flow: 645 assertions passed, including cancellation during the
  hold, fixed reward timing and once-only save behavior. The held body and glow
  remain stationary across 32 theme/viewport combinations.
- Native reveal: 2,011 assertions passed.
- Web export passed the startup-pack verifier for 350 word pronunciations,
  12 game effects and 314 required audio paths. The compressed startup is
  19.15 MB, using `game-57327e3cd5149fd8.pck` and the unchanged
  `engine-ab20058469bff805` engine.
- Four focused Chromium cases passed at 800 x 600: complete cancel/recharge
  performance, reduced motion, cancellation before versus after release, and
  bundled offline audio. The smaller viewport isolates cadence from the known
  software-renderer cost while retaining the existing strict beat assertions.
- The actual browser destination measured a 24.3 dB drop from the final roll
  to the held breath and a payoff peak of 0.8284, below clipping. Unlock,
  release and settling source onsets followed cue notifications by 4.9, 39.4
  and 3.9 ms. Total observed hold-to-save time was 5.120 seconds. These are
  software observations, not speaker or display latency claims.

## Recorded evidence

The ignored `build/chest-feel/` directory contains 640 x 640, 60 fps recordings
of Autumn, Space and Candy with actual mixed engine audio, plus matching-crop
held-pose comparisons and a frame grid. The clips include a short cancellation
and the complete five-second performance. Still-frame samples stay inside the
pause to avoid Movie Maker and decoder frame rounding at the release boundary.

Recorded mean levels in dBFS, without replacing or normalizing the soundtrack:

| Theme | Final roll | Held breath | Release | Whole-clip peak |
| --- | --- | --- | --- | --- |
| Autumn | -21.0 | -40.5 | -12.6 | -4.0 |
| Space | -21.2 | -46.8 | -12.9 | -4.6 |
| Candy | -21.5 | -41.8 | -12.7 | -4.2 |

The recorded hold-to-reward interval was 5.033 seconds at 60 fps, within the
existing frame-origin allowance. Early/late stills were visually inspected for
the loaded pose and a coherent continuation into the existing release bloom.

These checks establish timing, state, geometry and audio envelope behavior.
Subjective listening and physical Chrome/Safari device latency remain manual
checks; no real-device listening result is claimed.
