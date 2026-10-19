# ProfessionalPlay synchronous callback regression

The focused Godot 4.7 run passed **31 current checks with 0 failures** in **1,440 ms**. All **24 guarded inputs** were unchanged during the single dispatch. The same process separately replayed the saved original controller: **17 observations included 14 failing invariants**. Those historical failures are retained as reproductions, not counted as passing current-code checks. The native log contains only the engine banner and the two clearly separated summaries.

Only `scripts/professional_play.gd` and `tests/godot/professional_play_tests.gd` were modified. Both were existing untracked files; their exact bytes were saved under `preimages/` before editing. No other production file, content review, domain decision, policy installation, shared runner, build or export was changed.

## Behavior fixed

- A request captures its five supported context fields and an epoch before the earliest synchronous session notification. A nested request, cancellation or leave wins; the outer call cannot submit stale work or restore its pending selection afterward.
- The loader's synchronous theme callback cannot overwrite a newer pending selection when the original `request()` returns.
- `cancel()` and `leave()` retain any newer request created by their session callbacks. Cancelling pending preparation still keeps the active round's claimed media lease.
- `_media_prepared()` captures the source/epoch before opening storage and discards a returned result if a callback replaced or cleared pending work.
- `_round_opened()` captures the selection/source/content before notifying observers and rechecks them afterward. A stale callback cannot publish a new selection with the old source or read a cleared pending dictionary.
- Both retry continuations stop when a callback changes the selection. An obsolete retry cannot overwrite the newer phase or start recovery after a newer request.

The source diff is [review.diff](review.diff); [completion.json](completion.json) binds original and final file hashes. Source and test files are frozen after the successful dispatch for root's combined validation.

## Validation boundaries

The current suite retains all **10 existing real initial-storage recovery checks** and adds **21 controller checks**. Controlled loader/session/store callbacks exercise the actual `ProfessionalPlay` methods through their supported signals. They neither resolve curriculum nor grant fake domain acceptance. The active-lease checks use the actual Access registry around a controlled cache/resource and verify retention during pending cancellation plus exact single release on controller destruction. They do not establish real media fetch, hash/decode, playback or full application acceptance.

The saved-preimage replay uses the same probes but omits four cases that would read an empty pending dictionary in the old code and intentionally abort a GDScript function. Those four cases run against the fixed controller and pass without engine errors. The 14 remaining reproducible failures cover earliest session reentry, caller mutation, loader reentry, cancel/leave continuation, active restoration, ready publication, storage-opening completion and both retry continuations. Three unchanged control observations pass on both versions: active lease retention, single teardown release and normal current ready publication.

Evidence:

- [Original capture journal](change-journal.json), exact [controller preimage](preimages/scripts/professional_play.gd), and [test preimage](preimages/tests/godot/professional_play_tests.gd).
- [Pre-dispatch input inventory](execution-input-inventory.json) and [native attempt](native-attempt.json).
- [Historical failing observations](original-reproduction.json), [current passing assertions](current-report.json), [native log](native.log), and [validation receipt](validation-receipt.json).

The validation receipt SHA-256 is `8b8f1f8cb4b317a250167968b7a58e6a0809895875f35989aba7b03bba0bac78`. Final controller SHA-256 is `348431e211ca691aa873e201d8a5688e3e8f1cc63bc2fda6b8851b3c41a22db0`; final dedicated test SHA-256 is `c6fea401bb2eea0e0399aec939ec5e84f0c31e308a5bdc4554dc25acecb9c7f6`. Root owns subsequent combined validation. No additional focused native run is needed.
