extends SceneTree
## Matched transparent portraits from the first selected Atelier chest.

const View = preload("res://scripts/chest_model_view.gd")
const Catalog = preload("res://scripts/chest_tier_catalog.gd")
const OUTPUT: String = "res://assets/chests/shared/ui/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Chest portraits require a real rendering backend.")
		quit(1)
		return
	var view := View.new()
	root.add_child(view)
	var style: Dictionary = Catalog.style(1)
	style["max_resolution"] = 768
	if not view.configure(style):
		printerr(view.last_error)
		quit(1)
		return
	view.size = Vector2i(768, 768)
	view.set_render_active(true)
	var captures: Array[Image] = []
	var union := Rect2i()
	for opening: float in [0.0, 1.0]:
		view.set_pose(opening, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = view.get_texture().get_image()
		var occupied: Rect2i = capture.get_used_rect()
		if occupied.size.x <= 0 or occupied.size.y <= 0:
			printerr("The selected Atelier chest rendered empty.")
			quit(1)
			return
		union = occupied if captures.is_empty() else union.merge(occupied)
		captures.append(capture)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var fit: float = 472.0 / maxf(union.size.x, union.size.y)
	var fitted := Vector2i(roundi(union.size.x * fit), roundi(union.size.y * fit))
	var names: Array[String] = ["chest.png", "chest-open.png"]
	var outputs: Array[Dictionary] = []
	for index in range(captures.size()):
		var cropped: Image = captures[index].get_region(union)
		cropped.resize(fitted.x, fitted.y, Image.INTERPOLATE_LANCZOS)
		var portrait := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		portrait.fill(Color.TRANSPARENT)
		portrait.blit_rect(cropped, Rect2i(Vector2i.ZERO, fitted), (Vector2i(512, 512) - fitted) / 2)
		var path: String = OUTPUT + names[index]
		if portrait.save_png(path) != OK:
			printerr("Unable to save the selected chest portrait.")
			quit(1)
			return
		outputs.append({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path),
			"state": "closed" if index == 0 else "open", "width": 512, "height": 512})
	var manifest := {"version": 1, "asset_id": "wayfarer-oak", "source_model": str(style.model),
		"source_model_sha256": FileAccess.get_sha256("res://" + str(style.model)),
		"acquisition": "Rendered from the integrated chest01 Atelier model; not a source preview.",
		"creator": "See the source model's Atelier provenance record.",
		"license": "See the source model's Atelier license record; no new rights are asserted.",
		"animation": "Authored Open clip sampled at 0 and 1 seconds.",
		"framing": "One camera and one union alpha crop preserve body alignment across both states.",
		"outputs": outputs}
	var file := FileAccess.open(OUTPUT + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	view.free()
	print("Matched Atelier chest portraits rendered: 512 x 512.")
	quit(0)
