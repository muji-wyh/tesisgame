# Vocabulary mastery cards

The vocabulary catalog distinguishes a currently mastered word with a pale mint
card, a warm gold edge, a gold status pill, and a static medal in its upper-right
corner. The word illustration and spelling remain the main content. Learning
cards retain their paper surface and exact practice streak. This treatment uses
the current streak threshold, not lifetime learning credit; a reset removes the
award treatment when progress is refreshed.

The medal and status decorations ignore input. The whole card remains available
for pronunciation, scrolling, and keyboard focus. The treatment has no idle
animation, including when many mastered cards share a page.

## Integrated artwork

| Field | Record |
| --- | --- |
| Source | [Fluent Emoji Sports medal, pinned revision 1ffb34c](https://github.com/microsoft/fluentui-emoji/blob/1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/assets/Sports%20medal/3D/sports_medal_3d.png) |
| Creator | Microsoft Corporation |
| License | MIT; retained in [the existing Fluent license](licenses/fluent-emoji.txt) |
| Acquisition | Previously downloaded and integrated in the word library; the actual local medal and star artwork were inspected before choosing the medal |
| Local material | `assets/images/ui/mastery-medal.webp`, a byte-identical copy of `assets/images/word-library/medal.webp` |
| SHA-256 | `3e85d373d75134935a586990b94d16358b1390a29e60a26eeb6fe2e7f7b70ad6` |
| Status | Acquired locally and integrated as the mastery badge; no new download or marketplace preview |
| Animation | Static 3D illustration; no source rig, clips, or motion is used |

The original source hash and transparent-margin normalization remain recorded in
[the word-library manifest](word-library.json), entry `medal`. The dedicated UI
copy keeps the badge in the core UI without loading the age-seven vocabulary
pack. Card surfaces and status-pill geometry use the existing interface style;
they do not replace the sourced award artwork.
