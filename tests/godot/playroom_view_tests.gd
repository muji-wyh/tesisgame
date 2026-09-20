extends SceneTree

var checks: int = 0
var failures: int = 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture()
		return
	var path := "res://scripts/playroom_view.gd"
	check(FileAccess.file_exists(path), "The dedicated playroom view exists")
	if not FileAccess.file_exists(path):
		_finish()
		return
	var script = load(path)
	check(script != null and script.can_instantiate(), "The playroom view compiles")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var state_script = load("res://scripts/playroom_state.gd")
	var data = load("res://scripts/game_data.gd")
	var state = state_script.new()
	var counts: Dictionary = {}
	var view = script.new()
	root.add_child(view)
	view.size = Vector2(280, 1400)
	view.configure(state, counts, data.theme("spring"), true)
	await process_frame
	await process_frame
	check(view.has_signal("goal_requested"), "The room exposes a goal request for the host to save and start")
	if not view.has_signal("goal_requested"):
		view.queue_free()
		_finish()
		return
	check(view.goal_button is Button and view.controls().has(view.goal_button), "The contextual gift action participates in host focus and scrolling")
	check(not view.goal_button.visible, "An unselected goal does not offer a misleading continue action")
	check(view.duck_slot is Control and not view.feedback_text.is_empty(), "The room exposes the shared Pip slot and accessible feedback")
	check(view.favorite_medal is Control, "The room exposes the existing favourite display")
	check(view.toy_button.icon != null and not view.toy_button.disabled, "The starter ball is visible and immediately playable")
	var starter_tint: Color = view.toy_button.self_modulate
	check(view.toy_button.tooltip_text.ends_with("Tap: Roll the ball"), "The toy names its familiar noun and next action")
	check(view.item_buttons.size() == 9 and view.item_buttons.size() == state.toys().size()
		and view.item_buttons.keys().all(func(id: String) -> bool: return state.item(id).slot == "toy"),
		"Pip exposes exactly the starter ball and eight world toys, with no hidden backdrop buttons")
	_check_toy_partition(view, state, counts, "starter room")
	var original_controls: Array = view.item_buttons.values()
	view.configure(state, counts, data.theme("ocean"), true)
	check(view.item_buttons.values() == original_controls, "Reconfiguration preserves controls used by focus and scrolling")
	var words: Array[String] = []
	var actions: Array[String] = []
	var selections: Array[String] = []
	var previews: Array[String] = []
	var goals: Array[String] = []
	view.goal_requested.connect(func(id: String) -> void: goals.append(id))
	view.word_requested.connect(func(id: String) -> void: words.append(id))
	view.toy_played.connect(func(kind: String) -> void: actions.append(kind))
	view.item_selected.connect(func(id: String) -> void: selections.append(id))
	check(view.has_signal("item_previewed"), "The room announces locked previews to the host")
	if view.has_signal("item_previewed"):
		view.item_previewed.connect(func(message: String) -> void: previews.append(message))
	view.interaction_allowed = func() -> bool: return false
	var feedback_before: String = view.feedback_text
	view.toy_button.pressed.emit()
	view.item_buttons["toy-spring"].pressed.emit()
	check(words.is_empty() and actions.is_empty() and selections.is_empty(), "The parent guard rejects swipe releases and covered-room input before emitting signals")
	check(view.feedback_text == feedback_before and view.item_buttons["toy-spring"].visible, "Blocked room input cannot change its feedback, preview, or toy list")
	view.interaction_allowed = Callable()
	view.toy_button.pressed.emit()
	check(words == ["ball"] and actions == ["roll"], "Playing the starter requests the noun and the roll reaction once")
	check(view.feedback_text.to_lower().contains("ball"), "The toy leaves a named outcome for accessibility announcements")
	view.item_buttons["toy-spring"].pressed.emit()
	check(selections.is_empty(), "A locked preview cannot equip an item")
	check(view.goal_button.tooltip_text.contains("Blossom") and view.goal_label.text.contains("0/3"), "A locked card names its exact medal requirement and current count")
	check(not view.item_buttons["toy-ball"].disabled and view.item_buttons["toy-ball"].focus_mode == Control.FOCUS_ALL,
		"The owned ball card remains keyboard-focusable during a locked preview")
	check(view.goal_button.visible and view.goal_button.text.is_empty()
		and view.goal_button.get_parent() == view.item_buttons["toy-spring"]
		and view.goal_button.tooltip_text.begins_with("Start adventure"), "A locked card contains its own adventure action")
	view.goal_button.pressed.emit()
	check(goals == ["toy-spring"] and state.toy_id == "toy-ball", "The gift request identifies the preview without equipping it")
	check(view.toy_button.disabled and view.toy_button.focus_mode == Control.FOCUS_NONE, "The locked toy stays unplayable and cannot steal return focus")
	check(previews.size() == 1 and previews[0] == view.item_buttons["toy-spring"].tooltip_text,
		"Opening a locked toy announces the requirement shown on its card")
	view.toy_button.pressed.emit()
	check(words.size() == 1 and actions.size() == 1, "Locked object activation cannot pronounce or play the earned action")
	feedback_before = view.feedback_text
	view.interaction_allowed = func() -> bool: return false
	view.goal_button.pressed.emit()
	view.item_buttons["toy-ball"].pressed.emit()
	check(goals == ["toy-spring"], "The parent guard blocks a covered or swiped gift request")
	check(view.feedback_text == feedback_before and previews.size() == 1 and selections.is_empty(), "A covered preview rejects synthetic owned-card input")
	view.interaction_allowed = Callable()
	view.hide()
	view.goal_button.pressed.emit()
	view.item_buttons["toy-ball"].pressed.emit()
	check(goals == ["toy-spring"], "A hidden room cannot start a gift adventure")
	check(view.feedback_text == feedback_before and selections.is_empty(), "A hidden preview rejects synthetic owned-card input")
	view.show()
	view.item_buttons["toy-ball"].pressed.emit()
	check(selections == ["toy-ball"], "An owned card exits the preview through the host's selection path")
	view.configure(state, counts, data.theme("ocean"), true)
	check(view.toy_button.tooltip_text.ends_with("Tap: Roll the ball")
		and not view.toy_button.disabled and view.toy_button.focus_mode == Control.FOCUS_ALL,
		"Host confirmation restores the owned toy and its keyboard action")
	check(words.size() == 1 and actions.size() == 1 and state.toy_id == "toy-ball", "Returning to an owned card never equips or plays the locked toy")
	selections.clear()
	feedback_before = view.feedback_text
	var previews_before: int = previews.size()
	view._choose_item("backdrop-spring")
	check(not view.has_method("_show_category")
		and not view.get_property_list().any(func(property: Dictionary) -> bool: return property.name in ["category_buttons", "_category"]),
		"The Rooms category and its switching API are removed, not merely hidden")
	check(view.feedback_text == feedback_before and previews.size() == previews_before and selections.is_empty(),
		"A legacy backdrop ID cannot open a hidden preview or equipment route")
	check(view.controls().has(view.item_buttons["toy-spring"])
		and view.item_buttons.values().filter(func(button: Button) -> bool: return button.visible).size() == 8
		and not view.item_buttons[state.toy_id].visible,
		"All nine toy choices retain their host wiring while the active toy appears only once")
	check(view.controls().has(view.toy_button) and not view.toy_button.disabled, "Toy play remains available for host focus wiring")
	state.backdrop_id = "backdrop-spring"
	view.configure(state, {"spring-3": 3}, data.theme("ocean"), true)
	check(view._room.theme_id == "ocean" and state.backdrop_id == "backdrop-spring",
		"The current world renders while a legacy backdrop remains unchanged in saved state")
	state.goal_item_id = "backdrop-ocean"
	view.configure(state, {"spring-3": 3}, data.theme("ocean"), true)
	check(state.selected_goal({}).id == "backdrop-ocean" and not view.goal_button.visible
		and not view.goal_label.text.contains(state.item("backdrop-ocean").name),
		"An old backdrop goal remains saved data but is not advertised or resumed in Pip")
	var requests_before: int = goals.size()
	view.goal_button.pressed.emit()
	check(goals.size() == requests_before and state.goal_item_id == "backdrop-ocean",
		"A hidden old-goal control cannot start a backdrop adventure or erase its saved value")
	state.goal_item_id = "toy-spring"
	view.configure(state, {"spring-1": 1, "spring-3": 3}, data.theme("ocean"), true)
	check(view.goal_button.visible and view.goal_button.tooltip_text.begins_with("Continue adventure"), "A saved locked goal can resume its adventure")
	check(view.goal_label.text.contains("Spring flower") and view.goal_label.text.contains("2") and view.goal_label.text.contains("Spring"), "The selected goal retains its gift, world and exact remaining pieces across worlds")
	view.goal_button.pressed.emit()
	check(goals.back() == "toy-spring", "Continue requests the saved goal instead of the currently viewed world")
	var unlocking_card: Button = view.item_buttons["toy-spring"]
	unlocking_card.pressed.emit()
	check(view._preview_locked, "The pending gift is previewed before its final piece arrives")
	var unlocked_counts := {"spring-1": 3, "spring-3": 3}
	view.configure(state, unlocked_counts, data.theme("ocean"), true)
	await process_frame
	await process_frame
	check(view.item_buttons["toy-spring"] == unlocking_card and unlocking_card.get_parent() == view.owned_toys
		and view.item_buttons.values() == original_controls,
		"Unlocking moves the existing toy onto the playable floor without replacing host-wired controls")
	check(view._preview_id.is_empty() and not view._preview_locked and view._toy.id == state.toy_id
		and selections.is_empty(), "Unlocking clears the preview without silently changing the selected toy")
	_check_toy_partition(view, state, unlocked_counts, "newly unlocked room")
	for theme_id in data.THEMES:
		for medal in data.medals(theme_id):
			counts[medal.id] = 3
	var original_counts := counts.duplicate()
	view.configure(state, counts, data.theme("ocean"), true)
	await process_frame
	await process_frame
	_check_toy_partition(view, state, counts, "fully earned room")
	check(view.owned_toys.get_child_count() == 9 and not view._item_grid.visible
		and is_equal_approx(view.get_combined_minimum_size().y, view._room.get_combined_minimum_size().y),
		"All nine toys fit inside the home without an empty catalog row below it")
	var expected := {"spring": ["flower", "water"], "summer": ["ball", "roll"], "autumn": ["apple", "offer"], "winter": ["bell", "ring"], "ocean": ["shell", "open"], "space": ["rocket", "launch"], "jungle": ["monkey", "swing"], "candy": ["cake", "decorate"]}
	var next_actions := {"spring": ["Grow the flower", "Bloom the flower"], "summer": ["Return the ball", "Catch the ball"], "autumn": ["Nibble the apple", "Finish the apple"], "winter": ["Answer the bell", "Chime the bell"], "ocean": ["Listen to the shell", "Hear the waves"], "space": ["Ignite the rocket", "Launch the rocket"], "jungle": ["Wave to the monkey", "High-five the monkey"], "candy": ["Frost the cake", "Sprinkle the cake"]}
	for theme_id in expected:
		state.toy_id = "toy-" + theme_id
		state.backdrop_id = "backdrop-" + theme_id
		view.configure(state, counts, data.theme(theme_id), true)
		await process_frame
		if theme_id == "summer":
			var summer_icon: TextureRect = view.item_buttons["toy-summer"].get_child(0)
			check(view.toy_button.self_modulate != starter_tint and summer_icon.self_modulate == view.toy_button.self_modulate, "The earned Summer ball has a distinct sunny appearance in the room and catalog")
		else:
			check(view.toy_button.self_modulate == starter_tint, "The Summer ball's appearance does not tint another toy")
		if theme_id == "autumn":
			check(view.feedback_text.begins_with("An apple"), "The apple introduction uses the correct article")
		if theme_id == "ocean":
			check(view.toy_button.tooltip_text.ends_with("Tap: Lift the shell"), "The spiral shell begins with a physical action matching its artwork")
		var initial_action: String = view.toy_button.tooltip_text
		view.toy_button.pressed.emit()
		check(words.back() == expected[theme_id][0] and actions.back() == expected[theme_id][1], "The " + theme_id + " toy has the right noun and distinct action")
		check(view.feedback_text.to_lower().contains(expected[theme_id][0]), "The " + theme_id + " result retains its word association")
		check(view.toy_button.tooltip_text.ends_with("Tap: " + next_actions[theme_id][0]), "The " + theme_id + " first action leads to its second step")
		check(is_equal_approx(view._toy_label.position.x + view._toy_label.size.x * 0.5, view.toy_button.position.x + view.toy_button.size.x * 0.5), "The " + theme_id + " noun stays aligned with the toy after its action")
		if theme_id == "ocean":
			check(not view.feedback_text.contains("pearl") and not view.feedback_text.contains("opens"), "The spiral shell does not teach a hinged clam's behavior")
		var position: Vector2 = view.toy_button.position
		var rotation: float = view.toy_button.rotation
		var room_size: Vector2 = view._room.size
		var pose_offset: Vector2 = position + view.toy_button.size * 0.5 - view.playground._toy_home
		await process_frame
		await process_frame
		check(view.toy_button.position + view.toy_button.size * 0.5 - view.playground._toy_home == pose_offset
			and view.toy_button.rotation == rotation and not view.is_processing(),
			"Reduced-motion %s play keeps its exact room-relative pose while layout settles: position=%s -> %s rotation=%s -> %s room=%s -> %s processing=%s" % [
				theme_id, position, view.toy_button.position, rotation, view.toy_button.rotation,
				room_size, view._room.size, view.is_processing()])
		_check_room_text(view, theme_id + " first stage")
		var first_feedback: String = view.feedback_text
		view.toy_button.pressed.emit()
		await process_frame
		await process_frame
		_check_room_text(view, theme_id + " second stage")
		check(view.toy_button.tooltip_text.ends_with("Tap: " + next_actions[theme_id][1]) and view.feedback_text != first_feedback, "The " + theme_id + " second action has its own result and next step")
		check(view.toy_button.position != position or view.toy_button.rotation != rotation, "The " + theme_id + " second static stage visibly changes its pose")
		var second_feedback: String = view.feedback_text
		position = view.toy_button.position
		rotation = view.toy_button.rotation
		view.toy_button.pressed.emit()
		await process_frame
		await process_frame
		_check_room_text(view, theme_id + " final stage")
		check(view.toy_button.tooltip_text.ends_with("Tap: Play with the " + expected[theme_id][0] + " again") and view.feedback_text != second_feedback, "The " + theme_id + " third action completes the sequence and offers replay")
		check(view.toy_button.position != position or view.toy_button.rotation != rotation, "The " + theme_id + " final static stage has a distinct pose")
		check(words.back() == expected[theme_id][0] and actions.back() == expected[theme_id][1] and view.feedback_text.to_lower().contains(expected[theme_id][0]), "Every " + theme_id + " stage preserves the noun and existing host reaction")
		var before_replay: int = actions.size()
		view.toy_button.pressed.emit()
		check(view.toy_button.tooltip_text == initial_action and view.toy_button.icon != null and not view.is_processing(), "Replay restores the " + theme_id + " toy and first action")
		check(actions.size() == before_replay, "Replay resets without granting an extra toy reaction")
	check(counts == original_counts, "Room interactions never alter medal progress")
	check(not view.goal_button.visible and not view.goal_label.visible and state.goal_item_id == "toy-spring",
		"A completed goal remains saved while its owned card replaces the adventure action")
	requests_before = goals.size()
	view.goal_button.pressed.emit()
	check(goals.size() == requests_before and state.toy_id == "toy-candy", "A hidden completed-goal action cannot start another adventure or equip a toy")
	view.item_buttons["toy-autumn"].pressed.emit()
	check(selections == ["toy-autumn"], "An owned selector asks the parent to persist the choice")
	check(state.toy_id == "toy-candy", "The view does not report an uncommitted selection as saved")
	state.toy_id = "toy-spring"
	view.configure(state, {}, data.theme("spring"), true)
	check(view.toy_button.tooltip_text.ends_with("Tap: Roll the ball"), "A saved item without earned ownership renders the starter fallback")
	await process_frame
	await process_frame
	_check_toy_partition(view, state, {}, "unearned saved-toy fallback")
	view.configure(state, counts, data.theme("spring"), false)
	view.toy_button.pressed.emit()
	check(view.is_processing(), "Normal toy actions run a bounded animation")
	var first_stage_feedback: String = view.feedback_text
	view._process(1.0)
	check(not view.is_processing() and view.feedback_text == first_stage_feedback and view.toy_button.tooltip_text.ends_with("Tap: Grow the flower"), "Finishing an animation never advances the self-paced sequence")
	view.toy_button.pressed.emit()
	view.toy_button.pressed.emit()
	check(view.toy_button.tooltip_text.ends_with("Tap: Play with the flower again") and view.is_processing(), "Rapid input replaces the active animation and advances only the requested stages")
	view.settle()
	check(not view.is_processing() and view.toy_button.tooltip_text.ends_with("Tap: Play with the flower again"), "Background settling finishes the current animation without adding another stage")
	view.toy_button.pressed.emit()
	view.toy_button.pressed.emit()
	view.hide()
	check(not view.is_processing(), "Closing the room stops animation immediately")
	check(view.controls().size() == state.toys().size() + 2 and view.controls().has(view.goal_button)
		and view.controls().has(view.toy_button)
		and view.item_buttons.values().all(func(button: Button) -> bool: return view.controls().has(button)),
		"A hidden room exposes the toy, goal and all toy choices for host focus and scrolling wiring")
	view.show()
	view.configure(state, counts, data.theme("spring"), true)
	await process_frame
	await process_frame
	for control in view.controls():
		if not control.is_visible_in_tree():
			continue
		check(control.size.x >= 64 and control.size.y >= 64, "Room controls retain their generous 64 by 64 touch targets")
		check(control.get_global_rect().position.x >= view.global_position.x - 1 and control.get_global_rect().end.x <= view.global_position.x + view.size.x + 1, "Room controls fit a narrow phone column")
	view.queue_free()
	await process_frame
	await _check_current_theme_rendering()
	_finish()


