extends SceneTree
## Paired preparation CPU measurements; rendering and physical FPS are excluded.

const ModelView = preload("res://scripts/chest_model_view.gd")
const TierCatalog = preload("res://scripts/chest_tier_catalog.gd")
const TIERS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 99]
const PITCH_LIMIT: float = 0.24
const SOURCE_PATHS: Array[String] = [
	"res://tests/performance/chest_reward_preparation_benchmark.gd",
	"res://scripts/chest_reward_model.gd",
	"res://scripts/chest_model_view.gd",
	"res://scripts/chest_asset_states.gd",
	"res://scripts/chest_tier_catalog.gd",
	"res://assets/chests/catalog/chest-states.json",
	TierCatalog.PRESETS_PATH,
]

var _resources: Array[Resource] = []
var _hashes: Dictionary = {}
var _failure: String = ""
var _parity_checks: int = 0
var _reference_script: Script
var _reference_path: String = "res://scripts/chest_model_view.gd"
var _reference_sources: Dictionary = {}
var _reference_constant_sources: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> bool:
	_failure = message
	return false


func _options() -> Dictionary:
	var result: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			result[pair[0]] = pair[1]
	return result


func _pin(path: String) -> bool:
	var resource_path: String = path if path.begins_with("res://") else "res://" + path
	if _hashes.has(resource_path):
		return true
	if not FileAccess.file_exists(resource_path):
		return _fail("Missing source file: " + resource_path)
	var digest: String = FileAccess.get_sha256(resource_path)
	if digest.is_empty():
		return _fail("Cannot hash source file: " + resource_path)
	_hashes[resource_path] = digest
	if FileAccess.file_exists(resource_path + ".import") and not _pin(resource_path + ".import"):
		return false
	if resource_path.get_extension() in ["glb", "gltf", "tscn", "tres", "res", "png", "webp"]:
		var resource: Resource = ResourceLoader.load(resource_path)
		if resource == null:
			return _fail("Cannot warm source resource: " + resource_path)
		# Strong references keep the real source resources warm across fresh views.
		_resources.append(resource)
	return true


func _pin_recipe(value: Variant) -> bool:
	if value is Dictionary:
		for field: Variant in value.values():
			if not _pin_recipe(field):
				return false
	elif value is Array:
		for field: Variant in value:
			if not _pin_recipe(field):
				return false
	elif value is String and (value.begins_with("assets/") or value.begins_with("res://assets/")):
		return _pin(value)
	return true


func _pin_reference_sources(path: String) -> bool:
	if _reference_sources.has(path):
		return true
	if not _pin(path):
		return false
	_reference_sources[path] = _hashes[path]
	var script_resource := load(path) as Script
	if script_resource == null:
		return _fail("Cannot inspect reference script constants: " + path)
	# GDScript ResourceLoader dependencies can be empty even for preloads.
	# Inspect the actual loaded constants so private previous implementations
	# such as AssetStates are pinned rather than inferred from source text.
	var constants: Dictionary = script_resource.get_script_constant_map()
	var constant_sources: Dictionary = {}
	for constant_name: Variant in constants:
		var value: Variant = constants[constant_name]
		if value is Script:
			var source_path: String = value.resource_path.get_slice("::", 0)
			if not source_path.begins_with("res://") or not source_path.ends_with(".gd"):
				return _fail("Cannot pin reference Script constant %s in %s: %s" % [
					str(constant_name), path, source_path])
			constant_sources[str(constant_name)] = source_path
			if not _pin_reference_sources(source_path):
				return false
	_reference_constant_sources[path] = constant_sources
	for dependency: String in ResourceLoader.get_dependencies(path):
		var source_path: String = ""
		for part: String in dependency.split("::"):
			if part.begins_with("res://"):
				source_path = part
				break
		if source_path.is_empty() and dependency.begins_with("uid://"):
			var resource_id: int = ResourceUID.text_to_id(dependency.get_slice("::", 0))
			if ResourceUID.has_id(resource_id):
				source_path = ResourceUID.get_id_path(resource_id)
		if source_path.ends_with(".gd") and not _pin_reference_sources(source_path):
			return false
	return true


func _same_framing(reference, closed) -> bool:
	return reference.closed_box() == closed.closed_box() and reference._motion_box == closed._motion_box \
		and reference._body_box == closed._body_box and reference._cavity == closed._cavity \
		and reference._seam == closed._seam and reference._camera.transform == closed._camera.transform \
		and reference._camera.size == closed._camera.size and reference._camera.far == closed._camera.far \
		and reference.closed_bounds() == closed.closed_bounds() and reference.design_bounds() == closed.design_bounds()


