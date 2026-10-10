extends Node
## Mount age-scoped media only after the host verifies a complete download.

signal age_ready(age: int)
signal age_failed(age: int, message: String)
signal progress_changed(age: int, progress: float)

var _host: Object
var _mount: Callable
var _native: bool = false
var _configured: bool = false
var _generation: int = 0
var _states: Dictionary = {}
var _callbacks: Dictionary = {}
var _requests: Dictionary = {}
var _mounted_paths: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(host: Object = null, mount: Callable = Callable()) -> void:
	_generation += 1
	_states.clear()
	_callbacks.clear()
	_requests.clear()
	_host = host
	_mount = mount
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")
	_native = _host == null and not OS.has_feature("web")
	_configured = true


func request_age(age: int) -> void:
	if not _configured:
		configure()
	if age < 3 or age > 12:
		age_failed.emit(age, "Please choose an available age word set.")
		return
	if str(status(age).state) in ["loading", "ready"]:
		return
	_states[age] = {"age": age, "state": "loading", "progress": 0.0, "path": "", "paths": [], "error": ""}
	progress_changed.emit(age, 0.0)
	if _native:
		_complete(age, "")
		return
	if _host == null:
		_fail(age, "The words are unavailable. Please reload the game and try again.")
		return
	_requests[age] = int(_requests.get(age, 0)) + 1
	var receive: Callable = _receive.bind(age, _generation, int(_requests[age]))
	if _host is JavaScriptObject:
		_callbacks[age] = JavaScriptBridge.create_callback(receive)
	else:
		_callbacks[age] = receive
	_host.requestVocabulary(age, _callbacks[age])


func is_ready(age: int) -> bool:
	return str(status(age).state) == "ready"


func status(age: int) -> Dictionary:
	return _states.get(age, {"age": age, "state": "idle", "progress": 0.0, "path": "", "paths": [], "error": ""}).duplicate(true)


func _receive(arguments: Array, age: int, generation: int, request: int) -> void:
	if generation != _generation or request != int(_requests.get(age, 0)) or str(status(age).state) != "loading":
		return
	if arguments.size() != 1 or not arguments[0] is String or str(arguments[0]).length() > 65536:
		_fail(age, "The word download returned an invalid response. Please try again.")
		return
	var reply: Variant = JSON.parse_string(arguments[0])
	if not reply is Dictionary or reply.get("age") != age or reply.get("state") not in ["loading", "ready", "failed"]:
		_fail(age, "The word download returned an invalid response. Please try again.")
		return
	if reply.state == "failed":
		_fail(age, str(reply.get("error", "The words could not be loaded. Please try again.")))
		return
	var progress: Variant = reply.get("progress", 0.0)
	if not (progress is float or progress is int) or not is_finite(float(progress)) or float(progress) < 0.0 or float(progress) > 1.0:
		_fail(age, "The word download returned invalid progress. Please try again.")
		return
	if reply.state == "loading":
		var next_progress: float = maxf(float(_states[age].progress), float(progress))
		if next_progress != float(_states[age].progress):
			_states[age].progress = next_progress
			progress_changed.emit(age, next_progress)
		return
	var paths: Array[String] = _validated_paths(reply, age)
	if paths.is_empty():
		_fail(age, "The word download returned an invalid resource path. Please try again.")
		return
	for path in paths:
		if _mounted_paths.has(path):
			continue
		var mounted: bool = bool(_mount.call(path, false)) if _mount.is_valid() else ProjectSettings.load_resource_pack(path, false)
		if not mounted:
			_fail(age, "These words could not be opened. Please try again.")
			return
		# Successful mounts survive retries and loader reconfiguration.
		_mounted_paths[path] = true
	_complete(age, str(reply.path), paths)


func _validated_paths(reply: Dictionary, age: int) -> Array[String]:
	var result: Array[String] = []
	var base: Variant = reply.get("path")
	var base_pattern := RegEx.new()
	base_pattern.compile("^/vocabulary-%d-[a-f0-9]{16,64}\\.pck$" % age)
	if not base is String or base_pattern.search(base) == null:
		return result
	var paths: Variant = reply.get("paths", [base])
	if not paths is Array or paths.is_empty() or paths.size() > 513 or paths.back() != base:
		return result
	var shared_pattern := RegEx.new()
	shared_pattern.compile("^/vocabulary-shared-((?:[0-9]+-)+)[a-f0-9]{16,64}\\.pck$")
	for index in paths.size():
		var path: Variant = paths[index]
		if not path is String or result.has(path):
			return []
		if index < paths.size() - 1:
			var match_result: RegExMatch = shared_pattern.search(path)
			if match_result == null:
				return []
			var consumers: PackedStringArray = match_result.get_string(1).trim_suffix("-").split("-")
			if consumers.size() < 2 or consumers.size() > 10 or not consumers.has(str(age)):
				return []
			var previous: int = 2
			for consumer in consumers:
				var value: int = int(consumer)
				if value <= previous or value > 12 or str(value) != consumer:
					return []
				previous = value
		result.append(path)
	return result


func _complete(age: int, path: String, paths: Array[String] = []) -> void:
	_states[age] = {"age": age, "state": "ready", "progress": 1.0, "path": path, "paths": paths.duplicate(), "error": ""}
	progress_changed.emit(age, 1.0)
	age_ready.emit(age)


func _fail(age: int, message: String) -> void:
	_states[age] = {"age": age, "state": "failed", "progress": float(status(age).progress), "path": "", "paths": [], "error": message}
	age_failed.emit(age, message)
