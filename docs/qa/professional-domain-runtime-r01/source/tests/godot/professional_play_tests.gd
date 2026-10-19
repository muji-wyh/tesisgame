extends SceneTree

const Play = preload("res://scripts/professional_play.gd")
const Context = preload("res://scripts/learning_context.gd")
const Access = preload("res://scripts/professional_media_access.gd")

# These doubles emit lifecycle callbacks only. They do not resolve curriculum,
# grant domain reviews, load media, or claim that a professional module is ready.
class CallbackCache extends RefCounted:
	var leases: Dictionary = {}
	var releases: int = 0
	var texture := PlaceholderTexture2D.new()
	func pin_round(ids: Array) -> Dictionary:
		leases[1] = ids.duplicate()
		return {"ok": true, "lease": 1}
	func get_resource(id: String, lease: int) -> Resource:
		return texture if leases.get(lease, []).has(id) else null
	func release_round(lease: int) -> void:
		releases += 1
		leases.erase(lease)
	func deactivate() -> void:
		pass
	func trim_inactive() -> void:
		pass

class CallbackMedia extends RefCounted:
	var cache := CallbackCache.new()

class CallbackLoader extends Node:
	signal prepared(selection: int, content: Dictionary)
	signal failed(selection: int, result: Dictionary)
	signal theme_selected(selection: int, profile: Dictionary)
	signal invalidated(selection: int, result: Dictionary)
	var media := CallbackMedia.new()
	var requests: Array = []
	var selection: int = 0
	var closed := false
	var configure_ok := true
	var configure_calls := 0
	var after_cancel: Callable
	func configure(_host: Object = null) -> bool:
		configure_calls += 1
		return configure_ok
	func can_claim(value: int) -> bool:
		return not closed and value == selection
	func close() -> void:
		closed = true
		cancel()
	func retire() -> void:
		var previous: int = selection
		close()
		invalidated.emit(previous, {"ok": false, "error": "Retired test owner."})
	func cancel() -> void:
		selection += 1
		if after_cancel.is_valid():
			var callback: Callable = after_cancel
			after_cancel = Callable()
			callback.call()
	func request(context: Dictionary, _seed: int = -1) -> int:
		cancel()
		var requested: int = selection
		requests.append(context.duplicate(true))
		theme_selected.emit(requested, {})
		return requested

class CallbackStore extends Node:
	var closed := false
	func configure(_requirements: Array, _path: String, _host: Object) -> bool:
		return true
	func close() -> void:
		closed = true

class CallbackSession extends Node:
	signal round_opened(source: String, generation: int, result: Dictionary)
	signal changed(state: Dictionary)
	signal blocked(source: String, id: String, result: Dictionary)
	signal event_completed(id: String, source: String, result: Dictionary)
	var callback_stage: String = ""
	var fail_open: bool = false
	var open_pending: bool = true
	var is_blocked: bool = false
	var recover_calls: int = 0
	var leave_calls: int = 0
	func configure(_store: Node, _credit: Callable) -> bool:
		return true
	func recover() -> void:
		recover_calls += 1
	func retry() -> void:
		is_blocked = false
		callback_stage = "retry"
		changed.emit(snapshot())
		callback_stage = ""
	func leave_round() -> void:
		leave_calls += 1
		callback_stage = "leave"
		changed.emit(snapshot())
		callback_stage = ""
	func open_round(_context: Dictionary, _requirements: Dictionary, _source: String) -> Dictionary:
		var result: Dictionary = {"ok": not fail_open, "pending": open_pending, "error": "Injected opening failure."}
		callback_stage = "open"
		changed.emit(snapshot())
		callback_stage = ""
		return result
	func snapshot() -> Dictionary:
		return {"blocked": is_blocked, "progress_loaded": true, "pending_count": 0, "ready": false, "source_id": ""}

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle(play) -> void:
	for frame in range(60):
		await process_frame
		var state: Dictionary = play.session.snapshot()
		if frame >= 3 and (state.blocked or state.pending_count == 0):
			return
	check(false, "Professional recovery settles within a bounded number of frames")


