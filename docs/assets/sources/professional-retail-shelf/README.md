# Shelf term-picture candidate

This is a scratch-only source and candidate review for `shelf.storage-surface.n`. No production asset, lexeme, review status, test, or readiness gate is changed by this task. Root owns independent review and any later integration.

## Source and license

The source is [Kenney Mini Market](https://kenney.nl/assets/mini-market), version 1.0 from the previously acquired local All-in-1 3.7.0 library. The retained license lists Kenney and additional credits Fleur Keijsers and Guus Vermeulen, creation date 2024-10-25 15:22, and CC0 1.0. The source page consulted on 2026-10-16 also identifies version 1.0 and CC0. Exact original GLBs for shelf-boxes, shelf-bags, and shelf-end, their source previews, external colormap, license, and overview are copied byte-for-byte. `source-record.json` binds all nine retained files to their originals.

All three shelf GLBs are static with no skins or animation clips. Pack-wide animation advertising does not establish animation for these models. The tiny original pack previews are retained separately in `source/previews`; `source-preview-contact.png` is a clearly labeled 4x nearest-neighbor enlargement, not a candidate render.

## Inspection and composition

Eight new native views inspect the original models without hiding objects or changing geometry, materials, textures, or object transforms. shelf-boxes is the closest source to the live brief: its frame and support boards are distinct from six carton and four box children. shelf-bags uses bagged products; shelf-end has bottles, cartons, and a colored header. Their originals remain as comparison evidence.

Four scratch explorations keep the shelf-boxes frame and its two front upper boxes. The six cartons and two rear boxes are hidden at scene level. This uses source artwork only; no primitive stand-in, synthetic product, repaint, or new shelf geometry is introduced. `composition-exploration` records the omitted source nodes and alternative cameras. The whole-unit views leave both levels prominent, while the close top view better isolates the selected support surface.

The candidate uses camera [0.9, 1.8, 4], target [0, 0.66, 0], orthographic size 0.98, source-compatible studio lighting, and a transparent 768-square raw render. A focus rectangle [0, 0, 768, 640] excludes the lower shelf; alpha-bounds crop with a 16-pixel margin and Lanczos resize produce `candidate/shelf.png`, 512 x 309. The crop deliberately cuts through the original backing panel below the upper shelf. No node geometry, material, texture, or retained object transform is edited. Existing yellow bands belong to the source boxes; no label or word is added to identify the shelf.

## Actual WordCard evidence

`candidate/actual-word-card-contact.png` captures the real WordCard at Match 126 x 72 and Memory 144 x 74, unmatched and matched. The run passed 21 checks with zero failures. The real badge and 0.68 matched image alpha are present. Art renders at about 86.16 x 52 and 89.48 x 54. A direct scratch ImageTexture assignment is used; this does not exercise production media delivery.

The author observed a continuous shelf front edge with visible thickness beneath two boxes in all four states. Color and source shading are coherent with the accepted cart, basket, and pallet. The native crop comparison retains their existing pixels without rescaling or rerendering. The crop avoids the whole shelving unit, but its rectangular cutoff through the backing panel remains visible, and the bright source boxes are more visually prominent than the pale support. These are specific residual review concerns, not hidden by the passing layout checks. No participant recognition study has been conducted.

Recommendation: viable for root's independent review of the exact crop and tiny-card semantics, with acceptance still pending. Keep the production image pending unless root accepts these specific tradeoffs. Image acceptance would not approve word audio, language/domain review, morphology, or module readiness.

## Run history and preservation

The first source inspection attempt had an untyped loop parse error. The second reached a freed node reference in GLTFState's importer mapping and timed out without images. Both original failed scripts and logs are retained. The final source inspection uses the generated scene tree and completed successfully, as did composition exploration and the candidate. No failed log is presented as passing evidence.

The shared native slot was explicitly released after candidate QA. No further native run is planned. `review-receipt.json` records hashes, source identity checks, native evidence, adaptations, limitations, and production-pending status.
