# Professional round persistence and settlement

`scripts/professional_session.gd` wraps the asynchronous `ProfessionalStore` contract and the existing wallet's synchronous `credit(receipt_id, tier)` operation. It never updates Growth, selects a game, or invents an assessed answer. The caller supplies the actual sense, assessed skill, correctness, assistance, and atomic classification.

## Setup and round identity

```gdscript
var store = preload("res://scripts/professional_store.gd").new()
add_child(store)
store.configure([])
var session = preload("res://scripts/professional_session.gd").new()
add_child(session)
session.configure(store, coin_wallet.credit)
session.round_opened.connect(_professional_round_opened)
session.event_completed.connect(_professional_event_completed)
session.blocked.connect(_professional_persistence_failed)
session.open_round(resolved.context, resolved.requirements, stable_round_source_id)
```

Configure a controller once with one store and wallet. The store must guarantee deferred `completed(request_id, result)` responses, including failures; the production native and browser adapters do. The wallet callable must return the existing dictionary result with a boolean `ok`. It must use permanent receipt idempotency and report success only after saving. The controller does not support an asynchronous wallet callable.

`open_round(context, requirements, source_id)` validates and freezes deep copies, registers requirements lazily, saves context, loads progress, and drains pending reward outbox entries before reporting the round ready. Its immediate result is `{ok: true, pending: true, source_id, generation}`. Listen for `round_opened(source_id, generation, result)` and compare the source/generation to the current requested selection. `snapshot().ready` is true only for the current completed opening.

Source IDs are caller-supplied stable round identities. Reusing a source with changed context or requirements is rejected. Reopening a previously known source with exactly the same frozen identity is supported: it gets a new preparation generation and reloads its context/history, retaining old event identities. This permits cancelling another course's failed preparation and returning to an existing game. Superseded preparation jobs are cancelled; an in-flight operation finishes before its callback is ignored. A stale opening emits `stale: true` and a cancelled result. Already accepted answer jobs are preserved in their original order. Failed preparation can be superseded; failed accepted evidence must be retried before later evidence.

Call `leave_round()` to invalidate the current UI source and cancel pending preparation while continuing already accepted settlement. It does not discard saved reward obligations. `recover()` can load history and drain the outbox before any course is chosen; recovery does not invent an active round.

## Submit and synchronously poll collection

```gdscript
var result = session.submit({
    "id": deterministic_event_id,
    "sense_id": canonical_sense_id,
    "skill": "spelling",
    "correct": true,
    "assisted": actual_assisted_flag,
    "atomic": actual_atomic_flag,
    "reward": {"operation": "credit", "payload": {"tier": existing_reward_tier}}
}, stable_round_source_id)
```

Omit `reward` for a zero-coin event. The session supplies the frozen context; an explicitly supplied different context is rejected. The event ID must be deterministic for that particular attempt, and must remain identical on all retries. A same-ID, same-source, same-payload call polls existing work. Changed payload or source is rejected. Do not mint a fresh ID because a request timed out.

The first accepted call returns `{ok: false, pending: true, code: "pending", id, source_id, generation}`. A synchronous game callback must retain its tile/attempt and poll the same event later, either by calling `submit()` with the identical payload or `poll_event(id, source_id)`. Success returns `ok: true, pending: false` only after the progress transaction and any reward/acknowledgment complete. It contains `id`, source/generation, `duplicate`, `progress_sequence`, and optional `wallet` result. Repeated successful polls remain successful and never enqueue another reward. The latest full history is available through `snapshot().progress`, rather than duplicated into every retained event receipt.

Professional Word Jelly records one successful spelling event at **completed collection**, using the composition's actual assisted/atomic flags. A successful merge does not also record that answer. Incorrect manual merges are separate immediate incorrect events. Atomic collection has `atomic: true`, counts exposure only, and may still carry a legitimate collection reward. Assisted correct collection preserves the current streak but does not advance it. Zero-reward collection still waits for the durable answer record before removal. No extra exposure-only event field or fake assistance flag is required.

`event_completed(id, source_id, result)` identifies the original submitting source, even if it is no longer visible. New events from an inactive source are rejected, while an already accepted event remains pollable after switching. The UI must not apply another source's completed callback to its current game. Its global professional progress and wallet can still reflect the successful durable transaction.

## Failure, retry, and recovery

The FIFO queue preserves answer order. A failed record retains the exact payload and ID at the front; later events cannot overtake a mistake and incorrectly preserve a streak. Wallet failure retains the committed outbox. Wallet success is followed by an `ack` store request; if acknowledgment fails, an in-process retry repeats only the acknowledgment. After a crash, recovery replays the same permanent `professional:<event-id>` wallet receipt, so the wallet rejects a second credit and acknowledgment can finish safely.

`blocked(source_id, event_id, result)` exposes failures, including the job phase. Failed event polls return `ok: false, pending: false, retryable: true`, an error, and the retained source/ID. Call `retry()` after the user retries or the relevant availability changes. Polling by itself does not repeatedly write a failed job. The queue remains blocked until successful retry, except that superseded preparation may be cancelled. There is no automatic endless retry loop.

`changed(snapshot)` and `snapshot()` expose `configured`, `ready`, `source_id`, `generation`, frozen `context`, `progress_loaded`, latest `progress`, `saved_context`, `pending_count`, compact `pending` job descriptions, `outbox_pending`, `blocked`, and the failure dictionary in `error`. Before a successful read, `progress_loaded` is false; an empty progress dictionary is not represented as a newly created profile.

Accepted but not yet committed answers live in this controller's memory. The caller must retain the game attempt and show pending/failure until durable success; destroying the controller before commit can lose that uncommitted attempt. Once the store commits an event, progress and its reward obligation survive process loss. Do not destroy a controller merely because its game screen was replaced; `leave_round()` exists for that transition.

## Validation

Run `node tools/run-godot.cjs --headless --path . --script res://tests/godot/professional_session_tests.gd`. The tests use real native professional persistence and the real wallet, including failed record, failed wallet, failed acknowledgment, unchanged-ID retries, FIFO streak order, zero-reward and rewarded atomic collection, frozen caller data, conflicting source/payload rejection, rapid switching, failed preparation/resume, leaving with pending evidence, and crash recovery after a wallet commit but before acknowledgment. Progress parity is also checked by the existing native and Chromium IndexedDB suites.
