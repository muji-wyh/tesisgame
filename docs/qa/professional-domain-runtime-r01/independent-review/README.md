# Independent runtime integration static review

Result: passed bounded static review after the Play cancellation correction. No unresolved concrete defect was found in the reviewed loader, Play, and UI integration paths. This is a source review, not a runtime test result.

The loader author and root confirmed the final hashes recorded in `source-inventory.json`. Exact copies are retained under `source/`. Supporting Session, Store, media access, media loader, media cache, and view-teardown test files are included as the bounded context inspected. This is not a complete dependency inventory or a build receipt. No production/test file was modified and no Godot, syntax check, test, build, browser, export, or heavy verifier was executed by this reviewer.

## Source conclusions

- The ordinary catalog remains the Home metadata provider. Round preparation requests the internal policy owner; the production loader does not authorize rounds by resolving the ordinary catalog.
- Owner and media completions are copied and deferred. Selection, source object, request/generation, and phase checks suppress replaced or duplicated callbacks. The owner token is checked again after resolving, theme notification, media dispatch, scope acquisition, and binding.
- Unclaimed scopes are cleared before release. Acquisition that loses authority releases its newly acquired scope. Successful claim removes the pending scope, content, and token from the preparation, transferring ownership once. Later cancellation and owner retirement preserve an already claimed round lease.
- Owner retirement synchronously closes the loader and invalidates the selected pending request. Play cancels its pending opening through Session while keeping Store alive. Session marks open jobs obsolete and preserves accepted event, wallet, and acknowledgement jobs.
- Play checks `can_claim` before opening storage and again when storage reports readiness. Request epochs prevent a nested request from being overwritten after Session notifications and loader calls. The corrected cancellation/leave paths also check epochs after loader cancellation and resource release boundaries.
- UI checks claimability and game-model preflight before teardown, then performs the final claim before clearing current controls. Claim defers its UI notification. `_rebuilding` rejects nested `new_round` calls and suppresses intermediate Professional UI refreshes during the synchronous handoff.
- Terminal Play close suppresses later loader/session publications and closes persistence. A failed partial configure closes the instance, and a second configure cannot reconnect children or signals. These conclusions cover control flow; scene-level disposal timing is excluded below.

## Finding resolved during this review

The first inspected Play revision, SHA256 `3295220a63a5593a43a6d08dad21c17ca06336ed069b569f50fed6e808d76602`, did not check its epoch immediately after `loader.cancel()`. Under the synchronous callback contract supported by the loader, a cancellation callback could start request B, then the older Play frame would clear B's `pending` state before reaching its later epoch check. `leave()` also mutated active/pending state after potentially reentrant scope release.

Root corrected this in Play SHA256 `1841fb1b60d6a0b576d352d50221202c94611ec9832f8f5b039e4fe13a078489`: immediate epoch checks after loader cancellation, active/pending detachment before releasing the captured old scope, and checks after release/deactivate/trim. The focused Play test now contains nested request probes for loader cancellation. This is statically resolved. Those probes were not executed by this reviewer. The earlier problem was a deterministic callback-contract defect; the bundled JavaScript cancellation function was not observed directly calling Play, so this review does not claim a reproduced normal-runtime failure.

## Runtime proof still required

1. Actual GameUI scene disposal ordering is not established. `game_ui.gd::_exit_tree` does not explicitly order all sibling view/audio cleanup before Professional Play releases its active scope. Component teardown tests and controller-only free tests do not prove callback/resource order in the whole scene. This is an unresolved validation question, not a demonstrated callback or resource failure.
2. The application test with `obsolete-source` rejects at early claim preflight. Its corrected label accurately describes that coverage. It does not exercise a failure in the final `claim` after earlier preflight has passed, or callbacks during successful view handoff.
3. The application retirement probe fires from `loader.prepared` after Session queues an open and before its deferred Store pump. It covers pending storage opening. It does not hold an already dispatched register/context/load response, retire the owner, and then deliver that response. Session's obsolete-open guard was inspected statically.
4. Loader success tests use internal protocol doubles and synthetic content. Application tests use a synthetic owner and media provider. They do not establish production Web accepted-policy success, ready modules, policy/native authorization bypasses, real media fetch/decode behavior, human review, listening/visual quality, performance, or memory acceptance.
5. The retained source snapshots and the author's freeze establish the reviewed bytes. Root's subsequently executed check results must be assessed separately; this report does not anticipate their outcome.

The earlier frozen Web build review and its evidence remain unchanged. Production source drift from that build is intentional and is not revalidated by this review.
