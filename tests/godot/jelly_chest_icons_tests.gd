extends SceneTree

const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/chest_tier_catalog.gd")

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []
var icons: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func renderer_count(node: Node) -> int:
	var count: int = 1 if node is SubViewport else 0
	for child: Node in node.get_children():
		count += renderer_count(child)
	return count


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	if not data.load_all():
		check(false, "Static Jelly chest checks need the integrated production catalog")
		quit(1)
		return
	words = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 9)
	check(not words.is_empty(), "Static Jelly chest checks use real pictured vocabulary")
	if words.is_empty():
		quit(1)
		return
	_check_initialization_guards()
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(root.size)
	check(view.configure(words, 3, Data.theme("spring"), data.chests, true, 42),
		"The real Jelly owner configures with immediately available closed chest art")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	_check_all_tiers(view)
	_check_selection_rules(view)
	await _check_lifecycle(view)
	_check_tap_reference(view)
	_check_queued_references(view)
	view.free()
	await process_frame
	print("Static Jelly chest icons: %d checks; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_initialization_guards() -> void:
	var detached := Jelly.new()
	check(detached._reward_texture(1) == null and detached._chest_cache.is_empty(),
		"An unconfigured detached owner does not load or cache chest art")
	detached._manifest = data.chests
	check(detached._reward_texture(1) == null and detached._chest_cache.is_empty(),
		"Supplying a manifest before tree entry retains the existing initialization guard")
	check(renderer_count(detached) == 0,
		"Detached icon requests cannot create a temporary render surface")
	detached.free()
	var unconfigured := Jelly.new()
	root.add_child(unconfigured)
	unconfigured.set_process(false)
	check(unconfigured._reward_texture(1) == null and unconfigured._chest_cache.is_empty(),
		"Tree entry without a manifest does not substitute unrelated chest artwork")
	unconfigured.free()


func _check_all_tiers(view: Jelly) -> void:
	var model_before: Dictionary = view.game.snapshot().duplicate(true)
	for tier in range(1, Catalog.MAX_TIER + 1):
		var recipe: Dictionary = Catalog.preset(tier)
		var source_id: String = str(recipe.asset_id)
		var texture: AtlasTexture = view._reward_texture(tier) as AtlasTexture
		check(texture != null, "Lv%d has a ready stable closed chest texture wrapper" % tier)
		if texture == null:
			continue
		var expected: String = "res://assets/chests/models/atelier/%s/closed-jelly.png" % source_id
		check(texture.atlas != null and not texture.atlas is ViewportTexture
			and texture.atlas.resource_path == expected,
			"Lv%d uses its exact imported Atelier closed pose immediately" % tier)
		if texture.atlas == null:
			continue
		check(texture.get_width() > 0 and texture.get_height() > 0
			and texture.region == Rect2(Vector2.ZERO, texture.atlas.get_size()) and texture.filter_clip,
			"Lv%d retains the complete baked alpha crop without another fit or inset" % tier)
		if icons.has(source_id):
			check(texture == icons[source_id],
				"Lv%d reuses its source image wrapper while keeping its independent level" % tier)
		else:
			icons[source_id] = texture
			_check_source_crop(texture, source_id)
	check(icons.size() == Catalog.MATERIAL_COUNT and view._chest_cache.size() == Catalog.MATERIAL_COUNT,
		"All ninety-nine levels own exactly twenty-eight static source images")
	check(renderer_count(view) == 0,
		"Looking up every chest material creates no nested two-dimensional or three-dimensional renderer")
	check(view.game.snapshot() == model_before,
		"Loading every closed icon cannot award fragments, chest levels, points or words")


func _check_source_crop(texture: AtlasTexture, source_id: String) -> void:
	# Imported PNG pixels are CPU-backed in headless tests too. This inspects the
	# shipped bake, never a live viewport or a replacement runtime capture path.
	var picture: Image = texture.atlas.get_image()
	check(picture != null and not picture.is_empty(),
		"The imported %s icon has readable production pixels without rendering" % source_id)
	if picture == null or picture.is_empty():
		return
	var source: Image = Image.load_from_file(texture.atlas.resource_path)
	check(source != null and picture.get_format() == source.get_format()
		and picture.get_data() == source.get_data(),
		"The %s import preserves every baked pixel without lossy compression or alpha recoloring" % source_id)
	var occupied: Rect2i = picture.get_used_rect()
	check(occupied.has_area(), "The imported %s closed pose is not transparent" % source_id)
	if not occupied.has_area():
		return
	var margin: Vector2i = picture.get_size() - occupied.end
	check(occupied.position.x <= 2 and occupied.position.y <= 2 and margin.x <= 2 and margin.y <= 2,
		"The %s icon uses the existing two-pixel alpha crop instead of a padded preview" % source_id)
	check(picture.get_width() <= 768 and picture.get_height() <= 768,
		"The %s icon preserves the bounded native Jelly capture resolution" % source_id)


func _check_selection_rules(view: Jelly) -> void:
	for alias: String in Catalog.THEME_TIERS:
		var tier: int = int(Catalog.THEME_TIERS[alias])
		check(view._chest_for_theme(alias) == view._reward_texture(tier),
			"The %s theme alias retains its selected Atelier material" % alias)
	check(view._chest_for_theme("spring", 5) == view._reward_texture(5),
		"An explicit earned tier takes precedence over a representative theme alias")
	check(view._reward_texture(0) == view._reward_texture(1)
		and view._reward_texture(100) == view._reward_texture(99)
		and view._chest_for_theme("spring", 100) == view._reward_texture(99),
		"HUD and explicit positive-tier requests retain their existing one-to-ninety-nine clamp")
	check(view._reward_texture(28) == view._reward_texture(29)
		and view._reward_texture(28) == view._reward_texture(99),
		"Every level after the last acquired material retains that final source image")
	var original_tier: int = view.game.chest_tier
	view.game.chest_tier = 17
	check(view._reward_texture() == view._reward_texture(17)
		and view._reward_texture(-2) == view._reward_texture(17),
		"Current-tier requests continue to follow the model rather than a cached level")
	view.game.chest_tier = original_tier
	check(view._chest_texture == view._reward_texture(1),
		"Board treasure markers retain the existing first-material artwork")


func _check_lifecycle(view: Jelly) -> void:
	for theme_id: String in ["winter", "candy", "spring"]:
		view.apply_theme(Data.theme(theme_id), data.chests)
		check(view._chest_texture == icons[str(Catalog.preset(1).asset_id)],
			"Refreshing the %s theme preserves references already held by board markers" % theme_id)
	view.hide()
	await process_frame
	view.show()
	await process_frame
	for tier: int in [1, 8, 28, 99]:
		check(view._reward_texture(tier) == icons[str(Catalog.preset(tier).asset_id)],
			"Returning to the visible game preserves the existing Lv%d icon reference" % tier)
	view.stop()
	check(view.configure(words, 3, Data.theme("spring"), data.chests, true, 43),
		"A new real round can reuse the existing imported source images")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	check(view._chest_texture == icons[str(Catalog.preset(1).asset_id)]
		and view._reward_texture(99) == icons[str(Catalog.preset(99).asset_id)]
		and view._chest_cache.size() == Catalog.MATERIAL_COUNT and renderer_count(view) == 0,
		"Stopping and restarting preserve stable wrappers without rebuilding a source renderer")


func _check_tap_reference(view: Jelly) -> void:
	var before: Dictionary = view.game.snapshot().duplicate(true)
	var texture: Texture2D = view._loot_icon.texture
	view._tap_chest()
	check(view._chest_tap.is_active() and view._chest_tap._texture == texture,
		"The local chest response retains the same imported texture shown by the HUD")
	view._chest_tap.advance(0.15)
	check(view._chest_tap._texture == texture and renderer_count(view) == 0,
		"Tap effects keep their source reference without activating a chest renderer")
	check(view.game.snapshot() == before and not view._reward_presentation.is_active(),
		"Static icon feedback preserves the existing presentation-only tap behavior")
	view._chest_tap.clear()


func _check_queued_references(view: Jelly) -> void:
	var before: Dictionary = view.game.snapshot().duplicate(true)
	view._chest_milestone(2, 5)
	var events: Array = view._reward_presentation._events
	check(events.size() == 3, "A multi-level milestone queues every earned transition in order")
	for index in range(events.size()):
		var event: Dictionary = events[index]
		var previous: int = index + 2
		var tier: int = previous + 1
		check(int(event.previous_tier) == previous and int(event.tier) == tier
			and event.before == icons[str(Catalog.preset(previous).asset_id)]
			and event.after == icons[str(Catalog.preset(tier).asset_id)],
			"Queued transition %d retains its exact before and after imported references" % tier)
	check(view.game.snapshot() == before,
		"Preparing static milestone artwork cannot alter already committed reward ownership")
	check(view._reward_presentation._models._pool.is_empty() and renderer_count(view) == 0,
		"A reduced-motion queue uses ready icons without preparing any model surfaces")
	view._reward_presentation.clear()
	check(view._reward_texture(3) == icons[str(Catalog.preset(3).asset_id)]
		and view._chest_cache.size() == Catalog.MATERIAL_COUNT,
		"Clearing queued presentation does not invalidate source references retained by the owner")
