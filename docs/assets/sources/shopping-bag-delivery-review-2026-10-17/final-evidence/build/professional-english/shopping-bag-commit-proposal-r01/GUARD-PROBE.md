# Optional root-owned guard probe

guard-probe.cjs is unexecuted. It imports only built-ins and the side-effect-free frozen commit source. There is no CLI dispatch or write API. Root must pin both source files before importing either and retain its own fresh one-shot wrapper/output directory, source/input hashes, successful result or failure, and before/after real-file witnesses. The author has done only raw source inspection.

Call runProbe(actualInput, readOnlyAdapter, invocation), where invocation has repository_root, source_sha256 and token. The adapter is the commit source's realAdapter for the exact worktree, or a separately reviewed adapter with read, exists and list. Inputs must already be fully bound and independently reviewed; the initial positive validate call rejects unfinished candidates or metadata. No commit attempt or transaction may already exist.

The result includes all guard case names, outcomes and unchanged real-file descriptors. On a case failure, the thrown error also carries probe_cases and probe_real_inputs for root's immutable failure receipt. A failing early baseline does not establish negative-case coverage. The root wrapper must still rehash protected real inputs after failure.

The probe uses in-memory synthetic review envelopes to reach specific rejection guards without altering the actual review. Its synthetic journal is built directly from the accepted target manifest; the transaction helper is never called. This tests verifier checks against complete, incomplete, drifted and internally consistent rewritten journal states. It does not establish filesystem rename/recovery behavior, Windows symlink/junction handling, a loaded-registry result, candidate tests or persisted validation.

All disk access uses the read-only supplied adapter. Production mutations, project/native execution and transaction-helper execution are false in the successful receipt. Root alone decides whether to dispatch this optional probe and any later actual commit.
