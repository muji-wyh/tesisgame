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

The closed chest reuses the current world's integrated chest art. The
Royal, Energy and Crystal designs come from the user-provided Modern 2D Animated
Chests Pack_FREE Demo 1.0.2. Its original source paths and file hashes are
recorded in `assets/chests/SOURCE.txt` and `assets/chests/manifest.json`; those
records do not independently identify an artist or assert additional rights.
The five other world designs retain the acquired models and Unity Asset Store
Standard EULA records in `assets/chests/downloaded/manifest.json`. Previewing
a closed chest does not invoke its charge, opening, persistence or saved-reward
callbacks.

## Performance and completion

`RoundCelebration` samples one three-second clock. Pip appears at the center,
prepares through 0.25 s, leaps and lands feet first through 0.9 s, then makes
two happy steps and a wink. From 1.46 to 1.78 s the whole attached character
moves quickly to its final side position. The closed chest enters at 1.8 s,
descends at its final size, and makes a small settling rebound through 2.42 s.
It remains rigid; the entrance does not scale its body or operate its lid.
The earned-chest heading follows the landing, then the hold-to-open caption
appears through 2.72 s. The real chest becomes available at the existing
three-second/narration gate. The invitation keeps only subtle breathing and
occasional blinking. Outside Phrase Builder, previously unannounced earned chests
also reveal full-screen paper from 1.8 to 3 s,
using the shared renderer and existing licensed atlas documented in
[Jelly chest fragments](jelly-fragments.md). The burst ends independently of
long pronunciation and never captures input. Phrase Builder clears its gameplay
paper when this page opens and shows the entire invitation without confetti.
Reduced motion keeps Pip and the chest in fixed final positions, revealing
the chest and invitation in the same order without travel, rebound, halo or
confetti. These changes reuse the inspected integrated Pip growth artwork,
closed chest models/textures and portal glow above; no assets are acquired or
replaced. The available Pip poses and source chest clips remain unchanged.

`GameUI` owns the round identity, interruptions and input gate. Every mode uses
the shared settlement modal over its completed board; standalone result pages
are removed. Match, Memory and Phrase Builder keep this performance inside the
modal and wait for both the performance and final pronunciation before enabling
the real chest in place. There is no Open chest button or extra confirmation.
`RoundRewardLayout` gives the preview and settlement the same final Pip, chest,
title and instruction rectangles, keeping both subjects still across the handoff.
Scored results share an additional compact summary row. The existing hold
gesture drives the cavity glow, opening, cancellation, audio and durable reward save;
finishing the celebration never opens or awards treasure automatically. Phrase
accepts completion at this automatic handoff. Match and Memory
also celebrate rounds without treasure, omitting the chest and confetti before
offering Play again. Presentation never saves rewards or opens a chest.
Home remains available throughout the performance. Leaving uses the host's
existing completed-round settlement, stops the presentation and invalidates
late callbacks; a held Accept button never becomes an automatic Home press.

The direct chest target has no rectangular button or focus border. Keyboard focus
and pointer hover brighten the same acquired Bobardo `portal_glow.png` texture
used by Jelly and Pop settlement, with the existing source and license record in
[Jelly Finish](jelly-finish.md). This integrated static texture receives only
runtime placement and opacity changes; no new artwork or source animation is added.

Voice Pop and both Jelly modes use the same performance when a finished round
has a successfully saved chest. Voice Pop stops recognition and each mode saves
its final chest identity and tier before starting. The exact score and completed
word total remain visible during the performance. A save error shows its recovery
controls directly; restored inventory and zero-chest results remain immediate.
Already announced gameplay milestones do not replay their reward cue or confetti.
Jelly Finish uses
`Round complete`; danger expiry uses `Game over`. Earned chests open inside the
modal. Jelly `Play again` collects pending chest coins before starting a new
round. Pop `Play again` also settles its unopened treasure and returns to its
microphone gate. `Home` settles pending treasure before leaving any completed
round, and selecting that game again starts a fresh board. Live games still pause
and offer `Continue` on Home.

Pop and Jelly settlement keep the score, completed-word total and earned level
in the shared summary row above Pip and the reward. The chest artwork is the hold target; `Hold to open`
is plain, non-interactive text below it. Keyboard focus brightens the existing
chest glow instead of outlining the instruction. The compact modal keeps its
footer reachable and uses the same companion stage on phones and short landscapes.
The result selects the final chest by this round's saved reward identity, including
after a save retry or inventory reload. Earlier unopened treasure stays intact;
unfinished upgrade presentations never determine the settlement's chest level.

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
beats. An earned chest hands off once to the direct hold target. A completed
no-chest invitation preserves its ready state. Neither completion replays the
performance or its sounds when an overlay or background pause ends.

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
