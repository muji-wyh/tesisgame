# Professional card and Jelly layout review

## Result

Professional Match and Memory cards preserve full current eligible terms at a
minimum of 16 displayed pixels. The same nine authored Jelly identities now fit
all four required viewports at a cell pitch of at least 32 displayed pixels.
Collect remains above Auto merge with its divider; action targets retain at least
44 displayed pixels. A deliberately smaller 240 by 320 viewport pauses safely.

Professional cards wrap at word boundaries and measure the actual shaped Label
line height. A final symmetric vertical inset accommodates the shortest row
produced by GridContainer rounding. Professional word faces communicate matching
through their border/tint; their picture partner retains the pair badge. This
prevents a corner badge from obscuring short single-line terms as well as longer
multiword terms. Growth card presentation is preserved.

Authored Jelly reclaims unused outer spacing on compact views; it does not alter
the six-by-eight board, tile footprints, positions, identities, rewards, or
unauthored layout. Long unbreakable spellings retain the existing paused Read
detail, including horizontal scrolling and unchanged round state after closing.

## Evidence

Evidence is under `build/professional-english/full-theme-review/`.

| Check | Observed result |
| --- | --- |
| Actual Main r2e, all four required sizes | 598 checks, zero failures, 35 captures |
| Complete current picture-eligible card corpus | 205 canonical terms, eight actual minimum Match/Memory geometries, normal/matched states: 3,280 measurements, zero failures |
| Card control guards | Professional picture badge and Growth word badge remain visible when matched |
| Focused corrected Read r2f | 148 checks, zero failures, 12 captures at the four required sizes |
| Deliberately undersized Jelly | 240 by 320 safe pause verified in r2e |

Root independently inspected the 320 by 568 Match and Memory normal/matched
captures, the 320 by 568 and 844 by 390 Jelly boards, the undersized cover, and
the before/after card badge contact sheets. The after image preserves the full
strokes in `aisle`, `touchscreen`, `checkout`, `invoice`, and `mannequin`.
Root also inspected r2f's phone affordance, initial detail and scrolled end, plus
the landscape detail. The final `y` is visibly accessible at the phone's scroll
end; the landscape shows the complete test string at once.

The Read test uses `syntheticunbreakablelabelgeometry`, explicitly a geometry
fixture, not a vocabulary entry or a linguistic claim. At each required size,
the native final-character rectangle fits inside the scroll viewport; closing
resumes the identical board and reward counters. The fixture calls the actual
Main refresh after reconfiguration, so the career backdrop remains synchronized.

Reports: `runtime-r2e/report.json`, `runtime-r2f/report.json`, and
`card-label-scan-report-r2.json`. Representative images:
`card-label-badge-examples-after.png` and the `main-*` files in those runtime
directories. The scan covers all 205 terms currently marked picture-suitable,
not the remaining 4,734 entries or possible future content changes. It found no
exceptional unbreakable card term in this current eligible set.

## Preserved failures and limits

r2b had five real card clipping failures; r2c had four. r2d isolated two failures
on the last 320-pixel Match row, where a 72-pixel card needed 69 pixels for three
lines and its earlier label inset left only 68. These failures remain saved.
The first corpus scan found 467 conservative glyph/badge intersections across
143 terms; representative rendering confirmed real Match letter obstruction.
The revised scan resolves those cases without changing text or eligibility.

r2e's original Read fixture used a multiword spelling with artificial missing
breaks and directly reconfigured Word Jelly without the normal Main refresh.
That capture showed old Growth clouds. r2f separately records the before/after
Main refresh and uses a no-space synthetic string; production synchronization
works correctly. r2e is preserved rather than rewritten as corrected evidence.

Retail theme files in these captures are real source artwork. Curriculum images,
audio availability, and speech state are synthetic fixture seams. These checks
do not approve vocabulary, term artwork, audio playback, browser/device behavior,
or a complete production course. No deployment or release-readiness promotion
was performed by this review.
