extends Node
## Application-pinned Professional policy owner, adapted from the frozen async owner.
## The public request accepts only a context and seed. Authority never comes from a caller.

signal completed(request_id: int, result: Dictionary)
signal phase_entered(request_id: int, phase: String)
signal retired

const Context = preload("res://scripts/learning_context.gd")
const Adapter = preload("res://scripts/professional_domain_catalog.gd")
const MediaManifest = preload("res://scripts/professional_media_manifest.gd")
const PIN_PATH: String = "res://scripts/professional_domain_release.gd"
const RELEASE_ROOT: String = "res://data/professional/domain-policy/generated/"
const DESCRIPTOR_PATH: String = RELEASE_ROOT + "release.json"
const POLICY: String = "ordinary-lexical-v3"
const BOUNDARY: String = "containing-modules-v1"
const TRUST: String = "application_build_audited"
const MAX_DESCRIPTOR: int = 262144
const MAX_INDEX: int = 262144
const MAX_THEMES: int = 262144
const MAX_MANIFEST: int = 262144
const MAX_PAYLOAD: int = 524288
const MAX_COLD_BYTES: int = 2097152
const MAX_COLD_OPENS: int = 16
const MAX_ARTIFACTS: int = 402
const READ_CHUNK: int = 16384
const FRAME_BUDGET_USEC: int = 4000
const MAX_STEPS_PER_FRAME: int = 32
const BINDING_KEYS: Array[String] = ["source_inventory_sha256", "supporting_inventory_sha256", "contracts_sha256"]

class RequestToken extends RefCounted:
	pass

class CatalogCapability extends RefCounted:
	pass

var _epoch: int = 0
var _selection: int = 0
var _configured: bool = false
var _closed: bool = false
var _installed: bool = false
var _release_sha256: String = ""
var _pin: Dictionary = {}
var _descriptor: Dictionary = {}
var _rows: Dictionary = {}
var _themes: Dictionary = {}
var _cache: Dictionary = {}
var _cache_key: String = ""
var _tokens: Dictionary = {}
var _catalog_capabilities: Dictionary = {}
var _job: Dictionary = {}
var _file: FileAccess
var _hash: HashingContext
var _raw: PackedByteArray = PackedByteArray()
var _expected: Dictionary = {}
var _length: int = 0
var _read_kind: String = ""
var _reads: int = 0
var _bytes: int = 0
var _manifest_reads: int = 0
var _decode_calls: int = 0
var _resolve_calls: int = 0
var _publications: int = 0
var _cache_insertions: int = 0
var _cache_hits: int = 0
var _largest_chunk: int = 0
var _process_turns: int = 0
var _steps: int = 0
var _largest_steps_per_turn: int = 0
var _last_request: Dictionary = {}


func configure() -> Dictionary:
	if _closed:
		return _failure("The Professional policy owner has been retired.", "policy_unavailable")
	if not _configured:
		_epoch += 1
		_configured = true
		set_process(false)
	# Configuration schedules no reads and grants no policy authority.
	return {"ok": true}


func request(value: Variant, seed_value: int = 17) -> int:
	cancel()
	var selection: int = _selection
	_last_request = {"request_id": selection, "ok": false, "code": "pending", "policy_file_reads": 0,
		"encoded_bytes_read": 0, "manifest_file_reads": 0, "warm_cache_hit": false}
	if not _configured or _closed:
		_queue_error(selection, "The Professional policy owner is unavailable.", "policy_unavailable")
		return selection
	if not value is Dictionary or not Context.validate(value).is_empty() or value.get("track") != "professional":
		_queue_error(selection, "Choose a valid Professional lesson.")
		return selection
	var context: Dictionary = Context.freeze(value)
	_job = {"selection": selection, "epoch": _epoch, "context": context, "seed": seed_value,
		"key": context.course_id + "/" + context.module_id, "phase": "select" if _installed else "pin",
		"opens": 0, "bytes": 0, "manifest_opens": 0, "warm": false}
	set_process(true)
	return selection


func is_current(token: Variant) -> bool:
	if not _configured or _closed or not _installed or _release_sha256.is_empty() \
		or not token is RefCounted or not _tokens.has(token):
		return false
	var state: Dictionary = _tokens[token]
	return state.epoch == _epoch and state.selection == _selection and state.release_sha256 == _release_sha256


