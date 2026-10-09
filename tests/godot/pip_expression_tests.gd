extends SceneTree

const Mascot = preload("res://scripts/duck_mascot.gd")
const LEVELS := [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const FACES := ["neutral", "listening", "thinking", "delighted", "proud", "encourage", "surprised", "sleepy", "wink", "blink"]
const HAPPY_FACES := ["delighted", "wink", "proud"]
const RUNTIME_CASES := ["neutral", "listening", "thinking", "curious", "greeting", "hit-start", "hit-middle", "hit-tail", "miss-start", "miss-tail"]
const PADDING := 12

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(360, 300)
	var duck = Mascot.new()
	root.add_child(duck)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duck.custom_minimum_size = Vector2(52, 52)
	duck.size = Vector2(52, 52)
	duck.position = Vector2(100, 100)
	duck.set_process(false)
	_check_attention_and_priority(duck)
	_check_gameplay_expressions(duck)
	_check_lifecycle_and_reduced_motion(duck)
	_check_wardrobes_and_bounds(duck)
	if DisplayServer.get_name() != "headless":
		await _check_rendered_faces(duck)
	duck.free()
	print("Pip expressions: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _reset(duck) -> void:
	duck.show()
	duck.set_idle_paused(false)
	duck.set_reduced_motion(false)
	duck.set_proactive_allowed(false)
	duck.settle()
	duck.set_process(false)


func _activity(duck) -> Array:
	return [duck.pose, duck.speaking, duck.reduced_motion, duck.is_processing(),
		duck._attention, duck.reaction_left, duck._reaction,
		duck._idle_time, duck._speech_time, duck._idle_action, duck._idle_left,
		duck._idle_wait, duck._idle_index,
		duck._gameplay_reaction, duck._gameplay_left, duck._gameplay_seconds,
		duck.expression_name()]


func _check_attention_and_priority(duck) -> void:
	_reset(duck)
	check(duck.expression_name() == "neutral" and duck._attention.is_empty(),
		"A settled mascot starts with the original neutral face")
	for attention in ["listening", "thinking"]:
		duck.set_attention(attention)
		check(duck._attention == attention and duck.expression_name() == attention and duck.pose == 0,
			attention + " has a distinct face without changing the legacy pose contract")
		duck._process(0.18)
		var before := _activity(duck)
		for repeat in range(20):
			duck.set_attention(attention)
		check(_activity(duck) == before,
			"Repeated " + attention + " context leaves every reaction and idle timer untouched")
	duck.set_attention("listening")
	duck.react("curious")
	check(duck.expression_name() == "thinking" and is_equal_approx(duck.reaction_left, 0.65),
		"A curious greeting temporarily overrides the listening context with a thinking face")
	duck._process(0.2)
	var remaining: float = duck.reaction_left
	duck.set_attention("listening")
	check(is_equal_approx(duck.reaction_left, remaining) and duck.expression_name() == "thinking",
		"A context refresh cannot restart or replace a timed curious reaction")
	duck._process(0.46)
	check(duck.expression_name() == "listening" and is_zero_approx(duck.reaction_left),
		"Timed curiosity expires and reveals the still-current listening context")
	var greetings: Array[String] = []
	for repeat in range(9):
		duck.react("happy")
		var face: String = duck.expression_name()
		check(face in HAPPY_FACES and duck.pose == 3,
			"Happy greetings use a friendly expression while preserving legacy happy pose 3")
		if not greetings.has(face):
			greetings.append(face)
		duck._process(0.66)
	check(greetings.size() >= 2, "Repeated hellos vary their authored facial expression")
	duck.set_attention("thinking")
	duck.set_speaking(true)
	check(duck.expression_name() in ["neutral", "speaking"] and duck.speaking,
		"Actual pronunciation takes priority over a passive thinking expression")
	duck._process(0.12)
	var speech_time: float = duck._speech_time
	duck.set_attention("listening")
	check(is_equal_approx(duck._speech_time, speech_time) and duck.expression_name() != "listening",
		"Changing attention never restarts pronunciation or covers its speaking face")
	duck.set_speaking(false)
	check(duck.expression_name() == "listening", "Finishing pronunciation returns to the active attention face")
	duck.set_growth_level(12)
	for action in ["peekaboo", "high-five", "dance-wave"]:
		duck.settle()
		duck.set_attention("listening")
		duck.perform_trick(action)
		duck._process(0.15)
		var remaining_action: float = duck._idle_left
		duck.set_attention("thinking")
		check(duck._idle_action == action and is_equal_approx(duck._idle_left, remaining_action)
			and duck.expression_name() != "thinking", "A manual " + action + " retains its face and deadline over passive attention")
		duck._process(3.0)
		check(duck._idle_action.is_empty() and duck.expression_name() == "thinking", "An explicit gesture finishes and returns to the latest attention context")
		duck.settle()
	duck.set_attention("")
	check(duck._attention.is_empty() and duck.expression_name() == "neutral",
		"Clearing attention returns to the ordinary resting face")
	_reset(duck)


func _check_gameplay_expressions(duck) -> void:
	_reset(duck)
	var finished: Array[bool] = []
	var record := func(correct: bool) -> void: finished.append(correct)
	duck.gameplay_reaction_finished.connect(record)
	duck.set_attention("listening")
	duck.set_speaking(true)
	duck.react_gameplay(true)
	check(duck._gameplay_reaction == "happy" and duck.pose == 3
		and is_equal_approx(duck._gameplay_left, 1.25) and duck.expression_name() == "surprised",
		"A correct answer begins with happy semantics, legacy pose 3 and brief delighted surprise")
	duck._process(1.25 * 0.45)
	check(duck.expression_name() in HAPPY_FACES,
		"The central celebration uses one of the varied happy faces")
	var current_face: String = duck.expression_name()
	var remaining: float = duck._gameplay_left
	duck.react("curious")
	duck.set_attention("thinking")
	duck.set_speaking(false)
	duck.note_activity()
	check(duck.expression_name() == current_face and is_equal_approx(duck._gameplay_left, remaining)
		and duck.perform_trick("wave").is_empty(),
		"Attention, hover, speech and greeting input cannot replace the winning result")
	duck._process(1.25 * 0.47)
	check(duck.expression_name() == "proud" and duck._gameplay_reaction == "happy",
		"The last part of a correct response settles into a proud smile")
	duck._process(0.11)
	check(finished == [true] and duck._gameplay_reaction.is_empty() and duck.expression_name() == "thinking",
		"The win emits completion once and returns to the current attention context")
	for duration in [1.35, 2.4]:
		duck.react_gameplay(false, duration)
		check(duck._gameplay_reaction == "sad" and duck.pose == 2
			and is_equal_approx(duck._gameplay_left, duration) and duck.expression_name() == "thinking",
			"A miss preserves sad gameplay semantics and opens with a thoughtful face")
		duck._process(duration * 0.65)
		check(duck._gameplay_reaction == "sad" and duck.expression_name() == "encourage",
			"A missed answer moves into encouragement during its own feedback interval")
		duck._process(duration * 0.36)
		check(duck._gameplay_reaction.is_empty() and duck.expression_name() == "thinking",
			"The encouraging face expires at the requested miss deadline")
	check(finished == [true, false, false], "Each result emits exactly one matching completion signal")
	duck.gameplay_reaction_finished.disconnect(record)
	_reset(duck)


func _check_lifecycle_and_reduced_motion(duck) -> void:
	for reason in ["settle", "hide", "pause"]:
		_reset(duck)
		duck.set_attention("listening")
		duck.react("curious")
		match reason:
			"settle": duck.settle()
			"hide": duck.hide()
			"pause": duck.set_idle_paused(true)
		check(duck._attention.is_empty() and is_zero_approx(duck.reaction_left)
			and duck.expression_name() == "neutral", reason + " clears temporary and contextual expressions")
		if reason != "settle":
			duck.set_attention("thinking")
			duck.react("happy")
			duck.react_gameplay(true)
			check(duck._attention.is_empty() and is_zero_approx(duck.reaction_left)
				and duck._gameplay_reaction.is_empty() and not duck.is_processing(),
				reason + " rejects late face updates and never starts hidden animation work")
		_reset(duck)
		check(duck.expression_name() == "neutral", "Resuming after " + reason + " cannot replay a stale face")
	duck.set_reduced_motion(true)
	duck.set_attention("listening")
	for kind in ["curious", "happy"]:
		duck.react(kind)
		var face: String = duck.expression_name()
		check(is_equal_approx(duck.reaction_left, 0.65) and duck.is_processing()
			and (face == "thinking" if kind == "curious" else face in HAPPY_FACES),
			"Reduced motion retains a readable, timed " + kind + " expression")
		duck._process(0.35)
		check(duck.expression_name() == face and duck.reaction_left > 0.0,
			"Reduced-motion " + kind + " stays on one expression during its feedback interval")
		duck._process(0.31)
		check(duck.expression_name() == "listening" and is_zero_approx(duck.reaction_left)
			and not duck.is_processing(), "Reduced-motion " + kind + " expires without a permanent processing loop")
	for correct in [true, false]:
		duck.react_gameplay(correct)
		var expected: String = "delighted" if correct else "encourage"
		check(duck.expression_name() == expected, "Reduced-motion results use one calm, readable face")
		duck._process(0.7)
		check(duck.expression_name() == expected and duck._gameplay_left > 0.0,
			"Reduced-motion result expressions never cycle through animated phases")
		duck._process(0.7)
		check(duck.expression_name() == "listening" and duck._gameplay_reaction.is_empty()
			and not duck.is_processing(), "Static gameplay faces return to the live context at their deadline")
	_reset(duck)


func _check_wardrobes_and_bounds(duck) -> void:
	_reset(duck)
	var bounds: Rect2 = duck.get_rect()
	var children: int = duck.get_child_count()
	var presses: Array[bool] = []
	var record := func() -> void: presses.append(true)
	duck.pressed.connect(record)
	for scenario in ["listening", "thinking", "curious", "greeting", "hit-middle", "miss-tail"]:
		_select_runtime_case(duck, scenario)
		var before := [duck._attention, duck._reaction, duck.reaction_left, duck._gameplay_reaction, duck._gameplay_left, duck.expression_name()]
		for level in LEVELS:
			var theme := "Lv%d" % level
			duck.set_growth_level(level)
			check([duck._attention, duck._reaction, duck.reaction_left, duck._gameplay_reaction, duck._gameplay_left, duck.expression_name()] == before and duck.growth_level == level,
				"The " + theme + " wardrobe keeps the current " + scenario + " expression and its timing")
			var sheets: Array[Texture2D] = [duck._expression_sheet, duck._expression_heads]
			check(sheets.all(func(sheet: Texture2D) -> bool: return (sheet != null
				and sheet.get_height() > 0 and sheet.get_width() == sheet.get_height() * FACES.size())),
				"The " + theme + " wardrobe supplies ten aligned full-body and articulated-head cells")
			duck.set_growth_level(level)
			check(sheets == [duck._expression_sheet, duck._expression_heads] and [duck._attention, duck._reaction, duck.reaction_left, duck._gameplay_reaction, duck._gameplay_left, duck.expression_name()] == before,
				"Refreshing an unchanged wardrobe retains its expression resources and every deadline")
			check(duck.get_rect() == bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation),
				"Facial expression updates retain Pip's exact input bounds")
	check(presses.is_empty() and duck.get_child_count() == children,
		"Expressions add no activation, audio players, timer nodes or effect nodes")
	duck.pressed.disconnect(record)
	_reset(duck)


func _select_runtime_case(duck, scenario: String) -> void:
	_reset(duck)
	match scenario:
		"listening", "thinking": duck.set_attention(scenario)
		"curious": duck.react("curious")
		"greeting": duck.react("happy")
		"hit-start", "hit-middle", "hit-tail":
			duck.react_gameplay(true)
			var fraction: float = 0.05 if scenario == "hit-start" else 0.45 if scenario == "hit-middle" else 0.92
			duck._process(duck._gameplay_duration() * fraction)
		"miss-start", "miss-tail":
			duck.react_gameplay(false)
			duck._process(duck._gameplay_duration() * (0.1 if scenario == "miss-start" else 0.65))
	duck.set_process(false)


func _capture(viewport: SubViewport, duck) -> Image:
	var before := _activity(duck)
	duck.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(_activity(duck) == before, "Capturing visual evidence never advances or changes gameplay expression state")
	return viewport.get_texture().get_image()


func _visible_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				first = Vector2i(mini(first.x, x), mini(first.y, y))
				last = Vector2i(maxi(last.x, x), maxi(last.y, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= 0 else Rect2i()


func _check_rendered_faces(duck) -> void:
	var directory := ProjectSettings.globalize_path("res://build/pip-expressions-native")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The expression evidence directory is available")
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	duck.reparent(viewport)
	duck.position = Vector2(PADDING, PADDING)
	var artwork := TextureRect.new()
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.position = Vector2(PADDING, PADDING)
	viewport.add_child(artwork)
	var metadata := {"rows": LEVELS, "atlas_columns": FACES, "runtime_columns": RUNTIME_CASES}
	var manifest := FileAccess.open(directory + "/contact-sheets.json", FileAccess.WRITE)
	check(manifest != null, "The expression contact sheets have an English row and column key")
	if manifest != null:
		manifest.store_string(JSON.stringify(metadata, "\t"))
		manifest.close()
	for edge in [52, 156]:
		var cell: int = edge + PADDING * 2
		viewport.size = Vector2i(cell, cell)
		duck.size = Vector2(edge, edge)
		artwork.size = Vector2(edge, edge)
		await _render_atlases(viewport, duck, artwork, edge, directory)
		artwork.hide()
		duck.show()
		var montage := Image.create(cell * RUNTIME_CASES.size(), cell * LEVELS.size(), false, Image.FORMAT_RGBA8)
		montage.fill(Color("#fff7df"))
		for row in range(LEVELS.size()):
			duck.set_growth_level(LEVELS[row])
			var frames: Array[PackedByteArray] = []
			for column in range(RUNTIME_CASES.size()):
				_select_runtime_case(duck, RUNTIME_CASES[column])
				var frame: Image = await _capture(viewport, duck)
				frame.convert(Image.FORMAT_RGBA8)
				var used: Rect2i = _visible_bounds(frame)
				check(used.has_area() and Rect2i(1, 1, cell - 2, cell - 2).encloses(used),
					"The actual " + ("Lv%d" % LEVELS[row]) + " " + RUNTIME_CASES[column] + " mascot is complete at %d pixels" % edge)
				frames.append(frame.get_data())
				montage.blend_rect(frame, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(column * cell, row * cell))
			check(frames[0] != frames[1] and frames[0] != frames[2] and frames[1] != frames[2],
				"Rest, listening and thinking render distinct actual pixels in " + ("Lv%d" % LEVELS[row]) + " at %d pixels" % edge)
			check(frames[5] != frames[6] and frames[6] != frames[7] and frames[8] != frames[9],
				"Result faces visibly progress through their authored phases in " + ("Lv%d" % LEVELS[row]) + " at %d pixels" % edge)
			await _check_rendered_reduced_motion(viewport, duck, edge)
		check(montage.save_png(directory + "/runtime-%d.png" % edge) == OK,
			"Actual %d-pixel expressions are saved for independent visual review" % edge)
	_reset(duck)
	duck.reparent(root)
	viewport.queue_free()
	await process_frame


func _render_atlases(viewport: SubViewport, duck, artwork: TextureRect, edge: int, directory: String) -> void:
	var cell: int = edge + PADDING * 2
	duck.hide()
	artwork.show()
	for part in ["full", "heads"]:
		var montage := Image.create(cell * FACES.size(), cell * LEVELS.size(), false, Image.FORMAT_RGBA8)
		montage.fill(Color("#fff7df"))
		for row in range(LEVELS.size()):
			duck.set_growth_level(LEVELS[row])
			var sheet: Texture2D = duck._expression_sheet if part == "full" else duck._expression_heads
			var source_edge: float = sheet.get_height()
			var frames: Array[PackedByteArray] = []
			for column in range(FACES.size()):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(column * source_edge, 0, source_edge, source_edge)
				atlas.filter_clip = true
				artwork.texture = atlas
				var frame: Image = await _capture(viewport, duck)
				frame.convert(Image.FORMAT_RGBA8)
				var used: Rect2i = _visible_bounds(frame)
				check(used.has_area() and Rect2i(PADDING, PADDING, edge, edge).encloses(used),
					"The " + ("Lv%d" % LEVELS[row]) + " " + FACES[column] + " " + part + " atlas cell has isolated, visible artwork at %d pixels" % edge)
				var pixels: PackedByteArray = frame.get_data()
				check(not frames.has(pixels), "The " + ("Lv%d" % LEVELS[row]) + " " + FACES[column] + " " + part
					+ " expression has its own rendered pixels at %d pixels" % edge)
				frames.append(pixels)
				montage.blend_rect(frame, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(column * cell, row * cell))
		check(montage.save_png(directory + "/atlas-%s-%d.png" % [part, edge]) == OK,
			"All ten " + part + " expressions and ten growth appearances are saved at %d pixels" % edge)


func _check_rendered_reduced_motion(viewport: SubViewport, duck, edge: int) -> void:
	_reset(duck)
	duck.set_reduced_motion(true)
	duck.set_attention("listening")
	for kind in ["curious", "happy", "correct", "miss"]:
		if kind in ["correct", "miss"]:
			duck.react_gameplay(kind == "correct")
		else:
			duck.react(kind)
		duck.set_process(false)
		var before: PackedByteArray = (await _capture(viewport, duck)).get_data()
		duck._process(0.3)
		duck.set_process(false)
		check((await _capture(viewport, duck)).get_data() == before,
			"Reduced-motion " + kind + " keeps identical actual pixels at %d pixels" % edge)
		duck._process(2.0)
		duck.set_process(false)
	_reset(duck)
