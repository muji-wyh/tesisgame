# Browser-only shell supplement r05

The actual r04 Web export and native pack proof passed. Its browser run reached boot and validated the pack, then failed on its first ordinary click: the canvas intercepted the cold button. The retained engine code confirms that canvas resize policy 2 sets absolute positioning at (0, 0) and fills the browser window.

This proposal changes exactly one byte in index.html: canvasResizePolicy 2 becomes 1. Policy 1 uses the project viewport size, 960 by 640, while retaining normal document flow. Existing CSS, controls, handlers, runtime code, bridges, PCK, Wasm, sourced media, release pins and assertion bodies remain unchanged. No pointer-events override, z-index workaround, forced click, DOM-dispatched click, or direct fixture command is added.

shell-after.html is the concrete reviewable afterimage. proposal.json records its one-byte difference, exact inherited release, all 15 planned output hashes, and the browser scenario preservation check. inherited-inputs.json binds the retained export, original browser failure, frozen export review and original harness. source-references.json is copied byte-for-byte from r04. The inherited fixture and its outputs are never written.

Root reviews this frozen proposal before dispatch. Run materialize.cjs once to copy the existing 15 Web outputs into attempt-001/web and produce attempt-001/shell-supplement.json. This file copy is not a project preparation, export or native-proof replay. Inspect that receipt and output hashes, then run browser.cjs once. Root should persist its own start, command, execution log and outcome receipts for each dispatch. A consumed attempt must remain intact; any failure requires a fresh revision.

The browser uses the original audited release with the separate copied-output inventory. Its scenario, all existing assertions, and ordinary page.click calls are unchanged. Only input/receipt wiring and additional inherited-input integrity checks differ. The result receipts link both the original r04 export and this shell supplement, so a copied shell cannot be reported as a fresh export.

Only static artifact assembly has run at freeze. There is no attempt-001 directory, new export, native result or browser result yet. This remains a phrase-only synthetic technical fixture with one synthetic ready module and 199 unavailable modules. It does not grant production curriculum/asset acceptance or prove full GameUI behavior, the other modes, settlement, physical-device behavior, audibility, performance targets or heap reclamation.
