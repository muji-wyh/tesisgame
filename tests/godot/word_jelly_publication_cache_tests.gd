extends SceneTree

const Cache = preload("res://scripts/word_jelly_publication_cache.gd")
const Reference = preload("res://scripts/jelly_publication_json.gd")

func _initialize() -> void:
	_run.call_deferred()

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
	print("Word Jelly publication cache: %d checks, 0 failures" % checks)
	quit()
