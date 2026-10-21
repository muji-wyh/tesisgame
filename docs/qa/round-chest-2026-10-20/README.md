# Round chest arrival review

The requested sequence is shared by earned-chest endings in Match, Memory,
Phrase Builder, Voice Pop, Jelly Match and Word Jelly:

- Pip appears in the center and performs the existing articulated celebration.
- From 1.46 to 1.78 seconds Pip moves quickly to the side.
- The real closed chest artwork arrives from 1.8 seconds and settles by 2.42.
- The earned heading and hold-to-open instruction follow. The existing
  three-second and final-pronunciation gates still control the real chest.

The preview and interactive result share geometry, title and instruction copy.
Scored modes also share their actual points, completed words and final chest
level. Final reward identity, reward quantities, durable saves, hold-to-open
mechanics and restored inventory are preserved. A failed save exposes recovery
directly; zero-chest Pop/Jelly results do not invent a chest performance.
Reduced motion reveals still artwork in order without travel or rebound.
Home stays available during the performance and uses the existing exactly-once
completed-round settlement when the player leaves early.

## Material

This change reuses integrated project Pip growth art, acquired chest models and
textures, portal glow and the existing three audio cues. No artwork or audio is
acquired or replaced. Sources, creators, rights, acquisition status and existing
animations remain in [the round celebration record](../../assets/round-celebration.md),
[Pip growth](../../assets/pip-growth.md) and [chest replacement](../../assets/chest-refresh.md).

## Baseline

`build/round-chest-20261020/preimages/` preserves the pre-edit source, including
earlier uncommitted polish. The existing compiled Web build was used for actual
desktop Match and phone Pop completion captures, with 22 sampled frames, two
final images and runtime timelines. Match began with Pip already at the side;
Pop displayed its reward immediately.

The two baseline WebM files were invalid because the review harness decoded the
MediaRecorder data URL incorrectly. They are not motion or audio evidence. The
PNG frames and timelines remain intact. The decoder now checks byte length and
the WebM header before accepting a recording.

## Native verification

All 11 focused Godot suites passed, totaling 4,798 assertions/checks:

| Suite | Passed |
| --- | ---: |
| Round celebration | 108 |
| Round celebration flow | 437 |
| Round celebration audio | 52 |
| Pop reward flow | 174 |
| Pop reward room | 1,126 |
| Treasure scrolling | 53 |
| Jelly Match flow | 423 |
| Settlement modal | 594 |
| Danger game over | 688 |
| Jelly result coins | 516 |
| Queued-upgrade settlement | 627 |

The flow cases cover final saved chest identity/tier, narration, held input,
pause/resume, early Home, stale callbacks, storage recovery and exactly-once
settlement. Final runs contain no script errors or leaked-resource reports.
The audio test now awaits the real player's bounded `finished` signal rather
than assuming a recording has completed after a fixed 250 ms. Runtime audio
and its exact gain assertions are unchanged.

`build/round-chest-20261020/native/` contains 58 rendered actual-game frames
at 1000x800, 390x844, 844x390 and 568x320, including all six interactive
results and sampled Match/Pop sequence stages. Pop earns its level-three chest
through 14 real fragment awards. The report records stages, companion geometry,
saved reward data and the renderer. The capture uses isolated saves, seeded
gameplay, simulated microphone readiness, muted audio and manually advanced
clocks; it is rendered composition/state evidence, not natural timing or speech
recognition evidence. The extra age-11 frames explicitly select that appearance.

The first 58-frame run inherited the system's reduced-animation setting and is
preserved separately in `native-reduced/`. The normal-motion harness explicitly
disables that setting after the application is ready and asserts it in every
active sequence snapshot. The initial reward-room review passed 69 checks over
20 frames. The final retained-inventory/pager review passed another 37 checks
over eight frames at 1280x800, 390x844, 320x568 and 568x320. No partial pager is
visible in the initial result; scrolling exposes complete Previous/Next controls
above the fixed Home/Play again row. The final frames were visually inspected.

