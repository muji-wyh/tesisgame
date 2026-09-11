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
	check(view.duck_slot is Control and view.caption is Label, "The room exposes the shared Pip slot and caption")
	check(view.favorite_medal is Control, "The room exposes the existing favourite display")
	check(view.toy_button.icon != null and not view.action_button.disabled, "The starter ball is visible and immediately playable")
	var starter_tint: Color = view.toy_button.self_modulate
	check(view.action_button.text.to_lower().contains("ball"), "The action names its familiar noun")
	check(view.item_buttons.size() == state.catalog().size(), "Every room item has a visible catalog control")
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
	check(view.has_signal("item_previewed"), "The room announces locked previews and return to the host")
	if view.has_signal("item_previewed"):
		view.item_previewed.connect(func(message: String) -> void: previews.append(message))
	view.interaction_allowed = func() -> bool: return false
	var caption_before: String = view.caption.text
	view.action_button.pressed.emit()
	view.toy_button.pressed.emit()
	view.category_buttons["backdrop"].pressed.emit()
	view.item_buttons["toy-spring"].pressed.emit()
	check(words.is_empty() and actions.is_empty() and selections.is_empty(), "The parent guard rejects swipe releases and covered-room input before emitting signals")
	check(view.caption.text == caption_before and view.item_buttons["toy-spring"].visible, "Blocked room input cannot change its caption, preview, or category")
	view.interaction_allowed = Callable()
	view.action_button.pressed.emit()
	check(words == ["ball"] and actions == ["roll"], "Playing the starter requests the noun and the roll reaction once")
	check(view.caption.text.to_lower().contains("ball"), "The toy leaves a visible named outcome")
	view.item_buttons["toy-spring"].pressed.emit()
	check(selections.is_empty(), "A locked preview cannot equip an item")
	check(view.caption.text.contains("Blossom") and view.caption.text.contains("0/3"), "A locked toy names its exact medal requirement and current count")
	check(not view.action_button.disabled and view.action_button.text == "Back to my room", "A locked preview offers an actionable return to the selected room")
	check(view.goal_button.visible and view.goal_button.text == "Help Pip get this", "A locked preview offers a concrete gift adventure alongside Back")
	view.goal_button.pressed.emit()
	check(goals == ["toy-spring"] and state.toy_id == "toy-ball", "The gift request identifies the preview without equipping it")
	check(view.toy_button.disabled and view.toy_button.focus_mode == Control.FOCUS_NONE, "The locked toy stays unplayable and cannot steal return focus")
	check(previews.size() == 1 and previews[0] == view.caption.text, "Opening a locked toy announces its visible requirement")
	view.toy_button.pressed.emit()
	check(words.size() == 1 and actions.size() == 1, "Locked object activation cannot pronounce or play the earned action")
	caption_before = view.caption.text
	view.interaction_allowed = func() -> bool: return false
	view.goal_button.pressed.emit()
	view.action_button.pressed.emit()
	check(goals == ["toy-spring"], "The parent guard blocks a covered or swiped gift request")
	check(view.caption.text == caption_before and previews.size() == 1, "A covered preview rejects synthetic return input")
	view.interaction_allowed = Callable()
	view.hide()
	view.goal_button.pressed.emit()
	view.action_button.pressed.emit()
	check(goals == ["toy-spring"], "A hidden room cannot start a gift adventure")
	check(view.caption.text == caption_before, "A hidden preview rejects synthetic return input")
	view.show()
	view.action_button.pressed.emit()
	check(view.action_button.text == "Roll the ball" and not view.toy_button.disabled and view.toy_button.focus_mode == Control.FOCUS_ALL, "Back to my room restores the selected toy and its normal controls")
	check(previews.size() == 2 and previews.back() == view.caption.text, "Closing the preview announces the restored room")
	check(words.size() == 1 and actions.size() == 1 and selections.is_empty() and state.toy_id == "toy-ball", "Preview return never equips, plays or persists the locked toy")
	view.category_buttons["backdrop"].pressed.emit()
	view.item_buttons["backdrop-spring"].pressed.emit()
	check(view.caption.text.contains("Bee") and view.caption.text.contains("9"), "A later locked backdrop includes earlier incomplete medals in its requirement")
	check(view.controls().has(view.item_buttons["backdrop-spring"]), "Locked previews remain reachable with keyboard and controller")
	check(view.controls().has(view.item_buttons["toy-spring"]) and not view.item_buttons["toy-spring"].visible, "Hidden category controls remain available for one-time host wiring")
	check(view.controls().has(view.action_button) and not view.action_button.disabled, "The preview return remains available for host focus wiring")
	view.action_button.pressed.emit()
	check(view._room_title.text == "Pip's home" and view.action_button.text == "Roll the ball", "Returning from a locked backdrop restores the chosen room and toy")
	state.goal_item_id = "toy-spring"
	view.configure(state, {"spring-1": 1}, data.theme("ocean"), true)
	check(view.goal_button.visible and view.goal_button.text == "Continue adventure", "A saved locked goal can resume its adventure")
	check(view.goal_label.text.contains("Spring flower") and view.goal_label.text.contains("2") and view.goal_label.text.contains("Spring"), "The selected goal retains its gift, world and exact remaining pieces across worlds")
	view.goal_button.pressed.emit()
	check(goals.back() == "toy-spring", "Continue requests the saved goal instead of the currently viewed world")
	for theme_id in data.THEMES:
		for medal in data.medals(theme_id):
			counts[medal.id] = 3
	var original_counts := counts.duplicate()
	var expected := {"spring": ["flower", "water"], "summer": ["ball", "roll"], "autumn": ["apple", "offer"], "winter": ["bell", "ring"], "ocean": ["shell", "open"], "space": ["rocket", "launch"]}
	var next_actions := {"spring": ["Grow the flower", "Bloom the flower"], "summer": ["Return the ball", "Catch the ball"], "autumn": ["Nibble the apple", "Finish the apple"], "winter": ["Answer the bell", "Chime the bell"], "ocean": ["Listen to the shell", "Hear the waves"], "space": ["Ignite the rocket", "Launch the rocket"]}
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
			check(view.caption.text.begins_with("An apple"), "The apple introduction uses the correct article")
		if theme_id == "ocean":
			check(view.action_button.text == "Lift the shell", "The spiral shell begins with a physical action matching its artwork")
		var initial_action: String = view.action_button.text
		view.action_button.pressed.emit()
		check(words.back() == expected[theme_id][0] and actions.back() == expected[theme_id][1], "The " + theme_id + " toy has the right noun and distinct action")
		check(view.caption.text.to_lower().contains(expected[theme_id][0]), "The " + theme_id + " result retains its word association")
		check(view.action_button.text == next_actions[theme_id][0], "The " + theme_id + " first action leads to its second step")
		check(is_equal_approx(view._toy_label.position.x + view._toy_label.size.x * 0.5, view.toy_button.position.x + view.toy_button.size.x * 0.5), "The " + theme_id + " noun stays aligned with the toy after its action")
		if theme_id == "ocean":
			check(not view.caption.text.contains("pearl") and not view.caption.text.contains("opens"), "The spiral shell does not teach a hinged clam's behavior")
		var position: Vector2 = view.toy_button.position
		var rotation: float = view.toy_button.rotation
		await process_frame
		await process_frame
		check(view.toy_button.position == position and view.toy_button.rotation == rotation and not view.is_processing(), "Reduced-motion " + theme_id + " play leaves a stable visible outcome")
		_check_room_text(view, theme_id + " first stage")
		var first_caption: String = view.caption.text
		view.action_button.pressed.emit()
		await process_frame
		await process_frame
		_check_room_text(view, theme_id + " second stage")
		check(view.action_button.text == next_actions[theme_id][1] and view.caption.text != first_caption, "The " + theme_id + " second action has its own result and next step")
		check(view.toy_button.position != position or view.toy_button.rotation != rotation, "The " + theme_id + " second static stage visibly changes its pose")
		var second_caption: String = view.caption.text
		position = view.toy_button.position
		rotation = view.toy_button.rotation
		view.toy_button.pressed.emit()
		await process_frame
		await process_frame
		_check_room_text(view, theme_id + " final stage")
		check(view.action_button.text == "Play again" and view.caption.text != second_caption, "The " + theme_id + " third action completes the sequence and offers replay")
		check(view.toy_button.position != position or view.toy_button.rotation != rotation, "The " + theme_id + " final static stage has a distinct pose")
		check(words.back() == expected[theme_id][0] and actions.back() == expected[theme_id][1] and view.caption.text.to_lower().contains(expected[theme_id][0]), "Every " + theme_id + " stage preserves the noun and existing host reaction")
		var before_replay: int = actions.size()
		view.action_button.pressed.emit()
		check(view.action_button.text == initial_action and view.toy_button.icon != null and not view.is_processing(), "Replay restores the " + theme_id + " toy and first action")
		check(actions.size() == before_replay, "Replay resets without granting an extra toy reaction")
	check(counts == original_counts, "Room interactions never alter medal progress")
	check(view.goal_button.text == "Play with this gift" and view.goal_label.text.contains("Spring flower"), "A completed saved goal stays available for later use")
	view.goal_button.pressed.emit()
	check(goals.back() == "toy-spring" and state.toy_id == "toy-space", "A completed goal requests the host's persisted equipment path")
	view.category_buttons["toy"].pressed.emit()
	view.item_buttons["toy-autumn"].pressed.emit()
	check(selections == ["toy-autumn"], "An owned selector asks the parent to persist the choice")
	check(state.toy_id == "toy-space", "The view does not report an uncommitted selection as saved")
	state.toy_id = "toy-spring"
	view.configure(state, {}, data.theme("spring"), true)
	check(view.action_button.text.to_lower().contains("ball"), "A saved item without earned ownership renders the starter fallback")
	view.configure(state, counts, data.theme("spring"), false)
	view.action_button.pressed.emit()
	check(view.is_processing(), "Normal toy actions run a bounded animation")
	var first_stage_caption: String = view.caption.text
	view._process(1.0)
	check(not view.is_processing() and view.caption.text == first_stage_caption and view.action_button.text == "Grow the flower", "Finishing an animation never advances the self-paced sequence")
	view.action_button.pressed.emit()
	view.toy_button.pressed.emit()
	check(view.action_button.text == "Play again" and view.is_processing(), "Rapid input replaces the active animation and advances only the requested stages")
	view.settle()
	check(not view.is_processing() and view.action_button.text == "Play again", "Background settling finishes the current animation without adding another stage")
	view.action_button.pressed.emit()
	view.action_button.pressed.emit()
	view.hide()
	check(not view.is_processing(), "Closing the room stops animation immediately")
	check(view.controls().size() == state.catalog().size() + 6 and view.controls().has(view.word_sticker_button), "A hidden room exposes every button, including its word sticker and goal, for host focus and scrolling wiring")
	view.show()
	view.configure(state, counts, data.theme("spring"), true)
	await process_frame
	await process_frame
	for control in view.controls():
		if not control.is_visible_in_tree():
			continue
		check(control.size.x >= 64 and control.size.y >= 64, "Room controls retain generous touch targets")
		check(control.get_global_rect().position.x >= view.global_position.x - 1 and control.get_global_rect().end.x <= view.global_position.x + view.size.x + 1, "Room controls fit a narrow phone column")
	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Playroom view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_room_text(view, context: String) -> void:
	var bounds: Rect2 = view.caption.get_global_rect()
	check(bounds.position.x >= view.global_position.x and bounds.end.x <= view.global_position.x + view.size.x + 1, "The " + context + " caption stays inside the narrow room")
	check(view.caption.get_minimum_size().x <= view.caption.size.x and view.caption.get_visible_line_count() == view.caption.get_line_count(), "The " + context + " caption fits without cutting off text")
	check(view.caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "The " + context + " caption keeps a stable left text edge")


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
			view.action_button.pressed.emit()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			screenshot.save_png("res://build/visuals/playroom-" + theme_id + "-stage-%d.png" % (stage + 1))
			strip.blit_rect(screenshot, Rect2i(0, 0, 420, 590), Vector2i(stage * 420, 0))
		strip.save_png("res://build/visuals/playroom-steps-" + theme_id + ".png")
		# The animated mode must settle to the same readable third stage.
		view.action_button.pressed.emit()
		view.configure(state, counts, data.theme(theme_id), false)
		for stage in range(3):
			view.action_button.pressed.emit()
			view._process(1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/playroom-motion-" + theme_id + ".png")
	state.goal_item_id = "toy-spring"
	view.configure(state, counts, data.theme("space"), true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-goal-ready.png")
	state.goal_item_id = "backdrop-ocean"
	counts.erase("ocean-2")
	counts.erase("ocean-3")
	view.configure(state, counts, data.theme("space"), true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-goal-resume.png")
	view.category_buttons["backdrop"].pressed.emit()
	view.item_buttons["backdrop-ocean"].pressed.emit()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-locked.png")
	root.size = Vector2i(320, 800)
	scroll.size = Vector2(288, 768)
	view.action_button.pressed.emit()
	state.toy_id = "toy-autumn"
	state.backdrop_id = "backdrop-autumn"
	state.goal_item_id = ""
	view.configure(state, counts, data.theme("autumn"), true)
	for stage in range(3):
		view.action_button.pressed.emit()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/playroom-narrow-apple-stage-%d.png" % (stage + 1))
		_check_room_text(view, "captured narrow apple stage %d" % (stage + 1))
	print("Captured all six toy sequences and three gift-goal states.")
	_finish()
