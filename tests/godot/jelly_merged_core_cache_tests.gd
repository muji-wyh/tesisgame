extends SceneTree
## Frozen merged artwork preserves source phases, neighbors and translucent paint.

const Tile = preload("res://scripts/word_jelly_tile.gd")
const Cache = preload("res://scripts/jelly_merged_core_cache.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-coral.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")
# Transparent RGBA8 baking rounds color and alpha at each layer before one
# final opaque composite. Permit only a sparse, low-mean rounding tail;
# geometry, glyph, phase and source-order discrepancies remain outside it.
const MAX_RGBA8_CODES: float = 4.0
const MAX_RGBA8_MEAN_CODES: float = 0.35
const MAX_RGBA8_OUTLIER_RATIO: float = 0.0005
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _board(holder: Control, mixed: bool) -> Array:
	var tiles: Array = []
	for index in range(56):
		var tile := Tile.new()
		holder.add_child(tile)
		tile.position = Vector2(44 + (index % 7) * 68, 32 + int(index / 7) * 68)
		tile.size = Vector2(68, 68)
		tile.z_index = 1
		tile.set_merged_core_cache_enabled(false)
		var kind: String = "picture" if mixed and index % 4 == 0 else "merged"
		tile.configure({"id": index + 1, "jelly_kind": kind, "word": {"text": "cat"},
			"display_text": "cat", "text": "cat", "merge_level": 1 + index % 9,
			"fragments": index % 5}, SKIN, PICTURE, CHEST, Color("#357d70"))
		tile.set_merged_presentation(0.0137 + float(index) * 0.00091)
		tile.set_ambient_animation(false)
		tile._visual.position = Vector2(0.5, -0.25) if index % 5 == 0 else Vector2.ZERO
		if index % 7 == 0:
			tile.modulate = Color(0.81, 0.93, 0.87, 0.72)
			tile._visual.modulate = Color(0.94, 0.88, 0.98, 0.84)
		if index == 55:
			tile.rotation = 0.08
		tile.deform(0.0, 0.0)
		tile.set_idle_cached(true)
		tiles.append(tile)
	return tiles


func _settle_bodies(tiles: Array) -> bool:
	for frame in range(180):
		var ready: bool = true
		for tile in tiles:
			ready = ready and bool(tile.idle_cache_snapshot().cached)
		if ready:
			return true
		await process_frame
	return false


func _settle_cores(tiles: Array) -> bool:
	for frame in range(180):
		var ready: bool = true
		for tile in tiles:
			if tile.valid_word:
				ready = ready and bool(tile.merged_core_snapshot().cached)
		if ready:
			return true
		await process_frame
	return false


func _image() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _pixel_error(original: Image, cached: Image, label: String) -> Dictionary:
	var total: float = 0.0
	var maximum: float = 0.0
	var different: int = 0
	var worst := Vector2i.ZERO
	var diff := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(original.get_height()):
		for x in range(original.get_width()):
			var a: Color = original.get_pixel(x, y)
			var b: Color = cached.get_pixel(x, y)
			var error: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			total += error
			if error > maximum:
				maximum = error
				worst = Vector2i(x, y)
			if error > 2.0 / 255.0:
				different += 1
			diff.set_pixel(x, y, Color(absf(a.r - b.r) * 8.0, absf(a.g - b.g) * 8.0, absf(a.b - b.b) * 8.0, 1.0))
	var directory := "res://build/performance/merged-core-parity"
	DirAccess.make_dir_recursive_absolute(directory)
	original.save_png(directory + "/" + label + "-original.png")
	cached.save_png(directory + "/" + label + "-cached.png")
	diff.save_png(directory + "/" + label + "-difference.png")
	return {"mean": total / float(original.get_width() * original.get_height()), "maximum": maximum,
		"different_pixels": different, "pixel_count": original.get_width() * original.get_height(),
		"worst": [worst.x, worst.y]}