func _controller(play_script: Script) -> Node:
	var play: Node = play_script.new()
	play.loader.media.free()
	if "_owner" in play.loader:
		play.loader._owner.free()
	play.loader.free()
	play.store.free()
	play.session.free()
	play.loader = CallbackLoader.new()
	play.store = CallbackStore.new()
	play.session = CallbackSession.new()
	root.add_child(play)
	play.configure(null, func(_id: String, _tier: int) -> Dictionary: return {"ok": true})
	return play


func _probe(rows: Array, condition: bool, label: String) -> void:
	rows.append({"check": label, "passed": condition})


func _reentrancy_probes(play_script: Script, safe_original: bool = false) -> Array:
	var rows: Array = []
	var a: Dictionary = Context.professional("retail", "module03", "professional-v1", "phrase")
	var b: Dictionary = Context.professional("retail", "module04", "professional-v1", "phrase")
	for action: String in ["request", "cancel", "leave"]:
		var play: Node = _controller(play_script)
		var called: Array = [false, -1]
		play.changed.connect(func(_state: Dictionary) -> void:
			if not called[0] and play.session.callback_stage == "leave":
				called[0] = true
				if action == "request":
					called[1] = play.request(b)
				else:
					play.call(action))
		var outer: int = play.request(a)
		var expected: bool = outer == -1
		if action == "request":
			expected = expected and play.pending.get("context") == b and play.pending.get("selection") == called[1] \
				and play.phase == "media" and play.loader.requests.size() == 1
		else:
			expected = expected and play.pending.is_empty() and play.phase == "idle" and play.loader.requests.is_empty()
		_probe(rows, expected, "Request respects " + action + " from the earliest session notification")
		play.free()
	var mutation_play: Node = _controller(play_script)
	var caller_context: Dictionary = a.duplicate(true)
	mutation_play.changed.connect(func(_state: Dictionary) -> void:
		if mutation_play.session.callback_stage == "leave":
			caller_context.module_id = "module04"
			caller_context["injected"] = "ignored")
	mutation_play.request(caller_context)
	_probe(rows, mutation_play.pending.get("context") == a and mutation_play.loader.requests == [a],
		"Request freezes only supported context fields before the first callback")
	mutation_play.free()
	for action: String in ["request", "cancel", "leave"]:
		var play: Node = _controller(play_script)
		var called: Array = [false, -1]
		play.loader.theme_selected.connect(func(_selection: int, _profile: Dictionary) -> void:
			if not called[0]:
				called[0] = true
				if action == "request":
					called[1] = play.request(b)
				else:
					play.call(action))
		var outer: int = play.request(a)
		var expected: bool = outer > 0
		if action == "request":
			expected = expected and play.pending.get("context") == b and play.pending.get("selection") == called[1] \
				and outer != called[1] and play.phase == "media"
		else:
			expected = expected and play.pending.is_empty() and play.phase == "idle"
		_probe(rows, expected, "Loader callback " + action + " cannot be overwritten by the outer request return")
		play.free()
	for action: String in ["cancel", "leave"]:
		var play: Node = _controller(play_script)
		var called: Array = [false]
		play.changed.connect(func(_state: Dictionary) -> void:
			if not called[0] and play.session.callback_stage == "leave":
				called[0] = true
				play.request(b))
		play.call(action)
		_probe(rows, play.pending.get("context") == b and play.phase == "media",
			"Nested request keeps its state after " + action + " session notification")
		play.free()
	var restore_play: Node = _controller(play_script)
	var cache: RefCounted = restore_play.loader.media.cache
	var digest: String = "a".repeat(64)
	var scope: String = Access.acquire(cache, ["sha256:" + digest]).scope
	var resource_path: String = Access.path(scope, digest)
	restore_play.active = {"context": a, "requirements": {}, "source": "active-source", "media_scope": scope}
	restore_play.session.open_pending = false
	var restoring: Array = [false]
	restore_play.changed.connect(func(_state: Dictionary) -> void:
		if not restoring[0] and restore_play.session.callback_stage == "open":
			restoring[0] = true
			restore_play.request(b))
	restore_play.cancel()
	_probe(rows, restore_play.pending.get("context") == b and restore_play.phase == "media",
		"Restoring an active round cannot overwrite a nested newer request")
	_probe(rows, cache.releases == 0 and Access.resource(resource_path) == cache.texture,
		"Pending cancellation preserves the active claimed Access lease")
	restore_play.free()
	_probe(rows, cache.releases == 1 and Access.resource(resource_path) == null,
		"Controller teardown releases that active Access lease exactly once")
	for action: String in ["request", "cancel", "leave"]:
		# Historical replay skips empty-pending reads that would abort the old
		# script. Current-code tests include them and must produce no engine error.
		if safe_original and action != "request":
			continue
		var play: Node = _controller(play_script)
		var selection: int = play.request(a)
		var source: String = play.pending.source
		play.pending.content = {"context": a, "requirements": {}}
		var events: Array = []
		var called: Array = [false]
		play.round_prepared.connect(func(id: int, content: Dictionary, value: String) -> void: events.append([id, content, value]))
		play.changed.connect(func(_state: Dictionary) -> void:
			if not called[0] and play.phase == "ready":
				called[0] = true
				if action == "request":
					play.request(b)
					play.pending.content = {"context": b, "requirements": {}}
				else:
					play.call(action))
		play._round_opened(source, 1, {"ok": true})
		var expected: bool = events.is_empty()
		if action == "request":
			expected = expected and play.pending.get("context") == b and play.pending.get("selection") != selection and play.phase == "media"
		else:
			expected = expected and play.pending.is_empty() and play.phase == "idle"
		_probe(rows, expected, "Ready notification " + action + " suppresses the obsolete round_prepared event")
		play.free()
	for action: String in ["request", "cancel", "leave"]:
		if safe_original and action != "request":
			continue
		var play: Node = _controller(play_script)
		var selection: int = play.request(a)
		play.session.fail_open = true
		var called: Array = [false]
		play.changed.connect(func(_state: Dictionary) -> void:
			if not called[0] and play.session.callback_stage == "open":
				called[0] = true
				if action == "request":
					play.request(b)
				else:
					play.call(action))
		play._media_prepared(selection, {"context": a, "requirements": {}})
		var expected: bool = play.error.is_empty()
		if action == "request":
			expected = expected and play.pending.get("context") == b and play.phase == "media"
		else:
			expected = expected and play.pending.is_empty() and play.phase == "idle"
		_probe(rows, expected, "Opening callback " + action + " discards the obsolete storage result")
		play.free()
	for stage: String in ["retry", "leave"]:
		var play: Node = _controller(play_script)
		play.session.is_blocked = stage == "retry"
		var recoveries: int = play.session.recover_calls
		var called: Array = [false]
		play.changed.connect(func(_state: Dictionary) -> void:
			if not called[0] and play.session.callback_stage == stage:
				called[0] = true
				play.request(b))
		play.retry()
		_probe(rows, play.pending.get("context") == b and play.phase == "media" \
			and play.session.recover_calls == recoveries,
			"Retry preserves a nested selection from the " + stage + " notification")
		play.free()
	var ready_play: Node = _controller(play_script)
	var ready_selection: int = ready_play.request(a)
	var ready_source: String = ready_play.pending.source
	ready_play.pending.content = {"context": a, "requirements": {}}
	var prepared: Array = []
	ready_play.round_prepared.connect(func(id: int, content: Dictionary, source: String) -> void:
		prepared.append([id, content.context, source]))
	ready_play._round_opened(ready_source, 1, {"ok": true})
	_probe(rows, prepared == [[ready_selection, a, ready_source]] and ready_play.phase == "ready",
		"An unchanged current opening still publishes its original selection and source")
	ready_play.free()
	return rows