func _parity(reference, closed, tier: int) -> bool:
	if not _same_framing(reference, closed):
		return _fail("Exact closed/motion/camera framing differs for tier %d." % tier)
	var reference_state: Dictionary = reference.snapshot()
	var closed_state: Dictionary = closed.snapshot()
	# The optimized surface does not measure an unused opening/content envelope.
	reference_state.erase("content_box")
	closed_state.erase("content_box")
	if reference_state != closed_state:
		return _fail("Source identity, parts, contents, or render settings differ for tier %d." % tier)
	_parity_checks += 2
	var rest: Array = reference_state.parts.duplicate(true)
	for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		for pitch: float in [-PITCH_LIMIT, 0.0, PITCH_LIMIT]:
			reference.set_closed_turn(yaw, pitch)
			closed.set_closed_turn(yaw, pitch)
			var state: Dictionary = closed.snapshot()
			var projected: Rect2 = closed.closed_turn_bounds()
			if reference._rig.transform != closed._rig.transform or state.parts != rest \
				or reference.closed_turn_bounds() != projected or not _same_framing(reference, closed) \
				or state.open_amount != 0.0 or state.pressure != 0.0 or state.light_strength != 0.0:
				return _fail("Closed yaw/pitch parity differs for tier %d." % tier)
			for corner in range(8):
				var point: Vector2 = closed._project_point(closed._rig.transform * closed._closed_box.get_endpoint(corner))
				if not Rect2(0, 0, 1024, 1024).has_point(point) or not projected.grow(0.01).has_point(point):
					return _fail("A turned source corner escapes tier %d's fixed camera/bounds." % tier)
			_parity_checks += 2
	return true


func _pair(style: Dictionary, tier: int, closed_first: bool) -> Dictionary:
	var reference: Variant = _reference_script.new() if _reference_script != null else ModelView.new()
	if not reference is SubViewport:
		if reference is Node:
			reference.free()
		_fail("The reference view script must instantiate a SubViewport.")
		return {}
	for method: String in ["configure", "frame_closed_turn", "snapshot", "set_closed_turn", "closed_box",
			"closed_bounds", "design_bounds", "closed_turn_bounds", "_project_point"]:
		if not reference.has_method(method):
			reference.free()
			_fail("The reference view is missing required method: " + method)
			return {}
	var properties: Dictionary = {}
	for property: Dictionary in reference.get_property_list():
		properties[str(property.name)] = true
	for property: String in ["_motion_box", "_body_box", "_cavity", "_seam", "_camera", "_rig", "_closed_box", "last_error"]:
		if not properties.has(property):
			reference.free()
			_fail("The reference view is missing required model state: " + property)
			return {}
	var closed := ModelView.new()
	root.add_child(reference)
	root.add_child(closed)
	var timings: Array[int] = [0, 0]
	var succeeded: bool = true
	# View creation/attachment, resource warmup, parity, cleanup and reporting
	# stay outside both timed sections. Each measured configure gets a fresh view.
	for kind: int in ([1, 0] if closed_first else [0, 1]):
		var began: int = Time.get_ticks_usec()
		var ready: bool
		if kind == 0:
			ready = reference.configure(style) and reference.frame_closed_turn(PITCH_LIMIT)
		else:
			ready = closed.configure_closed_turn(style, PITCH_LIMIT)
		timings[kind] = Time.get_ticks_usec() - began
		if not ready:
			succeeded = _fail("Preparation failed for tier %d, path %d: %s" % [
				tier, kind, reference.last_error if kind == 0 else closed.last_error])
			break
	if succeeded:
		succeeded = _parity(reference, closed, tier)
	reference.free()
	closed.free()
	if not succeeded:
		return {}
	return {"reference_us": timings[0], "closed_us": timings[1],
		"order": ["closed", "reference"] if closed_first else ["reference", "closed"]}


func _statistics(values: Array[int]) -> Dictionary:
	var ordered: Array[int] = values.duplicate()
	ordered.sort()
	var total: int = 0
	for value: int in values:
		total += value
	var middle: int = ordered.size() / 2
	var median: float = float(ordered[middle]) if ordered.size() % 2 else (ordered[middle - 1] + ordered[middle]) * 0.5
	return {"samples": values.size(), "mean_us": float(total) / values.size(), "median_us": median,
		"min_us": ordered[0], "max_us": ordered[-1]}


