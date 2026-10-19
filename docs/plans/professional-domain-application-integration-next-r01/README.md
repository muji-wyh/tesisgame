# Next application integration boundary

Static proposal, 2026-10-17. No production implementation, test dispatch, build, media acquisition or deployment is included. The 20 observed course manifests still declare 200 draft modules and zero ready modules. `source-inputs.json` records 52 reference-file hashes and the per-course observation; it is not a fresh complete-source audit.

The smallest substantive production step is an **audited all-unavailable application release**, followed by routing Professional round preparation through the asynchronous owner. The build contract is the prerequisite: the tested owner deliberately accepts only a synthetic descriptor with `authority: none`, and the production generated package and tooling do not exist. A runnable loader patch would therefore preload an invented service or introduce a temporary trust bypass. This proposal supplies the dependency map instead.

## Existing chain and gaps

`game_ui.new_round` -> `ProfessionalPlay.request` -> `ProfessionalRoundLoader.request` -> synchronous `ProfessionalCatalog.resolve` -> media loader -> pending media lease -> store/session -> `round_prepared` -> actual view teardown -> `ProfessionalPlay.claim` -> old lease release.

| Boundary | Current evidence | Missing production contract |
| --- | --- | --- |
| Build authority | Scratch `compile(sourceRoot, outputRoot, options)` and independent `audit(sourceRoot, packageRoot, options)` reconstruct a complete copied source graph and enforce empty decisions. Both report scratch authority only. | Current-source snapshot, explicit empty production decisions, production descriptor/pin, strict output inventory and export binding. A matching hash proves integrity relative to its pin; a caller-owned pin does not authorize curriculum. |
| Runtime proof | Frozen `candidate_owner.gd` uses fixed synthetic paths, chunked reads, raw hashes, native JSON, private immutable data, registered tokens and cancellation. | App-owned descriptor verification before decoding, production schemas, instance ownership, cheap token-current check, coordinated retirement, and exact decoder parity. |
| Caller | Loader calls `catalog.resolve` synchronously; `ProfessionalPlay` already protects callback reentrancy with request epochs. | Async policy completion must be joined to loader selection, installed owner, request identity and later media generation. |
| Home metadata | `game_ui` and Home use `professional.loader.catalog.courses/course/theme_profile`. | Keep this API available for browsing. It must no longer authorize gameplay through the loader's request path. |
| Media | Catalog checks real manifest bytes/hash/context, dependency identities, reviewed theme artwork and motion; media loader and Access own fetching, decoding and leases. | The catalog reads the manifest synchronously on every resolution, even a warm owner hit. Current owner counters exclude that read. The integrated closure and timing must include it. |
| Shutdown | Loader `_exit_tree` cancels; Play `_exit_tree` releases its active scope. Main `game_ui._exit_tree` currently handles confetti, celebration and speech debug. | Prove actual scene teardown order, callbacks and reference release with the policy child present. Do not infer this from isolated view or owner tests. |

The retained owner success is 125/125 checks. The original negative run remains failed at 214 checks with one harness assertion failure; its affected supplement passed 28/28. These histories do not establish application trust, actual media delivery, all six compiled modes, Web behavior or performance.

## Dependency order and proposed files

All paths below are proposed edits, not files created by this proposal. Production/shared-test edits remain root-owned.

### 1. Produce and bind the all-unavailable application release

| File/API | Required change |
| --- | --- |
| `data/professional/domain-policy/decisions.json` | Explicit versioned empty `entries` list. Keep accepted IDs empty and all exception/acceptance grants absent or null as prescribed by the initial contract. Reject nonempty decisions; a build receipt is not review acceptance. |
| `tools/professional-domain/{contract,codec,inputs,snapshot,compiler,audit,release-gates}.cjs` | Adapt the audited scratch contracts into production-owned tooling without depending on `build/` paths. Keep `compile(sourceRoot, outputRoot)` and independent `audit(sourceRoot, packageRoot)` over disjoint fresh roots. Recompute memberships/coarse flags from every declared module, including unavailable modules; retain original review, source-reference, media and readiness gates. |
| `tools/professional-domain/package.cjs` | Orchestrate a fresh complete-source snapshot, unchanged production content audit, compile, independent output audit and source/tool/output drift checks. Write generated output only after all gates pass. Source inventories exclude their generated output to avoid a self-hash cycle. |
| `data/professional/domain-policy/generated/release.json`, `index.json`, `modules/<full-sha256>.json` | Versioned fixed app descriptor, full-hash index and only audited ready payloads. The initial real index contains exactly 200 unavailable entries and **no ready payloads**. Bind the frozen theme snapshot and selected ready media-manifest descriptors into the release closure. Every generated file and directory must be accounted for; stale payloads fail. |
| `scripts/professional_domain_release.gd` | Build-generated fixed descriptor path, full descriptor SHA-256/byte length and supported release schema/policy constants. This is the app's embedded pin. No runtime path, pin, accepted-ID or release-selector argument is accepted from UI/gameplay code. |
| `tools/build-web.cjs` | Invalidate the prior build receipt before domain preparation. Generate/audit/pin before Godot import and `snapshotInputs`; then run the existing export and raw PCK verification. Recheck the complete source binding before issuing the final receipt. |
| `tools/web-build-receipt.cjs`, `tests/godot/verify_web_pack.gd`, `export_presets.cfg` | Include new tooling in input inventories; include generated JSON in export; verify exact descriptor/index/payload/theme/manifest inventory and embedded full pin in the raw PCK. Bind that evidence to the final decoded PCK digest and build receipt. Existing Brotli/whole-pack checks alone do not prove this internal inventory. |

