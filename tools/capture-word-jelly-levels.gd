extends SceneTree
## Native effect study with ordinary-sized production Jelly tiles, not gameplay.

const Effects = preload("res://scripts/word_jelly_collection_fx.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Style = preload("res://scripts/ui_style.gd")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const CAT = preload("res://assets/images/ui/modes/cat.webp")
const OUTPUT: String = "res://build/jelly-level-feedback/six-levels"

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


func _effect(rect: Rect2, point: Vector2, level: int, age: float, steady: bool = false, batch: bool = false) -> Control:
	var result := Effects.new()
	content.add_child(result)
	result.configure_layout(rect)
	result.set_reduced_motion(steady)
	result.present(point, level, Color("#3d9e89"), batch, age)
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
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
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
	await _resize(Vector2i(1440, 740))
	_label("Jelly collection levels", Vector2(0, 8), Vector2(1440, 44), 30)
	_label("Native effect study: ordinary 1 x 1 Jelly shown as a size reference", Vector2(0, 48), Vector2(1440, 26), 17)
	for level in range(1, Model.MAX_MERGE_LEVEL + 1):
		var cell := Vector2((level - 1) % 3, (level - 1) / 3) * Vector2(480, 320) + Vector2(0, 80)
		var point: Vector2 = cell + Vector2(240, 150)
		_tile(point, level)
		var selected: Dictionary = Effects.profile(level)
		_effect(Rect2(cell, Vector2(480, 320)), point, level, minf(0.65, float(selected.seconds) * 0.38))
		_label("Lv%d - %s" % [level, selected.name], cell + Vector2(8, 268), Vector2(464, 36), 20)
	await _capture("all-six-levels")
	for age in [0.04, 0.12, 0.30, 0.55, 0.85, 1.30, 1.80, 2.40, 2.75]:
		await _resize(Vector2i(900, 600))
		_label("Lv4 - Firework bloom", Vector2(0, 20), Vector2(900, 40), 28)
		_label("Collection release + %.2f seconds" % age, Vector2(0, 60), Vector2(900, 30), 18)
		var point := Vector2(450, 320)
		var tile: Control = _tile(point, 4)
		tile.modulate.a = maxf(0.0, 1.0 - float(age) / 0.15)
		var fx: Control = _effect(Rect2(Vector2.ZERO, Vector2(900, 600)), point, 4, age)
		await _capture("lv4-%03dms" % roundi(float(age) * 1000), fx.snapshot())
	for age in [0.55, 1.80, 2.40]:
		await _phone(age)
	await _phone(0.16, true)
	await _phone(0.72, false, true)
	if "--frames" in OS.get_cmdline_user_args():
		await _frames()
	var report: Dictionary = {"kind": "Native six-level effect study with acquired production textures and WordTile controls",
		"notice": "Reference tiles remain visible in the sheet for scale comparison. These are isolated effects, not an end-to-end gameplay or audio capture.",
		"levels": Model.MAX_MERGE_LEVEL, "batch_interval": Model.BATCH_BEAT_SECONDS,
		"animation": {"directory": "animation", "frames": 105, "fps": 30, "audio": false} if "--frames" in OS.get_cmdline_user_args() else {},
		"captures": captures, "renderer": RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(OUTPUT + "/render-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Jelly level effect study: %d captures" % captures.size())
	quit(0)


func _phone(age: float, steady: bool = false, batch: bool = false) -> void:
	await _resize(Vector2i(390, 844))
	_label("Six-level batch" if batch else "Lv4 - Firework bloom", Vector2(0, 24), Vector2(390, 36), 24)
	_label("Reduced motion" if steady else "Batch at 140 ms" if batch else "Release + %.2f seconds" % age, Vector2(0, 61), Vector2(390, 28), 16)
	# Real tile controls use the current well dimensions and a square cell pitch.
	var pitch: float = 384.0 / Model.COLUMNS
	var origin := Vector2(3.0, 130.0)
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			var point: Vector2 = origin + (Vector2(column, row) + Vector2.ONE * 0.5) * pitch
			if row == 2 and column == 2:
				continue
			_tile(point, 1 + (row + column) % Model.MAX_MERGE_LEVEL, pitch * 0.91)
	var point: Vector2 = origin + Vector2(2.5, 2.5) * pitch
	var fx: Control = _effect(Rect2(Vector2(0, 130), Vector2(390, 620)), point, 1 if batch else 4, age, steady, batch)
	if batch:
		for index in range(1, Model.MAX_MERGE_LEVEL):
			fx.present(origin + Vector2(0.5 + index % 5, 1.5 + index / 5) * pitch,
				1 + index, Color("#3d9e89"), true, maxf(0.0, age - index * Model.BATCH_BEAT_SECONDS))
	await _capture("lv4-phone-steady" if steady else "batch-six-phone" if batch else "lv4-phone-%04dms" % roundi(age * 1000.0), fx.snapshot())


func _frames() -> void:
	await _resize(Vector2i(960, 600))
	_label("Six-level collection: release and recovery", Vector2(0, 18), Vector2(960, 44), 26)
	_label("Silent native samples at 30 fps; Lv1 / Lv4 / Lv6", Vector2(0, 62), Vector2(960, 30), 17)
	var effects: Array[Control] = []
	for index in range(3):
		var point := Vector2(160.0 + index * 320.0, 280.0)
		var level: int = [1, 4, 6][index]
		effects.append(_effect(Rect2(Vector2.ZERO, Vector2(960, 600)), point, level, 0.0))
		_label("Lv%d - %s" % [level, Effects.profile(level).name], Vector2(index * 320.0, 480.0), Vector2(320, 44), 19)
	for frame in range(105):
		await _capture("animation/frame-%03d" % frame)
		for fx: Control in effects:
			fx.advance(1.0 / 30.0)
