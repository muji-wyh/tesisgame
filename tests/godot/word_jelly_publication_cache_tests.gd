extends SceneTree

const Cache = preload("res://scripts/word_jelly_publication_cache.gd")
const Reference = preload("res://scripts/jelly_publication_json.gd")

func _initialize() -> void:
	_run.call_deferred()


func _check_native_pair(cache: Cache, state: Dictionary, overlay: Dictionary) -> int:
	var expected: Dictionary = Reference.encode_base(state)
	var encoded: Dictionary = cache.encode_base(state)
	assert(encoded.serialized == expected.serialized)
	assert(cache.encode_host(state, encoded, overlay) == Reference.encode_host(state, expected, overlay))
	return 2


func _check_record_key_transitions() -> int:
	var checks: int = 0
	var overlay: Dictionary = {"visible": false, "round_id": "record-key-transitions"}
	for unsupported: Variant in [7, NodePath("word"), Vector2(1, 2), true]:
		var cache := Cache.new()
		var record: Dictionary = {"id": 9, "age": 0.0, "7": "same-size schema change",
			"word": {"id": "cat", "meaning": "a small cat"}}
		var state: Dictionary = {"cells": [record], "tiles": []}
		for frame in range(2):
			record.age += 0.1
			checks += _check_native_pair(cache, state, overlay)
		assert(cache._records.cells.has(9))
		checks += 1
		# Keep the field count unchanged while replacing an accepted key type.
		# The unsupported record must use native fallback on every subsequent call.
		record.erase("7")
		record[unsupported] = "same-size schema change"
		for frame in range(3):
			record.age += 0.1
			checks += _check_native_pair(cache, state, overlay)
			assert(not cache._records.cells.has(9))
			checks += 1
		record.erase(unsupported)
		record[StringName("7")] = "same-size schema change"
		checks += _check_native_pair(cache, state, overlay)
		assert(cache._records.cells.has(9))
		checks += 1
		# StringName and String aliases remain valid on the unchanged-body path.
		var word: Dictionary = record.word
		record.erase("word")
		record[StringName("word")] = word
		record.age += 0.1
		checks += _check_native_pair(cache, state, overlay)
		word.meaning = "a changed meaning with the same vocabulary identity"
		record[StringName("quotes\"and}braces")] = "line one\nline two"
		checks += _check_native_pair(cache, state, overlay)
	return checks


func _run() -> void:
	var cache := Cache.new()
	var state: Dictionary = {"visible": true, "phase": "playing",
		"cells": [{"id": 1, "age": 0.0, "arrival": false, "word": {"text": "quote \" and newline\n"}},
			{"id": 2, "age": 2.0, "accessibility_name": "cat", "composition": {"parts": [1, 2]}}],
		"tiles": [{"id": 1, "age": 0.0, "presentation": {"frame": 0.125}, "visible": true}]}
	var overlay: Dictionary = {"visible": false, "round_id": "round:one", "pause": {"active": false}}
	var checks: int = 0
	for frame in range(80):
		for item: Dictionary in state.cells:
			item.age += 0.01667
		state.tiles[0].age += 0.01667
		if frame % 9 == 0:
			state.tiles[0].presentation.frame += 0.1
		if frame == 15:
			state.cells[1].composition.parts.append(3)
		if frame == 30:
			state.cells.remove_at(0)
		if frame == 45:
			state.cells.append({"id": 3, "age": 0.0, "word": {"text": "new"}})
		if frame == 50:
			overlay.pause.active = true
		var original: Dictionary = Reference.encode_base(state)
		var encoded: Dictionary = cache.encode_base(state)
		assert(encoded.serialized == original.serialized)
		assert(cache.encode_host(state, encoded, overlay) == Reference.encode_host(state, original, overlay))
		checks += 2
		# Published callers may mutate nested data after encoding.
		var saved: Dictionary = state.duplicate(true)
		state.cells[0].word = {"text": "external mutation"}
		state.assign(saved)
	cache.reset()
	assert(cache.encode_base(state).serialized == Reference.encode_base(state).serialized)
	checks += 1
	var numeric: Dictionary = {1: "native fallback", "cells": []}
	assert(cache.encode_base(numeric).serialized == Reference.encode_base(numeric).serialized)
	checks += 1
	var dense: Dictionary = {"cells": [], "tiles": [], "elapsed": 1}
	for index in range(56):
		dense.cells.append({"id": index, "age": 0.0, "falling": false, "word": {"text": "cat"}})
		dense.tiles.append({"id": index, "age": 0.0, "settled": true, "rect": [0.0, 0.0, 40.0, 40.0]})
	for frame in range(12):
		var moving: bool = frame >= 3 and frame < 9
		for index in range(56):
			dense.cells[index].age += 0.01667
			dense.cells[index].falling = moving
			dense.cells[index].word.text = "dog" if frame >= 6 else "cat"
			dense.tiles[index].age += 0.01667
			dense.tiles[index].settled = not moving
			dense.tiles[index].rect[1] = float(frame)
		dense.elapsed = 1.0 if frame >= 6 else 1
		var encoded: Dictionary = cache.encode_base(dense)
		var expected: Dictionary = Reference.encode_base(dense)
		assert(encoded.serialized == expected.serialized)
		assert(cache.encode_host(dense, encoded, overlay) == Reference.encode_host(dense, expected, overlay))
		assert(cache._records.has("cells") == not moving and cache._records.has("tiles") == not moving)
		checks += 3
	dense.cells[0].falling = true
	dense.tiles[0].settled = false
	assert(not cache._prefer_native_records(dense.cells) and not cache._prefer_native_records(dense.tiles))
	assert(not cache._prefer_native_records(dense.cells.slice(0, 7)))
	checks += 2
	# Gravity preserves falling history after landing; current settlement still
	# permits the age-only cache without changing any published field or bytes.
	for record: Dictionary in dense.cells:
		record.falling = true
		record.settling = false
	for record: Dictionary in dense.tiles:
		record.falling = true
		record.settled = true
	assert(not cache._prefer_native_records(dense.cells) and not cache._prefer_native_records(dense.tiles))
	checks += 1
	checks += _check_native_pair(cache, dense, overlay)
	assert(cache._records.has("cells") and cache._records.has("tiles"))
	checks += 1
	for record: Dictionary in dense.cells:
		record.settling = true
	for record: Dictionary in dense.tiles:
		record.settled = false
	assert(cache._prefer_native_records(dense.cells) and cache._prefer_native_records(dense.tiles))
	checks += 1
	checks += _check_native_pair(cache, dense, overlay)
	var arrival: Dictionary = {"id": 80, "age": 0.0, "arrival": true, "arrival_index": 0,
		"arrival_delay": 0.0, "row": 7, "height": 1, "width": 1, "settling": false, "falling": false}
	assert(cache._record_is_moving(arrival))
	arrival.age = 100.0
	assert(not cache._record_is_moving(arrival))
	checks += 2
	checks += _check_record_key_transitions()
	print("Word Jelly publication cache: %d checks, 0 failures" % checks)
	quit()
