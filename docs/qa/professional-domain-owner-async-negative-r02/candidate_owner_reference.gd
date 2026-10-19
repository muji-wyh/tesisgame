extends Node
## Candidate async owner. Fixed synthetic fixture resources carry no app authority.
## Process turns run bounded chunks/phases inside a small elapsed-time budget.

signal completed(selection: int, result: Dictionary)
signal phase_entered(selection: int, phase: String)

const Context = preload("res://scripts/learning_context.gd")
const Adapter = preload("res://fixture_catalog.gd")
const DESCRIPTOR: String = "res://fixture/release.json"
const RELEASE_ROOT: String = "res://fixture/release/"
const POLICY: String = "ordinary-lexical-v3"
const BOUNDARY: String = "containing-modules-v1"
const MAX_DESCRIPTOR: int = 8192
const MAX_INDEX: int = 262144
const MAX_PAYLOAD: int = 524288
const READ_CHUNK: int = 16384
const FRAME_BUDGET_USEC: int = 4000
const MAX_STEPS_PER_FRAME: int = 32

class RequestToken extends RefCounted:
	pass

var _epoch: int = 0
var _selection: int = 0
var _configured: bool = false
var _installed: bool = false
var _rows: Dictionary = {}
var _themes: Dictionary = {}
var _cache: Dictionary = {}
var _cache_key: String = ""
var _tokens: Dictionary = {}
var _job: Dictionary = {}
var _file: FileAccess
var _hash: HashingContext
var _raw: PackedByteArray = PackedByteArray()
var _expected: Dictionary = {}
var _length: int = 0
var _read_kind: String = ""
var _reads: int = 0
var _bytes: int = 0
var _publications: int = 0
var _cache_insertions: int = 0
var _largest_chunk: int = 0
var _process_turns: int = 0
var _steps: int = 0
var _largest_steps_per_turn: int = 0
var _last_error: String = ""


func configure() -> Dictionary:
	# Replacement retires all visible authority before any replacement file is read.
	retire()
	_configured = true
	set_process(true)
	return {"ok": true, "authority": "none"}


func request(value: Variant, seed_value: int = 17) -> int:
	cancel()
	var selection: int = _selection
	if not _configured:
		_queue_error(selection, "The fixture owner is retired or unconfigured.")
		return selection
	if not value is Dictionary or not Context.validate(value).is_empty() or value.get("track") != "professional":
		_queue_error(selection, "Invalid professional fixture context.")
		return selection
	var context: Dictionary = Context.freeze(value)
	_job = {"selection": selection, "epoch": _epoch, "context": context, "seed": seed_value,
		"key": context.course_id + "/" + context.module_id, "phase": "select" if _installed else "descriptor_open"}
	return selection


func resolve(token: Variant) -> Dictionary:
	if not _configured or not token is RefCounted or not _tokens.has(token):
		return _failure("The request token has no authority in this fixture owner.")
	var state: Dictionary = _tokens[token]
	if state.epoch != _epoch or state.selection != _selection:
		return _failure("The request token belongs to a retired fixture generation.")
	return state.content.duplicate(true)


func cancel() -> void:
	_selection += 1
	_tokens.clear()
	_job.clear()
	_close_read()


func retire() -> void:
	cancel()
	_epoch += 1
	_configured = false
	_installed = false
	_rows.clear()
	_themes.clear()
	_cache = {}
	_cache_key = ""


func diagnostics() -> Dictionary:
	return {"configured": _configured, "installed": _installed, "epoch": _epoch,
		"selection": _selection, "phase": _job.get("phase", "idle"), "policy_file_reads": _reads,
		"encoded_bytes_read": _bytes, "cached_modules": 0 if _cache.is_empty() else 1,
		"active_tokens": _tokens.size(), "active_jobs": 0 if _job.is_empty() else 1,
		"publications": _publications, "cache_insertions": _cache_insertions,
		"largest_read_chunk": _largest_chunk, "open_files": 0 if _file == null else 1,
		"process_turns": _process_turns, "steps": _steps, "largest_steps_per_turn": _largest_steps_per_turn}


