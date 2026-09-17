extends SceneTree

const Data = preload("res://scripts/game_data.gd")

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
	for frame in range(5):
		await process_frame


func _run() -> void:
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var card = load("res://scripts/word_card.gd").new()
	card.setup({"id": "cat:image", "kind": "image", "word": words[0]})
	root.add_child(card)
	card.size = Vector2(180, 140)
	card.refresh(Data.theme("summer"), false, false, false, false)
	var bounds: Rect2 = card.get_global_rect()
	card.play_press()
	check(card._feedback_kind == "tap" and card._feedback.visible,
		"Accepted clicks have a visible themed sparkle reaction")
	if card._feedback_kind == "tap":
		check(card._feedback.particle_count == 8, "Click effects use a small bounded sparkle count")
		card._process(0.18)
		check(card._feedback.progress > 0 and card.get_global_rect() == bounds,
			"The sparkle advances without moving the button's hit box")
		card.play_press()
		check(card._feedback.progress == 0, "A rapid click replaces the previous burst")
		card.stop_press()
		check(not card._feedback.visible, "Cancelling a press settles its extra visual effect")
	card.refresh(Data.theme("summer"), false, false, true, false)
	card.play_press()
	check(card._feedback_kind == "wrong", "Decorative clicks cannot replace meaningful wrong-answer feedback")
	card.clear_feedback()
	card.set_reduced_motion(true)
	card.play_press()
	check(not card._feedback.visible and card._press_motion._tween == null,
		"Reduced motion retains a still card without decorative particles")
	card.queue_free()
	await process_frame
	var probe = load("res://scripts/game_ui.gd").new()
	var ready: bool = probe.has_method("_style_voice_button")
	check(ready, "The microphone has a dedicated prominent style")
	probe.free()
	if ready:
		await _test_voice_style()
	print("Playful affordances: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_voice_style() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://voice-style-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	var original: Array = app.model.cards.duplicate(true)
	for theme_id in Data.THEMES:
		app.choose_theme(theme_id)
		var button: Button = app._voice_button
		button.disabled = false
		app._style_voice_button()
		check(button.get_theme_stylebox("normal").bg_color == Data.theme(theme_id).accent
			and button.get_theme_color("font_color") == Color.WHITE,
			"Available voice input has a filled theme surface and a contrasting white icon")
		var surface: StyleBox = button.get_theme_stylebox("normal")
		app._style_voice_button()
		check(button.get_theme_stylebox("normal") == surface, "Unchanged voice styling does not recreate its theme resources")
		button.button_pressed = true
		button.engaged = true
		app._style_voice_button()
		check(button.get_theme_stylebox("pressed").bg_color != button.get_theme_stylebox("normal").bg_color,
			"The active voice action has a distinct pressed appearance")
		button.disabled = true
		app._style_voice_button()
		check(button.get_theme_stylebox("disabled").bg_color != Data.theme(theme_id).accent
			and button.get_theme_color("font_disabled_color") != Color.WHITE,
			"Unavailable voice input remains clearly disabled")
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024)]:
		root.size = dimensions
		await settle()
		for button in [app._voice_button, app.hint_button, app.collection_button]:
			check(app.get_global_rect().encloses(button.get_global_rect())
				and button.size.x * app.Style.ui_scale(app) >= 44,
				"Prominence keeps all header targets usable on narrow screens")
	check(app.model.cards == original and not app._voice_mode and not app._voice_listening,
		"Styling never starts recording or changes the round")
	app.choose_mode("learn")
	app.set_reduced_motion(false)
	await settle()
	app._lesson.picture_button.pressed.emit()
	var tap: Control = app._lesson.get("_tap_effect")
	check(tap != null and tap.is_visible_in_tree(), "Learn shares the playful sparkle response, including silent play")
	app._lesson.cancel_swipe()
	check(tap == null or not tap.visible, "A new Learn gesture cancels the decorative burst")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
