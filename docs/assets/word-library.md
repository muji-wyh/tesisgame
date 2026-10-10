# Complete vocabulary picture library

The active curriculum uses 1,285 reviewed, animated pictures across ages 3 through 12+.
The other 265 words retain text-in-context practice because an isolated picture
would not teach their intended meaning. No word IDs, age assignments, audio,
practice rules or mastery progress are changed by this artwork release.

## Visual direction and acquired sources

Common objects, animals and expressive faces use acquired Microsoft Fluent Emoji
3D illustrations (MIT). Character and prop scenes use the acquired Kenney CC0
models described in [the Lv3 source record](lv3-vocabulary.json). Eight actions
have [joint-based teaching animation](lv3-motion-studies.md), with keyed bright
and delighted smiles, pleased closed-eye reactions, timed blinks, generous body
gestures and a readable completion pose.

Actions, spatial relationships and other educational concepts use adapted
Mulberry Symbols by Steve Lee, from the project originally designed by Garry
Paxton (CC BY-SA 4.0). The original teaching geometry and comparison cues are
retained. Outlines are softened, fluorescent colors moderated, and individual
filled shapes receive gentle shading. Specific color corrections make pink
distinct from peach and sausages distinct from bananas. The adapted pictures
remain CC BY-SA 4.0.

Specialist natural-world, geography and science vocabulary uses separately
reviewed photographs or educational illustrations where the above collections
do not have an accurate source. Each creator, original source page, download
hash, license, crop and transformation is recorded in
[word-library.json](word-library.json). This collection uses acquired artwork,
not newly drawn illustrations. No image-generation API is used.

Source selections reject misleading filenames and meanings, such as a woodworking
plane for an aircraft, underwear for trousers, and an architectural diagram for
a toe. The same picture is not reused for two distinct curriculum words.

## Runtime delivery

Every pictured word resolves through `GameData.load_all` to
`assets/images/word-library/<id>.webp`. Each still picture is 256 by 256 pixels,
fitted into 232 pixels with 12-pixel transparent margins. Photos retain the
subject's real surroundings where those surroundings explain the concept.
Cards share the same texture across Match, Memory, Phrase Builder, Voice Pop,
Jelly Match and the vocabulary catalogue.

Every pictured word has a shared 128-pixel animation atlas. The eight articulated
Blender actions retain 24 fps. The remaining 1,277 illustrations have 32-frame,
12 fps loops, with explicit per-word motion assignments in
`tools/vocabulary-art/library-motion-map.json`. These are illustration animations,
not newly rigged 3D models. A short preparation leads to a clear accent, a smaller
follow-through and a reading hold. Plants and fabric swish from their supports,
aquatic subjects dart into a glide, and grounded animals perk up with planted
contacts. Selected loose props give an undeformed presentation nod. Relationship
diagrams and supported objects use a uniform closer-look accent that preserves
their relative geometry. Photographs keep their anatomy under a modest camera
move. Negative emotions and restful subjects use calmer timing. Stable per-word
offsets prevent a page of pictures from moving in unison. No extra sound is added
to continuous picture playback.

`WordArt` loads motion sheets for visible owners and releases hidden sheets after
a short grace period. Reduced motion uses a static teaching pose. Menus and
background pages pause the shared animation clock. Hidden Memory cards, Phrase
drag previews and frozen Voice Pop slices keep their established behavior.

Historical picture files remain in the repository for provenance and old import
checks, but `assets/images/words/*` is excluded from the production pack. The
complete active library and all 1,285 motion atlases ship; authoring meshes, raw
source acquisitions, contact sheets and preview pages do not.

## Reproduction and local review

Acquisition maps and tools live in `tools/vocabulary-art/`. Fluent sources are
pinned to revision `1ffb34c752ecf5d402f04cfb4b392c77f57c54bc`. Mulberry sources
are pinned to `9cbab9f400c5de44e2bc58839cca07294aadb086`; place its `EN` folder
under `build/mulberry-source/`, or set `MULBERRY_SOURCE` to the acquired `EN`
directory. `SHARP_MODULE` may point to an installed Sharp module.

