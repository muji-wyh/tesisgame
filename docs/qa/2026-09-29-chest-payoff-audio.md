# Chest opening payoff audio

The final release now combines a fast low-mid impact, a crisp opening edge,
expanding air, and diffuse material shimmer. The earlier release lost nearly
all of its energy after 300 ms. The new 300-500 ms bloom supports the existing
theme flash while keeping the strongest impact within the first 45 ms.
Each world's material and resonance profile remains distinct. A separate
ascending reward accent resolves only after the reward save succeeds.

The five-second performance, release at 3.36 seconds, cancellation boundary,
visuals, and reward accounting are unchanged. Release and saved-reward playback
gains are 0.86 and 0.54. No new playback timers or audio lifecycle states were
added. The local fallback follows the same payoff envelope and uses the authored
reward duration of 740 ms.

## Waveform measurements

- Exactly 16 WAVs changed: release and reward for eight themes. The other 72
  authored cues reproduce their previous bytes. All 88 cues remain deterministic
  and total 1,549,152 bytes, with no additional downloads.
- Authored release RMS is 0.17, with first-40 ms RMS of 0.381-0.441 and
  300-500 ms RMS of 0.046-0.069. The final 620-680 ms RMS is 0.0009-0.0053.
- Authored saved-reward RMS is 0.12 across all eight worlds. Peaks are
  0.457-0.529 before the 0.54 playback gain.
- Release plus the overlapping lid stop peaks at 0.544-0.633 with the runtime
  gains and 420 ms offset. Adding each music asset's maximum peak at the louder
  settling duck gives a conservative combined bound below 0.680. The saved
  reward plus full music remains below 0.388 by the same calculation.
- Before/after clips, comparisons matched by source RMS, and the complete
  measurements are in the ignored `build/chest-payoff-comparison/` directory.
  These measurements establish envelope and headroom, not perceived excitement.

## Validation

- All 20 Node chest asset checks passed, including byte-exact generation,
  impact weight, audible bloom, final damping, reward level consistency,
  clip durations, and overlapping release/settle headroom.
- Native chest audio passed 2,376 assertions, including authored and actual
  fallback PCM, theme selection, gain, intact release during settling,
  mute/background cancellation, duplicate callbacks, and successful save retry.
- Native chest charge flow passed 605 assertions and UI audio flow passed
  147 assertions. The existing motion, input, save, and audio handoff contracts
  remain intact.
- Release export passed the pack verifier for 350 word pronunciations, 12
  general effects, and 314 required source/imported audio paths. Compressed
  startup transfer is 19.14 MB with `game-1f22a977a9fbe601.pck` and the unchanged
  `engine-ab20058469bff805` Web engine.
- Browser source monitoring accounts for Godot stopping/disconnecting a source
  from its natural-ended callback. An initial test incorrectly rejected any
  stop call, even after the complete 680/740 ms sound. The corrected assertion
  waits for natural completion and rejects stops scheduled before the clip's
  end; it also checks the actual mixed destination for energy and headroom.
- Three focused Chromium cases passed: cancellation at the visible release
  boundary, authored offline playback without audio HTTP requests, and the
  complete cancel/recharge/reward performance. The first two passed at
  1366 x 768. A full-size cadence recheck skipped the last pre-existing 60 ms
  beat during a software-rendering stall; the complete performance passed at
  800 x 600 without relaxing its beat or alignment assertions.
- The passing performance recorded a destination peak of 0.5902 and maximum
  sampled RMS of 0.2252. Unlock, release, and settling source onsets followed
  their browser cue notifications by 8.1, 67.2, and 4.2 ms. Both release and
  reward reached their complete source duration before cleanup. These are
  software scheduling observations, not a physical audio/display latency test.

Automated audio measurements cannot establish perceived excitement or physical
speaker/Bluetooth latency. Physical Chrome/Safari mobile listening remains a
manual check; no subjective listening or real-device validation is claimed.