func _process(_delta: float) -> void:
	if _job.is_empty():
		return
	_process_turns += 1
	var began: int = Time.get_ticks_usec()
	var steps: int = 0
	while not _job.is_empty() and steps < MAX_STEPS_PER_FRAME:
		_advance_one()
		steps += 1
		_steps += 1
		if Time.get_ticks_usec() - began >= FRAME_BUDGET_USEC:
			break
	_largest_steps_per_turn = maxi(_largest_steps_per_turn, steps)


func _advance_one() -> void:
	if _job.is_empty():
		return
	var selection: int = _job.selection
	var epoch: int = _job.epoch
	var phase: String = _job.phase
	# This checkpoint exposes scheduling only, never source data or authority.
	phase_entered.emit(selection, phase)
	if not _current(selection, epoch) or _job.phase != phase:
		return
	if phase.ends_with("_open"):
		_open_phase(phase.trim_suffix("_open"))
	elif phase.ends_with("_read"):
		_read_chunk()
	elif phase.ends_with("_decode"):
		_decode_phase()
	elif phase == "descriptor_validate":
		_validate_descriptor()
	elif phase == "index_validate":
		var problem: String = _validate_index(_job.decoded)
		if not problem.is_empty():
			_fail_job(problem)
		else:
			_job.index = _job.decoded
			_job.erase("decoded")
			_job.phase = "themes_open"
	elif phase == "themes_validate":
		_validate_themes()
	elif phase == "select":
		_select_payload()
	elif phase == "payload_validate":
		var problem: String = _validate_payload(_job.decoded, _job.context.course_id, _job.context.module_id)
		if not problem.is_empty():
			_fail_job(problem)
		else:
			_job.snapshot = _job.decoded
			_job.erase("decoded")
			_job.phase = "resolve"
	elif phase == "resolve":
		_resolve_phase(selection, epoch)
	elif phase == "publish":
		_publish(selection, epoch)
	elif phase == "error":
		var result: Dictionary = _job.result.duplicate(true)
		_job.clear()
		completed.emit(selection, result)


func _current(selection: int, epoch: int) -> bool:
	return not _job.is_empty() and _job.selection == selection and _selection == selection \
		and _job.epoch == epoch and _epoch == epoch


func _queue_error(selection: int, message: String, code: String = "invalid_fixture") -> void:
	_job = {"selection": selection, "epoch": _epoch, "phase": "error", "result": _failure(message, code)}


func _fail_job(message: String, code: String = "invalid_fixture") -> void:
	var selection: int = _job.selection
	_close_read()
	_queue_error(selection, message, code)


func _open_phase(kind: String) -> void:
	var path: String = DESCRIPTOR
	var maximum: int = MAX_DESCRIPTOR
	_expected = {}
	if kind in ["index", "themes"]:
		_expected = _job.descriptor[kind]
		path = _expected.path
		maximum = MAX_INDEX
	elif kind == "payload":
		_expected = _job.row.payload
		path = RELEASE_ROOT + _expected.path
		maximum = MAX_PAYLOAD
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null:
		_fail_job("Missing fixture resource.")
		return
	_length = _file.get_length()
	_reads += 1
	if _length < 1 or _length > maximum or not _expected.is_empty() and _expected.get("bytes") != _length:
		_fail_job("Fixture resource length differs or exceeds its bound.")
		return
	_hash = HashingContext.new()
	_hash.start(HashingContext.HASH_SHA256)
	_raw = PackedByteArray()
	_read_kind = kind
	_job.phase = kind + "_read"


func _read_chunk() -> void:
	var wanted: int = mini(READ_CHUNK, _length - _raw.size())
	var chunk: PackedByteArray = _file.get_buffer(wanted)
	_bytes += chunk.size()
	_largest_chunk = maxi(_largest_chunk, chunk.size())
	if chunk.size() != wanted:
		_fail_job("Fixture resource is truncated.")
		return
	_hash.update(chunk)
	_raw.append_array(chunk)
	if _raw.size() == _length:
		_file.close()
		_file = null
		var digest: String = _hash.finish().hex_encode()
		_hash = null
		if not _expected.is_empty() and digest != _expected.get("sha256"):
			_fail_job("Fixture resource digest differs.")
			return
		_job.phase = _read_kind + "_decode"


