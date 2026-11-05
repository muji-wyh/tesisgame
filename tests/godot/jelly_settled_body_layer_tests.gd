extends SceneTree
## The ordinary body batch preserves rendered cached paint and active feedback.

const Tile = preload("res://scripts/word_jelly_tile.gd")
const Layer = preload("res://scripts/jelly_settled_body_layer.gd")
const Cache = preload("res://scripts/jelly_idle_body_cache.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-coral.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _cell(id: int, kind: String = "root") -> Dictionary:
	return {"id": id, "jelly_kind": kind, "text": "cat", "display_text": "cat",
		"word": {"text": "cat"}, "merge_level": 1, "mass": 1, "fragments": 0}


func _tile(holder: Control, id: int, at: Vector2, kind: String = "root"):
	var tile := Tile.new()
	holder.add_child(tile)
	tile.position = at
	tile.size = Vector2(128, 96)
	tile.z_index = 1
	tile.configure(_cell(id, kind), SKIN, PICTURE, CHEST, Color("#357d70"))
	tile.set_ambient_animation(false)
	tile.deform(0.0, 0.0)
	return tile


func _settle_cache(tile) -> bool:
	tile.set_idle_cached(true)
	for frame in range(120):
		if bool(tile.idle_cache_snapshot().cached):
			return true
		await process_frame
	return false


func _render_frame() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _pixel_error(left: Image, right: Image, label: String = "batch") -> Dictionary:
	var total: float = 0.0
	var maximum: float = 0.0
	var worst := Vector2i.ZERO
	var different: int = 0
	var difference := Image.create(left.get_width(), left.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(left.get_height()):
		for x in range(left.get_width()):
			var a: Color = left.get_pixel(x, y)
			var b: Color = right.get_pixel(x, y)
			var error: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			total += error
			if error > maximum:
				maximum = error
				worst = Vector2i(x, y)
			if error > 2.0 / 255.0:
				different += 1
			difference.set_pixel(x, y, Color(absf(a.r - b.r) * 8.0, absf(a.g - b.g) * 8.0, absf(a.b - b.b) * 8.0, 1.0))
	var directory := "res://build/performance/settled-body-parity"
	DirAccess.make_dir_recursive_absolute(directory)
	left.save_png(directory + "/" + label + "-original.png")
	right.save_png(directory + "/" + label + "-batched.png")
	difference.save_png(directory + "/" + label + "-difference.png")
	return {"mean": total / float(left.get_width() * left.get_height()), "maximum": maximum,
		"worst": [worst.x, worst.y], "different_pixels": different}


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 420)
	RenderingServer.set_default_clear_color(Color("#182033"))
	var holder := Control.new()
	root.add_child(holder)
	holder.position = Vector2(30, 20)
	holder.size = Vector2(580, 380)
	holder.modulate = Color(0.94, 0.98, 0.91, 0.92)
	var layer := Layer.new()
	holder.add_child(layer)
	var tile = _tile(holder, 1, Vector2(48, 44))
	var picture = _tile(holder, 2, Vector2(260, 70), "picture")
	var rotated = _tile(holder, 3, Vector2(52, 224))
	rotated.rotation = 0.12
	rotated.scale = Vector2(0.96, 1.08)
	rotated.modulate = Color(0.80, 0.92, 0.88, 0.75)
	rotated._visual.position = Vector2(2.5, -1.25)
	rotated._visual.modulate = Color(0.91, 0.84, 0.98, 0.85)
	rotated._surface.modulate = Color(0.96, 0.92, 0.87, 0.80)
	rotated._surface.self_modulate = Color(0.68, 0.72, 0.76, 0.90)
	tile.scale = Vector2(0.96, 1.08)
	tile.modulate = Color(0.80, 0.92, 0.88, 0.75)
	tile._visual.position = Vector2(2.5, -1.25)
	tile._visual.modulate = Color(0.91, 0.84, 0.98, 0.85)
	tile._surface.modulate = Color(0.96, 0.92, 0.87, 0.80)
	tile._surface.self_modulate = Color(0.68, 0.72, 0.76, 0.90)
	if DisplayServer.get_name() == "headless":
		tile.set_idle_cached(true)
		layer.refresh(tile)
		layer._sync_dirty()
		check(layer.snapshot().bodies == 0 and tile._surface.visible,
			"Unavailable rendering retains ordinary surfaces without a fake batch")
		holder.free()
		print("Jelly settled body layer: %d checks, %d failures (headless fallback)" % [checks, failures])
		quit(1 if failures else 0)
		return
	check(await _settle_cache(tile) and await _settle_cache(picture) and await _settle_cache(rotated),
		"Rendered ordinary roots and pictures warm their real acquired body atlas")
	var original: Image = await _render_frame()
	var geometry: Array = [tile.get_rect(), tile.contact_bounds(), tile._label.get_rect(), tile._picture.get_rect()]
	layer.refresh(tile)
	layer.refresh(picture)
	layer.refresh(rotated)
	var batched: Image = await _render_frame()
	var error: Dictionary = _pixel_error(original, batched)
	print("Shared settled body layer pixel error: ", error)
	check(float(error.mean) <= 0.25 / 255.0 and float(error.maximum) <= 2.0 / 255.0,
		"Batched skins preserve atlas pixels, inherited tint, alpha, transforms, shadows and learning faces")
	check(layer.snapshot().bodies == 3 and not tile._surface.visible and not picture._surface.visible,
		"Real cached skins use the shared body layer")
	check(not rotated._surface.visible,
		"Rotated source skins preserve the original render-only Control snapping")
	check(geometry == [tile.get_rect(), tile.contact_bounds(), tile._label.get_rect(), tile._picture.get_rect()],
		"Batching leaves hit geometry and learning layout unchanged")
	tile.deform(0.03, 0.6)
	check(tile._surface.visible and tile._surface.material == tile._gel and layer.snapshot().bodies == 2,
		"Deformation restores the original live skin synchronously")
	tile.deform(0.0, 0.0)
	check(await _settle_cache(tile), "A released body returns to its real cached paint")
	layer.refresh(tile)
	await _render_frame()
	layer.refresh(tile, false)
	check(tile._surface.visible and layer.snapshot().bodies == 2,
		"Pointer or active-pose exclusion restores the original surface immediately")
	await _render_frame()
	var redraws: int = int(layer.snapshot().draws)
	for frame in range(12):
		tile.position.x += 0.25
		layer.refresh(tile, false)
		await process_frame
	check(int(layer.snapshot().draws) == redraws,
		"Already excluded moving bodies do not redraw unchanged retained skins")
	layer.refresh(tile)
	await _render_frame()
	tile.set_marked(true, true, true, false)
	check(tile._surface.visible and layer.snapshot().bodies == 2,
		"Selected and marked feedback keeps its original live shader")
	tile.set_marked(false, false, true, false)
	check(await _settle_cache(tile), "Feedback release can reuse the cache")
	layer.refresh(tile)
	await _render_frame()
	tile.hide()
	await _render_frame()
	check(layer.snapshot().bodies == 2, "Hidden tiles leave no orphan cached skin")
	tile.show()
	layer.refresh(tile)
	await _render_frame()
	check(layer.snapshot().bodies == 3, "Showing a settled body restores its shared paint")
	layer.forget(tile)
	check(tile._surface.visible and layer.snapshot().bodies == 2, "Untracking immediately restores the source surface")
	tile.configure(_cell(1, "merged"), SKIN, PICTURE, CHEST, Color("#357d70"))
	tile.set_ambient_animation(false)
	check(await _settle_cache(tile), "A merged skin still uses the established body cache")
	layer.refresh(tile)
	await _render_frame()
	check(tile._surface.visible and layer.snapshot().bodies == 2,
		"Merged bodies preserve their original glow and learning-face compositing")
	var saved: Image = await _render_frame()
	layer.forget(picture)
	var restored: Image = await _render_frame()
	error = _pixel_error(saved, restored, "restoration")
	check(float(error.maximum) <= 2.0 / 255.0, "Restoring the original cached node preserves rendered pixels")
	layer.refresh(picture)
	await _render_frame()
	picture.free()
	check(layer.snapshot().bodies == 1, "Tile teardown immediately removes its retained shared stamp")
	rotated.free()
	tile.free()
	await _check_mixed_neighbors(holder, layer)
	holder.free()
	print("Jelly settled body layer: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_mixed_neighbors(holder: Control, layer) -> void:
	var merged = _tile(holder, 4, Vector2(140, 140), "merged")
	var neighbor = _tile(holder, 5, Vector2(268, 140))
	check(await _settle_cache(merged) and await _settle_cache(neighbor),
		"Mixed adjacent skins use their real acquired cached artwork")
	var original: Image = await _render_frame()
	layer.refresh(merged)
	layer.refresh(neighbor)
	var batched: Image = await _render_frame()
	var error: Dictionary = _pixel_error(original, batched, "mixed-neighbors")
	check(float(error.maximum) <= 2.0 / 255.0 and neighbor._surface.visible \
		and int(layer.snapshot().occluded) == 1,
		"An earlier merged halo retains its original overlap beneath the adjacent ordinary skin")
	merged.position.y -= 160.0
	layer.refresh(merged)
	await _render_frame()
	check(layer.snapshot().bodies == 1 and not neighbor._surface.visible,
		"Moving a merged effect away makes the separated ordinary skin eligible")
	layer.refresh(neighbor, false)
	neighbor.position.y -= 160.0
	layer.refresh(neighbor)
	await _render_frame()
	check(layer.snapshot().bodies == 0 and neighbor._surface.visible,
		"An ordinary skin released beside a fixed merged effect retains original overlap")
	neighbor.position.y += 160.0
	layer.refresh(neighbor)
	await _render_frame()
	check(layer.snapshot().bodies == 1, "Moving the ordinary skin away clears its occlusion exclusion")
	merged.position.y += 160.0
	layer.refresh(merged)
	await _render_frame()
	check(layer.snapshot().bodies == 0 and neighbor._surface.visible,
		"Moving a merged effect back restores the original neighbor compositing")
	merged.free()
	await _render_frame()
	check(layer.snapshot().bodies == 1, "Removing the merged blocker restores safe body batching")
	neighbor.free()
