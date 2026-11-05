extends SceneTree
## Cached bodies retain neutral motion and use exact source paint for stretch.

const Tile = preload("res://scripts/jelly_tile.gd")
const Cache = preload("res://scripts/jelly_idle_body_cache.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-coral.png")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _tile(at: Vector2, extent: Vector2 = Vector2(120.0, 90.0)):
	var tile := Tile.new()
	root.add_child(tile)
	tile.position = at
	tile.size = extent
	tile.configure({"id": 7, "kind": "word", "word": {"text": "cat"}}, SKIN, null, CHEST, Color("#357d70"))
	tile._surface.stretch_mode = TextureRect.STRETCH_SCALE
	tile._label.hide()
	tile._shadow.hide()
	tile.deform(0.0, 0.0)
	return tile

func _settle_cache(tile) -> bool:
	for frame in range(120):
		if bool(tile.idle_cache_snapshot().cached):
			return true
		await process_frame
	return false

func _pixel_error(image: Image, a: Rect2i, b: Rect2i) -> Dictionary:
	var total: float = 0.0
	var maximum: float = 0.0
	var pixels: int = 0
	for y in range(a.size.y):
		for x in range(a.size.x):
			var left: Color = image.get_pixelv(a.position + Vector2i(x, y))
			var right: Color = image.get_pixelv(b.position + Vector2i(x, y))
			var difference: float = maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b)))
			total += difference
			maximum = maxf(maximum, difference)
			pixels += 1
	return {"mean": total / maxf(1.0, pixels), "maximum": maximum}

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 420)
	RenderingServer.set_default_clear_color(Color("#182033"))
	var live = _tile(Vector2(20.0, 20.0))
	var cached = _tile(Vector2(180.0, 20.0))
	check(live._idle_cache_eligible(), "A settled acquired body is eligible")
	live.deform(0.02, 0.5)
	check(not live._idle_cache_eligible(), "A moving body cannot enter the cache")
	live.deform(0.0, 0.0)
	live.set_preview_pressure(0.1, 0.0)
	check(not live._idle_cache_eligible(), "Preview pressure cannot enter the cache")
	live.set_preview_pressure(0.0, 0.0)
	live.set_projection(true)
	check(not live._idle_cache_eligible(), "Placement projections remain live")
	live.set_projection(false)
	live._label.hide()
	live._shadow.hide()
	cached._set_surface_parameter(&"completion_strength", 0.95)
	cached._set_surface_parameter(&"completion_glint", -2.0)
	check(cached._idle_cache_eligible(), "A still full-strength completion light is eligible with its complete padded paint")
	cached._set_surface_parameter(&"completion_strength", 0.55)
	check(not cached._idle_cache_eligible(), "Intermediate completion entry brightness remains live")
	cached._set_surface_parameter(&"completion_strength", 0.0)
	cached.set_idle_cached(true)
	if DisplayServer.get_name() == "headless":
		check(not cached.idle_cache_snapshot().cached and not cached.idle_cache_snapshot().requested,
			"Headless rendering retains the exact live material without queueing GPU work")
		check(root.get_node_or_null(Cache.POOL_NAME) == null, "Headless scenes never allocate an atlas")
		live.free()
		cached.free()
		print("Jelly idle body cache: %d checks, %d failures (headless fallback)" % [checks, failures])
		quit(1 if failures else 0)
		return
	check(await _settle_cache(cached), "A rendered settled body promotes after bounded warmup")
	var pool: Node = root.get_node_or_null(Cache.POOL_NAME)
	check(pool != null and int(pool.snapshot().bytes) == 2048 * 2048 * 4,
		"All cached bodies share one bounded RGBA atlas")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Dictionary = _pixel_error(image, Rect2i(20, 20, 120, 90), Rect2i(180, 20, 120, 90))
	print("Cached acquired paint pixel error: ", error)
	check(float(error.mean) <= 2.0 / 255.0 and float(error.maximum) <= 5.0 / 255.0,
		"Cached acquired contours, lighting and alpha match the original live shader")
	live.set_idle_cached(true)
	check(live._surface.texture == cached._surface.texture,
		"Identical settled shader states share the exact atlas region")
	var cached_texture: Texture2D = cached._surface.texture
	for step in range(30):
		cached.deform(0.0, 0.0)
		cached.set_contact("none")
		cached.set_marked(false)
		cached.set_idle_cached(true)
	check(cached._surface.texture == cached_texture and int(pool.snapshot().bakes) == 1,
		"Unchanged poses and repeated requests neither invalidate nor bake again")
	var face_rect := Rect2(cached._label.position, cached._label.size)
	var motion_raster: Vector2i = cached._idle_raster_size
	cached.set_motion_cached(true)
	for step in range(12):
		cached.position = Vector2(180.0 + float(step) * 0.25, 20.0 + float(step) * 0.125)
		cached.deform(0.0, 0.0)
		cached.set_motion_cached(true)
		check(cached._surface.texture == cached_texture and cached._idle_raster_size == motion_raster,
			"Neutral translation retains its original cached raster")
		check(Rect2(cached._label.position, cached._label.size) == face_rect,
			"Cached motion never deforms or moves the learning face")
	check(int(pool.snapshot().bakes) == 1,
		"Changing neutral motion positions do not schedule another body bake")
	cached.position = Vector2(180.0, 20.0)
	live.set_idle_cached(false)
	for tile in [live, cached]:
		tile.deform(0.0, 0.0, Vector2(1.06, 0.94))
	cached.set_motion_cached(true)
	check(not cached.idle_cache_snapshot().cached and cached._surface.material == cached._gel \
		and Rect2(cached._label.position, cached._label.size) == face_rect,
		"Affine motion restores exact source sampling while preserving the learning face")
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	error = _pixel_error(image, Rect2i(12, 12, 136, 106), Rect2i(172, 12, 136, 106))
	print("Affine motion native fallback pixel error: ", error)
	check(float(error.mean) <= 2.0 / 255.0 and float(error.maximum) <= 5.0 / 255.0,
		"Affine native fallback exactly preserves the acquired silhouette and lighting")
	for tile in [live, cached]:
		tile.deform(0.0, 0.0)
		tile.set_idle_cached(true)
	check(cached._surface.texture == cached_texture and int(pool.snapshot().bakes) == 1,
		"Landing at the neutral pose reuses its original body paint immediately")
	cached.set_contact("touch", Vector2.RIGHT, 0.4)
	check(cached._surface.material == cached._gel and cached._surface.texture == SKIN,
		"Contact restores the original artwork and live material in the same call")
	cached.set_contact("none")
	cached.set_idle_cached(true)
	check(cached.idle_cache_snapshot().cached, "Contact release reuses an existing cache entry immediately")
	cached.set_marked(true)
	check(not cached.idle_cache_snapshot().cached and cached._surface.material == cached._gel,
		"Highlighted selection restores live feedback immediately")
	cached.set_marked(false)
	cached.set_idle_cached(true)
	cached._set_surface_parameter(&"palette_hue", 0.57)
	check(not cached.idle_cache_snapshot().cached and cached._surface.texture == SKIN,
		"Palette changes never display previously cached paint")
	cached.set_idle_cached(true)
	check(await _settle_cache(cached), "A changed palette gets a separate cached region")
	check(cached._surface.texture != live._surface.texture, "Distinct palettes never alias an atlas cell")
	live._set_surface_parameter(&"palette_hue", 0.57)
	live.set_idle_cached(false)
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	error = _pixel_error(image, Rect2i(20, 20, 120, 90), Rect2i(180, 20, 120, 90))
	print("Cached palette pixel error: ", error)
	check(float(error.mean) <= 2.0 / 255.0 and float(error.maximum) <= 5.0 / 255.0,
		"Palette remapping preserves shader color and static transmitted lighting")
	for tile in [live, cached]:
		tile.set_idle_cached(false)
		tile._set_surface_parameter(&"completion_strength", 0.35)
		tile._set_surface_parameter(&"completion_glint", -2.0)
		tile._gel.set_shader_parameter("rim_strength", 1.0)
		tile._gel.set_shader_parameter("rim_width", 1.65)
		tile._gel.set_shader_parameter("rim_color", Color("#d7ac51"))
		tile._surface.self_modulate = Color(0.68, 0.72, 0.76, 0.45)
	cached.set_idle_cached(true)
	check(await _settle_cache(cached), "A settled merged sheen and acquired contour rim can be baked together")
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	error = _pixel_error(image, Rect2i(20, 20, 120, 90), Rect2i(180, 20, 120, 90))
	print("Cached merged rim and opacity pixel error: ", error)
	check(float(error.mean) <= 2.0 / 255.0 and float(error.maximum) <= 5.0 / 255.0,
		"Merged rims, dimming and opacity retain the original premultiplied edge coverage")
	# Integer backing dimensions and aligned origins compare the complete padded
	# light, including its spill outside the original body, after constant scale.
	for tile in [live, cached]:
		tile.set_idle_cached(false)
		tile.size = Vector2.ONE * 125.0
		tile.position = Vector2(42.5 if tile == live else 322.5, 90.0 + 125.0 * tile.Motion.FOOT_Y * 0.2)
		tile._label.hide()
		tile._shadow.hide()
		tile.deform(0.0, 0.0, Vector2.ONE * 1.2)
		tile._set_surface_parameter(&"completion_strength", 0.95)
		tile._set_surface_parameter(&"completion_glint", -2.0)
		tile._gel.set_shader_parameter("rim_strength", 1.0)
		tile._gel.set_shader_parameter("rim_width", 1.8)
		tile._gel.set_shader_parameter("rim_color", Color("#236451"))
		tile._surface.self_modulate = Color.WHITE
	cached.set_idle_cached(true)
	check(await _settle_cache(cached), "A constant enlarged full completion light captures its entire padded envelope")
	check(cached._surface.material != Cache.display_material()
		and is_equal_approx(float(cached._surface.material.get_shader_parameter("mesh_scale")), 1.32),
		"Padded paint uses a bounded entry display variant while ordinary bodies retain their shared material")
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	error = _pixel_error(image, Rect2i(6, 66, 198, 198), Rect2i(286, 66, 198, 198))
	print("Cached full completion light pixel error: ", error)
	check(float(error.mean) <= 2.0 / 255.0 and float(error.maximum) <= 5.0 / 255.0,
		"Full authored glow, dark silhouette rim and enlarged skin match across the complete padded rectangle")
	var hint_texture: Texture2D = cached._surface.texture
	var hint_bakes: int = int(pool.snapshot().bakes)
	for step in range(30):
		cached.deform(0.0, float(step), Vector2.ONE * 1.2)
		cached.set_idle_cached(true)
	check(cached._surface.texture == hint_texture and int(pool.snapshot().bakes) == hint_bakes,
		"Constant enlarged posture and irrelevant bend clocks do not churn padded cache entries")
	cached._surface.position = Vector2(3.0, -2.0)
	cached._visual.position = Vector2(-1.0, 4.0)
	check(cached._idle_cache_eligible() and cached.idle_cache_snapshot().cached,
		"Whole-quad offsets preserve cached paint without changing its UV deformation")
	cached.set_contact("match", Vector2.RIGHT, 0.6)
	check(not cached.idle_cache_snapshot().cached and cached._surface.material == cached._gel,
		"A padded cached completion target restores its live pressure feedback immediately")
	cached.set_contact("none")
	cached._visual.position = Vector2.ZERO
	cached._set_surface_parameter(&"completion_strength", 0.95)
	cached._set_surface_parameter(&"completion_glint", 0.5)
	cached.set_idle_cached(true)
	check(not cached.idle_cache_snapshot().cached, "A full completion sweep remains live")
	cached._set_surface_parameter(&"completion_strength", 0.35)
	cached._set_surface_parameter(&"completion_glint", 0.5)
	cached.set_idle_cached(true)
	check(not cached.idle_cache_snapshot().cached, "A moving merged sheen stays live")
	cached._set_surface_parameter(&"completion_glint", -2.0)
	cached.deform(0.0, 0.0)
	cached.set_idle_cached(true)
	cached.scale = Vector2.ONE * 1.25
	await process_frame
	check(not cached.idle_cache_snapshot().cached, "A changed backing pixel extent wakes the live body")
	cached.scale = Vector2.ONE
	cached.size = Vector2(144.0, 96.0)
	await process_frame
	cached.set_idle_cached(true)
	check(await _settle_cache(cached) and cached.idle_cache_snapshot().raster_size == [144, 96],
		"Responsive resize acquires an atlas entry at its new display resolution")
	var oversized = _tile(Vector2(-600.0, -600.0), Vector2(300.0, 220.0))
	oversized.set_idle_cached(true)
	check(not oversized.idle_cache_snapshot().requested and oversized._surface.material == oversized._gel,
		"Oversized bodies retain live detail instead of accepting an undersampled cache")
	oversized.free()
	var fixtures: Array[Node] = []
	for index in range(70):
		var tile = _tile(Vector2(-100.0, -100.0), Vector2.ONE * 12.0)
		tile._set_surface_parameter(&"palette_hue", float(index) / 71.0)
		tile.set_idle_cached(true)
		fixtures.append(tile)
	check(int(pool.snapshot().entries) == Cache.CELL_COUNT and int(pool.snapshot().fallbacks) > 0,
		"Capacity overflow retains live bodies without growing GPU allocation")
	var before: int = int(pool.snapshot().bakes)
	await process_frame
	await RenderingServer.frame_post_draw
	check(int(pool.snapshot().bakes) - before <= Cache.WARM_PER_FRAME,
		"Atlas warmup renders at most its small per-frame budget")
	for fixture: Node in fixtures:
		fixture.free()
	check(int(pool.snapshot().owners) == 1, "Freed tiles immediately release their cache leases")
	var replacement = _tile(Vector2(-100.0, -100.0), Vector2.ONE * 14.0)
	replacement.set_idle_cached(true)
	check(replacement.idle_cache_snapshot().requested and int(pool.snapshot().entries) == Cache.CELL_COUNT,
		"Unleased cells are reused while live cached owners stay protected")
	replacement.free()
	live.free()
	cached.free()
	await create_timer(Cache.UNUSED_SECONDS + 0.3).timeout
	check(root.get_node_or_null(Cache.POOL_NAME) == null, "The entire GPU atlas is released after its last owner leaves")
	print("Jelly idle body cache: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
