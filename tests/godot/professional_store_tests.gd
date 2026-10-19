extends SceneTree

const Store = preload("res://scripts/professional_store.gd")
const Progress = preload("res://scripts/professional_progress.gd")

var checks := 0
var failures := 0
var _directory := ""


class Host extends RefCounted:
	var requests: Array = []

	func professionalProgressRequest(text: String, callback: Callable) -> void:
		requests.append({"request": JSON.parse_string(text), "callback": callback})

	func reply(index: int) -> void:
		var request: Dictionary = requests[index].request
		requests[index].callback.call([JSON.stringify({"request_id": request.request_id,
			"ok": true, "progress": Progress.empty_progress(), "error": ""})])


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
		terms.append({"sense_id": "sense-%d" % index, "skills": ["recognition"]})
	for index in range(10):
		expressions.append("expression-%d" % index)
	return {"course_id": "retail", "module_id": "workplace", "curriculum_revision": "content-1",
		"requirements_revision": "objectives-1", "terms": terms, "expressions": expressions}


func _event(id: String) -> Dictionary:
	return {"id": id, "sense_id": "sense-0", "skill": "recognition", "correct": true,
		"assisted": false, "atomic": false,
		"context": {"track": "professional", "course_id": "retail", "module_id": "workplace",
			"curriculum_revision": "content-1", "mode": "match"},
		"reward": {"operation": "credit", "payload": {"tier": 1}}}


func _run() -> void:
	_directory = "user://professional-store-close-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(_directory) == OK, "Create isolated store-disposal directory")
	await _test_host_results_and_timeout()
	await _test_exit_tree_is_terminal()
	await _test_native_deferred_disposal()
	await _test_native_retry_disposal()
	await _test_committed_outbox_recovery()
	_test_close_during_commit_callback()
	for file in DirAccess.get_files_at(_directory):
		check(DirAccess.remove_absolute(_directory.path_join(file)) == OK, "Remove isolated store fixture")
	check(DirAccess.remove_absolute(_directory) == OK, "Remove isolated store-disposal directory")
	print("Professional store terminal disposal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_host_results_and_timeout() -> void:
	var host := Host.new()
	var store = Store.new()
	root.add_child(store)
	var emitted: Array = []
	store.completed.connect(func(id: int, result: Dictionary) -> void: emitted.append([id, result]))
	var path: String = _directory.path_join("host.json")
	check(store.configure([], path, host), "Configure host storage")
	var id: int = store.request("load")
	var generation: int = store._generation
	var tracked: Dictionary = store._timers[id]
	var timer: SceneTreeTimer = tracked.timer
	var timeout_callback: Callable = tracked.callback
	check(host.requests.size() == 1 and timer.timeout.is_connected(timeout_callback), "Host request retains a live timeout")
	# Queue a valid delivery before close, then also send a late host result after close.
	host.reply(0)
	store.close()
	store.close()
	host.reply(0)
	timer.timeout.emit()
	store._timeout(id, generation)
	await process_frame
	await process_frame
	check(emitted.is_empty() and not store.storage_ready and store.error == Store.CLOSED_ERROR,
		"Queued delivery, late host result and late timeout cannot publish after close")
	check(not timer.timeout.is_connected(timeout_callback) and store._timers.is_empty()
		and store._callbacks.is_empty() and store._pending.is_empty() and store._host == null,
		"Close releases callback ownership and disconnects the host timer")
	check(not store.configure([], path, host) and store.request("load") == 0 and host.requests.size() == 1,
		"A closed store cannot reconfigure or dispatch another host request")
	var result: Dictionary = store.transact_native("load")
	check(not result.ok and not result.retryable and result.reason == "closed", "Closed direct transactions report terminal disposal")
	check(not FileAccess.file_exists(path), "Host disposal creates no native snapshot")
	store.free()


func _test_exit_tree_is_terminal() -> void:
	var host := Host.new()
	var store = Store.new()
	root.add_child(store)
	var emitted: Array = []
	store.completed.connect(func(id: int, result: Dictionary) -> void: emitted.append([id, result]))
	check(store.configure([], _directory.path_join("exit-tree.json"), host), "Configure tree-exit fixture")
	store.request("load")
	root.remove_child(store)
	check(store.is_closed(), "Tree exit closes the store before node destruction")
	host.reply(0)
	root.add_child(store)
	check(not store.configure([], _directory.path_join("reattached.json"), host) and store.request("load") == 0,
		"Reattaching a disposed store does not restore its authority")
	await process_frame
	check(emitted.is_empty() and host.requests.size() == 1, "Tree-exit disposal suppresses retained host callbacks")
	store.free()


func _test_native_deferred_disposal() -> void:
	var store = Store.new()
	root.add_child(store)
	var path: String = _directory.path_join("deferred.json")
	var emitted: Array = []
	store.completed.connect(func(id: int, result: Dictionary) -> void: emitted.append([id, result]))
	check(store.configure([_module()], path), "Configure deferred native fixture")
	var id: int = store.request("record", _event("never-started"))
	check(id > 0, "Record starts as an asynchronous request")
	store.close()
	await process_frame
	await process_frame
	check(emitted.is_empty() and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".pending"),
		"Native work queued before close cannot write or emit afterward")
	check(store.request("record", _event("after-close")) == 0, "Closed native store refuses new requests")
	store.free()


