extends SceneTree
## Capture earned rewards inside the real app with its production canvas stretch.

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Quest = preload("res://scripts/talk_quest.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const Style = preload("res://scripts/ui_style.gd")
const OUTPUT := "res://build/talk-quest-victory-app-review"

var checks: int = 0
var failures: int = 0
var _directory: String
var _capture_enabled: bool = false
var _layouts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _isolate_quest(node: Node) -> void:
	if node.get_script() == Quest:
		node.save_path = _directory + "/quest.cfg"


func _freeze(quest) -> void:
	quest.set_process(false)
	quest._effects.set_process(false)
	quest._celebration.set_process(false)
	quest._treasure_backdrop.set_process(false)
	quest._chest.set_process(false)


func _resize(app, physical_size: Vector2i) -> void:
	root.size = physical_size
	# App containers must finish their deferred sizing before stage geometry is read.
	for frame in range(4):
		await process_frame
	app._layout()
	for frame in range(4):
		await process_frame
	app._quest._layout()
	await process_frame
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and root.content_scale_size == Vector2i(480, 480),
		"The app retains its production 480-pixel canvas stretch")
	check(app._quest.is_visible_in_tree() and app._quest.size.x > 0 and app._quest.size.y > 0,
		"The real app allocates visible space to Talk Quest at " + str(physical_size))


func _win(app, label: String) -> void:
	app._page_hidden = false
	app._speech_debug_active = false
	app.collection_page.hide()
	app._leaderboard_overlay.hide()
	var quest = app._quest
	quest.start_level(1)
	_freeze(quest)
	for turn in range(180):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if not prompt.is_empty():
			quest._submit_text(str(prompt.text))
		quest._process(0.65)
	_freeze(quest)
	check(quest.game.phase == "victory" and quest.game.hp == 0
		and quest.game.hits == quest.game.max_hp,
		label + " earns victory from actual live word submissions")
	check(quest._celebration.active and quest._celebration.is_visible_in_tree()
		and not quest._chest_button.is_visible_in_tree(),
		label + " shows Pip's dance before enabling the reward")
	quest._celebration._process(0.4)
	_freeze(quest)


func _check_layout(quest, label: String) -> void:
	var bounds: Rect2 = quest.get_global_rect().grow(1)
	var scale: float = Style.ui_scale(quest)
	check(quest._back.get_theme_font_size("font_size") * scale >= 13.0,
		label + " keeps the Map label readable after viewport scale changes")
	for control: Control in [quest._banner, quest._reward_eyebrow, quest._reward_detail,
		quest._chest, quest._chest_caption, quest._celebration, quest._back, quest._next]:
		if control.is_visible_in_tree():
			check(bounds.encloses(control.get_global_rect()),
				label + " keeps " + str(control.name) + " inside the app's visible Quest region: " + str(control.get_rect()))
	var celebration = quest._celebration
	check(celebration.get_global_rect().grow(1).encloses(celebration.pip.get_global_rect()),
		label + " keeps Pip's actual artwork inside the celebration region")
	check(celebration.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and celebration.pip.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label + " leaves chest gestures unobstructed by Pip")
	check(not quest._stage_scroll.get_v_scroll_bar().visible
		and not quest._stage_scroll.get_h_scroll_bar().visible,
		label + " displays the reward without scrollbars")
	check(not quest._meter.visible and not quest._transcript.visible,
		label + " removes combat-only status from victory and treasure")
	if quest.game.phase == "victory":
		check(celebration.headline.is_visible_in_tree() and celebration.note.is_visible_in_tree(),
			label + " retains the celebration message")
		for text_label: Label in [celebration.headline, celebration.note]:
			check(celebration.get_global_rect().grow(1).encloses(text_label.get_global_rect()),
				label + " keeps the victory copy inside its panel")
		check(celebration.headline.get_theme_font_size("font_size") * scale >= 24.0
			and celebration.note.get_theme_font_size("font_size") * scale >= 12.0,
			label + " keeps the scaled victory copy readable")
	else:
		check(not quest._banner.get_global_rect().intersects(quest._chest.get_global_rect()),
			label + " separates the reward name from its chest")
		check(quest._chest.size.x * scale >= 120 and quest._chest.size.y * scale >= 100,
			label + " preserves a substantial treasure presentation")
		if quest._next.is_visible_in_tree():
			check(quest._next.size.x * scale >= 44.0 and quest._next.size.y * scale >= 43.9,
				label + " preserves a touch-sized Next action under canvas scaling")


