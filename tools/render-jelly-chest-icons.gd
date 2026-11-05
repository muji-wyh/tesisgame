extends SceneTree
## Bake the exact closed Jelly chest cache through its production Control.

const Chest = preload("res://scripts/chest_view.gd")
const Catalog = preload("res://scripts/chest_tier_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const SIZE := Vector2i(768, 768)
const SETTLE_FRAMES: int = 6
const OUTPUT: String = "res://assets/chests/catalog/jelly-icons.json"
const SOURCE_CATALOG: String = "res://assets/chests/catalog/atelier.json"
const STATE_CATALOG: String = "res://assets/chests/catalog/chest-states.json"
const TEXT_EXTENSIONS: Array[String] = ["gd", "gdshader", "tscn", "tres", "import", "json", "godot"]
const INPUTS: Array[String] = [
	"res://tools/render-jelly-chest-icons.gd",
	"res://project.godot",
	SOURCE_CATALOG, STATE_CATALOG,
	"res://assets/chests/catalog/chest-state-assets.json",
	"res://assets/chests/catalog/chest-levels.json",
	Catalog.PRESETS_PATH,
	"res://scripts/chest_view.gd",
	"res://scripts/chest_model_view.gd",
	"res://scripts/chest_asset_states.gd",
	"res://scripts/chest_tier_catalog.gd",
	"res://scripts/chest_feel.gd",
	"res://scripts/chest_opening_effect.gd",
	"res://scripts/chest_rainbow_light.gdshader",
	"res://scripts/chest_surface.gdshader",
	"res://scripts/game_data.gd",
	"res://scripts/jelly_reward_progress.gd",
]

var _dependencies: Dictionary = {}
var _failure: String = ""
var _viewport: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> bool:
	_failure = message
	return false


func _read_catalog(path: String) -> Dictionary:
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not content is Dictionary:
		_fail("Unable to read chest catalog: " + path)
		return {}
	return content


func _pin(path: String, inspect_dependencies: bool = true) -> bool:
	var resource_path: String = path if path.begins_with("res://") else "res://" + path
	var relative: String = resource_path.trim_prefix("res://")
	if _dependencies.has(relative):
		return true
	if not FileAccess.file_exists(resource_path):
		return _fail("Missing chest render dependency: " + resource_path)
	var digest: String = FileAccess.get_sha256(resource_path)
	if digest.is_empty():
		return _fail("Unable to hash chest render dependency: " + resource_path)
	var record: Dictionary = {"path": relative, "sha256": digest}
	if resource_path.get_extension().to_lower() in TEXT_EXTENSIONS:
		var source_text: String = FileAccess.get_file_as_string(resource_path).replace("\r\n", "\n").replace("\r", "\n")
		record["text_sha256"] = source_text.sha256_text()
	_dependencies[relative] = record
	if FileAccess.file_exists(resource_path + ".import") and not _pin(resource_path + ".import", false):
		return false
	if not inspect_dependencies or resource_path.get_extension() not in ["gd", "gdshader", "tscn", "tres", "glb", "gltf"]:
		return true
	for dependency: String in ResourceLoader.get_dependencies(resource_path):
		var source_path: String = ""
		for part: String in dependency.split("::"):
			if part.begins_with("res://"):
				source_path = part
				break
		if source_path.is_empty() and dependency.begins_with("uid://"):
			var resource_id: int = ResourceUID.text_to_id(dependency.get_slice("::", 0))
			if ResourceUID.has_id(resource_id):
				source_path = ResourceUID.get_id_path(resource_id)
		if source_path.is_empty() or not _pin(source_path):
			return _fail("Unable to resolve chest dependency %s from %s" % [dependency, resource_path])
	return true


func _pin_runtime_paths(value: Variant) -> bool:
	if value is Dictionary:
		for child: Variant in value.values():
			if not _pin_runtime_paths(child):
				return false
	elif value is Array:
		for child: Variant in value:
			if not _pin_runtime_paths(child):
				return false
	elif value is String and (value.begins_with("assets/") or value.begins_with("res://assets/")):
		return _pin(value)
	return true


func _record_for(catalog: Dictionary, collection: String, id: String) -> Dictionary:
	for record: Variant in catalog.get(collection, []):
		if record is Dictionary and str(record.get("id", "")) == id:
			return record.duplicate(true)
	_fail("Missing %s source record for %s" % [collection, id])
	return {}


func _rect_values(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rgba_hash(picture: Image) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(picture.get_data()) != OK:
		_fail("Unable to hash captured chest pixels")
		return ""
	return hashing.finish().hex_encode()


func _set_lossless_import(image_path: String) -> bool:
	var import_path: String = image_path + ".import"
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return _fail("Import the generated chest PNGs before rebaking their lossless settings: " + import_path)
	# Preserve Godot's existing remap UID and destination; change only pixel handling.
	config.set_value("params", "compress/mode", 0)
	config.set_value("params", "mipmaps/generate", false)
	config.set_value("params", "process/fix_alpha_border", false)
	config.set_value("params", "process/size_limit", 0)
	if config.save(import_path) != OK:
		return _fail("Unable to preserve lossless Jelly chest import settings: " + import_path)
	return true


func _capture(tier: int, manifest: Dictionary, source_catalog: Dictionary, state_catalog: Dictionary) -> Dictionary:
	var recipe: Dictionary = Catalog.preset(tier)
	if recipe.is_empty():
		_fail(Catalog.error())
		return {}
	var id: String = str(recipe.asset_id)
	var source: Dictionary = _record_for(source_catalog, "models", id)
	var states: Dictionary = _record_for(state_catalog, "variants", id)
	var style: Dictionary = Catalog.style(tier, manifest)
	if source.is_empty() or states.is_empty() or style.is_empty():
		return {}
	if not _pin_runtime_paths(style) or not _pin_runtime_paths(states):
		return {}
	var model_path: String = str(style.model)
	var scene_path: String = str(states.get("scene", ""))
	if model_path != str(source.get("model", "")) or model_path != str(states.get("model", "")) \
		or scene_path.is_empty() or not source.get("source") is Dictionary \
		or str(source.source.get("creator", "")).is_empty() or str(source.get("license", "")).is_empty():
		_fail("Incomplete or inconsistent production source provenance for " + id)
		return {}
	var theme: String = RewardProgress.theme_for_tier(tier)
	var art := Chest.new()
	_viewport.add_child(art)
	art.size = Vector2(SIZE)
	art.reduced_motion = true
	art.configure_tier(tier, Data.theme(theme), manifest)
	if art.piece_count() == 0 or not is_instance_valid(art._model_view):
		art.free()
		_fail("The production Chest could not load " + id)
		return {}
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Match the runtime cache: render first, then pause immediately before capture.
	# Reduced motion keeps all closed-pose clocks at zero during these frames.
	for frame in range(SETTLE_FRAMES):
		await process_frame
		await RenderingServer.frame_post_draw
	art.set_idle_paused(true)
	art.process_mode = Node.PROCESS_MODE_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var picture: Image = _viewport.get_texture().get_image()
	var model_size: Vector2i = art._model_view.size
	var closed: bool = art.mode == "closed" and is_zero_approx(art._elapsed) \
		and is_zero_approx(art._idle_time) and is_zero_approx(art._model_time)
	art.free()
	if not closed or picture == null or picture.is_empty() or picture.get_size() != SIZE:
		_fail("The production closed pose did not render at 768 x 768: " + id)
		return {}
	var used: Rect2i = picture.get_used_rect()
	if not used.has_area():
		_fail("The production Chest rendered empty: " + id)
		return {}
	# Preserve the exact alpha crop used by the former runtime chest cache.
	var crop: Rect2i = used.grow(2).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	var captured: Image = picture.get_region(crop)
	var rgba_digest: String = _rgba_hash(captured)
	if rgba_digest.is_empty():
		return {}
	var output_path: String = "res://assets/chests/models/atelier/%s/closed-jelly.png" % id
	if captured.save_png(output_path) != OK:
		_fail("Unable to save captured Jelly chest: " + output_path)
		return {}
	if not _set_lossless_import(output_path) or not _pin(output_path + ".import", false):
		return {}
	return {"asset_id": id, "tier": tier, "theme": theme,
		"path": output_path.trim_prefix("res://"), "width": captured.get_width(), "height": captured.get_height(),
		"sha256": FileAccess.get_sha256(output_path), "rgba_sha256": rgba_digest,
		"crop": _rect_values(crop), "used_rect": _rect_values(used), "image_format": captured.get_format(),
		"source_model": {"path": model_path, "sha256": FileAccess.get_sha256("res://" + model_path)},
		"state_scene": _dependencies[scene_path].duplicate(true),
		"model_render_size": [model_size.x, model_size.y],
		"creator": source.source.creator, "license": source.license,
		"source": source.source.duplicate(true), "source_inputs": source.get("source_inputs", []).duplicate(true),
		"acquisition_status": source.get("authoring_source_record", {}).get("source_status", ""),
		"available_animations": source.get("animations", []).duplicate(true),
		"source_catalog_record": source,
		"derivation_status": "Rendered from the integrated production model, not a source preview."}


func _finish_error() -> void:
	if is_instance_valid(_viewport):
		_viewport.free()
	printerr(_failure if not _failure.is_empty() else "Unable to bake Jelly chest icons")
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Jelly chest icons require a real rendering backend; omit --headless.")
		_finish_error()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = SIZE
	root.position = Vector2i(-20000, -20000)
	var manifest: Dictionary = Catalog.manifest()
	var source_catalog: Dictionary = _read_catalog(SOURCE_CATALOG)
	var state_catalog: Dictionary = _read_catalog(STATE_CATALOG)
	if manifest.is_empty() or source_catalog.is_empty() or state_catalog.is_empty():
		_finish_error()
		return
	for path: String in INPUTS:
		if not _pin(path):
			_finish_error()
			return
	_viewport = SubViewport.new()
	_viewport.name = "JellyChestIconBake"
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	var icons: Array[Dictionary] = []
	for tier in range(1, Catalog.MATERIAL_COUNT + 1):
		var icon: Dictionary = await _capture(tier, manifest, source_catalog, state_catalog)
		if icon.is_empty():
			_finish_error()
			return
		icons.append(icon)
		print("Baked Jelly chest %d/%d: %s (%d x %d)" % [tier, Catalog.MATERIAL_COUNT,
			icon.asset_id, icon.width, icon.height])
		await process_frame
	_viewport.free()
	var dependency_paths: Array = _dependencies.keys()
	dependency_paths.sort()
	var dependencies: Array[Dictionary] = []
	for path: String in dependency_paths:
		dependencies.append(_dependencies[path])
	var report := {"version": 1, "title": "Production closed Jelly chest icons",
		"generator": "tools/render-jelly-chest-icons.gd", "source_catalog": SOURCE_CATALOG.trim_prefix("res://"),
		"render_size": [SIZE.x, SIZE.y], "settle_frames": SETTLE_FRAMES,
		"reduced_motion": true, "idle_paused_before_capture": true, "state": "closed",
		"crop_policy": "get_used_rect().grow(2).intersection(full_image_rect); no resize or postprocessing",
		"godot": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "icon_count": icons.size(),
		"dependencies": dependencies, "icons": icons}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("Unable to write the Jelly icon manifest: " + OUTPUT)
		_finish_error()
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Baked %d production Jelly chest icons and %s" % [icons.size(), OUTPUT])
	quit(0)
