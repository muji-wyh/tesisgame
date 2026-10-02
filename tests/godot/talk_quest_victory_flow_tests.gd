extends SceneTree
## Real word wins, uninterrupted rewards, and compact victory presentation.

const Quest = preload("res://scripts/talk_quest.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const OUTPUT := "res://build/talk-quest-victory-review"
var checks: int = 0
var failures: int = 0
var sounds: Array[String] = []
var capture_enabled: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _win(quest) -> void:
	quest.start_level(1)
	quest.set_process(false)
	for turn in range(180):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if not prompt.is_empty():
			quest._submit_text(str(prompt.text))
		quest._process(0.65)
	check(quest.game.phase == "victory" and quest.game.hp == 0,
		"Recognizing the final live word wins the encounter")
	check(quest._celebration.is_visible_in_tree() and quest._celebration.active,
		"Victory reveals Pip's celebration after the final projectile lands")
	check(quest._hold >= 3.2 and not quest._chest_button.is_visible_in_tree(),
		"The full dance remains visible before chest interaction begins")


func _capture(quest, label: String) -> void:
	if not capture_enabled:
		return
	quest._celebration.set_process(false)
	quest._treasure_backdrop.set_process(false)
	quest._chest.set_process(false)
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "The real renderer produced " + label)
	if image != null and not image.is_empty():
		var crop: Image = image.get_region(Rect2i(Vector2i.ZERO, Vector2i(quest.size)))
		check(crop.save_png(OUTPUT.path_join(label + ".png")) == OK, "Saved visual review " + label)


func _check_reward_layout(quest, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, quest.size)
	for control: Control in [quest._banner, quest._reward_eyebrow, quest._reward_detail,
		quest._chest, quest._chest_caption, quest._celebration, quest._back, quest._next]:
		if control.is_visible_in_tree():
			check(bounds.grow(1).encloses(control.get_rect()), label + " contains " + control.name)
	check(not quest._banner.get_rect().intersects(quest._chest.get_rect()), label + " separates treasure title and chest")
	check(not quest._chest_caption.get_rect().intersects(quest._banner.get_rect()), label + " separates title and hold instruction")
	check(quest._celebration.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label + " keeps decorative Pip transparent to chest gestures")
	check(quest._stage_scroll.get_v_scroll_bar().max_value <= quest._stage_scroll.size.y,
		label + " needs no vertical scrolling")
	if quest._next.visible:
		check(quest._next.size.y >= 44 and quest._next.size.x >= 44, label + " keeps Next touch sized")
	check(not quest._meter.visible and not quest._transcript.visible,
		label + " hides combat-only status during the reward")


func _run() -> void:
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	if capture_enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1050, 600)
	var quest = Quest.new()
	quest.save_path = "user://quest-victory-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	quest.size = Vector2(root.size)
	quest.sound_requested.connect(func(kind: String) -> void: sounds.append(kind))
	quest.set_process(false)
	quest.set_reduced_motion(false)
	_win(quest)
	check(sounds.count("pip_victory") == 1, "One win requests one cheerful Pip sequence")
	for index in range(5):
		quest._refresh()
	check(sounds.count("pip_victory") == 1, "Refreshing status never restarts the celebration calls")
	quest._celebration._process(0.7)
	await _capture(quest, "desktop-victory")
	quest._process(0.8)
	quest.pause()
	check(not quest._celebration.is_visible_in_tree(), "Pausing hides the celebration beneath the pause card")
	quest._process(20.0)
	check(quest.game.phase == "paused" and quest.game.total_clears == 0,
		"Pause cannot finish a victory or award a chest")
	quest._continue_run()
	check(sounds.count("pip_victory") == 1 and quest._celebration.settled,
		"Continue keeps Pip happy without replaying victory audio or the dance")
	quest._process(10.0)
	check(quest.game.phase == "chest" and sounds.back() == "pip_stop",
		"Entering the treasure room cancels remaining Pip calls")
	check(quest._celebration.is_visible_in_tree() and not quest._celebration.active,
		"Pip stays beside the unopened reward as a quiet companion")
	quest.start_chest_hold()
	quest._advance_chest_hold(0.4)
	quest.end_chest_hold()
	check(quest.game.total_clears == 0 and not quest._opening,
		"The upgraded presentation still cancels an unfinished hold without awarding")
	for layout: Dictionary in [
		{"name": "desktop", "size": Vector2i(1050, 600)},
		{"name": "phone", "size": Vector2i(366, 610)},
		{"name": "small-phone", "size": Vector2i(296, 414)},
		{"name": "landscape", "size": Vector2i(544, 140)}
	]:
		root.size = layout.size
		quest.size = Vector2(layout.size)
		quest._layout()
		_check_reward_layout(quest, str(layout.name))
		await _capture(quest, str(layout.name) + "-chest")
	quest.start_chest_hold()
	quest._advance_chest_hold(Feel.HOLD_SECONDS)
	quest._chest._advance_animation(Feel.RELEASE_TIME + 0.01)
	quest.end_chest_hold()
	quest._chest._advance_animation(Feel.OPEN_SECONDS)
	check(quest.game.phase == "complete" and quest.game.total_clears == 1 and quest._next.visible,
		"A committed opening collects exactly one reward and enables Next")
	quest._reward_finished()
	check(quest.game.total_clears == 1, "Duplicate completion cannot grant another treasure")
	_check_reward_layout(quest, "landscape collected")
	await _capture(quest, "landscape-collected")
	root.size = Vector2i(366, 610)
	quest.size = Vector2(root.size)
	quest._layout()
	await _capture(quest, "phone-collected")
	quest.set_reduced_motion(true)
	_win(quest)
	check(quest._celebration.reduced_motion, "Reduced motion retains the happy Pip presentation")
	await _capture(quest, "phone-reduced-victory")
	quest._process(10.0)
	quest.start_chest_hold()
	quest._advance_chest_hold(Feel.HOLD_SECONDS)
	check(quest.game.phase == "complete" and quest.game.total_clears == 2,
		"Reduced motion reaches the reward without requiring an animation callback")
	var path: String = quest.save_path
	quest.free()
	DirAccess.remove_absolute(path)
	print("Talk Quest victory flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
