extends RefCounted
## A small rotating idle cohort, with immediate motion for interaction owners.

const IDLE_SLOTS := 3
const ROTATION_SECONDS := 2.8

var _owners: Dictionary = {}
var _connections: Dictionary = {}
var _order: Array[int] = []
var _priority: Dictionary = {}
var _native: Dictionary = {}
var _animated: Dictionary = {}
var _changed: Dictionary = {}
var _cursor: int = 0
var _elapsed: float = 0.0
var _playing: bool = true
var _reduced: bool = false
var _priority_depth: int = 0
var _refresh_pending: bool = false
var _refreshes: int = 0


func begin_priority_update() -> void:
	_priority_depth += 1


func end_priority_update() -> void:
	if _priority_depth <= 0:
		return
	_priority_depth -= 1
	if _priority_depth == 0 and _refresh_pending:
		_refresh_pending = false
		_refresh()


func _request_refresh() -> void:
	if _priority_depth > 0:
		_refresh_pending = true
	else:
		_refresh()


func register(tile: CanvasItem) -> void:
	if not is_instance_valid(tile) or not tile.has_method("set_ambient_animation"):
		return
	var id: int = int(tile.get("tile_id"))
	if _owners.has(id) and _owners[id].get_ref() == tile:
		_request_refresh()
		return
	if _owners.has(id):
		unregister(id)
	_owners[id] = weakref(tile)
	_order.append(id)
	var callbacks: Dictionary = {}
	for event: StringName in [&"mouse_entered", &"mouse_exited", &"focus_entered", &"focus_exited"]:
		var kind: StringName = &"hover" if str(event).begins_with("mouse") else &"focus"
		var callback: Callable = _set_native_priority.bind(id, kind, str(event).ends_with("entered"))
		if tile.has_signal(event):
			tile.connect(event, callback)
			callbacks[event] = callback
	_connections[id] = callbacks
	tile.call("set_ambient_animation", false)
	_changed[id] = true
	_request_refresh()


func unregister(id: int) -> void:
	if not _owners.has(id):
		return
	var tile: CanvasItem = _owners[id].get_ref()
	if is_instance_valid(tile):
		_disconnect(tile, id)
		tile.call("set_ambient_animation", false)
	_owners.erase(id)
	_connections.erase(id)
	_order.erase(id)
	_priority.erase(id)
	_native.erase(id)
	_animated.erase(id)
	_changed.erase(id)
	_cursor = 0 if _order.is_empty() else _cursor % _order.size()
	_request_refresh()


func set_priority(id: int, enabled: bool) -> void:
	if not _owners.has(id) or _priority.has(id) == enabled:
		return
	if enabled:
		_priority[id] = true
	else:
		_priority.erase(id)
	_request_refresh()


func set_playing(enabled: bool) -> void:
	if _playing == enabled:
		return
	_playing = enabled
	_elapsed = 0.0
	_request_refresh()


func set_reduced_motion(enabled: bool) -> void:
	if _reduced == enabled:
		return
	_reduced = enabled
	_elapsed = 0.0
	_request_refresh()


func advance(delta: float) -> Array[int]:
	if _playing and not _reduced and is_finite(delta) and delta > 0.0:
		_elapsed += minf(delta, 0.1)
		if _elapsed >= ROTATION_SECONDS:
			_elapsed = fmod(_elapsed, ROTATION_SECONDS)
			if not _order.is_empty():
				# Replace one idle slot at a time instead of uploading three new
				# vocabulary sheets together at every rotation boundary.
				_cursor = (_cursor + 1) % _order.size()
			_request_refresh()
	var result: Array[int] = []
	result.assign(_changed.keys())
	_changed.clear()
	return result


func animated_ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(_animated.keys())
	return result


func clear() -> void:
	for id: int in _owners:
		var tile: CanvasItem = _owners[id].get_ref()
		if is_instance_valid(tile):
			_disconnect(tile, id)
			tile.call("set_ambient_animation", false)
	_owners.clear()
	_connections.clear()
	_order.clear()
	_priority.clear()
	_native.clear()
	_animated.clear()
	_changed.clear()
	_cursor = 0
	_elapsed = 0.0
	_priority_depth = 0
	_refresh_pending = false


func _disconnect(tile: CanvasItem, id: int) -> void:
	for event: StringName in _connections.get(id, {}):
		var callback: Callable = _connections[id][event]
		if tile.is_connected(event, callback):
			tile.disconnect(event, callback)


func _set_native_priority(id: int, kind: StringName, enabled: bool) -> void:
	if not _owners.has(id):
		return
	var state: Dictionary = _native.get(id, {})
	if state.has(kind) == enabled:
		return
	if enabled:
		state[kind] = true
	else:
		state.erase(kind)
	if state.is_empty():
		_native.erase(id)
	else:
		_native[id] = state
	# Native focus also changes body rims. Repose even if this owner already
	# occupies an idle slot so a released focus can reacquire its cached body.
	_changed[id] = true
	_request_refresh()


func _refresh() -> void:
	_refreshes += 1
	var next: Dictionary = {}
	var stale: Array[int] = []
	var idle: int = 0
	# Membership changes and the slow rotation inspect the board. Ordinary
	# animation frames only touch the already selected IDs in the board view.
	for offset in range(_order.size()):
		var id: int = _order[(_cursor + offset) % _order.size()]
		var tile: CanvasItem = _owners[id].get_ref()
		if not is_instance_valid(tile):
			stale.append(id)
			continue
		if not _playing or _reduced or not tile.is_visible_in_tree():
			continue
		if _priority.has(id) or _native.has(id):
			next[id] = true
		elif idle < IDLE_SLOTS and (not tile.has_method("has_ambient_animation") or tile.call("has_ambient_animation")):
			next[id] = true
			idle += 1
	for id: int in _animated:
		if not next.has(id):
			_set_enabled(id, false)
	for id: int in next:
		if not _animated.has(id):
			_set_enabled(id, true)
	_animated = next
	for id: int in stale:
		_owners.erase(id)
		_connections.erase(id)
		_order.erase(id)
		_priority.erase(id)
		_native.erase(id)
		_changed.erase(id)
	_cursor = 0 if _order.is_empty() else _cursor % _order.size()


func _set_enabled(id: int, enabled: bool) -> void:
	var tile: CanvasItem = _owners[id].get_ref() if _owners.has(id) else null
	if is_instance_valid(tile):
		tile.call("set_ambient_animation", enabled)
		_changed[id] = true


func snapshot() -> Dictionary:
	return {"owners": _owners.size(), "animated_ids": animated_ids(),
		"refreshes": _refreshes, "priority_depth": _priority_depth,
		"refresh_pending": _refresh_pending}
