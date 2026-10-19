extends Node
## One asynchronous request API for IndexedDB and recoverable native snapshots.
## Wallet delivery is external: credit receipt_id, then acknowledge only success.

signal completed(request_id: int, result: Dictionary)

const Progress = preload("res://scripts/professional_progress.gd")
const DEFAULT_PATH := "user://professional-v1.json"
const MAX_SAVE_BYTES := 128 * 1024 * 1024
const REQUEST_TIMEOUT_SECONDS := 30.0
const CLOSED_ERROR := "Professional storage is closed."

var progress = Progress.new()
var storage_ready := false
var error := ""
# Fault injection for native transactional tests; production leaves this unset.
var before_commit: Callable
var _path := DEFAULT_PATH
var _host: Object
var _configured := false
var _closed := false
var _generation := 0
var _next_request := 0
var _callbacks: Dictionary = {}
var _pending: Dictionary = {}
var _timers: Dictionary = {}


func configure(requirements: Array, path: String = DEFAULT_PATH, host: Object = null) -> bool:
	if _closed:
		return false
	if not _pending.is_empty():
		error = "Finish pending professional storage requests before reconfiguring."
		return false
	if path.is_empty() or not progress.configure(requirements):
		error = progress.error if not progress.error.is_empty() else "Choose a professional save path."
		return false
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")
	_generation += 1
	_configured = true
	storage_ready = false
	error = ""
	return true


## Terminal owner disposal only; selection and policy cancellation must not close storage.
## Already committed snapshots and wallet outbox receipts remain recoverable by a new store.
func close() -> void:
	if _closed:
		return
	_closed = true
	_generation += 1
	_configured = false
	storage_ready = false
	error = CLOSED_ERROR
	for id in _timers.keys():
		_clear_timer(int(id))
	_pending.clear()
	_callbacks.clear()
	_host = null
	before_commit = Callable()


func is_closed() -> bool:
	return _closed


func _exit_tree() -> void:
	close()


func request(operation: String, payload: Dictionary = {}) -> int:
	# Zero is the rejected terminal request sentinel; no completion is scheduled.
	if _closed:
		return 0
	_next_request += 1
	var id: int = _next_request
	_pending[id] = true
	if not _configured:
		_deliver.call_deferred(id, _failure("Configure professional storage before using it."))
	elif _host != null:
		var receive: Callable = _receive.bind(id, _generation)
		_callbacks[id] = JavaScriptBridge.create_callback(receive) if _host is JavaScriptObject else receive
		if is_inside_tree():
			var timer: SceneTreeTimer = get_tree().create_timer(REQUEST_TIMEOUT_SECONDS, true, false, true)
			_track_timer(id, timer, _timeout.bind(id, _generation))
		_host.professionalProgressRequest(JSON.stringify({"request_id": id, "operation": operation, "payload": payload}), _callbacks[id])
	elif OS.has_feature("web"):
		_deliver.call_deferred(id, _failure("Professional storage is unavailable. Please retry."))
	else:
		_native_request.call_deferred(id, operation, payload.duplicate(true), 0)
	return id


func _native_request(id: int, operation: String, payload: Dictionary, attempt: int) -> void:
	if _closed or not _pending.has(id):
		return
	_clear_timer(id)
	var result: Dictionary = transact_native(operation, payload)
	if not _closed and result.get("reason") == "busy" and attempt < 5 and is_inside_tree():
		var timer: SceneTreeTimer = get_tree().create_timer(0.1, true, false, true)
		_track_timer(id, timer, _native_request.bind(id, operation, payload, attempt + 1))
		return
	_deliver(id, result)


func _track_timer(id: int, timer: SceneTreeTimer, callback: Callable) -> void:
	_clear_timer(id)
	timer.timeout.connect(callback)
	_timers[id] = {"timer": timer, "callback": callback}


func _clear_timer(id: int) -> void:
	if not _timers.has(id):
		return
	var tracked: Dictionary = _timers[id]
	_timers.erase(id)
	var timer: SceneTreeTimer = tracked.timer
	var callback: Callable = tracked.callback
	if is_instance_valid(timer) and timer.timeout.is_connected(callback):
		timer.timeout.disconnect(callback)


func _timeout(id: int, generation: int) -> void:
	if not _closed and generation == _generation and _pending.has(id):
		_deliver(id, _failure("Professional storage took too long. Retry the same event ID."))


