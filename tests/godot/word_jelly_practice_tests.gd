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


func _check_resize_history(panel) -> void:
	for width: float in [232.0, 160.0, 200.0, 152.0, 232.0]:
		panel.configure_layout(Rect2(16, 70, width, 310), 1.0, false)
		await process_frame
		await process_frame
		var bounds: Rect2 = panel.get_global_rect()
		var viewport: Rect2 = panel._scroll.get_global_rect()
		check(bounds.grow(0.1).encloses(viewport),
			"Resizing the same sidebar to %.0f keeps its scroll viewport inside the reserved gutter: panel=%s scroll=%s content_min=%s" % [
				width, bounds, viewport, panel._content.custom_minimum_size])
		check(panel._scroll.get_v_scroll_bar().max_value > panel._scroll.get_v_scroll_bar().page,
			"A resized eight-word sidebar retains a real vertical scroll range after repeated refreshes")
		for row: Dictionary in panel._rows:
			if not row.surface.visible:
				continue
			var card: Rect2 = row.surface.get_global_rect()
			check(card.position.x >= bounds.position.x and card.end.x <= bounds.end.x + 0.1,
				"Resizing the same sidebar to %.0f never retains an earlier wider card (actual %.1f)" % [width, card.size.x])
	for compact: bool in [true, false, true]:
		var area := Rect2(16, 70, 300, 28) if compact else Rect2(16, 70, 160, 310)
		panel.configure_layout(area, 1.0, compact)
		await process_frame
		await process_frame
		check(panel.get_global_rect().grow(0.1).encloses(panel._scroll.get_global_rect()),
			"Switching between carousel and sidebar clears the previous axis's content minimum")


func _check_progress_feedback(panel) -> void:
	check(panel.has_signal("word_progressed") and panel.has_method("advance"),
		"Each saved word-progress transition has a bounded animation and completion event")
	if not panel.has_signal("word_progressed") or not panel.has_method("advance"):
		return
	panel.configure_layout(Rect2(16, 70, 232, 310), 1.0, false)
	var events: Array = []
	panel.connect("word_progressed", func(id: String, complete: bool) -> void: events.append([id, complete]))
	var state: Dictionary = panel._state.duplicate(true)
	state.practice[0].current = 1
	panel.set_stage(state)
	panel.advance(0.09)
	var row: Dictionary = panel._rows[0]
	check(row.fraction.scale.x > 1.0 and row.gain_label.is_visible_in_tree()
		and events == [[str(state.practice[0].id), false]],
		"A saved increment pops its own fraction and +1, without declaring completion")
	panel.set_stage(state)
	check(events.size() == 1, "Refreshing unchanged progress cannot replay an increment")
	state.practice[0].current = 3
	state.practice[0].mastered = true
	panel.set_stage(state)
	panel.advance(0.1)
	check(events.size() == 2 and events[1] == [str(state.practice[0].id), true]
		and panel.snapshot().words[0].get("complete_active", false),
		"Only the newly completed word emits its achievement event for visuals and audio")
	check(row.complete_badge.find_children("*", "Label", true, false).is_empty()
		and not row.fraction.is_visible_in_tree() and not row.gain_label.is_visible_in_tree(),
		"A completed goal uses only its check animation, without Done, seconds, fractions or +1 text")
	var check_material := row.complete_icon.material as ShaderMaterial
	check(check_material != null and float(check_material.get_shader_parameter("check_progress")) > 0.0
		and float(check_material.get_shader_parameter("check_progress")) < 1.0,
		"The acquired check stroke is actually being revealed, not merely showing a static icon")
	if check_material != null:
		var check_progress: float = float(check_material.get_shader_parameter("check_progress"))
		panel.set_stage(state)
		panel.configure_layout(Rect2(16, 70, 300, 28), 1.0, true)
		check(is_equal_approx(float(row.complete_elapsed), 0.1)
			and is_equal_approx(float(check_material.get_shader_parameter("check_progress")), check_progress),
			"Refresh and compact relayout preserve the same partial stroke and silent hold clock")
		check(row.complete_icon.material != panel._rows[1].complete_icon.material,
			"Each goal owns its own check stroke instead of animating every row together")
		panel.configure_layout(Rect2(16, 70, 232, 310), 1.0, false)
	panel.advance(1.2)
	check(panel.snapshot().words[0].get("completed_marker_visible", false)
		and not panel.snapshot().words[0].get("complete_active", false),
		"The completed badge remains readable after its success burst")
	var next_position: Vector2 = panel._rows[1].surface.position
	panel.advance(1.699)
	check(row.surface.visible and row.surface.modulate.a == 1.0
		and panel.snapshot().words[0].dismiss_remaining > 0.0,
		"Completion stays fully marked for the entire silent three-second hold")
	panel.advance(0.191)
	check(row.surface.visible and row.surface.modulate.a > 0.0 and row.surface.modulate.a < 1.0
		and panel._rows[1].surface.position.y < next_position.y,
		"After three seconds the completed row fades and pending goals smoothly reclaim its space")
	panel.advance(0.3)
	check(not row.surface.visible and panel.snapshot().words[0].retired
		and panel._rows[1].surface.position.y == 0.0,
		"The retired completion leaves only the next pending goal in the first list slot")
	panel.set_stage({})
	panel.set_stage(state)
	check(events.size() == 2 and panel.snapshot().words[0].retired
		and not panel.snapshot().words[0].get("completed_marker_visible", false)
		and not panel.snapshot().words[0].get("complete_active", false),
		"Reloading already completed targets keeps them out of the pending list without replaying success")
	panel.configure_layout(Rect2(16, 70, 300, 28), 1.0, true)
	check(not panel.snapshot().words[0].get("completed_marker_visible", false)
		and not panel._rows[0].fraction.is_visible_in_tree(),
		"A narrow layout cannot resurrect retired completed chips")