func _capture(quest, label: String) -> void:
	_freeze(quest)
	for frame in range(3):
		await process_frame
	_check_layout(quest, label)
	if not _capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty() and image.get_size() == root.size,
		label + " renders the full app at the requested physical resolution")
	if image != null and not image.is_empty():
		check(image.save_png(OUTPUT.path_join(label + ".png")) == OK,
			"Saved the real main-scene capture " + label)


func _review_layout(app, layout: Dictionary) -> void:
	await _resize(app, layout.size)
	var quest = app._quest
	var label: String = layout.label
	var previous_clears: int = quest.game.total_clears
	_win(app, label)
	await _capture(quest, label + "-victory")
	quest._process(10.0)
	check(quest.game.phase == "chest" and quest.game.total_clears == previous_clears,
		label + " waits for a deliberate opening before awarding treasure")
	await _capture(quest, label + "-chest")
	quest.start_chest_hold()
	quest._advance_chest_hold(Feel.HOLD_SECONDS)
	quest._chest._advance_animation(Feel.RELEASE_TIME + 0.08)
	quest.end_chest_hold()
	quest._process(0.0)
	check(quest._opening and quest._chest.opening_committed() and quest.game.phase == "chest",
		label + " reaches the committed opening through the real hold gesture")
	await _capture(quest, label + "-opening")
	quest._chest._advance_animation(Feel.OPEN_SECONDS)
	quest._process(0.0)
	check(quest.game.phase == "complete" and quest.game.total_clears == previous_clears + 1
		and quest._next.is_visible_in_tree(),
		label + " collects exactly one reward and enables the next adventure")
	await _capture(quest, label + "-collected")
	_layouts.append({"label": label, "physical_size": [root.size.x, root.size.y],
		"quest_size": [quest.size.x, quest.size.y], "ui_scale": Style.ui_scale(quest)})


func _run() -> void:
	_capture_enabled = OS.get_cmdline_user_args().has("--capture")
	if _capture_enabled and DisplayServer.get_name() == "headless":
		printerr("Victory review requires the real renderer; omit --headless and use --audio-driver Dummy.")
		quit(1)
		return
	if _capture_enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_directory = "user://quest-victory-app-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_directory) == OK,
		"The main-scene review creates isolated player storage")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(1440, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(
		_directory + "/medals.cfg", _directory + "/legacy.cfg")
	app.playroom_save_path = _directory + "/room.cfg"
	app._mode_id = "quest"
	PlayerFixture.install(app, _directory)
	node_added.connect(_isolate_quest)
	root.add_child(app)
	await process_frame
	await process_frame
	node_added.disconnect(_isolate_quest)
	app.set_process(false)
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	_freeze(app._quest)
	check(app._quest.save_path == _directory + "/quest.cfg" and app._quest._loaded,
		"Quest loads its isolated checkpoint before its ready callback")
	for layout: Dictionary in [
		{"label": "desktop", "size": Vector2i(1440, 900)},
		{"label": "phone", "size": Vector2i(390, 844)},
		{"label": "small-phone", "size": Vector2i(320, 568)},
		{"label": "compact-landscape", "size": Vector2i(568, 320)},
	]:
		await _review_layout(app, layout)
	if _capture_enabled:
		var report := FileAccess.open(OUTPUT.path_join("layouts.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(_layouts, "\t") + "\n")
			report.close()
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)
	print("Talk Quest main-scene victory review: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
