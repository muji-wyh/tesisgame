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
	for frame in range(5):
		await process_frame


func _run() -> void:
	var directory := "user://layout-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.find_child("Explore", true, false) == null and not app.has_method("_show_adventures"),
		"Explore is removed rather than hidden behind another entry")
	check(app.find_child("AdventureBook", true, false) == null, "The removed picker creates no hidden page")
	check(app.find_children("*", "Label", true, false).all(func(label: Label) -> bool:
		return not label.is_visible_in_tree() or not label.text in ["Pip and Words", "Play time", "Find 3 pairs"]),
		"The gameplay header has no redundant title")
	check(app._mode_buttons.size() == 3 and app.MODES.keys() == ["match", "memory", "pop"],
		"The centered mode switch contains Match, Memory and Voice Pop")
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900), Vector2i(599, 900), Vector2i(600, 900), Vector2i(1040, 480)]:
		root.size = dimensions
		app.size = dimensions
		for mode in ["match", "memory"]:
			app.choose_mode(mode)
			await settle()
			var view: Control = app._match_playfield if mode == "match" else app._memory
			var css_scale: float = app.Style.ui_scale(app)
			var inline_modes: bool = dimensions.x * css_scale >= 680
			var play_top: int = 76 if inline_modes else 128
			check(absf(view.get_global_rect().position.y * css_scale - play_top) <= 2,
				"%s %s: the responsive header leaves play at %d CSS pixels: %s" % [dimensions, mode, play_top, view.get_global_rect()])
			if inline_modes:
				check(app._header_duck_slot.get_global_rect().end.x <= app._mode_row.global_position.x
					and app._mode_row.get_global_rect().end.x <= app._toolbar.global_position.x,
					"Inline mode tabs sit between Pip on the left and the action icons on the right")
			check(app.get_global_rect().grow(1).encloses(view.get_global_rect()), "%s %s: the playfield fits the screen" % [dimensions, mode])
			check(app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()), "World choices stay out of active play")
			check(not app._room.is_visible_in_tree(), "The room does not take space above the game")
			check(app.duck.is_visible_in_tree(), "Pip remains a visible guide")
			for counter in [app._success, app._mistakes]:
				if counter.is_visible_in_tree():
					check(not counter.get_global_rect().intersects(app.duck.get_global_rect()), "Pip cannot cover game progress")
					check(counter.get_parent() == app._header_duck_slot
						and app._header_duck_slot.get_global_rect().grow(1).encloses(counter.get_global_rect()),
						"Numeric progress stays grouped inside Pip's header panel")
			check(app._success.is_visible_in_tree() and app._mistakes.is_visible_in_tree()
				and app._success.total_count == (5 if mode == "memory" else 3)
				and app._mistakes.total_count == (0 if mode == "memory" else 3),
				"Match and Memory keep their own correct totals and mistake policy beside Pip")
			for control in [app.collection_button, app.hint_button, app._voice_button, app._memory.study_button] + app._mode_buttons:
				if control.is_visible_in_tree():
					check(app.get_global_rect().grow(1).encloses(control.get_global_rect()), "Navigation fits the viewport")
					var scale: float = app.Style.ui_scale(app)
					check(control.size.x * scale >= 44 and control.size.y * scale >= 44, "Navigation keeps a 44px touch target")
			for control in [app.collection_button, app.hint_button, app._voice_button, app._memory.study_button]:
				if control.is_visible_in_tree():
					check(control.text.is_empty() and is_equal_approx(control.size.x, control.size.y)
						and control.get_parent() == app._toolbar and is_equal_approx(control.size.y, ceilf(44 / css_scale)),
						"Header actions share one aligned row of 44 CSS-pixel square icons")
			check(app._mode_buttons.all(func(button: Button) -> bool:
				return button.size.x * css_scale < 90 and button.size.y * css_scale < 48),
				"Mode buttons keep natural compact widths and heights at %s %s: %s CSS" % [
					dimensions, mode, app._mode_buttons.map(func(button: Button) -> Vector2: return button.size * css_scale)])
			if mode == "match":
				check(app.grid.get_rect().is_equal_approx(Rect2(Vector2.ZERO, app._match_playfield.size))
					and not app._message.is_visible_in_tree(),
					"The Match grid fills its playfield without a reserved feedback footer")
			if mode == "match" and dimensions == Vector2i(480, 900):
				check(app.grid.size.x * app.grid.size.y >= 0.6 * dimensions.x * dimensions.y,
					"The matching board owns at least 60% of a portrait screen")
	app.choose_mode("match")
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var cards: Array = app.model.cards.duplicate(true)
	var selected: String = app.model.selected_id
	var hints_remaining: int = app.model.hints_remaining
	var lesson_before: Array = app.model.lesson_words.duplicate(true)
	var progress_before: Array = [app.model.phase, app.model.successes, app.model.mistakes, app.model.streak]
	check(not selected.is_empty(), "The world-change fixture contains a real selected card")
	for world_id in ["ocean", "space"]:
		if not app.collection_page.visible:
			app._show_collection()
		await settle()
		check(app.theme_buttons.size() == 8 and app._collection_header.is_ancestor_of(app._world_choices),
			"Wide world choices share the More header")
		check(app.theme_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()), "All eight worlds remain selectable")
		app._world_grid.get_node(app.Data.theme(world_id).name).pressed.emit()
		await settle()
		check(app.model.theme_id == world_id and app.collection_page.visible and app._room.is_visible_in_tree()
			and app.playroom_state.preferred_theme_id == world_id,
			"Choosing a world saves the preference and keeps Pip's room open")
		check(app._mode_id == "match" and app.model.cards == cards and app.model.selected_id == selected
			and app.model.hints_remaining == hints_remaining and app.model.lesson_words == lesson_before
			and [app.model.phase, app.model.successes, app.model.mistakes, app.model.streak] == progress_before,
			"Changing a world preserves the exact round, cards, selection, and hints")
	root.size = Vector2i(480, 900)
	app.size = Vector2(480, 900)
	if not app.collection_page.visible:
		app._show_collection()
	await settle()
	check(app._room._room.get_global_rect().position.y - app._collection_scroll.global_position.y <= 8,
		"Pip's playable scene starts immediately below the persistent More controls, without repeated headings or goals")
	check(not app._room.goal_label.is_visible_in_tree() and not app._room.goal_button.is_visible_in_tree(),
		"Unselected gifts do not create a standalone status or action row")
	check(app._collection_title.text == "Pip" and not app.has_method("_show_reward_section"),
		"More keeps a single room and the shared World strip without retired navigation")
	for dimensions in [Vector2i(480, 900), Vector2i(1040, 900)]:
		root.size = dimensions
		app.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		check(app._collection_back.text.is_empty() and app._collection_back.symbol == app.Icons.Symbol.BACK
			and is_equal_approx(app._collection_back.size.y, ceilf(44 / scale)),
			"More uses a compact Back icon without losing its target size at %s: size=%s scale=%s minimum=%s header=%s" % [
				dimensions, app._collection_back.size, scale, app._collection_back.get_combined_minimum_size(), app._collection_header.size])
		check(app.theme_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()),
			"World choices remain available above Pip's room")
		check(app._world_grid.columns == (4 if dimensions.x == 480 else 8), "World choices use two complete rows on phones and one on wide screens")
		check(app._world_grid.get_theme_constant("h_separation") == roundi(6 / scale),
			"The World strip uses six CSS-pixel gaps with logical-pixel rounding")
		for index in range(app.theme_buttons.size()):
			var button: Button = app.theme_buttons[index]
			var palette: Dictionary = app.Data.theme(app.model.THEMES[index])
			check(button.text.is_empty() and button.tooltip_text == palette.name
				and button.get("accessibility_name") == palette.name and button.icon != null
				and button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"Every World icon retains its exact tooltip and accessible name")
			check(button.size.is_equal_approx(Vector2.ONE * ceilf(52 / scale))
				and app.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Every World icon has a larger 52 CSS-pixel square target")
			check(button.get_theme_constant("icon_max_width") == ceili(36 / scale),
				"World artwork uses a 36 CSS-pixel icon cap")
	app._hide_collection()
	app._progress_ready = false
	app._save_error = true
	app._refresh()
	await settle()
	for control in [app._storage_retry_button, app.collection_button, app.hint_button, app._voice_button]:
		check(app.get_global_rect().grow(1).encloses(control.get_global_rect()), "A saving problem does not push game controls off the screen")
	app._progress_ready = true
	app._save_error = false
	app.model.phase = "lost"
	app._refresh()
	await settle()
	check(not app._mode_row.is_visible_in_tree() and not app._success.is_visible_in_tree(), "Results do not repeat gameplay navigation and counters")
	check(app._outcome.get_global_rect().position.y <= 100, "The result gets the space below one simple header")
	var old_lesson: Array = app.model.lesson_words.duplicate(true)
	app._new_adventure_button.pressed.emit()
	await settle()
	check(app._mode_id == "match" and not app.collection_page.visible and app.model.lesson_words != old_lesson
		and app.grid.is_visible_in_tree(), "New adventure starts a fresh Match round directly")
	var action := Button.new()
	for world in app.model.THEMES:
		for primary in [false, true]:
			app.Style.action_button(action, app.Data.theme(world).accent, primary)
			for state in ["normal", "hover", "pressed"]:
				var fill: Color = action.get_theme_stylebox(state).bg_color.srgb_to_linear()
				var ink: Color = action.get_theme_color("font_color" if state == "normal" else "font_" + state + "_color").srgb_to_linear()
				var fill_luminance: float = 0.2126 * fill.r + 0.7152 * fill.g + 0.0722 * fill.b
				var ink_luminance: float = 0.2126 * ink.r + 0.7152 * ink.g + 0.0722 * ink.b
				check((maxf(fill_luminance, ink_luminance) + 0.05) / (minf(fill_luminance, ink_luminance) + 0.05) >= 4.5,
					world + ": action button text has readable contrast")
	action.free()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Gameplay-first layouts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
