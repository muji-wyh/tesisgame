# Nursing authored motion review

The accepted static scene now has a narrow authored curtain-hem movement candidate. The real native loader, cache and Art component display all sixteen poses and an eight-second loop. The source/candidate and production readiness remain separate: the candidate stays pending on disk, and no Nursing production descriptor was changed.

## Source and motion

The source-review receipt and accepted `static-r03` composition remain frozen. Innerscene supplies the bed, empty cart, nurse station and privacy curtain under CC0; Kenney supplies the original room panels, furniture and wheelchair under CC0. The frozen source records contain the original URLs, acquisition copies, creator/license evidence and SHA-256 identities. None of these sources contains an animation clip. This motion is explicitly authored; it is not a supplied rig or cloth simulation.

The curtain's cap-smoothed normals were split and corrected in the rendering adapter without modifying the acquired GLB, source positions, winding, UVs, materials, textures or hardware. To permit a local bend, its 532 side triangles were clipped into seven height bands, retaining the original 528 cap triangles. The authored textile has 7,444 triangles and 22,332 expanded vertices. Interpolated rest positions stay on the source surfaces. Subdivision changes rasterization and interpolated lighting slightly: 9,212 pixels differ from the accepted static render, with a maximum channel difference of 28. This is disclosed rather than described as byte-identical static art. The parent reviewer inspected the retessellated rest and both extremes and found the accepted composition retained.

Only the lower 45 percent bends in local depth, with a maximum hem displacement of 0.02 meters and a smoothstep height weight multiplied by a sine cycle. The upper 55 percent and all 29 original hardware mesh references/transforms remain fixed. Corrected normals follow the inverse-transpose depth-bend Jacobian. The model, room, nurse station, bed and other furniture remain stationary. No person, procedure or medical reading is animated.

The loop lasts eight seconds, has sixteen frames at two frames per second, and rests on frame zero. The sampled half-cycle and exact loop endpoint equal the rest render. The source motion bounds are `[497,362,743,558]` within a 1024-square composition. A padded `[489,354,262,212]` opaque patch preserves the curtain/bed occlusion and source lighting. Its 4-by-4 atlas is 1048 by 848. Every static-layer-plus-patch source composition equals its full source render exactly.

## Candidate and rendering corrections

`motion-r01` preserves the first layer and runtime evidence. `motion-r02` expands the props' binary changed-pixel mask by three source pixels, with unchanged source background in the added pixels. This fixes filtered edges outside the animated patch while preserving the exact full composition. The environment, Home image and atlas are unchanged from r01. The r02 candidate files are the final asset candidate for this review.

The first real native test found a runtime error: `TextureRect` motion children snapped their position/extent to GUI pixels, shifting the opaque patch against the fractional aspect-cover background. At 296 square, static Home versus animated rest differed in 2,992 pixels, with a maximum channel difference of 204. A scratch Sprite2D probe reproduced the correctly registered result while leaving viewport GUI snapping enabled.

The localized production runtime fix changes only ambient patches to uncentered Sprite2D children. Their scales derive from the atlas cell and authored normalized rectangle. Existing Control clipping, whole-UI snapping, source crop, layer order, AtlasTexture filter clipping, transition count, motion timing and resource access/release remain in place. At 296 square the residual comparison is 220 pixels, maximum difference 18. At 1024 square, the native composite equals the source exactly. Small filtering differences remain at opaque patch borders at fractional view sizes: at 390 by 844, all thirteen differences above ten channel levels lie on the bottom boundary row. `registration-comparison.json` records all required sizes; no claim is made that separately filtered layers are pixel-identical at every size.

## Verification

The focused Godot art suite passed 26 checks with zero failures. It covers subpixel transforms under default GUI snapping, frame bounds, authored rest, clipping/layer order, reduced motion, hidden processing, crossfades, missing/review-pending media and release. The Node motion suite passed all three tests covering validation and immutable delivery dependencies.

The fixed native run used actual raw delivery, actual decoder/cache and the actual updated Art component. It passed 142 checks with zero failures and saved 63 capture records. It exercised all sixteen frames at 296 square and 390 by 844, plus rest/crop comparisons at 320 by 568, 844 by 390, 1280 by 800 and 1024 square. The unforced loop recorded seventeen transitions and returned to rest at 8,025 ms; intervals were 492-509 ms. Every captured live frame equals its corresponding forced atlas pose. Reduced motion equals frame zero exactly and remains unchanged after the wait. Hidden time pauses and resumes correctly. Home remains static. All four resources and the single lease release to zero resident, pinned and reserved bytes, and the old scoped URL becomes inaccessible.

The review inspected the saved source rest/extremes, all sixteen actual 296-square native poses, actual 390-by-844 rest/extremes and every required native rest crop. The bed and nurse station remain legible; accepted portrait peripheral cropping and landscape ceiling cropping are retained. Generated timed GIF evidence uses recorded frame intervals rounded to the GIF centisecond clock. Saved pose inspection and recorded live processing do not constitute a claim of continuous visual playback review, Main/gameplay approval, audio listening or browser approval.

## Budget and protected work

The four theme resources use 772,803 encoded bytes and 32,275,456 decoded bytes under the existing v1 33,554,432-byte limit, leaving 1,278,976 bytes. This is theme-only evidence. A production module must also include its lesson media and satisfy the actual module/round delivery budgets; this candidate does not waive those requirements.

The frozen production theme identity and all twenty Home preview hashes are rechecked in `motion-review-receipt.json`. The accepted Retail theme and its original preview remain unchanged. No source is reacquired or rewritten, no production Nursing readiness tag is set, and no curriculum content is edited here.

The next decision belongs to independent review of the motion candidate, followed by any content-owner integration and full application review. The complete source, static acceptance, initial runtime baseline, fixed runtime, code/tests and candidate identities are hashed in the receipt.
