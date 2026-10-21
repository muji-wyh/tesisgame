extends SceneTree
## Native collection popup study using the production card, artwork and backdrop.

const Reveal = preload("res://scripts/word_jelly_word_reveal.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Card = preload("res://scripts/word_jelly_word_reveal_card.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Style = preload("res://scripts/ui_style.gd")
const CAT = preload("res://assets/images/ui/modes/cat.webp")
const APPLE = preload("res://assets/images/ui/modes/apple.webp")
const OUTPUT: String = "res://build/jelly-reveal-feedback"
const PROFILE_NAMES: Array[String] = ["Pearl greeting", "Crystal ribbon", "Sapphire spiral",
	"Golden fireworks", "Rose cascade", "Comet coronation", "Aurora embrace", "Starlight festival", "Prismatic finale"]

var content: Control
var backdrop: Control
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var fixture_words: Array[Dictionary] = []
var fixture_chests: Dictionary = {}
var fixture_theme: Dictionary = {}


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


func _supports_level(target: Object, method: String, baseline_count: int) -> bool:
	for entry: Dictionary in target.get_method_list():
		if str(entry.name) == method:
			return entry.args.size() > baseline_count
	return false


func _word(apple: bool = false) -> Dictionary:
	return {"id": "apple" if apple else "cat", "text": "apple" if apple else "cat",
		"image": APPLE.resource_path if apple else CAT.resource_path}


func _card(point: Vector2, level: int, age: float, available: Vector2,
		steady: bool = false, batch: bool = false, apple: bool = false) -> Control:
	var result := Card.new()
	content.add_child(result)
	var picture: Texture2D = APPLE if apple else CAT
	var args: Array = [level, _word(apple), picture, Color("#3d9e89"), batch, 1.0,
		0.86 if batch else 1.95, steady]
	if _supports_level(result, "configure", 8):
		args.append(level)
	result.callv("configure", args)
	result.fit_content(available, 1.0)
	result.rest_position = point - result.size * 0.5
	result.elapsed = age
	result.sync()
	return result


func _present(reveal: Control, level: int, age: float = 0.0, batch: bool = false, apple: bool = false) -> void:
	var args: Array = [_word(apple), APPLE if apple else CAT, Color("#3d9e89"), batch, age]
	if _supports_level(reveal, "present", 5):
		args.append(level)
	reveal.callv("present", args)


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


func _capture(name: String, state: Dictionary = {}) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = OUTPUT + "/" + name + ".png"
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var error: Error = root.get_texture().get_image().save_png(destination)
	if error != OK:
		push_error("Could not save " + destination)
		quit(1)
		return
	captures.append({"file": destination, "size": [root.size.x, root.size.y], "state": state})


func _comparison(prefix: String) -> void:
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844)]:
		await _resize(dimensions)
		_label("Collected word", Vector2(0, 24), Vector2(dimensions.x, 44), 28)
		_label("Same production popup at +0.24 seconds", Vector2(0, 70), Vector2(dimensions.x, 28), 16)
		var result: Control = _card(Vector2(dimensions) * 0.5, 9, 0.24, Vector2(dimensions))
		await _capture("%s-%dx%d" % [prefix, dimensions.x, dimensions.y], result.snapshot())


func _levels() -> void:
	await _resize(Vector2i(1440, 1040))
	_label("Collected word celebration", Vector2(0, 8), Vector2(1440, 44), 30)
	_label("Production popup cards at +0.30 seconds; identical word, scale and backdrop", Vector2(0, 50), Vector2(1440, 26), 17)
	for level in range(1, 10):
		var cell := Vector2((level - 1) % 3, (level - 1) / 3) * Vector2(480, 320) + Vector2(0, 80)
		_card(cell + Vector2(240, 142), level, 0.30, Vector2(480, 320))
		_label("Lv%d - %s" % [level, PROFILE_NAMES[level - 1]], cell + Vector2(8, 266), Vector2(464, 36), 20)
	await _capture("all-nine-levels")
	for level in [4, 9]:
		for age in [0.04, 0.12, 0.24, 0.40, 0.60, 0.90, 1.35, 1.80]:
			await _resize(Vector2i(900, 600))
			_label("Lv%d - %s" % [level, PROFILE_NAMES[level - 1]], Vector2(0, 22), Vector2(900, 44), 28)
			_label("Collected word release + %.2f seconds" % age, Vector2(0, 66), Vector2(900, 30), 18)
			var result: Control = _card(Vector2(450, 320), level, age, Vector2(900, 600))
			await _capture("lv%d-%04dms" % [level, roundi(age * 1000.0)], result.snapshot())


func _prepare_fixture() -> void:
	var data_script: Script = load("res://scripts/game_data.gd")
	var data = data_script.new()
	if not data.load_all():
		failures.append("Production fixture vocabulary did not load.")
		return
	for word: Dictionary in data.words:
		if str(word.id) in ["cat", "apple"]:
			fixture_words.append(word)
	fixture_chests = data.chests
	fixture_theme = data_script.theme("spring")


