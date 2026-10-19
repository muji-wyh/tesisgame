extends Node
## Own asynchronous preparation separately from the currently playable round.

signal round_prepared(selection: int, content: Dictionary, source_id: String)
signal changed(state: Dictionary)
signal event_completed(event_id: String, source_id: String, result: Dictionary)

const RoundLoader = preload("res://scripts/professional_round_loader.gd")
const Store = preload("res://scripts/professional_store.gd")
const Session = preload("res://scripts/professional_session.gd")
const Media = preload("res://scripts/professional_media_access.gd")
const Context = preload("res://scripts/learning_context.gd")

var loader = RoundLoader.new()
var store = Store.new()
var session = Session.new()
var active: Dictionary = {}
var pending: Dictionary = {}
var error: String = ""
var phase: String = "idle"
var _configured := false
var _request_epoch: int = 0


func configure(host: Object, wallet_credit: Callable, save_path: String = Store.DEFAULT_PATH) -> bool:
	if _configured:
		return false
	add_child(loader)
	add_child(store)
	add_child(session)
	loader.prepared.connect(_media_prepared)
	loader.failed.connect(_media_failed)
	session.round_opened.connect(_round_opened)
	session.changed.connect(func(_state: Dictionary) -> void: _notify())
	session.blocked.connect(_storage_failed)
	session.event_completed.connect(func(id: String, source: String, result: Dictionary) -> void:
		event_completed.emit(id, source, result))
	_configured = loader.configure(host) and store.configure([], save_path, host) \
		and session.configure(store, wallet_credit)
	if not _configured:
		error = "Professional learning could not be loaded. Please retry."
		phase = "failed"
		_notify()
		return false
	session.recover()
	return true


func request(context: Dictionary, seed_value: int = -1) -> int:
	if not _configured or not Context.validate(context).is_empty() or context.get("track") != "professional":
		error = "Choose an available professional module."
		phase = "failed"
		_notify()
		return -1
	_request_epoch += 1
	var request_epoch: int = _request_epoch
	var captured: Dictionary = Context.freeze(context)
	# Cancelling preparation does not release the active round's claimed lease.
	session.leave_round()
	if request_epoch != _request_epoch:
		return -1
	pending = {"context": captured, "seed": seed_value,
		"source": "professional:%d:%d" % [OS.get_process_id(), Time.get_ticks_usec()]}
	phase = "media"
	error = ""
	var selection: int = loader.request(captured, seed_value)
	# Both session and loader callbacks may synchronously replace this request.
	if request_epoch != _request_epoch:
		return selection
	pending.selection = selection
	_notify()
	return selection


func cancel() -> void:
	_request_epoch += 1
	var request_epoch: int = _request_epoch
	loader.cancel()
	pending.clear()
	error = ""
	if active.is_empty():
		session.leave_round()
		if request_epoch != _request_epoch:
			return
		phase = "idle"
	else:
		phase = "restoring"
		var result: Dictionary = session.open_round(active.context, active.requirements, active.source)
		if request_epoch != _request_epoch:
			return
		if not result.ok:
			error = result.error
			phase = "failed"
		elif not result.pending:
			phase = "idle"
	_notify()


func claim(selection: int) -> Dictionary:
	if phase != "ready" or pending.get("selection", -1) != selection:
		return {"ok": false, "error": "This course selection has changed."}
	var content: Dictionary = loader.claim(selection)
	if not content.ok:
		return content
	content["source"] = pending.source
	content["previous_media_scope"] = active.get("media_scope", "")
	active = content.duplicate(true)
	active.erase("previous_media_scope")
	pending.clear()
	phase = "idle"
	error = ""
	_notify()
	return content


func leave() -> void:
	# Call only after the old round's views/audio have dropped their resources.
	_request_epoch += 1
	var request_epoch: int = _request_epoch
	loader.cancel()
	Media.release(str(active.get("media_scope", "")))
	loader.media.cache.deactivate()
	loader.media.cache.trim_inactive()
	active.clear()
	pending.clear()
	session.leave_round()
	if request_epoch != _request_epoch:
		return
	phase = "idle"
	error = ""
	_notify()


func retry() -> void:
	if session.snapshot().blocked:
		var request_epoch: int = _request_epoch
		session.retry()
		if request_epoch != _request_epoch:
			return
		error = ""
		phase = "storage" if not pending.is_empty() else "restoring"
		_notify()
	elif not pending.is_empty():
		request(pending.context, int(pending.seed))
	else:
		var request_epoch: int = _request_epoch
		cancel()
		if _request_epoch != request_epoch + 1:
			return
		session.recover()


func can_play(source: String) -> bool:
	var state: Dictionary = session.snapshot()
	return not active.is_empty() and source == active.source and state.source_id == source \
		and state.ready and not state.blocked and phase == "idle"


func snapshot() -> Dictionary:
	return {"phase": phase, "error": error, "pending": pending.duplicate(true),
		"active_context": active.get("context", {}).duplicate(true), "session": session.snapshot()}


func _media_prepared(selection: int, content: Dictionary) -> void:
	if pending.get("selection", -1) != selection:
		return
	var request_epoch: int = _request_epoch
	var source: String = pending.source
	pending.content = content
	phase = "storage"
	var result: Dictionary = session.open_round(content.context, content.requirements, source)
	if request_epoch != _request_epoch or pending.get("selection", -1) != selection \
		or pending.get("source", "") != source:
		return
	if not result.ok:
		_storage_failed(source, "", result)
		return
	_notify()


func _media_failed(selection: int, result: Dictionary) -> void:
	if pending.get("selection", -1) != selection:
		return
	phase = "failed"
	error = str(result.get("error", "The course could not be loaded. Please retry."))
	_notify()


func _round_opened(source: String, _generation: int, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	if pending.get("source", "") == source:
		var request_epoch: int = _request_epoch
		var selection: int = pending.selection
		var content: Dictionary = pending.content.duplicate(true)
		phase = "ready"
		error = ""
		_notify()
		if request_epoch != _request_epoch or phase != "ready" \
			or pending.get("selection", -1) != selection or pending.get("source", "") != source:
			return
		round_prepared.emit(selection, content, source)
	elif active.get("source", "") == source and pending.is_empty():
		phase = "idle"
		error = ""
		_notify()


func _storage_failed(_source: String, _id: String, result: Dictionary) -> void:
	error = str(result.get("error", "Your progress could not be saved. Please retry."))
	phase = "failed"
	_notify()


func _notify() -> void:
	var state: Dictionary = session.snapshot()
	if phase == "restoring" and pending.is_empty() and state.progress_loaded and not state.blocked and state.pending_count == 0 \
		and (active.is_empty() or state.ready):
		# Initial recovery has no round to mark ready. A successful retry must
		# still release the Home busy state so a first course can be selected.
		phase = "idle"
		error = ""
	changed.emit(snapshot())


func _exit_tree() -> void:
	Media.release(str(active.get("media_scope", "")))
