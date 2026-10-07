# Answer feedback sounds

The user supplied `C:/uworks/right_and_wrong.mp4` and explicitly requested its
right and wrong effects for Match and Memory. The recording identifies Duolingo;
the original sound designer and license terms were not supplied. This record
does not assert an independent redistribution license. The source video and
extracted WAVs stay outside public Git content; the compiled game contains the
two finished excerpts. No new animation asset is involved.

Phrase Builder reuses these integrated right and wrong clips for its answer check.
It adds no further excerpts from the supplied recording.

The source frames show a wrong selection around 2.12 seconds and a right answer
around 4.32 seconds. The two audio events are separated by silence. Extraction
keeps the original timing and pitch, applies the same 1.5 gain to both sounds,
and uses 2 ms / 20 ms boundary fades. Each clip retains its decay, with no added
voice, mascot call or synthesized layer. The clips use mono PCM16 at 44.1 kHz,
no import normalization, no compression and no looping.

Match touch answers, Match spoken answers, Memory answers, and Phrase Builder
checks share one bounded feedback player at gain 0.48. A new selection, hint or word replay replaces the previous feedback;
mute, navigation and round reset stop it. Speech recognizer rollover preserves
an answer that has already started. Visual Pip reactions remain, while these
three modes do not play Pip calls. Word and phrase pronunciations stay on their
own channel.

Reproduce the private build inputs with FFmpeg installed:

```powershell
node tools/import-pair-feedback.cjs 'C:/uworks/right_and_wrong.mp4'
npm run import
```

[The generated manifest](pair-feedback-audio.json) records source and excerpt
hashes, sample windows and signal levels. Source frame timing, waveform,
silence boundaries and clipping were inspected. The agent environment cannot
receive audio input, so subjective listening is not claimed; runtime checks
verify the actual rendered buffers and playback lifecycle.
