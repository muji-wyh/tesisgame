extends RefCounted
## Reuse native JSON field encodings between base deduplication and host overlays.


static func encode_base(base: Dictionary) -> Dictionary:
	if not _has_string_like_keys(base):
		return {"serialized": JSON.stringify(base), "fragments": {}, "fragmented": false}
	var fragments: Dictionary = {}
	# Native dictionaries treat String and StringName with the same text as one key.
	for key: Variant in base:
		var canonical_key: String = String(key)
		fragments[canonical_key] = _member(canonical_key, base[key])
	return {"serialized": _join(fragments), "fragments": fragments, "fragmented": true}


static func encode_host(base: Dictionary, encoded: Dictionary, overrides: Dictionary) -> String:
	if not bool(encoded.fragmented) or not _has_string_like_keys(overrides):
		var value: Dictionary = base.duplicate()
		value.merge(overrides, true)
		return JSON.stringify(value)
	var fragments: Dictionary = encoded.fragments.duplicate()
	for key: Variant in overrides:
		var canonical_key: String = String(key)
		fragments[canonical_key] = _member(canonical_key, overrides[key])
	return _join(fragments)


static func _has_string_like_keys(value: Dictionary) -> bool:
	for key: Variant in value:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			return false
	return true


static func _member(key: String, value: Variant) -> String:
	return JSON.stringify(key) + ":" + JSON.stringify(value)


static func _join(fragments: Dictionary) -> String:
	var keys: Array = fragments.keys()
	keys.sort()
	var members := PackedStringArray()
	for key: String in keys:
		members.append(fragments[key])
	return "{" + ",".join(members) + "}"
