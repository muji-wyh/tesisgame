# Talk Quest atlas refresh

The chapter map now uses acquired parchment, coastline, engraved building,
forest, mountain, ship, and interface assets. The fourteen destination
illustrations are composed from source artwork; no monster portraits appear
on the atlas. Source files and attribution are recorded in
[the map source record](../../assets/talk_quest/map/SOURCE.md).

## Behavior and regression checks

- `talk_quest_map_tests.gd`: 1,637 checks passed. This covers all fourteen stops,
  chapter navigation, progression, saved-run chapter selection, focus transfer,
  imported textures, source metadata, reduced motion, separate touch targets,
  and full caption visibility across constrained layouts.
- `talk_quest_compact_layout_tests.gd -- --capture`: 176 checks passed, including
  the actual Quest header, Continue, Treasures, and all three chapters in short
  landscape and narrow portrait layouts. A real desktop-to-phone viewport
  scaling regression verifies Continue retains 14-16px physical text and its
  saved run during repeated rotation.
- `talk_quest_scene_tests.gd`: 689 checks passed.
- `node --test tests/web-export.test.cjs`: 28 tests passed.
- The actual exported game pack successfully loaded all three map backgrounds,
  fourteen destination textures, and thirteen interface textures.

Visual review found and corrected stretched label textures, oversized trail
stamps, enlarged low-resolution building brushes, clipped two-line titles,
and a cached Continue font size that became too small after browser resizing.
The long-title regression checks inspect visible lines, not only label bounds.

## Render evidence

`talk_quest_map_visual_review.gd` generated twelve actual renderer captures:
three chapters each at 390 x 650, 320 x 414, 544 x 140, and 1050 x 600. They are
stored locally under `build/talk-quest-map-review/`. Actual Quest layout captures
are under `build/talk-quest-compact/`. Both harnesses avoid player save changes;
the Quest harness uses its own temporary save path and removes it afterward.

The final Web build was opened in the in-app browser. All three chapters
navigated correctly, showing 4, 6, and 4 stops; the final Next button was
disabled. At 390 x 844 and 568 x 320, page dimensions had no overflow and the
published map scroll maximum remained zero. Continue stayed readable after
rotation. Browser screenshots are `after-game.png`, `after-phone.png`, and
`after-landscape.png` in the same local review directory. The normal viewport
was restored and the first chapter left open for review.

One native capture attempt encountered a Windows WASAPI initialization error
after its layout assertions passed. The visual harness was rerun successfully
with `--audio-driver Dummy`; this review does not validate device audio.

The source art is static. Flag motion, hover feedback, badge pulses, and chapter
crossfades are game presentation effects. Small original brush illustrations
retain their native detail limits; the new village compositions avoid using
large enlargement as a substitute for detail.

These are desktop renderer and browser layout checks, not physical mobile
device, microphone, or frame-rate measurements.
