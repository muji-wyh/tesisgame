# Interface button click

The user supplied `C:/uworks/sound_effect-select.mp4` and requested the click
from its first five seconds for non-gameplay buttons. The video identifies
Duolingo; the original sound designer and license terms were not supplied.
This record does not assert an independent redistribution license. The source
and extracted WAV remain outside public Git content. The finished clip is
embedded in the loading page and included in the compiled game pack.

The selected click occurs at the first word-tile selection around 2.20 seconds.
The excerpt starts at 2.190 seconds and lasts 80 ms, preserving its attack and
natural decay without the opening spoken phrase. Extraction applies a fixed
gain of 8, 0.5 ms / 5 ms boundary fades, and no pitch, speed or timbre changes.
The result is mono PCM16 at 44.1 kHz. Both browser and native UI use gain 0.48.
Each uses one replaceable click channel, so fast button presses cannot build up
overlapping layers in that interface.

Menus, navigation, settings, player management and result actions use this
cue. Card answers, word playback, hints, memory peeking, chest opening and
room toys retain their dedicated gameplay feedback. A committed button action
plays once; focus, hovering, disabled buttons, canceled gestures and scrolling
do not. Muting and page suspension stop the channel. Navigation allows its
short tail to finish without starting music or interrupting speech.

Reproduce the local build input with FFmpeg installed:

```powershell
node tools/import-ui-click.cjs 'C:/uworks/sound_effect-select.mp4'
npm run import
```

[The manifest](ui-click-audio.json) records the source hash, extraction window,
processed hash and signal levels. Source frames, event boundaries, waveform
and clipping were inspected. Audio input is unavailable to the agent, so no
subjective listening is claimed. Browser and native tests check real playback,
duration, gain, repeat behavior and lifecycle.
