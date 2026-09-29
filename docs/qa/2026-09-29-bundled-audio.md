# Bundled audio and playback recovery

All active music, speech and effects now arrive in the startup game pack. The
157 formerly separate recordings no longer have an audio URL map, HTTP loader,
temporary downloaded resource, or separate hosting route. The export checks
both source and imported resource paths before publishing. A changed recording
invalidates the pack hash, and packaging removes old standalone audio files.

The game also remembers whether background music was playing before hiding.
Returning restores only that music, with guards for mute, unavailable audio,
microphone use, Voice Pop and a lost round. Duplicate lifecycle notifications
do not restart the track. Interrupted words, Pip calls and chest cues remain
cancelled. Turning off Match voice input restores its background music.

Godot shares its existing AudioContext with the host. Entering the game,
returning to the foreground, and trusted pointer or keyboard gestures can
resume suspended/interrupted playback. Rejected or unresolved autoplay attempts
remain retryable, and engine cleanup detaches the context. This does not create
another audio context or bypass the browser's user-gesture requirement.

## Validation

- Eight native suites passed, totaling 3,319 checks: Pip audio and reactions,
  report narration, chest audio, UI audio flow/recovery, mascot lifecycle, and
  chest charge flow.
- 112 Node checks passed across Web export, world/report/chest assets,
  deployment, playroom host, and voice host. The separate Godot-runner fixture
  was excluded from that Node-only run to keep native processes serial.
- The focused Chromium/WebKit browser matrix finished with 18 passing cases
  and six explicit audio-only skips after targeted rechecks. Chromium verified
  real output energy, suspended-context and foreground recovery without reload,
  offline words, all eight music themes, Pip, chest cues, rewards, loss cleanup,
  Voice Pop exit, and report playback. The automatic report completed online
  with no audio requests, then replayed offline; browser speech recognition
  retains its separate connectivity requirements.
- The Windows WebKit runtime has no WebAudio. Its gameplay and unavailable-audio
  paths passed, but its six audio-only cases cannot establish iOS sound quality.
  The eight-theme Chromium test needed 150 seconds for its complete UI tour;
  individual sound assertions retain their original timeouts. Voice Pop test
  setup was corrected to enter recognition online before testing offline audio.
- The exported pack passed validation for 350 word pronunciations, 20 game
  effects, Pip recordings, and all 314 source/imported paths for the 157 newly
  bundled recordings. Retired prompts remain excluded.
- Compressed startup transfer is 19.49 MB, up from 16.54 MB. The 157 formerly
  separate imported resources total 3,854,180 bytes before pack compression.
- The validated export uses `game-2c915b7d588fcb1b.pck` and
  `engine-ab20058469bff805`. Its configuration has no audio URL map, and its
  output directory contains no standalone `.sample` downloads.

An additional adventure-layout suite reported four failures in the 320 x 320
loss screen. An isolated snapshot of baseline commit `3102618` reproduced all
four messages and bounds exactly (322 checks). This pre-existing square-layout
issue is outside the audio change; no layout behavior was changed.

The first emulated WebKit chest run completed its gameplay/reward assertions but
reported one polygon-triangulation error. The unchanged focused rerun passed
with no errors. Trace timing points to Pip's fading happy-reaction stars, whose
existing subpixel geometry is unchanged from `3102618`; this attribution is not
proven by a GDScript stack. The first-run trace and rerun output remain in the
local validation artifacts. No drawing behavior was changed for this audio fix.

Native tests, export and browser runs use separate, serial processes. Browser
audio checks observe source lifetimes and actual destination waveform energy;
they do not equate a call to `play()` with audible output. Desktop browser
automation and emulated WebKit are not physical iPhone, iPad or Android audio
validation.