func _within_rgba8_budget(error: Dictionary) -> bool:
	return float(error.maximum) <= MAX_RGBA8_CODES / 255.0 \
		and float(error.mean) <= MAX_RGBA8_MEAN_CODES / 255.0 \
		and int(error.different_pixels) <= float(error.pixel_count) * MAX_RGBA8_OUTLIER_RATIO


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	RenderingServer.set_default_clear_color(Color("#eaf5e8"))
	var holder := Control.new()
	root.add_child(holder)
	holder.position = Vector2(24.5, 18.25)
	holder.size = Vector2(1300, 720)
	holder.modulate = Color(0.96, 0.98, 0.94, 0.92)
	var tiles: Array = _board(holder, false)
	if DisplayServer.get_name() == "headless":
		check(not tiles[0].merged_core_snapshot().cached and root.get_node_or_null(Cache.POOL_NAME) == null,
			"Headless scenes retain original merged paint without GPU cache allocation")
		holder.free()
		print("Jelly merged core cache: %d checks, %d failures (headless fallback)" % [checks, failures])
		quit(1 if failures else 0)
		return
	check(await _settle_bodies(tiles), "Full-board source skins use their real body atlas")
	var original: Image = await _image()
	var original_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var phases: Array[float] = []
	for tile in tiles:
		phases.append(tile._merged_effect_frame)
		tile.set_merged_core_cache_enabled(true)
	if OS.get_cmdline_user_args().has("--atlas-diagnostic"):
		root.get_node(Cache.POOL_NAME)._diagnostic_enabled = true
	check(await _settle_cores(tiles), "All 56 frozen merged cores warm within the bounded frame budget")
	var cached: Image = await _image()
	var debug_pool: Node = root.get_node_or_null(Cache.POOL_NAME)
	DirAccess.make_dir_recursive_absolute("res://build/performance/merged-core-parity")
	debug_pool._atlas.get_texture().get_image().save_png("res://build/performance/merged-core-parity/core-atlas.png")
	var cached_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var error: Dictionary = _pixel_error(original, cached, "full-board")
	print("Full merged core pixel error: ", error, " draws: ", original_draws, " -> ", cached_draws)
	if OS.get_cmdline_user_args().has("--atlas-diagnostic"):
		var atlas_image: Image = debug_pool._atlas.get_texture().get_image()
		var alpha_pixels: int = 0
		for y in range(atlas_image.get_height()):
			for x in range(atlas_image.get_width()):
				alpha_pixels += int(atlas_image.get_pixel(x, y).a > 0.0)
		print("Core bake diagnostics: ", debug_pool._diagnostic_capture,
			" used rect: ", atlas_image.get_used_rect(), " alpha pixels: ", alpha_pixels)
		var capture: Dictionary = tiles[0]._capture_merged_core()
		var sources: Array[Dictionary] = []
		for source: Dictionary in capture.sources:
			sources.append({"class": source.node.get_class(), "name": source.node.name,
				"visible": source.node.visible, "size": source.node.size, "transform": source.transform,
				"color": source.color})
		print("Core capture bounds: ", capture.bounds, " sources: ", sources)
		quit(0)
		return
	check(_within_rgba8_budget(error),
		"All nine frozen levels preserve neighbor overlap, source phases, tint, alpha, text and transforms")
	check(cached_draws < original_draws, "Frozen core GPU captures reduce real rendered draw calls")
	for index in range(tiles.size()):
		var tile = tiles[index]
		check(tile._merged_effect_frame == phases[index] and tile._merged_effect.texture == Tile.MERGED_EFFECT_ATLAS,
			"The captured level retains its exact fractional phase and original atlas resource")
		check(tile._label.visible and tile._picture.visible and tile._shadow.visible \
			and tile._level_badge.visible == (tile.merge_level > 1),
			"Original learning and elevated badge nodes retain logical visibility and layout")
		check(not tile._merged_core_hidden.has(tile._label) \
			and not tile._merged_core_hidden.has(tile._fragment_count) \
			and tile._fragment_holder.is_visible_in_tree() == (tile.fragments > 0),
			"Learning text and reward fragments retain their native font and scaled drawing")
	var pool: Node = root.get_node_or_null(Cache.POOL_NAME)
	check(pool != null and int(pool.snapshot().entries) <= Cache.CAPACITY \
		and int(pool.snapshot().bytes) == Cache.ATLAS_EDGE * Cache.ATLAS_EDGE * 4,
		"All cores share one bounded GPU atlas without pixel readback")
	var selected = tiles[0]
	selected.set_ambient_animation(true)
	check(not selected.merged_core_snapshot().cached and selected._merged_core_hidden.is_empty(),
		"Hover or cohort entry restores every original source immediately")
	var neighbors_cached: bool = true
	for index in range(1, tiles.size()):
		neighbors_cached = neighbors_cached and bool(tiles[index].merged_core_snapshot().cached)
	check(neighbors_cached, "Restoring one active body retains every unrelated frozen core")
	selected.set_merged_presentation(0.091)
	selected.set_ambient_animation(false)
	selected.set_idle_cached(true)
	check(await _settle_cores(tiles), "A newly frozen source reenters at its current coherent phase")
	selected.set_match_dimmed(true)
	check(not selected.merged_core_snapshot().cached, "Component-specific dimming restores original paint immediately")
	selected.set_idle_cached(true)
	check(await _settle_cores(tiles), "A dimmed static source can capture its real component tints")
	selected.set_marked(true, true, true, false)
	check(not selected.merged_core_snapshot().cached, "Selected and marked feedback remains live")
	selected.set_marked(false, false, true, false)
	selected.set_match_dimmed(false)
	selected.set_idle_cached(true)
	check(await _settle_cores(tiles), "Released feedback returns to its stable source capture")
	for tile in tiles:
		tile.set_merged_core_cache_enabled(false)
	holder.modulate = Color(0.84, 0.92, 0.98, 0.64)
	original = await _image()
	for tile in tiles:
		tile.set_merged_core_cache_enabled(true)
	check(await _settle_cores(tiles), "Released atlas slots support a new full-board ancestor tint")
	cached = await _image()
	error = _pixel_error(original, cached, "ancestor-alpha")
	print("Ancestor-alpha merged core pixel error: ", error)
	check(_within_rgba8_budget(error), "Ancestor alpha is applied per source child before compositing")
	holder.modulate = Color(0.93, 0.96, 0.91, 0.83)
	await RenderingServer.frame_post_draw
	check(not tiles[55].merged_core_snapshot().cached, "Changing ancestor tint restores source paint before rebaking")
	check(await _settle_cores(tiles), "Shared ancestor tint watches refresh the exact captured paint")
	for tile in tiles:
		tile.free()
	holder.modulate = Color.WHITE
	tiles = _board(holder, true)
	check(await _settle_bodies(tiles), "Mixed source neighbors warm their actual body paint")
	original = await _image()
	for tile in tiles:
		tile.set_merged_core_cache_enabled(true)
	check(await _settle_cores(tiles), "Frozen merged cores coexist with ordinary original neighbors")
	cached = await _image()
	error = _pixel_error(original, cached, "mixed-neighbors")
	print("Mixed-neighbor merged core pixel error: ", error)
	check(_within_rgba8_budget(error), "Mixed ordinary and merged sibling order preserves all glow overlaps")
	selected = tiles[1]
	selected.set_projection(true)
	check(not selected.merged_core_snapshot().cached and not selected.presentation_snapshot().merged_effect.visible,
		"Projection restores source nodes and suppresses completed-word artwork")
	selected.set_projection(false)
	selected.set_fragment_arrival(0.12)
	check(not selected._merged_core_eligible(), "Fragment arrival pop remains live throughout its animation")
	for tile in tiles:
		tile.free()
	root.content_scale_size = Vector2i(480, 480)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	holder.position = Vector2(0.5, 0.25)
	holder.size = Vector2(854, 480)
	await process_frame
	tiles = _board(holder, true)
	check(root.get_oversampling() > 1.0, "The second fixture uses the real stretched desktop viewport")
	check(await _settle_bodies(tiles), "Stretched source skins warm at their actual backing resolution")
	original = await _image()
	for tile in tiles:
		tile.set_merged_core_cache_enabled(true)
	check(await _settle_cores(tiles), "Stretched core captures inherit source font and DPI oversampling")
	cached = await _image()
	error = _pixel_error(original, cached, "stretched-neighbors")
	print("Stretched-neighbor merged core pixel error: ", error)
	if OS.get_cmdline_user_args().has("--stretch-diagnostic"):
		var stretched = tiles[1]
		var stretched_capture: Dictionary = stretched._capture_merged_core()
		print("Stretched capture diagnostics: ", {"visible_rect": root.get_visible_rect(),
			"final_transform": root.get_final_transform(), "screen_transform": root.get_screen_transform(),
			"oversampling": root.get_oversampling(), "bounds": stretched_capture.bounds,
			"tile_global": stretched.get_global_transform(), "tile_screen": stretched.get_screen_transform(),
			"proxy_screen": stretched._merged_core_proxy.get_screen_transform(),
			"picture_global": stretched._picture.get_global_transform(),
			"picture_screen": stretched._picture.get_screen_transform(),
			"picture_captured": stretched._render_global_transform(stretched._picture)})
		var stretched_pool: Node = root.get_node(Cache.POOL_NAME)
		stretched_pool._atlas.get_texture().get_image().save_png(
			"res://build/performance/merged-core-parity/stretched-atlas.png")
	check(_within_rgba8_budget(error),
		"Stretched desktop captures preserve original glyph sharpness, phases and neighbor compositing")
	holder.free()
	print("Jelly merged core cache: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