func resolve(token: Variant) -> Dictionary:
	if not is_current(token):
		return _failure("The Professional request is no longer current.", "stale_policy")
	return _tokens[token].content.duplicate(true)


func cancel() -> void:
	_selection += 1
	_tokens.clear()
	_catalog_capabilities.clear()
	_job.clear()
	_close_read()
	set_process(false)


func retire() -> void:
	var notify_retired: bool = not _closed
	cancel()
	_epoch += 1
	_closed = true
	_configured = false
	_installed = false
	_release_sha256 = ""
	_pin = {}
	_descriptor = {}
	_rows = {}
	_themes = {}
	_cache = {}
	_cache_key = ""
	if notify_retired:
		# Consumers must coordinate pending media and storage cancellation as well.
		# A claimed media lease remains owned by its existing round/view lifecycle.
		retired.emit()


func diagnostics() -> Dictionary:
	return {"configured": _configured, "closed": _closed, "installed": _installed, "epoch": _epoch,
		"selection": _selection, "phase": _job.get("phase", "idle"), "policy_file_reads": _reads,
		"encoded_bytes_read": _bytes, "manifest_file_reads": _manifest_reads, "decode_calls": _decode_calls,
		"resolve_calls": _resolve_calls, "cached_modules": 0 if _cache.is_empty() else 1,
		"active_tokens": _tokens.size(), "active_catalog_capabilities": _catalog_capabilities.size(),
		"active_jobs": 0 if _job.is_empty() else 1, "publications": _publications,
		"cache_insertions": _cache_insertions, "cache_hits": _cache_hits,
		"largest_read_chunk": _largest_chunk, "open_files": 0 if _file == null else 1,
		"process_turns": _process_turns, "steps": _steps, "largest_steps_per_turn": _largest_steps_per_turn,
		"last_request": _last_request.duplicate(true)}


func _process(_delta: float) -> void:
	if _job.is_empty():
		set_process(false)
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
	if _job.is_empty():
		set_process(false)


func _advance_one() -> void:
	if _job.is_empty():
		return
	var selection: int = _job.selection
	var epoch: int = _job.epoch
	var phase: String = _job.phase
	# Checkpoints expose only scheduling, never data, paths, pins or capabilities.
	phase_entered.emit(selection, phase)
	if not _current(selection, epoch) or _job.phase != phase:
		return
	if phase == "pin":
		_load_pin()
	elif phase.ends_with("_open"):
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
			_job.phase = "manifest_open"
	elif phase == "manifest_validate":
		_validate_manifest()
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


func _queue_error(selection: int, message: String, code: String = "invalid_policy") -> void:
	_last_request["code"] = code
	_job = {"selection": selection, "epoch": _epoch, "phase": "error", "result": _failure(message, code)}
	# Even missing-pin, unsupported-host and retired-owner failures are deferred.
	set_process(true)


func _fail_job(message: String, code: String = "invalid_policy") -> void:
	var selection: int = _job.selection
	_remember_request(false, code)
	_close_read()
	_catalog_capabilities.clear()
	_queue_error(selection, message, code)


func _load_pin() -> void:
	# This candidate deliberately does not authorize an editable/native checkout.
	# A previously generated pin does not prove that current loose sources match.
	# A future native launcher must freshly prepare/verify sources before launch;
	# until that launch contract exists, native/editor Professional is unavailable.
	if not OS.has_feature("web") or OS.has_feature("editor"):
		_fail_job("Professional policy is unavailable for this local launch.", "policy_unavailable")
		return
	var script: Variant = load(PIN_PATH) if ResourceLoader.exists(PIN_PATH) else null
	if not script is GDScript:
		_fail_job("Professional lessons are unavailable in this application build.", "policy_unavailable")
		return
	var pin: Dictionary = script.get_script_constant_map()
	if not _keys(pin, ["SCHEMA_VERSION", "POLICY_VERSION", "CONTEXT_BOUNDARY", "DESCRIPTOR_PATH", "DESCRIPTOR_BYTES", "DESCRIPTOR_SHA256", "GENERATED_ROOT"]) \
		or pin.get("SCHEMA_VERSION") != 1 or pin.get("POLICY_VERSION") != POLICY or pin.get("CONTEXT_BOUNDARY") != BOUNDARY \
		or pin.get("DESCRIPTOR_PATH") != DESCRIPTOR_PATH or pin.get("GENERATED_ROOT") != RELEASE_ROOT \
		or not _integer(pin.get("DESCRIPTOR_BYTES")) or pin.DESCRIPTOR_BYTES < 1 or pin.DESCRIPTOR_BYTES > MAX_DESCRIPTOR \
		or not _digest(pin.get("DESCRIPTOR_SHA256")):
		_fail_job("The Professional application pin is unsupported.", "policy_unavailable")
		return
	_job.pin = pin.duplicate(true)
	_job.phase = "descriptor_open"


