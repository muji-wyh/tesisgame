extends SceneTree
## Scratch source conversion and the real raw-media/UI path; no readiness override.
const BASE := "res://build/professional-english/retail-term-art-review/cash-register-r04"
const INPUT := BASE + "/candidate-r02"
const OUTPUT := INPUT + "/output"
const MODEL := BASE + "/source/original/Assets/gltf/cash_register.gltf"
const ID := "cash-register.sales-device.n"
const LEXEMES := "res://data/professional/lexemes/retail-pilot.json"
const Loader = preload("res://scripts/professional_media_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Manifest = preload("res://scripts/professional_media_manifest.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")
const Card = preload("res://scripts/word_card.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks: Array = []
var captures: Array = []
var conversion: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(file))

func _check(ok: bool, label: String) -> void:
	checks.append({"check": label, "passed": ok})
	if not ok:
		push_error(label)

func _settle(count: int = 4) -> void:
	for frame in range(count):
		await process_frame

func _rgba_sha(image: Image) -> String:
	image.convert(Image.FORMAT_RGBA8)
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(image.get_data()) == OK)
	return hashing.finish().hex_encode()

func _write_json(path: String, value: Dictionary) -> void:
	assert(not FileAccess.file_exists(path), "Preserve output")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 14) -> void:
	var label := Style.label(text, font_size)
	label.position = at
	label.size = dimensions
	root.add_child(label)

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	assert(not first)
	return result