func _check_silent_check_lifecycle(panel) -> void:
	var state: Dictionary = panel._state.duplicate(true)
	for steady: bool in [false, true]:
		for compact: bool in [false, true]:
			panel.set_stage({})
			panel.reduced_motion = steady
			panel.configure_layout(Rect2(16, 70, 300, 28) if compact else Rect2(16, 70, 232, 310), 1.0, compact)
			state.practice[0].current = 2
			state.practice[0].mastered = false
			panel.set_stage(state)
			state.practice[0].current = 3
			state.practice[0].mastered = true
			panel.set_stage(state)
			var row: Dictionary = panel._rows[0]
			var material := row.complete_icon.material as ShaderMaterial
			check(row.complete_badge.is_visible_in_tree() and row.complete_badge.size.x == row.complete_badge.size.y
				and row.complete_badge.find_children("*", "Label", true, false).is_empty()
				and not row.fraction.visible and not row.gain_label.visible,
				"Both sidebar and compact completion marks are icon-only, never a Done/countdown pill")
			if material == null:
				check(false, "Each completion check has its source-stroke reveal material")
				continue
			check(is_equal_approx(float(material.get_shader_parameter("check_progress")), 1.0 if steady else 0.0),
				"Reduced motion shows a full still check; normal motion begins with the tick undrawn")
			panel.advance(0.20)
			var progress: float = float(material.get_shader_parameter("check_progress"))
			check(is_equal_approx(progress, 1.0) if steady else progress > 0.0 and progress < 1.0,
				"Normal motion visibly writes the tick while reduced motion keeps it complete and still")
			panel.hide()
			panel.advance(20.0)
			panel.show()
			check(is_equal_approx(float(row.complete_elapsed), 0.20)
				and is_equal_approx(float(material.get_shader_parameter("check_progress")), progress),
				"Hiding or pausing the owner does not consume the silent hold or advance its tick")
			panel.advance(2.799)
			check(row.surface.visible and row.surface.modulate.a == 1.0
				and is_equal_approx(float(material.get_shader_parameter("check_progress")), 1.0),
				"The complete silent check remains fully visible until three active seconds")
			panel.advance(0.002)
			check(not row.surface.visible if steady else row.surface.visible and row.surface.modulate.a < 1.0,
				"Only after three seconds does the row begin its exit, or retire directly in reduced motion")
			panel.advance(panel.EXIT_SECONDS)
			check(not row.surface.visible and row.retired and panel._rows[1].surface.position == Vector2.ZERO,
				"Retirement removes the completed card and gives its slot to the next pending goal")
	panel.reduced_motion = false


func _check_rendered_check(panel) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var state: Dictionary = panel._state.duplicate(true)
	panel.set_stage({})
	panel.configure_layout(Rect2(16, 70, 232, 310), 1.0, false)
	state.practice[0].current = 2
	state.practice[0].mastered = false
	panel.set_stage(state)
	state.practice[0].current = 3
	state.practice[0].mastered = true
	panel.set_stage(state)
	var row: Dictionary = panel._rows[0]
	var area := Rect2i(row.surface.get_global_rect())
	var sheet := Image.create(area.size.x * 3, area.size.y * 2, false, Image.FORMAT_RGBA8)
	var white_counts: Array[int] = []
	var elapsed: float = 0.0
	for index in range(6):
		var age: float = [0.0, 0.18, 0.60, 2.99, 3.19, 3.40][index]
		if age > elapsed:
			panel.advance(age - elapsed)
		elapsed = age
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		sheet.blit_rect(image, area, Vector2i((index % 3) * area.size.x, (index / 3) * area.size.y))
		if index >= 3:
			continue
		var icon: Rect2 = row.complete_icon.get_global_rect()
		var tick := Rect2i(icon.position + icon.size * Vector2(0.32, 0.35), icon.size * Vector2(0.36, 0.30))
		var white: int = 0
		for y in range(tick.position.y, tick.end.y):
			for x in range(tick.position.x, tick.end.x):
				var color: Color = image.get_pixel(x, y)
				if minf(color.r, minf(color.g, color.b)) > 0.85:
					white += 1
		white_counts.append(white)
	check(white_counts.size() == 3 and white_counts[0] < white_counts[1] and white_counts[1] < white_counts[2],
		"The actual rendered source tick grows from absent to partial to complete, not only a changing uniform: %s" % str(white_counts))
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-practice")
	check(sheet.save_png("res://build/qa/jelly-practice/check-stroke-retirement.png") == OK,
		"Capture the real completion stroke, silent hold, exit and reclaimed pending-goal slot")


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
			check(row.fraction.is_visible_in_tree() == (not state.compact and not state.words[index].mastered),
				"Compact practice cards never show progress numbers; desktop retains the readable fraction")
			var background: ProgressBar = row.get("background_progress")
			check(background != null and background.is_visible_in_tree() == (not state.words[index].mastered)
				and is_equal_approx(float(background.value) / float(background.max_value), float(index % 4) / 3.0),
				"Pending cards retain their true progress fill while precompleted cards stay retired")
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
		if dimensions == Vector2i(1366, 768):
			await _check_resize_history(panel)
			_check_progress_feedback(panel)
			_check_silent_check_lifecycle(panel)
			await _check_rendered_check(panel)
		view.free()
	await process_frame
	print("Jelly stage practice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