func _check_current_theme_rendering() -> void:
	var data = load("res://scripts/game_data.gd")
	var state_script = load("res://scripts/playroom_state.gd")
	var view_script = load("res://scripts/playroom_view.gd")
	for fixture in [
		{"id": "backdrop-home", "pieces": 0, "name": "default home"},
		{"id": "backdrop-spring", "pieces": 0, "name": "unearned legacy Spring room"},
		{"id": "backdrop-spring", "pieces": 3, "name": "earned legacy Spring room"}
	]:
		var state = state_script.new()
		state.toy_id = "toy-autumn"
		state.backdrop_id = fixture.id
		state.favorite_id = "spring-1"
		state.goal_item_id = "backdrop-ocean"
		var legacy_words: Array[String] = ["cat", "bell"]
		state.collected_word_ids = legacy_words
		state.displayed_word_id = "bell"
		state.preferred_theme_id = "autumn"
		var counts := {"spring-1": 3, "summer-1": 3, "autumn-1": 3, "spring-3": fixture.pieces}
		var original_counts := counts.duplicate(true)
		var view = view_script.new()
		root.add_child(view)
		view.size = Vector2(280, 1400)
		for theme_id in data.THEMES:
			var palette: Dictionary = data.theme(theme_id)
			view.configure(state, counts, palette, true)
			await process_frame
			_check_current_room_palette(view, palette, fixture.name + " in " + theme_id)
			check(view._toy.id == "toy-autumn" and view._toy_label.text == "apple"
				and state.toy_id == "toy-autumn" and state.backdrop_id == fixture.id
				and counts == original_counts and view._counts == original_counts,
				"Changing to " + theme_id + " preserves the equipped apple, legacy backdrop and medal progress for " + fixture.name)
		view.configure(state, counts, data.theme("autumn"), true)
		view.item_buttons["toy-space"].pressed.emit()
		check(view._preview_locked and view._toy.id == "toy-space" and view.toy_button.disabled,
			"The " + fixture.name + " fixture still supports a locked toy preview")
		_check_current_room_palette(view, data.theme("autumn"), fixture.name + " previewing a Space toy in Autumn")
		view.configure(state, counts, data.theme("ocean"), true)
		_check_current_room_palette(view, data.theme("ocean"), fixture.name + " switching worlds during a locked preview")
		check(view._preview_locked and view._toy.id == "toy-space" and state.toy_id == "toy-autumn"
			and state.backdrop_id == fixture.id and counts == original_counts and view._counts == original_counts
			and state.favorite_id == "spring-1" and state.goal_item_id == "backdrop-ocean"
			and state.collected_word_ids == ["cat", "bell"] and state.displayed_word_id == "bell"
			and state.preferred_theme_id == "autumn",
			"Rendering and previewing every world preserves all existing choices and legacy rewards for " + fixture.name)
		view.queue_free()
		await process_frame


