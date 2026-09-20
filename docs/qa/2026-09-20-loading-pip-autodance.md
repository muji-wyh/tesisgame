# Loading Pip: automatic dance and tap reactions

Pip starts dancing as soon as the loading playground appears and continues after
the game is ready until the player chooses **Enter game**. A tap on Pip or the
chest interrupts the dance with a jump, a shy head scratch or a playful bonk and
rebound. Shuffled groups cover all three reactions without consecutive repeats.
Rapid taps replace the active reaction instead of building a queue.

Music still requires a user gesture. Leaving the page stops movement and music;
returning resumes only the dance. Reduced motion uses distinct still poses and
text feedback. Entry and startup failure cancel all loading animations and audio.
All existing themed outfits are preserved; added SVG headroom prevents jump
poses from clipping the hat.

## Verification

- 67 Node tests passed across speech-host, playroom-host, wardrobe and Web-export
  contracts.
- The release export passed startup-pack checks: 200 word pronunciations, all
  eight imported hit sounds and zero missing resources. Startup remains 14.95 MB
  with 87 optional audio assets; the engine and game-pack hashes are unchanged.
- Desktop Chromium: 51 of 52 loading cases passed on the first run. The CPU 4x
  timing case initially measured a 2,132 ms engine task and 2,076 ms click delay
  at 98%, above the existing 2,000 ms limits. Its isolated recheck passed at
  1,535 ms and 1,460 ms respectively. No thresholds or runtime code were changed
  to obtain that result. The first-run trace and results are retained.
- Checks cover six moving limbs over a full automatic cycle, no automatic audio,
  touch/keyboard/controller reactions, 40-tap preemption, saved outfits, hidden
  and page-cache lifecycle, reduced motion, startup failures and entry during an
  active reaction. Old completion callbacks cannot restart loading effects.
- All 22 targeted iPhone/iPad WebKit cases passed, including automatic dance,
  reactions, outfits, rapid taps, reduced motion, page lifecycle and audio
  capability handling. These are Windows device profiles, not physical Apple
  hardware.
- Screenshots were inspected for the three reactions and 320x320, 320x568,
  844x390 and 1366x768 layouts. The head scratch reaches the hat rather than
  obscuring an eye; jump poses stay inside the SVG.

Evidence: `build/voice-pop-qa/loading-pip-autodance-desktop` and
`build/voice-pop-qa/loading-pip-autodance-cpu4-recheck`, plus
`build/voice-pop-qa/loading-pip-autodance-webkit`.

Timing and real-entry cases run the exported Godot engine. Controlled lifecycle
cases use the maintained HTML shell with an engine fixture. No physical
microphone was used.
