# Lv3 vocabulary artwork

The 69 pictured words in the age-three cohort now use larger, dimensional
illustrations. The eleven context-only words retain their existing treatment.
No vocabulary, level progression, pronunciation or answer rule changes.

## Acquired material

- **Microsoft Fluent Emoji:** 46 static 3D illustrations by Microsoft Corporation,
  acquired from revision `1ffb34c752ecf5d402f04cfb4b392c77f57c54bc` under MIT.
  Transparent margins are normalized. The doll is cropped to the single female
  figure from the Japanese dolls illustration. Parent images show adults caring
  for a baby. They depict a relationship through a familiar activity.
- **Kenney:** 23 offline Blender scene renders use the CC0 Food Kit 2.0,
  Furniture Kit 2.0, Animated Characters Protagonists 1.1 and Toy Car Kit 1.2.
  Acquired meshes are smoothed, posed, composed and lit in Blender 5.2.2 LTS.
  The plain clothing, selected hair extension, contained liquid and comparison
  pointers are local adaptations. The character source includes idle, jump and
  run animations; only static pictures ship.

Exact source URLs, archive hashes, per-picture hashes, changes and licenses are
recorded in [the manifest](lv3-vocabulary.json) and [license folder](licenses/).
No image generation API was used. Preview-only and rejected model studies remain
in the ignored local review directory; they are not shipped as vocabulary art.

## Selection and composition

Actions and relationships are checked beside their confusable words: open/close,
walk/run/jump, mother/father, in/on and big/small. The door scenes use the same
hinged source door, with the hand positioned against the leaf. Counting pictures
contain exactly one, two or three apples. Comparison pointers identify the intended
size. Pictured words contain no written answer.

All deliverables are transparent 256-pixel PNGs with a consistent safe margin.
Jelly allocates more space to the picture and moves its treasure marker away from
the central subject. The same images are used by Match, Memory, Phrase Builder,
Voice Pop and the vocabulary catalogue through `GameData.load_all`.
Original illustrations remain as historical source/fallback material, preserving
the existing licensed import and curriculum provenance checks.

## Local review and reproduction

The comparison gallery is `build/word-art-review/index.html`, served only on
localhost port 41775. It compares the previous and updated pictures at 48, 80 and
120 pixels. It is outside the Web export and has no production route.

The Blender scripts in `tools/vocabulary-art/` expect the four acquired packs in
`build/word-art-review/model-source/`, in folders matching their manifest IDs.
The renderer reads the retained skin adaptations directly from its `skins/` folder.
Run Blender in background mode with `--python-exit-code 1` and
`--python tools/vocabulary-art/render-scenes.py -- <word IDs>`.
The scripts write transparent source renders and editable `.blend` scenes under
`build/word-art-review/blender-study/`; those files stay local.
Without word IDs, the scene renderer produces all 23 selected Blender pictures.
For the final cards, trim transparent margins at threshold 8, fit each image
inside 232 by 232 pixels with its aspect ratio preserved, then add 12 transparent
pixels on each side. The Fluent doll crop is recorded in its manifest entry and
applies before trimming. Final PNG hashes are recorded after this normalization.

The importer verifies all 69 final images with `node tools/lv3-vocabulary-art.cjs`.
The Web builder also runs that check, and the exported-pack check requires every
replacement at its original 256-pixel size. Existing higher-level source importers
continue to validate the historical illustrations and curriculum independently.
