# Ava speech

All 1,550 vocabulary pronunciations, 330 whole-phrase recordings, and eight world
greetings use the user's approved **Ava Sweet** profile. The original vocabulary
and greetings replaced Jenny on October 3, 2026; Phrase Builder's first 36 recordings
were added on October 7 and expanded to 330 on October 9. The approved preview says
"Hello, how are you?"; its voice settings apply throughout the game catalog.

| Setting | Value |
| --- | --- |
| Voice | `en-US-AvaNeural` |
| Rate | `-15%` |
| Pitch | `+8Hz` |
| Volume | `+0%` |
| Creative postprocessing | None |
| Source WAV format | 22050 Hz, PCM16 mono WAV |

## Source and acquisition

- **Voice provider / creator:** Microsoft, Ava Neural, English (United States).
- **Original source:** Microsoft Edge online text-to-speech service,
  `speech.platform.bing.com/consumer/speech/synthesize/readaloud`.
- **Generation client:** [edge-tts 7.2.8](https://github.com/rany2/edge-tts),
  maintained by rany, licensed under LGPLv3. It is a development dependency;
  the Python client is not shipped in the game.
- **Speech terms:** Microsoft service terms apply to the synthesis service;
  see the [Microsoft Services Agreement](https://www.microsoft.com/servicesagreement).
  The client library's LGPL license and this repository's code license do not
  grant additional rights to Microsoft's voice service. The response supplies
  no separate CC0 or stock-audio license.
- **Scripts:** Original English game text from `words.json`, `phrases.json`, and
  `voice-prompts.json`. Phrases reuse existing words and receive complete spoken
  recordings, preserving natural phrase rhythm instead of concatenating word clips.
- **Acquisition status:** The selected voice was first generated as local
  previews and approved by the user. The full catalog is generated, validated,
  and integrated as repository WAV recordings, not as remote previews.
- **Animations:** Not applicable to audio recordings. Existing Pip animation
  and playback coordination are unchanged.

The active [manifest](ava-voice.json) records the voice profile, each spoken
script, and the WAV hashes. The service may evolve: the bundled recordings
are the exact delivered assets; regeneration is not guaranteed to be bit-identical.
The historical [Jungle and Candy manifest](jungle-candy-audio.json) retains the
original Jenny hashes instead of relabeling them as Ava.

## Regeneration

Install Python, FFmpeg, and the pinned generation dependency, then run:

```powershell
python -m pip install -r tools/voice-requirements.txt
node tools/generate-voices.cjs
npm run build:web
```

Set `PYTHON` to select a Python executable and use its environment's installed
dependencies. `tools/generate-voices.ps1` calls the same generator.
Use `--missing` only to add absent recordings to an already migrated catalog.
Use full generation when changing the voice profile or spoken text.

The Phrase Builder batch was acquired with `node tools/generate-voices.cjs --missing`.
All 1,258 existing recordings retained their documented bytes. Its 36 phrase
recordings remain active; three initial guide narration clips were retired.
The October 9 growth curriculum adds 300 word recordings and 294 whole phrases.
All 1,294 earlier recordings retain their exact documented bytes. The active
manifest now contains 1,888 recordings, acquired with the same `--missing` batch
workflow and approved voice settings. Every published WAV was checked for its
PCM format, audible samples and SHA-256 hash. This is technical validation, not
a claim of subjective listening review of every recording.

The generator uses at most two concurrent synthesis requests, bounded retries,
and a resumable cache keyed by the profile and spoken text in `build/voice-cache`.
It validates every result before replacing the existing batch. Unavailable
voices or failed synthesis produce an explicit error; there is no alternate
voice fallback. FFmpeg only decodes and resamples to the existing mobile format.
It does not apply the former Jenny style, EQ, pitch shifting, or silence trimming.
The audited picture-naming phrase "A kite." is retained for `word-kite`.
New heteronyms use a short grammatical context, such as "To tear.", "To close.",
"A present.", and "One minute.", to convey the authored sense. These exact
synthesis scripts are recorded in the manifest; no audio editing is applied.

## Runtime coverage

Match, Memory, Voice Pop, Phrase Builder, and the vocabulary library play bundled
pronunciations through `GameAudio.say`. Phrase Builder plays its 330 whole-phrase
clips and individual word pronunciations without spoken guide narration.
Eight world greetings use the same profile. Match no longer includes spoken
wrong-answer feedback or a loss prompt. Gameplay
never asks the operating system to choose a different speaking voice.

Pip's duck calls, music, chest sounds, and other nonverbal sound effects remain
their existing recordings. All speech stays in the startup game pack, so
playback does not download speech or contact the synthesis service. Godot keeps
the existing compressed audio import settings without changing speech pitch or speed.
