extends SceneTree
## Four scratch lane probes with actual phone-size WordCard states. No production writes.
const BASE := "res://build/professional-english/retail-term-art-review/checkout-r01"
const OUT := BASE + "/composition-probe"
const Card = preload("res://scripts/word_card.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
var checks: Array = []
var probes: Array = []
var source_instances: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, name: String) -> void:
	checks.append({"check": name, "passed": ok})
	if not ok:
		push_error(name)

func _pose(model: Node3D, clip: String, seconds: float) -> Dictionary:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var player: AnimationPlayer = players[0] as AnimationPlayer
	var actual := ""
	for name: StringName in player.get_animation_list():
		if str(name) == clip or str(name).ends_with("/" + clip):
			actual = str(name)
	assert(not actual.is_empty())
	player.play(actual)
	player.seek(seconds, true)
	player.pause()
	return {"clip": actual, "seconds": seconds, "source_animation_only": true}

func _add_source(parent: Node3D, relative: String, at: Vector3, yaw: float, uniform_scale: float = 1.0, pose: Dictionary = {}) -> void:
	var source := BASE + "/source/" + relative
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(source), state) == OK)
	var model := document.generate_scene(state)
	parent.add_child(model)
	model.position = at
	model.rotation_degrees.y = yaw
	model.scale = Vector3.ONE * uniform_scale
	var sampled: Dictionary = {}
	if not pose.is_empty():
		sampled = _pose(model, str(pose.clip), float(pose.seconds))
	source_instances.append({"source": source, "sha256": FileAccess.get_sha256(source), "root_position": [at.x, at.y, at.z], "root_yaw_degrees": yaw, "root_uniform_scale": uniform_scale, "source_pose": sampled, "hidden_source_nodes": [], "geometry_materials_textures_skins_and_child_bind_transforms": "preserved; any pose comes only from the included sampled source clip"})

func _label(container: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int = 14) -> void:
	var label := Style.label(text, font_size)
	label.position = at
	label.size = dimensions
	container.add_child(label)