func _run() -> void:
	var directory: String = "user://professional-play-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var unavailable: String = directory.path_join("unavailable")
	check(DirAccess.make_dir_absolute(directory) == OK, "Recovery regression uses isolated storage")
	var play := Play.new()
	root.add_child(play)
	check(play.configure(null, func(_id: String, _tier: int) -> Dictionary: return {"ok": true}, unavailable.path_join("progress.json")),
		"Professional preparation configures before its storage path becomes available")
	await _settle(play)
	check(play.phase == "failed" and play.session.snapshot().blocked, "An initial load failure exposes a retryable state")
	check(not play.session.snapshot().progress_loaded and play.active.is_empty() and play.pending.is_empty(),
		"An unavailable initial profile has no invented progress or playable round")
	check(DirAccess.make_dir_absolute(unavailable) == OK, "Restore the initial storage path")
	play.retry()
	check(play.phase == "restoring", "The initial load retry stays busy while recovery is pending")
	await _settle(play)
	var state: Dictionary = play.session.snapshot()
	check(play.phase == "idle" and play.error.is_empty() and not state.blocked and state.pending_count == 0,
		"Successful recovery without an active round returns Home to idle")
	check(state.progress_loaded and not state.ready and play.active.is_empty() and play.pending.is_empty(),
		"Recovery loads the profile without pretending a course is already prepared")
	check(not play.can_play(""), "An idle recovered profile still requires a real round source")
	play.queue_free()
	await process_frame
	check(DirAccess.remove_absolute(unavailable) == OK and DirAccess.remove_absolute(directory) == OK,
		"Remove the isolated recovery fixture")
	for result: Dictionary in _reentrancy_probes(Play):
		check(result.passed, result.check)
	await _lifecycle_checks()
	print("Professional play: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _lifecycle_checks() -> void:
	var context: Dictionary = Context.professional("retail", "module03", "professional-v1", "phrase")
	for action in ["cancel", "leave"]:
		var nested: Node = _controller(Play)
		var newer: Dictionary = Context.professional("nursing", "module03", "professional-v1", "phrase")
		nested.loader.after_cancel = func() -> void: nested.request(newer)
		nested.call(action)
		check(nested.pending.get("context") == newer and nested.phase == "media",
			"New selection from loader cancellation survives outer " + action)
		nested.free()
	var play: Node = _controller(Play)
	var selection: int = play.request(context)
	var source: String = play.pending.source
	play._media_prepared(selection, {"context": context, "requirements": {}})
	check(play.phase == "storage", "Current policy result reaches the storage phase")
	var opened: Array = []
	play.round_prepared.connect(func(id: int, _content: Dictionary, _source: String) -> void: opened.append(id))
	var leaves: int = play.session.leave_calls
	play.loader.retire()
	check(play.pending.is_empty() and play.session.leave_calls == leaves + 1,
		"Retirement during storage obsoletes the pending round open")
	play._round_opened(source, 1, {"ok": true})
	check(opened.is_empty() and play.phase == "failed", "Late retired storage success cannot publish a ready round")
	check(not play.store.closed, "Policy retirement keeps persistence alive for accepted settlements")
	play.free()

	play = _controller(Play)
	selection = play.request(context)
	var notifications: Array = []
	play.changed.connect(func(state: Dictionary) -> void: notifications.append(state))
	play.event_completed.connect(func(_id: String, _source: String, result: Dictionary) -> void: notifications.append(result))
	play.close()
	play.close()
	play.loader.prepared.emit(selection, {"context": context, "requirements": {}})
	play.session.round_opened.emit("late-source", 1, {"ok": true})
	play.session.changed.emit(play.session.snapshot())
	play.session.event_completed.emit("late-event", "late-source", {"ok": true})
	play.session.blocked.emit("late-source", "late-event", {"ok": false, "error": "late"})
	await process_frame
	check(notifications.is_empty() and play.phase == "closed" and play.pending.is_empty(),
		"Terminal close suppresses every late loader/session publication")
	check(play.store.closed and play.loader.closed and play.request(context) == -1,
		"Terminal close closes children and rejects new selections")
	play.free()

	play = Play.new()
	play.loader.media.free()
	play.loader._owner.free()
	play.loader.free()
	play.store.free()
	play.session.free()
	play.loader = CallbackLoader.new()
	play.loader.configure_ok = false
	play.store = CallbackStore.new()
	play.session = CallbackSession.new()
	root.add_child(play)
	var credit: Callable = func(_id: String, _tier: int) -> Dictionary: return {"ok": true}
	check(not play.configure(null, credit) and play.phase == "failed", "Partial setup fails with a terminal recoverable UI state")
	check(not play.configure(null, credit) and play.loader.configure_calls == 1 and play.get_child_count() == 3,
		"Repeated partial setup cannot duplicate child ownership or signal connections")
	play.free()
