extends SceneTree

const Architecture = preload("res://scripts/room_architecture.gd")
const Interior = preload("res://scripts/room_interior.gd")
const Playroom = preload("res://scripts/playroom_view.gd")
const State = preload("res://scripts/playroom_state.gd")
const Data = preload("res://scripts/game_data.gd")
const OUTPUT := "res://build/performance/room-cache-review"

class LiveRoom extends Control:
	var palette: Dictionary = {}
	var theme_id := "spring"

	func _draw() -> void:
		Interior.draw_room(self, palette, theme_id)

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(900, 700)
	_check_raster_geometry()
	await _check_integration()
	if DisplayServer.get_name() != "headless":
		await _check_native_cache()
	else:
		print("Native room pixel comparisons skipped: headless rendering is unavailable.")
	print("Room render cache: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_raster_geometry() -> void:
	var art := Architecture.new()
	art.size = Vector2(354, 420)
	var basis := Transform2D(Vector2(1.25, 0), Vector2(0, 2.625), Vector2(7.375, 12.625))
	var layout: Dictionary = art._raster_geometry(basis)
	check(layout.pixels == Vector2i(447, 1108), "The cache covers every device pixel at nonuniform device scale")
	var local_origin: Vector2 = -layout.offset / layout.scale
	var pixel_origin: Vector2 = basis * local_origin
	check(pixel_origin.is_equal_approx(pixel_origin.floor()), "The cached quad begins on integer device pixels at fractional positions")
	var shifted := basis
	shifted.origin += Vector2(73, -9)
	check(art._raster_geometry(shifted) == layout, "Integer-pixel translations reuse the same raster")
	shifted.origin += Vector2(0.25, 0)
	check(art._raster_geometry(shifted) != layout, "Subpixel translations require a newly aligned raster")
	check(art._raster_geometry(Transform2D(0.15, Vector2.ZERO)).is_empty(), "Rotation uses the live drawing path")
	check(art._raster_geometry(Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)).is_empty(), "Skew uses the live drawing path")
	check(art._raster_geometry(Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)).is_empty(), "Mirrored drawing keeps its original rasterization")
	check(art._raster_geometry(Transform2D(Vector2(100, 0), Vector2(0, 100), Vector2.ZERO)).is_empty(), "An oversized render target falls back instead of allocating an unbounded texture")
	art.free()


func _check_integration() -> void:
	var view := Playroom.new()
	root.add_child(view)
	view.size = Vector2(390, 650)
	view.configure(State.new(), {}, Data.theme("spring"), true)
	await settle()
	var art: Control = view._room_interior
	check(art is Architecture and art.show_behind_parent, "The raster preserves the original architecture layer")
	check(view._ground_shadows.get_parent() == view._room
		and view.duck_slot.get_parent() == view._room
		and view.toy_button.get_parent() == view._room
		and view.playground.get_parent() == view._room,
		"Ground shadows, Pip, and interactive toys remain live siblings of the architecture")
	check(art._theme_id == "spring" and art._palette == Data.theme("spring"), "The existing theme configures the cached architecture")
	view.configure(State.new(), {}, Data.theme("ocean"), true)
	check(art._theme_id == "ocean" and art._palette == Data.theme("ocean"), "Theme changes immediately update the live fallback and cache source")
	if DisplayServer.get_name() == "headless":
		check(art._viewport == null and not art._using_cache and not art.is_processing(), "Headless tests retain live drawing without allocating or waiting on a renderer")
	view.free()
	await process_frame


func _check_native_cache() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var holder := Control.new()
	holder.clip_contents = true
	root.add_child(holder)
	var art := Architecture.new()
	holder.add_child(art)
	var live := LiveRoom.new()
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(live)
	live.hide()
	var layouts: Array[Dictionary] = [
		{"id": "phone-light", "size": Vector2(354, 420), "scale": Vector2.ONE, "position": Vector2(16, 12), "theme": "spring", "back": Color("#f3eee6")},
		{"id": "phone-dark", "size": Vector2(354, 420), "scale": Vector2.ONE, "position": Vector2(16, 12), "theme": "spring", "back": Color("#14203b")},
		{"id": "fractional-scale", "size": Vector2(320, 300), "scale": Vector2(0.8125, 0.8125), "position": Vector2(16.25, 12.5), "theme": "ocean", "back": Color("#14203b")},
		{"id": "phone-window-scale", "size": Vector2(432, 518), "scale": Vector2(0.8125, 0.8125), "position": Vector2(12.1875, 18.6875), "theme": "spring", "back": Color("#14203b")},
		{"id": "compact-device", "size": Vector2(349, 271), "scale": Vector2(0.75, 0.75), "position": Vector2(12.25, 18.375), "theme": "summer", "back": Color("#f3eee6")},
		{"id": "high-density", "size": Vector2(220, 190), "scale": Vector2(2.625, 2.625), "position": Vector2(16.625, 12.125), "theme": "winter", "back": Color("#f3eee6")},
		{"id": "desktop", "size": Vector2(790, 410), "scale": Vector2.ONE, "position": Vector2(12, 12), "theme": "summer", "back": Color("#14203b")}
	]
	for layout: Dictionary in layouts:
		background.color = layout.back
		holder.position = layout.position
		holder.size = layout.size
		holder.scale = layout.scale
		art.size = layout.size
		art.configure(Data.theme(layout.theme), layout.theme)
		live.size = layout.size
		live.palette = Data.theme(layout.theme)
		live.theme_id = layout.theme
		live.queue_redraw()
		live.hide()
		art.show()
		await settle()
		check(art._using_cache and not art._pending, "The raster becomes ready: " + layout.id)
		check(art._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "The completed raster stops rendering: " + layout.id)
		var revision: int = art._render_revision
		await settle()
		check(art._render_revision == revision, "Unchanged frames reuse the raster: " + layout.id)
		var area := Rect2i(Vector2i(holder.position.floor()), Vector2i((holder.size * holder.scale + Vector2.ONE).ceil()))
		var cached: Image = root.get_texture().get_image().get_region(area)
		art.hide()
		live.show()
		await settle()
		var reference: Image = root.get_texture().get_image().get_region(area)
		_compare_images(reference, cached, layout.id)
	await _check_invalidation(art, live, holder)
	holder.free()
	background.free()
	await process_frame


