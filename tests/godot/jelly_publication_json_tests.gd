extends SceneTree
## Host JSON reuse must preserve native bytes, base deduplication and observers.

const PublicationJSON = preload("res://scripts/jelly_publication_json.gd")
const WordJellyModel = preload("res://scripts/word_jelly_model.gd")

class StubJelly extends "res://scripts/jelly_match.gd":
	var publication_state: Dictionary = {
		"visible": true, "mode": "jelly", "clock": 0,
		"finish": {"visible": true, "rect": [1, 2, 3, 4]},
	}

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _layout() -> void:
		pass

	func _visibility_changed() -> void:
		pass

	func snapshot() -> Dictionary:
		publication_state.stage = {"id": "stage-4", "level": 2}
		publication_state.property_added = true
		return publication_state

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _native_host(base: Dictionary, overrides: Dictionary) -> String:
	var value: Dictionary = base.duplicate()
	value.merge(overrides, true)
	return JSON.stringify(value)


func _key_signature(value: Dictionary) -> Array:
	var signature: Array = []
	for key: Variant in value:
		signature.append([str(key), typeof(key)])
	return signature


func _check_encoding(base: Dictionary, overrides: Dictionary, label: String, fragmented: bool = true) -> void:
	var base_before: String = JSON.stringify(base)
	var overrides_before: String = JSON.stringify(overrides)
	var base_keys_before: Array = _key_signature(base)
	var overrides_keys_before: Array = _key_signature(overrides)
	var encoded: Dictionary = PublicationJSON.encode_base(base)
	var cached_before: String = JSON.stringify(encoded)
	check(encoded.serialized == base_before, label + ": base bytes match native canonical JSON")
	check(bool(encoded.fragmented) == fragmented, label + ": String and StringName keys use field fragments")
	check(PublicationJSON.encode_host(base, encoded, overrides) == _native_host(base, overrides),
		label + ": the host envelope exactly matches native shallow overrides")
	check(PublicationJSON.encode_host(base, encoded, {}) == base_before,
		label + ": the same fragments can also publish the unchanged base")
	check(JSON.stringify(base) == base_before and JSON.stringify(overrides) == overrides_before,
		label + ": encoding leaves both caller dictionaries unchanged")
	check(_key_signature(base) == base_keys_before and _key_signature(overrides) == overrides_keys_before,
		label + ": original key types and insertion order remain unchanged")
	check(JSON.stringify(encoded) == cached_before,
		label + ": host overrides never modify cached fragments")
	if fragmented:
		check(encoded.fragments.size() == base.size()
			and encoded.fragments.keys().all(func(key: Variant) -> bool: return typeof(key) == TYPE_STRING),
			label + ": supported keys produce one canonical fragment for every base member")


func _check_native_values() -> void:
	_check_encoding({}, {}, "Empty base and host")
	_check_encoding({}, {"visible": false, "mode": "word_jelly"}, "Host-only fields")
	_check_encoding({"visible": true, "mode": "jelly", "z": 1, "a": 2},
		{"visible": false, "mode": "word_jelly", "round_id": "round-17"}, "Colliding host fields")
	_check_encoding({
		"quotes\"and}braces": "A \"quoted\" word {with braces}",
		"backslash": "C:\\jelly\\word.png", "newlines": "first\nsecond\tthird",
		"café": "café 🪼", "empty": "", "nested": {"z": [true, null, 3.5], "a": {}},
	}, {"quotes\"and}braces": "next\n\"level\"", "café": "🪼 café"}, "Escaping and Unicode")
	var integers: Array[int] = [3, 1, 2]
	var words: Array[String] = ["mint", "coral"]
	_check_encoding({
		"nested": {"integers": integers, "words": words, "packed": PackedFloat32Array([1.25, -3.5]),
			"vector": Vector2(1.5, -2.0), "bounds": Rect2(1, 2, 3, 4)},
		"nonfinite": [NAN, INF, -INF], "finish": {"visible": true, "rect": [1, 2, 3, 4]},
	}, {"finish": {"visible": false}, "vector": Vector3(1, 2, 3)}, "Native nested and Variant values")
	_check_encoding({7: "integer key", "mode": "jelly"},
		{"mode": "word_jelly", "visible": false}, "Non-String base fallback", false)
	_check_encoding({StringName("mode"): "jelly", "visible": true},
		{"visible": false}, "StringName base fragments")
	_check_encoding({StringName("visible"): true, "mode": "jelly", StringName("z"): 6,
		"a": 1, StringName("A"): 0, "b": 3, StringName("aa"): 2},
		{"visible": false, StringName("mode"): "word_jelly", StringName("B"): 4, "round_id": "round-17"},
		"Mixed named and literal keys with bidirectional host collisions")
	var property_base: Dictionary = {"visible": true, "mode": "jelly", "z": 9}
	property_base.stage = {"id": "stage-4"}
	property_base.a = 1
	property_base.visible = false
	var property_overrides: Dictionary = {"visible": true}
	property_overrides.mode = "word_jelly"
	property_overrides.stage = {"id": "stage-5"}
	property_overrides.round_id = "round-18"
	check(_key_signature(property_base).any(func(entry: Array) -> bool: return int(entry[1]) == TYPE_STRING_NAME)
		and _key_signature(property_overrides).any(func(entry: Array) -> bool: return int(entry[1]) == TYPE_STRING_NAME),
		"Dictionary property assignment adds actual StringName keys in both inputs")
	_check_encoding(property_base, property_overrides, "Dictionary property insertion and replacement")
	var model := WordJellyModel.new()
	var model_state: Dictionary = model.snapshot()
	check(_key_signature(model_state).any(func(entry: Array) -> bool:
		return entry[0] == "authored_morphology" and int(entry[1]) == TYPE_STRING_NAME),
		"A real Word Jelly model snapshot contains its property-added StringName key")
	_check_encoding(model_state, {"visible": false, "mode": "word_jelly"}, "Actual Word Jelly model snapshot")
	_check_encoding({"mode": "jelly", "visible": true},
		{7: "integer override", "visible": false}, "Non-String override fallback")
	_check_encoding({NodePath("node/path"): "unsupported key", "mode": "jelly"},
		{"visible": false}, "NodePath base fallback", false)


