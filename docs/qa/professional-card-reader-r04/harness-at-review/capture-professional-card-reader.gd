extends SceneTree
## Capture real Match/Memory callers with a private, explicitly synthetic media fixture.
## No production review flag or curriculum file is changed. Use a private APPDATA root.

const FIXTURE_PATH := "res://tools/fixtures/professional-card-reader.json"
const REVISION := "professional-card-reader-review-v1"
const READER := "card-reader.payment-device.n"
const SUBJECTS := [READER, "cash-register.sales-device.n", "barcode.product-code.n"]
const SIZES := [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]
const Context = preload("res://scripts/learning_context.gd")
const Resolver = preload("res://scripts/learning_content_resolver.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Manifest = preload("res://scripts/professional_media_manifest.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Style = preload("res://scripts/ui_style.gd")
const Connections = preload("res://scripts/match_connections.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const OwnerFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const Medal = preload("res://scripts/medal_progress.gd")

# As in the successful gift-wrap fixture, only the private delivery root changes.
# The real loader, decoder, cache, Access lease and WordArt remain in use.
class ReviewMedia extends "res://scripts/professional_media_loader.gd":
	var delivery_root: String
	func configure(_native_root: String = "", _host: Object = null) -> void:
		super.configure(delivery_root, null)

# Private readiness and review flags exist only to reach real app callers.
# They are never written into production data or a proposed production afterimage.
class ReviewCatalog extends RefCounted:
	var lexemes: Dictionary = {}
	var expressions: Dictionary = {}
	var manifest: Dictionary
	var course_data: Dictionary
	var palette: Dictionary
	func _init(originals: Dictionary, fixture: Dictionary, theme: Dictionary) -> void:
		palette = theme.get("palette", {}).duplicate(true)
		manifest = {"schema_version": 1, "course_id": "retail", "module_id": "module03",
			"curriculum_revision": REVISION, "resources": []}
		var metadata: Dictionary = {}
		for row: Dictionary in fixture.resources:
			metadata[str(row.lexeme_id) + ":" + str(row.metadata.kind)] = row.metadata
			manifest.resources.append(row.metadata.duplicate(true))
		var ids: Array = []
		for row: Dictionary in fixture.entries:
			var entry: Dictionary = originals[row.id].duplicate(true)
			entry.review = _review()
			entry.practice_modes = ["match", "memory"]
			if row.id == READER:
				entry.media.image = _descriptor(metadata[READER + ":image"])
			ids.append(row.id)
			lexemes[row.id] = entry
		var surrounding_image: Dictionary = metadata["shopping-bag.goods-carrier.n:image"]
		var surrounding_audio: Dictionary = metadata["shopping-bag.goods-carrier.n:audio"]
		var synthetic_ids: Array = []
		for index in range(45):
			var id: String = "synthetic.fixture.%02d" % index
			var label: String = "fixture%02d" % index
			ids.append(id)
			synthetic_ids.append(id)
			lexemes[id] = {"id": id, "text": label, "pos": "noun", "difficulty": "A2",
				"definition": "Synthetic surrounding row for layout only.", "example": "This is not course content.",
				"review": _review(), "practice_modes": ["phrase"],
				"media": {"image": _descriptor(surrounding_image), "audio": _descriptor(surrounding_audio)},
				"morphology": {"schema": 1, "id": id + ".analysis", "lexeme_id": id, "text": label,
					"kind": "atomic", "review": {"status": "reviewed", "reviewer": "Synthetic render fixture"},
					"nodes": [], "roots": ["whole"], "parts": [{"id": "whole", "canonical_id": id,
						"type": "atomic", "canonical": label, "surface": label, "break_offsets": []}]}}
		var expression_ids: Array = []
		for group in range(10):
			var id: String = "synthetic.expression.%02d" % group
			var focuses: Array = []
			var tokens: Array = []
			var text := ""
			for index in range(group, 45, 10):
				if not text.is_empty(): text += " "
				var label: String = lexemes[synthetic_ids[index]].text
				var start: int = text.length()
				text += label
				tokens.append({"index": tokens.size(), "text": label, "start": start, "end": text.length()})
				focuses.append(synthetic_ids[index])
			expression_ids.append(id)
			expressions[id] = {"id": id, "text": text, "review": _review(), "focus_lexeme_ids": focuses,
				"media": {"audio": _descriptor(surrounding_audio)}, "tokens": tokens}
		course_data = {"id": "retail", "title": "SYNTHETIC", "curriculum_revision": REVISION,
			"theme_id": "professional_retail", "modules": [{"id": "module03", "title": "Card-reader comparison",
				"status": "ready", "requirements_revision": REVISION, "lexeme_ids": ids, "expression_ids": expression_ids}]}
	func _review() -> Dictionary:
		return {"status": "reviewed", "language": "reviewed", "domain": "not_required", "reviewer": "Synthetic comparison fixture only"}
	func _descriptor(metadata: Dictionary) -> Dictionary:
		return {"status": "integrated", "path": "res://" + str(metadata.path), "sha256": metadata.sha256,
			"source": "Exact pinned fixture media; see fixture-media.json", "creator": "Fixture descriptor; original credit retained in source records",
			"license": "Original source designation retained; this descriptor is not a production approval",
			"review": {"status": "reviewed", "reviewer": "Synthetic comparison fixture only"}, "picture_suitable": true}
	func load_index() -> bool: return true
	func courses() -> Array:
		return [{"id": "retail", "title": "SYNTHETIC", "description": "Comparison only; real Retail03 remains draft.", "theme_id": "professional_retail"}]
	func course(id: String) -> Dictionary:
		return course_data.duplicate(true) if id == "retail" else {}
	func theme_profile(id: String) -> Dictionary:
		return {"id": id, "title": "Synthetic fixture; real Retail palette only", "palette": palette.duplicate(true), "art": {}}
	func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
		var result: Dictionary = Resolver.resolve_professional(context, course_data, lexemes, expressions, seed_value)
		if result.get("ok", false):
			result.media_manifest = manifest.duplicate(true)
			result.required_resource_ids = []
			for metadata: Dictionary in manifest.resources: result.required_resource_ids.append(metadata.id)
			result.theme_profile = theme_profile(str(course_data.theme_id))
		return result

var app
var output := "res://build/professional-english/card-reader-review-20261020/captures-r01"
var private_user_root := ""
var input_pins: Array[Dictionary] = []
var fixture: Dictionary = {}
var originals: Dictionary = {}
var catalog: ReviewCatalog
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var source_checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var lifecycle: Array[Dictionary] = []
var coverage: Dictionary = {}
var started := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "check": label})
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
	return ok

