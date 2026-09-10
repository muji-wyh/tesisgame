# Learning and playroom verification — September 10, 2026

The release keeps Godot 4.7.1 and the existing Azure Static Web App. It adds Learn,
stable five-word lessons, persistent picture/word feedback, and playable rewards.
It uses the original illustrations; new Unity Store acquisition/import is pending.

## Native and tooling checks

`npm test` passed on Windows with Node 24 and Godot 4.7.1:

- 5,475 Godot assertions/checks across model, scene, input, learning and save suites.
- 89 Node tests passed; one existing chest-source rerun test skipped because its
  external source package is unavailable. The imported chest-file/parser checks passed.
- The Unity archive/import tool has 24 passing checks, including path validation,
  selected hashes, complete override replacement, and tamper/junction rejection.
  These checks do not constitute acquisition or a real Unity Editor import.

The final audio regression reproduced and fixed an optional-music failure disabling
the bundled word Hear buttons. Genuine word playback failure still reveals the
Listen target; later music success cannot erase that fallback.

## Browser and visual checks

Browser verification covers desktop Chromium, iPhone WebKit, and iPad WebKit using the committed tests:
`godot.spec.cjs`, `learning.spec.cjs`, `expansion.spec.cjs`, `voice.spec.cjs`,
`loading.spec.cjs`, and `collection-scroll.spec.cjs`.

The combined matrix covers 243 unique cases: **225 passed, 18 expected skips**,
with no unresolved failures. Suites ran in batches; final affected cases were
repeated against the frozen release export.

| Coverage | Passed | Expected skips |
| --- | ---: | ---: |
| General gameplay, input, saves, audio and rewards | 110 | 10 |
| Learn, Match correction, Sky and silent Listen | 12 | 0 |
| Playroom, ownership, migration and persistence | 21 | 0 |
| Voice, loading and collection scrolling | 82 | 8 |

Ten skips are WebAudio-only cases in this Windows WebKit runtime, which exposes no
AudioContext; its silent-play paths still run. Eight are CDP-only touch cases on
WebKit. Chromium verifies real pronunciation and optional-audio failure/retry.
Timing failures were resolved with distinct-status/render waits or isolated reruns;
assertions were retained. The final room/learning replay passed 11/11 cases, and the
final desktop Hear-after-music-failure and loss/review replay passed 3/3.

The inspected artwork contact sheet contains the twelve revised original nouns.
Learning checks inspect actual canvas screenshots and confirm five lesson words,
mode continuity, self-paced feedback, explicit Continue, and unavailable-audio text.
Room checks cover locked gifts, toy actions, backdrop/favorite persistence, legacy
migration, save errors/retries, scrolling, reduced motion, and phone/tablet layouts.

## Release status

The final web export passed its startup-pack checks: 140 word pronunciations,
56 optional paths, 10.86 MB startup transfer and 28 on-demand audio assets.

Local release smoke passed Learn pronunciation, Match selection/cancel, Sky
feedback/Continue, Listen, and the starter room action/save with no browser errors.
The served pack matches the local file:

- Pack: `game-9610359c806410fe.pck`
- SHA256: `9610359c806410fe8b7f17531bfa8861894532a0e70cb65128769f551a05cef5`

Feature commit `3c0c712` was fast-forward merged into `main` and pushed to origin.
`npm run deploy -- -SkipBuild` successfully published this tested export to
[the production game](https://gentle-forest-02ff42900.3.azurestaticapps.net/).

Production verification passed against that URL: the served HTML names the same
pack and the downloaded pack's SHA256 matches the value above. A fresh Chromium
390 × 650 session passed Learn pronunciation, Match selection/cancel, Sky
feedback/Continue, Listen, and the starter room interaction/save, with no browser
errors. Local evidence is in `build/learning-production-release-check.log` and
`build/visuals/release-learn.png` / `release-room.png`.

The Unity acquisition step remains pending after the user stopped Computer Use.
No newly downloaded Unity package, actual CLI import, or licensed PNG override is
included. See [the provenance record](../assets/unity-art.md) for verified free
candidates and the import procedure.