The exported script and descriptor share the existing application's packaging trust boundary. This is not a new signature scheme or protection against someone replacing the whole application. In an editable native/editor checkout, require a freshly audited generated release bound to the current source snapshot or report policy unavailable. Never recover by scanning loose lexeme/expression files or choosing an older proof. Test-only synthetic releases are produced in a separate copied project and never installed into the real package.

This stage is useful independently: it establishes real packaging authority while preserving zero ready modules. It does not claim that runtime integration or release acceptance is complete.

### 2. Adapt the owner and verified catalog boundary

| File/API | Required change |
| --- | --- |
| `scripts/professional_domain_owner.gd` | Adapt the exact frozen async candidate to the embedded app pin and generated release. Keep `request(context, seed) -> int`, `completed(request_id, result)`, `resolve(token) -> Dictionary`, `cancel()` and `retire()`. Add `is_current(token) -> bool` without I/O or deep-copying gameplay content. It validates registration, current request/epoch and the installed release internally. Retire clears tokens/metadata/cache before replacement work. |
| `scripts/professional_domain_catalog.gd` | Private owner-created adapter using only its verified frozen selected course/records/theme/manifest. Preserve the existing resolver and catalog's media/theme/motion gate tail. Never reread `_records` from loose source files after proof. Do not expose an API accepting caller dictionaries or accepted IDs as authority. |
| `scripts/professional_catalog.gd` | Extract only the current manifest-open/hash/parse operation into a narrow internal helper such as `_load_module_media(descriptor, context)`. The ordinary catalog retains the existing operation; the owner-held adapter supplies the already verified cached manifest through the helper. Keep dependency checks, reviewed artwork, course/theme identity and motion compilation in the shared tail. |
| `scripts/learning_content_resolver.gd` | Preserve the existing resolver contract. Global coarse-required payload rows add a `review.domain == reviewed` requirement; they cannot weaken `_reviewed`, phrase focus/audio, selected 50/10 membership, morphology, mode/reachability or confusability gates. No exception or override flag is added. |

The owner must stage the selected media manifest as a bounded verified step before resolution, using its selected course descriptor and `MediaManifest.parse_manifest`. Cache its immutable validated form with the module and installed release; recheck expected course/module/revision on reuse. Keep the exact original required-resource checks. The current manifest bound is 256 KiB. Include manifest I/O, parsing, copies and validation in closure and timing accounting; a warm result that still opens the manifest is not a complete no-I/O policy hit. Image/audio delivery remains the existing media loader's work and has separate cache/lease accounting.

Do not rename scratch authority strings and treat that as adaptation. The generated production descriptor, its embedded pin, supported schema values and runtime gate parity must first have explicit matching contracts and independent evidence. The descriptor itself must pass its app-owned length/hash check before native decoding; the fixture owner presently has no expected hash for its top-level descriptor.

### 3. Wire the actual loader and keep controller behavior

`professional_round_loader.gd` internally constructs the policy owner as a child. Production has no public owner replacement or release-picker API; copied fixtures can substitute fixed dependencies without shipping a test injection path. Keep `catalog` for Home metadata. Add a once-only configured/closed lifecycle so duplicate setup or shutdown cannot reconnect callbacks or revive a retired owner.

The loader retains one private preparation record: its selection, frozen context/seed, owner instance, policy request ID/token, resolved content, media generation and pending scope. Revision authorization stays inside the owner's token registry; copied gameplay content carries no token or policy authority.

| Transition | Required ordering and guards |
| --- | --- |
| `request` | Cancel prior pending work and scope; capture current selection/context; call owner request; store returned request ID before any completion can fire. Success and immediate failure complete only after `request` returns. Preserve `ProfessionalPlay`'s existing request epoch and pending-selection assignment. |
| Policy completion | Match loader selection, owner instance and policy request ID. Verify `is_current(token)`, resolve once, store only the defensive result, emit `theme_selected`, then recheck the same preparation/token after synchronous callbacks before starting media. |
| Media completion | Match media generation and complete current preparation/token binding before acquire. Recheck after any reentrant operation and before `prepared`. Bind only exact required resources through current Access code. Release a newly acquired scope immediately if the preparation became stale. |
| `claim` | Require current selection, current installed-owner token and a pending scope. Bind and transfer the scope once. Invalidate only loader pending ownership; the claimed round is now independent of later policy cancellation. |
| `cancel` | Invalidate loader identity first, cancel policy/media, erase pending content/token and release the unclaimed scope once. Preserve already claimed active media. |
| Retire/shutdown | Route retirement through loader cancellation before `owner.retire`, then disconnect or ignore late callbacks. If owner retirement can occur independently, add an invalidation signal that immediately cancels pending media/scope. Idempotent shutdown must not leave an open file, token or retained policy cache. |

