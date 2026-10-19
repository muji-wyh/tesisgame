extends SceneTree
## Actual persisted image descriptor, raw sidecar, cache lease and WordCard consumer.
const BASE := "res://build/professional-english/retail-term-art-review/shopping-cart"
const DURABLE := "res://docs/assets/sources/kenney-mini-market-retail-terms/shopping-cart"
const ID := "shopping-cart.store-trolley.n"
const DIGEST := "b24c30c83f5b1a73cbee18b746ab96801bd01f91d3e7da5b40eb8bc9e260a5d1"
const LEXEMES := "res://data/professional/lexemes/retail-pilot.json"
const LEXEMES_SHA := "12c40ed580248dcdecbfa7504ef57e33c792c8ba8a4a250bebf2c722b5cb1f3b"
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
var output := BASE + "/production-verification"

func _initialize() -> void: _run.call_deferred()
func _json(file: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(file))
func _check(ok: bool, label: String) -> void:
	checks.append({"check": label, "passed": ok})
	if not ok: push_error(label)
func _settle(count: int = 4) -> void:
	for frame in range(count): await process_frame
func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 14) -> void:
	var label := Style.label(text, font_size)
	label.position = at
	label.size = dimensions
	root.add_child(label)

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(704, 250)
	var hashes := {}
	for file: String in [LEXEMES, "res://data/professional/courses/retail.json", "res://data/professional/themes.json", "res://data/professional/references.json"]:
		if FileAccess.file_exists(file): hashes[file] = FileAccess.get_sha256(file)
	_check(hashes[LEXEMES] == LEXEMES_SHA, "Production lexeme file matches serialized accepted image checkpoint")
	var entry: Dictionary = {}
	for value: Dictionary in _json(LEXEMES).lexemes:
		if value.id == ID: entry = value
	_check(not entry.is_empty(), "Actual persisted shopping-cart entry exists")
	if entry.is_empty(): quit(1); return
	var descriptor: Dictionary = entry.media.image
	_check(descriptor == _json(DURABLE + "/entry-image.after.json"), "Actual image descriptor equals exact independently accepted descriptor")
	_check(entry.editorial_notes == _json(DURABLE + "/editorial-note.delta.json").after, "Actual entry retains the exact approved image/audio note")
	_check(descriptor.status == "integrated" and descriptor.acquisition_status == "integrated" and descriptor.review.status == "reviewed" and descriptor.picture_suitable, "Only persisted image has integrated scoped review and suitability")
	_check(entry.media.audio.status == "pending" and entry.media.audio.review.status == "pending", "Actual word audio remains pending")
	_check(entry.morphology.review.status == "pending", "Actual word morphology remains pending")
	_check(entry.review.language == "reviewed", "Separate persisted language review is preserved")
	var resource: Dictionary = _json(DURABLE + "/media-resource.json")
	_check(Manifest.validate_resource(resource).ok, "Permanent immutable resource descriptor obeys delivery schema")
	_check(resource.sha256 == DIGEST and descriptor.sha256 == DIGEST and descriptor.path == "res://" + resource.path, "Persisted image and immutable resource identities agree")
	_check(FileAccess.get_sha256(descriptor.path) == DIGEST, "Exact accepted bytes exist at production raw sidecar path")
	var catalog := Catalog.new()
	_check(catalog.load_index(), "Real production catalog loads")
	var course: Dictionary = catalog.course("retail")
	for module: Dictionary in course.modules:
		_check(module.status == "draft", "Actual module remains draft: " + str(module.id))
	for mode: String in ["match", "memory", "pop", "jelly", "word_jelly", "phrase"]:
		var result: Dictionary = catalog.resolve(Context.professional("retail", "module03", course.curriculum_revision, mode))
		_check(not result.ok and result.get("code") == "content_pending", "Real catalog rejects incomplete module03 for " + mode)
	var manifest: Dictionary = {"schema_version": 1, "course_id": "retail", "module_id": "shopping-cart-image-verification", "curriculum_revision": "inspection-only-v1", "resources": [resource]}
	_check(Manifest.validate_manifest(manifest).ok, "Image-only inspection inventory meets immutable budget/schema")
	var loader := Loader.new()
	root.add_child(loader)
	loader.configure(ProjectSettings.globalize_path("res://"))
	_check(not loader.fetch_override.is_valid(), "Production raw loader has no injected fetch override")
	loader.request_module(manifest, {}, [resource.id])
	var completed: Array = await loader.completed
	_check(completed[1].ok, "Real native loader reads and decodes production raw sidecar")
	if not completed[1].ok: printerr(JSON.stringify(completed[1])); quit(1); return
	var leased := Access.acquire(loader.cache, completed[1].resource_ids)
	_check(leased.ok, "Actual decoded image acquires a scoped cache lease")
	if not leased.ok: quit(1); return
	var scoped_path: String = Access.path(leased.scope, DIGEST)
	var texture: Texture2D = Access.resource(scoped_path) as Texture2D
	_check(texture != null and texture.get_size() == Vector2(512, 415), "Real scoped image has exact accepted dimensions")
	_check(WordArt.texture(scoped_path) == texture, "Production WordArt resolves the actual scoped cache resource")
	var loaded: Dictionary = loader.cache.stats()
	_check(loaded.resources == 1 and loaded.resident_bytes == 1699840 and loaded.pinned_bytes == 1699840 and loaded.leases == 1, "Real cache accounts for one image, exact decoded budget and one lease")
	var background := ColorRect.new()
	background.color = Color("f6f3e9")
	background.size = Vector2(root.size)
	root.add_child(background)
	_label("Shopping cart | actual production media in minimum WordCard", Vector2(16, 10), Vector2(680, 24), 19)
	_label("Persisted image descriptor, raw native loader, scoped cache and real WordArt lookup. No audio or module override.", Vector2(16, 38), Vector2(680, 24), 12)
	var palette: Dictionary = Data.theme("spring")
	var profile: Dictionary = catalog.theme_profile("professional_retail")
	for key in profile.palette: palette[key] = Color(str(profile.palette[key]))
	var cards: Array = []
	for index in range(4):
		var memory: bool = index >= 2
		var matched: bool = index % 2 == 1
		var at := Vector2(16 + index * 172, 92)
		_label(("Memory" if memory else "Match") + (" / matched" if matched else " / unmatched"), Vector2(at.x, 67), Vector2(170, 20), 13)
		var card := Card.new()
		# This isolated image presentation uses persisted identity/text and the real
		# cache URL. Missing audio is not fabricated, and no complete round is bound.
		card.setup({"id": "shopping-cart-" + str(index), "kind": "image", "word": {"id": entry.id, "text": entry.text, "track": "professional", "image": scoped_path, "audio": ""}})
		root.add_child(card)
		card.custom_minimum_size = Vector2.ZERO
		card.set_reduced_motion(true)
		if memory: card.set_back(Control.new())
		card.set_face_up(true, false)
		card.position = at
		card.size = Vector2(144, 74) if memory else Vector2(126, 72)
		card.refresh(palette, false, matched, false, false, false, 0)
		_check(card.picture.texture == texture, "Actual WordCard setup receives cache resource via WordArt: " + str(index))
		cards.append(card)
		_label("144 x 74 | art 120 x 54" if memory else "126 x 72 | art 102 x 52", Vector2(at.x, 176), Vector2(170, 24), 12)
	_label("All four card crops are compared byte-for-byte with the independently accepted native candidate card captures.", Vector2(16, 218), Vector2(685, 20), 12)
	Input.warp_mouse(Vector2(700, 246))
	await _settle(5)
	await RenderingServer.frame_post_draw
	var contact: Image = root.get_texture().get_image()
	_check(contact.save_png(output + "/actual-production-word-card-contact.png") == OK, "Production card contact saved")
	for index in range(cards.size()):
		var card = cards[index]
		var name: String = ("memory" if index >= 2 else "match") + ("-matched" if index % 2 == 1 else "-unmatched")
		var region: Image = contact.get_region(Rect2i(Vector2i(card.position), Vector2i(card.size)))
		_check(region.save_png(output + "/" + name + ".png") == OK, "Production crop saved: " + name)
		var accepted := Image.load_from_file(BASE + "/candidate/" + name + ".png")
		region.convert(Image.FORMAT_RGBA8)
		accepted.convert(Image.FORMAT_RGBA8)
		var equal := region.get_size() == accepted.get_size() and region.get_data() == accepted.get_data()
		_check(equal, "Real production card pixels equal accepted native candidate: " + name)
		captures.append({"state": name, "pixels_equal_accepted": equal, "size": [card.size.x, card.size.y], "badge_visible": card.match_mark.visible, "picture_alpha": card.picture.modulate.a})
	for card in cards: card.queue_free()
	cards.clear()
	texture = null
	await _settle()
	Access.release(leased.scope)
	loader.cache.deactivate()
	loader.cache.trim_inactive()
	var released: Dictionary = loader.cache.stats()
	_check(released.resources == 0 and released.resident_bytes == 0 and released.pinned_bytes == 0 and released.leases == 0, "Production cache teardown releases all resources, bytes and leases")
	_check(Access.resource(scoped_path) == null and WordArt.texture(scoped_path) == null, "Released media URL cannot revive the accepted image")
	for file: String in hashes: _check(FileAccess.get_sha256(file) == hashes[file], "Production metadata remains unchanged by verifier: " + file)
	var failed: Array = checks.filter(func(item): return not item.passed)
	var report: Dictionary = {"scope": "Actual persisted shopping-cart image descriptor and production raw sidecar through native Loader, cache, scoped Access and actual WordCard/WordArt. No fetch override, no image substitution, no audio fabrication, no status/review overrides. This isolated image verification is not a playable round or production module manifest.", "lexemes_sha256": LEXEMES_SHA, "production_data_hashes": hashes, "accepted_image_sha256": DIGEST, "resource": resource, "loaded_cache": loaded, "released_cache": released, "captures": captures, "checks": checks, "failed": failed.size(), "production_scripts": {"loader": FileAccess.get_sha256("res://scripts/professional_media_loader.gd"), "access": FileAccess.get_sha256("res://scripts/professional_media_access.gd"), "word_art": FileAccess.get_sha256("res://scripts/word_art.gd"), "word_card": FileAccess.get_sha256("res://scripts/word_card.gd")}}
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	loader.queue_free()
	await _settle()
	print("Cart actual production image verification: " + str(checks.size()) + " checks, " + str(failed.size()) + " failures")
	quit(0 if failed.is_empty() else 1)
