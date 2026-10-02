extends SceneTree

const Quest = preload("res://scripts/talk_quest.gd")
const Style = preload("res://scripts/ui_style.gd")
const OUTPUT := "res://build/talk-quest-compact"
var checks: int = 0
var failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func capture(quest, label: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var crop: Image = frame.get_region(Rect2i(Vector2i(quest.position), Vector2i(quest.size)))
	check(crop.save_png(OUTPUT + "/" + label + ".png") == OK, "The constrained interface renders " + label)


func check_stage(quest, retry: bool, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, quest.size)
	for control in [quest._topline, quest._meter, quest._meter_text, quest._back, quest._words, quest._feedback, quest._transcript]:
		check(bounds.grow(1).encloses(control.get_rect()), label + " keeps its visible controls within the available game body")
	check(not quest._topline.get_rect().intersects(quest._meter.get_rect()), label + " separates the level title and health bar")
	check(not quest._topline.get_rect().intersects(quest._back.get_rect()), label + " separates the level title and Map button")
	check(not quest._meter.get_rect().intersects(quest._meter_text.get_rect()), label + " separates health fill and numeric health")
	check(quest._stage_header.get_rect().grow(1).encloses(quest._back.get_rect()), label + " contains the entire Map button in its header")
	if retry:
		check(bounds.grow(1).encloses(quest._mic_retry.get_rect()), label + " keeps microphone recovery inside the game body")
	for word: Dictionary in quest._words.geometry():
		var rect := Rect2(word.center - word.size * 0.5, word.size)
		check(Rect2(Vector2.ZERO, quest._words.size).encloses(rect), label + " keeps the entire illustrated word card inside its arena")
		check(word.size.x >= 44 and word.size.y >= 44, label + " preserves a readable word card in a short viewport")
		if retry:
			rect.position += quest._words.position
			check(not rect.intersects(quest._mic_retry.get_rect()), label + " never covers a word card with the microphone action")


func check_continue_after_scale_changes() -> void:
	var previous_size: Vector2i = root.size
	var previous_mode: int = root.content_scale_mode
	var previous_aspect: int = root.content_scale_aspect
	var previous_scale_size: Vector2i = root.content_scale_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(1440, 900)
	await settle()
	var quest = Quest.new()
	quest.save_path = "user://quest-continue-scale-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	quest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quest.set_process(false)
	quest.start_level(1)
	quest._show_map()
	await settle()
	var initial_scale: float = Style.ui_scale(quest)
	check(initial_scale > 1.5, "The Continue regression starts with a desktop-scaled interface")
	for dimensions in [Vector2i(390, 844), Vector2i(568, 320), Vector2i(390, 844)]:
		root.size = dimensions
		await settle()
		var scale: float = Style.ui_scale(quest)
		check(initial_scale > scale * 1.5, "Resizing changes the real viewport scale instead of only the map dimensions")
		check(quest._continue.visible and quest.game.has_saved_run(), "The same saved adventure retains its Continue action after resizing")
		var physical_font: float = quest._continue.get_theme_font_size("font_size") * scale
		check(physical_font >= 14.0 and physical_font <= 16.0,
			"Continue text stays readable after desktop-to-phone resizing at %s (%.2f pixels)" % [str(dimensions), physical_font])
		check(quest._continue.size.y * scale >= 44.0,
			"The resized Continue action keeps a full-size touch target")
	var path: String = quest.save_path
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	root.content_scale_mode = previous_mode
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_scale_size
	root.size = previous_size


func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(568, 320)
	var quest = Quest.new()
	quest.save_path = "user://quest-compact-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	quest.set_process(false)
	for layout: Dictionary in [
		{"viewport": Vector2i(568, 320), "position": Vector2(12, 124), "size": Vector2(544, 184), "label": "landscape"},
		{"viewport": Vector2i(320, 568), "position": Vector2(12, 142), "size": Vector2(296, 414), "label": "portrait"}
	]:
		root.size = layout.viewport
		quest.position = layout.position
		quest.size = layout.size
		quest.start_level(1)
		quest.game.advance(4.4)
		quest._refresh_word_field()
		await settle()
		check_stage(quest, false, str(layout.label) + " active")
		await capture(quest, str(layout.label) + "-active")
		quest._feedback.text = "Voice input is unavailable in this browser."
		quest._mic_retry.show()
		await settle()
		check_stage(quest, true, str(layout.label) + " retry")
		await capture(quest, str(layout.label) + "-retry")
		quest._show_map()
		check(quest._continue.visible, "The map layout retains a real saved run and its Continue action")
		quest._album_button.text = "Treasures  20 / 20"
		quest._layout()
		await settle()
		check(Rect2(Vector2.ZERO, quest.size).encloses(quest._album_button.get_rect()), str(layout.label) + " contains the full treasure collection button")
		check(not quest._map_heading.get_rect().intersects(quest._album_button.get_rect()), str(layout.label) + " keeps the map title separate from its treasure action")
		if str(layout.label) == "landscape":
			check(quest._continue.position.y == 0 and not quest._continue.get_rect().intersects(quest._album_button.get_rect()), "Landscape Continue shares the header without overlapping Treasures")
		for chapter in range(3):
			quest._atlas.set_chapter(chapter)
			await settle()
			for button in quest._atlas.visible_level_buttons():
				check(button.size.x >= 44 and button.size.y >= 44, "Every saved-map chapter retains full-size level targets")
				check(Rect2(Vector2.ZERO, button.size).encloses(button._caption.get_rect()), "Every saved-map caption is inside its actual target")
				if button.compact:
					check(Rect2(Vector2.ZERO, button.size).encloses(button.compact_badge_rect()), "Every compact level number paints inside its actual target")
			await capture(quest, str(layout.label) + "-map-" + str(chapter))
	var path: String = quest.save_path
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	await check_continue_after_scale_changes()
	print("Talk Quest compact layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
