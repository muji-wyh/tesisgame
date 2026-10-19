extends RefCounted

const GENERATED_ROOT := "res://data/professional/domain-policy/generated/"
const DESCRIPTOR_PATH := GENERATED_ROOT + "release.json"
const PIN_PATH := "res://scripts/professional_domain_release.gd"


static func verify(manifest: Variant) -> Dictionary:
	if not manifest is Dictionary or manifest.get("schema_version") != 1 \
		or manifest.get("kind") != "professional_domain_pack_verification_v1" \
		or not manifest.get("generated_inventory") is Array or not manifest.get("pin_constants") is Dictionary:
		return _failure("The Professional domain pack manifest is invalid.")
	var expected: Array = manifest.generated_inventory
	if expected.size() < 3:
		return _failure("The Professional domain pack inventory is incomplete.")
	var actual_paths: Array[String] = []
	if not _inventory(GENERATED_ROOT, actual_paths):
		return _failure("The Professional domain generated directory cannot be read.")
	actual_paths.sort()
	var expected_paths: Array[String] = []
	var observed: Array = []
	for item: Variant in expected:
		if not item is Dictionary or not item.get("path") is String or not item.get("sha256") is String \
			or not (item.get("bytes") is int or item.get("bytes") is float) \
			or item.bytes <= 0 or item.bytes != floor(item.bytes) or item.sha256.length() != 64:
			return _failure("The Professional domain pack contains an invalid expected file.")
		var relative: String = item.path.trim_prefix(GENERATED_ROOT)
		if not item.path.begins_with(GENERATED_ROOT) or relative.is_empty() or relative.contains("..") \
			or relative.contains("\\") or relative.contains(":") or not relative.ends_with(".json") \
			or expected_paths.has(item.path):
			return _failure("The Professional domain pack path is invalid or duplicated.")
		expected_paths.append(item.path)
		var file := FileAccess.open(item.path, FileAccess.READ)
		if file == null or file.get_length() != int(item.bytes):
			return _failure("A Professional domain file is absent or has the wrong length: " + item.path)
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var sha := HashingContext.new()
		sha.start(HashingContext.HASH_SHA256)
		sha.update(bytes)
		var hash_value: String = sha.finish().hex_encode()
		if hash_value != item.sha256:
			return _failure("A Professional domain file has the wrong hash: " + item.path)
		observed.append({"path": item.path, "bytes": bytes.size(), "sha256": hash_value})
	if expected_paths != actual_paths or not expected_paths.has(DESCRIPTOR_PATH):
		return _failure("The exported Professional domain inventory is not exact.")
	# GDScript is compiled/remapped by Web export. Verify its loaded constants;
	# its editable source bytes are separately bound by the build input receipt.
	var pin: Variant = load(PIN_PATH) if ResourceLoader.exists(PIN_PATH) else null
	if not pin is GDScript:
		return _failure("The embedded Professional domain pin cannot be loaded.")
	var constants: Dictionary = pin.get_script_constant_map()
	var expected_constants: Dictionary = manifest.pin_constants
	var fixed_constants := {"SCHEMA_VERSION": 1, "POLICY_VERSION": "ordinary-lexical-v3",
		"CONTEXT_BOUNDARY": "containing-modules-v1", "DESCRIPTOR_PATH": DESCRIPTOR_PATH,
		"GENERATED_ROOT": GENERATED_ROOT}
	if expected_constants.size() != 7:
		return _failure("The expected embedded pin has an unsupported shape.")
	for key: String in fixed_constants:
		if expected_constants.get(key) != fixed_constants[key]:
			return _failure("The expected embedded pin violates the application contract.")
	var observed_constants: Dictionary = {}
	for key: String in expected_constants:
		if constants.get(key) != expected_constants[key]:
			return _failure("The exported embedded pin is mismatched: " + key)
		observed_constants[key] = constants[key]
	var descriptor: Dictionary = {}
	for item: Dictionary in observed:
		if item.path == DESCRIPTOR_PATH:
			descriptor = item
	if descriptor.get("bytes") != constants.get("DESCRIPTOR_BYTES") \
		or descriptor.get("sha256") != constants.get("DESCRIPTOR_SHA256"):
		return _failure("The exported descriptor does not match the embedded pin.")
	return {"schema_version": 1, "kind": "professional_domain_pack_proof_v1", "ok": true,
		"generated_inventory": observed, "pin_constants": observed_constants}


static func _inventory(directory: String, paths: Array[String]) -> bool:
	var access := DirAccess.open(directory)
	if access == null:
		return false
	access.include_hidden = true
	access.include_navigational = false
	if access.list_dir_begin() != OK:
		return false
	var name := access.get_next()
	while not name.is_empty():
		var current := directory.path_join(name)
		if access.current_is_dir():
			if not _inventory(current, paths):
				return false
		else:
			paths.append(current)
		name = access.get_next()
	access.list_dir_end()
	return true


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
