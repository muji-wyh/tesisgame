# Chest unlock charge — 2026-09-24

The existing 1.2-second hold now shows a theme-colored progress ring, 24 ticks,
a stable percentage badge, bounded inward sparks, and an outward unlock burst.
The chest remains visible below the badge on short layouts. Reduced motion keeps
the percentage and static ring without shake, moving sparks, or the burst.
The existing 1.8-second reveal and saved fragment/toy unlock rules are retained.

One deferred audio channel plays a cached 0.28-second synthesized pulse. Actual
hold progress raises pitch from 0.82 to 2.4, accelerates pulses from approximately
2.9 to 8.6 per second, and raises gain. A 0.44-second completion chord blends with
the original theme-open effect. The two mono samples occupy less than 32 KiB in
memory and add no downloadable audio assets. Canceling, muting, or halting audio
stops the charge immediately; stale progress cannot rearm it.

Mouse, touch, keyboard and controller use the existing hold path. Duplicate start
notifications retain elapsed progress. Release, drag, More, backgrounding, browser
input cancellation and window blur stop the charge. Browser accessibility exposes
real progress in 5% increments without continuous live-region announcements.
Escape/controller B also cancel an active hold; controller A must be released
before another controller hold begins.

## Validation

- `chest_reveal_tests.gd`: 577 assertions passed. All eight themes across six stage
  dimensions, including 320×72 and 180×120; readable text and bounded artwork,
  cancellation, reduced motion, and one opening notification at the existing time.
  Phone stages place the badge on the right to clear the world label; wider stages
  retain the centered badge. Alignment remains stable across percentage digits.
- `chest_audio_tests.gd`: 35 assertions passed, covering actual native playback,
  progression without restart, silent sample boundaries, unclipped audio,
  cache/channel reuse, completion once, mute/halt and late callback suppression.
- `chest_charge_flow_tests.gd`: 72 assertions passed through real scene wins,
  duplicate input, cancel/rehold, mouse/touch drag, More, background, new-round
  auto-claim, controller release/disconnect/cancel, reduced motion and saved rewards.
  All three suites run together via `npm run test:chest-charge` (684 assertions).
- Existing native suites passed: medal scene (46), UI audio flow (98), UI recovery
  (36), Medals removal (74), gift adventure (130), Pip audio (48), Pop narration (60).
- Web export and chest asset Node contracts: 31 tests passed.

- Final Web export succeeded: 13.66 MB startup, 87 on-demand audio assets; existing
  multiplayer models remain 112.34 MB on demand. No new audio files were added.
- Chromium observation confirms actual audible, unclipped 0.28-second charge
  samples for each hold and exactly one 0.44-second completion accent. Godot Web
  implements looping by restarting buffer sources, so the check uses duration and
  waveform identity rather than `AudioBufferSourceNode.loop`.
- Six browser scenarios passed against the final export: normal and reduced
  motion in desktop Chromium, iPhone-sized WebKit, and iPad-sized WebKit. They use
  actual Match wins and hold/release gestures, preserve one saved piece through a
  repeated hold and navigation, and capture charging/opening/opened screenshots.
  The normal mobile runs use Summer to verify the widest world badge stays clear.
- Evidence: `build/chest-charge-browser-final/` and
  `build/chest-charge-webkit-final/`; results in the matching `.log` files.
  Native and packaging logs are `build/chest-charge-native.log`,
  `build/chest-contract-tests.log`, and `build/chest-charge-export.log`.
- The Windows Playwright WebKit runtime exposes no WebAudio. Its UI/reward tests
  therefore assert the sound-unavailable fallback; Safari sound on physical Apple
  devices remains unverified. Browser emulation does not establish physical-device
  performance or subjective audio quality.
