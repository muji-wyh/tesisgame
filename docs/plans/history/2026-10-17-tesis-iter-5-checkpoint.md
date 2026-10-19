# Professional English implementation checkpoint

Updated during the 2026-10-16 continuation of `tesis-iter-4`. This file records current status; immutable evidence remains at the linked paths.

## Workspace and authorization

- Work only in `Q:/.codex/worktrees/current-age-vocabulary/tesisgame`, branch `codex/current-age-vocabulary`, base HEAD `1a8e2c4d13b31e0da9b73adbf63f5327b8fab243`. Preserve existing uncommitted changes. Do not modify `C:/uworks/tesisgame`.
- The user asked this chat (`01a144df-5c22-7d53-808c-44407709f481`) to continue `tesis-iter-4` (`01a14325-e5ce-72a2-8b1a-b746c89e20c6`) after repeated decoding errors. The existing five-minute heartbeat `implement-professional-english-after-tesis-iter-3` now targets this chat; no duplicate schedule was created. It remains ACTIVE.
- The [approved specification](2026-10-15-professional-english-and-morphology.md) remains the full scope: Growth plus 20 courses with 500 reviewed vocabulary memberships and 100 expression memberships each, all professional media, 21 complete themes, six games, authored morphology and durable shared career progress. Pilot modules are checkpoints, not reduced delivery. No deployment or publication is authorized.
- `tesis-iter-3` is complete and accepted. Preserve the sequential collection audio 1-2-3-4-5-6-7-1, Collect/divider, startup focus, full-span drop admission, Jelly material and settlement fixes.
- The prior 68 KB checkpoint is preserved byte-for-byte at [the historical checkpoint](history/2026-10-16-tesis-iter-4-checkpoint.md), SHA256 `4b88a377279656f4043e096845c0d5cdfbd15ca696034d84017c0c56d4bf6779`. Its historical pending statuses and older counts are not current evidence.

## Current production state

All 200 modules are still draft; none is fully reviewed/playable. Inventory counts establish coverage only:

| Item | Current count |
| --- | ---: |
| Courses / modules / declared themes | 20 / 200 / 21 |
| Unique lexical senses | 4,939 |
| Vocabulary memberships | 10,000 |
| Unique expressions / memberships | 1,620 / 2,000 |
| Reviewed lexical review objects | 111 |
| Authored / independently reviewed Professional morphology | 4,045 / 89 |
| Integrated word images / approved recordings | 8 / 12 |
| Ready full themes | 2: Retail and Nursing |
| Ready modules | 0 |

The reviewed-lexeme count is not complete curriculum acceptance. Language, domain, morphology, media and module gates remain distinct. The post-supervisor draft audit has zero errors and 29,470 warnings; release is not ready. Supervisor's language-only transaction is committed and its focused 27/27 tests passed. R30 remains the last full combined baseline; another combined run is pending the active deliveries below.

## Completed application behavior

- Frozen sense-aware learning contexts; all six adapters preserve exact spelling, word boundaries and positional expression tokens. Incomplete modules fail closed.
- Professional sense/skill progress is shared between careers and separate from Growth. Transactional storage, wallet outbox/idempotency, replay, recovery and passive-exposure handling are implemented.
- On-demand media manifests, latest-selection/cancellation guards, scoped leases, 32 MiB delivery bundles, 10 MiB module first-use target and 128 MiB residency. Views release resource references before their leases.
- Home path cards, searchable careers/modules, Continue and automatic theme selection; on-demand Growth loading; Professional word library with paging/search and resource release.
- Authored atomic/multipart Jelly, legal partials and spelling transformations; common manual/hint/Auto resolver; readable frozen footprints, full-span supply, Read panel, undersized pause, normalized waves and exactly-once rewards.
- Growth has 1,550 reviewed analyses. Stable word identities, original media and all 265 context-only entries remain intact. Pending future analyses are excluded from Word Jelly without an invented atomic fallback.
- Retail and Nursing have complete reviewed environments/props/ambient art and production delivery evidence. Other Home previews do not count as completed themes.

Relevant durable QA is under `docs/qa/2026-10-16-*`, especially `professional-card-and-jelly-layout`, `professional-media-bundles`, `theme-motion-runtime`, `web-search-clear`, `professional-word-library`, `approved-professional-audio`, and `growth-morphology`. The historical checkpoint retains exact earlier browser runs and limitations. Physical-device OS keyboard behavior and full in-game acoustic acceptance remain unverified.

## Latest completed deliveries

### Professional selection callback ownership