func _decode_phase() -> void:
	# Native JSON decoding is indivisible. Its target-platform duration is unmeasured.
	var value: Variant = JSON.parse_string(_raw.get_string_from_utf8())
	_raw = PackedByteArray()
	if not value is Dictionary:
		_fail_job("Fixture resource is not a JSON object.")
		return
	_job.decoded = value
	_job.phase = _read_kind + "_validate"


func _validate_descriptor() -> void:
	var descriptor: Dictionary = _job.decoded
	if descriptor.get("schema") != 1 or descriptor.get("kind") != "isolated_compiled_domain_fixture_v1" \
		or descriptor.get("authority") != "none" or descriptor.get("production_use_prohibited") != true \
		or not descriptor.get("index") is Dictionary or not descriptor.get("themes") is Dictionary:
		_fail_job("Fixture descriptor is unavailable or unsupported.")
		return
	for spec: Array in [["index", RELEASE_ROOT + "index.json"], ["themes", "res://fixture/themes.json"]]:
		var item: Dictionary = descriptor[spec[0]]
		if item.get("path") != spec[1] or not _digest(item.get("sha256")) \
			or not _integer(item.get("bytes")) or item.bytes < 1 or item.bytes > MAX_INDEX:
			_fail_job("Fixture descriptor contains an invalid fixed resource.")
			return
	_job.descriptor = descriptor
	_job.erase("decoded")
	_job.phase = "index_open"


func _validate_themes() -> void:
	var themes: Dictionary = _job.decoded
	if themes.get("schema_version") != 1 or not themes.get("profiles") is Array:
		_fail_job("Fixture theme snapshot is invalid.")
		return
	var profiles: Dictionary = {}
	for profile: Variant in themes.profiles:
		if not profile is Dictionary or not profile.get("id") is String or profiles.has(profile.id):
			_fail_job("Fixture theme identity is invalid.")
			return
		profiles[profile.id] = profile
	# Commit the installed metadata together. Cancelled partial reads never install it.
	var rows: Dictionary = {}
	for row: Dictionary in _job.index.modules:
		rows[row.course_id + "/" + row.module_id] = row
	_rows = rows
	_themes = profiles
	_installed = true
	_job.erase("decoded")
	_job.erase("index")
	_job.erase("descriptor")
	_job.phase = "select"


func _select_payload() -> void:
	var row: Variant = _rows.get(_job.key)
	if not row is Dictionary or row.get("state") != "ready":
		_fail_job("This fixture module is unavailable.", "content_pending")
		return
	_job.row = row
	if _cache_key == _job.key and not _cache.is_empty():
		_job.snapshot = _cache
		_job.phase = "resolve"
	else:
		_job.phase = "payload_open"


func _resolve_phase(selection: int, epoch: int) -> void:
	var snapshot: Dictionary = _job.snapshot
	if snapshot.course.get("curriculum_revision") != _job.context.curriculum_revision:
		_fail_job("Fixture curriculum revision mismatch.")
		return
	var profile: Variant = _themes.get(snapshot.course.get("theme_id"))
	if not profile is Dictionary:
		_fail_job("Fixture theme is unavailable.")
		return
	var adapter: RefCounted = Adapter.new(snapshot, profile)
	var result: Dictionary = adapter.resolve(_job.context, _job.seed)
	if not _current(selection, epoch):
		return
	if not result.get("ok", false):
		_job.result = result.duplicate(true)
		_job.phase = "error"
		return
	_job.content = result
	_job.phase = "publish"


func _publish(selection: int, epoch: int) -> void:
	if not _current(selection, epoch):
		return
	# No cache insertion or token exists until every prior stage completed current.
	if _cache_key != _job.key:
		_cache = _job.snapshot
		_cache_key = _job.key
		_cache_insertions += 1
	var token: RefCounted = RequestToken.new()
	_tokens[token] = {"epoch": epoch, "selection": selection, "content": _job.content}
	_job.clear()
	_publications += 1
	completed.emit(selection, {"ok": true, "token": token})


func _close_read() -> void:
	if _file != null:
		_file.close()
	_file = null
	_hash = null
	_raw = PackedByteArray()
	_expected = {}
	_length = 0
	_read_kind = ""


func _exit_tree() -> void:
	retire()