Keep `ProfessionalPlay`'s current `media -> storage -> ready` phase sequence and existing callback guards. `game_ui` and `game_library` already treat `media` as busy; a new `policy` phase would require every consumer to change. A small optional copy change to “Preparing your workplace lesson...” can cover both policy and media work. `new_round` must still settle prior rewards, drop old views/audio references, claim the new round, then release `previous_media_scope`. Do not call `leave` early merely to retire a pending policy job.

## Focused acceptance cases after implementation

These are future cases, not executed checks. Use fresh attempt directories, serialized native windows and frozen inputs. The full existing `domain-policy-production-integration-r01/LATER-GATES.md` remains required; these are the smallest focused cases for the proposed seam.

| Case | Meaningful assertion / existing test boundary |
| --- | --- |
| All-unavailable real release | Independent audit and decoded PCK inventory report 20 courses/200 unavailable modules/zero ready payloads/zero grants. All real selections fail `content_pending`; no policy token, media request, storage opening or successful claim occurs. Home metadata and Growth remain usable. |
| Build tampering | Wrong/missing descriptor pin, stale or extra payload, source/reference addition, changed review/coarse flag/decision, file length/hash drift, output mutation and decoded-PCK mismatch each block the new receipt. Include strict-codec/native-decoder parity on emitted strings, Unicode, numeric limits, selected IDs and morphology. |
| Real ready seam in a copied fixture | The audited synthetic phrase-capable fixture traverses owner, verified adapter, actual media loader/Access, Play, real store/session and `game_ui.new_round`; use valid manifest-bound fixture media with explicit synthetic provenance. The current candidate copies no media and does not supply this test. |
| Other five modes | Current compiled fixture correctly refuses them. Author and independently audit eligible copied fixtures before claiming all-six-mode compiled-path acceptance. Existing application stub success is not interchangeable evidence. |
| Wait semantics | Update `professional_application_flow_tests.gd` helpers: `start_course` currently finishes media immediately and `settle` may return during `media`. Await the exact policy/media request or terminal state with a bounded timeout and fail on timeout; do not count a few idle frames as preparation completion. |
| Reentrancy and rapid selection | Extend `professional_round_loader_tests.gd` with A/B/A, cancel at policy checkpoints, a completed but unobserved token, and `theme_selected` selecting/cancelling again. No obsolete selection starts media, opens storage, emits `prepared` or claims. Preserve existing Play reentrancy checks. |
| Retire/replacement while media pending | Test-only A-to-invalid-B and A-to-valid-B replacement invalidates A before reading B; late A media success/error cannot acquire/publish. Pending A lease is released once; an already claimed A round retains its lease until normal view teardown. |
| Pending/claimed ownership | Cancel after acquire/before claim, repeated claim, cancel after claim, switch to Growth and scene exit. Assert cache resource/byte/lease counts and view/audio references, not only callback counts. Extend actual application and `professional_view_teardown_tests.gd` coverage with the owner present. |
| Cache mutation and failure recovery | Mutate caller context/result, forge or reuse foreign/stale tokens, request wrong revision/mode, remove/corrupt selected package or manifest, retry, then valid recovery. No fallback, new stale authority, leaked scope or source alias. A true warm policy hit has no policy/manifest I/O. |
| Actual Web and limits | Exercise the same chain in the exported single-thread Web app with `variant/thread_support=false`. Measure initialization, bounded reads/hashes, native decode, manifest/theme/resolver work, copies and caller publication; include cold and warm ownership checks outside timing. |

Performance remains unmeasured. The 4 ms between-step owner budget and 16 KiB reads do not bound indivisible decode/validation/resolution/copy work. Later acceptance requires warm p95 <=25 ms, desktop application-cold p95 <=500 ms, named representative low-end cold p95 <=1500 ms, every main-thread slice <=50 ms, closure <=2 MiB/16 opens and transient heap <=24 MiB with a defensible measurement method. Do not infer these from harness duration or native scheduling counters. Preserve the full later-gate sampling/profile requirements.

## Freeze and handoff

`source-inputs.json` is the static reference inventory. `artifact-inventory.json` records the proposal files and a second read-only source-hash/absence comparison. It does not certify the complete source graph, generated package, test success or production integration. No implementation diff is included because the required app authority and manifest cache seam do not yet exist. Root can take stage 1 as the next bounded production implementation, then stage 2/3 with the focused acceptance work above.
