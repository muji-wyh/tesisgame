# Professional round loader integration r01

The production round loader now prepares Professional rounds through its internal application-pinned owner. The ordinary catalog remains available for Home metadata; the request path never calls its resolve method. This is an implementation handoff, not runtime acceptance.

Only scripts/professional_round_loader.gd and tests/godot/professional_round_loader_tests.gd were edited by this assignment. Exact preimages were copied before editing and are bound by preimages.json. The parent independently owns the production owner/catalog installation, Play, session/storage, view lifecycle and application tests.

## Loader API and lifecycle

- configure(host, native_root) retains its first result and transport. Repeated successful configuration returns true without reconnecting signals, rereading the Home index or resetting media. Partial initialization remains false; a new instance is needed to retry initialization.
- request(context, seed) freezes a valid Professional context, dispatches only the internal owner, and returns its loader selection before any prepared or failed publication. The private preparation records selection, context/seed, owner, owner request/token, resolved content, media instance/generation and pending scope.
- Owner and media signal handlers copy and defer normal completion processing. Policy completion matches the owner and request, verifies token registration, resolves once, and checks the returned context. Authority is checked after theme_selected, after media request, before acquisition, after acquisition/binding and before preparation publication.
- can_claim(selection) is a synchronous preflight requiring the current prepared token and a pending scope. claim(selection) repeats authorization after media binding, transfers the scope once and clears private pending token/content. Later cancellation and terminal closure preserve that claimed scope.
- cancel() revokes pending authority, releases only its pending scope and cancels owner/media. Reentrant resource or host callbacks cannot make the old cancellation overwrite a new request.
- close() is terminal and idempotent. It revokes pending state, cancels media and retires the owner. invalidated(selection, result) is emitted synchronously once, with the selection from before cancellation and a policy_unavailable result. Play must invalidate its pending storage open immediately; normal prepared/failed completions remain deferred.

No caller-facing production API accepts a pin, policy snapshot, accepted ID list, owner, fixture or source fallback. The production owner's native/editor fail-closed behavior was not modified.

## Focused test fixture API

The test script exports FixtureOwner as an inner class. Tests may replace loader._owner before configure; they must free the initial unparented owner first. The production loader exposes no injection method.

FixtureOwner.new() supports explicitly controlled finish(request_id), fail(request_id), cancellation, retirement and inline-completion adversaries. FixtureOwner.new(existing_fixture_catalog) instead schedules the fixture catalog's resolve(context, seed) asynchronously, rechecks the request, registers its own private token and publishes that token. This optional constructor belongs only to the test double and allows the parent to retain its existing application-flow synthetic content.

The focused suite retains existing scoped WordArt/audio, library/theme/motion dependency and old/new lease assertions. Added cases cover configuration failure/idempotency, deferred inline completions, frozen caller context, defensive theme copies, A/B/A identity, stale policy/media results, unregistered/revoked tokens, result-context mismatch, duplicate completion/claim, reentrant theme replacement, acquisition/claim cancellation and terminal retirement. Those cases have not been executed by this assignment.

## Verification and remaining integration

Source reading, textual comparison and file hashing were performed. No Godot syntax invocation, native process, test, build or export was dispatched. The parent is coordinating independent review and execution.

The focused execution command for that coordinated run is:

    node tools/run-godot.cjs --headless --path . --script res://tests/godot/professional_round_loader_tests.gd

An internal owner double does not establish successful production policy authorization. Successful real owner-to-view behavior still requires an independently audited exported Web fixture; the native/editor candidate remains unavailable by design.

A compatibility search found tests/godot/professional_media_bundles_tests.gd still injecting the removed loader._pending_scope field. The parent was notified to update that separate fixture to the private preparation record before broader dispatch. No out-of-scope test was edited here.
