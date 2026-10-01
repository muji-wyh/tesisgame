extends SceneTree
## Run with a real rendering driver, not the headless dummy renderer.
## Writes individual runtime captures and contact sheets without touching saves.

const Backdrop = preload("res://scripts/talk_quest_backdrop.gd")
const Treasure = preload("res://scripts/talk_quest_chest.gd")
const OUTPUT := "res://build/talk-quest-art-review"
const PAPER := Color("#faf7f0")
var _viewport: SubViewport
var _surface: Control
var _background: ColorRect
var _caption: Label
var _failures: int = 0
var _captures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 480)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if directory_error != OK:
		printerr("Unable to create the Talk Quest art review directory.")
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 570)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_surface = Control.new()
	_viewport.add_child(_surface)
	_background = ColorRect.new()
	_background.color = PAPER
	_surface.add_child(_background)
	_caption = Label.new()
	_caption.add_theme_color_override("font_color", Color("#384964"))
	_caption.add_theme_font_size_override("font_size", 17)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_surface.add_child(_caption)
	var scene_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/talk_quest/scenes/manifest.json"))
	var chest_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/talk_quest/chests/manifest.json"))
	var scene_sheet: Image = _sheet(14, 4, Vector2i(480, 285))
	var scene_start_sheet: Image = _sheet(14, 4, Vector2i(480, 285))
	var narrow_sheet: Image = _sheet(14, 4, Vector2i(320, 210))
	for data: Dictionary in scene_manifest.scenes:
		var art := Backdrop.new()
		_surface.add_child(art)
		art.configure(int(data.level))
		art.set_reduced_motion(true)
		art.process_mode = Node.PROCESS_MODE_DISABLED
		var index: int = int(data.level) - 1
		var caption: String = "%02d  %s" % [int(data.level), str(data.name)]
		var starting: Image = await _capture(art, Vector2i(960, 570), caption + " / start", str(data.id) + "-start.png")
		_blit(scene_start_sheet, starting, index, 4, Vector2i(480, 285))
		art.set_progress(1.0)
		var complete: Image = await _capture(art, Vector2i(960, 570), caption + " / complete", str(data.id) + "-complete.png")
		_blit(scene_sheet, complete, index, 4, Vector2i(480, 285))
		var narrow: Image = await _capture(art, Vector2i(320, 210), caption, str(data.id) + "-320.png")
		_blit(narrow_sheet, narrow, index, 4, Vector2i(320, 210))
		art.queue_free()
		await process_frame
	_save(scene_start_sheet, "backdrops-start.png")
	_save(scene_sheet, "backdrops-complete.png")
	_save(narrow_sheet, "backdrops-320.png")
	var closed_sheet: Image = _sheet(20, 5, Vector2i(280, 267))
	var moving_sheet: Image = _sheet(20, 5, Vector2i(280, 267))
	var open_sheet: Image = _sheet(20, 5, Vector2i(280, 267))
	var narrow_chest_sheet: Image = _sheet(20, 5, Vector2i(320, 312))
	for data: Dictionary in chest_manifest.chests:
		var art := Treasure.new()
		_surface.add_child(art)
		art.configure(data)
		art.process_mode = Node.PROCESS_MODE_DISABLED
		var index: int = int(data.index) - 1
		var caption: String = "%02d  %s" % [int(data.index), str(data.name)]
		for pose in ["closed", "opening", "open"]:
			var seconds: float = {"closed": 0.0, "opening": 2.55, "open": 5.0}[pose]
			art.set_preview_time(seconds)
			var frame: Image = await _capture(art, Vector2i(420, 400), caption + " / " + pose, str(data.id) + "-" + pose + ".png")
			var sheet: Image = {"closed": closed_sheet, "opening": moving_sheet, "open": open_sheet}[pose]
			_blit(sheet, frame, index, 5, Vector2i(280, 267))
		art.set_reduced_motion(true)
		art.set_preview_time(5.0)
		var narrow: Image = await _capture(art, Vector2i(320, 312), caption, str(data.id) + "-320.png")
		_blit(narrow_chest_sheet, narrow, index, 5, Vector2i(320, 312))
		art.queue_free()
		await process_frame
	_save(closed_sheet, "chests-closed.png")
	_save(moving_sheet, "chests-opening.png")
	_save(open_sheet, "chests-open.png")
	_save(narrow_chest_sheet, "chests-320-reduced-motion.png")
	var report := {"captures": _captures, "failures": _failures,
		"scenes": 14, "chests": 20, "scene_progress": [0.0, 1.0],
		"chest_times_seconds": [0.0, 2.55, 5.0],
		"narrow_width": 320, "chest_narrow_reduced_motion": true,
		"renderer": RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(OUTPUT + "/report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		_failures += 1
	print("Talk Quest art review: %d PNG captures, %d failures; output %s" % [_captures, _failures, ProjectSettings.globalize_path(OUTPUT)])
	quit(1 if _failures else 0)


func _capture(art: Control, dimensions: Vector2i, caption: String, filename: String) -> Image:
	_viewport.size = dimensions
	_surface.size = Vector2(dimensions)
	_background.size = Vector2(dimensions)
	_caption.text = caption
	_caption.position = Vector2.ZERO
	_caption.size = Vector2(dimensions.x, 30)
	_caption.add_theme_font_size_override("font_size", 13 if dimensions.x <= 420 else 17)
	art.position = Vector2(0, 30)
	art.size = Vector2(dimensions.x, dimensions.y - 30)
	art.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	if frame == null or frame.is_empty():
		_failures += 1
		printerr("No rendered pixels for " + filename + "; use a real rendering driver.")
		return Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	_save(frame, filename)
	return frame


func _sheet(count: int, columns: int, cell: Vector2i) -> Image:
	var image := Image.create(columns * cell.x, ceili(float(count) / float(columns)) * cell.y, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)
	return image


func _blit(sheet: Image, frame: Image, index: int, columns: int, cell: Vector2i) -> void:
	var thumb: Image = frame.duplicate()
	thumb.convert(Image.FORMAT_RGBA8)
	thumb.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, cell), Vector2i(index % columns * cell.x, floori(float(index) / float(columns)) * cell.y))


func _save(frame: Image, filename: String) -> void:
	if frame.save_png(OUTPUT + "/" + filename) != OK:
		_failures += 1
		printerr("Unable to save " + filename)
	else:
		_captures += 1
