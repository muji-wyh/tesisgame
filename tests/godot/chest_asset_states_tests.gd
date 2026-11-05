extends SceneTree

const StatePlayer = preload("res://scripts/chest_asset_states.gd")
const CATALOG_PATH: String = "res://assets/chests/catalog/chest-states.json"
const CAPTURE_PATH: String = "res://build/qa/chest-asset-states"
const STATES: Array[String] = ["closed", "open", "treasure", "magic"]

var checks: int = 0
var failures: int = 0
var _variants: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	check(FileAccess.file_exists(CATALOG_PATH), "The reusable chest state catalog exists")
	if not FileAccess.file_exists(CATALOG_PATH):
		quit(1)
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	check(catalog is Dictionary and catalog.get("variants") is Array,
		"The state catalog declares a variants array")
	if not catalog is Dictionary or not catalog.get("variants") is Array:
		quit(1)
		return
	_variants = catalog.variants.filter(func(row: Dictionary) -> bool:
		return str(row.get("asset_type", "")) == "model")
	var level_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chests/catalog/chest-levels.json"))
	var ranked_ids: Dictionary = {}
	if level_catalog is Dictionary:
		for row: Dictionary in level_catalog.get("levels", []):
			if str(row.get("asset_type", "")) == "model":
				ranked_ids[str(row.asset_id)] = true
	var expected_models: int = ranked_ids.size()
	check(expected_models == 28 and _variants.size() == expected_models
		and int(catalog.get("variant_count", 0)) == expected_models
		and catalog.variants.size() == expected_models,
		"Every ranked chest model has a reusable state scene")
	for row: Dictionary in _variants:
		check(str(row.model).begins_with("assets/chests/models/atelier/") and ranked_ids.has(str(row.id)),
			"Every active state scene uses a retained Atelier identity rather than an old chest source")
		_check_model(row)
	_check_reconfiguration()
	_check_catalog_cache()
	if OS.get_cmdline_user_args().has("--capture") and failures == 0:
		await _capture_states()
	print("Chest asset states: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_model(row: Dictionary) -> void:
	var id: String = str(row.id)
	check(FileAccess.get_sha256(_resource_path(str(row.model))) == str(row.get("model_sha256", "")),
		id + " uses the exact cataloged source bytes")
	var scene_path: String = _resource_path(str(row.get("scene", "")))
	check(ResourceLoader.exists(scene_path, "PackedScene"), id + " has a sibling native state scene")
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return
	var scene := load(scene_path) as PackedScene
	var player: Node3D = scene.instantiate() as Node3D
	root.add_child(player)
	check(player.get_script() == StatePlayer, id + " scene uses the reusable state player")
	var initial: Dictionary = player.debug_state()
	check(bool(initial.configured), id + " configures without missing resources: " + str(initial.error))
	check(str(initial.id) == id, id + " scene retains its exact catalog identity")
	check(str(initial.model) == str(row.model), id + " retains the actual source GLB")
	check(player.source_model_path() == str(row.model), id + " exposes its source path without traversing render bounds")
	if not bool(initial.configured):
		player.free()
		return
	var closed_pose: Array = _source_pose(player)
	var open_pose: Array = []
	for state: String in STATES:
		check(player.set_state(state), id + " accepts state " + state)
		var info: Dictionary = player.debug_state()
		check(str(info.state) == state, id + " reports actual state " + state)
		check(is_equal_approx(float(info.openness), 0.0 if state == "closed" else 1.0),
			id + " has a fully posed source mechanism in " + state)
		check(bool(info.loot_visible) == (state == "treasure"),
			id + " shows genuine loot only in treasure")
		check(bool(info.magic_visible) == (state == "magic"),
			id + " shows source particle sprites only in magic")
		var bounds: AABB = info.bounds
		check(bounds.size.is_finite() and bounds.position.is_finite()
			and bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0,
			id + " has finite volumetric source bounds in " + state)
		if state == "open":
			open_pose = _source_pose(player)
			check(open_pose != closed_pose, id + " opens the actual separate lid or cover")
		elif state in ["treasure", "magic"]:
			check(_source_pose(player) == open_pose,
				id + " keeps the same open source pose when changing presentation")
		if state == "magic":
			check(int(info.magic_sprites) >= 3, id + " instantiates real glow, ray and sparkle textures")
			check(not bool(info.magic_clipped), id + " contains complete sprites in its magic envelope")
			for role: String in ["glow", "ray", "spark"]:
				var texture_path: String = _resource_path(str(info.magic_textures.get(role, "")))
				check(ResourceLoader.exists(texture_path, "Texture2D"),
					id + " magic " + role + " resolves to acquired source art")
			for time: float in [0.0, 0.2, 1.0, 5.0, 30.0]:
				player._sample_magic(time)
				check(not bool(player.debug_state().magic_clipped),
					id + " magic remains bounded through gentle motion at %.1f" % time)
	check(not player.set_state("unknown"), id + " rejects unknown presentation states")
	for repeat in range(3):
		player.set_state("closed")
		check(_source_pose(player) == closed_pose, id + " closes without accumulating hinge transforms")
		player.set_state("open")
		check(_source_pose(player) == open_pose, id + " reopens to the exact authored endpoint")
	player.reduced_motion = true
	player.set_state("magic")
	check(not player.is_processing(), id + " reduced motion retains a static readable magic state")
	check(bool(player.debug_state().magic_visible), id + " reduced motion retains acquired effect artwork")
	player.free()


func _source_pose(player: Node3D) -> Array:
	var source: Node3D = player.get("_source")
	var result: Array = []
	if source != null:
		_collect_pose(source, result)
	return result


func _collect_pose(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append([str(node.name), node.global_transform])
	for child: Node in node.get_children():
		_collect_pose(child, result)


func _check_reconfiguration() -> void:
	var player := StatePlayer.new()
	root.add_child(player)
	for row: Dictionary in _variants:
		check(player.configure(str(row.id)), str(row.id) + " supports reuse of one state player")
		player.set_state("treasure")
		check(bool(player.debug_state().loot_visible), str(row.id) + " reconfiguration retains its own loot")
	check(not player.configure("missing-chest"), "Unknown asset fails without substituting a different chest")
	check(player.get_child_count() == 0, "Failed reconfiguration clears stale source models and effects")
	check(not bool(player.debug_state().configured), "Failed reconfiguration reports unavailable state")
	check(player.source_model_path().is_empty(), "Failed reconfiguration clears the direct source path")
	player.free()


func _check_catalog_cache() -> void:
	if _variants.is_empty():
		return
	var first: Dictionary = _variants[0].duplicate(true)
	var id: String = str(first.id)
	first["cache_probe"] = {"marker": "original", "nested": [{"marker": "original"}]}
	var later: Dictionary = first.duplicate(true)
	later.cache_probe.marker = "later-duplicate"
	var original_text: String = JSON.stringify({"variants": [17, first, later]})
	var original: Variant = StatePlayer._entry_for_catalog_text(original_text, id)
	check(original is Dictionary and original.get("cache_probe", {}).get("marker") == "original",
		"An exact-text catalog cache preserves the first matching dictionary variant")
	if not original is Dictionary:
		return
	original.cache_probe.nested[0].marker = "mutated-copy"
	original.model = "mutated-copy"
	var repeated: Variant = StatePlayer._entry_for_catalog_text(original_text, id)
	check(repeated is Dictionary and repeated.get("model") == first.model \
		and repeated.get("cache_probe", {}).get("nested", [])[0].marker == "original",
		"Repeated source text returns detached nested entry data rather than shared cached dictionaries")
	var changed: Dictionary = first.duplicate(true)
	changed.cache_probe.marker = "changed-source"
	var changed_text: String = JSON.stringify({"variants": [changed]})
	var updated: Variant = StatePlayer._entry_for_catalog_text(changed_text, id)
	check(updated is Dictionary and updated.get("cache_probe", {}).get("marker") == "changed-source",
		"Changed source text replaces the previous parsed catalog immediately")
	for invalid_text: String in ["{", "null", "[]", "{\"variants\":{}}"]:
		check(StatePlayer._entry_for_catalog_text(invalid_text, id) == null,
			"Malformed or structurally invalid current text never falls back to the last valid catalog")
		var restored: Variant = StatePlayer._entry_for_catalog_text(original_text, id)
		check(restored is Dictionary and restored.get("cache_probe", {}).get("marker") == "original" \
			and restored.get("model") == first.model,
			"Restored valid source text recovers the original selected recipe after invalid text")
	var non_model: Dictionary = first.duplicate(true)
	non_model.asset_type = "sprite"
	var first_match: Variant = StatePlayer._entry_for_catalog_text(JSON.stringify({"variants": [non_model, first]}), id)
	check(first_match is Dictionary and first_match.get("asset_type") == "sprite",
		"A first matching non-model variant remains selected for the existing unknown-model failure")
	var empty: Variant = StatePlayer._entry_for_catalog_text("{\"variants\":[]}", id)
	check(empty is Dictionary and empty.is_empty(),
		"A valid empty variants array remains an unknown-asset result rather than an invalid catalog")
	var missing: Variant = StatePlayer._entry_for_catalog_text(original_text, "missing-cache-entry")
	check(missing is Dictionary and missing.is_empty(), "An unknown cached ID never substitutes another chest")
	var owner := StatePlayer.new()
	var sibling := StatePlayer.new()
	root.add_child(owner)
	root.add_child(sibling)
	var ready: bool = owner.configure(id) and sibling.configure(id)
	check(ready, "Real configure rereads the production catalog after synthetic cached source changes")
	if ready:
		var expected_model: String = sibling.source_model_path()
		owner._entry.magic.textures.glow = "instance-only-mutation"
		owner._entry["model"] = "instance-only-model"
		check(sibling.source_model_path() == expected_model \
			and sibling._entry.magic.textures.glow == first.magic.textures.glow,
			"Each configured instance owns both top-level source identity and nested content entries")
		owner._clear()
		check(owner.source_model_path().is_empty() and sibling.source_model_path() == expected_model \
			and sibling.configure(id) and sibling._entry.magic.textures.glow == first.magic.textures.glow,
			"Clearing a mutated instance cannot alter another instance or the privately cached catalog")
	owner.free()
	sibling.free()


func _capture_states() -> void:
	DirAccess.make_dir_recursive_absolute(CAPTURE_PATH)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9e3f0")
	environment.ambient_light_energy = 0.68
	world.environment = environment
	studio.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -35, 0)
	key.light_energy = 1.4
	studio.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 135, 0)
	fill.light_energy = 0.55
	studio.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.001
	camera.far = 100.0
	studio.add_child(camera)
	var strips: Array[Image] = []
	var rows: Array = []
	for row: Dictionary in _variants:
		var player := StatePlayer.new()
		studio.add_child(player)
		if not player.configure(str(row.id)):
			check(false, str(row.id) + " configures for capture")
			player.free()
			continue
		player.reduced_motion = true
		player.set_state("closed")
		var envelope: AABB = player.state_bounds()
		for state: String in STATES:
			player.set_state(state)
			envelope = envelope.merge(player.state_bounds())
		var direction: Vector3 = Vector3(0.56, 0.46, 1.0).normalized()
		var target: Vector3 = envelope.get_center()
		camera.position = target + direction * maxf(3.0, envelope.size.length() * 2.0)
		camera.look_at(target, Vector3.UP)
		var horizontal: float = 0.0
		var vertical: float = 0.0
		for corner in range(8):
			var point: Vector3 = envelope.position + Vector3(
				envelope.size.x if corner & 1 else 0.0,
				envelope.size.y if corner & 2 else 0.0,
				envelope.size.z if corner & 4 else 0.0)
			var local: Vector3 = camera.global_transform.affine_inverse() * point
			horizontal = maxf(horizontal, absf(local.x))
			vertical = maxf(vertical, absf(local.y))
		camera.size = maxf(horizontal, vertical) * 2.0 * 1.10
		var strip := Image.create_empty(384 * 4, 384, false, Image.FORMAT_RGBA8)
		var image_hashes: Array[String] = []
		for index in range(STATES.size()):
			player.set_state(STATES[index])
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			check(image != null and not image.is_empty(), str(row.id) + " renders " + STATES[index])
			if image == null or image.is_empty():
				continue
			image.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(image, Rect2i(0, 0, 384, 384), Vector2i(index * 384, 0))
			image_hashes.append(image.get_data().hex_encode().sha256_text())
			check(_clear_border(image), str(row.id) + " " + STATES[index] + " clears the fixed camera frame")
		check(image_hashes.size() == 4 and image_hashes[1] != image_hashes[2]
			and image_hashes[1] != image_hashes[3] and image_hashes[2] != image_hashes[3],
			str(row.id) + " empty Open, Treasure and Magic have distinct native rendered pixels")
		strip.save_png(CAPTURE_PATH + "/" + str(row.id) + ".png")
		strips.append(strip)
		rows.append({"id": row.id, "states": STATES, "render_sha256": image_hashes,
			"source_model": row.model, "sha256": FileAccess.get_sha256(_resource_path(str(row.model))),
			"bytes": FileAccess.open(_resource_path(str(row.model)), FileAccess.READ).get_length(),
			"scene": row.scene, "camera_size": camera.size,
			"capture": str(row.id) + ".png"})
		player.free()
	var contact := Image.create_empty(1536, strips.size() * 384, false, Image.FORMAT_RGBA8)
	for index in range(strips.size()):
		contact.blit_rect(strips[index], Rect2i(0, 0, 1536, 384), Vector2i(0, index * 384))
	contact.save_png(CAPTURE_PATH + "/all-model-states.png")
	contact.save_png(CAPTURE_PATH + "/all-asset-states.png")
	var file := FileAccess.open(CAPTURE_PATH + "/capture-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"checks": checks, "failures": failures, "passed": failures == 0,
		"capture_root": ProjectSettings.globalize_path(CAPTURE_PATH),
		"states": STATES, "models": rows, "sprites": []}, "\t") + "\n")
	viewport.free()


func _clear_border(image: Image) -> bool:
	for coordinate in range(image.get_width()):
		if image.get_pixel(coordinate, 0).a > 0.02 or image.get_pixel(coordinate, image.get_height() - 1).a > 0.02:
			return false
	for coordinate in range(image.get_height()):
		if image.get_pixel(0, coordinate).a > 0.02 or image.get_pixel(image.get_width() - 1, coordinate).a > 0.02:
			return false
	return true


func _resource_path(filename: String) -> String:
	return filename if filename.begins_with("res://") else "res://" + filename
