# Growth vocabulary artwork

The Grow with Pip curriculum adds 300 words. Thirty-five use additional acquired
Mulberry illustrations. The remaining 265 describe grammatical or abstract
concepts that are taught in Phrase Builder without substitute pictures.

This is the source record for the original growth batch. Current pictured-word
stills and animations are documented in the
[complete vocabulary artwork library](word-library.md).

## Source and license

- Original source: [Mulberry Symbols](https://github.com/mulberrysymbols/mulberry-symbols).
- Creator: Steve Lee; the original symbol design project originated with
  Garry Paxton, with artists, language professionals and community contributors.
- Pinned revision: `9cbab9f400c5de44e2bc58839cca07294aadb086`.
- License: [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
  This applies to the original illustrations and their PNG adaptations, separately
  from the game's code. The adapted PNGs remain available in the repository.
- Acquisition status: the pinned source checkout was already downloaded.
  Candidate source contact sheets were visually inspected before selection and
  conversion. All 35 selected files are now integrated assets, not remote previews.
- Source animations: none. This original acquisition supplied static educational
  illustrations. The current library adds locally authored illustration motion
  while preserving teaching cues and the source license.
- Transformation: original SVG geometry, colors, CSS and text are preserved while
  rasterizing to transparent 192 by 192 PNGs. No artwork was drawn as a substitute.

The [machine-readable manifest](growth-vocabulary.json) lists each exact source
URL, original hash, output path, output hash and renderer version. Existing
Mulberry credits remain applicable to this additional batch.

## Visual and meaning review

The review checked the actual depicted sense, not just the source filename.
For example, a source named “cracker” depicted a festive party cracker rather
than a biscuit; a “pepper” source depicted a green vegetable rather than ground
seasoning. Those mismatched sources were not integrated. Sources that showed a
romantic partner or an unrelated computer-save symbol were also excluded from
the proposed classroom meanings. Ambiguous grammar and generic relation diagrams
remain context-only rather than becoming forced Match pictures.

Numerals are retained as the actual visual form of number concepts, not as
substitute illustrations for nouns. The selected *chicken* picture depicts meat,
and its meaning says so. Confusable links prevent new pictures such as *cloudy*
and *cloud*, or *world* and *earth*, from becoming ambiguous choices together.

Source contact sheets are retained locally under
`build/growth-vocabulary/source-review-1.png` through `source-review-4.png`.
They include rejected candidates and must not be presented as the shipped set.

## Reproduction

```powershell
node tools/import-growth-vocabulary.cjs C:/path/to/pinned-mulberry-source --sharp C:/path/to/node_modules/sharp
node tools/import-growth-vocabulary.cjs --check
```

The importer verifies the clean pinned source revision, validates curriculum
reachability, rasterizes only the selected sources, then verifies output hashes.
Normal builds use the checked-in PNGs and do not contact a remote asset service.