func _game_fixture(dimensions: Vector2i, steady: bool = false) -> Control:
	var jelly_script: Script = load("res://scripts/word_jelly.gd")
	var view: Control = jelly_script.new()
	content.add_child(view)
	view.size = Vector2(dimensions)
	view.configure(fixture_words, 3, fixture_theme, fixture_chests, true, 42)
	view.set_reduced_motion(steady)
	view.set_process(false)
	view._layout()
	view._word_reveal._rng.seed = 20261022
	return view


func _devices(batch_only: bool = false) -> void:
	# Keep the production board, reveal region and control exclusions around the popup.
	var dimensions_to_capture: Array[Vector2i] = [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390)]
	if batch_only:
		dimensions_to_capture.remove_at(0)
	for dimensions in dimensions_to_capture:
		for steady in [false, true]:
			await _resize(dimensions)
			var view: Control = _game_fixture(dimensions, steady)
			if not batch_only:
				_present(view._word_reveal, 9, 0.24)
				await _capture("game-lv9-%dx%d%s" % [dimensions.x, dimensions.y, "-steady" if steady else ""], view._word_reveal.snapshot())
				view._word_reveal.reset()
				view._word_reveal._rng.seed = 20261022
			for index in range(3):
				_present(view._word_reveal, 7 + index, 0.0, true, index % 2 == 1)
				view._word_reveal.advance(Model.BATCH_BEAT_SECONDS if index < 2 else 0.18)
			await _capture("batch-%dms-%dx%d%s" % [roundi(Model.BATCH_BEAT_SECONDS * 1000.0), dimensions.x, dimensions.y, "-steady" if steady else ""], view._word_reveal.snapshot())


func _frames() -> void:
	# Fixed-time samples can be encoded at 30 fps without changing any game clock.
	await _resize(Vector2i(960, 600))
	_label("Collected word: normal-speed comparison", Vector2(0, 20), Vector2(960, 44), 28)
	_label("Lv1", Vector2(0, 470), Vector2(320, 36), 22)
	_label("Lv4 - Firework bloom", Vector2(320, 470), Vector2(320, 36), 22)
	_label("Lv9 - Grand bouquet", Vector2(640, 470), Vector2(320, 36), 22)
	var cards: Array[Control] = []
	for index in range(3):
		cards.append(_card(Vector2(160 + 320 * index, 285), [1, 4, 9][index], 0.0, Vector2(320, 400)))
	for frame in range(64):
		for card: Control in cards:
			card.elapsed = frame / 30.0
			card.sync()
		await _capture("animation/frame-%03d" % frame)


func _batch_frame_count() -> int:
	return ceili((8.0 * Model.BATCH_BEAT_SECONDS + Reveal.BATCH_SECONDS) * 30.0) + 1


func _batch_frame_directory() -> String:
	return "batch-animation-%dms" % roundi(Model.BATCH_BEAT_SECONDS * 1000.0)


func _rapid_frames() -> void:
	await _resize(Vector2i(390, 844))
	var view: Control = _game_fixture(Vector2i(390, 844))
	var next_release: int = 0
	for frame in range(_batch_frame_count()):
		var time: float = frame / 30.0
		if frame > 0:
			view._word_reveal.advance(1.0 / 30.0)
		while next_release < 9 and time + 0.0001 >= next_release * Model.BATCH_BEAT_SECONDS:
			_present(view._word_reveal, 1 + next_release, maxf(0.0, time - next_release * Model.BATCH_BEAT_SECONDS), true, next_release % 2 == 1)
			next_release += 1
		await _capture("%s/frame-%03d" % [_batch_frame_directory(), frame], view._word_reveal.snapshot())


func _write_report(baseline: bool, batch_only: bool = false) -> void:
	var filename: String = "baseline-render-report.json" if baseline else "render-report.json"
	if batch_only:
		filename = "batch-%dms-render-report.json" % roundi(Model.BATCH_BEAT_SECONDS * 1000.0)
	var file := FileAccess.open(OUTPUT + "/" + filename, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "Native collection popup study", "captures": captures,
		"notice": "Isolated production controls and explicit board fixtures, not an end-to-end input or audio recording.",
		"release_interval": Model.BATCH_BEAT_SECONDS,
		"animation": {} if baseline or batch_only else {"directory": "animation", "frames": 64, "fps": 30, "audio": false},
		"batch_animation": {} if baseline or batch_only else {"directory": _batch_frame_directory(), "frames": _batch_frame_count(),
			"fps": 30, "release_interval": Model.BATCH_BEAT_SECONDS, "audio": false},
		"failures": failures, "renderer": RenderingServer.get_video_adapter_name()}, "\t") + "\n")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This harness requires the native renderer; omit --headless.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	backdrop = Backdrop.new()
	root.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var batch_only: bool = "--batch-only" in OS.get_cmdline_user_args()
	if batch_only:
		_prepare_fixture()
		await _devices(true)
		_write_report(false, true)
		print("Jelly reveal batch study: %d captures" % captures.size())
		quit(0 if failures.is_empty() else 1)
		return
	await _comparison("before" if baseline else "after")
	if not baseline:
		_prepare_fixture()
		await _levels()
		await _devices()
		await _frames()
		await _rapid_frames()
	_write_report(baseline)
	print("Jelly reveal study: %d captures" % captures.size())
	quit(0 if failures.is_empty() else 1)
