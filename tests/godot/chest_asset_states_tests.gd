extends SceneTree

const StatePlayer = preload("res://scripts/chest_asset_states.gd")
const SpriteStates = preload("res://scripts/chest_sprite_states.gd")
const CATALOG_PATH: String = "res://assets/chests/catalog/chest-states.json"
const CAPTURE_PATH: String = "res://build/qa/chest-asset-states"
const STATES: Array[String] = ["closed", "open", "treasure", "magic"]

var checks: int = 0
var failures: int = 0
var _variants: Array = []
var _sprite_variants: Array = []


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
	check(_variants.size() == 21, "All twenty-one acquired chest models have reusable state scenes")
	for row: Dictionary in _variants:
		_check_model(row)
	_sprite_variants = catalog.variants.filter(func(row: Dictionary) -> bool:
		return str(row.get("asset_type", "")) == "sprites")
	if not OS.get_cmdline_user_args().has("--models-only"):
		check(_sprite_variants.size() == 3, "All three legacy sprite families have complete state compositions")
		for row: Dictionary in _sprite_variants:
			_check_sprite(row)
	_check_reconfiguration()
	if OS.get_cmdline_user_args().has("--capture") and failures == 0:
		await _capture_states()
	print("Chest asset states: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_model(row: Dictionary) -> void:
	var id: String = str(row.id)
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


func _check_sprite(row: Dictionary) -> void:
	var id: String = str(row.id)
	var scene_path: String = _resource_path(str(row.get("scene", "")))
	check(ResourceLoader.exists(scene_path, "PackedScene"), id + " has a sibling native sprite state scene")
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return
	var scene := load(scene_path) as PackedScene
	var sprite: Sprite2D = scene.instantiate() as Sprite2D
	root.add_child(sprite)
	check(sprite.get_script() == SpriteStates, id + " scene uses the source image state loader")
	check(bool(sprite.debug_state().configured), id + " configures all four real illustrations: " + sprite.last_error)
	var hashes: Dictionary = {}
	for state: String in STATES:
		check(sprite.set_state(state), id + " displays " + state)
		var info: Dictionary = sprite.debug_state()
		check(str(info.state) == state and str(info.texture) == _resource_path(str(row.states[state])),
			id + " displays the exact cataloged source-derived " + state + " texture")
		check(info.dimensions == Vector2(1024, 1024), id + " preserves the shared 1024-pixel framing")
		if sprite.texture == null:
			continue
		var image: Image = sprite.texture.get_image()
		check(image != null and not image.is_empty(), id + " " + state + " decodes in native Godot")
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		check(_clear_border(image), id + " " + state + " retains transparent stage padding")
		var digest: String = image.get_data().hex_encode().sha256_text()
		check(not hashes.has(digest), id + " " + state + " contains distinct artwork")
		hashes[digest] = state
		var selected: Texture2D = sprite.texture
		sprite.set_state("closed")
		sprite.set_state(state)
		check(sprite.texture == selected, id + " repeats " + state + " without changing the source illustration")
	check(not sprite.set_state("unknown"), id + " rejects unknown state images")
	check(not sprite.configure("missing-chest") and sprite.texture == null,
		id + " clears stale artwork when the requested asset is missing")
	sprite.free()


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
	player.free()


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
			"source_model": row.model, "scene": row.scene, "camera_size": camera.size})
		player.free()
	var sprite_rows: Array = []
	if not OS.get_cmdline_user_args().has("--models-only"):
		for row: Dictionary in _sprite_variants:
			var sprite := SpriteStates.new()
			viewport.add_child(sprite)
			check(sprite.configure(str(row.id)), str(row.id) + " configures for native sprite capture")
			sprite.position = Vector2(192, 192)
			sprite.scale = Vector2.ONE * (360.0 / 1024.0)
			var strip := Image.create_empty(1536, 384, false, Image.FORMAT_RGBA8)
			var image_hashes: Array[String] = []
			for index in range(STATES.size()):
				sprite.set_state(STATES[index])
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = viewport.get_texture().get_image()
				check(image != null and not image.is_empty(), str(row.id) + " renders native " + STATES[index])
				if image == null or image.is_empty():
					continue
				image.convert(Image.FORMAT_RGBA8)
				strip.blit_rect(image, Rect2i(0, 0, 384, 384), Vector2i(index * 384, 0))
				image_hashes.append(image.get_data().hex_encode().sha256_text())
				check(_clear_border(image), str(row.id) + " " + STATES[index] + " clears the native 2D frame")
			check(image_hashes.size() == 4 and image_hashes[1] != image_hashes[2]
				and image_hashes[1] != image_hashes[3] and image_hashes[2] != image_hashes[3],
				str(row.id) + " Open, Treasure and Magic render distinct native 2D pixels")
			strip.save_png(CAPTURE_PATH + "/" + str(row.id) + ".png")
			strips.append(strip)
			sprite_rows.append({"id": row.id, "states": STATES, "render_sha256": image_hashes,
				"source_images": row.states, "scene": row.scene})
			sprite.free()
	var contact := Image.create_empty(1536, strips.size() * 384, false, Image.FORMAT_RGBA8)
	for index in range(strips.size()):
		contact.blit_rect(strips[index], Rect2i(0, 0, 1536, 384), Vector2i(0, index * 384))
	contact.save_png(CAPTURE_PATH + "/all-model-states.png")
	contact.save_png(CAPTURE_PATH + "/all-asset-states.png")
	var file := FileAccess.open(CAPTURE_PATH + "/capture-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
		"states": STATES, "models": rows, "sprites": sprite_rows}, "\t") + "\n")
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
