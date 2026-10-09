extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func contrast(first: Color, second: Color) -> float:
	var a := first.srgb_to_linear()
	var b := second.srgb_to_linear()
	var first_light := 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
	var second_light := 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
	return (maxf(first_light, second_light) + 0.05) / (minf(first_light, second_light) + 0.05)


func _run() -> void:
	var Data = load("res://scripts/game_data.gd")
	check(Data.get_script_constant_map().get("GAME_NAME", "") == "Grow with Pip", "The visible game has its new Grow with Pip name")
	var backgrounds := ["#effbef", "#fff4df", "#fff2e5", "#eef5ff", "#e7f8fa", "#f1edfb", "#f0f8e7", "#fff0f7"]
	for index in range(Data.THEMES.size()):
		var palette: Dictionary = Data.theme(Data.THEMES.keys()[index])
		check(palette.background == Color(backgrounds[index]), "Each theme has its own refreshed background")
		check(contrast(Color.WHITE, palette.accent) >= 4.5, "Primary actions keep readable white text")
		check(contrast(load("res://scripts/ui_style.gd").INK, palette.background) >= 4.5, "The new background retains readable text")
	check(FileAccess.file_exists("res://scripts/card_motion.gd"), "A shared bounded card press reaction exists")
	if failures:
		quit(1)
		return
	await _test_motion()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	await _test_card_style_reuse()
	var directory := "user://card-polish-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	check(root.title == "Grow with Pip", "The native window displays the new name")
	check(ProjectSettings.get_setting("application/config/name") == "Word Buddies",
		"The internal project identity remains stable for existing native and Web save paths")
	var first: String = app.model.cards[0].id
	var card = app.cards[first]
	var rect: Rect2 = card.get_global_rect()
	card.pressed.emit()
	check(card._press_motion._tween != null, "A valid Match click starts a visual response")
	if card._press_motion._tween != null:
		card._press_motion._tween.pause()
		card._press_motion._tween.custom_step(0.04)
	check(card.get_global_rect() == rect and card._face.scale.y < 1.0, "The content presses down without moving the hit target")
	app._show_collection()
	check(card._press_motion._tween == null and card._face.scale.y == 1.0, "Opening More settles card press motion")
	app._hide_collection()
	app.set_reduced_motion(false)
	check(app.new_round(27, false, "", "match", "cat"), "The new vocabulary can start animated Match cards")
	await settle()
	for id in ["cat:image", "cat:word"]:
		var noun_card = app.cards[id]
		var noun_rect: Rect2 = noun_card.get_global_rect()
		noun_card.pressed.emit()
		check(noun_card._press_motion._tween != null and not app.audio.voice.playing,
			"A new noun gets picture and word press feedback even without sound")
		app._show_collection()
		check(noun_card.get_global_rect() == noun_rect and noun_card._press_motion._tween == null
			and noun_card._face.scale == Vector2.ONE, "Opening More settles Match motion without moving its target")
		app._hide_collection()
	app.choose_mode("memory")
	await settle()
	var memory_card = app._memory.card_buttons[0]
	var memory_rect: Rect2 = memory_card.get_global_rect()
	memory_card.pressed.emit()
	check(memory_card._press_motion._tween != null and memory_card._flip != null,
		"Memory combines a bounded press with its existing reveal")
	app.set_reduced_motion(true)
	check(memory_card.get_global_rect() == memory_rect and memory_card._press_motion._tween == null
		and memory_card._face.scale == Vector2.ONE, "Reduced motion settles both press and flip without changing Memory positions")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Card polish: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_card_style_reuse() -> void:
	var Data = preload("res://scripts/game_data.gd")
	var Style = preload("res://scripts/ui_style.gd")
	var word: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))[0]
	var card = preload("res://scripts/word_card.gd").new()
	card.setup({"id": word.id + ":word", "kind": "word", "word": word})
	root.add_child(card)
	card.size = Vector2(180, 120)
	var palette: Dictionary = Data.theme("summer")
	card.refresh(palette, false, false, false, false)
	await settle()
	var resting: Array = _card_styles(card)
	var font_changes := [0]
	card.word_label.theme_changed.connect(func() -> void: font_changes[0] += 1)
	for iteration in range(10):
		card.refresh(palette, false, false, false, false)
	await settle()
	check(_card_styles(card) == resting and font_changes[0] == 0,
		"Refreshing an unchanged card reuses its styles and does not invalidate label font sizing")
	card.refresh(palette, false, false, false, true)
	check(card.disabled and _card_styles(card) == resting,
		"Reusing a card's surface still applies a changed input lock")
	card.refresh(palette, true, false, false, false)
	var selected: Array = _card_styles(card)
	check(not card.disabled and selected != resting and selected[0].border_color == palette.accent
		and selected[0].border_width_left == 2,
		"Selecting a card replaces the resting surface with its active border")
	card.refresh(palette, true, false, false, false)
	check(_card_styles(card) == selected, "Repeated selected-card refreshes reuse the active styles")
	card.refresh(palette, false, true, false, false)
	check(card.disabled and card.match_mark.visible and card.get_theme_stylebox("normal").bg_color == Color("#e7f5e9"),
		"Matched state still updates the surface, badge, and input guard")
	card.refresh(palette, false, false, true, false)
	check(not card.disabled and not card.match_mark.visible
		and card.get_theme_stylebox("normal").border_color == Style.WRONG,
		"Wrong state replaces a cached matched surface and clears its badge")
	card.refresh(palette, false, false, false, false, true)
	check(card.get_theme_stylebox("normal").bg_color == Style.hint_palette(palette).fill,
		"Hints retain their distinct surface after other feedback states")
	var themed: Array = _card_styles(card)
	palette = Data.theme("winter")
	card.refresh(palette, false, false, false, false, true)
	check(_card_styles(card) != themed and card.get_theme_stylebox("focus").border_color == palette.accent,
		"Changing worlds refreshes the full card surface including keyboard focus")
	card.refresh(palette, false, false, false, false)
	var before_light: Resource = card.get_theme_stylebox("normal")
	palette.light = Color("#f2b1d2")
	card.refresh(palette, false, false, false, false)
	check(card.get_theme_stylebox("normal") == before_light,
		"Changing an unused palette light keeps the shared paper surface cached")
	var first_radius: int = card.get_theme_stylebox("normal").corner_radius_top_left
	card.set_back(Control.new())
	card.refresh(palette, false, false, false, false)
	check(card.get_theme_stylebox("normal").corner_radius_top_left == ceili(14 / Style.ui_scale(card))
		and card.get_theme_stylebox("normal").corner_radius_top_left != first_radius,
		"Attaching a Memory back refreshes the card's display-scaled corner size")
	card.queue_free()
	await process_frame


