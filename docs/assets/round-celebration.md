# Round completion presentation

Round completion uses Pip's existing articulated artwork and expression heads,
the selected world's existing closed chest, and a separate nonverbal audio
layer. It does not introduce another mascot, voice prompt, quack, chest-opening
animation or reward save. Word and phrase pronunciation keep their own channel.

## Reference and integrated material

The motion reference is the opening celebration in the user-supplied
`C:/uworks/sound_effect-chest_openning.mp4`. The reference informs anticipation,
the main gesture and the return to a readable reward invitation. Reference
imagery is not copied into the game. Pip keeps the existing six articulated
body parts, ten expression heads and all eight wardrobes described in
[Pip expressions](pip-expressions.md) and [Pip dance parts](pip-dance.md).
These are existing project artwork and locally authored derivatives; the
repository does not identify a separate individual illustrator.

The small closed chest reuses the current world's integrated chest art. The
Royal, Energy and Crystal designs come from the user-provided Modern 2D Animated
Chests Pack_FREE Demo 1.0.2. Its original source paths and file hashes are
recorded in `assets/chests/SOURCE.txt` and `assets/chests/manifest.json`; those
records do not independently identify an artist or assert additional rights.
The five other world designs retain the acquired models and Unity Asset Store
Standard EULA records in `assets/chests/downloaded/manifest.json`. Previewing
a closed chest does not invoke its charge, opening, persistence or saved-reward
callbacks.

## Performance and completion

`RoundCelebration` samples one three-second clock: preparation through 0.25 s,
leap and feet-first landing through 0.9 s, alternating steps and one wink through
1.65 s, then a presenting gesture as the closed chest appears at 1.8 s. Pip
settles by 2.4 s. The invitation keeps only subtle breathing and occasional
blinking. Every earned chest also reveals full-screen paper from 1.8 to 3 s,
using the shared renderer and existing licensed atlas documented in
[Jelly chest fragments](jelly-fragments.md). The burst ends independently of
long pronunciation and never captures input. Reduced motion uses a static
happy pose with no moving halo or confetti.

`GameUI` owns the round identity, interruptions and input gate. Match, Memory
and Phrase Builder wait for both the performance and the final pronunciation
before offering `Open chest`. Phrase accepts completion only at that action.
Voice Pop and Jelly Match save the score and final upgraded chest first, then
restore their complete result page after celebration. Their zero-chest rounds
go straight to results. Match and Memory celebrate completion even without a
chest, omit the chest artwork and confetti, and offer Play again. Presentation
never saves rewards or opens a chest.

## Shared recordings, separate playback

The presentation reuses three already integrated recordings. It does not
extract another section of the source video or create duplicate audio files.

| Timeline cue | Existing recording | Source start / duration | Runtime gain |
| --- | --- | --- | --- |
| `step` | `assets/imported-audio/chest-reference/step.wav` | 34.215 s / 0.24 s | 0.32 |
| `step-detail` | `assets/imported-audio/chest-reference/step-detail.wav` | 36.28 s / 0.24 s | 0.28 |
| `reward` | `assets/imported-audio/chest-reference/reward.wav` | 45.58 s / 1.2 s | 0.44 |

These WAVs remain mono PCM16 at 44,100 Hz, with their existing source pitch,
duration and boundary fades. The exact hashes and original extraction gains
remain in [the chest audio manifest](chest-reference-audio.json). The recording
identifies Duolingo; its original sound designer and license terms were not
supplied. The existing provenance does not assert an independent redistribution
license. These private build inputs remain embedded in the compiled game pack.
The separately inspected celebration near the start of the source video is a
motion reference; these three existing recordings come from its later chest
sequence.

`begin_round_celebration(round_id)` arms the audio layer without playing a cue.
`play_round_celebration_cue(round_id, cue)` accepts each of the three named beats
once per armed presentation. The owner supplies those events from its animation
timeline. Starting the same active ID is idempotent; a different ID cancels the
previous presentation. `stop_round_celebration()` invalidates the active ID,
stops both players, releases their streams and restores the music mix. A resume
of an unfinished presentation explicitly begins its audio again and restarts
the complete three-second visual timeline, including its three synchronized
beats. A completed invitation preserves its ready state and does not replay
the performance or its sounds when an overlay or background pause ends.

Two dedicated players bound overlap. These players share the loaded audio
resources with the chest bank but never call its opening or saved-reward APIs.
The `reward` name here is only a presentation cue for the earned closed chest;
it cannot acknowledge a saved collectible. Existing correct-answer sounds and
spoken words retain their own players. No random selection, pitch variation,
new narration or Pip call is added.

While the presentation is active, music receives an additional **-6 dB** gain.
Its existing pronunciation and chest mix still apply. The celebration cues
receive **-8 dB** only while the voice player is actually playing, including a
word that begins after a cue. Stopping or naturally finishing speech restores
the cue gain without replaying it. Stopping the presentation removes only its
own music reduction and does not interrupt narration.

Mute, navigation halt, background halt, unavailable audio and inactive gameplay
stop the presentation and invalidate late cues. Muting or returning to a page
does not independently replay a stopped audio event; only the owner's explicit
restart of an unfinished visual presentation arms its cues again. Interrupted
word and phrase narration is not replayed. Missing recordings consume their timeline event
silently, without synthesized substitutes, delayed retries or blocking the
visual sequence. The owner stops audio when the visual performance finishes.

## Validation boundary

`tests/godot/round_celebration_audio_tests.gd` checks real bundled stream identity,
original pitch, bounded players, round and cue guards, word playback isolation,
exact gain changes, natural voice completion, interruption and missing-resource
behavior. It also checks that no chest state or mascot-call channel changes.
These are software playback and lifecycle checks, not subjective listening or
physical-device speaker-latency evidence. Asset inspection and waveform metadata
alone do not establish the perceived quality of the combined performance.

`round_celebration_tests.gd` checks the articulated contact sequence, shared
clock, eight wardrobes, compact layouts and reduced motion. The flow suite
exercises actual round wins, all four Pop chest counts, interruption, held
controller input, stale callbacks, player removal and reward persistence.
The focused browser suite records normal-speed Chromium canvas video with the
real mixed output, checks the three cue onsets and captures responsive layouts.
WebKit runs the same gameplay gates and rendered-frame checks. These browser
profiles are emulation, not physical-device speaker or touch-latency tests.