func _open_phase(kind: String) -> void:
	var resource_path: String = DESCRIPTOR_PATH
	var maximum: int = MAX_DESCRIPTOR
	if kind == "descriptor":
		_expected = {"path": DESCRIPTOR_PATH, "bytes": _job.pin.DESCRIPTOR_BYTES, "sha256": _job.pin.DESCRIPTOR_SHA256}
	elif kind in ["index", "themes"]:
		_expected = _job.descriptor[kind]
		resource_path = RELEASE_ROOT + _expected.path
		maximum = MAX_INDEX if kind == "index" else MAX_THEMES
	elif kind in ["payload", "manifest"]:
		_expected = _job.row.payload if kind == "payload" else _job.row.media_manifest
		resource_path = RELEASE_ROOT + _expected.path
		maximum = MAX_PAYLOAD if kind == "payload" else MAX_MANIFEST
	else:
		_fail_job("The Professional read phase is unsupported.")
		return
	if _job.opens + 1 > MAX_COLD_OPENS or _job.bytes + int(_expected.bytes) > MAX_COLD_BYTES:
		_fail_job("The Professional policy closure exceeds its read budget.")
		return
	_file = FileAccess.open(resource_path, FileAccess.READ)
	_reads += 1
	_job.opens += 1
	if kind == "manifest":
		_manifest_reads += 1
		_job.manifest_opens += 1
	if _file == null:
		_fail_job("A required Professional policy resource is unavailable.")
		return
	_length = _file.get_length()
	if _length < 1 or _length > maximum or _expected.bytes != _length:
		_fail_job("A Professional policy resource has changed size or exceeds its bound.")
		return
	_hash = HashingContext.new()
	if _hash.start(HashingContext.HASH_SHA256) != OK:
		_fail_job("Professional policy integrity checking is unavailable.")
		return
	_raw = PackedByteArray()
	_read_kind = kind
	_job.phase = kind + "_read"


func _read_chunk() -> void:
	var wanted: int = mini(READ_CHUNK, _length - _raw.size())
	var chunk: PackedByteArray = _file.get_buffer(wanted)
	_bytes += chunk.size()
	_job.bytes += chunk.size()
	_largest_chunk = maxi(_largest_chunk, chunk.size())
	if chunk.size() != wanted or _hash.update(chunk) != OK:
		_fail_job("A Professional policy resource is truncated or cannot be hashed.")
		return
	_raw.append_array(chunk)
	if _raw.size() == _length:
		if _file.get_length() != _length:
			_fail_job("A Professional policy resource changed during its read.")
			return
		_file.close()
		_file = null
		var digest: String = _hash.finish().hex_encode()
		_hash = null
		if digest != _expected.sha256:
			_fail_job("A Professional policy resource failed its integrity check.")
			return
		# The descriptor itself reaches decoding only after its app-pin hash matches.
		_job.phase = _read_kind + "_decode"