func _card_styles(card: Button) -> Array:
	var result: Array = []
	for key in ["normal", "disabled", "hover", "pressed", "focus"]:
		result.append(card.get_theme_stylebox(key))
	return result


func _test_motion() -> void:
	var Motion = load("res://scripts/card_motion.gd")
	var motion = Motion.new()
	var target := Control.new()
	target.position = Vector2(12, 16)
	target.size = Vector2(140, 120)
	target.scale = Vector2(0.8, 0.9)
	target.rotation = 0.07
	target.pivot_offset = Vector2(4, 5)
	root.add_child(target)
	var position := target.position
	var size := target.size
	motion.play(target, false)
	check(motion._tween != null, "A visible target starts a press reaction")
	motion._tween.pause()
	motion._tween.custom_step(0.04)
	check(target.position == position and target.size == size and is_equal_approx(target.scale.x, 0.8) and target.scale.y < 0.9,
		"The visual reaction preserves layout properties and leaves Memory's X flip axis alone")
	var old: Tween = motion._tween
	motion.play(target, false)
	check(not old.is_valid(), "A rapid click replaces rather than accumulates tweens")
	target.scale.x = 0.4
	motion.stop()
	check(target.scale == Vector2(0.4, 0.9) and is_equal_approx(target.rotation, 0.07)
		and target.pivot_offset == Vector2(4, 5), "Stopping restores captured properties without overwriting an active flip")
	motion.play(target, true)
	check(motion._tween == null, "Reduced motion suppresses the press reaction")
	target.hide()
	motion.play(target, false)
	check(motion._tween == null, "Hidden controls do not start reactions")
	target.queue_free()
	await process_frame