Run the following from the repository root. Node tools that rasterize artwork
need Sharp; the Python illustration renderer needs Pillow and NumPy.

1. Run `node tools/vocabulary-art/acquire-fluent-library.cjs` and
   `node tools/vocabulary-art/acquire-supplemental.cjs` to acquire and verify the
   mapped source bytes. Existing matching files are reused.
2. Render the selected household props with Blender 5.2.2 LTS:
   `blender --background --factory-startup --python-exit-code 1 --python tools/vocabulary-art/render-library-props.py`.
   Source-pack locations and the character workflow are described in the linked
   Lv3 documents. Render and inspect the eight action sequences before packaging.
3. Run `node tools/vocabulary-art/make-animation-gallery.cjs`, then
   `node tools/vocabulary-art/package-runtime-motion.cjs`, to package the reviewed
   full action sequences and their posters. This updates the eight-clip source
   manifest; step 8 updates the combined runtime descriptor.
4. Run `node tools/vocabulary-art/prepare-curated-library.cjs` to reproduce the
   reviewed grain and fuzzy compositions from their pinned Mulberry sources.
5. Run `node tools/vocabulary-art/prepare-library.cjs` to stage all pictures and
   the before/after gallery in `build/word-art-review/library/`. Review at card
   sizes before integration.
6. Run `node tools/vocabulary-art/prepare-library.cjs --integrate` to copy the
   complete reviewed library and write its manifest. Missing sources or mismatched
   acquisition hashes stop it.
7. Run `python tools/vocabulary-art/render-library-motion.py`. It verifies the
   explicit word mapping and source hashes, then renders the illustration loops.
   Add `--ids <word> ...` for representative review; partial libraries cannot ship.
8. Run `node tools/vocabulary-art/make-library-motion-gallery.cjs` for the
   paginated local motion gallery. Review at 48, 80 and 128 pixels, including cycle
   boundaries and extreme poses. Run
   `python tools/vocabulary-art/render-library-motion.py --integrate` only after
   the complete review. This writes the combined runtime descriptor and detailed
   animation manifest, reusing validated unchanged atlases.

Serve the previews with
`python -m http.server 41775 --bind 127.0.0.1 --directory build/word-art-review`.
`/library/` provides age,
word and size filters; `/animated/` provides playback and frame inspection.
`/library-motion/` shows every animated picture with age, word and motion-family
filters, playback controls and paging. `/cheerful/` compares the previous shipped
animation against the new motion at 48, 80 and 128 pixels, with playback, replay
and frame inspection. To reproduce that comparison, first save the previous
runtime manifest as `build/word-art-review/cheerful/before/manifest.json` and its
atlases as `<id>.webp` in that directory, then run
`node tools/vocabulary-art/make-cheerful-motion-review.cjs` after rendering.
All preview pages remain localhost-only.

## Release checks

`tools/word-library-art.cjs` rejects incomplete coverage, invalid provenance,
changed output hashes and orphan pictures before a Web build. Asset tests inspect
the actual WebP canvas headers and require distinct outputs. The Godot vocabulary
art test checks every effective picture, age and context-only word, texture size
and transparent margin. The pack verifier checks effective runtime paths and
rejects historical picture imports and local authoring material.

The motion manifest links every adaptation to its original picture's license and
hash. `data/word-motion.json` contains only runtime timing and resource paths;
`docs/assets/word-library-motion.json` retains detailed provenance and frame QA.

Visual review checks all output contact sheets at 80 pixels, then inspects
ambiguous subjects individually. Motion review uses key poses and normal-speed
playback; automated timing checks supplement that visual review. Browser phone
emulation does not constitute physical-device testing.
