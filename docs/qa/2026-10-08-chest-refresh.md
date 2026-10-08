# Themed chest replacement QA

## Change

Replace the Autumn, Ocean, Space, Jungle and Candy chest models with Harvest
Keepsake, Lagoon Pearl, Moonstone Vault, Meadow Explorer and Strawberry Bonbon.
The shared celebration miniature and both reward presentations use the same
catalog. Source and adaptation details are in
[the asset record](../assets/chest-refresh.md).

The previous five private models and their extracted textures/import sidecars
were moved out of the asset tree into the ignored local archive
`build/chest-replaced-models/`. Five final models total approximately 3.56 MB.
Spring, Summer and Winter artwork is unchanged.

## Native and asset validation

- Asset and media suites: 45 Node tests passed. The 23 chest asset tests passed
  again after final geometry and anchor changes.
- All six chest suites passed: model rendering/lifecycle, reveal, feel, audio,
  real gameplay charge flow, and surprise.
- Final model validation: 125 checks passed; shared round celebration: 46
  assertions passed.
- Actual graphics captures under `build/chest-quality/game-review/` cover all
  five closed/open designs, pressure, 61 continuous opening samples and large
  close-ups. Independent visual review confirmed removal of Autumn's skull and
  pointed ornaments, Candy's lower stud profile, and corrected front rim lights.
- A floating cover needs translational compression while charging. This is
  exercised through the same cancel/pause/reduced-motion and no-early-reward
  checks as hinged lids.

## Browser validation

- Desktop Chromium: all three chest model tests passed. Five restored Voice Pop
  rewards were opened with real pointer holds and full motion. Each physical
  release produced exactly one durable reward write, with no early award.
- A real Match win exercised the shared celebration, all five closed miniature
  designs and all five closed themed stages. A full-motion Candy opening was
  followed by theme changes without duplicating its reward. The opened Candy
  chest intentionally stays attached to its claimed reward while the surrounding
  theme changes; those stage captures do not represent five separate openings.
- iPhone 13 WebKit portrait: the themed scene test passed. Actual screenshots
  were inspected for all five celebrations and closed models, plus the opened
  Candy reward and its bottom action.
- Pixel 7 Chromium profile at 844 by 390 pixels: the short-landscape scene test
  passed. All five celebrations and closed stages fit without clipping; the
  opened reward and action remain visible. Desktop and mobile runs finished
  with three and two passing tests respectively, with no recorded runtime errors.
- Desktop artifacts: `build/chest-refresh-browser/`.
- Mobile artifacts: `build/chest-refresh-mobile/`.

Static captures use reduced motion to avoid continuous 3D idle rendering slowing
the local software renderer. The first desktop run exceeded its timeout before
this adjustment. Every real opening explicitly restores full motion before the
press and waits for the opening to finish before freezing the next capture.
These are browser device profiles, not physical-device measurements.

## Web release

`npm run build:web` passed with a 41.56 MB startup payload. The export verifies
eight chest types, five live models, required media and the absence of excluded
resources in the startup pack. The successful receipt at
`2026-10-08T08:28:35.938Z` verifies 5,763 source inputs and 17 output files.
Production HTML and the versioned game pack are compared with the tested export
by `build/verify-chest-refresh.cjs`; its release evidence is saved to
`build/chest-refresh-production.json`.

Audio assets and the shared sound timeline were not changed. Native graphic
captures used the Dummy audio driver and do not constitute listening evidence.
