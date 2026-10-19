extends Node
## Serial durable answers and wallet outbox delivery for a frozen round context.

signal changed(state: Dictionary)
signal round_opened(source_id: String, generation: int, result: Dictionary)
signal event_completed(event_id: String, source_id: String, result: Dictionary)
signal blocked(source_id: String, event_id: String, result: Dictionary)

const Progress = preload("res://scripts/professional_progress.gd")

var _store: Node
var _credit_wallet: Callable
var _rules = Progress.new()
var _source := ""
var _generation := 0
var _context: Dictionary = {}
var _requirements: Dictionary = {}
var _sources: Dictionary = {}
var _events: Dictionary = {}
var _queue: Array[Dictionary] = []
var _request_id := 0
var _scheduled := false
var _paused := false
var _round_ready := false
var _loaded := false
var _progress: Dictionary = {}
var _saved_context: Variant = null
var _error: Dictionary = {}


func configure(store_node: Node, credit_wallet: Callable) -> bool:
	if _store != null or not _queue.is_empty() or _request_id != 0 or store_node == null or not store_node.has_method("request") \
		or not store_node.has_signal("completed") or not credit_wallet.is_valid():
		return false
	_store = store_node
	_credit_wallet = credit_wallet
	_store.completed.connect(_receive)
	return true


func open_round(context: Dictionary, requirements: Dictionary, source_id: String) -> Dictionary:
	if _store == null:
		return _failure("Configure professional persistence before opening a round.", "unavailable")
	if not Progress.identity(source_id):
		return _failure("A round needs a stable source identity.", "invalid_source")
	var rules = Progress.new()
	if not rules.configure([requirements]):
		return _failure(rules.error, "invalid_requirements")
	var problem: String = rules.validate_context(context, true)
	if not problem.is_empty():
		return _failure(problem, "invalid_context")
	var identity: String = Progress.canonical({"context": context, "requirements": requirements})
	if _sources.has(source_id):
		if _sources[source_id] != identity:
			return _failure("This round source identity already belongs to another frozen context.", "source_conflict")
		if source_id == _source:
			return {"ok": true, "pending": not _round_ready, "source_id": _source, "generation": _generation}
	# Preparation is replaceable; already accepted answer settlements are not.
	for pending in _queue:
		if pending.kind == "open":
			pending.obsolete = true
	if _paused and not _queue.is_empty() and _queue[0].kind == "open":
		_paused = false
		_error.clear()
	_sources[source_id] = identity
	_generation += 1
	_source = source_id
	_context = context.duplicate(true)
	_requirements = requirements.duplicate(true)
	_rules = rules
	_round_ready = false
	_queue.append({"kind": "open", "source_id": source_id, "generation": _generation, "phase": "register",
		"context": _context.duplicate(true), "requirements": _requirements.duplicate(true), "outbox": []})
	_notify()
	_schedule()
	return {"ok": true, "pending": true, "source_id": source_id, "generation": _generation}


func recover() -> Dictionary:
	if _store == null:
		return _failure("Configure professional persistence before recovering rewards.", "unavailable")
	for job in _queue:
		if job.kind in ["open", "recover"]:
			return {"ok": true, "pending": true}
	_queue.append({"kind": "recover", "source_id": _source, "generation": _generation, "phase": "load", "outbox": []})
	_schedule()
	_notify()
	return {"ok": true, "pending": true}


func submit(answer: Dictionary, source_id: String = "") -> Dictionary:
	var source: String = _source if source_id.is_empty() else source_id
	if not Progress.identity(answer.get("id")):
		return _failure("An answer needs a permanent event identity.", "invalid_event")
	var id: String = answer.id
	var event: Dictionary = answer.duplicate(true)
	var frozen: Dictionary = _context
	if _events.has(id):
		if _events[id].source_id != source:
			return _failure("This event identity belongs to another round source.", "source_conflict")
		frozen = _events[id].event.context
	if event.has("context") and Progress.canonical(event.context) != Progress.canonical(frozen):
		return _failure("An answer cannot change the round's frozen learning context.", "context_conflict")
	event.context = frozen.duplicate(true)
	var fingerprint: String = Progress.canonical(event)
	if _events.has(id):
		if _events[id].fingerprint != fingerprint:
			return _failure("This answer identity was already queued with different content.", "event_conflict")
		return poll_event(id, source)
	if source != _source or source.is_empty():
		return _failure("This round has been replaced. Keep its existing pending settlement only.", "stale_source")
	if not _round_ready:
		return _failure("The professional round is still loading its saved progress.", "not_ready")
	var problem: String = _rules.validate_event(event)
	if not problem.is_empty():
		return _failure(problem, "invalid_event")
	_events[id] = {"event": event, "fingerprint": fingerprint, "source_id": source, "generation": _generation,
		"state": "pending", "result": {}}
	_queue.append({"kind": "event", "id": id, "source_id": source, "generation": _generation, "phase": "record", "event": event})
	_notify()
	_schedule()
	return poll_event(id, source)


