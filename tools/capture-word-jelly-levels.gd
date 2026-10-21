extends SceneTree
## Native effect study with ordinary-sized production Jelly tiles, not gameplay.

const Effects = preload("res://scripts/word_jelly_collection_fx.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Style = preload("res://scripts/ui_style.gd")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const CAT = preload("res://assets/images/ui/modes/cat.webp")
const OUTPUT: String = "res://build/jelly-level-feedback"

var content: Control
var backdrop: Control
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _label(value: String, point: Vector2, dimensions: Vector2, pixels: int = 20) -> Label:
	var result: Label = Style.label(value, pixels)
	result.position = point
	result.size = dimensions
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(result)
	return result


func _tile(point: Vector2, level: int, edge: float = 64.0) -> Control:
	var result := Tile.new()
	content.add_child(result)
	result.position = point - Vector2.ONE * edge * 0.5
	result.size = Vector2.ONE * edge
	var word: Dictionary = {"id": "cat", "text": "cat", "image": CAT.resource_path}
	result.configure({"id": level, "kind": "word", "jelly_kind": "merged", "word": word,
		"image_word": word, "text": "cat", "display_text": "cat", "merge_level": level,
		"width": 1, "height": 1, "mass": 2, "fragments": 0}, GEL, CAT, null, Color("#3d9e89"), true)
	result.set_merged_presentation(0.5, true)
	return result


func _effect(rect: Rect2, point: Vector2, level: int, age: float, steady: bool = false) -> Control:
	var result := Effects.new()
	content.add_child(result)
	result.configure_layout(rect)
	result.set_reduced_motion(steady)
	result.present(point, level, Color("#3d9e89"), false, age)
	return result


func _resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	backdrop.size = Vector2(dimensions)
	if content != null:
		content.free()
	content = Control.new()
	root.add_child(content)
	content.size = Vector2(dimensions)
	await process_frame
	await process_frame


func _capture(name: String, effect_state: Dictionary = {}) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = OUTPUT + "/" + name + ".png"
	var error: Error = root.get_texture().get_image().save_png(destination)
	if error != OK:
		push_error("Could not save " + destination)
		quit(1)
		return
	captures.append({"file": destination, "size": [root.size.x, root.size.y], "effect": effect_state})


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	backdrop = Backdrop.new()
	root.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	await _resize(Vector2i(1440, 1040))
	_label("Jelly collection levels", Vector2(0, 8), Vector2(1440, 44), 30)
	_label("Native effect study: ordinary 1 x 1 Jelly shown as a size reference", Vector2(0, 48), Vector2(1440, 26), 17)
	for level in range(1, 10):
		var cell := Vector2((level - 1) % 3, (level - 1) / 3) * Vector2(480, 320) + Vector2(0, 80)
		var point: Vector2 = cell + Vector2(240, 150)
		_tile(point, level)
		var selected: Dictionary = Effects.profile(level)
		_effect(Rect2(cell, Vector2(480, 320)), point, level, float(selected.seconds) * 0.38)
		_label("Lv%d - %s" % [level, selected.name], cell + Vector2(8, 268), Vector2(464, 36), 20)
	await _capture("all-nine-levels")
	for age in [0.04, 0.12, 0.30, 0.55, 0.85]:
		await _resize(Vector2i(900, 600))
		_label("Lv4 - Firework bloom", Vector2(0, 20), Vector2(900, 40), 28)
		_label("Collection release + %.2f seconds" % age, Vector2(0, 60), Vector2(900, 30), 18)
		var point := Vector2(450, 320)
		var tile: Control = _tile(point, 4)
		tile.modulate.a = maxf(0.0, 1.0 - float(age) / 0.15)
		var fx: Control = _effect(Rect2(Vector2.ZERO, Vector2(900, 600)), point, 4, age)
		await _capture("lv4-%03dms" % roundi(float(age) * 1000), fx.snapshot())
	for steady in [false, true]:
		await _resize(Vector2i(390, 844))
		_label("Lv4 - Firework bloom", Vector2(0, 24), Vector2(390, 36), 24)
		_label("Reduced motion" if steady else "Phone scale effect study", Vector2(0, 61), Vector2(390, 28), 16)
		# Real tile controls retain a normal six-column cell pitch around the release.
		for row in range(6):
			for column in range(6):
				var point := Vector2(35 + column * 64, 220 + row * 64)
				if row == 2 and column == 2:
					continue
				_tile(point, 1 + (row + column) % 9, 58.0)
		var point := Vector2(163, 348)
		var fx: Control = _effect(Rect2(Vector2(0, 130), Vector2(390, 620)), point, 4, 0.27, steady)
		await _capture("lv4-phone-steady" if steady else "lv4-phone", fx.snapshot())
	var report: Dictionary = {"kind": "Native effect study with acquired production textures and WordTile controls",
		"notice": "Reference tiles remain visible in the sheet for scale comparison. These are isolated effects, not an end-to-end gameplay or audio capture.",
		"captures": captures, "renderer": RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(OUTPUT + "/render-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Jelly level effect study: %d captures" % captures.size())
	quit(0)
