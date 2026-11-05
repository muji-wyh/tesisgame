extends SceneTree
## Real dense-board native encoding CPU comparison; this does not measure FPS.

const Data = preload("res://scripts/game_data.gd")
const View = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const GrowthMorphology = preload("res://scripts/growth_morphology.gd")
const Publication = preload("res://scripts/jelly_publication_json.gd")
const ProductionCache = preload("res://scripts/word_jelly_publication_cache.gd")
const COHORT := ["cat", "dog", "sun", "ball", "car", "apple", "fish", "duck", "cow"]
const SEED: int = 73021


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	printerr("Dense publication CPU benchmark: " + message)
	quit(1)


func _options() -> Dictionary:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	return options


func _fixture(view, data) -> bool:
	var words_by_id: Dictionary = {}
	for word: Dictionary in data.words:
		words_by_id[str(word.id)] = word
	var cohort: Array[Dictionary] = []
	for word_id: String in COHORT:
		if not words_by_id.has(word_id) or int(words_by_id[word_id].get("min_age", -1)) != 3:
			_fail("Missing required production Age 3 word: " + word_id)
			return false
		var decorated: Dictionary = GrowthMorphology.decorate(words_by_id[word_id])
		if decorated.get("morphology_status", "") != "reviewed":
			_fail("Required production morphology is not reviewed: " + word_id)
			return false
		if not ResourceLoader.exists("res://" + str(decorated.get("image", ""))):
			_fail("Required production picture is not mounted: " + word_id)
			return false
		cohort.append(decorated)
	# All required initialization executes even when a release export removes asserts.
	if not view.configure(cohort, 3, Data.theme("spring"), data.chests, false, SEED):
		_fail("Production Word Jelly configuration failed: " + view.game.error)
		return false
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	for index in range(Model.CAPACITY):
		var selected: Dictionary = cohort[(index * 5 + int(index / Model.MAX_MERGE_LEVEL)) % cohort.size()]
		var tile: Dictionary = view.game._new_word_root(selected, 1)
		view.game._set_merged_word(tile, selected, index % Model.MAX_MERGE_LEVEL + 1, true)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		view.game.cells.append(tile)
	view.game.merged_count = Model.CAPACITY
	view._sync_tiles()
	view._layout()
	return true


func _mutate(state: Dictionary, scenario: String, frame: int) -> void:
	for field: String in ["cells", "tiles"]:
		for index in range(state[field].size()):
			var record: Dictionary = state[field][index]
			record.age += 1.0 / 60.0
			if scenario == "falling-pose":
				record.falling = true
				record.falling_rows = 1 + frame % 4
				if field == "tiles":
					record.rect[1] += 0.75
					record.settled = false
					record.presentation.merged_effect.frame = frame % 24
			elif scenario == "persistent-nested-metadata" and index == frame % Model.CAPACITY:
				# Mutate existing published metadata without restoring it before
				# encoding. Same vocabulary IDs retain genuinely different values.
				for word_field: String in ["word", "image_word"]:
					var word: Dictionary = record.get(word_field, {})
					if not word.is_empty():
						word.meaning = "Encoding experiment update %d for %s" % [frame, str(word.id)]
						word.morphology.review.rationale = "Persistent nested metadata revision %d" % frame
	state.spawn_elapsed += 1.0 / 60.0
	if scenario == "falling-pose":
		state.drag.active = true
		state.drag.source = int(state.tiles[0].id)
		state.contact.strength = float(frame % 60) / 60.0


func _native_host(state: Dictionary, overrides: Dictionary) -> String:
	var host: Dictionary = state.duplicate()
	host.merge(overrides, true)
	return JSON.stringify(host)


func _source_hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()


func _statistics(values: Array) -> Dictionary:
	var ordered: Array = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: int in values:
		total += value
	return {"mean_us": total / values.size(), "p95_us": ordered[ceili(values.size() * 0.95) - 1]}


