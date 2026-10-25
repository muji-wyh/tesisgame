extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-practice")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-practice/" + name + ".png") == OK,
		"Capture actual responsive word progress outside the well")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var data := Data.new()
	check(data.load_all(), "Practice uses real game vocabulary and existing production assets")
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(320, 480), Vector2i(844, 390)]:
		root.size = dimensions
		var view := Jelly.new()
		root.add_child(view)
		view.size = Vector2(dimensions)
		var words: Array = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3).slice(0, 8)
		check(view.configure(words, 3, Data.theme("spring"), data.chests, false, 3821), "The practice layout retains a real Jelly board")
		view.set_process(false)
		view.set_stage_progress({"number": 6, "mastered": 2, "total": 8, "remaining": 6})
		var board: Rect2 = view._board
		var preview: Rect2 = view._preview_rect
		var pitch: float = view._pitch
		var practice: Array[Dictionary] = []
		for index in range(8):
			practice.append({"id": words[index].id, "text": words[index].text,
				"image": words[index].get("image", ""),
				"current": index % 4, "required": 3, "mastered": index % 4 == 3})
		view.set_stage_progress({"number": 6, "mastered": 2, "total": 8, "remaining": 6, "practice": practice})
		await process_frame
		var panel = view._practice_panel
		var state: Dictionary = panel.snapshot()
		var bounds := Rect2(Vector2.ZERO, view.size)
		check(state.visible and state.words.size() == 8 and bounds.grow(0.1).encloses(panel.get_rect())
			and not panel.get_rect().intersects(view._board) and not panel.get_rect().intersects(view._preview_rect),
			"The eight word rows occupy unused gutter or the stage rail, never playable cells")
		check(view._board == board and view._preview_rect == preview and is_equal_approx(view._pitch, pitch),
			"Adding individual practice progress never shrinks or shifts the existing board or supply")
		if dimensions == Vector2i(1366, 768):
			check(not state.compact, "Desktop uses its empty sidebar for all practice words")
		elif dimensions.x < dimensions.y:
			check(state.compact, "Narrow portrait layouts use the existing stage rail without shrinking the well")
		for index in range(8):
			var row: Dictionary = panel._rows[index]
			check(row.label.text == str(words[index].text) and row.fraction.text == "%d/3" % [index % 4]
				and state.words[index].id == words[index].id,
				"The actual word label, fraction and diagnostics identify the same mastery progress")
			var picture: TextureRect = row.get("picture")
			check(picture != null and picture.texture != null,
				"Practice cards use each word's real acquired vocabulary illustration, not a plain spreadsheet row")
			if not state.compact:
				check(row.surface.size.y * panel._scale >= 50.0
					and row.label.get_theme_font_size("font_size") * panel._scale >= 16.9,
					"The sidebar gives every illustrated word a readable, comfortably spaced card")
			check(row.get("steps", []).size() == 3,
				"Three sourced mastery accents replace the generic table-like progress line")
			check(row.fraction.is_visible_in_tree() == (not state.compact),
				"Compact practice cards never show progress numbers; desktop retains the readable fraction")
			var background: ProgressBar = row.get("background_progress")
			check(background != null and background.is_visible_in_tree()
				and is_equal_approx(float(background.value) / float(background.max_value), float(index % 4) / 3.0),
				"Both desktop and compact card backgrounds fill in proportion to actual saved mastery")
			check(background != null and Rect2(Vector2.ZERO, row.surface.size).encloses(background.get_rect()),
				"Background progress preserves the rounded card border instead of bleeding past its edges")
			if row.get("steps", []).size() == 3:
				for step in range(3):
					check(row.steps[step].modulate == (Color("#e3aa35") if step < index % 4 else Color("#b9c9bf")),
						"The visible mastery accents fill from the same durable correct-answer count")
			check(row.surface.get_rect().grow(0.1).encloses(Rect2(
				row.surface.position + row.fraction.position, row.fraction.size)),
				"Every mastery number stays within its illustrated card instead of clipping at an edge")
		check(panel._rows[0].label.size.y <= panel._scroll.size.y + 0.1,
			"The compact word font fits the visible stage strip without clipping its descenders")
		await _capture("%dx%d-eight-words" % [dimensions.x, dimensions.y])
		view.free()
	await process_frame
	print("Jelly stage practice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
