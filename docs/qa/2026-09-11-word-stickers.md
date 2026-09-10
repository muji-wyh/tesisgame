# Word stickers release QA

## Scope

Correct target words now become unique stickers in My rewards > Words. The album
covers the existing 140 nouns in twelve topics, uses the canonical word image and
audio, and can display a collected word in Pip's room. Learn and correction images
are pronunciation controls. Browsing, mistakes, unmatched cards and Memory Study
do not grant stickers; medal and chest rules remain unchanged.

Playroom saves gain an optional validated sticker section. Existing saves migrate
without losing room, medal, favorite or journey choices. Failed writes preserve
pending correct discoveries for Retry in Words during the current session.

## Verification

- The new scene test first failed on the absent Words album, then passed through
  actual Match, Sky, Listen, Memory and spoken Match paths, save retry, modal guards
  and narrow layouts.
- Independent review reproduced disabled picture and room-sticker focus traps
  through actual mouse and Enter events. Fixes remove disabled controls from focus
  and restore current audio/focus rules after closing rewards. The expanded scene
  regression passes 47 assertions.
- Existing collection controller regression caught fixed header tabs being treated
  as scrolled content. All header controls now retain the header navigation row.
- The first exported Chromium smoke passed both new scenarios: real picture click,
  Match discovery, reload persistence, 320px album, keyboard Display with Pip and
  topic navigation. Rendered screenshots show the correct root/cat associations and
  readable touch controls without overlap.

Final `npm test` passed: **25 native suites, 12,563 checks/assertions, zero failures**;
Node **97 passed, 1 existing external-source skip**. `npm run build:web` passed with
Godot **4.7.1** and a **10.97 MB startup payload**, with 28 optional audio assets.
Independent integration review found no remaining blockers after the focus fixes.

The tested build at port 4181 has:

- HTML SHA256: `4f732572fe4dbf5ab9ca6db999b4d5de9703281e1fc32f68932b5df8aaafdfb7`
- Pack: `game-f2b0bf405e5b8e27.pck`
- Pack SHA256: `f2b0bf405e5b8e27e282531600c6bc92d1549a974723ea70ccc17fb57f0d421e`

Final exported-browser regression: **27 passed** across desktop Chromium,
iPhone WebKit and iPad WebKit profiles. It covers real picture pronunciation,
correct Match collection and reload, 320px keyboard album/display/topic controls,
self-paced feedback, unavailable audio, a full Memory win, denied reward storage,
failed victory save retry, and final/interim speech behavior. Evidence is in
`build/word-stickers-browser-final.log` and `build/qa-word-stickers/`.

Implementation commit: `ebffd2e` (merged to main and pushed). Deployment through
`npm run deploy -- -SkipBuild` succeeded at
https://gentle-forest-02ff42900.3.azurestaticapps.net/.

`node build/verify-ui-release.cjs <origin>` verified matching HTML and pack hashes
for the tested port 4181, local preview port 4173 and production. The tested export
was copied to the local preview with `index.html` last.

Production Chromium smoke: **2 passed**, through actual picture pronunciation,
Match collection, reload persistence, 320px album keyboard controls, displaying a
word with Pip and topic navigation. Logs/screenshots are in
`build/word-stickers-production-smoke.log` and `build/qa-word-stickers-production/`.
Both checkouts retain the tested gameplay source; the release-note follow-up only
records this evidence. The unrelated main-checkout `%ALLUSERSPROFILE%/` directory
was preserved.

## Outstanding external requirement and limits

Windows Computer Use reached the free Food Icons Pack listing and clicked Add to
My Assets. Unity redirected stable Chrome to sign-in; the user must finish that
authentication. The separate in-app browser connector still reports missing Codex
auth token. No package was acquired, imported through Unity CLI, or shipped in this
release. The earlier explicit Unity acquisition/import requirement stays open.

No real browser profile or save was cleared or changed by QA; Playwright uses
isolated contexts. Canary's initial WASM compilation delay is not claimed fixed.
WebKit profiles do not substitute for physical iPhone/iPad verification.
