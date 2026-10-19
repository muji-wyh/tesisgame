extends SceneTree
## One scratch candidate and actual WordCard QA. No production media gates are changed.
const BASE := "res://build/professional-english/retail-term-art-review/pallet-r01/candidate"
const MODEL := "res://build/professional-english/retail-term-art-review/pallet-r01/source/original/pallet.glb"
const Card = preload("res://scripts/word_card.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
var checks: Array = []
var cards: Array = []
var measurements: Array = []

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, name: String) -> void:
	checks.append({"check": name, "passed": ok})
	if not ok: push_error(name)

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 14) -> void:
	var label := Style.label(text, font_size)
	label.position = at
	label.size = dimensions
	root.add_child(label)

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(704, 250)
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
	environment.environment.ambient_light_energy = 0.35
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.light_color = Color("fffaf0")
	light.light_energy = 0.65
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.shadow_enabled = true
	viewport.add_child(light)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(MODEL), state) == OK)
	var model := document.generate_scene(state)
	viewport.add_child(model)
	var bounds := _bounds(model)
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.62
	viewport.add_child(camera)
	camera.position = Vector3(2.7, 1.6, 4)
	camera.look_at(Vector3(0, 0.067, 0))
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var raw: Image = viewport.get_texture().get_image()
	_check(raw.get_pixel(0, 0).a == 0.0, "Render background has alpha zero")
	assert(raw.save_png(BASE + "/render-raw.png") == OK)
	var used := raw.get_used_rect()
	var crop := used.grow(16).intersection(Rect2i(Vector2i.ZERO, raw.get_size()))
	var candidate := raw.get_region(crop)
	var dimensions := Vector2i(512, roundi(512.0 * float(crop.size.y) / float(crop.size.x)))
	candidate.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	assert(candidate.save_png(BASE + "/pallet.png") == OK)
	var texture := ImageTexture.create_from_image(candidate)
	viewport.queue_free()
	await process_frame
	var background := ColorRect.new()
	background.color = Color("f6f3e9")
	background.size = Vector2(root.size)
	root.add_child(background)
	_label("Pallet | actual WordCard at minimum observed sizes", Vector2(16, 10), Vector2(680, 24), 19)
	_label("Scratch texture only. Source geometry/materials unchanged. No term approval or production integration.", Vector2(16, 38), Vector2(680, 24), 12)
	var catalog := Catalog.new()
	assert(catalog.load_index())
	var profile: Dictionary = catalog.theme_profile("professional_retail")
	var palette: Dictionary = Data.theme("spring")
	for key in profile.palette: palette[key] = Color(str(profile.palette[key]))
	for column in range(4):
		var is_memory := column >= 2
		var matched := column % 2 == 1
		var title := ("Memory" if is_memory else "Match") + (" / matched" if matched else " / unmatched")
		var at := Vector2(16 + column * 172, 92)
		_label(title, Vector2(at.x, 67), Vector2(170, 20), 13)
		var card := Card.new()
		card.setup({"id": "pallet-" + str(column), "kind": "image", "word": {"id": "pallet.goods-platform.n", "text": "pallet", "track": "professional", "image": "", "audio": ""}})
		root.add_child(card)
		card.picture.texture = texture
		card.custom_minimum_size = Vector2.ZERO
		card.set_reduced_motion(true)
		if is_memory: card.set_back(Control.new())
		card.set_face_up(true, false)
		card.position = at
		card.size = Vector2(144, 74) if is_memory else Vector2(126, 72)
		card.refresh(palette, false, matched, false, false, false, 0)
		cards.append(card)
		_label("144 x 74 | art 120 x 54" if is_memory else "126 x 72 | art 102 x 52", Vector2(at.x, 176), Vector2(170, 24), 12)
	_label("Matched cards retain the real badge and 0.68 picture alpha. The contact is captured at 1 native pixel per pixel.", Vector2(16, 218), Vector2(685, 20), 12)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var contact: Image = root.get_texture().get_image()
	assert(contact.save_png(BASE + "/actual-word-card-contact.png") == OK)
	for index in range(cards.size()):
		var card = cards[index]
		var is_memory: bool = index >= 2
		var matched: bool = index % 2 == 1
		var expected_size := Vector2(144, 74) if is_memory else Vector2(126, 72)
		var expected_art := Vector2(120, 54) if is_memory else Vector2(102, 52)
		var name: String = ("memory" if is_memory else "match") + ("-matched" if matched else "-unmatched")
		_check(card.size == expected_size, name + ": exact minimum card size")
		_check(card.picture.size == expected_art, name + ": actual inset picture size")
		_check(card.match_mark.visible == matched, name + ": correct picture badge visibility")
		_check(is_equal_approx(card.picture.modulate.a, 0.68 if matched else 1.0), name + ": correct picture alpha")
		_check(card.picture.visible and card.face_up, name + ": visible picture face")
		var region: Image = contact.get_region(Rect2i(Vector2i(card.position), Vector2i(card.size)))
		assert(region.save_png(BASE + "/" + name + ".png") == OK)
		var scale_factor: float = minf(card.picture.size.x / dimensions.x, card.picture.size.y / dimensions.y)
		measurements.append({"state": name, "card_size": [card.size.x, card.size.y], "picture_size": [card.picture.size.x, card.picture.size.y], "image_render_size": [dimensions.x * scale_factor, dimensions.y * scale_factor], "badge_visible": card.match_mark.visible, "picture_alpha": card.picture.modulate.a, "card_script": card.get_script().resource_path, "texture_delivery": "Direct scratch ImageTexture assignment after real WordCard setup; not the production media loader."})
	contact.resize(contact.get_width() * 3, contact.get_height() * 3, Image.INTERPOLATE_NEAREST)
	assert(contact.save_png(BASE + "/actual-word-card-contact-3x.png") == OK)
	var failed: int = checks.filter(func(item): return not item.passed).size()
	var file := FileAccess.open(BASE + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "One source-rendered scratch term candidate and exact actual native WordCard size/state QA; no recognition acceptance, no curriculum approval, no production integration.", "model_sha256": FileAccess.get_sha256(MODEL), "candidate_sha256": FileAccess.get_sha256(BASE + "/pallet.png"), "camera": {"position": [2.7, 1.6, 4], "target": [0, 0.067, 0], "orthographic_size": 0.62, "lighting": {"ambient_energy": 0.35, "directional_energy": 0.65, "directional_rotation": [-50, -35, 0]}}, "raw_size": [768, 768], "alpha_bounds": [used.position.x, used.position.y, used.size.x, used.size.y], "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y], "candidate_size": [dimensions.x, dimensions.y], "palette": "Current production Retail profile over Spring defaults, as in Main", "measurements": measurements, "checks": checks, "failed": failed}, "\t") + "\n")
	file.close()
	print("Pallet scratch candidate and actual WordCard QA: " + str(checks.size()) + " checks, " + str(failed) + " failures")
	quit(1 if failed else 0)

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	return result
