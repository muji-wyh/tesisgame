extends SceneTree

const Session = preload("res://scripts/professional_session.gd")
const Store = preload("res://scripts/professional_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

var checks := 0
var failures := 0
var directory: String
var store: Node
var session: Node
var wallet: RefCounted
var fail_wallet := false
var wallet_calls: Array = []
var blocked_count := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _module() -> Dictionary:
	var terms: Array = []
	var expressions: Array = []
	for index in range(50):
		terms.append({"sense_id": "sense-%d" % index, "skills": ["recognition", "context", "spelling"]})
	for index in range(10):
		expressions.append("expression-%d" % index)
	# This atomic sense is reachable through picture recognition, not spelling.
	terms[1].skills = ["recognition"]
	return {"course_id": "retail", "module_id": "module01", "curriculum_revision": "content-1",
		"requirements_revision": "objectives-1", "terms": terms, "expressions": expressions}


func _context(mode: String = "word_jelly") -> Dictionary:
	return {"track": "professional", "course_id": "retail", "module_id": "module01", "curriculum_revision": "content-1", "mode": mode}


func _event(id: String, changes: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"id": id, "sense_id": "sense-0", "skill": "spelling", "correct": true, "assisted": false, "atomic": false}
	value.merge(changes, true)
	return value


func _credit(receipt: String, tier: int) -> Dictionary:
	wallet_calls.append({"receipt_id": receipt, "tier": tier})
	return {"ok": false, "error": "Injected wallet failure."} if fail_wallet else wallet.credit(receipt, tier)


func _settled() -> void:
	for _index in range(180):
		var state: Dictionary = session.snapshot()
		if state.blocked or state.pending_count == 0:
			return
		await process_frame
	check(false, "Session queue settles within the bounded test frames")


func _run() -> void:
	directory = "user://professional-session-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(directory) == OK, "Create isolated durable session directory")
	store = Store.new()
	root.add_child(store)
	check(store.configure([], directory.path_join("progress.json")), "Configure fresh session store")
	wallet = Wallet.new(directory.path_join("wallet.cfg"))
	check(wallet.load_state(), "Load real wallet for idempotent settlement")
	session = Session.new()
	root.add_child(session)
	check(session.configure(store, _credit), "Configure exclusive session persistence and wallet callback")
	session.blocked.connect(func(_source: String, _id: String, _result: Dictionary) -> void: blocked_count += 1)
	await _test_context_and_evidence()
	await _test_record_failure()
	await _test_wallet_and_ack_failure()
	await _test_source_switch()
	await _test_recovery()
	session.queue_free()
	store.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "Remove session fixture")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated session directory")
	print("Professional session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_context_and_evidence() -> void:
	check(not session.snapshot().progress_loaded and session.snapshot().progress.is_empty(), "An unloaded store is explicit, not a fabricated fresh profile")
	var context: Dictionary = _context()
	var requirements: Dictionary = _module()
	var opening: Dictionary = session.open_round(context, requirements, "round-1")
	check(opening.ok and opening.pending, "Opening a round registers and loads asynchronously")
	check(session.submit(_event("too-early")).code == "not_ready", "No answer accepted before durable context is ready")
	context.course_id = "changed"
	requirements.terms[0].sense_id = "changed"
	await _settled()
	check(session.snapshot().ready and session.snapshot().progress_loaded, "Context registration and recovery completed")
	check(session.snapshot().context.course_id == "retail" and store.transact_native("load").context.course_id == "retail", "Context and requirements are frozen against caller mutation")
	var first: Dictionary = _event("first")
	check(session.submit(first).pending, "Synchronous game callback queues a durable answer")
	first.correct = false
	check(session.submit(first).code == "event_conflict", "Changing a queued payload cannot reuse its event ID")
	check(session.submit(_event("first"), "another-source").code == "source_conflict", "Duplicate IDs cannot cross round sources")
	session.submit(_event("second"))
	session.submit(_event("hinted", {"assisted": true}))
	session.submit(_event("atomic-zero", {"sense_id": "sense-1", "atomic": true}))
	await _settled()
	var state: Dictionary = session.snapshot()
	check(state.progress.skills["sense-0"].spelling.streak == 2 and not state.progress.skills["sense-0"].spelling.earned, "Assisted collection preserves streak without granting mastery")
	check(state.progress.skills["sense-1"].spelling.exposures == 1 and not state.progress.skills["sense-1"].spelling.earned, "Zero-reward atomic collection persists exposure only")
	check(session.submit(_event("first")).ok and session.poll_event("first").ok, "Repeated synchronous callback consumes the same completed result")
	check(state.progress.sequence == 4 and wallet_calls.is_empty(), "Polling and reward-free collection do not mint rewards or duplicate evidence")
	session.submit(_event("third"))
	await _settled()
	check(session.snapshot().progress.skills["sense-0"].spelling.earned, "Third actual unassisted collection earns assessed mastery")
	check(session.submit(_event("bad-context", {"context": _context("match")})).code == "context_conflict", "Event cannot replace frozen exercise mode")
	check(session.open_round(_context("match"), _module(), "round-1").code == "source_conflict", "Round source identity is immutable")


func _test_record_failure() -> void:
	var before: int = session.snapshot().progress.sequence
	store.before_commit = func(operation: String) -> bool: return operation != "record"
	session.submit(_event("retry-answer", {"correct": false}))
	session.submit(_event("after-retry"))
	await _settled()
	check(session.snapshot().blocked and session.snapshot().pending_count == 2, "Failed record blocks later evidence without dropping either event")
	check(session.poll_event("retry-answer").code == "storage_failed" and store.transact_native("load").progress.sequence == before, "Failed native write has no false success")
	store.before_commit = Callable()
	session.retry()
	await _settled()
	check(session.poll_event("retry-answer").ok and session.poll_event("after-retry").ok, "Retry retains exact IDs and drains FIFO")
	check(session.snapshot().progress.sequence == before + 2 and session.snapshot().progress.skills["sense-0"].spelling.streak == 1, "Wrong answer then correct answer apply in original order")


func _test_wallet_and_ack_failure() -> void:
	var reward: Dictionary = _event("rewarded", {"reward": {"operation": "credit", "payload": {"tier": 1}}})
	fail_wallet = true
	session.submit(reward)
	await _settled()
	check(session.poll_event("rewarded").code == "wallet_failed" and store.transact_native("load").outbox.size() == 1, "Wallet failure retains the committed outbox")
	check(wallet.balance == 0, "Failed reward grants no coins")
	var sequence: int = session.snapshot().progress.sequence
	fail_wallet = false
	store.before_commit = func(operation: String) -> bool: return operation != "ack"
	session.retry()
	await _settled()
	check(wallet.balance == 50 and session.snapshot().blocked, "Wallet saves once before acknowledgment may fail")
	check(session.poll_event("rewarded").phase == "ack" and store.transact_native("load").outbox.size() == 1, "Ack failure remains at acknowledgment phase")
	var calls: int = wallet_calls.size()
	store.before_commit = Callable()
	session.retry()
	await _settled()
	check(session.submit(reward).ok and wallet_calls.size() == calls, "Ack retry does not repeat in-process wallet call")
	check(store.transact_native("load").outbox.is_empty() and session.snapshot().progress.sequence == sequence and wallet.balance == 50, "Durable collection and reward settle exactly once")
	var atomic: Dictionary = _event("atomic-reward", {"sense_id": "sense-1", "atomic": true, "reward": {"operation": "credit", "payload": {"tier": 1}}})
	session.submit(atomic)
	await _settled()
	check(session.poll_event("atomic-reward").ok and wallet.balance == 100 and not session.snapshot().progress.skills["sense-1"].spelling.earned, "Rewarded atomic collection is still only exposure")


func _test_source_switch() -> void:
	var old: Dictionary = _event("old-source-pending")
	session.submit(old, "round-1")
	var responses: Array = []
	session.round_opened.connect(func(source: String, generation: int, result: Dictionary) -> void:
		responses.append({"source": source, "generation": generation, "result": result}))
	check(session.open_round(_context("match"), _module(), "round-2").pending, "New round queues behind accepted old settlement")
	check(session.open_round(_context(), _module(), "round-3").pending, "Rapid round switch retains distinct source generation")
	await _settled()
	check(session.poll_event("old-source-pending", "round-1").ok, "Previously accepted old round event still completes")
	check(session.snapshot().ready and session.snapshot().source_id == "round-3", "Only latest round becomes current")
	check(responses.size() == 2 and responses[0].result.stale and not responses[1].result.stale, "UI receives explicit stale source identity for replaced opening")
	check(session.submit(_event("old-new"), "round-1").code == "stale_source", "Old callback cannot create a new assessment after switching")
	store.before_commit = func(operation: String) -> bool: return operation != "context"
	session.open_round(_context("match"), _module(), "failed-preparation")
	await _settled()
	check(session.snapshot().blocked and session.snapshot().error.phase == "context", "New-course preparation can fail before the old game is discarded")
	store.before_commit = Callable()
	check(session.open_round(_context(), _module(), "round-3").pending, "Returning to an unchanged known round starts a new preparation generation")
	await _settled()
	check(session.snapshot().ready and not session.snapshot().blocked and session.snapshot().source_id == "round-3", "Failed superseded preparation cannot block resuming the preserved round")
	check(session.submit(_event("old-source-pending"), "round-1").ok, "Earlier completed event remains idempotently pollable after resume")
	session.submit(_event("leaving"), "round-3")
	session.leave_round()
	await _settled()
	check(not session.snapshot().ready and session.snapshot().source_id.is_empty() and session.poll_event("leaving", "round-3").ok, "Leaving invalidates UI identity while accepted settlement completes")


func _test_recovery() -> void:
	var event: Dictionary = _event("crash-before-ack", {"context": _context(), "reward": {"operation": "credit", "payload": {"tier": 2}}})
	check(store.transact_native("record", event).ok, "Simulate persisted event before session restart")
	check(wallet.credit("professional:crash-before-ack", 2).ok and wallet.balance == 200, "Simulate wallet commit before crash without acknowledgment")
	session.queue_free()
	await process_frame
	session = Session.new()
	root.add_child(session)
	check(session.configure(store, _credit), "Recreate controller after crash")
	check(session.recover().pending, "Recovery works before choosing a course")
	await _settled()
	check(wallet.balance == 200 and store.transact_native("load").outbox.is_empty(), "Recovery reuses permanent wallet receipt and clears outbox once")
	check(session.snapshot().progress_loaded and not session.snapshot().ready, "Recovered history does not invent an active round")
	check(session.open_round(_context(), _module(), "restored-round").ok, "Open a new frozen context after recovery")
	await _settled()
	var replay: Dictionary = event.duplicate(true)
	replay.erase("context")
	var submitted: Dictionary = session.submit(replay)
	check(submitted.get("pending", false), "Durable replay is accepted: " + str(submitted))
	await _settled()
	var replayed: Dictionary = session.poll_event("crash-before-ack")
	check(replayed.get("duplicate", false) and wallet.balance == 200, "Replayed durable event after restart never duplicates progress or coins: " + str(replayed))