func _cards(candidate: Image, destination: String, title: String) -> Array:
	var texture := ImageTexture.create_from_image(candidate)
	var panel := Control.new()
	root.add_child(panel)
	var background := ColorRect.new()
	background.color = Color("f6f3e9")
	background.size = Vector2(root.size)
	panel.add_child(background)
	_label(panel, "Checkout probe: " + title + " | actual minimum WordCard", Vector2(16, 10), Vector2(680, 24), 18)
	_label(panel, "Source-rendered scratch image. No picture approval or production integration.", Vector2(16, 38), Vector2(680, 24), 12)
	var catalog := Catalog.new()
	assert(catalog.load_index())
	var profile: Dictionary = catalog.theme_profile("professional_retail")
	var palette: Dictionary = Data.theme("spring")
	for key in profile.palette:
		palette[key] = Color(str(profile.palette[key]))
	var cards: Array = []
	for column in range(4):
		var is_memory := column >= 2
		var matched := column % 2 == 1
		var at := Vector2(16 + column * 172, 92)
		_label(panel, ("Memory" if is_memory else "Match") + (" / matched" if matched else " / unmatched"), Vector2(at.x, 67), Vector2(170, 20), 13)
		var card := Card.new()
		card.setup({"id": "checkout-probe-" + str(column), "kind": "image", "word": {"id": "checkout.payment-area.n", "text": "checkout", "track": "professional", "image": "", "audio": ""}})
		panel.add_child(card)
		card.picture.texture = texture
		card.custom_minimum_size = Vector2.ZERO
		card.set_reduced_motion(true)
		if is_memory:
			card.set_back(Control.new())
		card.set_face_up(true, false)
		card.position = at
		card.size = Vector2(144, 74) if is_memory else Vector2(126, 72)
		card.refresh(palette, false, matched, false, false, false, 0)
		cards.append(card)
		_label(panel, "144 x 74 | art 120 x 54" if is_memory else "126 x 72 | art 102 x 52", Vector2(at.x, 176), Vector2(170, 24), 12)
	_label(panel, "Matched cards retain the real badge and 0.68 picture alpha. One native pixel per pixel.", Vector2(16, 218), Vector2(685, 20), 12)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var contact: Image = root.get_texture().get_image()
	assert(contact.save_png(destination + "/actual-word-card-contact.png") == OK)
	var measurements: Array = []
	for index in range(cards.size()):
		var card = cards[index]
		var is_memory: bool = index >= 2
		var matched: bool = index % 2 == 1
		var expected_size := Vector2(144, 74) if is_memory else Vector2(126, 72)
		var expected_art := Vector2(120, 54) if is_memory else Vector2(102, 52)
		var name: String = ("memory" if is_memory else "match") + ("-matched" if matched else "-unmatched")
		_check(card.size == expected_size, title + ": " + name + " card size")
		_check(card.picture.size == expected_art, title + ": " + name + " picture size")
		_check(card.match_mark.visible == matched, title + ": " + name + " badge")
		_check(is_equal_approx(card.picture.modulate.a, 0.68 if matched else 1.0), title + ": " + name + " picture alpha")
		var region: Image = contact.get_region(Rect2i(Vector2i(card.position), Vector2i(card.size)))
		assert(region.save_png(destination + "/" + name + ".png") == OK)
		var scale_factor: float = minf(card.picture.size.x / candidate.get_width(), card.picture.size.y / candidate.get_height())
		measurements.append({"state": name, "card_size": [card.size.x, card.size.y], "picture_size": [card.picture.size.x, card.picture.size.y], "image_render_size": [candidate.get_width() * scale_factor, candidate.get_height() * scale_factor], "badge_visible": card.match_mark.visible, "picture_alpha": card.picture.modulate.a, "texture_delivery": "Direct scratch ImageTexture assigned to the real WordCard; not the production Loader/cache delivery."})
	contact.resize(contact.get_width() * 3, contact.get_height() * 3, Image.INTERPOLATE_NEAREST)
	assert(contact.save_png(destination + "/actual-word-card-contact-3x.png") == OK)
	panel.queue_free()
	await process_frame
	return measurements

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT)), "Use a new revision to preserve previous probes")
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "/source-pose-review.json"))
	assert(review.status == "accepted_for_composition_probe")
	assert(review.source_inspection_report_sha256 == FileAccess.get_sha256(BASE + "/source-inspection/report.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(704, 250)
	for config: Dictionary in [{"name": "compact-three-quarter", "floor": false, "camera": Vector3(3, 2.7, 4), "size": 1.9}, {"name": "compact-high", "floor": false, "camera": Vector3(3, 4.0, 4), "size": 1.9}, {"name": "tiled-three-quarter", "floor": true, "camera": Vector3(3, 2.7, 4), "size": 2.55}, {"name": "tiled-high", "floor": true, "camera": Vector3(3, 4.0, 4), "size": 2.55}]:
		var destination := OUT + "/" + str(config.name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768, 768)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.18
		viewport.add_child(environment)
		var light := DirectionalLight3D.new()
		light.light_color = Color("fffaf0")
		light.light_energy = 0.38
		light.rotation_degrees = Vector3(-50, -35, 0)
		light.shadow_enabled = true
		viewport.add_child(light)
		var scene := Node3D.new()
		viewport.add_child(scene)
		source_instances = []
		var floor_y := 0.0
		if config.floor:
			for x in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					_add_source(scene, "mini-market/original/floor.glb", Vector3(x - 0.25, 0, z - 0.1), 0)
			floor_y = 0.025
		_add_source(scene, "mini-market/original/cash-register.glb", Vector3(0, floor_y, 0), 0)
		_add_source(scene, "mini-market/original/character-employee.glb", Vector3(0.23, floor_y, -0.33), 0, 1.0, review.employee_pose)
		_add_source(scene, "mini-characters/original/character-female-b.glb", Vector3(-0.75, floor_y, 0.0), 90, 1.0, review.shopper_pose)
		_add_source(scene, "food-kit/original/carton.glb", Vector3(-0.25, floor_y + 0.25, -0.13), -12, 0.32)
		_add_source(scene, "food-kit/original/apple.glb", Vector3(-0.24, floor_y + 0.25, 0.13), 20, 0.55)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(config.size)
		viewport.add_child(camera)
		camera.position = config.camera
		camera.look_at(Vector3(-0.16, 0.25, -0.1))
		for frame in range(7):
			await process_frame
		await RenderingServer.frame_post_draw
		var raw: Image = viewport.get_texture().get_image()
		_check(raw.get_pixel(0, 0).a == 0.0, str(config.name) + ": transparent background")
		assert(raw.save_png(destination + "/render-raw.png") == OK)
		var used := raw.get_used_rect()
		_check(used.position.x > 2 and used.position.y > 2 and used.end.x < 766 and used.end.y < 766, str(config.name) + ": complete scene in viewport")
		var crop := used.grow(16).intersection(Rect2i(Vector2i.ZERO, raw.get_size()))
		var candidate := raw.get_region(crop)
		var dimensions := Vector2i(512, roundi(512.0 * float(crop.size.y) / float(crop.size.x)))
		candidate.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
		assert(candidate.save_png(destination + "/checkout.png") == OK)
		var instances: Array = source_instances.duplicate(true)
		viewport.queue_free()
		await process_frame
		var measurements: Array = await _cards(candidate, destination, str(config.name))
		var camera_at: Vector3 = config.camera
		probes.append({"name": config.name, "scope": "Composition probe only; not selected or accepted", "source_instances": instances, "image_sha256": FileAccess.get_sha256(destination + "/checkout.png"), "dimensions": [dimensions.x, dimensions.y], "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y], "camera": {"position": [camera_at.x, camera_at.y, camera_at.z], "target": [-0.16, 0.25, -0.1], "orthographic_size": config.size}, "measurements": measurements})
	var failed: int = checks.filter(func(item): return not item.passed).size()
	var report := FileAccess.open(OUT + "/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope": "Four source-rendered checkout composition probes with real minimum WordCard states. Picture recognition remains a visual review decision. No production/media/language/morphology gates changed.", "source_pose_review_sha256": FileAccess.get_sha256(BASE + "/source-pose-review.json"), "source_record_sha256": FileAccess.get_sha256(BASE + "/source-record.json"), "palette": "Current Retail profile over Spring defaults as in Main", "probes": probes, "checks": checks, "failed": failed}, "\t") + "\n")
	report.close()
	print("Checkout composition probe: " + str(checks.size()) + " checks, " + str(failed) + " failures")
	quit(1 if failed else 0)
