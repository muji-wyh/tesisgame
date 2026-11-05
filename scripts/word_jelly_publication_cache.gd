extends RefCounted
## Reuse unchanged native JSON paint while each body's age continues normally.

const Publication = preload("res://scripts/jelly_publication_json.gd")
const WordModel = preload("res://scripts/word_jelly_model.gd")
var _fields: Dictionary = {}
var _overrides: Dictionary = {}
var _records: Dictionary = {}

func reset() -> void:
	_fields.clear()
	_overrides.clear()
	_records.clear()

func encode_base(state: Dictionary) -> Dictionary:
	if not Publication._has_string_like_keys(state):
		return Publication.encode_base(state)
	var fragments: Dictionary = {}
	for key: Variant in state:
		var name: String = String(key)
		var encoded: String
		if name in ["cells", "tiles"] and state[key] is Array:
			encoded = _encode_records(name, state[key])
		else:
			encoded = _encode_value(_fields, name, state[key])
		fragments[name] = JSON.stringify(name) + ":" + encoded
	return {"serialized": Publication._join(fragments), "fragments": fragments, "fragmented": true}

func encode_host(state: Dictionary, encoded: Dictionary, overrides: Dictionary) -> String:
	if not bool(encoded.fragmented) or not Publication._has_string_like_keys(overrides):
		return Publication.encode_host(state, encoded, overrides)
	var fragments: Dictionary = encoded.fragments.duplicate()
	for key: Variant in overrides:
		var name: String = String(key)
		fragments[name] = JSON.stringify(name) + ":" + _encode_value(_overrides, name, overrides[key])
	return Publication._join(fragments)

func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

func _encode_value(cache: Dictionary, name: String, value: Variant) -> String:
	if cache.has(name) and typeof(cache[name].value) == typeof(value) and cache[name].value == value:
		return cache[name].encoded
	var encoded: String = JSON.stringify(value)
	cache[name] = {"value": _copy(value), "encoded": encoded}
	return encoded

func _encode_records(name: String, records: Array) -> String:
	# Moving dense stacks invalidate most cached bodies. Native array encoding
	# avoids splitting and deep-copying every record during that interval.
	if _prefer_native_records(records):
		_records.erase(name)
		return JSON.stringify(records)
	var previous: Dictionary = _records.get(name, {})
	var current: Dictionary = {}
	var members := PackedStringArray()
	for index in range(records.size()):
		var record: Variant = records[index]
		if not record is Dictionary or not record.has("age") or not record.has("id"):
			members.append(JSON.stringify(record))
			continue
		var id: Variant = record.id
		var body: Dictionary = record.duplicate()
		body.erase("age")
		var entry: Dictionary = previous.get(id, {})
		if entry.is_empty() or entry.body != body:
			# Cache entries contain only validated string-like keys. An unchanged
			# body retains that schema, so its native equality check also avoids
			# another per-field GDScript scan. Unsupported records stay uncached.
			if not Publication._has_string_like_keys(record):
				members.append(JSON.stringify(record))
				continue
			var left: Dictionary = {}
			var right: Dictionary = {}
			for key: Variant in body:
				if String(key) < "age":
					left[key] = body[key]
				else:
					right[key] = body[key]
			entry = {"body": body.duplicate(true),
				"prefix": JSON.stringify(left).trim_suffix("}") + ("" if left.is_empty() else ",") + '"age":',
				"suffix": ("" if right.is_empty() else ",") + JSON.stringify(right).trim_prefix("{"),
				"age_json": "", "encoded": ""}
		var age_json: String = JSON.stringify(record.age)
		if age_json != entry.age_json or entry.encoded.is_empty():
			entry.age_json = age_json
			entry.encoded = String(entry.prefix) + age_json + String(entry.suffix)
		members.append(entry.encoded)
		current[id] = entry
	_records[name] = current
	return "[" + ",".join(members) + "]"

func _prefer_native_records(records: Array) -> bool:
	if records.size() < 8:
		return false
	var moving: int = 0
	for sample in range(8):
		var record: Variant = records[int(sample * (records.size() - 1) / 7)]
		if record is Dictionary and _record_is_moving(record):
			moving += 1
	return moving > 4


func _record_is_moving(record: Dictionary) -> bool:
	# Falling records retain their motion history after landing. Prefer current
	# settlement without changing the model or the published historical fields.
	if record.has("settled"):
		return not bool(record.settled)
	if record.has("age") and record.has("arrival") \
		and (not bool(record.arrival) or record.has("row") and record.has("height")):
		return float(record.age) + WordModel.EPSILON < WordModel.settle_duration(record)
	if record.has("settling"):
		return bool(record.settling)
	return bool(record.get("falling", false))
