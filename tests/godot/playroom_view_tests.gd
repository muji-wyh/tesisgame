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
	check(view.toy_button.disabled and view.toy_button.focus_mode == Control.FOCUS_NONE, "The locked toy stays unplayable and cannot steal return focus")
	check(previews.size() == 1 and previews[0] == view.caption.text, "Opening a locked toy announces its visible requirement")
	view.toy_button.pressed.emit()
	check(words.size() == 1 and actions.size() == 1, "Locked object activation cannot pronounce or play the earned action")
	caption_before = view.caption.text
	view.interaction_allowed = func() -> bool: return false
	view.action_button.pressed.emit()
	check(view.caption.text == caption_before and previews.size() == 1, "A covered preview rejects synthetic return input")
	view.interaction_allowed = Callable()
	view.hide()
	view.action_button.pressed.emit()
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
	for theme_id in data.THEMES:
		for medal in data.medals(theme_id):
			counts[medal.id] = 3
	var original_counts := counts.duplicate()
	var expected := {"spring": ["flower", "water"], "summer": ["ball", "roll"], "autumn": ["apple", "offer"], "winter": ["bell", "ring"], "ocean": ["shell", "open"], "space": ["rocket", "launch"]}
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
			check(view.action_button.text == "Listen to the shell", "The spiral shell has an action matching its artwork")
		view.action_button.pressed.emit()
		check(words.back() == expected[theme_id][0] and actions.back() == expected[theme_id][1], "The " + theme_id + " toy has the right noun and distinct action")
		check(view.caption.text.to_lower().contains(expected[theme_id][0]), "The " + theme_id + " result retains its word association")
		check(is_equal_approx(view._toy_label.position.x + view._toy_label.size.x * 0.5, view.toy_button.position.x + view.toy_button.size.x * 0.5), "The " + theme_id + " noun stays aligned with the toy after its action")
		if theme_id == "ocean":
			check(not view.caption.text.contains("pearl") and not view.caption.text.contains("opens"), "The spiral shell does not teach a hinged clam's behavior")
		var position: Vector2 = view.toy_button.position
		var rotation: float = view.toy_button.rotation
		await process_frame
		await process_frame
		check(view.toy_button.position == position and view.toy_button.rotation == rotation and not view.is_processing(), "Reduced-motion " + theme_id + " play leaves a stable visible outcome")
	check(counts == original_counts, "Room interactions never alter medal progress")
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
	view.hide()
	check(not view.is_processing(), "Closing the room stops animation immediately")
	check(view.controls().size() == state.catalog().size() + 5 and view.controls().has(view.word_sticker_button), "A hidden room exposes every button, including its word sticker, for host focus and scrolling wiring")
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


func _capture() -> void:
	var view = load("res://scripts/playroom_view.gd").new()
	var state = load("res://scripts/playroom_state.gd").new()
	var data = load("res://scripts/game_data.gd")
	var counts: Dictionary = {"spring-1": 3, "spring-2": 3, "spring-3": 3, "space-1": 3, "space-2": 3, "space-3": 3}
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
	for entry in [["spring", "playroom-flower"], ["space", "playroom-rocket"]]:
		state.toy_id = "toy-" + entry[0]
		state.backdrop_id = "backdrop-" + entry[0]
		view.configure(state, counts, data.theme(entry[0]), true)
		view.action_button.pressed.emit()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/" + entry[1] + ".png")
	view.category_buttons["backdrop"].pressed.emit()
	view.item_buttons["backdrop-ocean"].pressed.emit()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visuals/playroom-locked.png")
	print("Captured three playroom views.")
	quit()
