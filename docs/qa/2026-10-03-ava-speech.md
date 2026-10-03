# Approved Ava voice migration

## Change

Replaced all 360 active spoken recordings: 350 vocabulary pronunciations and ten
prompts. Every file uses the user-approved `en-US-AvaNeural` preset, rate `-15%`,
pitch `+8Hz`, volume `+0%`. FFmpeg only decodes/resamples to 22050 Hz PCM16 mono.
The former browser-default Talk Quest narrator was dormant and is now removed.
Microphone recognition, gameplay rules, nonverbal Pip calls, and SFX are outside
this voice replacement.

The generator uses pinned `edge-tts==7.2.8`, two bounded workers, resumable caches,
and validated batch publication. The [active manifest](../assets/ava-voice.json)
pins the profile, scripts, and every WAV hash. The old Jungle/Candy voice hashes
remain historical rather than being silently relabeled.

## Completed checks

- All 360 spoken files differ from the pre-migration recordings. All 120 other
  WAV files in `assets/audio` and `assets/imported-audio` are byte-identical to
  the pre-migration snapshot.
- Every new recording is valid, audible PCM16 mono at 22050 Hz, has unclipped
  samples, and matches the manifest hash. Total duration: 674.01 seconds; file
  durations: 1.152 to 3.192 seconds.
- Generator tests: 14 passed. These cover catalog safety, exact preset, complete
  PCM/tail preservation, interrupted synthesis and conversion, cache identity
  and corruption, and truthful missing-only publication.
- Offline Python helper checks: exact profile, at most two workers, three
  bounded attempts, timeouts, retained completed cache, and partial-file cleanup.
- Quest/voice host tests: 123 passed. Current browser code contains no fallback
  to `speechSynthesis` or `SpeechSynthesisUtterance`.
- Asset, world-audio, and Web export tests: 54 passed.
- Native playback checks: five suites, 533 assertions, zero failures:
  UI audio flow 239, Voice Pop audio 51, Pop result audio 71,
  Talk Quest audio 147, and Pip reaction audio 25.
- Web export passed: 350 word pronunciations, 12 effects, and 230 required
  audio paths verified in the startup pack with zero failures. The build
  receipt verified 2319 source inputs and all 16 output files before browser
  verification began.
- The first export encountered an `EBUSY` conflict with a concurrent build.
  After that build ended, a fresh export completed successfully.
- Browser playback regression: eight tests passed in desktop Chromium and
  Android Chromium emulation. They cover the first trusted entry gesture,
  suspended-context and background recovery, offline playback, and Match/Memory
  cue and pronunciation timing. These checks exercise real WebAudio output and
  bundled recording identity without bypassing the normal autoplay policy.
- The final source-receipt check detected later shared-workspace edits to
  `chest_surprise.gd`, `chest_view.gd`, `talk_quest.gd`, and
  `talk_quest_reward_chest.gd`. Those later edits are outside this speech
  verification; a deployment must rebuild the current workspace first. A
  separate final hash check confirmed all 16 tested output files and all 360
  spoken source files still match the successful build receipt.

Local evidence is stored in `build/voice-migration-validation.json`,
`build/ava-node-tests.log`, `build/ava-native-tests.log`, and
`build/ava-web-build-retry.log`, and `build/ava-browser-tests.log`. The source snapshot
and caches are ignored local files and may be absent from another checkout.

## Limits

The user approved the reference Ava preview. Format, identity, and playback
checks do not replace listening to every pronunciation or testing actual phone
speakers. This migration does not claim a change in microphone recognition
accuracy. No physical-device listening test was performed for this batch.
