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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://layout-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
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
	check(app._mode_buttons.size() == 5 and app.MODES.keys() == ["match", "memory", "pop", "phrase", "jelly"],
		"Pip's mode switch contains all five games")
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900), Vector2i(599, 900), Vector2i(600, 900), Vector2i(1040, 480)]:
		root.size = dimensions
		app.size = dimensions
		for mode in ["match", "memory", "phrase"]:
			app.choose_mode(mode)
			await settle()
			var view: Control = app._match_playfield if mode == "match" else app._memory if mode == "memory" else app._phrase
			var css_scale: float = app.Style.ui_scale(app)
			var play_top: int = 130 if mode in ["match", "memory"] else 76
			check(absf(view.get_global_rect().position.y * css_scale - play_top) <= 2,
				"%s %s: the responsive header leaves play at %d CSS pixels: %s" % [dimensions, mode, play_top, view.get_global_rect()])
			check(app._header_duck_slot.get_global_rect().end.x <= app._toolbar.global_position.x,
				"Pip and the action icons share the compact header without permanent mode tabs")
			check(app.get_global_rect().grow(1).encloses(view.get_global_rect()), "%s %s: the playfield fits the screen" % [dimensions, mode])
			check(app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()), "World choices stay out of active play")
			check(not app.collection_page.is_visible_in_tree(), "The room does not take space above the game")
			check(app.duck.is_visible_in_tree(), "Pip remains a visible guide")
			check(is_equal_approx(app._header_duck_slot.size.x, ceilf(52 / css_scale))
				and app._header_duck_slot.get_theme_stylebox("panel") is StyleBoxEmpty,
				"Every mode keeps Pip in a compact transparent header slot")
			check(app.find_child("MemoryProgress", true, false) == null and app.find_child("MemoryMistakes", true, false) == null,
				"Changing game modes cannot recreate the removed Memory counters")
			for control in [app.collection_button, app.hint_button, app._voice_button, app._memory.study_button] + app._mode_buttons:
				if control.is_visible_in_tree():
					check(app.get_global_rect().grow(1).encloses(control.get_global_rect()), "Navigation fits the viewport")
					var scale: float = app.Style.ui_scale(app)
					check(control.size.x * scale >= 44 and control.size.y * scale >= 44, "Navigation keeps a 44px touch target")
			for control in [app.hint_button, app._voice_button, app._memory.study_button]:
				if control.is_visible_in_tree():
					check(control.text.is_empty() and is_equal_approx(control.size.x, control.size.y)
						and control.get_parent() == app._toolbar and is_equal_approx(control.size.y, ceilf(44 / css_scale)),
						"Header actions share one aligned row of 44 CSS-pixel square icons")
			check(app.collection_button == app._growth_button and app._growth_button.get_parent() == app._toolbar
				and app._growth_button.level_label.text == app.growth.snapshot().label
				and app._growth_button.get_global_rect().grow(0.5).encloses(app._growth_bar.get_global_rect())
				and is_equal_approx(app._growth_button.get_global_rect().get_center().y, app._toolbar.get_global_rect().get_center().y),
				"The level badge opens learning progress with its track contained in the aligned header target")
			check(app._mode_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
				"Closed mode choices leave more space for gameplay at %s %s" % [dimensions, mode])
			if mode == "match":
				check(app.grid.get_rect().is_equal_approx(Rect2(Vector2.ZERO, app._match_playfield.size))
					and not app._message.is_visible_in_tree(),
					"The Match grid fills its playfield without a reserved feedback footer")
			if mode == "match" and dimensions == Vector2i(480, 900):
				check(app.grid.size.x * app.grid.size.y >= 0.6 * dimensions.x * dimensions.y,
					"The matching board owns at least 60% of a portrait screen")
	await _test_voice_layout(app)
	app._show_collection()
	await settle()
	check(app._compact_world.is_visible_in_tree() and not app._world_choices.is_visible_in_tree(),
		"Short landscape notebooks retain the compact world selector without crowding the word catalog")
	app._hide_collection()
	root.size = Vector2i(960, 720)
	app.size = Vector2(960, 720)
	await settle()
	app.choose_mode("match")
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var cards: Array = app.model.cards.duplicate(true)
	var selected: String = app.model.selected_id
	var hints_remaining: int = app.model.hints_remaining
	var lesson_before: Array = app.model.lesson_words.duplicate(true)
	var progress_before: Array = [app.model.phase, (app.model.matched_ids.size() / 2), app.model.mistakes]
	check(not selected.is_empty(), "The world-change fixture contains a real selected card")
	for world_id in ["ocean", "space"]:
		if not app.collection_page.visible:
			app._show_collection()
		await settle()
		check(app.theme_buttons.size() == 8 and app._world_scroll.is_ancestor_of(app._world_grid),
			"World choices stay in their independent horizontal strip")
		check(app.theme_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()), "All eight worlds remain selectable")
		app._world_grid.get_node(app.Data.theme(world_id).name).pressed.emit()
		await settle()
		check(app.model.theme_id == world_id and app.collection_page.visible and app._age_catalog.is_visible_in_tree()
			and app._presentation.preferred_theme == world_id,
			"Choosing a world saves the preference and keeps the growth catalog open")
		check(app._mode_id == "match" and app.model.cards == cards and app.model.selected_id == selected
			and app.model.hints_remaining == hints_remaining and app.model.lesson_words == lesson_before
			and [app.model.phase, (app.model.matched_ids.size() / 2), app.model.mistakes] == progress_before,
			"Changing a world preserves the exact round, cards, selection, and hints")
	root.size = Vector2i(480, 900)
	app.size = Vector2(480, 900)
	if not app.collection_page.visible:
		app._show_collection()
	await settle()
	check(app._age_catalog.is_visible_in_tree() and app._growth_summary.is_visible_in_tree(),
		"Growth presents progress and a vocabulary catalog without the retired room")
	check(app._collection_title.text == "Lv0 · Baby Pip" and not app.has_method("_show_reward_section"),
		"The growth notebook combines the independent level and Pip age in one title")
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
			"World choices remain available below the growth catalogue")
		check(app._world_grid is HBoxContainer, "World choices remain in one horizontally scrollable row at every width")
		check(app._world_grid.get_theme_constant("separation") == ceili(6 / scale),
			"The World strip uses six CSS-pixel gaps with logical-pixel rounding")
		for index in range(app.theme_buttons.size()):
			var button: Button = app.theme_buttons[index]
			var palette: Dictionary = app.Data.theme(app.model.THEMES[index])
			check(button.text.is_empty() and button.tooltip_text == palette.name
				and button.get("accessibility_name") == palette.name and button.icon != null
				and button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"Every World icon retains its exact tooltip and accessible name")
			check(button.size.is_equal_approx(Vector2.ONE * (44 / scale))
				and is_equal_approx(button.global_position.y, app.theme_buttons[0].global_position.y),
				"Every World icon keeps a 44 CSS-pixel square touch target in one row")
			check(button.get_theme_constant("icon_max_width") == ceili(30 / scale),
				"World artwork uses a 30 CSS-pixel icon cap")
	app._hide_collection()
	app._progress_ready = false
	app._save_error = true
	app._refresh()
	await settle()
	for control in [app._storage_retry_button, app.collection_button, app.hint_button, app._voice_button]:
		check(app.get_global_rect().grow(1).encloses(control.get_global_rect()), "A saving problem does not push game controls off the screen")
	app._progress_ready = true
	app._save_error = false
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").earn_pair_chest(app)
	app.model.phase = "won"
	app.model.chest_state = "opened"
	app._refresh()
	await settle()
	check(not app._mode_row.is_visible_in_tree(), "Results do not repeat gameplay navigation")
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


