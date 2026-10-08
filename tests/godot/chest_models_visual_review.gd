extends SceneTree
## Capture the actual shared ChestView, including its live model and reward effects.

const Data = preload("res://scripts/game_data.gd")
const Chest = preload("res://scripts/chest_view.gd")
const OUTPUT := "res://build/chest-quality/game-review"
const THEMES := ["autumn", "ocean", "space", "jungle", "candy"]
const LABELS := ["Autumn Harvest Keepsake", "Ocean Lagoon Pearl", "Space Moonstone Vault", "Jungle Meadow Explorer", "Candy Strawberry Bonbon"]
var data = Data.new()
var canvas := Control.new()
var chests: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _label(text: String, location: Vector2, dimensions: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = location
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas.add_child(label)


func _card(theme: String, title: String, location: Vector2, dimensions: Vector2):
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f5f3ed")
	style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = location
	panel.size = dimensions
	canvas.add_child(panel)
	_label(title, location + Vector2(24, 16), Vector2(dimensions.x - 48, 36), 23, Color("#283449"))
	var chest = Chest.new()
	canvas.add_child(chest)
	chest.position = location + Vector2(12, 46)
	chest.size = dimensions - Vector2(24, 58)
	chest.configure_skin(Data.theme(theme), data.chests)
	chest.set_process(false)
	chests.append(chest)
	return chest


func _stage(dimensions: Vector2i, title: String, subtitle: String) -> void:
	for child in canvas.get_children():
		child.free()
	chests.clear()
	root.size = dimensions
	canvas.size = Vector2(dimensions)
	var background := ColorRect.new()
	background.color = Color("#142130")
	background.size = Vector2(dimensions)
	canvas.add_child(background)
	_label(title, Vector2(36, 20), Vector2(dimensions.x - 72, 45), 32, Color("#faf5e9"))
	_label(subtitle, Vector2(38, 69), Vector2(dimensions.x - 76, 32), 17, Color("#afc4d2"))


func _capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(OUTPUT + "/" + name + ".png") != OK:
		push_error("Unable to capture chest review: " + name)
		quit(1)


func _grid() -> void:
	_stage(Vector2i(1440, 1000), "Treasure Collection", "Five new models. Continuous opening, moving hardware, and real surface lighting.")
	for index in range(THEMES.size()):
		var row: int = index / 3
		var column: int = index % 3
		_card(THEMES[index], LABELS[index], Vector2(34 + column * 460, 120 + row * 426), Vector2(446, 408))
	_label("Hold to charge\nRelease the lock\nDiscover the reward", Vector2(1020, 664), Vector2(350, 160), 28, Color("#dce4de"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.add_child(canvas)
	if not data.load_all():
		push_error(data.error)
		quit(1)
		return
	_grid()
	await _capture("collection-closed")
	for chest in chests:
		chest.begin_hold()
		chest.set_hold_progress(0.8)
	await _capture("collection-holding")
	for chest in chests:
		chest.start_open(false)
	for frame in range(61):
		for chest in chests:
			chest._advance_animation(1.0 / 12.0)
		await _capture("motion-%03d" % frame)
	await _capture("collection-opened")
	for index in range(THEMES.size()):
		_stage(Vector2i(1120, 900), LABELS[index], "Live game artwork at close range")
		var chest = _card(THEMES[index], Data.theme(THEMES[index]).name, Vector2(30, 116), Vector2(1060, 750))
		await _capture(THEMES[index] + "-closed")
		chest.start_open(false)
		chest.finish_immediately()
		await _capture(THEMES[index] + "-opened")
	print("Captured five live model designs, close-ups, and a continuous opening sequence.")
	canvas.free()
	quit()
