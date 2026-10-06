# Three age bands: 900 additional words

The catalog adds exactly 300 entries to each existing editorial age tier while
preserving the original 350 entries, IDs, pictures, recordings, and saved-word
references. The tiers now contain 448 basic (ages 4–6), 412 growing (ages 7–9), and
390 advanced (ages 10+) entries, totaling 1,250. The All words choice combines
these tiers; it is not a fourth age band. Gameplay retains the existing cumulative
eligibility and preference for words in the selected tier.

The additions comprise 540 nouns, 207 verbs, 112 adjectives, 17 prepositions,
11 adverbs, and 13 numbers. Seven metadata-driven topics join the 12 existing
adventures. Each addition has a short English meaning. Reviewed ambiguous
pictures, related meanings, compounds, and homophones cannot share a board when
their distinction would make matching or spoken answers ambiguous. Noun plural
rules no longer invent plural forms for verbs or adjectives.

## Artwork and pronunciation

All 900 additions use distinct acquired Mulberry Symbols illustrations, licensed
CC BY-SA 4.0 and pinned to revision
`9cbab9f400c5de44e2bc58839cca07294aadb086`. Curators inspected the corresponding
source artwork in contact sheets. The checked-in transparent 192×192 PNGs total
8.09 MiB; the original 350 SVGs remain available. The
[source and transformation record](../assets/mulberry-vocabulary.md) and its
machine-readable manifest record creator, license, source URLs, hashes, renderer
versions, acquisition status, and the absence of source animation. The shipped
Art credits page links to the source and adapted artwork.

All 900 new pronunciations use the approved Ava profile: `en-US-AvaNeural`,
rate `-15%`, pitch `+8Hz`, volume `+0%`. The existing 358 word/prompt recordings
were retained. Decoding to the existing 22,050 Hz mono PCM format is the only
audio conversion; Godot imports speech using the existing QOA compression.
Explicit short contexts select the intended pronunciation of ambiguous words
such as the verb “close” and noun “present”. The source WAV additions total
70.60 MiB; this is not the compressed Web download size.

## Catalog and responsive layout

The catalog shows 60 words per page and retains at most 60 picture resources.
Previous/Next navigation, global word focus, total counts, and pronunciation
continue to work across page boundaries. Selecting a new word also displays its
meaning. Age changes return to the first page without changing the current lesson.

The first complete layout sweep exposed 14 long-label failures on the 480×480
viewport. Match and Memory now use two columns when the board is narrow and five
rows can preserve 44-pixel touch targets; short landscape boards retain five
columns. No labels were truncated and no minimum font sizes were reduced.
The corrected sweep passed 30,151 assertions across all 1,250 labels and six
real scene sizes: 320×568, 390×844, 480×480, 844×390, 768×1024, and 1366×768.

The initial standalone catalog run exposed five obsolete fixture assumptions:
`ant` is no longer near the alphabetic start, and a 320×320 viewport cannot display
an entire tile after adding page controls. The fixtures now verify the actual
first entry, stable focus, no runaway scrolling, and a bounded offset that
reveals the caption when the full tile cannot fit. Existing assertions for usable
targets, visible focus, scrolling, and input cancellation remain in place.

## Verification

- Catalog import/provenance checks pass, including all 900 source hashes and
  picture outputs, exact per-tier additions, unique IDs and text, English metadata,
  and semantic equality of the original 350 entries.
- 164 focused Node tests pass across assets, pronunciation generation, speech
  host integration, and Web export contracts. Six focused image-generation checks
  also pass, along with 15 performance-harness checks. The catalog benchmark now
  samples the first, middle, and last entries across pages 1, 11, and 21.
- Model suites pass: adventures (5,844 assertions), Match speech (3,034), Memory
  (704), Voice Pop (32,402), and saved playroom state (2,511).
- Age eligibility passes 22,235 checks; age scene behavior passes 418.
- The corrected standalone catalog suite passes all 8,474 checks, including
  every page, keyboard/touch input, meanings, bounded resources, and resized focus.
- Memory component, held peek, and scene suites pass 63,811, 291, and 178 checks
  respectively, including the complete expanded vocabulary at supported geometry.
- The core suite passes 19,316 assertions and explicitly reaches all 1,250 words
  across 19 topics. Adventure scenes (175), Voice Pop scenes (1,562), Match groups
  (2,531), and Match connections (1,559) also pass. These make 17 passing focused
  native suites in total. The updated performance script passes a Godot parse
  check; this release does not claim a new comparative frame-time measurement.

The old global randomized reachability sweep exceeded its 180-second timeout
after the catalog grew. Its replacement retains 80 complete-catalog invariant
rounds, samples eight ordinary seeds per real topic, and deals every word through
the public required-word path at that word's actual age tier. This gives explicit
word/picture-pair, topic, age, and ambiguity coverage without relying on an
unbounded random search to eventually encounter the last word.

The first export correctly failed package verification because the old
`*-open.wav` exclusion also matched the new `word-open.wav`. Export exclusions
now name only the retired world prompts. The Web contract suite checks that no
catalog picture or pronunciation matches an exclusion; all 30 Web contract tests
pass after the correction.

The final Web pack verifies all 1,250 pictures and pronunciations, 10 game effects,
and 224 required source/imported audio paths with zero failures. Its receipt
covers 5,832 source inputs and 17 output files. Compressed startup engine/game
downloads total 38.74 MB, compared with 27.07 MB before this expansion; source WAV
sizes must not be confused with this delivery total.

The initial desktop browser matrix reached its 150-second test budget while
finishing its final assertions; trace inspection found no application wait or
assertion failure. Board scans now reuse their already measured canvas bounds,
removing 80 redundant browser round trips without reducing coverage or extending
the deadline. The first pagination fixture also assumed spatial Left would focus
Previous; it correctly selected a nearer word instead. The fixture now uses
Shift+Tab to follow the pager's tab order.

All eight targeted browser cases pass after rerunning the three affected cases:
four on desktop Chromium and four on the iPhone WebKit profile. They cover exact
age catalogs, preserved Match/Memory lessons, reload and failed-save recovery,
advanced gift lessons, and new-word pagination at 480×480. The new page test
checks `above` (preposition) and `bring` (verb), their meanings, touch Next,
keyboard Previous, unchanged saved progress, and no separate audio downloads.
Chromium additionally observes running WebAudio playbacks with the expected
recording durations. This Windows WebKit build lacks WebAudio, so its pass covers
interaction and rendering rather than actual audio output. Desktop, 320-pixel,
iPhone Memory, and new-word page screenshots were visually inspected.

Deployment uses the verified export receipt. Production verification compares
all 11 public output hashes against it and writes the local
`build/presentation-production-verified.json` evidence.

Local test logs, source contact sheets, export files, and browser captures live
under ignored `build/`. Browser device profiles are not physical-device evidence.
Deterministic speech fixtures verify word interpretation, not live microphone
accuracy or the acoustic behavior of every new pronunciation.
