extends SceneTree
## Scratch raw-media delivery and actual WordCard component captures.
const BASE := "res://build/professional-english/shopping-bag-candidate-r01"
const PREPARED := BASE + "/prepared"
const OUTPUT := BASE + "/output"
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
const Connections = preload("res://scripts/match_connections.gd")
var checks: Array = []
var captures: Array = []

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

func _write_json(file: String, value: Dictionary) -> void:
	assert(not FileAccess.file_exists(file), "Preserve evidence")
	var stream := FileAccess.open(file, FileAccess.WRITE)
	assert(stream != null)
	stream.store_string(JSON.stringify(value, "\t") + "\n")
	stream.close()

func _label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int) -> void:
	var label := Style.label(text, font_size)
	label.position = position
	label.size = size
	parent.add_child(label)

func _inspect_images(scope: String, resources: Array) -> Dictionary:
	# Local texture references end with this helper; return only weak references and data.
	var weak_references: Array = []
	var reports: Array = []
	for resource: Dictionary in resources:
		var scoped_path: String = Access.path(scope, resource.sha256)
		var texture: Texture2D = Access.resource(scoped_path) as Texture2D
		_check(texture != null, "Scoped image resolves: " + resource.id)
		assert(texture != null)
		_check(texture.get_size() == Vector2(resource.width, resource.height), "Exact decoded dimensions: " + resource.id)
		_check(WordArt.texture(scoped_path) == texture, "WordArt returns actual leased image: " + resource.id)
		var fixture: String = PREPARED + "/fixture/" + str(resource.path)
		_check(FileAccess.get_sha256(fixture) == resource.sha256, "Immutable fixture SHA matches: " + resource.id)
		var source_image := Image.load_from_file(fixture)
		assert(source_image != null)
		var expected_pixels := _rgba_sha(source_image)
		var decoded_pixels := _rgba_sha(texture.get_image())
		_check(decoded_pixels == expected_pixels, "Loader-decoded RGBA pixels equal exact PNG: " + resource.id)
		weak_references.append(weakref(texture))
		reports.append({"id": resource.id, "scoped_path": scoped_path, "source_rgba_sha256": expected_pixels, "decoded_rgba_sha256": decoded_pixels})
	return {"weak_references": weak_references, "images": reports}

func _states() -> Array:
	var result: Array = [
		{"name": "match-unmatched", "mode": "match", "matched": false, "pair": -1, "focused": false, "alpha": 1.0, "scope": "current_caller_equivalent"},
		{"name": "memory-unmatched", "mode": "memory", "matched": false, "pair": -1, "focused": false, "alpha": 1.0, "scope": "current_caller_equivalent"},
		{"name": "memory-matched", "mode": "memory", "matched": true, "pair": -1, "focused": false, "alpha": 1.0, "scope": "current_caller_equivalent"}
	]
	for lane in range(Connections.PAIR_COLORS.size()):
		for focused: bool in [false, true]:
			result.append({"name": "match-pair-%d-%s" % [lane + 1, "focused" if focused else "settled"], "mode": "match", "matched": true, "pair": lane, "focused": focused, "alpha": 1.0, "scope": "current_caller_equivalent"})
	result.append({"name": "match-stress-068", "mode": "match", "matched": true, "pair": 3, "focused": true, "alpha": 0.68, "scope": "wordcard_only_conservative_stress"})
	result.append({"name": "memory-stress-068", "mode": "memory", "matched": true, "pair": -1, "focused": false, "alpha": 0.68, "scope": "wordcard_only_conservative_stress"})
	return result