func _validate_index(index: Dictionary) -> String:
	if index.get("schema_version") != 1 or index.get("kind") != "compiled_professional_release_v1" \
		or index.get("policy_version") != POLICY or index.get("context_boundary") != BOUNDARY \
		or index.get("trust_status") != "scratch_no_app_authority":
		return "Unsupported compiled fixture index."
	if not index.get("modules") is Array or index.modules.size() != 200:
		return "Fixture index must contain all 200 modules."
	var seen: Dictionary = {}
	for row: Variant in index.modules:
		if not row is Dictionary or not row.get("course_id") is String or not row.get("module_id") is String:
			return "Invalid fixture module identity."
		var key: String = row.course_id + "/" + row.module_id
		if seen.has(key):
			return "Duplicate fixture module identity."
		seen[key] = true
		if row.get("state") == "unavailable":
			if row.get("source_status") not in ["draft", "planned"] or row.has("payload"):
				return "Unavailable fixture row cannot authorize a payload."
		elif row.get("state") == "ready":
			var descriptor: Variant = row.get("payload")
			if row.get("source_status") != "ready" or not descriptor is Dictionary \
				or not _digest(descriptor.get("sha256")) or not _integer(descriptor.get("bytes")) \
				or descriptor.bytes < 1 or descriptor.bytes > MAX_PAYLOAD \
				or descriptor.get("path") != "modules/" + str(descriptor.sha256) + ".json":
				return "Invalid fixture ready descriptor."
		else:
			return "Unknown fixture availability state."
	return ""


func _validate_payload(payload: Dictionary, course_id: String, module_id: String) -> String:
	if payload.get("schema_version") != 1 or payload.get("kind") != "compiled_professional_module_v1" \
		or payload.get("policy_version") != POLICY or payload.get("context_boundary") != BOUNDARY \
		or payload.get("course_id") != course_id or payload.get("module_id") != module_id:
		return "Compiled fixture payload identity differs."
	var course: Variant = payload.get("course")
	if not course is Dictionary or course.get("id") != course_id or not course.get("modules") is Array:
		return "Compiled fixture course identity differs."
	var selected: Dictionary = {}
	var module_ids: Dictionary = {}
	for module: Variant in course.modules:
		if not module is Dictionary or not module.get("id") is String or module_ids.has(module.id):
			return "Compiled fixture course has duplicate or invalid modules."
		module_ids[module.id] = true
		if module.id == module_id:
			selected = module
	if selected.get("status") != "ready":
		return "Compiled fixture module is not ready."
	for spec: Array in [["lexemes", "lexeme_ids", "lexical_domain", 50], ["expressions", "expression_ids", "expression_domain", 10]]:
		var records: Variant = payload.get(spec[0])
		var ids: Variant = selected.get(spec[1])
		var domain: Variant = payload.get(spec[2])
		if not records is Array or not ids is Array or not domain is Array \
			or records.size() != spec[3] or ids.size() != spec[3] or domain.size() != spec[3]:
			return "Compiled fixture selected membership count differs."
		var registry: Dictionary = {}
		for offset: int in range(ids.size()):
			var record: Variant = records[offset]
			if not ids[offset] is String or registry.has(ids[offset]) or not record is Dictionary or record.get("id") != ids[offset]:
				return "Compiled fixture selected membership identity differs."
			registry[ids[offset]] = record
		var rows: Dictionary = {}
		for row: Variant in domain:
			if not row is Dictionary or not row.get("id") is String or rows.has(row.id) \
				or not registry.has(row.id) or not row.get("coarse_required") is bool \
				or not row.has("exception") or row.exception != null:
				return "Compiled fixture domain row is invalid or grants an exception."
			rows[row.id] = true
			var review: Variant = registry[row.id].get("review")
			if not review is Dictionary or review.get("status") != "reviewed" or review.get("language") != "reviewed" \
				or review.get("domain") not in ["reviewed", "not_required"] \
				or row.coarse_required and review.domain != "reviewed":
				return "Compiled fixture requires the original lexical and expression domain reviews."
	return ""


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


func _digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _failure(message: String, code: String = "invalid_fixture") -> Dictionary:
	return {"ok": false, "error": message, "code": code, "words": [], "expressions": []}
