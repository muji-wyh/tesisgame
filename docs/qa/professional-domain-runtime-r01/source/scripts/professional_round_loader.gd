extends Node
## Prepare a complete module without replacing the currently playable round.

signal prepared(selection: int, content: Dictionary)
signal failed(selection: int, result: Dictionary)
signal theme_selected(selection: int, profile: Dictionary)
# Terminal and synchronous: Play must obsolete a pending storage open immediately.
# The selection is the last loader selection, before cancellation increments it.
signal invalidated(selection: int, result: Dictionary)

const Context = preload("res://scripts/learning_context.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Owner = preload("res://scripts/professional_domain_owner.gd")
const Loader = preload("res://scripts/professional_media_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")

# Ordinary catalog metadata remains available to Home; it cannot prepare rounds.
var catalog = Catalog.new()
var media = Loader.new()
var _owner = Owner.new()
var _selection: int = 0
var _preparation: Dictionary = {}
var _configure_started: bool = false
var _configured: bool = false
var _closed: bool = false


func configure(host: Object = null, native_root: String = "") -> bool:
	if _closed:
		return false
	# Retain the first outcome and transport. Repeated calls cannot cancel work,
	# reconnect signals, or reopen an incompletely initialized instance.
	if _configure_started:
		return _configured
	_configure_started = true
	if not is_instance_valid(_owner) or not is_instance_valid(media):
		return false
	if _owner.get_parent() != null or media.get_parent() != null:
		return false
	add_child(_owner)
	add_child(media)
	_owner.completed.connect(_owner_completed.bind(_owner))
	_owner.retired.connect(_owner_retired.bind(_owner))
	media.completed.connect(_media_completed.bind(media))
	var policy: Dictionary = _owner.configure()
	if not policy.get("ok", false) or _closed:
		return false
	media.configure(native_root, host)
	if _closed:
		return false
	_configured = catalog.load_index()
	return _configured


func request(context: Dictionary, seed_value: int = -1) -> int:
	var selection: int = _selection + 1
	cancel()
	if selection != _selection:
		return selection
	if not _configured or _closed:
		_publish_failure.call_deferred(selection, _failure("Professional lessons are unavailable.", "policy_unavailable"))
		return selection
	if not Context.validate(context).is_empty() or context.get("track") != "professional":
		_publish_failure.call_deferred(selection, _failure("Choose a valid Professional lesson.", "invalid_context"))
		return selection
	var captured: Dictionary = Context.freeze(context)
	var preparation: Dictionary = {"selection": selection, "context": captured, "seed": seed_value,
		"owner": _owner, "policy_request": -1, "token": null, "content": {}, "media": media,
		"media_generation": -1, "pending_scope": "", "phase": "policy"}
	_preparation = preparation
	var request_id: int = _owner.request(captured, seed_value)
	if _matches(preparation):
		preparation.policy_request = request_id
	return selection


func cancel() -> void:
	_selection += 1
	var selection: int = _selection
	var previous: Dictionary = _preparation
	_preparation = {}
	_release_pending(previous)
	# Resource/host callbacks may synchronously start a replacement request.
	if selection != _selection:
		return
	if is_instance_valid(_owner):
		_owner.cancel()
	if selection == _selection and is_instance_valid(media):
		media.cancel()


func can_claim(selection: int) -> bool:
	return selection == _selection and not _preparation.is_empty() \
		and _preparation.get("phase") == "prepared" and not str(_preparation.get("pending_scope", "")).is_empty() \
		and _authorized(_preparation)


func claim(selection: int) -> Dictionary:
	if not can_claim(selection):
		return _failure("This course selection has changed.", "stale_policy")
	var preparation: Dictionary = _preparation
	var scope: String = preparation.pending_scope
	var content: Dictionary = Access.bind_content(preparation.content, scope)
	if not _authorized(preparation) or preparation.get("pending_scope", "") != scope:
		_reject_stale(preparation)
		return _failure("This course selection has changed.", "stale_policy")
	if not content.get("ok", false):
		_fail_preparation(preparation, content)
		return content
	# Ownership transfers exactly once. The round keeps its scope when later
	# policy/media work is cancelled, and releases it after dropping views/audio.
	preparation.pending_scope = ""
	preparation.token = null
	preparation.content = {}
	_preparation = {}
	return content


func close() -> void:
	if _closed:
		return
	var selection: int = _selection
	_closed = true
	_configured = false
	cancel()
	if is_instance_valid(_owner):
		_owner.retire()
	invalidated.emit(selection, _failure("Professional lessons are unavailable.", "policy_unavailable"))


func _owner_completed(request_id: int, result: Dictionary, source_owner: Object) -> void:
	# Even an internal test owner that emits inside request cannot publish before
	# request returns. Copy signal data before another listener can mutate it.
	_complete_policy.call_deferred(request_id, result.duplicate(true), source_owner)


func _complete_policy(request_id: int, result: Dictionary, source_owner: Object) -> void:
	var preparation: Dictionary = _preparation
	if not _matches(preparation) or source_owner != preparation.owner \
		or request_id != preparation.policy_request or preparation.phase != "policy":
		return
	if not result.get("ok", false):
		_fail_preparation(preparation, result)
		return
	preparation.token = result.get("token")
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	var content: Dictionary = source_owner.resolve(preparation.token)
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	if not content.get("ok", false):
		_fail_preparation(preparation, content)
		return
	if not content.get("context") is Dictionary or not Context.same_round(content.context, preparation.context) \
		or not content.get("theme_profile") is Dictionary or not content.get("media_manifest") is Dictionary \
		or not content.get("required_resource_ids") is Array:
		_fail_preparation(preparation, _failure("The Professional result does not match this lesson.", "invalid_policy"))
		return
	preparation.content = content
	preparation.phase = "theme"
	theme_selected.emit(preparation.selection, content.theme_profile.duplicate(true))
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	preparation.phase = "media"
	var generation: int = preparation.media.request_module(content.media_manifest,
		preparation.context, content.required_resource_ids)
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	preparation.media_generation = generation


func _media_completed(generation: int, result: Dictionary, source_media: Object) -> void:
	_complete_media.call_deferred(generation, result.duplicate(true), source_media)


func _complete_media(generation: int, result: Dictionary, source_media: Object) -> void:
	var preparation: Dictionary = _preparation
	if not _matches(preparation) or source_media != preparation.media \
		or generation != preparation.media_generation or preparation.phase != "media":
		return
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	if not result.get("ok", false):
		_fail_preparation(preparation, result)
		return
	if not result.get("resource_ids") is Array:
		_fail_preparation(preparation, _failure("The required lesson media is unavailable.", "invalid_media"))
		return
	preparation.phase = "acquiring"
	var pinned: Dictionary = Access.acquire(preparation.media.cache, result.resource_ids)
	if not _authorized(preparation):
		if pinned.get("ok", false):
			Access.release(pinned.scope)
		_reject_stale(preparation)
		return
	if not pinned.get("ok", false):
		_fail_preparation(preparation, pinned)
		return
	preparation.pending_scope = pinned.scope
	var content: Dictionary = Access.bind_content(preparation.content, preparation.pending_scope)
	if not _authorized(preparation):
		_reject_stale(preparation)
		return
	if not content.get("ok", false):
		_fail_preparation(preparation, content)
		return
	preparation.phase = "prepared"
	# This handler itself is deferred; authority is checked after acquisition and
	# binding, immediately before the synchronous consumer callback boundary.
	prepared.emit(preparation.selection, content)


func _matches(preparation: Dictionary) -> bool:
	return _configured and not _closed and not preparation.is_empty() and not _preparation.is_empty() \
		and preparation.get("selection", -1) == _selection and _preparation.get("selection", -1) == _selection \
		and is_instance_valid(_owner) and preparation.get("owner") == _owner and _preparation.get("owner") == _owner \
		and preparation.get("policy_request", -1) == _preparation.get("policy_request", -1) \
		and is_instance_valid(media) and preparation.get("media") == media


func _authorized(preparation: Dictionary) -> bool:
	return _matches(preparation) and preparation.get("token") is RefCounted \
		and preparation.owner.is_current(preparation.token) and _matches(preparation)


func _reject_stale(preparation: Dictionary) -> void:
	if _matches(preparation):
		_fail_preparation(preparation, _failure("This course selection has changed.", "stale_policy"))


func _fail_preparation(preparation: Dictionary, result: Dictionary) -> void:
	if not _matches(preparation):
		return
	var selection: int = preparation.selection
	_preparation = {}
	_release_pending(preparation)
	if selection != _selection:
		return
	_owner.cancel()
	if selection != _selection:
		return
	media.cancel()
	_publish_failure.call_deferred(selection, result.duplicate(true))


func _release_pending(preparation: Dictionary) -> void:
	if preparation.is_empty():
		return
	var scope: String = preparation.get("pending_scope", "")
	preparation.pending_scope = ""
	preparation.token = null
	preparation.content = {}
	if not scope.is_empty():
		Access.release(scope)


func _publish_failure(selection: int, result: Dictionary) -> void:
	if selection == _selection and _preparation.is_empty():
		failed.emit(selection, result)


func _owner_retired(source_owner: Object) -> void:
	if source_owner == _owner:
		close()


func _failure(message: String, code: String) -> Dictionary:
	return {"ok": false, "error": message, "code": code}


func _exit_tree() -> void:
	close()