func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _rgba_hash(source: Image) -> String:
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	return _hash(image.get_data())

func _path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()

func _res_path(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("..") and not path.contains("\\")

func _pin(pin: Dictionary, stage: String) -> bool:
	var path: String = str(pin.get("path", ""))
	var exists: bool = not path.is_empty() and FileAccess.file_exists(path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()
	var digest: String = _hash(bytes)
	var matches: bool = exists and (pin.get("bytes") is float or pin.get("bytes") is int)
	matches = matches and bytes.size() == int(pin.get("bytes", -1)) and digest == pin.get("sha256")
	source_checks.append({"stage": stage, "path": path, "exists": exists, "bytes": bytes.size(), "sha256": digest, "matches": matches})
	return _check(matches, stage + " pin: " + path)

func _open_run() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--results-dir="): output = argument.trim_prefix("--results-dir=")
		elif argument.begins_with("--private-user-root="): private_user_root = argument.trim_prefix("--private-user-root=")
	if not _check(_res_path(output) and output.begins_with("res://build/professional-english/"), "Results stay in the local Professional build directory"): return false
	var project: String = _path(ProjectSettings.globalize_path("res://"))
	var private_root: String = _path(ProjectSettings.globalize_path(private_user_root))
	var actual_user: String = _path(OS.get_user_data_dir())
	if not _check(not private_user_root.is_empty() and private_root.begins_with(project + "/build/") and actual_user.begins_with(private_root + "/"), "Godot uses the explicitly supplied private build user directory"): return false
	if not _check(not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output), "Results directory is new; previous attempts are preserved"): return false
	return _check(DirAccess.make_dir_recursive_absolute(output) == OK, "Fresh results directory created")

func _capture_input_pins() -> bool:
	# Record the current checkout rather than replaying historical snapshot bindings.
	# Immutable asset bytes are separately verified against their acquisition identities.
	var paths: Array[String] = [FIXTURE_PATH, "res://tools/capture-professional-card-reader.gd",
		"res://project.godot", "res://scenes/main.tscn", str(fixture.lexemes_source),
		"res://data/professional/catalog.json", "res://data/professional/courses/retail.json",
		"res://data/professional/themes.json", "res://data/professional/domain-policy/generated/index.json",
		"res://data/professional/domain-policy/generated/release.json", "res://data/professional/domain-policy/generated/themes.json",
		"res://data/vocabulary-packs.json", "res://data/word-motion.json",
		"res://tests/godot/player_flow_fixture.gd", "res://tests/godot/professional_round_loader_tests.gd"]
	for name: String in DirAccess.get_files_at("res://scripts"):
		if name.ends_with(".gd"): paths.append("res://scripts/" + name)
	for path: String in fixture.provenance_files: paths.append(path)
	for row: Dictionary in fixture.resources: paths.append(str(row.source))
	paths.sort()
	for path: String in paths:
		if not _check(FileAccess.file_exists(path), "Current source exists: " + path): return false
		input_pins.append({"path": path, "bytes": FileAccess.get_file_as_bytes(path).size(), "sha256": FileAccess.get_sha256(path)})
	var original: Dictionary = fixture.candidate_provenance.original
	if not _pin(original, "acquired-original"): return false
	return _verify_inputs("before-native")

func _verify_inputs(stage: String) -> bool:
	var before: int = failures.size()
	for row: Dictionary in input_pins: _pin(row, stage)
	return failures.size() == before

func _source_contract() -> bool:
	var before: int = failures.size()
	var lexemes: Dictionary = _json(str(fixture.lexemes_source))
	for expected: Dictionary in fixture.entries:
		var matches: Array = lexemes.get("lexemes", []).filter(func(row: Dictionary) -> bool: return row.get("id") == expected.id)
		if _check(matches.size() == 1, "Exact source lexeme: " + str(expected.id)):
			originals[expected.id] = matches[0].duplicate(true)
	if failures.size() != before: return false
	var reader: Dictionary = originals[READER]
	_check(reader.text == "card reader" and reader.definition == "A device that reads payment information from a bank card." and reader.example == "The customer held a card near the card reader.", "Exact reviewed reader sense, definition and example")
	_check(reader.media.image.status == "pending" and reader.media.image.path == null and reader.media.image.review.status == "pending", "Real card-reader image remains unintegrated and unaccepted")
	_check(reader.media.audio.sha256 == "acd48c920c631906e6ff0775cf3f373c247687fcb128b41e3ce0f3bdf668ba45" and reader.media.audio.voice == "ava-sweet", "Approved reader audio identity retained without new approval")
	var voice: Dictionary = reader.media.audio.get("voice_settings", {})
	_check(voice.get("voice") == "en-US-AvaNeural" and voice.get("rate") == "-15%" and voice.get("pitch") == "+8Hz" and voice.get("volume") == "+0%" and voice.get("postprocessing") == false, "Exact approved Ava settings remain unchanged")
	var provenance: Dictionary = fixture.candidate_provenance
	_check(reader.media.image.brief == provenance.original_picture_brief, "Production brief remains the preserved original")
	_check(fixture.resources[0].metadata.sha256 == "67cb3e6f8e0be881b51a7d18ecc28fd1a02fab6b650197a8d60ef9d550b07c59", "Exact independently reviewed derivative")
	var real := Catalog.new()
	if not _check(real.load_index(), "Actual baseline catalog loads"): return false
	var course: Dictionary = real.course("retail")
	for mode: String in ["match", "memory", "pop", "jelly", "word_jelly", "phrase"]:
		var resolved: Dictionary = real.resolve(Context.professional("retail", "module03", str(course.get("curriculum_revision", "")), mode), 42)
		_check(not resolved.get("ok", false) and resolved.get("code") == "content_pending", "Real Retail03 still fails closed: " + mode)
	catalog = ReviewCatalog.new(originals, fixture, real.theme_profile("professional_retail"))
	for row: Dictionary in fixture.entries:
		var source: Dictionary = originals[row.id]
		var scoped: Dictionary = catalog.lexemes[row.id]
		_check(scoped.definition == source.definition and scoped.example == source.example and scoped.morphology == source.morphology and scoped.media.audio == source.media.audio, "Private fixture preserves exact language, morphology and audio: " + str(row.id))
		if row.id != READER:
			_check(scoped.media.image == source.media.image, "Existing image descriptor is unchanged: " + str(row.id))
	_check(Manifest.validate_manifest(catalog.manifest).get("ok", false), "Private manifest uses actual media schema and budgets")
	_check(fixture.resources.size() == 10 and catalog.manifest.resources.size() == 10, "Exactly five pinned images and five unchanged WAVs")
	_check(Connections.PAIR_COLORS.size() == 5, "Exactly five production Match pair colors")
	for mode: String in ["match", "memory"]:
		var resolved: Dictionary = catalog.resolve(Context.professional("retail", "module03", REVISION, mode), 42)
		if not _check(resolved.get("ok", false), "Actual resolver accepts private fixture for " + mode): continue
		_check(resolved.module_words.size() == 50 and resolved.words.size() == 5, "Only five real comparison/support senses reach " + mode)
		for row: Dictionary in fixture.entries:
			_check(resolved.words.any(func(word: Dictionary) -> bool: return word.id == row.id), "Fixture pool includes " + str(row.id) + " for " + mode)
	return failures.size() == before

func _delivery() -> bool:
	var target: String = output.path_join("delivery")
	if not _check(DirAccess.make_dir_recursive_absolute(target.path_join("professional-media")) == OK, "Private raw delivery created"): return false
	for row: Dictionary in fixture.resources:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(str(row.source))
		if not _check(bytes.size() == int(row.metadata.compressed_bytes) and _hash(bytes) == row.metadata.sha256, "Exact fixture source: " + str(row.metadata.id)): return false
		if row.lexeme_id != READER or row.metadata.kind != "image":
			if not _check(originals[row.lexeme_id].media[row.metadata.kind].sha256 == row.metadata.sha256, "Existing descriptor identity: " + str(row.metadata.id)): return false
		var file := FileAccess.open(target.path_join(str(row.metadata.path)), FileAccess.WRITE)
		if not _check(file != null, "Private sidecar writable: " + str(row.metadata.id)): return false
		file.store_buffer(bytes)
		file.close()
	return true

func _settle(frames: int = 8) -> void:
	for unused in range(frames): await process_frame
	await RenderingServer.frame_post_draw

func _wait_play(mode: String) -> bool:
	for unused in range(360):
		await process_frame
		if app.professional.phase == "failed" or app.professional.session.snapshot().blocked: return false
		if app._round_context.get("curriculum_revision") == REVISION and app._mode_id == mode and not app._mode_menu_open() and app.professional.can_play(app._round_id): return true
	return false

func _inspect_scope(scope: String) -> Dictionary:
	var weak_references: Array = []
	var decoded: Array = []
	var urls: Array = []
	for row: Dictionary in fixture.resources:
		var path: String = Access.path(scope, str(row.metadata.sha256))
		var resource: Resource = Access.resource(path)
		if not _check(resource != null, "Scoped resource resolves: " + path): continue
		weak_references.append(weakref(resource))
		urls.append(path)
		if row.metadata.kind == "image":
			var texture: Texture2D = resource as Texture2D
			if not _check(texture != null, "Actual loader returns a texture: " + path): continue
			_check(texture.get_size() == Vector2(row.metadata.width, row.metadata.height), "Exact native decoded dimensions: " + path)
			_check(WordArt.texture(path) == texture, "WordArt returns actual leased texture: " + path)
			var original: Image = Image.load_from_file(output.path_join("delivery").path_join(str(row.metadata.path)))
			if not _check(original != null and not original.is_empty(), "Source PNG decodes independently: " + path): continue
			var expected: String = _rgba_hash(original)
			# ANGLE can return a one-level channel difference only after a texture
			# has been drawn. Compare like-for-like renderer readbacks without a
			# tolerance, while independently requiring exact pre-render upload.
			var reference := ImageTexture.create_from_image(original)
			var uploaded: String = _rgba_hash(reference.get_image())
			_check(uploaded == expected, "Independent reference upload exactly preserves source RGBA: " + path)
			var reference_view := TextureRect.new()
			reference_view.texture = reference
			reference_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			reference_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			reference_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reference_view.size = Vector2(120, 80)
			root.add_child(reference_view)
			# Memory starts with hidden faces, so its real texture may not have
			# been drawn yet. Draw both references through the same path without
			# consuming a peek or changing any card/model state.
			var loaded_view := TextureRect.new()
			loaded_view.texture = texture
			loaded_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			loaded_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			loaded_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			loaded_view.position = Vector2(120, 0)
			loaded_view.size = Vector2(120, 80)
			root.add_child(loaded_view)
			await _settle()
			var rendered_reference: String = _rgba_hash(reference.get_image())
			var actual_image: Image = texture.get_image()
			var actual: String = _rgba_hash(actual_image)
			reference_view.queue_free()
			loaded_view.queue_free()
			await _settle()
			_check(actual == rendered_reference, "Raw-loader readback exactly equals independently rendered source: " + path)
			var observation: Dictionary = {"lexeme_id": row.lexeme_id, "scope_url": path, "width": texture.get_width(), "height": texture.get_height(), "source_rgba_sha256": expected, "decoded_rgba_sha256": actual,
				"reference_upload_rgba_sha256": uploaded, "reference_rendered_rgba_sha256": rendered_reference,
				"renderer_readback_differs_from_source": rendered_reference != expected,
				"pixel_comparison": "Exact raw-source upload, then exact actual-versus-independent post-render readbacks; no numerical tolerance or alpha normalization",
				"source_format": original.get_format(), "decoded_format": actual_image.get_format(),
				"source_mipmaps": original.has_mipmaps(), "decoded_mipmaps": actual_image.has_mipmaps(),
				"source_data_bytes": original.get_data_size(), "decoded_data_bytes": actual_image.get_data_size()}
			if actual != expected:
				var diagnostic: String = "source-readback-" + scope + "-" + str(row.lexeme_id)
				observation["expected_pixels"] = diagnostic + "-expected.png"
				observation["actual_pixels"] = diagnostic + "-actual.png"
				_check(original.save_png(output.path_join(str(observation.expected_pixels))) == OK, "Source pixels retained for readback diagnostic")
				_check(actual_image.save_png(output.path_join(str(observation.actual_pixels))) == OK, "Actual post-render pixels retained for readback diagnostic")
			decoded.append(observation)
		else:
			_check(resource is AudioStreamWAV, "Unchanged existing WAV uses the real decoder: " + path)
	return {"weak_references": weak_references, "urls": urls, "decoded_images": decoded}

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _clip(control: Control) -> Rect2:
	var visible := Rect2(Vector2.ZERO, Vector2(root.size))
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents: visible = visible.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return visible

func _card(id: String, kind: String, mode: String):
	if mode == "match": return app.cards.get(id + ":" + kind)
	for button in app._memory.card_buttons:
		if button.card_data.word.id == id and button.card_data.kind == kind: return button
	return null

func _card_observation(card, mode: String) -> Dictionary:
	var id: String = card.card_data.word.id
	var image: bool = card.card_data.kind == "image"
	var matched: bool = app.model.matched_ids.has(card.card_data.id) if mode == "match" else app._memory.memory.matched_word_ids.has(id)
	var selected: bool = app.model.selected_id == card.card_data.id if mode == "match" else app._memory.memory.selected_indices.has(app._memory.card_buttons.find(card)) and not matched and app._memory.memory.phase != "feedback"
	var pair: Dictionary = {}
	if mode == "match":
		for value: Dictionary in app._match_connections.connections:
			if value.id == id: pair = value
	var lane: int = int(pair.get("lane", -1))
	var pair_focused: bool = mode == "match" and matched and app._match_connections.focused_id == id
	var tint: Color = pair.get("color", Style.GOOD)
	var normal: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	var fill := Color("#fffef9")
	if selected: fill = app._active_palette.accent.lightened(0.86)
	elif matched: fill = tint.lightened(0.85 if pair_focused else 0.96) if lane >= 0 else Color("#e7f5e9")
	_check(normal != null and normal.bg_color.is_equal_approx(fill), "Actual caller fill: " + id + "/" + str(card.card_data.kind))
	_check(_clip(card).grow(1.0).encloses(card.get_global_rect()), "Complete card within actual viewport/clips: " + id + "/" + str(card.card_data.kind))
	_check(card.scale == Vector2.ONE and card.get_node("CardFace").scale == Vector2.ONE, "Settled reduced-motion card has unit scale: " + id)
	_check(is_equal_approx(Style.ui_scale(card), 1.0), "Native viewport uses one physical pixel per layout unit: " + id)
	_check(not card.is_hovered(), "No pointer hover contaminates the caller sample: " + id)
	var expected_disabled: bool = false if mode == "match" else matched or app._memory.memory.studying or app._memory._paused or not app._memory.is_visible_in_tree() or not app._memory.memory.phase in ["waiting", "matching", "feedback"]
	_check(card.disabled == expected_disabled, "Actual caller disabled state: " + id)
	_check(card.match_mark.visible == (matched and image), "Production picture-only matched badge: " + id + "/" + str(card.card_data.kind))
	_check(card.match_mark.pair_number == (lane + 1 if matched else 0), "Production badge number or generic Memory mark: " + id)
	_check(card.match_mark.active == pair_focused, "Production pair-focus flag: " + id)
	_check(is_equal_approx(card.picture.modulate.a, 1.0), "Actual caller keeps the image fully opaque: " + id)
	var texture: Texture2D = card.picture.texture
	_check(texture != null and texture == Access.resource(str(card.card_data.word.image)), "Actual card retains exact leased texture: " + id)
	var source := Vector2.ZERO if texture == null else texture.get_size()
	var box: Rect2 = card.picture.get_global_rect()
	var displayed := Rect2()
	if texture != null:
		var factor: float = minf(box.size.x / source.x, box.size.y / source.y)
		displayed = Rect2(box.position + (box.size - source * factor) * 0.5, source * factor)
		_check(card.picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Whole-source contain fit: " + id)
		_check(is_equal_approx(card.picture.get_global_transform().get_scale().x, card.picture.get_global_transform().get_scale().y), "No anisotropic image scale: " + id)
		if image and card.picture.is_visible_in_tree():
			_check(factor > 0 and _clip(card.picture).grow(1.0).encloses(displayed), "Visible whole image fits actual clipping ancestors: " + id)
	if not image and card.word_label.is_visible_in_tree():
		_check(card.word_label.text == card.card_data.word.text and card.word_label.get_visible_line_count() >= card.word_label.get_line_count(), "Complete term label remains visible: " + id)
	if mode == "match" and matched:
		_check(lane >= 0 and lane < Connections.PAIR_COLORS.size() and tint.is_equal_approx(Connections.PAIR_COLORS[lane]), "Actual Match connection supplies pair color: " + id)
		var key: String = "%dx%d:%s:%d:%s" % [root.size.x, root.size.y, id, lane, pair_focused]
		coverage[key] = true
	return {"lexeme_id": id, "kind": card.card_data.kind, "card_bounds": _rect(card.get_global_rect()),
		"picture_bounds": _rect(box), "displayed_source_bounds": _rect(displayed), "source_pixels": [source.x, source.y],
		"visible_clip": _rect(_clip(card)), "face_up": card.face_up, "picture_visible": card.picture.is_visible_in_tree(),
		"matched": matched, "selected": selected, "pair_lane": lane, "pair_tint": tint.to_html(), "pair_focused": pair_focused,
		"badge_visible": card.match_mark.visible, "badge_bounds": _rect(card.match_mark.get_global_rect()), "fill": normal.bg_color.to_html() if normal != null else "",
		"picture_alpha": card.picture.modulate.a, "disabled": card.disabled, "keyboard_focus": card.has_focus(), "pointer_hover": card.is_hovered(), "ui_scale": Style.ui_scale(card),
		"scope_url": str(card.card_data.word.image), "recognition_and_cue_acceptance": "pending independent image inspection; no participant recognition claim"}

func _save_png(name: String, image: Image, stage: String, detail: Dictionary) -> void:
	var path: String = output.path_join(name)
	if not _check(not FileAccess.file_exists(path), "Preserve exclusive PNG output: " + name): return
	if not _check(image.save_png(path) == OK, "Actual PNG saved: " + name): return
	captures.append({"file": name, "sha256": FileAccess.get_sha256(path), "rgba_sha256": _rgba_hash(image),
		"width": image.get_width(), "height": image.get_height(), "stage": stage, "detail": detail,
		"acceptance": "Synthetic technical fixture; independent visual review pending"})

func _capture(prefix: String, mode: String, stage: String) -> void:
	await _settle()
	var observed: Array = []
	for kind: String in ["image", "word"]:
		for id: String in SUBJECTS:
			var card = _card(id, kind, mode)
			if not _check(card != null, "Actual board contains " + id + "/" + kind): continue
			observed.append(_card_observation(card, mode))
	var screen: Image = root.get_texture().get_image()
	_check(screen.get_size() == root.size, "Actual viewport pixel dimensions: " + prefix + "/" + stage)
	var detail: Dictionary = {"mode": mode, "viewport": [root.size.x, root.size.y], "cards": observed,
		"state_scope": "actual_app_caller_on_private_synthetic_fixture", "synthetic_readiness": true,
		"real_retail03_ready": false, "motion": "Explicit reduced motion; static presentation only"}
	_save_png(prefix + "-" + mode + "-" + stage + ".png", screen, stage, detail)

func _match_states(prefix: String) -> void:
	await _capture(prefix, "match", "unmatched")
	app._select_card(READER + ":image")
	await _capture(prefix, "match", "selected-reader")
	app._select_card(READER + ":image")
	for id: String in SUBJECTS:
		app._select_card(id + ":image")
		app._select_card(id + ":word")
		_check(app.model.last_correct and app.model.matched_ids.has(id + ":image"), "Actual Match caller accepts the fixture pair: " + id)
		app._resolve_feedback()
		if not _check(await _wait_play("match"), "Private session settles after Match pair: " + id): return
	# Two focus states show the reader both emphasized and settled beside the
	# register, using the real pair-focus caller and unchanged natural deal order.
	for id: String in [READER, "cash-register.sales-device.n"]:
		app._select_card(id + ":image")
		_check(app._match_connections.focused_id == id, "Matched-card caller focuses exact pair: " + id)
		await _capture(prefix, "match", "matched-focus-reader" if id == READER else "matched-focus-register")

func _memory_index(id: String, kind: String) -> int:
	for index in range(app._memory.memory.cards.size()):
		var card: Dictionary = app._memory.memory.cards[index]
		if card.word.id == id and card.kind == kind: return index
	return -1

func _memory_states(prefix: String) -> void:
	await _capture(prefix, "memory", "backs")
	app._memory.begin_peek()
	_check(app._memory.memory.studying, "Actual Memory first peek reveals unmatched pictures")
	await _capture(prefix, "memory", "peek-unmatched")
	app._memory.end_peek()
	var selected: int = _memory_index(READER, "image")
	if not _check(selected >= 0, "Reader image exists in Memory deal"): return
	app._memory._choose(selected)
	app._memory.card_buttons[selected].grab_focus()
	await _capture(prefix, "memory", "selected-reader")
	app._memory._choose(selected)
	for id: String in SUBJECTS:
		var image_index: int = _memory_index(id, "image")
		var word_index: int = _memory_index(id, "word")
		if not _check(image_index >= 0 and word_index >= 0, "Both Memory partners exist: " + id): return
		app._memory._choose(image_index)
		app._memory._choose(word_index)
		_check(app._memory.memory.last_correct and app._memory.memory.matched_word_ids.has(id), "Actual Memory caller accepts the fixture pair: " + id)
		app._memory.continue_feedback()
		if not _check(await _wait_play("memory"), "Private session settles after Memory pair: " + id): return
	await _capture(prefix, "memory", "matched-three")

func _case(dimensions: Vector2i, mode: String) -> void:
	root.size = dimensions
	await _settle()
	var prefix: String = "%dx%d" % [dimensions.x, dimensions.y]
	_check(root.size == dimensions, "Requested actual native window size: " + prefix)
	var saves: String = output.path_join("saves").path_join(prefix + "-" + mode)
	DirAccess.make_dir_recursive_absolute(saves)
	app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, saves)
	app.medal_progress = Medal.new(saves + "/medals.cfg", saves + "/legacy.cfg")
	app._presentation.path = saves + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	var media := ReviewMedia.new()
	media.delivery_root = ProjectSettings.globalize_path(output.path_join("delivery"))
	app.professional.loader.media = media
	app.professional.loader.catalog = catalog
	app.professional.loader._owner.free()
	app.professional.loader._owner = OwnerFixture.FixtureOwner.new(catalog)
	root.add_child(app)
	await _settle(20)
	# Readiness reloads the OS motion default; set and verify this case afterward.
	app.set_reduced_motion(true)
	app._show_mode_menu()
	app._select_learning_context(Context.professional("retail", "module03", REVISION, mode))
	app.choose_mode(mode)
	var ready: bool = await _wait_play(mode)
	_check(ready, prefix + " actual " + mode + " app opens a private synthetic session")
	var inspected: Dictionary = {"weak_references": [], "urls": [], "decoded_images": []}
	var cache = media.cache
	var loaded: Dictionary = {}
	var lease_only: Dictionary = {}
	if ready:
		await _settle()
		_check(app.reduced_motion and app._memory.reduced_motion, "Explicit reduced motion selected after readiness")
		_check(app._professional_heading.text.contains("SYNTHETIC"), "Actual game header declares synthetic readiness")
		_check(not media.fetch_override.is_valid(), "Real native media loader has no fetch injection")
		_check(app._round_content.words.size() == 5 and app.model.lesson_words.size() == 5, "Actual board uses exactly five fixture senses")
		inspected = await _inspect_scope(str(app._round_content.media_scope))
		loaded = cache.stats()
		var total: int = int(fixture.total_decoded_bytes)
		_check(loaded.resources == 10 and loaded.resident_bytes == total and loaded.pinned_bytes == total and loaded.leases == 1 and loaded.reserved_bytes == 0, "Actual cache has ten exact resources, bytes and one lease")
		var active: Array = loaded.active_ids.duplicate()
		var required: Array = catalog.manifest.resources.map(func(row: Dictionary): return row.id)
		active.sort()
		required.sort()
		_check(active == required, "Only exact fixture resources are active")
		cache.deactivate()
		cache.trim_inactive()
		lease_only = cache.stats()
		_check(lease_only.resources == 10 and lease_only.resident_bytes == total and lease_only.pinned_bytes == total and lease_only.leases == 1 and lease_only.active_ids.is_empty(), "Lease alone retains all resources after deactivate and trim")
		for path: String in inspected.urls: _check(Access.resource(path) != null, "Lease-only resource stays resolvable: " + path)
		Input.warp_mouse(Vector2(dimensions) - Vector2.ONE)
		if mode == "match": await _match_states(prefix)
		else: await _memory_states(prefix)
	app.audio.halt()
	app.professional.close()
	for path: String in inspected.urls: _check(Access.resource(path) == null, "Closed scope cannot resolve former resource: " + path)
	cache.deactivate()
	cache.trim_inactive()
	var closed: Dictionary = cache.stats()
	_check(closed.resources == 0 and closed.resident_bytes == 0 and closed.pinned_bytes == 0 and closed.reserved_bytes == 0 and closed.leases == 0 and closed.active_ids.is_empty(), "Closing releases all cache ownership and budgets")
	app.queue_free()
	await _settle()
	app = null
	for weak in inspected.weak_references: _check(weak.get_ref() == null, "No decoded resource survives teardown as a strong reference")
	lifecycle.append({"viewport": prefix, "mode": mode, "opened": ready, "loaded_cache": loaded, "lease_only_cache": lease_only,
		"closed_cache": closed, "decoded_images": inspected.decoded_images, "weak_references_checked": inspected.weak_references.size()})
	_verify_inputs("after-" + prefix + "-" + mode)

func _finish() -> void:
	var report: Dictionary = {"schema": 1, "status": "technical_comparison_passed_pending_independent_visual_review" if failures.is_empty() else "failed_attempt_preserved",
		"started_utc": started, "finished_utc": Time.get_datetime_string_from_system(true),
		"fixture": FIXTURE_PATH, "input_pins": input_pins, "candidate_provenance": fixture.get("candidate_provenance", {}),
		"baseline_semantics": "Exact current source bytes are recorded before native work and checked afterward; no historical wrapper or receipt is replayed.",
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(),
		"actual_user_data_directory": OS.get_user_data_dir(), "checks": checks, "failures": failures, "source_checks": source_checks,
		"captures": captures, "lifecycle": lifecycle, "match_lane_focus_coverage": coverage,
		"scope": "Actual responsive Match/Memory callers, unchanged production deal order, two real Match focus states, and raw-media lifecycle in a private synthetic fixture. The capture matrix is not exhaustive lane-color or participant-recognition coverage.",
		"limits": {"synthetic_readiness": true, "synthetic_review_flags": true, "whole_animation_review": false, "physical_device_review": false,
			"human_recognition": false, "human_visual_acceptance": false, "final_exercise_suitability": false, "production_image_integration": false,
			"audio_approval_changed": false, "new_listening_or_mix_acceptance": false, "course_or_release_readiness": false}}
	var path: String = output.path_join("report.json")
	if FileAccess.file_exists(path):
		printerr("Refusing to replace an existing native report")
		quit(2)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write native comparison report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Card-reader native comparison: %d checks, %d failures; %d PNGs" % [checks.size(), failures.size(), captures.size()])
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	started = Time.get_datetime_string_from_system(true)
	if not _open_run():
		quit(2)
		return
	fixture = _json(FIXTURE_PATH)
	if not _check(fixture.get("entries") is Array and fixture.get("resources") is Array and fixture.get("provenance_files") is Array and fixture.get("candidate_provenance") is Dictionary and fixture.get("lexemes_source") is String, "Fixture metadata has the required schema"):
		_finish()
		return
	if not _check(DisplayServer.get_name() != "headless", "Actual non-headless renderer required") or not _capture_input_pins():
		_finish()
		return
	if not _source_contract() or not _delivery():
		_finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.title = "SYNTHETIC FIXTURE - card-reader caller comparison"
	for dimensions: Vector2i in SIZES:
		for mode: String in ["match", "memory"]:
			await _case(dimensions, mode)
			if not failures.is_empty():
				_finish()
				return
	for dimensions: Vector2i in SIZES:
		var prefix: String = "%dx%d" % [dimensions.x, dimensions.y]
		for id: String in [READER, "cash-register.sales-device.n"]:
			for focused: bool in [false, true]:
				var found := false
				for lane in range(5):
					if coverage.has("%s:%s:%d:%s" % [prefix, id, lane, focused]): found = true
				_check(found, "Actual caller covers focused and settled comparison: %s/%s/%s" % [prefix, id, focused])
	_check(captures.size() == 32, "Exactly 32 meaningful board captures across four viewports")
	_check(lifecycle.size() == 8, "All four viewports and both actual caller modes completed")
	_verify_inputs("after-native")
	_finish()
