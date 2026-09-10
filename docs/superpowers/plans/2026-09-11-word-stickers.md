# Pip's word stickers

## Goal and design

Make the learning rewards refer to the words the child actually finds. Keep the existing five modes and the same five-word lesson when switching modes. A correct target earns its existing picture-and-word sticker once; the twelve-topic Words album in My rewards lets the child hear collected words and display one beside Pip. The large Learn/correction picture also becomes an accessible pronunciation button. Existing toy, medal, chest and journey rules remain intact.

Use “Collected”, never “Mastered”. Match (including speech input) grants only its three matched words. Sky, Listen and Memory grant only correct target words. Learn, Memory Study, incorrect choices and orphan cards grant nothing. No timer, currency or daily streak. Reuse canonical word IDs, illustrations and audio; load only the selected topic's sticker art after opening Words.

## Implementation

- [x] Extend PlayroomState with validated optional sticker IDs and displayed sticker ID; preserve old saves, atomic persistence and failure rollback. Add focused migration, invalid-data, idempotency and retry tests.
- [x] Add a Words album with topic navigation, collected counts, picture/word cards, Hear and Display with Pip. Locked words stay available through normal Learn. Add a displayed word card in Pip's room and make Learn pictures clickable without moving their hit targets.
- [x] Integrate correct-answer paths for Match, spoken Match, Sky, Listen and Memory. Keep failed writes pending for an explicit retry and report them accurately. Preserve modal, controller, audio and reward guards.
- [x] Verify native suites, exported-browser gameplay and persistence, narrow layouts, reduced motion, keyboard, audio failure and existing chest/modal flows. Inspect rendered screenshots.
- [ ] Independent review, commit, merge main, push and deploy; synchronize local preview and verify production runtime plus release hashes.

## Separate outstanding asset requirement

- [ ] Acquire a suitable free Unity Asset Store package through supported Computer Use, inspect actual art and license, import selected art through installed Unity CLI, map exact source paths/hashes, and verify the imported word art in the deployed game. This requirement from the earlier learning/playroom plan is still incomplete. Existing original SVGs and an importer test do not fulfill it.

The in-app browser API currently fails with “Codex auth token is unavailable”. Windows Computer Use can list browser windows; investigate that supported route without touching credentials, browser profiles or real saves. Continue the gameplay work independently if acquisition remains unavailable. Preserve Godot 4.7.1 and leave the unrelated main-checkout `%ALLUSERSPROFILE%/` directory alone.

## Release evidence

Record exact commands, results, screenshots, commit and deployed hashes in `docs/qa/2026-09-11-word-stickers.md`. Canary's first-run WASM compilation delay and physical iOS coverage remain validation limits unless new evidence resolves them.
