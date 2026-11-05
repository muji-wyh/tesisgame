extends SceneTree
## Encoding-only CPU comparison. This does not measure rendered FPS.

const Data = preload("res://scripts/game_data.gd")
const View = preload("res://scripts/word_jelly.gd")
const Fixture = preload("res://tests/performance/jelly_drag_fixture.gd")
const Publication = preload("res://scripts/jelly_publication_json.gd")
const Cache = preload("res://scripts/word_jelly_publication_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var data := Data.new()
	assert(data.load_all())
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	Fixture.install(view, data, 56)
	var state: Dictionary = view.snapshot()
	var overrides: Dictionary = {"visible": true, "mode": "word_jelly", "round_id": "encoding-benchmark",
		"pause": {"active": false}, "campaign_map": {"visible": false}, "game_over": {"visible": false}}
	var merged: Dictionary = state.duplicate()
	merged.merge(overrides, true)
	var encoded: Dictionary = Publication.encode_base(state)
	assert(encoded.serialized == JSON.stringify(state))
	assert(Publication.encode_host(state, encoded, overrides) == JSON.stringify(merged))
	var cache := Cache.new()
	var times: Array = [[], [], []]
	for index in range(240):
		for field: String in ["cells", "tiles"]:
			for record: Dictionary in state[field]:
				record.age += 0.1
		for kind: int in ([0, 1, 2] if index % 2 == 0 else [2, 1, 0]):
			var began: int = Time.get_ticks_usec()
			if kind == 0:
				var fragments: Dictionary = Publication.encode_base(state)
				Publication.encode_host(state, fragments, overrides)
			elif kind == 1:
				JSON.stringify(state)
				var host: Dictionary = state.duplicate()
				host.merge(overrides, true)
				JSON.stringify(host)
			else:
				var reused: Dictionary = cache.encode_base(state)
				cache.encode_host(state, reused, overrides)
			if index >= 30:
				times[kind].append(Time.get_ticks_usec() - began)
		assert(cache.encode_base(state).serialized == Publication.encode_base(state).serialized)
	var output: Dictionary = {"protocol": "word-jelly-publication-encoding-cpu-v1", "tiles": 56,
		"characters": encoded.serialized.length(), "samples": 210, "semantic_parity": true,
		"fragmented": _stats(times[0]), "whole_dictionary": _stats(times[1]),
		"cached": _stats(times[2]),
		"samples_us": times, "scope": "Paired native CPU encoding only. Snapshot construction, browser bridge, rendering, audio and physical FPS are excluded."}
	var file := FileAccess.open("res://build/performance/chrome-60fps/publication-cpu.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(output))
	print("Publication encoding: ", output.fragmented, " -> cached ", output.cached)
	view.free()
	quit()

func _stats(values: Array) -> Dictionary:
	var ordered: Array = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: int in values:
		total += value
	return {"mean_us": total / values.size(), "p95_us": ordered[ceili(ordered.size() * 0.95) - 1]}
