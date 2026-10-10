# Expanded vocabulary artwork: original 900-word batch

The October 2026 expansion adds 300 words to each existing age level. All 350
earlier entries retain their IDs, levels, pictures, and recordings. The resulting
catalog contains 448 basic, 412 growing, and 390 advanced words (1,250 total).
The age bands were editorial guides, not a standardized proficiency assessment.
The subsequent [growth curriculum](../vocabulary/growth-curriculum.md) reorganizes
all entries into ten tiers and adds 300 more words. This document and its manifest
remain the source record for the original 900-picture batch; the additional 35
pictures have a [separate source record](growth-vocabulary.md).
Current stills and animated adaptations are documented in the
[complete vocabulary artwork library](word-library.md).

## Sources and license

- Original source: [Mulberry Symbols](https://mulberrysymbols.org/),
  [source repository](https://github.com/mulberrysymbols/mulberry-symbols).
- Pinned revision: `9cbab9f400c5de44e2bc58839cca07294aadb086`.
- Creator/copyright: Steve Lee, 2018–2026. The original symbol design project
  originated with Garry Paxton; the source project's history credits graphic
  artists, speech and language therapists, and community contributors.
- License: [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
  The sourced illustrations and their raster adaptations retain this license;
  it is separate from the game's code license.
- Acquisition: the pinned repository was downloaded locally and selected source
  illustrations were inspected in contact sheets before integration. The game
  bundles the converted pictures; it does not load remote preview images.
- Conversion: selected original SVGs are rasterized to transparent 192-pixel PNGs
  to preserve their colors, geometry, and CSS consistently in Godot. No substitute
  artwork or generated geometric placeholders were created.
- Source animations: none. This original batch acquired static educational
  illustrations. Current locally authored illustration motion is recorded in
  the complete-library manifest and retains the source license.

The [machine-readable manifest](mulberry-vocabulary.json) records every original
file URL, original hash, integrated path, output hash, and renderer version.
The published game's Art credits page provides attribution and links to these
sources and adapted assets. Adapted images are freely available in
`assets/images/words` under the same CC BY-SA 4.0 license.

## Editorial coverage

The [basic](../vocabulary/basic-expansion.json),
[growing](../vocabulary/growing-expansion.json), and
[advanced](../vocabulary/advanced-expansion.json) manifests each contain exactly
300 additions. Every addition specifies its level, part of speech, intended
meaning, illustration source, topic, and any manually identified confusing pairs.
The imported runtime catalog remains `words.json`; the editorial manifests are
build inputs, not a second runtime vocabulary.

Actions and descriptions use the source's corresponding action/state illustration.
Number, shape, and position words use educational diagrams for those actual
concepts. Similar pictures or meanings are excluded from the same board when
marked confusable. Speech matching accepts the intended word and its explicit
homophones; noun plural rules are not applied to verbs or adjectives.

## Reproduction

Use the pinned Mulberry checkout and a local Sharp installation:

```powershell
node tools/import-vocabulary.cjs C:/path/to/mulberry-symbols --sharp C:/path/to/node_modules/sharp
node tools/import-vocabulary.cjs --check
node tools/generate-voices.cjs --missing
npm run import
npm run test:ages
npm run build:web
```

Ordinary builds use the checked-in PNGs and WAVs and require no asset download,
rasterizer, or speech synthesis service. The pronunciation source and approved
settings are documented in [Ava speech](ava-voice.md).
