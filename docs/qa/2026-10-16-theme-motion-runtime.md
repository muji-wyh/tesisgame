# Authored theme-motion runtime

The prior theme renderer supported static environment/prop layers and crossfades.
It did not play the planned ambient clips or include them in module dependencies.
The runtime now accepts bounded, reviewed sprite sheets, keeps their placement
registered to the environment crop, and shares the round's existing media lease.
Reduced motion selects an authored resting frame. Hidden views stop updates;
replacement and teardown release outgoing image references.

This is engineering validation using existing licensed images as technical
fixtures. It is not artistic loop review or delivery of a production animated
theme. All 21 complete theme presentations still require their actual artwork
and motion review. Current career previews remain static.

- Native theme presentation: 21 checks, zero failures, including resting-frame
  selection, time advancement, crop registration after resize, hidden-view stop,
  motion preference changes, malformed frames/placement, and outgoing cleanup.
- Native round loading: 18 checks, zero failures, including sheet scope binding
  and rejection of a missing animation dependency.
- Existing content plus initial motion suite: 68 tests passed (66 content,
  two motion). The final focused motion suite passed 3/3, adding missing-sheet
  manifest coverage and immutable-path mismatch checks.

Evidence: `build/professional-english/theme-motion-native.log`,
`theme-motion-content.log`, and `theme-motion-delivery.log`. Runtime contract:
`docs/professional-media-contract.md`. These changes postdate immutable r3.