func _decode_phase() -> void:
	# Native decode, manifest validation and later resolver/copies are indivisible.
	# The scheduler budget is not a measured bound on their target-platform cost.
	_decode_calls += 1
	var text: String = _raw.get_string_from_utf8()
	if text.to_utf8_buffer() != _raw:
		_fail_job("A Professional policy resource contains invalid UTF-8.")
		return
	if _read_kind == "manifest":
		var media: Dictionary = MediaManifest.parse_manifest(_raw, _expected.sha256, _job.context)
		_raw = PackedByteArray()
		if not media.get("ok", false):
			_fail_job(str(media.get("error", "The Professional media manifest is invalid.")), str(media.get("code", "invalid_manifest")))
			return
		_job.media = media
		_job.phase = "manifest_validate"
		return
	var parser := JSON.new()
	var parsed: Error = parser.parse(text)
	_raw = PackedByteArray()
	if parsed != OK or not parser.data is Dictionary:
		_fail_job("A Professional policy resource is not a valid JSON object.")
		return
	_job.decoded = parser.data
	_job.phase = _read_kind + "_validate"


func _validate_descriptor() -> void:
	var descriptor: Dictionary = _job.decoded
	if not _keys(descriptor, ["schema_version", "kind", "policy_version", "context_boundary", "trust_status",
		"source_inventory_sha256", "supporting_inventory_sha256", "contracts_sha256", "index", "themes", "artifacts"]) \
		or not _header(descriptor, "professional_domain_application_release_v1") or not _binding_valid(descriptor):
		_fail_job("The Professional release descriptor is unsupported.")
		return
	if not _artifact(descriptor.index, "index.json", MAX_INDEX) or not _artifact(descriptor.themes, "themes.json", MAX_THEMES) \
		or not descriptor.artifacts is Array or descriptor.artifacts.size() < 2 or descriptor.artifacts.size() > MAX_ARTIFACTS:
		_fail_job("The Professional release descriptor has an invalid artifact inventory.")
		return
	var inventory: Dictionary = {}
	var previous_path: String = ""
	for item: Variant in descriptor.artifacts:
		if not item is Dictionary or not item.get("path") is String or not _artifact_kind(item) \
			or item.path <= previous_path or inventory.has(item.path):
			_fail_job("The Professional release artifact inventory is invalid or duplicated.")
			return
		inventory[item.path] = item
		previous_path = item.path
	if inventory.get("index.json") != descriptor.index or inventory.get("themes.json") != descriptor.themes:
		_fail_job("The Professional metadata descriptors do not match their release inventory.")
		return
	_job.descriptor = descriptor
	_job.artifacts = inventory
	_job.erase("decoded")
	_job.phase = "index_open"


func _validate_index(index: Dictionary) -> String:
	if not _keys(index, ["schema_version", "kind", "policy_version", "context_boundary", "trust_status",
		"source_inventory_sha256", "supporting_inventory_sha256", "contracts_sha256", "modules"]) \
		or not _header(index, "compiled_professional_release_v1") or not _binding_valid(index):
		return "The Professional release index is unsupported."
	for field: String in BINDING_KEYS:
		if index[field] != _job.descriptor[field]:
			return "The Professional index belongs to another audited source release."
	if not index.modules is Array or index.modules.size() != 200:
		return "The Professional index must contain all 200 modules."
	var seen: Dictionary = {}
	var courses: Dictionary = {}
	var referenced: Dictionary = {"index.json": true, "themes.json": true}
	var previous_key: String = ""
	for row: Variant in index.modules:
		if not row is Dictionary or not _identifier(row.get("course_id")) or not _module_id(row.get("module_id")):
			return "The Professional index has an invalid module identity."
		var key: String = row.course_id + "/" + row.module_id
		if seen.has(key) or key <= previous_key:
			return "The Professional index has duplicate or unordered module identities."
		seen[key] = true
		previous_key = key
		courses[row.course_id] = int(courses.get(row.course_id, 0)) + 1
		if row.get("state") == "unavailable":
			if not _keys(row, ["course_id", "module_id", "state", "source_status"]) or row.get("source_status") not in ["draft", "planned"]:
				return "An unavailable Professional module cannot authorize generated content."
		elif row.get("state") == "ready":
			if not _keys(row, ["course_id", "module_id", "state", "source_status", "payload", "media_manifest"]) \
				or row.get("source_status") != "ready" or not _hashed_artifact(row.get("payload"), "modules/", MAX_PAYLOAD) \
				or not _generated_manifest(row.get("media_manifest")):
				return "A ready Professional module has an invalid generated descriptor."
			for member: Dictionary in [row.payload, row.media_manifest]:
				if _job.artifacts.get(member.path) != _artifact_fields(member):
					return "A selected Professional artifact is absent from its exact release inventory."
				referenced[member.path] = true
			var closure_bytes: int = int(_job.pin.DESCRIPTOR_BYTES) + int(_job.descriptor.index.bytes) \
				+ int(_job.descriptor.themes.bytes) + int(row.payload.bytes) + int(row.media_manifest.bytes)
			if closure_bytes > MAX_COLD_BYTES or 5 > MAX_COLD_OPENS:
				return "A Professional module exceeds the complete policy closure budget."
		else:
			return "The Professional index has an unsupported availability state."
	if courses.size() != 20:
		return "The Professional index must account for all 20 courses."
	for count: int in courses.values():
		if count != 10:
			return "Each Professional course must account for its 10 modules."
	if referenced.size() != _job.artifacts.size():
		return "The Professional release contains an unreferenced generated artifact."
	return ""


