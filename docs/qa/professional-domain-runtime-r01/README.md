# Professional domain runtime integration: native focused checks

The production owner, private verified catalog, asynchronous round loader, Play lifecycle and terminal Store disposal are integrated. The nine focused native suites passed 848 checks with zero failures, after four successful syntax checks. All 265 bound GDScript/project/runner inputs stayed unchanged during this execution. No warning or engine error appeared in these logs.

| Actual suite | Passed checks |
| --- | ---: |
| Production owner native unavailable path | 263 |
| Asynchronous loader and scoped media protocol | 63 |
| Store terminal disposal | 36 |
| Play cancellation, reentrancy and closure | 41 |
| Existing progress and persistence | 240 |
| Existing session and settlement queue | 53 |
| Media bundles and pending/claimed scopes | 51 |
| Actual application with synthetic owner/media, six modes | 91 |
| Component view teardown | 10 |

The [execution receipt](checks-r01/receipt.json) SHA256 is `3ec61c23453f1484beb87e7be1b4d258d2ce23ad03ba77a75cac95f4aafe3439`. Each log has its own hash in that receipt. These are nine separate suite executions in one sequential witness, not 848 independently dispatched tests. The [copy receipt](copy-receipt.json), SHA256 `d059a41d56a280c0d43b8f43c861ae745bc789a1c86a55ad2dc2b63bd3f43781`, binds 87 preserved files; this README is added afterward.

The loader uses the application-owned policy owner for round authorization and keeps the ordinary catalog for Home metadata. It defers owner/media completion, checks current registered tokens at callback boundaries, and transfers a pending media scope only once. Play checks authorization before storage and publication, cancels obsolete opens on owner retirement, and leaves accepted answer/wallet/ack jobs intact. Store close is terminal and revokes callbacks/retries without deleting committed progress or outbox receipts. A native commit already dispatched to an external host cannot be rolled back by local closure.

The game claims the new round before clearing existing views, retains the previous lease until old view/audio cleanup, and defers claim notification until the synchronous handoff finishes. The application fixture now waits for the exact asynchronous media selection instead of treating idle storage as completed preparation. Obsolete-source preflight, retirement after an open is queued, six game routes, shared career progress and Growth preservation are covered with explicitly synthetic fixtures.

The [independent static review](independent-review/README.md), review SHA256 `da3d1e6618810b12dafef3a8691c8b9bfcd3c27d50a8b92f0066630bc8f32073`, found and retained one corrected Play reentrancy defect: a new selection begun inside loader cancellation could be overwritten by the old frame. Immediate epoch guards and state detachment before resource release resolve that source finding. The subsequent focused Play execution includes the new cancellation probes. Exact source snapshots, author preimages and reports are preserved; copied scripts are evidence and must not be replayed from this directory.

Limits remain explicit. The production owner deliberately rejects native/editor authorization before policy I/O because no source-bound native launcher is installed. Its successful compiled-policy path requires a separately audited actual Web fixture. Loader/application success cases here use test protocol doubles and synthetic content, not ready curricula or a production authorization bypass. Whole-scene disposal ordering, final-claim failure after preflight, retirement with an already dispatched Store response, actual Web media/decoder/cache behavior, performance, physical devices and human media acceptance remain separate work. A new scene-disposal test is being authored to resolve the first ordering question. The earlier successful Web build predates this source integration and remains historical evidence. No deployment occurred; zero modules are ready.