func _test_voice_layout(app) -> void:
	app.choose_mode("match")
	var previous_scale_mode: int = root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(320, 568), Vector2i(360, 640), Vector2i(568, 320)]:
		root.size = dimensions
		app.size = dimensions
		for voice_enabled in [false, true]:
			app._on_voice_state([voice_enabled, voice_enabled, ""])
			await settle()
			var context: String = "%s with voice %s" % [dimensions, voice_enabled]
			var playfield: Rect2 = app._match_playfield.get_global_rect()
			var speech_panel: Rect2 = app._voice_space.get_global_rect()
			var css_scale: float = app.Style.ui_scale(app)
			check(app.grid.columns == (2 if dimensions.x < dimensions.y else 5),
				context + ": five pairs retain portrait columns or landscape rows")
			check(app.grid.get_global_rect().is_equal_approx(playfield),
				context + ": the grid fits the actual space remaining below speech controls")
			for card in app.cards.values():
				check(app.get_global_rect().grow(1).encloses(card.get_global_rect())
					and playfield.grow(1).encloses(card.get_global_rect()),
					context + ": every card stays entirely inside the viewport and playfield")
				check(card.size.x * css_scale >= 44 and card.size.y * css_scale >= 44,
					context + ": all ten cards retain usable touch targets")
				if voice_enabled:
					check(not card.get_global_rect().intersects(speech_panel),
						context + ": speech controls do not obscure a card")
	app._on_voice_state([false, false, ""])
	root.content_scale_mode = previous_scale_mode
	await settle()
