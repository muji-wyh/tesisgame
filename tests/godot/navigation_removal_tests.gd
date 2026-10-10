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


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(768, 1024)
	var directory := "user://navigation-removal-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and app._mode_buttons[0].button_pressed,
		"Match is selected and playable on entry")
	check(not app.has_method("_replay")
		and not app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "replay_button"),
		"The Repeat lesson handler and control are removed")
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	app.model.phase = "won"
	app.model.chest_state = "opened"
	app._refresh()
	await settle()
	var actions: Array = app._outcome.find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.is_visible_in_tree() and not button.disabled)
	check(actions == [app._new_adventure_button] and app._default_focus() == app._new_adventure_button,
		"New adventure is the only normal result action and the default focus")
	var retry: Button = app.get("_result_retry_button")
	check(retry != null and app.has_method("_retry_reward_save"), "Reward save retry has its own action")
	if retry != null and app.has_method("_retry_reward_save"):
		app._progress_ready = false
		app._save_error = true
		app._refresh()
		await settle()
		check(retry.is_visible_in_tree() and retry.text == "Retry saving" and not app._new_adventure_button.visible,
			"Only a saving failure exposes Retry saving")
		var words: Array = app.model.lesson_words.duplicate(true)
		retry.grab_focus()
		retry.pressed.emit()
		check(not app._save_error and app.model.phase == "won" and app.model.lesson_words == words,
			"Retrying storage does not repeat or replace the lesson")
		check(root.gui_get_focus_owner() == app._new_adventure_button,
			"A successful retry restores keyboard focus to the remaining result action")
		retry.pressed.emit()
		check(app.model.phase == "won" and app.model.lesson_words == words,
			"An inactive retry action cannot restart play")
	app._progress_ready = true
	app._save_error = false
	app.medal_progress.counts = {"spring-3": 3}
	app._show_collection()
	await settle()
	var before_words: Array = app.model.lesson_words.duplicate(true)
	check(app._age_catalog.is_visible_in_tree() and app._collection_title.text == "Lv0 · Baby Pip",
		"The independent level-and-age word catalog replaces the retired Pip room")
	for retired in ["_start_gift_adventure", "_show_leaderboard", "_select_room_item"]:
		check(not app.has_method(retired), "Retired navigation cannot be invoked: " + retired)
	check(app._world_choices.is_visible_in_tree() and app._world_scroll.is_ancestor_of(app._world_grid),
		"The world choices are directly available below learning progress")
	for width in [320, 768]:
		root.size = Vector2i(width, 1024)
		await settle()
		check(app._world_grid is HBoxContainer, "Theme choices keep a single horizontal row without shrinking their targets")
		for index in range(app.theme_buttons.size()):
			var button: Button = app.theme_buttons[index]
			var scale: float = app.Style.ui_scale(app)
			button.grab_focus()
			await settle()
			check(button.is_visible_in_tree() and button.size.x * scale >= 44 and button.size.x * scale < 46
				and button.size.y * scale >= 44 and button.size.y * scale < 46
				and app._world_scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Focus reveals each full-size world choice within its own strip")
			check(button.text.is_empty() and button.tooltip_text == app.Data.theme(app.model.THEMES[index]).name,
				"Compact world icons retain their full names")
	var cards: Array = app.model.cards.duplicate(true)
	var hints: int = app.model.hints_remaining
	app.theme_buttons[4].pressed.emit()
	check(app.collection_page.visible and app._age_catalog.is_visible_in_tree() and app.model.theme_id == "ocean"
		and app.model.cards == cards and app.model.hints_remaining == hints,
		"A direct world choice keeps the page open and preserves the current game")
	app._hide_collection()
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and app.model.lesson_words != before_words,
		"New adventure starts a fresh Match board")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Navigation removal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
