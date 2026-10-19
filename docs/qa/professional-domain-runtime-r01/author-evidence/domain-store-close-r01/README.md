# Professional store terminal disposal preparation

Prepared scripts/professional_store.gd and the new tests/godot/professional_store_tests.gd. The existing progress suite remains unchanged. Original store bytes and the prior absence of the dedicated suite are recorded in preimages.json. Prepared file copies bind the handoff independently of later integration.

The public close() is idempotent and terminal; _exit_tree calls it. is_closed() exposes state. A closed configure returns false; request returns zero without a completion or dispatch; direct native transactions return a nonretryable closed result. Close invalidates the callback generation, disconnects tracked host-timeout and native-retry timers, and releases in-memory pending requests, host callbacks and the host reference. Deferred receive, delivery and native work cannot resume after close. A reentrant close in before_commit is checked before persistence.

Durable snapshots, answer receipts and unacknowledged wallet outbox entries remain untouched by close. Already-dispatched host commits may finish externally and are recovered by a new store. No policy or selection cancellation path closes storage.

The dedicated suite prepares six meaningful lifecycle scenarios, including real native lock contention and recovery by a fresh store. It has not been parsed or run. No native, test, build, export or packaging process was dispatched. Root coordinates execution; the new suite is not wired into tools/run-tests.cjs because that file is outside this assignment.

Read prepared-evidence.json for exact API behavior, checks and hashes. artifact-inventory.json binds this preparation except itself. Do not infer test success from static evidence.
