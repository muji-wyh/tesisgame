# Voice Pop slice feedback

## Implementation and scope

Reference: the user-provided `fruit_ninja.mp4` (56.8 seconds). The blade and fruit
impacts informed the movement implemented in the existing Godot 2D renderer.
The recording contains a composited picture and one
mixed audio track: it does not supply transparent effects or isolated stems.

1. Three premixed hit variants use short blade and cut excerpts with filtering
   and fades. Source and output hashes retain the private-audio import provenance.
2. A tapered curved blade, actual illustration fragments, colored droplets,
   cut edges, and weighted descent keep the word readable on the lower fragment.
3. The struck target holds for 44 milliseconds before its fragments separate.
   The rest of the game, the speech recognizer, and the round clock keep running.
4. Three fixed, preloaded hit channels preserve short tails during a multiword
   hit, bound overlap, and stop on mode exit or background.

The original slice-feedback change preserved recognition, scoring, vocabulary
and throw timing. Voice Pop now starts with 50 seconds, adds time at the second
and third streak hits, and occasionally throws two or three words together;
see the current gameplay rules in the README. Slice feedback starts when a hit
is accepted. The [speech matcher](voice-matching.md) separately applies the
interim stability window and candidate deduplication. Slice feedback does not
change recognition accuracy or introduce gesture controls.

## Presentation

The removed target supplies its exact center, size, rotation, word, and artwork.
Clipping the source geometry and texture coordinates preserves the two real
halves. The word stays whole on the lower half. Cut edges, an outward impulse,
opposing rotation, gravity, and a short fade make the result readable.

The blade lasts 140 milliseconds; fragments finish within 780 milliseconds.
At most six effects remain active, and their geometry is clipped to the play
arena. High throws and their cuts can overlap the field HUD; time-bonus feedback
stays in the foreground. Effect variation uses
the throw ID rather than the gameplay random generator. Reduced motion uses a
stationary cut mark and score, with no flying pieces or particles.
Consecutive hits widen the outer glow and increase splash spread by up to 20%
at six hits, using actual combo metadata. Card movement and sound gain stay
unchanged. Normal recognition rollover lets a newly earned cut finish; an
actual microphone error, menu visit, or background transition clears it.

Pip keeps the happy jump on a successful Voice Pop hit, while the blade and cut
recording supplies the hit sound. Hits do not play Pip's happy call. Missed
targets retain Pip's sad animation and call; Match and Memory feedback are
unchanged.

See [audio provenance and reproduction](assets/voice-pop-reference-audio.md)
and the [sample manifest](assets/voice-pop-reference-audio.json).

## Validation record

The following measurements record the initial reference-slice release, before
the Voice Pop happy hit call was removed. Its captured mix and export hash are
historical release evidence rather than measurements of the current hit mix.

Native checks passed: Voice Pop model (20,779), scene (812), slice geometry and
lifecycle (731), reference audio (31), report narration (63), UI audio flow
(158), Pip feedback (99), and shared chest audio (2,648). Existing narration and
Pip suites still report ObjectDB cleanup warnings after passing their checks.

Node checks passed: 89 tests across the browser speech host, voice assets,
reference extraction, test inventory, and export validation. The export rejects
partial reference banks, mismatched hashes, malformed WAVs, and invalid imports.

The deterministic capture uses the real main scene and gameplay audio wiring.
Desktop frames were reviewed for the retained picture, whole lower word,
separation, falling pieces, and two simultaneous cuts. Portrait stages use the
same renderer at 390 by 844 pixels. The desktop mixed recording is 4.517 seconds
at 60 fps, with a measured -10.1 dBFS encoded sample peak. Run
`node tools/capture-voice-pop-slice.cjs` to regenerate the local review artifacts.
Godot Movie Maker fixes its movie dimensions before the portrait script resizes
the viewport; the gallery therefore uses validated native portrait PNGs rather
than presenting a stretched portrait movie.

The Web export passed pack verification, including selection of all three
reference clips and 320 required source/import resource paths. The resulting
pack is `game-73048aa29451caaa.pck`; compressed startup resources total 19.21 MB.

Ten focused browser cases passed across desktop Chromium and iPhone/iPad
WebKit emulation: permission denial/retry, a complete 30-second round and report,
mode-switch audio, multiword hits, background cleanup, both compact orientations,
and reduced motion. The simultaneous-hit check observed three distinct PCM
sources starting at the same AudioContext time, each retaining its complete
tail. A second burst stopped all three channels when the page was hidden. No
separate audio downloads occurred, and finalizing the same recognition did not
replay any cut.

Automated speech fixtures exercise recognition callbacks without using a real
microphone. WebKit emulation on Windows does not verify real Safari audio.
Physical-device listening and microphone feedback remain manual checks; source
waveforms and runtime playback evidence do not substitute for subjective audio
review.