func _check_current_room_palette(view, palette: Dictionary, context: String) -> void:
	check(view._room.theme_id == palette.id and view._room.palette == palette,
		"The " + context + " uses the current world's decorations, wall and floor colors")
	check(view._room_title.text == palette.name + " room" and view.playground.accent == palette.accent,
		"The " + context + " uses the current world's room title and interaction color")


func _finish() -> void:
	print("Playroom view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_room_text(view, context: String) -> void:
	var room_bounds: Rect2 = view._room.get_global_rect()
	check(absf(view._item_grid.global_position.y - room_bounds.end.y - view.get_theme_constant("separation")) <= 1
		if view._item_grid.visible else is_equal_approx(view.get_combined_minimum_size().y, view._room.get_combined_minimum_size().y),
		"The " + context + " locked catalog follows the home only while unearned toys remain")
	check(not view._toy_label.text.is_empty() and view.feedback_text.to_lower().contains(view._toy_label.text.to_lower()),
		"The " + context + " visible toy noun retains its feedback association")
	check(view.playground.get_global_rect().grow(1).encloses(view._toy_label.get_global_rect()), "The " + context + " toy noun stays inside the active stage")


func _check_toy_partition(view, state, counts: Dictionary, context: String) -> void:
	var owned: Array = view.owned_toys.get_children()
	var locked: Array = view._item_grid.get_children()
	check(owned.size() + locked.size() == state.toys().size()
		and owned.all(func(card: Node) -> bool: return not locked.has(card)),
		"The " + context + " shows each toy in exactly one ownership group")
	for item in state.toys():
		var card: Button = view.item_buttons[item.id]
		var earned: bool = state.owned(item, counts)
		var active: bool = earned and not view._preview_locked and item.id == view._toy.id
		var visible_control: Control = view.toy_button if active else card
		check((owned.has(card) if earned else locked.has(card)) and card.in_room == earned
			and visible_control.is_visible_in_tree() and visible_control.focus_mode == Control.FOCUS_ALL
			and (not card.visible and card.focus_mode == Control.FOCUS_NONE if active else true),
			"The " + context + " renders " + item.id + " exactly once through a usable toy or locked card")
		if earned:
			check(view.playground.get_global_rect().grow(1).encloses(visible_control.get_global_rect()),
				"The " + context + " puts the playable " + item.id + " directly inside Pip's floor")
	var stage_bounds: Rect2 = view.playground.get_global_rect()
	check(view.owned_toys.get_parent() == view._room and stage_bounds == view._room.get_global_rect()
		and not view._room.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "shelves"),
		"The " + context + " makes the entire home playable without a separate shelf")
	check(owned.all(func(card: Control) -> bool: return stage_bounds.grow(1).encloses(card.get_global_rect())),
		"The " + context + " includes the last earned toy inside the room's scrollable floor")