func poll_event(event_id: String, source_id: String = "") -> Dictionary:
	if not _events.has(event_id):
		return _failure("This answer has not been submitted.", "unknown_event")
	var entry: Dictionary = _events[event_id]
	if not source_id.is_empty() and source_id != entry.source_id:
		return _failure("This event identity belongs to another round source.", "source_conflict")
	if entry.state in ["complete", "failed"]:
		return entry.result.duplicate(true)
	return {"ok": false, "pending": true, "retryable": true, "code": "pending", "error": "",
		"id": event_id, "source_id": entry.source_id, "generation": entry.generation}


func retry() -> Dictionary:
	if _store == null:
		return _failure("Professional persistence is unavailable.", "unavailable")
	_paused = false
	_error.clear()
	if not _queue.is_empty() and _queue[0].kind == "event":
		_events[_queue[0].id].state = "pending"
		_events[_queue[0].id].result = {}
	_schedule()
	_notify()
	return {"ok": true, "pending": not _queue.is_empty()}


func leave_round() -> void:
	_generation += 1
	for job in _queue:
		if job.kind == "open":
			job.obsolete = true
	if _paused and not _queue.is_empty() and _queue[0].kind == "open":
		_paused = false
		_error.clear()
	_source = ""
	_context.clear()
	_requirements.clear()
	_round_ready = false
	_schedule()
	_notify()


func snapshot() -> Dictionary:
	var pending: Array = []
	var outbox_count := 0
	for job in _queue:
		pending.append({"kind": job.kind, "id": job.get("id", ""), "source_id": job.source_id,
			"generation": job.generation, "phase": job.phase})
		outbox_count += job.get("outbox", []).size()
		if job.kind == "event" and job.phase in ["wallet", "ack"]:
			outbox_count += 1
	return {"configured": _store != null, "ready": _round_ready, "source_id": _source, "generation": _generation,
		"context": _context.duplicate(true), "progress_loaded": _loaded, "progress": _progress.duplicate(true),
		"saved_context": _saved_context.duplicate(true) if _saved_context is Dictionary else null,
		"pending_count": _queue.size(), "pending": pending, "outbox_pending": outbox_count,
		"blocked": _paused, "error": _error.duplicate(true)}


func _schedule() -> void:
	if _scheduled or _paused or _request_id != 0 or _queue.is_empty():
		return
	_scheduled = true
	_pump.call_deferred()


func _pump() -> void:
	_scheduled = false
	if _paused or _request_id != 0 or _queue.is_empty() or _store == null:
		return
	var job: Dictionary = _queue[0]
	if job.kind == "open" and job.get("obsolete", false):
		_discard_open()
		return
	match job.phase:
		"register": _ask("register", {"requirements": [job.requirements]})
		"context": _ask("context", job.context)
		"load": _ask("load", {})
		"record": _ask("record", job.event)
		"wallet":
			var reward: Dictionary = _reward_for(job)
			var message: String = _validate_reward(reward)
			if not message.is_empty():
				_fail_job(_failure(message, "invalid_outbox"))
				return
			var credited: Variant = _credit_wallet.call(str(reward.receipt_id), int(reward.payload.tier))
			if not credited is Dictionary or credited.get("ok") != true:
				var detail: String = str(credited.get("error", "")) if credited is Dictionary else ""
				_fail_job(_failure(detail if not detail.is_empty() else "Your reward could not be saved. Please retry.", "wallet_failed"))
				return
			job.wallet_result = credited.duplicate(true)
			job.phase = "ack"
			_schedule()
		"ack": _ask("ack", {"id": _reward_for(job).id})
		"done": _complete_job()
	_notify()


func _ask(operation: String, payload: Dictionary) -> void:
	# ProfessionalStore guarantees deferred completion, including immediate errors.
	_request_id = int(_store.request(operation, payload.duplicate(true)))
	if _request_id <= 0:
		_request_id = 0
		_fail_job(_failure("Professional persistence could not start this operation.", "unavailable"))