func _validate_themes() -> void:
	var themes: Dictionary = _job.decoded
	if not _keys(themes, ["schema_version", "profiles"]) or themes.get("schema_version") != 1 or not themes.get("profiles") is Array:
		_fail_job("The Professional theme snapshot is invalid.")
		return
	var profiles: Dictionary = {}
	for profile: Variant in themes.profiles:
		if not profile is Dictionary or not _identifier(profile.get("id")) or profiles.has(profile.id):
			_fail_job("The Professional theme snapshot has invalid or duplicate identities.")
			return
		profiles[profile.id] = profile
	var rows: Dictionary = {}
	for row: Dictionary in _job.index.modules:
		rows[row.course_id + "/" + row.module_id] = row
	# Publish all metadata atomically after the same app-pinned chain validates.
	_freeze_value(rows)
	_freeze_value(profiles)
	_freeze_value(_job.pin)
	_freeze_value(_job.descriptor)
	_rows = rows
	_themes = profiles
	_pin = _job.pin
	_descriptor = _job.descriptor
	_release_sha256 = _pin.DESCRIPTOR_SHA256
	_installed = true
	for key: String in ["decoded", "index", "descriptor", "artifacts", "pin"]:
		_job.erase(key)
	_job.phase = "select"


func _select_payload() -> void:
	var row: Variant = _rows.get(_job.key)
	if not row is Dictionary or row.get("state") != "ready":
		_fail_job("This Professional module is still being prepared.", "content_pending")
		return
	_job.row = row
	if _cache_key == _job.key and not _cache.is_empty() and _cache.release_sha256 == _release_sha256:
		_job.snapshot = _cache.snapshot
		_job.media = _cache.media
		_job.warm = true
		_cache_hits += 1
		_job.phase = "resolve"
	else:
		_job.phase = "payload_open"