## Browser verification

`npm run build:web` completed successfully. The local build receipt is
`build/web-build.json`, created at `2026-10-20T14:16:23.740Z`; its main pack is
`game-29989a17b6e9395f.pck.br`. Core startup is 37.08 MB plus the selected age
pack. Export resource checks passed, including the required audio resources.
The fresh build is served locally at `http://127.0.0.1:41773/`.

All five maintained Chromium scenarios have passing results on the fresh build:
Match, Memory, Voice Pop, Jelly Match and Word Jelly. They cover the ordered
performance, the pronunciation gate, actual earned reward identity/tier,
unopened handoff, bundled audio and absence of runtime/console errors. Match
also checks responsive layouts. Match and Memory follow completed-round Home
behavior: settle the earned reward once, then start a fresh round on reentry.
The final Match check verifies both the exact 50-coin receipt and its captured
legacy medal fragment, with no second award on reentry.
Chromium Memory's passing round awarded no chest and exercised Play again;
earned-chest handoff was exercised by Match, Pop and both Jelly scenarios.

The browser test budget accommodates software-rendered canvas startup and
responsive checks; individual event assertions retain their own bounds.
Responsive geometry allows less than 0.01 logical units of floating-point
rounding. The saved-progress parser reads complete multiline dictionaries.
Earlier attempts with stale layout, Home and legacy-reward assertions are
preserved separately from the successful targeted reruns. Desktop Pop's actual
browser dance, side placement and final invitation frames were visually
inspected without clipping or overlap.

The two focused 390x844 Chromium captures completed without page/console errors.
Phone Voice Pop earned a level-one chest through real accepted words and
retains 11 normal-speed frames, its runtime timeline and a 354,011-byte WebM
with the real mixed audio track. The observed stages are celebration, side
step, chest arrival, invitation and unopened handoff. The dance, arriving
chest, landed chest and final invitation frames were visually inspected.

Phone Match with reduced motion retained 11 frames and a 347,770-byte WebM.
That real round awarded no chest: it verifies the fixed-position companion
and no-chest Play again path, not a browser reduced-motion chest arrival.
Reduced-motion earned-chest presentation is covered by the native suites and
separately labeled native captures above. These phone profiles are browser
emulation, not physical devices; Voice Pop uses simulated speech readiness
and accepted transcript events, not a physical microphone.

The iPhone WebKit Match scenario passed in 37.8 seconds. That round awarded
no chest and verified actual rendered frames, completion gates, Play again,
unchanged wallet and fresh-round reentry. It is not WebKit earned-chest
handoff evidence.

Both phone recordings and complete capture metadata are under
`build/round-chest-20261020/after/`. Each saved WebM passed byte-length, Blob-size
and EBML-header checks, followed by ffprobe inspection and a complete ffmpeg
decode including audio. Packet timestamps span 7.232 seconds for Pop and 6.997
seconds for reduced Match. Unlike the invalid baseline WebMs, these are valid
natural-playback recordings. The frames were visually inspected; container,
signal and decode checks do not establish subjective audio quality or
physical-device latency. No subjective listening claim is made.

The portable review clip is `after/pip-earned-chest-phone.mp4`: 7.232 seconds,
390x844, H.264 at 30 fps with AAC stereo at 48 kHz, 220,410 bytes. Conversion
preserves the source color range, and the final MP4 fully decodes without
errors. Its extracted sequence was visually inspected. The mixed output is
non-silent (measured peak -16.1 dB). The original WebM remains available beside
the MP4, along with the contact sheet, metadata and decode logs.

Final browser logs are `maintained-match-final.log` (Match),
`maintained-match-memory.log` (Memory pass alongside the earlier Match harness
failure), `maintained-chromium-retry.log` (Pop and both Jelly passes alongside
earlier Match/Memory harness failures), `maintained-webkit.log`, and
`phone-evidence.log`, all under `build/round-chest-20261020/`. Runtime sources
did not change after the successful Web export. The change is locally built;
this review does not claim a production deployment.