func _capture() -> void:
	var view = load("res://scripts/playroom_view.gd").new()
	var state = load("res://scripts/playroom_state.gd").new()
	var data = load("res://scripts/game_data.gd")
	var counts: Dictionary = {}
	for theme_id in data.THEMES:
		for medal in data.medals(theme_id):
			counts[medal.id] = 3
	root.size = Vector2i(420, 940)
	var scroll := ScrollContainer.new()
	root.add_child(scroll)
	scroll.position = Vector2(16, 16)
	scroll.size = Vector2(388, 908)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(view)
	state.toy_id = "toy-spring"
	state.backdrop_id = "backdrop-spring"
	view.configure(state, counts, data.theme("spring"), true)
	var pip = load("res://scripts/duck_mascot.gd").new()
	view.duck_slot.add_child(pip)
	pip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pip.set_reduced_motion(true)
	DirAccess.make_dir_recursive_absolute("res://build/visuals")
	for theme_id in data.THEMES:
		state.toy_id = "toy-" + theme_id
		state.backdrop_id = "backdrop-" + theme_id
		view.configure(state, counts, data.theme(theme_id), true)
		var strip := Image.create(1260, 590, false, Image.FORMAT_RGBA8)
		for stage in range(3):
			view.toy_button.pressed.emit()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			screenshot.save_png("res://build/visuals/playroom-" + theme_id + "-stage-%d.png" % (stage + 1))
			strip.blit_rect(screenshot, Rect2i(0, 0, 420, 590), Vector2i(stage * 420, 0))
		strip.save_png("res://build/visuals/playroom-steps-" + theme_id + ".png")
		# The animated mode must settle to the same visible third stage.
		view.toy_button.pressed.emit()
		view.configure(state, counts, data.theme(theme_id), false)
		for stage in range(3):
			view.toy_button.pressed.emit()
			view._process(1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/playroom-motion-" + theme_id + ".png")
	state.goal_item_id = "toy-spring"
	view.configure(state, counts, data.theme("space"), true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-goal-ready.png")
	state.goal_item_id = "toy-ocean"
	counts["ocean-1"] = 1
	view.configure(state, counts, data.theme("space"), true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-goal-resume.png")
	view.item_buttons["toy-ocean"].pressed.emit()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-locked.png")
	root.size = Vector2i(320, 800)
	scroll.size = Vector2(288, 768)
	state.toy_id = "toy-autumn"
	state.backdrop_id = "backdrop-autumn"
	state.goal_item_id = ""
	view.configure(state, counts, data.theme("autumn"), true)
	for stage in range(3):
		view.toy_button.pressed.emit()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/playroom-narrow-apple-stage-%d.png" % (stage + 1))
		_check_room_text(view, "captured narrow apple stage %d" % (stage + 1))
	print("Captured all eight toy sequences and three gift-goal states.")
	_finish()
