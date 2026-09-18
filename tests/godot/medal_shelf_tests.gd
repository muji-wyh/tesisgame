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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(1024, 768)
	var directory := "user://medal-shelf-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var earlier: Dictionary = app.Data.rewards("spring").filter(
		func(reward: Dictionary) -> bool: return app.Data.medal(reward.id).is_empty())[0]
	app.medal_progress.counts = {"spring-1": 1, "spring-2": 3, "spring-3": 3, "summer-1": 3, "summer-2": 2}
	app.medal_progress.legacy_rewards = {earlier.id: true}
	app._build_collection()
	app._show_collection()
	app._show_reward_section("medals")
	await settle()
	check(app._reward_slots.size() == 49, "All active medals and the earned legacy reward remain available")
	check(app._reward_slots["spring-1"].label.text.ends_with("\n1/3"), "Partial medals retain their meaningful piece count")
	check(app._reward_slots["spring-2"].label.text == app._reward_slots["spring-2"].reward.name,
		"Completed medals do not repeat Complete under every name")
	check(app._reward_slots["spring-5"].label.text == "0/3", "Mystery eggs do not repeat Surprise on every tile")
	for dimensions in [Vector2i(320, 568), Vector2i(1024, 768), Vector2i(1536, 1152)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		check(app._collection_grid.get_theme_constant("separation") * scale >= 20,
			"World shelves have breathing room between them")
		if dimensions.x >= 1024:
			check(app._collection_shelves[0].size.y * scale <= 324,
				"A world with one earlier reward no longer consumes a second full-size section")
		for heading in app._collection_grid.find_children("*", "Label", true, false):
			if heading.text == "Earlier rewards":
				check(heading.get_theme_font_size("font_size") * scale >= 12
					and heading.get_theme_font_size("font_size") * scale < 14,
					"The legacy caption uses a quiet CSS-sized type scale")
		for id in app._reward_slots:
			var slot: Dictionary = app._reward_slots[id]
			if id == earlier.id:
				check(slot.button.size.y * scale >= 56 and slot.button.size.y * scale < 60
					and slot.button.size.x * scale <= 132, "Earlier rewards use compact, usable chips: size=%s scale=%s" % [slot.button.size, scale])
				check(slot.label.text == earlier.name and slot.picture.texture != null and not slot.button.disabled,
					"The legacy chip keeps its artwork, name, and action")
			else:
				check(is_zero_approx(slot.button.get_theme_stylebox("normal").bg_color.a),
					"Active medals do not add a second layer of white card panels")
			check(slot.button.get_global_rect().grow(1).encloses(slot.label.get_global_rect()),
				"Medal captions fit inside their targets at every scale")
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	var legacy: Dictionary = app.medal_progress.legacy_rewards.duplicate(true)
	app._reward_slots[earlier.id].button.pressed.emit()
	check(app._preview_page.visible and app._preview_reward_id == earlier.id,
		"The compact legacy chip still opens its original reward")
	check(app.medal_progress.counts == counts and app.medal_progress.legacy_rewards == legacy,
		"The presentation change does not alter saved progress")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Medal shelves: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