func _receive(arguments: Array, id: int, generation: int) -> void:
	if _closed or generation != _generation or not _pending.has(id):
		return
	var parser := JSON.new()
	var parsed: bool = arguments.size() == 1 and parser.parse(str(arguments[0])) == OK
	var result: Variant = parser.data if parsed else null
	if not result is Dictionary or result.get("request_id") != id or not result.get("ok") is bool:
		_deliver.call_deferred(id, _failure("Professional storage returned an invalid response. Please retry."))
		return
	if result.ok and result.has("progress"):
		var message: String = Progress.validate_progress(result.progress)
		if not message.is_empty():
			_deliver.call_deferred(id, _failure(message))
			return
	_deliver.call_deferred(id, result)


func _deliver(id: int, result: Dictionary) -> void:
	if _closed or not _pending.has(id):
		return
	_pending.erase(id)
	_callbacks.erase(id)
	_clear_timer(id)
	storage_ready = bool(result.get("ok", false))
	error = str(result.get("error", ""))
	completed.emit(id, result)


func transact_native(operation: String, payload: Dictionary = {}) -> Dictionary:
	if _closed:
		return _closed_failure()
	if not _configured or _host != null or OS.has_feature("web"):
		return _failure("Native professional storage is unavailable.")
	if operation not in ["load", "record", "context", "ack", "register"]:
		return _failure("Unknown professional storage operation.")
	# A process-owned loopback lock releases automatically after a crash. All
	# readers and writers for this normalized path use the same exclusive port.
	# A collision with another service fails safely instead of weakening locking.
	var absolute: String = ProjectSettings.globalize_path(_path).simplify_path()
	if OS.get_name() == "Windows":
		absolute = absolute.to_lower()
	var lock := TCPServer.new()
	var port: int = 20000 + absolute.sha256_text().substr(0, 8).hex_to_int() % 40000
	if lock.listen(port, "127.0.0.1") != OK:
		var busy: Dictionary = _failure("Another native session is using this professional save. Please retry.")
		busy.reason = "busy"
		return busy
	var result: Dictionary = _transact_locked(operation, payload)
	lock.stop()
	return result


func _transact_locked(operation: String, payload: Dictionary) -> Dictionary:
	if _closed:
		return _closed_failure()
	var stored: Dictionary = _read_native()
	if not stored.ok:
		return stored
	var state: Dictionary = stored.state
	if operation == "register":
		if not payload.get("requirements") is Array or not progress.register_requirements(payload.requirements, state.progress):
			return _failure(progress.error if not progress.error.is_empty() else "Professional requirements must be an array.")
		return {"ok": true, "registered": payload.requirements.size(), "error": ""}
	if operation == "load":
		return {"ok": true, "progress": state.progress, "context": state.context, "outbox": state.outbox.values(), "error": ""}
	var result: Dictionary = {"ok": true, "error": ""}
	if operation == "context":
		var message: String = progress.validate_context(payload)
		if not message.is_empty():
			return _failure(message)
		state.context = payload.duplicate(true)
		result.context = state.context
	elif operation == "record":
		var message: String = progress.validate_event(payload)
		if not message.is_empty():
			return _failure(message)
		var fingerprint: String = Progress.canonical(payload)
		if state.events.has(payload.id):
			if state.events[payload.id].fingerprint != fingerprint:
				return _failure("This answer ID was already used for a different event.")
			return {"ok": true, "duplicate": true, "progress": state.progress, "error": ""}
		var applied: Dictionary = progress.apply_event(state.progress, payload)
		if not applied.ok:
			return _failure(applied.error)
		state.progress = applied.progress
		state.events[payload.id] = {"fingerprint": fingerprint, "reward_acknowledged": false}
		if payload.has("reward"):
			state.outbox[payload.id] = {"id": payload.id, "receipt_id": "professional:" + str(payload.id),
				"operation": payload.reward.operation, "payload": payload.reward.payload.duplicate(true)}
		result.progress = state.progress
		result.duplicate = false
	else:
		if not Progress.identity(payload.get("id")) or not state.events.has(payload.id):
			return _failure("The reward has no saved answer receipt.")
		var receipt: Dictionary = state.events[payload.id]
		if not state.outbox.has(payload.id) and not receipt.reward_acknowledged:
			return _failure("This answer has no pending wallet reward.")
		result.duplicate = receipt.reward_acknowledged
		receipt.reward_acknowledged = true
		state.outbox.erase(payload.id)
	var commit_allowed: bool = not before_commit.is_valid() or bool(before_commit.call(operation))
	# A callback can synchronously dispose the owner while the transaction holds its lock.
	if _closed:
		return _closed_failure()
	if not commit_allowed:
		return _failure("Professional progress was not saved. Please retry.")
	var message: String = _persist_native(state)
	return result if message.is_empty() else _failure(message)