func _receive(request_id: int, result: Dictionary) -> void:
	if request_id != _request_id or _queue.is_empty():
		return
	_request_id = 0
	if _queue[0].kind == "open" and _queue[0].get("obsolete", false):
		_discard_open()
		return
	if result.get("ok") != true:
		_fail_job(_failure(str(result.get("error", "Professional progress was not saved. Please retry.")), "storage_failed"))
		return
	if result.has("progress"):
		var message: String = Progress.validate_progress(result.progress)
		if not message.is_empty():
			_fail_job(_failure(message, "invalid_progress"))
			return
		_progress = result.progress.duplicate(true)
		_loaded = true
	var job: Dictionary = _queue[0]
	match job.phase:
		"register": job.phase = "context"
		"context":
			_saved_context = job.context.duplicate(true)
			job.phase = "load"
		"load":
			if not result.has("progress") or not result.get("outbox") is Array:
				_fail_job(_failure("Professional recovery returned an incomplete snapshot.", "invalid_progress"))
				return
			if result.has("context"):
				_saved_context = result.context.duplicate(true) if result.context is Dictionary else null
			job.outbox = result.outbox.duplicate(true)
			for reward in job.outbox:
				var message: String = _validate_reward(reward)
				if not message.is_empty():
					_fail_job(_failure(message, "invalid_outbox"))
					return
			job.phase = "wallet" if not job.outbox.is_empty() else "done"
		"record":
			if not result.has("progress"):
				_fail_job(_failure("The answer receipt returned no saved progress.", "invalid_progress"))
				return
			job.record_result = result.duplicate(true)
			job.phase = "wallet" if job.event.has("reward") else "done"
		"ack":
			if job.kind == "event":
				job.phase = "done"
			else:
				job.outbox.pop_front()
				job.phase = "wallet" if not job.outbox.is_empty() else "done"
	_schedule()
	_notify()


func _reward_for(job: Dictionary) -> Dictionary:
	if job.kind == "event":
		return {"id": job.id, "receipt_id": "professional:" + str(job.id),
			"operation": job.event.reward.operation, "payload": job.event.reward.payload.duplicate(true)}
	return job.outbox[0] if not job.outbox.is_empty() else {}


func _validate_reward(reward: Variant) -> String:
	if not reward is Dictionary or not Progress.identity(reward.get("id")) \
		or reward.get("receipt_id") != "professional:" + str(reward.id) or reward.get("operation") != "credit" \
		or not reward.get("payload") is Dictionary or reward.payload.size() != 1 \
		or not Progress.whole(reward.payload.get("tier"), 0, 180143985094819):
		return "Professional recovery found an invalid wallet reward. Please retry after restoring the save."
	return ""


func _complete_job() -> void:
	var job: Dictionary = _queue.pop_front()
	var result: Dictionary = {"ok": true, "pending": false, "error": "", "source_id": job.source_id, "generation": job.generation}
	if job.kind == "event":
		result.id = job.id
		result.duplicate = bool(job.record_result.get("duplicate", false))
		result.progress_sequence = int(job.record_result.progress.sequence)
		if job.has("wallet_result"):
			result.wallet = job.wallet_result.duplicate(true)
		_events[job.id].state = "complete"
		_events[job.id].result = result.duplicate(true)
		event_completed.emit(job.id, job.source_id, result)
	elif job.kind == "open":
		if job.source_id == _source and int(job.generation) == _generation:
			_round_ready = true
		result.stale = job.source_id != _source or int(job.generation) != _generation
		round_opened.emit(job.source_id, job.generation, result)
	_schedule()
	_notify()


func _discard_open() -> void:
	var job: Dictionary = _queue.pop_front()
	var result: Dictionary = _failure("This round preparation has been replaced.", "cancelled")
	result.source_id = job.source_id
	result.generation = job.generation
	result.stale = true
	round_opened.emit(job.source_id, job.generation, result)
	_schedule()
	_notify()


func _fail_job(result: Dictionary) -> void:
	if _queue.is_empty():
		return
	var job: Dictionary = _queue[0]
	result.source_id = job.source_id
	result.generation = job.generation
	result.id = job.get("id", "")
	result.phase = job.phase
	_paused = true
	_error = result.duplicate(true)
	if job.kind == "event":
		_events[job.id].state = "failed"
		_events[job.id].result = result.duplicate(true)
	blocked.emit(job.source_id, job.get("id", ""), result)
	_notify()


func _failure(message: String, code: String) -> Dictionary:
	return {"ok": false, "pending": false, "retryable": true, "code": code, "error": message}


func _notify() -> void:
	changed.emit(snapshot())
