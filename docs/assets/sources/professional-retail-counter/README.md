# Counter candidate — pending root acceptance

Selected candidate: `candidate-broad-return/counter.png`, 512 x 293 pixels. The exact source image, actual minimum WordCard crops and decoded pixel hashes are frozen with this handoff. Nothing in this scratch revision integrates media or changes production readiness.

## Meaning and source selection

The selected sense is `counter.service-surface.n`: a raised work surface used to serve customers. The original example places a parcel on the counter. The exact live brief is retained in `source-record.json`; it requires a broad surface, solid front, staff side, customer standing space, and a subordinate parcel without a particular checkout/return/pickup action.

The composition uses four complete copies of Kenney's Furniture Kit 2.1 `kitchenBar` source: three across the front and one perpendicular return. A single sealed taped parcel comes from Kenney's Car Kit 3.1 `box`. Both are previously acquired CC0 1.0 originals. Exact local licenses, original filenames, copies, hashes and model metadata are retained. No animation clips or skins exist in the selected models.

The Furniture Kit closed-box lead was rejected after actual native inspection because its flaps stand open. Its source and diagnostic renders remain intact. The inspected matching counter-end module is not used. The prior shopping-bag review is frozen separately in `../shopping-bag-r01` and is not promoted by this work.

## Adaptations and presentation

Only complete source-model instances were positioned and rotated. Counter modules retain unit scale. The entire parcel root has uniform scale 0.16, yaw -10 degrees, and rests at the original countertop height 0.42. Every mesh, material, texture and source child transform remains unchanged. The return is a full source counter module rotated 90 degrees; no connector, floor, character, sign or other artwork was invented.

The assembled source model is recentered, rendered to a transparent 768 x 768 image, alpha-cropped with a 16-pixel margin, and proportionally resized to 512 x 293. No portion of the source assembly is deliberately cropped off. The camera is `[-1.1, 1.8, 4]`, aimed at `[0, 0.24, 0]`, with orthographic size 1.55. Ambient energy 0.18 and directional energy 0.38 preserve the source wood colors; original materials are unchanged.

The staff-side recess is established by the L-shaped return, with the solid front facing the open customer side. The parcel remains small and secondary. This is a generic counter illustration; it makes no claim that the furniture is unique to a retail service function.

## Native evidence

- Two source-only invocations produced ten unmodified original views before composition. `native-source-contact.png` combines those saved views.
- Three layouts were rendered to actual native WordCards: straight, short return, and broad return. Each passed 21 checks with zero failures. The earlier layouts remain unselected evidence.
- The selected image renders at approximately 90.87 x 52 pixels inside a real Match card measuring 126 x 72, and 94.36 x 54 inside a Memory card measuring 144 x 74. Both matched and unmatched states retain the real badge, face visibility and picture alpha.
- `selected-pixel-hashes.json` records exact PNG and decoded RGBA pixel hashes for the selected candidate and all four card crops.
- These are real WordCards with a direct scratch ImageTexture assignment after setup. They do not test production media loading, recognition by participants, audio, curriculum readiness, or release acceptance.

## Author visual finding

The broad return is the strongest of the three layouts: its top and three solid front panels stay readable at the true minimum size, while the return distinguishes a staff recess. The near-white top loses some edge contrast on the white card, and the matched badge partially overlaps its far-right end. The large front and inner return corner remain visible. This is an author recommendation for root review, not independent acceptance.

All five native invocations completed successfully on their first attempt. Every native log is retained. The native slot was explicitly released to root for R09; no further render is planned in this frozen revision.