func _panel(state: Dictionary, scope: String, resources: Array, entries: Array, palette: Dictionary) -> Image:
	var canvas := Control.new()
	canvas.size = Vector2(root.size)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("f6f3e9")
	background.size = canvas.size
	canvas.add_child(background)
	_label(canvas, str(state.name), Vector2(12, 7), Vector2(370, 23), 17)
	_label(canvas, "Bag candidate", Vector2(16, 34), Vector2(160, 20), 13)
	_label(canvas, "Accepted basket reference", Vector2(212, 34), Vector2(180, 20), 13)
	var cards: Array = []
	var memory: bool = state.mode == "memory"
	var dimensions := Vector2(144, 74) if memory else Vector2(126, 72)
	var picture_dimensions := Vector2(120, 54) if memory else Vector2(102, 52)
	var tint: Color = Connections.PAIR_COLORS[int(state.pair)] if int(state.pair) >= 0 else Style.GOOD
	for index in range(2):
		var resource: Dictionary = resources[index]
		var entry: Dictionary = entries[index]
		var scoped_path := Access.path(scope, resource.sha256)
		var card := Card.new()
		card.setup({"id": "bag-review-%s-%d" % [state.name, index], "kind": "image", "word": {"id": entry.id, "text": entry.text, "track": "professional", "image": scoped_path, "audio": ""}})
		canvas.add_child(card)
		card.custom_minimum_size = Vector2.ZERO
		card.set_reduced_motion(true)
		if memory:
			card.set_back(Control.new())
		card.set_face_up(true, false)
		card.position = Vector2(16 + index * 196, 60)
		card.size = dimensions
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.refresh(palette, false, state.matched, false, false, false, state.pair, tint, state.focused)
		# Both current mode callers restore alpha to 1 after refresh. The two
		# explicitly labeled stress states retain WordCard's own matched alpha.
		if state.scope == "current_caller_equivalent":
			card.picture.modulate.a = 1.0
			card.word_label.modulate.a = 1.0
			if not memory:
				card.disabled = false # Match caller restores disabled to the unlocked round state.
		_check(card.picture.texture == Access.resource(scoped_path), "Actual WordCard uses leased texture without replacement: %s/%d" % [state.name, index])
		cards.append(card)
	_label(canvas, "%d x %d | alpha %.2f | %s" % [dimensions.x, dimensions.y, state.alpha, "stress only" if state.scope != "current_caller_equivalent" else "caller-equivalent"], Vector2(12, 143), Vector2(380, 20), 12)
	Input.warp_mouse(Vector2(392, 169))
	await _settle(5)
	await RenderingServer.frame_post_draw
	var panel: Image = root.get_texture().get_image()
	_check(panel.get_size() == Vector2i(396, 172), "Unscaled native viewport: " + str(state.name))
	_check(panel.save_png(OUTPUT + "/panel-" + str(state.name) + ".png") == OK, "Native comparison panel saved: " + str(state.name))
	for index in range(cards.size()):
		var card = cards[index]
		var name: String = ("bag-" if index == 0 else "basket-") + str(state.name)
		_check(card.size == dimensions, "Exact established review card dimensions: " + name)
		_check(card.picture.size == picture_dimensions, "Exact picture insets: " + name)
		_check(is_equal_approx(Style.ui_scale(card), 1.0), "Native UI scale equals one: " + name)
		_check(card.scale == Vector2.ONE and card.get_node("CardFace").scale == Vector2.ONE, "No motion or flip scaling: " + name)
		_check(not card.has_focus() and not card.is_hovered(), "No keyboard focus or mouse hover contamination: " + name)
		_check(card.picture.visible and card.face_up, "Image face is visible: " + name)
		_check(card.picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Actual aspect-centered image mode: " + name)
		_check(card.match_mark.visible == state.matched, "Actual badge visibility: " + name)
		_check(card.match_mark.pair_number == (int(state.pair) + 1 if state.matched else 0), "Actual numbered or generic badge: " + name)
		_check(card.match_mark.active == (state.matched and state.focused), "Actual pair focus state: " + name)
		_check(is_equal_approx(card.picture.modulate.a, state.alpha), "Explicit caller or stress opacity: " + name)
		var expected_disabled: bool = state.matched and (memory or state.scope != "current_caller_equivalent")
		_check(card.disabled == expected_disabled, "Explicit caller or stress disabled state: " + name)
		var region := panel.get_region(Rect2i(Vector2i(card.position), Vector2i(card.size)))
		_check(region.save_png(OUTPUT + "/" + name + ".png") == OK, "Native card crop saved: " + name)
		var style: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
		var expected_fill: Color = (tint.lightened(0.85 if state.focused else 0.96) if int(state.pair) >= 0 else Color("e7f5e9")) if state.matched else Color("fffef9")
		_check(style.bg_color.is_equal_approx(expected_fill), "Actual unmatched or matched fill: " + name)
		var resource: Dictionary = resources[index]
		var factor: float = minf(picture_dimensions.x / resource.width, picture_dimensions.y / resource.height)
		var cue_visibility: Dictionary = {"two_separate_loop_handles": "pending_root_visual_review", "open_cavity": "pending_root_visual_review",
			"solid_tall_body_distinct_from_slotted_basket": "pending_root_visual_review", "no_gift_specific_decoration": "pending_root_visual_review"} if index == 0 else {
			"broad_carrying_handle": "pending_root_visual_review", "open_basket": "pending_root_visual_review", "squat_slotted_body_distinct_from_solid_bag": "pending_root_visual_review"}
		captures.append({"file": name + ".png", "sha256": FileAccess.get_sha256(OUTPUT + "/" + name + ".png"), "rgba_sha256": _rgba_sha(region),
			"subject": "bag_candidate" if index == 0 else "accepted_basket_reference", "state": state, "card_size": [dimensions.x, dimensions.y],
			"picture_size": [picture_dimensions.x, picture_dimensions.y], "rendered_image_size": [resource.width * factor, resource.height * factor],
			"badge_visible": card.match_mark.visible, "pair_number": card.match_mark.pair_number, "pair_tint": tint.to_html(), "fill": style.bg_color.to_html(),
			"picture_alpha": card.picture.modulate.a, "control_disabled": card.disabled, "cue_visibility": cue_visibility})
	canvas.queue_free()
	cards.clear()
	await _settle()
	return panel

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT)))
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(396, 172)
	var frozen := _json(PREPARED + "/frozen-inputs.json")
	var entries: Array = [_json(PREPARED + "/bag-entry-preimage.json"), _json(PREPARED + "/basket-entry-preimage.json")]
	_check(FileAccess.get_sha256(LEXEMES) == frozen.lexemes_raw_sha256, "Current lexeme bytes match preparation checkpoint")
	for expected: Dictionary in entries:
		var actual: Dictionary = {}
		for entry: Dictionary in _json(LEXEMES).lexemes:
			if entry.id == expected.id:
				actual = entry
		_check(actual == expected, "Full unchanged entry preimage: " + str(expected.id))
	_check(entries[0].media.image.status == "pending" and entries[0].media.image.path == null and entries[0].media.image.review.status == "pending", "Candidate image remains unintegrated and unaccepted")
	_check(entries[0].media.audio.sha256 == "6c7d2ac0e733214faf920a4a0781d0458b6b891a92aa07b7ab433b501d19de72", "Approved Ava recording descriptor remains exact without playback")
	_check(entries[0].media.image.brief == frozen.original_brief and not frozen.brief_revision_accepted, "Original brief is retained; revision is only proposed")
	var catalog := Catalog.new()
	_check(catalog.load_index(), "Actual current catalog loads")
	var course: Dictionary = catalog.course("retail")
	_check(not course.is_empty(), "Actual Retail course exists")
	for module: Dictionary in course.modules:
		_check(module.status == "draft", "Current actual Retail module remains draft: " + str(module.id))
	for mode: String in ["match", "memory", "pop", "jelly", "word_jelly", "phrase"]:
		var result: Dictionary = catalog.resolve(Context.professional("retail", "module03", course.curriculum_revision, mode))
		_check(not result.ok and result.get("code") == "content_pending", "Actual module03 remains unavailable: " + mode)
	var manifest := _json(PREPARED + "/manifest.json")
	_check(Manifest.validate_manifest(manifest).ok, "Scratch image-only manifest satisfies current schema and budgets")
	_check(manifest.resources == frozen.resources and manifest.resources.size() == 2, "Exactly bag candidate and accepted basket are requested")
	var required: Array = manifest.resources.map(func(value): return value.id)
	var loader := Loader.new()
	root.add_child(loader)
	loader.configure(ProjectSettings.globalize_path(PREPARED + "/fixture"))
	_check(not loader.fetch_override.is_valid(), "Real raw loader has no injected fetch callback")
	var generation: int = loader.request_module(manifest, {}, required)
	var completed: Array = await loader.completed
	_check(completed[0] == generation, "Loader completion belongs to this exact request generation")
	_check(completed[1].ok, "Actual loader reads, hashes and decodes both immutable scratch sidecars")
	assert(completed[1].ok)
	var leased: Dictionary = Access.acquire(loader.cache, completed[1].resource_ids)
	_check(leased.ok, "Both images acquire one actual scoped lease")
	assert(leased.ok)
	var inspected := _inspect_images(leased.scope, manifest.resources)
	var total_bytes: int = int(manifest.resources[0].decoded_bytes) + int(manifest.resources[1].decoded_bytes)
	var loaded: Dictionary = loader.cache.stats()
	_check(loaded.resources == 2 and loaded.resident_bytes == total_bytes and loaded.pinned_bytes == total_bytes and loaded.leases == 1 and loaded.reserved_bytes == 0, "Actual cache accounts for two images, exact bytes and one lease")
	var actual_ids: Array = loaded.active_ids.duplicate()
	actual_ids.sort()
	var sorted_required: Array = required.duplicate()
	sorted_required.sort()
	_check(actual_ids == sorted_required, "Only the exact two image identities are active")
	loader.cache.deactivate()
	loader.cache.trim_inactive()
	var lease_only: Dictionary = loader.cache.stats()
	_check(lease_only.resources == 2 and lease_only.resident_bytes == total_bytes and lease_only.pinned_bytes == total_bytes and lease_only.leases == 1 and lease_only.active_ids.is_empty(), "Lease alone retains both decoded resources after deactivation and trim")
	for item: Dictionary in inspected.images:
		_check(Access.resource(item.scoped_path) != null and WordArt.texture(item.scoped_path) != null, "Lease-only image remains resolvable: " + str(item.id))
	var palette: Dictionary = Data.theme("spring")
	var profile: Dictionary = catalog.theme_profile("professional_retail")
	for key in profile.palette:
		palette[key] = Color(str(profile.palette[key]))
	var states := _states()
	_check(states.size() == 15, "Five real Match pair colors have focused and settled cases plus unmatched, Memory and stress states")
	var contact := Image.create(1188, 860, false, Image.FORMAT_RGBA8)
	contact.fill(Color("f6f3e9"))
	for index in range(states.size()):
		var panel: Image = await _panel(states[index], leased.scope, manifest.resources, entries, palette)
		contact.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i((index % 3) * 396, floori(float(index) / 3.0) * 172))
	_check(contact.save_png(OUTPUT + "/actual-wordcard-comparison.png") == OK, "Contact assembled from exact native panels")
	var enlarged: Image = contact.duplicate() as Image
	enlarged.resize(contact.get_width() * 3, contact.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_check(enlarged.save_png(OUTPUT + "/actual-wordcard-comparison-3x.png") == OK, "Nearest-neighbor review aid preserves actual pixels")
	Access.release(leased.scope)
	loader.cache.trim_inactive()
	await _settle()
	var released: Dictionary = loader.cache.stats()
	_check(released.resources == 0 and released.resident_bytes == 0 and released.pinned_bytes == 0 and released.reserved_bytes == 0 and released.leases == 0 and released.active_ids.is_empty(), "Final teardown releases all resources, bytes, reservations, leases and active identities")
	var released_urls: Array = []
	var released_weakrefs: Array = []
	for index in range(inspected.images.size()):
		var item: Dictionary = inspected.images[index]
		var url_gone: bool = Access.resource(item.scoped_path) == null and WordArt.texture(item.scoped_path) == null
		var texture_gone: bool = inspected.weak_references[index].get_ref() == null
		released_urls.append(url_gone)
		released_weakrefs.append(texture_gone)
		_check(url_gone, "Released scoped URL cannot revive image: " + str(item.id))
		_check(texture_gone, "No strong texture reference survives: " + str(item.id))
	_check(FileAccess.get_sha256(LEXEMES) == frozen.lexemes_raw_sha256, "Persisted lexeme bytes remain unchanged")
	var failures: Array = checks.filter(func(item): return not item.passed)
	var report: Dictionary = {"schema": 1, "status": "candidate_probe_passed_pending_visual_review" if failures.is_empty() else "failed_attempt_preserved",
		"scope": "Two-image scratch fixture through real raw Loader, cache lease, Access, WordArt and native WordCard. Presentation copies current caller alpha/tint/focus; does not instantiate a complete board or prove a universal responsive-layout minimum.",
		"reference_review_sizes": {"match": [126, 72], "memory": [144, 74], "claim": "Established observed asset-review dimensions; current live boards compute sizes from viewport."},
		"frozen_inputs_sha256": FileAccess.get_sha256(PREPARED + "/frozen-inputs.json"), "manifest": manifest, "image_pixels": inspected.images,
		"loaded_cache": loaded, "lease_only_cache": lease_only, "released_cache": released, "released_scoped_urls": released_urls, "released_texture_weakrefs": released_weakrefs,
		"captures": captures, "checks": checks, "failed": failures.size(), "brief_revision_accepted": false, "production_acceptance": false, "cue_visibility_acceptance": false,
		"actual_board_execution": false, "participant_recognition_study": false, "audio_playback": false,
		"caller_sources": {"match": FileAccess.get_sha256("res://scripts/game_ui.gd"), "memory": FileAccess.get_sha256("res://scripts/memory_garden.gd"), "pair_colors": FileAccess.get_sha256("res://scripts/match_connections.gd")}}
	_write_json(OUTPUT + "/report.json", report)
	loader.queue_free()
	await _settle()
	print("Shopping-bag candidate QA: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