The actual `ProfessionalPlay` controller now establishes request ownership and freezes context before synchronous callbacks. Older request, cancel, leave, retry and storage-opening continuations stop when a callback selects something newer; the ready notification captures its payload before notifying observers and suppresses obsolete preparation events. This is a narrow production fix in `scripts/professional_play.gd`, with regressions in `tests/godot/professional_play_tests.gd`.

One retained native dispatch passed 31 current checks with zero failures in 1,440 ms. A separate replay of the exact saved preimage recorded 17 observations and the expected 14 invariant failures; those failures are not included in the passing current count. Four historical empty-pending abort paths were excluded from the old replay and included in the fixed tests. All 24 guarded inputs were unchanged. Root inspected the code and verified the retained inputs, preimages, log and report hashes. See [the durable controller evidence](../qa/professional-play-reentrancy-r01/README.md), including `validation-receipt.json` and `root-static-review-r01.json`. Callback tests use controlled session/loader/cache objects and actual Access bookkeeping; the retained initial-storage recovery test uses the real persistence path. No complete-game, domain-policy or media acceptance is implied.

### Cash-register image

The previous chat had already completed integration and actual production delivery; its checkpoint lagged. Eight pictures are integrated: shopping cart, shopping basket, pallet, shelf, counter, checkout, barcode and cash register. Cash-register delivery passed 81/0 native checks with exact complete pixels, four minimum Match/Memory crops and full resource/reference release. A continuation reviewer inspected the actual full image and four-state contact.

See [cash-register source and delivery](../assets/professional-retail-cash-register.md). Durable copied receipts are in `docs/assets/sources/professional-retail-cash-register/production-delivery-r01/`. Source: Tiny Treats Bakery Interior 1.1 FREE by Isa Lousberg, CC0; static original model, no animation. The image/source/audio/domain records remain separate.

### Exact approved Ava recordings

Twelve exact user-approved recordings are integrated: aisle, cash register, shopping cart, shopping basket, pallet, shelf, shopping bag, gift wrap, counter, checkout, card reader and barcode. Use the saved Ava Sweet settings without postprocessing. Do not request approval again for these exact clips.

The final card reader/barcode approval was recovered from the direct human reply in `tesis-iter-4` turn `01a144de-9fa7-7b03-808c-2d0aa3cfc73c`, question `call_7xvby6MgGR1DNVzcwIkhjACI`. The committed transaction preserved all 1,905 previous audio files and eight images. Focused Node tests passed 22/22. Actual native loader/cache delivery passed 141/0, with 990,648 decoded PCM bytes returning to zero resources, bytes and leases after release.

See [audio provenance](../assets/professional-retail-audio.md), `data/professional/provenance/retail-card-reader-barcode-approved-audio-2026-10-16.json`, and `build/professional-english/retail-audio-review/card-reader-barcode-acquired-r01/`. Native receipt SHA256: `809dca51fe175c706fe8403d465c98b7812b22123dc614a334c354c35b8a13b1`. Acquisition/pending receipts remain historical; later approval and native receipts establish the subsequent states. Future clips and the game mix have separate review requirements.

### Language and morphology

Foundation01 first through fifth batches delivered 48 language-reviewed entries across 960 memberships. The fifth batch integrates feedback, permission, responsibility, task, role, priority, location, address, signature and time zone, with 20 supporting source records. Exact prior independent root acceptance and fresh continuation source crosschecks support this language-only delivery. The later supervisor reconsideration below brings Foundation01 to 49/50 language-reviewed entries across 980 memberships. Attendance remains completely unchanged/pending.

The research-only note at `build/professional-english/foundation-module01-language-review/held-terms-research-r01/RESEARCH.md` remains an immutable proposal. Root subsequently directly inspected British Council, Oxford and Collins and independently accepted supervisor's ordinary work-oversight definition and editorial B2 placement. Oxford's observed C1 remains explicit; the A2 lesson occurrence establishes context, not word-level certification. Three fresh source records accompany the one-entry change. The research author reviewed the delivery technically, without claiming independent language review of its own research. Exact historical holds remain testable and unchanged. See [supervisor language delivery](../content-review/foundation-module01-supervisor-language-2026-10-16/README.md). The guarded transaction preserved all 4,938 other entries, expressions and nonlanguage gates; focused persisted tests passed 27/27. Registry after this transaction: `9030a86673b18539cab08848d1f1d893be5247b446fa4d615e729b1245d2404c`.