func _run() -> void:
	var options: Dictionary = _options()
	var samples: int = int(options.get("samples", 80))
	var warmup: int = int(options.get("warmup", 20))
	var output_path: String = str(options.get("output", "user://word-jelly-publication-dense-cpu-v1.json"))
	var reference_path: String = str(options.get("reference-cache", ""))
	var reference_script: Script
	var reference_label: String = "Fragmented native reference"
	var reference_key: String = "fragmented_reference"
	if samples <= 0 or warmup < 0:
		_fail("Samples must be positive and warmup cannot be negative.")
		return
	if FileAccess.file_exists(output_path):
		_fail("Refusing to overwrite existing output: " + output_path)
		return
	if not reference_path.is_empty():
		if not reference_path.begins_with("res://") or reference_path.contains("..") \
			or reference_path.contains("\\") or reference_path.get_extension() != "gd":
			_fail("The reference cache must be a project-local res:// GDScript path.")
			return
		reference_path = ProjectSettings.localize_path(ProjectSettings.globalize_path(reference_path))
		if not ResourceLoader.exists(reference_path, "Script"):
			_fail("The reference cache script is unavailable: " + reference_path)
			return
		reference_script = load(reference_path) as Script
		if reference_script == null:
			_fail("The reference cache script could not be loaded: " + reference_path)
			return
		reference_label = "Reference cache: " + reference_path
		reference_key = "reference_cache"
	var reference_source: String = reference_path if reference_script != null else "res://scripts/jelly_publication_json.gd"
	var reference_hash: String = _source_hash(reference_source)
	print("Dense publication reference: %s; SHA-256 %s" % [reference_label, reference_hash])
	var data := Data.new()
	if not data.load_all():
		_fail("Production GameData failed to load.")
		return
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	if not _fixture(view, data):
		view.free()
		return
	# Build the full real model/view snapshot once, outside every timed section.
	var fixture: Dictionary = view.snapshot()
	if fixture.cells.size() != Model.CAPACITY or fixture.tiles.size() != Model.CAPACITY \
		or not bool(fixture.get("authored_morphology", false)):
		view.free()
		_fail("The fixture must contain all 56 real merged bodies and authored Growth metadata.")
		return
	var seen_words: Dictionary = {}
	var seen_levels: Dictionary = {}
	for record: Dictionary in fixture.cells:
		if record.get("jelly_kind", "") != "merged" or record.word.get("morphology_status", "") != "reviewed" \
			or record.image_word.get("morphology_status", "") != "reviewed":
			view.free()
			_fail("Every fixture body must publish the real reviewed word and picture metadata.")
			return
		seen_words[str(record.word.id)] = true
		seen_levels[int(record.merge_level)] = true
	if seen_words.size() != COHORT.size() or seen_levels.size() != Model.MAX_MERGE_LEVEL:
		view.free()
		_fail("The fixture must include all nine requested vocabulary entries and merge levels.")
		return
	var fixture_characters: int = JSON.stringify(fixture).length()
	var overrides: Dictionary = {"visible": true, "mode": "word_jelly", "round_id": "dense-publication-cpu",
		"pause": {"active": false}, "campaign_map": {"visible": false}, "game_over": {"visible": false}}
	var rows: Array[Dictionary] = []
	for scenario: String in ["age-only", "falling-pose", "persistent-nested-metadata"]:
		var state: Dictionary = fixture.duplicate(true)
		var production := ProductionCache.new()
		var reference_cache: RefCounted
		if reference_script != null:
			var instance: Variant = reference_script.new()
			if not instance is RefCounted or not instance.has_method("encode_base") or not instance.has_method("encode_host"):
				view.free()
				_fail("The reference script must provide a RefCounted base and host encoder.")
				return
			reference_cache = instance
		var times: Array = [[], []]
		var sampled_min_characters: int = 9223372036854775807
		var sampled_max_characters: int = 0
		for frame in range(warmup + samples):
			_mutate(state, scenario, frame)
			var order: Array = [[0, 1], [1, 0]][frame % 2]
			var base_results: Array[String] = ["", ""]
			var host_results: Array[String] = ["", ""]
			for kind: int in order:
				var began: int = Time.get_ticks_usec()
				var encoded: Dictionary
				var hosted: String
				if kind == 0:
					if reference_cache != null:
						encoded = reference_cache.encode_base(state)
						hosted = reference_cache.encode_host(state, encoded, overrides)
					else:
						encoded = Publication.encode_base(state)
						hosted = Publication.encode_host(state, encoded, overrides)
				else:
					encoded = production.encode_base(state)
					hosted = production.encode_host(state, encoded, overrides)
				var elapsed: int = Time.get_ticks_usec() - began
				base_results[kind] = encoded.serialized
				host_results[kind] = hosted
				if frame >= warmup:
					times[kind].append(elapsed)
			# Complete native comparisons are outside timing and never warm a cache.
			var native_base: String = JSON.stringify(state)
			var native_host: String = _native_host(state, overrides)
			for kind in range(2):
				if base_results[kind] != native_base or host_results[kind] != native_host:
					view.free()
					_fail("Native JSON parity failed for encoder %d, scenario %s, frame %d." % [kind, scenario, frame])
					return
			if frame >= warmup:
				sampled_min_characters = mini(sampled_min_characters, native_base.length())
				sampled_max_characters = maxi(sampled_max_characters, native_base.length())
		var row: Dictionary = {"scenario": scenario, "samples": samples, "warmup": warmup,
			"snapshot_min_characters": sampled_min_characters, "snapshot_max_characters": sampled_max_characters,
			"native_byte_parity": true,
			"production_encoder": _statistics(times[1]),
			"samples_us": {"production_encoder": times[1]}}
		row[reference_key] = _statistics(times[0])
		row.samples_us[reference_key] = times[0]
		rows.append(row)
		print("Dense publication CPU: %s, %s %.3f ms, production %.3f ms" % [scenario, reference_label,
			float(row[reference_key].mean_us) / 1000.0, float(row.production_encoder.mean_us) / 1000.0])
	var report: Dictionary = {"protocol": "word-jelly-publication-dense-native-cpu-v1", "engine": Engine.get_version_info(),
		"encoder_sha256": {"reference": reference_hash,
			"production": _source_hash("res://scripts/word_jelly_publication_cache.gd")},
		"reference_label": reference_label, "reference_source": reference_source,
		"source_tiles": Model.CAPACITY, "viewport": [1366, 768], "seed": SEED,
		"cohort": COHORT, "merge_levels": [1, 2, 3, 4, 5, 6, 7, 8, 9],
		"fixture_snapshot_characters": fixture_characters, "native_byte_parity": true,
		"scope": "Headless native CPU encoding only: complete base and shallow host JSON for a real 56-body mixed-merged Word Jelly model/view snapshot using nine reviewed production Age 3 vocabulary entries and all nine merge levels. Snapshot construction, mutations, native parity comparisons and fixture setup are outside timing; reference and production call order alternates in the same process, with one independent encoder instance per scenario. Excludes rendering, bridge, signals, Auto Collect callbacks, audio and physical FPS. Compares the actual production encoder at measurement time with " + reference_label + ".",
		"rows": rows}
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	if directory_error != OK:
		view.free()
		_fail("Cannot create output directory: " + error_string(directory_error))
		return
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		view.free()
		_fail("Cannot open new output: " + output_path)
		return
	output.store_string(JSON.stringify(report))
	output.close()
	view.free()
	print("Dense publication CPU report: " + output_path)
	quit()