func _validate_payload(payload: Dictionary, course_id: String, module_id: String) -> String:
	if not _keys(payload, ["schema_version", "kind", "policy_version", "context_boundary", "course_id", "module_id",
		"course", "lexemes", "expressions", "lexical_domain", "expression_domain"]) \
		or payload.get("schema_version") != 1 or payload.get("kind") != "compiled_professional_module_v1" \
		or payload.get("policy_version") != POLICY or payload.get("context_boundary") != BOUNDARY \
		or payload.get("course_id") != course_id or payload.get("module_id") != module_id:
		return "The compiled Professional payload identity is unsupported."
	var course: Variant = payload.get("course")
	if not course is Dictionary or course.get("id") != course_id or not course.get("modules") is Array \
		or course.modules.size() != 10 or course.get("curriculum_revision") != _job.context.curriculum_revision:
		return "The compiled Professional course or curriculum revision differs."
	var selected: Dictionary = {}
	var module_ids: Dictionary = {}
	for module: Variant in course.modules:
		if not module is Dictionary or not _module_id(module.get("id")) or module_ids.has(module.id):
			return "The compiled Professional course has duplicate or invalid modules."
		module_ids[module.id] = true
		if module.id == module_id:
			selected = module
	if selected.get("status") != "ready":
		return "The compiled Professional module is not ready."
	var source_manifest: Variant = selected.get("media_manifest")
	var generated_manifest: Dictionary = _job.row.media_manifest
	if not source_manifest is Dictionary or not _keys(source_manifest, ["path", "sha256"]) \
		or source_manifest.get("path") != generated_manifest.source_path or source_manifest.get("sha256") != generated_manifest.sha256:
		return "The selected media manifest does not match the audited course descriptor."
	for spec: Array in [["lexemes", "lexeme_ids", "lexical_domain", 50], ["expressions", "expression_ids", "expression_domain", 10]]:
		var records: Variant = payload.get(spec[0])
		var ids: Variant = selected.get(spec[1])
		var domain: Variant = payload.get(spec[2])
		if not records is Array or not ids is Array or not domain is Array \
			or records.size() != spec[3] or ids.size() != spec[3] or domain.size() != spec[3]:
			return "The compiled Professional selected membership count differs."
		var registry: Dictionary = {}
		for offset: int in range(ids.size()):
			var record: Variant = records[offset]
			if not ids[offset] is String or registry.has(ids[offset]) or not record is Dictionary or record.get("id") != ids[offset]:
				return "The compiled Professional selected membership identity differs."
			registry[ids[offset]] = record
		var rows: Dictionary = {}
		var previous_id: String = ""
		for row: Variant in domain:
			if not row is Dictionary or not _keys(row, ["id", "coarse_required", "exception"]) \
				or not row.get("id") is String or rows.has(row.id) or row.id <= previous_id \
				or not registry.has(row.id) or not row.get("coarse_required") is bool or row.exception != null:
				return "The compiled Professional domain row is invalid or grants an exception."
			rows[row.id] = true
			previous_id = row.id
			var review: Variant = registry[row.id].get("review")
			if not review is Dictionary or review.get("status") != "reviewed" or review.get("language") != "reviewed" \
				or review.get("domain") not in ["reviewed", "not_required"] \
				or row.coarse_required and review.domain != "reviewed":
				return "The compiled Professional records require their original domain reviews."
	return ""


func _validate_manifest() -> void:
	var media: Dictionary = _job.media
	for field: String in ["course_id", "module_id", "curriculum_revision"]:
		if media.manifest.get(field) != _job.context[field]:
			_fail_job("The generated media manifest belongs to another Professional module revision.")
			return
	# These exact bytes already passed the generated descriptor hash before parse.
	_freeze_value(_job.snapshot)
	_freeze_value(media)
	_job.phase = "resolve"


func _resolve_phase(selection: int, epoch: int) -> void:
	var snapshot: Dictionary = _job.snapshot
	if snapshot.course_id != _job.context.course_id or snapshot.module_id != _job.context.module_id \
		or snapshot.course.get("curriculum_revision") != _job.context.curriculum_revision:
		_fail_job("The cached Professional content belongs to another curriculum revision.")
		return
	var profile: Variant = _themes.get(snapshot.course.get("theme_id"))
	if not profile is Dictionary:
		_fail_job("The Professional workplace theme is unavailable.", "theme_pending")
		return
	var capability: RefCounted = CatalogCapability.new()
	_catalog_capabilities[capability] = {"selection": selection, "epoch": epoch, "release_sha256": _release_sha256}
	var adapter: RefCounted = Adapter.new(self, capability)
	_catalog_capabilities.erase(capability)
	_resolve_calls += 1
	var result: Dictionary = adapter.resolve(_job.context, _job.seed)
	if not _current(selection, epoch):
		return
	if not result.get("ok", false):
		_remember_request(false, str(result.get("code", "content_unavailable")))
		_job.result = result.duplicate(true)
		_job.phase = "error"
		return
	_freeze_value(result)
	_job.content = result
	_job.phase = "publish"


func _take_catalog_snapshot(capability: Variant) -> Dictionary:
	if not capability is RefCounted or not _catalog_capabilities.has(capability):
		return {}
	var state: Dictionary = _catalog_capabilities[capability]
	_catalog_capabilities.erase(capability)
	if not _installed or not _configured or _closed or state.release_sha256 != _release_sha256 \
		or not _current(state.selection, state.epoch) or _job.phase != "resolve":
		return {}
	return {"snapshot": _job.snapshot, "profile": _themes[_job.snapshot.course.theme_id],
		"media": _job.media, "generated_manifest": _job.row.media_manifest, "context": _job.context}


