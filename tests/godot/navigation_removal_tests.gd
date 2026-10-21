extends SceneTree

const PlayerFlow = preload("res://tests/godot/player_flow_fixture.gd")

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


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(768, 1024)
	var directory := "user://navigation-removal-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	PlayerFlow.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	PlayerFlow.enter_mode(app, "match")
	await settle()
	check(app._mode_id == "match" and not app._mode_menu_open() and app.grid.is_visible_in_tree()
		and app.find_child("Mode_match", true, false).button_pressed,
		"Match is selected by identity and playable after entering it from Home")
	check(not app.has_method("_replay")
		and not app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "replay_button"),
		"The Repeat lesson handler and control are removed")
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	PlayerFlow.earn_pair_chest(app)
	app.model.phase = "won"
	check(app._settle_pair_reward(), "The result fixture settles its earned chest before checking navigation")
	app._refresh()
	PlayerFlow.finish_celebration(app)
	await settle()
	var actions: Array = app._single_result.find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.is_visible_in_tree() and not button.disabled \
			and (button.mouse_filter != Control.MOUSE_FILTER_IGNORE or button.focus_mode != Control.FOCUS_NONE))
	check(app._single_result.pip.mouse_filter == Control.MOUSE_FILTER_IGNORE and app._single_result.pip.focus_mode == Control.FOCUS_NONE,
		"The result's decorative Pip is excluded from pointer and keyboard navigation")
	check(actions.has(app._single_result.replay_button) and actions.has(app._single_result.home_button)
		and actions.size() == 2 and app._default_focus() == app._single_result.replay_button,
		"Saved results offer Home and Play again inside the dialog, with Play again as default focus (actions=%s, default=%s, chest=%s, celebration=%s)" % [
			actions.map(func(button: Button) -> String: return str(button.name)), app._default_focus().name,
			app.model.chest_state, app._round_celebration_active()])
	var retry: Button = app._single_result.retry_button
	check(retry != null and app.has_method("_retry_reward_save"), "Reward save retry has its own action")
	if retry != null and app.has_method("_retry_reward_save"):
		app._progress_ready = false
		app._save_error = true
		app._refresh()
		await settle()
		check(retry.is_visible_in_tree() and retry.text == "Retry save" and app._single_result.replay_button.disabled,
			"Only a saving failure exposes Retry save")
		var words: Array = app.model.lesson_words.duplicate(true)
		retry.grab_focus()
		retry.pressed.emit()
		check(not app._save_error and app.model.phase == "won" and app.model.lesson_words == words,
			"Retrying storage does not repeat or replace the lesson")
		check(root.gui_get_focus_owner() == app._single_result.replay_button,
			"A successful retry restores keyboard focus to the remaining result action")
		retry.pressed.emit()
		check(app.model.phase == "won" and app.model.lesson_words == words,
			"An inactive retry action cannot restart play")
	app._progress_ready = true
	app._save_error = false
	var completed_words: Array = app.model.lesson_words.duplicate(true)
	app._single_result.replay_button.pressed.emit()
	await settle()
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and app.model.lesson_words != completed_words,
		"Play again starts a fresh Match board")
	var cards: Array = app.model.cards.duplicate(true)
	var hints: int = app.model.hints_used
	var round_id: String = app._round_id
	app.medal_progress.counts = {"spring-3": 3}
	app._show_collection()
	await settle()
	check(app._age_catalog.is_visible_in_tree() and app._collection_title.text == "Word library"
		and app.growth.level == 0 and app.growth.age == 0,
		"The shared word library retains independent level-and-age progress without the retired Pip room")
	for retired in ["_start_gift_adventure", "_show_leaderboard", "_select_room_item"]:
		check(not app.has_method(retired), "Retired navigation cannot be invoked: " + retired)
	check(app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
		"Learning progress has no theme choices")
	app._hide_collection()
	app._show_mode_menu()
	await settle()
	for width in [320, 768]:
		root.size = Vector2i(width, 1024)
		await settle()
		for button: Button in [app._mode_panel._vocabulary_context, app._mode_panel.collection_button,
				app._mode_panel.sound_button, app._mode_panel.button_for_mode("match")]:
			var scale: float = app.Style.ui_scale(app)
			button.grab_focus()
			await settle()
			check(button.is_visible_in_tree() and app._valid_focus(button) and button.has_focus()
				and button.size.x * scale >= 44 and button.size.y * scale >= 44
				and app._mode_panel.scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Focus reveals the full-size Home %s control at width %d" % [button.name, width])
		check(app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree() and not app._valid_focus(button)),
			"Retired Home theme choices stay hidden and unreachable at width %d" % width)
	var selected_theme: String = app.model.theme_id
	var preferred_theme: String = app._preferred_theme
	app.theme_buttons[4].pressed.emit()
	check(app._mode_menu_open() and app.model.theme_id == selected_theme and app._preferred_theme == preferred_theme
		and app.model.cards == cards and app.model.hints_used == hints,
		"A retired theme action cannot override the learning theme or disturb the current game")
	app._mode_panel._vocabulary_context.pressed.emit()
	await settle()
	check(app.collection_page.is_visible_in_tree() and app._collection_title.text == "Word library",
		"The shared Home vocabulary entry opens the word library")
	app._collection_back.pressed.emit()
	await settle()
	check(app._mode_menu_open() and app.model.cards == cards and app.model.hints_used == hints and app._round_id == round_id,
		"Returning from the word library restores Home without replacing the active round")
	app.choose_mode("match")
	await settle()
	check(app._mode_id == "match" and not app._mode_menu_open() and app.grid.is_visible_in_tree()
		and app.model.cards == cards and app.model.hints_used == hints and app._round_id == round_id
		and app._valid_focus(app._default_focus()),
		"Choosing the current game resumes its board with a usable gameplay focus target")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Navigation removal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