func _read_native() -> Dictionary:
	if _closed:
		return _closed_failure()
	if DirAccess.open(_path.get_base_dir()) == null:
		return _failure("Professional storage is unavailable. Please retry.")
	if DirAccess.dir_exists_absolute(_path):
		return _failure("Professional progress could not be read. Please retry.")
	if not FileAccess.file_exists(_path) and FileAccess.file_exists(_path + ".previous"):
		if DirAccess.rename_absolute(_path + ".previous", _path) != OK:
			return _failure("Could not restore professional progress. Please retry.")
	if not FileAccess.file_exists(_path):
		# A pending first write was never acknowledged. Its event can be retried.
		return {"ok": true, "state": {"schema": 1, "progress": Progress.empty_progress(), "context": null, "events": {}, "outbox": {}}}
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null or file.get_length() == 0 or file.get_length() > MAX_SAVE_BYTES:
		return _failure("Professional progress could not be read. Please retry.")
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("Professional progress could not be read. Please retry.")
	var state: Variant = parser.data
	var message: String = _validate_state(state)
	return {"ok": true, "state": state} if message.is_empty() else _failure(message)


func _validate_state(state: Variant) -> String:
	if not state is Dictionary or state.get("schema") != 1 or not state.get("events") is Dictionary \
		or not state.get("outbox") is Dictionary or not state.has("context") \
		or (state.context != null and not state.context is Dictionary):
		return "Professional progress could not be read. Please retry."
	var message: String = Progress.validate_progress(state.get("progress"))
	if not message.is_empty():
		return message
	if state.events.size() != int(state.progress.sequence):
		return "Professional progress is missing its answer receipts. Please retry."
	for id in state.events:
		var receipt: Variant = state.events[id]
		if not Progress.identity(id) or not receipt is Dictionary or not receipt.get("fingerprint") is String \
			or receipt.fingerprint.is_empty() or not receipt.get("reward_acknowledged") is bool:
			return "Invalid professional answer receipt."
	for id in state.outbox:
		var reward: Variant = state.outbox[id]
		if not state.events.has(id) or state.events[id].reward_acknowledged or not reward is Dictionary \
			or reward.get("id") != id or reward.get("receipt_id") != "professional:" + str(id) \
			or reward.get("operation") != "credit" or not reward.get("payload") is Dictionary \
			or not Progress.whole(reward.payload.get("tier"), 0, 180143985094819):
			return "Invalid professional reward outbox."
	return ""


func _persist_native(state: Dictionary) -> String:
	if _closed:
		return CLOSED_ERROR
	var text: String = JSON.stringify(state)
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return "Professional receipt storage is full. This event has not been saved."
	var file := FileAccess.open(_path + ".pending", FileAccess.WRITE)
	if file == null:
		return "Professional progress was not saved. Please retry."
	file.store_string(text)
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	if not written or FileAccess.get_file_as_string(_path + ".pending") != text:
		return "Professional progress was not saved. Please retry."
	if FileAccess.file_exists(_path + ".previous") and DirAccess.remove_absolute(_path + ".previous") != OK:
		return "Could not preserve professional progress. Please retry."
	var existed: bool = FileAccess.file_exists(_path)
	if existed and DirAccess.rename_absolute(_path, _path + ".previous") != OK:
		return "Could not preserve professional progress. Please retry."
	if DirAccess.rename_absolute(_path + ".pending", _path) != OK:
		if existed:
			DirAccess.rename_absolute(_path + ".previous", _path)
		return "Professional progress was not saved. Please retry."
	# The new snapshot is committed; a leftover backup is safe to clean next time.
	if existed:
		DirAccess.remove_absolute(_path + ".previous")
	return ""


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "retryable": true, "error": message}


static func _closed_failure() -> Dictionary:
	return {"ok": false, "retryable": false, "reason": "closed", "error": CLOSED_ERROR}
