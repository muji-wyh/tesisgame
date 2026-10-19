extends Node
## Prepare a complete module without replacing the currently playable round.

signal prepared(selection: int, content: Dictionary)
signal failed(selection: int, result: Dictionary)
signal theme_selected(selection: int, profile: Dictionary)

const Context = preload("res://scripts/learning_context.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Loader = preload("res://scripts/professional_media_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")

var catalog = Catalog.new()
var media = Loader.new()
var _selection: int = 0
var _media_generation: int = -1
var _content: Dictionary = {}
var _pending_scope: String = ""


func configure(host: Object = null, native_root: String = "") -> bool:
	if not media.is_inside_tree():
		add_child(media)
	if not media.completed.is_connected(_media_completed):
		media.completed.connect(_media_completed)
	media.configure(native_root, host)
	return catalog.load_index()


func request(context: Dictionary, seed_value: int = -1) -> int:
	cancel()
	var selection: int = _selection
	var result: Dictionary = catalog.resolve(context, seed_value)
	if not result.get("ok", false):
		failed.emit.call_deferred(selection, result)
		return selection
	_content = result
	theme_selected.emit(selection, result.theme_profile.duplicate(true))
	# A synchronous selection callback may already have chosen another course.
	if selection == _selection:
		_media_generation = media.request_module(result.media_manifest, context, result.required_resource_ids)
	return selection


func cancel() -> void:
	_selection += 1
	_media_generation = -1
	media.cancel()
	_content.clear()
	if not _pending_scope.is_empty():
		Access.release(_pending_scope)
		_pending_scope = ""


func claim(selection: int) -> Dictionary:
	if selection != _selection or _pending_scope.is_empty():
		return {"ok": false, "error": "This course selection has changed."}
	var content: Dictionary = Access.bind_content(_content, _pending_scope)
	if content.ok:
		# Ownership transfers to the round. The game must clear its images and
		# audio players before releasing content.media_scope on round teardown.
		_pending_scope = ""
	return content


func _media_completed(generation: int, result: Dictionary) -> void:
	if generation != _media_generation or _content.is_empty():
		return
	var selection: int = _selection
	if not result.get("ok", false):
		failed.emit(selection, result)
		return
	var pinned: Dictionary = Access.acquire(media.cache, result.resource_ids)
	if not pinned.ok:
		failed.emit(selection, pinned)
		return
	_pending_scope = pinned.scope
	var content: Dictionary = Access.bind_content(_content, _pending_scope)
	if not content.ok:
		Access.release(_pending_scope)
		_pending_scope = ""
		failed.emit(selection, content)
		return
	prepared.emit(selection, content)


func _exit_tree() -> void:
	cancel()