func _test_native_retry_disposal() -> void:
	var store = Store.new()
	root.add_child(store)
	var path: String = _directory.path_join("retry.json")
	var emitted: Array = []
	store.completed.connect(func(id: int, result: Dictionary) -> void: emitted.append([id, result]))
	check(store.configure([_module()], path), "Configure native retry fixture")
	var absolute: String = ProjectSettings.globalize_path(path).simplify_path()
	if OS.get_name() == "Windows":
		absolute = absolute.to_lower()
	var lock := TCPServer.new()
	var port: int = 20000 + absolute.sha256_text().substr(0, 8).hex_to_int() % 40000
	var locked: bool = lock.listen(port, "127.0.0.1") == OK
	check(locked, "Hold the real native transaction lock to require a retry")
	if not locked:
		store.free()
		return
	var event: Dictionary = _event("retry-after-close")
	var id: int = store.request("record", event)
	for frame in range(8):
		if store._timers.has(id):
			break
		await process_frame
	check(store._timers.has(id) and store._pending.has(id), "Busy native transaction retains its scheduled retry")
	if store._timers.has(id):
		var tracked: Dictionary = store._timers[id]
		var timer: SceneTreeTimer = tracked.timer
		var callback: Callable = tracked.callback
		# Also preserve a callback already queued by the signal dispatcher.
		callback.call_deferred()
		store.close()
		lock.stop()
		timer.timeout.emit()
		await process_frame
		await process_frame
		check(not timer.timeout.is_connected(callback) and store._timers.is_empty(), "Close disconnects the native retry timer")
		check(emitted.is_empty() and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".pending"),
			"Released lock and late retry cannot revive a disposed transaction")
	else:
		store.close()
		lock.stop()
	store.free()


func _test_committed_outbox_recovery() -> void:
	var store = Store.new()
	root.add_child(store)
	var path: String = _directory.path_join("committed.json")
	var emitted: Array = []
	store.completed.connect(func(id: int, result: Dictionary) -> void: emitted.append([id, result]))
	check(store.configure([_module()], path), "Configure committed event fixture")
	var event: Dictionary = _event("durable-reward")
	check(store.transact_native("record", event).ok, "Commit an answer and wallet outbox before disposal")
	var snapshot: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for suffix in [".previous", ".pending"]:
		var file := FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_buffer(snapshot)
		file.close()
	store.request("ack", {"id": event.id})
	store.close()
	await process_frame
	await process_frame
	check(emitted.is_empty(), "Queued acknowledgment cannot publish after disposal")
	check(not store.transact_native("ack", {"id": event.id}).ok, "Disposed owner cannot acknowledge durable rewards")
	for suffix in ["", ".previous", ".pending"]:
		check(FileAccess.get_file_as_bytes(path + suffix) == snapshot, "Close preserves durable snapshot bytes: " + suffix)
	var recovery = Store.new()
	root.add_child(recovery)
	check(recovery.configure([_module()], path), "A new store can acquire the durable save")
	var loaded: Dictionary = recovery.transact_native("load")
	check(loaded.ok and loaded.progress.sequence == 1 and loaded.outbox.size() == 1
		and loaded.outbox[0].receipt_id == "professional:durable-reward", "Committed event and unacknowledged reward survive disposal")
	check(recovery.transact_native("record", event).duplicate, "Recovered event remains idempotent")
	check(recovery.transact_native("ack", {"id": event.id}).ok and recovery.transact_native("load").outbox.is_empty(),
		"Only an explicit acknowledgment by the new owner clears the recovered outbox")
	store.free()
	recovery.free()


func _test_close_during_commit_callback() -> void:
	var store = Store.new()
	root.add_child(store)
	var path: String = _directory.path_join("reentrant-close.json")
	check(store.configure([_module()], path), "Configure reentrant disposal fixture")
	store.before_commit = func(_operation: String) -> bool:
		store.close()
		return true
	var result: Dictionary = store.transact_native("record", _event("closed-before-persist"))
	check(not result.ok and result.reason == "closed" and not FileAccess.file_exists(path)
		and not FileAccess.file_exists(path + ".pending"), "Disposal from a commit callback revokes the remaining write")
	store.free()
