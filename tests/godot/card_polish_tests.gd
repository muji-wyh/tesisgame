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
	check(Data.get_script_constant_map().get("GAME_NAME", "") == "Pip and Words", "The visible game has its new Pip and Words name")
	var backgrounds := ["#effbef", "#fff4df", "#fff2e5", "#eef5ff", "#e7f8fa", "#f1edfb", "#f0f8e7", "#fff0f7"]
	for index in range(Data.THEMES.size()):
		var palette: Dictionary = Data.theme(Data.THEMES.keys()[index])
		check(palette.background == Color(backgrounds[index]), "Each theme has its own refreshed background")
		check(contrast(Color.WHITE, palette.accent) >= 4.5, "Primary actions and Using badges keep readable white text")
		check(contrast(load("res://scripts/ui_style.gd").INK, palette.background) >= 4.5, "The new background retains readable text")
	check(FileAccess.file_exists("res://scripts/card_motion.gd"), "A shared bounded card press reaction exists")
	check(FileAccess.file_exists("res://scripts/toy_card.gd"), "Pip's toy cards have a focused presentation component")
	if failures:
		quit(1)
		return
	await _test_motion()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://card-polish-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	check(root.title == "Pip and Words", "The native window displays the new name")
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
	app.medal_progress.counts = {"spring-1": 3, "ocean-1": 1}
	check(app.playroom_state.select_item("toy-spring", app.medal_progress.counts), "The fixture equips its earned flower")
	app._refresh_collection()
	await settle()
	var room = app._room
	var flower = room.item_buttons["toy-spring"]
	var shell = room.item_buttons["toy-ocean"]
	var ordinary: Color = shell.get_theme_stylebox("normal").bg_color
	var before: Dictionary = app.medal_progress.counts.duplicate(true)
	var scroll: int = app._collection_scroll.scroll_vertical
	shell.pressed.emit()
	check(shell._press_motion._tween != null, "A valid toy-card click animates its illustration")
	if shell._press_motion._tween != null:
		shell._press_motion._tween.pause()
	await settle()
	check(app.playroom_state.toy_id == "toy-spring" and app.medal_progress.counts == before,
		"Previewing a shell cannot equip it or change earned pieces")
	check(flower.badge.text == "Using" and flower.badge.is_visible_in_tree() and room.goal_label.text.contains("Preview")
		and room.item_buttons.values().filter(func(button: Button) -> bool: return button.badge.text == "Using").size() == 1,
		"Exactly one Using badge is distinct from the current Preview")
	check(shell.get_theme_stylebox("normal").bg_color == ordinary
		and shell.get_theme_stylebox("normal").get_border_width(SIDE_LEFT) == 1,
		"A preview keeps a neutral surface rather than another selected card fill")
	check(app._collection_scroll.scroll_vertical == scroll, "Card presentation changes do not jump the collection")
	check(room.goal_label.text.contains("1/3") and room.goal_button.get_parent() == shell,
		"The preview retains its real requirement and inline action")
	app.set_reduced_motion(true)
	check(shell._press_motion._tween == null and shell.picture.scale == Vector2.ONE,
		"Reduced motion immediately settles the toy-card reaction")
	check(app.playroom_state.set_goal("toy-ocean", app.medal_progress.counts), "The fixture can keep a gift goal")
	room.action_button.pressed.emit()
	check(room.goal_label.text.contains("Goal") and flower.badge.text == "Using", "Returning from preview distinguishes the gift Goal from the equipped toy")
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		for button in room.item_buttons.values():
			check(absf(button.size.y * scale - 128) <= 1 and button.size.x * scale >= 44,
				"Polished toy cards retain uniform 128px height and usable targets")
			for label in [button.title_label, button.detail_label, button.badge]:
				if label.is_visible_in_tree():
					check(button.get_global_rect().grow(1).encloses(label.get_global_rect()),
						"Toy titles, details and badges stay inside their cards")
			check(button.get_global_rect().grow(1).encloses(button.picture.get_global_rect()), "Illustrations fit the tile")
		check(shell.get_global_rect().grow(1).encloses(room.goal_label.get_global_rect())
			and shell.get_global_rect().encloses(room.goal_button.get_global_rect()),
			"The gift label and 44px action fit both stacked and wide card layouts")
	app._hide_collection()
	app.set_reduced_motion(false)
	check(app.new_round(27, false, "at-home", "match", "pillow"), "The new vocabulary can start animated Match cards")
	await settle()
	for id in ["pillow:image", "pillow:word"]:
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
	await _test_retry_layout(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Card polish: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_retry_layout(app) -> void:
	var confirmed = app.playroom_state
	app.playroom_state = app.PlayroomState.new("")
	app._playroom_ready = false
	app._show_collection()
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var card = app._room.item_buttons["toy-ball"]
		card.pressed.emit()
		await settle()
		check(not app._playroom_ready and card.detail_label.text.contains("Tap again to retry"),
			"A real failed-load selection exposes the starter toy's retry instructions")
		_check_retry_regions(card, card.detail_label, null, app.Style.ui_scale(app))
	app.playroom_state = confirmed
	app._playroom_ready = true
	confirmed.goal_item_id = "toy-spring"
	app._refresh_collection()
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var card = app._room.item_buttons["toy-spring"]
		app._room.show_item_error("toy-spring", "Not saved\nTap arrow to retry", "Fixture save failure.")
		await settle()
		_check_retry_regions(card, app._room.goal_label, app._room.goal_button, app.Style.ui_scale(app))


func _check_retry_regions(card, label: Label, action: Control, scale: float) -> void:
	var badge: Rect2 = card.badge.get_global_rect()
	check(card.badge.is_visible_in_tree() and card.badge.text == "Using",
		"The equipped toy remains identifiable while saving needs recovery")
	check(not badge.intersects(label.get_global_rect()),
		"The Using badge never covers retry instructions: badge=%s text=%s" % [badge, label.get_global_rect()])
	check(card.get_global_rect().grow(-4 / scale).encloses(label.get_global_rect())
		and card.get_global_rect().encloses(badge) and absf(card.size.y * scale - 128) <= 1,
		"The full retry state fits inside the unchanged card")
	if card.picture.is_visible_in_tree():
		check(not card.picture.get_global_rect().intersects(badge), "Retry layout keeps the badge clear of the illustration")
	if action != null:
		check(not action.get_global_rect().intersects(badge) and action.size.x * scale >= 44,
			"The inline retry action retains its unobstructed target")


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