Attendance has a new research-only B2 editorial proposal at `build/professional-english/foundation-module01-language-review/attendance-research-r02/research.json`. Directly inspected CEFR-J v1.5 lists the noun at B2, and a publisher workplace lesson is labelled B1-B2; the selected Oxford C1 observation remains explicit. CEFR-J is headword/POS evidence, not sense-level certification. Root authored this fresh proposal, so independent language review is pending. The live entry and every separate gate remain unchanged.

Foundation02 first10 has root language acceptance for nine original candidates plus a corrected confirm variant, but no production delivery yet. The original confirm proposal missed Oxford's selected arrangement B2 label and remains explicitly unaccepted; its fresh correction retains literal Collins B1+ and proposes editorial B2. Exact acceptance is `build/professional-english/foundation-module02-language-review/first10/root-acceptance-r01.json`, SHA256 `ef532122536c440871f4ea81eef48252dd0fa156e011758264520dac318d9db6`. The proposed batch changes four definitions, two examples and two difficulty placements while preserving all 200 memberships. Its 523-expression surface screen grants no expression approval; five new sense holds and twelve prior holds remain. Guarded delivery and independent technical review are in progress.

Fifth10 provenance is `data/professional/provenance/foundation-module01-language-fifth10-2026-10-16.json`; durable review/delivery evidence is in `docs/content-review/foundation-module01-language-fifth10-2026-10-16/`. Content delivery passed 7,829 guards and its separate shared-test transaction passed 1,906. Focused persisted verification passed 35/35 with no input drift; its receipt is `build/professional-english/foundation-module01-language-review/fifth10/continuation-validation-r01/receipt.json`. An independent review found no actionable issues and reconstructed both historical test preimages by reversing only the reviewed edits; see `fifth10/continuation-independent-review-r01/review.json`. Do not replay either completed transaction. The resulting registry SHA256 is `4ad48ae53f0fb028b95d063611c2ad95409e8e20716b65b0227b17d2f61b717f`. Language, domain, morphology, pictures, pronunciation and module readiness remain independently gated.

Retail03 has 50 reviewed graphs; Retail04 has 30; nine earlier Professional graphs have their own review. Exact provenance and history are under `data/professional/provenance/` and `docs/vocabulary/review-history/`. Do not replay one-shot integrated serializers. Existing ambiguity holds, specialist gates, later media changes and Growth family identities must remain intact.

## Latest validation and handoff

- R27 passed 226/226 Node tests, 2,837/0 native morphology and 119/0 audio before the latest two recordings.
- R28 is retained as failed: 227/228 Node passed; 2,837/0 native morphology and 141/0 audio passed. Inputs and registry were unchanged. The single failure was the Retail04 second-ten historical comparison, which omitted reversal of the later card-reader audio change. The narrow historical-test correction passed its affected test 1/1 without changing product data; evidence is `card-reader-barcode-acquired-r01/historical-test-correction-r01.json`.
- R29 passed 228/228 Node tests, 2,837/0 native morphology and 141/0 audio, with no measured input or registry drift. This is the successful baseline used to bind the subsequent Foundation fifth10 transactions.
- R30 passed 233/233 Node tests, 2,837/0 native morphology and 141/0 audio after Foundation fifth10 integration, with no measured input or registry drift. Receipt: `build/professional-english/continuation-validation-r30.json`. Focused Foundation verification separately passed 35/35. No browser, complete-game acoustic or full-module acceptance is implied.
- Active continuation writers: `foundation_continue` prepares Foundation02 delivery in scratch only; `approved_audio` independently reviews its technical guards; `recover_scope` has frozen its two-file controller fix after passing focused native checks and is writing scratch/durable handoff evidence only. Root owns registry/shared content-test mutation windows and the final combined receipt. Bind the actual current baseline only after these writers freeze; serialize registry/shared-test writes. Keep the existing five-minute continuation automation active; do not create a duplicate.

Receipts/logs are `build/professional-english/continuation-validation-rNN.json` and `continuation-*-rNN.log`. Use a fresh revision; never overwrite failed or successful evidence. Run `node build/professional-english/validate-continuation.cjs rNN` only for the current affected integration baseline. Do not rerun unrelated passed suites without a new reason.

## Domain-policy work and next steps

The latest compiled-package work remains scratch-only. No domain exception or real acceptance is enabled; all 26 historical decisions remain null. The r02 Node run was 67/70; r03 separately corrected and passed three fixture-dependent cases. Do not describe this as a clean single 70-check run. Fresh source changes require fresh commitments.