func _publish(selection: int, epoch: int) -> void:
	if not _current(selection, epoch):
		return
	# The selected payload and generated manifest enter the single-module cache
	# only after every original resolver, media, theme and motion gate succeeds.
	if _cache_key != _job.key or _cache.is_empty():
		_cache = {"snapshot": _job.snapshot, "media": _job.media, "release_sha256": _release_sha256}
		_freeze_value(_cache)
		_cache_key = _job.key
		_cache_insertions += 1
	var token: RefCounted = RequestToken.new()
	_tokens[token] = {"epoch": epoch, "selection": selection, "release_sha256": _release_sha256, "content": _job.content}
	_remember_request(true)
	_close_read()
	_job.clear()
	_publications += 1
	completed.emit(selection, {"ok": true, "token": token})


func _remember_request(ok: bool, code: String = "") -> void:
	_last_request = {"request_id": _job.get("selection", _selection), "ok": ok, "code": code,
		"policy_file_reads": _job.get("opens", 0), "encoded_bytes_read": _job.get("bytes", 0),
		"manifest_file_reads": _job.get("manifest_opens", 0), "warm_cache_hit": _job.get("warm", false)}


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


func _header(value: Dictionary, kind: String) -> bool:
	return value.get("schema_version") == 1 and value.get("kind") == kind and value.get("policy_version") == POLICY \
		and value.get("context_boundary") == BOUNDARY and value.get("trust_status") == TRUST


func _binding_valid(value: Dictionary) -> bool:
	for field: String in BINDING_KEYS:
		if not _digest(value.get(field)):
			return false
	return true


func _keys(value: Dictionary, names: Array) -> bool:
	if value.size() != names.size():
		return false
	for field: String in names:
		if not value.has(field):
			return false
	return true


func _artifact(value: Variant, expected_path: String, maximum: int) -> bool:
	return value is Dictionary and _keys(value, ["path", "bytes", "sha256"]) and value.get("path") == expected_path \
		and _digest(value.get("sha256")) and _integer(value.get("bytes")) and value.bytes >= 1 and value.bytes <= maximum


func _hashed_artifact(value: Variant, prefix: String, maximum: int) -> bool:
	return value is Dictionary and _digest(value.get("sha256")) \
		and _artifact(value, prefix + str(value.sha256) + ".json", maximum)


func _artifact_kind(value: Dictionary) -> bool:
	return _artifact(value, "index.json", MAX_INDEX) or _artifact(value, "themes.json", MAX_THEMES) \
		or _hashed_artifact(value, "modules/", MAX_PAYLOAD) or _hashed_artifact(value, "media-manifests/", MAX_MANIFEST)


func _generated_manifest(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["path", "bytes", "sha256", "source_path"]) \
		or not _source_manifest_path(value.get("source_path")):
		return false
	return _hashed_artifact(_artifact_fields(value), "media-manifests/", MAX_MANIFEST)


func _artifact_fields(value: Dictionary) -> Dictionary:
	return {"path": value.get("path"), "bytes": value.get("bytes"), "sha256": value.get("sha256")}


func _source_manifest_path(value: Variant) -> bool:
	if not value is String or not value.begins_with("res://data/professional/media-manifests/") or not value.ends_with(".json"):
		return false
	var name: String = value.trim_prefix("res://data/professional/media-manifests/").trim_suffix(".json")
	if name.is_empty() or name.contains(".."):
		return false
	for character: String in name:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-":
			return false
	return true


func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128:
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-":
			return false
	return not value.contains("..")


func _module_id(value: Variant) -> bool:
	return value is String and value in ["module01", "module02", "module03", "module04", "module05", "module06", "module07", "module08", "module09", "module10"]


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 9007199254740991.0 \
		and float(value) == floor(float(value))


func _digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _freeze_value(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_freeze_value(value[key])
		value.make_read_only()
	elif value is Array:
		for member: Variant in value:
			_freeze_value(member)
		value.make_read_only()


func _failure(message: String, code: String = "invalid_policy") -> Dictionary:
	return {"ok": false, "error": message, "code": code, "words": [], "expressions": []}