func _observe(view: StubJelly) -> Dictionary:
	var events: Dictionary = {"native": [], "serialized": [], "order": []}
	view.serialized_changed.connect(func(serialized: String) -> void:
		events.serialized.append(serialized)
		events.order.append("serialized"))
	view.changed.connect(func(state: Dictionary) -> void:
		events.native.append(state)
		events.order.append("native"))
	return events


func _check_default_publication() -> void:
	var view := StubJelly.new()
	var events: Dictionary = _observe(view)
	check(not view.publication_overrides.is_valid(), "Standalone views have no host override callback")
	view._publish()
	check(events.native.size() == 1 and events.serialized.size() == 1,
		"A standalone base change retains one native publication")
	check(events.serialized[0] == JSON.stringify(view.publication_state)
		and view._last_published == events.serialized[0],
		"The default path retains the exact native JSON baseline")
	check(is_same(events.native[0], view.publication_state),
		"Native observers receive the original snapshot dictionary")
	view._publish_elapsed = 0.5
	view._publish()
	check(events.native.size() == 1 and events.serialized.size() == 1 and is_zero_approx(view._publish_elapsed),
		"Duplicate base state resets the timer without emitting either signal")
	view.publication_state.clock = 1
	view._publish()
	check(events.native.size() == 2 and events.serialized.size() == 2,
		"A changed standalone field emits again at the original cadence")
	check(events.order == ["serialized", "native", "serialized", "native"],
		"Encoded observers run before native state observers")
	view.free()


func _check_hosted_publication() -> void:
	var view := StubJelly.new()
	var events: Dictionary = _observe(view)
	var host: Dictionary = {"calls": 0, "round_id": "round-17"}
	view.publication_overrides = func(_state: Dictionary) -> Dictionary:
		host.calls += 1
		return {"visible": true, "mode": "word_jelly", "round_id": host.round_id,
			"finish": {"visible": false}}
	var overrides: Dictionary = {"visible": true, "mode": "word_jelly", "round_id": host.round_id,
		"finish": {"visible": false}}
	var base_before: String = JSON.stringify(view.snapshot())
	var base_keys_before: Array = _key_signature(view.publication_state)
	view._publish()
	var encoded: Dictionary = PublicationJSON.encode_base(view.publication_state)
	check(bool(encoded.fragmented) and encoded.fragments.size() == view.publication_state.size()
		and base_keys_before.any(func(entry: Array) -> bool: return int(entry[1]) == TYPE_STRING_NAME),
		"A live hosted snapshot with property-added keys uses complete field fragments")
	check(events.serialized[0] == _native_host(view.publication_state, overrides)
		and view._last_published == base_before,
		"Hosted bytes use overrides while deduplication retains only native base JSON")
	check(JSON.stringify(view.publication_state) == base_before
		and bool(view.publication_state.finish.visible) and _key_signature(view.publication_state) == base_keys_before,
		"Host collisions leave the native visibility, mode and finish payload untouched")
	view.publication_state.visible = false
	view._publish()
	check(events.native.size() == 2 and events.serialized[0] == events.serialized[1],
		"A base visibility change still emits when its host field masks the change")
	view.publication_state.mode = "base-mode-change"
	view._publish()
	check(events.native.size() == 3 and events.serialized[1] == events.serialized[2] and host.calls == 3,
		"A masked base mode change also preserves the native publication count")
	host.round_id = "round-99"
	view._publish()
	check(events.native.size() == 3 and events.serialized.size() == 3 and host.calls == 3,
		"Host-only changes neither alter base deduplication nor build a duplicate overlay")
	view.publication_state.clock = 1
	view._publish()
	overrides.round_id = host.round_id
	check(events.native.size() == 4 and host.calls == 4
		and events.serialized.back() == _native_host(view.publication_state, overrides),
		"The next real base change reads fresh host overrides")
	check(view._last_published == JSON.stringify(view.publication_state)
		and is_same(events.native.back(), view.publication_state),
		"Hosted native observers retain the original base and its exact equality baseline")
	view.publication_state[7] = "fallback field"
	view._publish()
	check(events.native.size() == 5 and events.serialized.back() == _native_host(view.publication_state, overrides),
		"A non-String base key retains the same hosted signal behavior through native fallback")
	check(events.order == ["serialized", "native", "serialized", "native", "serialized", "native",
		"serialized", "native", "serialized", "native"],
		"Every hosted emission reaches encoded observers before native observers")
	root.add_child(view)
	root.remove_child(view)
	check(not view.publication_overrides.is_valid(), "Tree exit releases the host override callback")
	view.free()


func _run() -> void:
	_check_native_values()
	_check_default_publication()
	_check_hosted_publication()
	print("Jelly publication JSON: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