A continuation static review found no actionable issue in the compiler/auditor and r03 supplement; it verified 12 contract files, two harnesses and 23 retained artifacts. See `build/professional-english/continuation-recovery-2026-10-16/domain-review.md`.

The isolated runtime fixture passed 60/60 native checks in 2,326 ms, with 27 guarded inputs unchanged. Its 17-file prepared project contains exact copied production catalog/resolver code and the audited synthetic r03 fixture, with no copied media. It covers supported-API defensive copying, registered tokens, exact 50/10 membership, draft refusal, synchronous cancellation/retirement/reconfiguration and preservation of production gates. It grants no production authority. See `build/professional-english/retail-module03-morphology-review/domain-policy-runtime-fixture-r01/README.md`, `validation-receipt.json`, `OBSERVED.md` and `independent-review-r01.json`.

Warm reuse avoided additional owner JSON reads only; the production catalog still reads its media manifest. GDScript underscore privacy is conventional, not enforced access control. Phrase is the only successful mode in this synthetic fixture. Executed sources, reports and logs remain unchanged.

The separate r02 lifecycle fixture passed 84/84 native checks in 2,250 ms, with all 34 frozen inputs unchanged. It combines exact production RoundLoader/Cache/Access code with the r01 owner and explicit fixture coordination, and exercises synchronous reselection, stale media results, cancellation before claim, claimed-lease survival and teardown. Nine leases were acquired and released once each. Media consists of typed in-memory doubles; unavailable B is a draft module. This does not establish real fetch/decode/playback, ready-A/ready-B replacement, full ProfessionalPlay/store/view behavior, browser/export or performance. See `build/professional-english/retail-module03-morphology-review/domain-policy-runtime-fixture-r02/OBSERVED.md`, `validation-receipt.json` and `root-static-review-r01.json`. Root verified the frozen execution inventory and accepted only this stated fixture scope. The exact earlier README bytes cited by the immutable root review were recovered at `historical-readme-snapshot-r01/README.reviewed.md`, with an additive mapping receipt; current README and original review were left unchanged. The next production trust/owner proposal remains scratch-only; no domain policy is installed.

App descriptor trust, private snapshot/token ownership, lifecycle/cancellation, actual Web responsiveness, memory and cold/warm timing, and export/PCK verification still require implementation/evidence. Exact gates: `build/professional-english/retail-module03-morphology-review/domain-policy-production-integration-r01/LATER-GATES.md`. Preserve earlier latency failures; sampled timings do not establish target achievement.

## Asset queue and remaining delivery

- Shopping bag: the acquired Flipperside StrawberryBag was rendered in all six source views and rejected for the current fabric/open-bag brief. It has a closed thin body and dominant blurry branded strawberry texture, with mirrored rear lettering. No WordCard or production acceptance was added. Original source/harness hashes remain exact. Evidence: `build/professional-english/retail-term-art-review/shopping-bag-research-r02/native-source-inspection-r01/continuation-review.json`. Earlier Kenney/Innerscene rejections and the approved audio remain intact.
- Card reader: the 3D Assets source still returns 503 and its original model CDN hostname fails DNS resolution. The CC0 deed was retrieved, but no model was acquired. The alternative Poly Pizza lead by J-Toastie remains at automatic Cloudflare verification in Edge, after earlier 403/timeout attempts. No challenge interaction was attempted; precise license version and visual suitability remain unverified. See `build/professional-english/retail-term-art-review/card-reader-source-acquisition-r02/receipt.json` and `build/professional-english/continuation-recovery-2026-10-16/card-reader-source-lead.md`.
- Gift wrap and shopping bag: a new bounded source pass inspected Kenney's acquired completed gift, a CGTrader paper-roll preview and a Meshy canvas-tote preview. No suitable original model was acquired or accepted. The roll lacks the required loose patterned sheet/partial wrap; the tote preview cannot establish an open compartment or visible purchases. Exact entries and approved audio remain unchanged. Source/license/acquisition distinctions and next download leads are at `build/professional-english/retail-term-art-review/gift-wrap-and-bag-source-review-r01/HANDOFF.md`.
- Continue substantive source-backed language, morphology and appropriate specialist review, licensed term art, reviewed recordings and the remaining 19 full themes. The held-term research provides a concrete next language-review lead; the runtime fixture identifies the next application-ownership and lifecycle gates. Draft inventories and synthetic ready fixtures are not released lessons.
- Preserve current content readiness checks. Full completion requires every specification acceptance scenario; the broad scope is still unfinished. Keep the existing continuation schedule active until actual completion or a later user pause/cancellation.