func _run() -> void:
	var options: Dictionary = _options()
	var samples: int = int(options.get("samples", 3))
	var output_path: String = str(options.get("output", "user://chest-reward-preparation-cpu-%d-%d.json" % [
		int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]))
	if samples < 2 or samples > 20:
		_abort("Samples must be between 2 and 20 paired repetitions per tier.")
		return
	if FileAccess.file_exists(output_path):
		_abort("Refusing to overwrite existing output: " + output_path)
		return
	if options.has("reference-view"):
		_reference_path = str(options["reference-view"])
		if not _reference_path.begins_with("res://") or not _reference_path.ends_with(".gd") \
			or _reference_path.contains("..") or _reference_path.contains("\\"):
			_abort("The reference view must be a project-local res:// GDScript path.")
			return
		_reference_path = ProjectSettings.localize_path(ProjectSettings.globalize_path(_reference_path))
		if not ResourceLoader.exists(_reference_path, "Script"):
			_abort("The reference view script is unavailable: " + _reference_path)
			return
		_reference_script = load(_reference_path) as Script
		if _reference_script == null or not _reference_script.can_instantiate():
			_abort("The reference view script cannot be instantiated: " + _reference_path)
			return
	if not _pin_reference_sources(_reference_path):
		_abort(_failure)
		return
	for path: String in SOURCE_PATHS:
		if not _pin(path):
			_abort(_failure)
			return
	var manifest: Dictionary = TierCatalog.manifest()
	if manifest.is_empty():
		_abort("Production chest catalog failed: " + TierCatalog.error())
		return
	var styles: Dictionary = {}
	for tier: int in TIERS:
		var style: Dictionary = TierCatalog.style(tier, manifest)
		if style.is_empty():
			_abort("No real source recipe for tier %d." % tier)
			return
		style["camera_margin"] = 1.12
		style["max_resolution"] = 512
		if not _pin_recipe(style):
			_abort(_failure)
			return
		styles[tier] = style
	# Warm every actual recipe and both code paths before collecting any sample.
	for tier: int in TIERS:
		if _pair(styles[tier], tier, tier % 2 == 0).is_empty():
			_abort(_failure)
			return
	var rows: Array[Dictionary] = []
	var reference_times: Array[int] = []
	var closed_times: Array[int] = []
	for tier: int in TIERS:
		var style: Dictionary = styles[tier]
		var reference_samples: Array[int] = []
		var closed_samples: Array[int] = []
		var individual: Array[Dictionary] = []
		for index in range(samples):
			var paired: Dictionary = _pair(style, tier, (index + tier) % 2 == 0)
			if paired.is_empty():
				_abort(_failure)
				return
			paired["sample"] = index
			individual.append(paired)
			reference_samples.append(int(paired.reference_us))
			closed_samples.append(int(paired.closed_us))
			reference_times.append(int(paired.reference_us))
			closed_times.append(int(paired.closed_us))
		rows.append({"tier": tier, "preset_id": style.preset_id, "source_model": style.model,
			"state_scene": style.state_scene, "recipe_sha256": JSON.stringify(style).sha256_text(),
			"repeated_material": style.repeated_material, "individual_samples": individual,
			"reference": _statistics(reference_samples), "closed": _statistics(closed_samples)})
	var report: Dictionary = {"protocol": "chest-reward-preparation-cpu-v1",
		"engine": Engine.get_version_info(), "tiers": TIERS, "paired_samples_per_tier": samples,
		"reference_view": {"path": _reference_path, "sha256": _hashes[_reference_path],
			"script_sources_sha256": _reference_sources, "script_constant_sources": _reference_constant_sources,
			"preparation": "configure plus frame_closed_turn"},
		"production_view": {"path": "res://scripts/chest_model_view.gd",
			"sha256": _hashes["res://scripts/chest_model_view.gd"], "preparation": "configure_closed_turn"},
		"warmup_pairs_per_tier": 1, "pitch_limit": PITCH_LIMIT, "max_resolution": 512,
		"camera_margin": 1.12, "exact_native_parity": true, "parity_checks": _parity_checks,
		"source_sha256": _hashes, "reference": _statistics(reference_times), "closed": _statistics(closed_times),
		"scope": "Native preparation CPU only, on fresh inactive real model views with strongly retained warm production resources. The reported reference view's configure plus frame_closed_turn is paired with production configure_closed_turn in alternating order. By default both use the current ModelView and shared catalog cache; --reference-view can select a separately sourced previous implementation and its private dependencies in this same process. Source loading warmup, view creation/attachment, structural and yaw/pitch parity, cleanup, hashing and serialization are outside timing. Both paths preserve real geometry, materials and articulation. Excludes GPU rendering, browser bridge, audio, timeline, and physical FPS.",
		"rows": rows}
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	if directory_error != OK:
		_abort("Cannot create output directory: " + error_string(directory_error))
		return
	# Recheck immediately before writing so an existing result is never replaced.
	if FileAccess.file_exists(output_path):
		_abort("Refusing to overwrite existing output: " + output_path)
		return
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_abort("Cannot create new output: " + output_path)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("Chest reward preparation CPU report: " + output_path)
	print("Reference: ", report.reference, "; closed: ", report.closed)
	quit()


func _abort(message: String) -> void:
	printerr("Chest reward preparation CPU benchmark: " + message)
	quit(1)