func _render() -> Dictionary:
	var source_report: Dictionary = _json(BASE + "/native-inspection-r01/report.json")
	var source_view: Dictionary = source_report.captures[4]
	_check(source_view.file == "positive-z-right-low.png", "Root-selected original low-right source view is frozen")
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
	environment.environment.ambient_light_energy = 0.45
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
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
	var model: Node3D = document.generate_scene(state)
	viewport.add_child(model)
	var bounds := _bounds(model)
	model.position = -bounds.get_center()
	_check(model.find_children("*", "MeshInstance3D", true, false).size() == 2, "Complete original machine and original handle mesh are retained")
	_check(model.find_children("*", "AnimationPlayer", true, false).is_empty(), "Original source remains static; no animation invented")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = source_view.orthographic_size
	viewport.add_child(camera)
	camera.position = Vector3(source_view.camera[0], source_view.camera[1], source_view.camera[2])
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	await _settle(6)
	await RenderingServer.frame_post_draw
	var raw: Image = viewport.get_texture().get_image()
	_check(raw.get_size() == Vector2i(768, 768), "Scratch original render is exactly 768 x 768")
	_check(raw.get_pixel(0, 0).a == 0.0 and raw.get_pixel(767, 767).a == 0.0, "Render has transparent corner pixels")
	assert(raw.save_png(OUTPUT + "/render-raw.png") == OK)
	var used := raw.get_used_rect()
	_check(used.size.x > 0 and used.size.y > 0, "Original source produces a nonempty image")
	_check(used.position.x > 16 and used.position.y > 16 and used.end.x < 752 and used.end.y < 752, "Full source silhouette is inside render bounds with crop padding available")
	var crop := used.grow(16)
	var candidate := raw.get_region(crop)
	var dimensions := Vector2i(512, roundi(512.0 * float(crop.size.y) / float(crop.size.x)))
	candidate.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	assert(candidate.save_png(OUTPUT + "/cash-register.png") == OK)
	_check(candidate.get_pixel(0, 0).a == 0.0 and candidate.get_pixel(dimensions.x - 1, dimensions.y - 1).a == 0.0, "Tight candidate keeps transparent corner padding")
	var digest := FileAccess.get_sha256(OUTPUT + "/cash-register.png")
	var pixels := _rgba_sha(candidate)
	var bytes := FileAccess.get_file_as_bytes(OUTPUT + "/cash-register.png")
	var resource: Dictionary = {"id": "sha256:" + digest, "sha256": digest, "path": "professional-media/" + digest + ".png", "kind": "image", "format": "png", "compressed_bytes": bytes.size(), "decoded_bytes": dimensions.x * dimensions.y * 8, "width": dimensions.x, "height": dimensions.y}
	_check(Manifest.validate_resource(resource).ok, "Candidate has valid immutable delivery metadata")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "/fixture/professional-media")) == OK)
	var sidecar: String = OUTPUT + "/fixture/" + str(resource.path)
	var file := FileAccess.open(sidecar, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()
	_check(FileAccess.get_sha256(sidecar) == digest, "Scratch sidecar bytes equal original candidate PNG")
	_write_json(OUTPUT + "/resource.json", resource)
	conversion = {"model_sha256": FileAccess.get_sha256(MODEL), "source_view": source_view, "source_root_centering": source_report.root_centering_translation, "camera": {"position": source_view.camera, "look_at": [0, 0, 0], "orthographic_size": source_view.orthographic_size}, "lighting": source_report.lighting, "raw_size": [768, 768], "alpha_bounds": [used.position.x, used.position.y, used.size.x, used.size.y], "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y], "candidate_size": [dimensions.x, dimensions.y], "candidate_sha256": digest, "candidate_rgba_pixel_sha256": pixels, "adaptations": ["Original full source model and atlas, unchanged materials and child transforms", "Root centering, root-reviewed camera and original inspection studio lighting", "Transparent background, 16-pixel alpha-bound padding, 512-pixel-wide Lanczos resize"], "picture_review": "pending_root_visual_review"}
	viewport.queue_free()
	await _settle()
	return {"resource": resource, "rgba_pixel_sha256": pixels}

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT)))
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(704, 250)
	var frozen: Dictionary = _json(INPUT + "/frozen-inputs.json")
	_check(FileAccess.get_sha256(LEXEMES) == frozen.lexemes_raw_sha256, "Exact authored lexeme checkpoint is unchanged")
	_check(FileAccess.get_sha256(MODEL) == "43aed74637cf10432d996a18f03ed580f6cbc346b5f91d9592473370ed8ea1cc", "Original acquired glTF identity is frozen")
	var entry: Dictionary = {}
	for value: Dictionary in _json(LEXEMES).lexemes:
		if value.id == ID:
			entry = value
	_check(entry == _json(INPUT + "/entry-preimage.json"), "Exact full cash-register entry matches frozen preimage")
	_check(entry.media.image.status == "pending" and entry.media.image.path == null and entry.media.image.review.status == "pending", "Image integration and image review remain pending")
	_check(entry.media.audio.status == "integrated" and entry.media.audio.sha256 == "0f883c09be9a86be9f30e444953d001d3a385ba71034e60ceb4181fc0b9aa763", "Previously approved Ava recording remains intact without playback")
	_check(entry.review.status == "pending" and entry.review.domain == "pending", "Independent domain and overall review gates remain pending")
	var converted: Dictionary = await _render()
	var resource: Dictionary = converted.resource
	var dimensions := Vector2i(resource.width, resource.height)
	var digest: String = resource.sha256
	var catalog := Catalog.new()
	_check(catalog.load_index(), "Real current catalog loads without readiness overrides")
	var course: Dictionary = catalog.course("retail")
	for module: Dictionary in course.modules:
		_check(module.status == "draft", "Actual module remains draft: " + str(module.id))
	for mode: String in ["match", "memory", "pop", "jelly", "word_jelly", "phrase"]:
		var result: Dictionary = catalog.resolve(Context.professional("retail", "module03", course.curriculum_revision, mode))
		_check(not result.ok and result.get("code") == "content_pending", "Actual module03 remains unavailable for " + mode)
	var manifest: Dictionary = {"schema_version": 1, "course_id": "retail", "module_id": "cash-register-scratch-image-review", "curriculum_revision": "candidate-r02", "resources": [resource]}
	_check(Manifest.validate_manifest(manifest).ok, "Image-only scratch inventory fits immutable media schema and budgets")
	_write_json(OUTPUT + "/manifest.json", manifest)
	var loader := Loader.new()
	root.add_child(loader)
	loader.configure(ProjectSettings.globalize_path(OUTPUT + "/fixture"))
	_check(not loader.fetch_override.is_valid(), "Actual raw loader uses no injected fetch callback")
	loader.request_module(manifest, {}, [resource.id])
	var completed: Array = await loader.completed
	_check(completed[1].ok, "Real loader reads, hashes and decodes the scratch content-addressed sidecar")
	if not completed[1].ok:
		printerr(JSON.stringify(completed[1]))
		quit(1)
		return
	var leased: Dictionary = Access.acquire(loader.cache, completed[1].resource_ids)
	_check(leased.ok, "Actual decoded image acquires a scoped cache lease")
	if not leased.ok:
		quit(1)
		return
	var scoped_path: String = Access.path(leased.scope, digest)
	var texture: Texture2D = Access.resource(scoped_path) as Texture2D
	_check(texture != null and texture.get_size() == Vector2(dimensions), "Scoped decoded image has exact rendered dimensions")
	if texture == null:
		quit(1)
		return
	var texture_ref: WeakRef = weakref(texture)
	var loaded_image_sha := _rgba_sha(texture.get_image())
	_check(loaded_image_sha == converted.rgba_pixel_sha256, "Real decoded image pixels exactly equal source-rendered candidate pixels")
	_check(WordArt.texture(scoped_path) == texture, "Actual WordArt resolves the leased cache resource")
	var loaded: Dictionary = loader.cache.stats()
	_check(loaded.resources == 1 and loaded.resident_bytes == resource.decoded_bytes and loaded.pinned_bytes == resource.decoded_bytes and loaded.leases == 1 and loaded.reserved_bytes == 0 and loaded.active_ids == [resource.id], "Real cache accounts for exactly one candidate image and lease")
	var background := ColorRect.new()
	background.color = Color("f6f3e9")
	background.size = Vector2(root.size)
	root.add_child(background)
	_label("Cash register | minimum WordCard image review", Vector2(16, 10), Vector2(680, 24), 19)
	_label("Scratch source render through real Loader and WordArt. Image approval and integration remain pending.", Vector2(16, 38), Vector2(680, 24), 12)
	var palette: Dictionary = Data.theme("spring")
	var profile: Dictionary = catalog.theme_profile("professional_retail")
	for key in profile.palette:
		palette[key] = Color(str(profile.palette[key]))
	var cards: Array = []
	for index in range(4):
		var memory: bool = index >= 2
		var matched: bool = index % 2 == 1
		var at := Vector2(16 + index * 172, 92)
		_label(("Memory" if memory else "Match") + (" / matched" if matched else " / unmatched"), Vector2(at.x, 67), Vector2(170, 20), 13)
		var card := Card.new()
		card.setup({"id": "cash-register-review-" + str(index), "kind": "image", "word": {"id": entry.id, "text": entry.text, "track": "professional", "image": scoped_path, "audio": ""}})
		root.add_child(card)
		card.custom_minimum_size = Vector2.ZERO
		card.set_reduced_motion(true)
		if memory:
			card.set_back(Control.new())
		card.set_face_up(true, false)
		card.position = at
		card.size = Vector2(144, 74) if memory else Vector2(126, 72)
		card.refresh(palette, false, matched, false, false, false, 0)
		_check(card.picture.texture == texture, "Actual WordCard resolves the source through WordArt without texture substitution: " + str(index))
		cards.append(card)
		_label("144 x 74 | art 120 x 54" if memory else "126 x 72 | art 102 x 52", Vector2(at.x, 176), Vector2(170, 24), 12)
	_label("Inspect display, keys and drawer at native size; matched badge and 0.68 alpha are genuine.", Vector2(16, 218), Vector2(685, 20), 12)
	Input.warp_mouse(Vector2(700, 246))
	await _settle(5)
	await RenderingServer.frame_post_draw
	var contact: Image = root.get_texture().get_image()
	_check(contact.save_png(OUTPUT + "/actual-word-card-contact.png") == OK, "Actual native card contact is saved")
	for index in range(cards.size()):
		var card = cards[index]
		var memory: bool = index >= 2
		var matched: bool = index % 2 == 1
		var name: String = ("memory" if memory else "match") + ("-matched" if matched else "-unmatched")
		_check(card.size == (Vector2(144, 74) if memory else Vector2(126, 72)), "Exact minimum card size: " + name)
		_check(card.picture.size == (Vector2(120, 54) if memory else Vector2(102, 52)), "Exact picture inset size: " + name)
		_check(card.match_mark.visible == matched, "Real badge visibility: " + name)
		_check(is_equal_approx(card.picture.modulate.a, 0.68 if matched else 1.0), "Real matched picture alpha: " + name)
		_check(card.picture.visible and card.face_up, "Visible picture face: " + name)
		var region: Image = contact.get_region(Rect2i(Vector2i(card.position), Vector2i(card.size)))
		_check(region.save_png(OUTPUT + "/" + name + ".png") == OK, "Actual minimum crop is saved: " + name)
		var factor: float = minf(card.picture.size.x / dimensions.x, card.picture.size.y / dimensions.y)
		captures.append({"state": name, "file": name + ".png", "raw_sha256": FileAccess.get_sha256(OUTPUT + "/" + name + ".png"), "rgba_pixel_sha256": _rgba_sha(region), "card_size": [card.size.x, card.size.y], "picture_size": [card.picture.size.x, card.picture.size.y], "image_render_size": [dimensions.x * factor, dimensions.y * factor], "badge_visible": card.match_mark.visible, "picture_alpha": card.picture.modulate.a, "cue_visibility": {"complete_machine": "pending_root_visual_review", "sale_display_face": "pending_root_visual_review", "physical_key_bank": "pending_root_visual_review", "drawer_front_and_handle": "pending_root_visual_review", "secondary_receipt": "pending_root_visual_review"}})
	var enlarged: Image = contact.duplicate() as Image
	enlarged.resize(contact.get_width() * 3, contact.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_check(enlarged.save_png(OUTPUT + "/actual-word-card-contact-3x.png") == OK, "Nearest-neighbor enlarged review aid is saved")
	for card in cards:
		card.queue_free()
	cards.clear()
	texture = null
	await _settle()
	Access.release(leased.scope)
	loader.cache.deactivate()
	loader.cache.trim_inactive()
	await _settle()
	var released: Dictionary = loader.cache.stats()
	_check(released.resources == 0 and released.resident_bytes == 0 and released.pinned_bytes == 0 and released.reserved_bytes == 0 and released.leases == 0 and released.active_ids.is_empty(), "Cache teardown releases all resources, bytes, reservations, leases and active identities")
	var released_url: bool = Access.resource(scoped_path) == null and WordArt.texture(scoped_path) == null
	_check(released_url, "Released scope cannot revive the candidate image")
	var released_texture: bool = texture_ref.get_ref() == null
	_check(released_texture, "No strong reference retains decoded candidate after teardown")
	_check(FileAccess.get_sha256(LEXEMES) == frozen.lexemes_raw_sha256, "Full persisted lexeme bytes remain unchanged")
	var failed: Array = checks.filter(func(item): return not item.passed)
	var report: Dictionary = {"scope": "One scratch candidate from unchanged acquired Tiny Treats source, through real raw Loader, scoped cache lease, Access, WordArt and minimum WordCard. No texture substitution, fetch override, audio playback, readiness override or production writes. This image-only fixture is not an accepted media inventory or playable module.", "status": "candidate_probe_passed_pending_visual_review" if failed.is_empty() else "failed_attempt_preserved", "conversion": conversion, "resource": resource, "manifest": manifest, "candidate_rgba_pixel_sha256": converted.rgba_pixel_sha256, "loaded_image_rgba_pixel_sha256": loaded_image_sha, "loaded_cache": loaded, "released_cache": released, "released_texture_reference": released_texture, "released_scoped_url": released_url, "captures": captures, "checks": checks, "failed": failed.size(), "production_acceptance": false, "cue_visibility_acceptance": false, "production_scripts": {"loader": FileAccess.get_sha256("res://scripts/professional_media_loader.gd"), "access": FileAccess.get_sha256("res://scripts/professional_media_access.gd"), "word_art": FileAccess.get_sha256("res://scripts/word_art.gd"), "word_card": FileAccess.get_sha256("res://scripts/word_card.gd")}}
	_write_json(OUTPUT + "/report.json", report)
	loader.queue_free()
	await _settle()
	print("Cash-register scratch candidate delivery: " + str(checks.size()) + " checks, " + str(failed.size()) + " failures")
	quit(0 if failed.is_empty() else 1)