func _check_invalidation(art: Control, live: Control, holder: Control) -> void:
	live.hide()
	art.show()
	await settle()
	var revision: int = art._render_revision
	var texture: Texture2D = art._viewport.get_texture()
	art.configure(Data.theme("summer"), "summer")
	await settle()
	check(art._render_revision == revision and art._viewport.get_texture() == texture, "Identical configuration reuses the existing texture")
	art.configure(Data.theme("ocean"), "ocean")
	check(not art._using_cache, "A theme change uses live art immediately instead of displaying a stale texture")
	await settle()
	check(art._render_revision == revision + 1 and art._using_cache, "A changed palette rerenders exactly once")
	var changed: Dictionary = Data.theme("ocean").duplicate(true)
	changed["accent"] = Color("#4f78ad")
	revision = art._render_revision
	art.configure(changed, "ocean")
	await settle()
	check(art._render_revision == revision + 1, "A palette change with the same theme identifier invalidates the raster")
	revision = art._render_revision
	art.hide()
	art.size += Vector2(7, 3)
	art.configure(Data.theme("spring"), "spring")
	await settle()
	check(art._render_revision == revision and not art.is_processing(), "A hidden changed room does not render or poll its transform")
	art.show()
	await settle()
	check(art._render_revision == revision + 1 and art._using_cache, "Showing a changed room rebuilds at its current size")
	revision = art._render_revision
	holder.scale = Vector2(0.75, 0.75)
	await settle()
	check(art._render_revision == revision + 1, "Device scale changes rerasterize without stretching the old texture")
	revision = art._render_revision
	holder.position += Vector2(0.25, 0.125)
	await settle()
	check(art._render_revision == revision + 1, "Fractional device positions realign the cached texels")
	revision = art._render_revision
	holder.position += Vector2(10, 3)
	await settle()
	check(art._render_revision == revision, "Whole-device-pixel motion reuses the cache")
	for frame in range(8):
		holder.position += Vector2(0.125, 0.0625)
		await process_frame
		await RenderingServer.frame_post_draw
	check(art._render_revision == revision and not art._using_cache, "Continuous fractional scrolling draws live without repeatedly rasterizing a second copy")
	await settle()
	check(art._render_revision == revision + 1 and art._using_cache, "The room captures once after scrolling settles")
	holder.rotation = 0.1
	await settle()
	check(not art._using_cache and art.material == null, "Rotation returns to the unchanged live renderer and blend mode")
	holder.rotation = 0.0
	await settle()
	check(art._using_cache, "An axis-aligned room resumes caching after rotation")
	holder.modulate.a = 0.5
	await settle()
	check(not art._using_cache, "An ancestor fade preserves the original per-primitive alpha composition")
	holder.modulate.a = 1.0
	await settle()
	check(art._using_cache, "Caching resumes after an ancestor fade finishes")
	root.msaa_2d = Viewport.MSAA_2X
	revision = art._render_revision
	await settle()
	check(art._render_revision == revision + 1 and art._viewport.msaa_2d == root.msaa_2d, "The cache tracks changes to the parent viewport antialiasing")
	root.msaa_2d = Viewport.MSAA_DISABLED


func _compare_images(reference: Image, cached: Image, label: String) -> void:
	reference.convert(Image.FORMAT_RGBA8)
	cached.convert(Image.FORMAT_RGBA8)
	var expected := reference.get_data()
	var actual := cached.get_data()
	check(reference.get_size() == cached.get_size(), "The compared renders have matching device dimensions: " + label)
	if expected.size() != actual.size():
		return
	var maximum := 0
	var total := 0
	var over_two := 0
	for index in range(expected.size()):
		var difference := absi(int(expected[index]) - int(actual[index]))
		maximum = maxi(maximum, difference)
		total += difference
		if difference > 2:
			over_two += 1
	var mean := float(total) / maxf(1.0, expected.size())
	print("Room cache pixels %s: max=%d, mean=%.6f, channels_over_two=%d" % [label, maximum, mean, over_two])
	check(maximum <= 2, "Live and cached pixels differ by no more than two quantization steps: " + label)
	check(reference.save_png(OUTPUT + "/" + label + "-live.png") == OK, "The live visual comparison is saved: " + label)
	check(cached.save_png(OUTPUT + "/" + label + "-cached.png") == OK, "The cached visual comparison is saved: " + label)
