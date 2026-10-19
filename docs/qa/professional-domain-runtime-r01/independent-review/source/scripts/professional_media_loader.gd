extends Node
## One latest module selection, bounded raw transfers, and releasable resources.

signal completed(generation: int, result: Dictionary)

const Manifest = preload("res://scripts/professional_media_manifest.gd")
const Cache = preload("res://scripts/professional_media_cache.gd")
const DEFAULT_TIMEOUT := 15.0

var cache = Cache.new()
# Test seam: callback receives (metadata, generation, complete_callable).
# Production leaves this unset. Completion accepts {ok,bytes:PackedByteArray}.
var fetch_override: Callable
var timeout_seconds := DEFAULT_TIMEOUT
var _native_root := ""
var _host: Object
var _generation := 0
var _manifest: Dictionary = {}
var _queue: Array = []
var _index := 0
var _next_request := 0
var _pending: Dictionary = {}
var _callbacks: Dictionary = {}
var _loading := false


func configure(native_root: String = "", host: Object = null) -> void:
	cancel()
	_native_root = native_root
	if _native_root.is_empty():
		_native_root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func request_module(manifest: Dictionary, expected_context: Dictionary = {}, required_ids: Array = []) -> int:
	cancel()
	_generation += 1
	var generation: int = _generation
	var dependencies: Dictionary = Manifest.validate_dependencies(manifest, required_ids, expected_context)
	if not dependencies.ok:
		completed.emit.call_deferred(generation, dependencies)
		return generation
	var begun: Dictionary = cache.begin(manifest, generation, expected_context)
	if not begun.ok:
		completed.emit.call_deferred(generation, begun)
		return generation
	_manifest = begun.manifest.duplicate(true)
	_queue = _manifest.resources
	_index = 0
	_loading = true
	_next.call_deferred(generation)
	return generation


func cancel() -> void:
	var previous: int = _generation
	_generation += 1
	if _host != null:
		_host.professionalMediaCancel(previous)
	_pending.clear()
	cache.abort()
	if _loading:
		_loading = false
		completed.emit.call_deferred(previous, Manifest.failure("This media selection has been replaced.", "cancelled"))
	_queue.clear()
	_manifest.clear()


func _next(generation: int) -> void:
	if generation != _generation or not _loading:
		return
	while _index < _queue.size() and cache.contains(_queue[_index].id):
		_index += 1
	if _index >= _queue.size():
		var activated: Dictionary = cache.activate(generation)
		if activated.ok:
			activated["context"] = {"track": "professional", "course_id": _manifest.course_id,
				"module_id": _manifest.module_id, "curriculum_revision": _manifest.curriculum_revision}
		_finish(generation, activated)
		return
	var metadata: Dictionary = _queue[_index].duplicate(true)
	_next_request += 1
	var request_id: int = _next_request
	_pending[request_id] = {"generation": generation, "metadata": metadata}
	if is_inside_tree():
		get_tree().create_timer(clampf(timeout_seconds, 0.01, 60.0), true, false, true).timeout.connect(_timeout.bind(request_id, generation))
	if fetch_override.is_valid():
		fetch_override.call(metadata, generation, _receive_raw.bind(request_id, generation))
	elif _host != null:
		var receive: Callable = _receive_bridge.bind(request_id, generation)
		_callbacks[request_id] = JavaScriptBridge.create_callback(receive) if _host is JavaScriptObject else receive
		_host.professionalMediaRequest(JSON.stringify({"request_id": request_id, "generation": generation, "resource": metadata}), _callbacks[request_id])
	elif OS.has_feature("web"):
		_receive_raw(Manifest.failure("Professional media downloads are unavailable. Please retry.", "unavailable"), request_id, generation)
	else:
		_read_native.call_deferred(metadata, request_id, generation)


func _read_native(metadata: Dictionary, request_id: int, generation: int) -> void:
	if generation != _generation or not _pending.has(request_id):
		return
	if _native_root.is_empty():
		_receive_raw(Manifest.failure("Configure the native media delivery root before loading.", "unavailable"), request_id, generation)
		return
	# Paths have already been validated as a fixed content-addressed relative name.
	var file := FileAccess.open(_native_root.path_join(metadata.path), FileAccess.READ)
	if file == null:
		_receive_raw(Manifest.failure("Required media is missing. Please retry.", "missing_asset"), request_id, generation)
		return
	if file.get_length() != int(metadata.compressed_bytes):
		_receive_raw(Manifest.failure("Media size differs from its immutable manifest.", "size_mismatch"), request_id, generation)
		return
	var data: PackedByteArray = file.get_buffer(int(metadata.compressed_bytes))
	file.close()
	_receive_raw({"ok": true, "bytes": data}, request_id, generation)


func _receive_bridge(arguments: Array, request_id: int, generation: int) -> void:
	if generation != _generation or not _pending.has(request_id):
		_callbacks.erase(request_id)
		return
	var parser := JSON.new()
	var parsed: bool = arguments.size() == 1 and parser.parse(str(arguments[0])) == OK
	var result: Variant = parser.data if parsed else null
	if not result is Dictionary or result.get("request_id") != request_id or result.get("generation") != generation \
		or not result.get("ok") is bool:
		_receive_raw.call_deferred(Manifest.failure("Media returned an invalid response. Please retry.", "unavailable"), request_id, generation)
		return
	if result.ok:
		var expected: int = int(_pending[request_id].metadata.compressed_bytes)
		if not result.get("data_base64") is String or result.data_base64.length() != 4 * int(ceil(float(expected) / 3.0)):
			_receive_raw.call_deferred(Manifest.failure("Media returned an invalid byte payload.", "size_mismatch"), request_id, generation)
			return
		result["bytes"] = Marshalls.base64_to_raw(result.data_base64)
		result.erase("data_base64")
	_receive_raw.call_deferred(result, request_id, generation)


func _receive_raw(result: Dictionary, request_id: int, generation: int) -> void:
	if generation != _generation or not _pending.has(request_id):
		return
	var metadata: Dictionary = _pending[request_id].metadata
	_pending.erase(request_id)
	_callbacks.erase(request_id)
	if not result.get("ok", false):
		_finish(generation, result)
		return
	if not result.get("bytes") is PackedByteArray:
		_finish(generation, Manifest.failure("The media source returned no bytes.", "missing_asset"))
		return
	var decoded: Dictionary = Manifest.decode(result.bytes, metadata)
	result.erase("bytes")
	if not decoded.ok:
		_finish(generation, decoded)
		return
	var inserted: Dictionary = cache.insert(generation, metadata, decoded)
	if not inserted.ok:
		_finish(generation, inserted)
		return
	_index += 1
	_next.call_deferred(generation)


func _timeout(request_id: int, generation: int) -> void:
	if generation != _generation or not _pending.has(request_id):
		return
	if _host != null:
		_host.professionalMediaCancel(generation)
	_finish(generation, Manifest.failure("Media loading timed out. Please retry.", "timeout"))


func _finish(generation: int, result: Dictionary) -> void:
	if generation != _generation or not _loading:
		return
	_loading = false
	_pending.clear()
	if not result.get("ok", false):
		cache.abort()
	_queue.clear()
	_manifest.clear()
	completed.emit(generation, result)


func _exit_tree() -> void:
	cancel()
